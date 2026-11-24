create or replace procedure it.PRS_SNP_GEN_ENC_ESPECIAL( p_fecha in sb_encajes_esp.fec_constitucion%type default pas_snp.g_fec_actual ) is

   v_cod_mensaje              sb_snp_tip_mensajes.cod_mensaje%type := 'MTn99/SETACCOUNTLIMIT';
   v_mto_constitucion         sb_encajes_esp.bcp_depositado%type := 0;
   v_mto_desafectacion        sb_encajes_esp.bcp_depositado%type := 0;
   v_nro_ref_encaje           ge_snp_mensajes.nro_referencia%type;
   v_fec_proceso              sb_encajes_esp.fec_desafectacion%type := nvl(p_fecha, pas_snp.g_fec_actual);
   v_secuencia                number(2) := 0;
   v_mensaje                  varchar2(4000);
   v_lugar                    varchar2(200);
   v_hora                     ge_movimientos.hora%type;
   r_cc_cta_ban_liquidacion   cc_cta_bancarias%rowtype;
   v_contar                   number(3) := 0;

   cursor c_cuentas is --Cuentas de encaje legal
      select c.nro_cuenta,
             c.nro_cta_bancaria,
             c.cod_moneda,
             c.cod_modulo,
             c.cod_modalidad
        from cc_cta_bancarias c,
             gv_snp_participantes d
       where c.cod_banco = d.cod_banco --Solo de la entidad
         and d.cod_persona = fug_obt_per_entidad
         and c.cod_modulo = pas_snp.fu_obt_cod_mod_padre
         and c.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
         and fug_obt_paradicional(c.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'ESP';

   cursor c_enc_especial( p_cod_moneda in sb_encajes_esp.cod_moneda%type ) is
      select a.bcp_depositado,
             a.fec_constitucion,
             a.cod_moneda
        from sb_encajes_esp a
       where a.cod_moneda = p_cod_moneda
       and a.ind_excluir='N'
              /*Constitución Pendiente*/
         and ((a.fec_constitucion is null
               and a.nro_ref_constitucion is null
               and a.fec_rescate < v_fec_proceso)
              /*Desafectación Pendiente*/
           or (a.fec_desafectacion is null and a.nro_ref_desafectacion is null
               and pag_cal.fu_obt_fec_sig_hab(a.fec_constitucion/*(a pedido de jose sala)*/ + a.dia_transcurrido, null, 0) <= v_fec_proceso )
              /*Reversión de cancelación*/
           or (a.fec_desafectacion is null and a.nro_ref_desafectacion is null
               and a.dia_transcurrido = 0 ))
         for update of a.fec_constitucion,
                       a.nro_ref_constitucion;

begin
   --Por cada cuenta para encaje legal configurada
   --begin
     select count(1)
         into v_contar
         from sb_encajes_esp g where g.estado='P';
       if v_contar >0 then
         raise_application_error(-20001, 'Existen circuitos de workflow sin finalizar');
       end if;

   for cta in c_cuentas loop
      --Inicializo variables
      v_mto_constitucion      := 0;
      v_mto_desafectacion     := 0;
      v_nro_ref_encaje        := null;

      for enc in c_enc_especial( cta.cod_moneda ) loop
         if enc.fec_constitucion is null then --Constitución
            if v_nro_ref_encaje is null then
               v_nro_ref_encaje := pas_snp.fu_obt_sig_nro_referencia;
            end if;
            v_mto_constitucion := v_mto_constitucion + enc.bcp_depositado;
            update sb_encajes_esp e
               set e.nro_ref_constitucion = v_nro_ref_encaje,
                   e.fec_constitucion = v_fec_proceso
             where current of c_enc_especial;
         else --Desafectación
            if v_nro_ref_encaje is null then
               v_nro_ref_encaje := pas_snp.fu_obt_sig_nro_referencia;
            end if;
            v_mto_desafectacion := v_mto_desafectacion + enc.bcp_depositado;
            update sb_encajes_esp e
               set e.nro_ref_desafectacion = v_nro_ref_encaje,
                   e.fec_desafectacion = v_fec_proceso
             where current of c_enc_especial;
         end if;
      end loop;

      if v_mto_constitucion != 0
        or v_mto_desafectacion != 0 then
         --Hallo la interbancaria
         begin --Obtengo la cuenta interbancaria
            select c.*
              into r_cc_cta_ban_liquidacion
              from cc_cta_bancarias c,
                   gv_snp_participantes d
             where c.cod_banco = d.cod_banco --Solo de la entidad
               and d.cod_persona = fug_obt_per_entidad
               and c.cod_modulo = pas_snp.fu_obt_cod_mod_padre
               and c.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
               and c.cod_moneda = cta.cod_moneda
               and fug_obt_paradicional(c.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ';
         exception
            when others then
               raise_application_error(-20001, 'Error al recuperar la cuenta Interbancaria');
         end;

         v_hora := fug_ini_hora;

         if v_mto_constitucion > 0 then
            --Débito Cuenta Interbancaria Encaje Legal Especial y Crédito Cuenta Interbancaria BCP)
            --Movimiento cuenta Encaje
            pag_cta.pr_act_operacion( cta.nro_cuenta,                  -- Nro.Cta.
                                      v_hora,                          -- Hora
                                      'D',                             -- Tip.Mov.
                                      cta.cod_moneda,                  -- Cod.Mon.
                                      v_mto_constitucion,              -- Monto
                                      pas_snp.fu_obt_cod_tra_padre,    -- Trx.Padre
                                      4713,                             -- Trx.Hija
                                      v_nro_ref_encaje,                -- Nro.Doc.
                                      NULL,                            -- Cotizacion
                                      fug_obt_ofi_usuario (user),      -- Ofic.Orig.
                                      cta.cod_modulo,                  -- Mod.Padre
                                      cta.cod_modalidad,               -- Mad.Padre
                                      null,                            -- Cod.Tasa
                                      null,                            -- Val.Tasa
                                      'Constitución Enc.Legal',        -- Concepto
                                      'N',                             -- Emit.Aviso
                                      v_secuencia,
                                      v_fec_proceso
                                    );

            if pag_cta.fu_obt_cod_error <> 0 then
               raise_application_error(-20001, pag_cta.fu_obt_msj_error);
            end if;

         end if;
         if v_mto_desafectacion > 0 then

            --Movimiento cuenta Encaje
            pag_cta.pr_act_operacion( cta.nro_cuenta,                  -- Nro.Cta.
                                      v_hora,                          -- Hora
                                      'C',                             -- Tip.Mov.
                                      cta.cod_moneda,                  -- Cod.Mon.
                                      v_mto_desafectacion,              -- Monto
                                      pas_snp.fu_obt_cod_tra_padre,    -- Trx.Padre OJO
                                      4714,                             -- Trx.Hija OJO
                                      v_nro_ref_encaje,                -- Nro.Doc.
                                      NULL,                            -- Cotizacion
                                      fug_obt_ofi_usuario (user),      -- Ofic.Orig.
                                      r_cc_cta_ban_liquidacion.cod_modulo,    -- Mod.Padre
                                      r_cc_cta_ban_liquidacion.cod_modalidad, -- Mad.Padre
                                      null,                            -- Cod.Tasa
                                      null,                            -- Val.Tasa
                                      'Desafectación Enc.Legal',       -- Concepto
                                      'N',                             -- Emit.Aviso
                                      v_secuencia,
                                      v_fec_proceso
                                    );

            if pag_cta.fu_obt_cod_error <> 0 then
               raise_application_error(-20001, pag_cta.fu_obt_msj_error);
            end if;
         end if;

         pag_cta.PR_OBT_CUENTA(cta.nro_cuenta);

         /*Enviar un MT999 Set Account Limit por el mismo Importe que viene en el MT986 (Campo D)*/
         -- Cabecera y Nro. Referencia
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                            'CAB',
                                            '{1:F01'||rpad(pas_snp.g_usu_xadapter,12,'X')||'}'||
                                            '{2:I999'||rpad('BCPAPYPR',12,'X')||'N}'||
                                            '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20', v_nro_ref_encaje);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/SETACCOUNTLIMIT/SPMANDAT');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/STATUS/');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/ACTION/');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/ACCOUNT/'||cta.nro_cta_bancaria);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/AMOUNT/'||pas_snp.fu_obt_mto_formato(abs(pag_cta.FU_SAL_DISPONIBLE), null));
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '-}');

         -- Obtengo el mensaje envio
         v_lugar := 'Procesando y Enviando '||v_cod_mensaje||', ';
         pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);
         pas_snp.pr_gen_arc_swi_lote(v_mensaje);
         --pas_snp.pr_gen_arc_swi_lote(v_mensaje,v_nro_ref_encaje,pas_snp.g_fec_actual,999);

         v_lugar := 'Grabando el mensaje Enviado en GE_SNP_MENSAJES, ';
         INSERT INTO ge_snp_mensajes
            (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
             msj_swift, cod_moneda, monto, error)
         VALUES
            (v_nro_ref_encaje, null, 999, pas_snp.g_fec_actual,
             v_mensaje, cta.cod_moneda, abs(pag_cta.FU_SAL_DISPONIBLE), null);
      end if;
   end loop;

exception
   when others then
      raise_application_error(-20001, v_lugar||sqlerrm);

end PRS_SNP_GEN_ENC_ESPECIAL;
/


create or replace procedure IT.PRS_SNP_GEN_MT999( p_nro_cuenta sb_encajes_esp.nro_cuenta%type,
                                          p_monto in sb_encajes_esp.importe%type,
                                          p_cod_moneda in sb_encajes_esp.cod_moneda%type,
                                          p_nro_referencia out ge_snp_mensajes.nro_referencia%type) is

   v_mensaje                  varchar2(4000);
   v_lugar                    varchar2(200);
   v_cod_mensaje              varchar2(50) := 'MTn99/SETACCOUNTLIMIT';
   v_nro_ref_encaje           varchar2(100);
   v_situacion                ge_snp_mensajes.situacion%type := 'P';
begin
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
        --Inicializo variables

         v_nro_ref_encaje        := null;


         if v_nro_ref_encaje is null then
               v_nro_ref_encaje := pas_snp.fu_obt_sig_nro_referencia;
         end if;


         /*Enviar un MT999 Set Account Limit por el mismo Importe que viene en el MT986 (Campo D)*/
         -- Cabecera y Nro. Referencia
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje,
                                            'CAB',
                                            '{1:F01'||rpad(pas_snp.g_usu_xadapter,12,'X')||'}'||
                                            '{2:I999'||rpad(fue_obt_des_refcodes('SNP_BIC_SISTEMA', fug_es_produccion),12,'X')||'N}'|| 
                                            '{3:{113'||':'||lpad('20',4,'0')||'}}{4:');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20', v_nro_ref_encaje);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/SETACCOUNTLIMIT/MANDATORY');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/STATUS/');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/ACTION/');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/ACCOUNT/'||p_nro_cuenta);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/AMOUNT/'||trim(to_char(p_monto, '999999999999990D' ||
         rpad('9', nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
         p_cod_moneda => 'USD'), 2), '9'))), null);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '-}');

         -- Obtengo el mensaje envio
         v_lugar := 'Procesando y Enviando '||v_cod_mensaje||', ';
         pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);


         v_lugar := 'Grabando el mensaje Enviado en GE_SNP_MENSAJES, ';
         INSERT INTO ge_snp_mensajes
            (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor,
             msj_swift, cod_moneda, monto, error, situacion)
         VALUES
            (v_nro_ref_encaje, null, 999, pas_snp.g_fec_actual,
             v_mensaje, p_cod_moneda , abs(p_monto), null, v_situacion);

         p_nro_referencia := v_nro_ref_encaje;




exception
   when others then
      raise_application_error(-20001, v_lugar||sqlerrm);

end PRS_SNP_GEN_MT999;
/

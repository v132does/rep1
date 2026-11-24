CREATE OR REPLACE PROCEDURE IT.PRG_PRO_ACR_SET(p_fecha date, p_men_error out varchar2) is
  /*  Procesa la acreditación a la SET, en base al archivo depositado por Bancard.
  */
  ---
  v_fec_actual   date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_cod_oficina  number(4) := fug_obt_ofi_matriz;
  v_nro_secuencia number(4);
  v_hora         varchar2(8);
  v_mto_credito  ge_movimientos.monto%type;
  v_nro_proceso ge_inf_cob_batch.nro_proceso%type;
  v_cod_error varchar2(3) := '000';
  v_cod_mod_clearing ba_modulos.cod_modulo%type;
  v_cod_mad_clearing ge_modalidades.cod_modalidad%type;
  v_cod_mod_destino ba_modulos.cod_modulo%type;
  v_cod_mad_destino ge_modalidades.cod_modalidad%type;
  v_cod_moneda ba_monedas.cod_moneda%type;
  v_cod_mon_archivo ba_monedas.cod_moneda%type;
  v_exi_cta_bancard varchar2(1);

  procedure lp_ins_cre_ope_set is
    CURSOR c_mov_batch IS
      SELECT i.fecha, i.hora, i.nro_ord_transferencia, i.nro_cta_clearing, i.nro_cta_destino, i.monto, i.cod_moneda,
             i.cod_ban_clearing, i.cod_ban_destino
        FROM GE_CON_CRE_OPE_SET_TMP i
       WHERE fec_archivo = p_fecha;
    v_nro_cta_clearing ge_cuentas.nro_cuenta%type;
  Begin
     begin
       select s_nro_pro_set.nextval
         into v_nro_proceso
         from dual;
     exception
       when others then
         v_cod_error := '001';
         p_men_error := v_cod_error||'-No se pudo obtener el número de secuencia.';
     end;

     if nvl(v_cod_error,'000') = '000' then
       begin
         insert into GE_CON_CRE_OPE_SET (nro_proceso,fecha, fec_archivo, estado)
          values (v_nro_proceso, v_fec_actual, p_fecha, 'I');
       exception
         when others then
           v_cod_error := '002';
           p_men_error :=  substr(v_cod_error||'-No se pudo realizar la inserción de la cabecera - GE_INF_COB_BATCH. '||sqlerrm, 1,1000);
       end;
    end if;

    if nvl(v_cod_error,'000') = '000' then
       for i in c_mov_batch loop
         if trunc(i.fecha) <> trunc(p_fecha) and nvl(v_cod_error,'000') = '000' then
            v_cod_error := '003';
            p_men_error := v_cod_error||'-La fecha del archivo no corresponde con la fecha del detalle.';
         end if;


         if i.cod_ban_clearing <> fug_obt_cod_banco and nvl(v_cod_error,'000') = '000' then
           v_cod_error := '004';
           p_men_error := v_cod_error ||'-El código de Banco no corresponde a la cuenta.';
         end if;

         if i.cod_ban_destino <> fug_obt_cod_banco and nvl(v_cod_error,'000') = '000' then
           v_cod_error := '005';
           p_men_error := v_cod_error ||'-El código de Banco no corresponde a la cuenta.';
         end if;

         if i.monto <= 0 and nvl(v_cod_error,'000') = '000' then
           v_cod_error := '006';
           p_men_error := v_cod_error ||'-El monto de la operación debe ser mayor a 0.';
         end if;

         if nvl(v_cod_error,'000') = '000' then
          -- v_nro_cta_clearing := fug_con_cta_infonet(i.nro_cta_clearing);
           v_nro_cta_clearing := i.nro_cta_clearing;
           begin
             select cod_modulo, cod_modalidad, cod_moneda
               into v_cod_mod_clearing, v_cod_mad_clearing, v_cod_moneda
               from ge_cuentas
              where nro_cuenta = i.nro_cta_clearing;
           exception
             when others then
               v_cod_error := '007';
               p_men_error := substr(v_cod_error||'-Error al buscar la cuenta clearing. '||sqlerrm,1,1000);
           end;
         end if;

         if nvl(v_cod_error,'000') = '000' then
           begin
             SELECT m.moneda
               INTO v_cod_mon_archivo
               FROM BW_NOT_ISO_CODIGOS m
              WHERE m.cod_iso = i.cod_moneda
                and rownum=1;
           exception
             when others then
               v_cod_mon_archivo := 'GS';
           END;

           if v_cod_moneda <> v_cod_mon_archivo then
            v_cod_error := '008';
            p_men_error := v_cod_error ||'-La moneda de la cuenta no coincide con la moneda del archivo.';
           end if;
         end if;

         if nvl(v_cod_error,'000') = '000' then
           begin
             select cod_modulo, cod_modalidad, cod_moneda
             into v_cod_mod_destino, v_cod_mad_destino, v_cod_moneda
             from ge_cuentas
            where nro_cuenta = i.nro_cta_destino;
           exception
             when others then
              v_cod_error := '009';
              p_men_error := substr(v_cod_error||'-Error al buscar la cuenta. '||sqlerrm,1,1000);
           end;

           if v_cod_moneda <> v_cod_mon_archivo then
            v_cod_error := '010';
            p_men_error := v_cod_error ||'-La moneda de la cuenta no coincide con la moneda del archivo.';
           end if;
         end if;

         if nvl(v_cod_error,'000') = '000' then
           begin
            select distinct 'S'
              into v_exi_cta_bancard
              from ba_cod_referencias r
             where r.dominio = 'NRO_CTA_REL_SET_BANCARD'
               and r.val_minimo = i.nro_cta_destino;
           exception
             when others then
               v_exi_cta_bancard := 'N';
           end;

           if nvl(v_exi_cta_bancard, 'N') = 'N' then
             v_cod_error := '011';
             p_men_error :=  v_cod_error||'-No se encuentra la cuenta de relación SET-BANCARD. '||i.nro_cta_destino;
           end if;
         end if;


         if nvl(v_cod_error,'000') = '000' then
           begin
             insert into GE_CON_CRE_OPE_SET_DET (nro_proceso, fecha, hora, nro_ord_transferencia, nro_cta_clearing, nro_cta_destino, monto, cod_moneda,
                                                 cod_ban_clearing, cod_ban_destino, cod_mod_cta_clearing, cod_mad_cta_clearing,
                                                 cod_mod_cta_destino, cod_mad_cta_destino )
                                         values (v_nro_proceso, i.fecha, i.hora, i.nro_ord_transferencia, v_nro_cta_clearing, i.nro_cta_destino, i.monto, v_cod_moneda,
                                                 i.cod_ban_clearing, i.cod_ban_destino, v_cod_mod_clearing, v_cod_mad_clearing,
                                                 v_cod_mod_destino, v_cod_mad_destino);
             exception
               when others then
                 v_cod_error := '012';
                 p_men_error :=  substr(v_cod_error||'-No se pudo realizar la inserción de la cabecera - GE_INF_COB_BATCH_DET. '||sqlerrm, 1,1000);
           end;
        End If;
      end loop;
    end if;
  Exception
    WHEN NO_DATA_FOUND THEN
      v_cod_error := '013';
      P_men_error := substr(v_cod_error||'-No se pudo insertar en las tablas definitivas. '||sqlerrm,1,1000);
  end;


   --PROCESO DE ACREDITACIÓN DE LAS OPERACIONES EN FECHA DEL ARCHIVO, DEBITO CUENTA TRANSITORIA
   PROCEDURE lp_acr_batch IS
    CURSOR c_mov_pendientes IS
      select i.fecha, i.hora, i.nro_ord_transferencia, i.nro_cta_clearing, i.nro_cta_destino, i.monto, i.cod_moneda,
             i.cod_ban_clearing, i.cod_ban_destino, i.cod_mod_cta_clearing, i.cod_mad_cta_clearing, i.cod_mod_cta_destino,
             i.cod_mad_cta_destino
        FROM GE_CON_CRE_OPE_SET c, GE_CON_CRE_OPE_SET_DET i
       WHERE c.fec_archivo = p_fecha
         and c.nro_proceso = i.nro_proceso
         and c.estado <> 'F'
         and monto > 0;

     v_cod_tra_padre  number(3) := 384;  -- CANOSTDD-2 -- 01/2017 --
     v_cod_tra_credito NUMBER(03) := 602;
     v_cod_tra_debito NUMBER(03) := 503;
     v_lugar varchar2(200);
     v_nvo_estado varchar2(1);
     v_sal_disponible number(18,2);
     v_procesa varchar2(1) := 'S';

   BEGIN
     v_nro_secuencia := 0;
     v_mto_credito := 0;
     v_hora := to_char(sysdate,'HH24:MI:SS');
     v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
     --Movimientos por el rubro contable provisorio, comisión de bancard
     --CAPITAL
     FOR CC IN c_mov_pendientes LOOP
        v_lugar := 'Procesando.... Debito a: '||cc.nro_cta_clearing||
                   ' Credito a: '||cc.nro_cta_destino;

        --DEBITO
        if v_procesa = 'S' and nvl(v_cod_error,'000') = '000' then
           pag_cta.PR_VER_OPERACION(cc.nro_cta_clearing,v_cod_tra_padre,9,91,'D',
                                    v_cod_moneda,cc.monto,v_cod_oficina,
                                    cc.cod_mod_cta_clearing, cc.cod_mad_cta_clearing, v_nvo_estado,
                                    v_sal_disponible,v_procesa,v_cod_tra_debito);

           if v_procesa = 'N' then
              v_cod_error := '014';
              p_men_error     := substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error||'. Disponible '||v_sal_disponible, 1, 1000);
           end if;
        END IF;
        if nvl(v_cod_error,'000') = '000' then
          /* se puede realizar transferencia */
          -- calculo el numero de documento -----------------------------
          if v_nro_secuencia > 990 then
             v_nro_secuencia := -999;
          elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
             v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
             v_nro_secuencia := 0;
          end if;

          -- debito a la cuenta de debito
          pag_cta.PR_SET_NRO_DOCUMENTO3(cc.nro_ord_transferencia);
          pag_cta.pr_act_operacion(cc.nro_cta_clearing,
                                   v_hora,
                                   'D',
                                   v_cod_moneda,
                                   cc.monto,
                                   v_cod_tra_padre,
                                   v_cod_tra_debito,
                                   cc.nro_ord_transferencia,
                                   null,
                                   v_cod_oficina,
                                   9,
                                   91,
                                   null,
                                   null,
                                   'Débito por Pago de Serv. SET - Infonet. Nro OT: '||cc.nro_ord_transferencia,
                                   'N',
                                   v_nro_secuencia,
                                   v_fec_actual);
          if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            v_cod_error := '015';
            p_men_error     := substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
          end if;
        end if;
        if nvl(v_cod_error,'000') = '000' then
          if v_nro_secuencia > 990 then
             v_nro_secuencia := -999;
          elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
             v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
             v_nro_secuencia := 0;
          end if;
          --- debe hacer el credito a la secuencia indicada para corte

          begin
            pag_cta.PR_VER_OPERACION(cc.nro_cta_destino,v_cod_tra_padre,9,91,'C',
                                     v_cod_moneda,cc.monto,v_cod_oficina,
                                     cc.cod_mod_cta_destino, cc.cod_mad_cta_destino, v_nvo_estado,
                                     v_sal_disponible,v_procesa,v_cod_tra_credito);

            if v_procesa = 'N' then
               v_cod_error := '016';
               p_men_error     := substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
            end if;
            if nvl(v_cod_error,'000') = '000' then
               -- se hace el credito
               v_nro_secuencia := v_nro_secuencia + 1;

               pag_cta.PR_SET_NRO_DOCUMENTO3(cc.nro_ord_transferencia);
               pag_cta.pr_act_operacion(cc.nro_cta_destino,
                                        v_hora,
                                        'C',
                                        v_cod_moneda,
                                        cc.monto,
                                        v_cod_tra_padre,
                                        v_cod_tra_credito,
                                        cc.nro_ord_transferencia,
                                        null,
                                        v_cod_oficina,
                                        9,
                                        91,
                                        null,
                                        null,
                                        'Crédito por Pago de Serv. SET - Infonet. Nro OT: '||cc.nro_ord_transferencia,
                                        'N',
                                        v_nro_secuencia,
                                        v_fec_actual);
                if pag_cta.g_cod_error <> 0 then
                  -- actualizacion con problemas
                  v_cod_error := '017';
                  p_men_error := substr(v_cod_error ||'-'||ltrim(to_char(pag_cta.g_cod_error,'000'))||'-'||pag_cta.g_msj_error, 1, 1000);
                end if;
              end if;
            exception
              when others then
                 v_cod_error := '018';
                p_men_error := substr(v_cod_error ||'-'||'No se ha podido realizar el movimiento de crédito. '||sqlerrm, 1, 1000);
            end;
        end if;



      END LOOP;
      if nvl(v_cod_error,'000') = '000' then
        begin
          update GE_CON_CRE_OPE_SET
             set estado = 'F'
           where nro_proceso = v_nro_proceso;
       exception
         when others then
           v_cod_error := '019';
           p_men_error := substr(v_cod_error ||'-'||'No se puede actualizar el estado del Proceso. '||sqlerrm,1,1000);
       end;
     end if;
   end;
begin
  -- Acreditaciones en lotes durante el cierre
  prg_pro_inf_cobranzas('S');
  --debe comitear el proceso para las operaciones de acreditaciones
  commit;
  -- Inserción en tabla definitiva
  lp_ins_cre_ope_set;
  --Acreditación en batch
  if nvl(v_cod_error,'000') = '000' then
     lp_acr_batch;
  end if;

  if nvl(v_cod_error,'000') <> '000' then
    PRG_INS_LOG_ERRORES('PRG_PRO_ACR_SET',p_men_error, 'FEC_PROCESO', TO_CHAR(v_fec_actual,'dd/mm/yyyy'), 'FEC_ARCHIVO', TO_CHAR(p_fecha,'dd/mm/yyyy') );
  end if;
end;
/


CREATE OR REPLACE PROCEDURE IT.PRG_TRA_HIS_DUPLICADO IS
   v_fecha ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(1);
   v_can_duplicados number;
   vg_hora          varchar2(8);
   vg_cod_usuario   ba_usuarios.cod_usuario%type;
   v_observacion    ge_log_procesos.observacion%type;
   v_hor_ini        varchar2(8);
   v_hor_fin        varchar2(8);

   --ITGF - Incidencia en Traspaso de Movimientos al Histórico - SC 18445 
   
   --Procedimiento de registros de logs - CIE-380
   PROCEDURE lp_ins_log(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2, p_observacion varchar2)
     is pragma autonomous_transaction;
      begin
        insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin,observacion)
        values(v_fecha,'PRG_TRA_HIS_DUPLICADO',p_cod_proceso, p_hor_ini, p_hor_fin,p_observacion);
        commit;
      exception
        when others then null;
      end;
      
  --Procedimiento para eliminar movimientos_tmp procesados - CIE-380
   PROCEDURE lp_eli_ge_movimientos IS 
     BEGIN 
       delete ge_movimientos_tmp
           where tab_referencia = 'GE_MOVIMIENTOS'
             and procesado = 'S'; 
     END; 
    
   PROCEDURE lp_tra_env_email IS
    -- v_para       VARCHAR2(4000);
     -- Variables para mail
   --  v_asunto     VARCHAR2(2000);
   --  v_texto LONG;
   --  v_hin_mail ge_ra_log_mail.hor_inicio%type;
   --  v_hfi_mail ge_ra_log_mail.hor_fin%type;
   --  v_det_error ge_ra_log_mail.det_error%type;
     cursor c_tab_duplicado is
       select tab_referencia, cod_usuario, procesado, count(*) cantidad
         from ge_movimientos_tmp
        group by tab_referencia, cod_usuario, procesado
        order by 1;
   BEGIN
     v_hor_ini := to_char(sysdate,'hh24:mm:ss');
     for c in c_tab_duplicado loop

        /* v_asunto   := 'Error en Proceso de Cierre (11-369-prg_tra_his_duplicado): Insercion en Historico '||c.tab_referencia||' del '||to_char(v_fecha, 'DD/MM/YYYY');

         v_texto := 'Error al insertar Movimientos Historicos durante el cierre por duplicación de PK, en la fecha '||to_char(v_fecha, 'DD/MM/YYYY')||', de la tabla '||c.tab_referencia||'. Cant. Registros duplicados: '|| c.cantidad||
                    '. Verifique tabla GE_MOVIMIENTOS_TMP para ver movimientos duplicados.';

        BEGIN*/
           v_hor_fin := to_char(sysdate,'hh24:mm:ss');
           IF c.tab_referencia = 'GE_MOVIMIENTOS' and c.procesado = 'S' THEN -- CIE-380 
             v_observacion := 'Movimientos con duplicación de PK, actualizados a la '||to_char(v_fecha, 'DD/MM/YYYY')||', de la tabla '||c.tab_referencia||'. Cant. Registros: '||c.cantidad||' - '||'Usuario: '||c.cod_usuario||'.';
             lp_ins_log('PRG_TRA_HIS_DUPLICADO',v_hor_ini,v_hor_fin,v_observacion);
           ELSE
             v_observacion := 'Movimientos con duplicación de PK, en la tabla '||c.tab_referencia||' del '||to_char(v_fecha, 'DD/MM/YYYY');
             lp_ins_log('PRG_TRA_HIS_DUPLICADO',v_hor_ini,v_hor_fin,v_observacion);
           END IF;
             
          --CIE-380 Se comenta porque actualmente no se está utilizando IT_MAIL
         /*  v_hin_mail := to_char(sysdate, 'hh24:mi:ss');

             v_para := fug_obt_pardinamico('ENV_EMA_GUA_CIERRE');

             it_mail.mail(fug_obt_dir_correo,
                          v_para,
                          v_asunto,
                          v_texto);

             v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');

         EXCEPTION
            when others then
               v_det_error := substr(sqlerrm, 1, 4000);
               INSERT INTO ge_ra_log_mail (fec_envio,
                                           nom_archivo,
                                           dir_correo,
                                           mensaje,
                                           det_error,
                                           hor_inicio,
                                           hor_fin)
                                   VALUES (SYSDATE,
                                           null,
                                           v_para,
                                           v_asunto,
                                           v_det_error,
                                           v_hin_mail,
                                           v_hfi_mail);
        END;*/
     END LOOP;
   END lp_tra_env_email;      
         
   PROCEDURE lp_tra_ge_movimientos IS
   BEGIN
     BEGIN
      INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'GE_MOVIMIENTOS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND exists (select hora, cod_usuario, nro_secuencia, count(*) from ge_movimientos
                         where hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario
                         group by hora, cod_usuario, nro_secuencia
                         having count(*) > 1)
             AND m.fecha !=  v_fecha -- DYDMR-17534 evitamos desarmar movimiento bien insertado
             union all
             SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'GE_MOVIMIENTOS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND not exists (select hora, cod_usuario, nro_secuencia, count(*) from ge_movimientos
                         where hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario
                         group by hora, cod_usuario, nro_secuencia
                         having count(*) > 1)
             AND m.fecha !=  v_fecha --CIE-380 movimientos con fecha diferentes
             );
     EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_ge_movimientos.'||sqlerrm);

     END;
   END;

   PROCEDURE lp_tra_ge_movimientos_his IS
   BEGIN
     BEGIN
      INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'GE_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND ((cod_modulo = 1 AND cod_mod_padre = 1) OR (cod_modulo = 2 AND cod_mod_padre in (1,2,9)))
            AND exists (select 1 from ge_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_ge_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_ah_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'AH_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 3 OR (cod_modulo = 9 AND cod_mod_padre = 3))
            AND exists (select 1 from ah_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_ah_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_cc_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'CC_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 4 OR (cod_modulo = 9 AND cod_mod_padre = 4))
            AND exists (select 1 from cc_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_cc_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_ta_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'TA_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 5 OR (cod_modulo = 9 AND cod_mod_padre = 5))
            AND exists (select 1 from ta_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_ta_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_pr_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'PR_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 6 OR (cod_modulo = 9 AND cod_mod_padre = 6))
            AND exists (select 1 from pr_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_pr_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_lc_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion,  'LC_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 7 OR (cod_modulo = 9 AND cod_mod_padre = 7))
            AND exists (select 1 from lc_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_lc_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_cx_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'CX_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 8 OR (cod_modulo = 9 AND cod_mod_padre = 8))
            AND exists (select 1 from cx_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_cx_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_md_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'MD_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 10 OR (cod_modulo = 9 AND cod_mod_padre = 10))
            AND exists (select 1 from md_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_md_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_af_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'AF_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 13 OR (cod_modulo = 9 AND cod_mod_padre = 13))
            AND exists (select 1 from af_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_af_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_rh_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'RH_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 14 OR (cod_modulo = 9 AND cod_mod_padre = 14))
            AND exists (select 1 from rh_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_rh_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_ov_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'OV_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (nvl(cod_modulo, 15) IN (15, 16, 28) OR
                (cod_modulo = 9 AND cod_mod_padre IN (15, 16, 9, 28)))
            AND exists (select 1 from ov_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_ov_movimientos_his.'||sqlerrm);
     END;
   END;

   PROCEDURE lp_tra_bu_movimientos_his IS
   BEGIN
     BEGIN
        INSERT INTO GE_MOVIMIENTOS_TMP
        (SELECT v_fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                cod_retencion, fec_fin_retencion, est_cuenta, estado,
                cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                nro_documento4, protegido,cod_autorizacion,cod_usu_autorizador,
                usu_insercion, fec_insercion, usu_modificacion, fec_modificacion,
                tip_mov_rubro, cod_tip_ope_cambio,referencia, cod_persona, cod_sit_contable,
                nro_conciliacion, 'BU_MOVIMIENTOS_HIS' tab_referencia, null procesado
           FROM ge_movimientos m
          WHERE (cod_transaccion > 0 OR cod_rubro IS NOT NULL)
            AND (cod_modulo = 26 OR (cod_modulo = 9 AND cod_mod_padre = 26))
            AND exists (select 1 from bu_movimientos_his
                         where fecha = v_fecha
                           and hora = m.hora
                           and nro_secuencia = m.nro_secuencia
                           and cod_usuario = m.cod_usuario));
     EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR al insertar los movimientos duplicados en lp_tra_bu_movimientos_his.'||sqlerrm);
     END;
   END;

   --DYDMR-17534 Obtiene siguiente hora disponible, si no encuentra devuelve la misma
   FUNCTION lf_obt_hor_disponible (p_fecha       in date,
                                   p_hora        in varchar2,
                                   p_cod_usuario in varchar2 ) return varchar2 is
      v_existe varchar2(1);
      v_hora   varchar2(8);
      v_can_bus_hora number := 0;
      v_hor_agotada varchar2(1) := 'N';
   BEGIN
      if vg_cod_usuario is null or vg_cod_usuario != p_cod_usuario then
         vg_cod_usuario := p_cod_usuario;
         vg_hora := p_hora;
      end if;
      --si el movimiento es del mismo usuario, busca apartir de la ultima hora libre encontrada
      v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(vg_hora);
      loop
        v_can_bus_hora := nvl(v_can_bus_hora,0) + 1;
        begin
          select 'S'
            into v_existe
            from ge_movimientos
           where fecha = p_fecha
             and hora = v_hora
             and cod_usuario = p_cod_usuario
             and rownum <= 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;
        if v_can_bus_hora >= 86400 then
           v_hor_agotada := 'S';
        end if;
        exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      end loop;
      if v_existe = 'N' then
         vg_hora := v_hora;
         return v_hora;
      else
         return p_hora;
      end if;
   END;
   -- DYDMR-17534 Corrige hora de registros de ge_movimientos insertados con fecha siguiente
   PROCEDURE lp_act_hor_movimientos IS
     v_hora varchar2(8);
     cursor c_mov_tmp is select * from GE_MOVIMIENTOS_TMP where tab_referencia = 'GE_MOVIMIENTOS' order by cod_usuario, hora, nro_secuencia;
   BEGIN
     vg_hora := null;
     vg_cod_usuario := null;
     for c in c_mov_tmp loop
       BEGIN        
         v_hora := lf_obt_hor_disponible(v_fecha, c.hora, c.cod_usuario);
         if v_hora != c.hora then
             -- actualizamos hora del registro con error de PK
             update ge_movimientos
               set hora = v_hora,
                   fecha = v_fecha
             where fecha != v_fecha
               and hora = c.hora
               and nro_secuencia = c.nro_secuencia
               and cod_usuario = c.cod_usuario
               and monto = c.monto
               and fec_insercion = c.fec_insercion;
             --actualización de procesados en la tabla temporal
             update ge_movimientos_tmp a  
                set a.procesado = 'S'
             where a.hora = c.hora
               and a.nro_secuencia = c.nro_secuencia
               and a.cod_usuario = c.cod_usuario
               and a.tab_referencia = 'GE_MOVIMIENTOS'
               and a.monto = c.monto
               and a.fec_insercion = c.fec_insercion;    
         end if;
       EXCEPTION
          WHEN OTHERS THEN
            --en caso de error se continua para no interrumpir proceso del cierre
            null;
       END;
     end loop;
   END;

BEGIN
   BEGIN
     delete from ge_movimientos_tmp;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000, 'No se ha podido eliminar los movimientos de la tabla temporal.'||sqlerrm);
   END;
   lp_tra_ge_movimientos;
   lp_tra_ge_movimientos_his;
   lp_tra_ah_movimientos_his;
   lp_tra_cc_movimientos_his;
   lp_tra_ta_movimientos_his;
   lp_tra_pr_movimientos_his;
   lp_tra_lc_movimientos_his;
   lp_tra_cx_movimientos_his;
   lp_tra_md_movimientos_his;
   lp_tra_af_movimientos_his;
   lp_tra_rh_movimientos_his;
   lp_tra_ov_movimientos_his;
   lp_tra_bu_movimientos_his;
   lp_act_hor_movimientos;

   begin
     select count(*)
       into v_can_duplicados
       from ge_movimientos_tmp;
   exception
     when others then
       v_can_duplicados := 0;
   end;

   if nvl(v_can_duplicados, 0) > 0 then
      lp_tra_env_email;
   end if; 
     
   lp_eli_ge_movimientos;
   
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'Error en (prg_tra_his_duplicado). ' || SQLERRM);
      END IF;
END;
/

CREATE OR REPLACE PROCEDURE IT.prt_ins_pad_diario(p_online IN VARCHAR2 DEFAULT 'N') IS
  v_lugar           VARCHAR2(50);
  v_fecha           DATE := trunc(sysdate);
  v_ent_global      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_ENT_GLOBAL');
  r_log             ta_logs_gp%ROWTYPE;
  v_cierre          VARCHAR2(1);
  v_fec_cierre      ta_cal_cierres.fec_cierre%TYPE;
  v_url_ws          ge_par_dinamicos.val_parametro%type:= fug_obt_pardinamico('WS_SAL_TAR_CRE_GLO');
  v_url             ge_par_dinamicos.val_parametro%TYPE;
  v_men_error       varchar2(4000);
  v_cod_err_ws      number(6) := 0;
  v_cod_msg_exito   ge_par_dinamicos.val_parametro%TYPE:= fug_obt_pardinamico('COD_MSG_EXITO');
  v_sal_financiado  ta_cta_tarjetas.sal_financiado%TYPE;
  v_content         varchar2(4000);
  v_cod_error       NUMBER;
  v_nro_tarjeta     ta_tarjetas.nro_tarjeta%TYPE;

  CURSOR c_ta_pad_diario_tmp IS
    SELECT tip_registro,
           cod_marca,
           cod_entidad,
           cod_sucursal,
           nro_cuenta,
           cod_producto,
           apellido,
           nombre,
           tip_documento,
           nro_documento,
           trunc(dis_compra) dis_compra,
           signo1,
           trunc(dis_adelanto) dis_adelanto,
           signo2,
           dis_com_usd,
           signo3,
           dis_ade_usd,
           signo4,
           trunc(tra_pen_gs) tra_pen_gs,
           signo5,
           tra_pen_usd,
           signo6,
           est_cuenta,
           trunc(sal_ant_gs) sal_ant_gs,
           signo7,
           sal_ant_usd,
           signo8,
           trunc(sal_act_gs) sal_act_gs,
           signo9,
           sal_act_usd,
           signo10,
           TRIM(filler) filler
      FROM it.ta_pad_diario_tmp a
     WHERE a.cod_producto = fue_obt_val_max_referencia('GLP_TIP_PRODUCTOS','GP_CRE_COMBO2');
      
  CURSOR c_ta_pad_diario IS 
    SELECT tip_registro,
           cod_marca,
           cod_entidad,
           cod_sucursal,
           nro_cuenta,
           cod_producto,
           apellido,
           nombre,
           tip_documento,
           nro_documento,
           dis_compra,
           signo1,
           dis_adelanto,
           signo2,
           dis_com_usd,
           signo3,
           dis_ade_usd,
           signo4,
           tra_pen_gs,
           signo5,
           tra_pen_usd,
           signo6,
           est_cuenta,
           sal_ant_gs,
           signo7,
           sal_ant_usd,
           signo8,
           decode(signo9, '+', sal_act_gs, '-', (sal_act_gs * -1))sal_act_gs,
           signo9,
           sal_act_usd,
           signo10,
           filler
      FROM ta_pad_diario ta
     WHERE ta.fec_proceso = v_fecha
       AND ta.cod_producto = fue_obt_val_max_referencia('GLP_TIP_PRODUCTOS','GP_CRE_COMBO2');
     
  CURSOR c_sal_diario IS
    SELECT cta.nro_cuenta, gc.cod_persona
      FROM ta_cta_tarjetas cta, ta_tipos tip, ge_cta_clientes gc
     WHERE cta.afinidad = tip.afinidad
       AND cta.nro_cuenta = gc.nro_cuenta
       AND gc.relacion = 'P'
       AND cta.estado <> 'C'
       AND tip.cod_ent_procesadora = v_ent_global;
     
  CURSOR c_ext_cierre IS 
    SELECT tc.nro_cuenta, 
           tc.cod_modalidad, 
           tc.tip_cierre, 
           ext.fec_cierre, 
           nvl(trunc(ext.sal_financiado),0) sal_financiado, 
           nvl(trunc(ext.sal_facturado),0) sal_facturado, 
           nvl(tc.sal_facturar,0) sal_facturar, 
           nvl(tc.lin_cuotas,0) lin_cuotas, 
           nvl(trunc(ext.linea_credito),0) linea_credito, 
           nvl(trunc(ext.pago_minimo),0) pago_minimo, 
           ext.fec_vencimiento, 
           nvl(trunc(ext.sal_cuo_pendientes),0) sal_cuo_pendientes, 
           ext.dia_mora, 
           nvl(tc.lin_especial,0) lin_especial
      FROM ta_cta_tarjetas tc, ta_ext_cierre_tmp_gp ext
     WHERE tc.nro_cuenta = ext.nro_cuenta
       AND ext.fec_cierre = v_fec_cierre;
  

PROCEDURE lp_par_jason(p_dato           IN VARCHAR2,
                       p_cod_persona    IN VARCHAR2,
                       p_nro_cuenta     IN VARCHAR2,
                       p_sal_financiado OUT NUMBER,
                       p_error          OUT NUMBER) IS
v_sql   VARCHAR2(10000);
v_lugar VARCHAR2(100);
v_error EXCEPTION;
v_men_error    VARCHAR2(4000);
v_nom_programa VARCHAR2(50) := 'PAT_TGL.PR_PAR_JSON';

PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN 
  BEGIN
    /*Se carga la tabla temporal ah_json_tmp*/
    v_lugar := 'Inserta ah_json_tmp';
    v_sql   := 'INSERT INTO ah_json_tmp(dato, cod_persona, nro_cta) VALUES(' || '''' ||
                p_dato || '''' || ',' || '''' || p_cod_persona || '''' || ',' || '''' ||
                p_nro_cuenta || '''' || ');';
    v_lugar := 'Inserta ah_json_tmp 2';
    EXECUTE IMMEDIATE 'begin ' || v_sql || 'end;';
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      v_men_error := substr('Error al cargar la tabla ah_json_tmp: ' ||
                             p_dato || ' # ' || sqlerrm,
                             1,
                             4000);
      RAISE v_error;
  END;
  
  BEGIN
    v_lugar := 'Parseo Json';
    /*Parseamos los campos y obtenemos los datos*/
    SELECT trunc(a.creditLineUsed)
      INTO p_sal_financiado
      FROM ah_json_tmp j,
           json_table(dato
                      columns(creditLineUsed NUMBER(20,2) path '$.creditLineUsed')) as a
     WHERE j.nro_cta = p_nro_cuenta;
  EXCEPTION
    WHEN no_data_found THEN
      v_men_error := 'Sin registro en tabla AH_JSON_TMP. Json -> : ' ||
                      p_dato;
      RAISE v_error;
    WHEN too_many_rows THEN
      v_men_error := 'Demasiados registros recuperados en tabla AH_JSON_TMP. Json -> : ' ||
                      p_dato;
      RAISE v_error;
    WHEN OTHERS THEN
      p_error := 999;
      r_log.comentario := substr('Lugar: ' || v_lugar || ' ' ||
                                   v_men_error||' '||'cuenta: '||p_nro_cuenta,
                                   1,
                                   4000);
      pat_igp.PR_INS_LOG(r_log);
      v_men_error := substr('Error al obtener datos de json:' || p_dato ||
                            ' # ' || SQLERRM,
                            1,
                            4000);
      RAISE v_error;
    END; 
    
    BEGIN
      v_lugar:= 'Delete ah_json_tmp';
      DELETE ah_json_tmp j
       WHERE j.nro_cta = p_nro_cuenta;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
      v_men_error := substr('Error al cargar la tabla ah_json_tmp: ' ||
                             p_dato || ' # ' || sqlerrm,
                             1,
                             4000);
      RAISE v_error; 
    END;
  EXCEPTION
    WHEN v_error THEN
      p_error := 999;
      r_log.comentario := substr('Lugar: ' || v_lugar || ' ' ||
                                   v_men_error||' '||'cuenta: '||p_nro_cuenta,
                                   1,
                                   4000);
      pat_igp.PR_INS_LOG(r_log);
    WHEN OTHERS THEN
      p_error := 999;
      r_log.comentario := substr('Lugar: ' || v_lugar || ' ' ||
                                   v_men_error||' '||'cuenta: '||p_nro_cuenta,
                                   1,
                                   4000);
      pat_igp.PR_INS_LOG(r_log);

END;
  
  BEGIN
  /*Setear valores-llamar procedimiento de ta_logs de inicio de proceso*/
  IT.PRE_INI_APLICACION;
  pae_cnf.g_cod_modulo := 1;
  r_log.nom_proceso    := 'PRT_INS_PAD_DIARIO';
  r_log.fec_hor_ini    := SYSDATE;
  r_log.comentario     := '*** Inicio proceso de insercion Padron diario disponible ***';
  pat_igp.pr_ins_log(r_log, FALSE);

  FOR i IN c_ta_pad_diario_tmp LOOP 
      BEGIN
        v_lugar := 'update it.ta_pad_diario ' || i.nro_cuenta || ' ' || i.nro_documento; 
        UPDATE ta_pad_diario
            SET tip_registro    = i.tip_registro,
              cod_marca         = i.cod_marca,
              cod_entidad       = i.cod_entidad,
              cod_sucursal      = i.cod_sucursal,
              nro_cuenta        = i.nro_cuenta,
              cod_producto      = i.cod_producto,
              apellido          = i.apellido,
              nombre            = i.nombre,
              tip_documento     = i.tip_documento,
              nro_documento     = i.nro_documento,
              dis_compra        = i.dis_compra,
              signo1            = i.signo1,
              dis_adelanto      = i.dis_adelanto,
              signo2            = i.signo2,
              dis_com_usd       = i.dis_com_usd,
              signo3            = i.signo3,
              dis_ade_usd       = i.dis_ade_usd,
              signo4            = i.signo4,
              tra_pen_gs        = i.tra_pen_gs,
              signo5            = i.signo5,
              tra_pen_usd       = i.tra_pen_usd,
              signo6            = i.signo6,
              est_cuenta        = i.est_cuenta,
              sal_ant_gs        = i.sal_ant_gs,
              signo7            = i.signo7,
              sal_ant_usd       = i.sal_ant_usd,
              signo8            = i.signo8,
              sal_act_gs        = i.sal_act_gs,
              signo9            = i.signo9,
              sal_act_usd       = i.sal_act_usd,
              signo10           = i.signo10,
              filler            = i.filler,
              usu_insercion     = USER,
              fec_insercion     = SYSDATE,
              usu_modificacion  = USER,
              fec_modificacion  = SYSDATE,
              fec_proceso       = trunc(SYSDATE)
        WHERE nro_cuenta  = i.nro_cuenta
          AND fec_proceso = v_fecha;
      EXCEPTION
        WHEN OTHERS THEN
          r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                              v_lugar || '-' ||
                              to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                              SQLERRM;
          pat_igp.pr_ins_log(r_log);
      END;
      IF SQL%NOTFOUND THEN
      /*Si no encuentro registros, inserto en la tabla*/
        v_lugar := 'insert it.ta_pad_diario ' || i.nro_cuenta || ' ' || i.nro_documento;
        BEGIN
          INSERT INTO it.ta_pad_diario
            (tip_registro,
             cod_marca,
             cod_entidad,
             cod_sucursal,
             nro_cuenta,
             cod_producto,
             apellido,
             nombre,
             tip_documento,
             nro_documento,
             dis_compra,
             signo1,
             dis_adelanto,
             signo2,
             dis_com_usd,
             signo3,
             dis_ade_usd,
             signo4,
             tra_pen_gs,
             signo5,
             tra_pen_usd,
             signo6,
             est_cuenta,
             sal_ant_gs,
             signo7,
             sal_ant_usd,
             signo8,
             sal_act_gs,
             signo9,
             sal_act_usd,
             signo10,
             filler,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             fec_proceso)
          VALUES
            (i.tip_registro,
             i.cod_marca,
             i.cod_entidad,
             i.cod_sucursal,
             i.nro_cuenta,
             i.cod_producto,
             i.apellido,
             i.nombre,
             i.tip_documento,
             i.nro_documento,
             i.dis_compra,
             i.signo1,
             i.dis_adelanto,
             i.signo2,
             i.dis_com_usd,
             i.signo3,
             i.dis_ade_usd,
             i.signo4,
             i.tra_pen_gs,
             i.signo5,
             i.tra_pen_usd,
             i.signo6,
             i.est_cuenta,
             i.sal_ant_gs,
             i.signo7,
             i.sal_ant_usd,
             i.signo8,
             i.sal_act_gs,
             i.signo9,
             i.sal_act_usd,
             i.signo10,
             i.filler,
             USER,
             SYSDATE,
             USER,
             SYSDATE,
             trunc(SYSDATE));
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
            r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                                v_lugar || '-' ||
                                to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                SQLERRM;
            pat_igp.pr_ins_log(r_log);
        END;
      END IF; 
  END LOOP;
  
  v_cierre := pat_igp.FU_VER_FEC_CIERRE;
  IF v_cierre = 'S' THEN
    v_fec_cierre := nvl(pat_imp.fu_obt_fec_cierre(v_ent_global,53,3),pag_cal.FU_OBT_FEC_ACTUAL(5));
    FOR j IN c_ext_cierre LOOP
      v_lugar := 'Update ta_sal_cierres ' || j.nro_cuenta;
      BEGIN
        UPDATE ta_sal_cierres 
           SET sal_financiado      =  j.sal_financiado,
               sal_facturado       =  j.sal_facturado, 
               sal_facturar        =  j.sal_facturar,
               lin_credito         =  j.linea_credito,
               mto_pag_minimo      =  j.pago_minimo,
               fec_vto_pago        =  j.fec_vencimiento,
               lin_cuotas          =  j.lin_cuotas,
               sal_cuo_pendientes  =  j.sal_cuo_pendientes,
               dia_atraso          =  j.dia_mora,
               lin_especial        =  j.lin_especial
         WHERE nro_cuenta          =  j.nro_cuenta
           AND fec_cierre          =  j.fec_cierre; 
      EXCEPTION
        WHEN OTHERS THEN
          r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                              v_lugar || '-' ||
                              to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                              SQLERRM;
          pat_igp.pr_ins_log(r_log);
      END;
      IF SQL%NOTFOUND THEN     
        v_lugar := 'Insert ta_sal_cierres ' || j.nro_cuenta;
        BEGIN
          INSERT INTO ta_sal_cierres
            (nro_cuenta,
             fec_cierre,
             sal_financiado,
             sal_facturado,
             sal_facturar,
             lin_credito,
             mto_pag_minimo,
             fec_vto_pago,
             lin_cuotas,
             sal_cuo_pendientes,
             dia_atraso,
             lin_especial)
          VALUES 
            (j.nro_cuenta,
             j.fec_cierre,
             j.sal_financiado,
             j.sal_facturado,
             j.sal_facturar,
             j.linea_credito,
             j.pago_minimo,
             j.fec_vencimiento,
             j.lin_cuotas,
             j.sal_cuo_pendientes,
             j.dia_mora,
             j.lin_especial);            
        EXCEPTION
          WHEN OTHERS THEN
            r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                                v_lugar || '-' ||
                                to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                SQLERRM;
            pat_igp.pr_ins_log(r_log);
        END;
        v_lugar := 'Update ta_cta_tarjetas 1 ' || j.nro_cuenta;
        BEGIN
          UPDATE ta_cta_tarjetas tar
             SET tar.mto_pag_minimo     = j.pago_minimo,
                 sal_pag_minimo         = j.pago_minimo,
                 tar.sal_financiado     = j.sal_financiado,
                 tar.sal_facturado      = j.sal_facturado,
                 tar.sal_facturar       = j.sal_facturar,
                 tar.sal_cuo_pendientes = j.sal_cuo_pendientes,
                 tar.fec_ult_cierre     = j.fec_cierre,
                 tar.fec_vct_ult_cierre = j.fec_vencimiento,
                 tar.fec_ult_extracto   = j.fec_vencimiento
           WHERE tar.nro_cuenta         = j.nro_cuenta;
        EXCEPTION
          WHEN OTHERS THEN
            r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                                v_lugar || '-' ||
                                to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                SQLERRM;
            pat_igp.pr_ins_log(r_log);
        END;
      END IF;
    END LOOP;
  ELSE 
    /*Si el valor es 'S' devolverá el saldo online desde el WS*/
    IF p_online = 'S' THEN
      FOR c IN c_sal_diario LOOP
        BEGIN
          v_lugar := 'Busca Cuentas a actualizar ';
          SELECT b.nro_tarjeta
            INTO v_nro_tarjeta
            FROM ge_cta_clientes a, ta_tarjetas b
           WHERE b.nro_cuenta = c.nro_cuenta
             AND b.nro_cuenta = a.nro_cuenta
             AND b.cod_persona = a.cod_persona
             AND a.relacion = 'P'
             AND b.fec_emision = (SELECT MAX(x.fec_emision)
                                    FROM ta_tarjetas x
                                   WHERE x.nro_cuenta = b.nro_cuenta)    
             AND rownum =1;
        EXCEPTION
          WHEN OTHERS THEN
            r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                                 v_lugar || '-' ||
                                 to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                 SQLERRM;
            pat_igp.pr_ins_log(r_log);
        END;
          
        /*Obtengo el saldo financiado del cliente */
        v_url := v_url_ws;
        v_url := REPLACE(v_url, '{alphaAccountNumber}', c.nro_cuenta);
        v_url := REPLACE(v_url, '{cardNumber}', v_nro_tarjeta);
        /*Se crea la estructura json para pasar al ws*/
        v_content := NULL; 

        pat_tgl.pr_ws_conector(v_content,
                               v_url,
                               NULL,
                               c.cod_persona,
                               'M',
                               'GET',
                               v_cod_err_ws,
                               v_men_error); -- llama al web service

        IF v_cod_err_ws = v_cod_msg_exito THEN
          /*Extraigo la deuda de la cadena devuelta*/
          lp_par_jason(v_men_error,
                       c.cod_persona,
                       c.nro_cuenta,
                       v_sal_financiado,
                       v_cod_error);
          /*Si no hubo error de parseo de json, actualizo el saldo financiado en la cuenta*/
          IF v_cod_error IS NULL THEN
            BEGIN
              v_lugar := 'Actualizar saldo de Cuentas online ' || c.nro_cuenta;
              UPDATE ta_cta_tarjetas
                 SET sal_financiado = v_sal_financiado,
                     sal_facturado  = 0,
                     sal_facturar   = 0,
                     sal_cuo_pendientes = 0
               WHERE nro_cuenta = c.nro_cuenta;
            EXCEPTION 
              WHEN OTHERS THEN
                r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                                     v_lugar || '-' ||
                                     to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                     SQLERRM;
                pat_igp.pr_ins_log(r_log);
            END;
          END IF;
        END IF;
      END LOOP;
    /*Si no es online, actualizará el saldo desde el archivo de pradron diario*/
    ELSE
      FOR k IN c_ta_pad_diario LOOP
        v_lugar := 'Actualizar saldo de Cuentas desde archivo ' || k.nro_cuenta;
        BEGIN
          UPDATE ta_cta_tarjetas tar
             SET tar.sal_financiado = k.sal_act_gs,
                 tar.sal_facturado  = 0,
                 tar.sal_facturar   = 0,
                 tar.sal_cuo_pendientes = 0
           WHERE tar.nro_cuenta     = k.nro_cuenta;
        EXCEPTION
          WHEN OTHERS THEN
            r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || '-' ||
                                v_lugar || '-' ||
                                to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                SQLERRM;
            pat_igp.pr_ins_log(r_log);
        END;
      END LOOP; 
    END IF;
  END IF;
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de insercion de Padron diario disponible ***';
  pat_igp.pr_ins_log(r_log, FALSE);
  COMMIT;
END;
/


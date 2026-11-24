CREATE OR REPLACE PROCEDURE IT.PRG_INS_GAS_COBRANZAS is
   CURSOR c_pr_gastos IS
      SELECT a.cod_persona, a.cod_oficina, a.nro_cuenta, a.nro_cuota, a.cod_tra_cargo, 
             a.fec_vencimiento fec_ini_vigencia, a.monto, a.cod_emp_cob, pr.cod_modulo, 
             pr.cod_modalidad, pr.cod_moneda, pr.nro_solicitud
        FROM ge_gas_cobranzas_tmp a, ge_cta_clientes cl, pr_cta_prestamos pr
       WHERE a.nro_cuenta = cl.nro_cuenta
         AND a.cod_persona = cl.cod_persona
         AND a.nro_cuenta = pr.nro_cuenta
       ORDER BY pr.cod_moneda, a.nro_cuenta, a.fec_vencimiento;
   CURSOR c_cc_gastos IS
      SELECT a.cod_persona, a.cod_oficina, a.nro_cuenta, a.nro_cuota, a.cod_tra_cargo, 
             a.fec_vencimiento fec_ini_vigencia, a.monto, a.cod_emp_cob, cc.cod_modulo, 
             cc.cod_modalidad, cc.cod_moneda
        FROM ge_gas_cobranzas_tmp a, ge_cta_clientes cl, cc_cta_corrientes cc
       WHERE a.nro_cuenta = cl.nro_cuenta
         AND a.cod_persona = cl.cod_persona
         AND a.nro_cuenta = cc.nro_cuenta
       ORDER BY cc.cod_moneda, a.nro_cuenta, a.fec_vencimiento;
   CURSOR c_ov_gastos (p_cod_modalidad in number) IS
      SELECT a.cod_persona, a.cod_oficina, a.nro_cuenta, a.nro_cuota, a.cod_tra_cargo, 
             a.fec_vencimiento fec_ini_vigencia, a.monto, a.cod_emp_cob, ov.cod_modulo, 
             ov.cod_modalidad, ov.cod_moneda
        FROM ge_gas_cobranzas_tmp a, ge_cta_clientes cl, ov_cta_vencidas ov
       WHERE a.nro_cuenta = cl.nro_cuenta
         AND a.cod_persona = cl.cod_persona
         AND a.nro_cuenta = ov.nro_cuenta
         AND ov.cod_modalidad = p_cod_modalidad
       ORDER BY ov.cod_moneda, a.nro_cuenta, a.fec_vencimiento;
   
   v_usu_ejecucion          VARCHAR2(10):= USER;
   v_hor_log                VARCHAR2(20);
   v_err_mail               VARCHAR2(4000);
   v_can_registros          NUMBER(4);
   v_mto_total              NUMBER(18,2);
   
   v_conn                   utl_smtp.connection;
   v_dir_correo_de          VARCHAR2(100):= fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
   v_dir_correo_para        VARCHAR2(300):= FUG_OBT_PARDINAMICO('COS_REAL_DIR_CORREO');
   v_error                  ge_gas_cobranzas_log.error%type;
   v_monto                  pr_cta_gastos.monto%type;
   v_cod_moneda             ba_monedas.cod_moneda%type;
   v_redondeo               NUMBER(1);
   v_ref_archivo            VARCHAR2(30);
   v_referencia             VARCHAR2(10)  := 'GASCOBREAL';
   v_directorio             VARCHAR2(100) := 'MAIL';
   v_fec_actual             DATE := pag_cal.fu_obt_fec_actual(6);
   v_fec_hoy                DATE := trunc(sysdate);
   v_fec_disponible         DATE;
   v_entro                  VARCHAR2(1);
   v_mto_pag_dia            pr_cta_gastos.monto%type;
   PROCEDURE lp_env_email IS
   BEGIN
      IF v_dir_correo_para is not null THEN
         v_conn := it_mail.begin_mail(v_dir_correo_de,v_dir_correo_para,'Proceso de Importación de Gasto Cobranza con Errores');
         it_mail.write_text(v_conn,'Usuario: '||v_usu_ejecucion||' .Total de registros con errores: '||v_can_registros|| ' ,total monto: '||v_mto_total|| ' Para mas detalles verificar la Consulta Dinámica: ERRORES DEL PROCESO GASTOS DE COBRANZAS');
         it_mail.end_mail(v_conn);
      END IF;  
   EXCEPTION
      WHEN others THEN
         v_err_mail := sqlerrm;
         INSERT INTO ge_log_mail (fec_envio, cod_persona, dir_correo, mensaje, det_error, 
                                  nro_cuenta, hor_inicio, hor_fin)
         VALUES (trunc(sysdate), null, v_dir_correo_para,
             'Error en envío de mail Importación de Datos de Cargos por Gestión de Cobranza',
             v_err_mail, null, v_hor_log, v_hor_log);
   END;
   
   PROCEDURE lp_ins_log_error (p_error IN VARCHAR2,
                               p_hor_log IN VARCHAR2,
                               p_referencia IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;   
   BEGIN
      INSERT INTO ge_gas_cobranzas_log (error, hora, referencia)
      VALUES (p_error, p_hor_log, p_referencia);
      COMMIT;
   EXCEPTION
      WHEN others THEN
         RAISE_APPLICATION_ERROR(-20000, SQLERRM);
   END;
  --Función local para obtener monto pagado en el día
  FUNCTION lf_obt_obt_mto_pagado(p_cod_modulo in ba_modulos.cod_modulo%type,
                                 p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                                 p_cod_transaccion in pr_cta_gastos.cod_transaccion%type,
                                 p_fec_ini_vigencia in pr_cta_gastos.fec_ini_vigencia%type)
  RETURN NUMBER IS
     v_mto_pagado ge_movimientos.monto%type := 0;
  BEGIN
     IF p_cod_modulo = 6 THEN --busca gasto de Préstamos.
        BEGIN 
           SELECT SUM(g.monto)
             INTO v_mto_pagado
             FROM pr_cta_gastos g
            WHERE g.nro_cuenta = p_nro_cuenta
              AND g.cod_transaccion = p_cod_transaccion
              AND g.fec_ini_vigencia = p_fec_ini_vigencia
              AND g.fec_ult_pago = v_fec_actual
              AND referencia = v_referencia;
        EXCEPTION 
           WHEN others THEN
              v_mto_pagado := 0;  
        END;
     ELSIF p_cod_modulo =  15 then --busca gasto de Operaciones Vencidas.      
        BEGIN 
           SELECT SUM(g.monto)
             INTO v_mto_pagado
             FROM ov_cta_gastos g
            WHERE g.nro_cuenta = p_nro_cuenta
              AND g.cod_transaccion = p_cod_transaccion
              AND g.fec_ingreso = p_fec_ini_vigencia
              AND g.fec_ult_pago = v_fec_actual
              AND referencia=v_referencia;
        EXCEPTION 
           WHEN others THEN
              v_mto_pagado := 0;  
        END;
     END IF;
     RETURN v_mto_pagado;
  EXCEPTION
    WHEN others THEN
        v_mto_pagado := 0;
        RETURN v_mto_pagado;
  END;   

BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  IF pag_cal.fu_obt_fec_habil(v_fec_hoy,1,1) = v_fec_actual THEN -- Solo días hábiles
    -------------------------------------------
    -----------------PRÉSTAMOS-----------------
    -------------------------------------------
    IF nvl(fug_obt_pardinamico('COS_REAL_IND_ACTIVO', 6), 'N') = 'S' THEN
       v_entro      := 'N';
       v_cod_moneda := 'X';
       v_ref_archivo := 'GAS_COB_REAL_PRESTAM'; 
       v_hor_log := to_char(sysdate, 'HH24:MI:SS');
       BEGIN
          pag_arc.pr_arc_pro_archivo(v_ref_archivo, v_directorio, v_fec_actual);
       EXCEPTION
          WHEN others THEN
             v_error := substr('Error 01: '||sqlerrm, 1, 2000);
             lp_ins_log_error(v_error, v_hor_log, v_referencia);
       END;
       FOR rg IN c_pr_gastos LOOP
          IF v_entro = 'N' THEN
             v_entro := 'S';
             BEGIN
                DELETE pr_cta_gastos WHERE fec_ult_pago is null AND referencia=v_referencia;
             EXCEPTION
                WHEN others THEN
                   v_error := substr('Error 02: '||sqlerrm, 1, 2000);
                   lp_ins_log_error(v_error, v_hor_log, v_referencia);
             END; 
          END IF;
          IF v_cod_moneda <> rg.cod_moneda THEN
             v_cod_moneda := rg.cod_moneda;
             v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                             rg.cod_modulo,rg.cod_modalidad,rg.cod_moneda);
          END IF;
          v_monto := round(nvl(rg.monto,0),v_redondeo);
          /*Obtener monto pagado en el día*/
          v_mto_pag_dia := nvl(lf_obt_obt_mto_pagado(rg.cod_modulo,rg.nro_cuenta,rg.cod_tra_cargo,rg.fec_ini_vigencia),0);             
          IF v_mto_pag_dia > 0 and v_monto >= v_mto_pag_dia  THEN
             lp_ins_log_error('La Cta. '||rg.nro_cuenta||' ,ya tiene monto pagado en el día de: '||v_mto_pag_dia, v_hor_log, v_referencia);
             v_monto := round((v_monto - v_mto_pag_dia),v_redondeo);
          END IF;
          IF v_monto > 0  THEN
             v_fec_disponible := fup_obt_fec_dis_gastos(rg.nro_cuenta, rg.cod_tra_cargo, v_fec_actual, rg.nro_solicitud);
             BEGIN 
               INSERT INTO pr_cta_gastos(nro_cuenta, cod_transaccion, cod_moneda, monto, fec_ingreso,
                   cod_modalidad, cod_modulo, fec_ini_vigencia, referencia, nro_solicitud)
                VALUES (rg.nro_cuenta, rg.cod_tra_cargo, rg.cod_moneda, v_monto, v_fec_disponible,
                   rg.cod_modalidad, rg.cod_modulo, rg.fec_ini_vigencia, v_referencia, nvl(rg.nro_solicitud,9999999));
             EXCEPTION
                WHEN others THEN
                   v_error := substr('Error: '||sqlerrm, 1, 2000);
                   INSERT INTO ge_gas_cobranzas_log (cod_persona, cod_oficina, cod_modulo, cod_modalidad, nro_cuenta, 
                          nro_cuota, cod_tra_cargo, fec_vencimiento, monto, cod_emp_cob, error, hora, referencia)
                   VALUES (rg.cod_persona, rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad, rg.nro_cuenta, 
                          rg.nro_cuota, rg.cod_tra_cargo, rg.fec_ini_vigencia, v_monto, rg.cod_emp_cob, v_error,
                          v_hor_log, v_referencia);
             END;            
          END IF;   
       END LOOP;
       
       IF v_entro = 'S' THEN
          BEGIN --registros incorrectos
             SELECT count(*) cantidad_registros, sum(monto) monto_total
               INTO v_can_registros, v_mto_total
               FROM ge_gas_cobranzas_log a
              WHERE trunc(a.fec_insercion) = trunc(sysdate)
                AND hora = v_hor_log
                AND referencia = v_referencia
                AND cod_modulo = 6
                AND a.usu_insercion = user;
          END;
          IF v_can_registros > 0 THEN
             lp_env_email;
          END IF;
       END IF;
       COMMIT;
    END IF;   
     
    --------------------------------------------
    -----------------SOBREGIROS-----------------
    --------------------------------------------
    IF nvl(fug_obt_pardinamico('COS_REAL_IND_ACTIVO', 4), 'N') = 'S' THEN
       v_entro      := 'N';
       v_cod_moneda := 'X';
       v_ref_archivo := 'GAS_COB_REAL_SOBREGI';
       v_hor_log := to_char(sysdate, 'HH24:MI:SS');
       BEGIN
          pag_arc.pr_arc_pro_archivo(v_ref_archivo, v_directorio, v_fec_actual);
       EXCEPTION
          WHEN others THEN
             v_error := substr('Error 03: '||sqlerrm, 1, 2000);
             lp_ins_log_error(v_error, v_hor_log, v_referencia);
       END;
       FOR rg IN c_cc_gastos LOOP
          IF rg.fec_ini_vigencia >= v_fec_actual THEN
            IF v_entro = 'N' THEN
               v_entro := 'S';
               BEGIN
                  DELETE cc_cta_gastos WHERE fec_ult_pago is null AND referencia=v_referencia;
               EXCEPTION
                  WHEN others THEN
                     v_error := substr('Error 04: '||sqlerrm, 1, 2000);
                     lp_ins_log_error(v_error, v_hor_log, v_referencia);
               END;
            END IF; 
            IF v_cod_moneda <> rg.cod_moneda THEN
               v_cod_moneda := rg.cod_moneda;
               v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                               rg.cod_modulo,rg.cod_modalidad,rg.cod_moneda);
            END IF;
            v_monto := round(nvl(rg.monto,0),v_redondeo);
            BEGIN
               INSERT INTO cc_cta_gastos(nro_cuenta, cod_transaccion, cod_moneda, monto, fec_ingreso,
                  cod_modulo, cod_modalidad, referencia)
               VALUES (rg.nro_cuenta, rg.cod_tra_cargo, rg.cod_moneda, v_monto, rg.fec_ini_vigencia,
                  rg.cod_modulo, rg.cod_modalidad, v_referencia);
            EXCEPTION
               WHEN others THEN
                  v_error := substr('Error: '||sqlerrm, 1, 2000);
                  INSERT INTO ge_gas_cobranzas_log (cod_persona, cod_oficina, cod_modulo, cod_modalidad, nro_cuenta, 
                         nro_cuota, cod_tra_cargo, fec_vencimiento, monto, cod_emp_cob, error, hora, referencia)
                  VALUES (rg.cod_persona, rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad, rg.nro_cuenta, 
                         rg.nro_cuota, rg.cod_tra_cargo, rg.fec_ini_vigencia, v_monto, rg.cod_emp_cob, v_error,
                         v_hor_log, v_referencia);
            END;
          END IF;
       END LOOP;
       
       IF v_entro = 'S' THEN
          BEGIN --registros incorrectos
             SELECT count(*) cantidad_registros, sum(monto) monto_total
               INTO v_can_registros, v_mto_total
               FROM ge_gas_cobranzas_log a
              WHERE trunc(a.fec_insercion) = trunc(sysdate)
                AND hora = v_hor_log
                AND referencia = v_referencia
                AND cod_modulo = 4
                AND a.usu_insercion = user;
          END;
          IF v_can_registros > 0 THEN
             lp_env_email;
          END IF;
       END IF;
       COMMIT;
    END IF;   
     
    --------------------------------------------------
    -----------------Op. Vencidas TDC-----------------
    --------------------------------------------------
    IF nvl(fug_obt_pardinamico('COS_REAL_IND_ACTIVO', 15, 151), 'N') = 'S' THEN
       v_entro      := 'N';
       v_cod_moneda := 'X';
       v_ref_archivo := 'GAS_COB_REAL_TAR_VEN';
       v_hor_log := to_char(sysdate, 'HH24:MI:SS');
       BEGIN
          pag_arc.pr_arc_pro_archivo(v_ref_archivo, v_directorio, v_fec_actual);
       EXCEPTION
          WHEN others THEN
             v_error := substr('Error 05: '||sqlerrm, 1, 2000);
             lp_ins_log_error(v_error, v_hor_log, v_referencia);
       END;
       FOR rg IN c_ov_gastos(151) LOOP
          IF v_entro = 'N' THEN
             v_entro := 'S';
             BEGIN
                DELETE ov_cta_gastos WHERE cod_modalidad=151 AND fec_ult_pago is null AND referencia=v_referencia;
             EXCEPTION
                WHEN others THEN
                   v_error := substr('Error 06: '||sqlerrm, 1, 2000);
                   lp_ins_log_error(v_error, v_hor_log, v_referencia);
             END;
          END IF;
          IF v_cod_moneda <> rg.cod_moneda THEN
             v_cod_moneda := rg.cod_moneda;
             v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                             rg.cod_modulo,rg.cod_modalidad,rg.cod_moneda);
          END IF;
          v_monto := round(nvl(rg.monto,0),v_redondeo);
          /*Obtener monto pagado en el día*/
          v_mto_pag_dia := nvl(lf_obt_obt_mto_pagado(rg.cod_modulo,rg.nro_cuenta,rg.cod_tra_cargo,rg.fec_ini_vigencia),0);             
          IF v_mto_pag_dia > 0 and v_monto >= v_mto_pag_dia  THEN
             lp_ins_log_error('La Cta. '||rg.nro_cuenta||' ,ya tiene monto pagado en el día de: '||v_mto_pag_dia, v_hor_log, v_referencia);
             v_monto := round((v_monto - v_mto_pag_dia),v_redondeo);
          END IF;
          IF v_monto > 0  THEN
             BEGIN
                INSERT INTO ov_cta_gastos(nro_cuenta, cod_transaccion, cod_moneda, monto, fec_ingreso,
                   cod_modalidad, referencia)
                VALUES (rg.nro_cuenta, rg.cod_tra_cargo, rg.cod_moneda, v_monto, rg.fec_ini_vigencia,
                    rg.cod_modalidad, v_referencia);
             EXCEPTION
                WHEN others THEN
                   v_error := substr('Error: '||sqlerrm, 1, 2000);
                   INSERT INTO ge_gas_cobranzas_log (cod_persona, cod_oficina, cod_modulo, cod_modalidad, nro_cuenta, 
                          nro_cuota, cod_tra_cargo, fec_vencimiento, monto, cod_emp_cob, error, hora, referencia)
                   VALUES (rg.cod_persona, rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad, rg.nro_cuenta, 
                          rg.nro_cuota, rg.cod_tra_cargo, rg.fec_ini_vigencia, v_monto, rg.cod_emp_cob, v_error,
                          v_hor_log, v_referencia);
             END;
          END IF;   
       END LOOP;

       IF v_entro = 'S' THEN
          BEGIN --registros incorrectos
             SELECT count(*) cantidad_registros, sum(monto) monto_total
               INTO v_can_registros, v_mto_total
               FROM ge_gas_cobranzas_log a
              WHERE trunc(a.fec_insercion) = trunc(sysdate)
                AND hora = v_hor_log
                AND referencia = v_referencia
                AND cod_modalidad = 151
                AND a.usu_insercion = user;
          END;
          IF v_can_registros > 0 THEN
             lp_env_email;
          END IF;
       END IF;
       COMMIT; 
    END IF; 

    ------------------------------------------------------
    -----------------Op. Vencidas SOBREGI-----------------
    ------------------------------------------------------
    IF nvl(fug_obt_pardinamico('COS_REAL_IND_ACTIVO', 15, 152), 'N') = 'S' THEN
       v_entro      := 'N';
       v_cod_moneda := 'X';
       v_ref_archivo := 'GAS_COB_REAL_SOB_VEN';
       v_hor_log := to_char(sysdate, 'HH24:MI:SS');
       BEGIN
          pag_arc.pr_arc_pro_archivo(v_ref_archivo, v_directorio, v_fec_actual);
       EXCEPTION
          WHEN others THEN
             v_error := substr('Error 07: '||sqlerrm, 1, 2000);
             lp_ins_log_error(v_error, v_hor_log, v_referencia);
       END;
       FOR rg IN c_ov_gastos(152) LOOP
          IF v_entro = 'N' THEN
             v_entro := 'S';
             BEGIN
                DELETE ov_cta_gastos WHERE cod_modalidad=152 AND fec_ult_pago is null AND referencia=v_referencia;
             EXCEPTION
                WHEN others THEN
                   v_error := substr('Error 08: '||sqlerrm, 1, 2000);
                   lp_ins_log_error(v_error, v_hor_log, v_referencia);
             END;
          END IF;
          IF v_cod_moneda <> rg.cod_moneda THEN
             v_cod_moneda := rg.cod_moneda;
             v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                             rg.cod_modulo,rg.cod_modalidad,rg.cod_moneda);
          END IF;
          v_monto := round(nvl(rg.monto,0),v_redondeo);
          /*Obtener monto pagado en el día*/
          v_mto_pag_dia := nvl(lf_obt_obt_mto_pagado(rg.cod_modulo,rg.nro_cuenta,rg.cod_tra_cargo,rg.fec_ini_vigencia),0);             
          IF v_mto_pag_dia > 0 and v_monto >= v_mto_pag_dia   THEN
             lp_ins_log_error('La Cta. '||rg.nro_cuenta||' ,ya tiene monto pagado en el día de: '||v_mto_pag_dia, v_hor_log, v_referencia);
             v_monto := round((v_monto - v_mto_pag_dia),v_redondeo);
          END IF;
          IF v_monto > 0  THEN
             BEGIN
                INSERT INTO ov_cta_gastos(nro_cuenta, cod_transaccion, cod_moneda, monto, fec_ingreso,
                    cod_modalidad, referencia)
                VALUES (rg.nro_cuenta, rg.cod_tra_cargo, rg.cod_moneda, v_monto, rg.fec_ini_vigencia,
                    rg.cod_modalidad, v_referencia);
             EXCEPTION
                WHEN others THEN
                   v_error := substr('Error: '||sqlerrm, 1, 2000);
                   INSERT INTO ge_gas_cobranzas_log (cod_persona, cod_oficina, cod_modulo, cod_modalidad, nro_cuenta, 
                          nro_cuota, cod_tra_cargo, fec_vencimiento, monto, cod_emp_cob, error, hora, referencia)
                   VALUES (rg.cod_persona, rg.cod_oficina, rg.cod_modulo, rg.cod_modalidad, rg.nro_cuenta, 
                          rg.nro_cuota, rg.cod_tra_cargo, rg.fec_ini_vigencia, v_monto, rg.cod_emp_cob, v_error,
                          v_hor_log, v_referencia);
             END;
          END IF;   
       END LOOP;
       IF v_entro = 'S' THEN
          BEGIN --registros incorrectos
             SELECT count(*) cantidad_registros, sum(monto) monto_total
               INTO v_can_registros, v_mto_total
               FROM ge_gas_cobranzas_log a
              WHERE trunc(a.fec_insercion) = trunc(sysdate)
                AND hora = v_hor_log
                AND referencia = v_referencia
                AND cod_modalidad = 152
                AND a.usu_insercion = user;
          END;
          IF v_can_registros > 0 THEN
             lp_env_email;
          END IF;
       END IF;
       COMMIT;
    END IF;
  END IF;
  
EXCEPTION
   WHEN others THEN
     null;
END PRG_INS_GAS_COBRANZAS;
/


CREATE OR REPLACE PACKAGE BODY IT.PAB_RES  is
 
   -- Proceso principal para realizar Inventario de Cuentas de Resultado.
 PROCEDURE PR_GEN_INV_CTA_RES IS
     v_error varchar2(500);
     v_hor_inicio varchar2(8);
   BEGIN
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      EXECUTE IMMEDIATE ('truncate table cb_sal_inv_resultados_det');
      pag_cie.PR_INS_LOG('-FIN- 1. truncate cb_sal_inv_resultados_det.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      BEGIN
         DBMS_STATS.GATHER_TABLE_STATS('IT','CB_SAL_INVENTARIOS') ;
          pag_cie.PR_INS_LOG('-FIN- 2. Estadisticas CB_SAL_INVENTARIOS.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
         DBMS_STATS.GATHER_TABLE_STATS('IT','CB_SAL_INVENTARIOS_DET') ;
          pag_cie.PR_INS_LOG('-FIN- 3. Estadisticas CB_SAL_INVENTARIOS_DET.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      END;
      sql_util.ejecute_dml('ALTER INDEX IT.IN_CB_SAL_INVENTARIOS REBUILD',v_error);
      pag_cie.PR_INS_LOG('-FIN- 4. ALTER INDEX IT.IN_CB_SAL_INVENTARIOS REBUILD.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      IF v_error IS NOT NULL THEN
               raise_application_error(-20000, 'Alter Index ' || v_error);
      END IF;
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PROCESO INICIAL',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin Truncate-Estadisticas-RebuildIndex');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_DEV_PRESTAMOS;        -- Montos Devengados de Prestamos
      pag_cie.PR_INS_LOG('-FIN- 5. PR_ACU_DEV_PRESTAMOS', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_DEV_PRESTAMOS',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 1');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_DEV_MESA_DINERO;      -- Montos Devengados de Mesa de Dinero
      pag_cie.PR_INS_LOG('-FIN- 6. PR_ACU_DEV_MESA_DINERO', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_DEV_MESA_DINERO',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 2');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_DEV_CAJA_AHORRO;      -- Intereses Devengados de Caja de Ahorros
      pag_cie.PR_INS_LOG('-FIN- 7. PR_ACU_DEV_CAJA_AHORRO', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_DEV_CAJA_AHORRO',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 3');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_DEV_SUSPENSO;         -- Insteres Devengado en Suspenso
      pag_cie.PR_INS_LOG('-FIN- 8. PR_ACU_DEV_SUSPENSO', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_DEV_SUSPENSO',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 4');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_COMISIONES;           -- Comisiones Cobradas y Pagadas
      pag_cie.PR_INS_LOG('-FIN- 9. PR_ACU_COMISIONES', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_COMISIONES',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 5');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_COM_DIFERIDAS;        -- Comisiones Diferidas
      pag_cie.PR_INS_LOG('-FIN- 10. PR_ACU_COM_DIFERIDAS', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_COM_DIFERIDAS',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 6');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_OPE_CAMBIOS;          -- Operaciones de cambios
      pag_cie.PR_INS_LOG('-FIN- 11. PR_ACU_OPE_CAMBIOS', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_OPE_CAMBIOS',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 7');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_PREVISIONES;          -- Previsiones.
      pag_cie.PR_INS_LOG('-FIN- 12. PR_ACU_PREVISIONES', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_PREVISIONES',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 8');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_VALUACIONES;          -- Valuaciones.
      pag_cie.PR_INS_LOG('-FIN- 13. PR_ACU_VALUACIONES', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_VALUACIONES',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 9');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_OTR_INGRESOS;         -- Otros Ingresos
      pag_cie.PR_INS_LOG('-FIN- 14. PR_ACU_OTR_INGRESOS', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_OTR_INGRESOS',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 10');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_GASTOS;               -- Gastos
      pag_cie.PR_INS_LOG('-FIN- 15. PR_ACU_GASTOS', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_GASTOS',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 11');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_OTR_EGRESOS;           -- Otros Egresos
      pag_cie.PR_INS_LOG('-FIN- 16. PR_ACU_OTR_EGRESOS', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_OTR_EGRESOS',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 12');
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_IMPUESTOS;             -- Impuestos
      pag_cie.PR_INS_LOG('-FIN- 17. PR_ACU_IMPUESTOS', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      PRG_ACT_LOG_PROCESOS('PAB_RES.PR_GEN_INV_CTA_RES','PR_ACU_IMPUESTOS',trunc(sysdate),v_hor_inicio, to_char(sysdate,'hh24:mi:ss'),'Fin subPrograma 13');
   END;

  -- Proceso principal para realizar inventario Contable de cuentas de resultado
   PROCEDURE PR_INV_CTA_CONTABLE IS
     v_fec_actual    date;
     v_fec_anterior  date;
     v_periodo      cb_sal_inv_res_his.periodo%TYPE;
     v_anho         ge_cta_dep_internos_det.ano%type;
     v_mes          ge_cta_dep_internos_det.mes%type;
     v_ult_dia_mes_habil date;
     v_val_cot_usd   ge_cotizaciones.val_conversion%type;
     v_val_cot_eur   ge_cotizaciones.val_conversion%type;
     v_cod_mon_local ba_monedas.cod_moneda%type;
     v_fec_ant_mod_general date;
     v_hor_inicio            varchar2(8);
     v_hor_fin               varchar2(8);

   FUNCTION FU_OBT_COTIZACION(P_COD_MONEDA IN VARCHAR2, P_FECHA IN DATE) RETURN NUMBER IS
      v_val_cotizacion ge_cotizaciones.val_conversion%type;
   BEGIN
     IF P_COD_MONEDA = 'USD' THEN
        v_val_cotizacion := v_val_cot_usd;
     ELSIF P_COD_MONEDA = 'EUR' THEN
        v_val_cotizacion := v_val_cot_eur;
     ELSE
        v_val_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda, p_fecha);
     END IF;

     RETURN v_val_cotizacion;
   END;
  PROCEDURE PR_ACU_ASI_MANUALES IS
    -- Variables.
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_oficina                 cb_sal_inventarios.cod_oficina%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_cod_rubro                  VARCHAR2(15);
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    v_cod_persona                ba_personas.cod_persona%TYPE;
    v_cod_per_entidad            ba_personas.cod_persona%TYPE := fug_obt_per_entidad ;

    CURSOR c_mov_historicos(p_fecha DATE) IS
     select REPLACE(d.cod_rubro,' ','') cod_rubro,
            cd.nro_cuenta NRO_CUENTA,
            SUM(case
              when d.tip_movimiento = 'D' then
               d.mto_mon_rubro * -1
              else
               d.mto_mon_rubro
              end
            )MONTO,
            SUM(case
              when d.tip_movimiento = 'D' then
               d.mto_mon_local * -1
              else
               d.mto_mon_local
              end
            )MTO_EQU_LOCAL,
            cb.cod_moneda,
            d.val_cotizacion,
            c.cod_oficina,
            cd.cod_persona COD_PERSONA
       from cb_asientos c, cb_asientos_det d, cb_rubros cb, cb_dat_asientos_det cd
      where c.nro_asiento    = d.nro_asiento
        and d.fecha          = p_fecha
        and d.ref_movimiento is null
        and d.referencia     not like 'DEVENG.%'
        and d.referencia     not in ('DEP.INT','TRADING')
        and SUBSTR(d.cod_rubro,1,1) IN (6,7)
        and d.cod_rubro      = cb.cod_rubro
        and d.cod_rubro      IN (select distinct(h.cod_rubro) from cb_sal_inv_res_his h)
        and d.fecha = cd.fecha(+)
        and d.cod_oficina = cd.cod_oficina(+)
        and d.nro_asiento = cd.nro_asiento(+)
        and d.nro_linea = cd.nro_linea(+)
   group by REPLACE(d.cod_rubro,' ',''),
            cd.nro_cuenta,
            d.tip_movimiento,
            cb.cod_moneda,
            d.val_cotizacion,
            c.cod_oficina,
            cd.cod_persona;

  BEGIN
    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN c_mov_historicos (v_fec_actual);
    LOOP
      FETCH c_mov_historicos
       INTO v_cod_rubro,
            v_nro_cuenta,
            v_saldo_total,
            v_saldo_tot_gs,
            v_cod_moneda,
            v_cotizacion,
            v_cod_oficina,
            v_cod_persona;
    EXIT WHEN c_mov_historicos%NOTFOUND;

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (AM = ASIENTOS MANUALES)---
    v_tip_cta := 'AM';
    --
    IF v_nro_cuenta IS NULL THEN
       IF v_cod_persona IS NOT NULL AND v_cod_persona <> v_cod_per_entidad THEN
          BEGIN
             v_nro_cuenta := PAB_RES.FU_OBT_NRO_CUENTA(v_cod_persona);
          EXCEPTION
             WHEN OTHERS THEN
                v_nro_cuenta := NULL;
          END;
          --
          IF v_nro_cuenta IS NULL THEN
             v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
          END IF;
       ELSE
          v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
       END IF;
    END IF;

  BEGIN
      BEGIN
         --Obtiene los montos acumuldos anteriores
         SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
           INTO v_mto_ori_ant,v_mto_loc_ant
           FROM cb_sal_inv_res_his i
          WHERE i.cod_rubro    = v_cod_rubro
            AND i.nro_cuenta  = v_nro_cuenta
            AND i.periodo     = v_periodo;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_loc_ant:=0;
            v_mto_ori_ant:=0;
      END;

      IF v_cod_moneda = v_cod_mon_local THEN
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := 0;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera    := 0;
      ELSE
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := v_saldo_total;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_saldo_total,0);
      END IF;
      -- Si existe el registro actualizar.
      UPDATE cb_sal_inv_res_contables_det d
         SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
             d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
             d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
             d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND fecha       = v_fec_actual;

      -- Se inserta en la tabla de detalle diario.
      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inv_res_contables_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
         VALUES
            (v_fec_actual,v_cod_rubro,v_nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
      END IF;

      -- Requerimiento: CNFDEEVO-29.
      -- Fecha: 03/03/2016.
      -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
      UPDATE cb_sal_inv_res_his
         SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
             saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND periodo     = v_periodo
         AND tipo         = v_tip_cta
         AND cod_oficina = v_cod_oficina;

      IF SQL%NOTFOUND THEN
         -- Insertamos nuevos valores
         INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
              VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
      END IF;

    END;
    END LOOP;
    CLOSE c_mov_historicos;


  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_ASI_MANUALES: ' || SQLERRM);
  END PR_ACU_ASI_MANUALES;

    PROCEDURE PR_ACU_DEP_INTERNOS IS
    -- Variables.
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_oficina                cb_sal_inventarios.cod_oficina%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    -- Requerimiento: CNFDEEVO-1.
    -- Fecha: 09/11/2015.
    v_fec_cierre                 ge_calendarios.fec_actual%TYPE;
    v_cod_rubro                  VARCHAR2(15);

    -- Cursores.
    CURSOR c_mov_historicos IS
       SELECT   fu_obt_rubro(gc.cod_modulo, gc.cod_modalidad, cb.cod_transaccion, cb.cod_moneda,
                             NVL(ge.cod_sec_contable,'N'), null, NVL(ge.residente,'S'), null,
                             (case when cb.cod_transaccion = '888' then 'D' else 'C' end),
                             cb.estado, null, null, null, null, null, pr.cod_sec_credito) cod_rubro,
                cb.nro_cuenta,
                sum((case
                        when cb.cod_moneda = v_cod_mon_local then
                           0
                        else
                           (case
                               when cb.cod_transaccion = '888' then
                                  nvl(cb.mto_dep_interno,0) * (-1)
                               else
                                  nvl(cb.mto_dep_interno,0)
                            end)
                     end)) mto_mon_extranjera,
                sum((case
                        when cb.cod_moneda = v_cod_mon_local then
                           (case
                               when cb.cod_transaccion = '888' then
                                  nvl(cb.mto_dep_interno,0) * (-1)
                               else
                                  nvl(cb.mto_dep_interno,0)
                            end)
                        else
                           -- Requerimiento: CNFCMFDI-3.
                           -- Fecha: 08/09/2015.
                           (case
                               when cb.cod_transaccion = '888' then
                                  -- round((cb.mto_dep_interno * fug_obt_cotizacion(cb.cod_moneda,v_fec_actual)),0) * (-1)
                                  round(NVL(cb.mto_dep_mon_local,(cb.mto_dep_interno *
                                  (case
                                   when cb.cod_moneda = 'USD' then v_val_cot_usd
                                   when cb.cod_moneda = 'EUR' then v_val_cot_eur
                                   else pag_gen.fu_obt_cotizacion(cb.cod_moneda,v_fec_actual)
                                   end)
                                  )),0) * (-1)
                               else
                                  -- round((cb.mto_dep_interno * fug_obt_cotizacion(cb.cod_moneda,v_fec_actual)),0)
                                  round(NVL(cb.mto_dep_mon_local,(cb.mto_dep_interno *
                                  (case
                                   when cb.cod_moneda = 'USD' then v_val_cot_usd
                                   when cb.cod_moneda = 'EUR' then v_val_cot_eur
                                   else pag_gen.fu_obt_cotizacion(cb.cod_moneda,v_fec_actual)
                                   end)
                                  )),0)
                            end)
                     end)) mto_mon_local,
                cb.cod_moneda,
                cb.cod_oficina
           FROM ge_cta_dep_internos_det cb, ge_clientes ge, ge_cta_clientes gc, pr_cta_prestamos pr
          WHERE cb.ano = v_anho
            AND cb.mes = v_mes
            AND cb.nro_cuenta = gc.nro_cuenta
            AND gc.relacion = 'P'
            AND gc.cod_persona = ge.cod_persona
            AND gc.nro_cuenta = pr.nro_cuenta
            AND cb.mto_dep_interno <> 0
          GROUP BY fu_obt_rubro(gc.cod_modulo, gc.cod_modalidad, cb.cod_transaccion, cb.cod_moneda,
                             NVL(ge.cod_sec_contable,'N'), null, NVL(ge.residente,'S'), null,
                             (case when cb.cod_transaccion = '888' then 'D' else 'C' end),
                             cb.estado, null, null, null, null, null, pr.cod_sec_credito),
                   cb.nro_cuenta, v_periodo, 0, cb.cod_moneda, cb.cod_oficina
          UNION
           SELECT fu_obt_rubro(gc.cod_modulo, gc.cod_modalidad, cb.cod_transaccion, cb.cod_moneda,
                             NVL(ge.cod_sec_contable,'N'), null, NVL(ge.residente,'S'), null,
                             (case when cb.cod_transaccion = '888' then 'D' else 'C' end),
                             cb.estado, null, null, null, null, null, null) cod_rubro,
                  cb.nro_cuenta,
                  sum((case
                          when cb.cod_moneda = v_cod_mon_local then
                             0
                          else
                             (case
                               when cb.cod_transaccion = '888' then
                                  nvl(cb.mto_dep_interno,0) * (-1)
                               else
                                  nvl(cb.mto_dep_interno,0)
                            end)
                       end)) mto_mon_extranjera,
                  sum((case
                          when cb.cod_moneda = v_cod_mon_local then
                             (case
                               when cb.cod_transaccion = '888' then
                                  nvl(cb.mto_dep_interno,0) * (-1)
                               else
                                  nvl(cb.mto_dep_interno,0)
                            end)
                          else
                             -- Requerimiento: CNFCMFDI-3.
                             -- Fecha: 08/09/2015.
                             (case
                                 when cb.cod_transaccion = '888' then
                                    -- round((cb.mto_dep_interno * fug_obt_cotizacion(cb.cod_moneda,v_fec_actual)),0) * (-1)
                                    round(NVL(cb.mto_dep_mon_local,(cb.mto_dep_interno *
                                    (case
                                   when cb.cod_moneda = 'USD' then v_val_cot_usd
                                   when cb.cod_moneda = 'EUR' then v_val_cot_eur
                                   else pag_gen.fu_obt_cotizacion(cb.cod_moneda,v_fec_actual)
                                   end)
                                    )),0) * (-1)
                                 else
                                    -- round((cb.mto_dep_interno * fug_obt_cotizacion(cb.cod_moneda,v_fec_actual)),0)
                                    round(NVL(cb.mto_dep_mon_local,(cb.mto_dep_interno *
                                    (case
                                     when cb.cod_moneda = 'USD' then v_val_cot_usd
                                     when cb.cod_moneda = 'EUR' then v_val_cot_eur
                                     else pag_gen.fu_obt_cotizacion(cb.cod_moneda,v_fec_actual)
                                     end)
                                    )),0)
                              end)
                       end)) mto_mon_local,
                  cb.cod_moneda,
                  cb.cod_oficina
           FROM ge_cta_dep_internos_det cb, ge_clientes ge, ge_cta_clientes gc
          WHERE cb.ano = v_anho
            AND cb.mes = v_mes
            AND cb.nro_cuenta = gc.nro_cuenta
            AND gc.relacion = 'P'
            AND gc.cod_persona = ge.cod_persona
            AND gc.cod_modulo <> 6
            AND cb.mto_dep_interno <> 0
          GROUP BY fu_obt_rubro(gc.cod_modulo, gc.cod_modalidad, cb.cod_transaccion, cb.cod_moneda,
                             NVL(ge.cod_sec_contable,'N'), null, NVL(ge.residente,'S'), null,
                             (case when cb.cod_transaccion = '888' then 'D' else 'C' end),
                             cb.estado, null, null, null, null, null, null),
                   cb.nro_cuenta, v_periodo, 0, cb.cod_moneda, cb.cod_oficina;

BEGIN
    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    -- Requerimiento: CNFDEEVO-1.
    -- Fecha: 09/11/2015.
    -- IF v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL THEN
    BEGIN
       v_fec_cierre := to_date(fug_obt_pardinamico('CBN_FEC_ULT_DIA_CIE_ANUAL'),'dd/mm/yyyy');
    EXCEPTION
       WHEN OTHERS THEN
          v_fec_cierre := NULL;
    END;
    --
    IF v_fec_actual = v_ULT_DIA_MES_HABIL OR v_fec_actual = v_fec_cierre THEN
       OPEN c_mov_historicos;
       LOOP
         FETCH c_mov_historicos
          INTO v_cod_rubro,
               v_nro_cuenta,
               v_saldo_total,
               v_saldo_tot_gs,
               v_cod_moneda,
               v_cod_oficina;
       EXIT WHEN c_mov_historicos%NOTFOUND;

       -- OBTIENE EL TIPO DE CTA DE RESULTADO (DI=DEPOSITOS INTERNOS)---
       v_tip_cta := 'DI';
       --
       IF v_nro_cuenta IS NULL THEN
          v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
       END IF;

       BEGIN
         BEGIN
            --Obtiene los montos acumuldos anteriores
            SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
              INTO v_mto_ori_ant,v_mto_loc_ant
              FROM cb_sal_inv_res_his i
             WHERE i.cod_rubro   = v_cod_rubro
               AND i.nro_cuenta  = v_nro_cuenta
               AND i.periodo     = v_periodo;
         EXCEPTION
            WHEN no_data_found THEN
               v_mto_loc_ant := 0;
               v_mto_ori_ant := 0;
         END;
         IF v_cod_moneda = v_cod_mon_local THEN
            v_cotizacion                   := 1;
            v_sal_mon_local                := v_saldo_tot_gs;
            v_sal_mon_extranjera           := 0;
            v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
            v_sal_acu_act_mon_extranjera   := 0;
         ELSE
            v_cotizacion                   := fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            v_sal_mon_local                := v_saldo_tot_gs;
            v_sal_mon_extranjera           := v_saldo_total;
            v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
            v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_saldo_total,0);
         END IF;
         -- Si existe el registro actualizar.
         UPDATE cb_sal_inv_res_contables_det d
            SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
                d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
                d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
                d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
          WHERE cod_rubro   = v_cod_rubro
            AND nro_cuenta  = v_nro_cuenta
            AND fecha       = v_fec_actual;

         -- Se inserta en la tabla de detalle diario.
         IF SQL%NOTFOUND THEN
            INSERT INTO cb_sal_inv_res_contables_det
               (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
                sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
            VALUES
               (v_fec_actual,v_cod_rubro,v_nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
                v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
         END IF;

         -- Requerimiento: CNFDEEVO-29.
         -- Fecha: 03/03/2016.
         -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
         UPDATE cb_sal_inv_res_his
            SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
                saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
          WHERE cod_rubro    = v_cod_rubro
            AND nro_cuenta   = v_nro_cuenta
            AND periodo      = v_periodo
            AND tipo         = v_tip_cta
            AND cod_oficina  = v_cod_oficina;

         IF SQL%NOTFOUND THEN
            -- Insertamos nuevos valores
            INSERT INTO cb_sal_inv_res_his
               (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
            VALUES
               (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
         END IF;
       END;
       END LOOP;
       CLOSE c_mov_historicos;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_DEP_INTERNOS: ' || SQLERRM);
  END PR_ACU_DEP_INTERNOS;

  -- Trading (TA)
  PROCEDURE PR_ACU_TRADING IS
    -- Variables.
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_oficina                cb_sal_inventarios.cod_oficina%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_cod_persona                ge_movimientos.cod_persona%type;
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    -- Requerimiento: CNFDEEVO-1.
    -- Fecha: 09/11/2015.
    v_fec_cierre                 ge_calendarios.fec_actual%TYPE;
    v_cod_rubro                  VARCHAR2(15);

    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
      SELECT REPLACE(d.cod_rubro,' ','') cod_rubro,
              NULL NRO_CUENTA,
              trim(d.descripcion) cod_persona,
              SUM(case when d.tip_movimiento = 'D' then d.mto_mon_rubro * -1 else d.mto_mon_rubro end) MONTO,
              SUM(case when d.tip_movimiento = 'D' then d.mto_mon_local * -1 else d.mto_mon_local end) MTO_EQU_LOCAL,
              cb.cod_moneda,
              c.cod_oficina
         FROM cb_asientos c, cb_asientos_det d, cb_rubros cb, ba_personas ba
        WHERE c.nro_asiento  = d.nro_asiento
          AND d.fecha          = p_fecha
          AND d.ref_movimiento IS NULL
          AND d.referencia     = 'TRADING'
          AND SUBSTR(d.cod_rubro,1,1) IN (6,7)
          AND d.cod_rubro      = cb.cod_rubro
          AND ba.cod_persona = d.descripcion
        GROUP BY REPLACE(d.cod_rubro,' ',''),
              NULL,
              trim(d.descripcion),
              d.tip_movimiento,
              cb.cod_moneda,
              d.val_cotizacion,
              c.cod_oficina;

  -- Funciones.
  FUNCTION lf_obt_nro_cuenta(p_cod_persona ge_movimientos.cod_persona%type,
                             p_cod_moneda  ge_movimientos.cod_moneda%type)
  RETURN VARCHAR2
  AS
  v_nro_cuenta     ge_movimientos.nro_cuenta%type := NULL;
  BEGIN
    begin

       -- Obtengo las cuentas pasivas que posee el cliente.
       BEGIN
          IF v_nro_cuenta IS NULL AND p_cod_persona IS NOT NULL THEN
             select v.nro_cuenta
               into v_nro_cuenta
               from (
                 select a.nro_cuenta, a.cod_modulo
                   from ge_cuentas a, ge_cta_clientes b
                  where a.nro_cuenta  = b.nro_cuenta
                    and b.cod_persona = p_cod_persona
                    and a.cod_moneda  = p_cod_moneda
                    and a.cod_modulo in (3,4)
                    and a.estado not in ('A', 'C', 'X')
                  order by a.cod_modulo desc
                     ) v
              where rownum = 1;
          END IF;
       EXCEPTION
          WHEN OTHERS THEN
             v_nro_cuenta := NULL;
       END;

       -- Obtengo un nro. de cuenta que posee el cliente.
       IF v_nro_cuenta IS NULL AND p_cod_persona IS NOT NULL THEN
          select v.nro_cuenta
            into v_nro_cuenta
            from (
              select a.nro_cuenta, a.cod_modulo
                from ge_cuentas a, ge_cta_clientes b
               where a.nro_cuenta  = b.nro_cuenta
                 and b.cod_persona = p_cod_persona
                 and a.cod_moneda  = p_cod_moneda
                 and a.cod_modulo not in (3,4)
                 and a.estado not in ('A', 'C', 'X')
              order by a.cod_modulo desc
            ) v
            where rownum = 1;
       END IF;
    end;
       return v_nro_cuenta;
  EXCEPTION
     WHEN OTHERS THEN
       v_nro_cuenta := NULL;
       return v_nro_cuenta;
  END;

  BEGIN
    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    -- Requerimiento: CNFDEEVO-1.
    -- Fecha: 09/11/2015.
    -- IF v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL THEN
    BEGIN
       v_fec_cierre := to_date(fug_obt_pardinamico('CBN_FEC_ULT_DIA_CIE_ANUAL'),'dd/mm/yyyy');
    EXCEPTION
       WHEN OTHERS THEN
          v_fec_cierre := NULL;
    END;
    --
    IF v_fec_actual = v_ULT_DIA_MES_HABIL OR v_fec_actual = v_fec_cierre THEN
       OPEN c_mov_historicos (v_fec_actual);
       LOOP
          FETCH c_mov_historicos
          INTO v_cod_rubro,
               v_nro_cuenta,
               v_cod_persona,
               v_saldo_total,
               v_saldo_tot_gs,
               v_cod_moneda,
               v_cod_oficina;
       EXIT WHEN c_mov_historicos%NOTFOUND;

       -- OBTIENE EL TIPO DE CTA DE RESULTADO (TA=TRADING)---
       v_tip_cta := 'TA';
       --
       IF v_nro_cuenta IS NULL THEN
          v_nro_cuenta := NVL(NVL(lf_obt_nro_cuenta(v_cod_persona,v_cod_moneda),fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina)),'9999999999');
       END IF;

       BEGIN
         BEGIN
            --Obtiene los montos acumuldos anteriores
            SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
              INTO v_mto_ori_ant,v_mto_loc_ant
              FROM cb_sal_inv_res_his i
             WHERE i.cod_rubro   = v_cod_rubro
               AND i.nro_cuenta  = v_nro_cuenta
               AND i.periodo     = v_periodo;
         EXCEPTION
            WHEN no_data_found THEN
               v_mto_loc_ant := 0;
               v_mto_ori_ant := 0;
         END;
         --
         IF v_cod_moneda = v_cod_mon_local THEN
            v_cotizacion                   := 1;
            v_sal_mon_local                := v_saldo_tot_gs;
            v_sal_mon_extranjera           := 0;
            v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
            v_sal_acu_act_mon_extranjera   := 0;
         ELSE
            v_cotizacion                   := fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            v_sal_mon_local                := v_saldo_tot_gs;
            v_sal_mon_extranjera           := v_saldo_total;
            v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
            v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_saldo_total,0);
         END IF;

         -- Si existe el registro actualizar.
         UPDATE cb_sal_inv_res_contables_det d
            SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
                d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
                d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
                d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
          WHERE cod_rubro   = v_cod_rubro
            AND nro_cuenta  = v_nro_cuenta
            AND fecha       = v_fec_actual;

         -- Se inserta en la tabla de detalle diario.
         IF SQL%NOTFOUND THEN
            INSERT INTO cb_sal_inv_res_contables_det
               (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
                sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
            VALUES
               (v_fec_actual,v_cod_rubro,v_nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
                v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
         END IF;

         -- Requerimiento: CNFDEEVO-29.
         -- Fecha: 03/03/2016.
         -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
         UPDATE cb_sal_inv_res_his
            SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
                saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
          WHERE cod_rubro    = v_cod_rubro
            AND nro_cuenta   = v_nro_cuenta
            AND periodo      = v_periodo
            AND tipo         = v_tip_cta
            AND cod_oficina  = v_cod_oficina;

         IF SQL%NOTFOUND THEN
            -- Insertamos nuevos valores
            INSERT INTO cb_sal_inv_res_his
               (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
            VALUES
               (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
         END IF;
       END;
       END LOOP;
       CLOSE c_mov_historicos;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_TRADING: ' || SQLERRM);
  END PR_ACU_TRADING;

  PROCEDURE PR_REV_MOV_INVENTARIOS IS
  --
  v_nro_cuenta                  ge_movimientos.nro_cuenta%type;
  v_tip_cta                     cb_sal_inv_res_his.tipo%TYPE;
  --
  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.

  cursor c_rev_mov_rubros_dia(p_fecha DATE)  is
     select a.cod_rubro, b.nro_cuenta, 0 saldo_total, sum(nvl(b.sal_actual,0)) saldo_tot_gs, a.cod_oficina
       from cb_sal_inventarios a, cb_sal_inventarios_det b
      where a.nro_referencia = b.nro_referencia
        and a.tip_saldo = 'K'
        and not exists (select 1
                          from cb_rubros cb
                         where cb.cod_rubro   = a.cod_rubro
                        )
      group by a.cod_rubro, b.nro_cuenta, a.cod_oficina
     union all
     select a.cod_rubro, a.nro_cuenta,
            sum(nvl(a.saldo_total,0)) saldo_total,
            sum(nvl(a.saldo_tot_gs,0)) saldo_tot_gs, a.cod_oficina
       from cb_sal_inv_res_his a
      where a.saldo_tot_gs <> 0
        and a.tipo in ('AC','AM','AJ')
        and a.periodo = v_periodo
        and not exists (select 1
                          from ge_cuentas b
                         where b.nro_cuenta  = a.nro_cuenta
                       )
      group by a.cod_rubro, a.nro_cuenta, a.cod_oficina;

  cursor c_rev_mov_rubros_his(p_fecha DATE)  is
     select a.cod_rubro, b.nro_cuenta, 0 saldo_total, sum(nvl(b.sal_actual,0)) saldo_tot_gs, a.cod_oficina
       from cb_sal_inv_procesos a, cb_sal_inv_procesos_det b
      where a.nro_referencia = b.nro_referencia
        and a.fecha = b.fecha
        and a.fecha = p_fecha
        and a.tip_saldo = 'K'
        and not exists (select 1
                          from cb_rubros cb
                         where cb.cod_rubro   = a.cod_rubro
                        )
      group by a.cod_rubro, b.nro_cuenta, a.cod_oficina
     union all
     select a.cod_rubro, a.nro_cuenta,
            sum(nvl(a.saldo_total,0)) saldo_total,
            sum(nvl(a.saldo_tot_gs,0)) saldo_tot_gs, a.cod_oficina
       from cb_sal_inv_res_his a
      where a.saldo_tot_gs <> 0
        and a.tipo in ('AC','AM','AJ')
        and a.periodo = v_periodo
        and not exists (select 1
                          from ge_cuentas b
                         where b.nro_cuenta  = a.nro_cuenta
                       )
      group by a.cod_rubro, a.nro_cuenta, a.cod_oficina;

  BEGIN
  -- OBTIENE EL TIPO DE CTA DE RESULTADO (AC = AJUSTE CONTABLES)---
  v_tip_cta := 'AC';

  if v_fec_actual = v_fec_ant_mod_general then
  -- Insertamos monto negativo de los rubros que no estan en el balance --
      for reg in c_rev_mov_rubros_dia(v_fec_actual) loop

        -- insertamos en el detalle contable en negativo el monto
         begin
             -- Si existe el registro actualizar.
              UPDATE cb_sal_inv_res_contables_det d
                 SET d.sal_mon_extranjera         = d.sal_mon_extranjera + (nvl(reg.saldo_total,0) * (-1)),
                     d.sal_mon_local              = d.sal_mon_local + (nvl(reg.saldo_tot_gs,0) * (-1))
               WHERE cod_rubro   = reg.cod_rubro
                 AND nro_cuenta  = reg.nro_cuenta
                 AND fecha       = v_fec_actual;
              -- Se inserta en la tabla de detalle diario.
              IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inv_res_contables_det
                (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
                 sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
               VALUES
                (v_fec_actual,reg.cod_rubro,reg.nro_cuenta,1,(nvl(reg.saldo_total,0) * (-1)),(nvl(reg.saldo_tot_gs,0) * (-1)),0,0);
              END IF;

           -- Requerimiento: CNFDEEVO-29.
           -- Fecha: 03/03/2016.
           -- Insertamos en el historico los montos en negativo
           update cb_sal_inv_res_his cb
              set cb.saldo_tot_gs = cb.saldo_tot_gs + (nvl(reg.saldo_tot_gs,0) * (-1)),
                  cb.saldo_total  = cb.saldo_total + (nvl(reg.saldo_total,0) * (-1))
            where cb.cod_rubro  = reg.cod_rubro
              and cb.nro_cuenta = reg.nro_cuenta
              and cb.periodo    = v_periodo
              and cb.tipo       = v_tip_cta
              and cb.cod_oficina = reg.cod_oficina;

           IF SQL%NOTFOUND THEN
              insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                     values (reg.cod_rubro, reg.nro_cuenta, v_periodo, v_tip_cta, (nvl(reg.saldo_total,0) * (-1)), (nvl(reg.saldo_tot_gs,0) * (-1)), reg.cod_oficina);
           END IF;

         exception
           when others then
                NULL;
        end;
       end loop;
   else
       for reg in c_rev_mov_rubros_his(v_fec_actual) loop

        -- insertamos en el detalle contable en negativo el monto
         begin
             -- Si existe el registro actualizar.
              UPDATE cb_sal_inv_res_contables_det d
                 SET d.sal_mon_extranjera         = d.sal_mon_extranjera + (nvl(reg.saldo_total,0) * (-1)),
                     d.sal_mon_local              = d.sal_mon_local + (nvl(reg.saldo_tot_gs,0) * (-1))
               WHERE cod_rubro   = reg.cod_rubro
                 AND nro_cuenta  = reg.nro_cuenta
                 AND fecha       = v_fec_actual;
              -- Se inserta en la tabla de detalle diario.
              IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inv_res_contables_det
                (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
                 sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
               VALUES
                (v_fec_actual,reg.cod_rubro,reg.nro_cuenta,1,(nvl(reg.saldo_total,0) * (-1)),(nvl(reg.saldo_tot_gs,0) * (-1)),0,0);
              END IF;

           -- Requerimiento: CNFDEEVO-29.
           -- Fecha: 03/03/2016.
           -- Insertamos en el historico los montos en negativo
           update cb_sal_inv_res_his cb
              set cb.saldo_tot_gs = cb.saldo_tot_gs + (nvl(reg.saldo_tot_gs,0) * (-1)),
                  cb.saldo_total  = cb.saldo_total + (nvl(reg.saldo_total,0) * (-1))
            where cb.cod_rubro  = reg.cod_rubro
              and cb.nro_cuenta = reg.nro_cuenta
              and cb.periodo    = v_periodo
              and cb.tipo       = v_tip_cta
              and cb.cod_oficina = reg.cod_oficina;

           IF SQL%NOTFOUND THEN
              insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                     values (reg.cod_rubro, reg.nro_cuenta, v_periodo, v_tip_cta, (nvl(reg.saldo_total,0) * (-1)), (nvl(reg.saldo_tot_gs,0) * (-1)), reg.cod_oficina);
           END IF;

         exception
           when others then
                NULL;
        end;
       end loop;
   end if;

  EXCEPTION
     WHEN OTHERS THEN
        ROLLBACK;
        raise_application_error(-20000, 'ERROR PR_REV_MOV_INVENTARIOS: ' ||v_nro_cuenta|| SQLERRM);
  END PR_REV_MOV_INVENTARIOS;

  PROCEDURE PR_AJU_RUB_CONTABLES IS
  --
  v_sal_local                  ge_movimientos.monto%type :=0;
  v_sal_extranjero              ge_movimientos.monto%type :=0;
  v_dif_local                  ge_movimientos.monto%type :=0;
  v_mto_rubro                  ge_movimientos.monto%type :=0;
  v_dif_extranjero              ge_movimientos.monto%type :=0;
  v_nro_cuenta                  ge_movimientos.nro_cuenta%type;
  v_cod_moneda                  ge_movimientos.cod_moneda%type;
  v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
  v_mto_cotizacion             ge_cotizaciones.val_conversion%TYPE;
  v_cod_oficina                 cb_sal_inventarios.cod_oficina%TYPE;
  v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
  v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
  v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
  v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
  v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
  v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
  v_hor_ini_proc               varchar2(8) := to_char(sysdate,'hh24:mi:ss');
  v_hor_fin_proc               varchar2(8) := to_char(sysdate,'hh24:mi:ss');

  --
  cursor c_inventarios_dia(p_fecha DATE) is
      select h.cod_rubro, h.cod_oficina, 0 saldo_total, sum(nvl(h.sal_total,0)) saldo_tot_gs
        from cb_sal_inventarios h
       where substr(h.cod_rubro,1,1) IN ('6','7')
      group by h.cod_rubro, h.cod_oficina
      union all
      select a.cod_rubro, b.cod_oficina, 0 saldo_total, sum(nvl(a.saldo_tot_gs,0)) saldo_tot_gs
        from cb_sal_inv_res_his a, ge_cuentas b
       where a.nro_cuenta = b.nro_cuenta
         and a.periodo = v_periodo
         and a.tipo in ('AC','AM','AJ','DI','TA')
         and not exists (select 1
                           from cb_sal_inventarios cb
                          where cb.cod_rubro = a.cod_rubro
                            and cb.cod_oficina = b.cod_oficina
                            and substr(cb.cod_rubro,1,1) IN ('6','7'))
        group by a.cod_rubro, b.cod_oficina;

  cursor c_inventarios_his(p_fecha DATE) is
      select h.cod_rubro, h.cod_oficina, 0 saldo_total, sum(nvl(h.sal_total,0)) saldo_tot_gs
        from cb_sal_inv_procesos h
       where h.fecha = p_fecha
         and substr(h.cod_rubro,1,1) IN ('6','7')
      group by h.cod_rubro, h.cod_oficina
      union all
      select a.cod_rubro, b.cod_oficina, 0 saldo_total, sum(nvl(a.saldo_tot_gs,0)) saldo_tot_gs
        from cb_sal_inv_res_his a, ge_cuentas b
       where a.nro_cuenta = b.nro_cuenta
         and a.periodo = v_periodo
         and a.tipo in ('AC','AM','AJ','DI','TA')
         and not exists (select 1
                           from cb_sal_inv_procesos cb
                          where cb.fecha = p_fecha
                            and cb.cod_rubro = a.cod_rubro
                            and cb.cod_oficina = b.cod_oficina
                            and substr(cb.cod_rubro,1,1) IN ('6','7'))
        group by a.cod_rubro, b.cod_oficina;

  -- Insertamos los saldos que estan en el balance pero no en el historico --
  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  cursor c_balance_dia(p_fecha DATE) is
      select a.cod_rubro, b.cod_moneda, a.cod_oficina,
             sum((nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0))* -1) mto_local,
             sum((nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1) mto_extranjera
        from cb_sal_oficinas a, cb_rubros b
       where a.cod_rubro = b.cod_rubro
         and substr(a.cod_rubro,1,1) in ('6','7')
         and b.imputable = 'S'
         and SUBSTR(a.cod_rubro,6,3) IN (SELECT b.val_minimo FROM ba_cod_referencias b WHERE b.dominio IN ('COM_COBRADAS','COM_PAGADAS','OPE_CAMBIO','VALUACION','PREVISION','DEV_SUSPENSO','OTROS_INGRESOS','OTROS_EGRESOS','GASTOS','IMPUESTOS'))
         and not exists (select 1
                          from cb_sal_inventarios h
                         where substr(h.cod_rubro,1,1) IN ('6','7')
                           and h.cod_rubro = a.cod_rubro
                           and h.cod_oficina = a.cod_oficina)
         and not exists (select 1
                           from cb_sal_inv_res_his m, ge_cuentas ge
                          where m.cod_rubro = a.cod_rubro
                            and m.nro_cuenta = ge.nro_cuenta
                            and m.periodo = v_periodo
                            and m.tipo IN ('AC','AM','AJ','DI','TA')
                            and m.cod_oficina = a.cod_oficina)
       group by a.cod_rubro, b.cod_moneda, a.cod_oficina;

  cursor c_balance_his(p_fecha DATE) is
      select a.cod_rubro, b.cod_moneda, a.cod_oficina,
             sum((nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0))* -1) mto_local,
             sum((nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1) mto_extranjera
        from cb_sal_oficinas a, cb_rubros b
       where a.cod_rubro = b.cod_rubro
         and substr(a.cod_rubro,1,1) in ('6','7')
         and b.imputable = 'S'
         and SUBSTR(a.cod_rubro,6,3) IN (SELECT b.val_minimo FROM ba_cod_referencias b WHERE b.dominio IN ('COM_COBRADAS','COM_PAGADAS','OPE_CAMBIO','VALUACION','PREVISION','DEV_SUSPENSO','OTROS_INGRESOS','OTROS_EGRESOS','GASTOS','IMPUESTOS'))
         and not exists (select 1
                          from cb_sal_inv_procesos h
                         where h.fecha = p_fecha
                           and substr(h.cod_rubro,1,1) IN ('6','7')
                           and h.cod_rubro = a.cod_rubro
                           and h.cod_oficina = a.cod_oficina)
         and not exists (select 1
                           from cb_sal_inv_res_his m, ge_cuentas ge
                          where m.cod_rubro = a.cod_rubro
                            and m.nro_cuenta = ge.nro_cuenta
                            and m.periodo = v_periodo
                            and m.tipo IN ('AC','AM','AJ','DI','TA')
                            and m.cod_oficina = a.cod_oficina)
       group by a.cod_rubro, b.cod_moneda, a.cod_oficina;

  -- Insertamos monto negativo de los rubros que no estan en el balance -- --
  cursor c_eli_rubros_dia(p_fecha DATE)  is
      select a.cod_rubro, a.cod_oficina, 0 saldo_total, sum(nvl(a.sal_total,0)) saldo_tot_gs
        from cb_sal_inventarios a
       where substr(a.cod_rubro,1,1) IN ('6','7')
         and not exists (select 1
                           from cb_sal_oficinas b
                          where b.cod_oficina = a.cod_oficina
                            and b.cod_rubro   = a.cod_rubro
                         )
        group by a.cod_rubro, a.cod_oficina
        ;

  cursor c_eli_rubros_his(p_fecha DATE)  is
      select a.cod_rubro, a.cod_oficina, 0 saldo_total, sum(nvl(a.sal_total,0)) saldo_tot_gs
        from cb_sal_inv_procesos a
       where a.fecha = p_fecha
         and substr(a.cod_rubro,1,1) IN ('6','7')
         and not exists (select 1
                           from cb_sal_oficinas b
                          where b.cod_oficina = a.cod_oficina
                            and b.cod_rubro   = a.cod_rubro
                         )
        group by a.cod_rubro, a.cod_oficina
        ;

  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  FUNCTION fu_obt_mto_contable (p_cod_rubro   ge_movimientos.cod_rubro%type,
                                p_cod_oficina ge_movimientos.cod_oficina%type,
                                p_fecha       ge_movimientos.fecha%type)
  return number
  IS
   v_mto_contable                ge_movimientos.monto%type;
  BEGIN
    if v_fec_actual = v_fec_ant_mod_general then
        select nvl(sum(a.saldo_tot_gs),0)
          into v_mto_contable
          from cb_sal_inv_res_his a, ge_cuentas b
         where a.cod_rubro   = p_cod_rubro
           and a.nro_cuenta  = b.nro_cuenta
           and a.periodo = v_periodo
           and a.tipo  in ('AC','AM','AJ')
           and a.cod_oficina = p_cod_oficina
           and exists (select 1
                         from cb_sal_inventarios cb
                        where cb.cod_rubro = a.cod_rubro
                          and cb.cod_oficina = b.cod_oficina
                          and substr(cb.cod_rubro,1,1) IN ('6','7'));
      else
          select nvl(sum(a.saldo_tot_gs),0)
          into v_mto_contable
          from cb_sal_inv_res_his a, ge_cuentas b
         where a.cod_rubro   = p_cod_rubro
           and a.nro_cuenta  = b.nro_cuenta
           and a.periodo = v_periodo
           and a.tipo  in ('AC','AM','AJ')
           and a.cod_oficina = p_cod_oficina
           and exists (select 1
                         from cb_sal_inv_procesos cb
                        where cb.fecha = p_fecha
                          and cb.cod_rubro = a.cod_rubro
                          and cb.cod_oficina = b.cod_oficina
                          and substr(cb.cod_rubro,1,1) IN ('6','7'));
      end if;
         return v_mto_contable;
  EXCEPTION
     WHEN OTHERS THEN
        v_mto_contable := 0;
        return v_mto_contable;
  END;


  BEGIN
  -- OBTIENE EL TIPO DE CTA DE RESULTADO (AC = AJUSTE CONTABLES)---
  v_tip_cta := 'AC';

  if v_fec_actual = v_fec_ant_mod_general then
      v_hor_ini_proc := to_char(sysdate,'hh24:mi:ss');
      for reg in c_inventarios_dia(v_fec_actual) loop
        -- Obtengo el saldo contable
        begin
           begin
              select b.cod_moneda, a.cod_oficina,
                    sum((nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0))* -1),
                    sum((nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1)
                into v_cod_moneda,  v_cod_oficina, v_sal_local, v_sal_extranjero
                from cb_sal_oficinas a, cb_rubros b
               where a.cod_rubro   = b.cod_rubro
                 and a.cod_rubro   = reg.cod_rubro
                 and a.cod_oficina = reg.cod_oficina
                 and a.ano         = to_number(to_char(v_fec_actual,'YYYY'))
                 and a.mes         = to_number(to_char(v_fec_actual,'MM'))
               group by b.cod_moneda, a.cod_oficina;
           exception
              when others then
                 begin
                    select s.cod_moneda
                      into v_cod_moneda
                      from cb_rubros s
                     where s.cod_rubro = reg.cod_rubro;
                 exception
                    when others then
                       v_cod_moneda := v_cod_mon_local;
                 end;
                 v_cod_oficina:= reg.cod_oficina;
                 v_sal_local     := 0;
                 v_sal_extranjero:= 0;
           end;

          -- Comparo los montos para actualizar.
          v_nro_cuenta     := nvl(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina),'9999999999');
          v_dif_local      := 0;
          v_dif_extranjero := 0;
          v_mto_rubro      := nvl(reg.saldo_tot_gs,0) +  nvl(fu_obt_mto_contable(reg.cod_rubro, reg.cod_oficina, v_fec_actual),0);

          BEGIN
           --Obtiene los montos acumuldos anteriores
           SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
             INTO v_mto_ori_ant,v_mto_loc_ant
             FROM cb_sal_inv_res_his i
            WHERE i.cod_rubro    = reg.cod_rubro
              AND i.nro_cuenta  = v_nro_cuenta
              AND i.periodo     = v_periodo ;
          EXCEPTION
           WHEN no_data_found THEN
                v_mto_loc_ant:=0;
                v_mto_ori_ant:=0;
          END;

          -- Requerimiento: CNFDEEVO-29.
          -- Fecha: 03/03/2016.
          -- Cargamos en el historico
           v_dif_local := v_sal_local -  v_mto_rubro;
           begin
              if v_dif_local != 0 then
                 update cb_sal_inv_res_his cb
                    set cb.saldo_tot_gs = cb.saldo_tot_gs + v_dif_local
                  where cb.cod_rubro  = reg.cod_rubro
                    and cb.nro_cuenta = v_nro_cuenta
                    and cb.periodo    = v_periodo
                    and cb.tipo       = v_tip_cta
                    and cod_oficina   = reg.cod_oficina;

                 IF SQL%NOTFOUND THEN
                    insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                    values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, 0, v_dif_local, reg.cod_oficina);
                 END IF;
               end if;
           end;

          -- Cargamos en el inventario detallado --
          IF v_cod_moneda = v_cod_mon_local THEN

             v_mto_cotizacion := 1;

             v_sal_mon_local                := v_dif_local;
             v_sal_mon_extranjera            := 0;
             v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_dif_local,0);
             v_sal_acu_act_mon_extranjera    := 0;
          ELSE

             v_mto_cotizacion := fu_obt_cotizacion(v_cod_moneda, v_fec_actual);

             v_sal_mon_local                := v_dif_local;
             v_sal_mon_extranjera            := v_dif_extranjero;
             v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_dif_local,0);
             v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_dif_extranjero,0);
          END IF;

          -- Si existe el registro actualizar.
          UPDATE cb_sal_inv_res_contables_det d
             SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
                 d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
                 d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
                 d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
           WHERE cod_rubro   = reg.cod_rubro
             AND nro_cuenta  = v_nro_cuenta
             AND fecha       = v_fec_actual;
          -- Se inserta en la tabla de detalle diario.
          IF SQL%NOTFOUND THEN
           INSERT INTO cb_sal_inv_res_contables_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
           VALUES
            (v_fec_actual,reg.cod_rubro,v_nro_cuenta,v_mto_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
          END IF;

        exception
          when others then
           NULL;
        end;
      end loop;
      v_hor_fin_proc := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_RES .PR_AJU_RUB_CONTABLES','c_inventarios_dia', v_fec_actual, v_hor_ini_proc, v_hor_fin_proc);
   Else
      v_hor_ini_proc := to_char(sysdate,'hh24:mi:ss');
      for reg in c_inventarios_his(v_fec_actual) loop
      -- Obtengo el saldo contable
        begin
           begin
              select b.cod_moneda, a.ano, a.cod_oficina,
                    sum((nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0))* -1),
                    sum((nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1)
                into v_cod_moneda, v_periodo, v_cod_oficina, v_sal_local, v_sal_extranjero
                from cb_sal_oficinas a, cb_rubros b
               where a.cod_rubro   = b.cod_rubro
                 and a.cod_rubro   = reg.cod_rubro
                 and a.cod_oficina = reg.cod_oficina
                 and a.ano         = to_number(to_char(v_fec_actual,'YYYY'))
                 and a.mes         = to_number(to_char(v_fec_actual,'MM'))
               group by b.cod_moneda, ano, a.cod_oficina;
           exception
              when others then
                 begin
                    select s.cod_moneda
                      into v_cod_moneda
                      from cb_rubros s
                     where s.cod_rubro = reg.cod_rubro;
                 exception
                    when others then
                       v_cod_moneda := v_cod_mon_local;
                 end;
                 v_periodo    := to_char(v_fec_actual,'YYYY');
                 v_cod_oficina:= reg.cod_oficina;
                 v_sal_local     := 0;
                 v_sal_extranjero:= 0;
           end;

          -- Comparo los montos para actualizar.
          v_nro_cuenta     := nvl(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina),'9999999999');
          v_dif_local      := 0;
          v_dif_extranjero := 0;
          v_mto_rubro      := nvl(reg.saldo_tot_gs,0) + nvl(fu_obt_mto_contable(reg.cod_rubro, reg.cod_oficina, v_fec_actual),0);

          BEGIN
           --Obtiene los montos acumuldos anteriores
           SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
             INTO v_mto_ori_ant,v_mto_loc_ant
             FROM cb_sal_inv_res_his i
            WHERE i.nro_cuenta  = v_nro_cuenta
              AND i.cod_rubro    = reg.cod_rubro
              AND i.periodo     = v_periodo ;
          EXCEPTION
           WHEN no_data_found THEN
                v_mto_loc_ant:=0;
                v_mto_ori_ant:=0;
          END;

          -- Requerimiento: CNFDEEVO-29.
          -- Fecha: 03/03/2016.
          -- Cargamos en el historico
           v_dif_local := v_sal_local -  v_mto_rubro;
           begin
              if v_dif_local != 0 then
                 update cb_sal_inv_res_his cb
                    set cb.saldo_tot_gs = cb.saldo_tot_gs + v_dif_local
                  where cb.cod_rubro  = reg.cod_rubro
                    and cb.nro_cuenta = v_nro_cuenta
                    and cb.periodo    = v_periodo
                    and cb.tipo       = v_tip_cta
                    and cod_oficina   = reg.cod_oficina;

                 IF SQL%NOTFOUND THEN
                    insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                    values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, 0, v_dif_local, reg.cod_oficina);
                 END IF;
               end if;
           end;

          -- Cargamos en el inventario detallado --
          IF v_cod_moneda = v_cod_mon_local THEN

             v_mto_cotizacion := 1;

             v_sal_mon_local                := v_dif_local;
             v_sal_mon_extranjera            := 0;
             v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_dif_local,0);
             v_sal_acu_act_mon_extranjera    := 0;
          ELSE

             v_mto_cotizacion := fu_obt_cotizacion(v_cod_moneda, v_fec_actual);

             v_sal_mon_local                := v_dif_local;
             v_sal_mon_extranjera            := v_dif_extranjero;
             v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_dif_local,0);
             v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_dif_extranjero,0);
          END IF;

          -- Si existe el registro actualizar.
          UPDATE cb_sal_inv_res_contables_det d
             SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
                 d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
                 d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
                 d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
           WHERE cod_rubro   = reg.cod_rubro
             AND nro_cuenta  = v_nro_cuenta
             AND fecha       = v_fec_actual;
          -- Se inserta en la tabla de detalle diario.
          IF SQL%NOTFOUND THEN
           INSERT INTO cb_sal_inv_res_contables_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
           VALUES
            (v_fec_actual,reg.cod_rubro,v_nro_cuenta,v_mto_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
          END IF;

        exception
          when others then
           NULL;
        end;

      end loop;
     v_hor_fin_proc := to_char(sysdate,'hh24:mi:ss');
     prg_act_log_procesos('PAB_RES .PR_AJU_RUB_CONTABLES','c_inventarios_his', v_fec_actual, v_hor_ini_proc, v_hor_fin_proc);
  end if;
  -- Insertamos los saldos que estan en el balance pero no en el historico --
  if v_fec_actual = v_fec_ant_mod_general then
      v_hor_ini_proc := to_char(sysdate,'hh24:mi:ss');
      for reg in c_balance_dia(v_fec_actual) loop
             -- Obtengo el saldo contable.
             begin
                -- Comparo los montos para actualizar.
                v_nro_cuenta := nvl(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,reg.cod_moneda,reg.cod_oficina),'9999999999');

                -- Requerimiento: CNFDEEVO-29.
                -- Fecha: 03/03/2016.
                if reg.cod_moneda = v_cod_mon_local then
                   v_mto_cotizacion := 1;

                   insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                   values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, 0, reg.mto_local, reg.cod_oficina);
                else
                   v_mto_cotizacion := fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);

                   insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                   values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, reg.mto_extranjera, reg.mto_local, reg.cod_oficina);
                end if;

                -- Si existe el registro actualizar.
                UPDATE cb_sal_inv_res_contables_det d
                   SET d.sal_mon_extranjera         = d.sal_mon_extranjera + reg.mto_extranjera,
                       d.sal_mon_local              = d.sal_mon_local + reg.mto_local,
                       d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + reg.mto_extranjera,
                       d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + reg.mto_local
                 WHERE cod_rubro   = reg.cod_rubro
                   AND nro_cuenta  = v_nro_cuenta
                   AND fecha       = v_fec_actual;

                -- Se inserta en la tabla de detalle diario.
                IF SQL%NOTFOUND THEN
                 INSERT INTO cb_sal_inv_res_contables_det
                  (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
                   sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
                 VALUES
                  (v_fec_actual,reg.cod_rubro,v_nro_cuenta,v_mto_cotizacion,reg.mto_extranjera,reg.mto_local,
                   reg.mto_extranjera, reg.mto_local);
                END IF;

             exception
                when others then
                   null;
             end;
           end loop;
          v_hor_fin_proc := to_char(sysdate,'hh24:mi:ss');
          prg_act_log_procesos('PAB_RES .PR_AJU_RUB_CONTABLES','c_inventarios_dia', v_fec_actual, v_hor_ini_proc, v_hor_fin_proc);
       else
           v_hor_ini_proc := to_char(sysdate,'hh24:mi:ss');
           for reg in c_balance_his(v_fec_actual) loop
          -- Obtengo el saldo contable.
         begin
            -- Comparo los montos para actualizar.
            v_nro_cuenta := nvl(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,reg.cod_moneda,reg.cod_oficina),'9999999999');

            -- Requerimiento: CNFDEEVO-29.
            -- Fecha: 03/03/2016.
            if reg.cod_moneda = v_cod_mon_local then
               v_mto_cotizacion := 1;

               insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
               values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, 0, reg.mto_local, reg.cod_oficina);
            else
               v_mto_cotizacion := fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);

               insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
               values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, reg.mto_extranjera, reg.mto_local, reg.cod_oficina);
            end if;

            -- Si existe el registro actualizar.
            UPDATE cb_sal_inv_res_contables_det d
               SET d.sal_mon_extranjera         = d.sal_mon_extranjera + reg.mto_extranjera,
                   d.sal_mon_local              = d.sal_mon_local + reg.mto_local,
                   d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + reg.mto_extranjera,
                   d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + reg.mto_local
             WHERE cod_rubro   = reg.cod_rubro
               AND nro_cuenta  = v_nro_cuenta
               AND fecha       = v_fec_actual;

            -- Se inserta en la tabla de detalle diario.
            IF SQL%NOTFOUND THEN
             INSERT INTO cb_sal_inv_res_contables_det
              (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
               sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
             VALUES
              (v_fec_actual,reg.cod_rubro,v_nro_cuenta,v_mto_cotizacion,reg.mto_extranjera,reg.mto_local,
               reg.mto_extranjera, reg.mto_local);
            END IF;

         exception
            when others then
               null;
         end;
       end loop;
       v_hor_fin_proc := to_char(sysdate,'hh24:mi:ss');
       prg_act_log_procesos('PAB_RES .PR_AJU_RUB_CONTABLES','c_balance_his', v_fec_actual, v_hor_ini_proc, v_hor_fin_proc);

   end if;

   -- Insertamos monto negativo de los rubros que no estan en el balance --
   if v_fec_actual = v_fec_ant_mod_general then
       v_hor_ini_proc := to_char(sysdate,'hh24:mi:ss');
       for reg in c_eli_rubros_dia(v_fec_actual) loop

          -- Obtengo la moneda del rubro.
          begin
             select cb.cod_moneda
               into v_cod_moneda
               from cb_rubros cb
              where cb.cod_rubro = reg.cod_rubro;
          exception
             when others then
                v_cod_moneda := v_cod_mon_local;
          end;

          v_nro_cuenta := nvl(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,reg.cod_oficina),'9999999999');

          v_mto_rubro  := nvl(reg.saldo_tot_gs,0) + nvl(fu_obt_mto_contable(reg.cod_rubro, reg.cod_oficina, v_fec_actual),0);

        -- insertamos en el detalle contable en negativo el monto
         begin
             -- Si existe el registro actualizar.
              UPDATE cb_sal_inv_res_contables_det d
                 SET d.sal_mon_extranjera         = d.sal_mon_extranjera + 0,
                     d.sal_mon_local              = d.sal_mon_local + (v_mto_rubro * -1)
               WHERE cod_rubro   = reg.cod_rubro
                 AND nro_cuenta  = v_nro_cuenta
                 AND fecha       = v_fec_actual;
              -- Se inserta en la tabla de detalle diario.
              IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inv_res_contables_det
                (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
                 sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
               VALUES
                (v_fec_actual,reg.cod_rubro,v_nro_cuenta,1,0,(v_mto_rubro * -1),0,0);
              END IF;

           -- Insertamos en el historico los montos en negativo
           update cb_sal_inv_res_his cb
              set cb.saldo_tot_gs = cb.saldo_tot_gs + (v_mto_rubro * -1),
                  cb.saldo_total  = cb.saldo_total + 0
            where cb.cod_rubro  = reg.cod_rubro
              and cb.nro_cuenta = v_nro_cuenta
              and cb.periodo    = v_periodo
              and cb.tipo       = v_tip_cta
              and cb.cod_oficina = reg.cod_oficina;

           IF SQL%NOTFOUND THEN
              insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                     values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, 0, (v_mto_rubro * -1), reg.cod_oficina);
           END IF;

         exception
           when others then
                NULL;
        end;

       end loop;
        v_hor_fin_proc := to_char(sysdate,'hh24:mi:ss');
        prg_act_log_procesos('PAB_RES .PR_AJU_RUB_CONTABLES','c_rubros_dia', v_fec_actual, v_hor_ini_proc, v_hor_fin_proc);
   else
       v_hor_ini_proc := to_char(sysdate,'hh24:mi:ss');
       for reg in c_eli_rubros_his(v_fec_actual) loop

          -- Obtengo la moneda del rubro.
          begin
             select cb.cod_moneda
               into v_cod_moneda
               from cb_rubros cb
              where cb.cod_rubro = reg.cod_rubro;
          exception
             when others then
                v_cod_moneda := v_cod_mon_local;
          end;

          v_nro_cuenta := nvl(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,reg.cod_oficina),'9999999999');

          v_mto_rubro  := nvl(reg.saldo_tot_gs,0) + nvl(fu_obt_mto_contable(reg.cod_rubro, reg.cod_oficina, v_fec_actual),0);

        -- insertamos en el detalle contable en negativo el monto
         begin
             -- Si existe el registro actualizar.
              UPDATE cb_sal_inv_res_contables_det d
                 SET d.sal_mon_extranjera         = d.sal_mon_extranjera + 0,
                     d.sal_mon_local              = d.sal_mon_local + (v_mto_rubro * -1)
               WHERE cod_rubro   = reg.cod_rubro
                 AND nro_cuenta  = v_nro_cuenta
                 AND fecha       = v_fec_actual;
              -- Se inserta en la tabla de detalle diario.
              IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inv_res_contables_det
                (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
                 sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
               VALUES
                (v_fec_actual,reg.cod_rubro,v_nro_cuenta,1,0,(v_mto_rubro * -1),0,0);
              END IF;

           -- Insertamos en el historico los montos en negativo
           update cb_sal_inv_res_his cb
              set cb.saldo_tot_gs = cb.saldo_tot_gs + (v_mto_rubro * -1),
                  cb.saldo_total  = cb.saldo_total + 0
            where cb.cod_rubro  = reg.cod_rubro
              and cb.nro_cuenta = v_nro_cuenta
              and cb.periodo    = v_periodo
              and cb.tipo       = v_tip_cta
              and cb.cod_oficina = reg.cod_oficina;

           IF SQL%NOTFOUND THEN
              insert into cb_sal_inv_res_his(cod_rubro,nro_cuenta,periodo,tipo,saldo_total,saldo_tot_gs,cod_oficina)
                     values (reg.cod_rubro, v_nro_cuenta, v_periodo, v_tip_cta, 0, (v_mto_rubro * -1), reg.cod_oficina);
           END IF;

         exception
           when others then
                NULL;
        end;

       end loop;
       v_hor_fin_proc := to_char(sysdate,'hh24:mi:ss');
       prg_act_log_procesos('PAB_RES .PR_AJU_RUB_CONTABLES','c_eli_rubros_his', v_fec_actual, v_hor_inicio, v_hor_fin_proc);
   end if;

  EXCEPTION
     WHEN OTHERS THEN
        ROLLBACK;
        raise_application_error(-20000, 'ERROR PR_AJU_RUB_CONTABLES: ' ||v_nro_cuenta|| SQLERRM);
  END PR_AJU_RUB_CONTABLES;
 -----------------------------------------------------------------------------------------------------------

 -----------------------------------------------------------------------------------------------------------
  -- Acumulacion de Inventario Contable
  PROCEDURE PR_ACU_INV_CONTABLES IS
    -- Variables.
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_modulo                 cb_sal_inv_contables.cod_modulo%TYPE;
    v_cod_modalidad              cb_sal_inv_contables.cod_modalidad%TYPE;
    v_cod_oficina                cb_sal_inv_contables.cod_oficina%TYPE;
    v_cod_sec_contable           cb_sal_inv_contables.cod_sec_contable%TYPE;
    v_cod_tip_deudor             cb_sal_inv_contables.cod_tip_deudor%TYPE;
    v_residente                  cb_sal_inv_contables.residente%TYPE;
    v_cod_plazo                  cb_sal_inv_contables.cod_plazo%TYPE;
    v_tip_operacion              cb_sal_inv_contables.tip_operacion%TYPE;
    v_tip_interes                cb_sal_inv_contables.tip_interes%TYPE;
    v_nro_referencia             cb_sal_inv_contables.nro_referencia%TYPE;
    v_saldo_acumulado            cb_sal_inv_contables.sal_total%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_tip_saldo                  VARCHAR2(01);
    v_cod_rubro                  VARCHAR2(15);

  --
  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  CURSOR c_mov_inventario(p_fecha DATE) IS
     SELECT g.cod_modulo,
            g.cod_modalidad,
            NVL(h.cod_oficina,g.cod_oficina),
            g.cod_moneda,
            c.cod_sec_contable,
            c.residente,
            c.cod_tip_deudor,
            to_char(1) cod_plazo,
            h.cod_rubro,
            sum(nvl(h.saldo_tot_gs,0))
       FROM cb_sal_inv_res_his h,
            ge_cuentas g,
            ge_clientes      c,
            ge_cta_clientes  cc
      WHERE h.nro_cuenta    = g.nro_cuenta
        AND h.periodo       = v_periodo
        AND h.tipo          IN ('AM','AC','AJ','DI','TA')  -- Asientos Manuales,Ajustes Contables, DI, Trading.
        AND g.nro_cuenta    = cc.nro_cuenta
        AND cc.relacion     = 'P'
        AND c.cod_persona   = cc.cod_persona
        group by g.cod_modulo,
            g.cod_modalidad,
            NVL(h.cod_oficina,g.cod_oficina),
            g.cod_moneda,
            c.cod_sec_contable,
            c.residente,
            c.cod_tip_deudor,
            to_char(1),
            h.cod_rubro;

  BEGIN
  -- Transladamos los datos al historico antes de truncar la tabla
  EXECUTE IMMEDIATE ('insert into cb_sal_inv_contables_his (select '''||v_fec_anterior||''', c.* from cb_sal_inv_contables c)');
  EXECUTE IMMEDIATE ('insert into cb_sal_inv_contables_det_his (select d.*, '''||v_fec_anterior||''' from cb_sal_inv_contables_det d)');
  EXECUTE IMMEDIATE ('truncate table cb_sal_inv_contables');
  EXECUTE IMMEDIATE ('truncate table cb_sal_inv_contables_det');

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_inventario%ISOPEN THEN
      CLOSE c_mov_inventario;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN c_mov_inventario (v_fec_actual);
    LOOP
      FETCH c_mov_inventario
        INTO v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             v_cod_moneda,
             v_cod_sec_contable,
             v_residente,
             v_cod_tip_deudor,
             v_cod_plazo,
             v_cod_rubro,
             v_saldo_acumulado;
    EXIT WHEN c_mov_inventario%NOTFOUND;

      -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
      v_tip_saldo := 'K';
      --------------------------------------------------------------

      -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
      v_tip_interes := 'X';
      --------------------------------------------------------------

      -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
      v_tip_operacion := 'X';
      --------------------------------------------------------------

      ------------------------------
      -- INSERTA MONTO DEVENGADO --
      ------------------------------
      SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

      INSERT INTO cb_sal_inv_contables
          (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
           residente, cod_moneda, tip_saldo, cod_plazo, tip_operacion,
           tip_interes, sal_total, cod_rubro, nro_referencia)
       VALUES
          (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
           v_cod_tip_deudor, v_residente, v_cod_moneda, v_tip_saldo,
           v_cod_plazo, v_tip_operacion, v_tip_interes, nvl(v_saldo_acumulado,0), v_cod_rubro,
           v_nro_referencia);

    END LOOP;
    CLOSE c_mov_inventario;

      INSERT INTO cb_sal_inv_contables_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
          SELECT x.nro_referencia, h.nro_cuenta, sum(nvl(h.saldo_tot_gs,0)), sum(0)
                 FROM cb_sal_inv_res_his h, ge_cuentas g, ge_clientes c, ge_cta_clientes  cc, cb_sal_inv_contables x
                WHERE h.nro_cuenta    = g.nro_cuenta
                  AND h.periodo       = v_periodo
                  AND h.tipo          IN ('AM','AC','AJ','DI','TA')  -- Asientos Manuales,Ajustes Contables, DI, Trading.
                  AND g.nro_cuenta    = cc.nro_cuenta
                  AND cc.relacion     = 'P'
                  AND c.cod_persona   = cc.cod_persona
                  ---
                  and g.cod_modulo = x.cod_modulo
                  and g.cod_modalidad = x.cod_modalidad
                  and NVL(h.cod_oficina,g.cod_oficina) = x.cod_oficina
                  and c.cod_sec_contable = x.cod_sec_contable
                  and c.cod_tip_deudor = x.cod_tip_deudor
                  and c.residente = x.residente
                  and g.cod_moneda = x.cod_moneda
                  and to_char(1) = x.cod_plazo
                  and h.cod_rubro = x.cod_rubro
                  and x.tip_saldo = 'K'
                  and x.tip_interes = 'X'
                  and x.tip_operacion = 'X'
          group by x.nro_referencia, h.nro_cuenta;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_INV_CONTABLES: ' || SQLERRM);
  END PR_ACU_INV_CONTABLES;

  BEGIN
      --Carga de Variables--
      v_fec_actual            := pag_cal.FU_OBT_FEC_ACTUAL(2);
      v_fec_anterior          := pag_cal.FU_OBT_FEC_ANTERIOR(2);
      v_periodo               := trim(to_char(v_fec_actual,'yyyy'));
      v_anho                  := to_char(v_fec_actual,'yyyy');
      v_mes                   := to_char(v_fec_actual,'mm');
      pag_cal.PR_OBT_DAT_CALENDAR(2);
      v_ult_dia_mes_habil     := pag_cal.G_ULT_DIA_MES_HABIL;
      v_val_cot_usd           := pag_gen.fu_obt_cotizacion('USD', v_fec_actual);
      v_val_cot_eur           := pag_gen.fu_obt_cotizacion('EUR', v_fec_actual);
      v_cod_mon_local         := pag_gen.fu_obt_mon_local;
      v_fec_ant_mod_general   := pag_cal.FU_OBT_FEC_ANTERIOR(1);

      --Veritica si insertara temporal--
      if v_fec_actual <> v_fec_ant_mod_general then
         prg_ins_tab_procesos(v_fec_actual);
      end if;

      --Procesamiento de Datos--
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_ASI_MANUALES;        -- Asientos Manuales
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_RES ','PR_ACU_ASI_MANUALES', v_fec_actual, v_hor_inicio, v_hor_fin);

      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_DEP_INTERNOS;        -- Depositos Internos.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_RES ','PR_ACU_DEP_INTERNOS', v_fec_actual, v_hor_inicio, v_hor_fin);

      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_TRADING;             -- Trading.
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_RES ','PR_ACU_TRADING', v_fec_actual, v_hor_inicio, v_hor_fin);

      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_REV_MOV_INVENTARIOS;     -- Reverso mov. por error de parametrización
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_RES ','PR_REV_MOV_INVENTARIOS', v_fec_actual, v_hor_inicio, v_hor_fin);

      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_AJU_RUB_CONTABLES;       -- Ajuste de Saldos de Rubros Contables
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_RES ','PR_AJU_RUB_CONTABLES', v_fec_actual, v_hor_inicio, v_hor_fin);

      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      PR_ACU_INV_CONTABLES;       -- Acumulacion de Inventario Contable
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos('PAB_RES ','PR_ACU_INV_CONTABLES', v_fec_actual, v_hor_inicio, v_hor_fin);

   END;

-- obtiene el codigo de rubro que corresponde a una cuenta
  FUNCTION FU_OBT_RUBRO
     (
        p_cod_modulo       IN NUMBER,
        p_cod_modalidad    IN NUMBER,
        p_cod_transaccion  IN NUMBER,
        p_cod_moneda       IN VARCHAR2,
        p_cod_sec_contable IN VARCHAR2,
        p_cod_tip_deudor   IN NUMBER,
        p_residente        IN VARCHAR2,
        p_cod_plazo        IN VARCHAR2,
        p_tip_movimiento   IN VARCHAR2,
        p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
        p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
        p_cat_automatica   IN NUMBER DEFAULT NULL,
        p_tip_interes      IN VARCHAR2 DEFAULT NULL,
        p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
        p_cod_sit_contable IN NUMBER DEFAULT NULL,
        p_cod_sec_credito  IN NUMBER DEFAULT NULL
     )
     RETURN VARCHAR2 IS
        v_cod_rubro        ge_tip_asientos.cod_rubro%TYPE;
        v_cod_tip_asiento  ge_transacciones.cod_tip_asiento%TYPE;
        v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%TYPE;
        v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
        v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
        v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
        v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
  BEGIN
        /* busco la transaccion que le corresponde */
        SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
          INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
          FROM ge_modalidades mo, ge_transacciones tr
         WHERE tr.cod_modulo      = p_cod_modulo
           AND tr.cod_modalidad   = p_cod_modalidad
           AND tr.cod_transaccion = p_cod_transaccion
           AND mo.cod_modulo      = p_cod_modulo
           AND mo.cod_modalidad   = p_cod_modalidad;

        /* busco la cuenta contable que le corresponde (Ganancia o perdida) */
          SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
            INTO v_ind_plazo, v_ind_deudor, v_cod_rubro, v_ind_producto
            FROM ge_tip_asientos
           WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
             AND cod_moneda = p_cod_moneda
             AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
             AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
             AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
             and ((nvl(p_tip_cuenta, 'x') = 'B' and tip_cuenta = p_tip_cuenta) or
                  (nvl(p_tip_cuenta, 'x') <> 'B' and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)))
             AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
             AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
             AND (ind_residente = 'X' OR ind_residente = p_residente)
             AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
             AND tip_movimiento = p_tip_movimiento
             AND substr(cod_rubro,1,1) IN ('6','7')
             AND nro_linea =
                 (SELECT MIN(nro_linea)
                    FROM ge_tip_asientos
                   WHERE cod_tip_asiento = v_cod_tip_asiento
                     AND cod_moneda = p_cod_moneda
                     AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
                     AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
                     AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
                     AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
                     AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
                     AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
                     AND (ind_residente = 'X' OR ind_residente = p_residente)
                     AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
                     AND tip_movimiento = p_tip_movimiento);

        IF v_ind_plazo = 'S' THEN
           v_cod_rubro := substr(v_cod_rubro, 1, 2) || p_cod_plazo || substr(v_cod_rubro, 4, 12);
        END IF;
        IF v_ind_deudor = 'S' OR substr(v_cod_rubro, 9, 2) = 'TD' THEN
           v_cod_rubro := substr(v_cod_rubro, 1, 8) || (ltrim(to_char(p_cod_tip_deudor, '00'))) ||
                          substr(v_cod_rubro, 11, 5);
        END IF;
        ---Reemplaza el codigo del producto -----------------------
        IF v_ind_producto = 'S' THEN
           v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                          substr(v_cod_rubro, 14, 2);
        END IF;
        IF substr(v_cod_rubro, 11, 3) = 'SEC' THEN
           -- es solo para prestamos, para contabilizar por sector
           v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                          ltrim(to_char(fup_obt_sec_rubro(p_cod_sec_credito), '000')) ||
                          substr(v_cod_rubro, 14, 2);
        END IF;

        RETURN v_cod_rubro;

  EXCEPTION
        WHEN OTHERS THEN
           v_cod_rubro := 0;
           RETURN v_cod_rubro;
  END FU_OBT_RUBRO;

-- Funciones.
  -- Fecha: 12/08/2014.
  -- Requerimiento: CNFIRGTR-2.
  -- Obtiene la cuenta del cliente en base al código de persona.
  FUNCTION FU_OBT_NRO_CUENTA(p_cod_persona ge_movimientos.cod_persona%type)
  RETURN VARCHAR2
  AS
  v_nro_cuenta     ge_movimientos.nro_cuenta%type;
  BEGIN
     SELECT v.nro_cuenta
       INTO v_nro_cuenta
       FROM (
            SELECT a.nro_cuenta, (case when a.cod_modulo = 4 then 1 else 2 end) orden
              FROM ge_cuentas a, ge_cta_clientes b
             WHERE a.nro_cuenta  = b.nro_cuenta
               AND b.cod_persona = p_cod_persona
               AND a.cod_modulo in (3,4)
               AND b.relacion = 'P'
               AND a.estado not in ('A', 'C', 'X')
            UNION
            SELECT a.nro_cuenta, 3 orden
              FROM ge_cuentas a, ge_cta_clientes b
             WHERE a.nro_cuenta  = b.nro_cuenta
               AND b.cod_persona = p_cod_persona
               AND a.cod_modulo = 6
               AND b.relacion = 'P'
               AND a.estado not in ('N', 'I')
             UNION
             SELECT a.nro_cuenta, (case when a.cod_modulo = 5 then 4 else 5 end) orden
              FROM ge_cuentas a, ge_cta_clientes b
             WHERE a.nro_cuenta  = b.nro_cuenta
               AND b.cod_persona = p_cod_persona
               AND a.cod_modulo in (5,15)
               AND b.relacion = 'P'
               AND a.estado not in ('A', 'C', 'X')
             ORDER BY 2
            ) v
      WHERE rownum = 1;
      --
      RETURN v_nro_cuenta;
  EXCEPTION
     WHEN OTHERS THEN
       v_nro_cuenta := NULL;
       return v_nro_cuenta;
  END;
-----------------------------------------------------------------------------------------------------------

-- Devengados de Prestamos
  PROCEDURE PR_ACU_DEV_PRESTAMOS IS
    -- fechas --
    v_fec_actual          ge_calendarios.fec_actual%TYPE;
    -- monedad local --
    v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    -- variables ----
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable     cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor       cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente            cb_sal_inventarios.residente%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_situacion            cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_mont_dev             cb_sal_inventarios.sal_total%TYPE;
    v_tip_renovacion       cb_sal_inventarios.tip_renovacion%TYPE;
    v_cat_automatica       cb_sal_inventarios.cat_automatica%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local        cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_cod_sec_credito      pr_cta_prestamos.cod_sec_credito%TYPE;
    v_est_cuenta           pr_devengados.estado%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo            VARCHAR2(01);
    v_cod_transaccion      NUMBER(05);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);
    v_tip_movimiento      VARCHAR2(01);

    ------------------------- DEFINE MOVIMIEN HIS -----------------------------
    CURSOR movimien_his (p_fecha DATE) IS
      SELECT ct.cod_oficina,
             ct.cod_modulo,
             ct.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             ct.cod_moneda,
             to_char(nvl(pc.cod_plazo,0)),
             ct.tipo tip_operacion,
             ct.tip_interes,
             nvl(ct.tip_renovacion, 'A') tip_renovacion,
             d.categoria cat_automatica,
             ct.cod_sec_credito,
             d.estado est_cuenta,
             d.nro_cuenta,
             to_char(d.fecha,'YYYY') periodo,
             SUM(nvl(d.mto_dev_actual, 0))mto_dev_actual
        FROM ge_plz_contables pc,
             pr_devengados    d,
             pr_cta_prestamos ct,
             ge_clientes      c,
             ge_cta_clientes  cc,
             ge_modalidades   mo
       WHERE d.fecha          = p_fecha
         AND d.nro_cuenta     = ct.nro_cuenta
         AND d.nro_cuenta     = cc.nro_cuenta
         AND d.tipo <> 'S'
         AND cc.relacion      = 'P'
         AND c.cod_persona    = cc.cod_persona
         AND mo.cod_modulo    = ct.cod_modulo
         AND mo.cod_modalidad = ct.cod_modalidad
         AND d.mto_dev_actual <> 0
         AND pc.can_dias =
            (SELECT MIN(can_dias)
               FROM ge_plz_contables
              WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
    GROUP BY ct.cod_oficina,
             ct.cod_modulo,
             ct.cod_modalidad,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             ct.cod_moneda,
             to_char(nvl(pc.cod_plazo,0)),
             ct.tipo,
             ct.tip_interes,
             nvl(ct.tip_renovacion, 'A'),
             d.categoria,
             ct.cod_sec_credito,
             d.estado,
             d.nro_cuenta,
             to_char(d.fecha,'YYYY')
        ;

  ------------------------- DEFINE MOVIMIEN DEV -----------------------------
    -- Requerimiento: CNFDEEVO-29.
    -- Fecha: 03/03/2016.
    CURSOR movimien_dev (p_fecha DATE) IS
      SELECT ct.cod_modulo,
             ct.cod_modalidad,
             NVL(h.cod_oficina,ct.cod_oficina),
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             ct.cod_moneda,
             ct.est_batch situacion,
             pc.cod_plazo,
             ct.tipo tip_operacion,
             ct.tip_interes,
             nvl(ct.tip_renovacion, 'A') tip_renovacion,
             ct.cod_sec_credito,
             h.Saldo_Tot_Gs,
             h.cod_rubro,
             h.nro_cuenta,
             nvl(c.cat_riesgo, 1) cat_automatico
        FROM ge_plz_contables pc,
             cb_sal_inv_res_his h,
             pr_cta_prestamos ct,
             ge_clientes      c,
             ge_cta_clientes  cc,
             ge_modalidades   mo
       WHERE h.nro_cuenta     = ct.nro_cuenta
         AND h.nro_cuenta     = cc.nro_cuenta
         AND h.tipo           = 'DE'
         AND cc.relacion      = 'P'
         AND c.cod_persona    = cc.cod_persona
         AND mo.cod_modulo    = ct.cod_modulo
         AND mo.cod_modalidad = ct.cod_modalidad
         AND h.periodo        = to_char(p_fecha,'YYYY')
         AND pc.can_dias =
             (SELECT MIN(can_dias)
             FROM ge_plz_contables
             WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
      ;
  BEGIN



    --Obtiene la Fecha necesarias----------------------
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    -----------------------------------------------------

    -- Cerramos el cursor si se encuentra abierto -------
    IF movimien_his%ISOPEN THEN
      CLOSE movimien_his;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN movimien_his (v_fec_actual);
    LOOP
      FETCH movimien_his
        INTO v_cod_oficina,
             v_cod_modulo,
             v_cod_modalidad,
             v_cod_sec_contable,
             v_cod_tip_deudor,
             v_residente,
             v_cod_moneda,
             v_cod_plazo,
             v_tip_operacion,
             v_tip_interes,
             v_tip_renovacion,
             v_cat_automatica,
             v_cod_sec_credito,
             v_est_cuenta,
             v_nro_cuenta,
             v_periodo,
             v_mont_dev;
      EXIT WHEN movimien_his%NOTFOUND;

      -- OBTIENE EL TIPO DE CTA DE RESULTADO (DE=DEVENGADO)---
      v_tip_cta := 'DE';
      --------------------------------------------------------------

      -- OBTIENE EL TIPO DE MOVIMIENTO ----------------------------
      v_tip_movimiento := 'C';
      --------------------------------------------------------------

      --- OBTIENE EL CODIGO DE TRANSACCION ----
      v_cod_transaccion := 901;
      --------------------------------------------------------------

      --- OBTENEMOS EL RUBRO CONTABLE ----
      v_cod_rubro := FU_OBT_RUBRO (v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cod_plazo,
                                   v_tip_movimiento, v_est_cuenta, v_tip_renovacion, v_cat_automatica,
                                   v_tip_interes, v_tip_operacion, null, v_cod_sec_credito);
      --------------------------------------------------------------

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO
      BEGIN

        -- Recuperamos el monto acumulado anterior de la cuenta
        BEGIN
          SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
            INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
            FROM cb_sal_inv_res_his h
           WHERE h.cod_rubro   = v_cod_rubro
             AND h.nro_cuenta = v_nro_cuenta
             AND h.periodo     = to_char(v_fec_actual,'YYYY') ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_saldo_tot_acu    := 0;
            v_saldo_tot_gs_acu := 0;
        END;

        ---- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
        IF v_cod_moneda = v_cod_mon_local THEN
           -- es moneda nacional GS --
           v_mto_cotizacion    := 1;
           v_saldo_total       := 0;
           v_saldo_tot_gs      := v_mont_dev;

           v_sal_mon_local       := v_saldo_tot_gs;                       -- saldo moneda local
           v_sal_mon_extranjera   := 0;                                  -- saldo moneda extranjera
           v_sal_mon_loc_actual  := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
           v_sal_mon_ext_actual  := 0;                                  -- saldo acumulado actual extranjero
        ELSE
           -- Moneda extranjera
           -- Obtiene la cotizacion de cierre
           v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
           -- Cargamos las variables
           v_saldo_total    := v_mont_dev;
           v_saldo_tot_gs   := v_mont_dev * v_mto_cotizacion;

           v_sal_mon_local       := v_saldo_tot_gs;                         -- saldo moneda local
           v_sal_mon_extranjera   := v_saldo_total;                         -- saldo moneda extranjera
           v_sal_mon_loc_actual  := (v_saldo_tot_gs_acu + v_saldo_tot_gs); -- saldo acumulado actual local
           v_sal_mon_ext_actual  := (v_saldo_tot_acu + v_saldo_total);      -- saldo acumulado actual extranjero
        END IF;
          -----------------------------------------------------------------------------

         -- Actualizamos la tabla detallada de Inventario de Resultados
         UPDATE cb_sal_inv_resultados_det
            SET sal_mon_extranjera          = sal_mon_extranjera + v_sal_mon_extranjera,
                sal_mon_local                = sal_mon_local + v_sal_mon_local,
                sal_acu_act_mon_extranjera  = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
                sal_acu_act_mon_local        = sal_acu_act_mon_local + v_sal_mon_local
          WHERE fecha      = v_fec_actual
            AND cod_rubro  = v_cod_rubro
            AND nro_cuenta = v_nro_cuenta;

         IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el detalle
           INSERT INTO cb_sal_inv_resultados_det
                (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
                 sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
           VALUES
                (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
                 v_sal_mon_ext_actual, v_sal_mon_loc_actual);
         END IF;

         -- Requerimiento: CNFDEEVO-29.
         -- Fecha: 03/03/2016.
         --Actualizamos la tabla historico
         UPDATE cb_sal_inv_res_his
            SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
                saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
          WHERE cod_rubro   = v_cod_rubro
            AND nro_cuenta  = v_nro_cuenta
            AND periodo      = v_periodo
            AND tipo        = v_tip_cta
            AND cod_oficina = v_cod_oficina;

         IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el historico
           INSERT INTO cb_sal_inv_res_his
                (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
           VALUES
                (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
         END IF;
      END;
    END LOOP;
    CLOSE movimien_his;

    -- Cerramos el cursor si se encuentra abierto -------
    IF movimien_dev%ISOPEN THEN
      CLOSE movimien_dev;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN movimien_dev (v_fec_actual);
    LOOP
      FETCH movimien_dev
       INTO v_cod_modulo,
            v_cod_modalidad,
            v_cod_oficina,
            v_cod_sec_contable,
            v_cod_tip_deudor,
            v_residente,
            v_cod_moneda,
            v_situacion,
            v_cod_plazo,
            v_tip_operacion,
            v_tip_interes,
            v_tip_renovacion,
            v_cod_sec_credito,
            v_saldo_acumulado,
            v_cod_rubro,
            v_nro_cuenta,
            v_cat_automatica;
      EXIT WHEN movimien_dev%NOTFOUND;

      -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
       v_tip_saldo := 'K'; -- Inventario de Ctas de Resultado
      --------------------------------------------------------------

      -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
      BEGIN
          SELECT nro_referencia, ROWID
            INTO v_nro_referencia, v_rowid
            FROM cb_sal_inventarios
           WHERE cod_modulo       = v_cod_modulo
             AND cod_modalidad    = v_cod_modalidad
             AND cod_oficina      = v_cod_oficina
             AND cod_sec_contable = v_cod_sec_contable
             AND cod_tip_deudor   = v_cod_tip_deudor
             AND residente        = v_residente
             AND cod_moneda       = v_cod_moneda
             AND situacion        = v_situacion
             AND tip_saldo        = v_tip_saldo
             AND cod_plazo        = v_cod_plazo
             AND tip_operacion    = v_tip_operacion
             AND tip_interes      = v_tip_interes
             AND tip_renovacion   = v_tip_renovacion
             AND cat_automatica   = v_cat_automatica
             AND cod_sit_contable = fup_obt_sec_rubro(v_cod_sec_credito)
             AND cod_rubro        = v_cod_rubro;

         IF v_nro_referencia IS NOT NULL THEN
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(v_saldo_acumulado, 0)
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            --------------Genero detalle----------------
            UPDATE cb_sal_inventarios_det
               SET sal_anterior = nvl(sal_actual, 0),
                   sal_actual   = nvl(sal_actual, 0) + nvl(v_saldo_acumulado, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta     = v_nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                 (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                 (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0), 0);
            END IF;
         END IF;
      EXCEPTION
        WHEN no_data_found THEN

           ------------------------------
           -- INSERTA MONTO DEVENGADO --
           ------------------------------
           SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

           INSERT INTO cb_sal_inventarios
            (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
             residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
             tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
             cat_automatica, cod_sit_contable)
           VALUES
            (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
             v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
             v_cod_plazo, v_tip_operacion, v_tip_interes, nvl(v_saldo_acumulado, 0), v_cod_rubro,
             v_nro_referencia, v_tip_renovacion, v_cat_automatica,
             fup_obt_sec_rubro(v_cod_sec_credito));

           INSERT INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
           VALUES
            (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0),0 );
      END;
    END LOOP;
    CLOSE movimien_dev;


  EXCEPTION
    WHEN OTHERS THEN
         ROLLBACK;
         raise_application_error(-20000, 'ERROR PR_ACU_DEV_PRESTAMOS: ' || SQLERRM);
  END PR_ACU_DEV_PRESTAMOS;
-----------------------------------------------------------------------------------------------------

-- Montos Devengados de Mesa de Dinero
  PROCEDURE PR_ACU_DEV_MESA_DINERO IS
    -- fechas --
    v_fec_actual          ge_calendarios.fec_actual%TYPE;
    -- monedad local --
    v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    -- variables ----
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable     cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor       cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente            cb_sal_inventarios.residente%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_situacion            cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_mont_dev             cb_sal_inventarios.sal_total%TYPE;
    v_tip_renovacion       cb_sal_inventarios.tip_renovacion%TYPE;
    v_cat_automatica       cb_sal_inventarios.cat_automatica%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local        cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_cod_sit_contable     md_cta_documentos.cod_sit_contable%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo            VARCHAR2(01);
    v_cod_transaccion      NUMBER(05);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);
    v_tip_movimiento       VARCHAR2(01);

    ------------------------- DEFINE MOVIMIEN -----------------------------
  CURSOR movimien_his (p_fecha DATE) IS
    SELECT ct.cod_oficina,
           ct.cod_modulo,
           ct.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           ct.cod_moneda,
           to_char(nvl(pc.cod_plazo, 0)) cod_plazo,
           d.estado situacion,
           nvl(ct.cod_sit_contable, '10000000') cod_sit_contable,
           d.nro_cuenta,
           to_char(d.fecha,'YYYY') periodo,
           SUM(nvl(d.mto_dev_actual, 0)) mto_dev_actual
      FROM ge_plz_contables  pc,
           md_devengados     d,
           md_cta_documentos ct,
           ge_clientes       c,
           ge_cta_clientes   cc,
           ge_modalidades    mo
     WHERE d.fecha          = p_fecha
       AND d.nro_cuenta     = ct.nro_cuenta
       AND d.nro_cuenta     = cc.nro_cuenta
       AND cc.relacion      = 'P'
       AND c.cod_persona    = cc.cod_persona
       AND mo.cod_modulo    = ct.cod_modulo
       AND mo.cod_modalidad = ct.cod_modalidad
       AND d.mto_dev_actual <> 0
       AND pc.can_dias =
          (SELECT MIN(can_dias)
           FROM ge_plz_contables
          WHERE can_dias >= (decode(d.estado, 'E', (ct.fec_ven_repo - ct.fec_ini_repo),
              (ct.fec_vencimiento - ct.fec_inicio))))
  GROUP BY ct.cod_oficina,
           ct.cod_modulo,
           ct.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           ct.cod_moneda,
           to_char(nvl(pc.cod_plazo, 0)),
           d.estado,
           nvl(ct.cod_sit_contable, '10000000'),
           d.nro_cuenta,
           to_char(d.fecha,'YYYY');

  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  CURSOR movimien_dev (p_fecha DATE) IS
   SELECT ct.cod_modulo,
          ct.cod_modalidad,
          NVL(h.cod_oficina,ct.cod_oficina),
          c.cod_sec_contable,
          c.cod_tip_deudor,
          c.residente,
          ct.cod_moneda,
          ct.estado situacion,
          to_char(nvl(pc.cod_plazo, 0)) cod_plazo,
          nvl(ct.cod_sit_contable, '10000000') cod_sit_contable,
          h.Saldo_Tot_Gs,
          h.cod_rubro,
          h.nro_cuenta
     FROM ge_plz_contables   pc,
          cb_sal_inv_res_his h,
          md_cta_documentos  ct,
          ge_clientes        c,
          ge_cta_clientes    cc,
          ge_modalidades     mo
    WHERE h.nro_cuenta     = ct.nro_cuenta
      AND h.nro_cuenta     = cc.nro_cuenta
      AND h.tipo           = 'DE'
      AND cc.relacion      = 'P'
      AND c.cod_persona    = cc.cod_persona
      AND mo.cod_modulo    = ct.cod_modulo
      AND mo.cod_modalidad = ct.cod_modalidad
      AND h.periodo        = to_char(p_fecha,'YYYY')
      AND pc.can_dias =
        (SELECT MIN(can_dias)
        FROM ge_plz_contables
        WHERE can_dias >= (decode(ct.estado,'E', (ct.fec_ven_repo - ct.fec_ini_repo),
                    (ct.fec_vencimiento - ct.fec_inicio))))
   ;

  BEGIN

    --Obtiene las Fechas necesarias----------------------
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    -----------------------------------------------------

    -- Cerramos el cursor si se encuentra abierto -------
    IF movimien_his%ISOPEN THEN
      CLOSE movimien_his;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN movimien_his (v_fec_actual);
    LOOP
      FETCH movimien_his
       INTO v_cod_oficina,
            v_cod_modulo,
            v_cod_modalidad,
            v_cod_sec_contable,
            v_cod_tip_deudor,
            v_residente,
            v_cod_moneda,
            v_cod_plazo,
            v_situacion,
            v_cod_sit_contable,
            v_nro_cuenta,
            v_periodo,
            v_mont_dev;
      EXIT WHEN movimien_his%NOTFOUND;

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (DE=DEVENGADO)---
      v_tip_cta := 'DE';
      --------------------------------------------------------------


      -- OBTIENE EL TIPO DE MOVIMIENTO ----------------------------
      CASE
        WHEN ( v_cod_modalidad IN ('109','112','115','117','118','119') OR FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','R') = 'S' ) -- CNFREINT-1 - Repo Interbancario - Repo Recibido(vta doc)--
          THEN v_tip_movimiento := 'D';
        WHEN ( v_cod_modalidad IN ('101','102','104','105','106','110','114','116','146','123','124','125','129','132','134','144') OR FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' ) -- CNFREINT-1 - Repo Interbancario - Repo Otorgado(compra doc)--
          THEN v_tip_movimiento := 'C';
          -- si no es de ninguna modalidad le asignamos el tipo de mov
        ELSE
          v_tip_movimiento := 'D';
      END CASE;
      --------------------------------------------------------------

      --- OBTIENE EL CODIGO DE TRANSACCION ----
      -- Si es una cuenta con Estado REPO carga la transacción 902 - 12/2015
      IF v_situacion = 'E' THEN
         v_cod_transaccion := 902;
      ELSE
         v_cod_transaccion := 901;
      END IF;
      --v_cod_transaccion := 901;
      --------------------------------------------------------------

      -- REPO-CNF-12/2015: Para documentos Ripeados se cambia para tomar los rubros correctos - CNFREINT-104
      If v_situacion = 'R' Then
         v_cod_sit_contable := '10000003';
      End If;
      --------------------------------------------------------------

      --- OBTENEMOS EL RUBRO CONTABLE ----
      v_cod_rubro := FU_OBT_RUBRO(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                  v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cod_plazo,
                                  v_tip_movimiento, v_situacion, null, null, null, null,
                                  v_cod_sit_contable, null);
      --------------------------------------------------------------

      -- SI TRAJO CERO EL RUBRO, LE ASIGNAMOS OTRO TIPO DE MOV --
      IF v_cod_rubro = 0 THEN
        v_tip_movimiento := 'C';
        v_cod_rubro := FU_OBT_RUBRO(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                       v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cod_plazo,
                       v_tip_movimiento, v_situacion, null, null, null, null,
                       v_cod_sit_contable, null);
      END IF;

      -- COLOCAMOS EL SIGNO AL MONTO DE ACUERDO AL MOVIMIENTO
      IF v_tip_movimiento = 'D' THEN
         v_mont_dev := v_mont_dev * -1;
      END IF;
      --------------------------------------------------------------

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO
      BEGIN
        -- Recuperamos el monto acumulado anterior de la cuenta
        BEGIN
          SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
            INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
            FROM cb_sal_inv_res_his h
           WHERE h.cod_rubro   = v_cod_rubro
             AND h.nro_cuenta = v_nro_cuenta
             AND h.periodo     = to_char(v_fec_actual,'YYYY');
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_saldo_tot_acu    := 0;
            v_saldo_tot_gs_acu := 0;
        END;

        ---- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
        IF v_cod_moneda = v_cod_mon_local THEN
          -- es moneda nacional GS --
          v_mto_cotizacion    := 1;
          v_saldo_total       := 0;
          v_saldo_tot_gs      := v_mont_dev;

          -- saldo acumulado anterior extranjero
          v_sal_mon_local         := v_saldo_tot_gs;                       -- saldo moneda local
          v_sal_mon_extranjera   := 0;                                  -- saldo moneda extranjera
          v_sal_mon_loc_actual   := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
          v_sal_mon_ext_actual   := 0;                                  -- saldo acumulado actual extranjero
        ELSE
          -- Moneda extranjera
          -- Obtiene la cotizacion de cierre
          v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
          -- Cargamos las variables
          v_saldo_total    := v_mont_dev;
          v_saldo_tot_gs   := v_mont_dev * v_mto_cotizacion;

          v_sal_mon_local         := v_saldo_tot_gs;                         -- saldo moneda local
          v_sal_mon_extranjera   := v_saldo_total;                         -- saldo moneda extranjera
          v_sal_mon_loc_actual   := (v_saldo_tot_gs_acu + v_saldo_tot_gs); -- saldo acumulado actual local
          v_sal_mon_ext_actual   := (v_saldo_tot_acu + v_saldo_total);      -- saldo acumulado actual extranjero
        END IF;
        -----------------------------------------------------------------------------

        -- Actualizamos la tabla detallada de Inventario de Resultados
        UPDATE cb_sal_inv_resultados_det
           SET sal_mon_extranjera          = sal_mon_extranjera + v_sal_mon_extranjera,
               sal_mon_local              = sal_mon_local + v_sal_mon_local,
               sal_acu_act_mon_extranjera  = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
               sal_acu_act_mon_local      = sal_acu_act_mon_local + v_sal_mon_local
         WHERE fecha      = v_fec_actual
           AND cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el detalle
          INSERT INTO cb_sal_inv_resultados_det
                (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
                 sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
          VALUES
                (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
                 v_sal_mon_ext_actual, v_sal_mon_loc_actual);
        END IF;

        -- Requerimiento: CNFDEEVO-29.
        -- Fecha: 03/03/2016.
        --Actualizamos la tabla historico
        UPDATE cb_sal_inv_res_his
           SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
               saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
         WHERE cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta
           AND periodo    = v_periodo
           AND tipo       = v_tip_cta
           AND cod_oficina = v_cod_oficina;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el historico
          INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
          VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
        END IF;
      END;
    END LOOP;
    CLOSE movimien_his;


    -- Cerramos el cursor si se encuentra abierto -------
    IF movimien_dev%ISOPEN THEN
      CLOSE movimien_dev;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN movimien_dev (v_fec_actual);
    LOOP
      FETCH movimien_dev
         INTO v_cod_modulo,
              v_cod_modalidad,
              v_cod_oficina,
              v_cod_sec_contable,
              v_cod_tip_deudor,
              v_residente,
              v_cod_moneda,
              v_situacion,
              v_cod_plazo,
              v_cod_sit_contable,
              v_saldo_acumulado,
              v_cod_rubro,
              v_nro_cuenta;
      EXIT WHEN movimien_dev%NOTFOUND;

      -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
      v_tip_saldo := 'K'; -- Inventario de Ctas de Resultado
      -------------------------------------------------------------

      -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
      v_tip_interes := 'X';
      --------------------------------------------------------------

      -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
      v_tip_operacion := 'X';
      --------------------------------------------------------------

      -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
      BEGIN
        SELECT nro_referencia, ROWID
          INTO v_nro_referencia, v_rowid
          FROM cb_sal_inventarios
         WHERE cod_modulo       = v_cod_modulo
           AND cod_modalidad    = v_cod_modalidad
           AND cod_oficina      = v_cod_oficina
           AND cod_sec_contable = v_cod_sec_contable
           AND cod_tip_deudor   = v_cod_tip_deudor
           AND residente        = v_residente
           AND cod_moneda       = v_cod_moneda
           AND situacion        = v_situacion
           AND tip_saldo        = v_tip_saldo
           AND cod_plazo        = v_cod_plazo
           AND tip_operacion    = v_tip_operacion
           AND tip_interes      = v_tip_interes
           AND (tip_renovacion  = v_tip_renovacion OR tip_renovacion IS NULL)
           AND (cat_automatica  = v_cat_automatica OR cat_automatica IS NULL)
           AND cod_sit_contable = v_cod_sit_contable
           AND cod_rubro        = v_cod_rubro;

          IF v_nro_referencia IS NOT NULL THEN
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(v_saldo_acumulado, 0)
             WHERE nro_referencia = v_nro_referencia
               AND ROWID          = v_rowid;

            --------------Genero detalle----------------
            UPDATE cb_sal_inventarios_det
               SET sal_anterior = nvl(sal_actual, 0),
                   sal_actual   = nvl(sal_actual, 0) + nvl(v_saldo_acumulado, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta     = v_nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0), 0);
            END IF;
          END IF;
      EXCEPTION
      WHEN no_data_found THEN
         ------------------------------
         -- INSERTA MONTO DEVENGADO --
         ------------------------------
         SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

         INSERT INTO cb_sal_inventarios
          (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
           residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
           tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
           cat_automatica, cod_sit_contable)
         VALUES
          (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
           v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
           v_cod_plazo, v_tip_operacion, v_tip_interes, nvl(v_saldo_acumulado,0), v_cod_rubro,
           v_nro_referencia, v_tip_renovacion, v_cat_automatica, v_cod_sit_contable);

         INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado,0), 0);
      END;
    END LOOP;
    CLOSE movimien_dev;


  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_DEV_MESA_DINERO: ' || SQLERRM);
  END PR_ACU_DEV_MESA_DINERO;
------------------------------------------------------------------------------------------------------------

-- Intereses Devengados de Caja de Ahorros
  PROCEDURE PR_ACU_DEV_CAJA_AHORRO IS
    -- fechas --
    v_fec_actual          ge_calendarios.fec_actual%TYPE;
    -- monedad local --
    v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    -- variables ----
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable     cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor       cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente            cb_sal_inventarios.residente%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_situacion            cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_mont_dev             cb_sal_inventarios.sal_total%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local        cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo            VARCHAR2(01);
    v_cod_transaccion      NUMBER(05);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);
    v_tip_movimiento       VARCHAR2(01);
    v_cod_sub_modalidad    ge_sub_modalidades.cod_sub_modalidad%type;
    v_tip_cuenta           ge_tip_asientos.tip_cuenta%type;
    v_fec_periodo          varchar2(4);
    ------------------------- DEFINE MOVIMIEN -----------------------------
  CURSOR movimien_his (p_fecha DATE) IS
    SELECT cv.cod_oficina,
           cv.cod_modulo,
           cv.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           cv.cod_moneda,
           to_char(1) cod_plazo,
           d.nro_cuenta,
           to_char(d.fecha,'YYYY') periodo,
           SUM(nvl(d.mto_interes,0)) mto_interes,
           cv.cod_sub_modalidad
      FROM ah_cta_vistas   cv,
           ge_clientes     c,
           ah_devengados   d,
           ge_cta_clientes cc
     WHERE d.fecha        = p_fecha
       AND cv.nro_cuenta  = d.nro_cuenta
       AND cc.nro_cuenta  = d.nro_cuenta
       AND cc.cod_persona = c.cod_persona
       AND cc.relacion    = 'P'
       AND d.mto_interes  <> 0
       --
       AND length(cv.cod_oficina)   >=0
       AND length(cv.cod_modalidad) >=0
       AND length(c.cod_persona)    >=0
  GROUP BY cv.cod_oficina,
           cv.cod_modulo,
           cv.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           cv.cod_moneda,
           to_char(1),
           d.nro_cuenta,
           to_char(d.fecha,'YYYY'),
           cv.cod_sub_modalidad
   UNION
    SELECT cp.cod_oficina,
           cp.cod_modulo,
           cp.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           cp.cod_moneda,
           to_char(nvl(pc.cod_plazo, 0)) cod_plazo,
           d.nro_cuenta,
           to_char(d.fecha,'YYYY') periodo,
           SUM(nvl(d.mto_interes,0)) mto_interes,
           cv.cod_sub_modalidad
      FROM ge_plz_contables pc,
           ah_devengados    d,
           ah_cta_plazos    cp,
           ah_cta_vistas    cv,
           ge_clientes      c,
           ge_cta_clientes  cc
     WHERE d.fecha        = p_fecha
       AND cp.nro_cuenta  = d.nro_cuenta
       AND cv.nro_cuenta  = d.nro_cuenta
       AND cc.nro_cuenta  = d.nro_cuenta
       AND cc.cod_persona = c.cod_persona
       AND cc.relacion    = 'P'
       AND d.mto_interes  <> 0
       --
       AND length(cv.cod_oficina)   >=0 
       AND length(cv.cod_modalidad) >=0
       AND length(c.cod_persona)    >=0
       AND pc.can_dias =
        (SELECT MIN(can_dias)
         FROM ge_plz_contables
        WHERE can_dias >= (cp.fec_vencimiento - cp.fec_apertura))
  GROUP BY cp.cod_oficina,
           cp.cod_modulo,
           cp.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           cp.cod_moneda,
           to_char(nvl(pc.cod_plazo, 0)),
           d.nro_cuenta,
           to_char(d.fecha,'YYYY'),
           cv.cod_sub_modalidad
   UNION
    SELECT ct.cod_oficina,
           ct.cod_modulo,
           ct.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           ct.cod_moneda,
           to_char(nvl(pc.cod_plazo, 0)) cod_plazo,
           d.nro_cuenta,
           to_char(d.fecha,'YYYY') periodo,
           SUM(nvl(d.mto_interes,0)) mto_interes,
           null
      FROM ge_plz_contables    pc,
           ah_devengados       d,
           ah_cta_certificados ct,
           ge_clientes         c,
           ge_cta_clientes     cc          
     WHERE d.fecha        = p_fecha
       AND ct.nro_cuenta  = d.nro_cuenta
       AND cc.nro_cuenta  = d.nro_cuenta
       AND cc.cod_persona = c.cod_persona
       AND cc.relacion    = 'P'
       AND d.mto_interes  <> 0
       --
       AND length(ct.cod_oficina)   >=0
       AND length(ct.cod_modalidad) >=0
       AND length(c.cod_persona)    >=0
       AND pc.can_dias =
        (SELECT MIN(can_dias)
         FROM ge_plz_contables
        WHERE can_dias >= (ct.fec_vencimiento - ct.fec_apertura))
  GROUP BY ct.cod_oficina,
           ct.cod_modulo,
           ct.cod_modalidad,
           c.cod_sec_contable,
           c.cod_tip_deudor,
           c.residente,
           ct.cod_moneda,
           to_char(nvl(pc.cod_plazo, 0)),
           d.nro_cuenta,
           to_char(d.fecha,'YYYY');
    PROCEDURE LP_DISABLE_PARALLEL_DML
      IS
        PRAGMA AUTONOMOUS_TRANSACTION;
      BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
        COMMIT; -- Esto solo confirma la transacción del ALTER SESSION, no la del procedimiento principal.
      EXCEPTION
        WHEN OTHERS THEN
          -- ORA-12841: puede ocurrir si la sesión ya está en modo serial. Lo ignoramos de forma segura.
          IF SQLCODE = -12841 THEN
            NULL; 
          ELSE
            RAISE;
          END IF;
      END LP_DISABLE_PARALLEL_DML;
  BEGIN

    --Obtiene las Fechas necesarias----------------------
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    -----------------------------------------------------

    -- Cerramos el cursor si se encuentra abierto -------
    IF movimien_his%ISOPEN THEN
      CLOSE movimien_his;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN movimien_his (v_fec_actual);
    LOOP
      FETCH movimien_his
        INTO v_cod_oficina,
             v_cod_modulo,
             v_cod_modalidad,
             v_cod_sec_contable,
             v_cod_tip_deudor,
             v_residente,
             v_cod_moneda,
             v_cod_plazo,
             v_nro_cuenta,
             v_periodo,
             v_mont_dev,
             v_cod_sub_modalidad;
    EXIT WHEN movimien_his%NOTFOUND;

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (DE=DEVENGADO)---
    v_tip_cta := 'DE';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE MOVIMIENTO ----------------------------
    v_tip_movimiento := 'D';
    --------------------------------------------------------------

    --- OBTIENE EL CODIGO DE TRANSACCION ----
    v_cod_transaccion := 901;
    --------------------------------------------------------------
    if v_cod_sub_modalidad is not null then
      begin
        v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(v_cod_modulo)||trim(v_cod_modalidad)||trim(v_cod_sub_modalidad));
      exception
        when others then
          v_tip_cuenta := NULL;
      end;
    end if;

    --- OBTENEMOS EL RUBRO CONTABLE ---
    v_cod_rubro := FU_OBT_RUBRO (v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                 v_cod_sec_contable, v_cod_tip_deudor, v_residente, v_cod_plazo, v_tip_movimiento,
                                 null, null, null, null, v_tip_cuenta);
    --------------------------------------------------------------

    -- COLOCAMOS EL SIGNO AL MONTO DE ACUERDO AL MOVIMIENTO
    IF v_tip_movimiento = 'D' THEN
      v_mont_dev := v_mont_dev * -1;
    END IF;
    --------------------------------------------------------------

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO
      BEGIN
        -- Recuperamos el monto acumulado anterior de la cuenta
        BEGIN
          SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
            INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
            FROM cb_sal_inv_res_his h
           WHERE h.cod_rubro   = v_cod_rubro
             AND h.nro_cuenta = v_nro_cuenta
             AND h.periodo    = to_char(v_fec_actual,'YYYY') ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_saldo_tot_acu    := 0;
            v_saldo_tot_gs_acu := 0;
        END;

        ---- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
        IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional GS --
            v_mto_cotizacion    := 1;
            v_saldo_total       := 0;
            v_saldo_tot_gs      := v_mont_dev;

            v_sal_mon_local         := v_saldo_tot_gs;                      -- saldo moneda local
            v_sal_mon_extranjera   := 0;                                 -- saldo moneda extranjera
            v_sal_mon_loc_actual   := (v_saldo_tot_gs_acu + v_saldo_tot_gs); -- saldo acumulado actual local
            v_sal_mon_ext_actual   := 0;                                 -- saldo acumulado actual extranjero
        ELSE
          -- Moneda extranjera
            -- Obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            -- Cargamos las variables
            v_saldo_total    := v_mont_dev;
            v_saldo_tot_gs   := v_mont_dev * v_mto_cotizacion;

            v_sal_mon_local         := v_saldo_tot_gs;                        -- saldo moneda local
            v_sal_mon_extranjera   := v_saldo_total;                        -- saldo moneda extranjera
            v_sal_mon_loc_actual   := (v_saldo_tot_gs_acu + v_saldo_tot_gs);-- saldo acumulado actual local
            v_sal_mon_ext_actual   := (v_saldo_tot_acu + v_saldo_total);     -- saldo acumulado actual extranjero
        END IF;
        -----------------------------------------------------------------------------

        -- Actualizamos la tabla detallada de Inventario de Resultados
        UPDATE cb_sal_inv_resultados_det
           SET sal_mon_extranjera           = sal_mon_extranjera + v_sal_mon_extranjera,
               sal_mon_local               = sal_mon_local + v_sal_mon_local,
               sal_acu_act_mon_extranjera   = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
               sal_acu_act_mon_local       = sal_acu_act_mon_local + v_sal_mon_local
         WHERE fecha      = v_fec_actual
           AND cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el detalle
          INSERT INTO cb_sal_inv_resultados_det
                (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
                 sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
          VALUES
                (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
                 v_sal_mon_ext_actual, v_sal_mon_loc_actual);
        END IF;

        --Actualizamos la tabla historico
        UPDATE cb_sal_inv_res_his
           SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
               saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
         WHERE cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta
           AND periodo    = v_periodo
           AND tipo        = v_tip_cta
           AND cod_oficina = v_cod_oficina;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el historico
          INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
          VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
        END IF;
      END;
    END LOOP;
    CLOSE movimien_his;
 -------------------------MOVIMIEN P/ INV DEVENGADOS ------------------------------
    v_tip_saldo := 'K'; -- Inventario de Ctas de Resultado
    v_fec_periodo   := to_char(v_fec_actual, 'YYYY');

 -- Llamamos al procedimiento auxiliar para forzar la ejecución en serie de forma segura.
    LP_DISABLE_PARALLEL_DML;
    
    -----------------------------------------------------------------------------------
    --PREPARAR DATOS DE ORIGEN EN TABLA TEMPORAL
    ----------------------------------------------------------------------------------- 
    DELETE FROM cb_sal_movimientos;    
     INSERT INTO cb_sal_movimientos
    (cod_modulo,
     cod_modalidad,
     cod_oficina,
     cod_sec_contable,
     cod_tip_deudor,
     residente,
     cod_moneda,
     situacion,
     cod_plazo,
     cod_rubro,
     sal_total,
     nro_cuenta)
     WITH source_vistas AS
     (SELECT cv.cod_modulo,
             cv.cod_modalidad,
             NVL(h.cod_oficina, cv.cod_oficina) AS cod_oficina,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             cv.cod_moneda,
             nvl(cv.cta_combinada, 'N') AS situacion,
             '1' AS cod_plazo,
             h.cod_rubro,
             h.Saldo_Tot_Gs,
             h.nro_cuenta
        FROM ah_cta_vistas cv
        JOIN cb_sal_inv_res_his h
          ON h.nro_cuenta = cv.nro_cuenta
        JOIN ge_cta_clientes cc
          ON h.nro_cuenta = cc.nro_cuenta
        JOIN ge_clientes c
          ON cc.cod_persona = c.cod_persona
       WHERE h.tipo = 'DE'
         AND cc.relacion = 'P'
         AND h.periodo = v_fec_periodo),
    source_plazos AS
     (SELECT cp_ranked.cod_modulo,
             cp_ranked.cod_modalidad,
             NVL(h.cod_oficina, cp_ranked.cod_oficina) AS cod_oficina,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             cp_ranked.cod_moneda,
             nvl(cv.cta_combinada, 'N') AS situacion,
             to_char(nvl(cp_ranked.cod_plazo, 0)) AS cod_plazo,
             h.cod_rubro,
             h.Saldo_Tot_Gs,
             h.nro_cuenta
        FROM (SELECT cp.nro_cuenta,
                     cp.cod_modulo,
                     cp.cod_modalidad,
                     cp.cod_oficina,
                     cp.cod_moneda,
                     cp.fec_vencimiento,
                     cp.fec_apertura,
                     pc.cod_plazo,
                     ROW_NUMBER() OVER(PARTITION BY cp.nro_cuenta ORDER BY pc.can_dias ASC) as rn
                FROM ah_cta_plazos cp
                JOIN ge_plz_contables pc
                  ON pc.can_dias >= (cp.fec_vencimiento - cp.fec_apertura)) cp_ranked
        JOIN cb_sal_inv_res_his h
          ON h.nro_cuenta = cp_ranked.nro_cuenta
        JOIN ge_cta_clientes cc
          ON h.nro_cuenta = cc.nro_cuenta
        JOIN ge_clientes c
          ON cc.cod_persona = c.cod_persona
        JOIN ah_cta_vistas cv
          ON h.nro_cuenta = cv.nro_cuenta
       WHERE cp_ranked.rn = 1
         AND h.tipo = 'DE'
         AND cc.relacion = 'P'
         AND h.periodo = v_fec_periodo),
    source_certificados AS
     (SELECT ct_ranked.cod_modulo,
             ct_ranked.cod_modalidad,
             NVL(h.cod_oficina, ct_ranked.cod_oficina) AS cod_oficina,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             ct_ranked.cod_moneda,
             nvl((select cv.cta_combinada
                   from ah_cta_vistas cv
                  where cv.nro_cuenta = h.nro_cuenta),
                 'N') AS situacion,
             to_char(nvl(ct_ranked.cod_plazo, 0)) AS cod_plazo,
             h.cod_rubro,
             h.Saldo_Tot_Gs,
             h.nro_cuenta
        FROM (SELECT ct.nro_cuenta,
                     ct.cod_modulo,
                     ct.cod_modalidad,
                     ct.cod_oficina,
                     ct.cod_moneda,
                     ct.fec_vencimiento,
                     ct.fec_apertura,
                     pc.cod_plazo,
                     ROW_NUMBER() OVER(PARTITION BY ct.nro_cuenta ORDER BY pc.can_dias ASC) as rn
                FROM ah_cta_certificados ct
                JOIN ge_plz_contables pc
                  ON pc.can_dias >= (ct.fec_vencimiento - ct.fec_apertura)) ct_ranked
        JOIN cb_sal_inv_res_his h
          ON h.nro_cuenta = ct_ranked.nro_cuenta
        JOIN ge_cta_clientes cc
          ON h.nro_cuenta = cc.nro_cuenta
        JOIN ge_clientes c
          ON cc.cod_persona = c.cod_persona
       WHERE ct_ranked.rn = 1
         AND h.tipo = 'DE'
         AND cc.relacion = 'P'
         AND h.periodo = v_fec_periodo)
    SELECT cod_modulo,
           cod_modalidad,
           cod_oficina,
           cod_sec_contable,
           cod_tip_deudor,
           residente,
           cod_moneda,
           situacion,
           cod_plazo,
           cod_rubro,
           Saldo_Tot_Gs,
           nro_cuenta
      FROM source_vistas
    UNION
    SELECT cod_modulo,
           cod_modalidad,
           cod_oficina,
           cod_sec_contable,
           cod_tip_deudor,
           residente,
           cod_moneda,
           situacion,
           cod_plazo,
           cod_rubro,
           Saldo_Tot_Gs,
           nro_cuenta
      FROM source_plazos
    UNION
    SELECT cod_modulo,
           cod_modalidad,
           cod_oficina,
           cod_sec_contable,
           cod_tip_deudor,
           residente,
           cod_moneda,
           situacion,
           cod_plazo,
           cod_rubro,
           Saldo_Tot_Gs,
           nro_cuenta
      FROM source_certificados;
  -----------------------------------------------------------------------------------
  --MERGE A LA TABLA PRINCIPAL (cb_sal_inventarios)
  -----------------------------------------------------------------------------------
  MERGE INTO cb_sal_inventarios inv
  USING (SELECT cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                cod_moneda,
                situacion,
                cod_plazo,
                cod_rubro,
                SUM(sal_total) AS sal_total
           FROM cb_sal_movimientos
          GROUP BY cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   cod_sec_contable,
                   cod_tip_deudor,
                   residente,
                   cod_moneda,
                   situacion,
                   cod_plazo,
                   cod_rubro) src
  ON (DECODE(inv.cod_modulo, src.cod_modulo, 1, 0) = 1 
  AND DECODE(inv.cod_modalidad, src.cod_modalidad, 1, 0) = 1 
  AND DECODE(inv.cod_oficina, src.cod_oficina, 1, 0) = 1 
  AND DECODE(inv.cod_sec_contable, src.cod_sec_contable, 1, 0) = 1 
  AND DECODE(inv.cod_tip_deudor, src.cod_tip_deudor, 1, 0) = 1 
  AND DECODE(inv.residente, src.residente, 1, 0) = 1 
  AND DECODE(inv.cod_moneda, src.cod_moneda, 1, 0) = 1 
  AND DECODE(inv.situacion, src.situacion, 1, 0) = 1 
  AND DECODE(inv.tip_saldo, v_tip_saldo, 1, 0) = 1 
  AND DECODE(inv.cod_plazo, src.cod_plazo, 1, 0) = 1 
  AND DECODE(inv.tip_operacion, 'X', 1, 0) = 1 
  AND DECODE(inv.tip_interes, 'X', 1, 0) = 1 
  AND DECODE(inv.cod_rubro, src.cod_rubro, 1, 0) = 1)
  WHEN MATCHED THEN
    UPDATE
       SET inv.sal_total = NVL(inv.sal_total, 0) + NVL(src.sal_total, 0)
  WHEN NOT MATCHED THEN
    INSERT
      (cod_modulo,
       cod_modalidad,
       cod_oficina,
       cod_sec_contable,
       cod_tip_deudor,
       residente,
       cod_moneda,
       situacion,
       tip_saldo,
       cod_plazo,
       tip_operacion,
       tip_interes,
       sal_total,
       cod_rubro,
       nro_referencia)
    VALUES
      (src.cod_modulo,
       src.cod_modalidad,
       src.cod_oficina,
       src.cod_sec_contable,
       src.cod_tip_deudor,
       src.residente,
       src.cod_moneda,
       src.situacion,
       v_tip_saldo,
       src.cod_plazo,
       'X',
       'X',
       NVL(src.sal_total, 0),
       src.cod_rubro,
       s_nro_referencia.nextval);
  -----------------------------------------------------------------------------------
  --MERGE A LA TABLA DE DETALLE (cb_sal_inventarios_det)
  -----------------------------------------------------------------------------------
  MERGE INTO cb_sal_inventarios_det det
  USING (
    WITH grouped_source AS
     (SELECT nro_cuenta,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             cod_sec_contable,
             cod_tip_deudor,
             residente,
             cod_moneda,
             situacion,
             cod_plazo,
             cod_rubro,
             SUM(sal_total) AS sal_total
        FROM cb_sal_movimientos
       GROUP BY nro_cuenta,
                cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                cod_moneda,
                situacion,
                cod_plazo,
                cod_rubro)
    SELECT inv.nro_referencia, gs.nro_cuenta, gs.sal_total
      FROM grouped_source gs
      JOIN cb_sal_inventarios inv
        ON (DECODE(inv.cod_modulo, gs.cod_modulo, 1, 0) = 1 
        AND DECODE(inv.cod_modalidad, gs.cod_modalidad, 1, 0) = 1 
        AND DECODE(inv.cod_oficina, gs.cod_oficina, 1, 0) = 1 
        AND DECODE(inv.cod_sec_contable, gs.cod_sec_contable, 1, 0) = 1 
        AND DECODE(inv.cod_tip_deudor, gs.cod_tip_deudor, 1, 0) = 1 
        AND DECODE(inv.residente, gs.residente, 1, 0) = 1 
        AND DECODE(inv.cod_moneda, gs.cod_moneda, 1, 0) = 1 
        AND DECODE(inv.situacion, gs.situacion, 1, 0) = 1 
        AND DECODE(inv.tip_saldo, v_tip_saldo, 1, 0) = 1 
        AND DECODE(inv.cod_plazo, gs.cod_plazo, 1, 0) = 1 
        AND DECODE(inv.tip_operacion, 'X', 1, 0) = 1 
        AND DECODE(inv.tip_interes, 'X', 1, 0) = 1 
        AND DECODE(inv.cod_rubro, gs.cod_rubro, 1, 0) = 1)) new_data 
        
        ON (det.nro_referencia = new_data.nro_referencia 
        AND det.nro_cuenta = new_data.nro_cuenta) 
      WHEN MATCHED THEN
      UPDATE
         SET det.sal_anterior = NVL(det.sal_actual, 0),
             det.sal_actual   = NVL(det.sal_actual, 0) +
                                NVL(new_data.sal_total, 0)
    WHEN NOT MATCHED THEN
      INSERT
        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
      VALUES
        (new_data.nro_referencia, new_data.nro_cuenta,NVL(new_data.sal_total, 0),0);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_DEV_CAJA_AHORRO: ' || SQLERRM);
  END PR_ACU_DEV_CAJA_AHORRO;
-----------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------
-- Insteres Devengado en Suspenso
   PROCEDURE PR_ACU_DEV_SUSPENSO IS
    -- fechas --
    v_fec_actual           ge_calendarios.fec_actual%TYPE;
    -- monedad local --
    v_cod_mon_local        ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    -- variables ----
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_situacion            cb_sal_inventarios.situacion%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local      cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_cod_sec_contable     ge_sec_contables.cod_sec_contable%TYPE;
    v_residente            ge_clientes.residente%TYPE;
    v_tip_deudor           ge_clientes.cod_tip_deudor%TYPE;
    v_tip_saldo            VARCHAR2(01);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);

    ------------------------- DEFINE MOVIMIEN HIS -----------------------------
      CURSOR movimien_his (p_fecha DATE) IS
    SELECT replace(d.cod_rubro,' ','') COD_RUBRO,
           m.nro_cuenta,
           to_char(m.fecha,'YYYY') PERIODO,
           SUM(case
               when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' and m.MONTO > 0 then
                  decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
               else
                  decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
               end)
           as MONTO,
           SUM(case
               when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' and m.MONTO > 0 then
                  decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
               else
                  decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
               end)
           as MTO_EQU_LOCAL,
           m.COD_MONEDA,
           d.cod_oficina
      FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th
     WHERE d.fecha            = p_fecha
       AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
       AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'DEV_SUSPENSO')
       AND d.fecha            = m.fecha
       AND d.ref_movimiento   = m.nro_documento4
       AND m.cod_modulo       = th.cod_modulo(+)
       AND m.cod_modalidad    = th.cod_modalidad(+)
       AND m.cod_transaccion  = th.cod_transaccion(+)
  GROUP BY d.cod_rubro,
           m.nro_cuenta,
           to_char(m.fecha,'YYYY'),
           m.cod_moneda,
           d.cod_oficina;
  ------------------------- DEFINE MOVIMIEN DEV -----------------------------
    -- Requerimiento: CNFDEEVO-29.
    -- Fecha: 03/03/2016.
    CURSOR movimien_dev (p_fecha DATE) IS
      SELECT g.cod_modulo,
             g.cod_modalidad,
             NVL(h.cod_oficina,g.cod_oficina),
             g.cod_moneda,
             c.cod_sec_contable,
             c.residente,
             c.cod_tip_deudor,
             to_char(1) cod_plazo,
             h.saldo_tot_gs,
             h.cod_rubro,
             h.nro_cuenta
        FROM cb_sal_inv_res_his h,
             ge_cuentas g,
             ge_clientes      c,
             ge_cta_clientes  cc,
             ge_modalidades   mo
       WHERE h.periodo       = to_char(p_fecha,'YYYY')
         AND h.tipo          = 'DS'  -- Devengado en Suspenso
         AND h.nro_cuenta    = g.nro_cuenta
         AND g.nro_cuenta    = cc.nro_cuenta
         AND cc.relacion     = 'P'
         AND c.cod_persona   = cc.cod_persona
         AND g.cod_modulo    = mo.cod_modulo
         AND g.cod_modalidad = mo.cod_modalidad
      ;
      TYPE r_movimien_dev IS RECORD (
          cod_modulo       ge_cuentas.cod_modulo%TYPE,
          cod_modalidad    ge_cuentas.cod_modalidad%TYPE,
          cod_oficina      ge_cuentas.cod_oficina%TYPE,
          cod_moneda       ge_cuentas.cod_moneda%TYPE,
          cod_sec_contable ge_clientes.cod_sec_contable%TYPE,
          residente        ge_clientes.residente%TYPE,
          tip_deudor       ge_clientes.cod_tip_deudor%TYPE,
          cod_plazo        VARCHAR2(10),
          saldo_acumulado  cb_sal_inv_res_his.saldo_tot_gs%TYPE,
          cod_rubro        cb_sal_inv_res_his.cod_rubro%TYPE,
          nro_cuenta       ge_cuentas.nro_cuenta%TYPE
        );
        TYPE t_movimien_dev IS TABLE OF r_movimien_dev;
        l_movimientos t_movimien_dev;

 BEGIN
   --Obtiene la Fecha necesarias----------------------
   v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
   -----------------------------------------------------

   -- Cerramos el cursor si se encuentra abierto -------
   IF movimien_his%ISOPEN THEN
      CLOSE movimien_his;
   END IF;
   ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
   OPEN movimien_his (v_fec_actual);
    LOOP
      FETCH movimien_his
        INTO v_cod_rubro,
             v_nro_cuenta,
             v_periodo,
       v_saldo_total,
       v_saldo_tot_gs,
       v_cod_moneda,
       v_cod_oficina;
      EXIT WHEN movimien_his%NOTFOUND;

      --SI EL NRO DE CUENTA ES NULO LE ASIGNAMOS UNA CUENTA GENERICA DE ACUERDO A LA MONEDA
      IF v_nro_cuenta IS NULL THEN
         v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
         END IF;
      --------------------------------------------------------------

      -- OBTIENE EL TIPO DE CTA DE RESULTADO (DS=DEVENGADO SUSPENSO)---
      v_tip_cta := 'DS';  --Devengado en Suspenso
      --------------------------------------------------------------

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO
      BEGIN
        -- Recuperamos el monto acumulado anterior de la cuenta
        BEGIN
          SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
            INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
            FROM cb_sal_inv_res_his h
           WHERE h.cod_rubro  = v_cod_rubro
             AND h.nro_cuenta = v_nro_cuenta
             AND h.periodo    = v_periodo ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_saldo_tot_acu    := 0;
            v_saldo_tot_gs_acu := 0;
        END;

        ---- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
        IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional GS --
            v_mto_cotizacion     := 1;

            v_sal_mon_local       := v_saldo_tot_gs;                       -- saldo moneda local
            v_sal_mon_extranjera := 0;                                  -- saldo moneda extranjera
            v_sal_mon_loc_actual := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
            v_sal_mon_ext_actual := 0;                                  -- saldo acumulado actual extranjero
        ELSE
            -- Moneda extranjera
            v_mto_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);

            v_sal_mon_local       := v_saldo_tot_gs;                          -- saldo moneda local
            v_sal_mon_extranjera := v_saldo_total;                          -- saldo moneda extranjera
            v_sal_mon_loc_actual := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
            v_sal_mon_ext_actual := (v_saldo_tot_acu + v_saldo_total);       -- saldo acumulado actual extranjero
        END IF;
        -----------------------------------------------------------------------------

        -- Actualizamos la tabla detallada de Inventario de Resultados
        UPDATE cb_sal_inv_resultados_det
           SET sal_mon_extranjera          = sal_mon_extranjera + v_sal_mon_extranjera,
               sal_mon_local              = sal_mon_local + v_sal_mon_local,
               sal_acu_act_mon_extranjera  = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
               sal_acu_act_mon_local      = sal_acu_act_mon_local + v_sal_mon_local
         WHERE fecha      = v_fec_actual
           AND cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el detalle
          INSERT INTO cb_sal_inv_resultados_det
              (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
               sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
          VALUES
              (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
               v_sal_mon_ext_actual, v_sal_mon_loc_actual);
        END IF;

        -- Requerimiento: CNFDEEVO-29.
        -- Fecha: 03/03/2016.
        --Actualizamos la tabla historico
        UPDATE cb_sal_inv_res_his
           SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
               saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
         WHERE cod_rubro   = v_cod_rubro
           AND nro_cuenta  = v_nro_cuenta
           AND periodo     = v_periodo
           AND tipo         = v_tip_cta
           AND cod_oficina = v_cod_oficina;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el historico
          INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
          VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
        END IF;
      END;
    END LOOP;
    CLOSE movimien_his;

    -- Cerramos el cursor si se encuentra abierto -------
     IF movimien_dev%ISOPEN THEN
    CLOSE movimien_dev;
  END IF;

  ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
  -- Se abre el cursor, se leen TODOS los registros de una vez y se cierra.
  OPEN movimien_dev(v_fec_actual);
  FETCH movimien_dev BULK COLLECT INTO l_movimientos;
  CLOSE movimien_dev;

  -- 4. Se recorre la colección en memoria, en lugar del cursor.
  FOR i IN 1 .. l_movimientos.COUNT LOOP

    -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
    v_tip_saldo := 'K'; -- Inventario de Ctas de Resultado
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)
    v_tip_interes := 'X';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)
    v_tip_operacion := 'X';
    --------------------------------------------------------------

    -- OBTIENE LA SITUACION CONTABLE DE ACUERDO AL MODULO
    -- La lógica interna es la misma, pero ahora usa los datos de la colección l_movimientos(i)
    CASE l_movimientos(i).cod_modulo
      WHEN 3 THEN
        BEGIN
          SELECT cv.cta_combinada INTO v_situacion FROM ah_cta_vistas cv WHERE cv.nro_cuenta = l_movimientos(i).nro_cuenta;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_situacion := 'N';
          WHEN OTHERS THEN
            raise_application_error(-20000, 'Error v_situacion, modulo 3. Nro_cuenta:' || l_movimientos(i).nro_cuenta || '. :' || SQLERRM);
        END;
      WHEN 4 THEN
        BEGIN
          SELECT r.sit_deuda INTO v_situacion FROM cc_sobregiros_res r WHERE r.nro_cuenta = l_movimientos(i).nro_cuenta;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_situacion := 'S';
          WHEN OTHERS THEN
            raise_application_error(-20000, 'Error v_situacion, modulo 4. Nro_cuenta:' || l_movimientos(i).nro_cuenta || '. :' || SQLERRM);
        END;
      WHEN 6 THEN
        BEGIN
          SELECT p.est_batch INTO v_situacion FROM pr_cta_prestamos p WHERE p.nro_cuenta = l_movimientos(i).nro_cuenta;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_situacion := 'N';
          WHEN OTHERS THEN
            raise_application_error(-20000, 'Error v_situacion, modulo 6. Nro_cuenta:' || l_movimientos(i).nro_cuenta || '. :' || SQLERRM);
        END;
      ELSE
        v_situacion := 'N';
    END CASE;
    -----------------------------------------------------------------------------------------------------------------------

    -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
    BEGIN
      SELECT nro_referencia, ROWID
        INTO v_nro_referencia, v_rowid
        FROM cb_sal_inventarios
       WHERE cod_modulo       = l_movimientos(i).cod_modulo
         AND cod_modalidad    = l_movimientos(i).cod_modalidad
         AND cod_oficina      = l_movimientos(i).cod_oficina
         AND cod_moneda       = l_movimientos(i).cod_moneda
         AND situacion        = v_situacion
         AND cod_sec_contable = l_movimientos(i).cod_sec_contable
         AND residente        = l_movimientos(i).residente
         AND cod_tip_deudor   = l_movimientos(i).tip_deudor
         AND tip_saldo        = v_tip_saldo
         AND cod_plazo        = l_movimientos(i).cod_plazo
         AND tip_interes      = v_tip_interes
         AND tip_operacion    = v_tip_operacion
         AND cod_rubro        = l_movimientos(i).cod_rubro;

      IF v_nro_referencia IS NOT NULL THEN
        UPDATE cb_sal_inventarios
           SET sal_total = NVL(sal_total, 0) + NVL(l_movimientos(i).saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND ROWID          = v_rowid;

        --------------Genero detalle----------------
        UPDATE cb_sal_inventarios_det
           SET sal_anterior = NVL(sal_actual, 0),
               sal_actual   = NVL(sal_actual, 0) + NVL(l_movimientos(i).saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta     = l_movimientos(i).nro_cuenta;

        IF SQL%NOTFOUND THEN
          INSERT INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
          VALUES
            (v_nro_referencia, l_movimientos(i).nro_cuenta, NVL(l_movimientos(i).saldo_acumulado, 0), 0);
        END IF;
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        ------------------------------
        -- INSERTA MONTO DEVENGADO --
        ------------------------------
        SELECT s_nro_referencia.NEXTVAL INTO v_nro_referencia FROM dual;

        INSERT INTO cb_sal_inventarios
          (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, situacion, cod_sec_contable, residente, tip_interes,
           tip_operacion, cod_tip_deudor, tip_saldo, cod_plazo, sal_total, cod_rubro, nro_referencia)
        VALUES
          (l_movimientos(i).cod_modulo, l_movimientos(i).cod_modalidad, l_movimientos(i).cod_oficina, l_movimientos(i).cod_moneda, v_situacion, l_movimientos(i).cod_sec_contable, l_movimientos(i).residente, v_tip_interes,
           v_tip_operacion, l_movimientos(i).tip_deudor, v_tip_saldo, l_movimientos(i).cod_plazo, NVL(l_movimientos(i).saldo_acumulado, 0), l_movimientos(i).cod_rubro, v_nro_referencia);

        INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
        VALUES
          (v_nro_referencia, l_movimientos(i).nro_cuenta, NVL(l_movimientos(i).saldo_acumulado, 0), 0);
    END;
  END LOOP;


 EXCEPTION
  WHEN OTHERS THEN
     ROLLBACK;
     raise_application_error(-20000, 'ERROR PR_ACU_DEV_SUSPENSO: ' || SQLERRM);
 END PR_ACU_DEV_SUSPENSO;
-----------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------
-- Comisiones Cobradas y Pagadas
  PROCEDURE PR_ACU_COMISIONES IS
    -- fechas --
    v_fec_actual          ge_calendarios.fec_actual%TYPE;
    -- monedad local --
    v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    -- variables ----
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local        cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_cod_sec_contable     ge_sec_contables.cod_sec_contable%TYPE;
    v_residente            ge_clientes.residente%TYPE;
    v_tip_deudor           ge_clientes.cod_tip_deudor%TYPE;
    v_cod_persona          ge_movimientos.cod_persona%type;
    v_tip_saldo            VARCHAR2(01);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);
    v_fec_periodo          VARCHAR2(4);
    ------------------------- DEFINE MOVIMIEN HIS -----------------------------
    -- Fecha: 16/10/2013. JF.
    -- Requerimiento: REG-BBVA-CNF_2303_FAFU.01-COM_DEP_EFECTIVO.docx
    -- Fecha: 12/08/2014.
    -- Requerimiento: CNFIRGTR-2.
    CURSOR movimien_his (p_fecha DATE) IS
        SELECT REPLACE(d.cod_rubro,' ','') COD_RUBRO,
               (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END) NRO_CUENTA,
               to_char(m.fecha,'YYYY') PERIODO,
               SUM(case
                   when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' and m.MONTO > 0 then
                       decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                   else
                       decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                   end)
               as MONTO,
               SUM(case
                   when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' and m.MONTO > 0 then
                      decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                   else
                      decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                   end)
               as MTO_EQU_LOCAL,
               m.COD_MONEDA,
               m.cod_oficina,
               (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  m.cod_persona
                ELSE
                  NULL
                END) cod_persona
          FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th
         WHERE d.fecha          = p_fecha
               AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
               AND (SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'COM_COBRADAS')
                   OR SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'COM_PAGADAS')
                   )
               AND d.fecha          = m.fecha
               AND d.ref_movimiento = m.nro_documento4
               AND m.cod_modulo     = th.cod_modulo(+)
               AND m.cod_modalidad  = th.cod_modalidad(+)
               AND m.cod_transaccion= th.cod_transaccion(+)
      GROUP BY d.cod_rubro,
               (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END),
               to_char(m.fecha,'YYYY'),
               m.COD_MONEDA,
               m.cod_oficina,
               (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  m.cod_persona
                ELSE
                  NULL
                END);
   PROCEDURE LP_DISABLE_PARALLEL_DML
      IS
        PRAGMA AUTONOMOUS_TRANSACTION;
      BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
        COMMIT; -- Esto solo confirma la transacción del ALTER SESSION, no la del procedimiento principal.
      EXCEPTION
        WHEN OTHERS THEN
          -- ORA-12841: puede ocurrir si la sesión ya está en modo serial. Lo ignoramos de forma segura.
          IF SQLCODE = -12841 THEN
            NULL; 
          ELSE
            RAISE;
          END IF;
      END LP_DISABLE_PARALLEL_DML;

  BEGIN

    --Obtiene la Fecha necesarias----------------------
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    -----------------------------------------------------

  -- Cerramos el cursor si se encuentra abierto -------
    IF movimien_his%ISOPEN THEN
      CLOSE movimien_his;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN movimien_his (v_fec_actual);
    LOOP
      FETCH movimien_his
        INTO v_cod_rubro,
             v_nro_cuenta,
             v_periodo,
             v_saldo_total,
             v_saldo_tot_gs,
             v_cod_moneda,
             v_cod_oficina,
             -- Fecha: 12/08/2014.
             -- Requerimiento: CNFIRGTR-2.
             v_cod_persona;
      EXIT WHEN movimien_his%NOTFOUND;

    -- Fecha: 12/08/2014.
    -- Requerimiento: CNFIRGTR-2.
    --SI EL NRO DE CUENTA ES NULO LE ASIGNAMOS UNA CUENTA GENERICA DE ACUERDO A LA MONEDA
    IF v_nro_cuenta IS NULL THEN
       IF v_cod_persona IS NOT NULL THEN
          BEGIN
             v_nro_cuenta := FU_OBT_NRO_CUENTA(v_cod_persona);
          EXCEPTION
             WHEN OTHERS THEN
                v_nro_cuenta := NULL;
          END;
          --
          IF v_nro_cuenta IS NULL THEN
             v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
          END IF;
       ELSE
          v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
       END IF;
    END IF;
    --------------------------------------------------------------

      -- OBTIENE EL TIPO DE CTA DE RESULTADO (CO=COMISION PAGADA O COBRADA)---
      v_tip_cta := 'CO';  --comision pagada o cobrada
      --------------------------------------------------------------

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO
      BEGIN
        -- Recuperamos el monto acumulado anterior de la cuenta
        BEGIN
          SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
            INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
            FROM cb_sal_inv_res_his h
           WHERE h.cod_rubro  = v_cod_rubro
             AND h.nro_cuenta = v_nro_cuenta
             AND h.periodo    = v_periodo ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_saldo_tot_acu    := 0;
            v_saldo_tot_gs_acu := 0;
        END;

        ---- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
        IF v_cod_moneda = v_cod_mon_local THEN
          -- es moneda nacional GS --
          v_mto_cotizacion      := 1;

          v_sal_mon_local       := v_saldo_tot_gs;                       -- saldo moneda local
          v_sal_mon_extranjera := 0;                                  -- saldo moneda extranjera
          v_sal_mon_loc_actual := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
          v_sal_mon_ext_actual := 0;                                  -- saldo acumulado actual extranjero
        ELSE
          -- Moneda extranjera
          v_mto_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);

          v_sal_mon_local       := v_saldo_tot_gs;    -- saldo moneda local
          v_sal_mon_extranjera := v_saldo_total;    -- saldo moneda extranjera
          v_sal_mon_loc_actual := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
          v_sal_mon_ext_actual := (v_saldo_tot_acu + v_saldo_total);     -- saldo acumulado actual extranjero
        END IF;
        -----------------------------------------------------------------------------

        -- Actualizamos la tabla detallada de Inventario de Resultados
        UPDATE cb_sal_inv_resultados_det
           SET sal_mon_extranjera            = sal_mon_extranjera + v_sal_mon_extranjera,
               sal_mon_local                = sal_mon_local + v_sal_mon_local,
               sal_acu_act_mon_extranjera    = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
               sal_acu_act_mon_local        = sal_acu_act_mon_local + v_sal_mon_local
         WHERE fecha      = v_fec_actual
           AND cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el detalle
          INSERT INTO cb_sal_inv_resultados_det
            (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
             sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
          VALUES
            (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
             v_sal_mon_ext_actual, v_sal_mon_loc_actual);
        END IF;

        -- Requerimiento: CNFDEEVO-29.
        -- Fecha: 03/03/2016.
        --Actualizamos la tabla historico
        UPDATE cb_sal_inv_res_his
           SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
               saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
         WHERE cod_rubro   = v_cod_rubro
           AND nro_cuenta  = v_nro_cuenta
           AND periodo     = v_periodo
           AND tipo         = v_tip_cta
           AND cod_oficina = v_cod_oficina;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el historico
          INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
          VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
        END IF;
      END;
    END LOOP;
    CLOSE movimien_his;
    
    v_tip_saldo     := 'K';-- Inventario de Ctas de Resultado
    v_tip_interes   := 'X';-- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)
    v_tip_operacion := 'X';-- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)
    v_fec_periodo   := to_char(v_fec_actual, 'YYYY');
    
     -- Aseguramos la ejecución en serie para evitar errores de paralelismo
  LP_DISABLE_PARALLEL_DML;

  -----------------------------------------------------------------------------------
  --Cargar los datos de origen (Comisiones) en la Tabla Temporal
  -----------------------------------------------------------------------------------

  -- Usamos DELETE para mantener la integridad de la transacción principal
  DELETE FROM cb_sal_movimientos;

  INSERT INTO cb_sal_movimientos
    (cod_modulo,
     cod_modalidad,
     cod_oficina,
     cod_moneda,
     cod_sec_contable,
     residente,
     cod_tip_deudor,
     cod_plazo,
     sal_total,
     cod_rubro,
     nro_cuenta)
    SELECT g.cod_modulo,
           g.cod_modalidad,
           NVL(h.cod_oficina, g.cod_oficina) AS cod_oficina,
           g.cod_moneda,
           c.cod_sec_contable,
           c.residente,
           c.cod_tip_deudor,
           '1' AS cod_plazo,
           h.saldo_tot_gs,
           h.cod_rubro,
           h.nro_cuenta
      FROM cb_sal_inv_res_his h
      JOIN ge_cuentas g
        ON h.nro_cuenta = g.nro_cuenta
      JOIN ge_cta_clientes cc
        ON g.nro_cuenta = cc.nro_cuenta
      JOIN ge_clientes c
        ON cc.cod_persona = c.cod_persona
      JOIN ge_modalidades mo
        ON g.cod_modulo = mo.cod_modulo
       AND g.cod_modalidad = mo.cod_modalidad
     WHERE h.periodo = v_fec_periodo
       AND h.tipo = 'CO' -- Comisiones Pagadas y Cobradas
       AND cc.relacion = 'P';

  -----------------------------------------------------------------------------------
  -- MERGE a la tabla principal (cb_sal_inventarios)
  -----------------------------------------------------------------------------------
  MERGE INTO cb_sal_inventarios inv
  USING (SELECT cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_moneda,
                cod_sec_contable,
                residente,
                cod_tip_deudor,
                cod_plazo,
                cod_rubro,
                SUM(sal_total) AS saldo_acumulado
           FROM cb_sal_movimientos
          GROUP BY cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   cod_moneda,
                   cod_sec_contable,
                   residente,
                   cod_tip_deudor,
                   cod_plazo,
                   cod_rubro) src
  ON (DECODE(inv.cod_modulo, src.cod_modulo, 1, 0) = 1 
  AND DECODE(inv.cod_modalidad, src.cod_modalidad, 1, 0) = 1 
  AND DECODE(inv.cod_oficina, src.cod_oficina, 1, 0) = 1 
  AND DECODE(inv.cod_moneda, src.cod_moneda, 1, 0) = 1 
  AND DECODE(inv.cod_sec_contable, src.cod_sec_contable, 1, 0) = 1 
  AND DECODE(inv.residente, src.residente, 1, 0) = 1 
  AND DECODE(inv.cod_tip_deudor, src.cod_tip_deudor, 1, 0) = 1 
  AND DECODE(inv.tip_saldo, v_tip_saldo, 1, 0) = 1 
  AND DECODE(inv.cod_plazo, src.cod_plazo, 1, 0) = 1 
  AND DECODE(inv.tip_interes, v_tip_interes, 1, 0) = 1 
  AND DECODE(inv.tip_operacion, v_tip_operacion, 1, 0) = 1 
  AND DECODE(inv.cod_rubro, src.cod_rubro, 1, 0) = 1)
  WHEN MATCHED THEN
    UPDATE
       SET inv.sal_total = NVL(inv.sal_total, 0) +
                           NVL(src.saldo_acumulado, 0)
  WHEN NOT MATCHED THEN
    INSERT
      (cod_modulo,
       cod_modalidad,
       cod_oficina,
       cod_moneda,
       cod_sec_contable,
       residente,
       tip_interes,
       tip_operacion,
       cod_tip_deudor,
       tip_saldo,
       cod_plazo,
       sal_total,
       cod_rubro,
       nro_referencia)
    VALUES
      (src.cod_modulo,
       src.cod_modalidad,
       src.cod_oficina,
       src.cod_moneda,
       src.cod_sec_contable,
       src.residente,
       v_tip_interes,
       v_tip_operacion,
       src.cod_tip_deudor,
       v_tip_saldo,
       src.cod_plazo,
       NVL(src.saldo_acumulado, 0),
       src.cod_rubro,
       s_nro_referencia.nextval);

  -----------------------------------------------------------------------------------
  -- MERGE a la tabla de detalle (cb_sal_inventarios_det)
  -----------------------------------------------------------------------------------
  MERGE INTO cb_sal_inventarios_det det
  USING (
    WITH grouped_source AS
     (SELECT nro_cuenta,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             cod_moneda,
             cod_sec_contable,
             residente,
             cod_tip_deudor,
             cod_plazo,
             cod_rubro,
             SUM(sal_total) AS saldo_acumulado
        FROM cb_sal_movimientos
       GROUP BY nro_cuenta,
                cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_moneda,
                cod_sec_contable,
                residente,
                cod_tip_deudor,
                cod_plazo,
                cod_rubro)
    SELECT inv.nro_referencia, gs.nro_cuenta, gs.saldo_acumulado
      FROM grouped_source gs
      JOIN cb_sal_inventarios inv
        ON (DECODE(inv.cod_modulo, gs.cod_modulo, 1, 0) = 1 
        AND DECODE(inv.cod_modalidad, gs.cod_modalidad, 1, 0) = 1 
        AND DECODE(inv.cod_oficina, gs.cod_oficina, 1, 0) = 1 
        AND DECODE(inv.cod_moneda, gs.cod_moneda, 1, 0) = 1 
        AND DECODE(inv.cod_sec_contable, gs.cod_sec_contable, 1, 0) = 1 
        AND DECODE(inv.residente, gs.residente, 1, 0) = 1 
        AND DECODE(inv.cod_tip_deudor, gs.cod_tip_deudor, 1, 0) = 1 
        AND DECODE(inv.tip_saldo, v_tip_saldo, 1, 0) = 1 
        AND DECODE(inv.cod_plazo, gs.cod_plazo, 1, 0) = 1 
        AND DECODE(inv.tip_interes, v_tip_interes, 1, 0) = 1 
        AND DECODE(inv.tip_operacion, v_tip_operacion, 1, 0) = 1 
        AND DECODE(inv.cod_rubro, gs.cod_rubro, 1, 0) = 1)) new_data 
        ON (det.nro_referencia = new_data.nro_referencia 
        AND det.nro_cuenta = new_data.nro_cuenta)
    WHEN MATCHED THEN
      UPDATE
         SET det.sal_anterior = NVL(det.sal_actual, 0),
             det.sal_actual   = NVL(det.sal_actual, 0) +
                                NVL(new_data.saldo_acumulado, 0)
    WHEN NOT MATCHED THEN
      INSERT
        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
      VALUES
        (new_data.nro_referencia, new_data.nro_cuenta,NVL(new_data.saldo_acumulado, 0),0);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_COMISIONES: ' || SQLERRM);
  END PR_ACU_COMISIONES;
-------------------------------------------------------------------------------------------------

-- Insteres Devengado de COMISIONES Diferidas
   PROCEDURE PR_ACU_COM_DIFERIDAS IS
    -- fechas --
    v_fec_actual          ge_calendarios.fec_actual%TYPE;
    -- monedad local --
    v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    -- variables ----
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local        cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual  cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_mto_interes          ah_devengados.mto_interes%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_cod_sec_contable     ge_sec_contables.cod_sec_contable%TYPE;
    v_residente            ge_clientes.residente%TYPE;
    v_tip_deudor           ge_clientes.cod_tip_deudor%TYPE;
    v_tip_saldo            VARCHAR2(01);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);
    v_cod_tip_asiento     ge_tip_asientos.cod_tip_asiento%TYPE;
    v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
    ------------------------- DEFINE MOVIMIEN HIS -----------------------------
      -- Requerimiento: CNFDEEVO-29.
      -- Fecha: 03/03/2016.
      CURSOR movimien_his (p_fecha DATE) IS
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_moneda,
                SUM(md.mto_dev_actual),
                c.cod_sec_contable,
                c.residente,
                md.cod_transaccion,
                md.nro_cuenta,
                to_char(md.fec_ult_proceso,'YYYY') periodo,
                md.cod_oficina
           FROM ge_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = p_fecha
            AND md.nro_cuenta      = cc.nro_cuenta
            AND cc.relacion        = 'P'
            AND c.cod_persona      = cc.cod_persona
            AND md.cod_modulo      = mo.cod_modulo
            AND md.cod_modalidad   = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
       GROUP BY md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                pc.cod_plazo,
                md.cod_transaccion,
                md.nro_cuenta,
                to_char(md.fec_ult_proceso,'YYYY'),
                md.cod_oficina
         UNION
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_moneda,
                (SUM(md.mto_dev_anterior) * -1),
                c.cod_sec_contable,
                c.residente,
                md.cod_transaccion,
                md.nro_cuenta,
                to_char(md.fec_ult_proceso,'YYYY') periodo,
                md.cod_oficina
           FROM ge_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = p_fecha
            AND md.nro_cuenta      = cc.nro_cuenta
            AND cc.relacion        = 'P'
            AND md.estado          = 'C'
            AND c.cod_persona      = cc.cod_persona
            AND md.cod_modulo      = mo.cod_modulo
            AND md.cod_modalidad   = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
       GROUP BY md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda,
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                pc.cod_plazo,
                md.cod_transaccion,
                md.nro_cuenta,
                to_char(md.fec_ult_proceso,'YYYY'),
                md.cod_oficina;

    ------------------------- DEFINE MOVIMIEN DEV -----------------------------
    -- Requerimiento: CNFDEEVO-29.
    -- Fecha: 03/03/2016.
    CURSOR movimien_dev (p_fecha DATE) IS
       SELECT g.cod_modulo,
              g.cod_modalidad,
              NVL(h.cod_oficina,g.cod_oficina),
              h.cod_moneda,
              c.cod_sec_contable,
              c.residente,
              c.cod_tip_deudor,
              to_char(1) cod_plazo,
              h.nro_cuenta,
              h.cod_rubro,
              h.saldo_tot_gs
         FROM cb_sal_inv_res_his h,
              ge_cuentas g,
              ge_clientes      c,
              ge_cta_clientes  cc,
              ge_modalidades   mo
        WHERE h.periodo = to_char(p_fecha,'YYYY')
          AND h.tipo = 'CD'  -- Comisiones Diferidas
          AND h.nro_cuenta = g.nro_cuenta
          AND g.nro_cuenta = cc.nro_cuenta
          AND cc.relacion = 'P'
          AND c.cod_persona = cc.cod_persona
          AND g.cod_modulo = mo.cod_modulo
          AND g.cod_modalidad = mo.cod_modalidad
    ;

   BEGIN
     --Obtiene la Fecha necesarias----------------------
     v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
     -----------------------------------------------------

     -- Cerramos el cursor si se encuentra abierto -------
     IF movimien_his%ISOPEN THEN
       CLOSE movimien_his;
     END IF;
     ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
     OPEN movimien_his (v_fec_actual);
     LOOP
        FETCH movimien_his
          INTO v_cod_modulo,
               v_cod_modalidad,
               v_cod_moneda,
               v_mto_interes,
               v_cod_sec_contable,
               v_residente,
               v_cod_transaccion,
               v_nro_cuenta,
               v_periodo,
               v_cod_oficina;
        EXIT WHEN movimien_his%NOTFOUND;

     -- OBTIENE EL TIPO DE CTA DE RESULTADO (CD=COMISION DIFERIDA)---
     v_tip_cta := 'CD';  --comision diferida
     --------------------------------------------------------------

     --- ve el tipo de asiento de resultado
     BEGIN
      SELECT g.cod_tip_asi_resultado
        INTO v_cod_tip_asiento
        FROM ge_transacciones g
       WHERE g.cod_modulo      = v_cod_modulo
         AND g.cod_modalidad   = v_cod_modalidad
         AND g.cod_transaccion = v_cod_transaccion
         AND g.cod_tip_asi_resultado IS NOT NULL
      ;
     EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                     'NO TIENE ASIENTO RELAC.P/DEVENG COMISION DIFERIDA' ||
                    to_char(v_cod_modulo) || '-' || to_char(v_cod_modalidad) || '-' ||
                    to_char(v_cod_transaccion));
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error PR_ACU_COM_DIFERIDAS ' || SQLERRM);
     END;

     -- Obtenemos el rubro para inventario de resultado
     BEGIN
      SELECT a.cod_rubro
        INTO v_cod_rubro
        FROM ge_tip_asientos a
       WHERE a.cod_tip_asiento     = v_cod_tip_asiento
         AND a.cod_moneda          = v_cod_moneda
         AND (a.cod_sec_contable   = v_cod_sec_contable OR a.cod_sec_contable IS NULL)
         AND (a.ind_residente      = v_residente OR a.ind_residente = 'X')
         AND SUBSTR(a.cod_rubro,1,1) IN ('6','7')
       ;
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
          v_cod_rubro := 'X';
     END;
     --------------------------------------------------------------

     -- GUARDAMOS LOS MONTOS EN UN HISTORICO
     BEGIN
        -- Recuperamos el monto acumulado anterior de la cuenta
        BEGIN
          SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
            INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
            FROM cb_sal_inv_res_his h
           WHERE h.cod_rubro  = v_cod_rubro
             AND h.nro_cuenta = v_nro_cuenta
             AND h.periodo     = v_periodo
             AND h.cod_moneda = v_cod_moneda -- SOLO PARA COMISION DIFERIDA VERIFICAMOS LA MONEDA
             ;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_saldo_tot_acu    := 0;
            v_saldo_tot_gs_acu := 0;
        END;

        --- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
        IF v_cod_moneda = v_cod_mon_local THEN
          -- es moneda nacional GS --
          v_mto_cotizacion    := 1;
          v_saldo_tot_gs     := v_mto_interes;
          v_saldo_total       := 0;

          v_sal_mon_local        := v_saldo_tot_gs;                     -- saldo moneda local
          v_sal_mon_extranjera  := 0;                                  -- saldo moneda extranjera
          v_sal_mon_loc_actual  := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
          v_sal_mon_ext_actual  := 0;                                  -- saldo acumulado actual extranjero
        ELSE
          -- Moneda extranjera
          -- Obtiene la cotizacion de cierre
          v_mto_cotizacion    := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
          v_saldo_tot_gs     := v_mto_interes;
          v_saldo_total       := round(v_mto_interes / v_mto_cotizacion, 2);

          v_sal_mon_local        := v_saldo_tot_gs;                       -- saldo moneda local
          v_sal_mon_extranjera  := v_saldo_total;                         -- saldo moneda extranjera
          v_sal_mon_loc_actual  := (v_saldo_tot_gs_acu + v_saldo_tot_gs);-- saldo acumulado actual local
          v_sal_mon_ext_actual  := (v_saldo_tot_acu + v_saldo_total);    -- saldo acumulado actual extranjero
        END IF;
        -----------------------------------------------------------------------------

        -- Actualizamos la tabla detallada de Inventario de Resultados
        UPDATE cb_sal_inv_resultados_det
           SET sal_mon_extranjera           = sal_mon_extranjera + v_sal_mon_extranjera,
               sal_mon_local               = sal_mon_local + v_sal_mon_local,
               sal_acu_act_mon_extranjera   = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
               sal_acu_act_mon_local       = sal_acu_act_mon_local + v_sal_mon_local
         WHERE fecha      = v_fec_actual
           AND cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el detalle
          INSERT INTO cb_sal_inv_resultados_det
            (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
             sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
          VALUES
            (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
             v_sal_mon_ext_actual, v_sal_mon_loc_actual);
        END IF;

-- Solo para las Comisiones Diferidas guardamos la moneda del movimiento --
        --Actualizamos la tabla historico
        -- Requerimiento: CNFDEEVO-29.
        -- Fecha: 03/03/2016.
        UPDATE cb_sal_inv_res_his
           SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
               saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
         WHERE cod_rubro  = v_cod_rubro
           AND nro_cuenta = v_nro_cuenta
           AND periodo    = v_periodo
           AND tipo         = v_tip_cta
           AND cod_moneda = v_cod_moneda
           AND cod_oficina = v_cod_oficina;

        IF SQL%NOTFOUND THEN
          -- Insertamos nuevos valores en el historico
          INSERT INTO cb_sal_inv_res_his
                 (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_moneda, cod_oficina)
          VALUES
                 (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_moneda, v_cod_oficina);
        END IF;
      END;
    END LOOP;
    CLOSE movimien_his;

    -- Cerramos el cursor si se encuentra abierto -------
    IF movimien_dev%ISOPEN THEN
      CLOSE movimien_dev;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN movimien_dev (v_fec_actual);
    LOOP
      FETCH movimien_dev
       INTO v_cod_modulo,
            v_cod_modalidad,
            v_cod_oficina,
            v_cod_moneda,
            v_cod_sec_contable,
            v_residente,
            v_tip_deudor,
            v_cod_plazo,
            v_nro_cuenta,
            v_cod_rubro,
            v_saldo_acumulado;
      EXIT WHEN movimien_dev%NOTFOUND;

      -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
       v_tip_saldo := 'K'; -- Inventario de Ctas de Resultado
      --------------------------------------------------------------

      -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
      v_tip_interes := 'X';
      --------------------------------------------------------------

      -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
      v_tip_operacion := 'X';
      --------------------------------------------------------------

      -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
      BEGIN
        SELECT nro_referencia, ROWID
           INTO v_nro_referencia, v_rowid
          FROM cb_sal_inventarios
         WHERE cod_modulo       = v_cod_modulo
           AND cod_modalidad    = v_cod_modalidad
           AND cod_oficina      = v_cod_oficina
           AND cod_moneda       = v_cod_moneda
           AND cod_sec_contable = v_cod_sec_contable
           AND residente        = v_residente
           AND cod_tip_deudor   = v_tip_deudor
           AND tip_saldo        = v_tip_saldo
           AND cod_plazo        = v_cod_plazo
           AND tip_interes       = v_tip_interes
           AND tip_operacion     = v_tip_operacion
           AND cod_rubro        = v_cod_rubro;

       IF v_nro_referencia IS NOT NULL THEN
        UPDATE cb_sal_inventarios
           SET sal_total = nvl(sal_total, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND ROWID          = v_rowid;

        --------------Genero detalle----------------
        UPDATE cb_sal_inventarios_det
           SET sal_anterior = nvl(sal_actual, 0),
               sal_actual   = nvl(sal_actual, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta     = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
           INSERT INTO cb_sal_inventarios_det
           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
           VALUES
           (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0), 0);
        END IF;
       END IF;
      EXCEPTION
      WHEN no_data_found THEN
         ------------------------------
         -- INSERTA MONTO DEVENGADO --
         ------------------------------
         SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

         INSERT INTO cb_sal_inventarios
            (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_sec_contable, residente, tip_interes,
             tip_operacion, cod_tip_deudor, tip_saldo, cod_plazo, sal_total, cod_rubro, nro_referencia)
         VALUES
            (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_cod_sec_contable, v_residente, v_tip_interes,
             v_tip_operacion, v_tip_deudor, v_tip_saldo, v_cod_plazo, nvl(v_saldo_acumulado, 0), v_cod_rubro, v_nro_referencia);

         INSERT INTO cb_sal_inventarios_det
             (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
             (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0),0 );
      END;
    END LOOP;
    CLOSE movimien_dev;


  EXCEPTION
  WHEN OTHERS THEN
       ROLLBACK;
       raise_application_error(-20000, 'ERROR PR_ACU_COM_DIFERIDAS: ' || SQLERRM);
  END PR_ACU_COM_DIFERIDAS;
-----------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------
-- Operaciones de cambios
PROCEDURE PR_ACU_OPE_CAMBIOS IS
    -- Variables.
    v_fecha                      ge_movimientos.fecha%type;
    v_hora                       ge_movimientos.hora%type;
    v_cod_usuario                ge_movimientos.cod_usuario%type;
    v_fec_actual                 ge_calendarios.fec_actual%TYPE;
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_modulo                 cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad              cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina                cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable           cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor             cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente                  cb_sal_inventarios.residente%TYPE;
    v_situacion                  cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo                  cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion              cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes                cb_sal_inventarios.tip_interes%TYPE;
    v_nro_referencia             cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado            cb_sal_inventarios.sal_total%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_periodo                    cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo                  VARCHAR2(01);
    v_cod_rubro                  VARCHAR2(15);
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    v_cod_mon_local              ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;

    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
       SELECT REPLACE(d.cod_rubro,' ','') cod_rubro,
              m.FECHA,
              m.HORA,
              m.COD_USUARIO,
              (case when m.COD_TRANSACCION in (783,784) then
                  fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,cb.COD_MONEDA,'31')
               else
                  NULL
               end) NRO_CUENTA,
              to_char(m.fecha,'YYYY') periodo,
              SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                      end) MONTO,
               SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                   else
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                   end) MTO_EQU_LOCAL,
              cb.COD_MONEDA,
              m.cod_oficina
         FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th, cb_rubros cb
        WHERE d.fecha                 = v_fec_actual
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'OPE_CAMBIO')
          AND d.fecha                 = m.fecha
          AND d.ref_movimiento        = m.nro_documento4
          AND m.cod_modulo            = th.cod_modulo(+)
          AND m.cod_modalidad         = th.cod_modalidad(+)
          AND m.cod_transaccion       = th.cod_transaccion(+)
          AND d.cod_rubro             = cb.cod_rubro
     GROUP BY d.cod_rubro, m.fecha, m.hora, m.cod_usuario,
              (case when m.COD_TRANSACCION in (783,784) then
                  fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,cb.COD_MONEDA,'31')
               else
                  NULL
               end), to_char(m.fecha,'YYYY'), cb.cod_moneda, m.cod_oficina
       UNION ALL
       SELECT d.cod_rubro,
              NULL,
              NULL,
              NULL,
              fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,r.cod_moneda,d.cod_oficina) NRO_CUENTA,
              to_char(d.fecha,'YYYY'),
              SUM(decode(r.cod_moneda,'GS',d.mto_mon_local,d.mto_mon_rubro))monto,
              SUM(d.mto_mon_local),
              r.cod_moneda,
              d.cod_oficina
         FROM cb_asi_automaticos_det d, cb_rubros r
        WHERE d.fecha                 = v_fec_actual
          AND d.cod_rubro             = r.cod_rubro
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND d.tip_movimiento        ='D'
          AND SUBSTR(d.cod_rubro,6,3) IN (SELECT b.val_minimo FROM ba_cod_referencias b WHERE b.dominio = 'OPE_CAMBIO')
          AND d.ref_movimiento IS NULL
     GROUP BY d.cod_rubro, fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,r.cod_moneda,d.cod_oficina), to_char(d.fecha,'YYYY'),
              r.COD_MONEDA, d.cod_oficina;

  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  CURSOR c_mov_inventario(p_fecha DATE) IS
       SELECT g.cod_modulo,
              g.cod_modalidad,
              NVL(h.cod_oficina,g.cod_oficina),
              h.cod_moneda,
              c.cod_sec_contable,
              c.residente,
              c.cod_tip_deudor,
              to_char(1) cod_plazo,
              h.nro_cuenta,
              h.cod_rubro,
              h.saldo_tot_gs
         FROM cb_sal_inv_res_his h,
              ge_cuentas g,
              ge_clientes      c,
              ge_cta_clientes  cc,
              ge_modalidades   mo
        WHERE h.periodo   = to_char(p_fecha,'YYYY')
          AND h.tipo     = 'OC'  -- Operaciones de cambios
          AND h.nro_cuenta   = g.nro_cuenta
          AND g.nro_cuenta   = cc.nro_cuenta
          AND cc.relacion   = 'P'
          AND c.cod_persona = cc.cod_persona
          AND g.cod_modulo   = mo.cod_modulo
          AND g.cod_modalidad = mo.cod_modalidad;

  -- Funciones.
  FUNCTION lf_obt_nro_cuenta(p_fecha ge_movimientos.fecha%type,
                             p_hora  ge_movimientos.hora%type,
                             p_cod_usuario ge_movimientos.cod_usuario%type)
  RETURN VARCHAR2
  AS
  v_nro_cuenta     ge_movimientos.nro_cuenta%type;
  v_cod_persona    ge_movimientos.cod_persona%type;
  v_cod_moneda     ge_movimientos.cod_moneda%type;
  BEGIN
    begin
       select ge.nro_cuenta, ge.cod_persona, ge.cod_moneda
         into v_nro_cuenta, v_cod_persona, v_cod_moneda
         from ge_movimientos ge
        where ge.fecha         = p_fecha
          and ge.hora          = p_hora
          and ge.cod_usuario   = p_cod_usuario
          and ge.nro_secuencia = 1;

       IF v_nro_cuenta IS NULL AND v_cod_persona IS NOT NULL THEN
          select v.nro_cuenta
            into v_nro_cuenta
            from (
              select a.nro_cuenta, a.cod_modulo
                from ge_cuentas a, ge_cta_clientes b
               where a.nro_cuenta  = b.nro_cuenta
                 and b.cod_persona = v_cod_persona
                 and a.cod_moneda  = v_cod_moneda
                 and a.cod_modulo in (3,4)
                 and a.estado not in ('A', 'C', 'X')
              order by a.cod_modulo desc
            ) v
            where rownum = 1;
       END IF;
    end;
       return v_nro_cuenta;
  EXCEPTION
     WHEN OTHERS THEN
       v_nro_cuenta := NULL;
       return v_nro_cuenta;
  END;

  BEGIN

    -- Obtengo la fecha calendario.
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN c_mov_historicos (v_fec_actual);
    LOOP
      FETCH c_mov_historicos
       INTO v_cod_rubro,
            v_fecha,
            v_hora,
            v_cod_usuario,
            v_nro_cuenta,
            v_periodo,
            v_saldo_total,
            v_saldo_tot_gs,
            v_cod_moneda,
            v_cod_oficina;
    EXIT WHEN c_mov_historicos%NOTFOUND;

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (OC=OPERACIONES DE CAMBIOS)---
    v_tip_cta := 'OC';
    --
    IF v_nro_cuenta IS NULL THEN
       v_nro_cuenta := NVL(NVL(lf_obt_nro_cuenta(v_fecha,v_hora,v_cod_usuario),fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina)),'9999999999');
    END IF;

    BEGIN
      BEGIN
         --Obtiene los montos acumuldos anteriores
         SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
           INTO v_mto_ori_ant,v_mto_loc_ant
           FROM cb_sal_inv_res_his i
          WHERE i.nro_cuenta  = v_nro_cuenta
            AND i.cod_rubro    = v_cod_rubro
            AND i.periodo     = to_char(v_fec_actual,'YYYY') ;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_loc_ant:=0;
            v_mto_ori_ant:=0;
      END;
      IF v_cod_moneda = v_cod_mon_local THEN
      v_cotizacion                      := 1;
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := 0;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera    := 0;
      ELSE
       v_cotizacion                     := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := v_saldo_total;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_saldo_total,0);
      END IF;
      -- Si existe el registro actualizar.
      UPDATE cb_sal_inv_resultados_det d
         SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
             d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
             d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
             d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND fecha=v_fec_actual;

      -- Se inserta en la tabla de detalle diario.
      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inv_resultados_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
         VALUES
            (v_fec_actual,v_cod_rubro,v_nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
      END IF;

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
      UPDATE cb_sal_inv_res_his
         SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
             saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND periodo     = v_periodo
         AND tipo         = v_tip_cta
         AND cod_oficina = v_cod_oficina;

      IF SQL%NOTFOUND THEN
         -- Insertamos nuevos valores
         INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
              VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
      END IF;
    END;
    END LOOP;
    CLOSE c_mov_historicos;

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_inventario%ISOPEN THEN
      CLOSE c_mov_inventario;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN c_mov_inventario (v_fec_actual);
    LOOP
      FETCH c_mov_inventario
        INTO v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             v_cod_moneda,
             v_cod_sec_contable,
             v_residente,
             v_cod_tip_deudor,
             v_cod_plazo,
             v_nro_cuenta,
             v_cod_rubro,
             v_saldo_acumulado;
    EXIT WHEN c_mov_inventario%NOTFOUND;

    -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
    v_tip_saldo := 'K';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
    v_tip_interes := 'X';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
    v_tip_operacion := 'X';
    --------------------------------------------------------------

    -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
    BEGIN
      SELECT nro_referencia
        INTO v_nro_referencia
        FROM cb_sal_inventarios
       WHERE cod_modulo       = v_cod_modulo
         AND cod_modalidad    = v_cod_modalidad
         AND cod_oficina      = v_cod_oficina
         AND cod_sec_contable = v_cod_sec_contable
         AND cod_tip_deudor   = v_cod_tip_deudor
         AND residente        = v_residente
         AND cod_moneda       = v_cod_moneda
         AND situacion        = v_situacion
         AND tip_saldo        = v_tip_saldo
         AND cod_plazo        = v_cod_plazo
         AND tip_operacion    = v_tip_operacion
         AND tip_interes      = v_tip_interes
         AND cod_rubro        = v_cod_rubro;

      IF v_nro_referencia IS NOT NULL THEN
        UPDATE cb_sal_inventarios
           SET sal_total = nvl(sal_total, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia;

        --------------Genero detalle----------------
        UPDATE cb_sal_inventarios_det
           SET sal_anterior = nvl(sal_actual, 0),
               sal_actual   = nvl(sal_actual, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta     = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0), 0);
        END IF;
      END IF;
    EXCEPTION
    WHEN no_data_found THEN
       ------------------------------
       -- INSERTA MONTO DEVENGADO --
       ------------------------------
       SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

      INSERT INTO cb_sal_inventarios
          (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
           residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
           tip_interes, sal_total, cod_rubro, nro_referencia)
       VALUES
          (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
           v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
           v_cod_plazo, v_tip_operacion, v_tip_interes, nvl(v_saldo_acumulado,0), v_cod_rubro,
           v_nro_referencia);

       INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
       VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado,0), 0);
    END;
    END LOOP;
    CLOSE c_mov_inventario;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_OPE_CAMBIOS: ' || SQLERRM);
  END PR_ACU_OPE_CAMBIOS;
-----------------------------------------------------------------------------------------------------------

-- Previsiones
  PROCEDURE PR_ACU_PREVISIONES IS
    -- Variables.
    v_fec_actual           ge_calendarios.fec_actual%TYPE;
    v_cod_mon_local        ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local        cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual   cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual   cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_cod_sec_contable     ge_sec_contables.cod_sec_contable%TYPE;
    v_residente            ge_clientes.residente%TYPE;
    v_tip_deudor           ge_clientes.cod_tip_deudor%TYPE;
    v_tip_saldo            VARCHAR2(01);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);
    v_referencia           ge_movimientos.referencia%type;
    v_cod_transaccion      ge_movimientos.cod_transaccion%type;
    v_fec_periodo          varchar2(4);
    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
       SELECT REPLACE(d.cod_rubro,' ','') COD_RUBRO,
              m.nro_cuenta NRO_CUENTA,
              m.referencia,
              m.cod_transaccion,
              to_char(m.fecha,'YYYY') PERIODO,
              SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                      end) MONTO,
               SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                   else
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                   end) MTO_EQU_LOCAL,
              cb.cod_moneda,
              m.cod_oficina
         FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th, cb_rubros cb
        WHERE d.fecha           = v_fec_actual
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'PREVISION')
          AND d.fecha           = m.fecha
          AND d.ref_movimiento  = m.nro_documento4
          AND m.cod_modulo      = th.cod_modulo(+)
          AND m.cod_modalidad   = th.cod_modalidad(+)
          AND m.cod_transaccion = th.cod_transaccion(+)
          AND d.cod_rubro       = cb.cod_rubro
     GROUP BY d.cod_rubro, m.nro_cuenta, m.referencia, m.cod_transaccion, to_char(m.fecha,'YYYY'), cb.cod_moneda, m.cod_oficina;

     PROCEDURE LP_DISABLE_PARALLEL_DML
      IS
        PRAGMA AUTONOMOUS_TRANSACTION;
      BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
        COMMIT; -- Esto solo confirma la transacción del ALTER SESSION, no la del procedimiento principal.
      EXCEPTION
        WHEN OTHERS THEN
          -- ORA-12841: puede ocurrir si la sesión ya está en modo serial. Lo ignoramos de forma segura.
          IF SQLCODE = -12841 THEN
            NULL; 
          ELSE
            RAISE;
          END IF;
      END LP_DISABLE_PARALLEL_DML;

  BEGIN

  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
  -----------------------------------------------------

  -- Cerramos el cursor si se encuentra abierto -------
  IF c_mov_historicos%ISOPEN THEN
     CLOSE c_mov_historicos;
  END IF;
  --
  OPEN c_mov_historicos(v_fec_actual);
  LOOP
     FETCH c_mov_historicos
      INTO v_cod_rubro,
           v_nro_cuenta,
           v_referencia,
           v_cod_transaccion,
           v_periodo,
           v_saldo_total,
           v_saldo_tot_gs,
           v_cod_moneda,
           v_cod_oficina;
      EXIT WHEN c_mov_historicos%NOTFOUND;

  ---DYDMR-13777 - ITGF - Previsiones específicas. BANCO BILBAO VIZCAYA ARGENTARIA PY.S.A.
  --Si es Previsiones diferidas asignar la referencia que contiene el dato de cuenta
  If v_cod_transaccion = 9124 then
   v_nro_cuenta := v_referencia;
  end if;

  --SI EL NRO DE CUENTA ES NULO LE ASIGNAMOS UNA CUENTA GENERICA DE ACUERDO A LA MONEDA
  IF v_nro_cuenta IS NULL THEN
    v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
  END IF;
  --

  -- OBTIENE EL TIPO DE CTA DE RESULTADO (PR=PREVISIONES).
  v_tip_cta := 'PR';
  --

  -- GUARDAMOS LOS MONTOS EN UN HISTORICO
  BEGIN
     -- Recuperamos el monto acumulado anterior de la cuenta
     BEGIN
        SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
          INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
          FROM cb_sal_inv_res_his h
         WHERE h.cod_rubro  = v_cod_rubro
           AND h.nro_cuenta = v_nro_cuenta
           AND h.periodo    = v_periodo ;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           v_saldo_tot_acu    := 0;
           v_saldo_tot_gs_acu := 0;
     END;

     ---- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
     IF v_cod_moneda = v_cod_mon_local THEN
        -- Moneda local --
        v_mto_cotizacion      := 1;

        v_sal_mon_local       := v_saldo_tot_gs;                      -- saldo moneda local
        v_sal_mon_extranjera  := 0;                                  -- saldo moneda extranjera
        v_sal_mon_loc_actual  := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
        v_sal_mon_ext_actual  := 0;                                  -- saldo acumulado actual extranjero
     ELSE
        -- Moneda extranjera --
        v_mto_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);

        v_sal_mon_local       := v_saldo_tot_gs;                         -- saldo moneda local
        v_sal_mon_extranjera  := v_saldo_total;                          -- saldo moneda extranjera
        v_sal_mon_loc_actual  := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
        v_sal_mon_ext_actual  := (v_saldo_tot_acu + v_saldo_total);      -- saldo acumulado actual extranjero
     END IF;
     -----------------------------------------------------------------------------

     -- Actualizamos la tabla detallada de Inventario de Resultados
     UPDATE cb_sal_inv_resultados_det
        SET sal_mon_extranjera          = sal_mon_extranjera + v_sal_mon_extranjera,
            sal_mon_local               = sal_mon_local + v_sal_mon_local,
            sal_acu_act_mon_extranjera  = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
            sal_acu_act_mon_local       = sal_acu_act_mon_local + v_sal_mon_local
      WHERE fecha      = v_fec_actual
        AND cod_rubro  = v_cod_rubro
        AND nro_cuenta = v_nro_cuenta;

     IF SQL%NOTFOUND THEN
        -- Insertamos nuevos valores en el detalle
        INSERT INTO cb_sal_inv_resultados_det
                    (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
                    sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
             VALUES
                    (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
                     v_sal_mon_ext_actual, v_sal_mon_loc_actual);
     END IF;

     -- Requerimiento: CNFDEEVO-29.
     -- Fecha: 03/03/2016.
     --Actualizamos la tabla historico
     UPDATE cb_sal_inv_res_his
        SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
            saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
      WHERE cod_rubro   = v_cod_rubro
        AND nro_cuenta  = v_nro_cuenta
        AND periodo     = v_periodo
        AND tipo        = v_tip_cta
        AND cod_oficina = v_cod_oficina;

     IF SQL%NOTFOUND THEN
        -- Insertamos nuevos valores en el historico
        INSERT INTO cb_sal_inv_res_his
                   (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
             VALUES
                   (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
     END IF;
  END;
  END LOOP;
  CLOSE c_mov_historicos;
  
  v_tip_saldo     := 'K'; -- Inventario de Ctas de Resultado
  v_tip_interes   := 'X'; -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)
  v_tip_operacion := 'X'; -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)
  v_fec_periodo   := to_char(v_fec_actual, 'YYYY');
  
   -- Aseguramos la ejecución en serie para evitar errores de paralelismo
  LP_DISABLE_PARALLEL_DML;

  -----------------------------------------------------------------------------------
  -- PASO 1: Cargar los datos de origen en la Tabla Temporal
  -----------------------------------------------------------------------------------

  -- Usamos DELETE para mantener la integridad de la transacción principal
  DELETE FROM cb_sal_movimientos;

  -- Insertamos los datos del cursor c_mov_inventario en la GTT
  INSERT INTO cb_sal_movimientos
    (cod_modulo,
     cod_modalidad,
     cod_oficina,
     cod_moneda,
     cod_sec_contable,
     residente,
     cod_tip_deudor,
     cod_plazo,
     sal_total,
     cod_rubro,
     nro_cuenta)
    SELECT g.cod_modulo,
           g.cod_modalidad,
           NVL(h.cod_oficina, g.cod_oficina) AS cod_oficina,
           g.cod_moneda,
           c.cod_sec_contable,
           c.residente,
           c.cod_tip_deudor,
           '1' AS cod_plazo, -- El valor es constante '1' según el cursor
           h.saldo_tot_gs,
           h.cod_rubro,
           h.nro_cuenta
      FROM cb_sal_inv_res_his h
      JOIN ge_cuentas g
        ON h.nro_cuenta = g.nro_cuenta
      JOIN ge_cta_clientes cc
        ON g.nro_cuenta = cc.nro_cuenta
      JOIN ge_clientes c
        ON cc.cod_persona = c.cod_persona
      JOIN ge_modalidades mo
        ON g.cod_modulo = mo.cod_modulo
       AND g.cod_modalidad = mo.cod_modalidad
     WHERE h.periodo = v_fec_periodo
       AND h.tipo = 'PR' -- Previsiones
       AND cc.relacion = 'P';

  -----------------------------------------------------------------------------------
  -- PASO 2: MERGE a la tabla principal (cb_sal_inventarios)
  -----------------------------------------------------------------------------------
  MERGE INTO cb_sal_inventarios inv
  USING (SELECT cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_moneda,
                cod_sec_contable,
                residente,
                cod_tip_deudor,
                cod_plazo,
                cod_rubro,
                SUM(sal_total) AS saldo_acumulado
           FROM cb_sal_movimientos
          GROUP BY cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   cod_moneda,
                   cod_sec_contable,
                   residente,
                   cod_tip_deudor,
                   cod_plazo,
                   cod_rubro) src
  ON (DECODE(inv.cod_modulo, src.cod_modulo, 1, 0) = 1 
  AND DECODE(inv.cod_modalidad, src.cod_modalidad, 1, 0) = 1 
  AND DECODE(inv.cod_oficina, src.cod_oficina, 1, 0) = 1 
  AND DECODE(inv.cod_moneda, src.cod_moneda, 1, 0) = 1 
  AND DECODE(inv.cod_sec_contable, src.cod_sec_contable, 1, 0) = 1 
  AND DECODE(inv.residente, src.residente, 1, 0) = 1 
  AND DECODE(inv.cod_tip_deudor, src.cod_tip_deudor, 1, 0) = 1
  AND DECODE(inv.tip_saldo, v_tip_saldo, 1, 0) = 1 
  AND DECODE(inv.cod_plazo, src.cod_plazo, 1, 0) = 1 
  AND DECODE(inv.tip_interes, v_tip_interes, 1, 0) = 1 
  AND DECODE(inv.tip_operacion, v_tip_operacion, 1, 0) = 1 
  AND DECODE(inv.cod_rubro, src.cod_rubro, 1, 0) = 1)
  WHEN MATCHED THEN
    UPDATE
       SET inv.sal_total = NVL(inv.sal_total, 0) +
                           NVL(src.saldo_acumulado, 0)
  WHEN NOT MATCHED THEN
    INSERT
      (cod_modulo,
       cod_modalidad,
       cod_oficina,
       cod_moneda,
       cod_sec_contable,
       residente,
       tip_interes,
       tip_operacion,
       cod_tip_deudor,
       tip_saldo,
       cod_plazo,
       sal_total,
       cod_rubro,
       nro_referencia)
    VALUES
      (src.cod_modulo,
       src.cod_modalidad,
       src.cod_oficina,
       src.cod_moneda,
       src.cod_sec_contable,
       src.residente,
       v_tip_interes,
       v_tip_operacion,
       src.cod_tip_deudor,
       v_tip_saldo,
       src.cod_plazo,
       NVL(src.saldo_acumulado, 0),
       src.cod_rubro,
       s_nro_referencia.nextval);

  -----------------------------------------------------------------------------------
  -- PASO 3: MERGE a la tabla de detalle (cb_sal_inventarios_det)
  -----------------------------------------------------------------------------------
  MERGE INTO cb_sal_inventarios_det det
  USING (
    WITH grouped_source AS
     (SELECT nro_cuenta,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             cod_moneda,
             cod_sec_contable,
             residente,
             cod_tip_deudor,
             cod_plazo,
             cod_rubro,
             SUM(sal_total) AS saldo_acumulado
        FROM cb_sal_movimientos
       GROUP BY nro_cuenta,
                cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_moneda,
                cod_sec_contable,
                residente,
                cod_tip_deudor,
                cod_plazo,
                cod_rubro)
    SELECT inv.nro_referencia, gs.nro_cuenta, gs.saldo_acumulado
      FROM grouped_source gs
      JOIN cb_sal_inventarios inv
        ON (DECODE(inv.cod_modulo, gs.cod_modulo, 1, 0) = 1 
        AND DECODE(inv.cod_modalidad, gs.cod_modalidad, 1, 0) = 1 
        AND DECODE(inv.cod_oficina, gs.cod_oficina, 1, 0) = 1 
        AND DECODE(inv.cod_moneda, gs.cod_moneda, 1, 0) = 1 
        AND DECODE(inv.cod_sec_contable, gs.cod_sec_contable, 1, 0) = 1 
        AND DECODE(inv.residente, gs.residente, 1, 0) = 1 
        AND DECODE(inv.cod_tip_deudor, gs.cod_tip_deudor, 1, 0) = 1 
        AND DECODE(inv.tip_saldo, v_tip_saldo, 1, 0) = 1 
        AND DECODE(inv.cod_plazo, gs.cod_plazo, 1, 0) = 1 
        AND DECODE(inv.tip_interes, v_tip_interes, 1, 0) = 1 
        AND DECODE(inv.tip_operacion, v_tip_operacion, 1, 0) = 1 
        AND DECODE(inv.cod_rubro, gs.cod_rubro, 1, 0) = 1)) new_data 
        ON (det.nro_referencia = new_data.nro_referencia 
        AND det.nro_cuenta = new_data.nro_cuenta) 
    WHEN MATCHED THEN
        UPDATE
         SET det.sal_anterior = NVL(det.sal_actual, 0),
             det.sal_actual   = NVL(det.sal_actual, 0) +
                                NVL(new_data.saldo_acumulado, 0)
    WHEN NOT MATCHED THEN
      INSERT
        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
      VALUES
        (new_data.nro_referencia, new_data.nro_cuenta,NVL(new_data.saldo_acumulado, 0),0);

  EXCEPTION
    WHEN OTHERS THEN
         ROLLBACK;
         raise_application_error(-20000, 'ERROR PR_ACU_PREVISIONES: ' || SQLERRM);
  END PR_ACU_PREVISIONES;
  -----------------------------------------------------------------------------------------------------

-- Valuaciones
  PROCEDURE PR_ACU_VALUACIONES IS
    -- Variables.
    v_fec_actual           ge_calendarios.fec_actual%TYPE;
    v_cod_mon_local        ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_cod_modulo           cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad        cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina          cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_moneda           cb_sal_inventarios.cod_moneda%TYPE;
    v_cod_plazo            cb_sal_inventarios.cod_plazo%TYPE;
    v_nro_referencia       cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total          cb_sal_inventarios.sal_total%TYPE;
    v_tip_operacion        cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes          cb_sal_inventarios.tip_interes%TYPE;
    v_saldo_tot_gs         cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_tot_acu        cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs_acu     cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado      cb_sal_inventarios.sal_total%TYPE;
    v_sal_mon_extranjera   cb_sal_inv_resultados_det.sal_mon_extranjera%TYPE;
    v_sal_mon_local        cb_sal_inv_resultados_det.sal_mon_local%TYPE;
    v_sal_mon_ext_actual   cb_sal_inv_resultados_det.sal_acu_act_mon_extranjera%TYPE;
    v_sal_mon_loc_actual   cb_sal_inv_resultados_det.sal_acu_act_mon_local%TYPE;
    v_nro_cuenta           pr_devengados.nro_cuenta%TYPE;
    v_periodo              cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta              cb_sal_inv_res_his.tipo%TYPE;
    v_mto_cotizacion       ge_cotizaciones.val_conversion%TYPE;
    v_cod_sec_contable     ge_sec_contables.cod_sec_contable%TYPE;
    v_residente            ge_clientes.residente%TYPE;
    v_tip_deudor           ge_clientes.cod_tip_deudor%TYPE;
    v_tip_saldo            VARCHAR2(01);
    v_cod_rubro            VARCHAR2(15);
    v_rowid                VARCHAR2(30);

    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
       SELECT REPLACE(d.cod_rubro,' ','') COD_RUBRO,
              NULL NRO_CUENTA, -- Se informa solamente con la cuenta del banco.
              to_char(m.fecha,'YYYY') PERIODO,
              SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                      end) MONTO,
               SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                      end) MTO_EQU_LOCAL,
              cb.cod_moneda,
              m.cod_oficina
         FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th, cb_rubros cb
        WHERE d.fecha           = v_fec_actual
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'VALUACION')
          AND d.fecha           = m.fecha
          AND d.ref_movimiento  = m.nro_documento4
          AND m.cod_modulo      = th.cod_modulo(+)
          AND m.cod_modalidad   = th.cod_modalidad(+)
          AND m.cod_transaccion = th.cod_transaccion(+)
          AND d.cod_rubro       = cb.cod_rubro
     GROUP BY d.cod_rubro, m.nro_cuenta, to_char(m.fecha,'YYYY'), cb.cod_moneda, m.cod_oficina;

    -- Requerimiento: CNFDEEVO-29.
    -- Fecha: 03/03/2016.
    CURSOR c_mov_inventario (p_fecha DATE) IS
       SELECT g.cod_modulo,
              g.cod_modalidad,
              NVL(h.cod_oficina,g.cod_oficina),
              g.cod_moneda,
              c.cod_sec_contable,
              c.residente,
              c.cod_tip_deudor,
              to_char(1) cod_plazo,
              h.saldo_tot_gs,
              h.cod_rubro,
              h.nro_cuenta
         FROM cb_sal_inv_res_his h,
              ge_cuentas g,
              ge_clientes      c,
              ge_cta_clientes  cc,
              ge_modalidades   mo
        WHERE h.periodo        = to_char(p_fecha,'YYYY')
          AND h.tipo           = 'VL'  -- Valuaciones.
          AND h.nro_cuenta     = g.nro_cuenta
          AND g.nro_cuenta     = cc.nro_cuenta
          AND cc.relacion      = 'P'
          AND c.cod_persona    = cc.cod_persona
          AND g.cod_modulo     = mo.cod_modulo
          AND g.cod_modalidad  = mo.cod_modalidad;
          TYPE r_mov_inventario IS RECORD (
            cod_modulo       ge_cuentas.cod_modulo%TYPE,
            cod_modalidad    ge_cuentas.cod_modalidad%TYPE,
            cod_oficina      ge_cuentas.cod_oficina%TYPE,
            cod_moneda       ge_cuentas.cod_moneda%TYPE,
            cod_sec_contable ge_clientes.cod_sec_contable%TYPE,
            residente        ge_clientes.residente%TYPE,
            tip_deudor       ge_clientes.cod_tip_deudor%TYPE,
            cod_plazo        VARCHAR2(10), 
            saldo_acumulado  cb_sal_inv_res_his.saldo_tot_gs%TYPE,
            cod_rubro        cb_sal_inv_res_his.cod_rubro%TYPE,
            nro_cuenta       ge_cuentas.nro_cuenta%TYPE
          );

          TYPE t_mov_inventario IS TABLE OF r_mov_inventario;
          l_movimientos t_mov_inventario;

  BEGIN

  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
  -----------------------------------------------------

  -- Cerramos el cursor si se encuentra abierto -------
  IF c_mov_historicos%ISOPEN THEN
     CLOSE c_mov_historicos;
  END IF;
  --
  OPEN c_mov_historicos(v_fec_actual);
  LOOP
     FETCH c_mov_historicos
      INTO v_cod_rubro,
           v_nro_cuenta,
           v_periodo,
           v_saldo_total,
           v_saldo_tot_gs,
           v_cod_moneda,
           v_cod_oficina;
      EXIT WHEN c_mov_historicos%NOTFOUND;

  --SI EL NRO DE CUENTA ES NULO LE ASIGNAMOS UNA CUENTA GENERICA DE ACUERDO A LA MONEDA
  IF v_nro_cuenta IS NULL THEN
    v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
  END IF;
  --

  -- OBTIENE EL TIPO DE CTA DE RESULTADO (VL=VALUACIONES).
  v_tip_cta := 'VL';
  --

  -- GUARDAMOS LOS MONTOS EN UN HISTORICO
  BEGIN
     -- Recuperamos el monto acumulado anterior de la cuenta
     BEGIN
        SELECT SUM(nvl(saldo_total,0)), SUM(nvl(saldo_tot_gs,0))
          INTO v_saldo_tot_acu, v_saldo_tot_gs_acu
          FROM cb_sal_inv_res_his h
         WHERE h.cod_rubro  = v_cod_rubro
           AND h.nro_cuenta = v_nro_cuenta
           AND h.periodo    = v_periodo;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           v_saldo_tot_acu    := 0;
           v_saldo_tot_gs_acu := 0;
     END;

     ---- VERIFICAMOS MONEDA Y GUARDAMOS MONTOS -----
     IF v_cod_moneda = v_cod_mon_local THEN
        -- Moneda local --
        v_mto_cotizacion      := 1;

        v_sal_mon_local       := v_saldo_tot_gs;                         -- saldo moneda local
        v_sal_mon_extranjera  := 0;                                      -- saldo moneda extranjera
        v_sal_mon_loc_actual  := (v_saldo_tot_gs_acu + v_saldo_tot_gs);  -- saldo acumulado actual local
        v_sal_mon_ext_actual  := 0;                                      -- saldo acumulado actual extranjero
     ELSE
        -- Moneda extranjera --
        v_mto_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);

        v_sal_mon_local        := v_saldo_tot_gs;                        -- saldo moneda local
        v_sal_mon_extranjera   := v_saldo_total;                         -- saldo moneda extranjera
        v_sal_mon_loc_actual   := (v_saldo_tot_gs_acu + v_saldo_tot_gs); -- saldo acumulado actual local
        v_sal_mon_ext_actual   := (v_saldo_tot_acu + v_saldo_total);     -- saldo acumulado actual extranjero
     END IF;
     -----------------------------------------------------------------------------

     -- Actualizamos la tabla detallada de Inventario de Resultados
     UPDATE cb_sal_inv_resultados_det
        SET sal_mon_extranjera          = sal_mon_extranjera + v_sal_mon_extranjera,
            sal_mon_local               = sal_mon_local + v_sal_mon_local,
            sal_acu_act_mon_extranjera  = sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
            sal_acu_act_mon_local       = sal_acu_act_mon_local + v_sal_mon_local
      WHERE fecha      = v_fec_actual
        AND cod_rubro  = v_cod_rubro
        AND nro_cuenta = v_nro_cuenta;

     IF SQL%NOTFOUND THEN
        -- Insertamos nuevos valores en el detalle
        INSERT INTO cb_sal_inv_resultados_det
                    (fecha, cod_rubro, nro_cuenta, val_cotizacion, sal_mon_extranjera, sal_mon_local,
                    sal_acu_act_mon_extranjera, sal_acu_act_mon_local)
             VALUES
                    (v_fec_actual, v_cod_rubro,v_nro_cuenta, v_mto_cotizacion, v_sal_mon_extranjera, v_sal_mon_local,
                     v_sal_mon_ext_actual, v_sal_mon_loc_actual);
     END IF;

     --Actualizamos la tabla historico
     UPDATE cb_sal_inv_res_his
        SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
            saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
      WHERE cod_rubro   = v_cod_rubro
        AND nro_cuenta  = v_nro_cuenta
        AND periodo     = v_periodo
        AND tipo        = v_tip_cta
        AND cod_oficina = v_cod_oficina;

     IF SQL%NOTFOUND THEN
        -- Insertamos nuevos valores en el historico
        INSERT INTO cb_sal_inv_res_his
                   (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
             VALUES
                   (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
     END IF;
  END;
  END LOOP;
  CLOSE c_mov_historicos;

  -- Cerramos el cursor si se encuentra abierto -------
 IF c_mov_inventario%ISOPEN THEN
    CLOSE c_mov_inventario;
  END IF;

  ------------------------- LEER MOVIMIENTOS ------------------------------
  -- Se ejecuta la lectura en bloque: open, fetch bulk, close. Simple y eficiente.
  OPEN c_mov_inventario(v_fec_actual);
  FETCH c_mov_inventario BULK COLLECT INTO l_movimientos;
  CLOSE c_mov_inventario;

  -- 4. Se procesa la colección que ya está en memoria.
  FOR i IN 1 .. l_movimientos.COUNT LOOP

    -- Se asignan los valores constantes para cada iteración.
    v_tip_saldo := 'K';
    v_tip_interes := 'X';
    v_tip_operacion := 'X';
    
    -- La lógica de negocio se mantiene, pero usando los datos de la colección.
    BEGIN
      SELECT nro_referencia, ROWID
        INTO v_nro_referencia, v_rowid
        FROM cb_sal_inventarios
       WHERE cod_modulo       = l_movimientos(i).cod_modulo
         AND cod_modalidad    = l_movimientos(i).cod_modalidad
         AND cod_oficina      = l_movimientos(i).cod_oficina
         AND cod_moneda       = l_movimientos(i).cod_moneda
         AND cod_sec_contable = l_movimientos(i).cod_sec_contable
         AND residente        = l_movimientos(i).residente
         AND cod_tip_deudor   = l_movimientos(i).tip_deudor
         AND tip_saldo        = v_tip_saldo
         AND cod_plazo        = l_movimientos(i).cod_plazo
         AND tip_interes      = v_tip_interes
         AND tip_operacion    = v_tip_operacion
         AND cod_rubro        = l_movimientos(i).cod_rubro;

      -- Si el registro existe, se actualiza.
      IF v_nro_referencia IS NOT NULL THEN
        UPDATE cb_sal_inventarios
           SET sal_total = NVL(sal_total, 0) + NVL(l_movimientos(i).saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND ROWID          = v_rowid;

        -- Se actualiza (o inserta) el detalle.
        UPDATE cb_sal_inventarios_det
           SET sal_anterior = NVL(sal_actual, 0),
               sal_actual   = NVL(sal_actual, 0) + NVL(l_movimientos(i).saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta     = l_movimientos(i).nro_cuenta;

        IF SQL%NOTFOUND THEN
          INSERT INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
          VALUES
            (v_nro_referencia, l_movimientos(i).nro_cuenta, NVL(l_movimientos(i).saldo_acumulado, 0), 0);
        END IF;
      END IF;
    EXCEPTION
      -- Si no existe, se inserta.
      WHEN NO_DATA_FOUND THEN
        SELECT s_nro_referencia.NEXTVAL INTO v_nro_referencia FROM dual;

        INSERT INTO cb_sal_inventarios
          (cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_sec_contable, residente, tip_interes,
           tip_operacion, cod_tip_deudor, tip_saldo, cod_plazo, sal_total, cod_rubro, nro_referencia)
        VALUES
          (l_movimientos(i).cod_modulo, l_movimientos(i).cod_modalidad, l_movimientos(i).cod_oficina, l_movimientos(i).cod_moneda, l_movimientos(i).cod_sec_contable, l_movimientos(i).residente,
           v_tip_interes, v_tip_operacion, l_movimientos(i).tip_deudor, v_tip_saldo, l_movimientos(i).cod_plazo, NVL(l_movimientos(i).saldo_acumulado, 0),
           l_movimientos(i).cod_rubro, v_nro_referencia);

        INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
        VALUES
          (v_nro_referencia, l_movimientos(i).nro_cuenta, NVL(l_movimientos(i).saldo_acumulado, 0), 0);
    END;
  END LOOP;


  EXCEPTION
    WHEN OTHERS THEN
         ROLLBACK;
         raise_application_error(-20000, 'ERROR PR_ACU_VALUACIONES: ' || SQLERRM);
  END PR_ACU_VALUACIONES;
  -----------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------
-- Otros Ingresos (OI)
PROCEDURE PR_ACU_OTR_INGRESOS IS
    -- Variables.
    v_fec_actual                 ge_calendarios.fec_actual%TYPE;
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_modulo                 cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad              cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina                cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable           cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor             cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente                  cb_sal_inventarios.residente%TYPE;
    v_situacion                  cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo                  cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion              cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes                cb_sal_inventarios.tip_interes%TYPE;
    v_nro_referencia             cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado            cb_sal_inventarios.sal_total%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_periodo                    cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo                  VARCHAR2(01);
    v_cod_rubro                  VARCHAR2(15);
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    v_cod_mon_local              ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;

    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
       SELECT REPLACE(d.cod_rubro,' ','') cod_rubro,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END) NRO_CUENTA,
              to_char(m.fecha,'YYYY') periodo,
              SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                      end) MONTO,
               SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                   else
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                   end) MTO_EQU_LOCAL,
              cb.COD_MONEDA,
              m.cod_oficina
         FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th, cb_rubros cb
        WHERE d.fecha                 = v_fec_actual
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'OTROS_INGRESOS')
          AND d.fecha                 = m.fecha
          AND d.ref_movimiento        = m.nro_documento4
          AND m.cod_modulo            = th.cod_modulo(+)
          AND m.cod_modalidad         = th.cod_modalidad(+)
          AND m.cod_transaccion       = th.cod_transaccion(+)
          AND d.cod_rubro             = cb.cod_rubro
     GROUP BY d.cod_rubro, m.fecha, m.hora, m.cod_usuario,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END),
              to_char(m.fecha,'YYYY'),
              cb.cod_moneda, m.cod_oficina;

  --
  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  CURSOR c_mov_inventario(p_fecha DATE) IS
      SELECT c.cod_modulo,
             c.cod_modalidad,
             NVL(h.cod_oficina,c.cod_oficina),
             cl.cod_sec_contable,
             cl.cod_tip_deudor,
             cl.residente,
             c.cod_moneda,
             to_char(1) cod_plazo,
             h.saldo_tot_gs,
             h.cod_rubro,
             h.nro_cuenta
        FROM cb_sal_inv_res_his h, ge_cuentas c, ge_cta_clientes cc, ge_clientes cl
       WHERE h.periodo      = to_char(p_fecha,'YYYY')
         AND h.tipo         = 'OI'  -- Otros Ingresos
         AND h.nro_cuenta   = c.nro_cuenta
         AND c.nro_cuenta   = cc.nro_cuenta
         AND cc.relacion    = 'P'
         AND cc.cod_persona = cl.cod_persona;

BEGIN

    -- Obtengo la fecha calendario.
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN c_mov_historicos (v_fec_actual);
    LOOP
      FETCH c_mov_historicos
       INTO v_cod_rubro,
            v_nro_cuenta,
            v_periodo,
            v_saldo_total,
            v_saldo_tot_gs,
            v_cod_moneda,
            v_cod_oficina;
    EXIT WHEN c_mov_historicos%NOTFOUND;

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (OI=OTROS INGRESOS)---
    v_tip_cta := 'OI';
    --
    IF v_nro_cuenta IS NULL THEN
    v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
    END IF;

    BEGIN
      BEGIN
         --Obtiene los montos acumuldos anteriores
         SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
           INTO v_mto_ori_ant,v_mto_loc_ant
           FROM cb_sal_inv_res_his i
          WHERE i.nro_cuenta  = v_nro_cuenta
            AND i.cod_rubro    = v_cod_rubro
            AND i.periodo     = to_char(v_fec_actual,'YYYY') ;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_loc_ant:=0;
            v_mto_ori_ant:=0;
      END;
      IF v_cod_moneda = v_cod_mon_local THEN
      v_cotizacion                      := 1;
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := 0;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera    := 0;
      ELSE
       v_cotizacion                     := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := v_saldo_total;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_saldo_total,0);
      END IF;
      -- Si existe el registro actualizar.
      UPDATE cb_sal_inv_resultados_det d
         SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
             d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
             d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
             d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND fecha=v_fec_actual;

      -- Se inserta en la tabla de detalle diario.
      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inv_resultados_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
         VALUES
            (v_fec_actual,v_cod_rubro,v_nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
      END IF;

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
      UPDATE cb_sal_inv_res_his
         SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
             saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND periodo     = v_periodo
         AND tipo         = v_tip_cta
         AND cod_oficina = v_cod_oficina;

      IF SQL%NOTFOUND THEN
         -- Insertamos nuevos valores
         INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
              VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
      END IF;
    END;
    END LOOP;
    CLOSE c_mov_historicos;

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_inventario%ISOPEN THEN
      CLOSE c_mov_inventario;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN c_mov_inventario (v_fec_actual);
    LOOP
      FETCH c_mov_inventario
        INTO v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             v_cod_sec_contable,
             v_cod_tip_deudor,
             v_residente,
             v_cod_moneda,
             v_cod_plazo,
             v_saldo_acumulado,
             v_cod_rubro,
             v_nro_cuenta;
    EXIT WHEN c_mov_inventario%NOTFOUND;

    -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
    v_tip_saldo := 'K';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
    v_tip_interes := 'X';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
    v_tip_operacion := 'X';
    --------------------------------------------------------------

    -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
    BEGIN
      SELECT nro_referencia
        INTO v_nro_referencia
        FROM cb_sal_inventarios
       WHERE cod_modulo       = v_cod_modulo
         AND cod_modalidad    = v_cod_modalidad
         AND cod_oficina      = v_cod_oficina
         AND cod_sec_contable = v_cod_sec_contable
         AND cod_tip_deudor   = v_cod_tip_deudor
         AND residente        = v_residente
         AND cod_moneda       = v_cod_moneda
         AND situacion        = v_situacion
         AND tip_saldo        = v_tip_saldo
         AND cod_plazo        = v_cod_plazo
         AND tip_operacion    = v_tip_operacion
         AND tip_interes      = v_tip_interes
         AND cod_rubro        = v_cod_rubro;

      IF v_nro_referencia IS NOT NULL THEN
        UPDATE cb_sal_inventarios
           SET sal_total = nvl(sal_total, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia;

        --------------Genero detalle----------------
        UPDATE cb_sal_inventarios_det
           SET sal_anterior = nvl(sal_actual, 0),
               sal_actual   = nvl(sal_actual, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta     = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0), 0);
        END IF;
      END IF;
    EXCEPTION
    WHEN no_data_found THEN
       ------------------------------
       -- INSERTA MONTO DEVENGADO --
       ------------------------------
       SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

      INSERT INTO cb_sal_inventarios
          (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
           residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
           tip_interes, sal_total, cod_rubro, nro_referencia)
       VALUES
          (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
           v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
           v_cod_plazo, v_tip_operacion, v_tip_interes, nvl(v_saldo_acumulado,0), v_cod_rubro,
           v_nro_referencia);

       INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
       VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado,0), 0);
    END;
    END LOOP;
    CLOSE c_mov_inventario;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_OTR_INGRESOS: ' || SQLERRM);
  END PR_ACU_OTR_INGRESOS;
-----------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------
-- Gastos (GA)
PROCEDURE PR_ACU_GASTOS IS
    -- Variables.
    v_fec_actual                 ge_calendarios.fec_actual%TYPE;
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_modulo                 cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad              cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina                cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable           cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor             cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente                  cb_sal_inventarios.residente%TYPE;
    v_situacion                  cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo                  cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion              cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes                cb_sal_inventarios.tip_interes%TYPE;
    v_nro_referencia             cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado            cb_sal_inventarios.sal_total%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_periodo                    cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo                  VARCHAR2(01);
    v_cod_rubro                  VARCHAR2(15);
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    v_cod_mon_local              ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;

    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
       SELECT REPLACE(d.cod_rubro,' ','') cod_rubro,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END) NRO_CUENTA,
              to_char(m.fecha,'YYYY') periodo,
              SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                      end) MONTO,
               SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                   else
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                   end) MTO_EQU_LOCAL,
              cb.COD_MONEDA,
              m.cod_oficina
         FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th, cb_rubros cb
        WHERE d.fecha                 = v_fec_actual
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'GASTOS')
          AND d.fecha                 = m.fecha
          AND d.ref_movimiento        = m.nro_documento4
          AND m.cod_modulo            = th.cod_modulo(+)
          AND m.cod_modalidad         = th.cod_modalidad(+)
          AND m.cod_transaccion       = th.cod_transaccion(+)
          AND d.cod_rubro             = cb.cod_rubro
     GROUP BY d.cod_rubro, m.fecha, m.hora, m.cod_usuario,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END),
              to_char(m.fecha,'YYYY'), cb.cod_moneda, m.cod_oficina;

  --
  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  CURSOR c_mov_inventario(p_fecha DATE) IS
    SELECT c.cod_modulo,
             c.cod_modalidad,
             NVL(h.cod_oficina,c.cod_oficina),
             cl.cod_sec_contable,
             cl.cod_tip_deudor,
             cl.residente,
             c.cod_moneda,
             to_char(1) cod_plazo,
             h.saldo_tot_gs,
             h.cod_rubro,
             h.nro_cuenta
        FROM cb_sal_inv_res_his h, ge_cuentas c, ge_cta_clientes cc, ge_clientes cl
       WHERE h.periodo      = to_char(p_fecha,'YYYY')
         AND h.tipo         = 'GA'  -- Gastos
         AND h.nro_cuenta   = c.nro_cuenta
         AND c.nro_cuenta   = cc.nro_cuenta
         AND cc.relacion    = 'P'
         AND cc.cod_persona = cl.cod_persona;

BEGIN

    -- Obtengo la fecha calendario.
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN c_mov_historicos (v_fec_actual);
    LOOP
      FETCH c_mov_historicos
       INTO v_cod_rubro,
            v_nro_cuenta,
            v_periodo,
            v_saldo_total,
            v_saldo_tot_gs,
            v_cod_moneda,
            v_cod_oficina;
    EXIT WHEN c_mov_historicos%NOTFOUND;

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (GA=GASTOS)---
    v_tip_cta := 'GA';
    --
    IF v_nro_cuenta IS NULL THEN
    v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
    END IF;

    BEGIN
      BEGIN
         --Obtiene los montos acumuldos anteriores
         SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
           INTO v_mto_ori_ant,v_mto_loc_ant
           FROM cb_sal_inv_res_his i
          WHERE i.nro_cuenta  = v_nro_cuenta
            AND i.cod_rubro    = v_cod_rubro
            AND i.periodo     = to_char(v_fec_actual,'YYYY') ;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_loc_ant:=0;
            v_mto_ori_ant:=0;
      END;
      IF v_cod_moneda = v_cod_mon_local THEN
         v_cotizacion                      := 1;
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := 0;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera    := 0;
      ELSE
       v_cotizacion                     := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := v_saldo_total;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_saldo_total,0);
      END IF;
      -- Si existe el registro actualizar.
      UPDATE cb_sal_inv_resultados_det d
         SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
             d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
             d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
             d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND fecha=v_fec_actual;

      -- Se inserta en la tabla de detalle diario.
      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inv_resultados_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
         VALUES
            (v_fec_actual,v_cod_rubro,v_nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
      END IF;

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
      UPDATE cb_sal_inv_res_his
         SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
             saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND periodo     = v_periodo
         AND tipo         = v_tip_cta
         AND cod_oficina = v_cod_oficina;

      IF SQL%NOTFOUND THEN
         -- Insertamos nuevos valores
         INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
              VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
      END IF;
    END;
    END LOOP;
    CLOSE c_mov_historicos;

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_inventario%ISOPEN THEN
      CLOSE c_mov_inventario;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN c_mov_inventario (v_fec_actual);
    LOOP
      FETCH c_mov_inventario
        INTO v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             v_cod_sec_contable,
             v_cod_tip_deudor,
             v_residente,
             v_cod_moneda,
             v_cod_plazo,
             v_saldo_acumulado,
             v_cod_rubro,
             v_nro_cuenta;
    EXIT WHEN c_mov_inventario%NOTFOUND;

    -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
    v_tip_saldo := 'K';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
    v_tip_interes := 'X';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
    v_tip_operacion := 'X';
    --------------------------------------------------------------

    -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
    BEGIN
      SELECT nro_referencia
        INTO v_nro_referencia
        FROM cb_sal_inventarios
       WHERE cod_modulo       = v_cod_modulo
         AND cod_modalidad    = v_cod_modalidad
         AND cod_oficina      = v_cod_oficina
         AND cod_sec_contable = v_cod_sec_contable
         AND cod_tip_deudor   = v_cod_tip_deudor
         AND residente        = v_residente
         AND cod_moneda       = v_cod_moneda
         AND situacion        = v_situacion
         AND tip_saldo        = v_tip_saldo
         AND cod_plazo        = v_cod_plazo
         AND tip_operacion    = v_tip_operacion
         AND tip_interes      = v_tip_interes
         AND cod_rubro        = v_cod_rubro;

      IF v_nro_referencia IS NOT NULL THEN
        UPDATE cb_sal_inventarios
           SET sal_total = nvl(sal_total, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia;

        --------------Genero detalle----------------
        UPDATE cb_sal_inventarios_det
           SET sal_anterior = nvl(sal_actual, 0),
               sal_actual   = nvl(sal_actual, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta     = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0), 0);
        END IF;
      END IF;
    EXCEPTION
    WHEN no_data_found THEN
       ------------------------------
       -- INSERTA MONTO DEVENGADO --
       ------------------------------
       SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

      INSERT INTO cb_sal_inventarios
          (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
           residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
           tip_interes, sal_total, cod_rubro, nro_referencia)
       VALUES
          (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
           v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
           v_cod_plazo, v_tip_operacion, v_tip_interes, nvl(v_saldo_acumulado,0), v_cod_rubro,
           v_nro_referencia);

       INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
       VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado,0), 0);
    END;
    END LOOP;
    CLOSE c_mov_inventario;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_GASTOS: ' || SQLERRM);
  END PR_ACU_GASTOS;
-----------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------
-- Otros Egresos (OE)
PROCEDURE PR_ACU_OTR_EGRESOS IS
    -- Variables.
    v_fec_actual                 ge_calendarios.fec_actual%TYPE;
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_modulo                 cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad              cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina                cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable           cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor             cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente                  cb_sal_inventarios.residente%TYPE;
    v_situacion                  cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo                  cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion              cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes                cb_sal_inventarios.tip_interes%TYPE;
    v_nro_referencia             cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado            cb_sal_inventarios.sal_total%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_periodo                    cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo                  VARCHAR2(01);
    v_cod_rubro                  VARCHAR2(15);
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    v_cod_mon_local              ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_fec_periodo                varchar2(4);
    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
       SELECT REPLACE(d.cod_rubro,' ','') cod_rubro,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END) NRO_CUENTA,
              to_char(m.fecha,'YYYY') periodo,
              SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                      end) MONTO,
               SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                   else
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                   end) MTO_EQU_LOCAL,
              cb.COD_MONEDA,
              m.cod_oficina
         FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th, cb_rubros cb
        WHERE d.fecha                 = v_fec_actual
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'OTROS_EGRESOS')
          AND d.fecha                 = m.fecha
          AND d.ref_movimiento        = m.nro_documento4
          AND m.cod_tra_padre         = th.cod_transaccion
          AND m.cod_mod_padre         = th.cod_modulo
          AND m.cod_mad_padre         = th.cod_modalidad
          AND m.cod_modulo            = th.cod_modulo(+)
          AND m.cod_modalidad         = th.cod_modalidad(+)
          AND m.cod_transaccion       = th.cod_transaccion(+)
          AND d.cod_rubro             = cb.cod_rubro
          AND length(nvl(m.hora,0))   >=0 
          AND length(d.nro_asiento)   >=0
     GROUP BY d.cod_rubro, m.fecha, m.hora, m.cod_usuario,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END),
              to_char(m.fecha,'YYYY'), cb.cod_moneda, m.cod_oficina;

      TYPE cursor1_type IS TABLE OF c_mov_historicos%ROWTYPE;
      reg cursor1_type;

    PROCEDURE LP_DISABLE_PARALLEL_DML
      IS
        PRAGMA AUTONOMOUS_TRANSACTION;
      BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';
        COMMIT; -- Esto solo confirma la transacción del ALTER SESSION, no la del procedimiento principal.
      EXCEPTION
        WHEN OTHERS THEN
          -- ORA-12841: puede ocurrir si la sesión ya está en modo serial. Lo ignoramos de forma segura.
          IF SQLCODE = -12841 THEN
            NULL; 
          ELSE
            RAISE;
          END IF;
      END LP_DISABLE_PARALLEL_DML;

BEGIN

    -- Obtengo la fecha calendario.
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------

    OPEN c_mov_historicos(v_fec_actual);
    LOOP
         FETCH c_mov_historicos BULK COLLECT
            INTO reg ;
    FOR i IN 1 .. reg.count LOOP

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (OE=OTROS EGRESOS)---
    v_tip_cta := 'OE';
    --
    IF reg(i).nro_cuenta IS NULL THEN
    reg(i).nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,reg(i).cod_moneda,reg(i).cod_oficina), '9999999999');
    END IF;

    BEGIN
      BEGIN
         --Obtiene los montos acumuldos anteriores
         SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
           INTO v_mto_ori_ant,v_mto_loc_ant
           FROM cb_sal_inv_res_his i
          WHERE i.nro_cuenta  =  reg(i).nro_cuenta
            AND i.cod_rubro    = reg(i).cod_rubro
            AND i.periodo     = to_char(v_fec_actual,'YYYY') ;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_loc_ant:=0;
            v_mto_ori_ant:=0;
      END;
      IF reg(i).cod_moneda = v_cod_mon_local THEN
      v_cotizacion                      := 1;
         v_sal_mon_local                := reg(i).mto_equ_local;
         v_sal_mon_extranjera            := 0;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(reg(i).mto_equ_local,0);
         v_sal_acu_act_mon_extranjera    := 0;
      ELSE
       v_cotizacion                     := pag_gen.fu_obt_cotizacion(reg(i).cod_moneda, v_fec_actual);
         v_sal_mon_local                := reg(i).mto_equ_local;
         v_sal_mon_extranjera           := reg(i).monto;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(reg(i).mto_equ_local,0);
         v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(reg(i).monto,0);
      END IF;
      -- Si existe el registro actualizar.
      UPDATE cb_sal_inv_resultados_det d
         SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
             d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
             d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
             d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
       WHERE cod_rubro   = reg(i).cod_rubro
         AND nro_cuenta  = reg(i).nro_cuenta
         AND fecha       = v_fec_actual;

      -- Se inserta en la tabla de detalle diario.
      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inv_resultados_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
         VALUES
            (v_fec_actual,reg(i).cod_rubro,reg(i).nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
      END IF;

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
      UPDATE cb_sal_inv_res_his
         SET saldo_total  = nvl(saldo_total,0) + nvl(reg(i).monto,0),
             saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(reg(i).mto_equ_local,0)
       WHERE cod_rubro    = reg(i).cod_rubro
         AND nro_cuenta   = reg(i).nro_cuenta
         AND periodo      = reg(i).periodo
         AND tipo         = v_tip_cta
         AND cod_oficina  = reg(i).cod_oficina;

      IF SQL%NOTFOUND THEN
         -- Insertamos nuevos valores
         INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
              VALUES
            (reg(i).cod_rubro,reg(i).nro_cuenta, reg(i).periodo, v_tip_cta, nvl(reg(i).monto,0), nvl(reg(i).mto_equ_local,0), reg(i).cod_oficina);
      END IF;
    END;
    END LOOP;
    EXIT WHEN c_mov_historicos%NOTFOUND;
    END LOOP;
    CLOSE c_mov_historicos;
    
    -- Variables que se usarán como constantes en el MERGE
    v_tip_interes   := 'X';
    v_tip_operacion := 'X';
    v_tip_saldo     := 'K';
    v_fec_periodo   := to_char(v_fec_actual, 'YYYY');
    -- Llama al procedimiento auxiliar para asegurar una ejecución en serie
    -- Aseguramos la ejecución en serie para evitar errores de paralelismo
    LP_DISABLE_PARALLEL_DML;
    
    -----------------------------------------------------------------------------------
    --Cargar los datos de origen en la tabla de movimientos
    -----------------------------------------------------------------------------------    
    DELETE FROM cb_sal_movimientos;
    
    INSERT INTO cb_sal_movimientos (
        cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor, residente, 
        cod_moneda, situacion, cod_plazo, sal_total, cod_rubro, nro_cuenta)
    SELECT 
        c.cod_modulo,
        c.cod_modalidad,
        NVL(h.cod_oficina, c.cod_oficina) AS cod_oficina,
        cl.cod_sec_contable,
        cl.cod_tip_deudor,
        cl.residente,
        c.cod_moneda,
        NULL AS situacion,
        '1' AS cod_plazo,
        h.saldo_tot_gs,
        h.cod_rubro,
        h.nro_cuenta
    FROM cb_sal_inv_res_his h
    JOIN ge_cuentas c         ON h.nro_cuenta = c.nro_cuenta
    JOIN ge_cta_clientes cc   ON c.nro_cuenta = cc.nro_cuenta
    JOIN ge_clientes cl       ON cc.cod_persona = cl.cod_persona
    WHERE h.periodo = v_fec_periodo
      AND h.tipo = 'OE'
      AND SUBSTR(h.cod_rubro, 1, 1) IN ('6', '7')
      AND SUBSTR(h.cod_rubro, 6, 3) IN (SELECT b.val_minimo FROM ba_cod_referencias b WHERE b.dominio = 'OTROS_EGRESOS')
      AND cc.relacion = 'P';
    -----------------------------------------------------------------------------------
    --MERGE a la tabla principal (cb_sal_inventarios)
    -----------------------------------------------------------------------------------
    MERGE INTO cb_sal_inventarios inv
    USING (
        SELECT cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor, residente,
               cod_moneda, situacion, cod_plazo, cod_rubro,
               SUM(sal_total) AS sal_total
        FROM cb_sal_movimientos
        GROUP BY
            cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor, residente,
            cod_moneda, situacion, cod_plazo, cod_rubro) src
    ON (    inv.situacion IS NULL 
        AND DECODE(inv.cod_modulo,       src.cod_modulo,       1, 0) = 1 
        AND DECODE(inv.cod_modalidad,    src.cod_modalidad,    1, 0) = 1 
        AND DECODE(inv.cod_oficina,      src.cod_oficina,      1, 0) = 1 
        AND DECODE(inv.cod_sec_contable, src.cod_sec_contable, 1, 0) = 1 
        AND DECODE(inv.cod_tip_deudor,   src.cod_tip_deudor,   1, 0) = 1 
        AND DECODE(inv.residente,        src.residente,        1, 0) = 1 
        AND DECODE(inv.cod_moneda,       src.cod_moneda,       1, 0) = 1 
        AND DECODE(inv.tip_saldo,        v_tip_saldo,          1, 0) = 1 
        AND DECODE(inv.cod_plazo,        src.cod_plazo,        1, 0) = 1 
        AND DECODE(inv.tip_operacion,    v_tip_operacion,      1, 0) = 1 
        AND DECODE(inv.tip_interes,      v_tip_interes,        1, 0) = 1 
        AND DECODE(inv.cod_rubro,        src.cod_rubro,        1, 0) = 1)
    WHEN MATCHED THEN
        UPDATE SET inv.sal_total = NVL(inv.sal_total, 0) + NVL(src.sal_total, 0)
    WHEN NOT MATCHED THEN
        INSERT (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor, residente, cod_moneda,
                situacion, tip_saldo, cod_plazo, tip_operacion, tip_interes, sal_total, cod_rubro, nro_referencia)
        VALUES (src.cod_modulo, src.cod_modalidad, src.cod_oficina, src.cod_sec_contable, src.cod_tip_deudor, src.residente, src.cod_moneda,
                src.situacion, v_tip_saldo, src.cod_plazo, v_tip_operacion, v_tip_interes, NVL(src.sal_total, 0), -- Se usan las variables
                src.cod_rubro, s_nro_referencia.nextval);
    -----------------------------------------------------------------------------------
    --MERGE a la tabla de detalle (cb_sal_inventarios_det)
    -----------------------------------------------------------------------------------
    MERGE INTO cb_sal_inventarios_det det
    USING (
        WITH
        grouped_source AS (
            SELECT
                nro_cuenta, cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor, residente,
                cod_moneda, situacion, cod_plazo, cod_rubro,
                SUM(sal_total) AS sal_total
            FROM cb_sal_movimientos
            GROUP BY
                nro_cuenta, cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor, residente,
                cod_moneda, situacion, cod_plazo, cod_rubro
        )
        SELECT
            inv.nro_referencia,
            gs.nro_cuenta,
            gs.sal_total
        FROM grouped_source gs
        JOIN cb_sal_inventarios inv 
        ON (inv.situacion IS NULL 
            AND DECODE(inv.cod_modulo,       gs.cod_modulo,       1, 0) = 1 
            AND DECODE(inv.cod_modalidad,    gs.cod_modalidad,    1, 0) = 1 
            AND DECODE(inv.cod_oficina,      gs.cod_oficina,      1, 0) = 1 
            AND DECODE(inv.cod_sec_contable, gs.cod_sec_contable, 1, 0) = 1 
            AND DECODE(inv.cod_tip_deudor,   gs.cod_tip_deudor,   1, 0) = 1 
            AND DECODE(inv.residente,        gs.residente,        1, 0) = 1 
            AND DECODE(inv.cod_moneda,       gs.cod_moneda,       1, 0) = 1 
            AND DECODE(inv.tip_saldo,        v_tip_saldo,         1, 0) = 1 
            AND DECODE(inv.cod_plazo,        gs.cod_plazo,        1, 0) = 1 
            AND DECODE(inv.tip_operacion,    v_tip_operacion,     1, 0) = 1 
            AND DECODE(inv.tip_interes,      v_tip_interes,       1, 0) = 1 
            AND DECODE(inv.cod_rubro,        gs.cod_rubro,        1, 0) = 1)
    ) new_data
    ON (det.nro_referencia = new_data.nro_referencia 
    AND det.nro_cuenta = new_data.nro_cuenta)
    WHEN MATCHED THEN
        UPDATE SET
            det.sal_anterior = NVL(det.sal_actual, 0),
            det.sal_actual   = NVL(det.sal_actual, 0) + NVL(new_data.sal_total, 0)
    WHEN NOT MATCHED THEN
        INSERT (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
        VALUES (new_data.nro_referencia, new_data.nro_cuenta, NVL(new_data.sal_total, 0), 0);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_OTR_EGRESOS: ' || SQLERRM);
  END PR_ACU_OTR_EGRESOS;
-----------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------
-- Impuestos (IM)
PROCEDURE PR_ACU_IMPUESTOS IS
    -- Variables.
    v_fec_actual                 ge_calendarios.fec_actual%TYPE;
    v_cod_moneda                 ba_monedas.cod_moneda%TYPE;
    v_cod_modulo                 cb_sal_inventarios.cod_modulo%TYPE;
    v_cod_modalidad              cb_sal_inventarios.cod_modalidad%TYPE;
    v_cod_oficina                cb_sal_inventarios.cod_oficina%TYPE;
    v_cod_sec_contable           cb_sal_inventarios.cod_sec_contable%TYPE;
    v_cod_tip_deudor             cb_sal_inventarios.cod_tip_deudor%TYPE;
    v_residente                  cb_sal_inventarios.residente%TYPE;
    v_situacion                  cb_sal_inventarios.situacion%TYPE;
    v_cod_plazo                  cb_sal_inventarios.cod_plazo%TYPE;
    v_tip_operacion              cb_sal_inventarios.tip_operacion%TYPE;
    v_tip_interes                cb_sal_inventarios.tip_interes%TYPE;
    v_nro_referencia             cb_sal_inventarios.nro_referencia%TYPE;
    v_saldo_total                cb_sal_inventarios.sal_total%TYPE;
    v_saldo_tot_gs               cb_sal_inv_res_his.saldo_tot_gs%TYPE;
    v_saldo_acumulado            cb_sal_inventarios.sal_total%TYPE;
    v_nro_cuenta                 pr_devengados.nro_cuenta%TYPE;
    v_periodo                    cb_sal_inv_res_his.periodo%TYPE;
    v_tip_cta                    cb_sal_inv_res_his.tipo%TYPE;
    v_cotizacion                 ge_cotizaciones.val_conversion%TYPE;
    v_tip_saldo                  VARCHAR2(01);
    v_cod_rubro                  VARCHAR2(15);
    v_mto_ori_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_mto_loc_ant                cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_local      cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_acu_act_mon_extranjera cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_local              cb_sal_inv_res_his.saldo_total%TYPE;
    v_sal_mon_extranjera         cb_sal_inv_res_his.saldo_total%TYPE;
    v_cod_mon_local              ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;

    -- Cursores.
    CURSOR c_mov_historicos(p_fecha DATE) IS
       SELECT REPLACE(d.cod_rubro,' ','') cod_rubro,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END) NRO_CUENTA,
              to_char(m.fecha,'YYYY') periodo,
              SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0)) * -1
                      else
                         decode(m.cod_moneda,v_cod_mon_local,0,NVL(m.monto,0))
                      end) MONTO,
               SUM(case
                      when SUBSTR(d.cod_rubro,1,1) IN ('6','7') and d.tip_movimiento = 'D' then
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0)) * -1
                   else
                         decode(m.cod_moneda,v_cod_mon_local,NVL(m.monto,0),NVL(m.mto_equ_local,0))
                   end) MTO_EQU_LOCAL,
              cb.COD_MONEDA,
              m.cod_oficina
         FROM ge_movimientos m, cb_asi_automaticos_det d, ge_transacciones th, cb_rubros cb
        WHERE d.fecha                 = v_fec_actual
          AND SUBSTR(d.cod_rubro,1,1) IN ('6','7')
          AND SUBSTR(d.cod_rubro,6,3) IN (select b.val_minimo from ba_cod_referencias b where b.dominio = 'IMPUESTOS')
          AND d.fecha                 = m.fecha
          AND d.ref_movimiento        = m.nro_documento4
          AND m.cod_modulo            = th.cod_modulo(+)
          AND m.cod_modalidad         = th.cod_modalidad(+)
          AND m.cod_transaccion       = th.cod_transaccion(+)
          AND d.cod_rubro             = cb.cod_rubro
     GROUP BY d.cod_rubro, m.fecha, m.hora, m.cod_usuario,
              (CASE WHEN FUP_EXI_GRU_TRANSAC(800,m.cod_transaccion,m.cod_modulo, m.cod_modalidad) = 'S' THEN
                  NVL(m.referencia,m.nro_cuenta)
                ELSE
                  m.nro_cuenta
                END),
              to_char(m.fecha,'YYYY'), cb.cod_moneda, m.cod_oficina;

  --
  -- Requerimiento: CNFDEEVO-29.
  -- Fecha: 03/03/2016.
  CURSOR c_mov_inventario(p_fecha DATE) IS
    SELECT c.cod_modulo,
             c.cod_modalidad,
             NVL(h.cod_oficina,c.cod_oficina),
             cl.cod_sec_contable,
             cl.cod_tip_deudor,
             cl.residente,
             c.cod_moneda,
             to_char(1) cod_plazo,
             h.saldo_tot_gs,
             h.cod_rubro,
             h.nro_cuenta
        FROM cb_sal_inv_res_his h, ge_cuentas c, ge_cta_clientes cc, ge_clientes cl
       WHERE h.periodo      = to_char(p_fecha,'YYYY')
         AND h.tipo         = 'IM'  -- Impuestos
         AND h.nro_cuenta   = c.nro_cuenta
         AND c.nro_cuenta   = cc.nro_cuenta
         AND cc.relacion    = 'P'
         AND cc.cod_persona = cl.cod_persona;

BEGIN

    -- Obtengo la fecha calendario.
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_historicos%ISOPEN THEN
      CLOSE c_mov_historicos;
    END IF;
    ------------------------- LEER MOVIMIEN P/ HISTORICO ------------------------------
    OPEN c_mov_historicos (v_fec_actual);
    LOOP
      FETCH c_mov_historicos
       INTO v_cod_rubro,
            v_nro_cuenta,
            v_periodo,
            v_saldo_total,
            v_saldo_tot_gs,
            v_cod_moneda,
            v_cod_oficina;
    EXIT WHEN c_mov_historicos%NOTFOUND;

    -- OBTIENE EL TIPO DE CTA DE RESULTADO (IM=IMPUESTOS)---
    v_tip_cta := 'IM';
    --
    IF v_nro_cuenta IS NULL THEN
    v_nro_cuenta := NVL(fug_obt_pardinamico('INV_CTA_GENERICA',NULL,NULL,v_cod_moneda,v_cod_oficina), '9999999999');
    END IF;

    BEGIN
      BEGIN
         --Obtiene los montos acumuldos anteriores
         SELECT SUM(nvl(i.saldo_total,0)), SUM(nvl(i.saldo_tot_gs,0))
           INTO v_mto_ori_ant,v_mto_loc_ant
           FROM cb_sal_inv_res_his i
          WHERE i.nro_cuenta  = v_nro_cuenta
            AND i.cod_rubro    = v_cod_rubro
            AND i.periodo     = to_char(v_fec_actual,'YYYY') ;
      EXCEPTION
         WHEN no_data_found THEN
            v_mto_loc_ant:=0;
            v_mto_ori_ant:=0;
      END;
      IF v_cod_moneda = v_cod_mon_local THEN
         v_cotizacion                      := 1;
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := 0;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera    := 0;
      ELSE
         v_cotizacion                     := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         v_sal_mon_local                := v_saldo_tot_gs;
         v_sal_mon_extranjera            := v_saldo_total;
         v_sal_acu_act_mon_local        := nvl(v_mto_loc_ant,0)+nvl(v_saldo_tot_gs,0);
         v_sal_acu_act_mon_extranjera   := nvl(v_mto_ori_ant,0) + nvl(v_saldo_total,0);
      END IF;
      -- Si existe el registro actualizar.
      UPDATE cb_sal_inv_resultados_det d
         SET d.sal_mon_extranjera         = d.sal_mon_extranjera + v_sal_mon_extranjera,
             d.sal_mon_local              = d.sal_mon_local + v_sal_mon_local,
             d.sal_acu_act_mon_extranjera = d.sal_acu_act_mon_extranjera + v_sal_mon_extranjera,
             d.sal_acu_act_mon_local      = d.sal_acu_act_mon_local + v_sal_mon_local
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND fecha=v_fec_actual;

      -- Se inserta en la tabla de detalle diario.
      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inv_resultados_det
            (fecha, cod_rubro,nro_cuenta, val_cotizacion,sal_mon_extranjera,sal_mon_local,
             sal_acu_act_mon_extranjera,sal_acu_act_mon_local)
         VALUES
            (v_fec_actual,v_cod_rubro,v_nro_cuenta,v_cotizacion,v_sal_mon_extranjera,v_sal_mon_local,
             v_sal_acu_act_mon_extranjera, v_sal_acu_act_mon_local);
      END IF;

      -- GUARDAMOS LOS MONTOS EN UN HISTORICO ACUMULADO
      UPDATE cb_sal_inv_res_his
         SET saldo_total  = nvl(saldo_total,0) + nvl(v_saldo_total,0),
             saldo_tot_gs = nvl(saldo_tot_gs,0) + nvl(v_saldo_tot_gs,0)
       WHERE cod_rubro   = v_cod_rubro
         AND nro_cuenta  = v_nro_cuenta
         AND periodo     = v_periodo
         AND tipo         = v_tip_cta
         AND cod_oficina = v_cod_oficina;

      IF SQL%NOTFOUND THEN
         -- Insertamos nuevos valores
         INSERT INTO cb_sal_inv_res_his
            (cod_rubro, nro_cuenta, periodo, tipo, saldo_total, saldo_tot_gs, cod_oficina)
              VALUES
            (v_cod_rubro,v_nro_cuenta, v_periodo, v_tip_cta, nvl(v_saldo_total,0), nvl(v_saldo_tot_gs,0), v_cod_oficina);
      END IF;
    END;
    END LOOP;
    CLOSE c_mov_historicos;

    -- Cerramos el cursor si se encuentra abierto -------
    IF c_mov_inventario%ISOPEN THEN
      CLOSE c_mov_inventario;
    END IF;
    ------------------------- LEER MOVIMIEN P/ INV DEVENGADOS ------------------------------
    OPEN c_mov_inventario (v_fec_actual);
    LOOP
      FETCH c_mov_inventario
        INTO v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             v_cod_sec_contable,
             v_cod_tip_deudor,
             v_residente,
             v_cod_moneda,
             v_cod_plazo,
             v_saldo_acumulado,
             v_cod_rubro,
             v_nro_cuenta;
    EXIT WHEN c_mov_inventario%NOTFOUND;

    -- OBTIENE EL TIPO DE SALDO (INVENTARIO CTA DE RESULTADO) ---
    v_tip_saldo := 'K';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
    v_tip_interes := 'X';
    --------------------------------------------------------------

    -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
    v_tip_operacion := 'X';
    --------------------------------------------------------------

    -- BUSCAMOS SI EXISTE EL REGISTRO Y ACTUALIZAMOS LOS SALDOS EN EL INVENTARIO
    BEGIN
      SELECT nro_referencia
        INTO v_nro_referencia
        FROM cb_sal_inventarios
       WHERE cod_modulo       = v_cod_modulo
         AND cod_modalidad    = v_cod_modalidad
         AND cod_oficina      = v_cod_oficina
         AND cod_sec_contable = v_cod_sec_contable
         AND cod_tip_deudor   = v_cod_tip_deudor
         AND residente        = v_residente
         AND cod_moneda       = v_cod_moneda
         AND situacion        = v_situacion
         AND tip_saldo        = v_tip_saldo
         AND cod_plazo        = v_cod_plazo
         AND tip_operacion    = v_tip_operacion
         AND tip_interes      = v_tip_interes
         AND cod_rubro        = v_cod_rubro;

      IF v_nro_referencia IS NOT NULL THEN
        UPDATE cb_sal_inventarios
           SET sal_total = nvl(sal_total, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia;

        --------------Genero detalle----------------
        UPDATE cb_sal_inventarios_det
           SET sal_anterior = nvl(sal_actual, 0),
               sal_actual   = nvl(sal_actual, 0) + nvl(v_saldo_acumulado, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta     = v_nro_cuenta;

        IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
         VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado, 0), 0);
        END IF;
      END IF;
    EXCEPTION
    WHEN no_data_found THEN
       ------------------------------
       -- INSERTA MONTO DEVENGADO --
       ------------------------------
       SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

      INSERT INTO cb_sal_inventarios
          (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
           residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
           tip_interes, sal_total, cod_rubro, nro_referencia)
       VALUES
          (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
           v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
           v_cod_plazo, v_tip_operacion, v_tip_interes, nvl(v_saldo_acumulado,0), v_cod_rubro,
           v_nro_referencia);

       INSERT INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
       VALUES
          (v_nro_referencia, v_nro_cuenta, nvl(v_saldo_acumulado,0), 0);
    END;
    END LOOP;
    CLOSE c_mov_inventario;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'ERROR PR_ACU_IMPUESTOS: ' || SQLERRM);
  END PR_ACU_IMPUESTOS;
-----------------------------------------------------------------------------------------------------------

  -- Requerimiento: CNFDEEVO-1.
  -- Fecha: 09/11/2015.
  -- Actualiza la Fecha de Cierre Contable - Fin de Año para la Generación del Inventario de DI y Trading.
  PROCEDURE PR_ACT_FEC_CIE_CONTABLE(v_fecha date) IS
  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  BEGIN
     prg_act_par_dinamico('CBN_FEC_ULT_DIA_CIE_ANUAL',null, null, null, null,to_char(NVL(v_fecha,v_fec_actual),'dd/mm/yyyy'));
  EXCEPTION
     WHEN OTHERS THEN
        NULL;
  END;




end PAB_RES ;
/

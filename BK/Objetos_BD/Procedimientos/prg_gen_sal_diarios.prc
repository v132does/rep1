CREATE OR REPLACE PROCEDURE IT.PRG_GEN_SAL_DIARIOS
 IS
/* Proceso a ejecutarse diariamente luego del cierre, utilizado para
generar la tabla de saldos diarios de las cuentas activas */
/* Procedimiento Modificado para optimizacion de tiempos AP 3006 by PS*/
v_fec_actual   DATE := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_fec_anterior date := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,1);
v_cod_mon_local varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
TYPE array_tabla_sal IS TABLE OF ge_sal_diarios%ROWTYPE INDEX BY BINARY_INTEGER;

--cursor ahorros vistas
CURSOR cu_cta_ahorros IS
   SELECT v_fec_actual,a.nro_cuenta,a.cod_moneda,a.est_batch,a.sal_tot_batch, a.sal_blo_batch,
          a.sal_ret_batch,sum(nvl(b.mto_dev_acumulado,0)) dev_acumulado,sum(NVL(b.mto_interes,0)) dev_dia,
          0 dev_no_cobrado,0 dev_suspenso,0 val_suspenso, 1 cat_riesgo,0 dias_atraso,0 sal_mon_local,null val_cotizacion,
          0 mto_linea
     FROM AH_DEVENGADOS b, AH_CTA_VISTAS a
    WHERE b.FECHA(+) = v_fec_actual
      AND a.NRO_CUENTA = b.NRO_CUENTA(+)
      AND (a.est_batch not in ('A','X','T','C') or (a.est_batch = 'C' and a.fec_cam_estado = v_fec_actual))
    GROUP BY a.COD_MONEDA, a.nro_cuenta, a.est_batch, a.sal_tot_batch, a.sal_blo_batch, a.sal_ret_batch;

--cursor ahorros certificados
CURSOR cu_cta_certificados IS
   SELECT v_fec_actual,a.nro_cuenta,a.cod_moneda,a.est_batch, a.sal_tot_batch,a.sal_blo_batch,
          a.sal_ret_batch,sum(nvl(b.mto_dev_acumulado,0)) dev_acumulado,sum(NVL(b.mto_interes,0)) dev_dia,
          0 dev_no_cobrado,0 dev_suspenso,0 val_suspenso,1 cat_riesgo,0 dias_atraso,0 sal_mon_local,null val_cotizacion,
          0 mto_linea
     FROM AH_DEVENGADOS b, ah_cta_certificados a
    WHERE b.FECHA(+) = v_fec_actual
      AND a.NRO_CUENTA = b.NRO_CUENTA(+)
      AND (a.est_batch not in ('A','X','T','C') or (a.est_batch = 'C' and a.fec_cam_estado = v_fec_actual))
    GROUP BY a.COD_MONEDA, a.nro_cuenta, a.est_batch, a.sal_tot_batch, a.sal_blo_batch, a.sal_ret_batch;

-- cursor cuentas corrientes
CURSOR cu_cta_corrientes IS
   SELECT v_fec_actual, b.nro_cuenta,b.cod_moneda,b.est_batch,b.sal_tot_batch,b.sal_blo_batch,
          b.sal_ret_batch,0 dev_acumulado,0 dev_dia,
          0 dev_no_cobrado,0 dev_suspenso, 0 val_suspenso,1 cat_riesgo, r.can_dias,0 sal_mon_local, null val_cotizacion,
          FUC_OBT_MTO_LIN_SOB(b.nro_cuenta) mto_linea
     FROM cc_cta_corrientes b, cc_sobregiros_res r
    WHERE (b.est_batch not in ('A','X','T','C')
        or (b.est_batch = 'C' and b.fec_cam_estado = v_fec_actual))
        AND b.nro_cuenta = r.nro_cuenta(+);
    
--cursor tarjetas
cursor c_tarjetas is
   SELECT v_fec_actual, t.nro_cuenta, t.cod_moneda, t.estado, 
          0 sal_tot_cap, 0 sal_blo_int, 0 sal_ret_ade, 0 dev_acumulado, 0 dev_dia, 0 dev_no_cobrado, 
          0 dev_suspenso, 0 val_suspenso,
          t.cat_automatica, t.dia_mora, 
          0 sal_mon_local, null val_cotizacion, 
          t.lin_credito mto_linea
     FROM ta_cta_tarjetas t
    WHERE t.estado <> 'C';

--cursor comex  -- ICL 2009/07/31
CURSOR cu_cta_comex is
   SELECT v_fec_actual,e.nro_cuenta, e.cod_moneda, e.est_batch,fux_obt_sal_mto_utilizado(e.nro_cuenta) sal_negociado,
          nvl(e.sal_batch,0) - fux_obt_sal_mto_utilizado(e.nro_cuenta) no_negociado, e.monto, 0 dev_acumulado, 0 dev_dia,
          0 dev_no_cobrado, 0 dev_suspenso,0 val_suspenso, 1 cat_riesgo, 0 dias_atraso,0 sal_mon_local, null val_cotizacion,
          0 mto_linea
     FROM cx_cta_exportaciones e
    WHERE e.est_batch not in ('C','R','G','P')
    UNION ALL
   SELECT v_fec_actual, i.nro_cuenta,i.cod_moneda,i.est_batch, fux_obt_sal_mto_utilizado(i.nro_cuenta),nvl(i.sal_batch,0) - fux_obt_sal_mto_utilizado(i.nro_cuenta),
          i.monto,0 dev_acumulado, 0 dev_dia,
          0 dev_no_cobrado, 0 dev_suspenso,0 val_suspenso, 1 cat_riesgo, 0 dias_atraso,0 sal_mon_local, null val_cotizacion,
          0 mto_linea
     FROM cx_cta_importaciones i
    WHERE i.est_batch not in ('C','R','G','P')
    UNION ALL
   SELECT v_fec_actual,f.nro_cuenta,f.cod_moneda, f.est_batch,f.monto,0,
          0 ,0 dev_acumulado ,0 dev_dia,
          0 dev_no_cobrado, 0 dev_suspenso,0 val_suspenso, 1 cat_riesgo, 0 dias_atraso,0 sal_mon_local, null val_cotizacion,
          0 mto_linea
     FROM cx_fianzas f
    WHERE f.est_batch not in ('C','R','G','P')
    UNION ALL
   SELECT v_fec_actual, c.nro_cuenta,c.cod_moneda,c.est_batch, c.saldo, 0, 
          0,0 dev_acumulado, 0 dev_dia, 
          0 dev_no_cobrado, 0 dev_suspenso,0 val_suspenso, 1 cat_riesgo, 0 dias_atraso,0 sal_mon_local, null val_cotizacion,
          0 mto_linea
     FROM cx_cta_cobranzas c
    WHERE c.est_batch not in ('C','R','G','P')
    ORDER BY 1;

-- cursor de Mesa de Dinero, agregado por Daissy Fretes el 17052010
CURSOR cu_mes_dinero IS
   SELECT v_fec_actual, md.nro_cuenta, md.cod_moneda, md.estado, md.sal_capital,
          md.sal_interes,0 sal_ret_ade, md.dev_acumulado, null dev_dia, 0 dev_no_cobrado, 0 dev_suspenso, 0 val_suspenso, 1 cat_riesgo,
          0 dia_atraso, 0 sal_mon_local, null val_cotizacion,
          0 mto_linea
     FROM it.md_cta_documentos md
    WHERE md.estado not in ('N','S'); /*todos menos solicitado y cancelado*/
-- cursor Cuentas de Corresponsal--
CURSOR cu_corresponsal IS
  SELECT v_fec_actual, cb.nro_cuenta, cb.cod_moneda, cb.est_batch,cb.sal_tot_batch,  NULL sal_interes,NULL sal_ret_ade, 
          null dev_acumulado, null dev_dia, null dev_no_cobrado, null dev_suspenso, null val_suspenso, null cat_riesgo,
          null dia_atraso, 
          fub_con_mon_a_moneda(cb.cod_moneda,v_cod_mon_local,cb.sal_tot_batch,NULL,v_fec_actual), 
         -- pag_gen.FU_CON_MON_A_MONEDA (cb.cod_moneda, v_cod_mon_local, cb.sal_tot_batch, null) sal_mon_local,           
         (SELECT  val_conversion  FROM  ge_cotizaciones a
                        WHERE  fecha  = (SELECT max(fecha)
                               FROM ge_cotizaciones
                                    WHERE cod_moneda = cb.cod_moneda
                                     AND fecha <= v_fec_actual)
                          AND  cod_moneda = cb.cod_moneda)val_cotizacion,
        null mto_linea 
     FROM cc_cta_bancarias cb
       WHERE cb.cod_modalidad = 45;
      
--cursor de saldos diarios de ayer q no hayan entrado hoy y necesitan ser comparados en el reporte
CURSOR cu_saldos IS
    select v_fec_actual,w.nro_cuenta, w.cod_moneda,w.estado,0 sal_tot_cap,0 sal_blo_int,0 sal_ret_ade,              
    null dev_acumulado, null dev_dia,null dev_no_cobrado,null dev_suspenso,null val_suspenso, null cat_riesgo,0 dias_atraso,null sal_mon_local,null val_cotizacion,
          null mto_linea
     from ge_sal_diarios w
    where fecha = v_fec_anterior
      and (NVL(sal_tot_cap,0) <> 0 or NVL(sal_blo_int,0) <> 0 or NVL(sal_ret_ade,0) <> 0 or NVL(dev_dia,0) <> 0 or
          NVL(dia_atraso,0) <> 0  or NVL(dev_no_cobrado,0) <> 0 or NVL(dev_suspenso,0) <> 0)
      and not exists (
   select 1
     from ge_sal_diarios t
    where fecha = v_fec_actual
      and t.nro_cuenta = w.nro_cuenta);


 v_ge_sal_diarios array_tabla_sal;


/*PROCESO PRINCIPAL*/
BEGIN
  --borrar registros basura del dia
  delete from ge_sal_diarios where fecha = v_fec_actual;

  --insertar ahorros vistas
   BEGIN
      OPEN cu_cta_ahorros;
      LOOP
         FETCH cu_cta_ahorros BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'ERROR al insertar Saldos de Ahorros Vistas');
         END;
         EXIT WHEN cu_cta_ahorros%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE cu_cta_ahorros;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Generación saldos diarios en Ahorros Vistas '||sqlerrm);
   END;
  --insertar ahorros certificados
   BEGIN
      OPEN cu_cta_certificados;
      LOOP
         FETCH cu_cta_certificados BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'ERROR al insertar Saldos en Ahorros Certificados.');
         END;
         EXIT WHEN cu_cta_certificados%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE cu_cta_certificados;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Generación saldos diarios en Ahorros Certificados '||sqlerrm);
   END;

  --insertar cuentas corrientes
   BEGIN
      OPEN cu_cta_corrientes ;
      LOOP
         FETCH cu_cta_corrientes BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'ERROR. En al insertar Saldos en Cuentas Corrientes .');
         END;
         EXIT WHEN cu_cta_corrientes%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE cu_cta_corrientes ;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Generación saldos diarios en Cuentas Corrientes '|| sqlerrm);
   END;

--insertar tarjetas de crédito
   BEGIN
      OPEN c_tarjetas ;
      LOOP
         FETCH c_tarjetas BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'ERROR. En al insertar Saldos en Tarjetas .');
         END;
         EXIT WHEN c_tarjetas%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE c_tarjetas ;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Generación saldos diarios en Tarjetas '|| sqlerrm);
   END;
   
--Insertar Saldos de Cuentas de Corresponsal--
   BEGIN
      OPEN cu_corresponsal ;
      LOOP
         FETCH cu_corresponsal BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'ERROR. En al insertar Saldos diarios en Ctas. Corresponsales .');
         END;
         EXIT WHEN cu_corresponsal%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE cu_corresponsal ;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Generación saldos diarios Cuentas corresponsales '|| sqlerrm);
   END;

  --Insertar COMEX -- ICL 2009/07/31
    BEGIN
      OPEN  cu_cta_comex ;
      LOOP
         FETCH  cu_cta_comex  BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
            WHEN OTHERS THEN
                raise_application_error(-20000, 'ERROR al insertar Saldos en Comercio Exterior .');
         END;
         EXIT WHEN  cu_cta_comex%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE  cu_cta_comex;
    EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Generación saldos diarios en Comercio Exterior '||sqlerrm);
    END;

---Guardar también los saldos de mesa de dinero

    BEGIN
      OPEN cu_mes_dinero;
      LOOP
         FETCH cu_mes_dinero BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'ERROR al insertar Saldos en Mesa de Dinero .');
         END;
         EXIT WHEN cu_mes_dinero%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE cu_mes_dinero;
    EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Generación saldos diarios en Mesa de Dinero '||sqlerrm);
    END;

  --insertar cuentas que hoy ya no entraron pero estuvieron ayer
      BEGIN
      OPEN cu_saldos;
      LOOP
         FETCH cu_saldos BULK COLLECT
            INTO  v_ge_sal_diarios LIMIT 10000;
         BEGIN
            FORALL i IN 1 ..  v_ge_sal_diarios.count SAVE EXCEPTIONS
               INSERT INTO ge_sal_diarios VALUES  v_ge_sal_diarios(i);
         EXCEPTION
           when dup_val_on_index then
           raise_application_error(-20003,'Registro duplicado en saldos diarios');
           when others then
           raise_application_error(-20003,'Ins. saldos diarios. ');
         END;
         EXIT WHEN cu_saldos%NOTFOUND;
      END LOOP;
      COMMIT;
      CLOSE cu_saldos;
    EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Generación saldos diarios '||sqlerrm);
    END;
exception
  when dup_val_on_index then
    raise_application_error(-20004,'Registro duplicado cta_cte en saldos diarios.');
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Generación saldos diarios '||sqlerrm);
    End if;
end;
/

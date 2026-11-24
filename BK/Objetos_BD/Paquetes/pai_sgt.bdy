CREATE OR REPLACE PACKAGE BODY IT.PAI_SGT IS
V_SAL_MINIMO NUMBER(18);
v_fec_fin ig_parametros.fec_hasta%type;
v_periodo ig_parametros.tip_periodo%type;
v_fec_ini ig_parametros.fec_desde%type;
v_liquidado ig_parametros.liquidado%type;
v_mar_operativo ig_parametros.mar_operativo%type;
v_coeficiente ig_parametros.coeficiente%type;

V_MIN_EXIGIDO PR_PARAMETROS.CAP_MIN_EXIGIDO%TYPE;
v_por_min_exigido pr_parametros.por_cap_min_exigido%type;
V_RIESGO4 PR_PARAMETROS.POR_RIESGO_4%TYPE;
-- funcion para obtener el tipo de valor del sub concepto
FUNCTION LF_OBT_TIP_VALOR
   (P_COD_CONCEPTO IN NUMBER,
    P_COD_SUB_CONCEPTO IN NUMBER)
RETURN VARCHAR2 IS
v_tip_valor varchar2(1);
begin
  select tip_valor
    into v_tip_valor
    from ig_sub_conceptos a
   where a.cod_concepto = p_cod_concepto
     and a.cod_sub_concepto = p_cod_sub_concepto;
   return v_tip_valor;
exception
  when others then
     return null;
end;

/* Carga los datos de los ingresos y egresos */
PROCEDURE PR_CAR_ING_EGRESOS;
/* Devolucion de cargos */
PROCEDURE PR_REV_INGRESOS;
/* actualiza el monto en moneda local de los ingresos y egresos */
PROCEDURE PR_ACT_ING_EGRESOS;
-- insercion de metas de oficiales y unidades no definidas para el periodo
PROCEDURE PR_GEN_MET_NO_DEFINIDAS;

/* Calculo del margen operativo */
PROCEDURE PR_CAL_MAR_OPERATIVO;

/* Proceso principal de carga de operaciones por cuenta */
/* El proceso genera el detalle de operaciones y los resúmenes si recibe
'T', si recibe 'D' sólo detalles y si recibe 'R' sólo resúmenes */
/* Se debe correr diariamente entre los posteriores al cierre */
PROCEDURE PR_GEN_DAT_OPERACIONES
 (P_TIPO_PROCESO IN VARCHAR2 default 'T'
 )
 IS
-- INICIO DEL PROCESO PRINCIPAL---------------------------------------
v_error varchar2(2000);
BEGIN
   pag_cal.PR_OBT_DAT_CALENDAR(1);
   --recupera datos básicos
   v_fec_proceso := PAG_CAL.G_FEC_ACTUAL;
   pai_sgt.v_mon_calculo := fug_obt_pardinamico('COD_MON_CONSOLIDAR',NULL,NULL,NULL,NULL); --moneda de consolidado
   pai_sgt.v_cot_calculo := PAG_GEN.FU_OBT_COTIZACION(pap_cat.v_mon_fuerte);               --cotización de consolidado
   v_dias :=  pag_cal.G_FEC_PROXIMA - v_fec_proceso;
   if to_char(pag_cal.G_FEC_PROXIMA,'MM') <> to_char(v_fec_proceso,'MM') THEN
      -- es el ultimo dia de proceso del mes, solo se toman los dias hasta fin de mes
      v_dias := last_day(v_fec_proceso) - v_fec_proceso;
   elsif v_fec_proceso = pag_cal.G_PRI_DIA_MES_HABIL then
      -- es el primer dia habil, se toma los dias desde el primer dia...
      v_dias := pag_cal.g_fec_proxima - pag_cal.G_PRI_DIA_MES;
   end if;
   --busca parametros
   BEGIN
      SELECT FEC_HASTA, TIP_PERIODO, FEC_DESDE, LIQUIDADO, MAR_OPERATIVO, COEFICIENTE, COD_PERIODO
        INTO v_fec_fin, v_periodo, v_fec_ini, v_liquidado, v_mar_operativo, v_coeficiente, v_cod_periodo
        FROM IG_PARAMETROS
       WHERE v_fec_proceso between FEC_DESDE and FEC_HASTA;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         raise_application_error(-20000, 'Parámetros no registrados');
   END;
   --busca parámetros de morosidad
   begin
      --la máxima cantidad de días de mora a partir de los cuales se considera moroso
      select nvl(max(dia_hasta),0)
        into pai_sgt.v_dia_mora
        from ig_moras
       where morosidad = 'N';--hasta esta cantidad no es moroso pero más allá sí
   EXCEPTION
      when others then
         raise_application_error(-20000, 'Parámetros de Morosidad no registrados');
   end;

   IF p_tipo_proceso in ('T', 'D') THEN    ----  solo si es proceso general o detalles----
      -- Elimina los registros ---------------------
      v_lugar := 'Gen. operaciones..'; --Eliminando registro de la fecha de proceso si ya fue procesado';
      pr_gen_sub_conceptos;
   END IF;
   IF p_tipo_proceso IN ('T', 'R') THEN -- sólo resúmenes, si es general o resúmenes ----
      --eliminar logros morosidad
      v_lugar := 'Gen. morosidad..';
      delete from ig_ofi_logros
       where fecha = v_fec_proceso;
      --
      delete from ig_cli_logros
       where fecha = v_fec_proceso;
      --eliminar resúmenes x la fecha si hay
      delete ig_ope_res_entidad
       where fecha = v_fec_proceso;
      --unidad de negocios
      delete ig_ope_res_negocios
       where fecha = v_fec_proceso;
      --oficial
      delete ig_ope_res_oficiales
       where fecha = v_fec_proceso;
      --cliente
      delete ig_ope_res_clientes
       where fecha = v_fec_proceso;
      -- resumen general de oficiales
      delete from ig_res_oficiales
       where fecha = v_fec_proceso;
      -- borrar valores automaticos
      delete from ig_ren_valores a
        where fecha = v_fec_proceso
          and not exists (select 0 from ig_sub_conceptos b
                           where b.cod_concepto = a.cod_concepto
                             and b.cod_sub_concepto = a.cod_sub_concepto
                             and b.manual = 'S');
      -- Proceso de generación de resúmenes ------------------------------
      v_lugar := 'Gen. resúmenes..';
      PR_GEN_RESUMENES;
      commit;
      v_lugar := 'Gen. ingresos y egresos.';
      -- genera valores para la rentabilidad
      PR_CAR_ING_EGRESOS;
      v_lugar := 'Devoluciones de cargos';
      --
      PR_REV_INGRESOS;
      --
      v_lugar := 'Act. ingresos y egresos';
      -- actualiza los logros en moneda local
      PR_ACT_ING_EGRESOS;
      commit;
      --generar logros del oficial y por cliente
      v_lugar := 'generar logros por oficial y clientes';
      PR_GEN_LOGROS;
      commit;
      -- calculo el margen operativo
      v_lugar := 'Calculo del margen operativo';
      PR_CAL_MAR_OPERATIVO;
      --actualización de logros
      v_lugar := 'Act. las tablas de metas con los logros..';
      PR_ACT_MET_CON_LOGROS;
      -- inserto los logros de oficiales y unidades que no tienen metas definidas
      v_lugar := 'Insercion de metas no definidas';
      PR_GEN_MET_NO_DEFINIDAS;
      -- genero el adicional automatico por superar todas las metas
      v_lugar := 'Adicional por Superar todas las metas';
      --PR_CAL_ADICIONAL; -- ANULADO SOLO PARA PRUEBAS, DEBE ESTAR ACTIVO

   END IF;
   if p_tipo_proceso = 'T' then
      --actualizar fec_ult_proceso en parámetros
      begin
         update ig_parametros
            set fec_ult_proceso = v_fec_proceso
          where cod_periodo = v_cod_periodo;
      exception
         when others then
            raise_application_error(-20000,'Act.Fecha Periodo '||sqlerrm);
      end;
   end if;
   if p_tipo_proceso = 'L' then --liquidar
      PR_GEN_LIQUIDACION;
   end if;
--   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Gen.Operaciones -'||v_lugar||'-'||v_error||'-'||sqlerrm);
END;
/* Generar resúmenes */
PROCEDURE PR_GEN_RESUMENES
IS
BEGIN
   -- resumen x cliente
   insert into ig_ope_res_clientes
      (cod_periodo, cod_persona, cod_concepto, cod_sub_concepto, fecha, cod_plazo,
       cod_oficina, cod_unidad, cod_gru_economico, cod_usu_oficial, cat_riesgo,
       cod_moneda, sum_mto_apertura, sum_saldo, sum_interes,
       sum_int_devengado, sum_int_devengar, sum_int_dev_suspenso, sum_int_recuperado,
       sum_mto_mora, sum_sal_promedio, sum_logro, max_mora, pro_mora, can_cuentas)
       -- la suma de las operaciones por cliente, concepto y moneda
      (select v_cod_periodo,t.cod_persona, t.COD_CONCEPTO, t.cod_sub_concepto, v_fec_proceso, t.cod_plazo,
              x.COD_OFICINA, z.cod_unidad, x.cod_gru_economico, x.cod_usu_oficial, x.cat_riesgo,
              t.cod_moneda, t.mto_apertura, t.saldo, t.interes,
              t.devengado, int_devengar, int_dev_suspenso, int_recuperado,
              t.mora, t.sal_promedio, t.logro, t.max_mora, t.pro_mora,
              t.can_cuentas
         from ge_clientes x, ba_usuarios z,
              (select a.cod_persona, cod_concepto, cod_sub_concepto, cod_plazo, cod_moneda,
                      sum(mto_apertura) mto_apertura, sum(saldo) saldo, sum(interes) interes,
                      sum(int_devengado) devengado,
                      sum(int_devengar) int_devengar, sum(int_dev_suspenso) int_dev_suspenso,
                      sum(int_recuperado) int_recuperado,
                      sum(mto_mora) mora, sum(sal_promedio) sal_promedio,
                      sum(logro) logro, max(max_mora) max_mora, avg(pro_mora) pro_mora,
                      count(*) can_cuentas
                 from ig_operaciones a
                where fecha = v_fec_proceso
                group by a.cod_persona, cod_concepto, cod_sub_concepto, cod_plazo, cod_moneda) t
       where x.cod_usu_oficial = z.cod_usuario --oficial del cliente
         AND X.COD_PERSONA     = T.COD_PERSONA);   --cliente
commit;
   -- resumen x oficial
   insert into ig_ope_res_oficiales
      (cod_periodo,cod_usu_oficial, cod_concepto, cod_sub_concepto, fecha, cod_plazo,
      cod_oficina, cod_unidad,
      cod_moneda, sum_mto_apertura, sum_saldo, sum_interes,
      sum_int_devengado, sum_int_devengar, sum_int_dev_suspenso, sum_int_recuperado,
      sum_mto_mora, sum_sal_promedio,  sum_logro,  max_mora, pro_mora,
      can_cuentas, can_clientes)
      -- la suma de resumen de clientes por oficial, concepto y moneda
      (select v_cod_periodo,t.cod_usu_oficial, t.cod_concepto, t.cod_sub_concepto, v_fec_proceso, t.cod_plazo,
              z.cod_oficina, z.cod_unidad,
              t.cod_moneda, t.mto_apertura, t.saldo, t.interes,
              t.devengado, t.int_devengar, t.int_dev_suspenso, t.int_recuperado,
              t.mora, t.sal_promedio, t.logro,  t.max_mora, t.pro_mora,
              t.can_cuentas, t.can_clientes
         from ba_usuarios z, (select cod_usu_oficial, cod_concepto, cod_sub_concepto, cod_plazo, cod_moneda,
                                    sum(sum_mto_apertura) mto_apertura, sum(sum_saldo) saldo, sum(sum_interes) interes,
                                    sum(sum_int_devengado) devengado,
                                    sum(sum_int_devengar) int_devengar, sum(sum_int_dev_suspenso) int_dev_suspenso,
                                    sum(sum_int_recuperado) int_recuperado,
                                    sum(sum_mto_mora) mora, sum(sum_sal_promedio) sal_promedio,
                                    sum(sum_logro) logro,  max(max_mora) max_mora, avg(pro_mora) pro_mora,
                                    sum(can_cuentas) can_cuentas, count(*) can_clientes
                               from ig_ope_res_clientes a
                              where fecha = v_fec_proceso
                              group by a.cod_usu_oficial, cod_concepto, cod_sub_concepto, cod_plazo, cod_moneda) t   --cliente
        where z.cod_usuario = t.cod_usu_oficial);
commit;
   -- resumen x unidad de negocios
   insert into ig_ope_res_negocios
      (cod_periodo,cod_unidad, cod_concepto, cod_sub_concepto, fecha, cod_plazo,
      cod_moneda, sum_mto_apertura, sum_saldo, sum_interes,
      sum_int_devengado, sum_int_devengar, sum_int_dev_suspenso, sum_int_recuperado,
      sum_mto_mora, sum_sal_promedio, sum_logro, max_mora, pro_mora,
      can_cuentas, can_clientes)
       -- la suma de resumen de oficiales por unidad de negocios, concepto y moneda
      (select v_cod_periodo,cod_unidad, cod_concepto, cod_sub_concepto, v_fec_proceso, cod_plazo,
              cod_moneda, sum(sum_mto_apertura) capital, sum(sum_saldo) saldo, sum(sum_interes) interes,
              sum(sum_int_devengado) devengado,
              sum(sum_int_devengar) int_devengar, sum(sum_int_dev_suspenso) int_dev_suspenso,
              sum(sum_int_recuperado) int_recuperado,
              sum(sum_mto_mora) mora, sum(sum_sal_promedio) sal_promedio,
              sum(sum_logro) logro,  max(max_mora) max_mora, avg(pro_mora) pro_mora,
              sum(can_cuentas)  can_cuentas, sum(can_clientes) can_clientes
         from ig_ope_res_oficiales a
        where fecha = v_fec_proceso
        group by cod_unidad, cod_concepto, cod_sub_concepto, cod_plazo, cod_moneda);   --cliente
commit;
   --resumen x entidad
   insert into ig_ope_res_entidad
      (cod_periodo,cod_concepto, cod_sub_concepto, fecha, cod_plazo,
      cod_moneda, sum_mto_apertura, sum_saldo, sum_interes,
      sum_int_devengado, sum_int_devengar, sum_int_dev_suspenso, sum_int_recuperado,
      sum_mto_mora, sum_sal_promedio,  sum_logro,max_mora, pro_mora, can_cuentas, can_clientes)
       -- la suma de resumen de unidad de negocios por concepto y moneda
      (select v_cod_periodo,cod_concepto, cod_sub_concepto, v_fec_proceso, cod_plazo,
              cod_moneda, sum(sum_mto_apertura) capital, sum(sum_saldo) saldo, sum(sum_interes) interes,
              sum(sum_int_devengado) devengado, sum(sum_int_devengar), sum(sum_int_dev_suspenso),
              sum(sum_int_recuperado),
              sum(sum_mto_mora) mora, sum(sum_sal_promedio) sal_promedio,
              sum(sum_logro) logro,  max(max_mora) max_mora, avg(pro_mora) pro_mora,
              sum(can_cuentas), sum(can_clientes)
         from ig_ope_res_negocios a
        where fecha = v_fec_proceso
        group by cod_concepto, cod_sub_concepto, cod_plazo, cod_moneda);   --cliente
    -- resumen general por oficial
    insert into ig_res_oficiales
      (cod_usu_oficial, fecha, cod_periodo, cod_oficina, cod_unidad, tot_activo,
       tot_pasivo, tot_contingencia, tot_mora, can_cuentas, can_clientes, can_activo,
       can_pasivo, can_contingencia)
    select a.cod_usu_oficial, a.fecha, a.cod_periodo, a.cod_oficina, a.cod_unidad,
           sum(decode(c.tipo,'A',a.con_saldo,0)) tot_activo,
           sum(decode(c.tipo,'P',a.con_saldo,0)) tot_pasivo,
           sum(decode(c.tipo,'C',a.con_saldo,0)) tot_contingencia,
           sum(a.con_mto_mora) tot_mora,
           count(*) can_cuentas,
           count(distinct a.cod_persona) can_clientes,
           sum(decode(c.tipo,'A',1,0)) can_activo,
           sum(decode(c.tipo,'P',1,0)) can_pasivo,
           sum(decode(c.tipo,'C',1,0)) can_contingencia
      from ig_conceptos c, ig_operaciones a
     where a.cod_concepto = c.cod_concepto
       and a.fecha = v_fec_proceso
     group by a.cod_usu_oficial, a.fecha, a.cod_periodo, a.cod_oficina, a.cod_unidad;
EXCEPTION
   when others then
      raise_application_error(-20000,'Ins.Resúmenes '||sqlerrm);
END;
-- proceso que carga datos de los sub conceptos en forma dinamica
PROCEDURE PR_GEN_SUB_CONCEPTOS IS
v_sentencia varchar2(4000);
cursor sub_conceptos is
       select cod_concepto, cod_sub_concepto, tab_destino, cam_destino, cam_origen, det_sql
         from ig_sub_conceptos a
        where tab_destino is not null
        --and cod_sub_concepto = 701
        order by cod_concepto, cod_sub_concepto;
v_error varchar2(4000);
BEGIN
  --
  for sc in sub_conceptos loop
     v_lugar := 'Gen. sub concepto..'||sc.cod_concepto||'-'||sc.cod_sub_concepto;
     -- intento borrar los datos de esta fecha
     v_sentencia := 'begin delete '||sc.tab_destino||' where fecha = pai_sgt.v_fec_proceso and '||
                    ' cod_concepto = '||sc.cod_concepto||' and cod_sub_concepto = '||sc.cod_sub_concepto||'; end;';
     sql_util.ejecute_dml(v_sentencia, v_error);
     if v_error is not null then
        raise_application_error(-20000,v_error);
     end if;
     -- inserto into tabla de destino los datos
     v_sentencia := replace('BEGIN insert into '||sc.tab_destino||
                    ' ('||replace(sc.cam_destino,'#',',')||
                    ') select '||replace(sc.cam_origen,'#',',')||' '||
                    sc.det_sql||'; END;','&','pai_sgt.');
     sql_util.ejecute_dml(v_sentencia, v_error);
     if v_error is not null then
        /*insert into xx_log
        values (v_sentencia);
        commit;*/
        raise_application_error(-20000,replace(sc.cam_destino,'#',',')||'-'||v_error);
     end if;
     --
     commit;
	end loop;
END;
/*generación del concepto logros*/
PROCEDURE PR_GEN_LOGROS
IS
BEGIN
   --generar morosidad x oficial
   v_lugar := 'Gen. ofi. logros morosidad..';
   insert into ig_ofi_logros
      (fecha, cod_moneda, cod_unidad,  cod_usu_oficial,
      cod_concepto, cod_sub_concepto,
      cod_plazo,    cod_periodo,
      monto,        valor,           cantidad)
   select v_fec_proceso, a.cod_moneda, nvl(a.cod_unidad,999),  a.cod_usu_oficial,
          8, 801,
          a.cod_plazo,    v_cod_periodo,
          sum(a.con_mto_mora), sum(a.con_mto_mora) *100 / t.total porcentaje_mora, count(*) cantidad
     from ig_operaciones a, (select c.cod_usu_oficial, sum(nvl(c.con_saldo,0)+nvl(c.con_interes,0)) total --sobre el total de colocaciones
                               from ig_operaciones c
                              where c.fecha = v_fec_proceso
                                and c.cod_concepto in (2) -- colocaciones, operaciones vencidas
                               group by c.cod_usu_oficial) t
    where a.fecha = v_fec_proceso
      and a.cod_concepto in (2) -- colocaciones, operaciones vencidas
      and a.dia_mora > pai_sgt.v_dia_mora
      and nvl(a.mto_mora,0) > 0
      and a.cod_usu_oficial = t.cod_usu_oficial
    group by a.cod_moneda, nvl(a.cod_unidad,999), a.cod_usu_oficial, a.cod_plazo, a.cod_periodo, t.total;
   --generar logros de operaciones x oficial
   v_lugar := 'Gen. ofi. logros..';
   insert into ig_ofi_logros
      (fecha, cod_moneda,
       cod_unidad,  cod_usu_oficial,
       cod_concepto, cod_sub_concepto,
       cod_plazo,    cod_periodo,
       monto,        cantidad)
   select v_fec_proceso, a.cod_moneda,
          nvl(a.cod_unidad,999),  a.cod_usu_oficial,
          a.cod_concepto, a.cod_sub_concepto,
          a.cod_plazo,    v_cod_periodo,
          sum(a.con_logro), count(*)
     from ig_operaciones a
    where a.fecha = v_fec_proceso
    group by a.cod_moneda, nvl(a.cod_unidad,999), a.cod_usu_oficial, a.cod_concepto, a.cod_sub_concepto, a.cod_plazo, a.cod_periodo;
    -- inserto logros especiales (captaciones totales 3 = capt. vista 4 + capt. a plazo 5)
   v_lugar := 'Gen. ofi logros..3-301';
   insert into ig_ofi_logros
      (fecha, cod_moneda,
       cod_unidad,  cod_usu_oficial,
       cod_concepto, cod_sub_concepto,
       cod_plazo,    cod_periodo,
       monto,        cantidad)
   select v_fec_proceso, a.cod_moneda,
          nvl(a.cod_unidad,999),  a.cod_usu_oficial,
          3, 301,
          a.cod_plazo,    v_cod_periodo,
          sum(a.con_logro), count(*)
     from ig_operaciones a
    where a.fecha = v_fec_proceso
      and a.cod_concepto in (4,5) -- fijo vista 4 y a plazo 5
    group by a.cod_moneda, nvl(a.cod_unidad,999), a.cod_usu_oficial, a.cod_plazo, a.cod_periodo;

   -- generar los logros de oficiales por ingresos y egresos
   v_lugar := 'Gen. ofi logros.Ingresos-egresos..';
   insert into ig_ofi_logros
      (fecha, cod_moneda,
       cod_unidad,  cod_usu_oficial,
       cod_concepto, cod_sub_concepto,
       cod_plazo,    cod_periodo,
       monto,        cantidad)
   select v_fec_proceso, a.cod_moneda,
          NVL(u.cod_unidad,999),  b.cod_usu_oficial,
          a.cod_concepto, a.cod_sub_concepto,
          1,    v_cod_periodo,
          sum(pag_gen.FU_CON_MON_A_MONEDA(v_mon_local,v_mon_calculo,nvl(a.mto_equ_local,0))) logro,
          sum(a.cantidad) cantidadd
     from  ba_usuarios u, ge_clientes b, ig_ren_valores a
    where a.cod_periodo = v_cod_periodo
      and a.cod_persona = b.cod_persona
      and u.cod_usuario = b.cod_usu_oficial
    group by a.cod_moneda, NVL(u.cod_unidad,999), b.cod_usu_oficial,
             a.cod_concepto, a.cod_sub_concepto;
   --generar logros de morosidad x cliente
   v_lugar := 'Gen. cli logros morosidad..';
   insert into ig_cli_logros
      (fecha, cod_moneda, cod_persona, cod_concepto, cod_sub_concepto,
      cod_plazo, cod_periodo, monto,
      valor, cod_oficina, cod_unidad,
      cod_usu_oficial, cod_gru_economico, cat_riesgo, cantidad)
   select v_fec_proceso, z.cod_moneda, z.cod_persona, 8, 801,
          z.cod_plazo, v_cod_periodo, z.mto_mora,
          z.porcentaje_mora, b.cod_oficina, d.cod_unidad,
          b.cod_usu_oficial, b.cod_gru_economico, b.cat_riesgo, z.cantidad
     from ba_usuarios d, ge_clientes b,
          (select a.cod_persona, a.cod_moneda, a.cod_plazo, sum(a.con_mto_mora) mto_mora,
                  sum(a.con_mto_mora) *100 / t.total porcentaje_mora,  count(*) cantidad
             from ig_operaciones a, (select c.cod_usu_oficial, sum(nvl(c.con_saldo,0)+nvl(c.con_interes,0)) total --sobre el total de colocaciones
                                      from ig_operaciones c
                                     where c.fecha = v_fec_proceso
                                       and c.cod_concepto in (2) -- colocaciones, operaciones vencidas
                                      group by c.cod_usu_oficial) t
            where a.fecha = v_fec_proceso
              and a.cod_concepto in (2) -- colocaciones, operaciones vencidas
              and a.dia_mora > pai_sgt.v_dia_mora
              and nvl(a.mto_mora,0) > 0
              and a.cod_usu_oficial = t.cod_usu_oficial
            group by a.cod_persona, a.cod_moneda, a.cod_plazo, t.total) z
    where z.cod_persona = b.cod_persona
      and b.cod_usu_oficial = d.cod_usuario;
   --- logros de operaciones en clientes
   v_lugar := 'Gen. cli logros..';
   insert into ig_cli_logros
      (fecha, cod_moneda,
       cod_persona, cod_unidad,  cod_usu_oficial,
       cod_concepto, cod_sub_concepto,
       cod_plazo,    cod_periodo,
       cod_oficina, cod_gru_economico, cat_riesgo,
       monto,        cantidad)
   select v_fec_proceso, a.cod_moneda, a.cod_persona, a.cod_unidad,  a.cod_usu_oficial,
          a.cod_concepto, a.cod_sub_concepto,
          a.cod_plazo,    v_cod_periodo,
          b.cod_oficina,  b.cod_gru_economico, b.cat_riesgo,
          sum(a.con_logro), count(*)
     from  ge_clientes b, ig_operaciones a
    where a.fecha = v_fec_proceso
      and a.cod_persona = b.cod_persona
    group by a.cod_persona, a.cod_moneda, a.cod_unidad, a.cod_usu_oficial,
             b.cod_oficina, b.cod_gru_economico, b.cat_riesgo,
             a.cod_concepto, a.cod_sub_concepto, a.cod_plazo, a.cod_periodo;
  -- inserto logros especiales (captaciones totales 3 = capt. vista 4 + capt. a plazo 5)
   v_lugar := 'Gen. cli logros.3-301..';
   insert into ig_cli_logros
      (fecha, cod_moneda,
       cod_persona, cod_unidad,  cod_usu_oficial,
       cod_concepto, cod_sub_concepto,
       cod_plazo,    cod_periodo,
       cod_oficina, cod_gru_economico, cat_riesgo,
       monto,        cantidad)
   select v_fec_proceso, a.cod_moneda, a.cod_persona, a.cod_unidad,  a.cod_usu_oficial,
          3, 301,
          a.cod_plazo,    v_cod_periodo,
          b.cod_oficina,  b.cod_gru_economico, b.cat_riesgo,
          sum(a.con_logro), count(*)
     from  ge_clientes b, ig_operaciones a
    where a.fecha = v_fec_proceso
      and a.cod_persona = b.cod_persona
      and a.cod_concepto in (4,5) -- fijo captaciones vista y captaciones plazo
    group by a.cod_persona, a.cod_moneda, a.cod_unidad, a.cod_usu_oficial,
             b.cod_oficina, b.cod_gru_economico, b.cat_riesgo,
             a.cod_plazo, a.cod_periodo;
  -- cargar los logros por cliente de ingresos egresos
  v_lugar := 'Gen. cli logros.Ingresos-egresos..';
  insert into ig_cli_logros
      (fecha, cod_moneda, cod_persona, cod_unidad,  cod_usu_oficial,
      cod_concepto, cod_sub_concepto,
      cod_plazo,    cod_periodo,
      cod_oficina, cod_gru_economico, cat_riesgo,
      monto,        cantidad)
   select v_fec_proceso, a.cod_moneda, a.cod_persona, NVL(u.cod_unidad,999),  b.cod_usu_oficial,
          a.cod_concepto, a.cod_sub_concepto,
          1,    v_cod_periodo,
          b.cod_oficina,  b.cod_gru_economico, b.cat_riesgo,
          sum(pag_gen.FU_CON_MON_A_MONEDA(pai_sgt.v_mon_local,pai_sgt.v_mon_calculo,nvl(a.mto_equ_local,0))) logro,
          sum(a.cantidad) cantidadd
     from  ba_usuarios u, ge_clientes b, ig_ren_valores a
    where a.cod_periodo = v_cod_periodo
      and a.cod_persona = b.cod_persona
      and u.cod_usuario = b.cod_usu_oficial
    group by a.cod_persona, a.cod_moneda, NVL(u.cod_unidad,999), b.cod_usu_oficial,
             b.cod_oficina, b.cod_gru_economico, b.cat_riesgo,
             a.cod_concepto, a.cod_sub_concepto;

   --generar logros de bienes adjudicados x oficial
   v_lugar := 'Gen. ofi logros bienes adj..';
   insert into ig_ofi_logros
      (fecha, cod_moneda,
       cod_unidad,  cod_usu_oficial,
       cod_concepto, cod_sub_concepto,
       cod_plazo,    cod_periodo,
       monto,        cantidad)
   select v_fec_proceso, a.cod_moneda,
          a.cod_unidad,  a.cod_usu_oficial,
          a.cod_concepto, a.cod_sub_concepto,
          1,    v_cod_periodo,
          sum(a.con_logro), count(*)
     from ig_bie_adjudicados a
    where a.fecha = v_fec_proceso
    group by a.cod_moneda, a.cod_unidad, a.cod_usu_oficial, a.cod_concepto, a.cod_sub_concepto,  a.cod_periodo;
   --- logros de bienes adjudicados en clientes
   v_lugar := 'Gen. cli logros bienes adj..';
   insert into ig_cli_logros
      (fecha, cod_moneda,cod_persona, cod_unidad,  cod_usu_oficial,
      cod_concepto, cod_sub_concepto,
      cod_plazo,    cod_periodo,
      cod_oficina, cod_gru_economico, cat_riesgo,
      monto,        cantidad)
   select v_fec_proceso, a.cod_moneda, a.cod_persona, a.cod_unidad,  a.cod_usu_oficial,
          a.cod_concepto, a.cod_sub_concepto,
          1,    v_cod_periodo,
          b.cod_oficina,  b.cod_gru_economico, b.cat_riesgo,
          sum(a.con_logro), count(*)
     from  ge_clientes b, ig_bie_adjudicados a
    where a.fecha = v_fec_proceso
      and a.cod_persona = b.cod_persona
    group by a.cod_moneda, a.cod_persona, a.cod_unidad, a.cod_usu_oficial,
             b.cod_oficina, b.cod_gru_economico, b.cat_riesgo,
             a.cod_concepto, a.cod_sub_concepto,  a.cod_periodo;

   --- generar interoficina por cliente
   DECLARE
      cursor datos is
        SELECT cod_persona, cod_unidad, cod_usu_oficial, cod_plazo, cod_oficina,
               cod_gru_economico, cat_riesgo, cod_moneda, sum(total) monto, sum(cantidad), tipo
          FROM (
                select a.cod_persona, a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda, b.cod_oficina,
                       b.cod_gru_economico, b.cat_riesgo,
                       sum(nvl(decode(a.cod_sub_concepto,204,a.sal_promedio*-1,a.sal_promedio),0)) total, count(*) cantidad,'ACTIVO' tipo
                  from ge_clientes b, ig_operaciones a
                 where a.cod_persona = b.cod_persona
                   AND a.fecha = v_fec_proceso
                   and cod_concepto = 2
                 group by a.cod_persona, a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda, b.cod_oficina, b.cod_gru_economico, b.cat_riesgo
                union
                select a.cod_persona, a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda, b.cod_oficina,
                       b.cod_gru_economico, b.cat_riesgo,
                       sum(nvl(a.sal_promedio - (a.sal_promedio * (pai_sgt.FU_OBT_TAS_ENCAJE(a.cod_modulo,a.cod_modalidad,a.cod_moneda,nvl(fec_vencimiento - fec_apertura,0))/100)),0)) total,
                       count(*) cantidad, 'PASIVO' tipo
                  from ge_clientes b, ig_operaciones a
                 where a.cod_persona = b.cod_persona
                   AND a.fecha = v_fec_proceso
                   and cod_concepto in (4,5)
                 group by a.cod_persona, a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda, b.cod_oficina, b.cod_gru_economico, b.cat_riesgo
                 )
        group by cod_persona, cod_unidad, cod_usu_oficial, cod_plazo, cod_oficina, cod_gru_economico, cat_riesgo, tipo, cod_moneda
        order by cod_persona,cod_plazo,cod_moneda,tipo;
     v_activo number :=0;
     v_pasivo number :=0;
     v_monto number;
     v_corte varchar2(50);
     v_corte2 varchar2(50);
     v_fila varchar2(200);
     v_moneda ba_monedas.cod_moneda%type;
     v_plazo  ig_plazos.cod_plazo%type;
   BEGIN
      for reg in datos loop
         if nvl(v_corte,'X') <> reg.cod_persona||'-'||reg.cod_plazo||'-'||reg.cod_moneda then
           --calcular
           v_monto := pag_gen.FU_CON_MON_A_MONEDA(v_moneda,v_mon_calculo,((v_pasivo - v_activo)  * (pai_sgt.fu_obt_tas_interoficina(v_plazo, v_moneda))*90/36500));
           --actualizar los logros
           update ig_cli_logros
              set monto = NVL(monto,0) + v_monto
            where rowid = v_fila;
           if nvl(v_corte2,'Y') <> reg.cod_persona||'-'||reg.cod_plazo||'-'||reg.cod_moneda then
             --insertar registro
             insert into ig_cli_logros
                        (fecha, cod_moneda, cod_persona, cod_unidad,  cod_usu_oficial,
                        cod_concepto, cod_sub_concepto,
                        cod_plazo,    cod_periodo,
                        cod_oficina, cod_gru_economico, cat_riesgo,
                        monto,        cantidad)
                 values (v_fec_proceso, reg.cod_moneda, reg.cod_persona,reg.cod_unidad,reg.cod_usu_oficial,
                        6,601,
                        reg.cod_plazo,v_cod_periodo,
                        reg.cod_oficina, reg.cod_gru_economico, reg.cat_riesgo,
                        0, 0) --para actualizar luego
             returning rowid into v_fila;
             v_corte2 := reg.cod_persona||'-'||reg.cod_plazo||'-'||reg.cod_moneda;
           end if;
           --control de corte
           v_corte := reg.cod_persona||'-'||reg.cod_plazo||'-'||reg.cod_moneda;
           v_moneda := reg.cod_moneda;
           v_plazo  := reg.cod_plazo;
           v_activo := 0;
           v_pasivo := 0;
         end if;
         if reg.tipo = 'ACTIVO' then
            v_activo := reg.monto;
         else
            v_pasivo := reg.monto;
         end if;
      end loop;
      --calcular para el último corte
      v_monto := pag_gen.FU_CON_MON_A_MONEDA(v_moneda,v_mon_calculo,((v_pasivo - v_activo) * (pai_sgt.fu_obt_tas_interoficina(v_plazo, v_moneda))*90/36500));
      --actualizar los logros
      update ig_cli_logros
         set monto = NVL(monto,0) + v_monto
       where rowid = v_fila;
   exception
      when others then
         raise_application_error(-20000,'Ins.Interofic.Cliente. '||sqlerrm);
   END;

   --- generar interoficina por oficial
   DECLARE
      cursor datos is
        SELECT cod_unidad, cod_usu_oficial, cod_plazo, cod_moneda, sum(total) monto, sum(cantidad), tipo
          FROM (
                select a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda,
                       sum(nvl(decode(a.cod_sub_concepto,204,a.sal_promedio*-1,a.sal_promedio),0)) total, count(*) cantidad,'ACTIVO' tipo
                  from ig_operaciones a
                 where a.fecha = v_fec_proceso
                   and cod_concepto = 2
                 group by a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda
                union
                select a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda,
                       sum(nvl(a.sal_promedio - (a.sal_promedio * (pai_sgt.FU_OBT_TAS_ENCAJE(a.cod_modulo,a.cod_modalidad,a.cod_moneda,nvl(fec_vencimiento - fec_apertura,0))/100)),0)) total,
                       count(*) cantidad, 'PASIVO' tipo
                  from ig_operaciones a
                 where a.fecha = v_fec_proceso
                   and cod_concepto in (4,5)
                 group by a.cod_unidad, a.cod_usu_oficial, a.cod_plazo, a.cod_moneda
                 )
        group by cod_unidad, cod_usu_oficial, cod_plazo, tipo, cod_moneda
        order by cod_usu_oficial,cod_plazo,cod_moneda,tipo;
     v_activo number :=0;
     v_pasivo number :=0;
     v_monto number;
     v_corte varchar2(50);
     v_corte2 varchar2(50);
     v_fila varchar2(200);
     v_moneda ba_monedas.cod_moneda%type;
     v_plazo  ig_plazos.cod_plazo%type;
   BEGIN
      for reg in datos loop
         if nvl(v_corte,'X') <> reg.cod_usu_oficial||'-'||reg.cod_plazo||'-'||reg.cod_moneda then
           --calcular
           v_monto := pag_gen.FU_CON_MON_A_MONEDA(v_moneda,v_mon_calculo,((v_pasivo - v_activo)  * (pai_sgt.fu_obt_tas_interoficina(v_plazo, v_moneda))*90/36500));
           --actualizar los logros
           update ig_ofi_logros
              set monto = NVL(monto,0) + v_monto
            where rowid = v_fila;
           if nvl(v_corte2,'Y') <> reg.cod_usu_oficial||'-'||reg.cod_plazo||'-'||reg.cod_moneda then
              --insertar registro
              insert into ig_ofi_logros
                         (fecha, cod_moneda,
                         cod_unidad,  cod_usu_oficial,
                         cod_concepto, cod_sub_concepto,
                         cod_plazo,    cod_periodo,
                         monto,        cantidad)
                  values (v_fec_proceso, reg.cod_moneda,
                         reg.cod_unidad,reg.cod_usu_oficial,
                         6,601,
                         reg.cod_plazo,v_cod_periodo,
                         0, 0) --para actualizar luego
              returning rowid into v_fila;
              v_corte2 := reg.cod_usu_oficial||'-'||reg.cod_plazo||'-'||reg.cod_moneda;
           end if;
           --control de corte
           v_corte := reg.cod_usu_oficial||'-'||reg.cod_plazo||'-'||reg.cod_moneda;
           v_moneda := reg.cod_moneda;
           v_plazo  := reg.cod_plazo;
           v_activo := 0;
           v_pasivo := 0;
         end if;
         if reg.tipo = 'ACTIVO' then
            v_activo := reg.monto;
         else
            v_pasivo := reg.monto;
         end if;
      end loop;
      --calcular para el último corte
      v_monto := pag_gen.FU_CON_MON_A_MONEDA(v_moneda,v_mon_calculo,((v_pasivo - v_activo) * (pai_sgt.fu_obt_tas_interoficina(v_plazo, v_moneda))*90/36500));
      --actualizar los logros
      update ig_ofi_logros
         set monto = NVL(monto,0) + v_monto
       where rowid = v_fila;
   exception
      when others then
         raise_application_error(-20000,'Ins.Interofic.Oficial. '||sqlerrm);
   END;

exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000,'Ins.Logros '||sqlerrm);
      end if;
END;
/*proceso que actualiza los logros en las tablas de metas*/
PROCEDURE PR_ACT_MET_CON_LOGROS IS
 cursor oficial is
   select *
     from ig_ofi_metas
    where cod_periodo = v_cod_periodo
    for update;
 cursor unidad is
   select *
     from ig_uni_neg_metas
    where cod_periodo = v_cod_periodo
      for update;
 cursor entidad is
   select *
     from ig_ent_metas
    where cod_periodo = v_cod_periodo
      for update;
v_logro number;
v_tot_colocaciones number;
BEGIN
  v_lugar := '1';
   -- tomo el total de colocaciones
   select sum(c.con_saldo+c.con_interes)
     into v_tot_colocaciones --sobre el total de colocaciones
     from ig_operaciones c
    where c.fecha = v_fec_proceso
      and c.cod_concepto in (2); -- colocaciones, operaciones vencidas
v_lugar := '2';
   for reg in entidad loop
      --actualizar las metas con los logros obtenidos
      if FU_OBT_TIP_META(reg.cod_periodo, reg.cod_concepto, reg.cod_sub_concepto) <> 'P' then
        select sum(monto)
          into v_logro
          from ig_ofi_logros
         where cod_periodo  = reg.cod_periodo
           and fecha = v_fec_proceso
           and cod_concepto = reg.cod_concepto
           and (reg.cod_sub_concepto is null or (reg.cod_sub_concepto = cod_sub_concepto));
      else --porcentaje
        select sum(monto)/v_tot_colocaciones*100
          into v_logro
          from ig_ofi_logros
         where cod_periodo  = reg.cod_periodo
           and fecha = v_fec_proceso
           and cod_concepto = reg.cod_concepto
           and (reg.cod_sub_concepto is null or (reg.cod_sub_concepto = cod_sub_concepto));
      end if;
      update ig_ent_metas
         set logro = v_logro
       where current of entidad;
   end loop;
v_lugar := '3';
   ---
   for reg in unidad loop
      --actualizar las metas con los logros obtenidos
      if FU_OBT_TIP_META(reg.cod_periodo, reg.cod_concepto, reg.cod_sub_concepto) <> 'P' then
v_lugar := '3.1';
        select sum(monto) into v_logro
          from ig_ofi_logros
         where cod_periodo  = reg.cod_periodo
           and fecha = v_fec_proceso
           and cod_concepto = reg.cod_concepto
           and cod_unidad = reg.cod_unidad
           and (reg.cod_sub_concepto is null or (reg.cod_sub_concepto = cod_sub_concepto));
v_lugar := '3.2';
      else --porcentaje
v_lugar := '3.3 '||reg.cod_concepto||' '||reg.cod_sub_concepto||' '||reg.cod_unidad||' '||reg.cod_periodo;
        begin
        select sum(monto)/total*100 into v_logro
          from ig_ofi_logros,(select c.cod_unidad unidad, sum(c.con_saldo+c.con_interes) total --sobre el total de colocaciones
                                      from ig_operaciones c
                                     where c.fecha = v_fec_proceso
                                       and c.cod_concepto in (2) -- colocaciones, operaciones vencidas
                                      group by c.cod_unidad) t
         where cod_periodo  = reg.cod_periodo
           and fecha = v_fec_proceso
           and cod_concepto = reg.cod_concepto
           and cod_unidad = reg.cod_unidad
           and cod_unidad = unidad
           and (reg.cod_sub_concepto is null or (reg.cod_sub_concepto = cod_sub_concepto))
         group by total;
         exception
            when no_data_found then
               v_logro :=0;
            when others then
               raise_application_error(-20000,' Error al leer datos de ig_ofi_logros '||v_lugar);
         end;
v_lugar := '3.4';
      end if;
v_lugar := '3.5';
      update ig_uni_neg_metas
         set logro = v_logro
       where current of unidad;
   end loop;
   ---
v_lugar := '4';
   for reg in oficial loop
      --actualizar las metas con los logros obtenidos
      if FU_OBT_TIP_META(reg.cod_periodo, reg.cod_concepto, reg.cod_sub_concepto) <> 'P' then
        select sum(monto) into v_logro
          from ig_ofi_logros
         where cod_periodo  = reg.cod_periodo
           and fecha = v_fec_proceso
           and cod_concepto = reg.cod_concepto
           and cod_unidad = reg.cod_unidad
           and cod_usu_oficial = reg.cod_oficial
           and (reg.cod_sub_concepto is null or (reg.cod_sub_concepto = cod_sub_concepto));
      else --porcentaje
        select sum(valor) into v_logro
          from ig_ofi_logros
         where cod_periodo  = reg.cod_periodo
           and fecha = v_fec_proceso
           and cod_concepto = reg.cod_concepto
           and cod_unidad = reg.cod_unidad
           and cod_usu_oficial = reg.cod_oficial
           and (reg.cod_sub_concepto is null or (reg.cod_sub_concepto = cod_sub_concepto));
      end if;
      update ig_ofi_metas
         set logro = v_logro
       where current of oficial;
   end loop;
v_lugar := '5';
END;
/*proceso que reliza la liquidación de los periodos procesados*/
PROCEDURE PR_GEN_LIQUIDACION IS
v_cod_per_liquidar ig_parametros.cod_periodo%type;
BEGIN
  update ig_parametros x
     set x.liquidado = 'S'
   where x.fec_hasta = (select max(fec_hasta)
                          from ig_parametros
                         where fec_hasta < v_fec_proceso)
   returning x.cod_periodo into v_cod_per_liquidar;
  --
  update ig_ofi_metas t
     set t.liquidado = 'S'
   where t.cod_periodo = v_cod_per_liquidar;
  --
  update ig_uni_neg_metas t
     set t.liquidado = 'S'
   where t.cod_periodo = v_cod_per_liquidar;
  --
  update ig_ent_metas t
     set t.liquidado = 'S'
   where t.cod_periodo = v_cod_per_liquidar;
END;
/*obtener previsiones generales*/
FUNCTION FU_OBT_PREVISIONES
 (p_cod_periodo in number, p_fec_desde in date, p_fec_hasta in date, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
--v_fec_hasta date := pag_cal.FU_OBT_FEC_HABIL(p_fec_hasta,-1,null);
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --  between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 104
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener previsiones por unidad*/
FUNCTION FU_OBT_PREVISIONES
(p_cod_periodo in number, p_fec_desde in date, p_fec_hasta in date,P_COD_UNIDAD IN NUMBER, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 104
      and a.cod_unidad = p_cod_unidad
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener previsiones por oficial*/
FUNCTION FU_OBT_PREVISIONES
(p_cod_periodo in number, p_fec_desde in date, p_fec_hasta in date,P_COD_UNIDAD IN NUMBER,
P_COD_OFICIAL IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number is
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 104
      and a.cod_unidad = p_cod_unidad
      and a.cod_usu_oficial = p_cod_oficial
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener previsiones por cliente*/
FUNCTION FU_OBT_PREVISIONES
(p_cod_periodo in number, p_fec_desde in date, p_fec_hasta in date,
P_COD_UNIDAD IN NUMBER,
P_COD_OFICIAL IN VARCHAR2,
P_COD_CLIENTE IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_cli_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 104
      and a.cod_unidad = p_cod_unidad
      and a.cod_usu_oficial = p_cod_oficial
      and a.cod_persona = p_cod_cliente
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener ingresos por servicios generales*/
FUNCTION FU_OBT_SER_INGRESOS
(p_cod_periodo in number, p_fec_desde in date, p_fec_hasta in date, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 105
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener ingresos por servicios por unidad*/
FUNCTION FU_OBT_SER_INGRESOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date, P_COD_UNIDAD IN NUMBER, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 105
      and a.cod_unidad = p_cod_unidad
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener ingresos por servicios por oficial*/
FUNCTION FU_OBT_SER_INGRESOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date,
P_COD_UNIDAD IN NUMBER,
P_COD_OFICIAL IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 105
      and a.cod_unidad = p_cod_unidad
      and a.cod_usu_oficial = p_cod_oficial
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener ingresos por servicios por cliente*/
FUNCTION FU_OBT_SER_INGRESOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date,
 P_COD_UNIDAD IN NUMBER,
 P_COD_OFICIAL IN VARCHAR2,
 P_COD_CLIENTE IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_cli_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 105
      and a.cod_unidad = p_cod_unidad
      and a.cod_usu_oficial = p_cod_oficial
      and a.cod_persona = p_cod_cliente
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;

/*obtener costos por servicios generales*/
FUNCTION FU_OBT_SER_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 106
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener costos por servicios por unidad*/
FUNCTION FU_OBT_SER_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date, P_COD_UNIDAD IN NUMBER, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 106
      and a.cod_unidad = p_cod_unidad
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener costos por servicios por oficial*/
FUNCTION FU_OBT_SER_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date,P_COD_UNIDAD IN NUMBER,
P_COD_OFICIAL IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_ofi_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 106
      and a.cod_unidad = p_cod_unidad
      and a.cod_usu_oficial = p_cod_oficial
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;
/*obtener costos por servicios por cliente*/
FUNCTION FU_OBT_SER_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date,P_COD_UNIDAD IN NUMBER,
P_COD_OFICIAL IN VARCHAR2,
P_COD_CLIENTE IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
   select sum(monto)
     into v_retorno
     from ig_cli_logros a
    where a.cod_periodo = p_cod_periodo
      and fecha = p_fec_hasta   --between p_fec_desde and p_fec_hasta
      and a.cod_concepto = 1
      and a.cod_sub_concepto = 106
      and a.cod_unidad = p_cod_unidad
      and a.cod_usu_oficial = p_cod_oficial
      and a.cod_persona = p_cod_cliente
      and (a.cod_moneda = p_cod_moneda or nvl(p_cod_moneda,'z') = 'z');
   return v_retorno;
END;

/*obtener otros costos directos generales*/
FUNCTION FU_OBT_OTR_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
  if v_mon_calculo is null then
    pai_sgt.v_mon_calculo := fug_obt_pardinamico('COD_MON_CONSOLIDAR',NULL,NULL,NULL,NULL); --moneda de consolidado
  end if;
  select sum(monto)
    into v_retorno
    from ig_adi_oficiales b, ig_tip_adicionales a
   where a.cod_adicional = b.cod_adicional
     and a.tipo = 'S' --costos
     and b.cod_periodo = p_cod_periodo
     and fecha between p_fec_desde and p_fec_hasta
     and nvl(p_cod_moneda,'z') = 'z'; -- no tiene moneda, por lo que saldra solo en el consolidado
  return pag_gen.FU_CON_MON_A_MONEDA(v_mon_local, v_mon_calculo, v_retorno);
END;
/*obtener otros costos directos por unidad*/
FUNCTION FU_OBT_OTR_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date,P_COD_UNIDAD IN NUMBER, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
  if v_mon_calculo is null then
    pai_sgt.v_mon_calculo := fug_obt_pardinamico('COD_MON_CONSOLIDAR',NULL,NULL,NULL,NULL); --moneda de consolidado
  end if;
  select sum(monto)
    into v_retorno
    from ba_usuarios c, ig_adi_oficiales b, ig_tip_adicionales a
   where a.cod_adicional = b.cod_adicional
     and a.tipo = 'S' --costos
     and b.cod_oficial = c.cod_usuario
     and b.cod_periodo = p_cod_periodo
     and c.cod_unidad = p_cod_unidad
     and fecha between p_fec_desde and p_fec_hasta
     and nvl(p_cod_moneda,'z') = 'z'; -- no tiene moneda, por lo que saldra solo en el consolidado
  return pag_gen.FU_CON_MON_A_MONEDA(v_mon_local, v_mon_calculo, v_retorno);
END;
/*obtener otros costos directos por oficial*/
FUNCTION FU_OBT_OTR_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date,P_COD_UNIDAD IN NUMBER,
P_COD_OFICIAL IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number IS
v_retorno number;
BEGIN
  if v_mon_calculo is null then
    pai_sgt.v_mon_calculo := fug_obt_pardinamico('COD_MON_CONSOLIDAR',NULL,NULL,NULL,NULL); --moneda de consolidado
  end if;
  select sum(monto)
    into v_retorno
    from ig_adi_oficiales b, ig_tip_adicionales a
   where a.cod_adicional = b.cod_adicional
     and a.tipo = 'S' --costos
     and b.cod_periodo = p_cod_periodo
     and b.cod_oficial = p_cod_oficial
     and fecha between p_fec_desde and p_fec_hasta
     and nvl(p_cod_moneda,'z') = 'z'; -- no tiene moneda, por lo que saldra solo en el consolidado
  return pag_gen.FU_CON_MON_A_MONEDA(v_mon_local, v_mon_calculo, v_retorno);
END;
/*obtener otros costos directos por cliente*/
FUNCTION FU_OBT_OTR_COSTOS
(p_cod_periodo in number, p_fec_desde in date,p_fec_hasta in date,P_COD_UNIDAD IN NUMBER,
P_COD_OFICIAL IN VARCHAR2,
P_COD_CLIENTE IN VARCHAR2, P_COD_MONEDA IN VARCHAR2)
return number IS
BEGIN
   return 0;
END;
/*recuperar plazo*/
FUNCTION FU_OBT_PLAZO
(p_FEC_DESDE IN DATE,
p_FEC_HASTA IN DATE)
RETURN NUMBER IS
v_cod_plazo ig_plazos.cod_plazo%type;
BEGIN
   if p_fec_hasta is null then
      return 1;
   else
      begin
        SELECT COD_PLAZO
          into v_cod_plazo
          FROM IG_PLAZOS
         WHERE DIA_HASTA >= (p_fec_hasta - p_fec_desde)
           and rownum = 1
         order by dia_hasta;
        return v_cod_plazo;
      exception
        when no_data_found then
           return 1;
        when others then
           raise_application_error(-20000,'Recup.Plazo '||sqlerrm);
      end;
   end if;
END;
-- genera valores de la rentabilidad por transaccion
PROCEDURE PR_CAR_ING_EGRESOS IS

v_valor number;
v_cod_persona varchar2(15);
CURSOR MOVIMIENTOS IS
  SELECT NRO_CUENTA, COD_MONEDA, COD_CONCEPTO, COD_SUB_CONCEPTO,
         SUM(CANTIDAD) CANTIDAD, SUM(TOTAL) TOTAL
    FROM (
     SELECT M.NRO_CUENTA NRO_CUENTA, M.COD_MONEDA COD_MONEDA,
            B.COD_CONCEPTO COD_CONCEPTO, B.COD_SUB_CONCEPTO COD_SUB_CONCEPTO,
            COUNT(*) CANTIDAD,SUM(nvl(MONTO,0)) TOTAL
      FROM IG_SUB_CON_TRANSACCIONES B, GE_MOVIMIENTOS M  --- ramg07
      WHERE M.ESTADO = 'N'
      AND M.REVERSADO = 'N'
      AND B.COD_MODULO = M.COD_MODULO
      AND NVL(B.COD_MODALIDAD,M.COD_MODALIDAD) = M.COD_MODALIDAD
      AND B.COD_TRANSACCION = M.COD_TRANSACCION
      AND B.COD_MOD_PADRE = M.COD_MOD_PADRE
      AND NVL(B.COD_MAD_PADRE,M.COD_MAD_PADRE) = M.COD_MAD_PADRE
      AND B.COD_TRA_PADRE = M.COD_TRA_PADRE
      AND NRO_CUENTA IS NOT NULL
      GROUP BY M.NRO_CUENTA, M.COD_MONEDA, B.COD_CONCEPTO, B.COD_SUB_CONCEPTO
    UNION ALL
     SELECT fui_obt_mov_cuenta(M.FECHA, M.HORA, M.COD_USUARIO) NRO_CUENTA,
            M.COD_MONEDA, B.COD_CONCEPTO, B.COD_SUB_CONCEPTO,
            COUNT(*) CANTIDAD,SUM(nvl(MONTO,0)) TOTAL
      FROM IG_SUB_CON_TRANSACCIONES B, GE_MOVIMIENTOS M -- ramg07
      WHERE M.ESTADO = 'N'
      AND M.REVERSADO = 'N'
      AND B.COD_MODULO = M.COD_MODULO
      AND NVL(B.COD_MODALIDAD,M.COD_MODALIDAD) = M.COD_MODALIDAD
      AND B.COD_TRANSACCION = M.COD_TRANSACCION
      AND B.COD_MOD_PADRE = M.COD_MOD_PADRE
      AND NVL(B.COD_MAD_PADRE,M.COD_MAD_PADRE) = M.COD_MAD_PADRE
      AND B.COD_TRA_PADRE = M.COD_TRA_PADRE
      AND NRO_CUENTA IS NULL
      GROUP BY fui_obt_mov_cuenta(M.FECHA, M.HORA, M.COD_USUARIO),
            M.COD_MONEDA, B.COD_CONCEPTO, B.COD_SUB_CONCEPTO
     )
     GROUP BY NRO_CUENTA, COD_MONEDA, COD_CONCEPTO, COD_SUB_CONCEPTO;
----
v_mto_equ_local number(18,2);
begin
  for mv in movimientos loop
      v_cod_persona := fug_obt_cli_principal(mv.nro_cuenta);
      v_mto_equ_local := pag_gen.FU_CON_MON_A_MONEDA(mv.cod_moneda, v_mon_local, mv.total);

      update ig_ren_valores c
         set c.cantidad = nvl(c.cantidad,0) + nvl(mv.cantidad,0),
             c.monto = nvl(c.monto,0) + nvl(mv.total,0),
             c.mto_equ_local = nvl(c.mto_equ_local,0) + v_mto_equ_local
       where c.cod_persona = v_cod_persona
         and c.nro_cuenta = mv.nro_cuenta
         and c.cod_periodo = v_cod_periodo
         and c.fecha = v_fec_proceso
         and c.cod_concepto = mv.cod_concepto
         and c.cod_sub_concepto= mv.cod_sub_concepto
         and c.cod_moneda = mv.cod_moneda;
       if sql%notfound then
          insert into ig_ren_valores
             (cod_persona, nro_cuenta, cod_periodo, fecha, cod_concepto, cod_sub_concepto,
              cantidad, cod_moneda, monto, mto_equ_local
             )
          values
             (v_cod_persona, mv.nro_cuenta, v_cod_periodo, v_fec_proceso, mv.cod_concepto, mv.cod_sub_concepto,
              mv.cantidad, mv.cod_moneda, mv.total, v_mto_equ_local
             );
       end if;

  end loop;
END;

-- genera movimiento de egresos por las reversiones de ingresos
PROCEDURE PR_REV_INGRESOS IS

v_valor number;
v_cod_persona varchar2(15);
CURSOR MOVIMIENTOS IS
  SELECT NRO_CUENTA, COD_MONEDA, COD_CONCEPTO, COD_SUB_CONCEPTO,
         SUM(CANTIDAD) CANTIDAD, SUM(TOTAL) * -1 TOTAL
    FROM (
     SELECT M.NRO_CUENTA NRO_CUENTA, M.COD_MONEDA COD_MONEDA,
            B.COD_CONCEPTO COD_CONCEPTO, B.COD_SUB_CONCEPTO COD_SUB_CONCEPTO,
            COUNT(*) CANTIDAD,SUM(nvl(MONTO,0)) TOTAL
      FROM IG_SUB_CON_TRANSACCIONES B,GE_MOVIMIENTOS M
      WHERE M.ESTADO = 'N'
      AND M.REVERSADO = 'S'
      AND M.FECHA <> M.FEC_VALOR
      AND B.COD_MODULO = M.COD_MODULO
      AND NVL(B.COD_MODALIDAD,M.COD_MODALIDAD) = M.COD_MODALIDAD
      AND B.COD_TRANSACCION = M.COD_TRANSACCION
      AND B.COD_MOD_PADRE = M.COD_MOD_PADRE
      AND NVL(B.COD_MAD_PADRE,M.COD_MAD_PADRE) = M.COD_MAD_PADRE
      AND B.COD_TRA_PADRE = M.COD_TRA_PADRE
      AND NRO_CUENTA IS NOT NULL
      GROUP BY M.NRO_CUENTA, M.COD_MONEDA, B.COD_CONCEPTO, B.COD_SUB_CONCEPTO
    UNION ALL
     SELECT fui_obt_mov_cuenta(M.FECHA, M.HORA, M.COD_USUARIO) NRO_CUENTA,
            M.COD_MONEDA, B.COD_CONCEPTO, B.COD_SUB_CONCEPTO,
            COUNT(*) CANTIDAD,SUM(nvl(MONTO,0)) TOTAL
      FROM IG_SUB_CON_TRANSACCIONES B,GE_MOVIMIENTOS M
      WHERE M.ESTADO = 'N'
      AND M.REVERSADO = 'S'
      AND M.FECHA <> M.FEC_VALOR
      AND B.COD_MODULO = M.COD_MODULO
      AND NVL(B.COD_MODALIDAD,M.COD_MODALIDAD) = M.COD_MODALIDAD
      AND B.COD_TRANSACCION = M.COD_TRANSACCION
      AND B.COD_MOD_PADRE = M.COD_MOD_PADRE
      AND NVL(B.COD_MAD_PADRE,M.COD_MAD_PADRE) = M.COD_MAD_PADRE
      AND B.COD_TRA_PADRE = M.COD_TRA_PADRE
      AND NRO_CUENTA IS NULL
      GROUP BY fui_obt_mov_cuenta(M.FECHA, M.HORA, M.COD_USUARIO),
            M.COD_MONEDA, B.COD_CONCEPTO, B.COD_SUB_CONCEPTO
     )
     GROUP BY NRO_CUENTA, COD_MONEDA, COD_CONCEPTO, COD_SUB_CONCEPTO;
----
v_mto_equ_local number(18,2);
begin
  for mv in movimientos loop
      v_cod_persona := fug_obt_cli_principal(mv.nro_cuenta);
      v_mto_equ_local := pag_gen.FU_CON_MON_A_MONEDA(mv.cod_moneda, v_mon_local, mv.total);

      update ig_ren_valores c
         set c.cantidad = nvl(c.cantidad,0) + nvl(mv.cantidad,0),
             c.monto = nvl(c.monto,0) + nvl(mv.total,0),
             c.mto_equ_local = nvl(c.mto_equ_local,0) + v_mto_equ_local
       where c.cod_persona = v_cod_persona
         and c.nro_cuenta = mv.nro_cuenta
         and c.cod_periodo = v_cod_periodo
         and c.fecha = v_fec_proceso
         and c.cod_concepto = 10
         and c.cod_sub_concepto= 1001   -- fijo a egresos por devolucion de cargos
         and c.cod_moneda = mv.cod_moneda;
       if sql%notfound then
          insert into ig_ren_valores
             (cod_persona, nro_cuenta, cod_periodo, fecha, cod_concepto, cod_sub_concepto,
              cantidad, cod_moneda, monto, mto_equ_local
             )
          values
             (v_cod_persona, mv.nro_cuenta, v_cod_periodo, v_fec_proceso, 10, 1001,
              mv.cantidad, mv.cod_moneda, mv.total, v_mto_equ_local
             );
       end if;

  end loop;
END;




FUNCTION FU_OBT_DEVENGADO (P_NRO_CUENTA IN VARCHAR2, P_COD_MODULO IN NUMBER )
return number is
v_monto number := 0;
begin
  if p_cod_modulo = 6 then
    select nvl(sum(MTO_DEV_ACTUAL),0)
      into v_monto
      from pr_devengados
     where nro_cuenta = p_nro_cuenta
       and fecha = pai_sgt.v_fec_proceso;
  elsif p_cod_modulo = 3 then
    select nvl(sum(mto_interes),0)
      into v_monto
      from ah_devengados
     where nro_cuenta = p_nro_cuenta
       and fecha = pai_sgt.v_fec_proceso;
  end if;
  return v_monto;
exception
  when others then
     return 0;
END;

/*recuperar el tipo de meta del parámetro*/
FUNCTION FU_OBT_TIP_META
(p_COD_PERIODO IN NUMBER,
p_COD_CONCEPTO IN NUMBER,
p_COD_SUB_CONCEPTO IN NUMBER)
RETURN VARCHAR2 IS
v_tipo ig_par_conceptos.tip_meta%type;
BEGIN
   SELECT tip_meta
     into v_tipo
     from ig_par_conceptos
    where cod_periodo = p_cod_periodo
      and cod_concepto = p_cod_concepto
      and nvl(cod_sub_concepto,-1) = nvl(p_COD_SUB_CONCEPTO,-1);
   return v_tipo;
exception
   when no_data_found then
      raise_application_error(-20000,'No existe parámetro definido en Ig_Par_Conceptos.Per. '||p_cod_periodo||'-'||p_cod_concepto||'-'||p_cod_sub_concepto);
   when others then
      raise_application_error(-20000,'Obt.Parámetro Ig_Par_Conceptos.Per. '||p_cod_periodo||'-'||p_cod_concepto||'-'||p_cod_sub_concepto);
END;

/* actualiza el monto en moneda local de los ingresos y egresos */
PROCEDURE PR_ACT_ING_EGRESOS IS
cursor mov_dia is
select a.cod_concepto, a.cod_sub_concepto, b.tip_valor, b.costo,
       a.cantidad, a.cod_moneda, a.monto, a.rowid fila
  from ig_sub_conceptos b, ig_ren_valores a
 where a.cod_concepto = b.cod_concepto
   and a.cod_sub_concepto = b.cod_sub_concepto
   and fecha = v_fec_proceso;
v_cod_moneda    varchar2(6);
v_monto         number(18,2);
v_mto_equ_local number(18,2);
begin
  for mv in mov_dia loop
     if mv.tip_valor = 'C' then
        -- cantidad
        v_cod_moneda := v_mon_calculo;
        v_monto := nvl(mv.cantidad,0) * nvl(mv.costo,0);
     else -- es monto
        v_cod_moneda := mv.cod_moneda;
        v_monto      := mv.monto;
     end if;
     v_mto_equ_local := pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda, v_mon_local, v_monto);
     -- actualizo el monto y su equivalente en moneda local
     update ig_ren_valores
        set cod_moneda = v_cod_moneda,
            monto      = v_monto,
            mto_equ_local = v_mto_equ_local
      where rowid = mv.fila;
  end loop;
END;
/*recuperar tasa encaje*/
FUNCTION FU_OBT_TAS_ENCAJE
(P_COD_MODULO IN NUMBER,
P_COD_MODALIDAD IN NUMBER,
P_COD_MONEDA IN VARCHAR2,
P_PLAZO IN NUMBER)
RETURN NUMBER IS
v_tasa ig_tas_encajes.tasa%type;
begin
  SELECT tasa
    into v_tasa
    FROM IG_TAS_ENCAJES
   WHERE p_plazo between plz_desde and plz_hasta
     and cod_modulo = p_cod_modulo
     and cod_modalidad = p_cod_modalidad
     and cod_moneda = p_cod_moneda;
  return v_tasa;
exception
  when no_data_found then
     return 0;
  when others then
     raise_application_error(-20000,'Recup.Tasa '||sqlerrm);
end;

/*recuperar tasa interoficina*/
FUNCTION FU_OBT_TAS_INTEROFICINA
(p_PLAZO IN NUMBER,
P_COD_MONEDA IN VARCHAR2)
RETURN NUMBER IS
v_tasa ig_plazos_det.tas_compensacion%type;
begin
  SELECT tas_compensacion
    into v_tasa
    FROM IG_PLAZOS_DET
   WHERE cod_moneda = p_cod_moneda
     and cod_plazo = p_plazo;
  return v_tasa;
exception
  when no_data_found then
     return 0;
  when others then
     raise_application_error(-20000,'Recup.Tasa Inter. '||sqlerrm);
end;

-- Calculo del margen operativo
PROCEDURE PR_CAL_MAR_OPERATIVO is
  --
  v_fin_mes_anterior date;
  --- cursor de clientes de ingresos y egresos financieros
  cursor ing_egr is
  select a.cod_moneda, a.cod_persona, decode(a.cod_concepto,'2',101,102) cod_sub_concepto,
         b.cod_oficina, c.cod_unidad, b.cod_usu_oficial,
         b.cod_gru_economico, b.cat_riesgo,
         sum(con_int_devengado) monto,
         count(*) cantidad
    from ba_usuarios c, ge_clientes b, ig_operaciones a
   where a.cod_periodo = v_cod_periodo
     and a.cod_concepto in (2,4,5) -- colocaciones y captaciones
     and a.cod_persona = b.cod_persona
     and c.cod_usuario = b.cod_usu_oficial
   group by a.cod_moneda, a.cod_persona, decode(a.cod_concepto,'2',101,102),
         b.cod_oficina, c.cod_unidad, b.cod_usu_oficial,
         b.cod_gru_economico, b.cat_riesgo;
  --- previsiones
  cursor previsiones is
  select d.cod_moneda, b.cod_persona, 104 cod_sub_concepto,
         b.cod_oficina, nvl(u.cod_unidad,999) cod_unidad, b.cod_usu_oficial,
         b.cod_gru_economico, b.cat_riesgo,
         sum(pag_gen.FU_CON_MON_A_MONEDA(d.cod_moneda,'USD' /*v_mon_calculo*/,a.monto)) monto,
         count(*) cantidad
    from ba_usuarios u, ge_clientes b, ge_cta_clientes c, pr_cta_prestamos d, pr_previsiones a
   where a.fecha = v_fin_mes_anterior
     and a.nro_cuenta = c.nro_cuenta
     and c.relacion = 'P'
     and c.cod_persona = b.cod_persona
     and d.nro_cuenta = a.nro_cuenta
     and u.cod_usuario = b.cod_usu_oficial
   group by d.cod_moneda, b.cod_persona,
            b.cod_oficina, nvl(u.cod_unidad,999), b.cod_usu_oficial,
            b.cod_gru_economico, b.cat_riesgo;
   -- ingresos, egresos y costos
  cursor costos is
  select a.cod_moneda, a.cod_persona, decode(a.cod_concepto,'9',105,106) cod_sub_concepto,
         b.cod_oficina, nvl(u.cod_unidad,999) cod_unidad, b.cod_usu_oficial,
         b.cod_gru_economico, b.cat_riesgo,
         sum(mto_equ_local) monto,
         count(*) cantidad
    from ba_usuarios u, ge_clientes b, ig_ren_valores a
   where a.cod_periodo = v_cod_periodo
     and a.cod_concepto in (9,10,11) -- ingresos, egresos y costos
     and a.cod_persona = b.cod_persona
     and u.cod_usuario = b.cod_usu_oficial
   group by a.cod_moneda, a.cod_persona, decode(a.cod_concepto,'9',105,106),
         b.cod_oficina, nvl(u.cod_unidad,999), b.cod_usu_oficial,
         b.cod_gru_economico, b.cat_riesgo;
begin
   pag_cal.PR_OBT_DAT_CALENDAR(1);
   v_fin_mes_anterior := pag_cal.G_PRI_DIA_MES - 1;
   -- inserto los logros por ingresos y egresos financieros
   for ie in ing_egr loop
       insert into ig_cli_logros
           (fecha, cod_moneda, cod_persona, cod_concepto, cod_sub_concepto, cod_plazo, cod_periodo, monto,
            cod_oficina, cod_unidad, cod_usu_oficial, cod_gru_economico, cat_riesgo, cantidad)
       values
           (v_fec_proceso, ie.cod_moneda, ie.cod_persona, 1, ie.cod_sub_concepto, 1, v_cod_periodo, ie.monto,
            ie.cod_oficina, nvl(ie.cod_unidad,1), ie.cod_usu_oficial, ie.cod_gru_economico, ie.cat_riesgo, ie.cantidad);
   end loop;
   -- inserto los logros por previsiones
   for pr in previsiones loop
       insert into ig_cli_logros
           (fecha, cod_moneda, cod_persona, cod_concepto, cod_sub_concepto, cod_plazo, cod_periodo, monto,
            cod_oficina, cod_unidad, cod_usu_oficial, cod_gru_economico, cat_riesgo, cantidad)
       values
           (v_fec_proceso, pr.cod_moneda, pr.cod_persona, 1, pr.cod_sub_concepto, 1, v_cod_periodo, pr.monto,
            pr.cod_oficina, nvl(pr.cod_unidad,1), pr.cod_usu_oficial, pr.cod_gru_economico, pr.cat_riesgo, pr.cantidad);
   end loop;
   -- inserto los logros por ingresos, egresos y costos
   for co in costos loop
       insert into ig_cli_logros
           (fecha, cod_moneda, cod_persona, cod_concepto, cod_sub_concepto, cod_plazo, cod_periodo, monto,
            cod_oficina, cod_unidad, cod_usu_oficial, cod_gru_economico, cat_riesgo, cantidad)
       values
           (v_fec_proceso, co.cod_moneda, co.cod_persona, 1, co.cod_sub_concepto, 1, v_cod_periodo,
            pag_gen.FU_CON_MON_A_MONEDA(v_mon_local,v_mon_calculo,co.monto),
            co.cod_oficina, nvl(co.cod_unidad,1), co.cod_usu_oficial, co.cod_gru_economico, co.cat_riesgo, co.cantidad);
   end loop;
   -- inserto clientes logros
   insert into ig_cli_logros
         (fecha, cod_moneda, cod_persona, cod_concepto, cod_sub_concepto, cod_plazo, cod_periodo, monto,
          valor, cod_oficina, cod_unidad, cod_usu_oficial, cod_gru_economico, cat_riesgo, cantidad)
   select v_fec_proceso, cod_moneda, cod_persona, 1, 103, cod_plazo, cod_periodo, monto,
          valor, cod_oficina, nvl(cod_unidad,1), cod_usu_oficial, cod_gru_economico, cat_riesgo, cantidad
     from ig_cli_logros
    where cod_concepto = 6
      and cod_sub_concepto = 601
      and cod_periodo = v_cod_periodo
      and fecha = v_fec_proceso;

   -- inserto el resumen por oficiales de los conceptos insertados anteriormente
   insert into ig_ofi_logros
           (fecha, cod_moneda, cod_unidad, cod_usu_oficial, cod_concepto, cod_sub_concepto,
            cod_plazo, cod_periodo, monto,  cantidad)
    select fecha, cod_moneda, nvl(cod_unidad,1), cod_usu_oficial, cod_concepto, cod_sub_concepto,
           cod_plazo, cod_periodo, sum(monto), sum(cantidad)
      from ig_cli_logros
     where cod_concepto = 1
       and fecha = v_fec_proceso
       --and cod_sub_concepto in (101,101,103,104)
       and cod_periodo = v_cod_periodo
       and fecha = v_fec_proceso
     group by fecha, cod_moneda, cod_unidad, cod_usu_oficial, cod_concepto, cod_sub_concepto,
           cod_plazo, cod_periodo;
end;
-- insercion de datos de oficiale y unidades cuyas metas no fueron definidas
PROCEDURE PR_GEN_MET_NO_DEFINIDAS IS
BEGIN
-- inserto las metas no definidas para la unidad de negocio
insert into ig_uni_neg_metas
       (cod_concepto, cod_sub_concepto, cod_periodo, por_meta, mto_meta, liquidado, cod_unidad, logro)
 select a.cod_concepto, c.cod_sub_concepto, a.cod_periodo, 0, 0 , 'N', a.cod_unidad,
        sum(decode(a.cod_concepto,8,a.valor,a.monto))
  from ig_ent_metas c, ig_ofi_logros a
 where not exists (select 0
                     from ig_uni_neg_metas b
                    where b.cod_unidad = a.cod_unidad
                      and b.cod_periodo = a.cod_periodo
                      and b.cod_concepto = a.cod_concepto)
    and c.cod_periodo = a.cod_periodo
    and c.cod_concepto = a.cod_concepto
    and a.cod_periodo = v_cod_periodo
    and a.fecha = v_fec_proceso
    and (c.cod_sub_concepto is null or (c.cod_sub_concepto = a.cod_sub_concepto))
  group by a.cod_concepto, c.cod_sub_concepto, a.cod_periodo, a.cod_unidad;
-- inserto las metas de los oficiales no definidas para el periodo
insert into ig_ofi_metas
       (cod_oficial, cod_concepto, cod_sub_concepto, cod_periodo, por_meta, mto_meta, liquidado, cod_unidad, logro)
 select a.cod_usu_oficial, a.cod_concepto, c.cod_sub_concepto, a.cod_periodo, 0, 0 , 'N', a.cod_unidad,
        sum(decode(a.cod_concepto,8,a.valor,a.monto))
  from ig_ent_metas c, ig_ofi_logros a
 where not exists (select 0
                     from ig_ofi_metas b
                    where b.cod_oficial = a. cod_usu_oficial
                      and b.cod_unidad = a.cod_unidad
                      and b.cod_periodo = a.cod_periodo
                      and b.cod_concepto = a.cod_concepto)
    and c.cod_periodo = a.cod_periodo
    and c.cod_concepto = a.cod_concepto
    and a.cod_periodo = v_cod_periodo
    and a.fecha = v_fec_proceso
    and (c.cod_sub_concepto is null or (c.cod_sub_concepto = a.cod_sub_concepto))
  group by  a.cod_usu_oficial, a.cod_concepto, c.cod_sub_concepto, a.cod_periodo, a.cod_unidad;

-- inserto los logros y metas para los oficiales que no tuvieron ni metas ni logros en el periodo
insert into ig_ofi_metas
       (cod_oficial, cod_concepto, cod_sub_concepto, cod_periodo, por_meta, mto_meta, liquidado, cod_unidad, logro)
 select a.cod_usuario, c.cod_concepto, c.cod_sub_concepto, c.cod_periodo, 0, 0, 'N', a.cod_unidad, 0
   from ig_ent_metas c, ba_usuarios a
 where a.estado = 'A'
   and a.oficial = 'S'
   and a.cod_unidad is not null
   and not exists (select 0
                     from ig_ofi_metas b
                    where b.cod_unidad = a.cod_unidad
                      and b.cod_periodo = c.cod_periodo
                      and b.cod_concepto = c.cod_concepto
                      and b.cod_oficial = a.cod_usuario
                      and nvl(b.cod_sub_concepto,-1) = nvl(c.cod_sub_concepto,-1))
    and c.cod_periodo = v_cod_periodo
  group by a.cod_usuario, c.cod_concepto, c.cod_sub_concepto, c.cod_periodo, a.cod_unidad;

END;
-- Calculo del adicional automatico por superar todas las metas
PROCEDURE PR_CAL_ADICIONAL IS
cursor usuarios is
 select cod_oficial, sum(nvl(val_a_cobrar,0)) tot_a_cobrar,
   sum(decode(cod_concepto,1,nvl(superado,0),0)) superado
  from iv_usu_resultados a
 where cod_periodo = v_cod_periodo
   and ponderacion > 0
 group by cod_oficial
 having count(*) = sum(decode(superado,abs(superado),1,0))
    and (sum(decode(cod_concepto,1,nvl(superado,0),0)) >= 0 or 'N' = (select mar_operativo from ig_parametros b
 where b.cod_periodo = v_cod_periodo));
 v_monto number(18);
BEGIN
   if v_cod_periodo is null then
   --busca parametros
     if v_fec_proceso is null then
        v_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(1);
     end if;
     BEGIN
        SELECT FEC_HASTA, TIP_PERIODO, FEC_DESDE, LIQUIDADO, MAR_OPERATIVO, COEFICIENTE, COD_PERIODO
          INTO v_fec_fin, v_periodo, v_fec_ini, v_liquidado, v_mar_operativo, v_coeficiente, v_cod_periodo
          FROM IG_PARAMETROS
         WHERE v_fec_proceso between FEC_DESDE and FEC_HASTA;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           raise_application_error(-20000, 'Parámetros no registrados');
     END;
   end if;
   -- borro los registros anteriores
   delete from ig_adi_oficiales
    where cod_periodo = v_cod_periodo
      and cod_adicional = 999;
   -- genero el monto adicional por superar todas las metas
   for us in usuarios loop
       v_monto := round(us.tot_a_cobrar * .20);
       insert into ig_adi_oficiales
            (cod_periodo, cod_oficial, cod_adicional, monto, fecha)
       values
            (v_cod_periodo, us.cod_oficial, 999, v_monto, v_fec_proceso);
   end loop;
END;
-- Devuelve el total a cobrar por un usuario
FUNCTION FU_OBT_TOT_A_COBRAR (p_cod_oficial in varchar2)
  RETURN NUMBER IS
v_total number(18,2);
v_tot_adicional number(18,2);
BEGIN
   if v_cod_periodo is null then
   --busca parametros
     if v_fec_proceso is null then
        v_fec_proceso := pag_cal.FU_OBT_FEC_ACTUAL(1);
     end if;
     BEGIN
        SELECT FEC_HASTA, TIP_PERIODO, FEC_DESDE, LIQUIDADO, MAR_OPERATIVO, COEFICIENTE, COD_PERIODO
          INTO v_fec_fin, v_periodo, v_fec_ini, v_liquidado, v_mar_operativo, v_coeficiente, v_cod_periodo
          FROM IG_PARAMETROS
         where fec_hasta = (select max(fec_hasta)
                                from ig_parametros
                               where fec_hasta < v_fec_proceso);
     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           raise_application_error(-20000, 'Parámetros no registrados');
     END;
   end if;
   if v_liquidado = 'S' then
      return 0;
   else   
       -- sumo todo lo que debe cobrar
       select sum(nvl(val_a_cobrar,0))
         into v_total
        from iv_usu_resultados a
       where cod_periodo = v_cod_periodo
         and cod_oficial = p_cod_oficial
       group by cod_oficial
       having (sum(decode(cod_concepto,1,nvl(superado,0),0)) >= 0 or 'N' = (select mar_operativo from ig_parametros b
       where b.cod_periodo = v_cod_periodo));
       select sum(decode(z.tipo,'D',x.monto * -1, x.monto))
         into v_tot_adicional
         from ig_tip_adicionales z, ig_adi_oficiales x
        where x.cod_periodo = v_cod_periodo
          and x.cod_oficial = p_cod_oficial
          and x.monto > 0
          and x.cod_adicional = z.cod_adicional
          and z.tipo in ('D','C');
       v_total := nvl(v_total,0) + nvl(v_tot_adicional,0);
       return v_total;
   end if;
exception
  when no_data_found then
     return 0;
  when others then
     raise_application_error(-20000,'Error al calcular el total a cobrar de '||p_cod_oficial||' - '||sqlerrm);
END;


END PAI_SGT;
/


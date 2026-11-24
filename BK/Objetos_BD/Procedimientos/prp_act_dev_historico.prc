CREATE OR REPLACE PROCEDURE IT.PRP_ACT_DEV_HISTORICO IS
   --- Este procedimiento actualiza el monto devengado diario de las cuentas en las tablas
   --- de resumenes mensuales.
   v_fecha           ge_calendarios.fec_actual%type;
   v_ano             pr_sal_mensuales.ano%type;
   v_mes             pr_sal_mensuales.mes%type;
   v_dia             varchar2(02);
   v_sentencia       varchar2(2000);
   v_error           varchar2(1000);
   r_pdhis           pr_devengados_his%rowtype;
   --- Cursor de devengamientos del dia
   cursor c_devengados is
   select dev.nro_cuenta, cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina,
          dev.tipo, sum(dev.mto_dev_actual) mto_actual
     from pr_cta_prestamos cta, pr_devengados dev
    where cta.nro_cuenta = dev.nro_cuenta
      and dev.fecha = v_fecha
    group by dev.nro_cuenta, cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina,
             dev.tipo;
   --- Cursor de reconocimientos o reversiones de utilidad
   cursor c_utilidad is
   select fecha, nro_cuenta, monto, fec_valor, cod_oficina, cod_modulo, cod_modalidad
     from ge_movimientos
    where cod_modulo = 6
      and fecha = v_fecha
      and cod_transaccion = 948; --- Reconocimiento de utilidad
   --- Cursor de saldos devengados a un fin de mes
   cursor c_sal_devengado is
   select cta.nro_cuenta, cta.dev_acumulado, cta.dev_suspenso, cta.dev_no_cobrado,
          cta.cod_modulo, cta.cod_modalidad, cta.cod_oficina
     from pr_cta_prestamos cta
    where cta.estado <> 'N'
      and (nvl(cta.dev_suspenso,0) <> 0 or nvl(cta.dev_no_cobrado,0) <> 0);
             
PROCEDURE LP_INS_PR_DEVEN_HIS
  (p_pdhis in pr_devengados_his%rowtype
 )
 IS
BEGIN
   insert into pr_devengados_his(
      nro_cuenta, ano, mes, mto_interes,
      cod_modulo, cod_modalidad, cod_oficina,
      dev_no_cobrado, dev_suspenso, dev_ganancia, 
      dev_recuperado, sal_dev_acu_mes,sal_dev_noc_mes,
      sal_dev_sus_mes)
   values
     (p_pdhis.nro_cuenta, p_pdhis.ano, p_pdhis.mes, p_pdhis.mto_interes,
      p_pdhis.cod_modulo, p_pdhis.cod_modalidad, p_pdhis.cod_oficina,
      p_pdhis.dev_no_cobrado, p_pdhis.dev_suspenso, p_pdhis.dev_ganancia,
      p_pdhis.dev_recuperado, p_pdhis.sal_dev_acu_mes, p_pdhis.sal_dev_noc_mes,
      p_pdhis.sal_dev_sus_mes);
exception
   when dup_val_on_index then
      --- Actualizar el registro existente.
      update pr_devengados_his
         set mto_interes     = nvl(mto_interes,0) + nvl(p_pdhis.mto_interes,0),
             dev_no_cobrado  = nvl(dev_no_cobrado,0) + nvl(p_pdhis.dev_no_cobrado,0),
             dev_suspenso    = nvl(dev_suspenso,0) + nvl(p_pdhis.dev_suspenso,0),
             dev_ganancia    = nvl(dev_ganancia,0) + nvl(p_pdhis.dev_ganancia,0),
             dev_recuperado  = nvl(dev_recuperado,0) + nvl(p_pdhis.dev_recuperado,0),
             sal_dev_acu_mes = nvl(sal_dev_acu_mes,0) + nvl(p_pdhis.sal_dev_acu_mes,0),
             sal_dev_noc_mes = nvl(sal_dev_noc_mes,0) + nvl(p_pdhis.sal_dev_noc_mes,0),
             sal_dev_sus_mes = nvl(sal_dev_sus_mes,0) + nvl(p_pdhis.sal_dev_sus_mes,0)
       where nro_cuenta = p_pdhis.nro_cuenta
         and ano        = p_pdhis.ano
         and mes        = p_pdhis.mes;
END;
BEGIN
   pag_cal.PR_OBT_DAT_CALENDAR(6);
   v_fecha := pag_cal.G_FEC_ACTUAL;
   v_ano   := to_number(to_char(v_fecha,'YYYY'));
   v_mes   := to_number(to_char(v_fecha,'MM'));
   v_dia   := to_char(v_fecha,'DD');
   --- Actualizar saldos mensuales de prestamos
   for reg in c_devengados loop
      r_pdhis.nro_cuenta      := reg.nro_cuenta;
      r_pdhis.ano             := to_number(to_char(v_fecha,'YYYY'));
      r_pdhis.mes             := to_number(to_char(v_fecha,'MM'));
      r_pdhis.cod_modulo      := reg.cod_modulo;
      r_pdhis.cod_modalidad   := reg.cod_modalidad;
      r_pdhis.cod_oficina     := reg.cod_oficina;
      r_pdhis.sal_dev_acu_mes := 0;
      r_pdhis.sal_dev_noc_mes := 0;
      r_pdhis.sal_dev_sus_mes := 0;
      r_pdhis.dev_no_cobrado  := 0;
      r_pdhis.dev_suspenso    := 0;
      r_pdhis.dev_recuperado  := 0;
      r_pdhis.dev_ganancia    := 0; 
      r_pdhis.mto_interes     := nvl(reg.mto_actual,0);
      if reg.tipo = 'N' then
         r_pdhis.dev_no_cobrado := nvl(reg.mto_actual,0);
         r_pdhis.dev_ganancia   := nvl(reg.mto_actual,0);
      else
         r_pdhis.dev_suspenso   := nvl(reg.mto_actual,0);
      end if;
      --insertar o actualizar histórico
      lp_ins_pr_deven_his(r_pdhis);
   end loop;
   for reg in c_utilidad loop
      r_pdhis.nro_cuenta      := reg.nro_cuenta;
      r_pdhis.ano             := to_number(to_char(reg.fecha,'YYYY'));
      r_pdhis.mes             := to_number(to_char(reg.fecha,'MM'));
      r_pdhis.cod_modulo      := reg.cod_modulo;
      r_pdhis.cod_modalidad   := reg.cod_modalidad;
      r_pdhis.cod_oficina     := reg.cod_oficina;
      r_pdhis.sal_dev_acu_mes := 0;
      r_pdhis.sal_dev_noc_mes := 0;
      r_pdhis.sal_dev_sus_mes := 0;
      r_pdhis.mto_interes     := 0;
      r_pdhis.dev_no_cobrado  := 0;
      r_pdhis.dev_suspenso    := 0;
      r_pdhis.dev_recuperado  := nvl(reg.monto,0);
      r_pdhis.dev_ganancia    := nvl(reg.monto,0);
      --insertar o actualizar histórico
      lp_ins_pr_deven_his(r_pdhis);
   end loop;
   if v_fecha = pag_cal.G_ULT_DIA_MES_HABIL then
      --- Si es el ultimo dia del mes registrar saldos devengados
      for reg in c_sal_devengado loop
         r_pdhis.nro_cuenta      := reg.nro_cuenta;
         r_pdhis.ano             := to_number(to_char(v_fecha,'YYYY'));
         r_pdhis.mes             := to_number(to_char(v_fecha,'MM'));
         r_pdhis.cod_modulo      := reg.cod_modulo;
         r_pdhis.cod_modalidad   := reg.cod_modalidad;
         r_pdhis.cod_oficina     := reg.cod_oficina;
         r_pdhis.sal_dev_acu_mes := reg.dev_acumulado;
         r_pdhis.sal_dev_noc_mes := reg.dev_no_cobrado;
         r_pdhis.sal_dev_sus_mes := reg.dev_suspenso;
         r_pdhis.mto_interes     := 0;
         r_pdhis.dev_no_cobrado  := 0;
         r_pdhis.dev_suspenso    := 0;
         r_pdhis.dev_recuperado  := 0;
         r_pdhis.dev_ganancia    := 0;
         --insertar o actualizar histórico
         lp_ins_pr_deven_his(r_pdhis);
      end loop;
   end if;
END;
/


create or replace procedure it.PRT_ACT_SAL_MENSUAL
 IS
v_contador number := 0;
v_fcdehoy  date;
v_fcanter  date;
v_fcproxi  date;
v_ani_fcant number(4);
v_mes_fcant number(2);
v_ani_fchoy number(4);
v_mes_fchoy number(2);
v_ani_fcprx number(4);
v_mes_fcprx number(2);
v_dias     number(3,0);
v_diferdia number;
v_diferde1 number;
v_cdmoned  ba_monedas.cod_moneda%type;
v_mesprx   number(2);
v_aniprx   number(4);
v_fechaini date;
v_aniinici number(4);
v_mesinici number(2);
rv_gcale   ge_calendarios%rowtype;
cursor mae_cur is
  select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
         t.sal_facturar, t.sal_facturado, t.sal_financiado, t.sal_cuo_pendientes
    from ta_cta_tarjetas t
   where t.estado <> 'C';
v_para varchar(60) := null;
v_saldo ge_cuentas.sal_promedio%type :=0;
v_can_dias number;
TYPE tar_rec IS TABLE OF mae_cur%ROWTYPE;
v_tar_data tar_rec;
type rg_ge_cuentas is record(nro_cuenta ge_cuentas.nro_cuenta%type,
                             sal_promedio ge_cuentas.sal_promedio%type);
TYPE typ_ge_cuentas is TABLE OF rg_ge_cuentas;
reg_ge_cuentas typ_ge_cuentas := typ_ge_cuentas();
begin
  v_fcdehoy := pag_cal.fu_obt_fec_actual(5);
  rv_gcale  := pag_cal.fu_obt_reg_cal(5);
  v_fcanter := rv_gcale.fec_anterior;
  v_fcproxi := rv_gcale.fec_proxima;
  v_para := '1';
  v_mes_fcant := to_char(v_fcanter, 'MM');
  v_ani_fcant := to_char(v_fcanter, 'YYYY');
  v_mes_fchoy := to_char(v_fcdehoy, 'MM');
  v_ani_fchoy := to_char(v_fcdehoy, 'YYYY');
  v_mes_fcprx := to_char(v_fcproxi, 'MM');
  v_ani_fcprx := to_char(v_fcproxi, 'YYYY');
  v_dias := v_fcdehoy - v_fcanter;
  v_mesprx := to_char(v_fcproxi,'MM') ;
  v_aniprx := to_char(v_fcproxi,'YYYY');
  v_fechaini := v_fcdehoy;
  v_aniinici := to_char(v_fcdehoy,'YYYY');
  v_mesinici := to_char(v_fcdehoy,'MM');
  reg_ge_cuentas  := typ_ge_cuentas();
  v_para := '2';
  OPEN mae_cur;
   LOOP
     FETCH mae_cur BULK COLLECT INTO v_tar_data LIMIT 20000;
      EXIT WHEN v_tar_data.COUNT = 0;    
      FOR i IN v_tar_data.FIRST .. v_tar_data.LAST LOOP
        v_contador := v_contador + 1;
        v_para := '3 '||v_tar_data(i).nro_cuenta;
        if v_mes_fcprx <> v_mes_fchoy then
             v_diferdia := (last_day(v_fcdehoy)- v_fcdehoy) + 1;
             v_diferde1 := to_number(to_char(v_fcproxi,'DD')) - 1;
        else
             v_diferdia := v_fcproxi- v_fcdehoy;
             v_diferde1 := 0;
        end if;
       --- modifica saldos promedios del mes de la fecha anterior ----
        v_para := '4 '||v_tar_data(i).nro_cuenta;
        update ta_sal_mensuales
             set acu_sal_financiado = nvl(acu_sal_financiado,0) +
                                      nvl(v_tar_data(i).sal_financiado,0) * v_diferdia,
                 acu_sal_facturar   = nvl(acu_sal_facturar,0) +
                                      nvl(v_tar_data(i).sal_facturar,0) * v_diferdia,
                 acu_sal_facturado  = nvl(acu_sal_facturado,0) +
                                      nvl(v_tar_data(i).sal_facturado,0) * v_diferdia,
                 acu_sal_cuo_pendiente = nvl(acu_sal_cuo_pendiente,0) +
                                      nvl(v_tar_data(i).sal_cuo_pendientes,0) * v_diferdia,
                 can_dia_acumulado  = nvl(can_dia_acumulado,0) + v_diferdia
           where nro_cuenta = v_tar_data(i).nro_cuenta
             and ano = v_ani_fchoy
             and mes = v_mes_fchoy
         returning nvl(acu_sal_financiado,0) + nvl(acu_sal_facturar,0) + nvl(acu_sal_facturado,0) + nvl(acu_sal_cuo_pendiente,0), can_dia_acumulado into v_saldo, v_can_dias;

          ------------------------------------------------------------
          -- si no encontro genera un nuevo registro para la cuenta --
          ------------------------------------------------------------
        if sql%notfound then
             v_para := '5 '||v_tar_data(i).nro_cuenta;
             insert into ta_sal_mensuales
                   (cod_modulo, cod_modalidad, cod_oficina,nro_cuenta,ano, mes,
                    sal_financiado, sal_facturar, sal_facturado, sal_cuo_pendientes,
                    acu_sal_financiado, acu_sal_facturar, acu_sal_facturado, acu_sal_cuo_pendiente, can_dia_acumulado)
               values
                     (v_tar_data(i).cod_modulo, v_tar_data(i).cod_modalidad,v_tar_data(i).cod_oficina,
                      v_tar_data(i).nro_cuenta, v_ani_fchoy, v_mes_fchoy,
                      nvl(v_tar_data(i).sal_financiado,0), nvl(v_tar_data(i).sal_facturar,0), nvl(v_tar_data(i).sal_facturado,0), nvl(v_tar_data(i).sal_cuo_pendientes,0),
                      nvl(v_tar_data(i).sal_financiado,0) * v_diferdia,
                      nvl(v_tar_data(i).sal_facturar,0) * v_diferdia,
                      nvl(v_tar_data(i).sal_facturado,0) * v_diferdia,
                      nvl(v_tar_data(i).sal_cuo_pendientes,0)* v_diferdia  ,v_diferdia)
             returning nvl(acu_sal_financiado,0) + nvl(acu_sal_facturar,0) + nvl(acu_sal_facturado,0) + nvl(acu_sal_cuo_pendiente,0), can_dia_acumulado into v_saldo, v_can_dias;
        end if;
        --actualizar saldo promedio en ge_cuentas
        reg_ge_cuentas.EXTEND;
        reg_ge_cuentas(reg_ge_cuentas.COUNT).nro_cuenta := v_tar_data(i).nro_cuenta;
        if nvl(v_can_dias,0) = 0 then
          reg_ge_cuentas(reg_ge_cuentas.COUNT).sal_promedio := round(0,2);
        else
          reg_ge_cuentas(reg_ge_cuentas.COUNT).sal_promedio := round((v_saldo / v_can_dias), 2);
        end if;  
        if v_diferde1 <> 0 then
             ------------------------------------------------
             -- agrega registro del nuevo mes              --
             ------------------------------------------------
             v_para := '6 '||v_tar_data(i).nro_cuenta;
             insert into ta_sal_mensuales
                   (cod_modulo, cod_modalidad, cod_oficina,nro_cuenta,ano, mes,
                    sal_financiado, sal_facturar, sal_facturado, sal_cuo_pendientes,
                    acu_sal_financiado, acu_sal_facturar, acu_sal_facturado,acu_sal_cuo_pendiente,can_dia_acumulado)
               values
                     (v_tar_data(i).cod_modulo, v_tar_data(i).cod_modalidad,
                      v_tar_data(i).cod_oficina,
                      v_tar_data(i).nro_cuenta, v_ani_fcprx, v_mes_fcprx,
                      nvl(v_tar_data(i).sal_financiado,0), nvl(v_tar_data(i).sal_facturar,0), nvl(v_tar_data(i).sal_facturado,0),nvl(v_tar_data(i).sal_cuo_pendientes,0),
                      nvl(v_tar_data(i).sal_financiado,0) * v_diferdia,
                      nvl(v_tar_data(i).sal_facturar,0) * v_diferdia,
                      nvl(v_tar_data(i).sal_facturado,0) * v_diferdia,
                      nvl(v_tar_data(i).sal_cuo_pendientes,0) * v_diferdia, v_diferdia);
        end if;
      end loop;
  END LOOP;
  if v_contador = 0 then
    NULL;
  end if;
   BEGIN
     v_para := '7';
     FORALL i IN reg_ge_cuentas.FIRST .. reg_ge_cuentas.LAST
       update ge_cuentas
          set sal_promedio = reg_ge_cuentas(i).sal_promedio
        where nro_cuenta = reg_ge_cuentas(i).nro_cuenta;
   END;
exception
 when others then
    raise_application_error(-20000,'El ultimo numero ejecutado es '||to_char(v_para)||' '||sqlerrm);
end PRT_ACT_SAL_MENSUAL;
/

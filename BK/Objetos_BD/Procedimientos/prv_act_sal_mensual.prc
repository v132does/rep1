CREATE OR REPLACE PROCEDURE IT.PRV_ACT_SAL_MENSUAL
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
  select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,sal_total from ov_cta_vencidas
   where estado <> 'C';
v_para number(2) := 0;
v_saldo ge_cuentas.sal_promedio%type;
v_can_dias number;

begin
  v_fcdehoy := pag_cal.fu_obt_fec_actual(6);
  rv_gcale  := pag_cal.fu_obt_reg_cal(6);
  v_fcanter := rv_gcale.fec_anterior;
  v_fcproxi := rv_gcale.fec_proxima;
  v_para := 1;
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
  v_para := 2;
  for m1 in mae_cur loop
    v_contador := v_contador + 1;
    v_para := 3;
    if v_mes_fcprx <> v_mes_fchoy then
         v_diferdia := (last_day(v_fcdehoy)- v_fcdehoy) + 1;
         v_diferde1 := to_number(to_char(v_fcproxi,'DD')) - 1;
    else
         v_diferdia := v_fcproxi- v_fcdehoy;
         v_diferde1 := 0;
    end if;
   --- modifica saldos promedios del mes de la fecha anterior ----
    v_para := 4;
    update ov_sal_mensuales
         set sal_acumulado = nvl(sal_acumulado,0) +
                          m1.sal_total * v_diferdia,
             can_dia_acumulado = nvl(can_dia_acumulado,0) + v_diferdia
       where nro_cuenta = m1.nro_cuenta
         and ano = v_ani_fchoy
         and mes = v_mes_fchoy
       returning nvl(sal_acumulado,0), can_dia_acumulado into v_saldo, v_can_dias;
    ------------------------------------------------------------
    -- si no encontro genera un nuevo registro para la cuenta --
    ------------------------------------------------------------
    if sql%notfound then
       v_para := 5;
       insert into ov_sal_mensuales
             (cod_modulo, cod_modalidad, cod_oficina,nro_cuenta,
              ano, mes, sal_total,
              sal_acumulado, can_dia_acumulado)
         values
               (m1.cod_modulo, m1.cod_modalidad, m1.cod_oficina, m1.nro_cuenta,
                v_ani_fchoy, v_mes_fchoy, m1.sal_total , m1.sal_total * v_diferdia,  v_diferdia)
       returning nvl(sal_acumulado,0), can_dia_acumulado into v_saldo, v_can_dias;
    end if;
    --actualizar saldo promedio en ge_cuentas
    update ge_cuentas
       set sal_promedio = round(decode(v_can_dias, 0, 0, v_saldo / v_can_dias), 2)
     where nro_cuenta = m1.nro_cuenta;


    if v_diferde1 <> 0 then
       ------------------------------------------------
       -- agrega registro del nuevo mes              --
       ------------------------------------------------
       v_para := 6;
       insert into ov_sal_mensuales
              (cod_modulo,cod_modalidad,cod_oficina,nro_cuenta,ano,mes,sal_total,
               sal_acumulado, can_dia_acumulado)
         values
               (m1.cod_modulo, m1.cod_modalidad,
                m1.cod_oficina,
                m1.nro_cuenta, v_ani_fcprx, v_mes_fcprx,
                m1.sal_total , m1.sal_total * v_diferde1, v_diferde1);
    end if;
  end loop;
  if v_contador = 0 then   
    null;
  end if;
exception
 when others then
    raise_application_error(-20001,'El ultimo numero ejecutado es '||to_char(v_para)||SQLERRM);
end;
/


CREATE OR REPLACE PROCEDURE IT.PRA_ACT_VAL_TASA
  /* actualiza la tasa de cuentas de ahorros en ge_cuentas */
 IS
   v_fecha         ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(3);
   --- Cursor de ahorros vistas
CURSOR cuentas IS
  select a.nro_cuenta,
  fug_obt_val_tasa(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda, 
                  g.sal_promedio, g.tas_personalizada, g.cod_tasa, null, v_fecha) tasa
  from ge_cuentas g, ah_cta_vistas a
  where a.estado not in ('A','X','C','P')
    and a.nro_cuenta = g.nro_cuenta
  union
  select a.nro_cuenta,fug_obt_val_tasa(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda, 
                   g.sal_promedio, a.tas_personalizada, a.cod_tasa, null, v_fecha) tasa
  from ge_cuentas g, ah_cta_certificados a
  where a.estado not in ('A','X','C','P','T')
    and g.nro_cuenta = a.nro_cuenta;
v_nro_cuenta ge_cuentas.nro_cuenta%type;  
BEGIN
   -- tasas de cuentas
   for reg in cuentas loop
      v_nro_cuenta := reg.nro_cuenta;
      update ge_cuentas
         set val_tasa = reg.tasa
       where nro_cuenta = reg.nro_cuenta;
   end loop;
exception
   when others then
      raise_application_error(-20000,'Act.Ge_cuentas Cta.'||v_nro_cuenta||' -'||sqlerrm);   
END;
/


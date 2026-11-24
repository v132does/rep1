declare cursor c_dat is
select a.* 
from cc_previsiones a, ge_cuentas b
where b.nro_cuenta = a.Nro_Cuenta
and b.cod_moneda = 'USD'
and a.usu_insercion = 'MIGRAV';
v_mto_cotizacion number := fug_obt_cotizacion('USD');
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
  for k in c_dat loop
    update cc_previsiones a 
    set monto = round(nvl(a.monto,0) / v_mto_cotizacion,2),
        saldo = round(nvl(a.saldo,0) / v_mto_cotizacion,2),
        linea = round(nvl(a.linea,0) / v_mto_cotizacion,2),
        tot_gar_computable = round(nvl(a.tot_gar_computable,0) / v_mto_cotizacion,2),
        tot_pri_prevision = round(nvl(a.tot_pri_prevision,0) / v_mto_cotizacion,2),
        tot_prv_contingencia = round(nvl(a.tot_prv_contingencia,0) / v_mto_cotizacion,2),
        mto_pre_anterior = round(nvl(a.mto_pre_anterior,0) / v_mto_cotizacion,2)
    where a.fecha = k.fecha
      and a.nro_cuenta = k.nro_cuenta;
    COMMIT;
  end loop;
end;

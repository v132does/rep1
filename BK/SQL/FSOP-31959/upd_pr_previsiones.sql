declare cursor c_dat is
select a.* 
from pr_previsiones a, ge_cuentas b
where b.nro_cuenta = a.Nro_Cuenta
and b.cod_moneda = 'USD'
and a.usu_insercion = 'MIGRAV';
v_mto_cotizacion number := fug_obt_cotizacion('USD');
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
  for k in c_dat loop
    update pr_previsiones a 
    set a.monto = round(a.monto / v_mto_cotizacion,2),
        a.sal_capital = round(a.sal_capital / v_mto_cotizacion,2),
        a.dev_no_cobrado = round(a.dev_no_cobrado / v_mto_cotizacion,2),
        a.tot_gar_computables = round(a.tot_gar_computables / v_mto_cotizacion,2),
        a.tot_pri_prevision = round(a.tot_pri_prevision / v_mto_cotizacion,2),
        a.tot_cap_pri_prevision = round(a.tot_cap_pri_prevision / v_mto_cotizacion,2),
        a.tot_cap_seg_prevision = round(a.tot_cap_seg_prevision / v_mto_cotizacion,2),
        tot_int_pri_prevision = round(a.tot_int_pri_prevision / v_mto_cotizacion,2),
        tot_int_seg_prevision = round(a.tot_int_seg_prevision / v_mto_cotizacion,2),
        mto_pre_total = round(a.mto_pre_total / v_mto_cotizacion,2)
    where a.fecha = k.fecha
      and a.nro_cuenta = k.nro_cuenta;
    COMMIT;
  end loop;
end;

create or replace function it.fup_obt_fec_desembolso(p_nro_cuenta in varchar2)
  return date is
  v_fecha date;
begin
     select pm.fecha
     into v_fecha
     from pr_movimientos_his pm
     where pm.cod_tra_padre=358
     and upper(pm.reversado)='N'
     and pm.nro_cuenta=p_nro_cuenta
     fetch first 1 rows only;

  return v_fecha;
exception
  when others then
    return v_fecha;
end fup_obt_fec_desembolso;
/


create or replace function it.fup_obt_fec_ini_cuota(p_cuenta in varchar2, p_cuota in number) return date is
  Result date;
begin
  if p_cuota = 1 then
     select pr.fec_inicio
       into result
       from pr_cta_prestamos pr
      where pr.nro_cuenta = p_cuenta;
  else
    select pcuo.fec_vencimiento
      into result
      from pr_cuotas pcuo
     where pcuo.nro_cuenta = p_cuenta
       and pcuo.nro_cuota = p_cuota - 1; /*fec_vencimiento de la cuota anterior + 1*/
  end if;
  
  return(Result);
exception
  when others then
     return null;
end fup_obt_fec_ini_cuota;
/


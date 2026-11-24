create or replace function it.fuh_obt_sal_puesto
(p_cod_persona rh_puestos.cod_persona%type,
 p_fec_hasta   date)
return number
is
   v_salario rh_puestos.salario%type;
begin
   begin
      select salario
      into   v_salario
      from   rh_puestos p
      where  p.cod_persona = p_cod_persona
      and    p.fec_desde   = (select max(r.fec_desde)
                              from   rh_puestos r
                              where  r.cod_persona = p_cod_persona
                              and    to_number(to_char(p_fec_hasta,'YYYYMM')) >= to_number(to_char(r.fec_desde,'YYYYMM')) );
   exception
      when no_data_found then
           v_salario := null;
      when too_many_rows then
           raise_application_error(-20000,'Demasiados valores para el puesto.');
      when others then
           raise_application_error(-20000,'Error al consultar Puestos - '||sqlerrm );
   end;
   return v_salario;
end;
/


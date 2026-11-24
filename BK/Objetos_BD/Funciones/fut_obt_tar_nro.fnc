create or replace function it.fut_obt_tar_nro(p_cod_persona ta_tarjetas.cod_persona%type, p_nro_cuenta ta_tarjetas.nro_cuenta%type)
return varchar2 is
v_nro_tarjeta ta_tarjetas.nro_tarjeta%type;
begin
  select b.nro_tarjeta
    into v_nro_tarjeta
    from ge_cta_clientes a, ta_tarjetas b
   where b.nro_cuenta = p_nro_cuenta
     and b.cod_persona = p_cod_persona
     and b.nro_cuenta = a.nro_cuenta
     and b.cod_persona = a.cod_persona
     and a.relacion = 'P';
--     and b.vigente='S';
return v_nro_tarjeta;
exception
  when too_many_rows then
    select max(b.nro_tarjeta)
    into v_nro_tarjeta
    from ge_cta_clientes a, ta_tarjetas b
   where b.nro_cuenta = p_nro_cuenta
     and b.cod_persona = p_cod_persona
     and b.nro_cuenta = a.nro_cuenta
     and b.cod_persona = a.cod_persona
     and a.relacion = 'P'
     and b.fec_vencimiento = (select max(x.fec_vencimiento)
                                from ta_tarjetas x
                               where x.nro_cuenta = b.nro_cuenta
                                 and x.cod_persona = b.cod_persona);
     return v_nro_tarjeta;
  when no_data_found then
  return null;
  when others then
  return null;
end;
/


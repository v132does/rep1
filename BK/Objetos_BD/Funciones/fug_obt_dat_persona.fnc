create or replace function it.fug_obt_dat_persona(p_cod_persona in varchar2,
                                               p_tipo_dato   in char)
  return varchar2 is
  v_return varchar2(1500);
  cursor ctas(p_cod_persona in ba_personas.cod_persona%type) is
    SELECT substr(fug_obt_des_modalidad(a.cod_modalidad), 1, 20) || ' - ' ||
           a.nro_cuenta || ' (' || a.cod_moneda || ') ' || ' | ' as cta
      from ge_cuentas a, ge_cta_clientes b
     WHERE a.nro_cuenta = b.nro_cuenta
       and b.relacion in ('O', 'P', 'Y')
       and b.cod_persona = p_cod_persona
       and b.cod_modulo in (3, 4)
       and b.cod_modalidad in (31, 41)
       and exists (Select 0
              from ge_est_cuentas c
             where c.cod_modulo = b.cod_modulo
               and c.cod_modalidad = b.cod_modalidad
               and c.estado = a.estado
               and c.activo = 'S')
     order by b.cod_modulo;
begin
  if p_tipo_dato = 'C' then
    --'C' hace el Select para obtener las cuentas de la persona
    for x in ctas(p_cod_persona) loop
      v_return := v_return || x.cta;
    end loop;
  end if;
  return(v_return);
Exception
  When NO_DATA_FOUND Then
    return('NO HAY INFORMACIÓN');
end fug_obt_dat_persona;
/


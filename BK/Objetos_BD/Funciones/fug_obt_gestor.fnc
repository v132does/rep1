create or replace function it.fug_obt_gestor(p_cod_persona in ba_personas.cod_persona%type)
  return varchar2 is
  v_usu_oficial varchar2(100);

Begin
  select max(fue_obt_nom_usuario(cod_usu_oficial))
    into v_usu_oficial
    from ge_clientes
   where cod_persona = p_cod_persona;
  if trim(v_usu_oficial) is null then
    if fug_es_empleado(p_cod_persona) = 'S' then
      v_usu_oficial := 'RRHH';
    end if;
  end if;
  return nvl(v_usu_oficial, 'NO TIENE GESTOR');
exception
  when no_data_found then
    raise_application_error(-20000,
                            'No existe el gestor para ese cliente: ' ||
                            p_cod_persona);
End;
/


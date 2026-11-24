CREATE OR REPLACE FUNCTION IT."FUG_OBT_SEG_CLI_PRE"(p_cod_persona in ge_clientes.cod_persona%type)
  return varchar2 is
  v_preferente varchar2(100);
begin
  select trim(g.cod_seg_preferente) || ' ' || trim(s.descripcion)
    into v_preferente
    from ge_clientes g, ge_seg_preferentes S
   where g.cod_persona = p_cod_persona
     and g.cod_seg_preferente = s.cod_seg_preferente;
  return v_preferente;
exception
  when no_data_found then
    return null;
  when others then
    raise_Application_error(-20000, 'Obt.Segmento.' || sqlerrm);
end;
/


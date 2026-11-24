create or replace function it.fue_obt_cod_persona(p_nro_documento in varchar2)
  Return varchar2 is
  v_cod_per_documento ba_personas.cod_persona%type;
begin
  select cod_persona
    into v_cod_per_documento
    from ba_personas p
   where nro_documento = p_nro_documento;
  return v_cod_per_documento;
exception
  when too_many_rows then
    begin
      select cod_persona
        into v_cod_per_documento
        from ba_personas p, ba_tip_documentos b
       where p.cod_tip_documento = b.cod_tip_documento
         and nro_documento = p_nro_documento
         and b.abreviatura = 'CI';
      return v_cod_per_documento;
    exception
      when no_data_found then
        return null;
      when others then
        return null;
    end;
  when no_data_found then
    return null;
  when others then
    return null;
end;
/


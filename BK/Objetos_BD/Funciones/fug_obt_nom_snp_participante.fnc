create or replace function it.fug_obt_nom_snp_participante(p_cod_swift varchar2)
  return varchar2 is
  nombre varchar2(200);
begin
  begin
    select p.participante
      into nombre
      from it.gv_snp_participantes p
     where p.cod_swift = p_cod_swift;
  exception
    when no_data_found then
      nombre := null;
    when too_many_rows then
      select p.participante
        into nombre
        from gv_snp_participantes p
       where p.cod_swift = p_cod_swift
         and rownum = 1;
    when others then
      nombre := null;
  end;
  return(nombre);
end fug_obt_nom_snp_participante;
/


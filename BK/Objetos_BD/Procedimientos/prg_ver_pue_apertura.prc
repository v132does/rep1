create or replace procedure it.prg_ver_pue_apertura(p_cod_persona in varchar2,
                                                 p_pue_apertura out varchar2,
                                                 p_mensaje out varchar2) is
begin
  p_pue_apertura := 'S';
  p_mensaje := null;
  begin
  --Verificacion si pa persona es OFAC--
    select 'N', 'Error. La persona esta en la lista de OFAC, no puede Operar'
      into p_pue_apertura, p_mensaje
      from ba_personas a
     where a.cod_persona = p_cod_persona
       and a.nro_documento like 'OFAC%';
  exception
    when no_data_found then
         p_pue_apertura := 'S';
  end;
exception
    when others then
         raise_application_error(-20000,'Error en prg_ver_pue_apertura');
end prg_ver_pue_apertura;
/


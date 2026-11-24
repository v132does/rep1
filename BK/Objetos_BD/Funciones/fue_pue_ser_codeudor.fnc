create or replace function it.FUE_PUE_SER_CODEUDOR(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  v_gar_tercero ba_per_juridicas.gar_tercero%type;
begin
  Select nvl(gar_tercero, 'N')
    into v_gar_tercero
    from ba_per_juridicas
   where cod_persona = p_cod_persona;
  return(v_gar_tercero);
Exception
  When NO_DATA_FOUND then
       raise_application_error(-20000, 'Persona '||p_cod_persona||' Inexistente!');
  When OTHERS then
       raise_application_error(-20000, 'Error en la Persona '||p_cod_persona||': '||sqlerrm);
end FUE_PUE_SER_CODEUDOR;
/


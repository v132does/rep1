create or replace function it.FUG_OBT_EST_DOC_CATASTRO(p_cod_persona ba_personas.cod_persona%type)
  return varchar2 is

  V_VAL_MAXIMO BA_COD_REFERENCIAS.VAL_MAXIMO%TYPE := 6;
  V_ESTADO     BA_COD_REFERENCIAS.VAL_MINIMO%TYPE;

Begin
  begin
    Select MIN(R.VAL_MAXIMO)
      into V_VAL_MAXIMO
      from ba_cod_referencias r
     where r.dominio = 'CAT_EST_DOCUMENTO'
       and exists (select 1
              from GE_DOC_CATASTROS G
             where G.ESTADO = R.VAL_MINIMO
               and G.COD_PERSONA = P_COD_PERSONA);
   exception
      when no_data_found then
        --Asignar valor En Blanco cuando no se encuentre registros en Documentos de Catastros
        V_VAL_MAXIMO := 6;
  when others then
       NULL;
  end;
  ---Recuperar el estado al cual pertenece el valor minimo obtenido
  if nvl(V_VAL_MAXIMO,6) is not null then
     select R.VAL_MINIMO
       into V_ESTADO
       from BA_COD_REFERENCIAS R
      where r.dominio = 'CAT_EST_DOCUMENTO'
        and R.VAL_MAXIMO = nvl(V_VAL_MAXIMO,6);
  end if;
  return V_ESTADO;
exception
  when others then
    NULL;
end;
/


CREATE OR REPLACE FUNCTION IT.FUG_OBT_COD_GRUPO
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN NUMBER IS

v_cod_gru_economico ge_gru_economicos.cod_gru_economico%type;
Begin
    --Obtiene Grupo Economico de la Persona--
    select x.cod_gru_economico
      into V_COD_GRU_ECONOMICO
      from ge_clientes x
     where x.cod_persona = p_cod_persona
       and x.cod_gru_economico is not null;
    return v_cod_gru_economico;
Exception
       when no_data_found then
           return null;
       when others then
            raise_application_error(-20000,'Error en FUG_OBT_COD_GRUPO: '||sqlerrm);
End;
/


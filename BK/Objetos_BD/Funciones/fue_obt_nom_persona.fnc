CREATE OR REPLACE FUNCTION IT.FUE_OBT_NOM_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS

V_NOM_COMPLETO BA_PERSONAS.NOM_COMPLETO%TYPE;
Begin
    --Obtiene el Nombre completo de la persona
    if p_cod_persona is not null then
        select nom_completo
        into v_nom_completo
        from ba_personas
        where cod_persona = p_cod_persona;
    end if;
    return v_nom_completo;

    exception
       when no_data_found then
           return('Persona no registrada en el Sistema');
End;
/


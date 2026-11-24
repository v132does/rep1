CREATE OR REPLACE FUNCTION IT.FUE_OBT_NRO_DOC_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS

V_NRO_DOCUMENTO BA_PERSONAS.NRO_DOCUMENTO%TYPE;
Begin
    --Obtiene el nro de documento de la persona
    select nro_documento
    into v_nro_documento
    from ba_personas
    where cod_persona = p_cod_persona;

    return v_nro_documento;

    exception
       when no_data_found then
           return('Persona no registrada en el Sistema');
End;
/


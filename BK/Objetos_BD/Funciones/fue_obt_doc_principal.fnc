CREATE OR REPLACE FUNCTION IT.FUE_OBT_DOC_PRINCIPAL
 (P_COD_PERSONA IN VARCHAR2
 )
 RETURN VARCHAR
 IS

v_tip_documento ba_personas.cod_tip_documento%TYPE;
Begin
    --Obtiene el documento principal de la persona
    select cod_tip_documento
      into v_tip_documento
      from ba_personas
     where cod_persona = p_cod_persona;
    return v_tip_documento;
exception
   when no_data_found then
   return('Persona sin documento registrado');
End;
/


CREATE OR REPLACE FUNCTION IT.FUE_OBT_TIP_DOC_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
 RETURN NUMBER
 IS
  v_cod_tip_documento ba_tip_documentos.cod_tip_documento%type;
BEGIN
    select cod_tip_documento
     into v_cod_tip_documento
     from ba_personas
    where cod_persona = P_COD_PERSONA;
return v_cod_tip_documento;
    exception
       when no_data_found then
         return null;
END;
/


CREATE OR REPLACE FUNCTION IT.FUE_VAL_CUIL
 (P_NRO_DOCUMENTO IN ba_personas.NRO_DOCUMENTO%TYPE
 ,p_DOC_PRINCIPAL IN ba_personas.NRO_DOCUMENTO%TYPE
 )
 RETURN BOOLEAN
 IS
v_val_defecto varchar2(100);
BEGIN
 -- los últimos 8 dígitos anteriores al dígito verificador deben coincidir con el dni de la persona
  if fue_val_es_numerico(p_nro_documento) = fue_val_es_numerico(p_doc_principal) then
     if p_doc_principal <> substr(p_nro_documento,3,8) then
       raise_application_error(-20000,'Nro. de CUIL no contiene al Nro. de Documento de la persona');
     end if;
  end if;
  return true;
END;
/


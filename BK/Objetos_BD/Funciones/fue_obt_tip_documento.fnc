CREATE OR REPLACE FUNCTION IT.FUE_OBT_TIP_DOCUMENTO
 (P_TIPO IN VARCHAR2)
 RETURN VARCHAR2
 IS
  v_cod_tip_documento ba_tip_documentos.cod_tip_documento%type;
BEGIN
    select cod_tip_documento
     into v_cod_tip_documento
     from ba_tip_documentos
    where abreviatura = P_TIPO;
return v_cod_tip_documento;
    exception
       when no_data_found then
           return('Referencia  no registrada en el Sistema');
END;
/


CREATE OR REPLACE FUNCTION IT.fue_obt_tip_doc_abreviatura ( p_cod_tip_documento IN ba_tip_documentos.cod_tip_documento%type )
RETURN varchar2
IS
  v_abreviatura ba_tip_documentos.abreviatura%type := NULL;
BEGIN
    select abreviatura
      into v_abreviatura
      from ba_tip_documentos b
     where b.cod_tip_documento = p_cod_tip_documento
       and b.estado = 'A';
    return v_abreviatura;
EXCEPTION
  when no_data_found then
 /* fmolinas DYDMR-797
 raise_application_error(-20001, 'Tipo de Documento Inexistente  ' || p_cod_tip_documento);*/
 return(null);
  when others then
     raise_application_error(-20001, 'Error en FUE_OBT_TIP_DOC_ABREVIATURA. Tipo Documento - ' || p_cod_tip_documento || ' : ' || sqlerrm);
END fue_obt_tip_doc_abreviatura;
/


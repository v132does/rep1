CREATE OR REPLACE FUNCTION IT.fug_val_con_uni_per(p_cod_persona ba_personas.cod_persona%TYPE)
  RETURN varchar2 IS
  --
  v_tie_firmado varchar2(1) := 'N';

BEGIN
  BEGIN
    SELECT 'S'
      INTO v_tie_firmado
      FROM ba_per_ima_documentos a
     WHERE a.cod_persona = p_cod_persona
       AND a.cod_tip_documento = 64
       AND a.est_doc = 'A';
  EXCEPTION
    WHEN no_data_found THEN
      v_tie_firmado := 'N';
    WHEN too_many_rows THEN
      v_tie_firmado := 'S';
    WHEN OTHERS THEN
      v_tie_firmado := 'N';
  END;
  RETURN nvl(v_tie_firmado, 'N');
EXCEPTION
  WHEN no_data_found THEN
    raise_application_error(-20000,
                            'Error al validar el Contrato Unico de la persona ' ||
                            p_cod_persona);
  WHEN OTHERS THEN
    raise_application_error(-20001,
                            'Error en la funcion fug_val_con_uni_per ' ||
                            SQLERRM);
END;
/


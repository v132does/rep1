CREATE OR REPLACE FUNCTION IT.fut_obt_doc_bancard
(  p_cod_persona     ba_personas.cod_persona%TYPE,
   p_tip_doc_bancard ta_tar_cuentas_tmp.tip_documento%TYPE
) RETURN VARCHAR2 IS
   v_tip_documento ba_per_documentos.cod_tip_documento%TYPE;
   v_nro_documento ta_tar_cuentas_tmp.nro_documento%TYPE;
BEGIN
   BEGIN
      v_tip_documento := fue_obt_val_max_refcodes('TIP_DOC_BANCARD', p_tip_doc_bancard);
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   BEGIN
      SELECT nro_documento
        INTO v_nro_documento
        FROM ba_per_documentos
       WHERE cod_tip_documento = v_tip_documento
         AND cod_persona = p_cod_persona;
   EXCEPTION
      WHEN OTHERS THEN
         v_nro_documento := NULL;
   END;
   ---
   RETURN v_nro_documento;
END;
/


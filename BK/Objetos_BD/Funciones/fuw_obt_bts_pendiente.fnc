CREATE OR REPLACE FUNCTION IT.fuw_obt_bts_pendiente(p_nro_documento IN NUMBER, p_tipo IN VARCHAR2) RETURN VARCHAR2 IS
   v_retorno VARCHAR2(1) := 'N';
BEGIN
   IF p_tipo = 'P' THEN -- mov. de empresa
      SELECT 'S'
        INTO v_retorno
        FROM bw_mov_bts t
       WHERE t.estado = 'P'
         AND t.nro_doc_pendiente = p_nro_documento;
   ELSE
      SELECT 'S'
        INTO v_retorno
        FROM bw_mov_bts t
       WHERE t.estado = 'P'
         AND t.nro_documento = p_nro_documento;
   END IF;
   RETURN v_retorno;
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'N';
END;
/


CREATE OR REPLACE FUNCTION IT.fuw_obt_tip_pendiente(p_nro_documento IN bw_mov_pendientes.nro_documento%TYPE)
  RETURN VARCHAR2 IS
  v_cod_tip_mensaje bw_mov_pendientes.cod_tip_mensaje%TYPE;
BEGIN
  SELECT p.cod_tip_mensaje
    INTO v_cod_tip_mensaje
    FROM bw_mov_pendientes p
   WHERE p.nro_documento = p_nro_documento;
  RETURN v_cod_tip_mensaje;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/


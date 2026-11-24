CREATE OR REPLACE FUNCTION IT.fuw_obt_per_autorizacion(p_nro_documento IN bw_autorizaciones.nro_documento%TYPE,
                                                    p_accion        IN bw_autorizaciones.accion%TYPE) 
                                                    RETURN VARCHAR2 IS
  v_cod_persona ba_personas.cod_persona%TYPE;
BEGIN
   SELECT cod_persona
     INTO v_cod_persona
     FROM bw_autorizaciones
    WHERE nro_documento = p_nro_documento
      AND accion = p_accion
      AND rownum = 1;
   RETURN v_cod_persona;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/


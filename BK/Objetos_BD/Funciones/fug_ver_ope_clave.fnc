CREATE OR REPLACE FUNCTION IT.fug_ver_ope_clave
(
   p_cod_persona       IN ba_personas.cod_persona%TYPE,
   p_cod_per_vinculada IN ba_personas.cod_persona%TYPE,
	 p_tip_clave         IN bw_ope_claves.tip_clave%TYPE
) RETURN BOOLEAN IS
   v_existe VARCHAR2(1) := 'N';
BEGIN	
   IF p_cod_per_vinculada IS NULL THEN
      SELECT 'S'
        INTO v_existe
        FROM bw_ope_claves
       WHERE cod_persona = p_cod_persona
         AND cod_per_vinculada IS NULL
				 AND tip_clave = p_tip_clave;
   ELSE
      SELECT 'S'
        INTO v_existe
        FROM bw_ope_claves
       WHERE cod_persona = p_cod_persona
         AND cod_per_vinculada = p_cod_per_vinculada
				 AND tip_clave = p_tip_clave;
   END IF;
   IF v_existe = 'N' THEN
      RETURN FALSE;
   ELSIF v_existe = 'S' THEN
      RETURN TRUE;
   END IF;
EXCEPTION
   WHEN no_data_found THEN
      RETURN FALSE;
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en FUG_VER_OPE_CLAVE. ' || SQLERRM);
END;
/


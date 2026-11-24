CREATE OR REPLACE FUNCTION IT.fue_obt_onb_dat_adicional(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                                        p_parametro   IN ge_cta_dat_adicionales.parametro%TYPE)

 RETURN VARCHAR2 IS
  v_existe        varchar2(1) := 'N';
BEGIN
  BEGIN
    SELECT 'S'
      INTO v_existe
      FROM ba_per_dat_adicionales
     WHERE cod_persona = p_cod_persona
       AND parametro = p_parametro;
  EXCEPTION
    WHEN no_data_found THEN
      v_existe := 'N';
  END;

   RETURN v_existe;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;

END;
/


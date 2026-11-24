CREATE OR REPLACE FUNCTION IT.fug_obt_des_submodalidad
(
   p_cod_modulo        IN ge_modalidades.cod_modulo%TYPE,
   p_cod_modalidad     IN ge_modalidades.cod_modalidad%TYPE,
   p_cod_sub_modalidad IN ge_sub_modalidades.cod_sub_modalidad%TYPE
) RETURN VARCHAR2 IS
   v_descripcion ge_sub_modalidades.descripcion%TYPE;
BEGIN
   SELECT descripcion
     INTO v_descripcion
     FROM ge_sub_modalidades
    WHERE cod_modulo = p_cod_modulo
      AND cod_modalidad = p_cod_modalidad
      AND cod_sub_modalidad = p_cod_sub_modalidad;
   RETURN v_descripcion;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20000,
                              'La Sub-Modalidad ' || to_char(p_cod_sub_modalidad) ||' de la Modalidad ' || to_char(p_cod_modalidad) || ' no existe.');
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'Error en fug_obt_des_submodalidad. Sub-Modalidad: ' || to_char(p_cod_sub_modalidad) || SQLERRM);
END;
/


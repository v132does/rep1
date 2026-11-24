CREATE OR REPLACE FUNCTION IT.fug_obt_tip_modalidad
(  p_cod_modulo    ge_modalidades.cod_modulo%TYPE DEFAULT NULL,
   p_cod_modalidad ge_modalidades.cod_modalidad%TYPE
) RETURN VARCHAR2 IS
   v_tipo ge_modalidades.tipo%TYPE;
BEGIN
   SELECT tipo
     INTO v_tipo
     FROM ge_modalidades t
    WHERE t.cod_modulo = NVL(p_cod_modulo,t.cod_modulo)
      AND t.cod_modalidad = p_cod_modalidad;
   RETURN v_tipo;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20000, 'Modalidad ' || p_cod_modalidad || ' no definida.');
   WHEN too_many_rows THEN
      raise_application_error(-20000, 'Mas de una Modalidad ' || p_cod_modalidad || ' definida.');
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'Al Obt tipo para Modalidad ' || p_cod_modalidad || '. ' || SQLERRM);
END;
/


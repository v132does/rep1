CREATE OR REPLACE FUNCTION IT.fug_obt_des_bco_swift(p_cod_swift ge_bancos.cod_swift%TYPE) RETURN VARCHAR2 IS
   v_descripcion ge_bancos.descripcion%TYPE;
BEGIN
   SELECT descripcion
     INTO v_descripcion
     FROM ge_bancos
    WHERE nvl(cod_swift, 'p') = nvl(p_cod_swift, 'x');
   RETURN v_descripcion;
EXCEPTION
   WHEN no_data_found THEN
      RETURN NULL;
END;
/


CREATE OR REPLACE FUNCTION IT.fug_obt_des_tasa(p_cod_tasa IN NUMBER) RETURN VARCHAR2 IS
   v_retorno ge_tasas.descripcion%TYPE;
BEGIN
   SELECT descripcion 
     INTO v_retorno 
     FROM ge_tasas 
    WHERE cod_tasa = p_cod_tasa;
   RETURN v_retorno;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
/


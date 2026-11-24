CREATE OR REPLACE FUNCTION IT.fug_obt_per_bco_central RETURN VARCHAR2 IS
    v_cod_persona ge_bancos.cod_persona%TYPE;
BEGIN
   SELECT cod_persona
     INTO v_cod_persona
     FROM ge_bancos
    WHERE cod_banco = 1;
   RETURN v_cod_persona;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20000, 'Banco no registrado.');
   WHEN too_many_rows THEN
      raise_application_error(-20000, 'Banco Duplicado.');
END;
/


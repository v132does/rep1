CREATE OR REPLACE FUNCTION IT.fug_obt_bcp_entidad(p_sigla IN ge_bancos.sigla%TYPE) RETURN VARCHAR2 IS
   v_cod_banco ge_bancos.cod_bco_central%TYPE;
BEGIN
   SELECT a.cod_bco_central INTO v_cod_banco FROM ge_bancos a WHERE a.sigla = p_sigla;
   RETURN v_cod_banco;
EXCEPTION
   WHEN no_data_found THEN
      RETURN v_cod_banco;
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'en fug_obt_bcp_entidad. ' || SQLERRM);
      END IF;
END;
/


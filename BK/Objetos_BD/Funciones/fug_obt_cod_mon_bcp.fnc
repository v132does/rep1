CREATE OR REPLACE FUNCTION IT.fug_obt_cod_mon_bcp(p_cod_moneda VARCHAR2) RETURN NUMBER IS
   v_cod_mon_bcp ba_monedas.cod_mon_bco_central%TYPE;
BEGIN
   SELECT cod_mon_bco_central
     INTO v_cod_mon_bcp
     FROM ba_monedas
    WHERE cod_moneda = p_cod_moneda;
   RETURN v_cod_mon_bcp;
EXCEPTION
   WHEN no_data_found THEN
      RETURN('Código de Moneda no registrada en BA_MONEDAS.');
END;
/


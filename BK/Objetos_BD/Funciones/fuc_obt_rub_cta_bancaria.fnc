CREATE OR REPLACE FUNCTION IT.FUC_OBT_RUB_CTA_BANCARIA(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS

   v_cod_rubro cb_rubros.cod_rubro%TYPE;
BEGIN

   SELECT cod_rubro INTO v_cod_rubro FROM cc_cta_bancarias WHERE nro_cuenta = p_nro_cuenta;

   RETURN v_cod_rubro;
EXCEPTION
   WHEN no_data_found THEN
      raise_application_error(-20000, 'Rubro de la Cuenta Bancaria Inexistente');
   WHEN too_many_rows THEN
      raise_application_error(-20000, 'Más de un Rubro Definido');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Obt.Rubro Cuenta Bancaria. ' || SQLERRM);
END;
/


create or replace function it.FUG_OBT_TASA_IVA(p_mto_exento in cb_lib_ventas_det.mto_exento%TYPE,
                                               p_mto_grav_5 in cb_lib_ventas_det.mto_gravado_5%TYPE,
                                               p_mto_grav_10 in cb_lib_ventas_det.mto_gravado_10%TYPE) return NUMBER IS
v_tasa_iva number(2) := 0;
--Función que devuelve el código de la moneda según la norma ISO 4027
BEGIN
  IF p_mto_exento > 0 THEN
    v_tasa_iva := 0;
  ELSIF p_mto_grav_5 > 0 then
    v_tasa_iva := 5;
  ELSIF p_mto_grav_10 > 0 then
    v_tasa_iva := 10;
  END IF;

  RETURN v_tasa_iva;

END;
/


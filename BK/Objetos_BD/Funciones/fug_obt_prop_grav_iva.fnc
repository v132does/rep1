create or replace function it.FUG_OBT_PROP_GRAV_IVA(p_mto_exento in cb_lib_ventas_det.mto_exento%TYPE,
                                                    p_mto_grav_5 in cb_lib_ventas_det.mto_gravado_5%TYPE,
                                                    p_mto_grav_10 in cb_lib_ventas_det.mto_gravado_10%TYPE) return NUMBER IS
v_prop_iva number(3) := 0;
--Función que devuelve la proporción gravada del IVA
BEGIN
  IF p_mto_exento > 0 THEN
    v_prop_iva := 0;
  ELSE
    IF p_mto_grav_5 > 0 OR p_mto_grav_10 > 0 THEN
      v_prop_iva := 100;
    END IF;
  END IF;

  RETURN v_prop_iva;

END;
/


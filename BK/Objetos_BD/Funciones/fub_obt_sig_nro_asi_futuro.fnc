CREATE OR REPLACE FUNCTION IT.fub_obt_sig_nro_asi_futuro
(
   p_cod_oficina ba_oficinas.cod_oficina%TYPE,
   p_fecha       DATE
) RETURN NUMBER IS
   v_sig_nro_asi_futuro cb_asi_futuros_det.nro_asiento%TYPE;
BEGIN
   SELECT nvl(MAX(nro_asiento), 0)
     INTO v_sig_nro_asi_futuro
     FROM cb_asi_futuros_det
    WHERE cod_oficina = p_cod_oficina
      AND fecha = p_fecha;

   RETURN nvl(v_sig_nro_asi_futuro, 0) + 1;
END;
/


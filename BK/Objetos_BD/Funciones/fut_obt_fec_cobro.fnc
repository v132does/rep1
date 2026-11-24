CREATE OR REPLACE FUNCTION IT.fut_obt_fec_cobro
(  p_nro_cuenta   ge_cuentas.nro_cuenta%TYPE,
   p_fec_vto_pago DATE
) RETURN DATE IS
   v_fec_anterior DATE;
   v_fec_cobro     DATE;
BEGIN
   BEGIN
      SELECT (SELECT MAX(x.fec_vto_pago)
                 FROM ta_sal_cierres x
                WHERE x.fec_cierre < t.fec_cierre
                  AND x.nro_cuenta = t.nro_cuenta)
        INTO v_fec_anterior
        FROM ta_sal_cierres t
       WHERE t.nro_cuenta = p_nro_cuenta
         AND t.fec_vto_pago = p_fec_vto_pago;
   EXCEPTION
      WHEN no_data_found THEN
         v_fec_anterior := (p_fec_vto_pago + 30);
      WHEN OTHERS THEN
         v_fec_anterior := NULL;
   END;

   BEGIN
      SELECT max(a.fec_valor)
        INTO v_fec_cobro
        FROM ta_cobros a
       WHERE a.fec_valor > v_fec_anterior
         AND a.fec_valor <= p_fec_vto_pago
         AND a.nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN no_data_found THEN
         v_fec_cobro := NULL;
      WHEN OTHERS THEN
         v_fec_cobro := NULL;
   END;

   RETURN v_fec_cobro;

END;
/


CREATE OR REPLACE FUNCTION IT.fup_obt_mto_cobrado(p_nro_cuenta pr_cobros.nro_cuenta%TYPE,
                                               p_nro_cuota pr_cobros.nro_cuota%TYPE, 
                                               p_fecha pr_cobros.fecha%TYPE)
RETURN NUMBER IS
v_tot_cobrado NUMBER;
-- Retorna el monto pagado por cuota, hasta p_fecha.
BEGIN
  SELECT SUM(
         (nvl(a.mto_capital,0) +
          nvl(a.mto_interes,0) +
          nvl(a.mto_int_documentado,0) +
         (nvl(a.mto_int_moratorio,0) +
          nvl(a.mto_int_mor_interes,0) +
          nvl(a.mto_int_mor_adelantado,0)) +
          nvl(a.mto_int_punitorio,0) +
          nvl(a.mto_impuesto,0) +
         (nvl(a.mto_cargo,0) ))) mto_cobro
    INTO v_tot_cobrado
    FROM pr_cobros a
   WHERE a.nro_cuenta = p_nro_cuenta
     AND a.nro_cuota  = p_nro_cuota
     AND a.fecha     <= p_fecha;
  RETURN v_tot_cobrado;
EXCEPTION
  WHEN no_data_found THEN
  RETURN 0;
  WHEN OTHERS THEN
  RETURN -1;
END;
/


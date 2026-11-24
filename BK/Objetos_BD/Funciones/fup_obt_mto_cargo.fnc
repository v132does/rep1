CREATE OR REPLACE FUNCTION IT.fup_obt_mto_cargo(p_nro_solicitud   IN pr_sol_cargos.nro_solicitud%TYPE,
                                                p_cod_transaccion IN pr_sol_cargos.cod_transaccion%TYPE)
  RETURN NUMBER IS
  v_mto_cargo pr_sol_cargos.monto%TYPE;
BEGIN
  IF p_cod_transaccion IS NOT NULL THEN
    SELECT monto
      INTO v_mto_cargo
      FROM pr_sol_cargos
     WHERE nro_solicitud = p_nro_solicitud
       AND cod_transaccion = p_cod_transaccion;
    RETURN nvl(v_mto_cargo, 0);
  ELSE
    SELECT nvl(SUM(nvl(mto_mon_prestamo, 0)), 0)
      INTO v_mto_cargo
      FROM pr_sol_cargos c, pr_solicitudes p
     WHERE c.nro_solicitud = p_nro_solicitud
       AND c.nro_solicitud = p.nro_solicitud
       AND NOT EXISTS (SELECT t.cod_transaccion
              FROM ge_transacciones t
             WHERE t.cod_transaccion = c.cod_transaccion
               AND t.cod_modulo = p.cod_modulo
               AND t.cod_modalidad = p.cod_modalidad
               AND t.afecta = 'G'); -- G= Afecta Seguro  
    RETURN nvl(v_mto_cargo, 0);
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    return 0;
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'Error al devolver resultado' || SQLERRM);
END fup_obt_mto_cargo;
/


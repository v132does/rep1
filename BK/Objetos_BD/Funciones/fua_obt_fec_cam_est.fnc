CREATE OR REPLACE FUNCTION IT.fua_obt_fec_cam_est(p_nro_cuenta   ah_cta_vistas.nro_cuenta%TYPE,
                                                  p_est_anterior ge_cuentas_nov.est_anterior%TYPE,
                                                  p_est_actual   ge_cuentas_nov.est_actual%TYPE)
  RETURN DATE IS
  v_fec_cam_est date;
BEGIN
  IF p_est_actual = 'D' THEN
    BEGIN
      select max(t.fecha)
        into v_fec_cam_est
        from ge_cuentas_nov t
       where t.nro_cuenta = p_nro_cuenta
         and t.est_anterior = p_est_anterior
         and t.est_actual = p_est_actual
         and t.nro_detalle = fug_obt_pardinamico('COD_CAUSA_BLOQ_DEBITO');
    EXCEPTION
      WHEN no_data_found THEN
        v_fec_cam_est := null;
      WHEN too_many_rows THEN
        select max(t.fecha)
          into v_fec_cam_est
          from ge_cuentas_nov t
         where t.nro_cuenta = p_nro_cuenta
           and t.est_anterior = p_est_anterior
           and t.est_actual = p_est_actual
           and t.nro_detalle = fug_obt_pardinamico('COD_CAUSA_BLOQ_DEBITO')
           and rownum = 1;
    END;
  ELSE
    BEGIN
      select max(t.fecha)
        into v_fec_cam_est
        from ge_cuentas_nov t
       where t.nro_cuenta = p_nro_cuenta
         and t.est_anterior = p_est_anterior
         and t.est_actual = p_est_actual;
    EXCEPTION
      WHEN no_data_found THEN
        v_fec_cam_est := null;
      WHEN too_many_rows THEN
        select max(t.fecha)
          into v_fec_cam_est
          from ge_cuentas_nov t
         where t.nro_cuenta = p_nro_cuenta
           and t.est_anterior = p_est_anterior
           and t.est_actual = p_est_actual
           and rownum = 1;
    END;
  END IF;
  return v_fec_cam_est;
EXCEPTION
  WHEN no_data_found THEN
    raise_application_error(-20000,
                            'Error al obtener fecha de cambio de estado');
  WHEN OTHERS THEN
    raise_application_error(-20001,
                            'Error en la funcion fua_obt_fec_cam_esta. ' ||
                            SQLERRM);
END;
/


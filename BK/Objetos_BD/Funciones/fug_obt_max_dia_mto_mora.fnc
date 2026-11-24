CREATE OR REPLACE FUNCTION IT.fug_obt_max_dia_mto_mora
(
   p_cod_persona IN ba_personas.cod_persona%TYPE,
   p_dato        IN VARCHAR2 DEFAULT 'D',
   p_meses       IN NUMBER DEFAULT NULL
) RETURN NUMBER IS
   --(p_dato): Valores posibles 'D' Dias Atraso y 'M' Monto Mora
   --(p_meses): Representa la cantidad de meses a restar de la fecha actual
   v_max_atraso pr_cta_prestamos.max_atraso%TYPE;
   v_mto_mora   pr_cta_prestamos.mto_mora%TYPE;
   v_fecha      DATE;
BEGIN

   SELECT add_months(trunc(pag_cal.fu_obt_fec_actual(1)), -p_meses) INTO v_fecha FROM dual;

   IF p_dato = 'D' THEN
   
      SELECT nvl(MAX(x.dia_atraso), 0)
        INTO v_max_atraso
        FROM ge_cla_operaciones_his x
       WHERE x.cod_persona = p_cod_persona
         AND x.fecha >= nvl(v_fecha, x.fecha)
         AND x.nro_cuenta IN (SELECT a.nro_cuenta
                                FROM pr_cta_prestamos a, ge_cta_clientes b, ge_est_cuentas c
                               WHERE a.nro_cuenta = b.nro_cuenta
                                 AND b.relacion = 'P'
                                 AND a.cod_modulo = c.cod_modulo
                                 AND a.cod_modalidad = c.cod_modalidad
                                 AND a.estado = c.estado
                                 AND c.activo = 'S'
                                 AND b.cod_persona = p_cod_persona
                              UNION ALL
                              SELECT a.nro_cuenta
                                FROM cc_cta_corrientes a, ge_cta_clientes b, ge_est_cuentas c
                               WHERE a.nro_cuenta = b.nro_cuenta
                                 AND b.relacion = 'P'
                                 AND a.cod_modulo = c.cod_modulo
                                 AND a.cod_modalidad = c.cod_modalidad
                                 AND a.estado = c.estado
                                 AND c.activo = 'S'
                                 AND b.cod_persona = p_cod_persona
                              UNION ALL
                              SELECT a.nro_cuenta
                                FROM ta_cta_tarjetas a, ge_cta_clientes b, ge_est_cuentas c
                               WHERE a.nro_cuenta = b.nro_cuenta
                                 AND b.relacion = 'P'
                                 AND a.cod_modulo = c.cod_modulo
                                 AND a.cod_modalidad = c.cod_modalidad
                                 AND a.estado = c.estado
                                 AND c.activo = 'S'
                                 AND b.cod_persona = p_cod_persona);
   
      RETURN v_max_atraso;
   
   ELSIF p_dato = 'M' THEN
   
      SELECT nvl(MAX(x.tot_deu_real), 0)
        INTO v_mto_mora
        FROM ge_cla_operaciones_his x
       WHERE x.cod_persona = p_cod_persona
         AND x.fecha >= nvl(v_fecha, x.fecha)
         AND x.nro_cuenta IN (SELECT a.nro_cuenta
                                FROM pr_cta_prestamos a, ge_cta_clientes b, ge_est_cuentas c
                               WHERE a.nro_cuenta = b.nro_cuenta
                                 AND b.relacion = 'P'
                                 AND a.cod_modulo = c.cod_modulo
                                 AND a.cod_modalidad = c.cod_modalidad
                                 AND a.estado = c.estado
                                 AND c.activo = 'S'
                                 AND b.cod_persona = p_cod_persona
                              UNION ALL
                              SELECT a.nro_cuenta
                                FROM cc_cta_corrientes a, ge_cta_clientes b, ge_est_cuentas c
                               WHERE a.nro_cuenta = b.nro_cuenta
                                 AND b.relacion = 'P'
                                 AND a.cod_modulo = c.cod_modulo
                                 AND a.cod_modalidad = c.cod_modalidad
                                 AND a.estado = c.estado
                                 AND c.activo = 'S'
                                 AND b.cod_persona = p_cod_persona
                              UNION ALL
                              SELECT a.nro_cuenta
                                FROM ta_cta_tarjetas a, ge_cta_clientes b, ge_est_cuentas c
                               WHERE a.nro_cuenta = b.nro_cuenta
                                 AND b.relacion = 'P'
                                 AND a.cod_modulo = c.cod_modulo
                                 AND a.cod_modalidad = c.cod_modalidad
                                 AND a.estado = c.estado
                                 AND c.activo = 'S'
                                 AND b.cod_persona = p_cod_persona);
   
      RETURN v_mto_mora;
   
   END IF;

   RETURN - 1;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Al Obtener Máx. día de Incumplimiento ó Monto Máx. Incumplido del Cliente. ' ||SQLERRM);
END;
/


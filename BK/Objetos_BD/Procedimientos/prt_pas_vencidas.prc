CREATE OR REPLACE PROCEDURE IT.PRT_PAS_VENCIDAS IS
   v_fcdehoy       ge_movimientos.fecha%type;

  cursor tarjetas is
    --Global
    SELECT t1.nro_cuenta,
           t2.nro_tarjeta
      FROM ta_mov_especiales_tmp t, ta_cta_tarjetas t1, ta_tarjetas t2, ge_modalidades g
     WHERE t.nro_cuenta = t1.nro_cuenta
       AND t1.nro_cuenta = t2.nro_cuenta
       AND t1.cod_modulo = g.cod_modulo
       AND t1.cod_modalidad = g.cod_modalidad
       AND upper(g.descripcion) like '%MASTERCARD%'
       AND t2.vigente = 'S'
       AND t2.rel_tarjeta = '0'
       AND t.ref_proceso IS NULL --aun no fueron procesadas
       AND NOT EXISTS(SELECT 1 FROM ov_cta_vencidas v WHERE v.nro_cta_origen = t1.nro_cuenta)
    UNION
    --BANCARD
    SELECT t1.nro_cuenta,
           t2.nro_tarjeta
      FROM ta_mov_especiales_tmp t, ta_cta_tarjetas t1, ta_tarjetas t2, ge_modalidades g
     WHERE t.nro_cuenta = t1.nro_cuenta
       AND t1.nro_cuenta = t2.nro_cuenta
       AND t1.cod_modulo = g.cod_modulo
       AND t1.cod_modalidad = g.cod_modalidad
       AND upper(g.descripcion) not like '%MASTERCARD%'
       --AND t2.vigente = 'S'
       AND t2.rel_tarjeta = '0'
       AND t.ref_proceso IS NULL --aun no fueron procesadas
       AND NOT EXISTS(SELECT 1 FROM ov_cta_vencidas v WHERE v.nro_cta_origen = t1.nro_cuenta);
       
BEGIN
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
  v_fcdehoy            := pag_cal.fu_obt_fec_actual(5);
  FOR r IN tarjetas LOOP
    --actualizar la tabla tmp
    BEGIN
      UPDATE ta_mov_especiales_tmp
         SET nro_tarjeta     = r.nro_tarjeta,
             dig_verificador = 5,
             fec_movimiento  = v_fcdehoy,
             des_movimiento  = 'PASE A VENCIDA',
             tip_afectacion  = 0,
             tip_movimiento  = 'DB',
             financia        = 'S',
             fec_proceso     = v_fcdehoy,
             cod_usuario     = 'TARJETAS',
             cod_origen      = 1
       WHERE nro_cuenta = r.nro_cuenta;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20004,'Error al actualizar ta_mov_especiales_tmp. Cuenta:' ||r.nro_cuenta||' '|| SQLERRM);
    END;
  END LOOP;
  --llama al proceso de pase a vencidas (genera movimientos y ov_cta_vencida)
  it.prv_pas_ven_tarjetas;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20009, 'Error en PRT_PAS_VENCIDAS-' || SQLERRM);
END;
/

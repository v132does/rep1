CREATE OR REPLACE PROCEDURE IT.prt_gen_dat_cobros(p_cod_procesadora IN VARCHAR2) IS
  /*Definicion de variables utilizadas*/
  v_lugar         VARCHAR2(100) := 'Iniciando';
  v_fec_actual    ge_calendarios.fec_actual%TYPE;
  v_hora          ge_movimientos.hora%TYPE;
  v_cod_modulo    ge_modalidades.cod_modulo%TYPE;
  v_cod_modalidad ge_modalidades.cod_modalidad%TYPE;
  v_cod_banco     ta_env_cuentas.cod_banco%TYPE;
  v_cod_sucursal  ta_env_cuentas.cod_sucursal%TYPE;
  v_cod_oficina   ge_par_generales.cod_ofi_matriz%TYPE;
  --v_fec_envio -> c_fec_envio modificado el 24/12/2014 - DYDMR-1478
  c_fec_envio     ta_cobros.fec_proceso%type := pag_cal.FU_OBT_FEC_ACTUAL(5); 
  v_fec_valor     ta_cobros.fec_valor%type;
  v_existe        varchar2(1) := 'N';
  v_fec_cierre    ta_cal_cierres.fec_cierre%type;
  v_ret           NUMBER(3) := 0;

  /*Cursor de Pagos de Tarjetas*/
  CURSOR c_cobros IS
    SELECT t.*,
           t.rowid registro,
           a.cod_modulo,
           a.cod_modalidad,
           a.cod_tip_cierre
      FROM ta_cobros t, ta_cta_tarjetas a
     WHERE t.estado IN ('P', 'C')
       AND t.est_envio = 'P' --pendiente de enviar--
       AND a.nro_cuenta = t.nro_cuenta
       AND EXISTS
     (SELECT 1
              FROM ta_tipos b
             WHERE a.cod_modulo = b.cod_modulo
               AND a.cod_modalidad = b.cod_modalidad
               AND a.afinidad = b.afinidad
                  --AND nvl(a.sub_afinidad, 'ZZ') = nvl(b.sub_afinidad, 'ZZ')
               AND b.cod_ent_procesadora = p_cod_procesadora)
       AND NOT EXISTS 
       (SELECT 1 --13/05/2016 DYDMR-3805 GC: Se agrega condicion de que no existan pagos pendientes via WS del día, si sigue pendiente al día siguiente si estaría enviando.
              FROM ge_par_web_servicios g
             WHERE substr(g.dat_enviados,12,16) = t.nro_tarjeta
               AND g.estado = 'P'
               AND g.fecha = pag_cal.FU_OBT_FEC_ACTUAL(5));

  PROCEDURE lp_car_pardinamicos IS
  BEGIN
    /*Carga todos los parametros dinamicos necesarios*/
    v_lugar := 'lp_car_pardinamicos';
    ---0. limpio los valores a leer ------------------------------------
    v_cod_banco    := NULL;
    v_cod_sucursal := NULL;
    v_cod_banco    := fug_obt_parentes(p_cod_procesadora, 'COD_BANCO');
  
    SELECT cod_sucursal
      INTO v_cod_sucursal
      FROM ta_sucursales
     WHERE cod_ent_procesadora = p_cod_procesadora
       AND cod_oficina = v_cod_oficina
       AND rownum = 1;
    ---------------------------------------------------------------------
  END lp_car_pardinamicos;

  PROCEDURE pr_obt_fec_cierre(p_cod_ent_procesadora IN ta_cal_cierres.cod_ent_procesadora%type,
                              p_cod_modulo          IN ta_cal_cierres.cod_modulo%type,
                              p_cod_modalidad       IN ta_cal_cierres.cod_modalidad%type,
                              p_cod_tip_cierre      IN ta_cal_cierres.cod_tip_cierre%type,
                              p_fec_valor           IN ta_env_cobros.fec_valor%type,
                              p_fec_envio           IN ta_env_cobros.fec_envio%type,
                              p_existe              OUT VARCHAR2,
                              p_fec_cierre          OUT ta_cal_cierres.fec_cierre%type) AS
    -- Obtiene, si existe, la fecha de cierre entre la fecha valor y
    -- la fecha de envío.
  BEGIN
    SELECT c.fec_cierre
      INTO p_fec_cierre
      FROM ta_cal_cierres c
     WHERE c.cod_ent_procesadora = p_cod_ent_procesadora
       AND c.cod_modulo = p_cod_modulo
       AND c.cod_modalidad = p_cod_modalidad
       AND c.cod_tip_cierre = p_cod_tip_cierre
       and c.fec_cierre =
           (SELECT max(c.fec_cierre)
              FROM ta_cal_cierres c
             WHERE c.cod_ent_procesadora = p_cod_ent_procesadora
               AND c.cod_modulo = p_cod_modulo
               AND c.cod_modalidad = p_cod_modalidad
               AND c.cod_tip_cierre = p_cod_tip_cierre
               AND c.fec_cierre BETWEEN p_fec_valor AND p_fec_envio)
       AND c.fec_cierre BETWEEN p_fec_valor AND p_fec_envio
       --se agrega a pedido de Francisco Villalba -- Nov-2014 -- Fecha de envío <> a Fecha de cierre.
       AND c.fec_cierre <> p_fec_envio
       AND ROWNUM = 1;
  
    p_existe := 'S';
  
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_existe := 'N';
  END pr_obt_fec_cierre;
  --
BEGIN
  --inicio del prg principal--
  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  END;

  --Obtener la oficina matriz de la entidad
  SELECT cod_ofi_matriz INTO v_cod_oficina FROM ge_par_generales;

  --variables a utilizar--
  v_fec_actual := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
  v_hora       := pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS'));

  --borrar datos anteriores si hubiere--
  v_lugar := 'borrar ta_env_cobros';
  DELETE FROM ta_env_cobros WHERE cod_ent_procesadora = p_cod_procesadora;

  --cursor principal cuentas--
  v_lugar := 'cursor principal de cobros';
  FOR r_cue IN c_cobros LOOP
    v_cod_modulo    := r_cue.cod_modulo;
    v_cod_modalidad := r_cue.cod_modalidad;
    lp_car_pardinamicos;
    --02/06/2014--
    --Verificar si las fechas de envío y de valor son distintas--
    -- Si el tipo de cierre es 1, 2, 3, 4 ó 5--
    v_fec_valor := r_cue.fec_valor;
    --v_fec_envio := r_cue.fec_proceso;

    IF c_fec_envio <> r_cue.fec_valor AND --r_cue.fec_proceso -> c_fec_envio modificado el 24/12/2014 - DYDMR-1478
       r_cue.cod_tip_cierre IN (1, 2, 3, 4, 5) THEN
      -- Procedimiento verificar la fecha de cierre y cambio de la fecha valor en --
      -- caso que, entre la fecha valor y fecha envío, exista una fecha de cierre. --
      pr_obt_fec_cierre(p_cod_procesadora,
                        r_cue.cod_modulo,
                        r_cue.cod_modalidad,
                        r_cue.cod_tip_cierre,
                        v_fec_valor,
                        c_fec_envio, --v_fec_envío - modificado el 24/12/2014 - DYDMR-1478
                        v_existe,
                        v_fec_cierre);
      IF v_existe = 'S' then
        -- Fecha valor se modifica al día siguiente a la fecha de cierre.
        v_fec_valor := v_fec_cierre + 1;
      END IF;
    END IF;
    --02/06/2014--
  
    INSERT INTO ta_env_cobros
      (cod_ent_procesadora,
       cod_banco,
       cod_sucursal,
       nro_cuenta,
       nro_tarjeta,
       monto,
       fec_valor,
       fec_envio,
       hor_envio,
       tip_pago,
       estado,
       reg_cobro,
       cod_moneda,
       descripcion)
    VALUES
      (p_cod_procesadora,
       v_cod_banco,
       v_cod_sucursal,
       r_cue.nro_cuenta,
       r_cue.nro_tarjeta,
       r_cue.monto,
       --decode(r_cue.fec_proceso,r_cue.fec_valor,r_cue.fec_proceso,r_cue.fec_valor), --09/06/2014 egc
       decode(c_fec_envio, v_fec_valor, c_fec_envio, v_fec_valor),
       v_fec_actual,
       NULL,
       --decode(r_cue.fec_proceso,r_cue.fec_valor,'N','V'),'G', 
       --decode(r_cue.fec_valor, v_fec_actual, 'N', 'V'), --09/06/2014 egc
       decode(v_fec_valor, v_fec_actual, 'N', 'V'),
       'G',
       r_cue.registro,
       pag_gen.fu_obt_mon_local /* Valor por Defecto 'GS',*/,
       'SU PAGO, GRACIAS'
       /* Comentario por Defecto*/);
  
    --Notificacion de pago en Bach de tarjetas de credito - Notificaciones Fase 3
    v_ret := paw_not.fu_tar_pag_batch(r_cue.nro_tarjeta,r_cue.monto);
    
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000, SQLERRM || ' / ' || v_lugar || '-' || v_cod_modalidad);
END;
/


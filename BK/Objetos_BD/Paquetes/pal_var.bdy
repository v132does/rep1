CREATE OR REPLACE PACKAGE BODY IT.PAL_VAR IS

  -- Constantes
  c_mod_cambio     CONSTANT ge_movimientos.cod_modulo%TYPE := 7;
  c_mad_compra     CONSTANT ge_movimientos.cod_mad_padre%TYPE := 71;
  c_mad_venta      CONSTANT ge_movimientos.cod_mad_padre%TYPE := 72;
  c_mad_arbitraje  CONSTANT ge_movimientos.cod_mad_padre%TYPE := 73;

  -- Excepciones
  e_error EXCEPTION;
                           
  /*
   * Objetivo : Obtener totales por segmento a ser utilizados
   *           para el calculo de totales de posicion de cambio.
   * Segmentos considerados:
   *              Posicion inicial
   *              Posicion Spot
   *              Posicion Futura
   *              Home Banking
   *              Operaciones Pendientes
   *              Devengados: activos y pasivos
   *              Operaciones automaticas de compra y venta de divisas:
   *                     Previsiones, Proveedores, Cobro de comisiones,
   *                     Impuestos, Libranza en dolares, Transferencias.
   * Fecha creacion : 10/07/2013
   */
  PROCEDURE pr_obt_dif_pos_cambio (
      p_sec IN lc_pos_cambios_tmp.secuencia%TYPE,
      p_fecha IN DATE,
      p_oficina lc_pos_cambios_tmp.cod_oficina%TYPE DEFAULT NULL
  ) IS
      -- Constantes de movimientos
      c_est_normal     CONSTANT VARCHAR2(1) := 'N';
      c_est_pend_aut   CONSTANT VARCHAR2(1) := 'X';
      c_est_pend_caja  CONSTANT VARCHAR2(1) := 'J';
      c_est_pend_camb  CONSTANT VARCHAR2(1) := 'P';
      c_est_otro       CONSTANT VARCHAR2(1) := 'H';  -- no existe en tabla ba_cod_referencias
      c_est_ingresado  CONSTANT VARCHAR2(1) := 'I'; -- de operaciones futuras.
      -- Constantes caja
      c_mod_caja       CONSTANT ge_transacciones.cod_modulo%TYPE := 9;
      c_mad_caja       CONSTANT ge_transacciones.cod_modalidad%TYPE := 91;
      c_tra_compra     CONSTANT ge_transacciones.cod_transaccion%TYPE := 503;
      c_tra_venta      CONSTANT ge_transacciones.cod_transaccion%TYPE := 602;
      c_tra_padre      CONSTANT ge_transacciones.cod_transaccion%TYPE := 388;

      -- Otras constantes
      --c_tra_deveng CONSTANT ge_transacciones.cod_transaccion%TYPE := 901;
      --c_tra_auto CONSTANT ge_transacciones.cod_transaccion%TYPE := 942;
      c_tpos_efectivo  CONSTANT lc_sal_posiciones.tip_posicion%TYPE := 'E';
      c_tpos_nefectivo CONSTANT lc_sal_posiciones.tip_posicion%TYPE := 'O';

      -- Variables
      v_sec            lc_pos_cambios_tmp.secuencia%TYPE;
      v_segmento       VARCHAR2(20);
      v_fec_actual     DATE;
      v_modifica       BOOLEAN;
      v_mensaje        VARCHAR2(2000);
      v_lugar          VARCHAR2(2000);
      v_mon_local      ge_cotizaciones.cod_moneda%TYPE;

      -- Cursores
      -- Posicion Inicial
      CURSOR cur_pos_ini IS
          SELECT cod_moneda,
                 cod_ofi_cambio cod_oficina,
                 SUM(DECODE(tip_posicion, c_tpos_efectivo, mto_efe_compra,
                                          c_tpos_nefectivo, mto_nef_compra)) compra,
                 SUM(DECODE(tip_posicion, c_tpos_efectivo, mto_efe_venta,
                                          c_tpos_nefectivo, mto_nef_venta)) venta,
                 SUM(DECODE(tip_posicion, c_tpos_efectivo, mto_efe_compra * cot_efectivo,
                                          c_tpos_nefectivo, mto_nef_compra * cot_no_efectivo)) compra_gs,
                 SUM(DECODE(tip_posicion, c_tpos_efectivo, mto_efe_venta * cot_efectivo,
                                          c_tpos_nefectivo, mto_nef_venta * cot_no_efectivo)) venta_gs
          FROM lc_sal_posiciones
          WHERE (cod_ofi_cambio = p_oficina OR p_oficina IS NULL)
          GROUP BY cod_ofi_cambio, cod_moneda;

      -- Posicion SPOT
      CURSOR cur_mov IS
          SELECT  mo.cod_moneda,
                  f.cod_ofi_cambio cod_oficina,
                  NVL(SUM(DECODE(o.cod_mad_hijo, c_mad_compra, mo.monto)), 0) compra,
                  NVL(SUM(DECODE(o.cod_mad_hijo, c_mad_venta, mo.monto)), 0) venta,
                  NVL(SUM(DECODE(o.cod_mad_hijo, c_mad_compra, mo.monto * mo.cotizacion)), 0) compra_gs,
                  NVL(SUM(DECODE(o.cod_mad_hijo, c_mad_venta, mo.monto * mo.cotizacion)), 0) venta_gs
              FROM ba_oficinas f,
                   lc_tip_operaciones o,
                   ge_movimientos mo
              WHERE (f.cod_ofi_cambio = p_oficina OR p_oficina IS NULL)
              AND f.cod_oficina = mo.cod_oficina
              AND o.afe_posicion <> 'N'
              AND o.cod_tip_operacion = mo.cod_tip_ope_cambio
              AND mo.reversado = 'N'
              AND mo.estado IN (c_est_normal, c_est_pend_caja, c_est_otro, c_est_pend_camb, c_est_pend_aut)
              AND mo.cod_mod_padre = c_mod_cambio
              --AND mo.cod_mad_padre IN (c_mad_compra, c_mad_venta, c_mad_arbitraje)
              and ( (cod_mad_padre in (c_mad_compra, c_mad_venta) and nro_secuencia in (1)) 
                  or (cod_mad_padre = c_mad_arbitraje ) )
              --AND mo.nro_secuencia in (1,2)
              AND mo.fecha = v_fec_actual
              GROUP BY f.cod_ofi_cambio, mo.cod_moneda;

      -- Home Banking
      CURSOR cur_home_bank IS
          SELECT cab.cod_moneda,
                 f.cod_ofi_cambio cod_oficina,
                 NVL(SUM( DECODE(cab.cod_transaccion, c_tra_compra, cab.monto) ),0 ) compra,
                 NVL(SUM( DECODE(cab.cod_transaccion, c_tra_venta, cab.monto) ),0 ) venta,
                 NVL(SUM( DECODE(cab.cod_transaccion, c_tra_compra, cab.monto * cab.cotizacion) ),0 ) compra_gs,
                 NVL(SUM( DECODE(cab.cod_transaccion, c_tra_venta, cab.monto * cab.cotizacion) ),0 ) venta_gs
              FROM ba_oficinas f,
                   ge_movimientos cab
              WHERE (f.cod_ofi_cambio = p_oficina OR p_oficina IS NULL)
              AND f.cod_oficina = cab.cod_oficina
              AND EXISTS (
                  SELECT *
                      FROM ge_movimientos det
                      WHERE det.cod_moneda <> cab.cod_moneda
                      AND det.nro_secuencia <> cab.nro_secuencia
                      AND det.cod_usuario = cab.cod_usuario
                      AND det.hora = cab.hora
                      AND det.fecha = cab.fecha
                      AND det.cod_tra_padre = cab.cod_tra_padre -- DYDMR-2073  -- DYDMR-3777/05-2016
              )
              AND cab.cod_mod_padre = c_mod_caja
              AND cab.cod_mad_padre = c_mad_caja
              AND cab.reversado = 'N'
              AND cab.cod_tra_padre = c_tra_padre
              AND cab.cod_moneda <> v_mon_local
              AND cab.estado IN (c_est_normal, c_est_pend_caja, c_est_otro, c_est_pend_camb, c_est_pend_aut)
              AND cab.fecha = v_fec_actual
              GROUP BY f.cod_ofi_cambio, cab.cod_moneda;

      -- Operaciones pendientes--
      CURSOR cur_pend IS
          select x.cod_moneda, x.cod_oficina, 
                 sum(nvl(x.compra,0)) compra,
                 sum(nvl(x.venta,0)) venta,
                 sum(nvl(x.compra_gs,0)) compra_gs,
                 sum(nvl(x.venta_gs,0)) venta_gs
          from 
          (
          SELECT  ope.cod_moneda,
                  f.cod_ofi_cambio cod_oficina,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_compra,ope.monto)),0) compra,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_venta,ope.monto)),0) venta,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_compra,ope.monto * ope.cotizacion)),0) compra_gs,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_venta,ope.monto * ope.cotizacion)),0) venta_gs
              FROM ba_oficinas f,
                   lc_tip_operaciones o,
                   lc_ope_pendientes ope
              WHERE (f.cod_ofi_cambio = p_oficina OR p_oficina IS NULL)
              AND f.cod_oficina = ope.cod_oficina
              AND ope.liquidado = 'N'
              AND ope.cod_tip_operacion = o.cod_tip_operacion
              AND o.afe_posicion <> 'N'
              AND o.cod_mad_hijo IN (c_mad_compra, c_mad_venta)
              AND o.cod_modulo = c_mod_cambio
              GROUP BY f.cod_ofi_cambio, ope.cod_moneda
           union all
		   ----Proyecto DDARBDIG-1-Arbitraje Digital----
           SELECT  ope.cod_moneda,
                  f.cod_ofi_cambio cod_oficina,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_compra,ope.monto)),0) compra,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_venta,ope.monto)),0) venta,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_compra,ope.monto * ope.cotizacion)),0) compra_gs,
                  NVL(SUM(DECODE(o.cod_mad_hijo,c_mad_venta,ope.monto * ope.cotizacion)),0) venta_gs
              FROM ba_oficinas f,
                   lc_tip_operaciones o,
                   lc_ope_pen_cambios ope
              WHERE (f.cod_ofi_cambio = p_oficina OR p_oficina IS NULL)
              AND f.cod_oficina = ope.cod_oficina
              AND ope.liquidado = 'N'
              AND ope.cod_tip_operacion = o.cod_tip_operacion
              AND o.afe_posicion <> 'N'
              AND o.cod_mad_hijo IN (c_mad_compra, c_mad_venta)
              AND o.cod_modulo = c_mod_cambio
              GROUP BY f.cod_ofi_cambio, ope.cod_moneda) x
            group by x.cod_moneda, x.cod_oficina;

      -- Operaciones futuras
      CURSOR cur_fut_acum IS
          SELECT  o.cod_moneda,
                  f.cod_ofi_cambio cod_oficina,
                  NVL(SUM(DECODE(o.cod_mad_transaccion,c_mad_compra,o.monto)),0) compra,
                  NVL(SUM(DECODE(o.cod_mad_transaccion,c_mad_venta,o.monto)),0) venta,
                  NVL(SUM(DECODE(o.cod_mad_transaccion,c_mad_compra,o.monto * fug_obt_cotizacion(o.cod_moneda, v_fec_actual))),0) compra_gs,
                  NVL(SUM(DECODE(o.cod_mad_transaccion,c_mad_venta,o.monto * fug_obt_cotizacion(o.cod_moneda, v_fec_actual))),0) venta_gs
                  --NVL(SUM(DECODE(o.cod_mad_transaccion,c_mad_compra,o.monto * o.cotizacion)),0) compra_gs,
                  --NVL(SUM(DECODE(o.cod_mad_transaccion,c_mad_venta,o.monto * o.cotizacion)),0) venta_gs
              FROM ba_oficinas f,
                   lc_ope_futuras o
              WHERE (f.cod_ofi_cambio = p_oficina OR p_oficina IS NULL)
              AND f.cod_oficina = o.cod_oficina
              AND o.estado IN (c_est_normal)
              AND o.fec_operacion <= v_fec_actual -- DYDMR-4091 - RABP - 06/2016
              GROUP BY f.cod_ofi_cambio, o.cod_moneda;

  /*
      -- Operaciones de devengado
      CURSOR cur_deveng IS
          SELECT  m.cod_moneda,
                  o.cod_ofi_cambio cod_oficina,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_compra, m.monto, 0)), 0) compra,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_venta, m.monto, 0)), 0) venta,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_compra, m.monto * m.cotizacion, 0)), 0) compra_gs,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_venta, m.monto * m.cotizacion, 0)), 0) venta_gs
              FROM  ba_oficinas o,
                    ge_movimientos m
              WHERE o.cod_oficina = m.cod_oficina
              AND m.reversado = 'N'
              AND m.estado = 'N'
              AND m.cod_tra_padre = c_tra_deveng
              AND m.cod_transaccion = c_tra_deveng
              AND m.cod_mod_padre = c_mod_cambio
              AND m.cod_modulo = c_mod_cambio
              AND m.cod_moneda <> v_mon_local
              AND m.nro_secuencia = 1
              AND m.fecha = v_fec_actual
              GROUP BY o.cod_ofi_cambio, m.cod_moneda;
  */
  /*
      -- Operaciones automaticas de compra y venta contable de cambios
      CURSOR cur_auto IS
          SELECT  o.cod_ofi_cambio cod_oficina,
                  m.cod_moneda,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_compra, m.monto, 0)), 0) compra,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_venta, m.monto, 0)), 0) venta,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_compra, m.monto * m.cotizacion, 0)), 0) compra_gs,
                  NVL(SUM(DECODE(m.cod_modalidad, c_mad_venta, m.monto * m.cotizacion, 0)), 0) venta_gs
              FROM ba_oficinas o,
                   ge_movimientos m
              WHERE o.cod_oficina = m.cod_oficina
              AND m.reversado = 'N'
              AND m.estado = 'N'
              AND m.cod_tra_padre = c_tra_auto
              AND m.cod_transaccion = c_tra_auto
              AND m.cod_mod_padre = c_mod_cambio
              AND m.cod_modulo = c_mod_cambio
              AND m.cod_moneda <> v_mon_local
              AND m.nro_secuencia = 1
              AND m.fecha = v_fec_actual
              GROUP BY o.cod_ofi_cambio, m.cod_moneda;
  */
      -- Actualiza totales
      PROCEDURE lp_insertar_pos (
          p_segmento IN lc_pos_cambios_tmp.segmento%TYPE,
          p_moneda IN lc_pos_cambios_tmp.cod_moneda%TYPE,
          p_oficina IN lc_pos_cambios_tmp.cod_oficina%TYPE,
          p_compra IN lc_pos_cambios_tmp.compra%TYPE,
          p_venta IN lc_pos_cambios_tmp.venta%TYPE,
          p_compra_gs IN lc_pos_cambios_tmp.compra_gs%TYPE,
          p_venta_gs IN lc_pos_cambios_tmp.venta_gs%TYPE
      ) IS
      BEGIN
          v_lugar := 'INSERTAR_POS - SEGMENTO '||p_segmento;
          v_mensaje := NULL;
          v_modifica := FALSE;

          BEGIN
              INSERT INTO lc_pos_cambios_tmp (
                  secuencia,
                  segmento,
                  cod_moneda,
                  cod_oficina,
                  compra,
                  venta,
                  compra_gs,
                  venta_gs
              ) VALUES (
                  v_sec,
                  p_segmento,
                  p_moneda,
                  p_oficina,
                  NVL(p_compra, 0),
                  NVL(p_venta, 0),
                  ROUND(NVL(p_compra_gs, 0), 0),
                  ROUND(NVL(p_venta_gs, 0), 0)
              );
          EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                   v_modifica := TRUE;
          END;

          IF v_modifica THEN
              UPDATE lc_pos_cambios_tmp
              SET compra = NVL(compra, 0) + NVL(p_compra, 0),
                  venta = NVL(venta, 0) + NVL(p_venta, 0),
                  compra_gs = NVL(compra_gs, 0) + ROUND(NVL(p_compra_gs, 0), 0),
                  venta_gs = NVL(venta_gs, 0) + ROUND(NVL(p_venta_gs, 0), 0)
              WHERE segmento = p_segmento
              AND cod_oficina = p_oficina
              AND cod_moneda = p_moneda
              AND secuencia = v_sec;

              IF SQL%ROWCOUNT = 0 THEN
                  v_lugar := v_lugar||': No se realizo la actualizacion de totales.';
                  RAISE e_error;
              END IF;
          END IF;
      END;
  BEGIN
      v_lugar := 'INICIO';
      v_fec_actual := p_fecha;
      IF v_fec_actual IS NULL THEN
          v_fec_actual := pae_cnf.fu_obt_fec_actual(c_mod_cambio);
      END IF;
      v_fec_actual := TRUNC(v_fec_actual);

      v_sec := p_sec;
      IF v_sec IS NULL THEN
          v_lugar := 'El parametro SECUENCIA debe tener valor.';
          RAISE e_error;
      END IF;

      v_mon_local := pag_gen.FU_OBT_MON_LOCAL;
      IF v_mon_local IS NULL THEN
          v_lugar := 'La moneda local no esta configurada en el sistema.';
          RAISE e_error;
      END IF;

      -- Limpia tabla temporal.
      v_lugar := 'DELETE LC_POS_CAMBIOS_TMP';
      DELETE lc_pos_cambios_tmp;
       --WHERE secuencia = v_sec;
       
      v_lugar := 'INSERT DATOS';
      -- Posicion inicial
      v_segmento := 'INI';
      FOR c IN cur_pos_ini  LOOP
          lp_insertar_pos (
              v_segmento,
              c.cod_moneda,
              c.cod_oficina,
              c.compra,
              c.venta,
              c.compra_gs,
              c.venta_gs
          );
      END LOOP;

      -- Posicion SPOT
      v_segmento := 'CON';
      FOR c IN cur_mov  LOOP
          lp_insertar_pos (
              v_segmento,
              c.cod_moneda,
              c.cod_oficina,
              c.compra,
              c.venta,
              c.compra_gs,
              c.venta_gs
          );
      END LOOP;
      
      -- DYDMR-3777 - RABP - 05/2016
      IF nvl(PAE_CNF.G_PROGRAMA,'x') = 'LMCONPO1' THEN
        -- Home Banking
        v_segmento := 'HBK';
        FOR c IN cur_home_bank  LOOP
            lp_insertar_pos (
                v_segmento,
                c.cod_moneda,
                c.cod_oficina,
                c.compra,
                c.venta,
                c.compra_gs,
                c.venta_gs
            );
        END LOOP;
      END IF;

      -- Pendiente
      v_segmento := 'PEN';
      FOR c IN cur_pend LOOP
          lp_insertar_pos (
              v_segmento,
              c.cod_moneda,
              c.cod_oficina,
              c.compra,
              c.venta,
              c.compra_gs,
              c.venta_gs
          );
      END LOOP;

      -- Operacion futura acumulada a v_fec_actual
      v_segmento := 'FWT';
      FOR c IN cur_fut_acum  LOOP
          lp_insertar_pos (
              v_segmento,
              c.cod_moneda,
              c.cod_oficina,
              c.compra,
              c.venta,
              c.compra_gs,
              c.venta_gs
          );
      END LOOP;

      /*
         04/11/2013: Se elimina del calculo porque el cierre
         genera registros en la tabla de movimientos
         correspondientes a las operaciones de
         devengado y compras automaticas, por lo cual
         no es necesario incluir estas consultas.

      --   Operaciones de devengado: activos y pasivos
      v_segmento := 'DEV';
      FOR c IN cur_deveng  LOOP
          lp_insertar_pos (
              v_segmento,
              c.cod_moneda,
              c.cod_oficina,
              c.compra,
              c.venta,
              c.compra_gs,
              c.venta_gs
          );
      END LOOP;

      -- Operaciones automaticas de compra y venta de divisas:
      --  Previsiones, Proveedores, Cobro de comisiones,
      --  Impuestos, Libranza en dolares,  Transferencias.
      v_segmento := 'AUT';
      FOR c IN cur_auto  LOOP
          lp_insertar_pos (
              v_segmento,
              c.cod_moneda,
              c.cod_oficina,
              c.compra,
              c.venta,
              c.compra_gs,
              c.venta_gs
          );
      END LOOP;
  */

  EXCEPTION
      WHEN e_error THEN
           RAISE_APPLICATION_ERROR(-20000, v_lugar);
      WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20000, 'PR_OBT_DIF_POS_CAMBIO - '||
                                   v_lugar||' '||SQLERRM);
  END pr_obt_dif_pos_cambio;

  /*
   * Objetivo: Calcular la Variacion de Tipo de Cambio.
   *           Calcula la posicion de cambio para
   *           todas las oficinas y para todas las monedas,
   *           incluyendo la operacion de la moneda en curso de registrar.
   * Fecha creacion : 10/07/2013
   */
  PROCEDURE pr_cal_pos_cambio(
      p_fecha IN DATE DEFAULT NULL,
      p_oficina IN lc_tot_pos_cambios.cod_oficina%TYPE DEFAULT NULL,
      p_moneda IN lc_tot_pos_cambios.cod_moneda%TYPE DEFAULT NULL,
      p_monto IN lc_tot_pos_cambios.compra_spot_me%TYPE DEFAULT 0,
      p_cotizacion IN lc_tot_pos_cambios.cotizacion%TYPE DEFAULT 0,
      p_modalidad IN ge_movimientos.cod_mad_padre%TYPE DEFAULT NULL,
      p_segmento IN lc_pos_cambios_tmp.segmento%TYPE DEFAULT NULL,
      p_cod_error IN OUT NUMBER,
      p_mensaje IN OUT VARCHAR2
  ) IS
      -- Pragmas
      e_registro_bloqueado EXCEPTION;
      e_mensaje            EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_registro_bloqueado, -54);
      PRAGMA AUTONOMOUS_TRANSACTION;

      -- constantes
      c_dist_std_1         CONSTANT NUMBER(6,2) := 0.94; -- distribucion estandar.
      c_dist_std_2         CONSTANT NUMBER(6,2) := 0.06;
      c_volatil_default    CONSTANT lc_tot_pos_cambios.volatilidad%TYPE := 0;

      -- variables
      v_lugar              VARCHAR2(2000);
      v_duplica            BOOLEAN;
      v_fecha              DATE;
      v_sec                lc_pos_cambios_tmp.secuencia%TYPE;
      v_lim_factor         NUMBER;--(6,2);
      v_pos_ini_me         lc_tot_pos_cambios.pos_ini_me%TYPE;
      v_pos_ini_gs         lc_tot_pos_cambios.pos_ini_gs%TYPE;
      v_compra_pond        lc_tot_pos_cambios.compra_spot_pond%TYPE;
      v_venta_pond         lc_tot_pos_cambios.venta_spot_pond%TYPE;
      v_compra_spot_pond   lc_tot_pos_cambios.compra_spot_pond%TYPE;
      v_venta_spot_pond    lc_tot_pos_cambios.venta_spot_pond%TYPE;
      v_compra_fut_pond    lc_tot_pos_cambios.compra_spot_pond%TYPE;
      v_venta_fut_pond     lc_tot_pos_cambios.venta_spot_pond%TYPE;
      v_pos_neta           lc_tot_pos_cambios.pos_neta_me%TYPE;
      v_val_ini            lc_tot_pos_cambios.valuacion_ini%TYPE;
      v_val_spot           lc_tot_pos_cambios.valuacion_spot%TYPE;
      v_val_fut            lc_tot_pos_cambios.valuacion_fut%TYPE;
      v_val_neta           lc_tot_pos_cambios.valuacion_neta%TYPE;
      v_rend_tc            lc_tot_pos_cambios.rend_tc%TYPE;
      v_var                lc_tot_pos_cambios.valor_riesgo%TYPE;
      v_volatil_act        lc_tot_pos_cambios.volatilidad%TYPE;
      v_volatil_ant        lc_tot_pos_cambios.volatilidad%TYPE;
      v_cotiz_act          lc_tot_pos_cambios.cotizacion%TYPE;
      v_cotiz_ant          lc_tot_pos_cambios.cotizacion%TYPE;
      v_pos_spot           lc_tot_pos_cambios.compra_spot_me%TYPE;
      v_pos_fut            lc_tot_pos_cambios.compra_fut_me%TYPE;
      v_pos_ini_fut        lc_tot_pos_cambios.compra_fut_me%TYPE;
      v_uti_trad_compra    lc_tot_pos_cambios.utilidad_compra%TYPE;
      v_uti_trad_venta     lc_tot_pos_cambios.utilidad_venta%TYPE;
      v_compra_me          lc_tot_pos_cambios.compra_spot_me%TYPE;
      v_venta_me           lc_tot_pos_cambios.venta_spot_me%TYPE;
      v_pos_suspenso_me    lc_tot_pos_cambios.pos_suspenso_me%TYPE;
      v_lim_max_moneda     lc_tot_pos_cambios.pos_ini_me%TYPE;
      v_oficina            lc_tot_pos_cambios.cod_oficina%TYPE;
      -- Posicion Inicial
      CURSOR cur_pos_ini IS
          SELECT cod_oficina,
                 cod_moneda,
                 NVL(SUM(compra), 0) compra,
                 NVL(SUM(venta), 0) venta,
                 NVL(SUM(compra_gs), 0) compra_gs,
                 NVL(SUM(venta_gs), 0) venta_gs
            FROM lc_pos_cambios_tmp
           WHERE segmento = 'INI'
             AND secuencia = v_sec
           GROUP BY cod_oficina, cod_moneda;

      -- Posicion Spot
      CURSOR cur_pos_spot IS
          SELECT cod_moneda,
                 cod_oficina,
                 NVL(SUM(compra), 0) compra,
                 NVL(SUM(venta), 0) venta,
                 NVL(SUM(compra_gs), 0) compra_gs,
                 NVL(SUM(venta_gs), 0) venta_gs
            FROM lc_pos_cambios_tmp
           WHERE segmento NOT IN ('INI', 'FWT')
             AND secuencia = v_sec
           GROUP BY cod_oficina, cod_moneda;

      CURSOR cur_pos_fut IS
          SELECT cod_moneda,
                 cod_oficina,
                 NVL(SUM(compra), 0) compra,
                 NVL(SUM(venta), 0) venta,
                 NVL(SUM(compra_gs), 0) compra_gs,
                 NVL(SUM(venta_gs), 0) venta_gs
            FROM lc_pos_cambios_tmp
           WHERE segmento = 'FWT'
             AND secuencia = v_sec
           GROUP BY cod_oficina, cod_moneda;

      CURSOR cur_tot IS
          SELECT cod_oficina,
                 cod_moneda,
                 pos_ini_me,
                 pos_ini_gs,
                 compra_spot_me,
                 compra_spot_gs,
                 compra_fut_me,
                 compra_fut_gs,
                 venta_spot_me,
                 venta_spot_gs,
                 venta_fut_me,
                 venta_fut_gs
            FROM lc_tot_pos_cambios
           WHERE fecha = v_fecha
           ORDER BY cod_oficina, cod_moneda;

      -- Inserta operacion en curso
      PROCEDURE lp_insertar_ope_actual IS
          v_ofi_cambio lc_tot_pos_cambios.cod_oficina%TYPE;
      BEGIN
          v_lugar := 'VERIFICA PARAMETROS OPE_ACTUAL';
          IF p_modalidad IS NULL -- no corresponde a una operacion en curso
          OR p_moneda IS NULL THEN
              RETURN;
          END IF;

          IF p_oficina IS NULL THEN
              v_lugar := 'Parametro de oficina de operacion actual debe tener valor';
              RAISE e_mensaje;
          END IF;

          v_lugar := 'OBTIENE OFICINA CAMBIO';
          v_ofi_cambio := pal_cam.fu_obt_ofi_cambio(p_oficina);
          IF v_ofi_cambio IS NULL THEN
             v_lugar := 'No existe oficina de cambio para oficina '||p_oficina;
             RAISE e_mensaje;
          END IF;

          BEGIN
              v_duplica := FALSE;
              v_lugar := 'INSERTA_OPE_ACTUAL';
              INSERT INTO lc_pos_cambios_tmp (
                  secuencia,
                  segmento,
                  cod_moneda,
                  cod_oficina,
                  compra,
                  venta,
                  compra_gs,
                  venta_gs
              ) VALUES (
                  v_sec,
                  p_segmento,
                  p_moneda,
                  v_ofi_cambio,
                  DECODE(p_modalidad, c_mad_compra, p_monto, 0),
                  DECODE(p_modalidad, c_mad_venta, p_monto, 0),
                  DECODE(p_modalidad, c_mad_compra, p_monto * p_cotizacion, 0),
                  DECODE(p_modalidad, c_mad_venta, p_monto * p_cotizacion, 0)
              );
          EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                   v_duplica := TRUE;
          END;
          IF v_duplica THEN
              v_lugar := 'ACTUALIZA_OPE_ACTUAL';
              UPDATE lc_pos_cambios_tmp
                  SET compra  = compra
                              + DECODE(p_modalidad, c_mad_compra, p_monto, 0),
                      venta = venta
                            + DECODE(p_modalidad, c_mad_venta, p_monto, 0),
                      compra_gs = compra_gs
                                + DECODE(p_modalidad, c_mad_compra, p_monto * p_cotizacion, 0),
                      venta_gs = venta_gs
                               + DECODE(p_modalidad, c_mad_venta, p_monto * p_cotizacion, 0)
                  WHERE segmento = p_segmento
                  AND cod_oficina = v_ofi_cambio
                  AND cod_moneda = p_moneda
                  AND secuencia = v_sec;

              IF SQL%ROWCOUNT = 0 THEN
                  v_lugar := v_lugar||': No pudo actualizar registro';
                  RAISE e_mensaje;
              END IF;
          END IF;
      EXCEPTION
          WHEN e_mensaje THEN
              RAISE e_mensaje;
      END;

      -- Obtener cotizacion y volatilidad inicial
      -- Se busca el ultimo registro con fecha anterior a la actual.
      PROCEDURE lp_obt_volatil_ant (
          p_moneda IN lc_tot_pos_cambios.cod_moneda%TYPE,
          p_oficina IN lc_tot_pos_cambios.cod_oficina%TYPE
      ) IS
      BEGIN
          v_lugar := 'OBTENER VOLATILIDAD ANTERIOR';
          SELECT cotizacion,
                  volatilidad
              INTO v_cotiz_ant,
                   v_volatil_ant
              FROM lc_tot_pos_cambios a
              WHERE cod_oficina = p_oficina
              AND cod_moneda = p_moneda
              AND fecha = (
                  SELECT MAX(fecha)
                      FROM lc_tot_pos_cambios
                      WHERE cod_oficina = a.cod_oficina
                      AND cod_moneda = a.cod_moneda
                      AND fecha < v_fecha
              );
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              v_cotiz_ant := NULL;
              v_volatil_ant := NULL;
      END;

      -- Obtener cotizacion
      FUNCTION lf_obt_cotizacion (
          p_moneda IN ge_cotizaciones.cod_moneda%TYPE,
          p_fecha IN DATE
      ) RETURN ge_cotizaciones.val_conversion%TYPE IS
          v_cotiz ge_cotizaciones.val_conversion%TYPE;
      BEGIN
          v_lugar := 'OBTENER COTIZACION';
          v_cotiz := pag_gen.fu_obt_cotizacion(p_moneda, p_fecha);
          RETURN v_cotiz;
      END;
      -- Obtener Posicion en Suspenso
      FUNCTION lf_obt_pos_suspenso (
          p_moneda IN lc_tot_pos_suspenso.cod_moneda%TYPE
      ) return lc_tot_pos_suspenso.monto%TYPE IS
        v_monto lc_tot_pos_suspenso.monto%TYPE;
      BEGIN
          v_lugar := 'OBTENER POSICION EN SUSPENSO';
          SELECT monto
            INTO v_monto
            FROM lc_tot_pos_suspenso a
           WHERE cod_moneda = p_moneda
             -- De la fecha mas reciente para la moneda --
             AND fecha = ( select max(fecha) from lc_tot_pos_suspenso a where a.cod_moneda = p_moneda );
          return v_monto;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              RETURN NULL;
      END;
  BEGIN
      v_lugar := 'INICIO';
      p_cod_error := NULL;
      p_mensaje := NULL;

      v_fecha := p_fecha;
      IF v_fecha IS NULL THEN
          v_fecha := pae_cnf.fu_obt_fec_actual(c_mod_cambio);
      END IF;
      v_fecha := TRUNC(v_fecha);

      -- Obtener Factor que se utiliza para calcular el limite VaR
      BEGIN
          v_lim_factor := to_number(replace((nvl(fug_obt_pardinamico('LCA_LIM_VAR_FACTOR',7),0)),',','.'));
          IF v_lim_factor = 0 THEN
              RAISE NO_DATA_FOUND;
          END IF;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              v_lugar := 'Parametro dinamico LCA_LIM_VAR_FACTOR debe ser configurado';
              RAISE;
      END;

      -- Obtener secuencia
      v_lugar := 'OBTENER SECUENCIA';
      SELECT s_sec_limvar.nextval
        INTO v_sec
        FROM DUAL;

      -- Bloquea tabla de posicion de cambios
      v_lugar := 'LOCK TABLA LC_TOT_POS_CAMBIOS';
      LOCK TABLE LC_TOT_POS_CAMBIOS   
        IN EXCLUSIVE MODE
        NOWAIT;

      v_lugar := 'DELETE REGISTRO LC_TOT_POS_CAMBIOS';
      DELETE lc_tot_pos_cambios
       WHERE fecha = v_fecha;

      -- Llama a procedimiento
      v_lugar := 'CALCULA TOTALES';
      pr_obt_dif_pos_cambio(v_sec, v_fecha);

      -- Inserta operacion en curso en tabla temporal
      v_lugar := 'INSERTA OPERACION ACTUAL';
      lp_insertar_ope_actual;

      -- Posicion inicial
      v_lugar := 'ACTUALIZA POS INI';
      FOR c IN cur_pos_ini LOOP
          BEGIN
              v_pos_ini_me := c.compra  - c.venta;
              v_pos_ini_gs := c.compra_gs - c.venta_gs;
              v_duplica := FALSE;

              INSERT INTO lc_tot_pos_cambios (
                  cod_oficina,
                  cod_moneda,
                  fecha,
                  pos_ini_me,
                  pos_ini_gs
              ) VALUES (
                  c.cod_oficina,
                  c.cod_moneda,
                  v_fecha,
                  v_pos_ini_me,
                  v_pos_ini_gs
              );
          EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                  v_duplica := TRUE;
          END;

          IF v_duplica THEN
              UPDATE lc_tot_pos_cambios
                  SET pos_ini_me = v_pos_ini_me,
                      pos_ini_gs = v_pos_ini_gs
                  WHERE cod_moneda = c.cod_moneda
                  AND cod_oficina = c.cod_oficina
                  AND fecha = v_fecha;
              IF SQL%ROWCOUNT = 0 THEN
                  v_lugar := v_lugar||': No pudo actualizar registro';
                  RAISE e_mensaje;
              END IF;
          END IF;
      END LOOP;

      -- Posicion Spot
      v_lugar := 'ACTUALIZA POS SPOT ';
      FOR c IN cur_pos_spot LOOP
           BEGIN
              v_duplica := FALSE;
              INSERT INTO lc_tot_pos_cambios (
                  cod_oficina,
                  cod_moneda,
                  fecha,
                  compra_spot_me,
                  compra_spot_gs,
                  venta_spot_me,
                  venta_spot_gs
              ) VALUES (
                  c.cod_oficina,
                  c.cod_moneda,
                  v_fecha,
                  c.compra,
                  c.compra_gs,
                  c.venta,
                  c.venta_gs
              );
          EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                  v_duplica := TRUE;
          END;

          IF v_duplica THEN
              UPDATE lc_tot_pos_cambios
                 SET compra_spot_me = c.compra,
                     compra_spot_gs = c.compra_gs,
                     venta_spot_me = c.venta,
                     venta_spot_gs = c.venta_gs
               WHERE cod_moneda = c.cod_moneda
                 AND cod_oficina = c.cod_oficina
                 AND fecha = v_fecha;
              IF SQL%ROWCOUNT = 0 THEN
                  v_lugar := v_lugar||': No pudo actualizar registro';
                  RAISE e_mensaje;
              END IF;
          END IF;
      END LOOP;

      -- Posicion Futura
      v_lugar := 'ACTUALIZA POS FUT';
      FOR c IN cur_pos_fut LOOP
          BEGIN
              v_duplica := FALSE;
              INSERT INTO lc_tot_pos_cambios (
                  cod_oficina,
                  cod_moneda,
                  fecha,
                  compra_fut_me,
                  compra_fut_gs,
                  venta_fut_me,
                  venta_fut_gs
              ) VALUES (
                  c.cod_oficina,
                  c.cod_moneda,
                  v_fecha,
                  c.compra,
                  c.compra_gs,
                  c.venta,
                  c.venta_gs
              );
          EXCEPTION
              WHEN DUP_VAL_ON_INDEX  THEN
                  v_duplica := TRUE;
          END;

          IF v_duplica THEN
              UPDATE lc_tot_pos_cambios
                  SET compra_fut_me = c.compra,
                      compra_fut_gs = c.compra_gs,
                      venta_fut_me = c.venta,
                      venta_fut_gs = c.venta_gs
                  WHERE cod_moneda = c.cod_moneda
                  AND cod_oficina = c.cod_oficina
                  AND fecha = v_fecha;
              IF SQL%ROWCOUNT = 0 THEN
                  v_lugar := v_lugar||': No pudo actualizar registro';
                  RAISE e_mensaje;
              END IF;
          END IF;
      END LOOP;
      
      -- Calculo de formulas
      v_lugar := 'CALCULA FORMULAS';
      FOR c IN cur_tot LOOP
          lp_obt_volatil_ant(c.cod_moneda, c.cod_oficina);
          IF v_cotiz_ant IS NULL THEN
              v_cotiz_ant := lf_obt_cotizacion(c.cod_moneda, (v_fecha - 1));
          END IF;
          v_lugar := 'CALCULA FORMULAS';
          IF v_volatil_ant IS NULL THEN
              v_volatil_ant := c_volatil_default;
          END IF;
          v_cotiz_act := lf_obt_cotizacion(c.cod_moneda, v_fecha);
          v_lugar := 'CONTINUA CALCULA FORMULAS';
          
          -- Para el calculo de Posicion Neta utilizar la Posicion Futura Inicial --
          begin
          select nvl(sum(decode(cod_mad_padre, 71, monto, monto * -1)),0) total
            into v_pos_ini_fut
            from lc_movimientos_his
           where fecha = pag_cal.fu_obt_fec_ant_hab(v_fecha,c.cod_oficina,1)
             and cod_mod_padre = 7
             and cod_tra_padre = 189
             and nvl(monto, 0) > 0
             and cod_moneda = c.cod_moneda
             and cod_oficina = c.cod_oficina
           group by cod_moneda, cod_oficina;
          exception
            when others then
              v_pos_ini_fut := 0;
          end;
          
          v_pos_spot := NVL(c.compra_spot_me, 0) - NVL(c.venta_spot_me, 0);
          v_pos_fut := NVL(c.compra_fut_me, 0) - NVL(c.venta_fut_me, 0);
          v_pos_neta := NVL(c.pos_ini_me, 0) + v_pos_spot + v_pos_fut;       
          v_compra_me := NVL(c.compra_spot_me, 0) + NVL(c.compra_fut_me, 0);
          v_venta_me  := NVL(c.venta_spot_me, 0) + NVL(c.venta_fut_me, 0);

          --  Compra Promedio ponderado
          IF NVL(c.compra_spot_me, 0) = 0 THEN
              v_compra_spot_pond := ROUND( NVL(c.compra_spot_gs, 0),15);
          ELSE
              v_compra_spot_pond := ROUND( (NVL(c.compra_spot_gs, 0) / c.compra_spot_me),15);
          END IF;

          IF NVL(c.compra_fut_me, 0) = 0 THEN
              v_compra_fut_pond := ROUND( NVL(c.compra_fut_gs, 0),15);
          ELSE
              v_compra_fut_pond := ROUND( (NVL(c.compra_fut_gs, 0) / c.compra_fut_me),15);
          END IF;

          v_compra_pond := v_compra_spot_pond + v_compra_fut_pond;

          --  Venta Promedio ponderado
          IF NVL(c.venta_spot_me, 0) = 0 THEN
              v_venta_spot_pond := ROUND( NVL(c.venta_spot_gs, 0),15);
          ELSE
              v_venta_spot_pond := ROUND( (NVL(c.venta_spot_gs, 0) / c.venta_spot_me),15);
          END IF;

          IF NVL(c.venta_fut_me, 0) = 0 THEN
              v_venta_fut_pond := ROUND( NVL(c.venta_fut_gs, 0),15);
          ELSE
              v_venta_fut_pond := ROUND( (NVL(c.venta_fut_gs, 0) / c.venta_fut_me),15);
          END IF;

          v_venta_pond := v_venta_spot_pond + v_venta_fut_pond;

          -- Utilidad Trading
          -- DYDMR-3777 - RABP - 05/2016 
          v_uti_trad_compra := ROUND(((v_cotiz_act - v_compra_spot_pond) * NVL(c.compra_spot_me, 0)),2);
                            -- + (v_cotiz_act - v_compra_fut_pond) * NVL(c.compra_fut_me, 0)),2);
                                               
          v_uti_trad_venta := ROUND(((v_venta_spot_pond - v_cotiz_act) * NVL(c.venta_spot_me, 0)),2);
                            -- + (v_venta_fut_pond - v_cotiz_act) * NVL(c.venta_fut_me, 0)),2);

          -- Utilidad Valuacion
          v_val_ini := (v_cotiz_act - v_cotiz_ant) * NVL(c.pos_ini_me, 0);
          v_val_spot := (v_cotiz_act - v_cotiz_ant) * v_pos_spot;
          --v_val_fut := (v_cotiz_act - v_cotiz_ant) * v_pos_fut; 
          v_val_fut := (v_cotiz_act - v_cotiz_ant) * v_pos_ini_fut; -- DYDMR-3777 - RABP - 05/2016 
          v_val_neta := v_val_fut + v_val_ini;
          --
          v_rend_tc := LN(v_cotiz_act / v_cotiz_ant);
          v_volatil_act := SQRT((c_dist_std_1 * POWER(v_volatil_ant, 2)) + (c_dist_std_2 * POWER(v_rend_tc, 2)));
          --v_var := v_lim_factor * v_cotiz_act * v_volatil_act * ABS(v_pos_neta);

          -- Posicion en Suspenso
          v_pos_suspenso_me := nvl(lf_obt_pos_suspenso(c.cod_moneda),0);
          --v_pos_neta := v_pos_neta - nvl(v_pos_suspenso_me,0);
          --v_var := v_lim_factor * v_cotiz_act * v_volatil_act * ABS(v_pos_neta-nvl(v_pos_suspenso_me,0));
          v_var := v_lim_factor * v_cotiz_act * v_volatil_act * ABS(v_pos_neta + v_pos_suspenso_me);
          
          -- CNFLIMVAR-236 -- 
          -- Guardar el Limite de Valor de Riesgo. --
          v_lim_max_moneda := fug_obt_pardinamico('LCA_LIM_VAR_MAXIMO', 7, NULL, c.cod_moneda);

          v_lugar := 'ACTUALIZA TOTALES';
          UPDATE lc_tot_pos_cambios
              SET cotizacion = v_cotiz_act,
                  compra_spot_me = NVL(compra_spot_me, 0),
                  compra_spot_gs = NVL(compra_spot_gs, 0),
                  compra_fut_me = NVL(compra_fut_me, 0),
                  compra_fut_gs = NVL(compra_fut_gs, 0),
                  venta_spot_me = NVL(venta_spot_me, 0),
                  venta_spot_gs = NVL(venta_spot_gs, 0),
                  venta_fut_me = NVL(venta_fut_me, 0),
                  venta_fut_gs = NVL(venta_fut_gs, 0),
                  pos_spot_me = v_pos_spot,
                  pos_fut_me = v_pos_fut,
                  pos_neta_me = v_pos_neta,
                  compra_spot_pond = v_compra_spot_pond,
                  compra_fut_pond = v_compra_fut_pond,
                  venta_spot_pond = v_venta_spot_pond,
                  venta_fut_pond = v_venta_fut_pond,
                  utilidad_compra = v_uti_trad_compra,
                  utilidad_venta = v_uti_trad_venta,
                  valuacion_ini = v_val_ini,
                  valuacion_spot = v_val_spot,
                  valuacion_fut = v_val_fut,
                  valuacion_neta = v_val_neta,
                  rend_tc = v_rend_tc,
                  volatilidad = v_volatil_act,
                  valor_riesgo = v_var,
                  pos_suspenso_me =  v_pos_suspenso_me,
                  limite_var = v_lim_max_moneda 
              WHERE cod_oficina = c.cod_oficina
              AND cod_moneda = c.cod_moneda
              AND fecha = v_fecha;

          IF SQL%ROWCOUNT = 0 THEN
              v_lugar := v_lugar||': No pudo actualizar registro';
              RAISE e_mensaje;
          END IF;

      END LOOP;
      
      /*v_lugar := 'COMMIT';
      COMMIT;*/
      
      v_lugar := 'CALCULO VaR GLOBAL';
      -- Realizar el calculo del VaR Global (Canasto)
      v_oficina := to_number(nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),'1'));
      pr_cal_var_global(v_fecha,v_oficina, p_cod_error,p_mensaje);
      IF p_cod_error <> 0 THEN
          RETURN;
      END IF;
          
      /*v_lugar := 'BORRA TABLA TEMPORAL';
      DELETE lc_pos_cambios_tmp
          WHERE secuencia = v_sec;*/
      
      v_lugar := 'COMMIT';
      COMMIT;
          
      p_cod_error := 0;
      p_mensaje := NULL;
  EXCEPTION
      WHEN e_mensaje THEN
          ROLLBACK;
          p_cod_error := 1;
          p_mensaje := v_lugar;
      WHEN e_registro_bloqueado THEN
          ROLLBACK;
          p_cod_error := 10;
          p_mensaje := 'La posicion de cambios esta siendo actualizada'||
           '  por otro usuario, espere un momento e intentelo nuevamente.';
      WHEN OTHERS THEN
          ROLLBACK;
          p_cod_error := 99;
          p_mensaje := 'PAL_VAR.PR_CAL_POS_CAMBIO - '||v_lugar||': '||SQLERRM;
  END pr_cal_pos_cambio;

  /*
   * Objetivo: Controlar si por operacion de compra de divisas,
   *           supera el limite superior de riesgo, y por venta
   *           de divisas supera el limite inferior.
   * Fecha creacion : 24/07/2013
   */
  PROCEDURE pr_con_pos_cambio (
      p_usuario IN ge_aut_pedidos.cod_usuario%TYPE,
      p_oficina IN ge_movimientos.cod_oficina%TYPE,
      p_moneda IN ge_movimientos.cod_moneda%TYPE,
      p_monto IN ge_movimientos.monto%TYPE,
      p_cotizacion IN ge_movimientos.cotizacion%TYPE,
      p_tip_oper IN lc_tip_operaciones.descripcion%TYPE,
      p_modalidad IN ge_movimientos.cod_mad_padre%TYPE,
      p_segmento IN lc_pos_cambios_tmp.segmento%TYPE,
      p_fecha IN ge_movimientos.fecha%TYPE,
      p_hora IN ge_movimientos.hora%TYPE,
      p_home_bank IN VARCHAR2 DEFAULT 'N', -- S=Si, N=No
      p_confirma IN VARCHAR2, -- V=Valida, C=Confirma
      p_estado IN OUT ge_movimientos.estado%TYPE,
      p_cod_error IN OUT NUMBER,
      p_mensaje IN OUT VARCHAR2
  ) IS
      -- constantes
      c_est_pen_autoriz CONSTANT VARCHAR2(1) := 'X';  -- estado de tabla ge_movimientos

      -- variables
      v_lugar           VARCHAR2(2000);
      v_mensaje         VARCHAR2(2000);
      v_error           VARCHAR2(2000);
      v_fecha           DATE;
      v_mon_local       ge_movimientos.cod_moneda%TYPE;
      v_var_global      lc_tot_pos_cambios.valor_riesgo%TYPE;
      v_var_moneda      lc_tot_pos_cambios.valor_riesgo%TYPE;
      v_lim_max_moneda  lc_tot_pos_cambios.pos_ini_me%TYPE;
      v_lim_min_moneda  lc_tot_pos_cambios.pos_ini_me%TYPE;
      v_lim_max_global  lc_tot_pos_cambios.pos_ini_me%TYPE;
      v_lim_min_global  lc_tot_pos_cambios.pos_ini_me%TYPE;
      v_lim_mensaje     ge_par_dinamicos.val_parametro%TYPE;
      v_msg_mail        ge_par_dinamicos.val_parametro%TYPE;
      v_estado          ge_movimientos.estado%TYPE;
      v_lim_medicion    NUMBER(5,2);
      v_porc_global     NUMBER;
      v_porc_moneda     NUMBER;
      v_tipo_limite     VARCHAR2(20);
      v_msg_pendiente   VARCHAR2(500);
      v_activado        ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('LCA_LIM_VAR_ACT_AUTORIZACION',7),'N');
      v_var_hab_moneda  VARCHAR2(1);
      e_salir           EXCEPTION;
      v_cont            NUMBER := 0;
      v_date            DATE := NULL;
          
      CURSOR cur_email IS
          SELECT val_parametro
              FROM ge_par_dinamicos
              WHERE parametro LIKE 'LCA_LIM_VAR_EMAIL%';

      PROCEDURE lp_val_inicial IS
      BEGIN
          v_lugar := 'VALIDACION INICIAL';

          IF p_usuario IS NULL THEN
              v_error := 'Valor del parametro USUARIO no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_oficina IS NULL THEN
              v_error := 'Valor del parametro OFICINA no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_moneda IS NULL THEN
              v_error := 'Valor del parametro MONEDA no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_monto IS NULL THEN
              v_error := 'Valor del parametro MONTO no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_cotizacion IS NULL THEN
              v_error := 'Valor del parametro COTIZACION no puede ser nulo';
              RAISE e_error;
          END IF;

           IF p_tip_oper IS NULL THEN
              v_error := 'Valor del parametro TIPO DE OPERACION no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_modalidad IS NULL THEN
              v_error := 'Valor del parametro MODALIDAD no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_segmento IS NULL THEN
              v_error := 'Valor del parametro SEGMENTO no puede ser nulo';
              RAISE e_error;
          END IF;

         IF p_fecha IS NULL THEN
              v_error := 'Valor del parametro FECHA no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_hora IS NULL THEN
              v_error := 'Valor del parametro HORA no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_home_bank IS NULL THEN
              v_error := 'Valor del parametro HOME_BANK no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_confirma IS NULL THEN
              v_error := 'Valor del parametro CONFIRMA no puede ser nulo';
              RAISE e_error;
          END IF;

          IF p_confirma NOT IN ('V', 'C') THEN
              v_error := 'Valor del parametro CONFIRMA debe ser "V" o "C"';
              RAISE e_error;
          END IF;
      END;

      -- Obtener parametro
      FUNCTION lf_obt_param (
          p_param IN ge_par_dinamicos.parametro%TYPE,
          p_moneda IN ge_par_dinamicos.cod_moneda%TYPE,
          p_tipo IN VARCHAR2 -- N = Numerico, T = Texto
      ) RETURN ge_par_dinamicos.val_parametro%TYPE IS
          v_valor ge_par_dinamicos.val_parametro%TYPE;
      BEGIN
          v_lugar := 'OBT_PARAM';
          IF p_moneda IS NULL THEN
              v_valor := fug_obt_pardinamico(p_param, c_mod_cambio, NULL, NULL, NULL, NULL);
          ELSE
              v_valor := fug_obt_pardinamico(p_param, c_mod_cambio, NULL, p_moneda, NULL, NULL);
          END IF;

          IF p_tipo = 'N' THEN
              IF NVL(v_valor, 0) = 0 THEN
                  RAISE NO_DATA_FOUND;
              END IF;

              RETURN TO_NUMBER(v_valor);
          ELSE
              RETURN v_valor;
          END IF;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              v_lugar := 'Parametro dinamico '||p_param||
              ' para moneda '||NVL(p_moneda, 'NULL')||' no registrado'||
              ' o con valor cero (0).';
              RAISE;
      END;

      -- Obtiene valor de riesgo
      FUNCTION lf_obt_pos_cambio (
          p_tipo IN VARCHAR2  -- G = Global, M = Moneda
      ) RETURN lc_tot_pos_cambios.valor_riesgo%TYPE IS
          v_valor_riesgo lc_tot_pos_cambios.valor_riesgo%TYPE;
      BEGIN
          v_lugar := 'OBT_POS_CAMBIO';        
          -- CNFLIMVAR-236 --
          -- Cuando el parametro p_tipo = M, tomar el valor de riesgo de la fecha y de la moneda de la tabla LC_TOT_POS_CAMBIOS
          -- Cuando el parametro p_tipo = G, tomar el valor de riesgo de la fecha de la tabla LC_TOT_POS_CAM_GLOBAL. 
          IF p_tipo = 'M' THEN
            SELECT NVL(valor_riesgo,0) riesgo
              INTO v_valor_riesgo
              FROM lc_tot_pos_cambios
             WHERE cod_moneda = p_moneda
               AND fecha = v_fecha
               AND cod_oficina = to_number(nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),'1'))
               AND rownum = 1 ;
          ELSIF p_tipo = 'G' THEN
            SELECT NVL(valor_riesgo,0) riesgo
              INTO v_valor_riesgo
              FROM lc_tot_pos_cam_global
             WHERE fecha = v_fecha
               and rownum = 1;   
          END IF;
          --
          IF v_valor_riesgo = 0 THEN
              RAISE NO_DATA_FOUND;
          END IF;

          RETURN v_valor_riesgo;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
              v_lugar := 'Valor de riesgo no se ha podido obtener';
              RAISE;
      END;
  BEGIN
      v_lugar := 'INICIO';
      p_mensaje := NULL;
      lp_val_inicial;
      v_fecha := TRUNC(p_fecha);

      -- Obtiene parametros de control de limites VaR
      v_lugar := 'OBTENER PARAMETROS DINAMICOS';
      v_lim_max_moneda :=  lf_obt_param('LCA_LIM_VAR_MAXIMO', p_moneda, 'N');
      v_lim_min_moneda := lf_obt_param('LCA_LIM_VAR_MINIMO', p_moneda, 'N') * (-1);
      v_lim_max_global := lf_obt_param('LCA_LIM_VAR_MAXIMO', NULL, 'N');
      v_lim_min_global := lf_obt_param('LCA_LIM_VAR_MINIMO', NULL, 'N') * (-1);
      v_lim_medicion := lf_obt_param('LCA_LIM_VAR_MEDICION', NULL, 'N');
      v_lim_mensaje := lf_obt_param('LCA_LIM_VAR_MENSAJE', NULL, 'T');
      IF v_lim_mensaje IS NULL THEN
          v_lim_mensaje := 'Con esta operacion supera el limite VaR';
      END IF;
      v_msg_pendiente := 'La operacion queda pendiente de autorizacion'||
                         ' por superar el limite VaR';

      -- Obtiene codigo de moneda local y fuerte
      v_lugar := 'OBTIENE MONEDA LOCAL';
      v_mon_local := pag_gen.fu_obt_mon_local;
      IF v_mon_local IS NULL THEN
          v_error := 'La moneda local no esta configurada en el sistema.';
          RAISE e_error;
      END IF;

      -- Controla que la moneda no corresponda a la moneda local
      IF p_moneda = v_mon_local THEN
          v_error := 'ERROR - No se realiza el control para la moneda local';
          RAISE e_error;
      END IF;
      
      -- CNFLIMVAR-236 --
      -- Validar que sea de las monedas habilitada para el calculo de Limites VaR. --
      v_var_hab_moneda := nvl(fug_obt_pardinamico('LCA_LIM_VAR_HAB_MONEDA',7,null,p_moneda),'N');
      if v_var_hab_moneda != 'S' then 
        raise e_salir;
      end if;

      -- Realiza calculo de limites VaR
      v_lugar := 'CALCULAR LIMITES VAR';
      pr_cal_pos_cambio(p_fecha, p_oficina, p_moneda, p_monto, p_cotizacion,
                        p_modalidad, p_segmento, p_cod_error, p_mensaje);
      IF p_cod_error <> 0 THEN
          --RETURN;
         IF p_cod_error = 10 THEN -- registros bloqueados re-intentar calculo
			  	 v_cont := 0;   -- RABP-CNF-08-2016_DYDMR-4828
			     WHILE v_cont < 3 LOOP -- intentemos 3 veces
							 v_date := pai_int.smg_sleep('0.5');  -- se espera un momento
							 pr_cal_pos_cambio(p_fecha, p_oficina, p_moneda, p_monto, p_cotizacion,
                                 p_modalidad, p_segmento, p_cod_error, p_mensaje);
							 IF p_cod_error = 10 THEN -- reintentar si es bloqueo de registro
								  v_cont := v_cont + 1;
								  IF v_cont = 3 THEN
							  	   RETURN;
								  END IF; 
               ELSIF p_cod_error <> 0 THEN -- retornamos si es error diferente
                  RETURN;                     
							 ELSE -- si no hay error salimos de loop                                    
								  EXIT;
							 END IF;
			 	 	 END LOOP;
				 ELSE
				 	 RETURN;
				 END IF; 
      END IF;

      -- Obtiene posicion de moneda
      v_lugar := 'OBTIENE POSICION DE CAMBIO DE MONEDA';
      v_var_moneda := lf_obt_pos_cambio('M');

      -- Obtiene posicion global     
      v_lugar := 'OBTIENE POSICION DE CAMBIO GLOBAL';
      v_var_global := lf_obt_pos_cambio('G');

      -- Calcular porcentaje de riesgo de la moneda
      v_lugar := 'CALCULA PORCENTAJE VAR MONEDA';
      v_porc_moneda := ROUND(ABS(v_var_moneda * 100 / v_lim_max_moneda),2);

      -- Calcular porcentaje de riesgo global
      v_lugar := 'CALCULA PORCENTAJE VAR GLOBAL';
      v_porc_global := ROUND(ABS(v_var_global * 100 / v_lim_max_global),2);

      -- Enviar mail cuando valor de riesgo supera
      -- el porcentaje de medicion de la moneda
          
      -- CNFLIMVAR-236 --
      -- Si se desactiva el pedido de autorizacion se desactiva igualmente el envio de mails de alerta. --
      if v_activado = 'S' then
        v_lugar := 'CONTROLA PORCENTAJE VAR MONEDA';
        IF v_porc_moneda >= v_lim_medicion THEN
            v_msg_mail := 'La Posicion de Cambios de la moneda '||p_moneda||
                ' alcanza el '||v_porc_moneda||
                '% del limite VaR en una operacion de '||p_tip_oper;

            IF p_home_bank = 'S' THEN
                v_msg_mail := v_msg_mail||
                ', realizado a traves de Home Banking';
                v_mensaje := v_mensaje ||
                ', realizado a traves de Home Banking';
            END IF;

            v_msg_mail := v_msg_mail||'.';

            IF p_confirma = 'C' THEN -- Confirma la operacion
                v_mensaje := 'Con esta operacion alcanza el '||
                    LTRIM(TO_CHAR(ROUND(v_porc_moneda, 2), '999G999G999G990D00'))||
                    '% del limite VaR de la moneda';

                v_msg_mail := v_msg_mail||'.';
                    
                v_lugar := 'ENVIAR MAIL MONEDA';
                FOR c IN cur_email LOOP
                    it_mail.mail( fug_obt_dir_correo, --c.val_parametro,
                                  c.val_parametro,
                                  'LIMITES VaR',
                                  v_msg_mail);
                END LOOP;
            END IF;

        END IF;
            
        -- Controla porcentaje de medicion global.
        v_lugar := 'CONTROLA PORCENTAJE VAR GLOBAL';
        IF v_porc_global >= v_lim_medicion THEN
          v_mensaje := 'Con esta operacion alcanza el '||
              LTRIM(TO_CHAR(ROUND(v_porc_global, 2), '999G999G999G999G990D00'))||
              '% del limite VaR global';

          -- Enviar mail cuando valor de riesgo supera
          -- el porcentaje de medicion global.
          IF p_confirma = 'C' THEN -- Confirma la operacion
              v_msg_mail := 'La Posicion Global de Cambios '||p_moneda||
                  ' alcanza el '||v_porc_global||
                  '% del limite VaR global con la operacion de '||p_tip_oper;
              v_mensaje := 'Con esta operacion alcanza el '||
                  LTRIM(TO_CHAR(ROUND(v_porc_global, 2), '999G999G999G999G990D00'))||
                  '% del limite VaR';

              IF p_home_bank = 'S' THEN
                  v_msg_mail := v_msg_mail||
                  ', realizado a traves de Home Banking';
                  v_mensaje := v_mensaje ||
                  ', realizado a traves de Home Banking';
              END IF;
              v_msg_mail := v_msg_mail||'.';
                  
              v_lugar := 'ENVIAR MAIL GLOBAL';
              FOR c IN cur_email LOOP
                  it_mail.mail(fug_obt_dir_correo, --c.val_parametro,
                          c.val_parametro,
                          'LIMITES VaR',
                          v_msg_mail);
              END LOOP;
          END IF;
        END IF;
    
        -- Controla limites VaR (Tiene que generar una unica autorizacion).
        v_lugar := 'CONTROLA LIMITES';
        IF v_var_global >= v_lim_max_global THEN
          v_tipo_limite := 'maximo global';
          v_lim_mensaje := v_lim_mensaje||' '||v_tipo_limite;
          v_estado := c_est_pen_autoriz;
          --v_lim_mensaje := v_lim_mensaje||': '||LTRIM(TO_CHAR(v_lim_max_global, '999G999G999G990D00'));
        ELSE
          -- Controla si supera limite VaR Global
          IF v_var_global <= v_lim_min_global THEN
              v_tipo_limite := 'minimo global';
              v_lim_mensaje := v_lim_mensaje||' '||v_tipo_limite ;
              v_estado := c_est_pen_autoriz;
              --v_lim_mensaje := v_lim_mensaje||': '||LTRIM(TO_CHAR(v_lim_min_global, '999G999G999G990D00'));
          ELSE
              -- supera el valor de riesgo maximo para la moneda
              IF v_var_moneda >= v_lim_max_moneda THEN
                  v_tipo_limite := 'maximo de la moneda';
                  v_lim_mensaje := v_lim_mensaje||' '||v_tipo_limite;
                  v_estado := c_est_pen_autoriz;
                  --v_lim_mensaje := v_lim_mensaje||': '||
                  --    LTRIM(TO_CHAR(v_lim_max_moneda, '999G999G999G990D00'));
              ELSE
                    -- supera el valor de riesgo minimo para la moneda
                  IF v_var_moneda <= v_lim_min_moneda THEN
                      v_tipo_limite := 'minimo de la moneda';
                      v_lim_mensaje := v_lim_mensaje||' '||v_tipo_limite;
                      v_estado := c_est_pen_autoriz;
                      --v_lim_mensaje := v_lim_mensaje||': '||
                      --    LTRIM(TO_CHAR(v_lim_min_moneda, '999G999G999G990D00'));
                  END IF;
              END IF;
          END IF;
        END IF;
      end if;
          
      IF NVL(v_estado, '-') = c_est_pen_autoriz THEN
          v_mensaje :=  v_lim_mensaje;
          p_estado := v_estado;
          IF p_confirma = 'C' THEN
             IF p_segmento = 'CON' THEN
                --v_mensaje := v_msg_pendiente||v_tipo_limite;
                v_mensaje := v_mensaje||'. '||v_msg_pendiente||' '||v_tipo_limite;
             ELSIF p_segmento = 'FUT' THEN
                --v_mensaje := v_msg_pendiente||v_tipo_limite;
                v_mensaje := v_mensaje||'. '||v_msg_pendiente||' '||v_tipo_limite;
             END IF;
          END IF;
      ELSE
          p_estado := null; -- Se agrega para devolver el estado a null en caso de recibir el estado con valor distinto a null
          IF p_confirma <> 'C' THEN
              v_mensaje := NULL; -- para que emita el mensaje de porc. medicion solo al confirmar la operacion.
          END IF;
      END IF;

      IF v_mensaje IS NOT NULL THEN
          v_mensaje := v_mensaje||'.-';
      END IF;

      p_mensaje := v_mensaje;
          
      -- CNFLIMVAR-236 --
      -- Si no esta activado la generacion de Pedidos de Autorizaciones envia el estado=null de modo a no generar el pedido.
      if v_activado != 'S' then
        p_estado := null;
        p_cod_error := null;
        p_mensaje := null;
      end if;
          
  EXCEPTION
      WHEN e_salir THEN
          p_estado := null;
          p_cod_error := null;
          p_mensaje := null;
      WHEN e_error THEN
          p_cod_error := 1;
          p_mensaje := v_error;
       WHEN OTHERS THEN
          p_cod_error := 99;
          p_mensaje := 'PAL_VAR.PR_CON_POS_CAMBIO - '||v_lugar||': '||SQLERRM;
  END pr_con_pos_cambio;

  /*
   * Objetivo: Envolver el llamado al procedimiento
   *           PR_CON_POS_CAMBIO
   * Fecha creacion : 05/08/2013
   */
  PROCEDURE pr_wrap_con_pos_cambio (
      p_usuario IN ge_aut_pedidos.cod_usuario%TYPE,
      p_oficina IN ge_movimientos.cod_oficina%TYPE,
      p_moneda IN ge_movimientos.cod_moneda%TYPE,
      p_monto IN ge_movimientos.monto%TYPE,
      p_cotizacion IN ge_movimientos.cotizacion%TYPE,
      p_tip_oper IN lc_tip_operaciones.descripcion%TYPE,
      p_modalidad IN ge_movimientos.cod_mad_padre%TYPE,
      p_segmento IN lc_pos_cambios_tmp.segmento%TYPE,
      p_fecha IN ge_movimientos.fecha%TYPE,
      p_hora IN ge_movimientos.hora%TYPE,
      p_home_bank IN VARCHAR2 DEFAULT 'N', -- S=Si, N=No
      p_confirma IN VARCHAR2, -- V=Valida, C=Confirma
      p_estado IN OUT ge_movimientos.estado%TYPE,
      p_cod_error IN OUT NUMBER,
      p_mensaje IN OUT VARCHAR2
  ) IS
      
  BEGIN
      pr_con_pos_cambio(
          p_usuario,
          p_oficina,
          p_moneda,
          p_monto,
          p_cotizacion,
          p_tip_oper,
          p_modalidad,
          p_segmento,
          p_fecha,
          p_hora,
          p_home_bank,
          p_confirma,
          p_estado,
          p_cod_error,
          p_mensaje
      );
  END;
  
  /*
   * Objetivo: Envolver el llamado al procedimiento
   *           PR_CAL_POS_CAMBIO
   * Fecha creacion : 05/08/2013
   */
  PROCEDURE pr_wrap_cal_pos_cambio IS
      v_cod_error NUMBER;
      v_mensaje VARCHAR2(2000);
  BEGIN
      pr_cal_pos_cambio(NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                        v_cod_error, v_mensaje);
  END;
  -------------------
  -- CNFLIMVAR-236 --
  -------------------
  /* Inicializar Matriz (m*n) */
  function fu_ini_matriz( m integer, -- Numero de Filas
                          n integer  -- Numero de Columnas
                          ) return TblOfTblType is
    matR TblOfTblType;
  begin
    
    FOR i IN 1 .. m LOOP   --1 -- 2
      FOR j IN 1 .. n LOOP  -- 1 -- 5
        matR(i)(j).valor := 0;
      END LOOP;
    END LOOP;
    
    return matR;
  end fu_ini_matriz;
  --
   /* Multiplicar matrices -- A(m*p)*B(p*N) -- Resultado = Matriz R(m*n) */
   function fu_mul_matrices( m    integer, -- Numero de Filas de A
                             p    integer, -- Numero de Columnas de A = Numero de Filas de B
                             n    integer, -- Numero de Columnas de B
                             matA TblOfTblType, -- Matriz A
                             matB TblOfTblType -- Matriz B  
                            ) return TblOfTblType is
    matR TblOfTblType; -- Matriz Resultado            
  begin
    -- Matriz A(m*p) * Matriz B(p*N) -- Resultado = Matriz R(m*n)
    matR := fu_ini_matriz( m, -- Numero de Filas
                           n  -- Numero de Columnas
                          );
    FOR k IN 1 .. m LOOP -- m = Numero de Filas de A
      FOR j IN 1 .. n LOOP  -- n = Numero de Columnas de B
        FOR i IN 1 .. p LOOP   -- p = Numero de Columnas de A = Numero de Filas de B 
          matR(k)(j).valor := matR(k)(j).valor + ( (matA(k)(i).valor)*(matB(i)(j).valor) );
        END LOOP;
      END LOOP;
      
      return matR;
    END LOOP;      
  end fu_mul_matrices;
  --
  /* Invertir Matriz (m*n) */
  function fu_inv_matriz( m      integer,  -- Numero de Filas
                          n      integer,  -- Numero de Columnas
                          mat    TblOfTblType -- Matriz a invertir
                        ) return TblOfTblType is
    matR TblOfTblType;
  begin
     
    matR := fu_ini_matriz( n, -- Numero de Filas
                           m  -- Numero de Columnas
                          );
                        
    FOR i IN 1 .. n LOOP
      FOR j IN 1 .. m LOOP
        matR(i)(j).valor := mat(j)(i).valor;
      END LOOP;
    END LOOP;
    
    return matR;
  end fu_inv_matriz;
  --
  PROCEDURE pr_cal_var( p_fecha         IN DATE,
                        p_oficina       IN lc_tot_pos_cambios.cod_oficina%TYPE,
                        p_lim_factor    IN NUMBER,
                        p_volatilidad   IN OUT lc_tot_pos_cam_global.volatilidad%type, 
                        p_valor_riesgo  IN OUT lc_tot_pos_cam_global.valor_riesgo%type,  
                        p_pos_neta_pyg  IN OUT lc_tot_pos_cam_global.pos_neta_pyg%type, 
                        p_limite_var    IN OUT lc_tot_pos_cam_global.limite_var%type ) IS
    v_lugar      VARCHAR2(2000);
    -- Variables tipo Matriz --
    mat_pond     TblOfTblType;
    mat_covar    TblOfTblType; 
    mat_pos      TblOfTblType;
    mat_pos_inv  TblOfTblType;
    matV         TblOfTblType;  
    --
    v_pos_usd    number;
    v_pos_eur    number;
    v_pos_brl    number;
    v_pos_tot_gs number;
    
    function lf_obt_pos_moneda( p_fecha lc_tot_pos_cambios.fecha%type,
                                p_moneda lc_tot_pos_cambios.cod_moneda%type,
                                p_oficina lc_tot_pos_cambios.cod_oficina%type
                                ) return number is
      v_pos_neta_gs number; 
    begin
      select ( (nvl(a.pos_neta_me,0)+nvl(a.pos_suspenso_me,0)) * nvl(a.cotizacion,0) ) pos_neta_gs
        into v_pos_neta_gs
        from lc_tot_pos_cambios a
       where a.cod_moneda = p_moneda
         and a.cod_oficina = p_oficina
         and a.fecha = ( select max(b.fecha) 
                           from lc_tot_pos_cambios b
                          where b.cod_moneda = a.cod_moneda
                            and b.cod_oficina = a.cod_oficina
                            and b.fecha <= p_fecha );
      return nvl(v_pos_neta_gs,0);             
    end;
                                  
  BEGIN
     IF p_fecha IS NULL THEN
        v_lugar := 'El parametro FECHA debe tener valor.';
        RAISE e_error;
     END IF;
     v_lugar := 'OBTENER MATRIZ DE COVARIANZAS';
     -- Obtener la Matriz de Covarianzas (Relacion Moneda-Moneda). --
  /*
  Relacion Dolar-Dolar = Covarianza entre Rendimientos del Dolar.
  Relacion Dolar-Euro = Covarianza entre Rendimientos del Dolar y Rendimientos del Euro.
  Relacion Dolar-Real = Covarianza entre Rendimientos del Dolar y Rendimientos del Real.
  Relacion Euro-Dolar = Relacion Dolar-Euro.
  Relacion Euro-Euro= Covarianza entre Rendimientos del Euro.
  Relacion Euro-Real = Covarianza entre Rendimientos del Euro y Rendimientos del Real.
  Relacion Real-Dolar = Relacion Dolar-Real.
  Relacion Real-Euro = Relacion Euro-Real.
  Relacion Real-Real= Covarianza entre Rendimientos del Real.
  */
     -- 1 = Dolar
     -- 2 = Euro
     -- 3 = Real
     mat_covar := fu_ini_matriz( 3, -- Numero de Filas
                                 3 -- Numero de Columnas
                                );
     SELECT COVAR_POP(rend_usd, rend_usd) b11,
            COVAR_POP(rend_usd, rend_eur) b12,
            COVAR_POP(rend_usd, rend_brl) b13,
            COVAR_POP(rend_eur, rend_eur) b22,
            COVAR_POP(rend_eur, rend_brl) b23,
            COVAR_POP(rend_brl, rend_brl) b33
       INTO mat_covar(1)(1).valor, 
            mat_covar(1)(2).valor,
            mat_covar(1)(3).valor,
            mat_covar(2)(2).valor,
            mat_covar(2)(3).valor,
            mat_covar(3)(3).valor
       FROM lc_tot_pos_cam_global;
     
     mat_covar(2)(1).valor := mat_covar(1)(2).valor;
     mat_covar(3)(1).valor := mat_covar(1)(3).valor;
     mat_covar(3)(2).valor := mat_covar(2)(3).valor;
     
     v_lugar := 'OBTENER POSICION EN GS';
     -- Obtener la Posicion en Guaranies para cada Moneda --
  /*     
  Posicion Dolar Gs. = Valor absoluto de (Posicion Neta en Dolares * Tipo de Cambio Dolar).
  Posicion Euro Gs. = Valor absoluto de (Posicion Neta en Euros * Tipo de Cambio Euro).
  Posicion Real Gs. = Valor absoluto de (Posicion Neta en Reales * Tipo de Cambio Real).
  */
     v_pos_usd := lf_obt_pos_moneda(p_fecha, 'USD', p_oficina);
     v_pos_eur := lf_obt_pos_moneda(p_fecha, 'EUR', p_oficina);
     v_pos_brl := lf_obt_pos_moneda(p_fecha, 'BRL', p_oficina);
     
     v_lugar := 'OBTENER MATRIZ PONDERACION';
     -- Obtener la Ponderacion por Moneda. --
  /*     
  Posicion Total Gs. =PosicionDolar Gs. + Posicion Euro Gs. +PosicionRealGs.
  Ponderacion Dolar = PosicionDolar Gs. / Posicion Total Gs.
  Ponderacion Euro = Posicion Euro Gs. / Posicion Total Gs.
  Ponderacion Real = Posicion Real Gs. / Posicion Total Gs.
  */    
     -- 1 = Dolar
     -- 2 = Euro
     -- 3 = Real
     v_pos_tot_gs := abs(v_pos_usd) + abs(v_pos_eur) + abs(v_pos_brl);
     mat_pond := fu_ini_matriz( 1, -- Numero de Filas
                                3  -- Numero de Columnas
                               );
     if v_pos_tot_gs != 0 then
       mat_pond(1)(1).valor := abs(v_pos_usd)/v_pos_tot_gs;
       mat_pond(1)(2).valor := abs(v_pos_eur)/v_pos_tot_gs;
       mat_pond(1)(3).valor := abs(v_pos_brl)/v_pos_tot_gs;
     else
       mat_pond(1)(1).valor := 0;
       mat_pond(1)(2).valor := 0;
       mat_pond(1)(3).valor := 0;
     end if;
     
     v_lugar := 'OBTENER POSICION RELATIVA';
     -- Obtener la Posicion relativa por Moneda. --
  /*
  Para obtener la Ponderacion relativa por Moneda se realiza un Producto de Matrices donde:
  Matriz A = Matriz de Ponderacion por Moneda.
  Matriz B = Matriz de Covarianzas (Relacion Moneda-Moneda).
  */     
     -- 1 = Dolar
     -- 2 = Euro
     -- 3 = Real
     
     mat_pos := fu_mul_matrices( 1, -- m = Numero de Filas de A
                                 3, -- p = Numero de Columnas de A = Numero de Filas de B
                                 3, -- n = Numero de Columnas de B
                                 mat_pond,  -- Matriz A
                                 mat_covar  -- Matriz B
                      );
                      
     v_lugar := 'OBTENER VOLATILIDAD PORTFOLIO';
     -- Obtener el porcentaje de Volatilidad del Portfolio. --
  /*     
  Para obtener el porcentaje de Volatilidad del Portfolio se realiza un Producto de Matrices donde:
  Matriz A = Matriz de Ponderacion por Moneda.
  Matriz B = Transpuesta de la Matriz de Posicion Relativa por Moneda.
  Resultado = Matriz A * Matriz B = Volatilidad del Portfolio
  */
     
     mat_pos_inv := fu_inv_matriz( 1,      -- Numero de Filas de la Matriz a invertir
                                   3,      -- Numero de Columnas de la Matriz a invertir
                                   mat_pos -- Matriz a invertir
                                  );
     
     matV := fu_mul_matrices( 1,            -- m = Numero de Filas de A
                              3,            -- p = Numero de Columnas de A = Numero de Filas de B
                              1,            -- n = Numero de Columnas de B
                              mat_pond,     -- Matriz A
                              mat_pos_inv   -- Matriz B
                              );
                                                                                                                  
     p_volatilidad  := ROUND( SQRT( matV(1)(1).valor ), 20 );
     
     v_lugar := 'OBTENER POSICION NETA PYG';
     -- Obtener la Posicion Neta Total en Guaranies. --
  /*
  Posicion Neta Total en Guaranies = 
  (Posicion Neta en Dolares * Tipo de Cambio Dolar) + 
  (Posicion Neta en Euros * Tipo de Cambio Euro) + 
  (Posicion Neta en Reales * Tipo de Cambio Real)
  */     
     p_pos_neta_pyg := ROUND( (v_pos_usd + v_pos_eur + v_pos_brl), 2/*10*/ );
     
     v_lugar := 'OBTENER MONTO VaR Global';
     -- Obtener el Monto VaR Global. --
  /*     
  Monto VaR Global = Valor absoluto ( Posicion Neta Total en Guaranies * Volatilidad del Portfolio * Factor )
  */    
     p_valor_riesgo := ROUND( (abs( p_pos_neta_pyg * p_volatilidad * p_lim_factor )), 2 /*10*/);  
     
     v_lugar := 'OBTENER LIMITE VaR Global';   
     -- Obtener el Limite de Valor de Riesgo. --
     p_limite_var := fug_obt_pardinamico('LCA_LIM_VAR_MAXIMO', 7);
     
  EXCEPTION
      WHEN e_error THEN
           RAISE_APPLICATION_ERROR(-20000, v_lugar);
      WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20000, 'PR_CAL_VAR - '||
                                   v_lugar||' '||SQLERRM);    
  END pr_cal_var;
  --
  
  /*
   * Objetivo: Calcular el VaR Global de la fecha
   * Fecha creacion : 27/11/2014
   */
  PROCEDURE pr_cal_var_global( 
    p_fecha      IN DATE DEFAULT NULL,
    p_oficina    IN lc_tot_pos_cambios.cod_oficina%TYPE DEFAULT NULL,
    p_cod_error  IN OUT NUMBER,
    p_mensaje    IN OUT VARCHAR2
    ) IS
        
    e_registro_bloqueado EXCEPTION;
    e_mensaje            EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_registro_bloqueado, -54);
    --PRAGMA AUTONOMOUS_TRANSACTION;
  
    -- variables
    v_lugar         VARCHAR2(2000);
    v_duplica       BOOLEAN;  
    v_fecha         DATE;
    v_lim_factor    NUMBER;  
           
    v_rend_usd      lc_tot_pos_cam_global.rend_usd%type; 
    v_rend_eur      lc_tot_pos_cam_global.rend_eur%type;  
    v_rend_brl      lc_tot_pos_cam_global.rend_brl%type;  
    v_volatilidad   lc_tot_pos_cam_global.volatilidad%type;  
    v_valor_riesgo  lc_tot_pos_cam_global.valor_riesgo%type; 
    v_pos_neta_pyg  lc_tot_pos_cam_global.pos_neta_pyg%type;             
    v_limite_var    lc_tot_pos_cam_global.limite_var%type;  
  
    -- Obtener rendimiento --
    FUNCTION lf_obt_rendimiento (
        p_moneda IN ge_cotizaciones.cod_moneda%TYPE,
        p_fecha IN DATE
    ) RETURN lc_tot_pos_cambios.rend_tc%TYPE IS
        v_rend_tc lc_tot_pos_cambios.rend_tc%TYPE;
    BEGIN
        v_lugar := 'OBTENER RENDIMIENTO MONEDA';
        SELECT a.rend_tc 
          INTO v_rend_tc
          FROM lc_tot_pos_cambios a 
         WHERE a.cod_moneda = p_moneda
           AND a.cod_oficina = to_number(nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),'1'))
           AND a.fecha = ( SELECT MAX(fecha) 
                             FROM lc_tot_pos_cambios b
                            WHERE b.cod_moneda = a.cod_moneda
                              AND b.cod_oficina = a.cod_oficina
                              AND b.fecha <= p_fecha );
        RETURN v_rend_tc;
    EXCEPTION
      WHEN OTHERS THEN
        v_lugar := 'OBTENER RENDIMIENTO MONEDA, p_moneda '||p_moneda||' p_fecha '||p_fecha;
        raise;
    END;
    --
  BEGIN
    v_lugar := 'INICIO';
    p_cod_error := NULL;
    p_mensaje := NULL;

    v_fecha := p_fecha;
    IF v_fecha IS NULL THEN
        v_fecha := pae_cnf.fu_obt_fec_actual(7);
    END IF;
    v_fecha := TRUNC(v_fecha);
    
    v_lugar := 'OBTENER FACTOR';
    -- Obtener Factor que se utiliza para calcular el limite VaR --
    BEGIN          
        v_lim_factor := /*to_number(*/nvl(fug_obt_pardinamico('LCA_LIM_VAR_FACTOR',7),0)/*)*/;
        IF v_lim_factor = 0 THEN
            RAISE NO_DATA_FOUND;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_lugar := 'Parametro dinamico LCA_LIM_VAR_FACTOR debe ser configurado';
            RAISE;
    END;
      
    -- Bloquea tabla de Posicion de Cambios Global --
    v_lugar := 'LOCK TABLA LC_TOT_POS_CAM_GLOBAL';
    LOCK TABLE LC_TOT_POS_CAM_GLOBAL   
      IN EXCLUSIVE MODE
      NOWAIT;

    v_lugar := 'DELETE REGISTRO LC_TOT_POS_CAM_GLOBAL';
    DELETE lc_tot_pos_cam_global
     WHERE fecha = v_fecha;
    
    v_lugar := 'CALCULAR RENDIMIENTO MONEDA'; 
    -- Calcular datos --   
    -- USD --
    v_rend_usd :=  lf_obt_rendimiento('USD', v_fecha);
    -- EUR --
    v_rend_eur :=  lf_obt_rendimiento('EUR', v_fecha);
    -- BRL -- 
    v_rend_brl :=  lf_obt_rendimiento('BRL', v_fecha);
    --
    
    v_lugar := 'INSERTAR EN LC_TOT_POS_CAM_GLOBAL';
    -- Insertar en la tabla --  
    BEGIN
       INSERT INTO lc_tot_pos_cam_global( fecha, 
                                          rend_usd, 
                                          rend_eur, 
                                          rend_brl )
       VALUES( v_fecha, 
               v_rend_usd, 
               v_rend_eur, 
               v_rend_brl );
     EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            v_duplica := TRUE;
     END;

     IF v_duplica THEN
        UPDATE lc_tot_pos_cam_global
            SET rend_usd = v_rend_usd,
                rend_eur = v_rend_eur,
                rend_brl = v_rend_brl
            WHERE fecha = v_fecha;
        IF SQL%ROWCOUNT = 0 THEN
            v_lugar := v_lugar||': No pudo actualizar registro';
            RAISE e_mensaje;
        END IF;
     END IF;
     
     v_lugar := 'CALCULAR MATRIZ COVARIANZAS';      
     pr_cal_var( v_fecha, 
                 p_oficina,
                 v_lim_factor,
                 v_volatilidad, 
                 v_valor_riesgo, 
                 v_pos_neta_pyg, 
                 v_limite_var );
                 
     v_lugar := 'ACTUALIZAR LC_TOT_POS_CAM_GLOBAL';
     UPDATE lc_tot_pos_cam_global a
        SET a.volatilidad  = v_volatilidad,
            a.valor_riesgo = v_valor_riesgo,
            a.pos_neta_pyg = v_pos_neta_pyg,
            a.limite_var   = v_limite_var
        WHERE fecha = v_fecha;

    IF SQL%ROWCOUNT = 0 THEN
        v_lugar := v_lugar||': No pudo actualizar registro';
        RAISE e_mensaje;
    END IF;
    
    /*v_lugar := 'COMMIT';
    COMMIT;*/
    
    p_cod_error := 0;
    p_mensaje := NULL;
        
  EXCEPTION
    WHEN e_mensaje THEN
        ROLLBACK;
        p_cod_error := 1;
        p_mensaje := v_lugar;
    WHEN e_registro_bloqueado THEN
        ROLLBACK;
        p_cod_error := 10;
        p_mensaje := 'La Posicion de Cambios global esta siendo actualizada'||
         '  por otro usuario, espere un momento e intentelo nuevamente.';
    WHEN OTHERS THEN
        ROLLBACK;
        p_cod_error := 99;
        p_mensaje := 'PAL_VAR.PR_CAL_VAR_GLOBAL - '||v_lugar||': '||SQLERRM;
  END pr_cal_var_global;

BEGIN  
  pre_cam_for_numerico('.,');
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 7;
END PAL_VAR;
/


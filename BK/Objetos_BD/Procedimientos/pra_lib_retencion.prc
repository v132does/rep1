CREATE OR REPLACE PROCEDURE IT.PRA_LIB_RETENCION
(
   p_cta_desde      IN VARCHAR2 DEFAULT NULL,
   p_cta_hasta      IN VARCHAR2 DEFAULT NULL,
   p_lib_posterior  IN VARCHAR2 DEFAULT NULL,
   p_mue_error      IN VARCHAR2 DEFAULT 'S',
   p_nro_boleta     IN NUMBER DEFAULT NULL,
   p_mto_detalle    IN NUMBER DEFAULT NULL,
   p_hor_movimiento IN VARCHAR2 DEFAULT NULL, -- Se agrega para reversar liberaciones automaticas.
   p_cod_usuario    IN VARCHAR2 DEFAULT NULL  -- Se agrega para reversar liberaciones automaticas.
) IS

   v_mue_error       VARCHAR2(1);
   v_cod_moneda      ah_cta_vistas.cod_moneda%TYPE;
   v_mensaje         VARCHAR2(250);
   v_nro_tarjeta     ta_tarjetas.nro_tarjeta%TYPE;
   v_cod_usuario     ba_usuarios.cod_usuario%TYPE;
   v_hora            ge_movimientos.hora%TYPE;
   v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
   v_cod_mod_padre   ba_modulos.cod_modulo%TYPE;
   v_cod_mad_padre   VARCHAR2(240);
   v_fec_actual      DATE;
   v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
   r_gmovi           ge_movimientos%ROWTYPE;
   v_encontro        VARCHAR2(1) := 'N';
   --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
   v_cod_mon_local   ge_par_generales.cod_mon_local%type := pag_gen.fu_obt_mon_local;
   v_cta_desde       ge_cuentas.nro_cuenta%TYPE;
   v_cta_hasta       ge_cuentas.nro_cuenta%TYPE;
   v_existe          VARCHAR2(1) := 'N';
   v_tra_cargo       ge_transacciones.cod_transaccion%TYPE := 0;
   --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
   v_cod_mon_fuerte  ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
   v_gen_cargo       VARCHAR2(1) := 'N'; -- Indica si va generar cargo o no.
   v_nro_cuenta      ge_movimientos.nro_cuenta%TYPE; -- Desarrollo interno. 22/07
   v_can_che         NUMBER DEFAULT 0;
   v_can_che_exonerado      NUMBER DEFAULT 0;
   v_can_cheques     NUMBER := 0;
   v_can_che_mes_pl  NUMBER := 0;
   v_can_che_mes_pe  NUMBER := 0;
   v_can_che_cobrar  NUMBER := 0;
   v_tot_cheques     NUMBER := 0;
   v_fec_inicial     DATE DEFAULT pag_cal.fu_obt_fec_pri_dia_mes_habil(4);
   v_act_liberado    VARCHAR2(1):= 'S'; -- Indica si el registro se va marcar como Liberado S/N
   --Notificaciones Fase 3
   v_ret             NUMBER(3) := 0;
   v_cod_tra_padre   ge_movimientos.cod_tra_padre%type;
   --DESOPIMI-62 - Optimizar tratamiento de error en Liberación de Retenciones (PRA_LIB_RETENCION) - DYD-SDSL-3454
   v_val_parametro   ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('NRO_CTA_EXC_LIB_RET'),'0');
   v_exi_lib_anterior  NUMBER;
   v_lugar varchar2(2000):= '';
   v_sub varchar2(3000):= '';
   CURSOR c_ah_retenciones IS
      SELECT ah_retenciones.*, ah_retenciones.rowid fila
        FROM ah_retenciones
    where liberado  = 'N'
         AND cod_modulo IN (3, 4, 5, 6, 9)
      and nro_documento = nvl(p_nro_boleta,nro_documento)
      and ((fec_final <= v_fec_actual) or (lib_posterior = 'S'))
      and nvl(p_lib_posterior, lib_posterior) = lib_posterior
      and nro_cuenta between v_cta_desde and v_cta_hasta
      --DESOPIMI-62 - LCABRERA FEB/2017
      and instr(v_val_parametro, nro_cuenta) = 0 --Cuentas Excluidas por error detectado--
      --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
      --No considerar operaciones de tas no confirmadas
      and not exists (select 1
            from cj_movimientos c
                      where c.fecha         = ah_retenciones.fec_inicio
                        and c.cod_usuario   = ah_retenciones.cod_usuario
            and c.estado       = 'X'
            and c.nro_cuenta    = ah_retenciones.nro_cuenta
            and c.cod_moneda    = ah_retenciones.cod_moneda
            and c.nro_documento = ah_retenciones.nro_documento
            and c.monto     = ah_retenciones.monto)
      order by cod_modulo;

   CURSOR c_ah_ret_x_cuenta is
       select ah_retenciones.*, ah_retenciones.rowid fila
       from ah_retenciones
       where nro_cuenta    = v_cta_desde
       and nro_documento = nvl(p_nro_boleta, nro_documento)
       and liberado       = 'N'
       and cod_modulo    in (3,4,5,6,9)
       and ((fec_final   <= v_fec_actual) OR (lib_posterior = 'S'))
       and nvl(p_lib_posterior, lib_posterior) = lib_posterior
       --DESOPIMI-62 - LCABRERA FEB/2017
       and instr(v_val_parametro, nro_cuenta) = 0 --Cuentas Excluidas por error detectado--
        --- No considerar operaciones de tas no confirmadas
       and not exists (select 1
               from cj_movimientos c
               where c.fecha         = ah_retenciones.fec_inicio
                 and c.cod_usuario   = ah_retenciones.cod_usuario
                 and c.estado      = 'X'
                 and c.nro_cuenta    = ah_retenciones.nro_cuenta
                 and c.cod_moneda    = ah_retenciones.cod_moneda
                 and c.nro_documento = ah_retenciones.nro_documento
                 and c.monto        = ah_retenciones.monto);

   r_retencion c_ah_retenciones%ROWTYPE;

   --Actualizar estado de movimientos para liberar por Sobregiros CROAPARS-1 - 07/2015 V.V.
   CURSOR g_mov_pendientes is
       select m.cod_usuario,m.fecha,m.hora,m.nro_caja, m.cod_tra_padre
         from ge_movimientos m
       where m.cod_tra_padre = 355
         and   m.cod_mod_padre = 9
         and   m.cod_mad_padre = 91
         and   m.estado = 'X'
         and   m.reversado = 'N'
       union
       select m.cod_usuario,m.fecha,m.hora,m.nro_caja, m.cod_tra_padre
         from ge_movimientos m
       where m.cod_tra_padre = 345
         and   m.cod_mod_padre = 4
         and   m.cod_mad_padre = 41
         and   m.estado = 'X'
         and   m.reversado = 'N' ;

   /* Actualizar el saldo retenido en AH_CTA_VISTAS. */
   PROCEDURE lp_act_sal_ret_vista IS
      CURSOR c_ah_cta_vistas IS
         SELECT cod_moneda
           FROM ah_cta_vistas
          WHERE nro_cuenta = r_retencion.nro_cuenta
            FOR UPDATE OF sal_retenido;
   BEGIN
      v_sub := 'lp_act_sal_ret_vista';
      IF c_ah_cta_vistas%ISOPEN THEN
         CLOSE c_ah_cta_vistas;
      END IF;
      OPEN c_ah_cta_vistas;
      v_encontro := 'N';
      FETCH c_ah_cta_vistas
         INTO v_cod_moneda;
      IF c_ah_cta_vistas%FOUND THEN
         v_encontro := 'S';
         UPDATE ah_cta_vistas
         set sal_retenido = nvl(sal_retenido,0) - nvl(r_retencion.sal_retenido,0),
                fec_ult_movimiento = v_fec_actual,
                hor_ult_movimiento = v_hora
          WHERE CURRENT OF c_ah_cta_vistas;
      ELSE
         v_mensaje := ' No se encontro cuenta ' || r_retencion.nro_cuenta || ' en AH_CTA_VISTAS...';
      END IF;
      CLOSE c_ah_cta_vistas;
   END;
   /* Actualiza el saldo retenido en AH_CTA_PLAZOS. */
   PROCEDURE lp_act_sal_ret_plazo IS
      CURSOR c_ah_cta_plazos IS
         SELECT cod_moneda
           FROM ah_cta_plazos
          WHERE nro_cuenta = r_retencion.nro_cuenta
            FOR UPDATE OF sal_retenido;
   BEGIN
      v_sub := 'lp_act_sal_ret_plazo';
      IF c_ah_cta_plazos%ISOPEN THEN
         CLOSE c_ah_cta_plazos;
      END IF;
      OPEN c_ah_cta_plazos;
      v_encontro := 'N';
      FETCH c_ah_cta_plazos
         INTO v_cod_moneda;
      IF c_ah_cta_plazos%FOUND THEN
         v_encontro := 'S';
         UPDATE ah_cta_plazos
         set sal_retenido = nvl(sal_retenido,0) - nvl(r_retencion.sal_retenido,0),
                fec_ult_movimiento = v_fec_actual,
                hor_ult_movimiento = v_hora
          WHERE CURRENT OF c_ah_cta_plazos;
      ELSE
         v_mensaje := ' No se encontro cuenta ' || r_retencion.nro_cuenta || ' en AH_CTA_PLAZOS...';
      END IF;
      CLOSE c_ah_cta_plazos;
   END;
   /* Actualiza el saldo retenido en AH_CTA_CERTIFICADOS. */
   PROCEDURE lp_act_sal_ret_certi IS
      v_fec_apertura ah_cta_certificados.fec_apertura%TYPE;
      v_capital      ah_cta_certificados.capital%TYPE;
      v_sal_retenido ah_cta_certificados.sal_retenido%TYPE;
      CURSOR c_ah_cta_certificados IS
         SELECT cod_moneda, fec_apertura, capital, sal_retenido
           FROM ah_cta_certificados
          WHERE nro_cuenta = r_retencion.nro_cuenta
            FOR UPDATE OF sal_retenido;
   BEGIN
      v_sub := 'lp_act_sal_ret_certi';
      IF c_ah_cta_certificados%ISOPEN THEN
         CLOSE c_ah_cta_certificados;
      END IF;
      OPEN c_ah_cta_certificados;
      v_encontro := 'N';
      FETCH c_ah_cta_certificados
         INTO v_cod_moneda, v_fec_apertura, v_capital, v_sal_retenido;
      IF nvl(v_sal_retenido, 0) - nvl(r_retencion.monto, 0) = 0 THEN
         --- Se esta liberando definitivamente la cuenta
         IF v_fec_apertura <> v_fec_actual THEN
            raise_application_error(-20001, 'Liberación de CDA no permitida antes de la apertura');
         END IF;
      END IF;
      IF c_ah_cta_certificados%FOUND THEN
         v_encontro := 'S';
         UPDATE ah_cta_certificados
         set sal_retenido = nvl(sal_retenido,0) - nvl(r_retencion.sal_retenido,0),
                fec_ult_movimiento = v_fec_actual,
                hor_ult_movimiento = v_hora
          WHERE CURRENT OF c_ah_cta_certificados;
      ELSE
         v_mensaje := ' No se encontro cuenta ' || r_retencion.nro_cuenta ||
                      ' en AH_CTA_CERTIFICADOS...';
      END IF;
      CLOSE c_ah_cta_certificados;
   END;
   /* Actualiza el saldo retenido en CC_CTA_CORRIENTES. */
   PROCEDURE lp_act_sal_ret_cte IS
      CURSOR c_cc_cta_corrientes IS
         SELECT cod_moneda
           FROM cc_cta_corrientes
          WHERE nro_cuenta = r_retencion.nro_cuenta
            FOR UPDATE OF sal_retenido;
   BEGIN
      v_sub := 'lp_act_sal_ret_cte';
      IF c_cc_cta_corrientes%ISOPEN THEN
         CLOSE c_cc_cta_corrientes;
      END IF;
      OPEN c_cc_cta_corrientes;
      v_encontro := 'N';
      FETCH c_cc_cta_corrientes
         INTO v_cod_moneda;
      IF c_cc_cta_corrientes%FOUND THEN
         v_encontro := 'S';
         UPDATE cc_cta_corrientes
         set sal_retenido = nvl(sal_retenido,0) - nvl(r_retencion.sal_retenido,0),
                fec_ult_movimiento = v_fec_actual,
                hor_ult_movimiento = v_hora
          WHERE CURRENT OF c_cc_cta_corrientes;
      ELSE
         v_mensaje := ' No se encontro cuenta ' || r_retencion.nro_cuenta ||
                      ' en CC_CTA_CORRIENTES...';
      END IF;
      CLOSE c_cc_cta_corrientes;
   END;
   /* Actualiza el saldo retenido en CC_CTA_BANCARIAS. */
   PROCEDURE lp_act_sal_ret_ban IS
      CURSOR c_cc_cta_bancarias IS
         SELECT cod_moneda
           FROM cc_cta_bancarias
          WHERE nro_cuenta = r_retencion.nro_cuenta
            FOR UPDATE OF sal_retenido;
   BEGIN
      v_sub := 'lp_act_sal_ret_ban';
      IF c_cc_cta_bancarias%ISOPEN THEN
         CLOSE c_cc_cta_bancarias;
      END IF;
      OPEN c_cc_cta_bancarias;
      v_encontro := 'N';
      FETCH c_cc_cta_bancarias
         INTO v_cod_moneda;
      IF c_cc_cta_bancarias%FOUND THEN
         v_encontro := 'S';
         UPDATE cc_cta_bancarias
            SET sal_retenido       = nvl(sal_retenido, 0) - nvl(r_retencion.sal_retenido, 0),
                fec_ult_movimiento = v_fec_actual,
                hor_ult_movimiento = v_hora
          WHERE CURRENT OF c_cc_cta_bancarias;
      ELSE
         v_mensaje := ' No se encontro cuenta ' || r_retencion.nro_cuenta ||
                      ' en C_CC_CTA_BANCARIAS...';
      END IF;
      CLOSE c_cc_cta_bancarias;
   END;

   --Actualiza el detalle de los cheques <<EF,07/09/2009>>
   PROCEDURE lp_act_est_cheque IS

   BEGIN
      v_sub := 'lp_act_est_cheque';
      IF v_cod_transaccion IN (515, 565) THEN
         --Plaza Local
         UPDATE cc_che_enviados z
            SET z.liberado = 'S'
          WHERE z.nro_boleta = r_retencion.nro_documento
            AND z.nro_cuenta = r_retencion.nro_cuenta
            AND z.cod_retencion = r_retencion.cod_retencion
            AND z.liberado = 'N'
            AND z.fec_final = r_retencion.fec_final;
      ELSIF v_cod_transaccion = 560 THEN
         --  Plaza Extranjera
         UPDATE ge_che_exterior d
            SET d.liberado = 'S'
          WHERE d.nro_boleta = r_retencion.nro_documento
            AND d.nro_cuenta = r_retencion.nro_cuenta
            AND d.cod_retencion = r_retencion.cod_retencion
            AND d.liberado = 'N'
            AND d.fec_final = r_retencion.fec_final;
      END IF;
   END;
-- Verifica Cantidad Exento de Cargo.
PROCEDURE pr_can_chq_exentos
 (p_cod_tasa           in ge_tasas.cod_tasa%type
  ,p_cod_modulo        in ge_cuentas.cod_modulo%type
  ,p_cod_modalidad     in ge_cuentas.cod_modalidad%type
  ,p_cod_sub_modalidad in ge_cuentas.cod_sub_modalidad%type
  ,p_cod_oficina       in ge_cuentas.cod_oficina%type
  ,p_cod_moneda        in ge_cuentas.cod_moneda%type
  ,p_fecha             in date
  ,p_cantidad          out ge_tas_fechas.val_tasa%type
 )
 IS
BEGIN
  BEGIN
    v_sub := 'pr_can_chq_exentos:'||p_cod_tasa||','||p_cod_modulo||','||p_cod_modalidad||','||p_cod_sub_modalidad
    ||','||p_cod_oficina||','||p_cod_moneda||','||p_fecha||'..';
    SELECT val_tasa
      INTO p_cantidad
      FROM ge_tas_fechas a
     WHERE cod_modulo = p_cod_modulo
       AND cod_modalidad = p_cod_modalidad
       AND nvl(cod_sub_modalidad,-1) = nvl(p_cod_sub_modalidad,-1)
       AND nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
       AND nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
       AND cod_tasa = p_cod_tasa
       AND fec_vigencia =(SELECT MAX(fec_vigencia)
                            FROM ge_tas_fechas b
                           WHERE b.cod_modulo        = a.cod_modulo
                             AND b.cod_modalidad     = a.cod_modalidad
                             AND nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
                             AND nvl(b.cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
                             AND nvl(b.cod_moneda,nvl(p_cod_moneda,'x'))  = nvl(p_cod_moneda,'x')
                             AND cod_tasa = p_cod_tasa
                             AND fec_vigencia <= p_Fecha);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_cantidad := 0;
    WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20003,SQLERRM||' Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                               ' - para '||p_cod_moneda||' '||p_Fecha);
  END;
END;
--CROEFEBCO-28: Mejoras en la Operativa de Efectivo
--Procesar Liberacion de Retencion--
PROCEDURE LP_PRO_LIB_RETENCION IS
BEGIN
   v_sub := 'LP_PRO_LIB_RETENCION';
   v_mue_error := p_mue_error;
   IF nvl(pae_cnf.g_programa, 'X') = 'GPPROFIN' THEN
      v_mue_error := 'N';
   END IF;

   IF p_cta_desde IS NULL THEN
      v_cta_desde := '0';
   ELSE
      v_cta_desde := p_cta_desde;
   END IF;
   IF p_cta_hasta IS NULL THEN
     -- DYDMR-5324 NAF 01/2017
     -- si se recibe una cta en p_cta_desde se utiliza esta misma cta
     IF p_cta_desde IS NULL THEN
        v_cta_hasta := '999999999999999';
     ELSE
        v_cta_hasta := p_cta_desde;
     END IF;
   ELSE
      v_cta_hasta := p_cta_hasta;
   END IF;

   v_cod_mod_padre := 3;
   v_cod_mad_padre := 31;
   v_cod_usuario   := nvl(p_cod_usuario,USER);
   v_fec_actual    := pag_cal.fu_obt_fec_actual(3);
   v_hora          := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
   v_nro_secuencia := nvl(pae_cnf.g_nro_secuencia, -999);
   IF c_ah_retenciones%ISOPEN THEN
      CLOSE c_ah_retenciones;
   END IF;
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   OPEN c_ah_retenciones;
   LOOP
      FETCH c_ah_retenciones
         INTO r_retencion;
      EXIT WHEN c_ah_retenciones%NOTFOUND;
     --DYDMR-8743 - Incidencia SAU - Cobro de Comisión Deposito Cheques
      --contar liberaciones anteriores antes de procesar.
      IF r_retencion.cod_retencion = 4 THEN
        begin
          --cheque plaza extranjera
          select nvl(count(*), 0)
            into v_exi_lib_anterior
            from ge_che_exterior
           where nro_boleta = r_retencion.nro_documento
             and nro_cuenta = r_retencion.nro_cuenta
             and cod_moneda in (pag_gen.fu_obt_mon_fuerte, 'EUR')
             and liberado = 'S';
        exception
          when no_data_found then
            v_exi_lib_anterior := 0;
        end;
      else
        begin
          --cheque plaza local
          select nvl(count(*), 0)
            into v_exi_lib_anterior
            from cc_che_enviados
           where nro_boleta = r_retencion.nro_documento
             and nro_cuenta = r_retencion.nro_cuenta
             and cod_moneda in (pag_gen.fu_obt_mon_fuerte, 'EUR')
             and liberado = 'S';
        exception
          when no_data_found then
            v_exi_lib_anterior := 0;
        end;
      end if;
      --
      -- Se aumenta la hora 1 segundo, porque cuando se reversa lo hace por el remanente total de lo liberado en ese entonces
      if r_retencion.cod_modulo = 6 then
        -- v_hora := pag_gen.fu_obt_sig_segundo(v_hora);  DYDMR-8168 Abr/2018
         v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
      End If;
      v_nro_cuenta := r_retencion.nro_cuenta; -- Desarrollo interno. 22/07

      /* 28/02/2014 PN DI: Se guarda el mod y mad pader de ah_retenciones*/
      v_cod_mod_padre   := r_retencion.cod_modulo;
      v_cod_mad_padre   := r_retencion.cod_modalidad;
      /*14/11/2014 VV: Actualizar el saldo retenido de forma correcta*/
      IF nvl(p_mto_detalle,0) <> 0 and p_mto_detalle <> r_retencion.sal_retenido then
         r_retencion.sal_retenido := nvl(p_mto_detalle,0);
         v_act_liberado := 'N';
      END IF;
      IF r_retencion.cod_retencion = 0 THEN
         --Cheque ntro. banco
         v_cod_transaccion := 565;
         /* 28/02/2014 PN DI: Se comenta debido a que las siguientes retenciones
                              toma los valores anteriores y ocasiona un error de
                              fk de mod y mad padres, debido a que no se limpian
                              estos valores
         v_cod_mod_padre   := r_retencion.cod_modulo;
         v_cod_mad_padre   := r_retencion.cod_modalidad;*/
      ELSE

         IF r_retencion.cod_retencion = 4 THEN
            --Cheque plaza extranjejera
            v_cod_transaccion := 560;
            v_gen_cargo       := 'S';
         ELSE
            -- Solo para esta transaccion debe generar el cargo.
            v_cod_transaccion := 515;
            v_gen_cargo       := 'S';
         END IF;
      END IF;
      v_encontro := 'N';
      --Verificar los cheques cargo otros bancos en moneda extranjera que esten todos
      --confirmados
      v_existe := 'N';
      IF r_retencion.cod_moneda <> v_cod_mon_local AND
         r_retencion.cod_retencion NOT IN (0, 7, 8) THEN
         IF r_retencion.detallado = 'N' THEN
            IF p_cta_desde IS NOT NULL THEN
               raise_application_error(-20000,
                                       'Deposito ' || r_retencion.nro_documento ||
                                        ' no fue aun detallado. No se puede liberar');
            END IF;
            v_existe := 'S';
         ELSIF v_mue_error = 'S' THEN
            BEGIN
              SELECT 'S'
                INTO v_existe
                FROM (SELECT 'S' --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
                         FROM ge_che_exterior
                        WHERE cod_moneda    = v_cod_mon_fuerte
                          AND estado     IN ('I', 'E')
                          AND nro_boleta   = r_retencion.nro_documento
                          AND cod_retencion = r_retencion.cod_retencion
                          AND nro_cuenta   = r_retencion.nro_cuenta
                       UNION
                       SELECT 'S'
                         FROM cc_che_enviados
                        WHERE cod_moneda    = v_cod_mon_fuerte
                          AND estado     IN ('I', 'E')
                          AND nro_boleta   = r_retencion.nro_documento
                          AND cod_retencion = r_retencion.cod_retencion
                          AND cod_moneda  = 'GS'  -- CRO-MB-01/2015: Se agrega filtro para controlar solo GS. y no Dólares
                          AND nro_cuenta = r_retencion.nro_cuenta)
                WHERE rownum = 1;

               IF v_existe = 'S' AND v_mue_error = 'S' THEN
                  raise_application_error(-20001,
                                          'Existen cheques que no han sido confirmados. Cuenta: ' ||
                                           r_retencion.nro_cuenta || ' Boleta: ' ||
                                           r_retencion.nro_documento);
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  v_existe := 'N';
            END;
         END IF;
      END IF;
      IF (r_retencion.cod_modulo = 3 AND r_retencion.cod_modalidad in (31,334) AND v_existe = 'N') THEN
         lp_act_sal_ret_vista;
         -- Actualiza la retención que ya fue liberada
         ---------------------------------------------
         IF v_encontro = 'S' THEN
            UPDATE ah_retenciones
               SET liberado     = v_act_liberado,
                   sal_retenido = sal_retenido - r_retencion.sal_retenido
             WHERE ROWID = r_retencion.fila;
            lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
         END IF;
      ELSIF (r_retencion.cod_modulo = 3 AND r_retencion.cod_modalidad = 32 AND v_existe = 'N') THEN
         lp_act_sal_ret_plazo;
         -- Actualiza la retención que ya fue liberada
         ---------------------------------------------
         IF v_encontro = 'S' THEN
            UPDATE ah_retenciones
               SET liberado     = v_act_liberado,
                   sal_retenido = sal_retenido - r_retencion.sal_retenido
             WHERE ROWID = r_retencion.fila;
            lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
         END IF;
      ELSIF (r_retencion.cod_modulo = 3 AND r_retencion.cod_modalidad IN (33, 34, 35, 36) AND
            v_existe = 'N') THEN
         lp_act_sal_ret_certi;
         -- Actualiza la retención que ya fue liberada
         ---------------------------------------------
         IF v_encontro = 'S' THEN
            UPDATE ah_retenciones
               SET liberado     = v_act_liberado,
                   sal_retenido = sal_retenido - r_retencion.sal_retenido
             WHERE ROWID = r_retencion.fila;
            lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
         END IF;
      ELSIF r_retencion.cod_modalidad = 41 AND v_existe = 'N' THEN
         /* Ya se libera los de modalidad 42*/
         -- And R_RETENCION.COD_MODALIDAD = 41) THEN
         lp_act_sal_ret_cte;
         -- Actualiza la retención que ya fue liberada
         ---------------------------------------------
         IF v_encontro = 'S' THEN
            UPDATE ah_retenciones
               SET liberado     = v_act_liberado,
                   sal_retenido = sal_retenido - r_retencion.sal_retenido
             WHERE ROWID = r_retencion.fila;
            lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
         END IF;
      ELSIF r_retencion.cod_modulo = 4 AND r_retencion.cod_modalidad <> 41 AND v_existe = 'N' THEN
         /* Ya se libera los de modalidad 42,43, 44, ...*/
         lp_act_sal_ret_ban;
         -- Actualiza la retención que ya fue liberada
         ---------------------------------------------
         IF v_encontro = 'S' THEN
            UPDATE ah_retenciones
               SET liberado     = v_act_liberado,
                   sal_retenido = sal_retenido - r_retencion.sal_retenido
             WHERE ROWID = r_retencion.fila;
            lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
         END IF;
      ELSIF (r_retencion.cod_modulo = 5) AND v_existe = 'N' THEN
         -- Tarjetas. generacion de registros procesos del dia --
         --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
     declare
            v_tipo varchar2(1);
         BEGIN
            select tipo
            into v_tipo
            from ba_personas b, ge_cta_clientes g
            where g.nro_cuenta = r_retencion.nro_cuenta
              and g.relacion      = 'P'
              and b.cod_persona  = g.cod_persona;
            if v_tipo = 'J' then  -- Si es juridica la cuenta, se busca uno de los adicionales
        SELECT t.nro_tarjeta
          INTO v_nro_tarjeta
          FROM ta_tarjetas t, ge_cta_clientes g
         WHERE t.nro_cuenta  = r_retencion.nro_cuenta
           AND t.nro_cuenta  = g.nro_cuenta
           AND t.cod_persona = g.cod_persona
           AND vigente       = 'S'
           and relacion    <> 'P'
           and rownum      = 1;
            else -- es fisica la cuenta, se busca la tarjeta del principal
               select t.nro_tarjeta into v_nro_tarjeta
               from ta_tarjetas t, ge_cta_clientes g
               where t.nro_cuenta  = r_retencion.nro_cuenta
                 and t.nro_cuenta  = g.nro_cuenta
                 and t.cod_persona = g.cod_persona
                 and vigente      = 'S'
                 and relacion      = 'P'
                 and rownum      = 1;
            end if;
         EXCEPTION
            --- ajuste temporal 04-04-07
            WHEN no_data_found THEN
               BEGIN
                  SELECT t.nro_tarjeta
                    INTO v_nro_tarjeta
                    FROM ta_tarjetas t
                   WHERE t.nro_cuenta = r_retencion.nro_cuenta
                     AND vigente = 'S'
                     AND rownum = 1;
               EXCEPTION
                  WHEN no_data_found THEN
                     -- JIRA-1739
                     SELECT t.nro_tarjeta
                       INTO v_nro_tarjeta
                       FROM ta_tarjetas t
                      WHERE t.nro_cuenta = r_retencion.nro_cuenta
                        AND rownum = 1;
                  WHEN OTHERS THEN
                     raise_application_error(-20001, r_retencion.nro_cuenta || SQLERRM);
               END;
               --- hasta aquí
            WHEN OTHERS THEN
               raise_application_error(-20000, r_retencion.nro_cuenta || SQLERRM);
         END;
         --DYDMR-2803 - Envío de pagos duplicados a Bancard - SC 24812
         IF v_act_liberado = 'S' then
            pat_val.G_PROCESO := 'PRA_LIB_RETENCION'; -- DYDMR-3085 GC 24/02/2016 se agrega variable global para limpiar en el trigger ta_ta_cobros
            INSERT INTO ta_cobros
               (nro_cuenta, nro_tarjeta, monto,
                estado, observacion,
                fec_proceso, fec_valor, hora,
                est_envio) -- DYDMR-2936 ITGF - Pago de Tarjeta Duplicados SC - 25203
            VALUES
               (r_retencion.nro_cuenta, v_nro_tarjeta, r_retencion.monto,
               'P', 'Procesado por Liberacion de Ret.',
                v_fec_actual, r_retencion.fec_inicio,
                v_hora, --DYDMR-728 Reversion cobro tarjeta de credito SC - 4685
                'P'); -- DYDMR-2936 ITGF - Pago de Tarjeta Duplicados SC - 25203
         end if;
         -- actualiza la retencion que ya fue liberada--------------
         IF SQL%FOUND THEN
            v_encontro := 'S';
            UPDATE ah_retenciones
               SET liberado     = v_act_liberado,
                   sal_retenido = sal_retenido - r_retencion.sal_retenido
             WHERE ROWID = r_retencion.fila;
            lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
         END IF;
         v_cod_moneda := v_cod_mon_local;
         --------------------------------------------------------------
      ELSIF r_retencion.cod_modulo = 9 AND v_existe = 'N' THEN
         -- Actualiza la retención que ya fue liberada-----------------
         UPDATE ah_retenciones
            SET liberado     = v_act_liberado,
                sal_retenido = sal_retenido - r_retencion.sal_retenido
          WHERE ROWID = r_retencion.fila;
         --------------------------------------------------------------
         v_cod_moneda := v_cod_mon_local;
         lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
      ElsIf (r_retencion.cod_modulo = 6) and v_existe = 'N' THEN
             if  nvl(pae_cnf.G_PROGRAMA, 'X') <> ('CMCHDECA') Then
                 declare
                   v_cuo_minima    pr_cuotas.nro_cuota%type;
                   v_cuo_maxima    pr_cuotas.nro_cuota%type;
                   v_estado        varchar2(1);
                 Begin
                  begin
                     v_cod_tra_padre := null;
                     Select nvl(min(a.nro_cuota),0), nvl(max(a.nro_cuota),0), b.cod_tra_padre, a.estado
                       into v_cuo_minima           , v_cuo_maxima           , v_cod_tra_padre, v_estado
                       From pr_cob_cuo_otr_bco a, pr_movimientos_his b
                      where a.nro_cuenta  = r_retencion.nro_cuenta
                        and a.nro_boleta  = r_retencion.nro_documento
                        and a.nro_boleta  = b.nro_documento
                        and a.estado      in ('C','R')
                        and a.fec_cobro   = r_retencion.fec_final
                        and a.nro_cuenta  = b.nro_cuenta
                        and a.fec_proceso = b.fecha
                        and b.reversado   = 'N'
                        and b.cod_tra_padre in (359, 360, 361, 362)
                      Group by b.cod_tra_padre, a.estado;
                     exception
                       when no_data_found then
                          ----DYDMR-9818 Incidencia SAU - ITGF-Error cierre 30/10/18
                           v_cod_tra_padre := null;
                           Select nvl(min(a.nro_cuota),0), nvl(max(a.nro_cuota),0), b.cod_tra_padre, a.estado
                             into v_cuo_minima           , v_cuo_maxima           , v_cod_tra_padre, v_estado
                             From pr_cob_cuo_otr_bco a, ge_movimientos b
                            where a.nro_cuenta  = r_retencion.nro_cuenta
                              and a.nro_boleta  = r_retencion.nro_documento
                              and a.nro_boleta  = b.nro_documento
                              and a.estado      in ('C','R')
                              and a.fec_cobro   = r_retencion.fec_final
                              and a.nro_cuenta  = b.nro_cuenta
                              and a.fec_proceso = b.fecha
                              and b.reversado   = 'N'
                              and b.cod_tra_padre in (359, 360, 361, 362)
                            Group by b.cod_tra_padre, a.estado;
                      end;

                     IF SQL%FOUND and v_cuo_minima > 0 and v_cuo_maxima > 0 THEN
                        v_encontro := 'S';
                        If v_cod_tra_padre = 359 and v_estado = 'C' Then
                           pap_pre.pr_can_prestamo(r_retencion.nro_cuenta,
                                                   r_retencion.monto,
                                                   'N', --- Se pidio autorización
                                                   r_retencion.cod_ofi_origen,
                                                   'T', -- Tipo de Cancelación Total
                                                   v_fec_actual,
                                                   v_hora,
                                                   v_nro_secuencia,
                                                   null,
                                                   null,
                                                   null,
                                                   'N' );
                        Elsif v_cod_tra_padre = 362 and v_estado = 'C' Then
                           pap_pre.pr_cob_prestamo(r_retencion.nro_cuenta,
                                                   r_retencion.monto     ,
                                                   'N'                   ,
                                                   r_retencion.cod_ofi_origen,
                                                   v_cuo_minima,
                                                   v_cuo_maxima,
                                                   'CANCELACION PARCIAL '||r_retencion.nro_cuenta,
                                                   v_fec_actual,
                                                   v_hora,
                                                   v_nro_secuencia,
                                                   362,
                                                   r_retencion.cod_modulo,
                                                   r_retencion.cod_modalidad,
                                                   'P',
                                                   null,
                                                   null,
                                                   'N');
                        Elsif v_estado = 'C' Then
                            pap_pre.pr_cob_prestamo(r_retencion.nro_cuenta,
                                                    r_retencion.monto,
                                                    'N',
                                                    r_retencion.cod_ofi_origen,
                                                    v_cuo_minima,
                                                    v_cuo_maxima,
                                                    'Pago de Cuota',
                                                    v_fec_actual,
                                                    v_hora,
                                                    v_nro_secuencia,
                                                    360,
                                                    r_retencion.cod_modulo,
                                                    r_retencion.cod_modalidad,
                                                    'N',
                                                    null,
                                                    null,
                                                    'N' );
                        End IF;
                        v_encontro := 'S';
                        UPDATE ah_retenciones
                           SET liberado     = v_act_liberado,
                               sal_retenido = sal_retenido - r_retencion.sal_retenido
                         WHERE ROWID        = r_retencion.fila;
                        If v_estado = 'C' Then
                            update pr_cob_cuo_otr_bco a
                               set a.estado      = 'P'
                             where a.nro_cuenta  = r_retencion.nro_cuenta
                               and a.nro_boleta  = r_retencion.nro_documento
                               and a.estado      = v_estado
                               and a.fec_cobro   = r_retencion.fec_final;
                        Else
                           /*SI es por cobro de préstamos con cheque cargo otros bancos, y hubo una devolución,
                            debe usar la transaccion 1515 */
                            v_cod_transaccion := 1515;
                        End IF;
                        lp_act_est_cheque; --Actualiza detalle de cheques <<EF,08/09/2009>>
                     END IF;
               End;
             End If;
      END IF;
      --- Actualiza diario ---
      ------------------------
      IF v_encontro = 'S' AND v_existe = 'N' THEN
         v_sub := 'pag_gen.pr_ins_ge_movimiento';
         IF v_nro_secuencia > 990 THEN
          --  v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_hora  := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
            v_nro_secuencia := -999;
         END IF;



         v_nro_secuencia       := v_nro_secuencia + 1;
         r_gmovi.cod_usuario   := v_cod_usuario;
         r_gmovi.hora          := nvl(p_hor_movimiento,v_hora);
         r_gmovi.nro_secuencia := v_nro_secuencia;
         r_gmovi.cod_modulo    := r_retencion.cod_modulo;
         r_gmovi.cod_modalidad := r_retencion.cod_modalidad;
         r_gmovi.cod_oficina   := r_retencion.cod_oficina;
         IF r_retencion.cod_modulo = 9 THEN
            r_gmovi.nro_cuenta := NULL;
         ELSE
            r_gmovi.nro_cuenta := r_retencion.nro_cuenta;
         END IF;
         r_gmovi.cod_moneda      := r_retencion.cod_moneda;
         r_gmovi.fec_valor       := r_retencion.fec_inicio;
         r_gmovi.fecha           := v_fec_actual;
         If r_retencion.cod_modulo = 6 Then
            r_gmovi.cod_tra_padre  := v_cod_tra_padre;
         Else
            r_gmovi.cod_tra_padre   := v_cod_transaccion;
         End If;
         r_gmovi.cod_transaccion := v_cod_transaccion;
         r_gmovi.nro_documento   := r_retencion.nro_documento;
         r_gmovi.monto           := r_retencion.sal_retenido;
         r_gmovi.cod_retencion   := r_retencion.cod_retencion;
         r_gmovi.estado          := 'N';
         If r_retencion.cod_modulo = 6 Then
            r_gmovi.cod_ofi_origen  := r_retencion.Cod_Ofi_Origen;
         Else
            r_gmovi.cod_ofi_origen  := r_retencion.cod_oficina;
         End if;
         r_gmovi.reversado       := 'N';
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.protegido       := 'N';
         r_gmovi.cod_mod_padre   := v_cod_mod_padre;
         r_gmovi.cod_mad_padre   := v_cod_mad_padre;
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         pae_cnf.g_nro_secuencia := v_nro_secuencia;
      END IF;

      --> A los cobros de préstamos con cheque cargo otros bancos en USD NO se le cobrarán cargos.-
      IF v_gen_cargo = 'S' AND v_encontro = 'S' AND v_existe = 'N' and r_retencion.Cod_Modulo not in (6) THEN
         -- Realizar Cobro de Cargos para CHQ USD si corresponde
         IF r_retencion.cod_retencion = 4 THEN
            v_tra_cargo := 1178; --3,30
         ELSIF r_retencion.cod_retencion IN (1, 2, 3, 9) THEN
            v_tra_cargo := 5021; --1,10
         ELSE
            v_tra_cargo := 0;
         END IF;
         v_can_che_exonerado := 0;
         pr_can_chq_exentos(303, r_retencion.cod_modulo, r_retencion.cod_modalidad,
                            fug_obt_cod_sub_modalidad(r_retencion.nro_cuenta), r_retencion.cod_oficina,
                            R_retencion.cod_moneda, v_fec_actual, v_can_che_exonerado);
         v_can_che := 0;
         IF NOT nvl(v_tra_cargo, 0) = 0 AND
            R_retencion.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR') and
            nvl(v_can_che_exonerado,0) > 0 THEN
            pae_cnf.g_nro_secuencia := v_nro_secuencia;
            --DYDMR-6635 - Incidencia SAU - ITGF - Inconveniente Cobro Deposito Cheque
            ---Cantidad de cheques Plaza Extranjera - depositados en el mes
            BEGIN
              SELECT COUNT(*)
                INTO v_can_che_mes_pe
                FROM ah_retenciones b, ge_che_exterior e
               WHERE b.cod_modulo = r_retencion.Cod_Modulo
                 AND b.cod_modalidad = r_retencion.cod_modalidad
                 AND b.nro_cuenta = r_retencion.Nro_Cuenta
                 AND b.cod_ofi_origen = r_retencion.Cod_Ofi_Origen
                 and b.nro_documento = e.nro_boleta
                 AND b.nro_cuenta = e.nro_cuenta
                 AND b.liberado = 'S'
                 AND b.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR')
                 AND b.fec_final >= v_fec_inicial
                 AND b.fec_final <= v_fec_actual;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_can_che_mes_pe := 0;
              WHEN OTHERS THEN
                v_can_che_mes_pe := 0;
            END;
            --DYDMR-6635 - Incidencia SAU - ITGF - Inconveniente Cobro Deposito Cheque
            ---Cantidad de cheques Plaza Local - depositados en el mes
            BEGIN
              SELECT COUNT(*)
                INTO v_can_che_mes_pl
                FROM ah_retenciones b, cc_che_enviados e
               WHERE b.cod_modulo = r_retencion.Cod_Modulo
                 AND b.cod_modalidad = r_retencion.cod_modalidad
                 AND b.nro_cuenta = r_retencion.Nro_Cuenta
                 AND b.cod_ofi_origen = r_retencion.Cod_Ofi_Origen
                 and b.nro_documento = e.nro_boleta
                 AND b.nro_cuenta = e.nro_cuenta
                 AND b.liberado = 'S'
                 AND b.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR')
                 AND b.fec_final >= v_fec_inicial
                 AND b.fec_final <= v_fec_actual;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_can_che_mes_pl := 0;
              WHEN OTHERS THEN
                v_can_che_mes_pl := 0;
            END;
        END IF;

         --DYDMR-6635 - Incidencia SAU - ITGF - Inconveniente Cobro Deposito Cheque
         IF r_retencion.cod_retencion = 4 THEN
             SELECT COUNT(*)
               INTO v_can_cheques
               FROM ge_che_exterior a
              WHERE a.nro_boleta = r_retencion.nro_documento
                AND a.nro_cuenta = r_retencion.nro_cuenta
                AND a.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR'); -- DYDMR-7484
                --AND a.lib_posterior = 'N'; DYDMR-6887 - Incidencia SAU - ITGF - Cobro Comisión por depósito de cheques en USD
         ELSE
             SELECT COUNT(*)
               INTO v_can_cheques
               FROM cc_che_enviados a
              WHERE a.nro_boleta = r_retencion.nro_documento
                AND a.nro_cuenta = r_retencion.nro_cuenta
                AND a.cod_moneda in (pag_gen.fu_obt_mon_fuerte,'EUR'); -- DYDMR-7484
                --AND a.lib_posterior = 'N'; DYDMR-6887 - Incidencia SAU - ITGF - Cobro Comisión por depósito de cheques en USD
         END IF;

         --DYDMR-8743 Incidencia SAU - Cobro de Comisión Deposito Cheques
         -- Se descuenta los cheques liberados anticipadamente de la boleta / cuenta
         v_can_cheques := v_can_cheques - v_exi_lib_anterior;
         --DYDMR-6635 - Incidencia SAU - ITGF - Inconveniente Cobro Deposito Cheque
         ---Calculo de Cantidad de Cheques a Cobrar
         v_tot_cheques := (v_can_cheques + v_can_che_mes_pl + v_can_che_mes_pe) - v_can_che_exonerado;

         If v_tot_cheques > v_can_che_exonerado then
            If (v_can_che_mes_pe + v_can_che_mes_pl) >= v_can_che_exonerado then
               v_can_che_cobrar := v_can_cheques;
            else
               v_can_che_cobrar := v_tot_cheques;
            End if;
         Else
            v_can_che_cobrar := 0;
         End if;

         if v_can_che_cobrar > 0 and r_retencion.cod_moneda in (pag_gen.fu_obt_mon_fuerte, 'EUR') then -- DYDMR-7484
            v_sub := 'prg_cob_car_che_usd';
            prg_cob_car_che_usd(r_retencion.nro_cuenta, v_tra_cargo, null,
                                r_retencion.nro_documento, v_can_che_cobrar);
            v_nro_secuencia := pae_cnf.g_nro_secuencia;
         END IF;
      end if;
   end loop;
   --Notificaciones Fase 3
   v_sub := 'paw_not.fu_che_lib_fondos';
   v_ret := paw_not.fu_che_lib_fondos(r_retencion.nro_cuenta,r_retencion.monto,r_retencion.cod_moneda,null,r_retencion.fec_inicio);

END;

--CROEFEBCO-28: Mejoras en la Operativa de Efectivo
--- Inicio del proceso principal
BEGIN
   v_mue_error := p_mue_error;
   v_gen_cargo := 'N';
   --pat_val.G_PROCESO := 'PRA_LIB_RETENCION'; DYDMR-3085 GC 24/02/2016 Se lleva la variable global a la linea 548
   If pae_cnf.G_PROGRAMA in ('GPPROFIN', 'AMLICHNB') then
      v_mue_error := 'N';
   End If;
   --Actualiza el estado de los movimientos pendientes por pedidos de Autorizacioón por Sobregiro CROAPARS-1 - 07/2015 V.V.
   --Esto solo debe hacer en el cierre.
   If pae_cnf.G_PROGRAMA  = 'GPPROFIN' then
      For gmov in g_mov_pendientes loop
          v_lugar := 'pal_cam pr_act_movimientos';
          pal_cam.pr_act_movimientos(gmov.cod_usuario,
                                     gmov.fecha,
                                     gmov.hora,
                                     'N',  -- pasa a 'N-normal el movimiento
                                     gmov.nro_caja);
          
          -- para los cheques hibridos actualizamos en la tabla                            
          if gmov.cod_tra_padre = 345 then
             update cc_che_hibridos h
               set h.situacion = 'C'
              where h.fecha = gmov.fecha
                and h.cod_usuario = gmov.cod_usuario
                and h.hora = gmov.hora
                and h.situacion ='P';
          end if;                                      
          --
      End Loop;
   End If;
   --
   If p_cta_desde is null then
      v_cta_desde := '0';
   Else
      v_cta_desde := p_cta_desde;
   End If;
   If p_cta_hasta is null then
      -- DYDMR-5324 NAF 01/2017
      -- si se recibe una cta en p_cta_desde se utiliza esta misma cta
      IF p_cta_desde IS NULL THEN
         v_cta_hasta := '999999999999999';
      ELSE
         v_cta_hasta := p_cta_desde;
      END IF;
   Else
      v_cta_hasta := p_cta_hasta;
   End If;
   v_cod_mod_padre := 3;
   v_cod_mad_padre := 31;
   v_cod_usuario := nvl(p_cod_usuario,user);
   v_fec_actual := pag_cal.fu_obt_fec_actual(3);
   v_hora := nvl(p_hor_movimiento,fug_ini_hora(sysdate,'hh24:mi:ss'));
   v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
   v_nro_secuencia := nvl(pae_cnf.g_nro_secuencia, -999);
   if v_cta_desde <> v_cta_hasta then
      if c_ah_retenciones%isopen then
         close c_ah_retenciones;
      END IF;
      open c_ah_retenciones;
      loop
         fetch c_ah_retenciones into r_retencion;
         exit when c_ah_retenciones%notfound;
           v_lugar := 'LP_PRO_LIB_RETENCION 1 - cta ' || r_retencion.nro_cuenta;
           LP_PRO_LIB_RETENCION;
   END LOOP;
   IF c_ah_retenciones%ROWCOUNT = 0 THEN
      v_mensaje := ' No se encontraron retenciones para liberar ...';
      end if;
   else
      if c_ah_ret_x_cuenta%isopen then
         close c_ah_ret_x_cuenta;
      end if;
      open c_ah_ret_x_cuenta;
      loop
         fetch c_ah_ret_x_cuenta into r_retencion;
         exit when c_ah_ret_x_cuenta%notfound;
           v_lugar := 'LP_PRO_LIB_RETENCION 2 - cta ' || r_retencion.nro_cuenta;
           LP_PRO_LIB_RETENCION;
      end loop;
      if c_ah_ret_x_cuenta%rowcount = 0 then
         v_mensaje := ' No se encontraron retenciones para liberar ...'   ;
      end if;
   END IF;
   pae_cnf.g_nro_secuencia := nvl(v_nro_secuencia, 0); -- CROLIANC-4 AT

     --Agregar validacion para eliminar el parametro si fue cargado--
       if v_val_parametro is not null then
         delete from ge_par_dinamicos x
          where x.parametro = 'NRO_CTA_EXC_LIB_RET';
      end if;
EXCEPTION -- Desarrollo interno. 22/07
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN

         If pae_cnf.G_PROGRAMA  = 'GPPROFIN' then
            raise_application_error(-20001, ' Error en ' || v_lugar || '-' || v_sub || ' - ' || SQLERRM);
         else
           	RAISE;
         end if;
      ELSE
         raise_application_error(-20001, ' Error en cta  ' || v_nro_cuenta || '-' || SQLERRM);
      END IF;
END;
/

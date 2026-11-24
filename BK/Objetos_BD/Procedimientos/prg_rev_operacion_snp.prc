CREATE OR REPLACE PROCEDURE IT.PRG_REV_OPERACION_SNP
(
   p_fecha             IN ge_movimientos.fecha%TYPE,
   p_hora              IN ge_movimientos.hora%TYPE,
   p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
   p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
   p_cod_mad_padre     IN ge_movimientos.cod_mad_padre%TYPE,
   p_cod_tra_padre     IN ge_movimientos.cod_tra_padre%TYPE,
   p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE DEFAULT USER,
   p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE DEFAULT to_char(SYSDATE, 'HH24:MI:SS'),
   p_es_nocturno       IN VARCHAR2 DEFAULT 'N',
   p_concepto          IN VARCHAR2 DEFAULT NULL,
   p_nro_documento     IN ge_movimientos.nro_documento%TYPE DEFAULT NULL,
   p_mov_orden         IN VARCHAR2 DEFAULT NULL
) IS

   r_gmovi              ge_movimientos%ROWTYPE;
   v_es_nocturno        VARCHAR2(1);
   v_est_modulo         ba_modulos.estado%TYPE;
   v_fec_actual         ge_calendarios.fec_actual%TYPE;
   v_ope_pendiente      VARCHAR2(1) := 'N';
   v_cod_gru_iva        ge_gru_transacciones.cod_gru_transaccion%TYPE := fug_obt_pardinamico('COD_GRU_TRA_IVA');
   v_cod_tra_pago        ge_transacciones.Cod_Transaccion%type := 2602;
   v_nro_documento       ge_movimientos.nro_documento%TYPE;
   v_est_transferencia            varchar2(10);
   v_sit_transferencia            varchar2(10);
   v_hora                ge_movimientos.hora%type;
   v_afecta             varchar2(1):= (fug_obt_pardinamico('COD_MOD_EST_AFECTA',p_cod_mod_padre));-- C.D Fase II
   v_existe              varchar2(1);
   v_nro_referencia      lc_transferencias.nro_referencia%type;
   v_mto_credito         ge_movimientos.monto%TYPE;
   v_mov_orden           VARCHAR2(10) := nvl(p_mov_orden, 'DESC'); -- DYDMR-4088 Julio/2016
   v_exi_movimiento  VARCHAR2(1) := 'N';
   --------------------------------------
   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE
   );
   /* Crea los movimientos para insertarlos en GE_MOVIMIENTOS. */
   PROCEDURE lp_ins_movimientos
   (
      rp_gmovi            IN ge_movimientos%ROWTYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_es_nocturno       IN VARCHAR2 := 'X'
   );

   /* Validar que no permita reversar operaciones de IVA */
   PROCEDURE lp_val_iva(rp_gmovi IN ge_movimientos%ROWTYPE);
   /* Actualiza los movimientos historicos a reversado. */
   PROCEDURE lp_act_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_nro_secuencia     IN ge_movimientos.nro_secuencia%TYPE,
      p_cod_usu_insercion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_cod_modulo        IN ge_movimientos.cod_modulo%TYPE
   );

    FUNCTION lf_obt_hor_max_movimiento
    (
       p_fecha       in date,
       p_hora3        in varchar2,
       p_cod_usuario in varchar2
    ) return varchar2;


   CURSOR cur_gmovi IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado,
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable,
             nro_conciliacion
        FROM ge_movimientos
       WHERE fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND reversado = 'N'
       ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC;
   --
   CURSOR cur_gmono IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado,
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable,
             nro_conciliacion
        FROM ge_movimientos_noc
       WHERE fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND reversado = 'N'
       ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC;

    FUNCTION lf_obt_hor_max_movimiento
    (
       p_fecha       in date,
       p_hora3        in varchar2,
       p_cod_usuario in varchar2
    ) return varchar2 is
    v_hora ge_movimientos.hora%type;
    pragma autonomous_transaction;
    BEGIN
       BEGIN
          SELECT max(v.hora)
            INTO v_hora
            FROM ge_movimientos v
           WHERE (v.fecha, v.referencia, v.cod_usuario) in
                 (SELECT g.fecha, g.referencia, g.cod_usuario
                    FROM ge_movimientos g
                   WHERE G.fecha = p_fecha
                     AND G.hora =  p_hora3
                     AND G.cod_usuario = p_cod_usuario
                     AND g.referencia = v.referencia
                     AND G.referencia IS NOT NULL)
             and v.reversado = 'N'
          group by v.fecha, v.referencia, v.cod_usuario;
       EXCEPTION
          WHEN OTHERS THEN
             v_hora := null;
       END;
       return v_hora;
    END;
   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE
   ) IS
      CURSOR cur_modulos IS
         SELECT fecha,
                hora,
                cod_usuario,
                nro_secuencia,
                fec_valor,
                monto,
                nro_cuenta,
                cod_moneda,
                cod_oficina,
                cod_error,
                cod_retencion,
                fec_fin_retencion,
                est_cuenta,
                estado,
                cod_causa,
                cod_banco,
                cod_ofi_origen,
                concepto,
                cod_tasa,
                val_tasa,
                cod_rubro,
                cod_ref_cambio,
                reversado,
                cod_usu_reversion,
                hor_reversion,
                emi_aviso,
                cod_tra_padre,
                cod_mod_padre,
                cod_mad_padre,
                cod_transaccion,
                cod_modulo,
                cod_modalidad,
                mto_equ_local,
                nro_caja,
                cotizacion,
                cod_bco_central,
                nro_documento,
                nro_documento2,
                nro_documento3,
                nro_documento4,
                protegido,
                cod_autorizacion,
                cod_usu_autorizador,
                usu_insercion,
                fec_insercion,
                usu_modificacion,
                fec_modificacion,
                tip_mov_rubro,
                cod_tip_ope_cambio,
                referencia,
                cod_persona,
                cod_sit_contable,
                nro_conciliacion
           FROM gv_movimientos
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND reversado = 'N'
            AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
          ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC;
   BEGIN
      FOR c1 IN cur_modulos LOOP
            lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
         --AHORRO
         IF c1.cod_modulo = 3 THEN
            UPDATE ah_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- CUENTA CORRIENTE
         ELSIF c1.cod_modulo = 4 THEN
            UPDATE cc_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
          end if;
      END LOOP;
   END;
   /* Validar que no permita reversar operaciones de IVA */
   PROCEDURE lp_val_iva(rp_gmovi IN ge_movimientos%ROWTYPE) IS
      v_existe VARCHAR2(01) := 'N';
   BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ge_transacciones t, ge_gru_transacciones_det g
       WHERE g.cod_gru_transaccion = v_cod_gru_iva
         AND t.cod_modulo = g.cod_modulo
         AND t.cod_modalidad = g.cod_modalidad
         AND t.cod_transaccion = g.cod_transaccion
         AND t.cod_modulo = rp_gmovi.cod_modulo
         AND t.cod_modalidad = rp_gmovi.cod_modalidad
         AND t.cod_transaccion = rp_gmovi.cod_transaccion;
      IF v_existe = 'S' THEN
         raise_application_error(-20001, 'No puede reversar operaciones con IVA de fechas pasadas');
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN too_many_rows THEN
         raise_application_error(-20002, 'No puede reversar operaciones con IVA de fechas pasadas');
   END;


   /* Crea los movimientos para insertarlos en GE_MOVIMIENTOS. */
   PROCEDURE lp_ins_movimientos
   (
      rp_gmovi            IN ge_movimientos%ROWTYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_es_nocturno       IN VARCHAR2 := 'X'
   ) IS

      r_gmovi           ge_movimientos%ROWTYPE;
      v_est_anterior    VARCHAR2(1) := NULL;
      v_fec_cam_est_ant DATE := NULL;
      v_fec_ult_mov_ant DATE := NULL;
      v_hor_ult_mov_ant VARCHAR2(8) := NULL;
      v_afecta             ge_transacciones.afecta%TYPE := 'N';
      v_afe_sal_total      NUMBER := 0;
      v_afe_sal_retenido   NUMBER := 0;
      v_afe_sal_bloqueado  NUMBER := 0;
      v_act_ult_movimiento VARCHAR2(1) := 'N';
      v_tip_movimiento     ge_transacciones.tipo%TYPE;

      /* obtiene datos de la transaccion */
      PROCEDURE pr_obt_tip_transaccion
      (
         p_cod_transaccion IN ge_transacciones.cod_transaccion%TYPE,
         p_cod_modulo      IN ge_transacciones.cod_modulo%TYPE,
         p_cod_modalidad   IN ge_transacciones.cod_modalidad%TYPE,
         p_tipo            OUT VARCHAR2,
         p_afecta          OUT VARCHAR2
      ) IS
      BEGIN
         SELECT tipo, afecta
           INTO p_tipo, p_afecta
           FROM ge_transacciones
          WHERE cod_modulo = p_cod_modulo
            AND cod_modalidad = p_cod_modalidad
            AND cod_transaccion = p_cod_transaccion;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20004,
                                    'Transaccion inexistente ' || to_char(nvl(p_cod_modulo, 0)) || '-' ||
                                     to_char(nvl(p_cod_modalidad, 0)) || '-' ||
                                     to_char(p_cod_transaccion));
         WHEN OTHERS THEN
            raise_application_error(-20005, SQLERRM);
      END;
      --- Obtiene el rubro de reversion
      FUNCTION fl_obt_rub_reversion(p_cod_rubro IN VARCHAR2) RETURN VARCHAR2 IS
         v_rub cb_rubros.cod_rubro%TYPE;
      BEGIN
         BEGIN
            SELECT cod_rub_reversion
              INTO v_rub
              FROM cb_rub_reversiones
             WHERE cod_rubro = p_cod_rubro;
         EXCEPTION
            WHEN OTHERS THEN
               v_rub := NULL;
         END;
         RETURN v_rub;
      END;

      ------------------------------------------------------------------------------
   BEGIN

      -- Traspaso los datos del registro leido en el nuevo
      r_gmovi := rp_gmovi;
      --
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.fec_valor     := p_fecha;
      r_gmovi.cod_usuario   := p_cod_usu_reversion;
      r_gmovi.monto         := rp_gmovi.monto * -1;
      r_gmovi.mto_equ_local := rp_gmovi.mto_equ_local * -1;
      r_gmovi.hora              := p_hor_reversion;
      r_gmovi.reversado         := 'S';
      r_gmovi.hor_reversion     := rp_gmovi.hora;
      r_gmovi.cod_usu_reversion := rp_gmovi.cod_usuario;
      -- Reversion de IVA Facturado
      -- Verificar si el movimiento original fue facturado
      IF pab_iva.fu_mov_facturado(rp_gmovi.fecha, rp_gmovi.hora, rp_gmovi.cod_usuario) THEN
         DECLARE
            v_rub_rev     cb_rubros.cod_rubro%TYPE;
            v_tip_mov_rub ge_movimientos.tip_mov_rubro%TYPE;
         BEGIN
            v_tip_mov_rub := r_gmovi.tip_mov_rubro;
            v_rub_rev     := fl_obt_rub_reversion(nvl(r_gmovi.cod_rubro,
                                                      fub_obt_rub_transaccion(r_gmovi.cod_modulo,
                                                                               r_gmovi.cod_modalidad,
                                                                               r_gmovi.cod_transaccion,
                                                                               r_gmovi.cod_moneda, NULL,
                                                                               NULL, v_tip_mov_rub)));
            IF v_rub_rev IS NOT NULL THEN
               r_gmovi.cod_rubro       := v_rub_rev;
               r_gmovi.tip_mov_rubro   := v_tip_mov_rub;
               r_gmovi.cod_transaccion := NULL;
            END IF;
         END;
      END IF;
      --Insertamos el movimiento
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      -- restauro el estado de la cuenta --
      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.est_cuenta IS NOT NULL AND
         v_est_anterior IS NOT NULL AND r_gmovi.cod_modulo IN (3, 4) THEN
         pag_cta.pr_act_est_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, v_est_anterior,
                                v_fec_cam_est_ant);
      END IF;
      -- retorno el monto del saldo de la cuenta
      IF rp_gmovi.nro_cuenta IS NOT NULL AND
         (rp_gmovi.estado = 'N') AND
          rp_gmovi.monto <> 0 AND r_gmovi.cod_modulo IN (3, 4) THEN

         IF v_fec_ult_mov_ant IS NOT NULL THEN
            v_act_ult_movimiento := 'S'; -- debe actualizar la fecha y hora
         END IF;
         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                   rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);

         ---****************************************
         -- DDSI-212 -- 2017/12 -- Verificar que no se haya insertado como para actualizacion de saldo en batch
         v_exi_movimiento := pag_bat.fu_ver_exi_movimiento(rp_gmovi.nro_cuenta,rp_gmovi.fecha,rp_gmovi.hora,rp_gmovi.cod_usuario,
                                                           rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.monto);
         IF nvl(v_exi_movimiento,'N') = 'N' THEN
            --23/08 Cta.SIPAP - Se ajusta para que no llavee Sipap Cta Interbancaria
            IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad, rp_gmovi.nro_cuenta) = 'N' AND
               r_gmovi.cod_modulo <> 6 and rp_gmovi.cod_modalidad <> 455 THEN
               --solo para 3 y 4 por el momento
               -- cuenta llaveada
               raise_application_error(-20000, 'Cuenta ' || rp_gmovi.nro_cuenta || ' llaveada ');
            END IF;
         END IF;
         IF v_afecta = 'R' THEN
            -- afecta al saldo retenido
            IF v_tip_movimiento = 'C' THEN
               v_afe_sal_total     := r_gmovi.monto;
               v_afe_sal_retenido  := r_gmovi.monto;
               v_afe_sal_bloqueado := 0;
            ELSIF v_tip_movimiento = 'D' THEN
               v_afe_sal_total     := 0;
               v_afe_sal_retenido  := r_gmovi.monto;
               v_afe_sal_bloqueado := 0;
            END IF;
         ELSIF v_afecta IN ('C', 'I', 'S') THEN
            -- afecta al saldo total,capital o interes
            v_afe_sal_total  := r_gmovi.monto;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := 0;
         ELSIF v_afecta = 'B'  THEN
            -- afecta al saldo bloqueado
            v_afe_sal_total     := 0;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := r_gmovi.monto;
         END IF;
         IF nvl(v_afe_sal_total, 0) <> 0 OR nvl(v_afe_sal_retenido, 0) <> 0 OR
            nvl(v_afe_sal_bloqueado, 0) <> 0 THEN
            pag_cta.pr_obt_cuenta(rp_gmovi.nro_cuenta);
            IF nvl(v_exi_movimiento,'N') = 'N' THEN
              --12/03/2018 - Optimizacion - No se actualizara on line SIPAP
              if rp_gmovi.cod_modalidad <> 455 then
                 -- retorno el monto al saldo
                 pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, v_tip_movimiento,
                                       v_fec_ult_mov_ant, v_hor_ult_mov_ant, v_afe_sal_total,
                                       v_afe_sal_retenido, v_afe_sal_bloqueado, NULL,
                                       /* autorizacion pendiente */ v_act_ult_movimiento);
              end if;
            ELSE -- DDSI-212 -- 2017/12 -- Se actualiza el estado en la tabla GE_BAT_MOVIMIENTOS
              UPDATE GE_BAT_MOVIMIENTOS m
                 SET m.est_pro_batch = 'R'
                WHERE m.cod_tra_padre = rp_gmovi.cod_tra_padre
                AND m.fecha = rp_gmovi.fecha
                AND m.monto = rp_gmovi.monto
                AND m.hora = rp_gmovi.hora
                AND m.cod_transaccion = rp_gmovi.cod_transaccion
                AND cod_usuario = rp_gmovi.cod_usuario
                AND nro_cuenta = rp_gmovi.nro_cuenta
                AND m.est_pro_batch = 'N';
            END IF;


         END IF;

      END IF;

      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.estado IN ('P', 'X', 'J') AND --- Los movimientos 'J' no actualizan la cuenta
         rp_gmovi.monto <> 0 AND r_gmovi.cod_modulo IN (3, 4) AND
         (r_gmovi.cod_mod_padre IN (3, 4) ) THEN

         IF v_fec_ult_mov_ant IS NOT NULL THEN
            v_act_ult_movimiento := 'S'; -- debe actualizar la fecha y hora
         END IF;
         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         IF v_tip_movimiento = 'D' THEN
            -- si es un debito
            -- control de llaveo de cuenta DYDMR-3263
            IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad, rp_gmovi.nro_cuenta) = 'N' THEN
              -- cuenta llaveada
              raise_application_error(-20000, 'Cuenta ' || rp_gmovi.nro_cuenta || ' llaveada ');
            END IF;

            -- retorno el monto al saldo
            pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, 'D', rp_gmovi.fecha,
                                   rp_gmovi.hora, 0, 0, rp_gmovi.monto,
                                   -- el saldo bloqueado
                                   NULL, /* autorizacion pendiente */ v_act_ult_movimiento);
         END IF;
      END IF;
      --******************************************************************
      IF rp_gmovi.nro_cuenta IS NOT NULL AND
         rp_gmovi.monto <> 0 AND
         rp_gmovi.cod_tra_padre = 303 AND
         rp_gmovi.cod_modulo = 4 AND
         rp_gmovi.cod_modalidad = 455
      THEN -- Movimientos relacionados a SNP
        declare
            v_nro_referencia ge_snp_transferencias.nro_referencia%type;
            rg_cir           wf_circuitos%rowtype;
            v_ind_circuito   varchar2(1) := 'N';
        begin
            begin

              select t.nro_referencia,t.estado, t.situacion
                into v_nro_referencia,v_est_transferencia,v_sit_transferencia
                from ge_snp_transferencias t
               where t.fecha       = rp_gmovi.fecha
                 and t.hora        = rp_gmovi.hora
                 and t.cod_usuario = rp_gmovi.cod_usuario;

               /* Inicializa las variables de error del PAS_SNP*/
               pas_snp.pr_ini_variables;

               pas_snp.pr_obt_mensaje( v_nro_referencia );
               if pas_snp.fu_obt_cod_error <> 0 then
                  raise_application_error (-20001, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error );
               end if;

            exception
              when no_data_found then
                 raise pas_snp.ex_salir;
              when others then
                 raise_application_error(-20002,'Error al obtener datos de la mensajería. ' ||
                                                'Fec/Hora: ' || to_char(rp_gmovi.fecha,'DD/MM/YYYY') || ' ' || rp_gmovi.hora ||
                                                'Usuario: ' || rp_gmovi.cod_usuario || ', ' || sqlerrm);
            end;

            /*
            || Todos los SWIFTs APROBADOS, pero con situación distinta a CANCELADO, ERROR y LIQUIDADO NO podrán reversarse.
            || Para todos los otros estados (SOLICITADO, VERIFICADO, etc) de la mensajería que no estén con estado APROBADOS podrán reversarse.
            || Si una mensajería ya fue LIQUIDADA se podrá reversar el movimiento, se colocará a la mensajería el estado SOLICITADO y situación
            || PENDIENTE DE AUTORIZACION EN WF
            || Al reversar la operación se intentará cancelar la mensajería asociada y tareas pendientes del Workflow.
            || Si se reversa una mensajería LIQUIDADA se creará otro WorkFlow para su posterior proceso.
            */

            if pas_snp.g_msj.estado = 'A' then
               if nvl(pas_snp.g_msj.situacion,'~') not in ('C','E','L') then
                  raise_application_error(-20003,' No se puede reversar Transferencia Interbancaria con situacion '||nvl(pas_snp.g_msj.situacion,'NULA')||
                                                 ' Fec/Hora: ' || to_char(rp_gmovi.fecha,'DD/MM/YYYY') || ' ' || rp_gmovi.hora ||
                                                 ' Usuario: ' || rp_gmovi.cod_usuario ||
                                                 ' Cod. Mod. Padre: ' || rp_gmovi.cod_mod_padre );
               elsif nvl(pas_snp.g_msj.situacion,'~') = 'L' then
                  -- Se desvincula a la mensajería del movimiento y se levanta nuevamente WF.
                  pas_snp.g_msj.estado      := 'S';
                  pas_snp.g_msj.situacion   := 'I';
                  pas_snp.g_msj.fecha       := null;
                  pas_snp.g_msj.hora        := null;
                  pas_snp.g_msj.cod_usuario := null;
                  v_ind_circuito            := 'S';
                  pas_snp.pr_set_transferencias ( pas_snp.g_msj );
               end if;
            else
               --Si es llamado desde el programa GMSNP202 o GMSNP103, el update se hace a nivel de formulario
               if nvl(pae_cnf.g_programa,'X') not in ('GMSNP202', 'GMSNP103') then
                  pas_snp.g_msj.estado := 'C';
                  pas_snp.pr_set_transferencias ( pas_snp.g_msj );
               end if;
            end if;
            --Cancela el pago a proveedor, en caso de existir..
            update ge_pag_proveedores
                     set estado = 'A'
                   where nro_referencia = pas_snp.g_msj.nro_referencia;

            --Se cancela el circuito
            declare
               v_cod_tip_circuito wf_tip_circuitos.cod_tip_circuito%type;
            begin
              /*Se recupera el circuito generado para la cancelación*/
              select *
                into rg_cir
                from wf_circuitos
               where referencia = pas_snp.g_msj.nro_referencia
                 and estado not in ('C','F');

              --Se actualiza a cancelada las tareas para las tablas
              --wf_cir_tareas y wf_circuitos
              update wf_cir_tareas
                 set estado = 'C'
               where cod_circuito = rg_cir.cod_circuito;
              --
              update wf_circuitos
                 set estado = 'C'
               where cod_circuito = rg_cir.cod_circuito;

              if v_ind_circuito = 'S' then
                 if pas_snp.fu_val_es_enviado( pas_snp.g_msj ) then -- MT Enviado
                    if paw_cir.fu_ini_circuito( 111,
                                                rg_cir.referencia,
                                                rg_cir.cod_persona
                                              ) <> 0 then
                       raise pas_snp.ex_workflow;
                    end if;
                 else -- MT Recibido
                    if paw_cir.fu_ini_circuito( 911,
                                                rg_cir.referencia,
                                                rg_cir.cod_persona
                                              ) <> 0 then
                       raise pas_snp.ex_workflow;
                    end if;
                 end if;
              end if;

            exception
               when pas_snp.ex_workflow then
                  raise_application_error (-20004, 'Error al ejecutar el PAW_CIR.FU_INI_CIRCUITO: '||sqlerrm);
               when no_data_found then
                  if v_ind_circuito = 'S' then
                     if pas_snp.fu_val_es_enviado( pas_snp.g_msj ) then -- MT Enviado
                        if pas_snp.g_msj.cod_msj_swift = 104then
                           v_cod_tip_circuito := pas_snp.fu_obt_cod_tip_cir_workflow( pas_snp.g_msj.cod_msj_swift,
                                                                                      'C',
                                                                                      pas_snp.g_msj.cod_tip_operacion,
                                                                                      pas_snp.g_msj.cod_sub_tip_operacion
                                                                                    );
                        else
                           v_cod_tip_circuito := pas_snp.fu_obt_cod_tip_cir_workflow( pas_snp.g_msj.cod_msj_swift,
                                                                                      'E',
                                                                                      pas_snp.g_msj.cod_tip_operacion,
                                                                                      pas_snp.g_msj.cod_sub_tip_operacion
                                                                                    );
                        end if;

                        if paw_cir.fu_ini_circuito( v_cod_tip_circuito,
                                                    pas_snp.g_msj.nro_referencia,
                                                    nvl(pas_snp.g_msj.cod_per_solicitante,fug_obt_per_entidad)
                                                  ) <> 0 then
                           raise_application_error (-20005, 'Error al iniciar CIRCUITO p/ MT Enviado. Nro.Ref.: ' || pas_snp.g_msj.nro_referencia);
                        end if;
                     else -- MT Recibido
                        v_cod_tip_circuito := pas_snp.fu_obt_cod_tip_cir_workflow( pas_snp.g_msj.cod_msj_swift,
                                                                                   'R',
                                                                                   pas_snp.g_msj.cod_tip_operacion,
                                                                                   pas_snp.g_msj.cod_sub_tip_operacion
                                                                                 );
                        if paw_cir.fu_ini_circuito( v_cod_tip_circuito,
                                                    pas_snp.g_msj.nro_referencia,
                                                    nvl(pas_snp.g_msj.cod_per_beneficiario,fug_obt_per_entidad)
                                                  ) <> 0 then
                           raise_application_error (-20005, 'Error al iniciar CIRCUITO p/ MT Recibido. Nro.Ref.Ext.: ' || pas_snp.g_msj.nro_ref_externa ||
                                                            ' Error: ' || pas_snp.fu_obt_msj_error);
                        end if;
                     end if;
                  end if;
               when others then
                  raise_application_error (-20006, 'Error al cancelar circuito: ' || nvl(paw_cir.fu_obt_cod_error,sqlerrm));
            end;
        exception
           when pas_snp.ex_salir then
              null;
           when others then
              raise;
        end;
        -- Envía alerta por la Reversión de una transferencia entre clientes.
        if pas_snp.g_msj.cod_msj_swift in (103, 102) and nvl(v_est_transferencia,'X')='R'
           and nvl(v_sit_transferencia,'X')='L'  then
           pas_snp.pr_env_alerta ( pas_snp.g_msj, 'R' );
        else
           pas_snp.pr_env_alerta ( pas_snp.g_msj, 'W' );
        end if;
      END IF;
   END;
   /* Actualiza los movimientos historicos a reversado. */
   PROCEDURE lp_act_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_nro_secuencia     IN ge_movimientos.nro_secuencia%TYPE,
      p_cod_usu_insercion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_cod_modulo        IN ge_movimientos.cod_modulo%TYPE
   ) IS
   BEGIN
      -- AHORRO
      IF p_cod_modulo = 3 THEN
         UPDATE ah_movimientos_his
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = p_nro_secuencia
            AND reversado = 'N';
         -- CUENTA CORRIENTE
      ELSIF p_cod_modulo = 4 THEN
         UPDATE cc_movimientos_his
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = p_nro_secuencia
            AND reversado = 'N';
      END IF;
   END;



   FUNCTION lf_obt_ref_mov_mayor(p_hora2 in varchar2) return varchar2 is
      v_existe varchar2(1);
      v_hora ge_movimientos.hora%type;
      pragma autonomous_transaction;
   BEGIN
     v_hora := lf_obt_hor_max_movimiento(p_fecha, p_hora2, p_cod_usuario);
      begin
         SELECT 'S'
           into v_existe
           FROM ge_movimientos g
          WHERE g.fecha = p_fecha
            AND g.hora > p_hora2
            AND g.cod_usuario = p_cod_usuario
            AND g.monto <> 0
            AND g.cod_modulo = 26
            AND g.reversado = 'N'
            AND g.referencia =
                (SELECT m.referencia
                   FROM ge_movimientos m
                  WHERE m.fecha = p_fecha
                    AND m.hora = v_hora
                    AND m.cod_usuario = p_cod_usuario
                    AND m.monto <> 0
                    AND m.cod_modulo = 26
                    AND m.cod_tra_padre = p_cod_tra_padre
                    AND m.cod_transaccion = v_cod_tra_pago)
            and rownum = 1;

      EXCEPTION
         WHEN OTHERS THEN
            v_existe := 'N';
      end;
      return v_existe;
   end;

   /********PROCESO PRINCIPAL DEL PROCEDIMIENTO *****/
BEGIN
   --
   v_es_nocturno := p_es_nocturno;
   --
   --Inicializar errores de pag_cta
   pag_cta.g_msj_error := NULL;
   pag_cta.g_cod_error := 0;
   --
   IF p_es_nocturno = 'X' THEN
      -- Buscar si es nocturno o diurno
      v_est_modulo := pae_cnf.fu_obt_est_modulo(pae_cnf.g_cod_modulo);
      IF v_est_modulo = 2 THEN
         v_es_nocturno := 'N';
      ELSE
         v_es_nocturno := 'S';
      END IF;
   END IF;
   --
   IF v_es_nocturno = 'N' THEN
      v_fec_actual := pag_cal.fu_obt_fec_actual(p_cod_mod_padre);
      --
      IF p_fecha < v_fec_actual THEN
         --MOV. DEL HISTORICO
         lp_bus_dat_histo(p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, p_cod_usu_reversion,
                          p_hor_reversion);
      ELSIF p_fecha = v_fec_actual THEN
         --
         FOR c1 IN cur_gmovi LOOP
               lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
         END LOOP;
         IF v_ope_pendiente = 'N' Then
            --CRO-HO-CROCPCCB-16/09/15
             If nvl(v_mto_credito,0) = 0 THEN
                UPDATE ge_movimientos
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha = p_fecha
                   AND hora = p_hora
                   AND cod_usuario = p_cod_usuario
                   AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
                   AND reversado = 'N';
             Else --> Debe Actualizar todos los registros menos el de la liberación
                 UPDATE ge_movimientos
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha             = p_fecha
                   AND hora              = p_hora
                   AND cod_usuario       = p_cod_usuario
                   AND nro_documento     <> v_nro_documento
                   AND reversado         = 'N';
             End IF;
         END IF;
      END IF;
      --
   ELSIF v_es_nocturno = 'S' THEN
      FOR c1 IN cur_gmono LOOP
         lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'S');
      END LOOP;
      IF v_ope_pendiente = 'N' THEN
         UPDATE ge_movimientos_noc
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
            AND reversado = 'N';
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20099,
                                 'Fecha: ' || to_char(p_fecha, 'DD/MM/YYYY') || ' hora: ' ||
                                 p_hora || ' Cod. usuario: ' || p_cod_usuario || ' Cod. Mod. Padre: ' ||
                                 p_cod_mod_padre||' '||sqlerrm);
      end if;
END PRG_REV_OPERACION_SNP;
/


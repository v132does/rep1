CREATE OR REPLACE PROCEDURE IT.PRG_REV_OPE_ACCOUNTS2
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
   p_cod_transaccion   IN NUMBER DEFAULT NULL,
   p_nro_documento     IN ge_movimientos.nro_documento%TYPE DEFAULT NULL,
   p_mov_orden         IN VARCHAR2 DEFAULT NULL,
   v_fec_reversion     OUT ge_calendarios.fec_actual%TYPE
) IS

   r_gmovi              ge_movimientos%ROWTYPE;
   v_es_nocturno        VARCHAR2(1);
   v_est_modulo         ba_modulos.estado%TYPE;
   v_fec_actual         ge_calendarios.fec_actual%TYPE;
   v_mto_credito         ge_movimientos.monto%TYPE;
   v_mov_orden           VARCHAR2(10) := nvl(p_mov_orden, 'DESC'); 

   v_mod_habilitados varchar2(30);
   v_enc_gv_mov_par varchar2(1);
   v_cod_tra_cargo    ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_TRA_CARGOS');
   v_ope_ahorros        VARCHAR2(1) := 'N';
   v_exi_movimiento  VARCHAR2(1) := 'N';
   
   --------------------------------------
   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
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

    ---movimientos diurnos
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
         AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
         AND reversado = 'N'
       ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC;

   ---movimientos nocturnos
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

   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
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
      v_control VARCHAR2(1) := NULL;
   BEGIN
     
      FOR c1 IN cur_modulos LOOP
         --- Procesar reversion
         IF v_control IS NULL THEN
            v_control := 'S';
         END IF;
            --- Procesar reversion
            lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
         --- Actualizar Historicos
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
         END IF;
      END LOOP;
   END;
   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo_par
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
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
           FROM gv_movimientos_par
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND reversado = 'N'
            AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
          ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC;
   BEGIN

      --SETEA LOS PARÁMETROS PARA LA VISTA
       PAG_PAR.PR_SET_REV_COD_USUARIO(p_cod_usuario);
       PAG_PAR.PR_SET_REV_FECHA(p_fecha);
       PAG_PAR.PR_SET_REV_HORA(p_hora);
       PAG_PAR.PR_SET_REV_REVERSADO('N');

      FOR c1 IN cur_modulos LOOP
            --- Procesar reversion
            lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
        
         --- Actualizar Historicos
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
          END IF;
      END LOOP;
   END;

  PROCEDURE lp_ins_movimientos
   (
      rp_gmovi            IN ge_movimientos%ROWTYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_es_nocturno       IN VARCHAR2 := 'X'

   ) IS

      r_gmovi           ge_movimientos%ROWTYPE;
      v_fec_ult_mov_ant DATE := NULL;
      v_hor_ult_mov_ant VARCHAR2(8) := NULL;
      -- DATOS DE LA REVERSION DE LA CUENTA
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

 BEGIN

      -- Traspaso los datos del registro leido en el nuevo
      r_gmovi := rp_gmovi;
      --
      r_gmovi.fecha         := nvl(v_fec_actual,r_gmovi.fecha);
      r_gmovi.fec_valor     := p_fecha;
      r_gmovi.cod_usuario   := p_cod_usu_reversion;
      r_gmovi.monto         := rp_gmovi.monto * -1;
      r_gmovi.mto_equ_local := rp_gmovi.mto_equ_local * -1;
      --verifico la existencia de la cuenta
      pag_cta.pr_obt_cuenta(rp_gmovi.nro_cuenta);
       IF pag_cta.g_cod_error != 0 THEN
          raise_application_error(-20005, 'Cuenta ' || rp_gmovi.nro_cuenta || ' inexistente ');
       END IF;

         r_gmovi.hora              := p_hor_reversion;
         r_gmovi.reversado         := 'S';
         r_gmovi.hor_reversion     := rp_gmovi.hora;
         r_gmovi.cod_usu_reversion := rp_gmovi.cod_usuario;
         r_gmovi.concepto          := substr('Reversa de ' || rp_gmovi.concepto, 1, 100);

                        -- obtengo el tipo d/c y a que saldo afecto
         IF r_gmovi.cod_modulo <> 6 THEN
            pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                   rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         END IF;
      
   --
      IF r_gmovi.cod_tra_padre NOT IN (101, 102, 358, 359, 360, 362, 364, 139) THEN
         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);

      ELSE
         IF r_gmovi.cod_mod_padre <> 9 THEN
               pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         ELSE
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         END IF;
      END IF;

      -- retorno el monto del saldo de la cuenta
      IF rp_gmovi.nro_cuenta IS NOT NULL AND
         (rp_gmovi.estado = 'N' OR
         (rp_gmovi.estado = 'P' AND (instr(v_cod_tra_cargo,','||rp_gmovi.cod_tra_padre||',') > 0))) AND
          rp_gmovi.monto <> 0 AND r_gmovi.cod_modulo IN (3, 4) THEN 
         v_ope_ahorros := 'S';

     --- Verificar que no se haya insertado como para actualizacion de saldo en batch
         v_exi_movimiento := pag_bat.fu_ver_exi_movimiento(rp_gmovi.nro_cuenta,rp_gmovi.fecha,rp_gmovi.hora,rp_gmovi.cod_usuario,
                                                           rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.monto);

     IF nvl(v_exi_movimiento,'N') = 'N' THEN
              IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad, rp_gmovi.nro_cuenta, v_es_nocturno) = 'N' AND
                 r_gmovi.cod_modulo <> 6 and rp_gmovi.cod_modalidad not in (43,455) THEN
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
         ELSIF v_afecta IN ('C', 'I', 'S') AND (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') < 1) THEN
            -- afecta al saldo total,capital o interes
            v_afe_sal_total  := r_gmovi.monto;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := 0;
         ELSIF v_afecta = 'B' AND (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') < 1) THEN 
            -- afecta al saldo bloqueado
            v_afe_sal_total     := 0;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := r_gmovi.monto;
        ELSIF v_afecta IN ('C', 'I', 'S') and (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') > 0) AND rp_gmovi.estado = 'N' THEN
            -- afecta al saldo total,capital o interes
            v_afe_sal_total     := r_gmovi.monto;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := 0;
         ELSIF v_afecta IN ('C', 'I', 'S') and (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') > 0) AND rp_gmovi.estado = 'P' THEN
            -- afecta al saldo bloqueado
            v_afe_sal_total     := 0;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := rp_gmovi.monto;--se envia el monto positivo ya que es un debito a realizar
         END IF;          
     IF nvl(v_afe_sal_total, 0) <> 0 OR nvl(v_afe_sal_retenido, 0) <> 0 OR
            nvl(v_afe_sal_bloqueado, 0) <> 0 THEN
            pag_cta.pr_obt_cuenta(rp_gmovi.nro_cuenta);
           -- Verificar que no se haya insertado como para actualizacion de saldo en batch
            IF nvl(v_exi_movimiento,'N') = 'N' THEN
              if rp_gmovi.cod_modalidad <> 455 then
                 -- retorno el monto al saldo
                 pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, v_tip_movimiento,
                                       v_fec_ult_mov_ant, v_hor_ult_mov_ant, v_afe_sal_total,
                                       v_afe_sal_retenido, v_afe_sal_bloqueado, NULL,
                                       v_act_ult_movimiento);
              end if;
            END IF;         
       END IF;
       END IF;
      --
      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.estado IN ('P', 'X', 'J') AND --- Los movimientos 'J' no actualizan la cuenta
         rp_gmovi.monto <> 0 AND r_gmovi.cod_modulo IN (3, 4) AND
         (r_gmovi.cod_mod_padre IN (3, 4)) THEN
         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         IF v_tip_movimiento = 'D' THEN
            -- si es un debito
            IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad, rp_gmovi.nro_cuenta, v_es_nocturno) = 'N' THEN
              -- cuenta llaveada
              raise_application_error(-20000, 'Cuenta ' || rp_gmovi.nro_cuenta || ' llaveada ');
            END IF;

            -- retorno el monto al saldo
            pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, 'D', rp_gmovi.fecha,
                                   rp_gmovi.hora, 0, 0, rp_gmovi.monto,
                                   -- el saldo bloqueado
                                   NULL,  v_act_ult_movimiento);
         END IF;
      END IF;
   END;

   /* PROCESO PRINCIPAL DEL PROCEDIMIENTO */
BEGIN
   --
   v_es_nocturno := p_es_nocturno;
   --
   --Inicializar errores de pag_cta
   pag_cta.g_msj_error := NULL;
   pag_cta.g_cod_error := 0;
   --
   IF p_es_nocturno IN ('X','N') THEN
      -- Buscar si es nocturno o diurno
      v_est_modulo := pae_cnf.fu_obt_est_modulo(p_cod_mod_padre);
      IF v_est_modulo = 2 THEN
         v_es_nocturno := 'N';
      ELSIF v_est_modulo IN (1,6) THEN
         raise_application_error(-20003, 'Modulo cerrado.No se puede operar.');
      ELSE
         v_es_nocturno := 'S';
      END IF;
   END IF;

   IF NVL(v_es_nocturno,'N') = 'S' THEN
      pag_cta.g_horario := 'N';-- noche
   ELSE
      pag_cta.g_horario := 'D';-- dia normal
   END IF;
   --
   IF v_es_nocturno = 'N' THEN
      v_fec_actual := pag_cal.fu_obt_fec_actual(p_cod_mod_padre);
      --
      IF p_fecha < v_fec_actual THEN
         --MOV. DEL HISTORICO
         v_mod_habilitados := fug_obt_pardinamico('MOD_GV_MOV_PAR',p_cod_mod_padre,p_cod_mad_padre);--modulos habilitados separados por coma
         v_enc_gv_mov_par  := fug_obt_pardinamico('ENC_GV_MOV_PAR');--encendido de gv_movimientos_par

         IF v_mod_habilitados = 'S' AND v_enc_gv_mov_par = 'S' THEN--primero se confirma que el modulo padre esta dentro de la lista, luego se verifica si esta encendido la opcion
            lp_bus_dat_histo_par(p_fecha, p_hora, p_cod_usuario, p_cod_usu_reversion, p_hor_reversion);
         ELSE
            lp_bus_dat_histo(p_fecha, p_hora, p_cod_usuario, p_cod_usu_reversion, p_hor_reversion);
         END IF;
         
      ELSIF p_fecha = v_fec_actual THEN
         FOR c1 IN cur_gmovi LOOP
             lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
         END LOOP;
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
             End IF;
        END IF;

   ELSIF v_es_nocturno = 'S' THEN
      pag_cal.pr_obt_dat_calendar(p_cod_mod_padre);
      v_fec_actual := pag_cal.g_fec_proxima;
      IF p_fecha < v_fec_actual THEN
         --MOV. DEL HISTORICO
         v_mod_habilitados := fug_obt_pardinamico('MOD_GV_MOV_PAR',p_cod_mod_padre,p_cod_mad_padre);--modulos habilitados separados por coma
         v_enc_gv_mov_par  := fug_obt_pardinamico('ENC_GV_MOV_PAR');--encendido de gv_movimientos_par

         IF v_mod_habilitados = 'S' AND v_enc_gv_mov_par = 'S' THEN--primero se confirma que el modulo padre esta dentro de la lista, luego se verifica si esta encendido la opcion
            lp_bus_dat_histo_par(p_fecha, p_hora, p_cod_usuario, p_cod_usu_reversion, p_hor_reversion);
         ELSE
            lp_bus_dat_histo(p_fecha, p_hora, p_cod_usuario, p_cod_usu_reversion, p_hor_reversion);
             UPDATE ge_movimientos
                SET reversado         = 'S',
                    cod_usu_reversion = p_cod_usu_reversion,
                    hor_reversion     = p_hor_reversion
              WHERE fecha = p_fecha
                AND hora = p_hora
                AND cod_usuario = p_cod_usuario
                AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
                AND reversado = 'N';
         END IF;
      ELSE
      FOR c1 IN cur_gmono LOOP
         lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'S');
      END LOOP;
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
   -- Devolver la fecha de reversión solicitada
   v_fec_reversion := v_fec_actual;

EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
        raise_application_error(
           -20099,
           'Ctx PRG_REV_OPE_ACCOUNTS2 -> Fecha:'||to_char(p_fecha,'DD/MM/YYYY')||
           ' Hora:'||p_hora||
           ' Usuario:'||p_cod_usuario||
           ' ModPadre:'||p_cod_mod_padre||CHR(10)||
           'Origen: '||SQLERRM||CHR(10)||
           'Backtrace: '||DBMS_UTILITY.format_error_backtrace,
           TRUE 
        );
     end if;
END PRG_REV_OPE_ACCOUNTS2;
/

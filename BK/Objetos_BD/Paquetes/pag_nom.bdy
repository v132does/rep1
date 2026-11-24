CREATE OR REPLACE PACKAGE BODY IT.PAG_NOM is
  -- Function and procedure implementations
  function FU_MTO_LIN_SOBREGIROS(P_NRO_CUENTA        IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_ENTE          IN GE_ENTES.COD_ENTE%TYPE,
                                 P_TIP_CALCULO       IN VARCHAR2,
                                 P_CAN_MES_CALCULO   IN NUMBER,
                                 P_CAN_MES_RECALCULO IN NUMBER) return number is
    v_periodo       number;
    v_tra_padre     number := fug_obt_parentes(p_cod_ente,
                                               'COD_TRA_PAD_SUELDO');
    v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(4);
    v_cod_tasa      number := fug_obt_parentes(p_cod_ente,
                                               'COD_TAS_LIN_SOBREGIROS');
    v_val_tasa      ge_tas_fechas.val_tasa%type;
    v_redondeo      number := fug_obt_pardinamico('SUE_MTO_REDONDEO');
    v_cod_modulo    ge_cta_clientes.cod_modulo%type;
    v_cod_modalidad ge_cuentas.cod_modalidad%type;
    v_cod_oficina   ge_cuentas.cod_oficina%type;
    v_cod_moneda    ge_cuentas.cod_moneda%type;
    v_monto         number;
    v_promedio      number;
    v_mto_sobregiro number;
    v_mto_redondeo  number;
  begin
    if P_TIP_CALCULO = 'G' then
      v_periodo := P_CAN_MES_CALCULO;
    else
      v_periodo := P_CAN_MES_RECALCULO;
    end if;
    if v_periodo > 0 then
      if FU_OBT_CAN_PAGOS(p_nro_cuenta, p_tip_calculo) < v_periodo then
        v_mto_sobregiro := 0;
        return v_mto_sobregiro;
      else
        begin
          select cod_modulo, cod_modalidad, cod_oficina, cod_moneda
            into v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda
            from ge_cuentas
           where nro_cuenta = p_nro_cuenta;
        exception
          when no_data_found then
            raise_application_error(-20020,
                                    'No se encuentra la cuenta ' ||
                                    P_NRO_CUENTA);
        end;
        v_mto_redondeo := fug_obt_pardinamico('SUE_MTO_REDONDEO',
                                              v_cod_modulo,
                                              v_cod_modalidad,
                                              v_cod_moneda);
        if P_TIP_CALCULO = 'G' THEN
          begin
            select sum(a.monto)
              into v_monto
              from cc_movimientos_his a
             where a.nro_cuenta = p_nro_cuenta
               and a.cod_tra_padre = v_tra_padre
               and a.reversado = 'N'
               and to_char(a.fecha, 'MM/YYYY') >=
                   to_char(add_months(v_fec_actual, (v_periodo * -1)),
                           'MM/YYYY');
          exception
            when no_data_found then
              v_monto := 0;
          end;
        else
          begin
            select sum(a.monto)
              into v_monto
              from cc_movimientos_his a
             where a.nro_cuenta = p_nro_cuenta
               and a.cod_tra_padre = v_tra_padre
               and a.reversado = 'N'
               and to_char(a.fecha, 'MM/YYYY') >
                   to_char(add_months(v_fec_actual, (v_periodo * -1)),
                           'MM/YYYY');
          exception
            when no_data_found then
              v_monto := 0;
          end;
        end if;
        v_promedio := nvl(v_monto, 0) / v_periodo;
        v_val_tasa := fug_obt_val_tasa(v_cod_modulo,
                                       v_cod_modalidad,
                                       v_cod_oficina,
                                       p_nro_cuenta,
                                       v_cod_moneda,
                                       v_promedio,
                                       'N',
                                       v_cod_tasa,
                                       null,
                                       v_fec_actual);

        --Obtengo el monto de la Línea de Sobregiro en base a la tasa
        v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                               v_cod_modulo,
                                               v_cod_modalidad,
                                               v_cod_moneda);
        v_mto_sobregiro := round((ceil(nvl(v_promedio, 0) *
                                       nvl(nvl(v_val_tasa, 0) / 100, 0) /
                                       nvl(v_mto_redondeo, 1)) *
                                 nvl(v_mto_redondeo, 1)),
                                 v_redondeo);
        return v_mto_sobregiro;
      end if;
    else
      return 0;
    end if;

  end;
  FUNCTION FU_OBT_LIN_SOBREGIRO(p_nro_cuenta VARCHAR2,
                                p_documento  VARCHAR2,
                                p_tipo       VARCHAR2) RETURN VARCHAR2 IS
    v_existe VARCHAR2(1) := 'N';
  BEGIN
    BEGIN
      SELECT DISTINCT 'S'
        INTO v_existe
        FROM cc_lin_sobregiros
       WHERE nro_cuenta = p_nro_cuenta
         AND tipo = p_tipo;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
      WHEN OTHERS THEN
        raise_application_error(-20005,
                                'Error al buscar Líneas de Sobregiro. Documento Nro= ' ||
                                p_documento || ' ' || SQLERRM);
    END;

    RETURN v_existe;
  END;

  FUNCTION FU_OBT_CAN_PAGOS(p_nro_cuenta VARCHAR2, p_tip_calculo VARCHAR2)
    RETURN VARCHAR2 IS
    v_cantidad      number := 0;
    v_ini_sobregiro varchar2(6) := 0;
  BEGIN
    BEGIN
      SELECT to_number(to_char(to_date(val_parametro, 'dd/mm/yyyy'),
                               'yyyymm'))
        into v_ini_sobregiro
        from cc_cta_corrientes c, ge_cta_dat_adicionales a
       where c.nro_cuenta = a.nro_cuenta
         and a.parametro = 'SOB_FEC_INI_LINEA'
         and c.nro_cuenta = p_nro_cuenta;
    END;
    IF p_tip_calculo = 'G' then
      BEGIN
        select count(distinct to_number(to_char(fecha, 'mm')))
          into v_cantidad
          from cc_movimientos_his h
         where h.cod_tra_padre = 303
           and nro_cuenta = p_nro_cuenta
           and h.reversado = 'N'
           and h.monto > 0
           and to_number(to_char(fecha, 'yyyymm')) >= v_ini_sobregiro;
      EXCEPTION
        WHEN no_data_found THEN
          v_cantidad := 0;
        WHEN OTHERS THEN
          raise_application_error(-20005,
                                  'Error al obtener cantidad de Pagos. Cuenta Nro= ' ||
                                  p_nro_cuenta || ' ' || SQLERRM);
      END;
    ELSE
      BEGIN
        select count(distinct to_number(to_char(fecha, 'mm')))
          into v_cantidad
          from cc_movimientos_his h
         where h.cod_tra_padre = 303
           and nro_cuenta = p_nro_cuenta
           and h.reversado = 'N'
           and h.monto > 0
           and to_number(to_char(fecha, 'yyyymm')) > v_ini_sobregiro;
      EXCEPTION
        WHEN no_data_found THEN
          v_cantidad := 0;
        WHEN OTHERS THEN
          raise_application_error(-20005,
                                  'Error al obtener cantidad de Pagos. Cuenta Nro= ' ||
                                  p_nro_cuenta || ' ' || SQLERRM);
      END;
    END IF;

    RETURN v_cantidad;
  END;
  /****/
  FUNCTION FU_OBT_CAU_CAN_MASIVA(P_TIP_CAUSA          VARCHAR2,
                                 P_NRO_CUENTA         GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_ENTE           GE_ENTES.COD_ENTE%TYPE,
                                 P_CTA_SIN_MOVIMIENTO VARCHAR2)
    RETURN VARCHAR2 IS

    v_existe                 VARCHAR2(1) := 'N';
    v_sal_total              cc_cta_corrientes.sal_total%type;
    v_mto_min_cancelacion    varchar2(25);
    v_cod_cau_desvinculacion varchar2(200) := fug_obt_pardinamico('SUE_CAU_TEL_DESVINCULACION');
    v_cod_cau_cancelacion    varchar2(200) := fug_obt_pardinamico('SUE_CAU_TEL_CANCELACION');
    v_causa                  ge_par_cancelaciones.cod_causa%type;
    v_can_meses              varchar2(20) := fug_obt_pardinamico('CAN_MES_SIN_MOVIMIENTO',
                                                                 null,
                                                                 null,
                                                                 null,
                                                                 null,
                                                                 null); --fug_obt_parentes(p_cod_ente,'CAN_MES_SIN_MOVIMIENTO');
    v_fec_actual             DATE := pag_cal.fu_obt_fec_actual(1);
    v_can_movimientos        number;
    v_estado                 GE_EST_CUENTAS.ESTADO%TYPE;
    v_cod_moneda             cc_cta_corrientes.cod_moneda%TYPE;
    v_cod_modulo             cc_cta_corrientes.cod_modulo%TYPE;
    v_cod_modalidad          cc_cta_corrientes.cod_modalidad%TYPE;
    v_cod_sub_modalidad      cc_cta_corrientes.cod_sub_modalidad%TYPE;
    v_cod_oficina            cc_cta_corrientes.cod_oficina%TYPE;
  BEGIN
    BEGIN
      select sal_total,
             estado,
             cod_moneda,
             cod_modulo,
             cod_modalidad,
             cod_sub_modalidad,
             cod_oficina
        into v_sal_total,
             v_estado,
             v_cod_moneda,
             v_cod_modulo,
             v_cod_modalidad,
             v_cod_sub_modalidad,
             v_cod_oficina
        from cc_cta_corrientes
       where nro_cuenta = p_nro_cuenta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          select sal_total,
                 estado,
                 cod_moneda,
                 cod_modulo,
                 cod_modalidad,
                 cod_sub_modalidad
            into v_sal_total,
                 v_estado,
                 v_cod_moneda,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_sub_modalidad
            from ah_cta_vistas
           where nro_cuenta = p_nro_cuenta;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            raise_application_error(-20005,
                                    'No se encuentra la cuenta Nro. ' ||
                                    p_nro_cuenta);
        END;
    END;
    --Un parámetro para deudor y otro para acreedor
    if nvl(v_sal_total,0) > 0 then
       v_mto_min_cancelacion := fug_obt_pardinamico('PAG_NOM_MTO_CRE',
                                                 v_cod_modulo,
                                                 v_cod_modalidad,
                                                 v_cod_moneda,
                                                 v_cod_oficina,
                                                 v_cod_sub_modalidad);
    elsif nvl(v_sal_total,0) < 0 then
       v_mto_min_cancelacion := fug_obt_pardinamico('PAG_NOM_MTO_DEB',
                                                 v_cod_modulo,
                                                 v_cod_modalidad,
                                                 v_cod_moneda,
                                                 v_cod_oficina,
                                                 v_cod_sub_modalidad);
   end if;
                                                 
    BEGIN
      select 'S'
        into v_existe
        from ge_telegramas
       where ref_cuentas = p_nro_cuenta
         and instr(v_cod_cau_desvinculacion, to_char(cod_causa)) > 0;
    EXCEPTION
      WHEN TOO_MANY_ROWS THEN
        v_existe := 'S';
      WHEN NO_DATA_FOUND THEN
        v_existe := 'N';
    END;

    IF P_TIP_CAUSA = 'G' THEN
      IF abs(v_sal_total) <= nvl(v_mto_min_cancelacion, 0) /*and v_sal_total <> 0 */
       then
        BEGIN
          select cod_causa
            into v_causa
            from ge_par_cancelaciones
           where nat_saldo = 'C'
             and instr(v_cod_cau_desvinculacion, to_char(cod_causa)) > 0;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            raise_application_error(-20006,
                                    'No se encuentra el Código de Causa. ');
        END;
      END IF;
      IF v_existe = 'S' then
        IF (v_sal_total < 0 and abs(v_sal_total) > v_mto_min_cancelacion) THEN
          BEGIN
            select cod_causa
              into v_causa
              from ge_par_cancelaciones
             where nat_saldo = 'N'
               and instr(v_cod_cau_cancelacion, to_char(cod_causa)) > 0;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              raise_application_error(-20006,
                                      'No se encuentra el Código de Causa. ');
          END;
        END IF;
        IF (v_sal_total > 0 and abs(v_sal_total) > v_mto_min_cancelacion) THEN
          BEGIN
            select cod_causa
              into v_causa
              from ge_par_cancelaciones
             where nat_saldo = 'P'
               and instr(v_cod_cau_cancelacion, to_char(cod_causa)) > 0;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              raise_application_error(-20006,
                                      'No se encuentra el Código de Causa. ');
          END;
        END IF;
      ELSE
        IF v_sal_total < 0 and abs(v_sal_total) > v_mto_min_cancelacion THEN
          BEGIN
            select cod_causa
              into v_causa
              from ge_par_cancelaciones
             where nat_saldo = 'N'
               and instr(v_cod_cau_desvinculacion, to_char(cod_causa)) > 0;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              raise_application_error(-20006,
                                      'No se encuentra el Código de Causa. ');
          END;
        END IF;
        IF v_sal_total > 0 and abs(v_sal_total) > v_mto_min_cancelacion THEN
          BEGIN
            select cod_causa
              into v_causa
              from ge_par_cancelaciones
             where nat_saldo = 'P'
               and instr(v_cod_cau_desvinculacion, to_char(cod_causa)) > 0;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              raise_application_error(-20006,
                                      'No se encuentra el Código de Causa. ');
          END;
        END IF;
      END IF;
    ELSIF P_TIP_CAUSA = 'C' THEN
      BEGIN
        select count(*)
          into v_can_movimientos
          from cc_movimientos_his h
         where h.fecha >= add_months(v_fec_actual, -v_can_meses)
           and h.nro_cuenta = p_nro_cuenta
           and h.nro_cuenta is not null;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          BEGIN
            select count(*)
              into v_can_movimientos
              from ah_movimientos_his h
             where h.fecha >= add_months(v_fec_actual, -v_can_meses)
               and h.nro_cuenta = p_nro_cuenta
               and h.nro_cuenta is not null;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_can_movimientos := 0;
          END;
      END;
      IF v_can_movimientos = 0 THEN
        IF v_estado = 'A' then
          v_causa := 223;
        ELSIF v_estado <> 'A' and P_CTA_SIN_MOVIMIENTO = 'C' THEN
          IF v_sal_total < 0 and abs(v_sal_total) > v_mto_min_cancelacion then
            v_causa := 201;
          ELSE
            v_causa := 264;
          END IF;
        ELSE
          IF v_sal_total < 0 and abs(v_sal_total) > v_mto_min_cancelacion then
            v_causa := 201;
          ELSE
            v_causa := 266;
          END IF;
        END IF;
      ELSE
        IF P_CTA_SIN_MOVIMIENTO <> 'C' THEN
          IF v_sal_total < 0 and abs(v_sal_total) > v_mto_min_cancelacion then
            v_causa := 201;
          ELSE
            v_causa := 266;
          END IF;
        END IF;
      END IF;
      NULL;
    END IF;
    RETURN v_causa;
  END;
  /**Proceso de Re-calculo de Líneas de Sobregiros**/
  PROCEDURE PR_GEN_LIN_SOBREGIRO(P_NRO_CUENTA        IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_ENTE          IN GE_ENTES.COD_ENTE%TYPE,
                                 P_TIP_CALCULO       IN VARCHAR2,
                                 P_MTO_SOB_SUELDO    IN NUMBER DEFAULT 0,
                                 P_MTO_SOB_AGUINALDO IN NUMBER DEFAULT 0) IS

    v_can_meses         number := fug_obt_parentes(p_cod_ente,
                                                   'SOB_PER_CALCULO');
    v_can_mes_recalculo number := fug_obt_parentes(p_cod_ente,
                                                   'SOB_PER_RECALCULO');
    v_nro_cedula        ba_personas.nro_documento%type;
    v_cod_persona       ba_personas.cod_persona%type;
    v_nro_secuencia     cc_lin_sobregiros.nro_secuencia%TYPE;
    v_nro_sec_padre     cc_lin_sobregiros.nro_secuencia%TYPE;
    v_nro_sec_aguinaldo cc_lin_sobregiros.nro_secuencia%TYPE;
    v_nro_sec_agu_padre cc_lin_sobregiros.nro_secuencia%TYPE;
    v_fec_ven_sobregiro cc_lin_sobregiros.fec_vencimiento%TYPE;
    v_fec_vencimiento   ah_tar_debitos.fec_vencimiento%TYPE;
    v_cod_mon_linea     ba_monedas.cod_moneda%TYPE;
    --v_direccion           ba_direcciones.direccion%TYPE;
    --v_obs_direccion       ba_direcciones.observacion%TYPE;
    --v_cod_concepto        cr_con_ing_egr.cod_concepto%TYPE;
    --v_anio                VARCHAR2(10);
    v_cot_original NUMBER;
    v_cot_destino  NUMBER;
    -- v_mto_ant_sueldo      NUMBER;
    v_observacion   VARCHAR2(50) := 'PLAN SUELDO';
    v_mto_sobregiro cc_lin_sobregiros.monto%type;
    v_cod_moneda    cc_cta_corrientes.cod_moneda%TYPE;
    v_mto_cuenta    cc_lin_sobregiros.monto%TYPE;
    v_acu_sobregiro cc_cta_corrientes.acu_sobregiro%type := 'N'; --DYDMR-4334 ALV

  BEGIN
    -- Sobregiros de Sueldos
    BEGIN
      select p.nro_documento, p.cod_persona
        into v_nro_cedula, v_cod_persona
        from ge_cta_clientes c, ba_personas p
       where c.cod_persona = p.cod_persona
         and c.nro_cuenta = p_nro_cuenta
         and c.relacion = 'P';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        raise_application_error(-20021,
                                'No se encontraron datos de la persona. Nro. Cuenta: ' ||
                                p_nro_cuenta);
      WHEN OTHERS THEN
        raise_application_error(-20036,
                                'Error al buscar datos de la persona en BA_PERSONAS. Nro. Cuenta : ' ||
                                p_nro_cuenta || ' ' || SQLERRM);
    END;

    BEGIN
      SELECT cod_moneda
        INTO v_cod_moneda
        FROM cc_cta_corrientes
       WHERE nro_cuenta = p_nro_cuenta;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20008,
                                'Error al buscar datos CC_CTA_CORRIENTES. Cta: ' ||
                                p_nro_cuenta || '-' || SQLERRM);
    END;

    IF FU_OBT_LIN_SOBREGIRO(P_NRO_CUENTA, v_nro_cedula, 'T') = 'N' OR
       (FU_OBT_LIN_SOBREGIRO(P_NRO_CUENTA, v_nro_cedula, 'T') = 'S' AND
        P_TIP_CALCULO = 'R') THEN
      -- v_lugar := '30-SOBREGIROS';
      --- Verifica si ya tiene cabecera de linea de sobregiro
      v_nro_sec_padre := NULL;
      IF P_MTO_SOB_SUELDO > 0 THEN
        v_mto_sobregiro := P_MTO_SOB_SUELDO;
      else
        v_mto_sobregiro := fu_mto_lin_sobregiros(p_nro_cuenta,
                                                 p_cod_ente,
                                                 p_tip_calculo,
                                                 v_can_meses,
                                                 v_can_mes_recalculo); --nvl(t.mto_ant_sueldo, 0);
      end if;
      IF v_mto_sobregiro > 0 then
        BEGIN
          SELECT nro_secuencia, cod_moneda
            INTO v_nro_sec_padre, v_cod_mon_linea
            FROM cc_lin_sobregiros
           WHERE cod_persona = v_cod_persona
             AND tipo = 'T'
             AND nro_cuenta IS NULL;

          -- si ya tiene creada linea de sobregiro cabecera , sumar a la misma la nueva linea de sobregiro
          /* RI : 30/03/2010: Si la moneda del detalle es diferente a de la cabecera
          convertir para actualizar la cabecera */
          v_cot_original := NULL;
          v_cot_destino  := NULL;
          -- v_mto_ant_sueldo := NULL;

          IF v_cod_moneda <> v_cod_mon_linea THEN
            pag_gen.pr_con_mon_a_moneda(v_cod_moneda,
                                        v_cod_mon_linea,
                                        nvl(v_mto_sobregiro, 0),
                                        v_mto_sobregiro,
                                        v_cot_original,
                                        v_cot_destino);
          ELSE
            v_mto_sobregiro := nvl(v_mto_sobregiro, 0);
          END IF;
          IF P_TIP_CALCULO = 'R' THEN
            SELECT monto
              INTO v_mto_cuenta
              FROM cc_lin_sobregiros
             WHERE nro_cuenta = p_nro_cuenta
               AND tipo = 'T';

            if v_can_mes_recalculo is not null then
              v_fec_vencimiento := add_months(v_fec_actual,
                                              v_can_mes_recalculo);
            else
              v_fec_vencimiento := v_fec_actual + 30;
            end if;
            --- Actualizo la fecha de inicio de sobregiro para la cuenta.
            update ge_cta_dat_adicionales
               set val_parametro = to_char(v_fec_actual, 'dd/mm/yyyy')
             where parametro = 'SOB_FEC_INI_LINEA'
               and nro_cuenta = p_nro_cuenta;

            BEGIN
              UPDATE cc_lin_sobregiros
                 SET fec_inicio      = to_date(v_fec_actual, 'dd/mm/rrrr'),
                     fec_vencimiento = v_fec_vencimiento,
                     monto           = nvl(monto, 0) - nvl(v_mto_cuenta, 0) +
                                       nvl(v_mto_sobregiro, 0)
               WHERE nro_cuenta = p_nro_cuenta;
               v_acu_sobregiro:= 'S'; --DYDMR-4334 ALV
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20035,
                                        'Error al actualizar datos en CC_LIN_SOBREGIRO. Sec.sobregiro : ' ||
                                        v_nro_sec_padre || ' ' || SQLERRM);
            END;

            BEGIN
              UPDATE cc_lin_sob_garantias
                 SET mto_aplicado = nvl(mto_aplicado, 0) -
                                    nvl(v_mto_cuenta, 0) +
                                    nvl(v_mto_sobregiro, 0)
               WHERE nro_secuencia = v_nro_sec_padre
                 AND cod_garantia = 1;
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20036,
                                        'Error al actualizar datos en CC_LIN_SOB_GARANTIAS. Sec.sobregiro : ' ||
                                        v_nro_sec_padre || ' ' || SQLERRM);
            END;

          ELSE
            BEGIN
              UPDATE cc_lin_sobregiros
                 SET monto = nvl(monto, 0) + nvl(v_mto_sobregiro, 0)
               WHERE nro_secuencia = v_nro_sec_padre;
               v_acu_sobregiro:= 'S'; --DYDMR-4334 ALV
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20035,
                                        'Error al actualizar datos en CC_LIN_SOBREGIRO. Sec.sobregiro : ' ||
                                        v_nro_sec_padre || ' ' || SQLERRM);
            END;

            BEGIN
              UPDATE cc_lin_sob_garantias
                 SET mto_aplicado = nvl(mto_aplicado, 0) +
                                    nvl(v_mto_sobregiro, 0)
               WHERE nro_secuencia = v_nro_sec_padre
                 AND cod_garantia = 1;
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20036,
                                        'Error al actualizar datos en CC_LIN_SOB_GARANTIAS. Sec.sobregiro : ' ||
                                        v_nro_sec_padre || ' ' || SQLERRM);
            END;
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              --Traer el Nro. de Secuencia--
              SELECT s_nro_lin_sobregiro.nextval
                INTO v_nro_sec_padre
                FROM dual;
            EXCEPTION
              WHEN no_data_found THEN
                v_nro_sec_padre := 1;
              WHEN OTHERS THEN
                raise_application_error(-20034,
                                        'Error al generar secuencia de sobregiro. Documento Nro= ' ||
                                        v_nro_cedula || ' ' || SQLERRM);
            END;
            if v_can_meses is not null then
              v_fec_vencimiento := add_months(v_fec_actual, v_can_meses);
            else
              v_fec_vencimiento := v_fec_actual + 30;
            end if;
            --
            BEGIN
              --v_lugar := '31-Insert CC_LIN_SOBREGIROS';
              INSERT INTO cc_lin_sobregiros
                (nro_cuenta,
                 fec_vencimiento,
                 fec_inicio,
                 nro_secuencia,
                 monto,
                 tipo,
                 cod_persona,
                 cod_moneda,
                 estado,
                 nro_sec_padre,
                 observacion,
                 niv_aprobacion,
                 cotizacion)
              VALUES
                (NULL,
                 v_fec_vencimiento,
                 v_fec_actual,
                 v_nro_sec_padre,
                 v_mto_sobregiro,
                 'T',
                 v_cod_persona,
                 v_cod_moneda,
                 'A',
                 NULL,
                 v_observacion,
                 7,
                 v_cot_original);
              v_acu_sobregiro := 'S'; --DYDMR-4334 ALV
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20035,
                                        'Error al insertar datos en CC_LIN_SOBREGIRO. Documento Nro= SECUENCIA= ' ||
                                        v_nro_sec_padre || ' PRUEBA ' ||
                                        v_nro_cedula || ' ' || SQLERRM);
            END;

            BEGIN
              --v_lugar := '33-Insert CC_LIN_SOB_GARANTIAS';
              INSERT INTO cc_lin_sob_garantias
                (mto_aplicado, nro_secuencia, cod_garantia)
              VALUES
                (v_mto_sobregiro, v_nro_sec_padre, 1);
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20041,
                                        'Error al insertar datos en CC_LIN_SOB_GARANTIAS. Documento Nro= ' ||
                                        v_nro_cedula || ' ' || SQLERRM);
            END;

          WHEN OTHERS THEN
            raise_application_error(-20035,
                                    'Error al generar secuencia de sobregiro. Documento Nro= ' ||
                                    v_nro_cedula || ' ' || SQLERRM);
        END;

        --
        IF P_TIP_CALCULO in ('G','M') THEN
          BEGIN
            --Traer el Nro. de Secuencia--
            SELECT s_nro_lin_sobregiro.nextval
              INTO v_nro_secuencia
              FROM dual;
          EXCEPTION
            WHEN no_data_found THEN
              v_nro_secuencia := 1;
            WHEN OTHERS THEN
              raise_application_error(-20034,
                                      'Error al generar secuencia de sobregiro. Documento Nro= ' ||
                                      v_nro_cedula || ' ' || SQLERRM);
          END;

          --
          if v_can_meses is not null then
            v_fec_vencimiento := add_months(v_fec_actual, v_can_meses);
          else
            v_fec_vencimiento := v_fec_actual + 30;
          end if;

          BEGIN
            --v_lugar := '32-Insert CC_LIN_SOBREGIROS';
            INSERT INTO cc_lin_sobregiros
              (nro_cuenta,
               fec_vencimiento,
               fec_inicio,
               nro_secuencia,
               monto,
               tipo,
               cod_persona,
               cod_moneda,
               estado,
               nro_sec_padre,
               observacion,
               niv_aprobacion,
               cotizacion)
            VALUES
              (p_nro_cuenta,
               v_fec_vencimiento,
               v_fec_actual,
               v_nro_secuencia,
               v_mto_sobregiro,
               'T',
               NULL,
               v_cod_moneda,
               'A',
               v_nro_sec_padre,
               v_observacion,
               7,
               v_cot_original);
             v_acu_sobregiro := 'S'; --DYDMR-4334 ALV
          EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20036,
                                      'Error al insertar datos en CC_LIN_SOBREGIRO. Documento Nro= ' ||
                                      v_nro_cedula || ' ' || SQLERRM);
          END;
          --- Actualizo la fecha de inicio de sobregiro para la cuenta. BBVADES 2576
          update ge_cta_dat_adicionales
             set val_parametro = to_char(v_fec_actual, 'dd/mm/yyyy')
           where parametro = 'SOB_FEC_INI_LINEA'
             and nro_cuenta = p_nro_cuenta;
        END IF;
      END IF;
    END IF;
    --DYDMR-4334 Se actualiza el valor del campo en la tabla maestra ALV
    if v_acu_sobregiro = 'S' then
      update cc_cta_corrientes c
         set c.acu_sobregiro = v_acu_sobregiro
       where c.nro_cuenta = P_NRO_CUENTA;
    end if;
  END;
  /**Proceso de Generación y Re-Cálculo de Líneas de Sobregiros**/

  PROCEDURE PR_PRO_LIN_SOBREGIRO(P_NRO_CUENTA  IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,
                                 P_COD_ENTE    IN GE_ENTES.COD_ENTE%TYPE DEFAULT NULL,
                                 P_TIP_CALCULO IN VARCHAR2 DEFAULT NULL) IS

    v_mto_sueldo     cr_per_ing_egresos.importe%type;
    v_por_lim_sueldo number;
    v_mto_sob_sueldo cc_lin_sobregiros.monto%type;

    cursor c_rec_sobregiros is
      select c.*, 'R' tip_calculo
        from cc_cta_corrientes c, ge_entes e, ge_cta_dat_adicionales a
       where c.cod_ente = e.cod_ente
         and e.tipo = 'SU'
         and c.nro_cuenta = a.nro_cuenta
         and a.parametro = 'SOB_FEC_INI_LINEA'
         and (c.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
         and (c.cod_ente = p_cod_ente or p_cod_ente is null)
         and c.cod_ente is not null
         and (p_tip_calculo = 'R' or p_tip_calculo is null)
         and exists (select *
                from cc_lin_sobregiros cc
               where cc.nro_cuenta = c.nro_cuenta);
    cursor c_gen_sobregiros is
      select c.*, 'G' tip_calculo
        from cc_cta_corrientes c, ge_entes e, ge_cta_dat_adicionales a
       where c.cod_ente = e.cod_ente
         and e.tipo = 'SU'
         and c.nro_cuenta = a.nro_cuenta
         and a.parametro = 'SOB_FEC_INI_LINEA'
         and (c.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
         and (c.cod_ente = p_cod_ente or p_cod_ente is null)
         and c.cod_ente is not null
         and (p_tip_calculo = 'G' or p_tip_calculo is null)
         and not exists (select *
                from cc_lin_sobregiros cc
               where cc.nro_cuenta = c.nro_cuenta);
    cursor c_rec_mas_sobregiros is
      select c.*, cta.cod_persona, 'M' tip_calculo
        from ge_nom_sobregiros_tmp c, ge_entes e, ge_cta_dat_adicionales a, ge_cta_clientes cta
       where c.cod_ente = e.cod_ente
         and e.tipo = 'SU'
         and c.nro_cuenta = a.nro_cuenta
         and a.parametro = 'SOB_FEC_INI_LINEA'
         and c.cod_ente is not null
         and c.nro_cuenta = cta.nro_cuenta
         and cta.relacion = 'P'
         and p_tip_calculo = 'M'
         and exists (select *
                from cc_lin_sobregiros cc
               where cc.nro_cuenta = c.nro_cuenta);
    cursor c_gen_mas_sobregiros is
      select c.*, cta.cod_persona, 'M' tip_calculo
        from ge_nom_sobregiros_tmp c, ge_entes e, ge_cta_dat_adicionales a, ge_cta_clientes cta
       where c.cod_ente = e.cod_ente
         and e.tipo = 'SU'
         and c.nro_cuenta = a.nro_cuenta
         and a.parametro = 'SOB_FEC_INI_LINEA'
         and c.cod_ente is not null
         and c.nro_cuenta = cta.nro_cuenta
         and cta.relacion = 'P'
         and p_tip_calculo = 'M'
         and not exists (select *
                from cc_lin_sobregiros cc
               where cc.nro_cuenta = c.nro_cuenta);

  begin
    FOR i in c_rec_sobregiros loop
      begin
        pag_nom.pr_gen_lin_sobregiro(i.nro_cuenta,
                                     i.cod_ente,
                                     i.tip_calculo,
                                     0,
                                     0);
      end;
    END LOOP;

    FOR j in c_gen_sobregiros loop
      begin
        pag_nom.pr_gen_lin_sobregiro(j.nro_cuenta,
                                     j.cod_ente,
                                     j.tip_calculo,
                                     0,
                                     0);
      end;
    END LOOP;

    FOR l in c_rec_mas_sobregiros loop

        insert into tm_log_sueldos
        (nro_cuenta, nro_documento, cod_ente, monto, lugar, observacion)
        values
        (l.nro_cuenta, null, l.cod_ente, l.monto, 'PR_PRO_LIN_SOBREGIRO',
        'Cliente ya cuenta con sobregiro vigente. Verifique.');

    END LOOP;

    FOR k in c_gen_mas_sobregiros loop

      v_mto_sueldo     := fug_obt_ing_cliente(k.cod_persona,null);
      v_por_lim_sueldo := fug_obt_parentes(k.cod_ente, 'POR_LIM_SUELDO');

      if v_por_lim_sueldo is not null then
        v_mto_sob_sueldo := (v_mto_sueldo*v_por_lim_sueldo)/100;
      else
        v_mto_sob_sueldo := 0;
      end if;

      begin
        pag_nom.pr_gen_lin_sobregiro(k.nro_cuenta,
                                     k.cod_ente,
                                     k.tip_calculo,
                                     nvl(k.monto,v_mto_sob_sueldo),
                                     0);
      end;
    END LOOP;

  end;
  /** Mejoras en Pago de Nómina Fase 3***/
  PROCEDURE PR_CAN_TAR_DEBITO(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE) IS
  BEGIN
    Update ah_tar_debitos
       set cod_est_solicitud = 16
     Where nro_cuenta = p_nro_cuenta
       and cod_est_solicitud not in (1, 2, 3, 16);

    Update ah_tar_debitos
       set cod_est_solicitud = 1
     Where nro_cuenta = p_nro_cuenta
       and cod_est_solicitud < 4;

    Delete from ah_tar_deb_cuentas
     Where nro_cta_relacionada = p_nro_cuenta;
  END;

  /* Cancela el Débito Automático asociado a una cuenta  - Mejora Pago de Nómina Fase 3*/
  PROCEDURE PR_CAN_DEB_AUTOMATICO(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) IS
   CURSOR c_pres IS
      SELECT nro_cuenta
        FROM pr_cta_prestamos
       WHERE nro_cta_debito = p_nro_cuenta
         AND estado = 'N';
    CURSOR c_soli IS
      SELECT nro_solicitud
        FROM pr_solicitudes
       WHERE nro_cta_debito = p_nro_cuenta;
    CURSOR c_tarj IS
      SELECT nro_cuenta
        FROM ta_cta_tarjetas
       WHERE nro_cta_debito = p_nro_cuenta;
    CURSOR c_tar_solicitudes IS
      SELECT nro_cuenta
        FROM ta_solicitudes
       WHERE nro_cta_debito = p_nro_cuenta;
    CURSOR c_contratos IS
      select nro_contrato
        from cs_contratos c
       where c.nro_cta_debito = p_nro_cuenta
         and c.estado not in ('C','R'); -- (C)ancelados y (R)echazados
    CURSOR c_cta_certificados IS
      select nro_cuenta
        from ah_cta_certificados a
       where a.nro_cta_credito = p_nro_cuenta
         and a.estado not in ('T','C');
  BEGIN
    FOR reg IN c_pres LOOP
      UPDATE pr_cta_prestamos
         SET nro_cta_debito = NULL, cob_automatico = 'N'
       WHERE nro_cuenta = reg.nro_cuenta;
    END LOOP;
    FOR reg IN c_soli LOOP
      UPDATE pr_solicitudes
         SET nro_cta_debito = NULL, deb_automatico = 'N'
       WHERE nro_solicitud = reg.nro_solicitud;
    END LOOP;
    FOR reg IN c_tarj LOOP
      UPDATE ta_cta_tarjetas
         SET nro_cta_debito = NULL, deb_automatico = 'N'
       WHERE nro_cuenta = reg.nro_cuenta;
    END LOOP;
    FOR reg IN c_tar_solicitudes LOOP
      UPDATE ta_solicitudes
         SET nro_cta_debito = NULL, deb_automatico = 'N'
       WHERE nro_cuenta = reg.nro_cuenta;
    END LOOP;
    FOR reg IN c_contratos LOOP
      UPDATE cs_contratos
         SET nro_cta_debito = NULL
       WHERE nro_contrato = reg.nro_contrato;
    END LOOP;
     FOR reg IN c_cta_certificados LOOP
      UPDATE ah_cta_certificados
         SET nro_cta_credito = NULL, cre_automatico = 'N'
       WHERE nro_cuenta = reg.nro_cuenta;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Cancela Cta.Débito -' || SQLERRM);
  END;
  /* Inserta en el Log de Pago de Cancelación de Pago de Nominas - Mejoras Pago de Nómina Fase 3 */
  PROCEDURE PR_INS_LOG(p_nro_cuenta       IN ge_cuentas.nro_cuenta%TYPE,
                       p_cod_error        IN ge_log_pag_nominas.cod_error%TYPE,
                       p_descripcion      IN VARCHAR2,
                       p_cod_usu_oficial  IN VARCHAR2 DEFAULT NULL,
                       p_cod_ente         IN VARCHAR2,
                       p_ind_desvinculado IN VARCHAR2 DEFAULT 'N',
                       p_nro_lote         IN NUMBER DEFAULT NULL) IS
    v_fecha DATE := pag_cal.fu_obt_fec_actual(1);
    v_hora  varchar2(8) := to_char(sysdate, 'HH24:MI:SS');
    v_existe varchar2(1);

    BEGIN
          select 'S'
            into v_existe
            from ge_log_pag_nominas
           where nro_cuenta = P_NRO_CUENTA
             and nro_lote = p_nro_lote
             /*and trunc(fecha) = trunc(v_fecha)
             and cod_error = P_COD_ERROR*/;
          
          if v_existe = 'S' then
            update ge_log_pag_nominas a
               set a.descripcion = substr(p_descripcion, 1, 400),
                   a.cod_error = p_cod_error,
                   a.fecha = v_fecha,
                   a.hora = v_hora
             where a.nro_cuenta = P_NRO_CUENTA
               and a.nro_lote = p_nro_lote;
          end if;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
              INSERT INTO ge_log_pag_nominas
                (nro_cuenta,
                 fecha,
                 cod_error,
                 descripcion,
                 hora,
                 cod_usu_oficial,
                 cod_ent_desv,
                 ind_desvinculado,
                 nro_lote)
              VALUES
                (p_nro_cuenta,
                 v_fecha,
                 p_cod_error,
                 substr(p_descripcion, 1, 400),
                 v_hora,
                 p_cod_usu_oficial,
                 p_cod_ente,
                 p_ind_desvinculado,
                 p_nro_lote);
      WHEN OTHERS THEN
        raise_application_error(-20001, 'Ins.Log Nominas -' || SQLERRM);
    END; 

  FUNCTION FU_VAL_CUENTA(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                         P_NRO_LOTE IN GE_TELEGRAMAS.NRO_LOTE%TYPE)
    RETURN BOOLEAN IS
    --- Variables de la Cuenta
    v_sal_retenido cc_cta_corrientes.sal_retenido%TYPE;
    --- Variables de Sobregiros
    v_gas_pendiente  cc_lin_sobregiros.monto%TYPE;
    v_sal_disponible cc_cta_corrientes.sal_total%TYPE;
    v_diferencia     cc_cta_corrientes.sal_total%TYPE;
    --- Variables de Control
    debcre     VARCHAR2(1);
    v_cantidad NUMBER;
    v_existe   VARCHAR2(1) := 'N';
    --- Variables para insertar en el Log de nominas
    v_cod_error   ge_log_pag_nominas.cod_error%TYPE := 0;
    v_descripcion VARCHAR2(4000);
    v_cod_ente    ge_entes.cod_ente%type;
  BEGIN
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    /**Verifico que la cuenta tenga un ente vinculado**/
    BEGIN
      SELECT c.cod_ente
        INTO v_cod_ente
        FROM cc_cta_corrientes c
       WHERE c.nro_cuenta = p_nro_cuenta
         AND c.estado in ('A', 'I', 'N')
      UNION
      SELECT a.cod_ente
        FROM ah_cta_vistas a
       WHERE a.nro_cuenta = p_nro_cuenta
         AND a.estado in ('A', 'I', 'N');
    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
      WHEN others THEN
        v_cantidad := 1;
    END;

    IF v_cantidad = 0 THEN
      v_cod_error   := 20;
      v_descripcion := 'No puede cancelar cuentas no vinculadas a entes.';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    
    --- Validar modalidades de pago de nómina.
    IF fug_obt_pardinamico('SUE_MAD_CLIENTES',
                           pag_cta.G_CTAS.COD_MODULO,
                           pag_cta.G_CTAS.COD_MODALIDAD,
                           NULL,
                           NULL) IS NULL THEN
      v_cod_error   := 30;
      v_descripcion := 'No puede cancelar producto que no sea de nómina';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         NULL,
                         NULL,
                         NULL,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    v_sal_retenido   := nvl(pag_cta.G_CTAS.SAL_RETENIDO, 0) +
                        nvl(pag_cta.G_CTAS.MTO_CRE_PENDIENTES, 0);
    v_sal_disponible := (nvl(pag_cta.G_CTAS.SAL_TOTAL, 0) +
                        nvl(pag_cta.G_CTAS.MTO_CRE_A_CONFIRMAR, 0)) -
                        (nvl(pag_cta.G_CTAS.SAL_BLOQUEADO, 0) +
                        nvl(pag_cta.G_CTAS.SAL_RETENIDO, 0) +
                        nvl(pag_cta.G_CTAS.MTO_DEB_PENDIENTES, 0));

    SELECT SUM(nvl(monto, 0))
      INTO v_gas_pendiente
      FROM cc_lin_sobregiros
     WHERE nro_cuenta = p_nro_cuenta
       AND fec_inicio IS NULL
       AND estado = 'A';
    IF v_sal_disponible <= v_gas_pendiente AND v_gas_pendiente != 0 THEN
      v_cod_error   := 40;
      v_descripcion := 'La cuenta no posee saldo para los gastos pendientes: ' ||
                       to_char(v_gas_pendiente, '999,999,999,999.99');
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    v_diferencia := nvl(v_sal_disponible,0) - nvl(v_gas_pendiente,0);
    IF pag_cta.G_CTAS.ESTADO NOT IN ('A', 'I', 'N') THEN
      v_cod_error   := 50;
      v_descripcion := 'No puede cancelar, el estado de la cuenta no lo permite';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    ELSIF nvl(v_diferencia,0) < 0 AND nvl(fug_obt_pardinamico('SUE_GEN_OPE_VENCIDA',NULL ,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL),'N')= 'N' THEN
      v_cod_error   := 60;
      v_descripcion := 'No se puede cancelar, la cuenta tiene saldo negativo';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    ELSIF nvl(pag_cta.G_CTAS.SAL_BLOQUEADO, 0) > 0 THEN
      v_cod_error   := 70;
      v_descripcion := 'No puede cancelar, tiene saldo bloqueado';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    ELSIF nvl(v_sal_retenido, 0) > 0 THEN
      v_cod_error   := 80;
      v_descripcion := 'No puede cancelar, tiene saldo retenido';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si la cuenta a cancelar esta relacionada con Prestamos **/
    BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM pr_cta_prestamos
       WHERE nro_cta_debito = p_nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
      WHEN too_many_rows THEN
        v_cantidad := 1;
    END;
    IF v_cantidad > 0 and fug_obt_pardinamico('PAG_NOM_PRE_CLIE') = 'S' THEN
      v_cod_error   := 220;
      v_descripcion := 'Cuenta es Débito Automático de Prestamos(s)';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si la cuenta a cancelar es Débito Automático de Solicitudes de Préstamos **/
    BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM pr_solicitudes
       WHERE nro_cta_debito = p_nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
      WHEN too_many_rows THEN
        v_cantidad := 1;
    END;
    IF v_cantidad > 0 and fug_obt_pardinamico('PAG_NOM_PRE_CLIE') = 'S' THEN
      v_cod_error   := 230;
      v_descripcion := 'Cuenta es débito automático de Solicitudes de Prestamos(s)';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si está asociado a un Paquete **/
    SELECT COUNT(t.cod_paquete)
      INTO v_cantidad
      FROM ge_paq_cuentas t, ge_paq_clientes c
     WHERE t.cod_paquete = c.cod_paquete
       AND t.cod_persona = c.cod_persona
       AND t.nro_secuencia = c.nro_secuencia
       AND t.nro_cuenta = p_nro_cuenta
       AND c.estado = 'N';
    IF v_cantidad > 0 and fug_obt_pardinamico('PAG_NOM_PAQ_CLIE') = 'S' THEN
      v_cod_error   := 190;
      v_descripcion := 'No puede cancelar, Cuenta pertenece a Paquete';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si posee Cheque en Custodia **/
    SELECT COUNT(1)
      INTO v_cantidad
      FROM ge_che_custodias
     WHERE nro_referencia = p_nro_cuenta
       AND estado IN ('C');
    IF v_cantidad > 0 THEN
      v_cod_error   := 170;
      v_descripcion := 'No puede cancelar, Cuenta posee Cheques en Custodia';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si posee Chequeras Emitidas **/
    SELECT COUNT(1)
      INTO v_cantidad
      FROM cc_chequeras
     WHERE nro_cuenta = p_nro_cuenta
       AND estado = 'E';
    IF v_cantidad > 0 and fug_obt_pardinamico('PAG_NOM_CHQ_CAN') = 'S' THEN
      v_cod_error   := 180;
      v_descripcion := 'No puede cancelar, Cuenta posee Chequeras Emitidas';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si la cuenta a Cancelar esta relacionada con Tarjetas  **/
    BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM ta_cta_tarjetas
       WHERE nro_cta_debito = p_nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
      WHEN too_many_rows THEN
        v_cantidad := 1;
    END;
    IF v_cantidad > 0 and fug_obt_pardinamico('PAG_NOM_TAR_CRE') = 'S' THEN
      v_cod_error   := 210;
      v_descripcion := 'Cuenta es Débito Automático de Tarjeta(s)';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    IF pag_cta.G_CTAS.CTA_COMBINADA = 'S' and fug_obt_pardinamico('PAG_NOM_CTA_COM') = 'S' THEN
      v_cod_error   := 90;
      v_descripcion := 'No puede cancelar, participa en cuenta combinada';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifico si la cuenta tiene movimientos pendientes y exonero lo que cubra el Límite de exoneración **/
     BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM ge_mov_pendientes
       WHERE nro_cuenta = p_nro_cuenta
         AND estado = 'I'
         AND rownum = 1;
     EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
     END;

    if v_cantidad > fug_obt_pardinamico('PAG_NOM_MTO_MAX') and fug_obt_pardinamico('PAG_NOM_MOV_PEN') = 'S' then
        PR_EXO_MOV_PENDIENTE(p_nro_cuenta,
                             pag_cta.G_CTAS.cod_modulo,
                             pag_cta.G_CTAS.cod_modalidad,
                             pag_cta.G_CTAS.cod_moneda,
                             pag_cta.G_CTAS.cod_oficina,
                             null);
    end if;

    /** Vuelvo a verificar si hubo movimientos no exonerados para generar el log**/
    BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM ge_mov_pendientes
       WHERE nro_cuenta = p_nro_cuenta
         AND estado = 'I'
         AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
    END;

    IF v_cantidad > fug_obt_pardinamico('PAG_NOM_MTO_MAX') and fug_obt_pardinamico('PAG_NOM_MOV_PEN') = 'S' THEN
      v_cod_error   := 100;
      v_descripcion := 'No puede cancelar, tiene Movimientos Pendientes no Liquidados';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si posee Movimientos Pendientes de Confirmación **/
    SELECT COUNT(1)
      INTO v_cantidad
      FROM ge_movimientos
     WHERE nro_cuenta = p_nro_cuenta
       AND reversado = 'N'
       AND estado IN ('J', 'X', 'P')
       AND rownum = 1;
    IF v_cantidad > 0 THEN
      v_cod_error   := 200;
      v_descripcion := 'No puede cancelar, Cuenta tiene Movimientos Pendientes de Confirmacion';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si posee Gastos de Sobregiros Pendientes **/
    BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM cc_sobregiros
       WHERE nro_cuenta = p_nro_cuenta
         AND liquidado = 'N';
    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
      WHEN too_many_rows THEN
        v_cantidad := 1;
    END;
    BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM cc_lin_sobregiros
       WHERE nro_cuenta = p_nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
      WHEN too_many_rows THEN
        v_cantidad := 1;
    END;
    IF v_cantidad > 0 THEN
      v_cod_error   := 160;
      v_descripcion := 'No puede cancelar, Cuenta tiene una Linea de Sobregiro o Sobregiros Pendientes de regularizar';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Valida que no sea cuenta plazo fijo **/
    BEGIN
      SELECT COUNT(1)
        INTO v_cantidad
        FROM ah_cta_plazos
       WHERE nro_cuenta = p_nro_cuenta
         AND estado <> 'C';

    EXCEPTION
      WHEN no_data_found THEN
        v_cantidad := 0;
      WHEN too_many_rows THEN
        v_cantidad := 1;
      WHEN OTHERS THEN
        NULL;
    END;
    IF v_cantidad > 0 THEN
      v_cod_error   := 110;
      v_descripcion := 'No puede cancelar, es cuenta de capitalizacion en plazo fijo';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    -- no es cta a plazo fijo
    /** Verifica si es una Cuenta parametrizada para Transacción Automática **/
    BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ge_par_dinamicos
       WHERE val_parametro = p_nro_cuenta;
    EXCEPTION
      WHEN OTHERS THEN
        v_existe := 'N';
    END;
    IF v_existe = 'S' THEN
      v_cod_error   := 120;
      v_descripcion := 'No puede Cancelar, es Cuenta de Débito/Crédito de Transaccion Automática';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    /** Verifica si es una Cuenta Parametrizada para Transacciones de Entes **/
    BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ge_par_entes
       WHERE val_parametro = p_nro_cuenta;
    EXCEPTION
      WHEN OTHERS THEN
        v_existe := 'N';
    END;
    IF v_existe = 'S' THEN
      v_cod_error   := 130;
      v_descripcion := 'No puede Cancelar, es Cuenta de Transaccion de Entes';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;

    IF nvl(v_sal_disponible, 0) < 0 AND pag_cta.G_CTAS.COD_MODALIDAD <> 41 THEN
      --cta ctes se puede cancelar en negativo
      v_cod_error   := 140;
      v_descripcion := 'No puede Cancelar, Cuenta con Saldo Deudor';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    ELSIF nvl(v_diferencia, 0) < 0 AND pag_cta.G_CTAS.COD_MODALIDAD <> 41 THEN
      --cta ctes se puede cancelar en negativo
      v_cod_error   := 150;
      v_descripcion := 'Cuenta quedará con Saldo Deudor. Verifique!!';
      pag_nom.pr_ins_log(p_nro_cuenta,
                         v_cod_error,
                         v_descripcion,
                         null,
                         null,
                         null,
                         p_nro_lote);
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END;

  /** Obtiene las Cuentas de Nominas de Clientes que recibieron Colasionados.**/
  PROCEDURE PR_CAN_NOMINA IS
    v_existe       varchar2(1);
    v_can_dias     number;
    v_tip_persona  ba_personas.tipo%type;
    v_fec_actual   date;
    v_fecha        date;
    v_fec_cap      ah_cta_vistas.fec_ult_capitalizacion%type;
    v_fec_apertura ah_cta_vistas.fec_apertura%type;

    v_cod_telegrama     ge_telegramas.cod_telegrama%type;
    v_causa             ge_telegramas.cod_causa%type;
    v_cod_modulo        ge_cta_clientes.cod_modulo%type;
    v_cod_modalidad     ge_cta_clientes.cod_modalidad%type;
    v_mto_interes       NUMBER(18, 2) := 0;
    v_nro_cuenta        ge_cta_clientes.nro_cuenta%type;
    v_cod_tasa          ge_tas_fechas.val_tasa%type;
    v_val_tasa          ge_tas_fechas.val_tasa%type;
    v_cod_oficina       ge_cuentas.cod_oficina%type;
    v_cod_moneda        ge_cuentas.cod_moneda%type;
    v_aut_pendiente     ah_cta_vistas.aut_pendiente%type;
    v_sal_total         ah_cta_vistas.sal_total%type;
    v_tas_personalizada ah_cta_vistas.tas_personalizada%type;
    --variable de tipo registro
    r_gmovi               ge_movimientos%rowtype;
    v_cod_usuario         ge_movimientos.cod_usuario%type;
    v_cod_tra_padre       ge_transacciones.cod_transaccion%type;
    v_cod_mod_padre       ge_transacciones.cod_modulo%type;
    v_cod_mad_padre       ge_transacciones.cod_modalidad%type;
    v_cod_ofi_origen      ba_oficinas.cod_oficina%type;
    v_estado              ge_est_cuentas.estado%type;
    g_cod_error           pag_cta.G_COD_ERROR%type;
    v_sal_disponible      number;
    v_cod_cau_cancelacion ge_telegramas.cod_cau_cancelacion%type;
    v_monto               number;
    v_saldo               number;
    v_direccion           ge_telegramas.direccion%type;
    v_nro_casa            ge_telegramas.nro_casa%type;
    v_telefono            ge_telegramas.telefono%type;
    v_localidad           ge_telegramas.localidad%type;
    v_cod_sub_modalidad   cc_cta_corrientes.cod_sub_modalidad%type;
    v_mto_min_cancelacion varchar2(25);
    v_est_cancelacion VARCHAR2(1);
    v_cod_error   ge_log_pag_nominas.cod_error%TYPE := 0;
    v_descripcion VARCHAR2(4000);

    /* Cursor que trae las cuentas  de los Clientes a los cuales se le envió Colasionado*/
    CURSOR c_tel is
      SELECT t.cod_telegrama, t.cod_causa, t.zona,t.fec_entrega, t.cod_persona,
      t.ref_cuentas, t.monto, t.cod_moneda, t.direccion, t.nro_casa, t.telefono,
      t.cod_cau_cancelacion, t.localidad, t.usu_insercion, 
      trunc(t.fec_insercion) fec_insercion, t.nro_lote,
      'S' telegrama
        FROM ge_telegramas t, cc_cta_corrientes c, ah_cta_vistas v
       WHERE instr(fug_obt_pardinamico('SUE_CAU_TEL_DESVINCULACION'),
                   t.cod_causa) > 0
         AND (v_fec_actual - t.fec_entrega) >
             (fug_obt_parcausales(t.cod_causa, 'CAN_DIA_CANCELACION'))
         AND t.estado <> 'N'
         AND t.ref_cuentas = c.nro_cuenta(+)
         AND t.ref_cuentas = v.nro_cuenta(+)
         AND (c.estado not in('C','P')
         OR v.estado not in('C','P'))

         union all

         select null,null, null,null,null,c.nro_cuenta,c.sal_total, c.cod_moneda,null,null,null,
                null, null,user,null,x.nro_lote,'N'
           from cc_cta_corrientes c,
                (select nvl(max(a.nro_lote),0) nro_lote, a.nro_cuenta
                   from ge_log_pag_nominas a, ge_cta_dat_adicionales b
                  where a.nro_cuenta = b.nro_cuenta
                    and b.val_parametro = 'S'
                    and a.descripcion like '%insertada para su posterior cancelación en el cierre%'
                  group by a.nro_cuenta) x
          where c.estado not in('P','C')
            and c.nro_cuenta = x.nro_cuenta
            and exists (select 1 from ge_cta_dat_adicionales a
                          where a.parametro = 'CAN_CTA_NOM_MASIVA'
                            and a.val_parametro = 'S'
                            and a.nro_cuenta = c.nro_cuenta)

         union all

         select null,null, null,null,null,v.nro_cuenta,v.sal_total, v.cod_moneda,null,null,null,
                null, null,user,null,x.nro_lote,'N'
           from ah_cta_vistas v,
                (select nvl(max(a.nro_lote),0) nro_lote, a.nro_cuenta
                   from ge_log_pag_nominas a, ge_cta_dat_adicionales b
                  where a.nro_cuenta = b.nro_cuenta
                    and b.val_parametro = 'S'
                    and a.descripcion like '%insertada para su posterior cancelación en el cierre%'
                  group by a.nro_cuenta) x
          where v.estado not in('P','C')
            and v.nro_cuenta = x.nro_cuenta
            and exists (select 1 from ge_cta_dat_adicionales a
                          where a.parametro = 'CAN_CTA_NOM_MASIVA'
                            and a.val_parametro = 'S'
                            and a.nro_cuenta = v.nro_cuenta);

  BEGIN
    v_fec_actual := pag_cal.fu_obt_fec_actual(4);
    v_hora:= to_char(sysdate, 'HH24:MI:SS');
    --v_hora       := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
    v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    v_nro_secuencia := 0;
    FOR c in c_tel loop
      /** Mejoras para el Proceso de Desvinculación de Cuentas pago de Nóminas - PCCMN-291 - MDCV **/
      begin
        select trunc(ad.fec_insercion)
          into v_fecha
          from ge_cta_dat_adicionales ad
         where ad.parametro = 'CAN_CTA_NOM_MASIVA'
           and ad.val_parametro = 'S'
           and ad.nro_cuenta = c.ref_cuentas;
      exception
        when others then
           v_fecha := null;
      end;
      begin
        select 'S'
          into v_existe
          from ge_pag_sueldos su
         where su.fec_proceso between nvl(c.fec_insercion,v_fecha) and v_fec_actual
           and su.nro_cuenta = c.ref_cuentas
           and su.tipo = 'C'
           and rownum = 1;
      exception
        when others then
           v_existe := 'N';
      end;
      --Verifica si tuvo algún movimiento de crédito
      begin
        select 'S'
          into v_existe
          from gv_movimientos m
         where m.fecha between nvl(c.fec_insercion,v_fecha) and v_fec_actual
           and m.nro_cuenta = c.ref_cuentas
           and m.cod_tra_padre in (303,3303,333)
           and m.reversado = 'N'
           and m.estado = 'N'
           and rownum = 1;
      exception
        when others then
           v_existe := 'N';
      end;
      IF v_existe = 'S' then
         if c.cod_causa is not null then  
           pag_nom.pr_ins_log(c.ref_cuentas,
                               210,
                               'Cuenta con movimientos de pago de salario.',
                               null,
                               null,
                               null,
                               c.nro_lote);

           begin
             update ge_telegramas t
                set t.estado = 'N'
              where t.cod_telegrama = c.cod_telegrama;
           exception
             when others then
                  raise_application_error(-20000,'Error al actualizar en ge_telegramas. Telegrama nro.: ' || 
                                                    c.cod_telegrama || '-' || SQLERRM);
           end;
         else  
           begin  
             update ge_cta_dat_adicionales ad
                set ad.val_parametro = 'N'
              where ad.nro_cuenta = c.ref_cuentas
                and ad.parametro = 'CAN_CTA_NOM_MASIVA';
           exception
             when others then
                  raise_application_error(-20000,'Error al actualizar en ge_cta_dat_adicionales. Cta: ' || 
                                                    c.ref_cuentas || '-' || SQLERRM);
           end;
         end if;
      else
        IF pag_nom.fu_val_cuenta(c.ref_cuentas,c.nro_lote) THEN
         if v_nro_secuencia >= 990 then
            --v_hora          := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
            v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
            v_nro_secuencia := -999;
         end if;
          -- indica que no hubo errores
          IF c.telegrama = 'S' then
          begin
            select 'S',
                   t.monto,
                   t.saldo,
                   t.direccion,
                   t.nro_casa,
                   t.telefono,
                   t.localidad
              into v_existe,
                   v_monto,
                   v_saldo,
                   v_direccion,
                   v_nro_casa,
                   v_telefono,
                   v_localidad
              from ge_telegramas t
             where instr(fug_obt_pardinamico('SUE_CAU_TEL_CANCELACION'),
                         c.cod_causa) > 0
               and instr(ref_cuentas, ref_cuentas) > 0;
          exception
            when others then
              v_existe := 'N';
          end;
         end if;
          --Obtener datos de la cuenta
          pag_cta.PR_OBT_CUENTA(c.ref_cuentas);
          v_sal_disponible := PAG_CTA.G_CTAS.sal_disponible;

          --
          /** Si no se ha enviado se genera el Telegrama de Cancelación **/
          if nvl(v_existe, 'N') = 'N' or c.telegrama = 'N' then

              pag_cta.pr_obt_cuenta(c.ref_cuentas);
              v_nro_cuenta        := pag_cta.g_ctas.nro_cuenta;
              v_cod_modulo        := pag_cta.g_ctas.cod_modulo;
              v_cod_modalidad     := pag_cta.g_ctas.cod_modalidad;
              v_sal_total         := pag_cta.g_ctas.sal_total;
              v_tas_personalizada := pag_cta.g_ctas.tas_personalizada;
              v_aut_pendiente     := pag_cta.g_ctas.autorizado;
              v_cod_oficina       := pag_cta.g_ctas.cod_oficina;
              v_cod_moneda        := pag_cta.g_ctas.cod_moneda;
              v_cod_tasa          := pag_cta.g_ctas.cod_tasa;
              v_fecha             := pag_cal.FU_OBT_FEC_ACTUAL(3);
              v_fec_cap           := pag_cta.g_ctas.fec_ult_capitalizacion;
              v_fec_apertura      := pag_cta.g_ctas.fec_apertura;
              v_estado            := pag_cta.g_ctas.estado;

            --Un parámetro para deudor y otro para acreedor
            if nvl(v_sal_total,0) >= 0 then --ENE/2017 OMM DYDMR-5912
               v_mto_min_cancelacion := nvl(fug_obt_pardinamico('PAG_NOM_MTO_CRE',
                                                             v_cod_modulo,
                                                             v_cod_modalidad,
                                                             v_cod_moneda,
                                                             v_cod_oficina,
                                                             v_cod_sub_modalidad),0);
            elsif nvl(v_sal_total,0) < 0 then
               v_mto_min_cancelacion := nvl(fug_obt_pardinamico('PAG_NOM_MTO_DEB',
                                                             v_cod_modulo,
                                                             v_cod_modalidad,
                                                             v_cod_moneda,
                                                             v_cod_oficina,
                                                             v_cod_sub_modalidad),0);
            end if;
            
            if c.telegrama = 'S' then

                v_causa               := pag_nom.FU_OBT_CAU_CAN_MASIVA('G',
                                                                       c.ref_cuentas,
                                                                       null,
                                                                       'E');
                v_cod_cau_cancelacion := nvl(pag_nom.FU_OBT_CAU_CAN_MASIVA('C',
                                                                       c.ref_cuentas,
                                                                       null,
                                                                       'E'),c.cod_cau_cancelacion);


                if v_causa is not null and abs(v_sal_disponible)> v_mto_min_cancelacion then
                  SELECT s_cod_telegrama.NEXTVAL INTO v_cod_telegrama FROM dual;

                  insert into ge_telegramas
                    (cod_telegrama,
                     cod_causa,
                     fec_generacion,
                     tip_entrega,
                     fec_entrega,
                     cod_persona,
                     estado,
                     ref_cuentas,
                     monto,
                     saldo,
                     cod_moneda,
                     direccion,
                     nro_casa,
                     telefono,
                     cod_cau_cancelacion,
                     localidad)
                  values
                    (v_cod_telegrama,
                     v_causa,
                     v_fec_actual,
                     null,
                     null,
                     c.cod_persona,
                     'G',
                     c.ref_cuentas,
                     v_sal_disponible,
                     v_sal_disponible,
                     c.cod_moneda,
                     c.direccion,
                     c.nro_casa,
                     c.telefono,
                     v_cod_cau_cancelacion,
                     c.localidad);
                end if;
           end if;
           IF v_cod_modalidad = '31' THEN
              /** Obtiene el Interes **/
              pra_cap_cta_vista(v_nro_cuenta, 'N', v_fecha, v_mto_interes);
              /** Obtiene el Valor de la Tasa**/
              v_val_tasa := fug_obt_val_tasa(v_cod_modulo,
                                             v_cod_modalidad,
                                             v_cod_oficina,
                                             c.ref_cuentas,
                                             v_cod_moneda,
                                             v_sal_total,
                                             v_tas_personalizada,
                                             v_cod_tasa,
                                             null,
                                             pag_cal.fu_obt_fec_actual(3));

              update ah_cta_vistas
                 set sal_total              = nvl(v_sal_total, 0) +
                                              nvl(v_mto_interes, 0),
                     fec_ult_capitalizacion = v_fecha,
                     sal_ult_capitalizacion = nvl(sal_total, 0) +
                                              nvl(v_mto_interes, 0),
                     fec_ult_movimiento     = v_fecha,
                     hor_ult_movimiento     = v_hora
               where nro_cuenta = v_nro_cuenta;

              /** Genera  Movimiento por el Interés **/
              if nvl(v_mto_interes, 0) > 0 then
                v_nro_secuencia := v_nro_secuencia + 1;

                r_gmovi.nro_secuencia   := v_nro_secuencia;
                r_gmovi.cod_usuario     := user;
                r_gmovi.hora            := v_hora;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.cod_modulo      := v_cod_modulo;
                r_gmovi.cod_modalidad   := v_cod_modalidad;
                r_gmovi.cod_oficina     := v_cod_oficina;
                r_gmovi.nro_cuenta      := c.ref_cuentas;
                r_gmovi.cod_moneda      := v_cod_moneda;
                r_gmovi.est_cuenta      := null;
                r_gmovi.cod_tra_padre   := 325;
                r_gmovi.cod_transaccion := 609;
                r_gmovi.concepto        := 'CAPITALIZACION DE INTERES AV';
                r_gmovi.monto := nvl(v_mto_interes, 0);
                r_gmovi.estado            := 'N';
                r_gmovi.reversado         := 'N';
                r_gmovi.fec_valor          := v_fec_actual;
                r_gmovi.emi_aviso      := 'N';
                r_gmovi.cod_ofi_origen := pag_cta.g_ctas.cod_oficina;
                r_gmovi.cod_tasa       := v_cod_tasa;
                r_gmovi.val_tasa       := v_val_tasa;
                r_gmovi.cod_mod_padre  := v_cod_modulo;
                r_gmovi.cod_mad_padre  := v_cod_modalidad;
                pag_gen.pr_ins_ge_movimiento(r_gmovi);

              end if;

              v_sal_disponible:= nvl(v_sal_disponible,0) + nvl(v_mto_interes,0);
              if v_sal_disponible < v_mto_min_cancelacion then
                /** Actualizar el estado de la Cuenta **/
                if v_sal_disponible > 0 then
                   PR_COB_CARGO(v_nro_cuenta,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_cod_oficina,
                           v_cod_moneda,
                           v_sal_disponible,
                           v_cod_cau_cancelacion);
                end if;
                  /** Setea los valores iniciales **/
                PAG_CTA.PR_SET_VARIABLES(c.usu_insercion,
                                         pag_cal.FU_OBT_FEC_ACTUAL(1),
                                         '301', -- Pasar a (P)endiente de Cancelacion
                                         'N'/*v_estado*/,--DYDMR-3289 - Diferencias Batch / Online en Estados
                                         'N',
                                         v_nro_secuencia,
                                         null,
                                         v_cod_oficina,
                                         v_cod_modulo,
                                         v_cod_modalidad);


                 pag_cta.PR_ACT_ESTADO(c.ref_cuentas, -- nro_cuenta del cursor
                                       'C',
                                       pag_cal.FU_OBT_FEC_ACTUAL(1),
                                       v_hora,
                                       substr(nvl(v_cod_telegrama,c.cod_telegrama),1,15));

                --inserto en el log la cancelacion
                pag_nom.pr_ins_log(c.ref_cuentas,
                               250,
                               'Cuenta cancelada en el proceso masivo de cancelaciones.',
                               null,
                               null,
                               null,
                               c.nro_lote);
                /* 24/06/2014: SPI 3930 Se eliminan de los parámetros adicionales para que en caso de que una
                                        cuenta no deba ser cancelada y se realice el ajuste de la misma a Normal
                                        no sea nuevamente cancelada */
                
                BEGIN
                  delete from ge_cta_dat_adicionales
                   where nro_cuenta = c.ref_cuentas
                     and parametro = 'CAN_CTA_NOM_MASIVA';
                EXCEPTION
                  WHEN OTHERS THEN
                    raise_application_error(-20001,
                                            'No se puede eliminar el parámetro de Cancelación - Cta. '||c.ref_cuentas ||' - '|| SQLERRM);
                END;

                 v_nro_secuencia := v_nro_secuencia + 1;
                /** Cancelar la Tarjeta de Débito **/
                pag_nom.pr_can_tar_debito(c.ref_cuentas);
              else
                  /** Actualizar el estado de la Cuenta **/
                 PAG_CTA.PR_SET_VARIABLES(c.usu_insercion,
                                         pag_cal.FU_OBT_FEC_ACTUAL(1),
                                         '405', -- Pasar a (P)endiente de Cancelacion
                                         'N'/*v_estado*/,--DYDMR-3289 - Diferencias Batch / Online en Estados
                                         'N',
                                         v_nro_secuencia,
                                         null,
                                         v_cod_oficina,
                                         v_cod_modulo,
                                         v_cod_modalidad);

                 pag_cta.PR_ACT_ESTADO(c.ref_cuentas, -- nro_cuenta del cursor
                                       'P',
                                       pag_cal.FU_OBT_FEC_ACTUAL(1),
                                       v_hora,
                                       substr(nvl(v_cod_telegrama,c.cod_telegrama),1,15));

                 v_nro_secuencia := v_nro_secuencia + 1;
                --inserto en el log la cancelacion
                pag_nom.pr_ins_log(c.ref_cuentas,
                               240,
                               'Cuenta Pendiente de Cancelacion desde el proceso masivo de cancelaciones.',
                               null,
                               null,
                               null,
                               c.nro_lote);
                /** Cancelar la Tarjeta de Débito **/
                pag_nom.pr_can_tar_debito(c.ref_cuentas); -- nro_cuenta del cursor
              end if;
            elsif v_cod_modalidad = '41' THEN
               if v_sal_disponible < 0 and
                  abs(v_sal_disponible) > v_mto_min_cancelacion and
                    NVL(fug_obt_pardinamico('SUE_GEN_OPE_VENCIDA',v_cod_modulo,
                                                             v_cod_modalidad,
                                                             v_cod_moneda,
                                                             v_cod_oficina,
                                                             v_cod_sub_modalidad),'N')='S' then

                PRV_PAS_VEN_SOBREGIROS(v_nro_cuenta,
                                       null,
                                       v_cod_cau_cancelacion,
                                       'Cancelación Masiva de Nóminas','S',c.nro_lote);
                --inserto en el log el pase a vencido
                pag_nom.pr_ins_log(c.ref_cuentas,
                               260,
                               'Operacion Vencida generada para la cuenta.',
                               null,
                               null,
                               null,
                               c.nro_lote);
                pag_nom.pr_can_tar_debito(c.ref_cuentas); -- nro_cuenta del cursor
              else
                if ((v_sal_disponible > 0) and (v_sal_disponible < v_mto_min_cancelacion)) then
                    PR_COB_CARGO(v_nro_cuenta,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_cod_oficina,
                           v_cod_moneda,
                           v_sal_disponible,
                           v_cod_cau_cancelacion);
                end if;
                if v_sal_disponible < 0 then
                   v_cod_error:= 60;
                   v_descripcion:= 'No se puede cancelar, la cuenta tiene saldo negativo';

                   pag_nom.pr_ins_log(v_nro_cuenta,
                           v_cod_error,
                           v_descripcion,
                           NULL,
                           NULL,
                           NULL,
                           c.nro_lote);
                end if;

                /** Actualizar el estado de la Cuenta **/
                if nvl(v_sal_disponible,0) < v_mto_min_cancelacion then
                   v_est_cancelacion:= 'C';
                   v_cod_tra_padre := 301;
                else
                   v_est_cancelacion:= 'P';
                   v_cod_tra_padre := 405;
                end if;

                if (v_sal_disponible >= 0) then

                        /** Setea los valores iniciales **/
                    PAG_CTA.PR_SET_VARIABLES(c.usu_insercion,
                                             pag_cal.FU_OBT_FEC_ACTUAL(1),
                                             v_cod_tra_padre,--'405', -- Pasar a (P)endiente de Cancelacion
                                             'N'/*v_estado*/,--DYDMR-3289 - Diferencias Batch / Online en Estados
                                             'N',
                                             v_nro_secuencia,
                                             null,
                                             v_cod_oficina,
                                             v_cod_modulo,
                                             v_cod_modalidad);

                     pag_cta.PR_ACT_ESTADO(c.ref_cuentas, -- nro_cuenta del cursor
                                          v_est_cancelacion,
                                          pag_cal.FU_OBT_FEC_ACTUAL(1),
                                          v_hora,
                                          substr(nvl(v_cod_telegrama,c.cod_telegrama),1,15));
                   --inserto en el log la cancelacion
                   if v_est_cancelacion = 'C' then
                      pag_nom.pr_ins_log(c.ref_cuentas,
                               250,
                               'Cuenta cancelada en el proceso masivo de cancelaciones.',
                               null,
                               null,
                               null,
                               c.nro_lote);
                   else   
                      pag_nom.pr_ins_log(c.ref_cuentas,
                                     240,
                                     'Cuenta Pendiente de Cancelacion desde el proceso masivo de cancelaciones.',
                                     null,
                                     null,
                                     null,
                                     c.nro_lote);
                   end if;
                   /* 24/06/2014: SPI 3930 Se eliminan de los parámetros adicionales para que en caso de que una
                                  cuenta no deba ser cancelada y se realice el ajuste de la misma a Normal
                                  no sea nuevamente cancelada */

                    BEGIN
                      delete from ge_cta_dat_adicionales
                       where nro_cuenta = c.ref_cuentas
                         and parametro = 'CAN_CTA_NOM_MASIVA';
                    EXCEPTION
                      WHEN OTHERS THEN
                        raise_application_error(-20001,
                                                'No se puede eliminar el parámetro de Cancelación - Cta. '||c.ref_cuentas ||' - '|| SQLERRM);
                    END;

                    v_nro_secuencia := v_nro_secuencia + 1;
                    /** Cancelar la Tarjeta de Débito **/
                    pag_nom.pr_can_tar_debito(c.ref_cuentas); -- nro_cuenta del cursor
                end if;
              end if;
            end if;
          end if;
        end if;
      end if;
    end loop; -- todo debe realizar dentro del loop
  END;

  -- RABP-PCC 11-11-2013:
  -- Desviculamos del ente, lac Ctas registradas en el LOG de Cancelacion Masiva despues de un cierto tiempo --
  PROCEDURE PR_PRO_DESVINCULACION IS
    cursor c_cta_desvinculadas is
      select n.nro_cuenta,
             n.fecha,
             n.hora,
             n.cod_error,
             n.cod_ent_desv,
             c.cod_modulo,
             c.cod_modalidad
        from ge_log_pag_nominas n, ge_cta_clientes c
       where n.nro_cuenta = c.nro_cuenta
         and c.relacion = 'P'
         and c.cod_modulo in (3, 4)
         and ((fue_obt_fec_calendar(1) - n.fecha) -
             fug_obt_pardinamico('DIA_PER_DESVINCULACION')) > 0
         and exists (select 1
                from ba_cod_referencias r
               where r.dominio = 'COD_ERR_DESVINCULACIONES'
                 and r.val_minimo = n.cod_error)
         and n.ind_desvinculado = 'N';
    -- tabla temporal
    TYPE r_desvinculados IS RECORD(
      oficial ge_clientes.cod_usu_oficial%TYPE);
    TYPE t_desvinculados IS TABLE OF r_desvinculados;
    v_desvinculados t_desvinculados;

    -- variables para mail
    v_recibe   ba_usuarios.dir_correo%TYPE;
    v_env_mail varchar2(1) := nvl(fug_obt_pardinamico('SUE_ENV_MAIL_DESVINCULACION'),'N');
    v_asunto   VARCHAR2(200) := 'Desvinculación de Cuentas de un Ente.';
    v_mje_mail VARCHAR2(4000) := 'Se comunica por este medio que existe/n una/s cuenta/s en la cual usted figura como gestor y las cuales fueron desvinculadas de un ente.
Para mas detalles favor ejecutar la consulta dinámica "LOG DE PAGO DE NOMINAS".';

  BEGIN
    BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    -- Hallamos los oficiales de las cuentas a desvincular
    select distinct n.cod_usu_oficial bulk collect
      into v_desvinculados
      from ge_log_pag_nominas n
     where ((fue_obt_fec_calendar(1) - n.fecha) -
           fug_obt_pardinamico('DIA_PER_DESVINCULACION')) > 0
       and exists (select 1
              from ba_cod_referencias r
             where r.dominio = 'COD_ERR_DESVINCULACIONES'
               and r.val_minimo = n.cod_error)
       and n.ind_desvinculado = 'N';

    -- Desvinculamos las cuentas
    FOR i in c_cta_desvinculadas loop
      -- Cuentas Corrientes
      if i.cod_modalidad = 41 then
        -- Insertamos el codigo de ente en el log de nominas --
        update ge_log_pag_nominas
           set ind_desvinculado = 'S'
         where nro_cuenta = i.nro_cuenta
           and fecha = i.fecha
           and hora = i.hora
           and cod_error = i.cod_error
           and cod_ent_desv = i.cod_ent_desv;
        -- Desvinculamos la cuenta del ente ---
        update cc_cta_corrientes
           set cod_ente = null
         where nro_cuenta = i.nro_cuenta;
      end if;
      -- Caja de Ahorros
      if i.cod_modalidad = 31 then
        -- Insertamos el codigo de ente en el log de nominas --
        update ge_log_pag_nominas
           set ind_desvinculado = 'S'
         where nro_cuenta = i.nro_cuenta
           and fecha = i.fecha
           and hora = i.hora
           and cod_error = i.cod_error
           and cod_ent_desv = i.cod_ent_desv;
        -- Desvinculamos la cuenta del ente ---
        update ah_cta_vistas a
           set cod_ente = null
         where nro_cuenta = i.nro_cuenta;
      end if;

    END LOOP;
  if v_env_mail = 'S' then
    FOR vInd IN 1 .. v_desvinculados.count LOOP
      v_recibe := FUG_OBT_DIR_MAIL_USU(v_desvinculados(vInd).oficial);
      IF v_recibe IS NOT NULL THEN
        -- Enviamos el mail a los gestores
        it_mail.mail(fug_obt_dir_correo, -- De:
                     v_recibe, -- Para:
                     v_asunto, -- Asunto:
                     v_mje_mail -- Mensaje:
                     );
      END IF;
    END LOOP;
  end if;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20008,
                              'Error al desvincular cuentas -' || SQLERRM);
  END;

  PROCEDURE PR_EXO_MOV_PENDIENTE(P_NRO_CUENTA        IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_MODULO        IN ge_cuentas.cod_modulo%type,
                                 P_COD_MODALIDAD     IN ge_cuentas.cod_modalidad%type,
                                 P_COD_MONEDA        IN ge_cuentas.cod_moneda%type,
                                 P_COD_OFICINA       IN ge_cuentas.cod_oficina%type,
                                 P_COD_SUB_MODALIDAD IN ge_cuentas.cod_sub_modalidad%type) IS

    v_saldo               number := 0;
    v_mto_total           number(20);
    v_mto_min_exoneracion varchar2(25) := nvl(fug_obt_pardinamico('SUE_LIM_EXO_MOV_PENDIENTES',
                                                              p_cod_modulo,
                                                              p_cod_modalidad,
                                                              p_cod_moneda,
                                                              p_cod_oficina,
                                                              p_cod_sub_modalidad),0);

    cursor mov_pendientes is
      select saldo, cod_movimiento
        from ge_mov_pendientes m
       where nro_cuenta = p_nro_cuenta
         and estado = 'I';

  begin
  begin
       select sum(saldo) mto_total
         into v_mto_total
         from ge_mov_pendientes m
        where nro_cuenta = p_nro_cuenta
          and estado = 'I';
  end;
    if v_mto_total <= v_mto_min_exoneracion then

    for x in mov_pendientes loop
       begin
          update ge_mov_pendientes
             set mto_exonerado = nvl(mto_exonerado,0) + x.saldo
           where nro_cuenta = p_nro_cuenta
             and cod_movimiento = x.cod_movimiento;
       end;
    end loop;
    end if;
  end;

   /**Cobro de cargos si el saldo no supera el monto mínimo de cancelación**/

  PROCEDURE PR_COB_CARGO(P_NRO_CUENTA        IN ge_cuentas.nro_cuenta%TYPE,
                         P_COD_MODULO        IN ge_cuentas.cod_modulo%TYPE,
                         P_COD_MODALIDAD     IN ge_cuentas.cod_modalidad%TYPE,
                         P_COD_OFICINA       IN ge_cuentas.cod_oficina%TYPE,
                         P_COD_MONEDA        IN ge_cuentas.cod_moneda%TYPE,
                         P_SAL_DISPONIBLE    IN number,
                         P_CAUSA             IN ge_telegramas.cod_cau_cancelacion%TYPE)is
  v_tra_prohibida varchar2(1);
  v_tie_tra_prohibida varchar2(1);
  v_aut_pendiente varchar2(1);
  v_cod_tra_padre ge_transacciones.cod_transaccion%type := 301;
  v_cod_transaccion ge_transacciones.cod_transaccion%type := 501;
  v_cod_tra_impuesto ge_transacciones.cod_transaccion%type := 502;
  v_eximido ge_autorizaciones.eximido%type;
  v_pue_cobrar varchar2(1);
  r_gmovi ge_movimientos%rowtype;
  v_cod_tasa ge_tasas.cod_tasa%type;
  v_tip_valor ge_tasas.tip_valor%type;
  v_tipo ge_tasas.tipo%type;
  v_tas_personalizada varchar2(1);
  v_val_tasa ge_tas_fechas.val_tasa%type;
  v_mto_cargo number;
  v_mto_impuesto number;
  v_porcen number(3);
  v_cod_tas_impuesto ge_tasas.cod_tasa%type;
  v_val_tas_impuesto ge_tas_fechas.val_tasa%type;
  v_fec_vigencia date;

  begin
     v_fec_actual := pag_cal.fu_obt_fec_actual(4);
     v_pue_cobrar := 'S';
     v_mto_cargo:= p_sal_disponible;

     if v_nro_secuencia = 990 then
        --v_hora          := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
        v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
        v_nro_secuencia := -999;
     end if;

     If p_cod_modulo = 4 Then
        Select aut_pendiente, tra_prohibida,tas_personalizada
          into v_aut_pendiente, v_tra_prohibida,v_tas_personalizada
          from cc_cta_corrientes
         where nro_cuenta = p_nro_cuenta;
     ElsIf p_cod_modulo = 3 Then --AHORROS A LA VISTA
        Select aut_pendiente, tra_prohibida,tas_personalizada
          into v_aut_pendiente, v_tra_prohibida,v_tas_personalizada
          from ah_cta_vistas
         where nro_cuenta  = p_nro_cuenta;
     end if;

     if v_tra_prohibida = 'S' then
       v_tie_tra_prohibida := pag_cta.fu_ver_tra_prohibida(p_nro_cuenta, v_cod_transaccion,
                                               p_cod_modulo,p_cod_modalidad);
        if v_tie_tra_prohibida = 'S' then
           v_pue_cobrar:= 'N';
        end if;
     end if;
           --Se verifica si tiene autorización pendiente
        if v_aut_pendiente = 'S' and v_pue_cobrar = 'S' then
              PR_VER_AUTORIZACION(v_tie_tra_prohibida,
                                  p_cod_modulo,
                                  p_cod_modalidad,
                                  p_cod_oficina,
                                  p_nro_cuenta,
                                  v_cod_tra_padre,
                                  v_cod_transaccion,
                                  v_eximido);
               IF v_tie_tra_prohibida = 'S' AND v_eximido = 'S' THEN
                  v_pue_cobrar:= 'N';
               END IF;
        end if;
        if v_pue_cobrar = 'S' then
          -- Buscar el valor de la tasa para el cargo

           PAG_GEN.PR_OBT_VAL_TASA(p_cod_modulo,p_cod_modalidad,p_cod_oficina,
                 p_nro_cuenta,  p_cod_moneda, 0,v_tas_personalizada,
                 v_cod_tasa, v_cod_transaccion,v_fec_actual,v_val_tasa,v_fec_vigencia,
                 v_tip_valor, v_tipo);

          --Buscar el valor de la tasa para el impuesto

           PAG_GEN.PR_OBT_VAL_TASA(p_cod_modulo,p_cod_modalidad,p_cod_oficina,
                 p_nro_cuenta,  p_cod_moneda, 0,v_tas_personalizada,
                 v_cod_tas_impuesto, v_cod_tra_impuesto,v_fec_actual,v_val_tas_impuesto,v_fec_vigencia,
                 v_tip_valor, v_tipo);
          --Calcula el valor del impuesto del cargo

           IF NVL(v_mto_cargo,0) != 0 AND
              v_cod_tas_impuesto IS NOT NULL AND v_val_tas_impuesto IS NOT NULL THEN

                 V_PORCEN := NVL(v_val_tas_impuesto,0) + 100;
                  if p_cod_moneda = pag_gen.fu_obt_mon_local then
                    v_mto_impuesto := ROUND(NVL(v_mto_cargo,0) *  --IMTRANS
                                             NVL(v_val_tas_impuesto,0)/V_PORCEN,0);
                  Else
                    v_mto_impuesto := ROUND(NVL(v_mto_cargo,0) *  --IMTRANS
                                             NVL(v_val_tas_impuesto,0)/V_PORCEN,2);
                  End If;

                --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                v_mto_impuesto := pag_gen.FU_OBT_VAL_FINAL(v_mto_impuesto);

                if trunc(nvl(v_mto_impuesto,0)) > 0 then
                   v_mto_cargo := v_mto_cargo - v_mto_impuesto;
                else
                  v_mto_impuesto:= 0;
                end if;
            END IF;



           -- Prepara el registro para insertar en GE_MOVIMIENTOS por el cargo
           v_nro_secuencia := nvl(v_nro_secuencia, 1) + 1;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_usuario     := user;
           r_gmovi.hora            := v_hora;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.cod_modulo      := p_cod_modulo;
           r_gmovi.cod_modalidad   := p_cod_modalidad;
           r_gmovi.cod_oficina     := p_cod_oficina;
           r_gmovi.nro_cuenta      := p_nro_cuenta;
           r_gmovi.cod_moneda      := p_cod_moneda;
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := v_cod_tra_padre;
           r_gmovi.cod_transaccion := v_cod_transaccion;
           r_gmovi.est_cuenta      := null;
           r_gmovi.estado          := 'N';
           r_gmovi.cod_ofi_origen  := p_cod_oficina;
           r_gmovi.reversado       := 'N';
           r_gmovi.emi_aviso       := 'S';
           r_gmovi.protegido       := 'N';
           r_gmovi.cod_mod_padre   := p_cod_modulo;
           r_gmovi.cod_mad_padre   := p_cod_modalidad;
           r_gmovi.monto           := v_mto_cargo;
           r_gmovi.nro_documento   := null;
           r_gmovi.cod_causa       := p_causa;
           r_gmovi.cod_tasa        := v_cod_tasa;
           r_gmovi.val_tasa        := v_val_tasa;
           r_gmovi.concepto        := 'CUENTA CANCELADA';
           --Inserta en GE_MOVIMIENTOS
           pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

        if trunc(nvl(v_mto_impuesto,0)) > 0 then
           -- Generación de movimientos por el impuesto
           v_nro_secuencia := nvl(v_nro_secuencia, 1) + 1;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_usuario     := user;
           r_gmovi.hora            := v_hora;
           r_gmovi.fecha           := v_fec_actual;
           r_gmovi.cod_modulo      := p_cod_modulo;
           r_gmovi.cod_modalidad   := p_cod_modalidad;
           r_gmovi.cod_oficina     := p_cod_oficina;
           r_gmovi.nro_cuenta      := p_nro_cuenta;
           r_gmovi.cod_moneda      := p_cod_moneda;
           r_gmovi.fec_valor       := v_fec_actual;
           r_gmovi.cod_tra_padre   := v_cod_tra_padre;
           r_gmovi.cod_transaccion := v_cod_tra_impuesto;
           r_gmovi.est_cuenta      := null;
           r_gmovi.estado          := 'N';
           r_gmovi.cod_ofi_origen  := p_cod_oficina;
           r_gmovi.reversado       := 'N';
           r_gmovi.emi_aviso       := 'S';
           r_gmovi.protegido       := 'N';
           r_gmovi.cod_mod_padre   := p_cod_modulo;
           r_gmovi.cod_mad_padre   := p_cod_modalidad;
           r_gmovi.monto           := v_mto_impuesto;
           r_gmovi.nro_documento   := null;
           r_gmovi.cod_causa       := p_causa;
           r_gmovi.cod_tasa        := v_cod_tas_impuesto;
           r_gmovi.val_tasa        := v_val_tas_impuesto;
           r_gmovi.concepto        := 'CUENTA CANCELADA';
           --Inserta en GE_MOVIMIENTOS
           pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
        end if;

        if p_cod_modulo = 4 then
            Update CC_CTA_CORRIENTES
               set SAL_TOTAL = nvl(SAL_TOTAL,0) -  nvl(v_mto_impuesto, 0) - nvl(v_mto_cargo, 0),
                   tra_prohibida = 'N',
                   cod_cau_cancelacion = p_causa
             where NRO_CUENTA = p_nro_cuenta;
        else
            Update ah_cta_vistas
             set SAL_TOTAL = nvl(SAL_TOTAL,0) -  nvl(v_mto_impuesto, 0) - nvl(v_mto_cargo, 0),
                 tra_prohibida = 'N',
                 cod_cau_cancelacion = p_causa
           where NRO_CUENTA = p_nro_cuenta;
        end if;

        end if;
  end;
   PROCEDURE PR_VER_AUTORIZACION(P_TRA_PROHIBIDA IN OUT   VARCHAR2,
         P_MODULO     IN     NUMBER,
         P_MODALIDAD  IN     NUMBER,
         P_OFICINA    IN     NUMBER,
         P_NRO_CUENTA     IN       VARCHAR2,
         P_COD_TRA_PADRE    IN     NUMBER,
         P_COD_TRANSACCION    IN     NUMBER,
         P_EXIMIDO    IN OUT   VARCHAR2 )IS

   BEGIN
       SELECT EXIMIDO
         INTO P_EXIMIDO
         FROM GE_AUTORIZACIONES
        WHERE GE_AUTORIZACIONES.COD_MODULO = P_MODULO
          AND GE_AUTORIZACIONES.COD_MODALIDAD = P_MODALIDAD
          AND GE_AUTORIZACIONES.NRO_CUENTA = P_NRO_CUENTA
          AND GE_AUTORIZACIONES.COD_TRA_PADRE = P_COD_TRA_PADRE
          AND GE_AUTORIZACIONES.COD_TRANSACCION= P_COD_TRANSACCION;

       IF SQL%FOUND THEN
          P_TRA_PROHIBIDA := 'S';
       END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
           P_TRA_PROHIBIDA := 'N';
    END;
end pag_nom;
/


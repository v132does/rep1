CREATE OR REPLACE PROCEDURE IT.prs_sb_tas_ape_semanales is
  v_valor_cambio       ge_cotizaciones.val_conversion%type;
  v_cod_moneda         mi_sb_tas_ape_semanales.cod_moneda%type;
  v_monto              sb_tas_ape_semanales.monto%type;
  v_mto_ape_original   sb_tas_ape_semanales.mto_ape_original%type;
  v_periodo            number(5);
  v_acod               varchar2(5);
  v_corcod             varchar2(10);
  v_entcod             mi_sb_tas_ape_semanales.entcod%type;
  v_codcta             mi_sb_tas_ape_semanales.codcta%type;
  v_plazo              NUMBER(5);
  v_tasreg             mi_sb_tas_ape_semanales.tasreg%type;
  v_tip_capitalizacion ah_cta_certificados.tip_capitalizacion%type;
  v_error              log_mi_sb_tas_ape_semanales.error%type;

  v_cod_mon_local ge_par_generales.cod_mon_local%type;
  r_pcpre         pr_cta_prestamos%rowtype;
  v_fec_apertura  ge_cuentas.fec_apertura%type;

  r_mcdoc md_cta_documentos%rowtype;
  V_FECHA date := PAG_CAL.FU_OBT_FEC_ACTUAL(1);

  Cursor c_tasem is
    select *
      from sb_tas_ape_semanales a
     where trunc(a.fec_apertura) = v_fecha;

begin
  
  v_cod_mon_local := pag_gen.fu_obt_mon_local;

  /* ENTCOD: Es el código de entidad (código BCP) */
  BEGIN
    SELECT cod_entidad
      INTO v_entcod
      FROM GE_PAR_GENERALES
     WHERE ROWNUM = 1;
  EXCEPTION
    WHEN OTHERS THEN
      v_entcod := 6004;
  END;

  for c_tas in c_tasem loop
  
    if c_tas.cod_modalidad = 675 then
      v_fec_apertura := pag_cal.fu_obt_fec_actual(6);
    else
      v_fec_apertura := c_tas.fec_apertura;
    end if;
    /* MONEDA: Para guaraníes 6900, y dolares 6200 */
    IF c_tas.cod_mon_original <> v_cod_mon_local THEN
      v_cod_moneda := '6200';
      /* Recuperar Valor de Cambio */
      BEGIN
        v_valor_cambio := pag_gen.FU_OBT_COTIZACION(c_tas.cod_mon_original,
                                                    TRUNC(c_tas.fec_apertura));
      EXCEPTION
        WHEN OTHERS THEN
          v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                     SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
          INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
            (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES
            (SYSDATE, v_error, 'Problemas al recuperar cotizacion');
      END;
      --Comentado se informa el saldo de fin de mes de los rubros de ahorro a pedido del Dpto. de Contabilidad.
      --Historicamente estan informando el saldo de los rubros y no el promedio de los mismos. 26/10/2011.- AP 2230.
      v_monto            := (nvl(c_tas.monto, 0) * nvl(v_valor_cambio, 0)) / 1000;
      v_mto_ape_original := (nvl(c_tas.mto_ape_original, 0) *
                            nvl(v_valor_cambio, 0)) / 1000;
    ELSE
      v_cod_moneda := '6900';
      --Comentado se informa el saldo de fin de mes de los rubros de ahorro a pedido del Dpto. de Contabilidad.
      --Historicamente estan informando el saldo de los rubros y no el promedio de los mismos. 26/10/2011.- AP 2230.
      v_monto            := nvl(c_tas.monto, 0) / 1000;
      v_mto_ape_original := nvl(c_tas.mto_ape_original, 0) / 1000;
    END IF;
    /* CORCOD: Fecha de corte semanal, se ingresa como parámetro.
    Estas fechas de corte son proveídas por el BCP */
    BEGIN
      SELECT SEMANA
        INTO v_corcod
        FROM SB_SEMANAS
       WHERE v_fec_apertura BETWEEN DESDE AND HASTA;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                   SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
        INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
          (FECHA_PROCESO, ERROR, MENSAJE)
        VALUES
          (SYSDATE, v_error, 'La fecha ingresada no es válida');
      WHEN OTHERS THEN
        v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                   SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
        INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
          (FECHA_PROCESO, ERROR, MENSAJE)
        VALUES
          (SYSDATE, v_error, 'Problemas al determinar semana');
    END;
  
    /* CODCTA: Es el tipo de operación cartera relacionada con contabilidad,
    solo 156000, en este caso (CDA) */
    if c_tas.cod_modalidad = 34 then
      v_codcta := '214000';
    elsif c_tas.cod_modalidad = 41 then
      v_codcta := '189000';
    elsif c_tas.cod_modulo = 5 then
      v_codcta := '205002';
      -- BBVANOR-90
    elsif fug_obt_pardinamico('MDD_MAD_EMI_CALLMONEY',
                              c_tas.cod_modulo,
                              c_tas.cod_modalidad,
                              null,
                              null,
                              null) = 'S' then
      v_codcta := '391000';
      v_acod   := 1046;
    elsif fug_obt_pardinamico('MDD_MAD_REC_CALLMONEY',
                              c_tas.cod_modulo,
                              c_tas.cod_modalidad,
                              null,
                              null,
                              null) = 'S' then
      v_codcta := '304000';
      v_acod   := 2150;
    else
      --- Prestamos, ah.vista y CDA
      v_codcta := fug_obt_mod_sup_rubro(c_tas.cod_modulo, c_tas.nro_cuenta);
      v_codcta := rpad(substr(v_codcta, 1, 3), 6, '0');
      if nvl(fup_obt_tip_descuento(c_tas.cod_modalidad), 'x') in ('F', 'C') then
        v_codcta := '405001'; -- descuento de cheques
      elsif nvl(fup_obt_tip_descuento(c_tas.cod_modalidad), 'x') = 'D' then
        v_codcta := '351000'; -- descuento de documentos   Pedido 79/08 (Modif. T)
      end if;
      IF c_tas.cod_modulo = 6 THEN
        --Obtener datos del préstamo
        BEGIN
          pap_pre.pr_obt_dat_prestamo(c_tas.nro_cuenta, r_pcpre);
        EXCEPTION
          WHEN OTHERS THEN
            v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                       SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
            INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
              (FECHA_PROCESO, ERROR, MENSAJE)
            VALUES
              (SYSDATE,
               v_error,
               'Problemas al recuperar Datos del Préstamo');
        END;
        IF r_pcpre.cod_ori_fondo =
           FUG_OBT_PARDINAMICO('COD_ORI_FON_AFD',
                               null,
                               null,
                               r_pcpre.cod_moneda,
                               null,
                               null) THEN
          v_codcta := '209004';
        ELSIF r_pcpre.cod_ori_fondo =
              FUG_OBT_PARDINAMICO('COD_ORI_FON_BCP',
                                  null,
                                  null,
                                  r_pcpre.cod_moneda,
                                  null,
                                  null) THEN
          v_codcta := '209002';
        END IF;
      END IF;
    end if;
    if c_tas.cod_modalidad = 31 then
      v_plazo              := 0;
      v_tip_capitalizacion := 3; --- Fijo Trimestral, la mayoria
      select decode(v_tip_capitalizacion,
                    1,
                    30,
                    2,
                    60,
                    3,
                    90,
                    4,
                    120,
                    6,
                    180,
                    12,
                    365,
                    99,
                    v_plazo,
                    null)
        into v_periodo
        from dual;
      /* TASREG: Vencida o Adelantada, en este caso solamente Vencida (V) */
      v_tasreg := 'V';
      /* ACOD: Es el área que corresponde, de acuerdo al plazo de la operación */
      v_acod := 2021;
    elsif c_tas.cod_modalidad = 33 then
      BEGIN
        SELECT FEC_VENCIMIENTO - FEC_APERTURA
          INTO v_plazo
          FROM ah_cta_certificados
         WHERE nro_cuenta = c_tas.NRO_CUENTA;
      EXCEPTION
        WHEN OTHERS THEN
          v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                     SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
          INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
            (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES
            (SYSDATE, v_error, 'Problemas al recuperar plazo');
      END;
      IF v_codcta = '104000' THEN
        IF v_plazo <= 90 THEN
          v_acod := '2034';
        ELSIF v_plazo <= 180 THEN
          v_acod := '2035';
        ELSIF v_plazo <= 365 THEN
          v_acod := '2036';
        ELSIF v_plazo > 365 THEN
          v_plazo := 365;
          v_acod  := '2037';
        END IF;
      ELSIF v_codcta = '156000' THEN
        IF v_plazo <= 180 THEN
          v_acod := '2075';
        ELSIF v_plazo <= 365 THEN
          v_acod := '2076';
        ELSIF v_plazo > 365 THEN
          v_plazo := 365;
          v_acod  := '2077';
        END IF;
      ELSE
        IF v_plazo > 365 THEN
          v_plazo := 365;
        END IF;
        v_acod := fus_obt_are_bcp_cta(c_tas.nro_cuenta, c_tas.cod_modulo);
      
      END IF;
      /* PERIODO: Depende del tipo de capitalización (TIP_CAPITALIZACION)
      de la tabla ah_cta_certificados */
      BEGIN
        SELECT TIP_CAPITALIZACION
          INTO v_tip_capitalizacion
          FROM AH_CTA_CERTIFICADOS
         WHERE NRO_CUENTA = c_tas.NRO_CUENTA;
      EXCEPTION
        WHEN OTHERS THEN
          v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                     SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
          INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
            (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES
            (SYSDATE,
             v_error,
             'Problemas al recuperar Tipo de Capitalizacion');
      END;
      select decode(v_tip_capitalizacion,
                    1,
                    30,
                    2,
                    60,
                    3,
                    90,
                    4,
                    120,
                    6,
                    180,
                    12,
                    365,
                    99,
                    v_plazo,
                    null)
        into v_periodo
        from dual;
      /* TASREG: Vencida o Adelantada, en este caso solamente Vencida (V) */
      v_tasreg := 'V';
    -- Plazo Fijo
    elsif c_tas.cod_modalidad in (37, 38) then
      BEGIN
        SELECT fec_vencimiento - fec_apertura, TIP_CAPITALIZACION
          INTO v_plazo, v_tip_capitalizacion
          FROM ah_cta_plazos
         WHERE nro_cuenta = c_tas.nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                     SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
          INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
            (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES
            (SYSDATE, v_error, 'Problemas al recuperar Plazo y Tipo Capitalizacion');
      END;
      IF v_codcta = '104000' THEN
        IF v_plazo <= 90 THEN
          v_acod := '2034';
        ELSIF v_plazo <= 180 THEN
          v_acod := '2035';
        ELSIF v_plazo <= 365 THEN
          v_acod := '2036';
        ELSIF v_plazo > 365 THEN
          v_plazo := 365;
          v_acod  := '2037';
        END IF;
      ELSIF v_codcta = '156000' THEN
        IF v_plazo <= 180 THEN
          v_acod := '2075';
        ELSIF v_plazo <= 365 THEN
          v_acod := '2076';
        ELSIF v_plazo > 365 THEN
          v_plazo := 365;
          v_acod  := '2077';
        END IF;
      ELSE
        IF v_plazo > 365 THEN
          v_plazo := 365;
        END IF;
        v_acod := fus_obt_are_bcp_cta(c_tas.nro_cuenta, c_tas.cod_modulo);
      
      END IF;
      
      select decode(v_tip_capitalizacion, 1, 30,
                    2, 60,
                    3, 90,
                    4, 120,
                    6, 180,
                    12,365,
                    99, v_plazo, null)
        into v_periodo
        from dual;
      /* TASREG: Vencida o Adelantada, en este caso solamente Vencida (V) */
      v_tasreg := 'V';
    end if;
    --- Prestamos
    if c_tas.cod_modulo = 6 then
      v_tasreg := r_pcpre.tip_interes;
      v_acod   := fus_obt_are_bcp_cta(c_tas.nro_cuenta, c_tas.cod_modulo);
      --- informar el promedio si la cuenta es de modalidad descuento en periodo
      If fup_obt_tip_descuento(r_pcpre.cod_modalidad) in ('D', 'C', 'F') then
        select avg(fec_vencimiento - r_pcpre.fec_inicio)
          into v_periodo
          from pr_cuotas
         where nro_cuenta = c_tas.nro_cuenta
           and nro_cuota > 0;
      else
        v_periodo := r_pcpre.per_vto_capital;
        If r_pcpre.can_cuotas = 1 then
          v_periodo := r_pcpre.fec_vencimiento - r_pcpre.fec_inicio;
        End if;
      End if;
      if v_periodo > 365 then
        --- Agregado el 23/06/08 pedido: Juan Silvero de BCP dijo que el sistema de tasas no acepta periodo > 365
        v_periodo := 365;
      end if;
    end if;
    --- Tarjetas
    if c_tas.cod_modulo = 5 then
      v_tasreg  := 'V';
      v_acod    := fus_obt_are_bcp_cta(c_tas.nro_cuenta, c_tas.cod_modulo);
      v_periodo := 30;
    end if;
    --- Sobregiros
    if c_tas.cod_modulo = 4 then
      v_tasreg  := 'V';
      v_acod    := fus_obt_are_bcp_cta(c_tas.nro_cuenta, c_tas.cod_modulo);
      v_periodo := 30;
    end if;
    --- Verificar el monto
    if v_monto < 1 then
      v_monto := 1;
    end if;
    --- Call Money
    if c_tas.cod_modulo = 10 then
      pam_doc.pr_obt_datos(c_tas.nro_cuenta, r_mcdoc);
      v_tasreg  := r_mcdoc.tip_calculo;
      v_periodo := r_mcdoc.fec_vencimiento - r_mcdoc.fec_inicio;
    end if;
    BEGIN
      INSERT INTO MI_SB_TAS_APE_SEMANALES
        (NRO_CUENTA,
         COD_MODULO,
         COD_MODALIDAD,
         COD_MON_ORIGINAL,
         COD_MONEDA,
         FEC_APERTURA,
         MTO_APE_ORIGINAL,
         MONTO,
         VAL_TAS_NOMINAL,
         VAL_TAS_EFECTIVA,
         COD_PLAZO,
         CORCOD,
         ENTCOD,
         CODCTA,
         ACOD,
         PERIODO,
         TASREG,
         USU_INSERCION,
         FEC_INSERCION,
         USU_MODIFICACION,
         FEC_MODIFICACION)
      VALUES
        (c_tas.NRO_CUENTA,
         c_tas.COD_MODULO,
         c_tas.COD_MODALIDAD,
         c_tas.COD_MON_ORIGINAL,
         v_cod_moneda,
         v_fec_apertura,
         v_mto_ape_original,
         v_monto,
         c_tas.VAL_TAS_NOMINAL,
         c_tas.VAL_TAS_EFECTIVA,
         c_tas.COD_PLAZO,
         v_corcod,
         v_entcod,
         v_codcta,
         v_acod,
         v_periodo,
         v_tasreg,
         c_tas.USU_INSERCION,
         c_tas.FEC_INSERCION,
         c_tas.USU_MODIFICACION,
         c_tas.FEC_MODIFICACION);
    EXCEPTION
      WHEN OTHERS THEN
        v_error := 'Cuenta: ' || c_tas.nro_cuenta || ' - ' ||
                   SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
        INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
          (FECHA_PROCESO, ERROR, MENSAJE)
        VALUES
          (SYSDATE,
           v_error,
           'Problemas al insertar datos en tabla destino');
    END;

  end loop;
exception
  when others then
       raise_application_error(-20000,'Error en Ejecución de: PRS_SB_TAS_APE_SEMANALES - '||sqlerrm);
end PRS_SB_TAS_APE_SEMANALES;
/


CREATE OR REPLACE PROCEDURE IT.prg_cal_ofe_clientes(p_cod_persona    ba_personas.cod_persona%TYPE,
                                                    p_cat_crc        ba_per_gen_ofertas.cod_cat_crc%TYPE,
                                                    p_deu_tot_crc    ba_per_gen_ofertas.tot_deu_crc%TYPE,
                                                    p_faja           ba_per_gen_ofertas.faja%TYPE,
                                                    p_fec_ing_set    ba_per_gen_ofertas.fec_ing_set%TYPE,
                                                    p_ant_infomercio ba_per_gen_ofertas.ant_infomercio%TYPE,
                                                    p_rta_servicio   ba_per_gen_ofertas.rta_servicio%TYPE,
                                                    p_error          ba_per_gen_ofertas.error%TYPE,
                                                    p_cod_error      OUT NUMBER,
                                                    p_msj_error      OUT VARCHAR2) IS
  ----------
  v_cod_error NUMBER;
  v_msj_error VARCHAR2(2000);
  ----------
  v_deu_teorica    NUMBER;
  v_cuo_maxima     NUMBER;
  v_cuo_aproximada NUMBER;
  v_mto_ingreso    NUMBER;
  v_por_cli_nue    NUMBER;
  v_cuo_minima     NUMBER;
  v_mto_lim_max    NUMBER;
  v_cod_registro   NUMBER;
  v_est_servicio   VARCHAR2(1);
  v_est_rrnn       VARCHAR(1);
  ----------    
  v_mto_oferta NUMBER;
  v_can_cuotas NUMBER;
  v_cod_moneda VARCHAR2(3);
  ----------
  v_mto_lim_pre NUMBER;
  v_tip_ingreso ge_ing_clientes.tip_ingreso%TYPE;
  v_antiguedad  NUMBER;
  ----------
  PROCEDURE ge_ins_log(p_cod_registro IN NUMBER,
                       p_cod_persona  IN ba_personas.cod_persona%TYPE,
                       p_cod_error    IN NUMBER,
                       p_msj_error    IN VARCHAR2) IS
  BEGIN
    INSERT INTO ba_log_per_gen_ofe
      (cod_registro, cod_persona, cod_error, msj_error)
    VALUES
      (p_cod_registro, p_cod_persona, p_cod_error, p_msj_error);
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al inserta log. ' || SQLERRM);
  END;

BEGIN
  BEGIN
    pre_ini_aplicacion;
  END;
  --
  v_cod_error   := null;
  v_msj_error   := null;
  v_por_cli_nue := fug_obt_pardinamico('BAS_PRO_CLI_NUEV');
  v_mto_lim_max := fug_obt_pardinamico('BAS_MTO_LIM_OFE_CLI_NUE');
  --
  BEGIN
    SELECT o.cod_registro, nvl(o.mto_lim_prestable, 0)
      INTO v_cod_registro, v_mto_lim_pre
      FROM ba_per_gen_ofertas o
     WHERE o.cod_persona = p_cod_persona
       AND o.est_servicios = 'P';
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_error := 5;
      v_msj_error := 'ERROR. Oferta no encontrada para el cliente ' ||
                     p_cod_persona;
      ge_ins_log(v_cod_registro, p_cod_persona, v_cod_error, v_msj_error);
    WHEN too_many_rows THEN
      SELECT o.cod_registro, nvl(o.mto_lim_prestable, 0)
        INTO v_cod_registro, v_mto_lim_pre
        FROM ba_per_gen_ofertas o
       WHERE o.cod_persona = p_cod_persona
         AND o.est_servicios = 'P'
         AND o.fec_consulta =
             (SELECT min(o.fec_consulta)
                FROM ba_per_gen_ofertas o
               WHERE o.cod_persona = p_cod_persona
                 AND o.est_servicios = 'P');
    WHEN OTHERS THEN
      v_cod_error := 6;
      v_msj_error := 'ERROR. Al buscar la oferta ' || SQLERRM;
      ge_ins_log(v_cod_registro, p_cod_persona, v_cod_error, v_msj_error);
  END;
  --
  IF upper(p_rta_servicio) = 'ACEPTAR' THEN
    v_est_servicio := 'V';
    v_est_rrnn     := 'P';
  ELSIF upper(p_rta_servicio) = 'RECHAZAR' THEN
    v_est_servicio := 'R';
    v_est_rrnn     := 'R';
  ELSIF upper(p_rta_servicio) = 'ERROR' THEN
    v_est_servicio := 'E';
    v_est_rrnn     := 'E';
  ELSE
    v_est_servicio := 'E';
    v_est_rrnn     := 'E';
  END IF;
 
 IF upper(p_rta_servicio) = 'ACEPTAR' THEN   
  IF p_cat_crc > 1 THEN
    v_cod_error := 1;
    v_msj_error := 'Categoría mayor a lo establecido en la politica';    
  ELSE
    --
    IF v_mto_lim_pre > 0 THEN
      BEGIN
        SELECT mto_ingreso
          INTO v_mto_ingreso
          FROM ba_per_gen_ofertas a
         WHERE a.cod_persona = p_cod_persona
           AND a.fec_consulta =
               (SELECT max(b.fec_consulta)
                  FROM ba_per_gen_ofertas b
                 WHERE a.cod_registro = b.cod_registro
                   AND a.cod_persona = b.cod_persona
                   AND b.est_servicios = 'P');
      EXCEPTION
        WHEN no_data_found THEN
          v_mto_ingreso := 0;
        WHEN OTHERS THEN
          v_cod_error := 2;
          v_msj_error := 'ERROR. al buscar ingreso del cliente ' || SQLERRM;
          ge_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
      END;
      --
      BEGIN
        SELECT min(a.mto_cuota)
          INTO v_cuo_minima
          FROM ge_ofe_par_cuotero a;
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_error := 3;
          v_msj_error := 'ERROR. No se encuentra datos en el cuotero.';
          ge_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
        WHEN OTHERS THEN
          v_cod_error := 4;
          v_msj_error := 'ERROR. Al momento de buscar datos en el cuotero.';
          ge_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
      END;
      --
      v_deu_teorica := round((p_deu_tot_crc / 18), 0);
      v_cuo_maxima  := round(((v_mto_ingreso * v_por_cli_nue) / 100), 0);
      --
      v_cuo_aproximada := v_cuo_maxima - v_deu_teorica;
      --
      IF v_cuo_minima > v_cuo_aproximada THEN
        v_cod_error := 5;
        v_msj_error := 'Cliente con alto nivel de endeudamiento.';
        ge_ins_log(v_cod_registro, p_cod_persona, v_cod_error, v_msj_error);
      END IF;
      --
      IF nvl(v_cod_error, '000') = '000' THEN
        BEGIN
          SELECT aa.mto_prestamo, aa.cod_moneda, aa.can_cuota
            INTO v_mto_oferta, v_cod_moneda, v_can_cuotas
            FROM ge_ofe_par_cuotero aa
           where aa.mto_cuota =
                 (SELECT max(c.mto_cuota)
                    FROM ge_ofe_par_cuotero c
                   WHERE v_cuo_aproximada >= c.mto_cuota);
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_error := 3;
            v_msj_error := 'ERROR. No se encuentra datos en el cuotero.';
            ge_ins_log(v_cod_registro,
                       p_cod_persona,
                       v_cod_error,
                       v_msj_error);
          WHEN OTHERS THEN
            v_cod_error := 4;
            v_msj_error := 'ERROR. Al momento de buscar datos en el cuotero.';
            ge_ins_log(v_cod_registro,
                       p_cod_persona,
                       v_cod_error,
                       v_msj_error);
        END;
        --
        IF nvl(v_cod_error, '000') = '000' THEN
          IF v_mto_lim_max < v_mto_oferta THEN
            v_mto_oferta := v_mto_lim_max;
          END IF;
        END IF;
      END IF;
    ELSE
      --
      v_can_cuotas := fug_obt_pardinamico('GEN_CAN_CUO_FIJ_ONB');
      v_cod_moneda := pag_gen.FU_OBT_MON_LOCAL;
      --
      BEGIN
        SELECT cl.tip_ingreso
          INTO v_tip_ingreso
          FROM ge_ing_clientes cl
         WHERE cl.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_error := 5;
          v_msj_error := 'ERROR. Al momento de buscar el tipó de ingreso.';
          ge_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
        WHEN OTHERS THEN
          v_cod_error := 6;
          v_msj_error := 'ERROR. Al momento al buscar Tipo ' || SQLERRM;
          ge_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
      END;
      IF nvl(v_cod_error, '000') = '000' THEN
        IF v_tip_ingreso = 3 AND p_fec_ing_set is not null THEN
          v_antiguedad := TRUNC((to_date(pag_cal.FU_OBT_FEC_ACTUAL(1),
                                         'DD/MM/RRRR') -
                                TO_DATE(p_fec_ing_set, 'DD/MM/RRRR')) /
                                365.25);
          IF v_antiguedad >= 1 THEN
            BEGIN
              SELECT T.MTO_APROBADO
                INTO v_mto_oferta
                FROM GE_PAR_POL_PRE_APR T
               WHERE (p_deu_tot_crc between t.mto_deu_crc_des and
                     t.mto_deu_crc_has)
                 AND t.tip_ingreso = v_tip_ingreso
                 AND t.cat_crc = p_cat_crc
                 AND p_faja <= t.faja
                 AND t.ant_infomercio = p_ant_infomercio;
            EXCEPTION
              WHEN no_data_found THEN
                v_cod_error := 7;
                v_msj_error := 'ERROR. Monto de oferta indefinido para faja mayor a J. '||' Faja: '||p_faja;--LOU 'ERROR. Al momento de buscar el monto de la oferta.';
                ge_ins_log(v_cod_registro,
                           p_cod_persona,
                           v_cod_error,
                           v_msj_error);
              WHEN OTHERS THEN
                v_cod_error := 8;
                v_msj_error := 'ERROR. Monto de oferta indefinido para faja mayor a J. '||SQLERRM;-- LOU 'ERROR. Al momento al buscar Oferta ' ||SQLERRM;
                ge_ins_log(v_cod_registro,
                           p_cod_persona,
                           v_cod_error,
                           v_msj_error);
            END;
          END IF;
        ELSIF (v_tip_ingreso = 4 OR
              (v_tip_ingreso = 3 AND p_fec_ing_set is null)) THEN
          BEGIN
            SELECT T.MTO_APROBADO
              INTO v_mto_oferta
              FROM GE_PAR_POL_PRE_APR T
             WHERE ((p_deu_tot_crc between t.mto_deu_crc_des and
                   t.mto_deu_crc_has) OR
                   (p_deu_tot_crc is null and t.mto_deu_crc_des is null and
                   t.mto_deu_crc_has is null))
               AND t.tip_ingreso = 4
               AND ((t.cat_crc = p_cat_crc) or
                   (p_cat_crc is null and t.cat_crc is null))
               AND p_faja <= t.faja
               AND t.ant_infomercio = p_ant_infomercio;
          EXCEPTION
            WHEN no_data_found THEN
              v_cod_error := 9;
              v_msj_error := 'ERROR. Contribuyente sin antigüedad mínima en la SET '||'Ant: '||v_antiguedad;--LOU'ERROR. Al momento de buscar el monto de la oferta.';
              ge_ins_log(v_cod_registro,
                         p_cod_persona,
                         v_cod_error,
                         v_msj_error);
            WHEN OTHERS THEN
              v_cod_error := 10;
              v_msj_error := 'ERROR. Contribuyente sin antigüedad mínima en la SET. '||SQLERRM;--'ERROR. Al momento al buscar Oferta ' ||
              ge_ins_log(v_cod_registro,
                         p_cod_persona,
                         v_cod_error,
                         v_msj_error);
          END;
        END IF;
        IF nvl(v_cod_error, '000') = '000' THEN
          IF v_mto_lim_max < v_mto_oferta THEN
            v_mto_oferta := v_mto_lim_max;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;
  END IF;
  UPDATE ba_per_gen_ofertas o
     SET o.cod_cat_crc        = p_cat_crc,
         o.tot_deu_crc        = p_deu_tot_crc,
         o.mto_cuo_aproximado = v_cuo_aproximada,
         o.faja               = p_faja,
         o.fec_ing_set        = p_fec_ing_set,
         o.ant_infomercio     = p_ant_infomercio,
         o.mto_oferta         = v_mto_oferta,
         o.can_cuotas         = v_can_cuotas,
         o.cod_moneda         = v_cod_moneda,
         o.rta_servicio       = p_rta_servicio,
         o.error              = p_error,
         o.est_servicios      = v_est_servicio,
         o.est_rrnn           = v_est_rrnn,
         o.fec_consulta       = pag_cal.FU_OBT_FEC_ACTUAL(1)
   WHERE o.cod_persona = p_cod_persona
     AND o.cod_registro = v_cod_registro
     AND o.est_servicios = 'P';

  IF nvl(v_cod_error, '000') = '000' THEN
    v_cod_error := 0;
    v_msj_error := 'Proceso concluido con exito.';
  END IF;
  p_cod_error := v_cod_error;
  p_msj_error := v_msj_error;
END;
/

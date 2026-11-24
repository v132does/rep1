CREATE OR REPLACE PROCEDURE IT.prg_obt_lim_prestable(p_cod_persona    ba_personas.cod_persona%TYPE,
                                                    p_cat_crc        ba_per_gen_ofertas.cod_cat_crc%TYPE,
                                                    p_deu_tot_crc    ba_per_gen_ofertas.tot_deu_crc%TYPE,
                                                    p_faja           ba_per_gen_ofertas.faja%TYPE,
                                                    p_fec_ing_set    ba_per_gen_ofertas.fec_ing_set%TYPE,
                                                    p_ant_infomercio ba_per_gen_ofertas.ant_infomercio%TYPE,
                                                    p_rta_servicio   ba_per_gen_ofertas.rta_servicio%TYPE,
                                                    p_nivel_endeudamiento OUT NUMBER,
                                                    p_lim_prestable OUT NUMBER,
                                                    p_cod_registro   ba_per_gen_ofertas.cod_registro%TYPE,
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
  v_por_cli_nuevo    NUMBER;
  v_cuo_minima     NUMBER;
  v_mto_lim_maximo    NUMBER;
  v_cod_registro   NUMBER;
  v_est_servicio   VARCHAR2(1);
  v_est_rrnn       VARCHAR(1);
  ----------    
  v_mto_oferta NUMBER;
  v_can_cuotas NUMBER;
  v_cod_moneda VARCHAR2(3);
  ----------
  v_mto_lim_prestable NUMBER;
  v_tip_ingreso ge_ing_clientes.tip_ingreso%TYPE;
  v_antiguedad  NUMBER;
  ----------
  PROCEDURE pr_ins_log(p_cod_registro IN NUMBER,
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
  v_por_cli_nuevo := fug_obt_pardinamico('BAS_PRO_CLI_NUEV');
  v_mto_lim_maximo := fug_obt_pardinamico('BAS_MTO_LIM_OFE_CLI_NUE');
  --
  BEGIN
    SELECT o.cod_registro, nvl(o.mto_lim_prestable, 0)
      INTO v_cod_registro, v_mto_lim_prestable
      FROM ba_per_gen_ofertas o
     WHERE o.cod_persona = p_cod_persona
       AND o.est_servicios = 'P' 
       AND o.cod_registro = p_cod_registro;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_error := 5;
      v_msj_error := 'ERROR. Oferta no encontrada para el cliente ' ||
                     p_cod_persona;
      pr_ins_log(v_cod_registro, p_cod_persona, v_cod_error, v_msj_error);
    WHEN too_many_rows THEN
      SELECT o.cod_registro, nvl(o.mto_lim_prestable, 0)
        INTO v_cod_registro, v_mto_lim_prestable
        FROM ba_per_gen_ofertas o
       WHERE o.cod_persona = p_cod_persona
         AND o.est_servicios = 'P'
         AND o.cod_registro =  p_cod_registro
         AND o.fec_consulta =
             (SELECT min(o.fec_consulta)
                FROM ba_per_gen_ofertas o
               WHERE o.cod_persona = p_cod_persona
                 AND o.cod_registro = p_cod_registro
                 AND o.est_servicios = 'P');
    WHEN OTHERS THEN
      v_cod_error := 6;
      v_msj_error := 'ERROR. Al buscar la oferta ' || SQLERRM;
      pr_ins_log(v_cod_registro, p_cod_persona, v_cod_error, v_msj_error);
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
    IF v_mto_lim_prestable > 0 THEN
      BEGIN
        SELECT mto_ingreso
          INTO v_mto_ingreso
          FROM ba_per_gen_ofertas a
         WHERE a.cod_persona = p_cod_persona
           AND a.cod_registro = p_cod_registro;
      EXCEPTION
        WHEN no_data_found THEN
          v_mto_ingreso := 0;
        WHEN OTHERS THEN
          v_cod_error := 2;
          v_msj_error := 'ERROR. al buscar ingreso del cliente ' || SQLERRM;
          pr_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
      END;
      --
      --
      v_deu_teorica := round((p_deu_tot_crc / 18), 0);
      v_cuo_maxima  := round(((v_mto_ingreso * v_por_cli_nuevo) / 100), 0);
      --
      v_cuo_aproximada := v_cuo_maxima - v_deu_teorica;
      p_nivel_endeudamiento := nvl(v_cuo_aproximada,0);
      p_lim_prestable := nvl(v_mto_lim_prestable,0);
      --
      IF v_cuo_minima > v_cuo_aproximada THEN
        v_cod_error := 5;
        v_msj_error := 'Cliente con alto nivel de endeudamiento.';
        pr_ins_log(v_cod_registro, p_cod_persona, v_cod_error, v_msj_error);
      END IF;
      --
    ELSE
      --
      v_can_cuotas := fug_obt_pardinamico('GEN_CAN_CUO_FIJ_ONB');
      v_cod_moneda := pag_gen.FU_OBT_MON_LOCAL;
      --
      BEGIN
        SELECT distinct cl.tip_ingreso
          INTO v_tip_ingreso
          FROM ge_ing_clientes cl
         WHERE cl.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          v_cod_error := 5;
          v_msj_error := 'ERROR. Al momento de buscar el tipó de ingreso.';
          pr_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
        WHEN OTHERS THEN
          v_cod_error := 6;
          v_msj_error := 'ERROR. Al momento al buscar Tipo ' || SQLERRM;
          pr_ins_log(v_cod_registro,
                     p_cod_persona,
                     v_cod_error,
                     v_msj_error);
      END;

    END IF;
  END IF;
  END IF;
  IF nvl(v_cod_error, '000') = '000' THEN
    v_cod_error := 0;
    v_msj_error := 'Proceso concluido con exito.';
  END IF;
  p_cod_error := v_cod_error;
  p_msj_error := v_msj_error;
END;
/

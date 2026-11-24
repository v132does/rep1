CREATE OR REPLACE PACKAGE BODY it.pag_evr IS

  FUNCTION fu_cal_venc_perfil(p_cod_riesgo     IN VARCHAR2,
                              p_fec_evaluacion IN DATE DEFAULT SYSDATE)
    RETURN DATE IS
    v_meses_vigencia NUMBER;
    v_fec_base       DATE := nvl(p_fec_evaluacion, trunc(SYSDATE));
  BEGIN
    -- Consulta la matriz de parametrización dinámica
    v_meses_vigencia := fue_obt_val_max_referencia('PLA_VIGENCIA_RIESGO',upper(p_cod_riesgo));
    RETURN add_months(v_fec_base, v_meses_vigencia);
  EXCEPTION
    WHEN OTHERS THEN
      v_meses_vigencia := fue_obt_val_max_referencia('PLA_VIGENCIA_RIESGO','BAJO'); -- Por defecto 5 años (Riesgo Bajo)
      RETURN add_months(v_fec_base, v_meses_vigencia);
  END;

  FUNCTION fu_obt_riesgo_cli(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2 IS
    v_riesgo cr_per_riesgo_pla_his.nivel_riesgo%type;
  BEGIN
    BEGIN
      SELECT nivel_riesgo
        INTO v_riesgo
        FROM cr_per_riesgo_pla_his t
       WHERE t.cod_persona = p_cod_persona
         AND t.fec_insercion =
             (SELECT MAX(b.fec_insercion)
                FROM cr_per_riesgo_pla_his b
               WHERE b.cod_persona = t.cod_persona)
         AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        v_riesgo := 'BAJO';--Predeterminado
      WHEN others THEN
        v_riesgo := NULL;
    END;
    RETURN v_riesgo;
  END;
  
  FUNCTION fu_ver_riesgo_cli(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2 IS
    v_riesgo VARCHAR2(50);
  BEGIN
    BEGIN
      SELECT nivel_riesgo
        INTO v_riesgo
        FROM cr_per_riesgo_pla_his t
       WHERE t.cod_persona = p_cod_persona
         AND t.fec_insercion =
             (SELECT MAX(b.fec_insercion)
                FROM cr_per_riesgo_pla_his b
               WHERE b.cod_persona = t.cod_persona)
         AND rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        v_riesgo := 'BAJO';--Predeterminado
      WHEN others THEN
        v_riesgo := NULL;
    END;
    IF v_riesgo = 'ALTO' THEN
      RETURN('RIESGO ALTO');
    ELSIF v_riesgo = 'MEDIO' THEN
      RETURN('RIESGO MEDIO');
    ELSE
      RETURN 'RIESGO BAJO';
    END IF;
  END;

  FUNCTION fu_ver_venc_perfil(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN DATE IS
    v_vencimiento DATE;
  BEGIN
    BEGIN
      SELECT c.fec_vencimiento
        INTO v_vencimiento
        FROM cr_per_tip_operaciones c
       WHERE c.cod_persona = p_cod_persona
         AND rownum = 1
         AND c.fec_vencimiento =
             (SELECT MAX(f.fec_vencimiento)
                FROM cr_per_tip_operaciones f
               WHERE f.cod_persona = c.cod_persona);
    EXCEPTION
      WHEN no_data_found THEN
        v_vencimiento := NULL;
      WHEN others THEN
        v_vencimiento := NULL;
    END;
    RETURN(v_vencimiento);
  END;

  PROCEDURE pr_pro_act_riesgo(p_cod_persona    IN VARCHAR2 DEFAULT NULL,
                              p_cod_riesgo     IN VARCHAR2,
                              p_fec_evaluacion IN DATE DEFAULT SYSDATE,
                              p_codigo_error   OUT NUMBER,
                              p_mensaje_error  OUT VARCHAR2) IS
  BEGIN
    p_codigo_error  := 0;
    p_mensaje_error := 'OK';
    UPDATE cr_per_tip_operaciones c
       SET c.fec_vencimiento = fu_cal_venc_perfil(p_cod_riesgo, nvl(p_fec_evaluacion, trunc(SYSDATE))),
           c.fec_inicio = p_fec_evaluacion 
     WHERE c.cod_persona = p_cod_persona 
       AND c.fec_vencimiento > trunc(SYSDATE) 
       AND c.fec_inicio = (SELECT MAX(f.fec_inicio)
                             FROM cr_per_tip_operaciones f
                            WHERE f.cod_persona = c.cod_persona) 
       AND rownum = 1;
       
    COMMIT;
    
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_codigo_error  := -1;
      p_mensaje_error := 'Error en PR_PRO_ACT_RIESGO: ' || SQLERRM;
  END;

END;
/

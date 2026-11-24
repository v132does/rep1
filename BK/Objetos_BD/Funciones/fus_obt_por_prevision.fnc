CREATE OR REPLACE FUNCTION IT.fus_obt_por_prevision(p_cat_riesgo IN ge_cla_operaciones.cat_automatica%TYPE)
    RETURN NUMBER IS
   v_riesgo1a   pr_parametros.por_riesgo_1a%TYPE;
   v_riesgo1b   pr_parametros.por_riesgo_1b%TYPE;
   v_riesgo2    pr_parametros.por_riesgo_2%TYPE;
   v_riesgo3    pr_parametros.por_riesgo_3%TYPE;
   v_riesgo4    pr_parametros.por_riesgo_4%TYPE;
   v_riesgo5    pr_parametros.por_riesgo_5%TYPE;
   v_riesgo6    pr_parametros.por_riesgo_6%TYPE;
   v_porcentaje pr_previsiones.porcentaje%TYPE;
BEGIN

   BEGIN
      SELECT por_riesgo_1a,
             por_riesgo_1b,
             por_riesgo_2,
             por_riesgo_3,
             por_riesgo_4,
             por_riesgo_5,
             por_riesgo_6
        INTO v_riesgo1a, v_riesgo1b, v_riesgo2, v_riesgo3, v_riesgo4, v_riesgo5, v_riesgo6
        FROM pr_parametros
       WHERE rownum = 1;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Parametros de riesgos no definidos');
   END;
   IF p_cat_riesgo = 1.1 then
      v_porcentaje := v_riesgo1a;
   ELSIF p_cat_riesgo = 1.2 then
      v_porcentaje := v_riesgo1b;
   ELSIF p_cat_riesgo = 2 THEN
      v_porcentaje := v_riesgo2;
   ELSIF p_cat_riesgo = 3 THEN
      v_porcentaje := v_riesgo3;
   ELSIF p_cat_riesgo = 4 THEN
      v_porcentaje := v_riesgo4;
   ELSIF p_cat_riesgo = 5 THEN
      v_porcentaje := v_riesgo5;
   ELSIF p_cat_riesgo = 6 THEN
      v_porcentaje := v_riesgo6;
   ELSE
      v_porcentaje := 0;
   END IF;
   RETURN v_porcentaje;
EXCEPTION
  WHEN OTHERS THEN
     RETURN 0;
END;
/


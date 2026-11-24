CREATE OR REPLACE FUNCTION it.fuj_val_mto_max_efe_cam(p_cod_persona   IN NUMBER,
                                                      p_mto_operacion IN NUMBER)
  RETURN VARCHAR2 IS
  v_tip_persona      ba_personas.tipo%TYPE;
  v_mto_max_fisica   NUMBER := to_number(nvl(fug_obt_pardinamico('OPE_SUP_EFE_CAJ_PF'),'10000'));
  v_mto_max_juridica NUMBER := to_number(nvl(fug_obt_pardinamico('OPE_SUP_EFE_CAJ_PJ'),'10000'));
  v_deposita         VARCHAR2(1) := 'N';
BEGIN
  --Validamos si es persona Fisica o Juridica
  IF pag_gen.fu_es_per_fisica(p_cod_persona) = 'S' THEN
    v_tip_persona := 'F';
  ELSE
    v_tip_persona := 'J';
  END IF;
  --Validar parámetro de exclusión
  IF NVL(FUE_PER_DAT_ADICIONAL(p_cod_persona,'EXC_VAL_EFE_CAM_CAJA'),'N') = 'S' THEN
    v_deposita := 'S'; --Si Deposita
  ELSE
    --Validamos monto por tipo de persona
    IF v_tip_persona = 'F' THEN
      --operacion > limite
      IF p_mto_operacion > v_mto_max_fisica THEN
        v_deposita := 'N'; --No Deposita (supera el límite)
      ELSE
        v_deposita := 'S'; --Si Deposita
      END IF;
    ELSIF v_tip_persona = 'J' THEN
      --operacion > limite
      IF p_mto_operacion > v_mto_max_juridica THEN
        v_deposita := 'N'; --No Deposita (supera el límite)
      ELSE
        v_deposita := 'S'; --Si Deposita
      END IF;
    END IF;
  END IF;
  RETURN(v_deposita);
END fuj_val_mto_max_efe_cam;
/

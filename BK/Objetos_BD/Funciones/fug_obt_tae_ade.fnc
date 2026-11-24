CREATE OR REPLACE FUNCTION IT.fug_obt_tae_ade(p_tasa          IN NUMBER,
                                p_periodo_capit IN NUMBER) RETURN NUMBER IS
  v_tae  NUMBER(21, 10);
  v_tae1 NUMBER(21, 10);
  v_tae2 NUMBER(21, 10);
BEGIN
  v_tae1 := 1 - (((p_tasa) * p_periodo_capit) / 36500);
  v_tae2 := 365 / p_periodo_capit;
  v_tae  := 100 * ((1 / (power((v_tae1), (v_tae2)))) - 1);
  RETURN round(v_tae, 4);
END;
/


CREATE OR REPLACE FUNCTION IT.FUG_OBT_ENT_SEGURO
 (P_COD_MODULO IN GE_SOL_CARGOS.COD_MODULO%TYPE,
  P_COD_MODALIDAD IN GE_SOL_CARGOS.COD_MODALIDAD%TYPE,
  P_TIP_TASA IN VARCHAR2
 )
 RETURN NUMBER
 IS
 v_cod_trans         ge_sol_cargos.cod_transaccion%type;
 v_cod_transaccion   VARCHAR2(100);
BEGIN
  IF P_TIP_TASA = 'V' THEN -- Seguro de Vida
    v_cod_transaccion := 1521;
  ELSIF P_TIP_TASA = 'I' THEN -- Seguro contra Incendio
    v_cod_transaccion := 1520;
  END IF;

  BEGIN
    SELECT distinct cod_ent_seguro
    into v_cod_trans
    from ge_sol_cargos 
   where cod_modulo = P_COD_MODULO
     and cod_modalidad = P_COD_MODALIDAD
     and cod_canal is null
     and cod_campana is null
     and (cod_tip_canal is null)
     and instr(v_cod_transaccion,cod_transaccion) > 0;
     RETURN v_cod_trans;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_trans := NULL;
      RETURN v_cod_trans;
  END;
  
EXCEPTION
    WHEN no_data_found THEN
      v_cod_trans := NULL;
      RETURN v_cod_trans;
END;
/


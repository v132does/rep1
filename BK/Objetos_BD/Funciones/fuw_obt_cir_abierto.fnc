CREATE OR REPLACE FUNCTION IT.FUW_OBT_CIR_ABIERTO(P_COD_PERSONA ba_personas.cod_persona%TYPE)
  RETURN VARCHAR2 IS
  v_existe VARCHAR2(1) := 'N';
BEGIN
  BEGIN
    SELECT 'S'
      INTO v_existe
      FROM wf_circuitos c
     WHERE c.cod_persona = p_cod_persona
       AND c.cod_tip_circuito in (37, 38, 39, 41, 42, 43)
       AND (c.estado = 'E' OR c.estado = 'F' AND EXISTS (SELECT 1
              FROM wf_cir_tareas t
             WHERE t.cod_circuito = c.cod_circuito
               AND t.estado = 'R'));
  EXCEPTION
    WHEN no_data_found THEN
      v_existe := 'N';
    WHEN too_many_rows THEN
      v_existe := 'S';
    WHEN OTHERS THEN
      v_existe := 'N';
  END;
  return(v_existe);
END;
/


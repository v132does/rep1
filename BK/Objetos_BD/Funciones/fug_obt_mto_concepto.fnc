CREATE OR REPLACE FUNCTION IT.fug_obt_mto_concepto
(
   p_cod_persona  IN ba_personas.cod_persona%TYPE,
   p_cod_concepto IN cr_con_ing_egr.cod_concepto%TYPE
) RETURN NUMBER IS
   v_importe cr_per_ing_egresos.importe%TYPE := 0;
BEGIN
   SELECT a.importe
     INTO v_importe
     FROM cr_per_ing_egresos a
    WHERE a.cod_persona = p_cod_persona
      AND a.cod_concepto = p_cod_concepto;
   RETURN v_importe;
EXCEPTION
   WHEN no_data_found THEN
      RETURN 0;
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en FUG_OBT_MTO_CONCEPTO. ' || SQLERRM);
END;
/


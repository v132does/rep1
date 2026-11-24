CREATE OR REPLACE FUNCTION IT.fug_obt_cod_actividad(p_cod_rub_primario VARCHAR2) RETURN NUMBER IS
   v_cod_actividad ge_rub_economicos.referencia%TYPE;
BEGIN
   SELECT referencia
     INTO v_cod_actividad
     FROM ge_rub_economicos
    WHERE cod_rub_economico = p_cod_rub_primario;
   RETURN v_cod_actividad;
EXCEPTION
   WHEN no_data_found THEN
      RETURN('Código de Actividad no registrada en GE_RUB_ECONOMICOS.');
END;
/


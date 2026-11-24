CREATE OR REPLACE FUNCTION IT.fug_obt_tip_emp_onb(p_tip_empresa_set IN ba_cod_referencias.VAL_MINIMO%TYPE) RETURN VARCHAR2 IS

--Función que devuelve (parsea) los valores del tipo de empresa que recibimos de la SET con
--los que tenemos registrados en el core
--Por mmelgarejo
--Jira NVB-2593
--08/09/2023

  v_referencia      ba_cod_referencias.VAL_MAXIMO%TYPE := 'N';
BEGIN
  SELECT val_maximo
     INTO v_referencia
     FROM ba_cod_referencias
    WHERE dominio = 'ONB_TIP_EMPRESA'
      AND val_minimo = p_tip_empresa_set;

   RETURN v_referencia;
EXCEPTION
   WHEN no_data_found THEN
      RETURN('12');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR al buscar BA_COD_REFERENCIAS :  ' || SQLERRM);

END;
/

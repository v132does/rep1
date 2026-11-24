CREATE OR REPLACE FUNCTION IT.fug_val_dat_parametros(p_parametro in ge_par_dinamicos.parametro%type,
                                 p_cod_modulo in ba_modulos.cod_modulo%type,
                                 p_cod_modalidad in ge_modalidades.cod_modalidad%type default NULL,
                                 p_cod_sub_modalidad ge_par_dinamicos.cod_sub_modalidad%type default NULL,
                                 p_valor in ge_par_dinamicos.val_parametro%type default NULL,
                                 p_modo in varchar2 default 'I' -- p_modo I -> incremental / N -> normal
                                 ) RETURN number IS
v_respuesta      number(1) :=  null;
v_val_parametro  ge_par_dinamicos.val_parametro%type;
BEGIN
  -- BSEVOCORE-111 - Implementacion de Plastico Contactless
  -- Función que devuelve 1 si existe parametro configurado para Modulo, Modalidad y Valor de manera incremental si p_modo = I.
  -- Implementa % como comodin para permitir que cualquier valor de modulo / modalidad de ese parametro responda 1.
  -- Obs.: los valores del parametro dinamico deben estar separados por comas, sin espacios
  v_respuesta := 0;  
  select val_parametro
  into v_val_parametro
  from ge_par_dinamicos
  where cod_modulo = nvl(p_cod_modulo, -1)
    and cod_modalidad = nvl(p_cod_modalidad, -1)
    and nvl(cod_sub_modalidad,-1) = nvl(p_cod_sub_modalidad, nvl(cod_sub_modalidad,-1)) -- opcional
    and parametro = p_parametro;
  -- Se valida valor
  IF v_val_parametro is not null THEN
      IF INSTR(',' || v_val_parametro || ',', ',' || p_valor || ',') > 0
      or INSTR(v_val_parametro, '%') > 0 THEN
         v_respuesta := 1;
      ELSE
        IF p_valor is null and p_modo = 'I' THEN
            v_respuesta := 1;
        ELSE
            v_respuesta := 0;
        END IF;
      END IF;
  END IF;
  RETURN v_respuesta;
 EXCEPTION
   WHEN TOO_MANY_ROWS THEN
      IF p_modo = 'I' THEN
          RETURN 1;
      ELSE
          RETURN 0;
      END IF;
   WHEN NO_DATA_FOUND THEN
      RETURN 0;
  WHEN OTHERS THEN
      RETURN 0;
END;
/


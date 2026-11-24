CREATE OR REPLACE FUNCTION IT.fug_obt_val_numerico(p_valor IN VARCHAR2)
  RETURN NUMBER AS
  /** Función que recibe como parámetro de entrada un varchar y lo convierte en numérico*/
  v_val_numerico     NUMBER; -- variable numérica de retorno
  v_val_reemplazado  VARCHAR2(25); --variable del valor reemplazado
  v_nom_base         VARCHAR2(20) := upper(sys_context('USERENV', 'DB_NAME')); --variable que obtiene el DB_NAME
BEGIN
  SELECT TO_NUMBER(p_valor) 
    INTO v_val_numerico
    FROM DUAL;

  RETURN v_val_numerico;
EXCEPTION
  WHEN OTHERS THEN
    IF v_nom_base not in ('IT', 'BBVADESA') then -- Se valida la base para saber si reemplazar el punto o la coma.
      v_val_reemplazado := REPLACE(p_valor, ',', '.');--esto dependiendo del formato en los parámetros NLS.
    ELSE
      v_val_reemplazado := REPLACE(p_valor, '.', ',');
    END IF;
    v_val_numerico := TO_NUMBER(v_val_reemplazado);
    RETURN v_val_numerico;
END;
/


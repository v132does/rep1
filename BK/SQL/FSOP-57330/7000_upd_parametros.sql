SET SERVEROUTPUT ON;

DECLARE
  v_val_param   GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
BEGIN
  -- Inicialización de aplicación
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  -- 1) Actualizar parámetro de control
  UPDATE GE_PAR_DINAMICOS
     SET VAL_PARAMETRO = 'fielprodprdcdb01'
   WHERE PARAMETRO = 'VAL_BDNAME_CONTROL_SIM';

  -- Guardar valor actualizado para mostrar
  SELECT VAL_PARAMETRO
    INTO v_val_param
    FROM GE_PAR_DINAMICOS
   WHERE PARAMETRO = 'VAL_BDNAME_CONTROL_SIM';

  DBMS_OUTPUT.PUT_LINE('VAL_BDNAME_CONTROL_SIM actualizado a: ' || v_val_param);

  -- 2) Actualizar BASE_OBJETIVO en todas las simulaciones activas
  UPDATE GE_CLA_FEC_SIMULACION
     SET BASE_OBJETIVO = 'fincdb02'
   WHERE FLAG_ACTIVO = 'S';

  DBMS_OUTPUT.PUT_LINE('BASE_OBJETIVO actualizado a fincdb02 en GE_CLA_FEC_SIMULACION');

  COMMIT;

  -- 3) Mostrar estado final de las simulaciones activas
  DBMS_OUTPUT.PUT_LINE('--- Estado final GE_CLA_FEC_SIMULACION ---');
  FOR r IN (SELECT ID_PARAM, FECHA_PROGRAMADA, BASE_OBJETIVO, FLAG_ACTIVO
              FROM GE_CLA_FEC_SIMULACION
             WHERE FLAG_ACTIVO = 'S'
             ORDER BY ID_PARAM) LOOP
    DBMS_OUTPUT.PUT_LINE('ID_PARAM=' || r.ID_PARAM ||
                         ' | FECHA_PROGRAMADA=' || TO_CHAR(r.FECHA_PROGRAMADA,'DD/MM/YYYY HH24:MI:SS') ||
                         ' | BASE_OBJETIVO=' || r.BASE_OBJETIVO ||
                         ' | FLAG_ACTIVO=' || r.FLAG_ACTIVO);
  END LOOP;
END;
/

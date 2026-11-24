CREATE OR REPLACE FUNCTION IT.fug_obt_fec_habil_ant(p_fecha IN DATE)
  RETURN DATE IS
  v_fecha       DATE := p_fecha - 1; -- Empezar con el día anterior
  v_dia_semana  VARCHAR2(15);
  festivo_count INTEGER;
BEGIN
  -- Loop para encontrar el día hábil anterior
  LOOP
    -- Obtener el nombre del día de la semana en formato textual
    v_dia_semana := TO_CHAR(v_fecha, 'Day', 'NLS_DATE_LANGUAGE=SPANISH');

    -- Verificar si el día es sábado o domingo
    IF NOT (v_dia_semana LIKE '%Sábado%' OR v_dia_semana LIKE '%Domingo%' OR
        v_dia_semana LIKE '%Saturday%' OR v_dia_semana LIKE '%Sunday%') THEN
      -- Verificar si el día es festivo
      SELECT COUNT(*)
        INTO festivo_count
        FROM it.ba_feriados
       WHERE fecha = v_fecha;

      IF festivo_count = 0 THEN
        -- Si no es festivo, salir del bucle
        EXIT;
      END IF;
    END IF;

    -- Si es sábado, domingo o festivo, restar un día y continuar el bucle
    v_fecha := v_fecha - 1;
  END LOOP;

  RETURN v_fecha;
END;
/
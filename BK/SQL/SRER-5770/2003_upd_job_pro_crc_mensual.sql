-- SRER-5770 | JOB_PRO_CRC_MENSUAL
-- Cambios: guards RAISE->RETURN silencioso + EXCEPTION + LOGGING_LEVEL=FULL
-- Ref: NOR-655
BEGIN
  DBMS_SCHEDULER.DISABLE(
    name  => 'IT.JOB_PRO_CRC_MENSUAL',
    force => FALSE
  );
END;
/

BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_PRO_CRC_MENSUAL',
    attribute => 'job_action',
    value     => q'[
      DECLARE
          v_fec_actual             DATE;
          v_ult_dia_mes_habil      DATE;
          v_base_objetivo          CONSTANT VARCHAR2(20)  := UPPER(TRIM(fug_obt_pardinamico('BA_OBJ_CRC_MENSUAL')));
          v_base_actual            CONSTANT VARCHAR2(20)  := UPPER(TRIM(SYS_CONTEXT('USERENV','DB_UNIQUE_NAME')));
          v_base_prod              CONSTANT VARCHAR2(20)  := UPPER(TRIM(fug_obt_pardinamico('BA_PRO_CRC_CONTROL')));
      BEGIN
          -- Obtener fecha actual desde funcion
          v_fec_actual := pag_cal.fu_obt_fec_actual(1);

          -- Obtener ultima fecha del mes habil
          SELECT ult_dia_mes_habil
          INTO v_ult_dia_mes_habil
          FROM ge_calendarios
          WHERE cod_modulo = 1;

          -- Guard: base objetivo (condicion esperada -> RETURN silencioso)
          IF v_base_actual != v_base_objetivo THEN
            DBMS_OUTPUT.PUT_LINE('SKIP | Base no es finmes: ' || v_base_actual);
            RETURN;
          END IF;

          -- Guard: base productiva (condicion esperada -> RETURN silencioso)
          IF v_base_actual = v_base_prod THEN
            DBMS_OUTPUT.PUT_LINE('SKIP | Base productiva: ' || v_base_actual);
            RETURN;
          END IF;

          -- Guard: no es ultimo dia habil del mes (condicion esperada -> RETURN silencioso)
          IF v_fec_actual != v_ult_dia_mes_habil THEN
            DBMS_OUTPUT.PUT_LINE('SKIP | No es ultimo dia habil. Fecha: ' || TO_CHAR(v_fec_actual, 'DD/MM/YY'));
            RETURN;
          END IF;

          -- Ejecucion real del proceso mensual
          IT.PRG_EJE_CRC_MENSUAL;

      EXCEPTION
          WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
              -20099,
              'CRC_MENSUAL FAILED | ' || SQLERRM || ' | ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
      END;
    ]'
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_PRO_CRC_MENSUAL',
    attribute => 'logging_level',
    value     => DBMS_SCHEDULER.LOGGING_FULL
  );

  DBMS_SCHEDULER.ENABLE(
    name => 'IT.JOB_PRO_CRC_MENSUAL'
  );
END;
/

BEGIN
  DBMS_SCHEDULER.DISABLE( 
  name => 'IT.JOB_PRO_CRC_MENSUAL');
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
          v_fecha                  DATE;
          v_base_objetivo          CONSTANT VARCHAR2(20)  := UPPER(TRIM(fug_obt_pardinamico('BA_OBJ_CRC_MENSUAL')));
          v_base_actual            CONSTANT VARCHAR2(20)  := UPPER(TRIM(SYS_CONTEXT('USERENV','DB_UNIQUE_NAME')));  
          v_base_prod              CONSTANT VARCHAR2(20)  := UPPER(TRIM(fug_obt_pardinamico('BA_PRO_CRC_CONTROL')));
      BEGIN
          -- Obtener fecha actual desde función
          v_fec_actual := pag_cal.fu_obt_fec_actual(1);

          -- Obtener última fecha del mes hábil
          SELECT ult_dia_mes_habil 
          INTO v_ult_dia_mes_habil
          FROM ge_calendarios 
          WHERE cod_modulo = 1;
          
          --verificar si es finmes 
          IF v_base_actual != v_base_objetivo THEN
            RAISE_APPLICATION_ERROR(-20001, 'Inserción prohibida en base que no sea finmes  |  Base actual: ' || v_base_actual);
          ELSIF v_base_actual = v_base_prod THEN  --Controlar que no se permita insertar en base produccion
           RAISE_APPLICATION_ERROR(-20001, 'Inserción prohibida en base productiva  |  Base actual: ' ||v_base_actual);
          ELSE
            IF v_fec_actual = v_ult_dia_mes_habil THEN
               IT.PRG_EJE_CRC_MENSUAL;   -- Ejecutar proceso   
            ELSE
               RAISE_APPLICATION_ERROR(-20002, 'La fecha actual no es la misma que la del último día hábil del mes: ' || TO_CHAR(v_fec_actual, 'YYYY-MM-DD'));
            END IF;
          END IF;   

      END;
    ]'
  );
END;
/


BEGIN
  DBMS_SCHEDULER.ENABLE(
    name => 'IT.JOB_PRO_CRC_MENSUAL');
END;
/

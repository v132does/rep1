CREATE OR REPLACE TRIGGER IT.tb_cr_act_esperadas
   BEFORE DELETE OR UPDATE ON cr_act_esperadas
   FOR EACH ROW
DECLARE
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(12);
BEGIN
  
   --Validar que no se grabe si la fecha del registro no corresponde a la fecha actual.
   IF updating THEN
      if substr(UPPER(user),1,4) <> 'HBAN' then
       IF :old.fecha <> v_fec_actual THEN
         raise_application_error(-20000, 'No se puede modificar registros con Fecha de Ingreso distinta a la Fecha Actual ' ||
                                          to_char(v_fec_actual, 'dd/mm/yyyy'));
       END IF;
      end if;
   ELSIF deleting THEN
      IF :old.fecha <> v_fec_actual THEN
         raise_application_error(-20001, 'No se puede eliminar registros con Fecha de Ingreso distinta a la Fecha Actual ' ||
                                          to_char(v_fec_actual, 'dd/mm/yyyy'));
      END IF;
   END IF;
END;
/


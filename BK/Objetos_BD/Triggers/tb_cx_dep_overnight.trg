CREATE OR REPLACE TRIGGER IT.TB_CX_DEP_OVERNIGHT
 BEFORE DELETE OR INSERT OR UPDATE
     ON CX_DEP_OVERNIGHT
    FOR EACH ROW
declare
   --Fecha de Proceso - asume del módulo de Comex
   r_gcale            ge_calendarios%rowtype :=pag_cal.FU_OBT_REG_CAL(8);--Obtenemos la Fecha Actual de Comex
   v_fec_proceso      CONSTANT DATE := r_gcale.fec_anterior;-- Fecha del dia anterior del módulo de Comex
   v_fecha            CONSTANT DATE := r_gcale.fec_actual;-- Fecha del dia actual del módulo de Comex
begin
    if updating then
       if (nvl(:new.monto,0) <= 0 or nvl(:new.val_tasa,0) <= 0 or nvl(:new.mto_interes,0) <= 0) then
          raise_application_error(-20000,'Error: El monto o el valor de la tasa no puede ser cero!');
       end if;
       if :new.fecha <> v_fec_proceso then
          raise_application_error(-20000,'Error: Solo se permite modificar en la fecha '||
                                  to_char(v_fec_proceso,'dd/mm/yyyy')||'!');
       end if;
    end if;
END;
/


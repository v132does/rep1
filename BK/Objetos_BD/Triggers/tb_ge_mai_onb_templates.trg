CREATE OR REPLACE TRIGGER IT.TB_GE_MAI_ONB_TEMPLATES
 BEFORE INSERT OR UPDATE
 ON it.GE_MAI_ONB_TEMPLATES
 FOR EACH ROW


BEGIN
  if it.fug_bus_onb_template(:new.tip_producto,:new.ini_vigencia,:new.fin_vigencia,:new.rowid) = 'S' then
     raise_application_error(-20000,'Ya existe un template vigente para producto '||:new.tip_producto);
 end if;
END;
/


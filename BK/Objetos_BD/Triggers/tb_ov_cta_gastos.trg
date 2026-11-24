CREATE OR REPLACE TRIGGER IT."TB_OV_CTA_GASTOS"
 BEFORE DELETE OR INSERT OR UPDATE
     ON OV_CTA_GASTOS
    FOR EACH ROW
begin
  If inserting then
    If :new.monto > 0 then
      :new.saldo := :new.monto;
    End if;
  End if;
end;
/


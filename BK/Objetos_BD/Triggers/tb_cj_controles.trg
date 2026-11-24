CREATE OR REPLACE TRIGGER IT.TB_CJ_CONTROLES
  BEFORE DELETE OR INSERT OR UPDATE
  ON "IT"."CJ_CONTROLES"
  FOR EACH ROW
begin
  If updating then
    -- Para cajas del tipo Autoservicios verifica que no tenga saldo al cierre.
    If fuj_obt_tip_caja(:new.nro_caja) = 'S' and :new.estado = 2 then
      If :new.sal_actual > 0 then
        raise_application_error(-20000, 'Caja de Autoservicios no puede quedar con saldo al Cierre.');
      End if;
    End if;
    IF :new.sal_actual < 0 THEN
      raise_application_error(-20001, 'Caja no tiene saldo para esta Operacion.');
    END IF;
  End if;
end;
/


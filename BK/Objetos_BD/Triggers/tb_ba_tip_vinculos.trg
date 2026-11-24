CREATE OR REPLACE TRIGGER IT.TB_BA_TIP_VINCULOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON BA_TIP_VINCULOS
 FOR EACH ROW
begin
  If updating then
    If :new.cod_tip_vinculo <> :old.cod_tip_vinculo then
       If :new.cod_tip_vinculo  = 'E' then
         raise_application_error(-20000,
         'El tipo de vinculo no pude ser modificado');
       End if;
    End if;
  End if;
  If deleting then
    If :old.cod_tip_vinculo  = 'E' then
       raise_application_error(-20000,
       'El tipo de vinculo no pude ser borrado');
    End if;
  End if;
end;
/


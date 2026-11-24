CREATE OR REPLACE TRIGGER IT.TB_BA_PER_JURIDICAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON BA_PER_JURIDICAS
 FOR EACH ROW

begin
  --DYDMR-2480 ITGF - Nombre de Clientes con caracteres especiales - SC 21234
  if inserting or updating then
    if :new.raz_social <> :old.raz_social then
       :new.raz_social := replace(replace(:new.raz_social, chr(10), ''), chr(13), '');        
    end if;
  end if;
end;
/


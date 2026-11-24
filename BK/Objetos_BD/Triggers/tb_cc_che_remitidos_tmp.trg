CREATE OR REPLACE TRIGGER IT.TB_CC_CHE_REMITIDOS_TMP
 BEFORE INSERT OR UPDATE
 ON CC_CHE_REMITIDOS_TMP
 FOR EACH ROW
DECLARE

BEGIN
  --Si viene Bco. 11 (ABN) cambiar a 28 (Regional)
  if inserting then
    if :new.cod_banco = 11 then
      :new.cod_banco := 28;
    end if;
  end if;
END;
/


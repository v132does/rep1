CREATE OR REPLACE TRIGGER IT.TB_AH_TAR_DEBITOS
 BEFORE INSERT
 ON IT.AH_TAR_DEBITOS
 FOR EACH ROW
BEGIN
  if inserting then
     /*Solo nuevas TDs*/    
       IF :new.id is null then
         :new.id := it.fut_obt_cod_uuid;
       END IF;
  end if;
END;
/

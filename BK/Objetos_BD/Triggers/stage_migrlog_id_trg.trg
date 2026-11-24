CREATE OR REPLACE TRIGGER IT."STAGE_MIGRLOG_ID_TRG" BEFORE INSERT OR UPDATE ON STAGE_MIGRLOG
FOR EACH ROW
BEGIN
  if inserting and :new.id is null then
        :new.id := MD_META.get_next_id;
    end if;
END;
/


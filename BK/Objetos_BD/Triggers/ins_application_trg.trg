CREATE OR REPLACE TRIGGER IT."INS_APPLICATION_TRG" BEFORE INSERT OR UPDATE ON MD_APPLICATIONS
FOR EACH ROW
BEGIN
  if inserting and :new.id is null then
        :new.id := MD_META.get_next_id;
    end if;
END;
/


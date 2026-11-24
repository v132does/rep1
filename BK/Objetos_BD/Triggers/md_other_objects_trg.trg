CREATE OR REPLACE TRIGGER IT."MD_OTHER_OBJECTS_TRG" BEFORE INSERT OR UPDATE ON MD_OTHER_OBJECTS
FOR EACH ROW
BEGIN
  if inserting and :new.id is null then
        :new.id := MD_META.get_next_id;
    end if;
END;
/


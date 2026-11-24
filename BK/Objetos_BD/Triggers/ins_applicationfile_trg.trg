CREATE OR REPLACE TRIGGER IT."INS_APPLICATIONFILE_TRG" BEFORE INSERT OR UPDATE ON MD_APPLICATIONFILES
FOR EACH ROW
BEGIN
  if inserting and :new.id is null then
        :new.id := MD_META.get_next_id;
    end if;
END;
/


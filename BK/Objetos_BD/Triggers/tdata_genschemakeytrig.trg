CREATE OR REPLACE TRIGGER IT."TDATA_GENSCHEMAKEYTRIG"
                                BEFORE INSERT ON STAGE_TERADATA_DATABASES
                                FOR EACH ROW 
                                BEGIN
                                  IF :new.MDID IS NULL OR :new.MDID=0 THEN
                                     :new.MDID := MD_META.get_next_id;
                                  END IF;
                                END TDATA_GENSCHEMAKEYTRIG;
/


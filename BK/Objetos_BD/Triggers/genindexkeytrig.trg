CREATE OR REPLACE TRIGGER IT.GenIndexKeyTrig
					BEFORE INSERT ON stage_syb12_sysindexes
					FOR EACH ROW 
					BEGIN
					  IF :new.indid_gen is null THEN
					     :new.indid_gen := MD_META.get_next_id;
					  END IF;
                    END GenIndexKeyTrig;
/


CREATE OR REPLACE TRIGGER IT."GENSCHEMAKEYTRIG"
					BEFORE INSERT ON stage_syb12_sysusers
					FOR EACH ROW 
					BEGIN
					  IF :new.suid_gen is null THEN
					     :new.suid_gen := MD_META.get_next_id;
					  END IF;
					END GenSchemaKeyTrig;
/


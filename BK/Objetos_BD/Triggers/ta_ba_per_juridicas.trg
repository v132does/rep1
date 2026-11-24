CREATE OR REPLACE TRIGGER IT.TA_BA_PER_JURIDICAS
 AFTER INSERT OR UPDATE
 ON BA_PER_JURIDICAS
 FOR EACH ROW


BEGIN
IF updating THEN
   IF :old.raz_social <> :new.raz_social THEN
      pre_act_ba_personas(:old.cod_persona,:new.raz_social);
   END IF;
   ELSIF inserting THEN
      pre_act_ba_personas(:new.cod_persona,:new.raz_social);
   END IF;
END;
/


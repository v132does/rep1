CREATE OR REPLACE TRIGGER IT.TA_BA_PER_FISICAS
 AFTER INSERT OR UPDATE
 ON BA_PER_FISICAS
 FOR EACH ROW


BEGIN
IF updating THEN
  IF nvl(:old.pri_nombre,'x') <> nvl(:new.pri_nombre,'x') OR
     nvl(:old.seg_nombre,'x') <> nvl(:new.seg_nombre,'x') OR
     nvl(:old.pri_apellido,'x') <> nvl(:new.pri_apellido,'x') OR
     nvl(:old.seg_apellido,'x') <> nvl(:new.seg_apellido,'x') THEN
     pre_act_ba_personas(:old.cod_persona,:new.pri_nombre||' '||:new.seg_nombre||' '||
                         :new.pri_apellido||' '||:new.seg_apellido);
  END IF;
ELSIF inserting THEN
     pre_act_ba_personas(:new.cod_persona,:new.pri_nombre||' '||:new.seg_nombre||' '||
                         :new.pri_apellido||' '||:new.seg_apellido);
END IF;
END;
/


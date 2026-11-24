CREATE OR REPLACE TRIGGER IT.Tb_ba_onb_correos
  before INSERT ON IT.ba_onb_correos
  FOR EACH ROW

BEGIN
  if inserting then
    :new.nro_correo:= s_ba_onb_correos.nextval;
  end if;
END;
/

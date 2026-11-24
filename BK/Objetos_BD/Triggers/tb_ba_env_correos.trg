CREATE OR REPLACE TRIGGER IT.TB_BA_ENV_CORREOS
  before INSERT ON IT.BA_ENV_CORREOS
  FOR EACH ROW

BEGIN
  if inserting then
    :new.nro_correo := s_ba_env_correos.nextval;
  end if;
END;
/

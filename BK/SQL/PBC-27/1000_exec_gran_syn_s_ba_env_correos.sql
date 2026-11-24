DECLARE
  v_max_nro_correo NUMBER;
BEGIN
  SELECT NVL(MAX(t.nro_correo), 0) + 600
  INTO v_max_nro_correo
  FROM BA_ENV_CORREOS t;

  EXECUTE IMMEDIATE 'CREATE SEQUENCE IT.S_BA_ENV_CORREOS START WITH ' || v_max_nro_correo ||
                    ' MINVALUE 1 MAXVALUE 999999999999999 INCREMENT BY 1 NOCACHE';
END;

create or replace public synonym S_BA_ENV_CORREOS
  for IT.S_BA_ENV_CORREOS;

grant select on IT.S_BA_ENV_CORREOS to IT_TEMPORAL;
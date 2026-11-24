DECLARE
  v_max_nro_correo NUMBER;
BEGIN
  SELECT NVL(MAX(t.nro_correo), 0) + 600
  INTO v_max_nro_correo
  FROM ba_onb_correos t;

  EXECUTE IMMEDIATE 'CREATE SEQUENCE IT.S_BA_ONB_CORREOS START WITH ' || v_max_nro_correo ||
                    ' MINVALUE 1 MAXVALUE 999999999999999 INCREMENT BY 1 NOCACHE';
END;

create or replace public synonym S_BA_ONB_CORREOS
  for IT.S_BA_ONB_CORREOS;

grant select on IT.S_BA_ONB_CORREOS to IT_TEMPORAL;
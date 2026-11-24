begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
/

-- Verificar que el campo esta vacio antes de actualizar
SELECT REFERENCIA, ARCHIVO, CHARSET_ARCHIVO
  FROM IT.GE_ARCHIVOS
 WHERE REFERENCIA IN ('BCP_CIUDADES', 'BCP_BARRIOS')
 ORDER BY REFERENCIA, NRO_SECUENCIA;

-- Actualizar solo si CHARSET_ARCHIVO es null (no sobreescribir si ya fue seteado)
UPDATE IT.GE_ARCHIVOS
   SET CHARSET_ARCHIVO = 'WE8MSWIN1252'
 WHERE REFERENCIA IN ('BCP_CIUDADES', 'BCP_BARRIOS')
   AND CHARSET_ARCHIVO IS NULL;

-- Se esperan exactamente 2 filas (una por BCP_CIUDADES y una por BCP_BARRIOS)
BEGIN
  IF SQL%ROWCOUNT != 2 THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20001, 'Se esperaban 2 filas actualizadas, se obtuvieron: ' || SQL%ROWCOUNT || '. Se revierte el cambio.');
  END IF;
END;
/

COMMIT;

-- Verificar que quedo bien completado
SELECT REFERENCIA, ARCHIVO, CHARSET_ARCHIVO
  FROM IT.GE_ARCHIVOS
 WHERE REFERENCIA IN ('BCP_CIUDADES', 'BCP_BARRIOS')
 ORDER BY REFERENCIA, NRO_SECUENCIA;

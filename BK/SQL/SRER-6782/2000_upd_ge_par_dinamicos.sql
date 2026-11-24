------------------------------
-- upd ge_par_dinamicos --
------------------------------

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 10;
END;
/


UPDATE ge_par_dinamicos
   SET val_parametro = '15500001'   -- siguiente nro cuenta modalidad 155
 WHERE parametro = 'SIG_NROCTA'
   AND cod_modulo = 10
   AND cod_modalidad = 155;

UPDATE ge_par_dinamicos
   SET val_parametro = '15000001'   -- siguiente nro cuenta modalidad 150
 WHERE parametro = 'SIG_NROCTA'
   AND cod_modulo = 10
   AND cod_modalidad = 150;

COMMIT;

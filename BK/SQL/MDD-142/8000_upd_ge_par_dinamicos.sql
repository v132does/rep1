BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
UPDATE it.ge_par_dinamicos
   SET val_parametro = '123,106,114,100'
 WHERE parametro = 'MOD_PAG_BON_TESORO';

COMMIT;
/
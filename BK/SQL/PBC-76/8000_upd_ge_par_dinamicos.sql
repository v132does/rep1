begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
UPDATE GE_PAR_DINAMICOS
SET VAL_PARAMETRO = 1
WHERE PARAMETRO = 'CAN_SES_ACT_ITGF';

COMMIT;
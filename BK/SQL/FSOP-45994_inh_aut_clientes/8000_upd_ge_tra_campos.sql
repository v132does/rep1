BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE ge_tra_campos
SET    nro_orden = 5, validado = 'S'
WHERE  cod_transaccion = 354
AND    cod_campo       = 'IMP_CHEQUE';

COMMIT;

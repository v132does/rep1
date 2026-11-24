BEGIN pre_ini_aplicacion; END; 
/
DELETE FROM ge_transacciones_det b WHERE b.cod_transaccion = 704 AND b.COD_MODALIDAD = 668;

COMMIT;

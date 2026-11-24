BEGIN
  dbms_session.set_identifier('FSOP-62112');
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
END;
/ 
UPDATE ge_par_dinamicos a
   SET a.val_parametro = '26091432'
 WHERE a.parametro = 'MAD_LIM_TRANSACCIONAL'
   AND a.cod_modalidad = '334';
commit;


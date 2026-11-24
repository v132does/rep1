BEGIN
  dbms_session.set_identifier('FSOP-62112');
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
END;
/ 
UPDATE ge_par_dinamicos 
SET val_parametro = '26091432' 
WHERE parametro = 'ONB_LIM_INICIAL' 
AND cod_modulo = 3 
AND cod_modalidad = 334 
AND cod_moneda = 'GS';
commit;

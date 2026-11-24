BEGIN
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
END;
/ 
INSERT INTO ge_par_dinamicos(parametro, val_parametro) VALUES('MTO_MAX_OPE_CAM_NO_CLIENTE','0');

COMMIT;

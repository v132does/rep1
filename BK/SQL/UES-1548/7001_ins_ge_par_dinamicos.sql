begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/ 
insert into it.ge_par_dinamicos
  (parametro, val_parametro )
values
  ('MAX_CAN_LIN_ARC_MT940', 20);
commit;  

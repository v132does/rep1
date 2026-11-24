begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ge_par_dinamicos
  (parametro, val_parametro)
values
  ('COD_ENT_IPS', 5037);
  
commit;

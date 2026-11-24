BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
END;
/
update ge_par_dinamicos s 
set s.val_parametro='GP_AUT'
where s.parametro='USU_GLO_ACTUAL';
commit;

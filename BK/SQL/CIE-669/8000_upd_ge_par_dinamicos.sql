begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;  
/
update ge_par_dinamicos w set w.val_parametro='PARALLEL_EXECUTE' where w.parametro='PRG_ACT_MOV_INI_PARALLEL';
commit;

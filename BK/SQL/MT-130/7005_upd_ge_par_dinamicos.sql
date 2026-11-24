begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
update ge_par_dinamicos
   set val_parametro = val_parametro ||',67,68' 
 where parametro = 'CJ_COD_OPE_TED';
commit;

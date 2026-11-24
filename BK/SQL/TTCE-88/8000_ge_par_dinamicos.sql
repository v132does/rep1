begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
update ge_par_dinamicos
set val_parametro='30'
where parametro='SNP_CANT_MAX_MSJ_LOTE';
commit;

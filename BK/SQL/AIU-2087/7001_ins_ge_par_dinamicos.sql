begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;                                  
/
insert into ge_par_dinamicos(parametro,val_parametro,cod_modulo,cod_modalidad)
   values ('USU_CDA_APP','AISE_AH','3','33');
commit;

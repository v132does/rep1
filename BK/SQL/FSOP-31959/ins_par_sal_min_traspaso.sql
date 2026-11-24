Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_par_dinamicos(parametro,val_parametro)
values('SAL_MIN_TRASPASO','0');

insert into ge_par_dinamicos(parametro,val_parametro)
values('SAL_MIN_TRA_EMPLEADO','0');
commit;

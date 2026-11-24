Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;      
/
update ge_par_dinamicos
set    val_parametro = ' '
where  parametro     = 'CAJ_SER_FIR_EXTERNO';

commit;

begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/

update ge_par_dinamicos c
set c.val_parametro = '3800000'
where c.parametro  = 'SIG_NROCTA'
and c.cod_modulo = '3'
and c.cod_modalidad = '38';


update ge_par_dinamicos c
set c.val_parametro = '530'
where c.parametro  = 'COD_TAS_CAR_FIJ_APR';

update ge_par_dinamicos c
set c.val_parametro = '602'
where c.parametro  = 'COD_TAS_CAR_POR_APR';

commit;

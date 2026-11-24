begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;           
/
update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_FIJ_APR'
   and a.cod_modulo = 4
   and a.cod_modalidad = 41;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_FIJ_APR'
   and a.cod_modulo = 3
   and a.cod_modalidad = 31;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_FIJ_APR'
   and a.cod_modulo = 3
   and a.cod_modalidad = 334;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_POR_APR'
   and a.cod_modulo = 4
   and a.cod_modalidad = 41;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_POR_APR'
   and a.cod_modulo = 3
   and a.cod_modalidad = 31;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_POR_APR'
   and a.cod_modulo = 3
   and a.cod_modalidad = 334;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_TOT_APR'
   and a.cod_modulo = 4
   and a.cod_modalidad = 41;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_TOT_APR'
   and a.cod_modulo = 3
   and a.cod_modalidad = 31;

update ge_par_dinamicos a 
   set a.val_parametro = '2504'
 where a.parametro = 'COD_TRA_CAR_TOT_APR'
   and a.cod_modulo = 3
   and a.cod_modalidad = 334;

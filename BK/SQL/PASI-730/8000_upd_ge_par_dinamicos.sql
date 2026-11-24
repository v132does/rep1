begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 6; end;
/
-- UPDATE
update ge_par_dinamicos pd
set pd.val_parametro = replace(pd.val_parametro, '.', ',')
where pd.parametro = 'PRE_CHE_ROG_VAL_DIV_GTO_ADM';
/
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
update ge_par_dinamicos
set    val_parametro = 'N'
where  parametro = 'CJ_VAL_USD_CAJA';

commit;

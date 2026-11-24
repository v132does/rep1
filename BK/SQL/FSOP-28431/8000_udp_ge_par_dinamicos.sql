BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update ge_par_dinamicos a 
set    a.val_parametro=',970000,970001,970002,'
where a.parametro='COD_RUB_ECO_VIVIENDA';


commit;

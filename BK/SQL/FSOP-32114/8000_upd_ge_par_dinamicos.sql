BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update ge_par_dinamicos a
set a.val_parametro='N'
where a.parametro='PRE_REQ_FUSION'; 

commit; 

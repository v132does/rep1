BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update ge_par_dinamicos a
set a.val_parametro=3280
where a.parametro='SIG_NRO_ASIENTO'; 

commit;

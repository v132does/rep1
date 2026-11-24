BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update  ge_par_dinamicos a
set    a.val_parametro='32,33,34,38,39,40,41'
where a.parametro='COD_GAR_FOGAPY';

commit; 


Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
/

update it.ge_parametros p set p.permiso = 'UENO_AUDITINT' where p.parametro = 'FEC_LCR';

update it.ge_par_dinamicos a
   set a.val_parametro='29/05/2026'
 where a.parametro='FEC_LCR';

commit;
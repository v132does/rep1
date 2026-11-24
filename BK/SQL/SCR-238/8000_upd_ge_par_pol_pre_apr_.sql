BEGIN
  PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1;
END;
/
update GE_PAR_POL_PRE_APR a
   set a.mto_aprobado = 500000
 where a.tip_politica = 3;

commit;

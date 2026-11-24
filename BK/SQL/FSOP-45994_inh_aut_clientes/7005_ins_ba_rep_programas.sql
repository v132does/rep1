BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_rep_programas (COD_PROGRAMA, COD_PRO_REPORTE)
values ('CMCLEREC', 'CLRECAUT');

COMMIT;

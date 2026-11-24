BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CLDCHRD1', 'COM_DIRECT', 'CC_CHE_RECIBIDOS', null, 'F', 5, 'V', 'S', 'N');

insert into ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CLDCHRR1', 'COM_DIRECT', 'CC_CHE_RECIBIDOS', null, 'F', 5, 'V', 'S', 'N');

COMMIT;

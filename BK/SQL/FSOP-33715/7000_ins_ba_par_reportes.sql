begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CLCLEENV', 'COD_MONEDA', null, null, 'F', USER, sysdate, USER, sysdate, null, null, null, null);

commit;
/

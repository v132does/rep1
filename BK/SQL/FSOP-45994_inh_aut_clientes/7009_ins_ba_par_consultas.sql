BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CD_WF_INH', 'FEC_INI_WF', null, null, 'F', 1, 'V', 'S', 'S');

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CD_WF_INH', 'USUARIO', null, null, 'F', 2, 'V', 'S', 'N');

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CD_INH_ERR', 'FECHA', null, null, 'F', 1, 'V', 'S', 'N');

COMMIT;

begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_BLO_CRE', 'CUENTA', 'b', null, 'F', 1, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_BLO_CRE', 'BLO_FEC', 'b', null, 'F', 2, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_BLO_CRD', 'CUENTA', 'b', null, 'F', 1, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_BLO_CRD', 'BLO_FEC', 'b', null, 'F', 2, 'V', 'S', 'N', null);

commit;

Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_SAL_GRU', 'GRU_ECO', 'w', null, 'F', 1, 'V', 'S', 'S', 'S');

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_SAL_GRU', 'NRO_DOCU', 'p', null, 'F', 2, 'V', 'S', 'N', 'S');

insert into BA_PAR_CONSULTAS (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_SAL_GRU', 'NRO_CUENTA', 'c', null, 'F', 3, 'V', 'S', 'N', 'S');

commit;

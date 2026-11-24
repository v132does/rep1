begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;END;
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_CEF_LEG', 'CUENTA', 'a', null, 'F', 1, 'V', 'S', 'S', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_CEF_LEG', 'FECHA', 'a', null, 'F', 2, 'V', 'S', 'S', null);

commit;

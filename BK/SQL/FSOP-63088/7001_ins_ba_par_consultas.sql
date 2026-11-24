Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_SAL_ACU', 'NRO_DOCU', 'a', null, 'F', 1, 'V', 'S', 'S', 'S');

insert into BA_PAR_CONSULTAS (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_SAL_ACU', 'COD_MONEDA', 'a', null, 'F', 2, 'V', 'S', 'S', 'S');

commit;

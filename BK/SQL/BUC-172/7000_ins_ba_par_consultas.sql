Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_PAGPRV', 'FEC_COMP', 'a', null, 'F', 6, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_PAGPRV', 'FEC_PAGO', 'a', null, 'F', 7, 'V', 'S', 'N', null);

commit;

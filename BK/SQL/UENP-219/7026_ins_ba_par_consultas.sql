begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CD_CHEROGA', 'NRO_DOC_SO', null, null, 'F', 1, 'V', 'S', 'N');

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CD_CHEROGA', 'FEC_OFE', null, null, 'F', 2, 'V', 'S', 'N');

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CD_CHEROGA', 'EST_OFERTA', null, null, 'F', 3, 'V', 'S', 'N');


commit;

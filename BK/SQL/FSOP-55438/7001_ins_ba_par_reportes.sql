Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'FECHA', 'a', null, 'F', 1, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'OFI_CAMBIO', null, null, 'F', 2, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'USUARIO', 'a', null, 'F', 3, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'COD_MONEDA', 'a', null, 'F', 4, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'MOD_CAMB', 'a', null, 'F', 5, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'OFICINA', 'a', null, 'F', 6, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'TIP_OPE_CA', 'a', null, 'F', 7, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'MONTO', 'a', null, 'F', 9, 'V', 'S', 'N');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'NUM_DOC_CL', 'a', null, 'F', 10, 'V', 'S', 'N');

commit;

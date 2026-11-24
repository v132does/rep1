Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('PLCHEDES', 'NRO_DOCU', 'ba_personas', null, 'F', null, 'V', 'S', 'S');

insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('LLTRADET', 'NRO_DOCU', 'CLIENTE', null, 'F', null, 'V', 'S', 'N');

commit;

begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('GLESPTMP', 'PERSONA', 'E', null, 'A', null, null, null, null);

commit;

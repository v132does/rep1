BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO)
values ('CLCHRMTL', 'TIP_MON', 'c', null, 'F', 4, 'S', 'S', 'S');

COMMIT;

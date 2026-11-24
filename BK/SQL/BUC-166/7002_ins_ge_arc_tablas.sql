Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
values ('TAR_DEV_CARGOS', 'TM_DEV_CAR_TARJETAS', 'TAR_DEV_CARGOS.CSV', 1, 'N');

commit;

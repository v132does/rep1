Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
values ('COM_CARTERA', 'PR_COM_CARTERA', 'CAB_COM_CARTERA.CSV', 1, 'S');

insert into ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
values ('COM_CARTERA', 'PR_CUO_COM_CARTERA', 'CUO_COM_CARTERA.CSV', 2, 'S');

COMMIT;

begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR)
values ('REGISTRO_PLANES', 'GE_PLAN_DAS_TMP', 'BEXTER_GS.XLS', 1, 'N');

commit;

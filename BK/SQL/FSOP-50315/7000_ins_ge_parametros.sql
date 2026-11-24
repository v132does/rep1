Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION)
values ('INH_CAU_ROLES', 'CAUSALES POR ROL', 'BA_COD_REFERENCIAS', 'Causales por roles, utilizado en la pantalla de Personas Inhibidas');

COMMIT;

BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION)
values ('COD_USU_DEB_AUTOMATICO', 'USUARIO DE DEBITO AUTOMATICO TC', 'GE_PAR_DINAMICOS', null, 'Utilizado para designar el usuario base con el que se insertaran los debitos automaticos de TC');
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_USU_DEB_AUTOMATICO', 'DEBITAUT');
COMMIT;

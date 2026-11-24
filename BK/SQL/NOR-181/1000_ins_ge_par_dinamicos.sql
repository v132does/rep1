BEGIN pre_ini_aplicacion; END; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('FEC_CIE_CRC_MENSUAL', 'FECHA PARA EL CIERRE MENSUAL', 'GE_PAR_DINAMICOS', null, 'Parametro dinamico para indicar la fecha para el cierre mensual.', null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('BA_OBJ_CRC_MENSUAL', 'BASE OBJETIVO PARA CIERRE', 'GE_PAR_DINAMICOS', null, 'Parametro dinamico para indicar la base en cual se debe ejecutar el proceso para cierre.', null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO)
values ('BA_PRO_CRC_CONTROL', 'BASE PRODUCCION', 'GE_PAR_DINAMICOS', null, 'Parametro para indicar nombre de la base de produccion.', null, null);


insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA)
values ('FEC_CIE_CRC_MENSUAL', '30/09/2025', null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA)
values ('BA_OBJ_CRC_MENSUAL', 'finmes', null, null, null, null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA)
values ('BA_PRO_CRC_CONTROL', 'FIELPRODOCI', null, null, null, null);


commit;
/
 

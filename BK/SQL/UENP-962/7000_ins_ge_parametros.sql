BEGIN pre_ini_aplicacion; END; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_OFE_PRE_APR_WEB', 'IND. ACTIVA DESA PRE-APR WEB', 'GE_PAR_DINAMICOS', null, 'Indica que se desactiva o no las oferta de pre-aprobado en la web:
N=No utiliza las tablas web.
S=utiliza las tablas web.', null, null, 'N', null);

COMMIT;

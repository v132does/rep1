Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('MTO_MAX_LIM_PRESTABLE', 'MONTO MAXIMO LIMITE PRESTABLE', 'GE_PAR_DINAMICOS', null, 'Utilizado para guardar el monto máximo de limite prestable', null, null, 'S', null);

commit;

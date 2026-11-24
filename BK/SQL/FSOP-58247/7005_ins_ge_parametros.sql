BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_GRU_TRA_UMBRAL', 'Conf. Grupo Transaccion', 'GE_PAR_DINAMICOS', null, 'Configuracion Grupo Transaccion para validacion de Deposito en efectivo Umbral.', null, null, 'N', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('COD_GRU_TRA_UMBRAL', '110');

commit;

BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_GRU_TRA_UMBRAL_J', 'Conf. Grupo Transaccion USD', 'GE_PAR_DINAMICOS', null, 'Configuracion Grupo Transaccion USD personas Juridicas, para validacion de Deposito en efectivo Umbral.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_GRU_TRA_UMBRAL_GS', 'Conf. Grupo Transaccion GS', 'GE_PAR_DINAMICOS', null, 'Configuracion Grupo Transaccion GS. para validacion de Deposito en efectivo Umbral.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_GRU_TRA_UMBRAL_GS_J', 'Conf. Grupo Transaccion GS', 'GE_PAR_DINAMICOS', null, 'Configuracion Grupo Transaccion GS personas Juridicas, para validacion de Deposito en efectivo Umbral.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IMP_MAX_DEP_F_GS', 'UMBRAL MAXIMO DEP. GS FISICAS', 'GE_PAR_DINAMICOS', null, 'Se utiliza para validar el monto umbral configurado para depósitos en moneda GS persona física.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IMP_MAX_DEP_J_GS', 'UMBRAL MAXIMO DEP. GS JURIDICAS', 'GE_PAR_DINAMICOS', null, 'Se utiliza para validar el monto umbral configurado para depósitos en moneda GS persona juridica.', null, null, 'N', null);

commit;

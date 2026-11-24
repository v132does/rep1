BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CJ_VAL_USD_CAJA', 'Conf. de Val Dep. Efectivo USD Caja', 'GE_PAR_DINAMICOS', null, 'Configuracion para validacion de Deposito en efectivo USD en Caja.', null, null, 'N', null);

commit;

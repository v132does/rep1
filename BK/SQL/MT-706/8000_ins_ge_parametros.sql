BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
--Parámetros
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CJ_VAL_USD_TED', 'Conf. de Val Dep. Efectivo USD TEDs', 'GE_PAR_DINAMICOS', null, 'IT', to_date('10-07-2025 01:28:24', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('10-07-2025 01:28:24', 'dd-mm-yyyy hh24:mi:ss'), 'Configuracion para validacion de Deposito en efectivo USD en TEDs', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IMP_MAX_DEP_FIS', 'UMBRAL MAXIMO DEP. USD TEDs FISICAS', 'GE_PAR_DINAMICOS', null, 'IT', to_date('10-07-2025 01:35:12', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('10-07-2025 01:48:18', 'dd-mm-yyyy hh24:mi:ss'), 'Se utiliza para validar el monto umbral configurado para depósitos en moneda USD persona física.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('IMP_MAX_DEP_JUR', 'UMBRAL MAXIMO DEP. USD TEDs JURIDIC', 'GE_PAR_DINAMICOS', null, 'IT', to_date('10-07-2025 01:35:13', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('10-07-2025 01:48:19', 'dd-mm-yyyy hh24:mi:ss'), 'Se utiliza para validar el monto umbral configurado para depósitos en moneda USD persona jurídica.', null, null, 'N', null);

commit;

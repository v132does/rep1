Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('EXC_VAL_EFE_CAM_CAJA', 'EXCL. VALID. OPER. CAMB. EFECT.CAJA', 'BA_PER_DEF_ADICIONALES', null, 'Excluir validación de Operaciones de Cambio en Caja por Monto Superior a Parametria', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('OPE_SUP_EFE_CAJ_PF', 'OP. SUPERIORES PER. FISICA', 'GE_PAR_DINAMICOS', null, 'Utilizado para validar operaciones que supera el monto estipulado para personas Físicas.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('OPE_SUP_EFE_CAJ_PJ', 'OP. SUPERIORES PER. JURIDICA', 'GE_PAR_DINAMICOS', null, 'Utilizado para validar operaciones que supera el monto estipulado para personas Jurídicas.', null, null, 'N', null);

commit;

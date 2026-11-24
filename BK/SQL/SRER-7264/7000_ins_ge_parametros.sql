begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_CTA_EQU_FOGAPY', 'Cta. a informar a Fogapy', 'GE_CTA_DEF_ADICIONALES', null, 'Cuenta equivalente a reportar en informe FOGAPY', null, null, 'S', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_GAR_INF_FOGAPY', 'GARANTIAS FOGAPY INFORME', 'GE_PAR_DINAMICOS', null, 'Codigos de garantia habilitados para informe FOGAPY', null, null, 'S', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_INF_CTA_FOGAPY', 'INFORMAR A FOGAPY?', 'GE_CTA_DEF_ADICIONALES', null, 'Flag de inclusion/exclusion FOGAPY (S/N)', null, null, 'S', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_MAD_INF_FOGAPY', 'MODALIDADES FOGAPY INFORME', 'GE_PAR_DINAMICOS', null, 'Modalidades/submodalidades habilitadas para informe FOGAPY', null, null, 'S', null);

commit;

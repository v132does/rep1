begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CRE_CHE_CTA_CAN', 'CREA CHEQUERA CTA CANCELADA', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Crea Chequera a Cuenta Cnacelada', null, null, 'S', null);
/
commit;

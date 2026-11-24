begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_PAD_AHO_JUB', 'TRAN. PADRE JUB/PRE/SAL AHO IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción padre módulo ahorro para pago a Jubilados/Préstamos/Sueldos IPS', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_PAD_CTE_JUB', 'TRAN. PADRE JUB/PRE/SAL CTE IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción padre módulo Cuenta Corriente para pago a Jubilados/Préstamos/Sueldos IPS', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_AHO_JUB', 'TRAN. CRED. MOD. AHORRO JUB. IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción crédito módulo ahorro para pago a Jubilados IPS', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_CTE_JUB', 'TRAN. CRED. MOD. CTA.CTE JUB. IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción crédito módulo cuenta corriente para pago a Jubilados IPS', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_AHO_PRE', 'TRAN. CRED. MOD. AHORRO PREST. IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción crédito módulo ahorro para pago de préstamos IPS', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_CTE_PRE', 'TRAN. CRED. MOD. CTA.CTE PREST. IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción crédito módulo cuenta corriente para pago de préstamos IPS', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_AHO_SUE', 'TRAN. CRED. MOD. AHORRO SUEL. IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción crédito módulo ahorro para pago de Sueldos ips', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_CTE_SUE', 'TRAN. CRED. MOD. CTA.CTE SUEL. IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción crédito módulo cuenta corriente para pago de Sueldos ips', null, null, null, 'S');

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COD_TRA_DEB_IPS', 'TRAN. DÉBITO AHORRO CTA.CTE IPS', 'GE_PAR_ENTES', 'SU', 'Código transacción débito módulo ahorro y cuenta corriente  para pago de Jubilados/Préstamos/Sueldos ips', null, null, null, 'S');

insert into it.ge_parametros
  (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, modificable, val_defecto)
values
  ('NRO_CTA_DEB_JUB', 'NRO CTA DÉBITO JUBILADOS IPS', 'GE_PAR_ENTES', 'SU', 'Nro de cuenta débito para pago a Jubilados IPS', null, null, 'N', null);
  

insert into it.ge_parametros
  (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, modificable, val_defecto)
values
  ('NRO_CTA_DEB_PRE', 'NRO CTA DÉBITO PRÉSTAMOS IPS', 'GE_PAR_ENTES', 'SU', 'Nro de cuenta débito para pago de Préstamos IPS', null, null, 'N', null);


insert into it.ge_parametros
  (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, modificable, val_defecto)
values
  ('NRO_CTA_DEB_SUE', 'NRO CTA DÉBITO SUELDOS IPS', 'GE_PAR_ENTES', 'SU', 'Nro de cuenta débito para pago de Sueldos IPS', null, null, 'N', null);


insert into it.ge_parametros
  (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, modificable, val_defecto)
values
  ('COD_ENT_IPS', 'CÓDIGO DE ENTE PARA IPS', 'GE_PAR_DINAMICOS', null, 'Código de ente asignado a IPS', null, null, 'N', null);
  

commit;

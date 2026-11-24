-- Create table
create global temporary table IT.AH_SAL_MENSUALES_TMP
(
  nro_cuenta        VARCHAR2(15) not null,
  ano               NUMBER(4) not null,
  mes               NUMBER(2) not null,
  cod_modulo        NUMBER(3) not null,
  cod_modalidad     NUMBER(3) not null,
  cod_oficina       NUMBER(3) not null,
  can_debitos       NUMBER(8) not null,
  can_creditos      NUMBER(8) not null,
  tot_debitos       NUMBER(18,2) default 0 not null,
  tot_creditos      NUMBER(18,2) default 0 not null,
  can_che_devueltos NUMBER(4) not null,
  sal_acu_diario    NUMBER(18,2) default 0 not null,
  can_dia_acumulado NUMBER(4) not null,
  sal_ini_mes       NUMBER(18,2) default 0 not null,
  sal_fin_mes       NUMBER(18,2) default 0,
  usu_insercion     VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_insercion     DATE default SYSDATE not null,
  usu_modificacion  VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_modificacion  DATE default SYSDATE,
  mto_int_devengado NUMBER(18,2),
  sal_ult_extracto  NUMBER(18,2)
)
on commit preserve rows;
-- Add comments to the table 
comment on table AH_SAL_MENSUALES_TMP
  is 'Contiene datos sobre los Saldos Mensuales de Ahorros que solo existen durante la sesión';
-- Add comments to the columns 
comment on column AH_SAL_MENSUALES_TMP.nro_cuenta
  is 'Numero de Cuenta.';
comment on column AH_SAL_MENSUALES_TMP.ano
  is 'Año del Saldo Mensual.';
comment on column AH_SAL_MENSUALES_TMP.mes
  is 'Mes del Saldo Mensual.';
comment on column AH_SAL_MENSUALES_TMP.cod_modulo
  is 'Codigo de Modulo de la cuenta.';
comment on column AH_SAL_MENSUALES_TMP.cod_modalidad
  is 'Codigo de Modalidad de la cuenta.';
comment on column AH_SAL_MENSUALES_TMP.cod_oficina
  is 'Codigo de Oficina de la cuenta.';
comment on column AH_SAL_MENSUALES_TMP.can_debitos
  is 'Cantidad de Debitos.';
comment on column AH_SAL_MENSUALES_TMP.can_creditos
  is 'Cantidad de Creditos.';
comment on column AH_SAL_MENSUALES_TMP.tot_debitos
  is 'Total de Debitos.';
comment on column AH_SAL_MENSUALES_TMP.tot_creditos
  is 'Total de Creditos.';
comment on column AH_SAL_MENSUALES_TMP.can_che_devueltos
  is 'Cantidad de Cheques Devueltos.';
comment on column AH_SAL_MENSUALES_TMP.sal_acu_diario
  is 'Acumulado de Saldo Diario.';
comment on column AH_SAL_MENSUALES_TMP.can_dia_acumulado
  is 'Cantidad de Dias Acumulados.';
comment on column AH_SAL_MENSUALES_TMP.sal_ini_mes
  is 'Saldo Inicial del Mes.';
comment on column AH_SAL_MENSUALES_TMP.sal_fin_mes
  is 'Saldo Final del Mes.';
comment on column AH_SAL_MENSUALES_TMP.usu_insercion
  is 'Usuario que realizo la insercion del registro.';
comment on column AH_SAL_MENSUALES_TMP.fec_insercion
  is 'Fecha en que se inserto el registro.';
comment on column AH_SAL_MENSUALES_TMP.usu_modificacion
  is 'Usuario que realizo la ultima modificacion en el registro.';
comment on column AH_SAL_MENSUALES_TMP.fec_modificacion
  is 'Fecha en que se realizo la ultima modificacion en el registro.';
comment on column AH_SAL_MENSUALES_TMP.mto_int_devengado
  is 'Monto de Interes Devengado.';
comment on column AH_SAL_MENSUALES_TMP.sal_ult_extracto
  is 'Saldo de Último Extracto.';



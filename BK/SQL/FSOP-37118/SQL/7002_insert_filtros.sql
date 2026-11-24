begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;

/

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('SITU_TR_RE', 'Situacion', 'S', 1, 'V', null, null, 'sv_tra_rec_spi_sipap', 's.situacion', null, 'select r.significado,r.val_minimo from  ba_cod_referencias r
where r.dominio = ''SITUACION''', user, sysdate, user, sysdate, 'Ingrese Situacion de la transferencia', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('TRA_ENV_SI', 'Situacion', 'S', 1, 'V', null, null, 'sv_tra_env_spi_sipap', 's.situacion', null, 'select r.significado,r.val_minimo from  ba_cod_referencias r
where r.dominio = ''SITUACION''', user, to_date('16-08-2024 14:47:30', 'dd-mm-yyyy hh24:mi:ss'), user, sysdate, 'Ingrese Situacion de la transferencia', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('FEC_TRA_IN', 'Fecha desde', 'F', 10, 'R', null, null, 'sv_tra_env_spi_sipap', 'trunc(s.fec_insercion)', null, null, user, sysdate, user, sysdate, 'Ingrese fecha insercion', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('FEC_TRA_EH', 'Fecha hasta', 'F', 10, 'R', null, null, 'sv_tra_env_spi_sipap', 'trunc(s.fec_insercion)', null, null, user, sysdate, user, sysdate, 'Ingrese fecha insercion', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('FEC_TRA_RH', 'Fecha hasta', 'F', 10, 'R', null, null, 'sv_tra_rec_spi_sipap', 'trunc(s.fec_insercion)', null, null, user, sysdate, user, sysdate, 'Ingrese fecha insercion', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('TRA_EST_RE', 'Estado', 'S', 1, 'V', null, null, 'sv_tra_rec_spi_sipap', 's.estado', null, 'select r.significado,r.val_minimo from ba_cod_referencias r 
where r.dominio = ''EST_MSJ_SNP''', user, sysdate, user, sysdate, 'Ingrese Estado de transferencia', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('COD_PER_BR', 'Cod. Persona', 'S', 15, 'R', null, null, 'sv_tra_rec_spi_sipap', 's.cod_per_beneficiario', null, null, user, to_date('16-08-2024 14:55:24', 'dd-mm-yyyy hh24:mi:ss'), user, sysdate, 'Ingrese codigo de persona', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('FEC_TRA_DE', 'Fecha desde', 'F', 10, 'R', null, null, 'sv_tra_rec_spi_sipap', 'trunc(s.fec_insercion)', null, null, user, to_date('16-08-2024 14:55:57', 'dd-mm-yyyy hh24:mi:ss'), user, sysdate, 'Ingrese fecha insercion', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('COD_PERS', 'Cod. Persona', 'S', 15, 'R', null, null, 'sv_tra_env_spi_sipap', 's.cod_per_solicitante', null, null, user, sysdate, user, sysdate, 'Ingrese codigo de persona', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('NRO_CTASOL', 'Nro Cuenta', 'S', 35, 'R', null, null, 'sv_tra_env_spi_sipap', 's.nro_cta_solicitante', null, null, user, sysdate, user, sysdate, 'Ingrese cuenta solicitante', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('TRA_ESTADO', 'Estado', 'S', 1, 'V', null, null, 'sv_tra_env_spi_sipap', 's.estado', null, 'select r.significado,r.val_minimo from ba_cod_referencias r 
where r.dominio = ''EST_MSJ_SNP''', user, to_date('14-08-2024 19:33:21', 'dd-mm-yyyy hh24:mi:ss'), user, sysdate, 'Ingrese Estado de transferencia', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

insert into ge_filtros (COD_CAMPO, DESCRIPCION, TIP_CAMPO, LON_CAMPO, TIP_DATO, VAL_MAX_PERMITIDO, VAL_MIN_PERMITIDO, NOM_TAB_ASOCIADA, NOM_REFERENCIA, NRO_ORDEN, DET_SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, TIPO, AFE_SEGMENTACION, AFE_PUNTUACION, AFE_REPORTES, AFE_CONSULTAS, AFE_RECLAMOS, TIP_SOL_IGUAL, PERMISO)
values ('CTA_BEN_RE', 'Nro Cuenta', 'S', 35, 'R', null, null, 'sv_tra_rec_spi_sipap', 's.nro_cta_beneficiario', null, null, user, to_date('14-08-2024 20:58:11', 'dd-mm-yyyy hh24:mi:ss'), user, to_date('14-08-2024 20:58:11', 'dd-mm-yyyy hh24:mi:ss'), 'Ingrese cuenta solicitante', 'D', 'N', 'N', 'N', 'S', 'N', 'N', null);

/ 
commit;

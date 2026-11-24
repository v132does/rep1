ALTER TABLE it.ge_dat_transferencias 
ADD (
  consumidor               VARCHAR2(35),
  cod_per_solicitante      VARCHAR2(10),
  cod_per_beneficiario     VARCHAR2(10),
  cod_mon_solicitante      VARCHAR2(3),
  cod_mon_beneficiario     VARCHAR2(3),
  cod_pai_solicitante      VARCHAR2(3),
  cod_pai_beneficiario     VARCHAR2(3),
  email_solicitante        VARCHAR2(80),
  email_beneficiario       VARCHAR2(80),
  alias_solicitante        VARCHAR2(80),
  alias_beneficiario       VARCHAR2(80),
  tip_per_solicitante      VARCHAR2(10),
  tip_per_beneficiario     VARCHAR2(10),
  mot_transferencia        VARCHAR2(80),
  inf_adi_consumidor       CLOB
);
comment on column IT.GE_DAT_TRANSFERENCIAS.consumidor
  is 'Consumidor de la API';
comment on column IT.GE_DAT_TRANSFERENCIAS.cod_per_solicitante
  is 'Codigo de persona del solicitante';
comment on column IT.GE_DAT_TRANSFERENCIAS.cod_per_beneficiario
  is 'Codigo de persona del beneficiario';
comment on column IT.GE_DAT_TRANSFERENCIAS.cod_mon_solicitante
  is 'Codigo moneda del solicitante';
comment on column IT.GE_DAT_TRANSFERENCIAS.cod_mon_beneficiario
  is 'Codigo moneda del beneficiario';
comment on column IT.GE_DAT_TRANSFERENCIAS.cod_pai_solicitante
  is 'Codigo pais del solicitante';
comment on column IT.GE_DAT_TRANSFERENCIAS.cod_pai_beneficiario
  is 'Codigo pais del beneficiario';
comment on column IT.GE_DAT_TRANSFERENCIAS.email_solicitante
  is 'Email del solicitante';
comment on column IT.GE_DAT_TRANSFERENCIAS.email_beneficiario
  is 'Email del beneficiario.';
comment on column IT.GE_DAT_TRANSFERENCIAS.alias_solicitante
  is 'Alias del solicitante';
comment on column IT.GE_DAT_TRANSFERENCIAS.alias_beneficiario
  is 'alias del beneficiario';
comment on column IT.GE_DAT_TRANSFERENCIAS.tip_per_solicitante
  is 'Tipo de persona del solicitante';
comment on column IT.GE_DAT_TRANSFERENCIAS.tip_per_beneficiario
  is 'tipo de persona del beneficiario';
comment on column IT.GE_DAT_TRANSFERENCIAS.mot_transferencia
  is 'Motivo de la transferencia';
comment on column IT.GE_DAT_TRANSFERENCIAS.inf_adi_consumidor
  is 'Informacion adicional enviada por los consumidores';

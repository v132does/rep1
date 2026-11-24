-- Add/modify columns 
alter table IT.AH_CON_DIA_DET_HIS add imp_rg4815 number(18,4);
alter table IT.AH_CON_DIA_DET_HIS add sig_rg4815 varchar2(1);
alter table IT.AH_CON_DIA_DET_HIS add extracash number(1);
alter table IT.AH_CON_DIA_DET_HIS add imp_extracash number(18,4);
alter table IT.AH_CON_DIA_DET_HIS add sig_extracash varchar2(1);
alter table IT.AH_CON_DIA_DET_HIS add tra_tokenizada VARCHAR2(1);
alter table IT.AH_CON_DIA_DET_HIS add tas_isa number(18,2);
alter table IT.AH_CON_DIA_DET_HIS add tra_origen varchar2(1);
alter table IT.AH_CON_DIA_DET_HIS add imp_rg5272 number(18,4);
alter table IT.AH_CON_DIA_DET_HIS add sig_imp_rg5272 varchar2(1);
alter table IT.AH_CON_DIA_DET_HIS add fec_transferencia varchar2(20);
alter table IT.AH_CON_DIA_DET_HIS add ref_adquiriente varchar2(23);
alter table IT.AH_CON_DIA_DET_HIS add id_adquiriente varchar2(11);
alter table IT.AH_CON_DIA_DET_HIS add nro_ref_recupero varchar2(12);
alter table IT.AH_CON_DIA_DET_HIS add id_terminal varchar2(8);
alter table IT.AH_CON_DIA_DET_HIS add nom_terminal varchar2(99);
alter table IT.AH_CON_DIA_DET_HIS add id_transaccion varchar2(16);
alter table IT.AH_CON_DIA_DET_HIS add token varchar2(11);
alter table IT.AH_CON_DIA_DET_HIS add billetera varchar2(3);
alter table IT.AH_CON_DIA_DET_HIS add per_tra_fondos varchar2(286);
-- Add comments to the columns 
comment on column IT.AH_CON_DIA_DET_HIS.filter
  is 'Filtros/Filler';
comment on column IT.AH_CON_DIA_DET_HIS.imp_rg4815
  is 'Importe de RG4815';
comment on column IT.AH_CON_DIA_DET_HIS.sig_rg4815
  is 'Signo del Importe RG4815. Valores posibles: "-", "+"';
comment on column IT.AH_CON_DIA_DET_HIS.extracash
  is '0-NO / 1-SI';
comment on column IT.AH_CON_DIA_DET_HIS.imp_extracash
  is 'Importe Extracash';
comment on column IT.AH_CON_DIA_DET_HIS.sig_extracash
  is 'Signo del Importe Extracash. Valores posibles: "-", "+"';
comment on column IT.AH_CON_DIA_DET_HIS.tra_tokenizada
  is 'Identifica las transacciones que llegarian por una tarjeta Tokenizada opciones 0- No tokenizada, 1- Tokenizada';
comment on column IT.AH_CON_DIA_DET_HIS.tas_isa
  is 'Tasa ISA';
comment on column IT.AH_CON_DIA_DET_HIS.tra_origen
  is 'Indica el origen de la Transaccion. Local o Internacional';
comment on column IT.AH_CON_DIA_DET_HIS.imp_rg5272
  is 'Importe RG 5272';
comment on column IT.AH_CON_DIA_DET_HIS.sig_imp_rg5272
  is 'Signo del Importe RG 5272. Valores posibles: "-", "+"';
comment on column IT.AH_CON_DIA_DET_HIS.fec_transferencia
  is 'Fecha de transferencia / ID del ciclo de vida';
comment on column IT.AH_CON_DIA_DET_HIS.ref_adquiriente
  is 'Datos de referencia del adquirente';
comment on column IT.AH_CON_DIA_DET_HIS.id_adquiriente
  is 'ID de la institución adquirente';
comment on column IT.AH_CON_DIA_DET_HIS.nro_ref_recupero
  is 'Número de referencia de recuperacion';
comment on column IT.AH_CON_DIA_DET_HIS.id_terminal
  is 'Identificacion del terminal';
comment on column IT.AH_CON_DIA_DET_HIS.nom_terminal
  is 'Nombre/localizacion del terminal';
comment on column IT.AH_CON_DIA_DET_HIS.id_transaccion
  is 'ID del ciclo de vida de la transaccion';
comment on column IT.AH_CON_DIA_DET_HIS.token
  is 'Token';
comment on column IT.AH_CON_DIA_DET_HIS.billetera
  is 'Billetera';
comment on column IT.AH_CON_DIA_DET_HIS.per_tra_fondos
  is 'Persona que envia la Transferencia de Fondos';

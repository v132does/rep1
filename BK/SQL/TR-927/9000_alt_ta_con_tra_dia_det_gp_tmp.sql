-- Add/modify columns 
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add cod_estado VARCHAR2(1);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add fec_estado VARCHAR2(20);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add imp_rg4815 NUMBER(20,4);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add sig_imp_rg4815 VARCHAR2(1);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add tra_tokenizada VARCHAR2(1);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add ori_transaccion NUMBER;
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add aut_id NUMBER;
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add ext_cash VARCHAR2(1);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add imp_ext_cash NUMBER(20,4);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add sig_ext_cash VARCHAR2(1);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add imp_rg_5272 NUMBER(20,4);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add sig_imp_rg_5272 VARCHAR2(1);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add fec_transferencia VARCHAR2(20);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add cod_ins_adquieriente NUMBER;
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add nro_ref_recuperacion VARCHAR2(12);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add id_terminal VARCHAR2(8);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add nom_terminal VARCHAR2(50);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add dat_token NUMBER;
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add dat_red VARCHAR2(12);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add dat_billetera VARCHAR2(3);
alter table IT.TA_CON_TRA_DIA_DET_GP_TMP add per_env_fondos VARCHAR2(320);
-- Add comments to the columns 
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.cod_estado
  is 'Cod. Ultimo estado de la autorizacion';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.fec_estado
  is 'Fecha de ultimo cambio de estado de autorizacion';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.imp_rg4815
  is 'Importe impuesto RG4815';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.sig_imp_rg4815
  is 'Signo del campo anterior. Valores posibles: "-", "+"';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.tra_tokenizada
  is 'Identifica las transacciones que llegarian por una Tarjeta Tokenizada. Opciones 0- No tokenizada, 1- Tokenizada';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.ori_transaccion
  is 'Origen de la transaccion. Local=0, Internacional=1';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.aut_id
  is 'ID de la Autorizacion';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.ext_cash
  is '0 - No / 1 - Si';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.imp_ext_cash
  is 'Importe Extra Cash';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.sig_ext_cash
  is 'Signo Importe Extra Cash. Valores posibles: "-","+"';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.imp_rg_5272
  is 'Importe de Impuesto RG 5272 25%';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.sig_imp_rg_5272
  is 'Signo del Impuesto RG 5272. Valores posibles: "-", "+"';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.fec_transferencia
  is 'Fecha (mes y día) en que los fondos serán transferidos entre un adquirente y un emisor o un intermediario apropiado';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.cod_ins_adquieriente
  is 'Codigo de identificacion de la institucion adquiriente';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.nro_ref_recuperacion
  is 'Numero de referencia de recuperacion';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.id_terminal
  is 'Identificacion de la terminal';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.nom_terminal
  is 'Nombre/ubicación de la terminal de tarjetas para todas las transacciones';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.dat_token
  is 'ID del solicitante del Token';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.dat_red
  is 'Datos de Red';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.dat_billetera
  is 'Identificador de la Billetera';
comment on column IT.TA_CON_TRA_DIA_DET_GP_TMP.per_env_fondos
  is 'Persona que envia la Transferencia de Fondos';

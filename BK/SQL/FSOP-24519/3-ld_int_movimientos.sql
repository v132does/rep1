-- Create table
create table IT.LD_INT_MOVIMIENTOS
(
  fecha                     DATE not null,
  hora                      VARCHAR2(8) not null,
  cod_usuario               VARCHAR2(10) not null,
  nro_secuencia             NUMBER(3) not null,
  nro_cuenta                VARCHAR2(15),
  cod_modulo                NUMBER(3),
  cod_modalidad             NUMBER(3),
  cod_transaccion           NUMBER(4),
  cod_moneda                VARCHAR2(3),
  tip_monto                 VARCHAR2(1) not null,
  monto                     NUMBER(18,2),
  cotizacion                NUMBER(14,8),
  tipo                      VARCHAR2(1) not null,
  cod_ofi_origen            NUMBER(3),
  nro_caja                  NUMBER(3),
  cod_canal                 NUMBER(3),
  estado                    VARCHAR2(1),
  reversado                 VARCHAR2(1),
  cod_usu_reversion         VARCHAR2(10),
  cod_pai_corresponsal      NUMBER(3),
  cod_persona               VARCHAR2(10),
  cod_tip_doc_solicitante   NUMBER(3),
  nro_doc_solicitante       VARCHAR2(20),
  cod_per_beneficiario      VARCHAR2(10),
  cod_pai_beneficiario      NUMBER(3),
  cod_ciu_beneficiario      NUMBER(3),
  bco_beneficiario          NUMBER(3),
  cod_per_solicitante       VARCHAR2(10),
  cod_pai_solicitante       NUMBER(3),
  cod_ciu_solicitante       NUMBER(3),
  cod_tra_padre             NUMBER(4),
  cod_mod_padre             NUMBER(4),
  cod_mad_padre             NUMBER(4),
  est_informacion           VARCHAR2(1),
  fec_generacion            DATE,
  fec_proceso               DATE,
  cod_operacion             NUMBER(3),
  cod_tip_doc_beneficiario  NUMBER(3),
  nro_doc_beneficiario      VARCHAR2(20),
  mto_equ_local             NUMBER,
  mto_mon_origen            NUMBER(20,2),
  cod_mon_destino           VARCHAR2(3),
  cot_mon_destino           NUMBER(20,2),
  nom_ent_externa           VARCHAR2(30),
  nro_cta_ent_externa       VARCHAR2(50),
  cod_pai_ent_externa       VARCHAR2(5),
  nom_ciu_ent_externa       VARCHAR2(50),
  nro_cheque                VARCHAR2(30),
  nro_boleta                VARCHAR2(25),
  motivo                    VARCHAR2(60),
  observacion               VARCHAR2(50),
  cod_pai_bco_intermediario VARCHAR2(6),
  nom_bco_intermediario     VARCHAR2(30),
  cod_aba_bco_intermediario VARCHAR2(18),
  cod_swi_bco_intermediario VARCHAR2(18),
  nom_corresponsal          VARCHAR2(40),
  usu_insercion             VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_insercion             DATE default SYSDATE not null,
  usu_modificacion          VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_modificacion          DATE default SYSDATE not null,
  region                    VARCHAR2(1),
  nombre_solicitante        VARCHAR2(120),
  nombre_beneficiario       VARCHAR2(120),
  ins_seprelad              VARCHAR2(10),
  cta_destino               VARCHAR2(15),
  cda                       VARCHAR2(1),
  des_tra_hija              VARCHAR2(300),
  des_tra_madre             VARCHAR2(300),
  cod_mon_original          VARCHAR2(3)
)
tablespace IT_DATA
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
-- Add comments to the table 
comment on table IT.LD_INT_MOVIMIENTOS
  is 'Movimientos Diarios. Contiene todos los movimientos generados en todo el Sistema.';
-- Add comments to the columns 
comment on column IT.LD_INT_MOVIMIENTOS.fecha
  is 'Fecha de la transacci�n.';
comment on column IT.LD_INT_MOVIMIENTOS.hora
  is 'Hora del movimiento.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_usuario
  is 'C�digo de operador.';
comment on column IT.LD_INT_MOVIMIENTOS.nro_secuencia
  is 'N�mero de secuencia.';
comment on column IT.LD_INT_MOVIMIENTOS.nro_cuenta
  is 'N�mero de cuenta.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_modulo
  is 'C�digo de m�dulo.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_modalidad
  is 'C�digo de modalidad.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_transaccion
  is 'C�digo de transacci�n.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_moneda
  is 'C�digo de moneda.';
comment on column IT.LD_INT_MOVIMIENTOS.tip_monto
  is 'Tipo de Monto (E=Efectivo, C=Cargo Nuestro, O=Cargo Otros S=Otros.Bcos.Suc. T=Otros.Bcos.Tarde, X=Plaza Extranjera, N=No entro por caja).';
comment on column IT.LD_INT_MOVIMIENTOS.monto
  is 'Importe de la transacci�n.';
comment on column IT.LD_INT_MOVIMIENTOS.cotizacion
  is 'Cotizaci�n de la transacci�n';
comment on column IT.LD_INT_MOVIMIENTOS.tipo
  is 'Tipo de Movimiento.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_ofi_origen
  is 'C�digo de oficina de Origen.';
comment on column IT.LD_INT_MOVIMIENTOS.nro_caja
  is 'N�mero de caja.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_canal
  is 'C�digo de canal por donde ingreso la operaci�n';
comment on column IT.LD_INT_MOVIMIENTOS.estado
  is 'Estado del movimiento. ( ).';
comment on column IT.LD_INT_MOVIMIENTOS.reversado
  is 'Reversado. (N=NO / S=SI).';
comment on column IT.LD_INT_MOVIMIENTOS.cod_usu_reversion
  is 'Operador de reversi�n.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_pai_corresponsal
  is 'C�digo del Pa�s del Corresponsal.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_persona
  is 'Persona asociada al movimiento.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_tip_doc_solicitante
  is 'Tipo  de documento de cliente ocasional solicitante';
comment on column IT.LD_INT_MOVIMIENTOS.nro_doc_solicitante
  is 'N�mero de documento cliente ocasional solicitante';
comment on column IT.LD_INT_MOVIMIENTOS.cod_per_beneficiario
  is 'C�digo del Cliente Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_pai_beneficiario
  is 'C�digo del Pa�s del Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_ciu_beneficiario
  is 'C�digo del Ciudad del Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS.bco_beneficiario
  is 'C�digo del Banco del Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_per_solicitante
  is 'C�digo del Cliente Solicitante.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_pai_solicitante
  is 'C�digo del Pa�s del Solicitante';
comment on column IT.LD_INT_MOVIMIENTOS.cod_ciu_solicitante
  is 'C�digo del Ciudad del Solicitante';
comment on column IT.LD_INT_MOVIMIENTOS.cod_tra_padre
  is 'C�digo de transacci�n padre.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_mod_padre
  is 'C�digo m�dulo padre';
comment on column IT.LD_INT_MOVIMIENTOS.cod_mad_padre
  is 'C�digo modalidad padre ';
comment on column IT.LD_INT_MOVIMIENTOS.est_informacion
  is 'Estado de Informaci�n.';
comment on column IT.LD_INT_MOVIMIENTOS.fec_generacion
  is 'Fecha de Generaci�n.';
comment on column IT.LD_INT_MOVIMIENTOS.fec_proceso
  is 'Fecha de Proceso.';
comment on column IT.LD_INT_MOVIMIENTOS.cod_operacion
  is 'Tipo de Operaci�n para CML';
comment on column IT.LD_INT_MOVIMIENTOS.cod_tip_doc_beneficiario
  is 'Tipo de documento cliente ocasional beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS.nro_doc_beneficiario
  is 'N�mero de documento cliente ocasional beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS.mto_equ_local
  is 'Monto equivalente en moneda local.';
comment on column IT.LD_INT_MOVIMIENTOS.usu_insercion
  is 'Usuario que realiz� la inserci�n del registro.';
comment on column IT.LD_INT_MOVIMIENTOS.fec_insercion
  is 'Fecha en que se insert� el registro.';
comment on column IT.LD_INT_MOVIMIENTOS.usu_modificacion
  is 'Usuario que realiz� la �ltima modificaci�n en el registro.';
comment on column IT.LD_INT_MOVIMIENTOS.fec_modificacion
  is 'Fecha en que se realiz� la �ltima modificaci�n en el registro.';
comment on column IT.LD_INT_MOVIMIENTOS.nombre_solicitante
  is 'Nombre del Solicitante.';
comment on column IT.LD_INT_MOVIMIENTOS.nombre_beneficiario
  is 'Nombre del Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS.ins_seprelad
  is 'Instrumento SEPRELAD.';
comment on column IT.LD_INT_MOVIMIENTOS.cta_destino
  is 'Numero de Cuenta Destino.';
comment on column IT.LD_INT_MOVIMIENTOS.cda
  is 'CDA';
comment on column IT.LD_INT_MOVIMIENTOS.des_tra_hija
  is 'DES_TRA_HIJA';
comment on column IT.LD_INT_MOVIMIENTOS.des_tra_madre
  is 'DES_TRA_MADRE';
comment on column IT.LD_INT_MOVIMIENTOS.cod_mon_original
  is 'Código de Moneda Original.';
-- Create/Recreate indexes 
create unique index IT.PK_LD_INT_MOVIMIENTOS on IT.LD_INT_MOVIMIENTOS (FECHA, HORA, COD_USUARIO, NRO_SECUENCIA, TIPO, TIP_MONTO)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
-- Grant/Revoke object privileges 
grant select, insert, update, delete, alter, debug on IT.LD_INT_MOVIMIENTOS to IT_TEMPORAL;

-- Create the synonym 
create or replace public synonym LD_INT_MOVIMIENTOS
  for IT.LD_INT_MOVIMIENTOS
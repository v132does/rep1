-- Create table
create table IT.LD_INT_MOVIMIENTOS_TMP
(
  tip_movimiento            VARCHAR2(1),
  fecha                     DATE,
  hora                      VARCHAR2(8),
  cod_usuario               VARCHAR2(10),
  nro_secuencia             NUMBER(3),
  nro_cuenta                VARCHAR2(15),
  cod_modulo                NUMBER(3),
  cod_modalidad             NUMBER(3),
  cod_transaccion           NUMBER(4),
  cod_moneda                VARCHAR2(3),
  tip_monto                 VARCHAR2(1),
  monto                     NUMBER,
  cotizacion                NUMBER,
  tipo                      VARCHAR2(1),
  cod_ofi_origen            NUMBER,
  nro_caja                  NUMBER(3),
  cod_canal                 NUMBER,
  estado                    VARCHAR2(1),
  reversado                 VARCHAR2(1),
  cod_usu_reversion         VARCHAR2(10),
  cod_persona               CHAR(10),
  cod_tip_doc_solicitante   NUMBER,
  nro_doc_solicitante       VARCHAR2(20),
  cod_per_beneficiario      VARCHAR2(10),
  cod_pai_beneficiario      NUMBER,
  cod_ciu_beneficiario      NUMBER,
  cod_per_solicitante       VARCHAR2(10),
  cod_pai_solicitante       NUMBER,
  cod_ciu_solicitante       NUMBER,
  cod_tra_padre             NUMBER(4),
  cod_mod_padre             NUMBER(3),
  cod_mad_padre             NUMBER(3),
  cod_operacion             NUMBER(3),
  cod_tip_doc_beneficiario  NUMBER,
  nro_doc_beneficiario      VARCHAR2(20),
  cod_ofi_destino           NUMBER,
  nombre_solicitante        VARCHAR2(120),
  dir_solicitante           VARCHAR2(100),
  nombre_beneficiario       VARCHAR2(120),
  dir_beneficiario          VARCHAR2(100),
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
  nom_bco_intermediario     VARCHAR2(60),
  cod_aba_bco_intermediario VARCHAR2(18),
  cod_swi_bco_intermediario VARCHAR2(18),
  nom_corresponsal          VARCHAR2(40),
  usu_insercion             VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_insercion             DATE default SYSDATE not null,
  usu_modificacion          VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_modificacion          DATE default SYSDATE not null,
  region                    VARCHAR2(1),
  ins_seprelad              VARCHAR2(10),
  cta_destino               VARCHAR2(15),
  cda                       VARCHAR2(1),
  des_tra_hija              VARCHAR2(300),
  des_tra_madre             VARCHAR2(300)
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
comment on table IT.LD_INT_MOVIMIENTOS_TMP
  is 'Tabla Temporal de Movimientos Diarios para el proceso de interfaz.';
-- Add comments to the columns 
comment on column IT.LD_INT_MOVIMIENTOS_TMP.tip_movimiento
  is 'Tipo de Movimientos.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.fecha
  is 'Fecha de la transacci�n.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.hora
  is 'Hora del movimiento.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_usuario
  is 'C�digo de operador.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_secuencia
  is 'N�mero de secuencia.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_cuenta
  is 'N�mero de cuenta.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_modulo
  is 'C�digo de modulo.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_modalidad
  is 'C�digo de modalidad.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_transaccion
  is 'C�digo de transacci�n.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_moneda
  is 'C�digo de moneda.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.tip_monto
  is 'Tipo de Monto (E=Efectivo, C=Cargo Nuestro, O=Cargo Otros S=Otros.Bcos.Suc. T=Otros.Bcos.Tarde, X=Plaza Extranjera, N=No entro por caja).';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.monto
  is 'Importe de la transaccion.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cotizacion
  is 'Cotizaci�n de la transacci�n';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.tipo
  is 'Tipo de Movimiento.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_ofi_origen
  is 'C�digo de oficina de Origen.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_caja
  is 'N�mero de caja.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_canal
  is 'C�digo de canal por donde ingres� la operaci�n';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.estado
  is 'Estado del movimiento.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.reversado
  is 'Reversado. (N=NO / S=SI).';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_usu_reversion
  is 'Operador de reversi�n.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_persona
  is 'Persona asociada al movimiento.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_tip_doc_solicitante
  is 'Tipo  de documento de cliente ocasional solicitante';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_doc_solicitante
  is 'N�mero de documento cliente ocasional solicitante';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_per_beneficiario
  is 'C�digo del Cliente Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_pai_beneficiario
  is 'C�digo del Pa�s del Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_ciu_beneficiario
  is 'C�digo del Ciudad del Beneficiario.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_per_solicitante
  is 'C�digo del Cliente Remitente.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_pai_solicitante
  is 'C�digo del Pa�s del Solicitante.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_ciu_solicitante
  is 'C�digo del Ciudad del Solicitante.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_tra_padre
  is 'C�digo de transacci�n padre.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_mod_padre
  is 'C�digo m�dulo padre';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_mad_padre
  is 'C�digo modalidad padre ';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_operacion
  is 'Tipo de Operaci�n para CML';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_tip_doc_beneficiario
  is 'Tipo de documento cliente ocasional beneficiario';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_doc_beneficiario
  is 'N�mero de documento cliente ocasional beneficiario';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_ofi_destino
  is 'C�digo de oficina de Destino.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nombre_solicitante
  is 'Nombre del Solicitante.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.dir_solicitante
  is 'Direcci�n del Solicitante.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nombre_beneficiario
  is 'Nombre del Beneficiario. ';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.dir_beneficiario
  is 'Direcci�n del Beneficiario. ';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.mto_equ_local
  is 'Monto equivalente en moneda local.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.mto_mon_origen
  is 'Monto en Moneda de origen usado en
operaciones con Moneda origen distinta a
moneda local.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_mon_destino
  is 'Codigo de Moneda (BCP) segun codificacion convenida para arbitraje.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cot_mon_destino
  is 'Cotizacion de la Moneda destino solo para
tipo de operacion arbitraje. Cotizacion
del Dolar estadounidense en la moneda
destino. Si la moneda destino es dolar
estadounidense, completar con 1.00';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nom_ent_externa
  is 'Nombre otra entidad origen/destino o
Banco Corresponsal, en casos de
transferencias.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_cta_ent_externa
  is 'Numero de otra Cuenta origen / destino.
(en casos de transferencias)';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_pai_ent_externa
  is 'Codigo de pais de la otra entidad origen /
destino o Banco Corresponsal, segun
codificacion convenida en casos de
transferencias.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nom_ciu_ent_externa
  is 'Nombre de otra ciudad origen / destino,
(en casos de transferencias)';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_cheque
  is 'Numero de Cheque / Nro.cupon
(depositos, cobro cheques, etc.)';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nro_boleta
  is 'Nro de boleta o comprobante de deposito /
extraccion / compra / venta divisas /
nro.CDA / nro.cupon de tarjeta / etc.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.motivo
  is 'Descripcion del motivo de la transferencia,
devolucion, prestamo, etc.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.observacion
  is 'Observacion en el caso de ser rechazado
por falta de fondo.Cheque emitido debito /
Cargos bancarios o varios debito / credito
/ Extracciones caja de ahorro debito.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_pai_bco_intermediario
  is 'Codigo de pais de Banco Intermediario,
segun codificacion convenida.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nom_bco_intermediario
  is 'Nombre de Banco Intermediario';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_aba_bco_intermediario
  is 'Codigo alfanumerico. Usado en
Transferencias internacionales.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cod_swi_bco_intermediario
  is 'Codigo internacional alfanumerico. Usado
en Transferencias internacionales.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.nom_corresponsal
  is 'Nombre de sucursal de Banco Corresponsal.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.usu_insercion
  is 'Usuario que realiz� la inserci�n del registro.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.fec_insercion
  is 'Fecha en que se insert� el registro.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.usu_modificacion
  is 'Usuario que realiz� la �ltima modificaci�n en el registro.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.fec_modificacion
  is 'Fecha en que se realiz� la �ltima modificaci�n en el registro.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.ins_seprelad
  is 'Instrumento SEPRELAD.';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cta_destino
  is 'Numero de Cuenta Destino';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.cda
  is 'CDA';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.des_tra_hija
  is 'DES_TRA_HIJA';
comment on column IT.LD_INT_MOVIMIENTOS_TMP.des_tra_madre
  is 'DES_TRA_MADRE';
-- Grant/Revoke object privileges 
grant select, insert, update, delete on IT.LD_INT_MOVIMIENTOS_TMP to IT_TEMPORAL;

-- Create the synonym 
create or replace public synonym LD_INT_MOVIMIENTOS_TMP
  for IT.LD_INT_MOVIMIENTOS_TMP;
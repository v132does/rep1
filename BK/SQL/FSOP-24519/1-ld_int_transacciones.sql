-- Create table
create table IT.LD_INT_TRANSACCIONES
(
  cod_transaccion  NUMBER(4) not null,
  cod_modulo       NUMBER(3) not null,
  cod_modalidad    NUMBER(3) not null,
  descripcion      VARCHAR2(60),
  cod_operacion    NUMBER(3),
  ve_cliente       VARCHAR2(1),
  tipo             VARCHAR2(1),
  est_informacion  VARCHAR2(1),
  fec_generacion   DATE,
  fec_proceso      DATE,
  usu_insercion    VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_insercion    DATE default SYSDATE not null,
  usu_modificacion VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_modificacion DATE default SYSDATE not null,
  ins_seprelad     VARCHAR2(10),
  ope_seprelad     VARCHAR2(10)
)
tablespace IT_DATA
  pctfree 10
  initrans 1
  maxtrans 255
  storage
  (
    initial 192K
    next 1M
    minextents 1
    maxextents unlimited
  );
-- Add comments to the table 
comment on table IT.LD_INT_TRANSACCIONES
  is 'Transacciones Padres.';
-- Add comments to the columns 
comment on column IT.LD_INT_TRANSACCIONES.cod_transaccion
  is 'Código de Transacción.';
comment on column IT.LD_INT_TRANSACCIONES.cod_modulo
  is 'Código de Módulo.';
comment on column IT.LD_INT_TRANSACCIONES.cod_modalidad
  is 'Código de Modalidad.';
comment on column IT.LD_INT_TRANSACCIONES.descripcion
  is 'Nombre de la Transacción.';
comment on column IT.LD_INT_TRANSACCIONES.cod_operacion
  is 'Tipo de Operación para CML';
comment on column IT.LD_INT_TRANSACCIONES.ve_cliente
  is 'Es una transacción utilizada para la consulta de movimientos del cliente?.';
comment on column IT.LD_INT_TRANSACCIONES.tipo
  is 'Tipo de Transacción. Define en qué forma afecta en la operación.';
comment on column IT.LD_INT_TRANSACCIONES.est_informacion
  is 'Estado de Información.';
comment on column IT.LD_INT_TRANSACCIONES.fec_generacion
  is 'Fecha de Generación.';
comment on column IT.LD_INT_TRANSACCIONES.fec_proceso
  is 'Fecha de Proceso.';
comment on column IT.LD_INT_TRANSACCIONES.usu_insercion
  is 'Usuario que realizó la inserción del registro.';
comment on column IT.LD_INT_TRANSACCIONES.fec_insercion
  is 'Fecha en que se insertó el registro.';
comment on column IT.LD_INT_TRANSACCIONES.usu_modificacion
  is 'Usuario que realizó la última modificación en el registro.';
comment on column IT.LD_INT_TRANSACCIONES.fec_modificacion
  is 'Fecha en que se realizó la última modificación en el registro.';
comment on column IT.LD_INT_TRANSACCIONES.ins_seprelad
  is 'Instrumento Seprelad';
comment on column IT.LD_INT_TRANSACCIONES.ope_seprelad
  is 'Operación Seprelad';
-- Create/Recreate primary, unique and foreign key constraints 
alter table IT.LD_INT_TRANSACCIONES
  add constraint PK_LD_INT_TRANSACCIONES primary key (COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
  using index 
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

-- Create the synonym 
create or replace public synonym LD_INT_TRANSACCIONES
  for IT.LD_INT_TRANSACCIONES;

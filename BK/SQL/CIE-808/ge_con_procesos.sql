-- Create table
create table IT.GE_CON_PROCESOS
( cod_control   NUMBER not null,
  descripcion   VARCHAR2(500),
  observacion   VARCHAR2(500),
  sql_control   CLOB,
  sql_correccion CLOB,
  prioridad       NUMBER(3)      NOT NULL,
  estado          VARCHAR2(1)    DEFAULT 'A' NOT NULL,
  accion_critica  VARCHAR2(1)    DEFAULT 'N' NOT NULL,
  tip_correccion  VARCHAR2(1),
  autocorregir    VARCHAR2(1)DEFAULT 'N' NOT NULL, 
  usu_insercion VARCHAR2(10) default SUBSTR(USER,1,10) not null,
  fec_insercion DATE default SYSDATE not null
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
comment on table IT.GE_CON_PROCESOS
  is 'Definicion de control log pre-cierre.';
comment on column IT.GE_CON_PROCESOS.cod_control
  is 'Codigo del control.';
comment on column IT.GE_CON_PROCESOS.descripcion
  is 'Descripcion del control.';
comment on column IT.GE_CON_PROCESOS.sql_control
  is 'Consulta para el control.';
comment on column IT.GE_CON_PROCESOS.sql_correccion
  is ' Sentencia DML. Si es NULL, es alerta manual.';
comment on column IT.GE_CON_PROCESOS.usu_insercion
  is 'Usuario que realizo la insercion del registro.';
comment on column IT.GE_CON_PROCESOS.fec_insercion
  is 'Fecha en que se inserto el registro.';
  comment on column IT.GE_CON_PROCESOS.tip_correccion
  is 'M si la correccion es masiva I si es individual.';

grant select, insert, update, delete, alter, debug, read on IT.GE_CON_PROCESOS to IT_TEMPORAL;

-- Grant/Revoke object privileges 
create or replace public synonym GE_CON_PROCESOS for IT.GE_CON_PROCESOS;
grant all on IT.GE_CON_PROCESOS to it_temporal;

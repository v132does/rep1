-- Create table
create table IT.TEMP_4
(
  cedula          VARCHAR2(15),
  cod_persona     VARCHAR2(10),
  cod_oficial     VARCHAR2(15),
  nro_cuenta      VARCHAR2(15),
  cod_oficina     NUMBER(3),
  nro_cuota       NUMBER(3),
  mto_interes     NUMBER(18,2),
  sal_interes     NUMBER(18,2),
  fec_vencimiento DATE,
  cod_modulo      VARCHAR2(3),
  cod_modalidad   VARCHAR2(3),
  cod_switch      NUMBER(7),
  comentario      VARCHAR2(1000)
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
-- Grant/Revoke object privileges 
grant select on IT.TEMP_4 to IT_CONSULTAS;
grant select, insert, update, delete on IT.TEMP_4 to IT_TEMPORAL;
create public synonym TEMP_4 for IT.TEMP_4;

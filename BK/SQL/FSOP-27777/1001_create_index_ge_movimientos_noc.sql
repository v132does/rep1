/*CONSTRAINT "FK_GMNOC_COD_MONEDA" FOREIGN KEY ("COD_MONEDA")
REFERENCES "IT"."BA_MONEDAS" ("COD_MONEDA") ENABLE,*/
create index IT.IN_GMNOC_COD_MONEDA on IT.GE_MOVIMIENTOS_NOC(COD_MONEDA) online
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
/*CONSTRAINT "FK_GMNOC_COD_OFICINA" FOREIGN KEY ("COD_OFICINA")
REFERENCES "IT"."BA_OFICINAS" ("COD_OFICINA") ENABLE,*/
create index IT.IN_GMNOC_COD_OFICINA on IT.GE_MOVIMIENTOS_NOC (COD_OFICINA) online
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
/*CONSTRAINT "FK_GMNOC_COD_OFI_ORIGEN" FOREIGN KEY ("COD_OFI_ORIGEN")
REFERENCES "IT"."BA_OFICINAS" ("COD_OFICINA") ENABLE,*/
create index IT.IN_GMNOC_COD_OFI_ORIGEN on IT.GE_MOVIMIENTOS_NOC (COD_OFI_ORIGEN) online
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
/*CONSTRAINT "FK_GMNOC_COD_PERSONA" FOREIGN KEY ("COD_PERSONA")
REFERENCES "IT"."BA_PERSONAS" ("COD_PERSONA") ENABLE,*/
create index IT.IN_GMNOC_COD_PERSONA on IT.GE_MOVIMIENTOS_NOC (COD_PERSONA) online
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
/*CONSTRAINT  FOREIGN KEY ("COD_USU_AUTORIZADOR")
REFERENCES "IT"."BA_USUARIOS" ("COD_USUARIO") ENABLE,*/
create index IT.IN_GMNOC_COD_USU_AUTORIZADOR on IT.GE_MOVIMIENTOS_NOC (COD_USU_AUTORIZADOR) online
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
/*CONSTRAINT  FOREIGN KEY ("COD_USU_REVERSION")
REFERENCES "IT"."BA_USUARIOS" ("COD_USUARIO") ENABLE,*/
create index IT.IN_GMNOC_COD_USU_REVERSION on IT.GE_MOVIMIENTOS_NOC (COD_USU_REVERSION) online
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
/*CONSTRAINT "FK_GMNOC_COD_RUBRO" FOREIGN KEY ("COD_RUBRO")
REFERENCES "IT"."CB_RUBROS" ("COD_RUBRO") ENABLE,*/
create index IT.IN_GMNOC_COD_RUBRO on IT.GE_MOVIMIENTOS_NOC (COD_RUBRO) online
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
/*CONSTRAINT "FK_GMNOC_NRO_CAJA" FOREIGN KEY ("NRO_CAJA")
REFERENCES "IT"."CJ_CAJAS" ("NRO_CAJA") ENABLE,*/
create index IT.IN_GMNOC_NRO_CAJA on IT.GE_MOVIMIENTOS_NOC (NRO_CAJA) online
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
/*CONSTRAINT "FK_GMNOC_COD_BANCO" FOREIGN KEY ("COD_BANCO")
REFERENCES "IT"."GE_BANCOS" ("COD_BANCO") ENABLE,*/
create index IT.IN_GMNOC_COD_BANCO on IT.GE_MOVIMIENTOS_NOC (COD_BANCO) online
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
/*CONSTRAINT "FK_GMNOC_COD_CAUSA" FOREIGN KEY ("COD_CAUSA")
REFERENCES "IT"."GE_CAUSALES" ("COD_CAUSA") ENABLE,*/
create index IT.IN_GMNOC_COD_CAUSA on IT.GE_MOVIMIENTOS_NOC (COD_CAUSA) online
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
/*CONSTRAINT "FK_GMNOC_COD_RETENCION" FOREIGN KEY ("COD_RETENCION")
REFERENCES "IT"."GE_RETENCIONES" ("COD_RETENCION") ENABLE,*/
create index IT.IN_GMNOC_COD_RETENCION on IT.GE_MOVIMIENTOS_NOC (COD_RETENCION) online
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
/*CONSTRAINT (COD_TRANSACCION,COD_MODULO,COD_MODALIDAD)
REFERENCES "IT"."GE_TRANSACCIONES" ("COD_TRANSACCION", "COD_MODULO", "COD_MODALIDAD") ENABLE,*/
create index IT.IN_GMNOC_COD_TRANSACCION on IT.GE_MOVIMIENTOS_NOC (COD_TRANSACCION,COD_MODULO,COD_MODALIDAD) online
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
/*CONSTRAINT  (COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE)
REFERENCES "IT"."GE_TRANSACCIONES" ("COD_TRANSACCION", "COD_MODULO","COD_MODALIDAD") ENABLE,*/
create index IT.IN_GMNOC_COD_TRA_PADRE on IT.GE_MOVIMIENTOS_NOC (COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE) online
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
/*CONSTRAINT "FK_GMNOC_COD_TASA" FOREIGN KEY ("COD_TASA")
REFERENCES "IT"."GE_TASAS" ("COD_TASA") ENABLE*/
create index IT.IN_GMNOC_COD_TASA on IT.GE_MOVIMIENTOS_NOC (COD_TASA) online
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

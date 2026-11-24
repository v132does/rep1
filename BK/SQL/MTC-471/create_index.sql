CREATE INDEX IT.IN_AMHIS_FEC_INS_NRO_CUENTA ON IT.AH_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_FEC_INS_NRO_CUENTA ON IT.GE_MOVIMIENTOS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_CMOHI_FEC_INS_NRO_CUENTA ON IT.CC_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_FMOHI_FEC_INS_NRO_CUENTA ON IT.AF_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_UMOHI_FEC_INS_NRO_CUENTA ON IT.BU_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_XMHIS_FEC_INS_NRO_CUENTA ON IT.CX_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_GMOHI_FEC_INS_NRO_CUENTA ON IT.GE_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_LMHIS_FEC_INS_NRO_CUENTA ON IT.LC_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_MMOHI_FEC_INS_NRO_CUENTA ON IT.MD_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_VMHIS_FEC_INS_NRO_CUENTA ON IT.OV_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_PMOHI_FEC_INS_NRO_CUENTA ON IT.PR_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_TMHIS_FEC_INS_NRO_CUENTA ON IT.TA_MOVIMIENTOS_HIS (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );

CREATE INDEX IT.IN_GMNOC_FEC_INS_NRO_CUENTA ON IT.GE_MOVIMIENTOS_NOC (FEC_INSERCION,NRO_CUENTA) online
 tablespace IT_IND
 pctfree 10
 initrans 10
 maxtrans 255
 storage
 (
  initial 64K
  next 1M
  minextents 1
  maxextents unlimited
 );
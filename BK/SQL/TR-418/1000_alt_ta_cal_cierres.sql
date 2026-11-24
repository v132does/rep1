alter table IT.TA_CAL_CIERRES
drop constraint UK_TA_CAL_CIERRES cascade;
  
alter table IT.TA_CAL_CIERRES
add constraint UK_TA_CAL_CIERRES unique (COD_ENT_PROCESADORA, COD_MODULO, COD_MODALIDAD, ANO, MES,COD_TIP_CIERRE)
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

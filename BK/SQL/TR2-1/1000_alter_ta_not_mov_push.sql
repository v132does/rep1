-- Create/Recreate primary, unique and foreign key constraints 
alter table IT.TA_NOT_MOV_PUSH
  drop constraint PK_TAMOVPUSH cascade;
alter table IT.TA_NOT_MOV_PUSH
  add constraint PK_TAMOVPUSH primary key (ID_TRANSACCION, ID_NOVEDAD)
  using index 
  tablespace IT_DATA
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

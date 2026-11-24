alter table IT.GE_AUT_PEDIDOS_TMP
      drop constraint PK_GE_AUT_PEDIDOS_TMP;
-- Create/Recreate primary, unique and foreign key constraints 
alter table IT.GE_AUT_PEDIDOS_TMP
  add constraint PK_GE_AUT_PEDIDOS_TMP primary key (COD_USUARIO, FECHA, HORA, TIP_AUTORIZACION)
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

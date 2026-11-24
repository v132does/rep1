CREATE INDEX IT.IN_TOTALES_DEUDOR_GE_CLI ON IT.GE_CLIENTES (
    NVL(tot_deu_sistema, 0),
    NVL(tot_deu_cod_sistema, 0),
    NVL(tot_deu_con_sistema, 0) ONLINE
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

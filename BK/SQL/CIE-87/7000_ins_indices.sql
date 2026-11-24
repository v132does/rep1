--elimninar indice
DROP INDEX IT.IN_GMRE_NRO_CUENTA;
-- Create/Recreate indexes 
create index IT.IN_GMRE_NRO_CUENTA on IT.GE_MOVIMIENTOS_RES (NRO_CUENTA, FEC_VALOR, REVERSADO, COD_TRANSACCION, COD_MONEDA, FEC_MAX_INSERCION,PROCESADO,RUTINA1,TIPO,AFECTA)
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

-- Create/Recreate indexes
create index IT.IDX_GTRAN_RUTINA1 on IT.GE_TRANSACCIONES (RUTINA1)
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




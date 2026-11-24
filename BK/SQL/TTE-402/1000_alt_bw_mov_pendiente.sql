
ALTER TABLE it.bw_mov_pendientes 
  ADD canal VARCHAR2(20);
  COMMENT ON COLUMN IT.bw_mov_pendientes.canal
  is 'Canal digital desde donde se genero el movimiento';

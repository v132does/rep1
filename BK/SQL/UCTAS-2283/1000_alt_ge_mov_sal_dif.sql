ALTER table it.ge_mov_sal_dif
ADD (fec_conciliacion DATE);

COMMENT ON COLUMN ge_mov_sal_dif.fec_conciliacion
  is 'Fecha de conciliacion del movimiento.';
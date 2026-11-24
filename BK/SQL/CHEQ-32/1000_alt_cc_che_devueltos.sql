alter table IT.CC_CHE_DEVUELTOS add fec_regularizacion date;

comment on column IT.CC_CHE_DEVUELTOS.fec_regularizacion
  is 'Fecha de regularización';
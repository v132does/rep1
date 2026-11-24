ALTER TABLE it.ah_cta_plazos
ADD ( fec_ult_provision DATE);


comment on column IT.AH_CTA_PLAZOS.fec_ult_provision
  is 'Fecha de última provisión.';

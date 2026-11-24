alter table IT.BW_PAG_SERVICIOS
add (COD_PAG_SERVICIO VARCHAR2(50));

comment on column BW_PAG_SERVICIOS.NRO_PAG_SERVICIO
  is 'Código de Pago Servicio Generado en Base Intermedia';

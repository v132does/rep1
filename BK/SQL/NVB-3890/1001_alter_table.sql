alter table IT.CB_RECIBOS_DET
   add cod_oficina  NUMBER(3);
   
comment on column IT.CB_RECIBOS_DET.cod_oficina
  is 'Código de Oficina';
  
alter table it.cb_recibos
   add tip_recibo VARCHAR2(1);

comment on column IT.CB_RECIBOS.tip_recibo
  is 'Tipo de Recibo (BA_COD_REFERENCIAS -> TIP_RECIBO)';

alter table it.cb_recibos  
  add nom_completo     VARCHAR2(120);
  
alter table it.cb_recibos
  add  nro_documento VARCHAR2(20);

comment on column IT.CB_RECIBOS.nro_documento
  is 'Nro. de Documento de la Persona';

comment on column IT.CB_RECIBOS.nom_completo
  is 'Nombre de la Persona';
  
alter table it.cb_recibos  
  add concepto         VARCHAR2(120);
  
comment on column IT.CB_RECIBOS.concepto
  is 'Concepto de Recibo';
  
alter table it.cb_recibos
   add mto_efectivo  NUMBER(18,2);
   
comment on column IT.CB_RECIBOS.mto_efectivo
  is 'Monto Efectivo';
     
alter table it.cb_recibos
   add  mto_retenido NUMBER(18,2);

comment on column IT.CB_RECIBOS.mto_retenido
  is 'Monto Retenido'

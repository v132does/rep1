
-- Add/modify columns 
alter table IT.MD_DOC_DETALLES_TMP add val_cap_presente NUMBER(18,2) default 0;
-- Add comments to the columns 
comment on column IT.MD_DOC_DETALLES_TMP.val_cap_presente
  is 'monto capital descontado';

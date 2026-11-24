
alter table it.md_doc_detalles add val_cap_presente number(18,2);
-- Add comments to the columns 
comment on column IT.MD_DOC_DETALLES.val_cap_presente
  is 'monto capital descontado';
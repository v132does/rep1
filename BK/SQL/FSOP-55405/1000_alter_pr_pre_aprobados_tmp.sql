alter table IT.PR_PRE_APROBADOS_TMP drop column cod_persona;

alter table IT.PR_PRE_APROBADOS_TMP add cod_tip_documento NUMBER(3);
alter table IT.PR_PRE_APROBADOS_TMP add nro_documento VARCHAR2(20);
-- Add comments to the columns 
comment on column IT.PR_PRE_APROBADOS_TMP.cod_tip_documento
  is 'Codigo del tipo de documento';
comment on column IT.PR_PRE_APROBADOS_TMP.nro_documento
  is 'Numero de documento de la persona';

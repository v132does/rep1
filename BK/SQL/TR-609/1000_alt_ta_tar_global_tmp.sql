-- Add/modify columns 
alter table IT.TA_TAR_GLOBAL_TMP add fec_insercion date default sysdate not null;
alter table IT.TA_TAR_GLOBAL_TMP add usu_insercion VARCHAR2(10) default SUBSTR(USER,1,10) not null;
alter table IT.TA_TAR_GLOBAL_TMP add fec_modificacion date default SYSDATE not null;
alter table IT.TA_TAR_GLOBAL_TMP add usu_modificacion varchar2(10) default SUBSTR(USER,1,10);
-- Add comments to the columns 
comment on column IT.TA_TAR_GLOBAL_TMP.fec_insercion
  is 'Fecha de insercion del registro';
comment on column IT.TA_TAR_GLOBAL_TMP.usu_insercion
  is 'Usuario que inserto el registro';
comment on column IT.TA_TAR_GLOBAL_TMP.fec_modificacion
  is 'Fecha de modificacion del registro';
comment on column IT.TA_TAR_GLOBAL_TMP.usu_modificacion
  is 'Usuario que modifico el registro';

-- Drop primary, unique and foreign key constraints 
alter table IT.CC_CHE_REMITIDOS
  drop constraint PK_CC_CHE_REMITIDOS cascade;
alter table IT.CC_CHE_REMITIDOS
  drop constraint FK_CCREM_NRO_CAJA;  
-- Add/modify columns 
alter table IT.CC_CHE_REMITIDOS modify nro_caja null; 
alter table IT.CC_CHE_REMITIDOS modify nro_lote null;  

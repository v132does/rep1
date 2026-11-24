create or replace public synonym GE_MOV_TRANSACCIONES_TMP
  for IT.GE_MOV_TRANSACCIONES_TMP;  
-- Grant/Revoke object privileges 
grant select on GE_MOV_TRANSACCIONES_TMP to IT_CONSULTAS;
grant select, insert, update, delete on GE_MOV_TRANSACCIONES_TMP to IT_TEMPORAL;
  
create or replace public synonym GE_MOV_CONTABLES_TMP
  for IT.GE_MOV_CONTABLES_TMP;  
-- Grant/Revoke object privileges 
grant select on GE_MOV_CONTABLES_TMP to IT_CONSULTAS;
grant select, insert, update, delete on GE_MOV_CONTABLES_TMP to IT_TEMPORAL;

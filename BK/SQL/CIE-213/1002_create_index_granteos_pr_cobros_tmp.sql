create or replace public synonym PR_COBROS_TMP for it.PR_COBROS_TMP;
-- Grant/Revoke object privileges 
grant select on IT.PR_COBROS_TMP to IT_CONSULTAS;
grant select, insert, update, delete on IT.PR_COBROS_TMP to IT_TEMPORAL;
grant select, insert, update, delete, references on IT.PR_COBROS_TMP to MI;
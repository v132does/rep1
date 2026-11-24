create or replace public synonym GE_CNS_DINAMICAS_TMP for it.GE_CNS_DINAMICAS_TMP;
-- Grant/Revoke object privileges 
grant select, insert, update, delete on it.GE_CNS_DINAMICAS_TMP to IT_CONSULTAS;
grant select on it.GE_CNS_DINAMICAS_TMP to IT_DYD;
grant select, insert, update, delete on it.GE_CNS_DINAMICAS_TMP to IT_TEMPORAL;
grant select, insert, update, delete, references on it.GE_CNS_DINAMICAS_TMP to MI;

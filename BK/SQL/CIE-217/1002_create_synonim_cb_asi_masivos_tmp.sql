create or replace public synonym CB_ASI_MASIVOS_TMP for it.CB_ASI_MASIVOS_TMP;
-- Grant/Revoke object privileges 
grant select, insert, update, delete on IT.CB_ASI_MASIVOS_TMP to IT_TEMPORAL;
grant select on it.CB_ASI_MASIVOS_TMP to IT_BTSOPORTE;
grant select on it.CB_ASI_MASIVOS_TMP to IT_CONSULTAS;
grant select, insert, update, delete on it.CB_ASI_MASIVOS_TMP to IT_TEMPORAL;
grant select, insert, update, delete on it.CB_ASI_MASIVOS_TMP to JLOPEZ;
grant select, insert, update, delete, references on it.CB_ASI_MASIVOS_TMP to MI;

create or replace public synonym SB_LCR_DEFINICIONES FOR IT.SB_LCR_DEFINICIONES;
create or replace public synonym SB_LCR_DATOS_TMP FOR IT.SB_LCR_DATOS_TMP;
create or replace public synonym SB_LCR_INF_FINAL FOR IT.SB_LCR_INF_FINAL;
create or replace public synonym SB_LCR_LIQ_INV_TMP FOR IT.SB_LCR_LIQ_INV_TMP;


grant select, insert, update, delete on IT.SB_LCR_DEFINICIONES to IT_TEMPORAL;
grant select, insert, update, delete on IT.SB_LCR_DATOS_TMP to IT_TEMPORAL;
grant select, insert, update, delete on IT.SB_LCR_INF_FINAL to IT_TEMPORAL;
grant select, insert, update, delete on IT.SB_LCR_LIQ_INV_TMP; to IT_TEMPORAL;

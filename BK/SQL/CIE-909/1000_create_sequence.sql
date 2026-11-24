create sequence IT.S_HOR_MOVCIERRE7
minvalue 1
maxvalue 999999999
start with 1
increment by 1
nocache
cycle;

create or replace public synonym S_HOR_MOVCIERRE7 for IT.S_HOR_MOVCIERRE7;
grant select on IT.S_HOR_MOVCIERRE7 to IT_TEMPORAL;

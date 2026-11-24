create sequence IT.S_HOR_MOVCIERRE9
minvalue 1
maxvalue 999999999
start with 1
increment by 1
nocache
cycle;

create or replace public synonym S_HOR_MOVCIERRE9 for IT.S_HOR_MOVCIERRE9;
grant select on IT.S_HOR_MOVCIERRE9 to IT_TEMPORAL;

create sequence IT.S_HOR_MOVCIERRE6
minvalue 1
maxvalue 999999999
start with 1
increment by 1
nocache
cycle;

create or replace public synonym S_HOR_MOVCIERRE6 for IT.S_HOR_MOVCIERRE6;
grant select on IT.S_HOR_MOVCIERRE to IT_TEMPORAL;

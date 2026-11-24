-- Usuario
-- Create sequence 
create sequence IT.S_SER_USER_AIRFLOW
minvalue 1
maxvalue 999999999
start with 1
increment by 1
nocache
cycle;
-- Create the synonym 
create or replace public synonym S_SER_USER_AIRFLOW
  for IT.S_SER_USER_AIRFLOW;

-- Grant/Revoke object privileges 
grant select on IT.S_SER_USER_AIRFLOW to IT_TEMPORAL;
-- Hora
-- Create sequence 
create sequence IT.S_NRO_HORA10
minvalue 1
maxvalue 999999999999999999999999999
start with 1
increment by 1
cache 20
cycle;
-- Create the synonym 
create or replace public synonym S_NRO_HORA10
  for IT.S_NRO_HORA10;
-- Grant/Revoke object privileges 
grant select on IT.S_NRO_HORA10 to IT_TEMPORAL;

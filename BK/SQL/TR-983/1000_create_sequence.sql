-- Create sequence 
create sequence IT.S_NRO_HORA0
minvalue 1
maxvalue 999999999999999999999999999
start with 1
increment by 1
nocache
cycle;

--Create Grant
grant select on IT.S_NRO_HORA0 to IT_TEMPORAL;

-- Create the synonym 
create or replace public synonym S_NRO_HORA0
  for IT.S_NRO_HORA0;

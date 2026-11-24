-- Create sequence 
create sequence IT.S_SER_USER_CREDCARDMS
minvalue 1
maxvalue 999999999
start with 1
increment by 1
nocache
cycle;

-- Create the synonym 
create or replace public synonym S_SER_USER_CREDCARDMS
  for IT.S_SER_USER_CREDCARDMS;

-- Grant/Revoke object privileges 
grant select on IT.S_SER_USER_CREDCARDMS to IT_TEMPORAL;

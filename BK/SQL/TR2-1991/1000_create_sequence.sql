-- Create sequence 
create sequence IT.S_SER_USER_GP_AUT
minvalue 1
maxvalue 999999999
start with 1
increment by 1
nocache
cycle;

-- Create the synonym 
create or replace public synonym S_SER_USER_GP_AUT
  for IT.S_SER_USER_GP_AUT;

-- Grant/Revoke object privileges 
grant select on IT.S_SER_USER_GP_AUT to IT_TEMPORAL;

create or replace public synonym GE_PER_WORKFLOW_TMP
  for IT.GE_PER_WORKFLOW_TMP;
  
grant select, update, delete, insert on IT.GE_PER_WORKFLOW_TMP to IT_TEMPORAL;

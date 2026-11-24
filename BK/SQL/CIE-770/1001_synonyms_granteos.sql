-- Grant/Revoke object privileges 
create or replace public synonym GE_INF_REMUNERACIONES for IT.GE_INF_REMUNERACIONES;
grant all on IT.GE_INF_REMUNERACIONES to it_temporal;
grant all on IT.GE_INF_REMUNERACIONES to IT_USEREM;

create public synonym PRG_GEN_INF_REMUNERACIONES for IT.PRG_GEN_INF_REMUNERACIONES;
grant all on PRG_GEN_INF_REMUNERACIONES  to it_temporal;


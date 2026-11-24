select s.* 
from ge_log_errores s 
where s.cod_programa in ('UPDATE_TD_UUID_ID','UPDATE_TC_UUID_ID')
and s.fec_insercion>=trunc(sysdate)
order by s.fec_insercion desc;

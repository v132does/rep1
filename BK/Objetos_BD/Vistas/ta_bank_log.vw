create or replace force view it.ta_bank_log as
select "MENSAJE","RESPUESTA","USU_INSERCION","FEC_INSERCION","ERROR","FEC_INICIO","REPROCESADO" from IT.log_atm at where TO_DATE(substr(at.mensaje, 182, 8),'DD/MM/YYYY') >= '01/07/2019';


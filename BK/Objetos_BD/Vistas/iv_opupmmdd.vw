create or replace force view it.iv_opupmmdd as
select '0007'|| --cd_agencia,
       rpad(a.cod_usuario,10,' ')||-- cd_operador,
       rpad(a.nombre,35,' ')||-- nb_nombre
       TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MM/DD/YYYY')||--fh_operacion
       '*'CADENA
from ba_usuarios a
where a.nombre not like '%FRON%'
;


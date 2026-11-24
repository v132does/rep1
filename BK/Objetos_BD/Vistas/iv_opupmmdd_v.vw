create or replace force view it.iv_opupmmdd_v as
select '0007'|| --cd_agencia,
       rpad(a.cod_usuario,10,' ')||-- cd_operador,
       rpad(a.nombre,35,' ')||-- nb_nombre
       '*'CADENA
from ba_usuarios a
where a.nombre not like '%FRON%'
and a.estado='A'
;


create or replace force view it.wv_circuitos_res as
select a.cod_tip_circuito, b.descripcion, floor(promedio) dias,
       floor(promedio*24)-(floor(promedio)*24) hs,
       mod(floor(promedio*24*60),60) min,
       mod(floor(promedio*24*60*60),60) seg,
       cantidad,
       pendientes
 from wf_tip_circuitos b, (
select cod_tip_circuito,(sum((nvl(fec_fin,sysdate)-fec_inicio))/count(*)) promedio, count(*) cantidad,
       sum(decode(estado,'E',1,0)) pendientes
from wf_circuitos
group by cod_tip_circuito
) a
where a.cod_tip_circuito = b.cod_tip_circuito;


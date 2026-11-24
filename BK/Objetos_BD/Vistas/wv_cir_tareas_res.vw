create or replace force view it.wv_cir_tareas_res as
select a.cod_tip_circuito, b.descripcion, a.cod_tip_tarea, c.descripcion des_cir_tarea,
       a.cod_gru_responsable, d.descripcion des_grupo,
       floor(promedio) dias,
       floor(promedio*24)-(floor(promedio)*24) hs,
       mod(floor(promedio*24*60),60) min,
       mod(floor(promedio*24*60*60),60) seg,
       cantidad,
       pendientes
 from wf_grupos d, wf_tip_circuitos b, wf_tip_cir_tareas c, (
select cod_tip_circuito, cod_tip_tarea, cod_gru_responsable, (sum((nvl(fec_finalizacion,sysdate)-fec_asignacion))/count(*)) promedio, count(*) cantidad,
       sum(decode(estado,'P',1,0)) pendientes
from wf_cir_tareas
where cod_tip_tarea > 0
group by cod_tip_circuito, cod_tip_tarea, cod_gru_responsable
) a
where a.cod_tip_circuito = b.cod_tip_circuito
and a.cod_tip_circuito = c.cod_tip_circuito
and a.cod_tip_tarea = c.cod_tip_tarea
and a.cod_gru_responsable = d.cod_grupo;


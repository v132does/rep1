create or replace force view it.mv_per_sec_espana as
select rpad(p.cod_persona,10,' ')||lpad(e.cod_actividad,3,0)||lpad(i.cod_act_int_padre,4,0)||lpad(c.cod_departamento,3,0) linea
from ba_personas p, ge_actividades e, ge_act_internas i, ge_clientes c
where p.cod_actividad = e.cod_actividad
and e.cod_act_interna = i.cod_act_interna
and p.cod_persona = c.cod_persona;


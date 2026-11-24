create or replace view it.barrios_bcp_bankitti as
select barban.cod_pais,barban.PAIS_DESCRIPCION,barban.cod_ciudad,barban.CUIDAD_DESCRIPCION,
barban.cod_barrio,barban.BARRIO_DESCRIPCION,barban.cod_departamento,barban.DEP_DESCRIPCION,
case when barbcp.cod_barrio_bcp is null then 1101001 ELSE barbcp.cod_barrio_bcp END as COD_BARRIO_BCP
from (
select bar.cod_pais,bpais.descripcion AS PAIS_DESCRIPCION,
bar.cod_ciudad,ciu.descripcion as CUIDAD_DESCRIPCION,
bar.cod_barrio,bar.descripcion AS BARRIO_DESCRIPCION,
ciu.cod_departamento,bdep.descripcion as DEP_DESCRIPCION
from IT.BA_BARRIOS bar, it.ba_paises bpais, it.ba_ciudades ciu, it.ba_departamentos bdep
where bar.cod_pais=bpais.cod_pais
and bar.cod_pais=ciu.cod_pais
and ciu.cod_pais=bpais.cod_pais
and bar.cod_ciudad=ciu.cod_ciudad
and ciu.cod_departamento=bdep.cod_departamento) barban
left join IT.BA_BARRIOS_BCP barbcp 
on barbcp.cod_pais=barban.cod_pais
and barbcp.cod_ciudad=barban.cod_ciudad
and barbcp.cod_departamento=barban.cod_departamento
and barbcp.cod_barrio=barban.cod_barrio;

CREATE PUBLIC SYNONYM barrios_bcp_bankitti FOR it.barrios_bcp_bankitti;
GRANT SELECT, INSERT, UPDATE, DELETE ON it.barrios_bcp_bankitti TO IT_TEMPORAL;
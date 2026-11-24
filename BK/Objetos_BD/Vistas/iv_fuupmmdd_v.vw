create or replace force view it.iv_fuupmmdd_v as
select '0007'||-- cd_agencia,
       rpad(pai_dtm.fu_for_cod_gestor(a.cod_usuario),8,' ') ||--cd_gestor,
       rpad(a.nombre,35,' ') ||--nb_fun_nombres,
       rpad('1',5,' ') ||--cd_pais_gestor,
       '*' CADENA
from ba_usuarios a
where a.oficial='S'
and a.estado='A'
;


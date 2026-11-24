create or replace force view it.iv_fuupmmdd as
select '0007'||-- cd_agencia,
       rpad(pai_dtm.fu_for_cod_gestor(a.cod_usuario),5,' ') ||--cd_gestor,
       rpad(a.nombre,35,' ') ||--nb_completo_funcio,
       rpad('1',5,' ') ||--cd_pais_gestor,
       TO_CHAR(pai_dtm_v.FU_OBT_fec_actual(3),'MM/DD/YYYY')||
       '*' CADENA
from ba_usuarios a
where a.oficial='S'
order by 1
;


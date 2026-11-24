create or replace force view it.iv_prupmmdd as
select '0007'||-- cd_agencia,
       rpad(to_char(a.cod_modalidad),5,' ')|| --cd_tp_cta
       rpad(a.descripcion,35,' ')|| --nb_tp_cte
      to_char(pai_dtm_v.FU_OBT_fec_actual(3),'MM/DD/YYYY')||--fh_operacion
      '*' CADENA

from ge_modalidades a
where  a.cod_modalidad in(31,32,33,41)
;


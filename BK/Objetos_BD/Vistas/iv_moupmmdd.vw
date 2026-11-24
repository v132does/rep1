create or replace force view it.iv_moupmmdd as
select to_char(pai_dtm_v.FU_OBT_fec_actual(3),'MM/DD/YYYY')||
       '0007'||-- cd_agencia,
       rpad(a.cod_moneda,4,' ')||-- cd_moneda,
       rpad(a.descripcion,30,' ')||-- nb_moneda
       '*'CADENA
from ba_monedas a
;


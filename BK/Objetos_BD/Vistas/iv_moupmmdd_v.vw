create or replace force view it.iv_moupmmdd_v as
select to_char(pai_dtm_t.fu_obt_fecha,'MM/DD/YYYY')||
       '0007'||-- cd_agencia,
       rpad(a.cod_moneda,4,' ')||-- cd_moneda,
       rpad(a.cod_moneda,3,' ')||-- nb_moneda
       '*'CADENA
from ba_monedas a
;


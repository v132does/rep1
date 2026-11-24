create or replace force view it.iv_uoupmmdd_v as
select '0007'||-- cd_agencia,
       lpad(to_char('0'),4,'0')||-- cd_unidad_organiz,
       lpad(to_char(a.cod_oficina),4,'0')||-- cd_sucursal,
       rpad(SUBSTR(a.descripcion,1,LENGTH(A.DESCRIPCION)-1),45,' ')||-- nb_sucursal
       '*'CADENA
from ba_oficinas a
;


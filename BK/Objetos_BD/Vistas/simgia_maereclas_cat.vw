create or replace force view it.simgia_maereclas_cat as
select
b.cod_persona as RCRIESGO,
nvl(to_char(b.fec_ult_clasif,'DDMMYYYY'),(select to_char(a.pri_dia_mes - 1, 'DDMMYYYY') from ge_calendarios a where a.cod_modulo = 1)) as  RCFECHA,
b.cat_subjetiva as RCRECLASIF
/*RCPONDERAC
RCSIT01
RCSIT02
RCSIT03
RCSIT04
RCSIT05
RCSIT06
RCSIT07
RCSIT08
RCSIT09
RCSIT10
RCOBS01
RCOBS02
RCRESPONSA
RCUSUARIO
RCTERMINAL*/
from ge_clientes b
where b.cat_subjetiva in (1,2,3,4,5,6)
and b.cat_riesgo <> b.cat_subjetiva;


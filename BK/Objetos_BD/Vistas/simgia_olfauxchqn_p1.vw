create or replace force view it.simgia_olfauxchqn_p1 as
select "CHQSUC","CHQCTA","CHQSUB","CHQSERIE","CHQDESDE","CHQHASTA","CHQFECHA","NRO_CUENTA","VCTA","COD_MONEDA","RNUM" from
/* p1 1 - 30 mil */
(select a.*, rownum rnum
from ( select * from SIMGIA_OLFAUXCHQN ) a
where rownum <= 30000 )
where rnum >= 1;


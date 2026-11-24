create or replace force view it.simgia_olfauxchqn_p3 as
select "CHQSUC","CHQCTA","CHQSUB","CHQSERIE","CHQDESDE","CHQHASTA","CHQFECHA","NRO_CUENTA","VCTA","COD_MONEDA","RNUM" from
/* p3 60001 - 1000 mil */
(select a.*, rownum rnum
from ( select * from SIMGIA_OLFAUXCHQN ) a
where rownum <= 1000000 )
where rnum >= 60001;


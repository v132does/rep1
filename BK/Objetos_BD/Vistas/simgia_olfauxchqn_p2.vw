create or replace force view it.simgia_olfauxchqn_p2 as
select "CHQSUC","CHQCTA","CHQSUB","CHQSERIE","CHQDESDE","CHQHASTA","CHQFECHA","NRO_CUENTA","VCTA","COD_MONEDA","RNUM" from
/* p2 30.001 - 60 mil */
(select a.*, rownum rnum
from ( select * from SIMGIA_OLFAUXCHQN ) a
where rownum <= 60000 )
where rnum >= 30001;


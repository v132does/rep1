create or replace force view it.simgia_arclinomi_p3 as
select "CLIENPAGN","CLIENCOBN","CLIENFUM","RNUM" from
/* p3 60001 - 1000 mil */
(select a.*, rownum rnum
from ( select * from SIMGIA_ARCLINOMI ) a
where rownum <= 1000000 )
where rnum >= 60001;


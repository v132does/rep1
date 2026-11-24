create or replace force view it.simgia_arclinomi_p1 as
select "CLIENPAGN","CLIENCOBN","CLIENFUM","RNUM" from
/* p1 1 - 30 mil */
(select a.*, rownum rnum
from ( select * from SIMGIA_ARCLINOMI ) a
where rownum <= 30000 )
where rnum >= 1;


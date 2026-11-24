create or replace force view it.simgia_arclinomi_p2 as
select "CLIENPAGN","CLIENCOBN","CLIENFUM","RNUM" from
/* p2 30.001 - 60 mil */
(select a.*, rownum rnum
from ( select * from SIMGIA_ARCLINOMI ) a
where rownum <= 60000 )
where rnum >= 30001;


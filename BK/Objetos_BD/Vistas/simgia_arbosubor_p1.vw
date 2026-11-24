create or replace force view it.simgia_arbosubor_p1 as
select "BSSERIE","BSNUMERO","BSCUPON","BSTITUR","BSSUC","BSNUMCLIEN","BSAGENTE","BSMONEDA","BSMONTO","BSFEMISI","BSVENCIM","BSTIPOT","BSTASA1","BSTASA2","BSTASA3","BSTASA4","BSLRM_LIB","BSFEINI","BSDEVENG","BSUSUARIO","BSFEREG","BSPIGNO","RNUM" from
/* p1 1 - 30 mil */
(select a.*, rownum rnum
from ( select * from SIMGIA_ARBOSUBOR ) a
where rownum <= 30000 )
where rnum >= 1;


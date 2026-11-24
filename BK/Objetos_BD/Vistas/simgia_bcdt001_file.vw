create or replace force view it.simgia_bcdt001_file as
select
lpad(nvl(t.numclien,0),6,0) ||
lpad(nvl(t.ncalifbcp,1),1,0) ||
lpad(t.nfecalif,8,0) linea
from simgia_bcdt001_cat t;


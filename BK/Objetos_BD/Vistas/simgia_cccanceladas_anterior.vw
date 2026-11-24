create or replace force view it.simgia_cccanceladas_anterior as
select "NSUC","NCTA","NSUB","CLIENTE","FECAN","MOTIVO","FECHA_HIS"
from simgia_cccanceladas_bkp a;


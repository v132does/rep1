create or replace force view it.simgia_previcar_file as
select lpad('0',2,0) ||
lpad('0',6,0) ||
lpad('0',12,0) ||
lpad(TO_CHAR(pag_cal.fu_obt_fec_actual(1),'DDMMYY'),6,0) ||
lpad('0',14,0) ||
lpad('0',1,0) ||
lpad('0',1,0) linea
from dual
union all
select
lpad(t.PCSUC,2,0) ||
lpad(t.PCRIESGO,6,0) ||
lpad(t.PCCUENTA,12,0) ||
lpad(t.PCPROPUE,6,0) ||
lpad(trunc(abs(t.PCMONTO)),12,0) || substr(rpad( (nvl(abs(PCMONTO),0)-trunc(nvl(abs(PCMONTO),0)) ),3,0),-2) ||
lpad(t.PCIND,1,0) ||
lpad(nvl(t.PCCLASE,1),1,0) linea
from simgia_previcar t;


create or replace force view it.simgia_maeicpc_f4_file as
select
lpad(t.riesgo,6,0) ||
lpad(t.vto,8,0) ||
lpad(t.docnro,6,0) ||
lpad(t.sucursal,2,0) ||
decode(abs(t.interes),t.interes, '0' , '-') ||
lpad(trunc(abs(t.interes)),10,0) /*|| '|'*/|| substr(rpad((nvl(abs(interes),0)-trunc(nvl(abs(interes),0))),3,0),-2)/* || '|'*/||
lpad(feini,8,0) ||
decode(abs(t.intdev),t.intdev, '0' , '-') || --decode(abs(t.intdev),t.intdev, '0' , '-') ||
lpad(trunc(abs(t.intdev)),10,0) || substr(rpad((nvl(abs(intdev),0)-trunc(nvl(abs(intdev),0))),3,0),-2) /*||'|'*/ ||
decode(abs(t.intnodev),t.intnodev, '0' , '-') ||
lpad(trunc(abs(t.intnodev)),10,0) || substr(rpad((nvl(abs(intnodev),0)-trunc(nvl(abs(intnodev),0))),3,0),-2) ||
lpad(t.fechcont,8,0) ||
lpad(t.periodo,2,0) ||
lpad(t.rubrocr,12,0) ||
lpad(t.inddocum,2,0) ||
lpad(t.ctaactivo,12,0) ||
lpad(t.ctaordact,12,0) ||
lpad(t.ctapasivo,12,0) ||
decode(abs(t.cobadl),t.cobadl, '0' , '-') ||
lpad(trunc(abs(t.cobadl)),10,0) || substr(rpad((nvl(abs(t.cobadl),0)-trunc(nvl(abs(t.cobadl),0))),3,0),-2) ||
lpad(t.propuesta,6,0) ||
decode(abs(t.devsusp),t.devsusp, '0' , '-') ||
lpad(trunc(abs(t.devsusp)),10,0) || substr(rpad((nvl(abs(t.devsusp),0)-trunc(nvl(abs(t.devsusp),0))),3,0),-2) ||
--lpad(t.filler,32,0) linea
lpad(t.rubro_susp,12,0) ||
lpad(t.filler,20,0) linea
from simgia_maeicpc_f4_bkp t
--where t.interes = 446.97
--where t.intdev < 0
--where t.intnodev < 0
;


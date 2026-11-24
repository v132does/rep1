create or replace force view it.simgia_maecartera_f4_file as
select
lpad(NURIES,6,0) ||
lpad(CONGRU,12,0) ||
lpad(VENCIM,8,0) ||
lpad(NUDOC,6,0) ||
lpad(TIPOD,2,0) ||
lpad(FECHAEMISI,6,0) ||
lpad(SUCURSALFU,2,0) ||
lpad(SUCURSALCU,11,0) ||
lpad(PROPUESTA,6,0) ||
--lpad(trunc(GUARANIES),12,0) || substr(rpad((nvl(GUARANIES,0)-trunc(nvl(GUARANIES,0))),3,0),-2) ||
decode(abs(GUARANIES),GUARANIES, '0' , '-') ||
lpad(trunc(abs(GUARANIES)),11,0) || substr(rpad( (nvl(abs(GUARANIES),0)-trunc(nvl(abs(GUARANIES),0)) ),3,0),-2) ||
lpad(trunc(CODTASA),2,0) || substr(rpad((nvl(CODTASA,0)-trunc(nvl(CODTASA,0))),3,0),-2) ||
--lpad(trunc(CONTRAVALO),12,0) /*|| '|'*/ ||substr( rpad((nvl(CONTRAVALO,0)-trunc(nvl(CONTRAVALO,0))),3,0),-2) || /*'|' || */
decode(abs(CONTRAVALO),CONTRAVALO, '0' , '-') ||
lpad(trunc(abs(CONTRAVALO)),11,0) || substr(rpad( (nvl(abs(CONTRAVALO),0)-trunc(nvl(abs(CONTRAVALO),0)) ),3,0),-2) ||
lpad(NROLIBRADO,6,0) ||
lpad(trunc(GASTOSGC),10,0) || substr(rpad((nvl(GASTOSGC,0)-trunc(nvl(GASTOSGC,0))),3,0),-2) ||
lpad(VCTOINT,6,0) ||
lpad(trunc(IADMONTODC),12,0) || substr(rpad((nvl(IADMONTODC,0)-trunc(nvl(IADMONTODC,0))),3,0),-2) ||
lpad(trunc(IADSALDOCP),12,0) || substr(rpad((nvl(IADSALDOCP,0)-trunc(nvl(IADSALDOCP,0))),3,0),-2) ||
lpad(IADMETODO,1,0) ||
lpad(IADFEINI,6,0) ||
lpad(IADDIAS,4,0) ||
decode(abs(IADINTERES),IADINTERES, '0' , '-') ||
lpad(trunc(abs(IADINTERES)),11,0) || substr(rpad( (nvl(abs(IADINTERES),0)-trunc(nvl(abs(IADINTERES),0)) ),3,0),-2) ||
decode(abs(IADADEV),IADADEV, '0' , '-') ||
lpad(trunc(abs(IADADEV)),11,0) || substr(rpad( (nvl(abs(IADADEV),0)-trunc(nvl(abs(IADADEV),0))),3,0),-2) ||
lpad(IADDIVISA,2,0) ||
lpad(IADNROCUO,2,0) ||
lpad(trunc(IADCODTASA),2,0) || substr(rpad((nvl(IADCODTASA,0)-trunc(nvl(IADCODTASA,0))),3,0),-2) ||
lpad(CTADOCACT,12,0) ||
lpad(CTADOCPAS,12,0) ||
decode(abs(CTANDOCACT),CTANDOCACT, '0' , '-') ||
lpad(trunc(abs(CTANDOCACT)),11,0) ||
lpad(CTANDOCORD,12,0) ||
lpad(CTANDOCORH,12,0) ||
--lpad(FILLER,25,0) linea
lpad(rubro_susp,12,0) ||
lpad(FILLER,13,0) linea
from simgia_maecartera_f4_bkp t
;


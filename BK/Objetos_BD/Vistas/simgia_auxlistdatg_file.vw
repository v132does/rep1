create or replace force view it.simgia_auxlistdatg_file as
select
lpad(t.ALCATEG,1,0) ||
lpad(t.ALCLASE,1,0) ||
lpad(t.ALRIESGO,6,0) ||
lpad(t.ALSUCURSAL,2,0) ||
lpad(t.ALTITULAR,40,' ') ||
decode(abs(t.ALRIETOT),t.ALRIETOT, '0' , '-') ||
lpad(trunc(abs(t.ALRIETOT)),13,0) ||
decode(abs(t.ALCUBIERTO),t.ALCUBIERTO, '0' , '-') ||
lpad(trunc(abs(t.ALCUBIERTO)),13,0) ||
lpad(t.ALINDICUB,1,0) ||
lpad(t.ALVMINIMO,8,0) ||
decode(abs(t.ALPREVI),t.ALPREVI, '0' , '-') ||
lpad(trunc(abs(t.ALPREVI)),11,0) ||
decode(abs(t.ALSOBREGI),t.ALSOBREGI, '0' , '-') ||
lpad(trunc(abs(t.ALSOBREGI)),13,0) ||
decode(abs(t.ALCONTING),t.ALCONTING, '0' , '-') ||
lpad(trunc(abs(t.ALCONTING)),13,0) ||
decode(abs(t.ALGESTION),t.ALGESTION, '0' , '-') ||
lpad(trunc(abs(t.ALGESTION)),13,0) ||
decode(abs(t.ALINTERES),t.ALINTERES, '0' , '-') ||
lpad(trunc(abs(t.ALINTERES)),13,0) ||
decode(abs(t.ALADEV),t.ALADEV, '0' , '-') ||
lpad(trunc(abs(t.ALADEV)),13,0) ||
decode(abs(t.ALVENCICO),t.ALVENCICO, '0' , '-') ||
lpad(trunc(abs(t.ALVENCICO)),13,0) linea
from simgia_auxlistdatg t;


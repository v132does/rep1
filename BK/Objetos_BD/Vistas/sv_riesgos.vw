create or replace force view it.sv_riesgos as
select '0' identificador, '5' tip_formulario, cuenta, tot_mon_local, tot_mon_extranjera, tot_equivalente
from
(
select substr(cuenta,1,3)||'00000000' cuenta,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_mon_local))) tot_mon_local,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_mon_extranjera))) tot_mon_extranjera,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_equivalente))) tot_equivalente
  from sb_riesgos
 where instr(substr(cuenta,4,2),'0') = 0
 group by substr(cuenta,1,3)
union
select substr(cuenta,1,4)||'0000000' cuenta,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_mon_local))) tot_mon_local,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_mon_extranjera))) tot_mon_extranjera,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_equivalente))) tot_equivalente
  from sb_riesgos
 where instr(substr(cuenta,4,2),'0') = 0
 group by substr(cuenta,1,4)
union
select substr(cuenta,1,3)||'0'||substr(cuenta,5,1)||'000000' cuenta,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_mon_local))) tot_mon_local,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_mon_extranjera))) tot_mon_extranjera,
       abs(sum((decode(substr(cuenta,4,1),'9',-1,'7',-1,1)*tot_equivalente))) tot_equivalente
  from sb_riesgos
 where instr(substr(cuenta,4,2),'0') = 0
 group by substr(cuenta,1,3)||'0'||substr(cuenta,5,1)
union
select cuenta,
       tot_mon_local,
       tot_mon_extranjera,
       tot_equivalente
  from sb_riesgos
 where instr(substr(cuenta,4,2),'0') = 0
)
order by 1;


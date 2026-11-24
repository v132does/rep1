create or replace procedure it.PRG_DEBCREIT_ACTUALIZADO( RESPUESTA OUT VARCHAR2)
as
BEGIN
   --select nvl((select 'S' from simgia_debcreit d where d.fec_migracion > (sysdate - interval '360' MINUTE) and rownum = 1), 'N') into RESPUESTA
   select nvl((select 'S' from simgia_debcreit d where d.fec_proceso = pag_cal.fu_obt_fec_actual(1)  and rownum = 1), 'N') into RESPUESTA
from dual;
   
END;
/


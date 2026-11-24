CREATE OR REPLACE PROCEDURE IT.PRB_ACT_CALENDARIO
 IS
BEGIN
   --- Cambiar fecha del modulo CONTABLE
   update ge_calendarios
   set fec_actual = fec_proxima
   where cod_modulo = 2;
END;
/


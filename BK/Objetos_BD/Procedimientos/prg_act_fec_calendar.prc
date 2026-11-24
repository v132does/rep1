CREATE OR REPLACE PROCEDURE IT.PRG_ACT_FEC_CALENDAR
 IS
v_fec_actual ge_calendarios.fec_actual%type;
BEGIN
   --- Cambiar fecha del modulo general
   update ge_calendarios
   set fec_actual = fec_proxima
   where cod_modulo = 1;
   --- Recuperar fecha de calendario del modulo general
   BEGIN
      select fec_actual into v_fec_actual
      from ge_calendarios
      where cod_modulo = 1;
   exception
      when no_data_found then
         raise_application_error(-20000,
         'No existe calendario para modulo 1');
   END;
   --- Actualizar fecha calendario de los demás modulos
   update ge_calendarios
   set fec_actual = v_fec_actual
--   where cod_modulo <> 1;
   where cod_modulo not in (1,2); -- Modificado por tys 17-05-2007
END;
/


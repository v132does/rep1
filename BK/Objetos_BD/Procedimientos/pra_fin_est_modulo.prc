CREATE OR REPLACE PROCEDURE IT.PRA_FIN_EST_MODULO
 IS
BEGIN
   UPDATE ba_modulos
   set estado = 4
   where cod_modulo = 3;
   if sql%notfound then
      raise_application_error(-20000,
      'Act. Modulo Ahorro a cerrado');
   end if;
END;
/


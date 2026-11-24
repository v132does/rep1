CREATE OR REPLACE PROCEDURE IT.PRP_FIN_EST_MODULO
 IS
BEGIN
   UPDATE ba_modulos
   set estado = 4
   where cod_modulo = 6;
   if sql%notfound then
      raise_application_error(-20000,
      'Act. Modulo Prestamos a cerrado');
   end if;
END;
/


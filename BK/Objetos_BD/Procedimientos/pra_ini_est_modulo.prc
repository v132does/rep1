CREATE OR REPLACE PROCEDURE IT.PRA_INI_EST_MODULO
 IS
v_estado ba_modulos.estado%type;
BEGIN
   Select estado
     into v_estado
     from ba_modulos
    where cod_modulo = 3;
   if nvl(v_estado,0)  not in (2,6,99) then
      raise_application_error(-20000,'Estado del Modulo de Ahorros incorrecto');
   end if;
   UPDATE ba_modulos
      set estado = 3
    where cod_modulo = 3;
   if sql%notfound then
      raise_application_error(-20000, 'Act. Modulo Ahorro a cerrado');
   end if;
END;
/


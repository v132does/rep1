CREATE OR REPLACE PROCEDURE IT.PRB_INI_EST_MODULO
 IS
v_estado ba_modulos.estado%type;
BEGIN
   Select estado
     into v_estado
     from ba_modulos
    where cod_modulo = 2;
   /*if nvl(v_estado,0)  not in (88) then
      raise_application_error(-20000,'Debe correr el proceso de Union y Validación de Asientos');
   end if;*/
   UPDATE ba_modulos
      set estado = 3
    where cod_modulo = 2;
   if sql%notfound then
      raise_application_error(-20000, 'Act. Modulo Contable a cerrado');
   end if;
END;
/


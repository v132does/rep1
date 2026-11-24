CREATE OR REPLACE PROCEDURE IT.PRB_ACT_EST_INI_MOD IS
  /* inicio contable. Cambio de estado del modulo */
BEGIN
   update ba_modulos
      set estado = 1
    where cod_modulo = 2
      and estado = 4;
   if sql%notfound then
      raise_application_error(-20000,'Estado incorrecto. Verifique el estado del Modulo Contable!!');
   end if;
END;
/


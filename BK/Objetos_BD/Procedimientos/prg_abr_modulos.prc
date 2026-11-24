CREATE OR REPLACE PROCEDURE IT.PRG_ABR_MODULOS
 IS
BEGIN
   update ba_modulos
      set estado = 2
    where cod_modulo <> 2;
END;
/


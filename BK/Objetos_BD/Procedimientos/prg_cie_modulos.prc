CREATE OR REPLACE PROCEDURE IT.PRG_CIE_MODULOS
 IS
BEGIN
   update ba_modulos
      set estado = 4
    where cod_modulo not in (3,2,9);
END;
/


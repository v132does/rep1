CREATE OR REPLACE PROCEDURE IT.PRB_ABR_CONTABILIDAD
 IS
BEGIN
   update ba_modulos
      set estado = 2
    where cod_modulo = 2;
END;
/


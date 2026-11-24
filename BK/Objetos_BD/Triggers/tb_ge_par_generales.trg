CREATE OR REPLACE TRIGGER IT.TB_GE_PAR_GENERALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_PAR_GENERALES
 FOR EACH ROW


DECLARE
   v_cantidad number(03);
BEGIN
   if inserting then
      select count(*)
      into v_cantidad
      from ge_par_generales;
      if v_cantidad >= 1 then
         raise_application_error(-20000,
         'Sólo puede insertar un registro de parámetro');
      end if;
   end if;
END;
/


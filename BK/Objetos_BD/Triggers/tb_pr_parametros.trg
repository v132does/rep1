CREATE OR REPLACE TRIGGER IT.TB_PR_PARAMETROS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_PARAMETROS
 FOR EACH ROW


DECLARE
       v_cantidad number(03);
BEGIN
   if inserting then
      select count(*)
      into v_cantidad
      from pr_parametros;
      if v_cantidad >= 1 then
         raise_application_error(-20000,
         'Sólo puede insertar un registro de Parámetros de Préstamos');
      end if;
   end if;
END;
/


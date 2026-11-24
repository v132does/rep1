CREATE OR REPLACE TRIGGER IT.TB_AH_CUPONES
 BEFORE DELETE OR INSERT OR UPDATE
 ON AH_CUPONES
 FOR EACH ROW


BEGIN
   if deleting then
      if :old.estado <> 'C' then
         raise_application_error(-20000,
         'No puede eliminar cupones emitidos');
      end if;
   end if;
END;
/


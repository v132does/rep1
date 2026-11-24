CREATE OR REPLACE TRIGGER IT.TB_IG_OFI_METAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON IG_OFI_METAS
 FOR EACH ROW
BEGIN
   if deleting or updating then
      if :old.liquidado = 'S' then
         raise_application_error(-20000,'No puede actualizar o eliminar registros liquidados');
      end if;
   end if;
END;
/


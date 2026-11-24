CREATE OR REPLACE TRIGGER IT.TB_GE_ENT_USUARIOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_ENT_USUARIOS
 FOR EACH ROW


BEGIN
   -- el usuario equivalente sólo puede ser de 4 caracteres
   if inserting or updating then
      if length(:new.cod_usu_ente) > 12 then
         raise_application_error(-20000,'Usuario equivalente en la procesadora no puede tener más de 4 caracteres.');
      end if;
   end if;
END;
/


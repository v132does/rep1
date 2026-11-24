CREATE OR REPLACE TRIGGER IT.TB_AP_GRUPOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_GRUPOS
 FOR EACH ROW


BEGIN
   if inserting then
      if :new.principal = 'S' then
         --Verifica si existe Grupo Principal
         pry_ver_gruprincipal;
      end if;
   end if;
END;
/


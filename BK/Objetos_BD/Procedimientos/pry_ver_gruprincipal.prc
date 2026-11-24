CREATE OR REPLACE PROCEDURE IT.PRY_VER_GRUPRINCIPAL
 IS

V_CANT NUMBER(10);
BEGIN
   select count(*)
   into v_cant
   from ap_grupos
   where principal = 'S';

   if v_cant >= 1 then
      raise_application_error (-20000,
      'No puede existir mas de un Grupo Principal' || ' - '|| sqlerrm);
   end if;
END;
/


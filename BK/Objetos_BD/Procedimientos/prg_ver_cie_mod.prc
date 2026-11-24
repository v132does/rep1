CREATE OR REPLACE PROCEDURE IT.PRG_VER_CIE_MOD
 IS
v_cantidad number(3);
BEGIN
   select count(*)
   into v_cantidad
   from ba_modulos
   where estado <> 4
   and cod_modulo not in (2,13); -- agregado AF
   if v_cantidad > 0 then
      raise_application_error(-20000,
      'Existen procesos sin cerrarse');
   end if;
END;
/


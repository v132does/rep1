CREATE OR REPLACE PROCEDURE IT.PRE_VER_FMT_TELEFONO
 (P_TELEFONO IN VARCHAR2
 )
 IS
BEGIN
   for i in 1..nvl(length(p_telefono),0) loop
      if instr('1234567890-/() ',substr(p_telefono,i,1)) = 0 then
      	 raise_application_error(-20000,
      	 'Solo puede ingresar Números, guiones o barras invertidas: Ejemplo: 1/2 o 1-2');
      end if;
   end loop;
END;
/


CREATE OR REPLACE PROCEDURE IT.PRG_VAL_PORCENTAJE(P_VALOR IN VARCHAR2)
 IS
begin
  If p_valor > 100 or p_valor < 0 then
    raise_application_error(-20000,'Debe ser entre 0 y 100');
  end if;
END;
/


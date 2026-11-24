CREATE OR REPLACE PROCEDURE IT.PRA_VER_EXO_ENCAJES
 (P_VALOR IN VARCHAR2
 )
 IS
begin
  If p_valor not in ('S','N') then
    raise_application_error(-20000,'Valor incorrecto, Debe ser S o N');
  end if;
END;
/


CREATE OR REPLACE PROCEDURE IT.PRC_VER_CAT_CORRESPONSAL
 (P_VALOR IN VARCHAR2
 )
 IS
begin
  If p_valor not in ('1','2','3','4') then
    raise_application_error(-20000,'Valor Incorrecto, Debe ser de 1 a 4');
  end if;
END;
/


CREATE OR REPLACE PROCEDURE IT.PRA_VER_CDA_SERIE
 (P_VALOR IN VARCHAR2
 )
 IS
begin
  If length(p_valor) > 2 then
    raise_application_error(-20000,'Longitud del Valor no puede ser mayor a 2 letras');
  elsif upper(p_valor)<> p_valor  then  
    raise_application_error(-20000,'Valor debe ser ingresado en mayúscula');
  elsif p_valor not between 'A' and 'ZZ' then  
    raise_application_error(-20000,'Valor incorrecto. Verifique el Dato');
  end if;
END;
/


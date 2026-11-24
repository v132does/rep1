CREATE OR REPLACE PROCEDURE IT.PRA_VER_MTO_EXO_DEP_ME
 (P_VALOR IN VARCHAR2
 )
 IS
 -- VALIDADOR DEL PARAMETRO DINAMICO DE MONTO EXONERADO EN DEPOSITOS M/E
begin
  If p_valor is null then
    raise_application_error(-20000,'Monto debe ser ingresado.');
  End if;  
  If fue_val_es_numerico(p_valor) = 'N' then
    raise_application_error(-20000,'El dato debe ser numerico');
  End if;  
END;
/


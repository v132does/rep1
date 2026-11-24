CREATE OR REPLACE PROCEDURE IT.PRG_VAL_CAJ_PRO_CONECTOR
 (P_VALOR IN VARCHAR2
 )
 IS
 -- VALIDADOR DEL PARAMETRO DINAMICO PROCESADOR DE CONECTOR PARA SISTEMA PRODEP
begin
  If p_valor is null then
     raise_application_error(-20000,'Valor debe ser ingresado.');
  End if;
  If fue_obt_des_refcodes('CAJ_PRO_CONECTOR', p_valor) = 'Referencia  no registrada en el Sistema' then
     raise_application_error(-20000, 'El dato ingresado no corresponde a un valor válido para el tipo de Conector.');
  End if;
END;
/


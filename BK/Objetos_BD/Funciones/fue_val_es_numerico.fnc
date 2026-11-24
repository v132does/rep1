CREATE OR REPLACE FUNCTION IT.FUE_VAL_ES_NUMERICO
 (P_VALOR IN VARCHAR2
 )
 RETURN varchar2
 IS
 --Creado por : Julio Leguizamon
 --Fecha 			: 07/02/2005
 --Objetivo		: devolver si el parametro recibido es de tipo numerico
 v_numero  number(18,2);
 v_result  varchar2(1);
begin
	 v_result	:= 'N';
   v_numero := to_number(p_valor);
	 v_result	:= 'S';
	 return v_result;

	exception
   when others then
	 	 return v_result;
End;
/


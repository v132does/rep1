CREATE OR REPLACE FUNCTION IT.FUL_OBT_DEC_MASCARA
(p_cantidad in number)
/*obtener la máscara para la cantidad de decimales recibida*/
RETURN VARCHAR2 IS
	v_decimales varchar2(10);
BEGIN
 if p_cantidad > 0 then
   v_decimales := 'D';
   for i in 1..p_cantidad loop
     v_decimales := v_decimales||'9';
   end loop;
 end if;
 return v_decimales;
END;
/


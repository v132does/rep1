CREATE OR REPLACE FUNCTION IT.fug_obt_mas_tarjeta
 (P_VALOR IN VARCHAR2
 )
 RETURN varchar2
 IS
 v_result  varchar2(30);
begin

   v_result := rpad(substr(substr(p_valor,-16),1,4),12,'*')||substr(substr(p_valor,-16),-4);
   return v_result;

  exception
   when others then
     return v_result;
End;
/


CREATE OR REPLACE FUNCTION IT.FUH_OBT_HORA_GMT_ACTUAL
 (P_HORA OUT date
 )
 RETURN VARCHAR2
 IS
begin
    select (sysdate+((1/24)*4)) into p_hora from dual;
    return p_hora;
end;
/


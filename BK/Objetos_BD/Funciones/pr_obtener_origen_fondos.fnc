CREATE OR REPLACE FUNCTION IT."PR_OBTENER_ORIGEN_FONDOS" (p_afd varchar2, p_divisa varchar2)
return number
is
begin



       if(p_divisa = 0) then
           return 1;
       end if;

       if(p_divisa = 5) then
          return 2;
       end if;

       return null;
end;
/


create or replace function it.fug_eli_car_especiales (p_campo in varchar2) return varchar2 is
  v_campo varchar2(1000):=p_campo;
begin
   v_campo := REPLACE(v_campo, ';', ',');
   v_campo := REPLACE(v_campo, '|', '');
   v_campo := REPLACE(v_campo, '"', '');
   v_campo := REPLACE(v_campo, chr(9), '');
   v_campo := REPLACE(v_campo, chr(10), '');
   v_campo := REPLACE(v_campo, chr(13), '');
   return v_campo;
end;
/


create or replace function it.fug_obt_est_modalidad(
p_cod_modulo in number, p_cod_modalidad in number) 
return VARCHAR2 is 
v_estado varchar2(1) :=   'A';
begin
  -- se permite operar con límite a todas las modalidades
   /*if p_cod_modulo in (6,8) and p_cod_modalidad IN 
      (63,66,68,69,82,89,601,602,603,604,605,607,609,610,611,612,614,615,
      616,617,618,619,621,623,624,625,626,60,67,606,620,622) then
      v_estado := 'I';
   end if;*/
   return v_estado;
end;
/


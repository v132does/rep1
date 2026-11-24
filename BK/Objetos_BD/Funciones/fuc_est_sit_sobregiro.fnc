create or replace function it.fuc_est_sit_sobregiro (
   p_dia_mora  number)
   return Char is
   v_categoria varchar(35);
begin
	---
    if p_dia_mora <= 60 or p_dia_mora is null then
       v_categoria := '1';
    elsif p_dia_mora > 60  and p_dia_mora <= 90  then
       v_categoria := '2';
    elsif p_dia_mora > 90  and p_dia_mora <= 180 then
       v_categoria := '3';
    elsif p_dia_mora > 180 then
       v_categoria := '4';
    end if;
	---
    return v_categoria;
exception
    when no_data_found then
       return null;
END;
/


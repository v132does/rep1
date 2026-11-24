create or replace function it.fut_est_sit_tarjetas(
   p_dia_mora   number,
   p_cat_riesgo ge_clientes.cat_riesgo%type)
   return Char
is
   v_categoria varchar(35);
   v_atraso number(10);
begin
  ---
  v_atraso := p_dia_mora;
  ---
  if v_atraso <= 60 or v_atraso is null then 
     v_categoria := '1';
  elsif v_atraso > 60  and v_atraso <= 90  then 
     v_categoria := '2';                      
  elsif v_atraso > 90  and v_atraso <= 180 then 
     v_categoria := '3';                       
  elsif v_atraso > 180 then 
     v_categoria := '4'; 
  end if;    
  ---
  return v_categoria;
exception
    when no_data_found then
       return p_cat_riesgo;
  
end;
/


create or replace function it.fug_obt_num_ascii(p_cadena in varchar2) return number is
  v_can_caracteres number(10);
  v_indice number(10);
  v_val_ascii number(10);
begin
  v_can_caracteres := length(p_cadena);
  v_val_ascii := 0;
  for v_indice in 1..v_can_caracteres loop
      v_val_ascii := nvl(v_val_ascii,0) + ascii(substr(p_cadena,v_indice,1));
  end loop;
  return v_val_ascii;
end;
/


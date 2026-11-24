create or replace function it.fug_obt_tex_numero(p_texto in varchar2) return number is
  --Funcion que convierte cualquier cadena de texto a numerico--
  v_pos_separador number(4);
  v_par_entera varchar2(1000);
  v_par_decimal varchar2(1000);
  v_par_dec_div number(10);
  v_numero number(22,6);
  v_rev_numerica number(2);
begin
  v_numero := 0;
  select instr(p_texto,',')
    into v_pos_separador
    from dual;
  if v_pos_separador = 0 then
     select instr(p_texto,'.')
       into v_pos_separador
       from dual;
  end if;
  if v_pos_separador = 0 and length(p_texto) > 0 then
     if fug_val_es_numerico(p_texto) = 'S' then
        v_numero := to_number(p_texto);
     else
        v_numero := 0;
     end if;
  elsif v_pos_separador = 0 and length(p_texto) = 0 then
     v_numero := 0;
  else
     v_par_entera := trim(substr(p_texto,1,v_pos_separador-1));
     v_par_decimal := trim(substr(p_texto,v_pos_separador+1));
     v_rev_numerica := 0;
     if fug_val_es_numerico(v_par_entera) = 'S' then
        v_rev_numerica := v_rev_numerica + 1;
     end if;
     if fug_val_es_numerico(v_par_decimal) = 'S' then
        v_rev_numerica := v_rev_numerica + 1;
     end if;
     if v_rev_numerica < 2 then
        v_numero := 0;
     else
        v_par_dec_div := power(10,length(v_par_decimal));
        v_numero := nvl(to_number(v_par_entera),0) + nvl(to_number(v_par_decimal),0) / v_par_dec_div;
     end if;
  end if;
  return v_numero;
exception
  when others then
    raise_application_error(-20000,'Error en fug_obt_tex_numero: '||sqlerrm);
end;
/


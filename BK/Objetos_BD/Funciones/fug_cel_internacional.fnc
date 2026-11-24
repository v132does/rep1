create or replace function it.fug_cel_internacional(p_numero IN VARCHAR2) return varchar2 is
  v_resultado VARCHAR2(21) := substr(p_numero, 1, 21);
  v_prefijo   NUMBER := -1;
begin
  -- longitud maxima soportada = 15
  if length(nvl(v_resultado, '222222222222222222228')) > 20 then
    return p_numero;
  end if;
  
  v_resultado := replace(v_resultado, '-', '');
  v_resultado := replace(v_resultado, '+', '');
  v_resultado := replace(v_resultado, '(', '');
  v_resultado := replace(v_resultado, ')', '');
  v_resultado := replace(v_resultado, ' ', '');
  -- se buscan los posibles prefijos
  -- 59509 = 5
  -- 5959 = 4
  -- 09 = 2
  -- 9 = 1
  if substr(v_resultado, 1, 5) in ('59509') then
     v_prefijo := 5;
  elsif substr(v_resultado, 1, 4) in ('5959') then
     v_prefijo := 4;
  elsif substr(v_resultado, 1, 2) in ('09') then
     v_prefijo := 2;
  elsif substr(v_resultado, 1, 1) in ('9') then
     v_prefijo := 1;
  end if;
  -- se busca que el siguiente numero luego del prefijo sea 6, 7, 8, 9
  if v_prefijo > 0 and substr(v_resultado, v_prefijo + 1, 1) in ('6','7','8','9') then
    -- numero valido
    v_resultado := '09' || substr(v_resultado, v_prefijo + 1);
  else 
    v_resultado := p_numero;
  end if;
  
  return v_resultado;
exception
  when others then
    return p_numero;
end;
/


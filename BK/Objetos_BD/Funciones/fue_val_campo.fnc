CREATE OR REPLACE FUNCTION IT.FUE_VAL_CAMPO
 ( P_CAMPO IN VARCHAR2
  ,P_TIPO IN VARCHAR2 --N=Numerico, L=Solo Letras, A=Alfanumerico,
                      --F-Fecha, H-Hora, %-Tasa, C-Codigo, M-Solo Mayusc., $-Monto
  ,P_LONGITUD IN NUMBER DEFAULT 200
 )
 RETURN VARCHAR2
 IS

V_CONTADOR NUMBER(2) := 0;
v_caracter VARCHAR2(1);
v_respuesta varchar2(1);
v_fecha date;
begin
IF length(P_CAMPO) > P_LONGITUD THEN
   return 'N';
ELSE
  v_respuesta := 'S';
  if p_tipo = 'A' then -- alfanumerico, acepta todo
      v_respuesta := 'S';
  elsif p_tipo = 'M' then -- mayusculas
      if upper(p_campo) <> p_campo then
         v_respuesta := 'N';
      end if;
  elsif  p_tipo = 'F' then -- fecha
      begin
          v_fecha := to_date(replace(p_campo,'.','/'),'dd/mm/yyyy');
      exception
         when others then
            v_respuesta := 'N';
      end;
  elsif p_tipo in ('$','%','C') then  -- monto, tasa, codigo
      if fue_val_es_numerico(p_campo) = 'N' then
         v_respuesta := 'N';
      else
         if p_tipo = '%' and to_number(p_campo) not between 0 and 100 then
            v_respuesta := 'N';
         elsif p_tipo = 'C' and to_number(p_campo) not between 0 and 999 then
            v_respuesta := 'N';
         end if;

      end if;
  elsif p_tipo = 'H' then  -- hora
      begin
          v_fecha := to_date('01/01/1990 '||replace(p_campo,'.',':'),'dd/mm/yyyy hh24:mi:ss');
      exception
         when others then
            v_respuesta := 'N';
      end;
null;
  else
      For c in 1..length(P_CAMPO) loop
        v_contador  := v_contador + 1;
        v_caracter := substr(P_CAMPO,v_contador,1);
        If p_tipo = 'L' then
          If upper(v_caracter) not in ('A','B','C','D','E','F','G','H','I','J','K',
                                   'L','M','N','Ñ','O','P','Q','R','S','T','U','V','W','X','Y','Z') then
            v_respuesta := 'N';
          End if;
        elsif p_tipo = 'N' then
          If v_caracter not in ('0','1','2','3','4','5','6','7','8','9') then
            v_respuesta := 'N';
          End if;
        end if;
      End loop;
  end if;
  return v_respuesta;
END IF;
End;
/


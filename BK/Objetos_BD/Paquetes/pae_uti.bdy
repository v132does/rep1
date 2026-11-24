CREATE OR REPLACE PACKAGE BODY IT.PAE_UTI IS
function FU_OBT_POSICION(p_cadena in varchar2,
                         p_valor in varchar2)
  return number
  is
  v_cadena varchar2(1000):= ','||trim(TRANSLATE(p_cadena,'ºª!@#$%^&*()_+{}´¨[]-:"''<>./?~`;\|',',,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,'))||',';
  v_valor  varchar2(1000):= ','||trim(TRANSLATE(p_valor,'ºª!@#$%^&*()_+{}´¨[]-:"''<>./?~`;\|',',,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,'))||',';
  v_pos    number := 0;
  begin
    v_pos := instr(v_cadena,v_valor);
    if v_pos > 0 then
      --existe, se verifica cuantas comas hay.
      v_cadena := substr(v_cadena,1,v_pos);
      v_pos := 0;
      for i in 1..length(v_cadena) loop
        if substr(v_cadena,i,1)=',' then
           v_pos := v_pos+1;
        end if;
      end loop;
    end if;
    return v_pos;
end;
function FU_OBT_VALOR(p_registro in varchar2,
                      p_nro_secuencia in number)
  return varchar2
  is
  v_pos_inicial number :=0;
  v_pos_final   number :=0;
  v_longitud    number :=0;
  v_retorno    varchar2(1000);
  v_registro   varchar2(4000):=trim(TRANSLATE(p_registro,'ºª!@#$%^&*()_+{}´¨[]-:"''<>./?~`;\|',',,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,'));

  begin
    if p_nro_secuencia = 1 then
       v_pos_inicial := 1;
    else
       v_pos_inicial := instr(v_registro,',',1,p_nro_secuencia-1)+1;
    end if;
    v_pos_final := instr(v_registro,',',1,p_nro_secuencia);
    if v_pos_inicial = 0 then
       raise_application_error(-20000,'No se encuentra el separador nro. '||p_nro_secuencia||' en '||p_registro);
    elsif v_pos_final = 0 then
       v_pos_final := length(v_registro||',');
    end if;
    v_longitud := v_pos_final - v_pos_inicial;
    v_retorno  := substr(v_registro,v_pos_inicial,v_longitud);
    return v_retorno;
  end;
function fu_por_igu_textos(p_texto1 in varchar2,
                           p_texto2 in varchar2,
                           p_may_sensible in varchar2,
                           p_modo in varchar2)
return number is
  v_por_igualdad number := 0;
  v_texto1 varchar2(1000) := replace(trim(p_texto1),'  ',' ');
  v_texto2 varchar2(1000) := replace(trim(p_texto2),'  ',' ');
  v_longitud number := 0;
  v_i2 number := 1;
  v_cantidad number := 0;
  v_modo varchar2(1);
begin
   if length(v_texto1) <= 0 or length(v_texto2) <= 0 then
      return 0;
   end if;
   v_modo := nvl(upper(p_modo),'C');
   -- 'C' se compara hasta el final del texto mas largo
   -- 'P' se compara hasta el final del texto mas corto
   if  v_modo = 'C' then
       if length(v_texto1) < length(v_texto2) then
          v_texto1 := v_texto2;
          v_texto2 := replace(trim(p_texto1),'  ',' ');
       end if;
       v_longitud := length(v_texto1);
   else
       if length(v_texto1) < length(v_texto2) then
          v_longitud := length(v_texto1);
       else
          v_longitud := length(v_texto2);

       end if;
   end if;

   -- si no importa diferencias de mayusculas
   if upper(p_may_sensible) = 'N' then
      v_texto1 := upper(v_texto1);
      v_texto2 := upper(v_texto2);
   end if;
   v_i2 := 1;
   for i in 1..v_longitud loop
     if substr(v_texto1,i,1) = substr(v_texto2,v_i2,1) then
        v_cantidad := v_cantidad + 1;
        v_i2 := v_i2 + 1;
     elsif substr(v_texto1,i+1,1) = substr(v_texto2,v_i2+1,1) then
        v_i2 := v_i2 + 1;
     elsif substr(v_texto1,i,1) = substr(v_texto2,v_i2+1,1) then
        v_i2 := v_i2  + 2;
        v_cantidad := v_cantidad + 1;
     end if;
   end loop;
   v_por_igualdad := round((v_cantidad / v_longitud * 100), 2);
   return v_por_igualdad;
end;


function FU_OBT_MONTO(p_dato in varchar2)
return varchar2
is
  v_retorno    varchar2(1000);
  v_longitud number(20,2);
  begin
    v_longitud:= to_number(p_dato)/100;
    v_retorno:= v_longitud;
  return v_retorno;
  end;

-- Para obtener valor especificando el separador de campos --
function FU_OBT_VALOR( p_registro in varchar2,
                       p_nro_secuencia in number,
                       p_separador in varchar2 )
return varchar2
is
v_pos_inicial number :=0;
v_pos_final   number :=0;
v_longitud    number :=0;
v_retorno    varchar2(1000);
--v_registro   varchar2(4000):=trim(TRANSLATE(p_registro,'ºª!@#$%^&*()_+{}´¨[]-:"''<>./?~`;\|',',,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,'));

begin
  if p_nro_secuencia = 1 then
     v_pos_inicial := 1;
  else
     v_pos_inicial := instr(p_registro,p_separador,1,p_nro_secuencia-1)+1;
  end if;
  v_pos_final := instr(p_registro,p_separador,1,p_nro_secuencia);
  if v_pos_inicial = 0 then
     raise_application_error(-20000,'No se encuentra el separador nro. '||p_nro_secuencia||' en '||p_registro);
  elsif v_pos_final = 0 then
     v_pos_final := length(p_registro||',');
  end if;
  v_longitud := v_pos_final - v_pos_inicial;
  v_retorno  := substr(p_registro,v_pos_inicial,v_longitud);
  return v_retorno;
end;
    
	
END PAE_UTI;
/


create or replace function it.fua_obt_nom_cda
(denominacion  in varchar2, ---- TEXTO QUE SE IMPRIMIRA
 linea in varchar2,    --- LINEA EN LA QUE SE IMPRIMIRA
 cant_linea in number --- SE REFIERE A LA UBICACION DE FIN LINEA 1/ INICIO DEMÁS LINEAS
)
return varchar2 is
v_retorno varchar2(1000) := null;
v_retorno_1 varchar2(1000) := null;
v_total number;
v_total_1 number;
v_tot number;
ultimo_espacio number;
v_can_linea number:=0;
begin
  ---- obtengo el total general
     begin
     select length(denominacion)
       into v_total
       from dual;
     end;
     ---- debe controlar como termina----
     ---busca el ultimo CARACTER PARA SEPARAR DEL TOTAL GENERAL
     begin
     select INSTR(denominacion,' ', -1, 1)
       into ultimo_espacio
       from dual;
     end;

     ------ controla la posición del último espacio en blanco con el total de la cadena permitida en la linea 1
     if ultimo_espacio > cant_linea and linea = 1 then
       ---- busca el último espacio dentro de la cantidad asignada 88
       begin
         select substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'), 'ñ', 'n'), linea, cant_linea)
           into v_retorno
           from dual;
       end;
             ---busca el ultimo espacio dentro de lo asignado en cant_linea
        begin
         select INSTR(v_retorno,' ', -1, 1)
           into ultimo_espacio
           from dual;
        end;

       begin
         select substr(v_retorno, 1, ultimo_espacio)
           into v_retorno
           from dual;
       end;

     elsif ultimo_espacio > cant_linea and linea != 1 then
       --realizar el mismo proceso de la linea 1 para saber hasta cuantos caracteres extrajo para la primera linea y 
       --apartir de ahi extraer para la siguiente linea.
       ---- busca el último espacio dentro de la cantidad asignada 88
       v_can_linea := cant_linea - 1;
       begin
         select substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'),
                               'ñ',
                               'n'),
                       1,
                       v_can_linea)
           into v_retorno_1
           from dual;
       end;
       ---busca el ultimo espacio dentro de lo asignado en cant_linea
       begin
         select INSTR(v_retorno_1, ' ', -1, 1)
           into ultimo_espacio
           from dual;
       end;
       if v_total > linea then
         begin
           select substr(v_retorno_1, 1, ultimo_espacio)
             into v_retorno_1
             from dual;
         end;
       
         begin
           select length(v_retorno_1) into v_total_1 from dual;
         end;
         if linea != 1 then
           v_retorno := substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'),
                                       'ñ',
                                       'n'),
                               1, linea-1);
           ultimo_espacio := INSTR(v_retorno, ' ', -1, 1);
           v_retorno := substr(denominacion, ultimo_espacio, length(denominacion) );
           return TRIM(v_retorno);
         end if;
       else
         return v_retorno;
       end if;
       if v_total <= cant_linea then
        v_retorno:=substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'), 'ñ', 'n'), 1, cant_linea);
        
       /*else
        v_retorno:=substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'), 'ñ', 'n'), 1, ultimo_espacio);*/
       end if;
     elsif ultimo_espacio <= cant_linea and linea != 1 then
       begin
         v_can_linea := cant_linea - 1;
         select substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'),
                               'ñ',
                               'n'),
                       1,
                       v_can_linea)
           into v_retorno_1
           from dual;
       end;
       IF v_retorno_1 <> denominacion then
         ---busca el ultimo espacio dentro de lo asignado en cant_linea
         begin
           select INSTR(v_retorno_1, ' ', -1, 1)
             into ultimo_espacio
             from dual;
         end;
         if v_total > linea then
           begin
             select substr(v_retorno_1, 1, ultimo_espacio)
               into v_retorno_1
               from dual;
           end;
         
           begin
             select length(v_retorno_1) into v_total_1 from dual;
           end;
           if linea != 1 then

             v_retorno := substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'),
                                         'ñ',
                                         'n'),
                                 v_total_1,
                                 cant_linea);
             return TRIM(v_retorno)||'.--';
           end if;
         else
           return v_retorno||'.--';
         end if;
       else
         return null;
       end if;
     elsif ultimo_espacio <= cant_linea and linea = 1 and v_total <= cant_linea then 
       begin
         select substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'), 'ñ', 'n'), linea, cant_linea)
           into v_retorno
           from dual;
       end;
     elsif ultimo_espacio <= cant_linea and linea = 1 and v_total > cant_linea then
          select substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'),
                                'ñ',
                                'n'),
                        linea,
                        ultimo_espacio-1)
            into v_retorno
            from dual;
     end if;

     if linea = 1 then
         if (v_total + 3) <= cant_linea then
            return v_retorno||'.--';
         else
           if (v_total + 3)= (cant_linea+1) then
               return v_retorno||'.-';
           elsif (v_total + 3 ) = (cant_linea+2) then
             return v_retorno||'.';
           else
             return v_retorno;
           end if;
         end if;

     /*else
       v_tot:=0;
       ---debe recuperar donde se quedó anteriormente
         ---- obtengo el 2do total
        begin
         select length(v_retorno)
           into v_tot
           from dual;
        end;
        begin
         select substr(REPLACE(REPLACE(TRIM(denominacion), 'Ñ', 'N'), 'ñ', 'n'), v_tot+1, v_total)
           into v_retorno
           from dual;
        end;
          if v_retorno is not null then
            return v_retorno||'.--';
          else
            return null;
          end if;*/
     end if;

end;
/


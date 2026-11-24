create or replace function it.fug_obt_nombre(ptexto in varchar2, posicion in number) return varchar2 is
  -- Permite desmembrar el nombre y apellido de una persona
  Result varchar2(60);
  xx number;
  xxant number;
  texto varchar2(100) := upper(trim(ptexto));
begin
  if posicion = 1 then -- primer nombre o apellido
     xx := instr(texto, ' ');
     if xx > 0 then
        if xx < 5 then -- es un dato muy corto busco sino hay mas espacios
           xxant := xx;
           xx := instr(texto, ' ',xx+1);
           if xx = 0 then
              xx := xxant;
           end if;
        end if;      
        Result := trim(substr(texto,1,xx));
     else
        Result := texto;   
     end if;   
  else -- segundo nombre o apellido
     xx := instr(texto, ' ');
     if xx > 0 and xx < length(texto) then
        if xx < 5 then -- es un dato muy corto busco sino hay mas espacios
           xxant := xx;
           xx := instr(texto, ' ',xx+1);
           if xx = 0 then
              xx := xxant;
           end if;
        end if;       
        Result := trim(substr(texto,xx));
     else
        Result := null;   
     end if;
  end if;
  return(Result);
end fug_obt_nombre;
/


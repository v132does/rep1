create or replace function it.FUG_EMP_ENMASCARA(p_cod_identificador varchar2,
                                             p_campo             varchar2) return varchar2 is
  --p_cod_identificador pueede contener cod_persona o cod_usuario                                             
  v_campo  varchar2(32767);
  v_cod_persona ba_personas.cod_persona%type;
begin
  -- Verifica que el codigo de persona exista en el sistema
  begin
    select p.cod_persona 
      into v_cod_persona
      from ba_personas p 
     where p.cod_persona = p_cod_identificador;
  exception
    when others then
      v_cod_persona := null;
  end;
  -- En el caso de no encontrar la persona, procede a buscar 
  -- el codigo de persona del codigo de usuario recibido
  if v_cod_persona is null then
    begin
      select u.cod_persona
        into v_cod_persona
        from ba_usuarios u
       where u.cod_usuario = p_cod_identificador;
    exception
      when others then
        v_cod_persona := null;
    end;
  end if;
  
  if v_cod_persona is not null then
    if (fug_es_empleado(v_cod_persona) = 'S') then
      begin
        -- Remplaza todos los caracteres por asteriscos
        select translate(lower(p_campo),c.caracteres, rpad('*', length(c.caracteres), '*'))
          into v_campo
          from dual,
               --Convierte los numeros obtenidos por su equivalente en ASCII menos el 32 que equivale a un espacio " "
              (select ','||replace(ASCII(chr(l)), ',', '') caracteres               
                 --Trae numeros del 1 al 256 menos el 32 
                 from (select level l from dual where level != 32 connect by level <= 256)) c;
      exception
        when others then
          v_campo := '**********';
      end;
    else
      v_campo := p_campo;
    end if;
  else
    v_campo := p_campo;
  end if;
  
  return v_campo;
end fug_emp_enmascara;
/


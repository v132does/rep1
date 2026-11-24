CREATE OR REPLACE FUNCTION IT.fug_val_car_invalidos(p_tipo   IN varchar2,
                                                 p_cadena in out varchar2)
  RETURN VARCHAR2 IS

  v_cadena VARCHAR2(500) := p_cadena;
Begin
  if p_tipo = 'T' then
    -- Tarjeta de CrИdito
    select translate(v_cadena,
                     'аимсзщдкожэюхлры,+╢~-|╟╨╙╛!"#$%&/()=?║©*╗{}^`[]_:;><гц%@''',
                     'AEIOUYAEIOUAEIOU')
      into v_cadena
      from dual;
  elsif p_tipo = 'C' then
    -- Tarjeta de CrИdito
    select translate(v_cadena,
                     'аимсзщдкожэюхлры+╢~|╟╨╙╛!"#$%&()=?║©*╗{}^`[]_:;><гц%@''',
                     'AEIOUYAEIOUAEIOU')
      into v_cadena
      from dual;
  elsif p_tipo = 'D' then
    -- Tarjeta de DИbito
    select translate(v_cadena,
                     'яаимсзщдкожэюхлры+╢~-|╟╛!"#$%&/()=?║©*╗{}^`[]_:;,><гц',
                     'NAEIOUYAEIOUAEIOU')
      into v_cadena
      from dual;
  else
    select translate(v_cadena,
                     'аимсзщдкожэюхлры+╢~|╟╨╙╛!"#$%&()=?║©*╗{}^`[]_:;><гц%@'''||chr(10),
                     'AEIOUYAEIOUAEIOU')
      into v_cadena
      from dual;
  end if;
  return(v_cadena);
exception
  when no_data_found then
    raise_application_error(-20000,
                            'Error al validar Caracteres InvАlidos.' ||
                            sqlerrm);
End;
/


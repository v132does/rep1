CREATE OR REPLACE FUNCTION IT.fug_eli_car_invalidos(p_cadena in varchar2)
  RETURN VARCHAR2 IS

  v_cadena VARCHAR2(1000) := p_cadena;
Begin
    select translate(v_cadena,
                     nvl(fug_obt_pardinamico('ELI_CAR_INVALIDOS_E'), 'ÑÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙñáéíóúýäëïöüàèìòù+´~-|°¬!"#$%&/\(???¡¿*¨{}^`[]_:;,><ÇÃ'),
                     nvl(fug_obt_pardinamico('ELI_CAR_INVALIDOS_S'), 'NAEIOUYAEIOUAEIOUnaeiouyaeiouaeiou'))
      into v_cadena
      from dual;
      return(v_cadena);
exception
  when no_data_found then
    raise_application_error(-20000,
                            'Error al validar Caracteres Invalidos.' ||
                            sqlerrm);
End;
/


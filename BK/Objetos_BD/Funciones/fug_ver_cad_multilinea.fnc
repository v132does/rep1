CREATE OR REPLACE FUNCTION IT.fug_ver_cad_multilinea( p_cadena             in varchar2,
                                                   p_separador          in varchar2 default null,
                                                   p_can_max_lineas     in number default null,
                                                   p_can_max_caracteres in number default null
                                                 ) return varchar2
IS
  /*
  || Convierte una cadena de caracteres en líneas mediante su separador.
  || Limpia filas en blanco innecesarias.
  || Verifica la cantidad máxima de líneas y caracteres por línea que debe tener.
  */

  v_cadena    varchar2(4000) := null;
  v_texto     varchar2(4000) := replace(p_cadena,chr(13));
  v_separador varchar2(2)    := nvl(replace(p_separador,chr(13)),chr(10));
  v_can_filas number         := 0;

  cursor c_cur_lineas is
    SELECT column_value filas
      FROM TABLE( fug_obt_tab_registro( v_texto, v_separador ) )
     WHERE column_value is not null; -- Se excluye filas en blanco innecesarias.
BEGIN
  if p_cadena is null then
     raise_application_error(-20000, 'Cadena no puede ser nulo');
  end if;
  if v_separador is null then
     raise_application_error(-20001, 'Separador no puede ser nulo');
  end if;
  if p_can_max_lineas <= 0 then
     raise_application_error(-20002, 'Cant. máx. de líneas debe ser mayor a 0');
  end if;
  if p_can_max_caracteres <= 0 then
     raise_application_error(-20003, 'Cant. máx. de caracteres por línea debe ser mayor a 0');
  end if;

  -- Si el texto comienza con el caracter igual al duplicado, se excluye.
  for c in c_cur_lineas loop
    v_can_filas := v_can_filas + 1;
    if v_can_filas > p_can_max_lineas then
       raise_application_error(-20004, 'Cant. máx. de líneas permitidas es '||p_can_max_lineas);
    end if;
    if nvl(length(c.filas),0) > p_can_max_caracteres then
       raise_application_error(-20005, 'Cant. máx. de caracteres por línea permitidos es '||p_can_max_caracteres);
    end if;
    if v_cadena is null then
       v_cadena := c.filas;
    else
       v_cadena := substr( v_cadena || nvl(v_separador,chr(10)) || c.filas, 1, 4000 );
    end if;

  end loop;

  return substr(v_cadena,1, 4000);

exception
   when others then
      if sqlcode <= -20000  then
         raise;
      else
         raise_application_error(-20099,'FUG_VER_CAD_MULTILINEA: '||sqlerrm);
      end if;
end fug_ver_cad_multilinea;
/


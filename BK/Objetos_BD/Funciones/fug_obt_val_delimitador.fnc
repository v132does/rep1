create or replace function it.fug_obt_val_delimitador(p_cadena      in varchar2,
                                        p_delimitador in varchar2,
                                        p_posicion    in number) return varchar2 is
  v_retorno varchar2(200);
begin
  select linea
    into v_retorno
    from ( select rownum nro_linea,
                  column_value linea
             from table(fug_obt_tab_registro(p_cadena, p_delimitador))
            where column_value is not null )
    where nro_linea = p_posicion;
  return v_retorno;
exception
  when others then
     return p_cadena;
end fug_obt_val_delimitador;
/


create or replace function it.fug_obt_usu_apr_linea(p_nro_linea in pr_lineas.nro_linea%type)
  return varchar2 is
  v_cod_usu_aprobador ba_usuarios.cod_usuario%type;
Begin
  --Buscar el Py Autorizador Historico
  select l.usu_insercion
    into v_cod_usu_aprobador
    from pr_lineas_his l
   where l.nro_linea = p_nro_linea
     and l.estado = 'A'
     and l.fec_insercion = (select max(h.fec_insercion)
                              from pr_lineas_his h
                             where h.nro_linea = l.nro_linea
                               AND h.estado = 'A');
  if v_cod_usu_aprobador is null then
    select a.cod_usuario
      into v_cod_usu_aprobador
      from pr_lin_vin_productos_his a
     where a.nro_linea = p_nro_linea
       and a.fecha = (select max(fecha)
                        from pr_lin_vin_productos_his h
                       where h.nro_linea = a.nro_linea)
       and rownum = 1;
    if v_cod_usu_aprobador is null then
      select l.usu_insercion
        into v_cod_usu_aprobador
        from pr_lineas l
       where l.nro_linea = p_nro_linea
         and l.estado = 'A'
         and l.fec_insercion = (select max(h.fec_insercion)
                                  from pr_lineas h
                                 where h.nro_linea = l.nro_linea
                                   and h.estado = 'A');
    end if;
  end if;

  return v_cod_usu_aprobador;
exception
  when no_data_found then
    return NULL;
  when too_many_rows then
    return NULL;
end;
/


create or replace procedure it.prf_act_articulos(
  p_cod_articulo in af_articulos.cod_articulo%type)
is
  v_can_total  af_articulos.can_total%type;
begin
  --- Valido existencia total
  begin
     select nvl(a.can_total,0)
     into   v_can_total
     from   af_articulos a
     where  a.cod_articulo  = p_cod_articulo;
  exception
     when no_data_found then
          v_can_total := 0;
     when others then
          raise_application_error(-20000,
          'Error al consultar Artículos. '||sqlerrm);
  end;

  if nvl(v_can_total,0) <= 0 then
     raise_application_error(-20000,
     'El Artículo ' || p_cod_articulo || ' no posee existencia actualmente');
  end if;

  --- Actualizo el artículo
  update af_articulos a
  set    a.can_total     = a.can_total - 1
  where  a.cod_articulo  = p_cod_articulo;
  if sql%notfound then
     raise_application_error(-20000,
     'El Artículo no fue actualizado');
  end if;
end;
/


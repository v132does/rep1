CREATE OR REPLACE FUNCTION IT.fuw_obt_cotizacion
 (p_cod_moneda in ba_monedas.cod_moneda%type,
  p_tipo       in varchar2,  -- C-COMPRA o V-VENTA
  p_fec_actual date
 )
 return number
 is

v_cotizacion ge_cotizaciones.val_conversion%type;
begin
   select decode(p_tipo,'C',val_com_electronica,'V',val_ven_electronica,null)
     into  v_cotizacion
     from  ge_cotizaciones a
     where  fecha  = (select max(fecha)
                        from ge_cotizaciones
                       where cod_moneda = p_cod_moneda
                         and fecha <= p_fec_actual)
      and  cod_moneda = p_cod_moneda;
   return v_cotizacion;
exception
   when no_data_found then
      return null;
   when others then
      raise_application_error(-20000,sqlerrm||'error. al buscar cotizacion de venta ');
end;
/


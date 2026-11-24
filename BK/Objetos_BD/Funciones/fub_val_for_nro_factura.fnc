create or replace function it.fub_val_for_nro_factura(p_nro_factura in varchar2)
  return varchar2 is
  v_mensaje varchar2(300);
  
begin
  begin    
    if length(p_nro_factura) > 15 then
      v_mensaje := 'Numero de Factura no puede superar 15 dígitos';
    elsif instr(p_nro_factura,' ') > 0 THEN
      v_mensaje := 'El nro. de factura no puede contener espacios';
    elsif fue_val_es_numerico(replace(p_nro_factura, '-', '')) = 'N' THEN
      v_mensaje := 'Numero de Factura no puede contener valores no numericos';
    elsif p_nro_factura not like '___-___-_______' then
      v_mensaje := 'Numero de Factura debe tener el formato: 999-999-9999999';
    elsif to_number(substr(p_nro_factura, 1, 3)) <= 0 then
      v_mensaje := 'Los primeros dígitos del Numero de Factura debe ser mayor a cero';
    elsif to_number(substr(p_nro_factura, 5, 3)) <= 0 then
      v_mensaje := 'El punto de expedición del Numero de Factura debe ser mayor a cero';
    elsif to_number(substr(p_nro_factura, 9)) <= 0 then
      v_mensaje := 'El numero secuencial del Numero de Factura debe ser mayor a cero';
    end if;
  exception
    when others then
      v_mensaje := 'Error en formato de Numero de Factura. ' || substr(sqlerrm, 1, 290);
  end;
  return v_mensaje;
end;
/


create or replace function it.FUG_OBT_NRO_VIVIENDA(p_nro_vivienda in ba_direcciones.numero%TYPE) return number IS
v_nro_casa number(10);
--Función que devuelve el número de la vivienda, si dicho número contiene letras 
--dispara una excepción que devuelve el número 0
BEGIN
  begin
    v_nro_casa := to_number(p_nro_vivienda) + 0;
    return to_number(p_nro_vivienda);
  exception
    when others then
      return 0;
  end;
END;
/


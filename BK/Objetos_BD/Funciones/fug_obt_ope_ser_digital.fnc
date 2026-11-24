create or replace function it.fug_obt_ope_ser_digital -- Funcion de busqueda de servicio digital en una transferencia
   (p_nro_operacion in varchar2) -- Recibe el nro de operacion
    return varchar2 is        -- Devuelve S (si) o N (no) o X (vacio en caso de operaciones anteriores)
    Result varchar2(3);
    Var1 varchar2 (3);
begin
  -- Busca la operacion para consultar si corresponde a un Servicio Digital
    select case
    when (select a.ind_ser_digital from lc_ope_pendientes a where a.nro_operacion = p_nro_operacion) = 'S' then 'S'
    when (select a.ind_ser_digital from lc_ope_pendientes a where a.nro_operacion = p_nro_operacion) = 'N' then 'N'
    when (select a.ind_ser_digital from lc_ope_pen_cambios a where a.nro_operacion = p_nro_operacion
          and a.ind_ser_digital = 'S') = 'S' then 'S'
    when (select a.ind_ser_digital from lc_ope_pen_cambios a where a.nro_operacion = p_nro_operacion
          and a.ind_ser_digital = 'S') = 'N' then 'N'
    when (select x.cod_transaccion from ge_movimientos x where x.nro_documento = p_nro_operacion
          and x.cod_transaccion in (9611,9612) and rownum=1) is not null then 'S'
    when (select x.cod_transaccion from ge_movimientos x where x.nro_documento = p_nro_operacion
          and x.cod_transaccion in (9611,9612) and rownum=1) is null then 'N'
    END Valor
    INTO Var1 from dual;
  If Var1 not in ('S','N') then
     Var1 := 'X';
  End if;
 Result := Var1;
 return(Result);

exception
  when no_data_found then
     raise_application_error(-20000,'Error al consultar la operacion : '||p_nro_operacion||'-'||sqlerrm);
  when others then
     raise_application_error(-20000,'Error en fug_obt_ope_ser_digital : '||p_nro_operacion||'-'||sqlerrm);
end fug_obt_ope_ser_digital;
/


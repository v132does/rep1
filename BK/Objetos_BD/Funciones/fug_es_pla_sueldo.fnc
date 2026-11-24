CREATE OR REPLACE FUNCTION IT.fug_es_pla_sueldo
( p_nro_cuenta    GE_CUENTAS.NRO_CUENTA%TYPE,
  p_cod_modalidad GE_TRANSACCIONES.COD_TRANSACCION%TYPE default null )
  RETURN VARCHAR2 IS
  v_es_plan_sueldo VARCHAR2(1) := 'N';
BEGIN
  if nvl(p_cod_modalidad,0) in (31, 41) then
    if p_cod_modalidad = 31 then --ahorros vistas
      select 'S'
        into v_es_plan_sueldo
        from ah_cta_vistas
       where cod_ente is not null
         and nro_cuenta = p_nro_cuenta;
    else --ctas ctes
      select 'S'
        into v_es_plan_sueldo
        from cc_cta_corrientes
       where cod_ente is not null
         and nro_cuenta = p_nro_cuenta;
    end if;
  elsif p_cod_modalidad is null then --sin modalidad
    begin
      select 'S'
        into v_es_plan_sueldo
        from ah_cta_vistas
       where cod_ente is not null
         and nro_cuenta = p_nro_cuenta;
       return v_es_plan_sueldo;
    exception
      when no_data_found then
        select 'S'
          into v_es_plan_sueldo
          from cc_cta_corrientes
         where cod_ente is not null
           and nro_cuenta = p_nro_cuenta;
      when others then
        return 'N';
    end;
   else
     return 'N';
   end if;

 return v_es_plan_sueldo;
EXCEPTION
 when no_data_found then
   return 'N';
 when others then
   RAISE_APPLICATION_ERROR( -20000, 'FUG_ES_PLA_SUELDO '||P_NRO_CUENTA||'-'|| sqlerrm );
END;
/


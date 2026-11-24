create or replace function it.fug_obt_dat_operaciones(p_nro_cuenta in ge_cuentas.nro_cuenta%type,
                                                   p_tipo       in char)
  return varchar2 is
  v_cod_modulo ge_cuentas.cod_modulo%type;
  v_fecha    date ;
  v_return   varchar2(50) := '';
begin
  -- Extrae el Módulo --
  Select cod_modulo
    into v_cod_modulo
    from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
  if p_tipo = 'F' then
      if v_cod_modulo = 6 then
        -- Préstamos --
        Select p.fec_inicio
          into v_fecha
          from pr_cta_prestamos p
         where nro_cuenta = p_nro_cuenta;
      elsif v_cod_modulo = 3 then
        -- Caja de Ahorro --
        Select a.fec_apertura
          into v_fecha
          from ah_cta_vistas a
         where a.nro_cuenta = p_nro_cuenta;
      elsif v_cod_modulo = 4 then
        -- Cuenta Corriente --
        Select c.fec_apertura
          into v_fecha
          from cc_cta_corrientes c
         where c.nro_cuenta = p_nro_cuenta;
      elsif v_cod_modulo = 5 then
        -- Tarjeta --
        Select t.fec_apertura
          into v_fecha
          from ta_cta_tarjetas t
         where t.nro_cuenta = p_nro_cuenta;
      elsif v_cod_modulo = 8 then
        -- Importación/Exportación --
        Select max(i.fec_solicitud)
          into v_fecha
          from cx_cta_importaciones i
         where i.nro_cuenta = p_nro_cuenta;
        if v_fecha is null then
          Select max(i.fec_solicitud)
            into v_fecha
            from cx_cta_exportaciones i
           where i.nro_cuenta = p_nro_cuenta;
        end if;
		--- P/ QUERY 10 ---
        if v_fecha is null then
          Select max(i.fec_solicitud)
            into v_fecha
            from cx_fianzas i
           where i.nro_cuenta = p_nro_cuenta;
        end if;
      elsif v_cod_modulo = 10 then
        -- Fianzas --
        Select f.fec_inicio
          into v_fecha
          from md_cta_documentos f --- P/ QUERY 10 ---
         where f.nro_cuenta = p_nro_cuenta;
      elsif v_cod_modulo = 15 then
        -- Operaciones Vencidas --
        select o.fec_apertura
          into v_fecha
          from ov_cta_vencidas o
         WHERE o.nro_cuenta = p_nro_cuenta;
      end if;
      v_return := to_char(v_fecha,'dd/mm/yyyy');
  end if;
  return nvl(v_return, '');
exception
  when others then
    return '';
end;
/


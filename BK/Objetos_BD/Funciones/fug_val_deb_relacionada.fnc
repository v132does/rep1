CREATE OR REPLACE FUNCTION IT.fug_val_deb_relacionada(P_NRO_CUENTA IN VARCHAR2)
  RETURN VARCHAR2 is
  cursor cuenta is
      select 'S'
        from pr_cta_prestamos b
       where b.nro_cta_debito = p_nro_cuenta
       and b.estado != 'N'  -- Préstamos no CANCELADOS
    union
      select 'S'
        from pr_solicitudes s
       where s.nro_cta_debito = p_nro_cuenta
       and s.estado in ('L','S')  -- (S)olicitada y Pendiente (L)iquidacion
       and s.deb_automatico = 'S'
    union
      select 'S'
        from ta_cta_tarjetas
       where nro_cta_debito = p_nro_cuenta
           and estado != 'C'  -- Tarjetas no Canceladas
    union
      select 'S'
        from cs_contratos c
       where c.nro_cta_debito = p_nro_cuenta
       and c.estado not in ('C','R') -- (C)ancelados y (R)echazados
    union
      select 'S'
        from ah_cta_certificados a
       where a.nro_cta_credito = p_nro_cuenta
         and a.estado not in ('T','C'); -- (T)otalmente Pagada y (C)ancelada
  v_existe varchar2(01) := 'N';
begin
    open cuenta;
    fetch cuenta into v_existe;
    close cuenta;
    return v_existe;
exception
  when others then
    raise_application_error(-20002, 'Error al buscar Debitos Automaticos ' || sqlerrm);
end;
/


create or replace function it.fug_obt_ctas_activas(p_nro_cuenta in varchar2)
  return varchar2 is
  v_return varchar2(150);
begin
  -- Busca si el producto que se le pasa (p_nro_cuenta) se movió en los últimos 6 meses --
  Select max(conteo)
     into v_return
    from ( -- Ahorro
          Select count(*) conteo
            from AH_MOVIMIENTOS_HIS mo
           where trunc(ADD_MONTHS(sysdate, -6)) < mo.fecha
             and mo.nro_cuenta = p_nro_cuenta
          union
          -- Cuenta Corriente
          Select count(*) conteo
            from CC_MOVIMIENTOS_HIS mo
           where trunc(ADD_MONTHS(sysdate, -6)) < mo.fecha
             and mo.nro_cuenta = p_nro_cuenta
          union
          -- Préstamos
          Select count(*) conteo
            from PR_MOVIMIENTOS_HIS mo
           where trunc(ADD_MONTHS(sysdate, -6)) < mo.fecha
             and nro_cuenta = p_nro_cuenta
          union
          -- Tarjetas
          Select count(*) conteo
            from TA_MOVIMIENTOS_HIS mo
           where trunc(ADD_MONTHS(sysdate, -6)) < mo.fecha
             and nro_cuenta = p_nro_cuenta
          union
          -- Cambios
          Select count(*) conteo
            from LC_MOVIMIENTOS_HIS mo
           where trunc(ADD_MONTHS(sysdate, -6)) < mo.fecha
             and nro_cuenta = p_nro_cuenta
          union
          -- Comex
          Select count(*) conteo
            from CX_MOVIMIENTOS_HIS mo
           where trunc(ADD_MONTHS(sysdate, -6)) < mo.fecha
             and nro_cuenta = p_nro_cuenta
          union
          -- Finanzas
          Select count(*) conteo
            from MD_MOVIMIENTOS_HIS mo
           where trunc(ADD_MONTHS(sysdate, -6)) < mo.fecha
             and nro_cuenta = p_nro_cuenta);

       return(v_return);
end fug_obt_ctas_activas;
/


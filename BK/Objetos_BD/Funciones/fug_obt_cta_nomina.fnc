create or replace function it.fug_obt_cta_nomina(p_cod_persona ba_personas.cod_persona%type,
                                              p_cod_moneda  ba_monedas.cod_moneda%type)
  return varchar2 is
  v_cta_nomina varchar2(15) := null;
  v_error      varchar2(1000);
  /*
  Ajustado segun requerimiento del usuario, se ajusta para que se obtengan solo cuentas de
  sub_modalidad nomina segun el parametro y tomando en cuenta el saldo de la cuenta.
  */
begin
  Select nro_cuenta
    into v_cta_nomina
    from (Select cc.nro_cuenta,
                 cc.sal_total - (cc.sal_bloqueado + cc.sal_retenido) sal_total
            from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
           where cl.nro_cuenta = cc.nro_cuenta
             and cl.cod_persona = p_cod_persona
             and cc.cod_moneda = p_cod_moneda
             and cl.cod_modulo = g.cod_modulo
             and cl.cod_modalidad = g.cod_modalidad
             and cc.Cod_Sub_Modalidad =
                 fug_obt_pardinamico('COD_SUB_MOD_NOMINAS',
                                     cc.cod_modulo,
                                     cc.cod_modalidad)
             and cc.estado = g.estado
             and g.activo = 'S'
             and cl.relacion = 'P'
             and cc.cod_ente is not null
          union all
          Select ah.nro_cuenta,
                 ah.sal_total - (ah.sal_bloqueado + ah.sal_retenido)
            from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
           where cl.nro_cuenta = ah.nro_cuenta
             and cl.cod_persona = p_cod_persona
             and ah.cod_moneda = p_cod_moneda
             and cl.cod_modulo = g.cod_modulo
             and cl.cod_modalidad = g.cod_modalidad
             and ah.Cod_Sub_Modalidad =
                 fug_obt_pardinamico('COD_SUB_MOD_NOMINAS',
                                     ah.cod_modulo,
                                     ah.cod_modalidad)
             and ah.estado = g.estado
             and g.activo = 'S'
             and cl.relacion = 'P'
             and ah.cod_ente is not null
           order by 2 desc)
   where rownum = 1; --0101560664)
  return v_cta_nomina;
exception
  when no_data_found then
    begin
      select nro_cuenta
        into v_cta_nomina
        from (Select ah.nro_cuenta,
                     ah.sal_total - (ah.sal_bloqueado + ah.sal_retenido) sal_total
                from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
               where cl.nro_cuenta = ah.nro_cuenta
                 and cl.cod_persona = p_cod_persona
                 and ah.cod_moneda = p_cod_moneda
                 and cl.cod_modulo = g.cod_modulo
                 and cl.cod_modalidad = g.cod_modalidad
                 and ah.Cod_Sub_Modalidad <>
                     nvl(fug_obt_pardinamico('SUB_MOD_AGU_NOMINA',
                                             ah.cod_modulo,
                                             ah.cod_modalidad),
                         '9999')
                 and ah.estado = g.estado
                 and g.activo = 'S'
                 and cl.relacion in ('P', 'O')
              union all
              Select cc.nro_cuenta,
                     cc.sal_total - (cc.sal_bloqueado + cc.sal_retenido)
                from cc_cta_corrientes cc,
                     ge_cta_clientes   cl,
                     ge_est_cuentas    g
               where cl.nro_cuenta = cc.nro_cuenta
                 and cl.cod_persona = p_cod_persona
                 and cc.cod_moneda = p_cod_moneda
                 and cl.cod_modulo = g.cod_modulo
                 and cc.cod_modalidad = g.cod_modalidad
                 and cc.Cod_Sub_Modalidad <>
                     nvl(fug_obt_pardinamico('SUB_MOD_AGU_NOMINA',
                                             cc.cod_modulo,
                                             cc.cod_modalidad),
                         '9999')
                 and cc.estado = g.estado
                 and g.activo = 'S'
                 and cl.relacion in ('P', 'O')
               ORDER BY 2 DESC) a
       where not exists (select a.nro_cuenta
                from ge_cta_clientes b
               where b.nro_cuenta = a.nro_cuenta
                 and b.relacion = 'Y')
         and rownum = 1;
    exception
      when others then
        v_error      := sqlerrm;
        v_cta_nomina := null;
    end;
    return v_cta_nomina;
end;
/


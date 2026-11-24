create or replace function it.FUP_OBT_MTO_EXONERADO(p_cod_persona in varchar2, p_nro_solicitud in number) return number is
  v_monto         pr_cta_prestamos.monto%type;
  v_mto_solicitud pr_cta_prestamos.monto%type;
  v_mon_local pr_cta_prestamos.cod_moneda%type;
begin
  -- Obtiene la moneda local.
  v_mon_local := pag_gen.fu_obt_mon_local;
  -- Verifica préstamos vigentes...
  Select sum(pag_gen.FU_CON_MON_A_MONEDA(p.cod_moneda, v_mon_local, p.mto_capital))
    into v_monto
    from pr_cta_prestamos p, ge_cta_clientes c
   where p.nro_cuenta = c.nro_cuenta
     and c.relacion = 'P'
     and p.cod_sec_credito between 100 and 199 -- solo del sector agricola.
     and p.estado != 'N'
     and nvl(p.exo_impuestos, 'N') = 'S'
     and c.cod_persona = p_cod_persona;
  -- Verifica solicitudes en proceso.
  Select sum(pag_gen.FU_CON_MON_A_MONEDA(p.cod_moneda, v_mon_local, p.tot_prestamo))
    into v_mto_solicitud
    from pr_solicitudes p
   where p.cod_sec_credito between 100 and 199 -- solo del sector agricola.
     and p.estado not in ('R', 'A', 'E')
     and nvl(p.exo_impuesto, 'N') = 'S'
     and p.cod_persona = p_cod_persona
     and p.nro_solicitud != p_nro_solicitud;
  v_monto := nvl(v_monto,0) + nvl(v_mto_solicitud,0);
  return(v_monto);
end FUP_OBT_MTO_EXONERADO;
/


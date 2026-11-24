CREATE OR REPLACE FUNCTION IT.FUG_OBT_TOT_OPE_ESPECIFICA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 )
 RETURN NUMBER
 IS
 v_tot_lin_sobregiros number;
 v_tot_sobregiros     number;
 v_tot_sob_temp       number;
 v_tot_prestamos      number;
 v_tot_tarjetas       number;
 v_tot_tar_sob        number;
 
 v_tot_importaciones number;
 v_tot_exportaciones number;
 v_tot_fianzas       number;
 v_tot_mesa          number;
 v_tot_cambio       number;
 v_fec_actual         date := pag_cal.FU_OBT_FEC_ACTUAL(1);

begin
  select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, b.monto))
    into v_tot_lin_sobregiros
    from cc_lin_sobregiros b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.fec_vencimiento >= v_fec_actual
     and b.tipo = 'T'
     and b.nro_linea is null
     and b.estado = 'A'; -- TRANSITORIO
  select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, (b.sal_total-b.sal_retenido)*-1))
    into v_tot_sobregiros
    from cc_cta_corrientes b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado not in ('X', 'A', 'C')
     and b.sal_total-b.sal_retenido < 0
     and not exists (select 0 from cc_lin_sobregiros x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.estado in ('A', 'P', 'X') ---DYDMR-7228 - Incidencia SAU - ITGF - Inconveniente Linea de Crédito
                        and x.fec_vencimiento >= v_fec_actual);

  select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, b.sal_capital+nvl(b.sal_int_adelantado,0)))
    into v_tot_prestamos
    from pr_cta_prestamos b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado <> 'N'
     and b.sal_capital+nvl(b.sal_int_adelantado,0) > 0
     and b.nro_linea is null;

  select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, nvl(b.lin_credito,0)+nvl(b.lin_cuotas,0)))
    into v_tot_tarjetas
    from ta_cta_tarjetas b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado <> 'C'
     and b.nro_linea is null;

  select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, ((nvl(b.lin_credito,0)+nvl(b.lin_cuotas,0)) - 
            (nvl(b.sal_facturar,0)+nvl(b.sal_financiado,0)+nvl(b.sal_facturado,0))) * -1))
    into v_tot_tar_sob
    from ta_cta_tarjetas b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado <> 'C'
     and (nvl(b.lin_credito,0)+nvl(b.lin_cuotas,0)) - 
          (nvl(b.sal_facturar,0)+nvl(b.sal_financiado,0)+nvl(b.sal_facturado,0)) < 0;
     
  SELECT sum(pag_gen.FU_CON_MON_A_MONEDA(cta.cod_moneda, p_cod_moneda,
  decode(greatest(fuc_obt_mto_lin_sob(cta.nro_cuenta),sal_sobregiro), fuc_obt_mto_lin_sob(cta.nro_cuenta), 
  0, sal_sobregiro - fuc_obt_mto_lin_sob(cta.nro_cuenta))))
   Into v_tot_sob_temp
  FROM 
  (Select distinct cta.cod_moneda, cta.nro_cuenta nro_cuenta, ((nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0))* -1) sal_sobregiro
    from CC_LIN_SOBREGIROS LIN,
       CC_LIN_SOBREGIROS SOB,
       CC_LIN_SOB_GARANTIAS GAR,
       cc_cta_corrientes cta,
       GE_CTA_CLIENTES CLI
  WHERE LIN.NRO_SECUENCIA = SOB.NRO_SEC_PADRE
    --and cta.nro_cuenta = lin.nro_cuenta
    and cta.nro_cuenta = sob.nro_cuenta
    AND SOB.TIPO in ('T', 'P')
    AND SOB.ESTADO = 'A'
    and CTA.estado not in ('X', 'A', 'C')    
    AND CLI.COD_PERSONA = p_cod_persona
    AND SOB.NRO_SEC_PADRE = GAR.NRO_SECUENCIA
    AND SOB.NRO_CUENTA = CLI.NRO_CUENTA
    AND CLI.RELACION = 'P') cta;

   select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, nvl(b.saldo,0)))
    into v_tot_importaciones
    from cx_cta_importaciones b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado not in ('C','G')
     and b.nro_linea is null;
--DE-2507 - Ajustes en el detalle de Cobranzas Import/Expor y Cartas de Crédito de Exportación afectan el Activo - DYD-SDSL-3431
  /*select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, nvl(b.saldo,0)))
    into v_tot_exportaciones
    from cx_cta_exportaciones b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado not in ('C','G')
     and b.nro_linea is null;*/

  select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, nvl(monto,0)))
    into v_tot_fianzas
    from cx_fianzas b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado <> 'C'
     and b.nro_linea is null;
    --wa:04/04 para operaciones de Cambios
   v_tot_cambio:=0;

  select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, nvl(b.mto_limite,0)))
    into v_tot_cambio
    from lc_cta_cambios b, ge_cta_clientes a
   where b.nro_cuenta = a.nro_cuenta
     and a.cod_persona = p_cod_persona
     and a.relacion = 'P'
     and b.estado in ('N','A')
     and b.nro_linea is null
     and rownum=1;

      --SDCAMBENFI-1 - Op de Cambios con Entidades Financieras
      select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, nvl(monto,0)))
        into v_tot_mesa
        from md_cta_documentos m, ge_cta_clientes g, ge_est_cuentas e 
       where m.nro_cuenta = g.nro_cuenta
         and g.cod_persona = p_cod_persona
         and m.cod_modulo = e.cod_modulo
         and m.cod_modalidad = e.cod_modalidad
         and m.estado = e.estado
         and e.activo = 'S'
         and (fug_obt_pardinamico('LIM_PRO_HABILITADOS',
                                10,
                                m.cod_modalidad,
                                NULL) = 'S')
         and g.relacion = 'P'
         and m.nro_linea is null;

  return nvl(v_tot_tarjetas,0)+nvl(v_tot_tar_sob,0)+nvl(v_tot_prestamos,0)+nvl(v_tot_lin_sobregiros,0)+nvl(v_tot_sobregiros,0)+nvl(v_tot_sob_temp,0)+
         nvl(v_tot_importaciones,0)+nvl(v_tot_exportaciones,0)+nvl(v_tot_fianzas,0)+nvl(v_tot_cambio,0)
         + nvl(v_tot_mesa,0);
  /*IF nvl(v_tot_lin_sobregiros,0) < nvl(v_tot_sobregiros,0) THEN
      return nvl(v_tot_tarjetas,0)+nvl(v_tot_tar_sob,0)+nvl(v_tot_prestamos,0)+nvl(v_tot_sobregiros,0)+
		nvl(v_tot_sob_temp,0)+nvl(v_tot_importaciones,0)+nvl(v_tot_exportaciones,0)+nvl(v_tot_fianzas,0);
	ELSE
      return nvl(v_tot_tarjetas,0)+nvl(v_tot_tar_sob,0)+nvl(v_tot_prestamos,0)+nvl(v_tot_lin_sobregiros,0)+
		nvl(v_tot_sob_temp,0)+nvl(v_tot_importaciones,0)+nvl(v_tot_exportaciones,0)+nvl(v_tot_fianzas,0);	
	END IF;*/
end;
/


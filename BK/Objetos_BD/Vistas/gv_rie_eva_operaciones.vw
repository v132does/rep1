create or replace force view it.gv_rie_eva_operaciones as
select sol.nro_solicitud,
       substr(rpad(nvl(' ', ' '), 10, ' '), 1, 10) afinidad,
       substr(rpad(nvl(to_char(sol.cod_canal), ' '), 3, ' '), 1, 3) canal,
       lpad(ltrim(to_char(nvl(sol.cod_campana, 0), '9999999999999')), 3, '0') codcamapro,
       lpad(ltrim(nvl(to_number(sol.cod_destino), 0)), 3, '0') destino,
       substr(rpad(nvl(sol.deb_automatico, ' '), 1, ' '), 1, 1) esdebitoautom,
       substr(rpad(nvl(to_char(sol.fec_inicio, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fechasolicitud,
       lpad(ltrim(to_char(nvl(sol.cod_modalidad, 0), '9999999999999')), 3, '0') modalidad,
       substr(rpad(nvl(sol.cod_moneda, ' '), 3, ' '), 1, 3) monedamonto,
       substr(rpad(nvl(lin.cod_moneda, ' '), 10, ' '), 1, 10) monedamontolin,
       substr(rpad(nvl(nvl(g.cod_moneda,sol.cod_moneda), ' '), 3, ' '), 1, 3) monedavalgar,
       lpad(ltrim(to_char(nvl(prgar.mto_aplicado, 0), '999999999999990D99')), 20, ' ') montoaplicado,
       lpad(ltrim(to_char(nvl(lin.monto, 0), '999999999999990D99')), 20, ' ') montolinea,
       lpad(ltrim(to_char(nvl(sol.monto, 0), '999999999999990D99')), 20, ' ') montosolicitado,
       lpad(ltrim(to_char(nvl((select count(1) from pr_sol_cuotas cu where cu.nro_cuota <> 0 and cu.nro_solicitud = sol.nro_solicitud), 0), '9999999999999')), 3, '0') numcuotas,
       lpad(ltrim(to_char(nvl(sol.nro_solicitud, 0), '9999999999999')), 7, '0') numpropuesta,
       lpad(ltrim(to_char(nvl(sol.cod_oficina, 0), '9999999999999')), 3, '0') oficina,
       lpad(ltrim(to_char(nvl(sol.dia_plazo, 0), '9999999999999')), 4, '0') plazo,
       lpad(ltrim(to_char(decode(g.cod_garantia,3,(select sum(nvl(t.val_edilicio, 0) + nvl(t.val_terreno, 0)) from pr_gar_hipotecarias t where t.nro_garantia = ghip.nro_garantia), nvl(g.val_tasacion,0)), '999999999999990D99')), 20, ' ') tasacion,
       lpad(ltrim(to_char(nvl((select val_tasa from pr_sol_tasas t where t.nro_solicitud = sol.nro_solicitud), 0), '999999999999990D9999')), 20, ' ') tasainteres,
       substr(rpad(nvl(ghip.tip_vivienda, ' '), 3, ' '), 1, 3) tipobien,
       lpad(ltrim(to_char(nvl(prgar.cod_garantia, 0), '9999999999999')), 3, '0')  tipogarantia,
       lpad(ltrim(to_char(nvl(g.valor, 0), '999999999999990D99')), 20, ' ')  valorgarantia,
       lpad(ltrim(to_char(nvl(sol.val_presupuesto, 0), '999999999999990D99')), 20, ' ')  valorpresupuesto,
       lpad(ltrim(nvl(sol.cod_modulo, 0)), 3, '0') modulo,
       lpad(ltrim(nvl(sol.cod_sub_modalidad, 0)), 3, '0') sub_modalidad,
       lpad(ltrim(nvl(sol.cod_ent_concesionaria,0)), 5, '0') cod_ent_concesionaria,
       lpad(ltrim(to_char(nvl(FUE_TAB_DAT_ADICIONAL('PR_SOLICITUDES', 'COD_MARCA',  sol.nro_solicitud), 0), '9999999999999')), 3, '0') cod_marca,
       lpad(ltrim(to_char(nvl(FUE_TAB_DAT_ADICIONAL('PR_SOLICITUDES', 'COD_ORIGEN', sol.nro_solicitud), 0), '9999999999999')), 3, '0') cod_origen,
       lpad(ltrim(to_char(decode(sol.cod_moneda, pag_gen.fu_obt_mon_local, 1 ,pag_gen.fu_obt_cotizacion(sol.cod_moneda, sol.fec_inicio)), '999999999999990D99')), 7, 0) cotizacion,
       lpad(ltrim(to_char(nvl(sol.tot_prestamo, 0), '999999999999990D99')), 20, ' ') totprestamos,
       --lpad(ltrim(to_char(nvl(scuo.max_cuota, 0), '999999999999990D99')), 20, ' ') cuotapr
       lpad(ltrim(to_char(nvl(par_per.fu_cal_cuota(sol.nro_solicitud), 0), '999999999999990D99')), 20, ' ') cuotapr
  from ba_personas         p,
       pr_solicitudes      sol,
       ba_per_fisicas      pf,
       ge_clientes         ge,
       pr_sol_garantias    prgar,
       pr_garantias        g,
       pr_gar_hipotecarias ghip,
       pr_lineas lin/*,
       (select max(nvl(c.mto_capital, 0) - decode(a.tipo, 'D', nvl(c.val_int_adelantado, 0), 0) + c.val_interes) max_cuota,
               a.nro_solicitud
          from pr_sol_cuotas c, pr_solicitudes a
         where c.nro_solicitud = a.nro_solicitud
           and c.nro_cuota > 0
        group by a.nro_solicitud) scuo*/
 where p.cod_persona       = sol.cod_persona
   and p.cod_persona       = pf.cod_persona
   and sol.nro_linea       = lin.nro_linea(+)
   and p.cod_persona       = ge.cod_persona
   and sol.nro_solicitud   = prgar.nro_solicitud(+)
   and prgar.nro_garantia  = g.nro_garantia(+)
   and prgar.cod_garantia  = g.cod_garantia(+)
   and g.nro_garantia      = ghip.nro_garantia(+)
   --and sol.nro_solicitud   = scuo.nro_solicitud(+)
 union all
   select sol.nro_solicitud,
       substr(rpad(nvl(sol.afinidad, ' '), 10, ' '), 1, 10) afinidad,
       substr(rpad(nvl(to_char(sol.cod_canal), ' '), 3, ' '), 1, 3) canal,
       lpad(ltrim(to_char(nvl(sol.cod_campana, 0), '9999999999999')), 3, '0') codcamapro,
       lpad(ltrim(nvl(0, 0), '9999999999999'), 3, '0') destino,
       substr(rpad(nvl(sol.deb_automatico, ' '), 1, ' '), 1, 1) esdebitoautom,
       substr(rpad(nvl(to_char(sol.fec_solicitud, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fechasolicitud,
       lpad(ltrim(to_char(nvl(sol.cod_modalidad, 0), '9999999999999')), 3, '0') modalidad,
       substr(rpad(nvl(sol.cod_moneda, ' '), 3, ' '), 1, 3) monedamonto,
       substr(rpad(nvl(sol.cod_moneda, ' '), 10, ' '), 1, 10) monedamontolin,
       substr(rpad(nvl(nvl(g.cod_moneda,sol.cod_moneda), ' '), 3, ' '), 1, 3) monedavalgar,
       lpad(ltrim(to_char(nvl(prgar.mto_aplicado, 0), '999999999999990D99')), 20, ' ') montoaplicado,
       lpad(ltrim(to_char(nvl(sol.monto, 0), '999999999999990D99')), 20, ' ') montolinea,
       lpad(ltrim(to_char(nvl(sol.monto, 0), '999999999999990D99')), 20, ' ') montosolicitado,
       lpad(ltrim(to_char(nvl(0, 0), '9999999999999')), 3, '0') numcuotas,
       lpad(ltrim(to_char(nvl(sol.nro_solicitud, 0), '9999999999999')), 7, '0') numpropuesta,
       lpad(ltrim(to_char(nvl(sol.cod_oficina, 0), '9999999999999')), 3, '0') oficina,
       lpad(ltrim(to_char(nvl(0, 0), '9999999999999')), 4, '0') plazo,
       lpad(ltrim(to_char(decode(g.cod_garantia,3,(select sum(nvl(t.val_edilicio, 0) + nvl(t.val_terreno, 0)) from pr_gar_hipotecarias t where t.nro_garantia = ghip.nro_garantia), nvl(g.val_tasacion,0)), '999999999999990D99')), 20, ' ') tasacion,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D9999')), 20, ' ') tasainteres,
       substr(rpad(nvl(ghip.tip_vivienda, ' '), 3, ' '), 1, 3) tipobien,--substr(rpad(nvl(' ', ' '), 3, ' '), 1, 3) tipobien,
       lpad(ltrim(to_char(nvl(prgar.cod_garantia, 0), '9999999999999')), 3, '0')  tipogarantia,
       lpad(ltrim(to_char(nvl(g.valor, 0), '999999999999990D99')), 20, ' ')  valorgarantia,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D99')), 20, ' ')  valorpresupuesto,
       lpad(ltrim(nvl(sol.cod_modulo, 0)), 3, '0') modulo,
       lpad(ltrim(nvl(sol.cod_sub_modalidad, 0)), 3, '0') sub_modalidad,
       lpad(ltrim(0), 5, '0') cod_ent_concesionaria,
       lpad(ltrim(to_char(0, '9999999999999')), 3, '0') cod_marca,
       lpad(ltrim(to_char(0, '9999999999999')), 3, '0') cod_origen,
       lpad(ltrim(to_char(decode(sol.cod_moneda, pag_gen.fu_obt_mon_local, 1 ,pag_gen.fu_obt_cotizacion(sol.cod_moneda, sol.fec_solicitud)), '999999999999990D99')), 7, 0) cotizacion,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D99')), 20, ' ') totprestamos,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D99')), 20, ' ') cuotapr
  from ba_personas         p,
       ta_solicitudes      sol,
       ba_per_fisicas      pf,
       ge_clientes         ge,
       ta_sol_garantias    prgar,
       pr_garantias        g,
       pr_gar_hipotecarias ghip,
       pr_lineas lin
 where p.cod_persona       = sol.cod_persona
   and p.cod_persona       = pf.cod_persona
   and sol.nro_linea       = lin.nro_linea(+)
   and p.cod_persona       = ge.cod_persona
   and sol.nro_solicitud   = prgar.nro_solicitud(+)
   and prgar.nro_garantia  = g.nro_garantia(+)
   and prgar.cod_garantia  = g.cod_garantia(+)
   and g.nro_garantia      = ghip.nro_garantia(+)
union all
select sol.nro_solicitud,
       substr(rpad(nvl(t.afinidad, ' '), 10, ' '), 1, 10) afinidad,
       substr(rpad(nvl(to_char(nvl(nvl(sol.cod_canal, s.cod_canal), ge.cod_canal)), ' '), 3, ' '), 1, 3) canal,--DYDMR-13561-- Se modifica para que tome el canal de la tabla ta_sol_lineas.
       lpad(ltrim(to_char(nvl(t.cod_campana, 0), '9999999999999')), 3, '0') codcamapro,
       lpad(ltrim(nvl(0, 0), '9999999999999'), 3, '0') destino,
       substr(rpad(nvl(t.deb_automatico, ' '), 1, ' '), 1, 1) esdebitoautom,
       substr(rpad(nvl(to_char(sol.fec_ingreso, 'YYYYMMDD'), ' '), 8, ' '), 1, 8) fechasolicitud,
       lpad(ltrim(to_char(nvl(t.cod_modalidad, 0), '9999999999999')), 3, '0') modalidad,
       substr(rpad(nvl(sol.cod_moneda, ' '), 3, ' '), 1, 3) monedamonto,
       substr(rpad(nvl(sol.cod_moneda, ' '), 10, ' '), 1, 10) monedamontolin,
       substr(rpad(nvl(nvl(g.cod_moneda,sol.cod_moneda), ' '), 3, ' '), 1, 3) monedavalgar,
       lpad(ltrim(to_char(nvl(sol.lin_credito, 0), '999999999999990D99')), 20, ' ') montoaplicado,
       lpad(ltrim(to_char(nvl(sol.lin_credito, 0), '999999999999990D99')), 20, ' ') montolinea,
       lpad(ltrim(to_char(nvl(sol.lin_credito, 0), '999999999999990D99')), 20, ' ') montosolicitado,
       lpad(ltrim(to_char(nvl(0, 0), '9999999999999')), 3, '0') numcuotas,
       lpad(ltrim(to_char(nvl(sol.nro_solicitud, 0), '9999999999999')), 7, '0') numpropuesta,
       lpad(ltrim(to_char(nvl(t.cod_oficina, 0), '9999999999999')), 3, '0') oficina,
       lpad(ltrim(to_char(nvl(0, 0), '9999999999999')), 4, '0') plazo,
       lpad(ltrim(to_char(decode(g.cod_garantia,3,(select sum(nvl(t.val_edilicio, 0) + nvl(t.val_terreno, 0)) from pr_gar_hipotecarias t where t.nro_garantia = ghip.nro_garantia), nvl(g.val_tasacion,0)), '999999999999990D99')), 20, ' ') tasacion,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D9999')), 20, ' ') tasainteres,
       substr(rpad(nvl(ghip.tip_vivienda, ' '), 3, ' '), 1, 3) tipobien,
       lpad(ltrim(to_char(nvl(prgar.cod_garantia, 0), '9999999999999')), 3, '0')  tipogarantia,
       lpad(ltrim(to_char(nvl(g.valor, 0), '999999999999990D99')), 20, ' ')  valorgarantia,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D99')), 20, ' ')  valorpresupuesto,
       lpad(ltrim(nvl(t.cod_modulo, 0)), 3, '0') modulo,
       lpad(ltrim(nvl(s.cod_sub_modalidad, 0)), 3, '0') sub_modalidad,
       lpad(ltrim(0), 5, '0') cod_ent_concesionaria,
       lpad(ltrim(to_char(0, '9999999999999')), 3, '0') cod_marca,
       lpad(ltrim(to_char(0, '9999999999999')), 3, '0') cod_origen,
       lpad(ltrim(to_char(decode(sol.cod_moneda, pag_gen.fu_obt_mon_local, 1 ,pag_gen.fu_obt_cotizacion(sol.cod_moneda, sol.fec_ingreso)), '999999999999990D99')), 7, 0) cotizacion,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D99')), 20, ' ') totprestamos,
       lpad(ltrim(to_char(nvl(0, 0), '999999999999990D99')), 20, ' ') cuotapr
  from ba_personas         p,
       ta_sol_lineas       sol,
       ta_cta_tarjetas     t,
       ta_solicitudes      s,
       ba_per_fisicas      pf,
       ge_clientes         ge,
       ta_cta_garantias    prgar,
       pr_garantias        g,
       pr_gar_hipotecarias ghip,
       pr_lineas lin
 where p.cod_persona       = sol.cod_persona
   and sol.tip_solicitud   = 'A'-- Sólo Ampliaciones
   and p.cod_persona       = pf.cod_persona
   and t.nro_linea         = lin.nro_linea(+)
   and p.cod_persona       = ge.cod_persona
   and sol.nro_cuenta      = t.nro_cuenta
   and t.nro_solicitud     = s.nro_solicitud(+)
   and t.nro_cuenta        = prgar.nro_cuenta(+)
   and prgar.nro_garantia  = g.nro_garantia(+)
   and prgar.cod_garantia  = g.cod_garantia(+)
   and g.nro_garantia      = ghip.nro_garantia(+)
;


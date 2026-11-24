create or replace force view it.gv_cta_garantias as
select gar.nro_garantia, --GARANTIAS
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) - nvl(gar.mto_aplicado,0)
            else 0 end saldo,
       to_char(null) nro_cuenta,
       0 mto_aplicado,
       0 mto_apl_computable,
       to_char(null) descripcion,
       0 sal_capital,
       0 dev_no_cobrado,
       gar.cod_moneda cod_mon_ope,
       null cod_modalidad,
       0 sal_interes,
       null estado,
       to_number(null) nro_linea,
       null cod_modulo,
       gar.tipo,
       null fec_insercion
  from pr_garantias gar
 where not exists (select 1 from pr_cta_garantias cta
                   where cta.nro_garantia = gar.nro_garantia)
  and not exists  (select 1 from cc_lin_sob_garantias cta
                   where cta.nro_garantia = gar.nro_garantia)
  and not exists  (select 1 from ta_cta_garantias cta
                   where cta.nro_garantia = gar.nro_garantia)
  and not exists  (select 1 from cx_cta_garantias cta
                   where cta.nro_garantia = gar.nro_garantia)
  and not exists  (select 1 from cc_cta_garantias cta
                   where cta.nro_garantia = gar.nro_garantia)
union
select cta.nro_garantia, --Solicitud de PRESTAMOS
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) - nvl(gar.mto_aplicado,0)
            else 0 end saldo,
       'Prop.Nro. '||to_char(pre.NRO_SOLICITUD) nro_cuenta,
       cta.mto_aplicado,
       cta.mto_aplicado,
       mad.descripcion,
       nvl(pre.tot_prestamo,0) sal_capital,
       0 dev_no_cobrado,
       pre.cod_moneda cod_mon_ope,
       pre.cod_modalidad,
       decode(pre.tip_interes,'A',0,nvl(pre.mto_interes,0)) sal_interes,
       pre.estado estado,
       to_number(null) nro_linea,
       pre.cod_modulo,
       gar.tipo,
       trunc(cta.fec_insercion) fec_insercion
  from pr_garantias gar,
       pr_sol_garantias cta,
       pr_solicitudes pre,
       ge_modalidades mad
 where gar.nro_garantia(+) = cta.nro_garantia
   and gar.cod_garantia(+) = cta.cod_garantia
   and cta.nro_solicitud = pre.nro_solicitud
   and pre.cod_modulo = mad.cod_modulo
   and pre.cod_modalidad = mad.cod_modalidad
   and pre.estado in ('S','L')
union
select cta.nro_garantia, --PRESTAMOS
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,--pre.cod_moneda se cambio x la de la garantia
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
              case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       cta.nro_cuenta,
       cta.mto_aplicado,
       cta.mto_apl_computable,
       mad.descripcion,
       nvl(pre.sal_capital,0)+nvl(pre.sal_int_adelantado,0) sal_capital,
       nvl(pre.dev_no_cobrado,0) dev_no_cobrado,
       pre.cod_moneda cod_mon_ope,
       pre.cod_modalidad,
       nvl(pre.sal_interes,0) sal_interes,
       pre.estado estado,
       to_number(null) nro_linea,
       pre.cod_modulo,
       gar.tipo,
       trunc(cta.fec_insercion) fec_insercion
  from pr_garantias gar,
       pr_cta_garantias cta,
       pr_cta_prestamos pre,
       ge_modalidades mad
 where gar.nro_garantia(+) = cta.nro_garantia
   and gar.cod_garantia(+) = cta.cod_garantia
   and cta.nro_cuenta = pre.nro_cuenta
   and pre.cod_modulo = mad.cod_modulo
   and pre.cod_modalidad = mad.cod_modalidad
   and pre.estado != 'N'
   and pre.nro_sol_renovada is null --se tienen en cuenta las operaciones nuevas de RRR
union
select gar.nro_garantia, --SOBREGIROS
       g.cod_garantia,
       g.fec_vencimiento,
       g.cod_persona,
       g.cod_moneda,-- sob.cod_moneda se cambio x la de la garantia
       g.valor,
       case when g.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(g.nro_garantia)
            else 0 end val_computable,
       decode(g.nro_garantia,null, g.valor,
              case when g.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(g.nro_garantia) else 0 end) - nvl(g.mto_aplicado,0) saldo,
       cta.nro_cuenta,
       pag_gen.FU_CON_MON_A_MONEDA(lin.cod_moneda,sob.cod_moneda,
                                  (round(pag_gen.FU_CON_MON_A_MONEDA(sob.cod_moneda,lin.cod_moneda,
                                   sob.monto,pag_gen.fu_obt_cotizacion(sob.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(4)))/lin.monto*gar.mto_aplicado,0)),pag_gen.fu_obt_cotizacion(sob.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(4))) mto_aplicado,
       pag_gen.FU_CON_MON_A_MONEDA(lin.cod_moneda,sob.cod_moneda,
                                   (round(pag_gen.FU_CON_MON_A_MONEDA(sob.cod_moneda,lin.cod_moneda,
                                    sob.monto,pag_gen.fu_obt_cotizacion(sob.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(4)))/lin.monto*gar.mto_apl_computable,0)),pag_gen.fu_obt_cotizacion(sob.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(4))) mto_apl_computable,
                                    mad.descripcion,
       nvl(cta.sal_total,0) - nvl(cta.sal_retenido,0) sal_capital,
       0,
       cta.cod_moneda cod_mon_ope,
       cta.cod_modalidad,
       0 sal_interes,
       cta.estado estado,
       lin.nro_secuencia nro_linea,
       cta.cod_modulo,
       g.tipo,
       trunc(gar.fec_insercion) fec_insercion
  from pr_garantias g,
       cc_lin_sobregiros lin,
       cc_lin_sobregiros sob,
       cc_lin_sob_garantias gar,
       cc_cta_corrientes cta,
       ge_modalidades mad
 where g.nro_garantia  = gar.nro_garantia(+)
   and g.cod_garantia = gar.cod_garantia(+)
   and gar.nro_secuencia = lin.nro_secuencia
   and lin.nro_secuencia = sob.nro_sec_padre
   and sob.estado = 'A'
   and sob.nro_sec_padre = gar.nro_secuencia
   and sob.nro_cuenta = cta.nro_cuenta
   and cta.cod_modulo = mad.cod_modulo
   and cta.cod_modalidad = mad.cod_modalidad
union
select c.nro_garantia,--TARJETAS
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,--b.cod_moneda se cambio x la de la garantia
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
              case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       b.nro_cuenta,
       c.mto_aplicado,
       c.mto_apl_computable,
       mad.descripcion,
       nvl(b.sal_facturar,0)+nvl(b.sal_facturado,0)+nvl(b.sal_financiado,0) sal_capital,
       0,
       b.cod_moneda cod_mon_ope,
       b.cod_modalidad,
       0 sal_interes,
       b.estado estado,
       to_number(null) nro_linea,
       b.cod_modulo,
       gar.tipo,
       trunc(c.fec_insercion) fec_insercion
  from pr_garantias gar,
       ta_cta_tarjetas b,
       ta_cta_garantias c,
       ge_modalidades mad
 where gar.nro_garantia(+) = c.nro_garantia
   and gar.cod_garantia(+) = c.cod_garantia
   and c.nro_cuenta = b.nro_cuenta
   and b.cod_modulo = mad.cod_modulo
   and b.cod_modalidad = mad.cod_modalidad
   and b.estado != 'C'
union
select c.nro_garantia,-- Importaciones
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,--b.cod_moneda se cambio x la de la garantia
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
              case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       b.nro_cuenta,
       c.mto_aplicado,
       c.mto_apl_computable,
       mad.descripcion,
       b.monto,
       0,
       b.cod_moneda cod_mon_ope,
       b.cod_modalidad,
       0 sal_interes,
       b.estado estado,
       to_number(null) nro_linea,
       b.cod_modulo,
       gar.tipo,
       trunc(c.fec_insercion) fec_insercion
  from pr_garantias gar,
       cx_cta_garantias c,
       cx_cta_importaciones b,
       ge_modalidades mad
  where gar.nro_garantia(+) = c.nro_garantia
    and gar.cod_garantia(+) = c.cod_garantia
    and c.nro_cuenta = b.nro_cuenta
    and b.cod_modulo = mad.cod_modulo
    and b.cod_modalidad = mad.cod_modalidad
    and b.estado not in ('C','G')
union
select c.nro_garantia,-- Exportaciones
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,--b.cod_moneda se cambio x la de la garantia
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
              case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       b.nro_cuenta,
       c.mto_aplicado,
       c.mto_apl_computable,
       mad.descripcion,
       b.monto, 0,
       b.cod_moneda cod_mon_ope,
       b.cod_modalidad,
       0 sal_interes,
       b.estado estado,
       to_number(null) nro_linea,
       b.cod_modulo,
       gar.tipo,
       trunc(c.fec_insercion) fec_insercion
  from pr_garantias gar,
       cx_cta_garantias c,
       cx_cta_exportaciones b,
       ge_modalidades mad
  where gar.nro_garantia(+) = c.nro_garantia
    and gar.cod_garantia(+) = c.cod_garantia
    and c.nro_cuenta = b.nro_cuenta
    and b.cod_modulo = mad.cod_modulo
    and b.cod_modalidad = mad.cod_modalidad
    and b.estado not in ('C','G')
union
select c.nro_garantia,--Fianzas
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,--b.cod_moneda se cambio x la de la garantia
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
              case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       b.nro_cuenta,
       c.mto_aplicado,
       c.mto_apl_computable,
       mad.descripcion,
       b.monto, 0,
       b.cod_moneda cod_mon_ope,
       b.cod_modalidad,
       0 sal_interes,
       b.estado estado,
       to_number(null) nro_linea,
       b.cod_modulo,
       gar.tipo,
       trunc(c.fec_insercion) fec_insercion
  from pr_garantias gar,
       cx_cta_garantias c,
       cx_fianzas b,
       ge_modalidades mad
  where gar.nro_garantia(+) = c.nro_garantia
    and gar.cod_garantia(+) = c.cod_garantia
    and c.nro_cuenta = b.nro_cuenta
    and b.cod_modulo = mad.cod_modulo
    and b.cod_modalidad = mad.cod_modalidad
    and b.estado != 'C'
/* agregado para solicitudes de tarjetas de credito */
union
select c.nro_garantia,-- SOLICITUDES DE TARJETAS
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,--b.cod_moneda se cambio x la de la garantia
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
              case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       'Sol.Nro. '||to_char(B.NRO_SOLICITUD) nro_cuenta,
       c.mto_aplicado,
       c.mto_aplicado,
       mad.descripcion,
       0 sal_capital,
       0,
       b.cod_moneda cod_mon_ope,
       b.cod_modalidad,
       0 sal_interes,
       'N' estado, -- fijo estado 'N'
       to_number(null) nro_linea,
       b.cod_modulo,
       gar.tipo,
       trunc(c.fec_insercion) fec_insercion
  from pr_garantias gar,
       ta_solicitudes b,
       ta_sol_garantias c,
       ge_modalidades mad
 where gar.nro_garantia(+) = c.nro_garantia
   and gar.cod_garantia(+) = c.cod_garantia
   and c.nro_solicitud = b.nro_solicitud
   and b.cod_modulo = mad.cod_modulo
   and b.cod_modalidad = mad.cod_modalidad
   and b.cod_estado in ('PAN','APR')
union
select c.nro_garantia,-- OPERACIONES VENCIDAS
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
              case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       b.nro_cuenta,
       c.mto_aplicado,
       c.mto_apl_computable,
       mad.descripcion,
       b.sal_total sal_capital,
       0,
       b.cod_moneda cod_mon_ope,
       b.cod_modalidad,
       0 sal_interes,
       b.estado estado,
       to_number(null) nro_linea,
       b.cod_modulo,
       gar.tipo,
       trunc(c.fec_insercion) fec_insercion
  from pr_garantias gar,
       ov_cta_vencidas b,
       ov_cta_garantias c,
       ge_modalidades mad
 where gar.nro_garantia(+) = c.nro_garantia
   and gar.cod_garantia(+) = c.cod_garantia
   and c.nro_cuenta = b.nro_cuenta
   and b.cod_modulo = mad.cod_modulo
   and b.cod_modalidad = mad.cod_modalidad
   and b.estado != 'C'
union
select c.nro_garantia,--Cuentas Corrientes
       gar.cod_garantia,
       gar.fec_vencimiento,
       gar.cod_persona,
       gar.cod_moneda,
       gar.valor,
       case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia)
            else 0 end val_computable,
       decode(gar.nro_garantia,null, gar.valor,
               case when gar.cod_garantia > 2 then pap_gar.FU_OBT_VAL_COMPUTABLE(gar.nro_garantia) else 0 end) - nvl(gar.mto_aplicado,0) saldo,
       b.nro_cuenta,
       c.mto_aplicado,
       c.mto_apl_computable,
       mad.descripcion,
       nvl(b.sal_total,0) sal_capital,
       0,
       b.cod_moneda cod_mon_ope,
       b.cod_modalidad,
       0 sal_interes,
       b.estado estado,
       to_number(null) nro_linea,
       b.cod_modulo,
       gar.tipo,
       null fec_insercion
  from pr_garantias gar,
       cc_cta_corrientes b,
       cc_cta_garantias c,
       ge_modalidades mad
 where gar.nro_garantia(+) = c.nro_garantia
   and gar.cod_garantia(+) = c.cod_garantia
   and c.nro_cuenta = b.nro_cuenta
   and b.cod_modulo = mad.cod_modulo
   and b.cod_modalidad = mad.cod_modalidad
   and b.estado != 'C'
   --DYDMR-7225 - Incidencia SAU - Agosto/2017
   and not exists (select 1
                     from cc_lin_sobregiros l
                     where l.nro_cuenta = c.nro_cuenta)
;


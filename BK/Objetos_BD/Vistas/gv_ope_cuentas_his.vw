CREATE OR REPLACE FORCE VIEW IT.GV_OPE_CUENTAS_HIS AS
select /*Q_PRESTAMOS*/ a.pais, tip_doc, a.nro_documento, a.tip_operacion, a.cod_mon_bco_central, a.moneda, a.rubro_bcp,
       c.nro_cuenta, to_char(p.fec_inicio,'yyyymmdd') fec_contabilizacion, p.val_tasa,
       to_char(c.fec_vencimiento,'yyyymmdd') fec_vencimiento, to_char(c.fec_ult_pago,'yyyymmdd') fec_ult_pago,
       c.fec_ult_pago - c.fec_vencimiento atraso,
       nvl(c.mto_capital,0)+nvl(c.mto_interes,0) + nvl(c.mto_int_documentado,0) mto_cuota,
       nvl(c.mto_capital,0) mto_capital,
       nvl(c.mto_interes,0) + nvl(c.mto_int_documentado,0)  mto_interes,
       nvl(c.sal_capital,0) sal_capital,
       nvl(c.sal_interes,0) + NVL(c.sal_int_documentado,0) sal_interes,
       0 saldo_pagar_capital, 0 saldo_pagar_interes,
       fup_est_sit_cuota(c.fec_ult_pago, c.nro_cuenta, c.nro_cuota,
                         c.fec_ult_pago - c.fec_vencimiento, c.estado) estado_sit,
       a.categoria, c.nro_cuota, a.modalidad, a.cod_persona, p.fec_inicio
  from pr_cuotas c,
       pr_cta_prestamos p,
       gv_ope_clientes_his a
 where p.nro_cuenta = c.nro_cuenta
   and c.nro_cuota > 0
   and p.nro_cuenta = a.nro_cuenta
   and 1 >= (select count(*) from pr_cobros b
              where c.nro_cuenta = b.nro_cuenta and c.nro_cuota = b.nro_cuota)
   and a.fec_operacion = (select min(x.fecha)
                            from sb_crc_operaciones_det x
                           where nvl(substr(x.nro_operacion,1,INSTR(x.nro_operacion,'#')-1),x.nro_operacion) = p.nro_cuenta)
 union
--- Cuotas Parceladas
select a.pais, tip_doc, a.nro_documento, a.tip_operacion, a.cod_mon_bco_central, a.moneda, a.rubro_bcp,
       cu.nro_cuenta, to_char(p.fec_inicio,'yyyymmdd') fec_contabilizacion, p.val_tasa,
       to_char(cu.fec_vencimiento,'yyyymmdd') fec_vencimiento, to_char(x.fecha,'yyyymmdd') fec_ult_pago,
       nvl(x.dia_mora,0) atraso,
       nvl(cu.mto_capital,0)+nvl(cu.mto_interes,0) + nvl(cu.mto_int_documentado,0) mto_cuota,
       nvl(x.mto_capital,0) mto_capital,
       nvl(x.mto_interes,0) + nvl(x.mto_int_documentado,0)  mto_interes,
       DECODE(CU.ESTADO, 'N', 0, decode(cu.fec_ult_pago, x.fecha, (nvl(x.sal_capital_cuo,0)) -
        (nvl(x.mto_capital,0)),0)) sal_capital,
       nvl(cu.sal_interes,0) + NVL(cu.sal_int_documentado,0) sal_interes,
       0 saldo_pagar_capital, 0 saldo_pagar_interes,
       decode(x.estado,'C','1','A','1','V','2','G','3','M','4','5') estado_sit,
       a.categoria, x.nro_cuota, a.modalidad, a.cod_persona, p.fec_inicio
  from pr_cuotas cu, pr_cobros x, gv_ope_clientes_his a, pr_cta_prestamos p
 where cu.nro_cuenta = p.nro_cuenta
   and cu.nro_cuenta = x.nro_cuenta
   and cu.nro_cuota = x.nro_cuota
   and cu.nro_cuenta = a.nro_cuenta
   and nvl(x.mto_capital,0) + nvl(x.mto_interes,0) + nvl(x.mto_int_documentado,0) > 0
   and 1 < (select count(*) from pr_cobros b
             where x.nro_cuenta = b.nro_cuenta and x.nro_cuota = b.nro_cuota)
    and a.fec_operacion = (select min(x.fecha) from sb_crc_operaciones_det x
                            where nvl(substr(x.nro_operacion,1,INSTR(x.nro_operacion,'#')-1),x.nro_operacion) = p.nro_cuenta)
union
--- Q_TARJETAS
select a.pais, tip_doc, a.nro_documento, a.tip_operacion, a.cod_mon_bco_central, a.moneda, a.rubro_bcp,
       c.nro_cuenta, to_char(t.fec_apertura,'yyyymmdd') fec_contabilizacion, t.tas_financiacion val_tasa,
       to_char(c.fec_vto_pago,'yyyymmdd') fec_vencimiento,
       to_char(fut_obt_fec_cobro(c.nro_cuenta,c.fec_vto_pago),'yyyymmdd') fec_ult_pago,
       case
          when nvl(t.dia_mora,0) <> 0 then
             t.dia_mora
          when nvl(t.dia_mora,0) = 0 and nvl(c.dia_atraso,0) <> 0 then
             c.dia_atraso
          else
             nvl(fut_obt_fec_cobro(c.nro_cuenta,c.fec_vto_pago),c.fec_vto_pago) - c.fec_vto_pago
       end atraso,
       case
          when nvl(c.mto_pag_minimo,0) <> 0 then
             c.mto_pag_minimo
          else
             (SELECT nvl(sum(t.monto),0)
                FROM ta_cobros t
               WHERE t.fec_valor  = fut_obt_fec_cobro(c.nro_cuenta,c.fec_vto_pago)
                 AND t.nro_cuenta = c.nro_cuenta)
       end mto_cuota,
       nvl(c.mto_pag_minimo,0) mto_capital,
       0  mto_interes,
       decode(c.mto_pag_minimo-t.mto_pag_mes, abs(c.mto_pag_minimo-t.mto_pag_mes), c.mto_pag_minimo-t.mto_pag_mes, 0) sal_capital,
       0 sal_interes,
       0 saldo_pagar_capital, 0 saldo_pagar_interes,
       fut_est_sit_tarjetas(t.dia_mora, a.cat_riesgo) estado_sit,
       a.categoria, 1 nro_cuota, a.modalidad, a.cod_persona, t.fec_apertura fec_inicio
  from ta_sal_cierres c,
       ta_cta_tarjetas t,
       gv_ope_clientes_his a
 where t.nro_cuenta = c.nro_cuenta
   and t.nro_cuenta = a.nro_cuenta
union
--- Q_AH_CTA_CERTIFICADOS
select a.pais, tip_doc, a.nro_documento, a.tip_operacion, a.cod_mon_bco_central, a.moneda, a.rubro_bcp,
       t.nro_cuenta, to_char(t.fec_apertura,'yyyymmdd') fec_contabilizacion,
       FUG_OBT_VAL_TASA(t.cod_modulo,
                        t.cod_modalidad,
                        t.cod_oficina,
                        t.nro_cuenta,
                        t.cod_moneda,
                        t.capital,
                        t.tas_personalizada,
                        t.cod_tasa,
                        NULL,
                        t.fec_apertura) val_tasa,
       to_char(c.fec_vencimiento,'yyyymmdd') fec_vencimiento, to_char(c.fec_pago,'yyyymmdd') fec_ult_pago,
       case
          when c.fec_pago > c.fec_vencimiento then
  	            c.fec_pago - c.fec_vencimiento
          Else
  	            0
          End atraso,
       case
          when c.nro_cupon = (select nvl(count(x.nro_cupon),0)
                                from ah_cupones x
                               where c.nro_cuenta = x.nro_cuenta) then
               (nvl(t.capital, 0) + nvl(c.mto_interes,0))
          else
             nvl(c.mto_interes,0)
          end mto_cuota,
       case
          when c.nro_cupon = (select nvl(count(x.nro_cupon),0)
                                from ah_cupones x
                               where c.nro_cuenta = x.nro_cuenta) then
  	            t.capital
          else
  	            0
          end mto_capital,
       nvl(c.mto_interes,0) mto_interes,
       0 sal_capital,
       0 sal_interes,
       case
          when c.nro_cupon = (select nvl(count(x.nro_cupon),0)
                                from ah_cupones x
                               where c.nro_cuenta = x.nro_cuenta) then
               decode(t.fec_pago, null, t.capital, 0)
          else
             0
          end saldo_pagar_capital,
       case
          when c.fec_pago is null AND c.ESTADO != 'P' then
  	            c.mto_interes
          else
  	            0
          end saldo_pagar_interes,
       case
          when c.fec_pago > c.fec_vencimiento then
  	            '2'
          else
               '1'
          end estado_sit,
       a.categoria, c.nro_cupon nro_cuota, a.modalidad, a.cod_persona, t.fec_apertura fec_inicio
  from ah_cupones c,
       ah_cta_certificados t,
       gv_ope_clientes_his a
 where t.nro_cuenta = c.nro_cuenta
   and t.nro_cuenta = a.nro_cuenta
   and a.fec_operacion = (select min(det.fecha)
                            from sb_crc_operaciones_det det
                           where a.nro_cuenta = nvl(substr(det.nro_operacion,1,INSTR(det.nro_operacion,'#')-1),det.nro_operacion))
union
--- Movimientos sobregiros
select a.pais, tip_doc, a.nro_documento, a.tip_operacion, a.cod_mon_bco_central, a.moneda, a.rubro_bcp,
       g.nro_cuenta, to_char(g.FECHA,'yyyymmdd') fec_contabilizacion,
       DECODE(g.COD_TRANSACCION,550,g.VAL_TASA,520,g.VAL_TASA,0) VAL_TASA,
       to_char(o.fecha_sobregiro,'yyyymmdd') fec_vencimiento, to_char(o.fec_liquidacion,'yyyymmdd') fec_ult_pago,
       o.dias_sobregiro atraso,
       nvl(o.saldo_sobregiro,0) mto_cuota,
       nvl(o.saldo_sobregiro,0) mto_capital,
       round(((nvl(o.saldo_sobregiro,0) * nvl(DECODE(g.COD_TRANSACCION,550,g.VAL_TASA,520,g.VAL_TASA,0),0))/36500),
             decode(g.cod_moneda,'GS',0,2)) mto_interes,
       decode(o.dias_sobregiro,null,o.saldo_sobregiro,0) sal_capital,
       decode(o.dias_sobregiro,null,
       round(((nvl(o.saldo_sobregiro,0) * nvl(DECODE(g.COD_TRANSACCION,550,g.VAL_TASA,520,g.VAL_TASA,0),0))/36500),
             decode(g.cod_moneda,'GS',0,2)),0) sal_interes,
       0 saldo_pagar_capital, 0 saldo_pagar_interes,
       fuc_est_sit_sobregiro(o.dias_sobregiro) estado_sit,
       a.categoria, null nro_cuota, a.modalidad, a.cod_persona, g.FECHA fec_inicio
  FROM CC_MOVIMIENTOS_HIS g, gv_ope_clientes_his a, gv_ope_sobregiros_his o
 WHERE g.COD_TRANSACCION IN (520,550)
   and g.nro_cuenta = a.nro_cuenta
   and a.nro_cuenta = o.nro_cuenta
   and g.fecha = o.fec_liquidacion
   and a.fec_operacion = (select min(det.fecha)
                            from sb_crc_operaciones_det det
                           where a.nro_cuenta = nvl(substr(det.nro_operacion,1,INSTR(det.nro_operacion,'#')-1),det.nro_operacion)
                             and substr(det.cta_con_cap_original,1,1) = 1)
UNION
select a.pais, tip_doc, a.nro_documento, a.tip_operacion, a.cod_mon_bco_central, a.moneda, a.rubro_bcp,
       g.nro_cuenta, to_char(g.FECHA,'yyyymmdd') fec_contabilizacion,
       DECODE(g.COD_TRANSACCION,550,g.VAL_TASA,520,g.VAL_TASA,0) VAL_TASA,
       to_char(o.fecha_sobregiro,'yyyymmdd') fec_vencimiento, to_char(o.fec_liquidacion,'yyyymmdd') fec_ult_pago,
       o.dias_sobregiro atraso,
       nvl(o.saldo_sobregiro,0) mto_cuota,
       nvl(o.saldo_sobregiro,0) mto_capital,
       round(((nvl(o.saldo_sobregiro,0) * nvl(DECODE(g.COD_TRANSACCION,550,g.VAL_TASA,520,g.VAL_TASA,0),0))/36500),
             decode(g.cod_moneda,'GS',0,2)) mto_interes,
       decode(o.dias_sobregiro,null,o.saldo_sobregiro,0) sal_capital,
       decode(o.dias_sobregiro,null,
       round(((nvl(o.saldo_sobregiro,0) * nvl(DECODE(g.COD_TRANSACCION,550,g.VAL_TASA,520,g.VAL_TASA,0),0))/36500),
             decode(g.cod_moneda,'GS',0,2)),0) sal_interes,
       0 saldo_pagar_capital, 0 saldo_pagar_interes,
       fuc_est_sit_sobregiro(o.dias_sobregiro) estado_sit,
       a.categoria, null nro_cuota, a.modalidad, a.cod_persona, g.FECHA fec_inicio
  FROM GE_MOVIMIENTOS g, gv_ope_clientes_his a, gv_ope_sobregiros_his o
 WHERE g.COD_TRANSACCION IN (520,550)
   and g.nro_cuenta = a.nro_cuenta
   and a.nro_cuenta = o.nro_cuenta
   and g.fecha = o.fec_liquidacion
   and a.fec_operacion = (select min(det.fecha)
                            from sb_crc_operaciones_det det
                           where a.nro_cuenta = nvl(substr(det.nro_operacion,1,INSTR(det.nro_operacion,'#')-1),det.nro_operacion)
                             and substr(det.cta_con_cap_original,1,1) = 1)
;


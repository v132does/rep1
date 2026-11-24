CREATE OR REPLACE FORCE VIEW IT.BV_LIQ_CARTERAS_HIS AS
SELECT decode(c.cod_moneda, 'GS',m.cod_mon_bco_central,'6100') moneda,
--                     substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
                     substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',
                     case
                     when c.tip_saldo = 'A' then -- A devengar
                          ct.val_int_devengar*-1
                     when c.tip_saldo = 'L' then -- valuacion
                          ct.mto_valuacion*-1
                     when c.tip_saldo='V' then --- prevision
                          ct.mto_prevision*-1
                     when c.tip_saldo in ('C','F') then -- capital
                          ct.sal_capital
                     when c.tip_saldo = 'I' then -- interes
                          ct.sal_interes
                     else d.sal_actual end
                     )
               else (case
                     when c.tip_saldo = 'A' then -- A devengar
                          ct.val_int_devengar*-1
                     when c.tip_saldo = 'L' then -- valuacion
                          ct.mto_valuacion*-1
                     when c.tip_saldo='V' then --- prevision
                          ct.mto_prevision*-1
                     when c.tip_saldo in ('C','F') then -- capital
                          ct.sal_capital
                     when c.tip_saldo = 'I' then -- interes
                          ct.sal_interes
                     else d.sal_actual end)
               end) monto,
               d.nro_cuenta cuenta,
               -- Prestamos Vistas van A la vista en base a pedido de Carlos Cabrera 26/08/2011
              (case when pr.cod_modalidad in (675,677) then 1 else (nvl(ct.fec_vencimiento,pag_cal.FU_OBT_FEC_ACTUAL(2))  - pag_cal.FU_OBT_FEC_ACTUAL(2)) end) dias,
              c.cod_modulo,
              c.cod_modalidad,
              g.cod_persona,
              c.tip_saldo,
              (nvl(ct.fec_vencimiento,pag_cal.FU_OBT_FEC_ACTUAL(2))  - pag_cal.FU_OBT_FEC_ACTUAL(2)) dias_real
 FROM cb_sal_inventarios_det_his d,
      cb_sal_inventarios_his     c,
      cb_rubros                  r,
      ba_monedas                 m,
      ge_clientes                g,
      ge_cta_clientes            ge,
      pr_cta_prestamos           pr,
      sb_liq_cuotas              ct
WHERE c.nro_referencia = d.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  and pr.est_batch in ('C','A')
  AND c.cod_modulo = 6
  AND c.tip_saldo in ('C','F','A','I','L','V','D') -- Capital: CF, A Devengar: A, Interes: I, Valuacion: L, Prevision: V
  and substr(r.cod_rub_padre,1,2) <> '16' -- Vencidas no se informa
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND ge.relacion = 'P'
  AND nvl(d.sal_actual, 0) != 0
  AND c.cod_rubro IS NOT NULL
  AND d.nro_cuenta = pr.nro_cuenta
  and pr.nro_cuenta=ct.nro_cuenta
  AND ct.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha

UNION ALL

--CTA.CTE--
SELECT decode(c.cod_moneda, 'GS', m.cod_mon_bco_central,'6100') moneda,
---                     substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
                     substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',d.sal_actual)
                else d.sal_actual end) monto,
               d.nro_cuenta cuenta,
                0 dias,
                c.cod_modulo,
                c.cod_modalidad,
                g.cod_persona,
                c.tip_saldo,
                0 dias_real

 FROM cb_sal_inventarios_det_his     d,
      cb_sal_inventarios_his         c,
      cb_rubros                  r,
      ba_monedas                 m,
      ge_clientes                g,
      ge_cta_clientes            ge
WHERE d.nro_referencia = c.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  AND c.cod_modulo = 4
  AND c.cod_modalidad = 41
  AND c.tip_saldo in ('C','T') -- Solo capital y regularizadora de Pignoración
  AND nvl(d.sal_actual, 0) != 0
  and substr(r.cod_rub_padre,1,2) <> '16' -- Vencidas No se informa
  AND c.cod_rubro IS NOT NULL
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND ge.relacion = 'P'
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha
UNION ALL

--AHORRO
SELECT decode(c.cod_moneda, 'GS', m.cod_mon_bco_central,'6100') moneda,
---             substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
                     substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',(case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end))
                else (case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end) end) monto,
               d.nro_cuenta cuenta,
               0 dias,
               c.cod_modulo,
               c.cod_modalidad,
               g.cod_persona,
               c.tip_saldo,
               0 dias_real
 FROM cb_sal_inventarios_det_his     d,
      cb_sal_inventarios_his         c,
      cb_rubros                  r,
      ba_monedas                 m,
      ge_clientes                g,
      ge_cta_clientes            ge
WHERE d.nro_referencia = c.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  AND c.cod_modulo = 3
  AND c.cod_modalidad = 31
  AND c.tip_saldo not in ('R','P','K') -- Sacar saldo retenido, pignoraciones
                                       --y cuentas de resultados por N.A.D. 08/05/2012
  AND nvl(d.sal_actual, 0) != 0
  AND c.cod_rubro IS NOT NULL
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND ge.relacion = 'P'
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha

UNION ALL

--AHORROS Y CTA.CTE--PIGNORACIONES -- Se hace en base al residual del Activo que avala en base a pedido de Carlos Cabrera 26/08/2011
SELECT decode(c.cod_moneda, 'GS', m.cod_mon_bco_central,'6100') moneda,
                       substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
---                     substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',d.sal_actual)
                else d.sal_actual end) monto,
               d.nro_cuenta cuenta,
               p.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2) dias,
               c.cod_modulo,
               c.cod_modalidad,
               g.cod_persona,
               c.tip_saldo,
               p.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2) dias_real
 FROM cb_sal_inventarios_det_his     d,
      cb_sal_inventarios_his         c,
      cb_rubros                  r,
      ba_monedas                 m,
      ge_clientes                g,
      ge_cta_clientes            ge,
      pr_gar_cash                P
WHERE d.nro_referencia = c.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  AND c.cod_modulo in (3, 4)
  and c.cod_modalidad in (31,41)
  AND c.tip_saldo in ('P') -- Pignoraciones
  AND nvl(d.sal_actual, 0) != 0
  and substr(r.cod_rub_padre,1,2) <> '16' -- Vencidas No se informa
  AND c.cod_rubro IS NOT NULL
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND ge.relacion = 'P'
  AND d.nro_cuenta = p.nro_cta_referencia
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha

UNION ALL
--C.D.A
SELECT decode(c.cod_moneda,'GS',m.cod_mon_bco_central,'6100') moneda,
---                     substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
                       substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',(case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end))
                else (case when c.tip_saldo in ('A','L','V') then d.sal_actual*-1 else d.sal_actual end) end) monto,
               d.nro_cuenta cuenta,
               decode(substr(r.cod_rubro,6,3),'138',0,a.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2)) dias,
               c.cod_modulo,
               c.cod_modalidad,
               g.cod_persona,
               c.tip_saldo,
               decode(substr(r.cod_rubro,6,3),'138',0,a.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2)) dias_real
FROM cb_sal_inventarios_det_his     d,
    cb_sal_inventarios_his         c,
    cb_rubros                  r,
    ba_monedas                 m,
    ge_clientes                g,
    ge_cta_clientes            ge,
    ah_cta_certificados        a
WHERE d.nro_referencia = c.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  AND c.cod_modulo = 3
  AND c.cod_modalidad not in (31)
  AND c.tip_saldo in ('C','P','T') -- Capital: C, Pignoración: PT, A Devengar: A
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND nvl(d.sal_actual, 0) != 0
  AND ge.relacion = 'P'
  AND c.cod_rubro IS NOT NULL
  AND d.nro_cuenta = a.nro_cuenta
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha
UNION ALL
--- CDA Intereses
SELECT decode(c.cod_moneda,'GS',m.cod_mon_bco_central,'6100') moneda,
---                     substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
                       substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',
                     case when c.tip_saldo = 'A' then decode(cu.val_int_devengar,0,cu.sal_interes*-1,cu.val_int_devengar*-1)
                     else cu.sal_interes end )
                else (case when c.tip_saldo = 'A' then decode(cu.val_int_devengar,0,cu.sal_interes*-1,cu.val_int_devengar*-1)
                     else cu.sal_interes end)  end) monto,
               d.nro_cuenta cuenta,
               cu.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2) dias,
               c.cod_modulo,
               c.cod_modalidad,
               g.cod_persona,
               c.tip_saldo,
               cu.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2) dias_real
FROM cb_sal_inventarios_det_his     d,
    cb_sal_inventarios_his         c,
    cb_rubros                  r,
    ba_monedas                 m,
    ge_clientes                g,
    ge_cta_clientes            ge,
    ah_cta_certificados        a,
    sb_liq_cuotas              cu
WHERE d.nro_referencia = c.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  AND c.cod_modulo = 3
  AND c.cod_modalidad not in (31)
  AND c.tip_saldo in ('A', 'I')  -- A devengar e Interés
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND nvl(d.sal_actual, 0) != 0
  AND ge.relacion = 'P'
  AND c.cod_rubro IS NOT NULL
  AND d.nro_cuenta = a.nro_cuenta
  AND a.nro_cuenta=cu.nro_cuenta
  AND cu.fecha=pag_cal.fu_obt_fec_actual(2)
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha
UNION ALL
--- MESA DE DINERO
SELECT decode(c.cod_moneda,'GS',m.cod_mon_bco_central,'6100') moneda,
---                     substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
                       substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',
                     case when c.tip_saldo = 'A' then sal_actual*-1
                     else sal_actual end )
                else (case when c.tip_saldo = 'A' then sal_actual*-1
                     else sal_actual end)  end) monto,
               d.nro_cuenta cuenta,
               a.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2) dias,
               c.cod_modulo,
               c.cod_modalidad,
               g.cod_persona,
               c.tip_saldo,
               a.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2) dias_real
FROM cb_sal_inventarios_det_his     d,
    cb_sal_inventarios_his         c,
    cb_rubros                  r,
    ba_monedas                 m,
    ge_clientes                g,
    ge_cta_clientes            ge,
    md_cta_documentos        a
WHERE d.nro_referencia = c.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  AND c.cod_modalidad in (112, 117,118, 144,145,126)
  AND c.tip_saldo in ('C', 'A', 'I')  -- Capital, A devengar e Interés
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND nvl(d.sal_actual, 0) != 0
  AND ge.relacion = 'P'
  AND c.cod_rubro IS NOT NULL
  AND d.nro_cuenta = a.nro_cuenta
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha
UNION ALL
--- Tarjetas
SELECT decode(c.cod_moneda,'GS',m.cod_mon_bco_central,'6100') moneda,
---                     substr(r.cod_rub_padre,1,2)||'0000000000000' cuentas,
                       substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
               (case when c.cod_moneda not in ('GS', 'USD') then
                     FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',
                     case when c.tip_saldo = 'V' then sal_actual*-1
                     else sal_actual end )
                else (case when c.tip_saldo = 'V' then sal_actual*-1
                     else sal_actual end)  end) monto,
               d.nro_cuenta cuenta,
               decode(nvl(a.dia_mora,0),0,a.fec_vct_ult_cierre,pag_cal.fu_obt_fec_actual(2)-a.dia_mora-1) - pag_cal.FU_OBT_FEC_ACTUAL(2) dias,
               c.cod_modulo,
               c.cod_modalidad,
               g.cod_persona,
               c.tip_saldo,
               decode(nvl(a.dia_mora,0),0,a.fec_vct_ult_cierre,pag_cal.fu_obt_fec_actual(2)-a.dia_mora-1) - pag_cal.FU_OBT_FEC_ACTUAL(2) dias_real
FROM cb_sal_inventarios_det_his     d,
    cb_sal_inventarios_his         c,
    cb_rubros                  r,
    ba_monedas                 m,
    ge_clientes                g,
    ge_cta_clientes            ge,
    ta_cta_tarjetas        a
WHERE d.nro_referencia = c.nro_referencia
  AND c.cod_rubro = r.cod_rubro
  AND c.cod_moneda = m.cod_moneda
  AND c.tip_saldo in ('C', 'V') -- Capital y previsiones
  and substr(r.cod_rub_padre,1,2) not in ( '16','25') -- Vencidas no se informa
  AND ge.nro_cuenta = d.nro_cuenta
  AND g.cod_persona = ge.cod_persona
  AND nvl(d.sal_actual, 0) != 0
  AND ge.relacion = 'P'
  AND c.cod_rubro IS NOT NULL
  AND d.nro_cuenta = a.nro_cuenta
  AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
  AND d.fecha=c.fecha
;


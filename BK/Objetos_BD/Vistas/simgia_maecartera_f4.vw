CREATE OR REPLACE FORCE VIEW IT.SIMGIA_MAECARTERA_F4 AS
select to_char(pag_cal.fu_obt_fec_actual(8), 'DDMMYY') fecha,
      0 SUCURSALFU,
      '0' NURIES,
      0 PROPUESTA,
      '0' CONGRU,
      0 NUDOC,
      0 GUARANIES,
      0 CONTRAVALO,
      0 IADDIVISA,
      '0' VENCIM,
      0 CODTASA,
      0 NROLIBRADO,
      0 CTADOCACT, --Frances P y Aleman F
      '0' rubro_act,
      0 CTADOCPAS, --Frances P y Aleman F
      '0' rubro_pas,
      '0' FILLER,

      0 TIPOD,
      to_char(pag_cal.fu_obt_fec_actual(1), 'DDMMYY') FECHAEMISI,
      0 SUCURSALCU,
      0 GASTOSGC,
      '0' VCTOINT,
      0 IADMONTODC,
      0 IADSALDOCP,
      0 IADMETODO,
      0 IADFEINI,
      0 IADDIAS,
      0 IADINTERES, --mto interes
      0 IADADEV, --mto a devengar
      0 IADNROCUO,
      0 IADCODTASA,
      0 CTANDOCACT,
      0 CTANDOCORD,
      0 CTANDOCORH,
      '0' rubro,
      0 transaccion,
      0 transaccion2,
      0 transaccion3,
      0 modalidad,
      '0' tip_amortizacion,
      '0' cod_moneda,
      '0' cat_riesgo,
      '0' nro_cuenta,
      0 cod_ori_fondo,
      '0' tipo,
      '0' rubro_susp
from dual

UNION ALL

select to_char(pag_cal.fu_obt_fec_actual(8), 'DDMMYY') fecha,
      sucursal SUCURSALFU,
      cliente NURIES,
      nvl(to_number(substr(nro_cuenta,-6)),0) PROPUESTA,
      nvl(c.cod_rub_externo, decode(nro_cuenta,'1666067636','169502504718',0)) CONGRU, --nvl(c.cod_rub_externo,0) CONGRU,
      rownum NUDOC, --se toman los últimos 6 dígitos de la cuenta para adecuar al tamaño del archivo
      importe_ml GUARANIES,
      --0 intereses,
      importe_me CONTRAVALO,
      decode(b.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                 'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28) IADDIVISA,
      to_char(fec_vencimiento, 'YYYYMMDD') VENCIM,
      nvl(val_tasa,0) CODTASA,
      0 NROLIBRADO,
      decode(tip_amortizacion, 'F', 0, decode(b.tipo,'afd2',0, nvl(PAI_INT.fu_obt_cta_contable(rubro_act),0))) CTADOCACT, --Frances P y Aleman F
      rubro_act,
      decode(tip_amortizacion, 'F', 0, decode(b.tipo,'afd2',0, nvl(PAI_INT.fu_obt_cta_contable(rubro_pas),0))) CTADOCPAS, --Frances P y Aleman F
      rubro_pas,
      nro_cuenta FILLER,
      --nuevos campos en la vista 20100617 na
      0 TIPOD,
      to_char(b.fec_inicio, 'DDMMYY') FECHAEMISI,
      decode(b.cod_modalidad,675,b.cod_modalidad,0) SUCURSALCU,
      nvl(gastos,0) GASTOSGC,
      decode(b.tipo, 'ope_vencidas', '0', to_char(fec_vencimiento, 'YYMMDD')) VCTOINT,
      0 IADMONTODC,
      0 IADSALDOCP,
      0 IADMETODO,
      0 IADFEINI,
      0 IADDIAS,
      nvl(mto_interes,0) IADINTERES, --mto interes
      nvl(mto_adev,0) IADADEV, --mto a devengar
      0 IADNROCUO,
      0 IADCODTASA,
      nvl(dev_suspenso,0) CTANDOCACT,
      to_number( nvl(tip_interes,0) || nvl(destino,0)) CTANDOCORD,
      nvl(nro_cuota,0) CTANDOCORH,
      rubro,
      transaccion,
      transaccion2,
      transaccion3,
      b.cod_modalidad modalidad,
      b.tip_amortizacion,
      b.cod_moneda,
      cat_riesgo,
      b.nro_cuenta,
      b.cod_ori_fondo,
      b.tipo,
       nvl(PAI_INT.fu_obt_cta_contable(b.rubro_susp),0)
from cb_rubros c,
      (
-----------------

      /*Prestamos*/
       select pcp.nro_cuenta,
       pcp.cod_modalidad,
       pcp.cod_oficina sucursal,
       nvl(solic.tip_amortizacion,'F') tip_amortizacion,
       gccli.cod_persona as cliente,
       fub_obt_rub_transaccion(pcp.cod_modulo,
                         pcp.cod_modalidad,
                         case
                         when (fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,pcp.cod_moneda,null,null) <> pcp.cod_ori_fondo
                            and pcp.por_ori_fondo = 100 ) then

                              fup_obt_transaccion('CA',pcp.estado, pcp.tipo, pcp.tip_interes, pcp.nro_cuenta, pcp.cod_ori_fondo, null)
                         else
                              PAP_PRE.FU_OBT_TRA_CONCEPTO('CA',pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion)
                         end , --codigo transaccion
                         pcp.cod_moneda,
                         gccli.cod_persona,
                         fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                         'C',
                         pcp.estado,
                         pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro,

      case
      when (fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,pcp.cod_moneda,null,null) <> pcp.cod_ori_fondo and pcp.por_ori_fondo <> 100 ) then
         decode(pcp.cod_moneda,
           'GS',
           (cuo.sal_capital - round(cuo.sal_Capital * pcp.por_ori_fondo / 100,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,pcp.cod_modalidad, pcp.cod_moneda))) ,
           pag_gen.FU_CON_MON_A_MONEDA(pcp.cod_moneda,'GS', (cuo.sal_capital - round(cuo.sal_Capital * pcp.por_ori_fondo / 100,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,pcp.cod_modalidad, pcp.cod_moneda)))))
      else
         decode(pcp.cod_moneda,'GS',cuo.sal_capital, pag_gen.FU_CON_MON_A_MONEDA(pcp.cod_moneda,'GS',cuo.sal_capital))
      end importe_ml, --en moneda local


      decode(pcp.cod_moneda, 'GS',0,
      case
      when (fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,pcp.cod_moneda,null,null) <> pcp.cod_ori_fondo and pcp.por_ori_fondo <> 100 ) then
           (cuo.sal_capital - round(cuo.sal_Capital * pcp.por_ori_fondo / 100,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,pcp.cod_modalidad, pcp.cod_moneda)))
      else
           cuo.sal_capital
      end
      ) importe_me,

      pcp.cod_moneda,
      cuo.fec_vencimiento fec_vencimiento,
      case
      when (fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,pcp.cod_moneda,null,null) <> pcp.cod_ori_fondo and pcp.por_ori_fondo = 100 ) then

           fup_obt_transaccion('CA',pcp.estado, pcp.tipo, pcp.tip_interes, pcp.nro_cuenta, pcp.cod_ori_fondo, null)
       else
           PAP_PRE.FU_OBT_TRA_CONCEPTO('CA',pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion)
       end transaccion,
      --pcp.nro_solicitud
      fub_obt_rub_transaccion(pcp.cod_modulo,
                         pcp.cod_modalidad,
                         PAP_PRE.FU_OBT_TRA_CONCEPTO(case when pcp.tip_interes = 'V' then 'IN' when pcp.tip_interes = 'A' then 'AI' end,pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion), --codigo transaccion
                         pcp.cod_moneda,
                         gccli.cod_persona,
                         fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                         'C',
                         pcp.estado,
                         pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro_act,
       PAP_PRE.FU_OBT_TRA_CONCEPTO(case when pcp.tip_interes = 'V' then 'IN' when pcp.tip_interes = 'A' then 'AI' end,pcp.estado,pcp.tipo,pcp.tip_interes,pcp.tip_renovacion) transaccion2, --codigo transaccion
       fub_obt_rub_transaccion(pcp.cod_modulo,
                         pcp.cod_modalidad,
                         903, --codigo transaccion
                         pcp.cod_moneda,
                         gccli.cod_persona,
                         fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                         'D',
                         pcp.estado,
                         pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro_pas,
        903 transaccion3,
        pcp.usu_insercion,
        pcp.nro_solicitud,
        pcp.fec_inicio,
        cuo.nro_cuota,
        (select sum(pag_gen.FU_CON_MON_A_MONEDA(ga.cod_moneda,pcp.cod_moneda,ga.monto))
        from pr_cta_gastos ga
        where ga.cod_transaccion not in (1520,1521)
        and ga.nro_cuenta = pcp.nro_cuenta) gastos,
        decode(solic.tip_amortizacion,'P',(nvl(cuo.sal_interes,0) + nvl(cuo.sal_int_documentado,0)),0) mto_interes,
        decode(solic.tip_amortizacion,'P',((nvl(cuo.sal_interes,0) + nvl(cuo.sal_int_documentado,0)) - (nvl(cuo.dev_no_cobrado,0) + nvl(cuo.dev_suspenso,0))),0) mto_adev,
        gecli.cat_riesgo,
        case
        when (fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,pcp.cod_moneda,null,null) <> pcp.cod_ori_fondo ) then
        'prestamo'
        else
        'afd1'
        end tipo,
        cuo.dev_suspenso,
        pcp.cod_ori_fondo,
        pcp.val_tasa,
        decode(pcp.tip_destino, 3,3,4,2,1) destino,
        decode(pcp.tip_interes,'A',1,'V',2) tip_interes,
        fub_obt_rub_transaccion(pcp.cod_modulo,
           pcp.cod_modalidad,
           947, --codigo transaccion
           pcp.cod_moneda,
           gccli.cod_persona,
           fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
           'C',
           pcp.estado,
           pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro_susp

  from pr_cta_prestamos pcp, pr_cuotas cuo, ge_cta_clientes gccli, pr_solicitudes solic, ge_clientes gecli
  where pcp.nro_cuenta = cuo.nro_cuenta and pcp.nro_cuenta = gccli.nro_cuenta
  and pcp.nro_solicitud=solic.nro_solicitud(+)
  and gecli.cod_persona = gccli.cod_persona
  --Frances P y Aleman F o C
  and (solic.tip_amortizacion = 'P' or (solic.tip_amortizacion = 'F' and cuo.sal_capital > 0 ) or (solic.tip_amortizacion = 'C' and cuo.sal_capital > 0 ) or solic.tip_amortizacion is null)
  and gccli.relacion = 'P'
  and cuo.estado <> 'N'
  and pcp.estado not in ('I','N')

  UNION ALL

  /* AFD */
  select pcp.nro_cuenta,
       pcp.cod_modalidad,
       pcp.cod_oficina sucursal,
       solic.tip_amortizacion,
       gccli.cod_persona as cliente,
       fub_obt_rub_transaccion(pcp.cod_modulo,
                         pcp.cod_modalidad,
                         fup_obt_transaccion('CA',pcp.estado, pcp.tipo, pcp.tip_interes, pcp.nro_cuenta, pcp.cod_ori_fondo, null), --codigo transaccion
                         pcp.cod_moneda,
                         gccli.cod_persona,
                         fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                         'C',
                         pcp.estado,
                         pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro,


      round(nvl(cuo.sal_capital,0) * nvl(pcp.por_ori_fondo,0) / 100,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,pcp.cod_modalidad, pcp.cod_moneda)) importe_ml, --en moneda local

      decode(pcp.cod_moneda, 'GS',0,round(nvl(cuo.sal_capital,0) * nvl(pcp.por_ori_fondo,0) / 100,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,pcp.cod_modalidad, pcp.cod_moneda))) importe_me,

      pcp.cod_moneda,
      cuo.fec_vencimiento fec_vencimiento,
      fup_obt_transaccion('CA',pcp.estado, pcp.tipo, pcp.tip_interes, pcp.nro_cuenta, pcp.cod_ori_fondo, null) transaccion,
      --pcp.nro_solicitud
      '0' rubro_act,
      0 transaccion2, --codigo transaccion
      '0' rubro_pas,
      0 transaccion3,
        pcp.usu_insercion,
        pcp.nro_solicitud,
        pcp.fec_inicio,
        cuo.nro_cuota,
        0 gastos,
        0 mto_interes,
        0 mto_adev,
        gecli.cat_riesgo,
        'afd2' tipo,
        cuo.dev_suspenso,
        pcp.cod_ori_fondo,
        pcp.val_tasa,
        decode(pcp.tip_destino, 3,3,4,2,1) destino,
        decode(pcp.tip_interes,'A',1,'V',2) tip_interes,
        fub_obt_rub_transaccion(pcp.cod_modulo,
           pcp.cod_modalidad,
           947, --codigo transaccion
           pcp.cod_moneda,
           gccli.cod_persona,
           fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
           'C',
           pcp.estado,
           pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro_susp

  from pr_cta_prestamos pcp, pr_cuotas cuo, ge_cta_clientes gccli, pr_solicitudes solic, ge_clientes gecli
  where pcp.nro_cuenta = cuo.nro_cuenta and pcp.nro_cuenta = gccli.nro_cuenta
  and pcp.nro_solicitud=solic.nro_solicitud
  and gecli.cod_persona = gccli.cod_persona
  --Frances P y Aleman F o C
  and (solic.tip_amortizacion = 'P' or (solic.tip_amortizacion = 'F' and cuo.sal_capital > 0 ) or (solic.tip_amortizacion = 'C' and cuo.sal_capital > 0 ))
  and gccli.relacion = 'P'
  and cuo.estado <> 'N'
  and pcp.cod_ori_fondo <> fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,pcp.cod_moneda,null,null)
  and pcp.por_ori_fondo <> 100
  and pcp.estado not in ('I','N')

  UNION ALL

  /* IVA */
  select pcp.nro_cuenta,
       pcp.cod_modalidad,
       pcp.cod_oficina sucursal,
       solic.tip_amortizacion,
       gccli.cod_persona as cliente,
       fub_obt_rub_transaccion(pcp.cod_modulo,
                         pcp.cod_modalidad,
                         708, --codigo transaccion
                         pcp.cod_moneda,
                         gccli.cod_persona,
                         fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                         'C',
                         pcp.estado,
                         pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro,
       decode(pcp.cod_moneda,'GS',nvl((select sum(round(p.mto_iva_imponible * (fug_obt_val_tasa(pcp.cod_modulo,pcp.cod_modalidad,pcp.cod_oficina,null,
       pcp.cod_moneda,0,'N',null,708,pag_cal.fu_obt_fec_actual(6)) / 100),
       fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', pcp.cod_modulo, pcp.cod_modalidad, pcp.cod_moneda, pcp.cod_oficina)))
                           from pr_cuotas p
                           where p.nro_cuota > 0
                            and p.estado != 'N'
                            and p.nro_cuenta = pcp.nro_cuenta
                            and p.nro_cuota = cuo.nro_cuota
                            and nvl(p.mto_iva_imponible,0) > 0),0),
      pag_gen.FU_CON_MON_A_MONEDA(pcp.cod_moneda,'GS',nvl(( select sum(round(p.mto_iva_imponible * (fug_obt_val_tasa(pcp.cod_modulo,pcp.cod_modalidad,pcp.cod_oficina,null,
                            pcp.cod_moneda,0,'N',null,708,pag_cal.fu_obt_fec_actual(6)) / 100)
                            ,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', pcp.cod_modulo, pcp.cod_modalidad, pcp.cod_moneda, pcp.cod_oficina)))
                            from pr_cuotas p
                            where p.nro_cuota > 0
                            and p.estado != 'N'
                            and p.nro_cuenta = pcp.nro_cuenta
                            and p.nro_cuota = cuo.nro_cuota
                            and nvl(p.mto_iva_imponible,0) > 0),0))) importe_ml, --en moneda local
      decode(pcp.cod_moneda, 'GS',0,nvl((select sum(round(p.mto_iva_imponible * (fug_obt_val_tasa(pcp.cod_modulo,pcp.cod_modalidad,pcp.cod_oficina,null,
                            pcp.cod_moneda,0,'N',null,708,pag_cal.fu_obt_fec_actual(6)) / 100)
                            ,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', pcp.cod_modulo, pcp.cod_modalidad, pcp.cod_moneda, pcp.cod_oficina)))
                            from pr_cuotas p
                            where p.nro_cuota > 0
                            and p.estado != 'N'
                            and p.nro_cuenta = pcp.nro_cuenta
                            and p.nro_cuota = cuo.nro_cuota
                            and nvl(p.mto_iva_imponible,0) > 0),0)) importe_me,
      pcp.cod_moneda,
      cuo.fec_vencimiento fec_vencimiento,
      708 transaccion,---codigo transaccion
      --pcp.nro_solicitud
      '0' rubro_act,
       0 transaccion2,
      '0' rubro_pas,
       0 transaccion3,
        pcp.usu_insercion,
        pcp.nro_solicitud,
        pcp.fec_inicio,
        cuo.nro_cuota,
       0 gastos,
       0 mto_interes,
       0 mto_adev,
       gecli.cat_riesgo,
       'iva' tipo,
       0 dev_suspenso,
       0 cod_ori_fondo,
       0 val_tasa,
       0 destino,
       0 tip_interes,
       '0' rubro_susp
from pr_cta_prestamos pcp, pr_cuotas cuo, ge_cta_clientes gccli, pr_solicitudes solic, ge_clientes gecli
  where pcp.nro_cuenta = cuo.nro_cuenta
  and pcp.nro_cuenta = gccli.nro_cuenta
  and pcp.nro_solicitud=solic.nro_solicitud
  and gecli.cod_persona = gccli.cod_persona
  and gccli.relacion = 'P'
  and cuo.estado <> 'N'
  and nvl((select sum(round(p.mto_iva_imponible * (fug_obt_val_tasa(pcp.cod_modulo,pcp.cod_modalidad,pcp.cod_oficina,null,
                                pcp.cod_moneda,0,'N',null,708,pag_cal.fu_obt_fec_actual(6)) / 100),
                                fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', pcp.cod_modulo, pcp.cod_modalidad, pcp.cod_moneda, pcp.cod_oficina)))
                           from pr_cuotas p
                           where p.nro_cuota > 0
                            and p.estado != 'N'
                            and p.nro_cuenta = pcp.nro_cuenta
                            and p.nro_cuota = cuo.nro_cuota
                            and nvl(p.mto_iva_imponible,0) > 0),0) <> 0

    UNION ALL

    /* SEGUROS */
    select pcp.nro_cuenta,
       pcp.cod_modalidad,
       pcp.cod_oficina sucursal,
       solic.tip_amortizacion,
       gccli.cod_persona as cliente,
       fub_obt_rub_transaccion(pcp.cod_modulo,
                         pcp.cod_modalidad,
                         cod_transaccion, --codigo transaccion
                         pcp.cod_moneda,
                         gccli.cod_persona,
                         fug_obt_plz_contable(pcp.fec_vencimiento - pcp.fec_inicio),
                         'C',
                         pcp.estado,
                         pcp.tip_renovacion, gecli.cat_riesgo, pcp.tip_interes, pcp.tipo,null,pcp.cod_sec_credito) rubro,
     decode(pcp.cod_moneda,'GS',g.monto,
                         pag_gen.FU_CON_MON_A_MONEDA(pcp.cod_moneda,'GS',g.monto)) importe_ml, --en moneda local
     decode(pcp.cod_moneda, 'GS',0,g.monto) importe_me,----moneda extranjera

      pcp.cod_moneda,
      g.fec_ingreso,
      g.cod_transaccion transaccion,
      --pcp.nro_solicitud
      '0' rubro_act,
       0 transaccion2, --codigo transaccion
      '0' rubro_pas,
       0 transaccion3,
       pcp.usu_insercion,
       pcp.nro_solicitud,
       pcp.fec_inicio,
       0 nro_cuota,
       0 gastos,
       0 mto_interes,
       0 mto_adev,
       gecli.cat_riesgo,
       'seguro' tipo,
       0 dev_suspenso,
       0 cod_ori_fondo,
       0 val_tasa,
       0 destino,
       0 tip_interes,
       '0' rubro_susp
from pr_cta_prestamos pcp, ge_cta_clientes gccli, pr_solicitudes solic, ge_clientes gecli,
     ge_plz_contables d, pr_cta_gastos g
  where  pcp.nro_cuenta = gccli.nro_cuenta---ge-cta-cliente con ctaprestamo
  and g.nro_cuenta = pcp.nro_cuenta---gastos con prestamo
  and pcp.nro_solicitud = solic.nro_solicitud
  and gecli.cod_persona = gccli.cod_persona---ge-cliente con ge-cta-cliente
  and gccli.relacion = 'P'---ge-cta-cliente
  and pcp.est_batch != 'N'---prestamo
  and g.cod_transaccion in (1520,1521)---codigo transaccion
  and can_dias = (SELECT MIN(can_dias)---dias
                                    FROM ge_plz_contables pl
                                    WHERE can_dias >=pcp.fec_vencimiento - pcp.fec_inicio)
  and g.fec_ult_pago is null

UNION ALL

   /* md_cta_documentos */
   select mcdoc.nro_cuenta nro_cuenta,
      mcdoc.cod_modalidad,
      mcdoc.cod_oficina sucursal,
      ' ' tip_amortizacion,
      mcdoc.cod_persona cliente,

            fub_obt_rub_transaccion(mcdoc.cod_modulo,
                                                        mcdoc.cod_modalidad,
                                                         case
                                                           when mcdoc.cod_sit_contable=10000001 then 805
                                                           when mcdoc.cod_sit_contable<>10000001 then 711
                                                         end, /*codigo transaccion*/
                                                        mcdoc.cod_moneda,
                                                        gccli.cod_persona,
                                                        fug_obt_plz_contable(mcdoc.fec_vencimiento - mcdoc.fec_inicio),
                                                        'D',
                                                        mcdoc.estado, null, null, null, null,
                                                        mcdoc.cod_sit_contable) rubro,
             decode(mcdoc.cod_moneda, 'GS',decode(mcdoc.cod_modalidad,104,mcdoc.val_presente,monto),
                        pag_gen.FU_CON_MON_A_MONEDA(mcdoc.cod_moneda, 'GS', decode(mcdoc.cod_modalidad,104,mcdoc.val_presente,monto) )) importe_ml, --en moneda local
             decode(mcdoc.cod_moneda, 'GS',0, decode(mcdoc.cod_modalidad,104,mcdoc.val_presente,monto) ) importe_me,
             mcdoc.cod_moneda,
             fec_vencimiento,
             case
                 when mcdoc.cod_sit_contable=10000001 then 805
                 when mcdoc.cod_sit_contable<>10000001 then 711
             end transaccion,
      '0' rubro_act,
       0 transaccion2,
      '0' rubro_pas,
       0 transaccion3,
       mcdoc.usu_insercion,
       0 nro_solicitud,
       mcdoc.fec_inicio,
       0 nro_cuota,
       0 gastos,
       0 mto_interes,
       0 mto_adev,
       '0' cat_riesgo,
       'bonos' tipo,
       0 dev_suspenso,
       0 cod_ori_fondo,
       0 val_tasa,
       0 destino,
       0 tip_interes,
       '0' rubro_susp
      from md_cta_documentos mcdoc, ge_cta_clientes gccli
      where mcdoc.nro_cuenta = gccli.nro_cuenta
      and   gccli.relacion = 'P'
      and mcdoc.estado <> 'N'
      /*and  (mcdoc.cod_modalidad in (104,124) or (mcdoc.estado='C' and mcdoc.fec_ven_repo is not null))*/
      and  (mcdoc.cod_modalidad in (104,124) or mcdoc.val_bas_repo is null and mcdoc.fec_ven_repo is not null)

   UNION ALL

      ----operaciones vencidas
      select ov.nro_cuenta,
             ov.cod_modalidad,
             ov.cod_oficina sucursal,
             '0' tip_amortizacion,
             gecli.cod_persona as cliente,
             fub_obt_rub_transaccion(ov.cod_modulo,
                               ov.cod_modalidad,
                               decode(ov.estado,'I',959,711), --codigo transaccion
                               ov.cod_moneda,
                               gccli.cod_persona,
                               fug_obt_plz_contable(ov.fec_ini_mora - ov.fec_cam_estado),
                               'D',
                               ov.estado,
                               null /*pcp.tip_renovacion*/, gecli.cat_riesgo, null/*pcp.tip_interes*/, gecli.tipo,null,null/*pcp.cod_sec_credito*/) rubro,
             decode(ov.cod_moneda,'GS',nvl(ov.mto_origen,0),
             pag_gen.FU_CON_MON_A_MONEDA(ov.cod_moneda,'GS',nvl(ov.mto_origen,0)))importe_ml, --en moneda local
             decode(ov.cod_moneda, 'GS',0,nvl(ov.mto_origen,0)) importe_me,
             ov.cod_moneda,
             ov.fec_ini_mora fec_vencimiento,
             decode(ov.estado,'I',959,711)transaccion,---codigo transaccion
                '0' rubro_act,
             0 transaccion2,
             '0' rubro_pas,
             0 transaccion3,
             ov.usu_insercion,
             0 nro_solicitud,
             ov.fec_cam_estado as fec_inicio,--fecha inicio
             0 nro_cuota,
             nvl(ogg.saldo,0) gastos,
             0 mto_interes,
             0 mto_adev,
             gecli.cat_riesgo,
             'ope_vencidas' tipo,
             0 dev_suspenso,
             0 cod_ori_fondo,
             0 val_tasa,
             0 destino,
             0 tip_interes,
             '0' rubro_susp
      from ov_cta_vencidas ov, ge_cta_clientes gccli, ge_clientes gecli, ov_cta_gastos ogg
        where ov.nro_cuenta = gccli.nro_cuenta--vencidas con cta cliente
        and gecli.cod_persona=gccli.cod_persona--clientes con cta cliente
        and ov.nro_cuenta = ogg.nro_cuenta(+)---vencidas con gastos
        --and gccli.nro_cuenta=ogg.nro_cuenta ---cta cliente con gastos
        and gccli.relacion = 'P'

union all
        ----tarjetas monto utilizado
      select ta.nro_cuenta,
             ta.cod_modalidad,
             ta.cod_oficina sucursal,
             '0' tip_amortizacion,
             gecli.cod_persona as cliente,
             fub_obt_rub_transaccion(ta.cod_modulo,
                               ta.cod_modalidad,
                               decode(ta.cat_automatica,'1',decode(ta.cod_modalidad,55,1507,1506),'2',920,'3',926,'4',929,929), --codigo transaccion
                               ta.cod_moneda,
                               gccli.cod_persona,
                               1,
                               'D',
                               ta.estado,
                               null /*pcp.tip_renovacion*/, gecli.cat_riesgo, null/*pcp.tip_interes*/, gecli.tipo,null,null/*pcp.cod_sec_credito*/) rubro,
             --nvl(ta.sal_facturar,0)+nvl(ta.sal_facturado,0)+nvl(ta.sal_financiado,0)+nvl(ta.sal_cuo_pendientes,0) importe_ml, --en moneda local
             nvl(ta.sal_procesadora,0) importe_ml,
             0 importe_me,
             ta.cod_moneda,
             decode(nvl(ta.dia_mora,0),0,ta.fec_vct_ult_cierre,pag_cal.fu_obt_fec_actual(5)-ta.dia_mora-1) fec_vencimiento,
             decode(ta.cat_automatica,'1',decode(ta.cod_modalidad,55,1507,1506),'2',920,'3',926,'4',929,929) transaccion,---codigo transaccion
             '0' rubro_act,
             0 transaccion2,
             '0' rubro_pas,
             0 transaccion3,
             ta.usu_insercion,
             0 nro_solicitud,
             ta.fec_apertura as fec_inicio,--fecha inicio
             0 nro_cuota,
             0 gastos,
             0 mto_interes,
             0 mto_adev,
             gecli.cat_riesgo,
             'tarj_utilizado' tipo,
             0 dev_suspenso,
             0 cod_ori_fondo,
             nvl(ta.tas_financiacion,0) val_tasa,
             0 destino,
             0 tip_interes,
             --to_number(substr(ta.nro_cuenta,3,1)||substr(ta.nro_cuenta,5,5)) nro_tarjeta_as
             '0' rubro_susp
      from ta_cta_tarjetas ta, ge_cta_clientes gccli, ge_clientes gecli
        where ta.nro_cuenta = gccli.nro_cuenta--vencidas con cta cliente
        and gecli.cod_persona=gccli.cod_persona--clientes con cta cliente
        and gccli.relacion = 'P'
        -- and ta.estado <> 'C'
        and ((ta.estado = 'N') or (ta.estado = 'B' and nvl(ta.sal_procesadora,0) <> 0))

union all

      ----tarjetas monto no utilizado
      select ta.nro_cuenta,
             ta.cod_modalidad,
             ta.cod_oficina sucursal,
             '0' tip_amortizacion,
             gecli.cod_persona as cliente,
             '410106170200199' rubro,
             --(nvl(ta.lin_credito,0)+nvl(ta.lin_cuotas,0))-(nvl(ta.sal_facturar,0)+nvl(ta.sal_facturado,0)+nvl(ta.sal_financiado,0)+nvl(ta.sal_cuo_pendientes,0)) importe_ml, --en moneda local
             (nvl(ta.lin_credito,0)+nvl(ta.lin_cuotas,0))-nvl(ta.sal_procesadora,0) importe_ml,
             0 importe_me,
             ta.cod_moneda,
             ta.fec_vct_ult_cierre fec_vencimiento,
             0 transaccion,---codigo transaccion
             '0' rubro_act,
             0 transaccion2,
             '0' rubro_pas,
             0 transaccion3,
             ta.usu_insercion,
             0 nro_solicitud,
             ta.fec_apertura as fec_inicio,--fecha inicio
             0 nro_cuota,
             0 gastos,
             0 mto_interes,
             0 mto_adev,
             gecli.cat_riesgo,
             'tarj_noutilizado' tipo,
             0 dev_suspenso,
             0 cod_ori_fondo,
             0 val_tasa,
             0 destino,
             0 tip_interes,
             '0' rubro_susp
             --to_number(substr(ta.nro_cuenta,3,1)||substr(ta.nro_cuenta,5,5)) nro_tarjeta_as

      from ta_cta_tarjetas ta, ge_cta_clientes gccli, ge_clientes gecli
        where ta.nro_cuenta = gccli.nro_cuenta--vencidas con cta cliente
        and gecli.cod_persona=gccli.cod_persona--clientes con cta cliente
        and gccli.relacion = 'P'
        -- and ta.estado <> 'C'
        and ((ta.estado = 'N') or (ta.estado = 'B' and nvl(ta.sal_procesadora,0) <> 0))


  ) b
where c.cod_rubro(+) = b.rubro

UNION ALL

      /* COMEX vista de simgia basada en vista mi_interfaz_comex de IT */
    Select fecha,
      sucursal SUCURSALFU,
      riesgo NURIES,
      propue PROPUESTA,
      codigo CONGRU,
      rownum NUDOC,
      importe GUARANIES,
      montodivis CONTRAVALO,
      codivisa IADDIVISA,
      vencimiento VENCIM,
      doccodtasa CODTASA,
      docnrolibr NROLIBRADO,
      ctaintact CTADOCACT,
      '0' rubro_act,
      ctaintpas CTADOCPAS,
      '0' rubro_pas,
      replace(filler,CHR(59),'') FILLER,
      --nuevos campos en la vista 20100809 na
      0 TIPOD,
      '0' FECHAEMISI,
      0 SUCURSALCU,
      0 GASTOSGC,
      '0' VCTOINT,
      0 IADMONTODC,
      0 IADSALDOCP,
      0 IADMETODO,
      0 IADFEINI,
      0 IADDIAS,
      intereses IADINTERES, --mto interes
      0 IADADEV, --mto a devengar
      0 IADNROCUO,
      0 IADCODTASA,
      0 CTANDOCACT,
      0 CTANDOCORD,
      0 CTANDOCORH,
      '0' rubro,
      0 transaccion,
      0 transaccion2,
      0 transaccion3,
      0 modalidad,
      '' tip_amortizacion,
      '' cod_moneda,
      '0' cat_riesgo,
      replace(filler,CHR(59),'') nro_cuenta,
      0 cod_ori_fondo,
     'comex' tipo,
     '0' rubro_susp
from smg_interfaz_comex
;


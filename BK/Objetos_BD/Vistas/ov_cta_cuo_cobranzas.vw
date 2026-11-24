create or replace force view it.ov_cta_cuo_cobranzas as
Select e.nro_cuenta NRO_OPERACION,
       d.nro_cuota,
       to_char(d.fec_vencimiento, 'DD/MM/YYYY') FEC_VENCIMIENTO,
       to_char(d.fec_ult_pago, 'DD/MM/YYYY') fec_ult_pago,
       nvl(d.mto_capital, 0) as MTO_CAPITAL,
       nvl(d.sal_capital, 0) as SAL_CAPITAL,
       nvl(d.mto_interes, 0) + nvl(d.mto_int_documentado, 0) as MTO_INTERES,
       nvl(d.sal_interes, 0) + nvl(d.sal_int_documentado, 0) as SAL_INTERES,
       nvl(d.mto_int_descontado, 0) MTO_INT_DESCONTADO,
       nvl(d.dev_no_cobrado, 0) DEV_NO_COBRADO,
       nvl(d.dev_suspenso, 0) DEV_SUSPENSO,
       nvl(d.dev_acumulado, 0) DEV_ACUMULADO,
       r.cod_banco COD_BANCO,
       r.cta_libradora CTA_LIBRADORA,
       r.nro_cheque,
       to_char(t.fec_emision, 'DD/MM/YYYY') FEC_EMISION,
       nvl(t.monto, 0) MTO_CHEQUE,
       nvl(l.nom_librador,b.nom_completo) nom_librador,
       l.ape_librador,
       nvl(l.nro_documento, b.nro_documento) NRO_DOC_LIBRADOR,
       nvl(l.cod_tip_documento, b.cod_tip_documento) COD_TIP_DOC_LIBRADOR,
       l.cod_sexo SEXO_LIBRADOR,
       trim(x.denominacion) CTA_LIB_DENOMINACION,
       e.cod_oficina, t.cod_cau_devolucion
  from ge_che_custodias  t,
       pr_cta_prestamos  e,
       pr_cuotas         d,
       ba_personas       p,
       ge_cta_clientes   g,
       pr_rel_chq_lib    r,
       pr_chq_libradores b,
       (select a.cod_tip_documento,
               a.nro_documento,
               case
                 when b.tipo = 'F' then
                  trim(c.pri_nombre) || ' ' || trim(c.seg_nombre)
                 else
                  b.nom_completo
               end as nom_librador,
               trim(c.pri_apellido) || ' ' || trim(c.seg_apellido) as ape_librador,
               c.cod_sexo
          from pr_chq_libradores a,
               ba_personas       b,
               ba_per_fisicas    c,
               ba_per_juridicas  d
         where b.cod_tip_documento = a.cod_tip_documento
           and b.nro_documento = a.nro_documento
           and c.cod_persona(+) = b.cod_persona
           and d.cod_persona(+) = b.cod_persona) l,
       ge_clientes       c,
       ba_per_fisicas    f,
       ba_per_juridicas  j,
       pr_lib_cuentas    x
 where e.nro_cuenta = t.nro_referencia(+) -- por nro cuenta
   and e.nro_cuenta = g.nro_cuenta
   and g.relacion = 'P'
   and g.cod_persona = p.cod_persona
   and l.cod_tip_documento(+) = r.cod_tip_documento
   and l.nro_documento(+) = r.nro_documento
   and b.cod_tip_documento(+) = r.cod_tip_documento
   and b.nro_documento(+) = r.nro_documento
   and t.cod_banco = r.cod_banco(+)
   and t.nro_cheque = r.nro_cheque(+)
   and t.cta_libradora = r.cta_libradora(+)
   and g.cod_persona = c.cod_persona
   and g.cod_persona = f.cod_persona(+)
   and g.cod_persona = j.cod_persona(+)
   and e.nro_cuenta = d.nro_cuenta
   and d.nro_cuota <> 0
   and d.nro_cuenta = t.nro_referencia(+)
   and d.nro_cuota = t.nro_cuota(+)
   and t.cod_banco = x.cod_banco(+)
   and t.cta_libradora = x.nro_cuenta(+)
;


create or replace force view it.av_cda_devengados as
select 'AH_DEVENGADOS' tabla,
       dev.Fecha fecha,
       cta.cod_oficina cod_oficina,
       gmo.descripcion des_modalidad,
       dev.cod_moneda cod_moneda,
       dev.nro_cuenta Cuenta,
       cta.cod_modalidad,
       dev.val_tasa tasa,
       dev.fec_tasa fec_tasa,
       dev.can_dia_interes dias_interes,
       nvl(dev.sal_acumulado,0) sal_acumulado,
       nvl(dev.mto_interes,0) mto_interes,
       dev.dia_dev_anterior dia_dev_anterior,
       nvl(dev.mto_dev_anterior,0) mto_dev_anterior,
       dev.fec_inicio fec_inicio,
       nvl(dev.mto_dev_acumulado,0) mto_dev_acumulado,
       se.descripcion sec_contable,
       se.cod_sec_contable,
       cl.cod_tip_deudor,
       cta.fec_vencimiento,
       cta.fec_apertura,
       cta.est_batch
  from ah_cta_certificados cta,
       ge_modalidades gmo,
       ge_cta_clientes ct,
       ge_clientes cl,
       ge_sec_contables se,
       ah_devengados dev
 where dev.nro_cuenta   = cta.nro_cuenta
       and cta.cod_modulo   = gmo.cod_modulo
       and cta.cod_modalidad= gmo.cod_modalidad
       and dev.nro_cuenta = ct.nro_cuenta
       and ct.relacion = 'P'
       and ct.cod_persona = cl.cod_persona
       and cl.cod_sec_contable = se.cod_sec_contable
Union all
select 'AH_CTA_CERTIFICADOS',
       pag_cal.fu_obt_fec_actual(3) fecha,
       cta.cod_oficina oficina,
       gmo.descripcion des_modalidad,
       cd.cod_moneda moneda,
       cd.nro_cuenta Cuenta,
       cta.cod_modalidad,
       null tasa,
       null fec_tasa,
       0 dias_interes,
       nvl(cd.capital,0) sal_acumulado,
       0 mto_interes,
       0 dia_dev_anterior,
       0 mto_dev_anterior,
       null fec_inicio,
       0 mto_dev_acumulado,
       se.descripcion sec_contable,
       se.cod_sec_contable,
       cl.cod_tip_deudor,
       cta.fec_vencimiento,
       cta.fec_apertura,
       cd.est_batch
  from ah_cta_certificados cd,
       ge_cuentas cta,
       ge_modalidades gmo,
       ge_cta_clientes ct,
       ge_clientes cl,
       ge_sec_contables se
 where cd.nro_cuenta = cta.nro_cuenta
   and cd.est_batch not in ('A', 'V', 'T', 'C')
   and not exists (Select '1'
                     from ah_devengados dv
                    where dv.nro_cuenta = cd.nro_cuenta
                      and dv.fecha = pag_cal.fu_obt_fec_actual(3)
                   )
       and cta.cod_modulo = gmo.cod_modulo
       and cta.cod_modalidad= gmo.cod_modalidad
       and cd.nro_cuenta = ct.nro_cuenta
       and ct.relacion = 'P'
       and ct.cod_persona = cl.cod_persona
       and cl.cod_sec_contable = se.cod_sec_contable
       and cd.nro_certificado is not null;


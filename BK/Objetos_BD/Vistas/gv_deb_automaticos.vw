CREATE OR REPLACE FORCE VIEW IT.GV_DEB_AUTOMATICOS AS
SELECT pr.estado ESTADO_CTA_PRESTAMOS, to_number(pr.nro_cuenta) NRO_CUENTA_CTA_PRESTAMOS,
pr.nro_cta_debito NRO_CTA_DEBITO_CTA_PRESTAMOS
      FROM pr_cta_prestamos pr
      WHERE pr.nro_cta_debito = pr.nro_cta_debito
      and pr.estado != 'N'

      union all

      select sol.estado ESTADO_SOLICITUDES, sol.nro_solicitud NRO_SOLICITUD,
      sol.nro_cta_debito NRO_CTA_DEBITO_SOLICITUDES
        from pr_solicitudes sol
       where sol.nro_cta_debito = sol.nro_cta_debito
       and sol.estado in ('L','S')  -- (S)olicitada y Pendiente (L)iquidacion
       and sol.deb_automatico = 'S'

      union all

      select ta.estado ESTADO_TA_TARJETAS, to_number(ta.nro_cuenta) NRO_CUENTA_TA_TARJETAS, ta.nro_cta_debito NRO_CTA_DEBITOS_TA_TARJETAS
        from ta_cta_tarjetas ta
       where ta.nro_cta_debito = ta.nro_cta_debito
        and ta.estado != 'C'  -- Tarjetas no Canceladas

       union all

      select cer.estado ESTADO_CTA_CERTIFICADO, to_number(cer.nro_cuenta) NRO_CUENTA_CTA_CERTIFICADOS,
      cer.nro_cta_credito NRO_CTA_CREDITO_CERTIFICADOS
        from ah_cta_certificados cer
       where cer.nro_cta_credito = cer.nro_cta_credito
         and cer.estado not in ('T','C')

    union
      select cs.estado ESTADO_CONTRATOS, to_number(cs.nro_contrato) NRO_CONTRATO_CONTRATO, cs.nro_cta_debito NRO_CTA_DEBITO_CONTRATOS
        from cs_contratos cs
       where cs.nro_cta_debito = cs.nro_cta_debito
       and cs.estado not in ('C','R') -- (C)ancelados y (R)echazados
;


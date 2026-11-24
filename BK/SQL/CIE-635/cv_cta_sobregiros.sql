CREATE OR REPLACE VIEW IT.CV_CTA_SOBREGIROS AS
SELECT c.nro_cuenta, r.fecha, r.saldo, r.mto_linea, r.can_dia_sobregiro
  FROM cc_cta_corrientes c, cc_sobregiros r
 WHERE c.nro_cuenta = r.nro_cuenta
   AND c.cod_modulo = 4
   AND c.cod_modalidad = 41
   AND nvl(c.sal_total, 0) - nvl(c.sal_retenido, 0) - nvl(c.sal_bloqueado, 0) < 0
   AND c.estado <> 'C'
   AND length(r.nro_cuenta) > 0
   AND length(c.nro_cuenta) > 0
 ORDER BY 1, 2 DESC, 3 ASC;

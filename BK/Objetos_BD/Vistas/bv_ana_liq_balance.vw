CREATE OR REPLACE FORCE VIEW IT.BV_ANA_LIQ_BALANCE AS
SELECT '6100' moneda,
       --substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
       r.cod_rubro cuentas,
       (c.sal_mon_rub_ant+c.deb_mon_rubro-c.cre_mon_rubro) monto
 FROM cb_sal_consolidados c,
      cb_rubros                  r,
      ba_monedas                 m
WHERE c.cod_rubro = r.cod_rubro
  AND r.cod_moneda = m.cod_moneda
  AND c.cod_rubro IS NOT NULL
  AND r.nivel=5
  AND substr(c.cod_rubro,1,2) IN ('12','13','14','17','21','22')

union all

SELECT '6900' moneda,
       --substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
       r.cod_rubro cuentas,
       ((c.sal_mon_loc_ant+c.deb_mon_local-c.cre_mon_local)-(c.sal_equ_loc_ant+c.deb_equ_local-c.cre_equ_local)) monto
 FROM cb_sal_consolidados c,
      cb_rubros                  r,
      ba_monedas                 m
WHERE c.cod_rubro = r.cod_rubro
  AND r.cod_moneda = m.cod_moneda
  AND c.cod_rubro IS NOT NULL
  AND r.nivel=5
  AND substr(c.cod_rubro,1,2) IN ('12','13','14','17','21','22')
;


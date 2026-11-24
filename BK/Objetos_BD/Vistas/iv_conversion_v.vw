create or replace force view it.iv_conversion_v as
select rpad(a.cod_persona,10,' ')||--NU_CLTE,
       rpad(pai_dtm_t.FU_OBT_NRO_CTA_ANTERIOR(a.nro_cuenta,c.cod_moneda),30,' ')||-- NU_CTA_CLTE_ANT,
       rpad(a.nro_cuenta,30,' ')||--NU_CTA_CLTE_NVA,
       decode(pai_dtm.fu_obt_nom_cliente(a.cod_persona),
       null,rpad(' ',35,' ' ),
       rpad(pai_dtm.fu_obt_nom_cliente(a.cod_persona),35,' ') )||--NB_CLTE,
       '*'CADENA
from ge_cta_clientes a,ge_clientes b,ge_cuentas c,ba_personas d
where
b.cod_persona=a.cod_persona
and c.nro_cuenta=a.nro_cuenta
and a.cod_persona=d.cod_persona
and  a.cod_modalidad in(31,32,33,41)
and (a.cod_modalidad in(31,41)
  or (a.cod_modalidad in (32,33)
  and c.nro_cuenta = (select min(t.nro_cuenta) from ge_cta_clientes t, ge_cuentas e
                       where t.cod_persona = d.cod_persona
                         and t.nro_cuenta = e.nro_cuenta
                         and e.estado not in ('C','T','P','X','A'))))
and a.relacion='P'
and c.fec_apertura<=pai_dtm_t.fu_obt_fecha
and c.estado not in ('C','T','P','X','A')
/*and  (c.estado!='I'
or (c.estado='I'and exists(select * from gv_movimientos x
                                    where x.nro_cuenta=a.nro_cuenta
                                    and x.cod_tra_padre!=310
                                    and x.FECHA=pai_dtm_t.fu_obt_fecha)));*/
;


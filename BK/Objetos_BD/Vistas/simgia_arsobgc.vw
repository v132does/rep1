create or replace force view it.simgia_arsobgc as
select --min(ccso.fecha),
       nvl(substr(ccso.nro_cuenta, 1, 2), 0) SGCSUC,
       pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ccso.nro_cuenta, 3, 2),gcue.cod_moneda) SGCCTA,
       nvl(substr(ccso.nro_cuenta, 5, 6), 0)SGCSUB,
       --decode(nvl( cccor.dia_atraso,0), 0, 0, to_number(to_char((select t.fec_proxima from ge_calendarios t where t.cod_modulo = 1) - 1 - nvl(cccor.dia_atraso,0), 'ddmmyy')) ) SGCFEINI, --cambiado el 20100429, segun modif de IT
       decode(nvl( cccor.dia_atraso,0), 0, 0, to_number(to_char( pae_cnf.fu_obt_fec_actual(1) + 1 - nvl(cccor.dia_atraso,0), 'ddmmyy')) ) SGCFEINI,
       nvl((select a.sal_total from cc_sobregiros a where a.nro_cuenta = ccso.nro_cuenta and a.fecha = (select max(b.fecha) from cc_sobregiros b where b.nro_cuenta = ccso.nro_cuenta)) * -1,0)  SGCSDOACT,
       nvl(pai_int.fu_obt_cta_contable(fub_obt_rub_transaccion(gcue.cod_modulo,
                                                           gcue.cod_modalidad,
                                                           949, /*codigo transaccion*/
                                                           gcue.cod_moneda,
                                                           gccli.cod_persona,
                                                           fug_obt_plz_contable((select max(b.fecha) from cc_sobregiros b where b.nro_cuenta = ccso.nro_cuenta) - min(ccso.fecha)),
                                                           'D',/*(tipo movimiento)*/
                                                           gcue.estado)),0) SGCMAYOR,
       fub_obt_rub_transaccion(gcue.cod_modulo,
                                                           gcue.cod_modalidad,
                                                           949, /*codigo transaccion*/
                                                           gcue.cod_moneda,
                                                           gccli.cod_persona,
                                                           fug_obt_plz_contable((select max(b.fecha) from cc_sobregiros b where b.nro_cuenta = ccso.nro_cuenta) - min(ccso.fecha)),
                                                           'D',/*(tipo movimiento)*/
                                                           gcue.estado) rt,
       to_number(to_char((pae_cnf.fu_obt_fec_actual(1) - (nvl(cccor.dia_atraso,0)-1) + 60), 'ddmmyy'))  SGCFETRASP,
       'D' SGCVIA,
       gccli.cod_persona SGCRIESGO,
       0 SGCGRUPO,
       fub_obt_rub_transaccion(gcue.cod_modulo,
                                                           gcue.cod_modalidad,
                                                           949, /*codigo transaccion*/
                                                           gcue.cod_moneda,
                                                           gccli.cod_persona,
                                                           fug_obt_plz_contable((select max(b.fecha) from cc_sobregiros b where b.nro_cuenta = ccso.nro_cuenta) - min(ccso.fecha)),
                                                           'D',/*(tipo movimiento)*/
                                                           gcue.estado) rub_transaccion
from cc_sobregiros ccso, ge_cta_clientes gccli, ge_cuentas gcue, cc_lin_sobregiros cclso, cc_cta_corrientes cccor
where ccso.nro_cuenta = cclso.nro_cuenta(+)
and cclso.nro_cuenta is null
--and ccso.fecha = (select min(z.fecha) from cc_sobregiros z where z.nro_cuenta = ccso.nro_cuenta)
--and (sysdate - ccso.fecha) >= 60
and gccli.nro_cuenta =  ccso.nro_cuenta(+)
and gccli.relacion(+) like 'P'
and gcue.nro_cuenta(+) = ccso.nro_cuenta
and cccor.nro_cuenta = ccso.nro_cuenta
and nvl(cccor.dia_atraso,0) >= 60
group by ccso.nro_cuenta, gcue.cod_moneda, gcue.cod_modulo, gcue.cod_modalidad, gccli.cod_persona,cccor.dia_atraso, gcue.estado
;


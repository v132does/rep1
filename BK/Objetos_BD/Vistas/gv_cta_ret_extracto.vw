CREATE OR REPLACE FORCE VIEW IT.GV_CTA_RET_EXTRACTO AS
SELECT distinct e.nro_cuenta cuenta, 1 monto, e.cod_moneda moneda,
       1 cantidad, NULL nro_documento ,  NULL nro_documento2
from ge_cuentas c, ge_ext_cli_cuentas e
where e.fec_extracto between to_Date('01'||to_char(add_months(pag_cal.fu_obt_fec_actual(4),-1),'mmyyyy'),'ddmmyyyy')
  and last_day(add_months(pag_cal.fu_obt_fec_actual(4),-1))
and ( exists (select 1 from ge_dir_envios d
           where d.nro_cuenta  = e.nro_cuenta and d.tip_envio = 'R')
      or ( exists (select 1 from ge_dir_envios d
           where d.cod_persona = e.cod_persona
             and d.nro_cuenta  is null and d.tip_envio = 'R')
     and not exists  (select 1 from ge_dir_envios d
                       where d.nro_cuenta = e.nro_cuenta)
          )
 )
and not exists (Select 1 from cc_cta_corrientes c
           where c.nro_cuenta = e.nro_cuenta and c.cod_ente is not null)
and not exists(Select 1 from ah_cta_vistas c
           where c.nro_cuenta = e.nro_cuenta and c.cod_ente is not null)
and not exists (select 1 from ge_clientes g
           where g.cod_persona = e.cod_persona
             and g.tip_extracto = 'N')
and c.nro_cuenta = e.nro_cuenta
and c.estado not in ('C','P','A','T','D','X')
UNION
SELECT distinct t.nro_cuenta cuenta, 1 monto, e.cod_moneda moneda,
       1 cantidad, NULL nro_documento ,  NULL nro_documento2
from ge_cuentas c, ta_tarjetas t, ge_ext_cli_cuentas e
where e.fec_extracto between to_Date('01'||to_char(add_months(pag_cal.fu_obt_fec_actual(4),-1),'mmyyyy'),'ddmmyyyy')
       and last_day(add_months(pag_cal.fu_obt_fec_actual(4),-1))
and t.Nro_Tarjeta = e.nro_cuenta
and ( exists (select 1 from ge_dir_envios d
           where d.nro_cuenta  = t.nro_cuenta and d.tip_envio = 'R')
      or ( exists (select 1 from ge_dir_envios d
           where d.cod_persona = t.cod_persona
             and d.nro_cuenta  is null and d.tip_envio = 'R')
     and not exists  (select 1 from ge_dir_envios d
                       where d.nro_cuenta = t.nro_cuenta)
          )
 )
and not exists (select 1 from ge_clientes g
           where g.cod_persona = e.cod_persona
             and g.tip_extracto = 'N')
and c.nro_cuenta = t.nro_cuenta
and c.cod_modulo = 5
and c.estado not in ('C','P','A','T','D','X');


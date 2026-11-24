create or replace force view it.gv_pago_sueldo as
Select          p.cod_persona cliente,
                p.nom_completo nom_cliente,
                s.nro_cuenta,
                pa.cod_persona cod_cli_pagadora,
                pa.nom_completo nom_emp_pagadora,
                s.monto,
                s.fec_proceso,
                s.cod_moneda,
                s.cod_ente
  from Ge_pag_sueldos  s,
       Ge_cta_clientes cl,
       ba_personas     p,
       ba_personas     pa,
       ge_entes        e
 where s.procesado = 'S'
   and s.tipo = 'C'
   and s.monto > 0
   and cl.nro_cuenta = s.nro_cuenta
   and cl.relacion = 'P'
   and p.cod_persona = cl.cod_persona
   and e.cod_ente = s.cod_ente
   and pa.cod_persona = e.cod_persona
   and pa.cod_persona <> 11198;


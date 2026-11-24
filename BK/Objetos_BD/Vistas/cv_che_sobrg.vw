create or replace force view it.cv_che_sobrg as
select a.fec_proceso as fec_valor,
         x.fecha as fec_operacion,to_char(to_date(a.fec_insercion,'dd/mm/yyyy hh24:mi:ss'),'hh24:mi:ss') as hora_operacion,
         a.nro_cuenta,a.nro_cheque, b.denominacion,b.cod_moneda, a.monto, a.cod_ofi_camara, decode(a.est_cheque,'P','PAGADOS','RECHAZADOS') as estado,
         x.cod_tra_padre transaccion,
         x.cod_mod_padre modulo,
         x.cod_mad_padre modalidad,
         x.cod_usuario,
         '1' tipo_cobro, 'POR CLEARING' desc_cobro
     from cc_che_recibidos a, ge_cuentas b, cc_movimientos_his x, ge_calendarios z
    where a.nro_cuenta = b.nro_cuenta
      and a.est_cheque IN('P','R')
      and exists (select 1 from ba_oficinas z
          where z.cod_ofi_camara = a.cod_ofi_camara
            and z.cod_ofi_camara is not null)
      and x.nro_cuenta =  b.nro_cuenta
      and x.nro_cuenta = a.nro_cuenta
      and z.cod_modulo = 4
      and (x.cod_usuario = a.cod_usuario or
           a.est_cheque = 'R')
      and x.nro_documento = a.nro_cheque
      and ((x.cod_tra_padre in (320,138) and x.fecha = a.fec_proceso) or
            (x.cod_tra_padre in (132) and x.fecha = a.fec_proceso))
     AND a.fec_proceso between z.fec_actual - 3 and z.fec_actual
UNION ALL ----- DYDMR-4345 -- DE-2248
select a.fecha as fec_valor,
         x.fecha as fec_operacion,to_char(to_date(a.fec_insercion,'dd/mm/yyyy hh24:mi:ss'),'hh24:mi:ss') as hora_operacion,
         a.nro_cuenta,a.nro_cheque, b.denominacion,b.cod_moneda, a.monto, a.cod_ofi_camara, 'RECHAZADOS' as estado,
         x.cod_tra_padre transaccion,
         x.cod_mod_padre modulo,
         x.cod_mad_padre modalidad,
         x.cod_usuario,  '1', 'POR CLEARING' desc_cobro
     from cc_che_devueltos a, ge_cuentas b, cc_movimientos_his x, ge_calendarios z
    where a.nro_cuenta = b.nro_cuenta
      and x.nro_cuenta =  b.nro_cuenta
      and x.nro_cuenta = a.nro_cuenta
      and z.cod_modulo = 4
      and x.nro_documento = a.nro_cheque
      and ((x.cod_tra_padre in (320,138) and x.fecha = a.fecha) or
            (x.cod_tra_padre in (132) and x.fecha = a.fecha ))
     AND a.fecha between z.fec_actual - 3 and z.fec_actual
     and not exists (select 0 from cc_che_recibidos b where b.nro_cuenta = x.nro_cuenta and --- DYDMR-4345
                      b.est_cheque = 'R' and b.nro_cheque = x.nro_documento)
    UNION ALL
    --Recibidos por CAJA 354,355
     select c.fecha,
             trunc(c.fec_insercion),
             to_char(to_date(c.fec_insercion,'dd/mm/yyyy hh24:mi:ss'),'hh24:mi:ss') as hora_operacion,
             c.nro_cuenta,
             c.nro_documento,
             fue_obt_nom_persona(fug_obt_cli_principal(c.nro_cuenta))denominacion,
             c.cod_moneda,
             c.monto,
             c.cod_oficina,
             'PAGADOS' as estado,
             c.cod_tra_padre,
             c.cod_mod_padre modulo,
             c.cod_mad_padre modalidad,
             c.cod_usuario, '2', 'POR CAJA' desc_cobro
        from cj_movimientos_his c, ge_calendarios z
       where c.estado = 'N'
       AND c.cod_tra_padre in (354,355)
       and z.cod_modulo = 4
       --- si el cheque ya fue rechazado para que no tome en este cursor - DYDMR-3599
       and not exists (select 0 from cc_che_recibidos b where b.nro_cuenta = c.nro_cuenta and
                        b.est_cheque = 'R' and b.nro_cheque = c.nro_documento)
       and not exists (select 0 from cc_che_devueltos d where d.nro_cuenta = c.nro_cuenta and --- DYDMR-4345
                       d.nro_cheque = c.nro_documento )
     AND c.fecha between z.fec_actual - 3 and z.fec_actual
    UNION ALL
    --RECIBIDOS POR CAJA 3320
    select c.fecha,
             trunc(c.fec_insercion),
             to_char(to_date(c.fec_insercion,'dd/mm/yyyy hh24:mi:ss'),'hh24:mi:ss') as hora_operacion,
             c.nro_cuenta,
             c.nro_documento,
             fue_obt_nom_persona(fug_obt_cli_principal(c.nro_cuenta))denominacion,
             c.cod_moneda,
             c.monto,
             c.cod_oficina,
             'PAGADOS' as estado,
             c.cod_tra_padre,
             c.cod_mod_padre modulo,
             c.cod_mad_padre modalidad,
             c.cod_usuario, '1', 'POR CLEARING' desc_cobro
        from cc_movimientos_his c, ge_calendarios z
       where c.estado = 'N'
       AND c.cod_tra_padre in (3320)
       and z.cod_modulo = 4
     AND c.fecha between z.fec_actual - 3 and z.fec_actual
    UNION ALL
    select a.fec_proceso  as fec_valor,
         x.fecha as fec_operacion,to_char(to_date(a.fec_insercion,'dd/mm/yyyy hh24:mi:ss'),'hh24:mi:ss') as hora_operacion,
         a.nro_cuenta,a.nro_cheque, b.denominacion,b.cod_moneda, a.monto, a.cod_ofi_camara, decode(a.est_cheque,'P','PAGADOS','RECHAZADOS') as estado,
         x.cod_tra_padre transaccion,
         x.cod_mod_padre modulo,
         x.cod_mad_padre modalidad,
         x.cod_usuario, '1', 'POR CLEARING' desc_cobro
     from cc_che_recibidos a, ge_cuentas b, ge_movimientos x
    where a.nro_cuenta = b.nro_cuenta
      and a.est_cheque IN('P','R')
      and exists (select 1 from ba_oficinas z
          where z.cod_ofi_camara = a.cod_ofi_camara
           and z.cod_ofi_camara is not null)
      and x.nro_cuenta =  b.nro_cuenta
      and x.nro_cuenta = a.nro_cuenta
      and (x.cod_usuario = a.cod_usuario or
           a.est_cheque = 'R')
      and x.nro_documento = a.nro_cheque
      and ((x.cod_tra_padre in (320,138) and x.fecha = a.fec_proceso) or
     --- que incluya si el cheque fue rechazado - DYDMR-3599
           ( x.cod_tra_padre in (132) and x.fecha = a.fec_proceso))
    UNION ALL
  --Recibidos por CAJA 354,355
     select c.fecha,
             trunc(c.fec_insercion),
             to_char(to_date(c.fec_insercion,'dd/mm/yyyy hh24:mi:ss'),'hh24:mi:ss') as hora_operacion,
             c.nro_cuenta,
             c.nro_documento,
             fue_obt_nom_persona(fug_obt_cli_principal(c.nro_cuenta))denominacion,
             c.cod_moneda,
             c.monto,
             c.cod_oficina,
             'PAGADOS' as estado,
             c.cod_tra_padre,
             c.cod_mod_padre modulo,
             c.cod_mad_padre modalidad,
             c.cod_usuario, '2', 'POR CAJA' desc_cobro
        from cj_movimientos c
       where c.estado = 'N'
       AND c.cod_tra_padre in (354,355)
       --- si el cheque ya fue rechazado para que no tome en este cursor - DYDMR-3599
       and not exists (select 0 from cc_che_recibidos b where b.nro_cuenta = c.nro_cuenta and
                        b.est_cheque = 'R' and b.nro_cheque = c.nro_documento)
       and not exists (select 0 from cc_che_devueltos d where d.nro_cuenta = c.nro_cuenta and ---- DYDMR-4345
                       d.nro_cheque = c.nro_documento )
    UNION ALL
    --RECIBIDOS POR CAJA 3320
    select c.fecha,
             trunc(c.fec_insercion),
             to_char(to_date(c.fec_insercion,'dd/mm/yyyy hh24:mi:ss'),'hh24:mi:ss') as hora_operacion,
             c.nro_cuenta,
             c.nro_documento,
             fue_obt_nom_persona(fug_obt_cli_principal(c.nro_cuenta))denominacion,
             c.cod_moneda,
             c.monto,
             c.cod_oficina,
             'PAGADOS' as estado,
             c.cod_tra_padre,
             c.cod_mod_padre modulo,
             c.cod_mad_padre modalidad,
             c.cod_usuario, '2', 'POR CAJA' desc_cobro
        from ge_movimientos c
       where c.estado = 'N'
       AND c.cod_tra_padre in (3320)
;

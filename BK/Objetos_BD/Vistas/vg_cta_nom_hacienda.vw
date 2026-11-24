create or replace force view it.vg_cta_nom_hacienda as
select e.cod_ente,
       fue_obt_nom_persona(e.cod_persona) empresa,
       ah.cod_modulo,
       ah.cod_modalidad,
       ah.nro_cuenta,
       'AHO' tipo_cta,
       ah.estado,
       ah.cod_sub_modalidad sub_mod,
       case
         when (ah.cod_sub_modalidad = '6') then
          'AGUINALDO'
         else
          'NOMINA'
       end sub_mod_cta,
       ah.cod_moneda,
       ge.cod_persona,
       fue_obt_nom_persona(ge.cod_persona) cliente,
       ah.fec_apertura,
       nvl(ah.SAL_TOTAL, 0) - nvl(ah.SAL_RETENIDO, 0) -
       nvl(ah.SAL_BLOQUEADO, 0) SAL_DISPONIBLE,
       (select max(fecha)
          from ah_movimientos_his h
         where h.cod_modulo = ah.cod_modulo
           and h.cod_modalidad = ah.cod_modalidad
           and h.nro_cuenta = ah.nro_cuenta
           and h.cod_moneda = ah.cod_moneda
           and ((h.COD_TRANSACCION = 503 and
               h.COD_TRA_PADRE in (309, 320, 382) and h.COD_TASA is null and
               h.VAL_TASA is null) or
               (h.cod_transaccion = 591 and h.cod_tra_padre = 355) or
               (h.cod_transaccion = 590 and h.cod_tra_padre = 354))) fec_ult_extraccion,
       (select max(h.fecha)
          from it.ah_movimientos_his h
         where h.COD_MODULO = ah.cod_modulo
           and h.COD_MODALIDAD = ah.cod_modalidad
           and h.NRO_CUENTA = ah.nro_cuenta
           and h.COD_TRANSACCION in
               ('602', '690', '606', '607', '613', '614', '615', '632'))fec_ult_deposito,
       (select count(1)
          from cc_chequeras ce
         where ce.nro_cuenta = ah.nro_cuenta
           and ce.estado = 'E') cheq_activas
  from ah_cta_vistas ah, ge_entes e, ge_cta_clientes ge
 where ah.cod_ente is not null
   and ah.cod_ente = e.cod_ente
   and e.tipo = 'SU'
   and e.cod_persona != 11198
   and ah.nro_cuenta = ge.nro_cuenta
   and ge.relacion = 'P'
union all
select e.cod_ente,
       fue_obt_nom_persona(e.cod_persona) empresa,
       ah.cod_modulo,
       ah.cod_modalidad,
       ah.nro_cuenta,
       'CC' tipo_cta,
       ah.estado,
       ah.cod_sub_modalidad sub_mod,
       case
         when (ah.cod_sub_modalidad = '6') then
          'AGUINALDO'
         else
          'NOMINA'
       end sub_mod_cta,
       ah.cod_moneda,
       ge.cod_persona,
       fue_obt_nom_persona(ge.cod_persona) cliente,
       ah.fec_apertura,
       nvl(ah.SAL_TOTAL, 0) - nvl(ah.SAL_RETENIDO, 0) -
       nvl(ah.SAL_BLOQUEADO, 0) SAL_DISPONIBLE,
       (select max(fecha)
          from cc_movimientos_his h
         where h.cod_modulo = ah.cod_modulo
           and h.cod_modalidad = ah.cod_modalidad
           and h.nro_cuenta = ah.nro_cuenta
           and h.cod_moneda = ah.cod_moneda
           and ((h.COD_TRANSACCION = 503 and
               h.COD_TRA_PADRE in (309, 320, 382) and h.COD_TASA is null and
               h.VAL_TASA is null) or
               (h.cod_transaccion = 591 and h.cod_tra_padre = 355) or
               (h.cod_transaccion = 590 and h.cod_tra_padre = 354))) fec_ult_extraccion,
       (select max(h.fecha)
          from it.cc_movimientos_his h
         where h.COD_MODULO = ah.cod_modulo
           and h.COD_MODALIDAD = ah.cod_modalidad
           and h.NRO_CUENTA = ah.nro_cuenta
           and h.COD_TRANSACCION in
               ('602', '690', '606', '607', '613', '614', '615', '632')) fec_ult_deposito,
       (select count(1)
          from cc_chequeras ce
         where ce.nro_cuenta = ah.nro_cuenta
           and ce.estado = 'E') cheq_activas
  from cc_cta_corrientes ah, ge_entes e, ge_cta_clientes ge
 where ah.cod_ente is not null
   and ah.cod_ente = e.cod_ente
   and e.tipo = 'SU'
   and e.cod_persona != 11198
   and ah.nro_cuenta = ge.nro_cuenta
   and ge.relacion = 'P';


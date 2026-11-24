CREATE OR REPLACE FORCE VIEW IT.BV_ATM_MOVIMIENTOS AS
SELECT DISTINCT to_date(substr(mensaje, 182, 8), 'dd/mm/yyyy') fec_valor,
                gm.fecha,
                to_char(to_date(substr(mensaje, 190, 6), 'hh24miss'), 'hh24:mi:ss') hora,
                gm.cod_persona,
                gm.referencia nro_cta,
                case
                  when gm.nro_cuenta = substr(la.mensaje, 2, 2) || '0' || substr(la.mensaje, 4, 7) and
                                       substr(la.mensaje, 2, 2) || '0' || substr(la.mensaje, 4, 7) is not null and
                                       substr(mensaje, 15, 2)   || '0' || substr(mensaje,   17, 7) <> --cta_credito
                                       substr(la.mensaje, 2, 2) || '0' || substr(la.mensaje, 4, 7)--cta_debito
                                    or gm.nro_cuenta is not null then
                   gm.nro_cuenta --cta_debito
                  when gm.nro_cuenta = substr(mensaje, 15, 2)   || '0' || substr(mensaje, 17, 7) and
                                       substr(mensaje, 15, 2)   || '0' || substr(mensaje, 17, 7) is not null and
                                       substr(mensaje, 15, 2)   || '0' || substr(mensaje, 17, 7) <>
                                       substr(la.mensaje, 2, 2) || '0' || substr(la.mensaje, 4, 7)
                                    or gm.nro_cuenta is not null then
                   gm.nro_cuenta --cta_credito
                  when substr(mensaje, 15, 2)   || '0' || substr(mensaje, 17, 7) =
                       substr(la.mensaje, 2, 2) || '0' || substr(la.mensaje, 4, 7) then
                   substr(mensaje, 15, 2) || '0' || substr(mensaje, 17, 7)
                  else
                   null
                end nro_cuenta,
                case
                  when substr(mensaje,  1, 10) is not null and substr(mensaje, 11, 3) = 7 then
                   gm.denominacion
                  when substr(mensaje, 14, 10) is not null and substr(mensaje, 24, 3) = 7 then
                   gm.denominacion
                  else
                   'no es cliente' || ' :' || gm.denominacion
                end riesgo,
                gm.monto,
                substr(mensaje, 110, 2) moneda,
                gm.cod_banco || ' ' || gm.des_banco des_banco,
                substr(mensaje, 2, 2)  || '0' || substr(mensaje, 4, 7) cta_debito,
                substr(mensaje, 11, 3) || ' ' || fug_obt_des_banco(substr(mensaje, 11, 3)) bco_debito,
                substr(mensaje, 15, 2) || '0' || substr(mensaje, 17, 7) cta_credito,
                substr(mensaje, 24, 3) ||' :' || fug_obt_des_banco(substr(mensaje, 24, 3)) bco_credito,
                fut_obt_nro_tarjeta(gm.nro_cuenta) nro_tarjeta,
                substr(mensaje, 27, 2) operacion,
                gm.cod_transaccion     ||' - '|| gm.des_transaccion transaccion,
                gm.cod_tra_padre,
                gm.des_tra_padre,
                (to_number(substr(mensaje, 61, 15))) / 100 importe,
                to_number(substr(mensaje, 76, 15)) importe2,
                to_number(substr(mensaje, 91, 15)) importe3,
                substr(mensaje, 106, 4) can_cheques,
                gm.nro_caja nro_atm,
                ct.nro_caj_externo nro_atm_as400,
                cc.descripcion descripcion_atm,
                substr(mensaje, 124, 40) negocio,
                substr(mensaje, 115, 2) nro_pos,
                substr(mensaje, 117, 4) tra_pos,
                substr(mensaje, 121, 3) tip_hora,
                substr(mensaje, 179, 3) bco_atm,
                substr(respuesta, 1, 2) cod_respuesta,
                decode(substr(respuesta, 1, 2), '11',  'aprobado',
                                                '19',  'reintente',
                                                '05',  'no aprobado',
                                                '14',  'cuenta inexistente',
                                                '12',  'operacion inválida',
                                                '51',  'saldo insuficiente',
                                                '99',  'otro error',
                                                '91',  'en cierre') des_respuesta,
                to_number(substr(respuesta, 3, 15)) saldo1,
                to_number(substr(respuesta, 19, 15)) saldo2,
                substr(mensaje, 52, 9) nro_boleta,
                gm.cod_tip_movimiento,
                gm.cod_rubro,
                ct.cod_rubro ct_rubro,
                gm.des_rubro
  from log_atm la, gv_movimientos gm, cc_cta_cajeros ct, cj_cajas cc
 where gm.fecha          = to_date(substr(la.mensaje,182,8),'ddmmyyyy')
   and gm.hora           = to_char(to_date(substr(la.mensaje, 190, 6), 'hh24miss'), 'hh24:mi:ss')
   and substr(gm.cod_usuario,1,3)    = 'ATM'
   and gm.nro_documento2 = ct.nro_caj_externo (+)
   and ct.nro_caja       = cc.nro_caja        (+)
   and gm.reversado      = 'N'
   and gm.tipo          != 'D'
   and gm.cod_tra_padre  in (227, 228, 251, 252, 309, 328, 353, 363,  375,  376,  377,  381,
                             382, 387, 389, 390, 425, 430, 432, 503, 1216, 1251, 1605, 1779)
;


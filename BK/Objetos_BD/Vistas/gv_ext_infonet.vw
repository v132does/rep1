CREATE OR REPLACE FORCE VIEW IT.GV_EXT_INFONET AS
SELECT reg.fecha            fecha_extorno,
       reg.hora             hora_extorno,
       reg.nro_documento    documento_extorno,
       reg.cod_operacion    operacion_extorno,
       reg.monto            monto_extorno,
       reg.cod_moneda       moneda_extorno,
       xx.fecha             fecha,
       xx.hora              hora,
       xx.nro_documento     nro_documento,
	   xx.nro_cuenta        cuenta,
       xx.cod_usuario       usuario,
       xx.cod_mod_padre     modulo,
       xx.cod_mad_padre     modalidad,
       xx.cod_tra_padre     trans_padre,
       xx.reversado         reversado,
       xx.hor_reversion     hora_reversion,
       xx.cod_usu_reversion usuario_reversion
  FROM ge_ext_infonet_tmp reg,
       (SELECT fecha,
               hora,
               cod_usuario,
               cod_mod_padre,
               cod_mad_padre,
               cod_tra_padre,
               reversado,
               nro_documento,
               cod_moneda,
               monto,
							 nro_cuenta,
               hor_reversion,
               cod_usu_reversion
          FROM cc_movimientos_his g
         WHERE g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
           AND nvl(g.monto, 0) > 0
           AND NOT EXISTS (SELECT 1
                  FROM cc_movimientos_his e
                 WHERE e.nro_documento = g.nro_documento
                   AND e.cod_moneda = g.cod_moneda
                   AND g.cod_tra_padre IN (996, 227, 238)  -- CANOSTDD-2 -- 01/2017 --
                   AND nvl(e.monto, 0) < 0)
        UNION ALL
        SELECT fecha,
               hora,
               cod_usuario,
               cod_mod_padre,
               cod_mad_padre,
               cod_tra_padre,
               reversado,
               nro_documento,
               cod_moneda,
               monto,
							 nro_cuenta,
               hor_reversion,
               cod_usu_reversion
          FROM ah_movimientos_his g
         WHERE g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
           AND nvl(g.monto, 0) > 0
           AND NOT EXISTS (SELECT 1
                  FROM ah_movimientos_his e
                 WHERE e.nro_documento = g.nro_documento
                   AND e.cod_moneda = g.cod_moneda
                   AND g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
                   AND nvl(e.monto, 0) < 0)
        UNION ALL
        SELECT fecha,
               hora,
               cod_usuario,
               cod_mod_padre,
               cod_mad_padre,
               cod_tra_padre,
               reversado,
               nro_documento,
               cod_moneda,
               monto,
							 nro_cuenta,
               hor_reversion,
               cod_usu_reversion
          FROM ta_movimientos_his g
         WHERE g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
           AND nvl(g.monto, 0) > 0
           AND NOT EXISTS (SELECT 1
                  FROM ah_movimientos_his e
                 WHERE e.nro_documento = g.nro_documento
                   AND e.cod_moneda = g.cod_moneda
                   AND g.cod_tra_padre IN (996, 227, 238) -- CANOSTDD-2 -- 01/2017 --
                   AND nvl(e.monto, 0) < 0)) xx
 WHERE /*reg.cod_extorno = '99'
   AND*/ reg.cod_operacion = '72'
   AND xx.nro_documento = to_number(substr(reg.nro_documento, -7))
   AND xx.monto = reg.monto
   AND xx.cod_moneda = reg.cod_moneda
---
UNION
---
SELECT reg.fecha            fecha_extorno,
       reg.hora             hora_extorno,
       reg.nro_documento    documento_extorno,
       reg.cod_operacion    operacion_extorno,
       reg.monto            monto_extorno,
       reg.cod_moneda       moneda_extorno,
       xx.fecha             fecha,
       xx.hora              hora,
       xx.nro_documento     nro_documento,
	   xx.nro_cuenta        cuenta,
       xx.cod_usuario       usuario,
       xx.cod_mod_padre     modulo,
       xx.cod_mad_padre     modalidad,
       xx.cod_tra_padre     trans_padre,
       xx.reversado         reversado,
       xx.hor_reversion     hora_reversion,
       xx.cod_usu_reversion usuario_reversion
  FROM ge_ext_infonet_tmp reg,
       (SELECT fecha,
               hora,
               cod_usuario,
               cod_mod_padre,
               cod_mad_padre,
               cod_tra_padre,
               reversado,
               nro_documento,
               fec_valor,
               monto,
               cod_moneda,
							 nro_cuenta,
               hor_reversion,
               cod_usu_reversion
          FROM cc_movimientos_his g
         WHERE g.cod_usuario = 'ATM'
           AND g.cod_tra_padre <> 309
           AND nvl(g.monto, 0) > 0
           AND NOT EXISTS (SELECT 1
                  FROM cc_movimientos_his e
                 WHERE e.fec_valor = g.fec_valor
                   AND e.nro_documento = g.nro_documento
                   AND e.cod_moneda = g.cod_moneda
                   AND e.cod_usuario = g.cod_usuario
                   AND e.cod_tra_padre <> 309
                   AND nvl(e.monto, 0) < 0)
        UNION ALL
        SELECT fecha,
               hora,
               cod_usuario,
               cod_mod_padre,
               cod_mad_padre,
               cod_tra_padre,
               reversado,
               nro_documento,
               fec_valor,
               monto,
               cod_moneda,
							 nro_cuenta,
               hor_reversion,
               cod_usu_reversion
          FROM ah_movimientos_his g
         WHERE g.cod_usuario = 'ATM'
           AND g.cod_tra_padre <> 309
           AND nvl(g.monto, 0) > 0
           AND NOT EXISTS (SELECT 1
                  FROM ah_movimientos_his e
                 WHERE e.fec_valor = g.fec_valor
                   AND e.nro_documento = g.nro_documento
                   AND e.cod_moneda = g.cod_moneda
                   AND e.cod_usuario = g.cod_usuario
                   AND e.cod_tra_padre <> 309
                   AND nvl(e.monto, 0) < 0)) xx
 WHERE /*reg.cod_extorno = '99'
   AND*/ reg.cod_operacion <> 72
   AND xx.nro_documento = to_number(substr(reg.nro_documento, -7))
   AND xx.monto = reg.monto
   AND xx.cod_moneda = reg.cod_moneda
   AND xx.fec_valor = reg.fecha
;


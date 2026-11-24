CREATE OR REPLACE FORCE VIEW IT.GV_POS_CAMB AS
select zx.AFECTA,
       zx.cod_moneda,
       zx.pos_anterior,
       zx.equivalente_gs equi_pos_ant_gs,
       zx.TOT_COMPRA,
       round(nvl(MTO_EQU_GS_COMPRA, 0) / decode(nvl(TOT_COMPRA, 1), 0, 1, TOT_COMPRA),2) cambio_com,
       MTO_EQU_GS_COMPRA,
       pag_gen.FU_CON_MON_A_MONEDA(zx.cod_moneda, 'USD', TOT_COMPRA) mto_equ_usd_compra,
       zx.TOT_VENTA,
       round(nvl(MTO_EQU_GS_VENTA, 0) / decode(nvl(TOT_VENTA, 1), 0, 1, TOT_VENTA),2) cambio_ven,
       MTO_EQU_GS_VENTA,
       pag_gen.FU_CON_MON_A_MONEDA(zx.cod_moneda, 'USD', TOT_VENTA) mto_equ_usd_venta,
       (zx.pos_anterior + TOT_COMPRA - TOT_VENTA) sobre_com_ven_me,
       round(nvl((zx.pos_anterior + TOT_COMPRA - TOT_VENTA), 0) * nvl(fug_obt_cotizacion(zx.cod_moneda, pag_cal.fu_obt_fec_actual(1)),0),0) equi_pos_act_gs,
       fug_obt_cotizacion(zx.cod_moneda, pag_cal.fu_obt_fec_actual(1)) cambio_cierre,
       ROUND((nvl((equivalente_gs + MTO_EQU_GS_COMPRA - MTO_EQU_GS_VENTA),0) * -1) + nvl(round(nvl((zx.pos_anterior + TOT_COMPRA - TOT_VENTA), 0) *
              nvl(fug_obt_cotizacion(zx.cod_moneda,pag_cal.fu_obt_fec_actual(1)),0),0),0)) resultado
  from (select zz.pos_anterior,
               zz.equivalente_gs,
               DECODE(LC.AFE_POSICION, 'E', 'EFECTIVO', 'NO EFECTIVO') AFECTA,
               GE.COD_MONEDA cod_moneda,
               LC.AFE_POSICION AFE_POSICION,
               SUM(DECODE(GE.COD_MAD_PADRE, 71, nvl(MONTO, 0), 0)) +
               SUM(DECODE(GE.COD_MAD_PADRE,73,DECODE(GE.NRO_SECUENCIA, 1, NVL(MONTO, 0), 0),74,DECODE(GE.NRO_SECUENCIA, 1, NVL(MONTO, 0), 0),0)) TOT_COMPRA,
               ROUND(SUM(DECODE(GE.COD_MAD_PADRE,71,round(nvl(monto, 0) * nvl(cotizacion, 0),fue_dec_mon_local),0)) +
                     SUM(DECODE(GE.COD_MAD_PADRE,73,DECODE(GE.NRO_SECUENCIA,1,round(nvl(monto, 0) *nvl(cotizacion, 0),fue_dec_mon_local),0),74,
                                DECODE(GE.NRO_SECUENCIA,1,round(nvl(monto, 0) *nvl(cotizacion, 0),fue_dec_mon_local),0),0))) MTO_EQU_GS_COMPRA,
               SUM(DECODE(GE.COD_MAD_PADRE, 72, nvl(MONTO, 0), 0)) +
               SUM(DECODE(GE.COD_MAD_PADRE,73,DECODE(GE.NRO_SECUENCIA, 2, NVL(MONTO, 0), 0),74,DECODE(GE.NRO_SECUENCIA, 2, NVL(MONTO, 0), 0),0)) TOT_VENTA,
               ROUND(SUM(DECODE(GE.COD_MAD_PADRE,72,round(nvl(monto, 0) * nvl(cotizacion, 0),fue_dec_mon_local),0)) +
                     SUM(DECODE(GE.COD_MAD_PADRE,73,DECODE(GE.NRO_SECUENCIA,2,round(nvl(monto, 0) *nvl(cotizacion, 0),fue_dec_mon_local),0),74,
                                DECODE(GE.NRO_SECUENCIA,2,round(nvl(monto, 0) *nvl(cotizacion, 0),fue_dec_mon_local),0),0))) MTO_EQU_GS_VENTA
          FROM Ge_MOVIMIENTOS ge,
               LC_TIP_OPERACIONES lc,
               BA_MONEDAS ba,
               BA_OFICINAS o,
               (select xx.cod_moneda,
                       xx.tip_posicion,
                       xx.pos_anterior,
                       round(xx.pos_anterior * xx.cotizacion,
                             fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,71,pag_gen.fu_obt_mon_local)) equivalente_gs
                  from (SELECT COD_MONEDA,
                               TIP_POSICION,
                               DECODE(x.TIP_POSICION,'E',(NVL(x.MTO_EFE_COMPRA, 0) -NVL(x.MTO_EFE_VENTA, 0)),(NVL(x.MTO_NEF_COMPRA, 0) -
                                      NVL(x.MTO_NEF_VENTA, 0))) pos_anterior,
                               DECODE(x.TIP_POSICION,'E',NVL(x.COT_EFECTIVO, 0),NVL(x.COT_NO_EFECTIVO, 0)) COTIZACION
                          FROM LC_SAL_POSICIONES x
                         order by tip_posicion, cod_moneda) xx) zz
         WHERE COD_MOD_PADRE = 7
           AND COD_MAD_PADRE IN (71, 72, 73)
           AND REVERSADO = 'N'
           AND GE.COD_MONEDA = BA.COD_MONEDA
           AND LC.AFE_POSICION IN ('E', 'O')
           AND GE.ESTADO IN ('N')
           AND o.COD_OFICINA = GE.COD_OFI_ORIGEN
           AND COD_TIP_OPE_CAMBIO = COD_TIP_OPERACION
           and ((cod_mad_padre in (73) and nro_secuencia in (1, 2)) or
               (cod_mad_padre in (71, 72) and nro_secuencia in (1)))
           and LC.AFE_POSICION = zz.tip_posicion
           and ge.cod_moneda = zz.cod_moneda
         GROUP BY o.COD_OFI_CAMBIO,
                  fue_obt_des_oficina(o.COD_OFI_CAMBIO),
                  DECODE(LC.AFE_POSICION, 'E', 'EFECTIVO', 'NO EFECTIVO'),
                  GE.COD_MONEDA,
                  LC.AFE_POSICION,
                  zz.pos_anterior,
                  zz.equivalente_gs
        UNION
        select po.pos_anterior,
               round(po.pos_anterior * po.cotizacion,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,71,pag_gen.fu_obt_mon_local)) equivalente_gs,
               po.AFECTA,
               po.COD_MONEDA,
               po.TIP_POSICION,
               0,
               0,
               0,
               0
          from (select DECODE(a.TIP_POSICION,'E',(NVL(a.MTO_EFE_COMPRA, 0) -NVL(a.MTO_EFE_VENTA, 0)),(NVL(a.MTO_NEF_COMPRA, 0) -
                              NVL(a.MTO_NEF_VENTA, 0))) pos_anterior,
                       DECODE(a.TIP_POSICION,'E',NVL(a.COT_EFECTIVO, 0),NVL(a.COT_NO_EFECTIVO, 0)) COTIZACION,
                       DECODE(a.TIP_POSICION, 'E', 'EFECTIVO', 'NO EFECTIVO') AFECTA,
                       a.COD_MONEDA,
                       a.TIP_POSICION,0,0,0,0
                  FROM LC_SAL_POSICIONES a, BA_MONEDAS, BA_OFICINAS
                 WHERE TIP_POSICION in ('E', 'O')
                   AND BA_OFICINAS.COD_OFICINA = a.COD_OFI_CAMBIO
                   AND a.COD_MONEDA = BA_MONEDAS.COD_MONEDA
                   AND ((TIP_POSICION = 'E' AND
                       (a.MTO_EFE_COMPRA > 0 OR a.MTO_EFE_VENTA > 0)) OR
                       (TIP_POSICION = 'O' AND
                       (a.MTO_NEF_COMPRA > 0 OR a.MTO_NEF_VENTA > 0)))
                   AND NOT EXISTS
                 (SELECT 1
                          FROM LC_TIP_OPERACIONES X, GE_MOVIMIENTOS Z
                         WHERE COD_MONEDA = a.COD_MONEDA
                           AND COD_MOD_PADRE = 7
                           AND COD_MAD_PADRE IN (71, 72, 73)
                           AND REVERSADO = 'N'
                           AND MONTO <> 0
                           AND Z.ESTADO = 'N'
                           AND X.COD_TIP_OPERACION = Z.COD_TIP_OPE_CAMBIO
                           AND X.AFE_POSICION = a.TIP_POSICION)) po) zx
 order by zx.afecta, zx.cod_moneda;


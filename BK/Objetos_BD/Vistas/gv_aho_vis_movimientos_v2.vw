CREATE OR REPLACE FORCE VIEW IT.GV_AHO_VIS_MOVIMIENTOS_V2 AS
SELECT HIS.NRO_CUENTA,
       HIS.MONTO TransactionsAmount,
       fug_obt_paradicional(HIS.nro_cuenta, 'ALIAS_CTA') alias,
       UPPER(SUBSTR(TRAPADRE.DESCRIPCION,1,1))||LOWER(SUBSTR(TRAPADRE.DESCRIPCION,2))  description,
       HIS.fec_insercion transactionDate,
       to_char(HIS.fec_insercion, 'hh24:mi:ss') transactionhour,
       HIS.fec_insercion transactionDateValue,
       HIS.cod_moneda transactionCurrency,
       HIS.ESTADO status,
       HIS.reversado,
        case when HIS.reversado='N' and HIS.estado='N' then
               'Realizado'
              when  HIS.reversado='N' and HIS.estado!='N' then
                'Pendiente'
             when HIS.reversado='S'  and HIS.monto < 0 then
               'Realizado'
             when HIS.reversado='S'  and HIS.monto > 0 then
                'Rechazado'
         end  statusDescription,
               case when HIS.reversado='S' then
                  case when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and his.monto<0 then
                     'C'
                       when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and his.monto<0 then
                     'D'
                   else
                     decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                   end
                else
                   decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                end transactionType,
       HIS.nro_documento transactionId,
       it.fug_obt_categoria(HIS.cod_tra_padre,

                            HIS.cod_mad_padre,

                            HIS.cod_mod_padre) category,
       HIS.cod_transaccion,
        case when HIS.reversado='S' then
                  case when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and HIS.monto<0 then
                     'Acreditación en cuenta'
                       when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and HIS.monto<0 then
                     'Débito en cuenta'
                   else
                     UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                   end
                else
                   UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                end transactionDescription,
       HIS.cod_modulo,
       HIS.cod_modalidad,
       HIS.Fec_Modificacion,
       HIS.COD_TRA_PADRE,
       HIS.COD_MOD_PADRE,
       HIS.COD_MAD_PADRE,
       HIS.COD_RETENCION,
       HIS.FEC_FIN_RETENCION,
       HIS.Fecha,
       HIS.Hora,
       HIS.Cod_Usuario,
       HIS.Nro_Secuencia,
       HIS.CONCEPTO,
       HIS.NRO_DOCUMENTO2,
       HIS.NRO_DOCUMENTO3,
       HIS.NRO_DOCUMENTO4,
       HIS.REFERENCIA,
       HIS.TIP_MOV_RUBRO,
       HIS.MTO_EQU_LOCAL,
       HIS.COD_USU_REVERSION,
       HIS.HOR_REVERSION,
       HIS.FEC_VALOR

  FROM GE_TRANSACCIONES TRA, AH_MOVIMIENTOS_HIS HIS,GE_TRANSACCIONES TRAPADRE

 WHERE  HIS.COD_MODULO = TRA.COD_MODULO
   AND HIS.COD_MODALIDAD = TRA.COD_MODALIDAD
   AND HIS.COD_TRANSACCION = TRA.COD_TRANSACCION
   AND TRAPADRE.COD_MODULO = HIS.COD_MOD_PADRE
   AND TRAPADRE.COD_MODALIDAD = HIS.COD_MAD_PADRE
   AND TRAPADRE.COD_TRANSACCION = HIS.COD_TRA_PADRE
   AND TRA.VE_CLIENTE = 'S'
   AND TRA.TIPO IN ('C', 'D')
   AND NVL(HIS.MONTO,0)!=0
   AND HIS.ESTADO not in ('X','J')
   AND trunc(his.fec_insercion) between trunc(last_day(add_months(sysdate,-7))-1, 'mm') and trunc(sysdate)

union all


  SELECT GM.NRO_CUENTA,
         GM.MONTO TransactionsAmount,
         fug_obt_paradicional(GM.nro_cuenta, 'ALIAS_CTA') alias,
         UPPER(SUBSTR(TRAPADRE.DESCRIPCION,1,1))||LOWER(SUBSTR(TRAPADRE.DESCRIPCION,2))  description,
         GM.fec_insercion transactionDate,
         to_char(GM.fec_insercion, 'hh24:mi:ss') transactionhour,
         GM.fec_insercion transactionDateValue,
         GM.cod_moneda transactionCurrency,
         GM.ESTADO status,
         GM.reversado,
         case when GM.reversado='N' and GM.estado='N' then
               'Realizado'
              when  GM.reversado='N' and GM.estado!='N' then
                'Pendiente'
             when GM.reversado='S'  and GM.monto < 0 then
               'Realizado'
             when GM.reversado='S'  and GM.monto > 0 then
                'Rechazado'
         end  statusDescription,
          case when GM.reversado='S' then
                  case when decode(GM.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and GM.monto<0 then
                     'C'
                       when decode(GM.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and GM.monto<0 then
                     'D'
                   else
                     decode(GM.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                   end
                else
                   decode(GM.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                end transactionType,
         GM.nro_documento transactionId,
         it.fug_obt_categoria(GM.cod_tra_padre,

                              GM.cod_mad_padre,

                              GM.cod_mod_padre) category,
         GM.cod_transaccion,
            case when GM.reversado='S' then
                  case when decode(GM.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and GM.monto<0 then
                     'Acreditación en cuenta'
                       when decode(GM.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and GM.monto<0 then
                     'Débito en cuenta'
                   else
                     UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                   end
                else
                   UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                end transactionDescription,
         GM.cod_modulo,
         GM.cod_modalidad,
         GM.Fec_Modificacion,
         GM.COD_TRA_PADRE,
         GM.COD_MOD_PADRE,
         GM.COD_MAD_PADRE,
         GM.COD_RETENCION,
         GM.FEC_FIN_RETENCION,
         GM.Fecha,
         GM.Hora,
         GM.Cod_Usuario,
         GM.Nro_Secuencia,
         GM.CONCEPTO,
         GM.NRO_DOCUMENTO2,
         GM.NRO_DOCUMENTO3,
         GM.NRO_DOCUMENTO4,
         GM.REFERENCIA,
         GM.TIP_MOV_RUBRO,
         GM.MTO_EQU_LOCAL,
         GM.COD_USU_REVERSION,
         GM.HOR_REVERSION,
         GM.FEC_VALOR

    FROM GE_TRANSACCIONES TRA, GE_MOVIMIENTOS GM,GE_TRANSACCIONES TRAPADRE

   WHERE GM.COD_MODULO = TRA.COD_MODULO
     AND GM.COD_MODALIDAD = TRA.COD_MODALIDAD
     AND GM.COD_TRANSACCION = TRA.COD_TRANSACCION
     AND TRAPADRE.COD_MODULO = GM.COD_MOD_PADRE
     AND TRAPADRE.COD_MODALIDAD = GM.COD_MAD_PADRE
     AND TRAPADRE.COD_TRANSACCION = GM.COD_TRA_PADRE
     AND TRA.VE_CLIENTE = 'S'
     AND TRA.TIPO IN ('C', 'D')
     AND NVL(GM.MONTO,0)!=0
     AND GM.ESTADO not in ('X','J')
     AND pae_cnf.FU_OBT_EST_MODULO(3) <> 4
     AND trunc(gm.fec_insercion) between trunc(last_day(add_months(sysdate,-7))-1, 'mm') and trunc(sysdate)
 union all

  SELECT GMN.NRO_CUENTA,
         GMN.MONTO TransactionsAmount,
         fug_obt_paradicional(GMN.nro_cuenta, 'ALIAS_CTA') alias,
         UPPER(SUBSTR(TRAPADRE.DESCRIPCION,1,1))||LOWER(SUBSTR(TRAPADRE.DESCRIPCION,2))  description,
         GMN.fec_insercion transactionDate,
         to_char(GMN.fec_insercion, 'hh24:mi:ss') transactionhour,
         GMN.fec_insercion transactionDateValue,
         GMN.cod_moneda transactionCurrency,
         GMN.ESTADO status,
         GMN.reversado,
          case when GMN.reversado='N' and GMN.estado='N' then
               'Realizado'
              when  GMN.reversado='N' and GMN.estado!='N' then
                'Pendiente'
             when GMN.reversado='S'  and GMN.monto < 0 then
               'Realizado'
             when GMN.reversado='S'  and GMN.monto > 0 then
                'Rechazado'
         end  statusDescription,
           case when GMN.reversado='S' then
                  case when decode(GMN.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and GMN.monto<0 then
                     'C'
                       when decode(GMN.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and GMN.monto<0 then
                     'D'
                   else
                     decode(GMN.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                   end
                else
                   decode(GMN.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
             end transactionType,
         GMN.nro_documento transactionId,
         it.fug_obt_categoria(GMN.cod_tra_padre,

                              GMN.cod_mad_padre,

                              GMN.cod_mod_padre) category,
         GMN.cod_transaccion,
          case when GMN.reversado='S' then
                  case when decode(GMN.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and GMN.monto<0 then
                     'Acreditación en cuenta'
                       when decode(GMN.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and GMN.monto<0 then
                     'Débito en cuenta'
                   else
                     UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                   end
                else
                   UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                end transactionDescription,
         GMN.cod_modulo,
         GMN.cod_modalidad,
         GMN.Fec_Modificacion,
         GMN.COD_TRA_PADRE,
         GMN.COD_MOD_PADRE,
         GMN.COD_MAD_PADRE,
         GMN.COD_RETENCION,
         GMN.FEC_FIN_RETENCION,
         GMN.Fecha,
         GMN.Hora,
         GMN.Cod_Usuario,
         GMN.Nro_Secuencia,
         GMN.Concepto,
         GMN.NRO_DOCUMENTO2,
         GMN.NRO_DOCUMENTO3,
         GMN.NRO_DOCUMENTO4,
         GMN.REFERENCIA,
         GMN.TIP_MOV_RUBRO,
         GMN.MTO_EQU_LOCAL,
         GMN.COD_USU_REVERSION,
         GMN.HOR_REVERSION,
         GMN.FEC_VALOR

    FROM GE_TRANSACCIONES TRA, GE_MOVIMIENTOS_NOC GMN,GE_TRANSACCIONES TRAPADRE

   WHERE  GMN.COD_MODULO = TRA.COD_MODULO
     AND GMN.COD_MODALIDAD = TRA.COD_MODALIDAD
     AND GMN.COD_TRANSACCION = TRA.COD_TRANSACCION
     AND TRAPADRE.COD_MODULO = GMN.COD_MOD_PADRE
     AND TRAPADRE.COD_MODALIDAD = GMN.COD_MAD_PADRE
     AND TRAPADRE.COD_TRANSACCION = GMN.COD_TRA_PADRE
     AND TRA.VE_CLIENTE = 'S'
     AND TRA.TIPO IN ('C', 'D')
     AND NVL(GMN.MONTO,0)!=0
     AND GMN.ESTADO not in ('X','J')
     AND trunc(gmn.fec_insercion) between trunc(last_day(add_months(sysdate,-7))-1, 'mm') and trunc(sysdate)
union all

SELECT HIS.NRO_CUENTA,
       HIS.MONTO TransactionsAmount,
       fug_obt_paradicional(HIS.nro_cuenta, 'ALIAS_CTA') alias,
       UPPER(SUBSTR(TRAPADRE.DESCRIPCION,1,1))||LOWER(SUBSTR(TRAPADRE.DESCRIPCION,2))  description,
       HIS.fec_insercion transactionDate,
       to_char(HIS.fec_insercion, 'hh24:mi:ss') transactionhour,
       HIS.fec_insercion transactionDateValue,
       HIS.cod_moneda transactionCurrency,
       HIS.ESTADO status,
       HIS.reversado,
         case when HIS.reversado='N' and HIS.estado='N' then
               'Realizado'
              when  HIS.reversado='N' and HIS.estado!='N' then
                'Pendiente'
             when HIS.reversado='S'  and HIS.monto < 0 then
               'Realizado'
             when HIS.reversado='S'  and HIS.monto > 0 then
                'Rechazado'
         end  statusDescription,
               case when HIS.reversado='S' then
                  case when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and his.monto<0 then
                     'C'
                       when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and his.monto<0 then
                     'D'
                   else
                     decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                   end
                else
                   decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                end transactionType,
       HIS.nro_documento transactionId,
       it.fug_obt_categoria(HIS.cod_tra_padre,

                            HIS.cod_mad_padre,

                            HIS.cod_mod_padre) category,
       HIS.cod_transaccion,
        case when HIS.reversado='S' then
                  case when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and HIS.monto<0 then
                     'Acreditación en cuenta'
                       when decode(HIS.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and HIS.monto<0 then
                     'Débito en cuenta'
                   else
                     UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                   end
                else
                   UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                end transactionDescription,
       HIS.cod_modulo,
       HIS.cod_modalidad,
       HIS.Fec_Modificacion,
       HIS.COD_TRA_PADRE,
       HIS.COD_MOD_PADRE,
       HIS.COD_MAD_PADRE,
       HIS.COD_RETENCION,
       HIS.FEC_FIN_RETENCION,
       HIS.Fecha,
       HIS.Hora,
       HIS.Cod_Usuario,
       HIS.Nro_Secuencia,
       HIS.Concepto,
       HIS.NRO_DOCUMENTO2,
       HIS.NRO_DOCUMENTO3,
       HIS.NRO_DOCUMENTO4,
       HIS.REFERENCIA,
       HIS.TIP_MOV_RUBRO,
       HIS.MTO_EQU_LOCAL,
       HIS.COD_USU_REVERSION,
       HIS.HOR_REVERSION,
       HIS.FEC_VALOR

  FROM GE_TRANSACCIONES TRA, CC_MOVIMIENTOS_HIS HIS,GE_TRANSACCIONES TRAPADRE

 WHERE  HIS.COD_MODULO = TRA.COD_MODULO
   AND HIS.COD_MODALIDAD = TRA.COD_MODALIDAD
   AND HIS.COD_TRANSACCION = TRA.COD_TRANSACCION
   AND TRAPADRE.COD_MODULO = HIS.COD_MOD_PADRE
   AND TRAPADRE.COD_MODALIDAD = HIS.COD_MAD_PADRE
   AND TRAPADRE.COD_TRANSACCION = HIS.COD_TRA_PADRE
   AND TRA.VE_CLIENTE = 'S'
   AND TRA.TIPO IN ('C', 'D')
   AND NVL(HIS.MONTO,0)!=0
   AND HIS.ESTADO not in ('X','J')
   AND trunc(his.fec_insercion) between trunc(last_day(add_months(sysdate,-7))-1, 'mm') and trunc(sysdate)
union all

SELECT TA.NRO_CUENTA,
       TA.MONTO TransactionsAmount,
       fug_obt_paradicional(TA.nro_cuenta, 'ALIAS_CTA') alias,
       UPPER(SUBSTR(TRAPADRE.DESCRIPCION,1,1))||LOWER(SUBSTR(TRAPADRE.DESCRIPCION,2))  description,
       TA.fec_insercion transactionDate,
       to_char(TA.fec_insercion, 'hh24:mi:ss') transactionhour,
       TA.fec_insercion transactionDateValue,
       TA.cod_moneda transactionCurrency,
       TA.ESTADO status,
       TA.reversado,
         case when TA.reversado='N' and TA.estado='N' then
               'Realizado'
              when  TA.reversado='N' and TA.estado!='N' then
                'Pendiente'
             when TA.reversado='S'  and TA.monto < 0 then
               'Realizado'
             when TA.reversado='S'  and TA.monto > 0 then
                'Rechazado'
         end  statusDescription,
               case when TA.reversado='S' then
                  case when decode(TA.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and TA.monto<0 then
                     'C'
                       when decode(TA.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and TA.monto<0 then
                     'D'
                   else
                     decode(TA.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                   end
                else
                   decode(TA.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                end transactionType,
       TA.nro_documento transactionId,
       it.fug_obt_categoria(TA.cod_tra_padre,

                            TA.cod_mad_padre,

                            TA.cod_mod_padre) category,
       TA.cod_transaccion,
        case when TA.reversado='S' then
                  case when decode(TA.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and TA.monto<0 then
                     'Acreditación en cuenta'
                       when decode(TA.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and TA.monto<0 then
                     'Débito en cuenta'
                   else
                     UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                   end
                else
                   UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                end transactionDescription,
       TA.cod_modulo,
       TA.cod_modalidad,
       TA.Fec_Modificacion,
       TA.COD_TRA_PADRE,
       TA.COD_MOD_PADRE,
       TA.COD_MAD_PADRE,
       TA.COD_RETENCION,
       TA.FEC_FIN_RETENCION,
       TA.Fecha,
       TA.Hora,
       TA.Cod_Usuario,
       TA.Nro_Secuencia,
       TA.Concepto,
       TA.NRO_DOCUMENTO2,
       TA.NRO_DOCUMENTO3,
       TA.NRO_DOCUMENTO4,
       TA.REFERENCIA,
       TA.TIP_MOV_RUBRO,
       TA.MTO_EQU_LOCAL,
       TA.COD_USU_REVERSION,
       TA.HOR_REVERSION,
       TA.FEC_VALOR

  FROM GE_TRANSACCIONES TRA, TA_MOVIMIENTOS_HIS TA,GE_TRANSACCIONES TRAPADRE

 WHERE  TA.COD_MODULO = TRA.COD_MODULO
   AND TA.COD_MODALIDAD = TRA.COD_MODALIDAD
   AND TA.COD_TRANSACCION = TRA.COD_TRANSACCION
   AND TRAPADRE.COD_MODULO = TA.COD_MOD_PADRE
   AND TRAPADRE.COD_MODALIDAD = TA.COD_MAD_PADRE
   AND TRAPADRE.COD_TRANSACCION = TA.COD_TRA_PADRE
   AND TRA.VE_CLIENTE = 'S'
   AND TRA.TIPO IN ('C', 'D')
   AND NVL(TA.MONTO,0)!=0
   AND TA.ESTADO not in ('X','J')
   AND trunc(TA.fec_insercion) between trunc(last_day(add_months(sysdate,-7))-1, 'mm') and trunc(sysdate)
union all

SELECT PR.NRO_CUENTA,
       PR.MONTO TransactionsAmount,
       fug_obt_paradicional(PR.nro_cuenta, 'ALIAS_CTA') alias,
       UPPER(SUBSTR(TRAPADRE.DESCRIPCION,1,1))||LOWER(SUBSTR(TRAPADRE.DESCRIPCION,2))  description,
       PR.fec_insercion transactionDate,
       to_char(PR.fec_insercion, 'hh24:mi:ss') transactionhour,
       PR.fec_insercion transactionDateValue,
       PR.cod_moneda transactionCurrency,
       PR.ESTADO status,
       PR.reversado,
         case when PR.reversado='N' and PR.estado='N' then
               'Realizado'
              when  PR.reversado='N' and PR.estado!='N' then
                'Pendiente'
             when PR.reversado='S'  and PR.monto < 0 then
               'Realizado'
             when PR.reversado='S'  and PR.monto > 0 then
                'Rechazado'
         end  statusDescription,
               case when PR.reversado='S' then
                  case when decode(PR.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and PR.monto<0 then
                     'C'
                       when decode(PR.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and PR.monto<0 then
                     'D'
                   else
                     decode(PR.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                   end
                else
                   decode(PR.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)
                end transactionType,
       PR.nro_documento transactionId,
       it.fug_obt_categoria(PR.cod_tra_padre,

                            PR.cod_mad_padre,

                            PR.cod_mod_padre) category,
       PR.cod_transaccion,
       case when PR.reversado='S' then
                  case when decode(PR.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='D' and PR.monto<0 then
                     'Acreditación en cuenta'
                       when decode(PR.COD_TRANSACCION, 515, 'C', 560, 'C', TRA.TIPO)='C' and PR.monto<0 then
                     'Débito en cuenta'
                   else
                     UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                   end
                else
                   UPPER(SUBSTR(TRA.DESCRIPCION,1,1))||LOWER(SUBSTR(TRA.DESCRIPCION,2))
                end transactionDescription,
       PR.cod_modulo,
       PR.cod_modalidad,
       PR.Fec_Modificacion,
       PR.COD_TRA_PADRE,
       PR.COD_MOD_PADRE,
       PR.COD_MAD_PADRE,
       PR.COD_RETENCION,
       PR.FEC_FIN_RETENCION,
       PR.Fecha,
       PR.Hora,
       PR.Cod_Usuario,
       PR.Nro_Secuencia,
       PR.Concepto,
       PR.NRO_DOCUMENTO2,
       PR.NRO_DOCUMENTO3,
       PR.NRO_DOCUMENTO4,
       PR.REFERENCIA,
       PR.TIP_MOV_RUBRO,
       PR.MTO_EQU_LOCAL,
       PR.COD_USU_REVERSION,
       PR.HOR_REVERSION,
       PR.FEC_VALOR

  FROM GE_TRANSACCIONES TRA, PR_MOVIMIENTOS_HIS PR,GE_TRANSACCIONES TRAPADRE

 WHERE  PR.COD_MODULO = TRA.COD_MODULO
   AND PR.COD_MODALIDAD = TRA.COD_MODALIDAD
   AND PR.COD_TRANSACCION = TRA.COD_TRANSACCION
   AND TRAPADRE.COD_MODULO = PR.COD_MOD_PADRE
   AND TRAPADRE.COD_MODALIDAD = PR.COD_MAD_PADRE
   AND TRAPADRE.COD_TRANSACCION = PR.COD_TRA_PADRE
   AND TRA.VE_CLIENTE = 'S'
   AND TRA.TIPO IN ('C', 'D')
   AND NVL(PR.MONTO,0)!=0
   AND PR.ESTADO not in ('X','J')
   AND trunc(pr.fec_insercion) between trunc(last_day(add_months(sysdate,-7))-1, 'mm') and trunc(sysdate);
/

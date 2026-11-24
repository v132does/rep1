CREATE OR REPLACE VIEW IT.LV_MOVIMIENTOS AS
(select
  a.FECHA,
  a.HORA,
  a.COD_USUARIO,
  a.NRO_SECUENCIA,
  a.NRO_CUENTA,
  a.COD_MODULO,
  a.COD_MODALIDAD,
  a.COD_TRANSACCION,
  a.COD_MONEDA,
  a.TIP_MONTO,
  a.MONTO,
  a.COTIZACION,
  a.TIPO,
  a.COD_OFI_ORIGEN,
  a.NRO_CAJA,
  a.COD_CANAL,
  a.ESTADO,
  a.REVERSADO,
  a.COD_USU_REVERSION,
  a.COD_PAI_CORRESPONSAL,
  a.COD_PERSONA,
  a.COD_TIP_DOC_SOLICITANTE,
  a.NRO_DOC_SOLICITANTE,
  a.COD_PER_BENEFICIARIO,
  a.COD_PAI_BENEFICIARIO,
  a.COD_CIU_BENEFICIARIO,
  a.BCO_BENEFICIARIO,
  a.COD_PER_SOLICITANTE,
  a.COD_PAI_SOLICITANTE,
  a.COD_CIU_SOLICITANTE,
  a.COD_TRA_PADRE,
  a.COD_MOD_PADRE,
  a.COD_MAD_PADRE,
  a.EST_INFORMACION,
  a.FEC_GENERACION,
  a.FEC_PROCESO,
  a.COD_OPERACION,
  a.COD_TIP_DOC_BENEFICIARIO,
  a.NRO_DOC_BENEFICIARIO,
  a.MTO_EQU_LOCAL,
  a.MTO_MON_ORIGEN,
  a.COD_MON_DESTINO,
  a.COT_MON_DESTINO,
  a.NOM_ENT_EXTERNA,
  a.NRO_CTA_ENT_EXTERNA,
  a.COD_PAI_ENT_EXTERNA,
  a.NOM_CIU_ENT_EXTERNA,
  a.NRO_CHEQUE,
  a.NRO_BOLETA,
  a.MOTIVO,
  a.OBSERVACION,
  a.COD_PAI_BCO_INTERMEDIARIO,
  a.NOM_BCO_INTERMEDIARIO,
  a.COD_ABA_BCO_INTERMEDIARIO,
  a.COD_SWI_BCO_INTERMEDIARIO,
  a.NOM_CORRESPONSAL,
  a.USU_INSERCION,
  a.FEC_INSERCION,
  a.USU_MODIFICACION,
  a.FEC_MODIFICACION,
  a.TIPO_CANCELACION,
  a.MONTO_CANC,
  a.CDA,
  a.CTA_DESTINO,
  a.SNP_NOM_SOLICITANTE,
  a.SNP_NRO_DOC_SOLICITANTE,
  a.SNP_NRO_CTA_SOLICITANTE,
  a.SNP_NOM_BENEFICIARIO,
  a.SNP_NRO_DOC_BENEFICIARIO,
  a.SNP_NRO_CTA_BENEFICIARIO,
  a.SNP_NOM_BANCO,
  a.SNP_NOM_BANCO_SOLICITANTE,
  a.SNP_COD_SWI_BENEFICIARIO,
  a.SNP_COD_SWI_SOLICITANTE,
  a.COD_MON_ORIGINAL,
  a.DES_TRA_HIJA,
  a.DES_TRA_MADRE,
  a.REGION,
  a.INS_SEPRELAD,
  b.sal_actual

from (select m.*
  from (SELECT f.*/*, cod_moneda cod_mon_original*/

        FROM (select int.*,
              NVL(snp.nom_solicitante, int.nombre_solicitante)             snp_nom_solicitante,
              NVL(snp.nro_doc_solicitante, int.nro_doc_solicitante)        snp_nro_doc_solicitante,
              snp.nro_cta_solicitante                                      snp_nro_cta_solicitante,
              NVL(snp.nom_beneficiario, INT.nombre_beneficiario)           snp_nom_beneficiario,
              NVL(snp.nro_doc_beneficiario, int.nro_doc_beneficiario)      snp_nro_doc_beneficiario,
              snp.nro_Cta_beneficiario                                     snp_nro_cta_beneficiario,
              ba.participante                                              snp_nom_banco,
              ba2.participante                                             snp_nom_banco_solicitante,
              NVL(snp.cod_swi_pte_beneficiario, COD_SWI_BCO_INTERMEDIARIO) snp_cod_swi_beneficiario,
              NVL(snp.cod_swi_pte_solicitante, COD_SWI_BCO_INTERMEDIARIO)  snp_cod_swi_solicitante

             from  (select F.*,
                    F.MONTO MONTO_CANC,

                    CASE
                      WHEN (SELECT DISTINCT 1 FROM GV_MOVIMIENTOS R
                                              WHERE R.FECHA       = F.FECHA
                                              AND R.HORA          = F.HORA
                                              AND R.COD_TRA_PADRE = 358) = 1 THEN '3R'

                      WHEN (SELECT DISTINCT 1 FROM GV_MOVIMIENTOS R
                                              WHERE R.FECHA         = F.FECHA
                                              AND R.HORA            = F.HORA
                                              AND R.COD_TRA_PADRE   = 359
                                              AND R.COD_TRANSACCION = 740) = 1 THEN 'EFECTIVO'

                      WHEN (SELECT DISTINCT 1 FROM GV_MOVIMIENTOS R
                                              WHERE R.FECHA         = F.FECHA
                                              AND R.HORA            = F.HORA
                                              AND R.COD_TRA_PADRE   = 359
                                              AND R.COD_TRANSACCION = 503) = 1 THEN 'DEBITO EN CTA.'

                      WHEN (SELECT DISTINCT 1 FROM GV_MOVIMIENTOS R
                                              WHERE R.FECHA         = F.FECHA
                                              AND R.HORA            = F.HORA
                                              AND R.COD_TRA_PADRE   = 359
                                              AND R.COD_TRANSACCION in (607, 610)) = 1 THEN 'CHEQUE.'
                    END TIPO_CANCELACION

                    from LD_INT_MOVIMIENTOS f
                    --where f.nro_cuenta  = '4719148'
                    --and f.NRO_BOLETA = '57611'
                    ) int
              left join ge_snp_transferencias snp on int.nro_boleta = snp.nro_referencia
              left join gv_snp_participantes ba on snp.cod_swi_pte_beneficiario = ba.cod_swift
              left join gv_snp_participantes ba2 on snp.cod_swi_pte_solicitante = ba2.cod_swift) f
        ) m

      ) a
   left outer join  (select b.*, c.fecha fecha_sal, c.nro_cuenta, c.sal_actual from cb_sal_inventarios_his b
                                                                               inner join cb_sal_inventarios_det_his c on b.nro_referencia = c.nro_referencia
                                                                               where tip_saldo ='C'
                                                                               and situacion   = 'N') b on a.fecha     = b.fecha_sal
                                                                                                      and a.nro_cuenta = b.nro_cuenta
                                                                                                      and b.fecha      = a.fecha)
;

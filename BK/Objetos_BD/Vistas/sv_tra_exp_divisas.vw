CREATE OR REPLACE FORCE VIEW IT.SV_TRA_EXP_DIVISAS AS
SELECT distinct g.fecha,
                l.nro_referencia,
                l.cod_oficina,
                l.fec_operacion,
                l.nro_operacion,
                l.cod_moneda,
                l.monto,
                l.nro_cta_referencia,
                l.cod_banco,
                l.cod_pai_banco,
                l.cod_ciu_banco,
                l.cod_swi_banco,
                l.cod_bco_corresponsal,
                l.cod_per_solicitante,
                l.cod_pai_solicitante,
                l.cod_ciu_solicitante,
                l.cod_per_beneficiario,
                l.cod_pai_beneficiario,
                l.cod_ciu_beneficiario,
                l.nro_ref_externa,
                l.nro_doc_beneficiario,
                l.tip_fondo,
                l.tip_motivo,
                l.tip_financiacion,
                l.msj_swift,
                l.cod_modulo,
                l.cod_modalidad
  FROM ge_movimientos g, lc_transferencias l
 WHERE g.nro_documento = l.nro_operacion
   AND l.cod_modalidad = 71
   AND l.estado = 'OK'
   AND g.estado = 'N'
   AND g.reversado = 'N'
   AND g.cod_tra_padre = 253
   AND g.nro_secuencia < 900
   AND g.cod_transaccion = 760
   AND pag_gen.fu_obt_cod_entidad = 1007;

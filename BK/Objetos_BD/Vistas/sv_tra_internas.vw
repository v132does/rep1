CREATE OR REPLACE FORCE VIEW IT.SV_TRA_INTERNAS AS
SELECT DISTINCT g.cod_transferencia,
                   m.fecha,
                   g.cod_ofi_origen,
                   NULL cod_ofi_destino,
                   g.cod_moneda,
                   g.monto,
                   g.cod_per_remitente,
                   g.cod_per_beneficiario,
                   g.nro_cuenta,
                   g.tip_fondo,
                   g.tip_motivo,
                   g.tip_financiacion,
                   NULL nro_doc_beneficiario,
                   NULL cod_tip_doc_beneficiario,
                   m.cod_modulo,
                   m.cod_modalidad
     FROM ge_tra_internas g, ge_movimientos m
    WHERE g.estado = 'P'
       AND m.cod_tra_padre IN (296, 297)
       AND m.nro_documento = g.cod_transferencia;

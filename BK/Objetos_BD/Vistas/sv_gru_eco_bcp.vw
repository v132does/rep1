CREATE OR REPLACE FORCE VIEW IT.SV_GRU_ECO_BCP AS
SELECT a.numero, a.grupo,
       to_date(a.fec_alta, 'ddmmyyyy') fec_alta,
       to_date(a.fec_baja, 'ddmmyyyy') fec_baja,
       a.cod_tip_documento, a.tip_documento, a.doc_numero, a.nombre, a.apellido,
       to_date(a.per_fec_alta, 'ddmmyyyy') per_fec_alta,
       to_date(a.per_fec_baja, 'ddmmyyyy') per_fec_baja
  FROM (
SELECT a.numero, a.grupo,
       decode(a.fec_alta, '00000000', NULL, a.fec_alta) fec_alta,
       decode(a.fec_baja, '00000000', NULL, a.fec_baja) fec_baja,
       b.cod_tip_documento, a.tip_documento, a.doc_numero, a.nombre, a.apellido,
       decode(a.per_fec_alta, '00000000', NULL, a.per_fec_alta) per_fec_alta,
       decode(a.per_fec_baja, '00000000', NULL, a.per_fec_baja) per_fec_baja
  FROM sb_gru_eco_bcp_det a, ba_tip_documentos b
 WHERE b.abreviatura (+) = a.tip_documento
 ORDER BY a.numero, a.tip_documento, a.doc_numero) a;


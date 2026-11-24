CREATE OR REPLACE VIEW IT.SV_TRANSFERENCIAS AS
SELECT o.linea, o.registro, o.fecha
  FROM (SELECT rpad(s.nom_referencia, 10) || rpad(to_char(s.fec_periodo, 'yyyymmdd'), 8, ' ') ||
               lpad(s.cod_entidad, 4, 0) || lpad(c.can_reg, 9, 0) linea,
               0 registro,
               s.fec_periodo fecha
          FROM sb_transferencias s,
               (SELECT a.fecha fec, COUNT(*) can_reg FROM sb_transferencias_det a GROUP BY a.fecha) c
         WHERE s.fec_periodo = fec) o
UNION ALL
SELECT o2.linea, o2.registro, o2.fecha
  FROM (SELECT rpad(gru.nro_formulario, 3, 0) ||
               decode (pas_cri.fu_obt_cod_entidad, 2079, rpad(lpad(gru.cod_oficina, 2, 0),4,' '), 1007,
               lpad(gru.cod_oficina, 4, 0), 2036, rpad(lpad(gru.cod_oficina,2,0), 4, ' '), 2080, lpad(gru.cod_oficina, 4, 0) , rpad(gru.cod_oficina, 4, ' ')) ||
               lpad(gru.tip_movimiento, 3, '0') ||
               rpad(nvl(to_char(gru.nro_operacion), ' '), 60, ' ') ||
               rpad(gru.cod_mon_iso, 3, ' ') ||
               rpad(nvl(to_char(gru.fec_operacion, 'yyyymmdd'), ' '), 8, ' ') ||
               rpad(nvl(gru.tip_doc_ordenante, ' '), 3, ' ') ||
               rpad(nvl(ltrim(case when gru.tip_doc_ordenante = 'RUC' and instr(gru.nro_doc_ordenante,'-') = 0 then
                               substr(gru.nro_doc_ordenante,1,length(gru.nro_doc_ordenante)-1)||'-'||substr(gru.nro_doc_ordenante, length(gru.nro_doc_ordenante),1)
                             else gru.nro_doc_ordenante end,'0'), ' '), 30, ' ')||
               rpad(nvl(gru.nro_cta_ordenante, ' '), 30, ' ') ||
               lpad(to_char(nvl(gru.monto * 100, 0)), 20, '0') ||
               lpad(to_char(nvl(gru.val_conversion * 100, 0)), 10, '0') ||
               rpad(nvl(decode(gru.cod_swi_bco_intermediario,'COMAPYPA','COMAPYPAXXX',
                                                             'SOLAPYPA','SOLAPYPAXXX',
                                                             'TUFIPYPA','TUFIPYPAXXX',
                                                             'FNXAPYPA','FNXAPYPAXXX',
                                                             'FINLPYPA','FINLPYPAXXX',
                                                             'MIHAPYPAXXX','MIHAPYPA',
                                                             'BCOPPYPA','BCOPPYPAXXX',
                                                             'AMAMPYPA','AMAMPYPAXXX',
                                                             'FIPJPYPA','FIPJPYPAXXX',
                                                             'FICSPYPA','FICSPYPAXXX',
                                                             'BISAPYPE','BISAPYPEXXX',
                                                             'BCNAPYPA','BCNAPYPAXXX',
                                                             gru.cod_swi_bco_intermediario),' '),12,' ')||
               rpad(nvl(gru.cod_pai_iso_origen, ' '), 2, ' ') ||
               rpad(nvl(replace(gru.des_ciu_iso_origen,'ÑEMBY',''), ' '), 60, ' ') ||
               rpad(nvl(decode(pas_cri.fu_obt_cod_entidad, 2036, ' ', decode(gru.cod_swi_bco_beneficiario,'COMAPYPA','COMAPYPAXXX',
                                                                                                          'SOLAPYPA','SOLAPYPAXXX',
                                                                                                          'TUFIPYPA','TUFIPYPAXXX',
                                                                                                          'FNXAPYPA','FNXAPYPAXXX',
                                                                                                          'FINLPYPA','FINLPYPAXXX',
                                                                                                          'MIHAPYPAXXX','MIHAPYPA',
                                                                                                          'BCOPPYPA','BCOPPYPAXXX',
                                                                                                          'AMAMPYPA','AMAMPYPAXXX',
                                                                                                          'FIPJPYPA','FIPJPYPAXXX',
                                                                                                          'FICSPYPA','FICSPYPAXXX',
                                                                                                          'BISAPYPE','BISAPYPEXXX',
                                                                                                          'BCNAPYPA','BCNAPYPAXXX',
                                                                                                          gru.cod_swi_bco_beneficiario)), ' '), 12, ' ') ||
               rpad(nvl(nvl(gru.cod_pai_iso_destino,(select 'PY'
                                                     from ba_personas pe
                                                         ,ge_cta_clientes cl
                                                     where pe.nro_documento=gru.nro_doc_beneficiario
                                                       and pe.cod_persona=cl.cod_persona
                                                       and cl.nro_cuenta=gru.nro_cta_beneficiario)), ' '), 2, ' ') ||
               rpad(nvl(replace(gru.des_ciu_iso_destino,'ÑEMBY',''), ' '), 60, ' ') ||
               lpad(nvl(gru.tip_fondo,0), 2, '0') ||
               lpad(nvl(gru.tip_motivo,6), 2, '0') ||
               lpad(nvl(gru.tip_financiacion,1), 2, '0') ||
               rpad(nvl(gru.tip_doc_transportadora, ' '), 3, ' ') ||
               rpad(nvl(gru.nro_doc_transportadora, ' '), 30, ' ') ||
               rpad(nvl(gru.tip_doc_beneficiario, ' '), 3, ' ') ||
               rpad(nvl(ltrim(case when gru.tip_doc_beneficiario = 'RUC' and instr(gru.nro_doc_beneficiario,'-') = 0 then
                               substr(gru.nro_doc_beneficiario,1,length(gru.nro_doc_beneficiario)-1)||'-'||substr(gru.nro_doc_beneficiario, length(gru.nro_doc_beneficiario),1)
                             else gru.nro_doc_beneficiario end,'0'), ' '), 30, ' ')||
               rpad(nvl(gru.nro_cta_beneficiario, ' '), 30, ' ') ||
               rpad(nvl(gru.autorizado, ' '), 1, ' ') ||
               lpad(gru.nro_registro, 9, 0) linea,
               gru.nro_registro registro,
               fecha
          FROM (SELECT d.nro_formulario,
                       d.cod_oficina,
                       decode(d.tip_movimiento,1,3,d.tip_movimiento) tip_movimiento,
                       d.nro_operacion,
                       d.cod_mon_iso,
                       d.fec_operacion,
                       d.tip_doc_ordenante,
                       d.nro_doc_ordenante,
                       decode(nvl(d.nro_cta_ordenante,'0'),'0',nvl((select tr.nro_cta_solicitante
                                                                    from ge_snp_transferencias tr
                                                                    where tr.nro_referencia = d.nro_operacion),'0'),
                                                               d.nro_cta_ordenante) nro_cta_ordenante,
                       d.monto,
                       d.val_conversion,
                       d.cod_swi_bco_intermediario,
                       d.cod_pai_iso_origen,
                       d.des_ciu_iso_origen,
                       replace(d.cod_swi_bco_beneficiario,'UENO','COMA') cod_swi_bco_beneficiario,
                       d.cod_pai_iso_destino,
                       d.des_ciu_iso_destino,
                       nvl(d.tip_fondo,nvl(pas_tra.fu_obt_ori_fondo(replace(d.nro_doc_ordenante,'BR','')),0)) tip_fondo,
                       d.tip_motivo,
                       d.tip_financiacion,
                       d.tip_doc_transportadora,
                       d.nro_doc_transportadora,
                       decode(nvl(d.tip_doc_beneficiario,'X'),'X',(select td.abreviatura
                                                                   from ge_snp_transferencias tr
                                                                       ,ba_tip_documentos td
                                                                   where tr.nro_referencia = d.nro_operacion
                                                                     and tr.cod_tip_doc_beneficiario=td.cod_tip_documento),
                                                                  d.tip_doc_beneficiario) tip_doc_beneficiario,

                       decode(nvl(d.nro_doc_beneficiario,'X'),'X',(select tr.nro_doc_beneficiario
                                                                   from ge_snp_transferencias tr
                                                                   where tr.nro_referencia = d.nro_operacion),
                                                                  d.nro_doc_beneficiario) nro_doc_beneficiario,
                       decode(nvl(d.nro_cta_beneficiario,'0'),'0',nvl((select tr.nro_cta_beneficiario
                                                                       from ge_snp_transferencias tr
                                                                       where tr.nro_referencia = d.nro_operacion),'0'),
                                                                  replace(d.nro_cta_beneficiario,'UENO','COMA')) nro_cta_beneficiario,
                       d.autorizado,
                       d.nro_registro,
                       d.fecha
                 FROM sb_transferencias_det d) gru
          ORDER BY gru.nro_registro) o2
 ORDER BY fecha, registro
;

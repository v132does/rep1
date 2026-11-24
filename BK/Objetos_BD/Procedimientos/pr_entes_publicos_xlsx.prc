create or replace PROCEDURE  IT.PR_ENTES_PUBLICOS_XLSX (p_fecha in date, p_doc_id out varchar2)
AS
g_col number := 2;
g_row number := 1;
V_COUNT number := 0;
V_CATEGORIA varchar2(50) := null;
v_blob blob;
v_id number;
v_fmt_miles pls_integer;
-- VARIABLES para almacenar los totales
v_gc_cta_cte number := 0;
v_gc_ahorro number := 0;
v_gc_cda number := 0;
v_gc_cta_cte_usd number := 0;
v_gc_ahorro_usd number := 0;
v_gc_cda_usd number := 0;
v_gc_total_gs number := 0;
v_gc_total_usd number := 0;

v_spnf_cta_cte number := 0;
v_spnf_ahorro number := 0;
v_spnf_cda number := 0;
v_spnf_cta_cte_usd number := 0;
v_spnf_ahorro_usd number := 0;
v_spnf_cda_usd number := 0;
v_spnf_total_gs number := 0;
v_spnf_total_usd number := 0;

v_pj_cta_cte number := 0;
v_pj_ahorro number := 0;
v_pj_cda number := 0;
v_pj_cta_cte_usd number := 0;
v_pj_ahorro_usd number := 0;
v_pj_cda_usd number := 0;
v_pj_total_gs number := 0;
v_pj_total_usd number := 0;

v_ed_cta_cte number := 0;
v_ed_ahorro number := 0;
v_ed_cda number := 0;
v_ed_cta_cte_usd number := 0;
v_ed_ahorro_usd number := 0;
v_ed_cda_usd number := 0;
v_ed_total_gs number := 0;
v_ed_total_usd number := 0;

v_tot_cta_cte number := 0;
v_tot_ahorro number := 0;
v_tot_cda number := 0;
v_tot_cta_cte_usd number := 0;
v_tot_ahorro_usd number := 0;
v_tot_cda_usd number := 0;
v_tot_total_gs number := 0;
v_tot_total_usd number := 0;
--
cursor c1(p_id number) is 
SELECT ENTE_PRIN, CTA_CTE, AHORRO_A_LA_VISTA, CDA, CTA_CTE_USD, 
         AHORRO_A_LA_VISTA_USD, CDA_USD, TOTAL_GS, TOTAL_USD
    FROM (
      SELECT 'GOBIERNO CENTRAL' AS ENTE_PRIN,
             SUM(CTA_CTE) AS CTA_CTE,
             SUM(AHORRO_A_LA_VISTA) AS AHORRO_A_LA_VISTA,
             SUM(CDA) AS CDA,
             SUM(CTA_CTE_USD) AS CTA_CTE_USD,
             SUM(AHORRO_A_LA_VISTA_USD) AS AHORRO_A_LA_VISTA_USD,
             SUM(CDA_USD) AS CDA_USD,
             SUM(TOTAL_GS) AS TOTAL_GS,
             SUM(TOTAL_USD) AS TOTAL_USD,
             1 AS orden
        FROM IT.SB_ENTES_PUBLICOS_DET
       WHERE id = p_id
         AND categoria IN ('MINISTERIOS', 'PODER JUDICIAL', 'OTROS ORGANISMOS DEL ESTADO')
       GROUP BY 'GOBIERNO CENTRAL'
       union all 
       select distinct 'PODER EJECUTIVO' AS ENTE_PRIN, 
              CAT_CTA_CTE, 
              CAT_AHORRO_A_LA_VISTA, 
              CAT_CDA, 
              CAT_CTA_CTE_USD, 
              CAT_AHORRO_A_LA_VISTA_USD,
              CAT_CDA_USD, 
              CAT_TOTAL_GS, 
              CAT_TOTAL_USD,
              2 AS orden
        from IT.SB_ENTES_PUBLICOS_DET 
        where id = p_id 
        and categoria = 'MINISTERIOS'
        union all 
       select 'ENTIDADES DESCENTRALIZADAS' AS ENTE_PRIN, 
              sum(CAT_CTA_CTE) CAT_CTA_CTE, 
              sum(CAT_AHORRO_A_LA_VISTA) CAT_AHORRO_A_LA_VISTA, 
              sum(CAT_CDA) CAT_CDA, 
              sum(CAT_CTA_CTE_USD) CAT_CTA_CTE_USD, 
              sum(CAT_AHORRO_A_LA_VISTA_USD) CAT_AHORRO_A_LA_VISTA_USD,
              sum(CAT_CDA_USD) CAT_CDA_USD, 
              sum(CAT_TOTAL_GS) CAT_TOTAL_GS, 
              sum(CAT_TOTAL_USD) CAT_TOTAL_USD,
              3 AS orden
        from (select distinct  
                      CAT_CTA_CTE, 
                      CAT_AHORRO_A_LA_VISTA, 
                      CAT_CDA, 
                      CAT_CTA_CTE_USD, 
                      CAT_AHORRO_A_LA_VISTA_USD,
                      CAT_CDA_USD, 
                      CAT_TOTAL_GS, 
                      CAT_TOTAL_USD,
                      2 AS orden
                from IT.SB_ENTES_PUBLICOS_DET 
                where id = p_id 
                and categoria in ('ORG. DE PROMOCION Y DESARROLLO', 'ENTIDADES REGULADORAS'))
      UNION ALL
      SELECT 'SECTOR PUBLICO NO FINANCIERO' AS ENTE_PRIN,
             SUM(CTA_CTE) AS CTA_CTE,
             SUM(AHORRO_A_LA_VISTA) AS AHORRO_A_LA_VISTA,
             SUM(CDA) AS CDA,
             SUM(CTA_CTE_USD) AS CTA_CTE_USD,
             SUM(AHORRO_A_LA_VISTA_USD) AS AHORRO_A_LA_VISTA_USD,
             SUM(CDA_USD) AS CDA_USD,
             SUM(TOTAL_GS) AS TOTAL_GS,
             SUM(TOTAL_USD) AS TOTAL_USD,
             3 AS orden
        FROM IT.SB_ENTES_PUBLICOS_DET
       WHERE id = p_id
         AND categoria != 'SECTOR PUBLICO FINANCIERO'
       GROUP BY 'SECTOR PUBLICO NO FINANCIERO'
    )
   ORDER BY orden;
begin
 v_id := IT.S_ID_ENTES_PUBLICOS_DET.nextval; 
 -- insert tabla 
 insert into IT.SB_ENTES_PUBLICOS_DET (ID, fecha, ENTE, CATEGORIA, CTA_CTE, AHORRO_A_LA_VISTA, CDA, CTA_CTE_USD, AHORRO_A_LA_VISTA_USD, CDA_USD,
            TOTAL_GS, TOTAL_USD, CAT_CTA_CTE, CAT_AHORRO_A_LA_VISTA, CAT_CDA, CAT_CTA_CTE_USD, CAT_AHORRO_A_LA_VISTA_USD, CAT_CDA_USD,
            CAT_TOTAL_GS, CAT_TOTAL_USD, ORDEN)
 select  v_id,  p_fecha, ENTE, CATEGORIA, CTA_CTE, AHORRO_A_LA_VISTA, CDA, CTA_CTE_USD, AHORRO_A_LA_VISTA_USD, CDA_USD, TOTAL_GS, TOTAL_USD,
        round(sum(CTA_CTE) over (partition by categoria) ) CAT_CTA_CTE,  
        round(sum(AHORRO_A_LA_VISTA) over (partition by categoria)) CAT_AHORRO_A_LA_VISTA,  
        round(sum(CDA) over (partition by categoria)) CAT_CDA,  
        round(sum(CTA_CTE_USD) over (partition by categoria),2) CAT_CTA_CTE_USD, 
        round(sum(AHORRO_A_LA_VISTA_USD) over (partition by categoria),2) CAT_AHORRO_A_LA_VISTA_USD,  
        round(sum(CDA_USD) over (partition by categoria),2) CAT_CDA_USD,
        round(sum(TOTAL_GS) over (partition by categoria)) CAT_TOTAL_GS,
        round(sum(TOTAL_USD) over (partition by categoria),2) CAT_TOTAL_USD
        , orden 
from (
  select ENTE ENTE,
       CATEGORIA,
       round(COALESCE(SUM(CASE WHEN a.cod_modalidad = 41 AND a.cod_moneda = 'GS' THEN a.sal_actual END), 0)) AS CTA_CTE,
       round(COALESCE(SUM(CASE WHEN a.cod_modalidad = 31 AND a.cod_moneda = 'GS' THEN a.sal_actual END), 0)) AS AHORRO_A_LA_VISTA,
       round(COALESCE(SUM(CASE WHEN a.cod_modalidad = 33 AND a.cod_moneda = 'GS' THEN a.sal_actual END), 0)) AS CDA,
       round(COALESCE(SUM(CASE WHEN a.cod_modalidad = 41 AND a.cod_moneda = 'USD' THEN a.sal_actual END), 0),2) AS CTA_CTE_USD,
       round(COALESCE(SUM(CASE WHEN a.cod_modalidad = 31 AND a.cod_moneda = 'USD' THEN a.sal_actual END), 0),2) AS AHORRO_A_LA_VISTA_USD,
       round(COALESCE(SUM(CASE WHEN a.cod_modalidad = 33 AND a.cod_moneda = 'USD' THEN a.sal_actual END), 0),2) AS CDA_USD,
       round(COALESCE(SUM(case when a.cod_moneda = 'GS' then a.sal_actual end ), 0)) AS TOTAL_GS,
       round(COALESCE(SUM(case when a.cod_moneda = 'USD' then a.sal_actual end ), 0),2) AS TOTAL_USD,
       orden
from (
SELECT gcc.cod_persona,
       c.fecha,
       c.cod_modalidad,
       c.cod_moneda,
       d.sal_actual
  FROM it.cb_sal_inventarios_his c 
  JOIN it.cb_sal_inventarios_det_his d 
    ON (d.nro_referencia = c.nro_referencia AND d.fecha = c.fecha)
  JOIN it.ge_cta_clientes gcc 
    ON (gcc.nro_cuenta = d.nro_cuenta AND gcc.relacion = 'P')
 WHERE c.fecha = p_fecha
   AND c.cod_modalidad IN (41, 31, 33)
   AND c.cod_sec_contable = 'P' 
   AND c.tip_saldo      IN ('C', 'Q')
   union all
   SELECT gcc.cod_persona,
       c.fecha,
       c.cod_modalidad,
       c.cod_moneda,
       d.sal_actual
FROM it.cb_sal_inventarios_his c 
  JOIN it.cb_sal_inventarios_det_his d 
    ON (d.nro_referencia = c.nro_referencia AND d.fecha = c.fecha)
  JOIN it.ge_cta_clientes gcc 
    ON (gcc.nro_cuenta = d.nro_cuenta AND gcc.relacion = 'P')
  join it.SB_ENTES_PUBLICOS_PARAM b 
    ON (b.cod_persona = gcc.cod_persona and categoria = 'SECTOR PUBLICO FINANCIERO')
 WHERE c.fecha = p_fecha
   AND c.cod_modalidad IN (41, 31, 33)
   AND c.cod_sec_contable in ('F', 'I')
   AND c.tip_saldo      IN ('C', 'Q')) a
   right join it.SB_ENTES_PUBLICOS_PARAM b ON (b.cod_persona = a.cod_persona)
   GROUP BY b.ENTE, b.CATEGORIA, b.orden)
 order by orden;

    FOR r_resumen IN c1(v_id) loop
        IF r_resumen.ENTE_PRIN = 'GOBIERNO CENTRAL' THEN
            v_gc_cta_cte := r_resumen.CTA_CTE;
            v_gc_ahorro := r_resumen.AHORRO_A_LA_VISTA;
            v_gc_cda := r_resumen.CDA;
            v_gc_cta_cte_usd := r_resumen.CTA_CTE_USD;
            v_gc_ahorro_usd := r_resumen.AHORRO_A_LA_VISTA_USD;
            v_gc_cda_usd := r_resumen.CDA_USD;
            v_gc_total_gs := r_resumen.TOTAL_GS;
            v_gc_total_usd := r_resumen.TOTAL_USD;
        ELSIF r_resumen.ENTE_PRIN = 'PODER EJECUTIVO' then
            v_pj_cta_cte := r_resumen.CTA_CTE;
            v_pj_ahorro := r_resumen.AHORRO_A_LA_VISTA;
            v_pj_cda := r_resumen.CDA;
            v_pj_cta_cte_usd := r_resumen.CTA_CTE_USD;
            v_pj_ahorro_usd := r_resumen.AHORRO_A_LA_VISTA_USD;
            v_pj_cda_usd := r_resumen.CDA_USD;
            v_pj_total_gs := r_resumen.TOTAL_GS;
            v_pj_total_usd := r_resumen.TOTAL_USD;
        ELSIF r_resumen.ENTE_PRIN = 'ENTIDADES DESCENTRALIZADAS' then
            v_ed_cta_cte := r_resumen.CTA_CTE;
            v_ed_ahorro := r_resumen.AHORRO_A_LA_VISTA;
            v_ed_cda := r_resumen.CDA;
            v_ed_cta_cte_usd := r_resumen.CTA_CTE_USD;
            v_ed_ahorro_usd := r_resumen.AHORRO_A_LA_VISTA_USD;
            v_ed_cda_usd := r_resumen.CDA_USD;
            v_ed_total_gs := r_resumen.TOTAL_GS;
            v_ed_total_usd := r_resumen.TOTAL_USD;
        ELSIF r_resumen.ENTE_PRIN = 'SECTOR PUBLICO NO FINANCIERO' THEN
            v_spnf_cta_cte := r_resumen.CTA_CTE;
            v_spnf_ahorro := r_resumen.AHORRO_A_LA_VISTA;
            v_spnf_cda := r_resumen.CDA;
            v_spnf_cta_cte_usd := r_resumen.CTA_CTE_USD;
            v_spnf_ahorro_usd := r_resumen.AHORRO_A_LA_VISTA_USD;
            v_spnf_cda_usd := r_resumen.CDA_USD;
            v_spnf_total_gs := r_resumen.TOTAL_GS;
            v_spnf_total_usd := r_resumen.TOTAL_USD;
        END IF;
    end loop;

    it.as_xlsx.clear_workbook;
    it.as_xlsx.new_sheet('Informe');
    v_fmt_miles := it.as_xlsx.get_numFmt('#,##0');
    it.as_xlsx.set_column_width(p_col => 1, p_width => 10);
    it.as_xlsx.set_column_width(p_col => 2, p_width => 40);
    it.as_xlsx.set_column_width(p_col => 3, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 4, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 5, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 6, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 7, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 8, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 9, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 12, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 13, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 14, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 15, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 16, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 17, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 18, p_width => 20);
    it.as_xlsx.set_row(
                p_row    => 1,
                p_height => 40
            );
    commit;

    for r in (select ENTE, CATEGORIA, CTA_CTE, AHORRO_A_LA_VISTA, CDA, CTA_CTE_USD, AHORRO_A_LA_VISTA_USD, CDA_USD,
                     TOTAL_GS, TOTAL_USD, CAT_CTA_CTE, CAT_AHORRO_A_LA_VISTA, CAT_CDA, CAT_CTA_CTE_USD, CAT_AHORRO_A_LA_VISTA_USD, CAT_CDA_USD,
                     CAT_TOTAL_GS, CAT_TOTAL_USD
               from IT.SB_ENTES_PUBLICOS_DET 
               where id = v_id 
               ORDER BY orden, ente) loop
        if v_count = 0 then 

            it.as_xlsx.cell(g_col, g_row, 'BANCO CENTRAL DEL PARAGUAY', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    ));
            g_row := g_row+1;
            it.as_xlsx.cell(g_col, g_row, 'GERENCIA DE ESTUDIOS ECONOMICOS', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    ));
            g_row := g_row+1;
            it.as_xlsx.cell(g_col, g_row, 'DEPARTAMENTO DE ESTUDIOS MONETARIOS Y FINANCIEROS', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    ));
            g_row := g_row+2;
            g_col := g_col+2;
            it.as_xlsx.cell(g_col, g_row, 'SALDO DE LOS DEPOSITOS DEL SECTOR PUBLICO EN UENO BANK S.A.', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    ));
            g_row := g_row+1;
            it.as_xlsx.cell(g_col, g_row, 'FECHA:', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, last_Day(p_fecha), p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    ));
            g_col := 2;
            g_row := g_row+2;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', 'thin', 'thin' ));
            g_col := g_col+1;
            as_xlsx.set_row( g_row, p_fillId => as_xlsx.get_fill( 'solid', '808080' ) );
            it.as_xlsx.cell(g_col, g_row, 'EN GUARANIES', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                                , p_fontsize => 8
                                                                                , p_bold => TRUE
                                                                                )
                                                                  , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', '' )
                                                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', 'thin' ));
            g_col := g_col+1;
            as_xlsx.mergecells( 3, g_row, 9, g_row);
            g_col := 2;
            g_row := g_row+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '','thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'CTA. CTE.', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'AHORRO A LA VISTA', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                             , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                             , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'AHORRO PLAZO', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'CDA', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'OTROS 1/', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'TOTAL', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                 , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                 , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'PREST.A INST.', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));

            as_xlsx.mergecells( 2, 8, 2, 9);
            g_col := 2;
            g_row := g_row+1;
            as_xlsx.set_row( g_row, p_fillId => as_xlsx.get_fill( 'solid', '808080' ) );
            it.as_xlsx.cell(g_col, g_row, 'SECTOR PUBLICO NO FINANCIERO', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                                    , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_spnf_cta_cte, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_spnf_ahorro, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_spnf_cda, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_spnf_total_gs, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                          , p_borderId => as_xlsx.get_border( 'thin','', 'thin', 'thin' ));
            g_col := 2;
            g_row := g_row+1;
            it.as_xlsx.cell(g_col, g_row, 'A) GOBIERNO CENTRAL', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_cta_cte, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                     , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_ahorro, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                          , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_cda, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_total_gs, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( '','thin', 'thin', 'thin' ));
            g_col := 2;
            g_row := g_row+1;
            V_COUNT := V_COUNT + 1;
        end if;
        if v_categoria is null or v_categoria != r.categoria then 
           if r.categoria in ('ORG. DE PROMOCION Y DESARROLLO', 'MUNICIPALIDADES') then 
               if r.categoria = 'MUNICIPALIDADES' then
                it.as_xlsx.cell(g_col, g_row, 'III. GOBERNACIONES', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                                        , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := 2;
                g_row := g_row+1;
               else 
                it.as_xlsx.cell(g_col, g_row, case r.CATEGORIA
                                                when 'ORG. DE PROMOCION Y DESARROLLO' then 'C) ENTIDADES DESCENTRALIZADAS'
                                                end, p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                                        , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,v_ed_cta_cte , p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                          , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,v_ed_ahorro, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                               , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,v_ed_cda, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                    , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,v_ed_total_gs, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                           , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                              , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));

                g_col := 2;
                g_row := g_row +1;
                end if;
           end if;
            if r.categoria = 'SECTOR PUBLICO FINANCIERO' then 
                as_xlsx.set_row( g_row, p_fillId => as_xlsx.get_fill( 'solid', '808080' ) );
                v_tot_cta_cte := v_spnf_cta_cte  + r.CAT_CTA_CTE;
                v_tot_ahorro := v_spnf_ahorro  + r.CAT_AHORRO_A_LA_VISTA;
                v_tot_cda := v_spnf_cda  + r.CAT_CDA;
                v_tot_cta_cte_usd := v_spnf_cta_cte_usd  + r.CAT_CDA_USD;
                v_tot_ahorro_usd := v_spnf_ahorro_usd  + r.CAT_AHORRO_A_LA_VISTA_USD;
                v_tot_cda_usd := v_spnf_cda_usd  + r.CAT_CDA_USD;
                v_tot_total_gs := v_spnf_total_gs  + r.CAT_TOTAL_GS;
                v_tot_total_usd := v_spnf_total_usd  + r.CAT_TOTAL_USD;
            end if;

            it.as_xlsx.cell(g_col, g_row, case r.CATEGORIA
                                            when 'PODER LEGISLATIVO' then 'I. '||r.CATEGORIA
                                            when 'PODER EJECUTIVO' then 'II. '||r.CATEGORIA
                                            when 'MINISTERIOS' then '*. '||r.CATEGORIA
                                            when 'PODER JUDICIAL' then 'III. '||r.CATEGORIA
                                            when 'OTROS ORGANISMOS DEL ESTADO' then 'IV. '||r.CATEGORIA
                                            when 'FONDO DE SEGURIDAD SOCIAL' then 'B) '||r.CATEGORIA
                                            when 'ORG. DE PROMOCION Y DESARROLLO' then 'I. '||r.CATEGORIA
                                            when 'ENTIDADES REGULADORAS' then 'II. '||r.CATEGORIA
                                            when 'MUNICIPALIDADES' then 'IV. '||r.CATEGORIA
                                            when 'OTRAS ENTIDADES DESCENTRALIZADAS' then 'V. '||r.CATEGORIA
                                            when 'EMPRESAS PUBLICAS' then 'D) '||r.CATEGORIA
                                            else r.CATEGORIA
                                            end, p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,r.CAT_CTA_CTE + case when r.categoria = 'PODER EJECUTIVO' then v_pj_cta_cte else 0 end, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                      , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,r.CAT_AHORRO_A_LA_VISTA + case when r.categoria = 'PODER EJECUTIVO' then v_pj_ahorro else 0 end , p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                                , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                           , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,r.CAT_CDA + case when r.categoria = 'PODER EJECUTIVO' then v_pj_cda else 0 end, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                            , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,r.CAT_TOTAL_GS + case when r.categoria = 'PODER EJECUTIVO' then v_pj_total_gs else 0 end, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                       , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                          , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));

            g_col := 2;
            g_row := g_row +1;
            v_categoria:= r.categoria;
        end if; 
        it.as_xlsx.cell(g_col, g_row, '      '||r.ENTE, p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => FALSE)
                                                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, r.CTA_CTE, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, r.AHORRO_A_LA_VISTA, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, '', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, r.CDA, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, '', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, r.TOTAL_GS, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, '', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := 2;
        g_row := g_row +1;
    end loop;

    as_xlsx.set_row( g_row, p_fillId => as_xlsx.get_fill( 'solid', '808080' ) );
    it.as_xlsx.cell(g_col, g_row,'TOTAL GENERAL', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,v_tot_cta_cte, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,v_tot_ahorro, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                   , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,v_tot_cda, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                   , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,v_tot_total_gs, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                   , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                   , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));

    --2do reporte 
    v_categoria := null;
    g_col := 12;
    g_row := 8;
    v_count := 0;

for r in (select ENTE, CATEGORIA, CTA_CTE, AHORRO_A_LA_VISTA, CDA, CTA_CTE_USD, AHORRO_A_LA_VISTA_USD, CDA_USD,
                     TOTAL_GS, TOTAL_USD, CAT_CTA_CTE, CAT_AHORRO_A_LA_VISTA, CAT_CDA, CAT_CTA_CTE_USD, CAT_AHORRO_A_LA_VISTA_USD, CAT_CDA_USD,
                     CAT_TOTAL_GS, CAT_TOTAL_USD
               from IT.SB_ENTES_PUBLICOS_DET 
               where id = v_id 
               ORDER BY orden, ente) loop
        if v_count = 0 then 
            as_xlsx.set_row( g_row, p_fillId => as_xlsx.get_fill( 'solid', '808080' ) );
            it.as_xlsx.cell(g_col, g_row, 'EN DOLARES', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                                , p_fontsize => 8
                                                                                , p_bold => TRUE
                                                                                )
                                                                  , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', '' )
                                                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', '' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin','', '', 'thin' ));
            g_col := g_col+1;
            as_xlsx.mergecells( 12, g_row, 18, g_row);
            g_col := 12;
            g_row := g_row+1;
            it.as_xlsx.cell(g_col, g_row, 'CTA. CTE.', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'AHORRO A LA VISTA', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                             , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                             , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'AHORRO PLAZO', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'CDA', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'OTROS 1/', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'TOTAL', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                 , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                 , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row, 'PREST.A INST.', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin','thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true));

            g_col := 12;
            g_row := g_row+1;
            as_xlsx.set_row( g_row, p_fillId => as_xlsx.get_fill( 'solid', '808080' ) );
            it.as_xlsx.cell(g_col, g_row,v_spnf_cta_cte_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                            , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_spnf_ahorro_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                          , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_spnf_cda_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                        , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_spnf_total_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                         , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( 'thin','', 'thin', 'thin' ));
            g_col := 12;
            g_row := g_row+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_cta_cte_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                         , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_ahorro_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                        , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_cda_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                    , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,v_gc_total_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                        , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '','thin', 'thin', 'thin' ));
            g_col := 12;
            g_row := g_row+1;
            V_COUNT := V_COUNT + 1;
        end if;
        if v_categoria is null or v_categoria != r.categoria then 
            if r.categoria in ('ORG. DE PROMOCION Y DESARROLLO', 'MUNICIPALIDADES') then 
                if r.categoria = 'MUNICIPALIDADES' then
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                    g_col := g_col+1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                    g_col := g_col+1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                    g_col := g_col+1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                    g_col := g_col+1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                    g_col := g_col+1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                    g_col := g_col+1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                    g_col := 12;
                    g_row := g_row+1;
               else 
                
                it.as_xlsx.cell(g_col, g_row,v_ed_cta_cte_usd , p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                          , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,v_ed_ahorro_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                               , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,v_ed_cda_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                    , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,v_ed_total_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                                           , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col+1;
                it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                        , p_fontsize => 8
                                                                        , p_bold => TRUE)
                                              , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));

                g_col := 12;
                g_row := g_row +1;
                end if;
           
           end if;

            it.as_xlsx.cell(g_col, g_row,r.CAT_CTA_CTE_USD + case when r.categoria = 'PODER EJECUTIVO' then v_pj_cta_cte_usd else 0 end, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                      , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,r.CAT_AHORRO_A_LA_VISTA_USD + case when r.categoria = 'PODER EJECUTIVO' then v_pj_ahorro_usd else 0 end, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                                , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                           , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,r.CAT_CDA_USD+ case when r.categoria = 'PODER EJECUTIVO' then v_pj_cda_usd else 0 end , p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                            , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,r.CAT_TOTAL_USD + case when r.categoria = 'PODER EJECUTIVO' then v_pj_total_usd else 0 end, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                                       , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := g_col+1;
            it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                    , p_fontsize => 8
                                                                    , p_bold => TRUE)
                                          , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
            g_col := 12;
            g_row := g_row +1;
            v_categoria:= r.categoria;
        end if; 
        it.as_xlsx.cell(g_col, g_row, r.CTA_CTE_USD, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, r.AHORRO_A_LA_VISTA_USD, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, '', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, r.CDA_USD, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, '', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, r.TOTAL_USD, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row, '', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE)
                                                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := 12;
        g_row := g_row +1;
    end loop;

    as_xlsx.set_row( g_row, p_fillId => as_xlsx.get_fill( 'solid', '808080' ) );
    it.as_xlsx.cell(g_col, g_row,v_tot_cta_cte_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,v_tot_ahorro_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,v_tot_cda_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,v_tot_total_usd, p_numFmtId => v_fmt_miles
                                                           , p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col+1;
    it.as_xlsx.cell(g_col, g_row,'', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => TRUE)
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));

    g_col := 2;
    g_row := g_row +2;

    it.as_xlsx.cell(g_col, g_row,'1/ Bonos y Fideicomisos', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE));
    g_row := g_row +1;                                                                        
    it.as_xlsx.cell(g_col, g_row,'2/ Toda Institucion que no este especificada en el formulario y pertenezca a la clasificación', p_fontId => it.as_xlsx.get_font( 'TIMES NEW ROMAN'
                                                                            , p_fontsize => 8
                                                                            , p_bold => FALSE));        
    v_blob := it.as_xlsx.finish;
        INSERT INTO IT.SB_ENTES_PUBLICOS_ARCHIVOS ( nombre_archivo, contenido_blob ) VALUES ('Entes_Publicos_'||to_char(p_fecha,'DDMMYYYY'), v_blob ) 
		returning id into p_doc_id;
        COMMIT;

 end;
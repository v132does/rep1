CREATE OR REPLACE VIEW IT.SV_LCR_INF AS
SELECT t.fec_proceso,
       d.id_bcp,
       t.nro_item,
       t.id_padre,
       t.nro_agrupador,
       t.nro_orden,
       LEVEL AS nivel,
       LTRIM(SYS_CONNECT_BY_PATH(t.nro_orden, '.'), '.') AS orden_visual,
       LPAD(' ', (LEVEL - 1) * 3) ||
       TRANSLATE(
         REPLACE(NVL(t.grupo, t.sub_grupo), ',', '.'),
         'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛáàäâéèëêíìïîóòöôúùüûÑñ',
         'AAAAEEEEIIIIOOOOUUUUaaaaeeeeiiiioooouuuuNn'
      ) AS descripcion,

       t.sal_guaranies,
       t.sal_extranjera,
       t.sal_total,
       t.sal_gua_ponderado,
       t.sal_ext_ponderado,
       t.sal_tot_ponderado,

       TO_CHAR(t.fec_proceso, 'YYYYMMDD') || ';' ||
       d.id_bcp || ';;' ||

       CASE
          WHEN t.nro_item IN (101, 102, 103) THEN
             TO_CHAR(NVL(t.sal_gua_ponderado, 0),
                     'FM999999999999999990D0000',
                     'NLS_NUMERIC_CHARACTERS=''.,''')
          ELSE
             TO_CHAR(NVL(t.sal_guaranies, 0),
                     'FM999999999999999990D00',
                     'NLS_NUMERIC_CHARACTERS=''.,''')
       END || ';' ||

       CASE
          WHEN t.nro_item IN (101, 102, 103) THEN
             TO_CHAR(NVL(t.sal_ext_ponderado, 0),
                     'FM999999999999999990D0000',
                     'NLS_NUMERIC_CHARACTERS=''.,''')
          ELSE
             TO_CHAR(NVL(t.sal_extranjera, 0),
                     'FM999999999999999990D00',
                     'NLS_NUMERIC_CHARACTERS=''.,''')
       END || ';' ||

       CASE
          WHEN t.nro_item IN (101, 102, 103) THEN
             TO_CHAR(NVL(t.sal_tot_ponderado, 0),
                     'FM999999999999999990D0000',
                     'NLS_NUMERIC_CHARACTERS=''.,''')
          ELSE
             TO_CHAR(NVL(t.sal_total, 0),
                     'FM999999999999999990D00',
                     'NLS_NUMERIC_CHARACTERS=''.,''')
       END AS linea,

       d.reporta
  FROM it.sb_lcr_inf_final t
  JOIN it.sb_lcr_definiciones d
    ON d.nro_item = t.nro_item
 START WITH t.id_padre IS NULL
CONNECT BY PRIOR t.nro_item = t.id_padre
       AND PRIOR t.fec_proceso = t.fec_proceso
 ORDER SIBLINGS BY t.nro_agrupador, t.nro_orden;

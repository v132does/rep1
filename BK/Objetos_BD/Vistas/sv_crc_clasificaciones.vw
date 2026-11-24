create or replace force view it.SV_CRC_CLASIFICACIONES as
  select SUBSTR(TRIM(nro_formulario),1,3)                 ||';'||
               SUBSTR(TRIM(TO_CHAR(fecha, 'YYYYMMDD')),1,8)     ||';'||
               SUBSTR(TRIM(tip_documento),1,3)                  ||';'||
               SUBSTR(TRIM( decode(tip_documento, 'RUC',
                      decode(pas_cri.fu_obt_cod_entidad, 
                           2079,  nro_documento  || '-' || fue_obt_ruc_dig_verificador(nro_documento), 
                           6004,  nro_documento  || '-' || fue_obt_ruc_dig_verificador(nro_documento),
                           nro_documento  ),
                           nro_documento )),1,30)                            ||';'||
               SUBSTR(TRIM(cat_riesgo),1,2)                                  ||';'||
               SUBSTR(TRIM(cat_subjetiva),1,2)                               ||';'||
               SUBSTR(TRIM(cat_rie_fideicomiso),1,2)                         ||';'||
               SUBSTR(TRIM(to_char(nvl(por_prevision,0),        'FM990.00')),1,20)                 ||';'||
               SUBSTR(TRIM(to_char(nvl(mto_vta_cartera, 0),     'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(mto_deu_incobrable, 0),  'FM999999999999999990.00') ),1,20) ||';'||
               SUBSTR(TRIM(to_char(nvl(sal_cap_vencido, 0),     'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(sal_int_vencido, 0),     'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_garantia,0),         'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_cap_pri_prevision,0),'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_int_pri_prevision,0),'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_cap_seg_prevision,0),'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_int_seg_prevision,0),'FM999999999999999990.00')),1,20)  ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_tc,0),'FM999999999999999990.00')),1,20)                 ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_tr,0),'FM999999999999999990.00')),1,20)                 ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_dr,0),'FM999999999999999990.00')),1,20)                 ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_er,0),'FM999999999999999990.00')),1,20)                 ||';'||
               SUBSTR(TRIM(to_char(nvl(tot_sr,0),'FM999999999999999990.00')),1,20)                 ||';'||
               SUBSTR(TRIM(to_char(nvl(por_ing_mon_extranjera,0),'FM990.00')),1,5)                 ||';'||  --prc_ingreso_ext
               SUBSTR(TRIM(nro_registro),1,9)                                                               --nro_linea			   
               linea, 1 registro, fecha
         from  sb_crc_clasificaciones_det 
order by fecha, nro_registro;
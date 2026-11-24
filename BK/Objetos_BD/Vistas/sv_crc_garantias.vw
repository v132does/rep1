CREATE OR REPLACE VIEW IT.SV_CRC_GARANTIAS
AS SELECT to_number(d.nro_formulario) ||';'||
               to_char(d.fecha, 'yyyymmdd')||';'||
               d.cod_oficina ||';'||
               d.cod_mon_iso_garantia ||';'||
               nvl(to_char(d.nro_garantia), ' ') ||';'||
               nvl(d.cod_ref_bco_central, 0) ||';'||
               nvl(d.nro_inscripcion, ' ') ||';'||
               nvl(d.rango, 0) ||';'||
               nvl(to_char(d.fec_valor, 'yyyymmdd'), ' ') ||';'||
               nvl(to_char(d.fec_vencimiento, 'yyyymmdd'), ' ') ||';'||
               TO_CHAR(NVL(d.mto_gar_equ_local, 0) , 'FM999999999990.00') || ';' ||
               nvl(to_char(d.fec_ini_tasacion, 'yyyymmdd'), ' ') ||';'||
               nvl(to_char(d.fec_vto_tasacion, 'yyyymmdd'), ' ') ||';'||
               TO_CHAR(NVL(d.mto_tas_ase_equ_local, 0) , 'FM999999999990.00') || ';' ||
               TO_CHAR(NVL(d.mto_tas_no_ase_equ_local, 0) , 'FM999999999990.00') || ';' ||
               nvl(to_char(d.fec_ini_seguro, 'yyyymmdd'), ' ') ||';'||
               nvl(to_char(d.fec_vto_seguro, 'yyyymmdd'), ' ') ||';'||
               nvl(d.cod_mon_iso_seguro, ' ') ||';'||
               TO_CHAR(NVL(d.mto_seg_equ_local, 0) , 'FM999999999990.00') || ';' ||
               nvl(tip_gar_especifica, ' ') ||';'||
               nvl(d.perfeccionada, ' ') ||';'||
               it.fu_obt_ref_bcp_barrio(d.cod_persona)||';'||
               d.nro_registro linea,
               d.nro_registro registro,
               fecha
          FROM sb_crc_garantias_det d
         WHERE nom_referencia = 'GARANTIAS'
         ORDER BY d.fecha,d.nro_registro;
         
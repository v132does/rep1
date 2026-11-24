CREATE OR REPLACE PROCEDURE IT.PRA_INS_GE_CUENTAS
 (RP_GCUEN IN GE_CUENTAS%ROWTYPE
 )
 IS
BEGIN

   insert into ge_cuentas(nro_cuenta, dig_verificador,
                          denominacion, cod_modulo,
                          cod_modalidad,cod_oficina,
                          estado, fec_cam_estado,
                          sal_contable, cod_moneda,
                          fec_apertura, fec_vencimiento,
                          cod_cau_cancelacion, cod_tasa,
                          fre_extracto, tas_personalizada,
                          tra_prohibida, ret_personalizada,
                          dia_atraso, max_atraso,
                          pro_atraso, sal_promedio,
                          mto_mora)
   values (rp_gcuen.nro_cuenta, rp_gcuen.dig_verificador,
           rp_gcuen.denominacion, rp_gcuen.cod_modulo,
           rp_gcuen.cod_modalidad, rp_gcuen.cod_oficina,
           rp_gcuen.estado, rp_gcuen.fec_cam_estado,
           rp_gcuen.sal_contable, rp_gcuen.cod_moneda,
           rp_gcuen.fec_apertura, rp_gcuen.fec_vencimiento,
           rp_gcuen.cod_cau_cancelacion, rp_gcuen.cod_tasa,
           rp_gcuen.fre_extracto, rp_gcuen.tas_personalizada,
           rp_gcuen.tra_prohibida, rp_gcuen.ret_personalizada,
           rp_gcuen.dia_atraso, rp_gcuen.max_atraso,
           rp_gcuen.pro_atraso, rp_gcuen.sal_promedio,
           rp_gcuen.mto_mora );

END;
/


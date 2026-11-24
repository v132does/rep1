CREATE OR REPLACE PROCEDURE IT.PRA_UPD_GE_CUENTAS
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,RP_GCUEN IN GE_CUENTAS%ROWTYPE
 )
 IS
BEGIN
   --Actualiza los datos en GE_CUENTAS
   update ge_cuentas
   set ge_cuentas.dig_verificador = rp_gcuen.dig_verificador,
       ge_cuentas.denominacion = rp_gcuen.denominacion,
       ge_cuentas.cod_modulo = rp_gcuen.cod_modulo,
       ge_cuentas.cod_modalidad = rp_gcuen.cod_modalidad,
       ge_cuentas.cod_oficina = rp_gcuen.cod_oficina,
       ge_cuentas.estado = rp_gcuen.estado,
       ge_cuentas.fec_cam_estado = rp_gcuen.fec_cam_estado,
       ge_cuentas.sal_contable = rp_gcuen.sal_contable,
       ge_cuentas.cod_moneda = rp_gcuen.cod_moneda,
       ge_cuentas.fec_apertura = rp_gcuen.fec_apertura,
       ge_cuentas.fec_vencimiento = rp_gcuen.fec_vencimiento,
       ge_cuentas.cod_cau_cancelacion = rp_gcuen.cod_cau_cancelacion,
       ge_cuentas.cod_tasa = rp_gcuen.cod_tasa,
       ge_cuentas.fre_extracto = rp_gcuen.fre_extracto,
       ge_cuentas.tas_personalizada = rp_gcuen.tas_personalizada,
       ge_cuentas.tra_prohibida = rp_gcuen.tra_prohibida,
       ge_cuentas.ret_personalizada = rp_gcuen.ret_personalizada,
       ge_cuentas.dia_atraso = rp_gcuen.dia_atraso,
       ge_cuentas.max_atraso = rp_gcuen.max_atraso,
       ge_cuentas.pro_atraso = rp_gcuen.pro_atraso,
       ge_cuentas.sal_promedio = rp_gcuen.sal_promedio,
       ge_cuentas.mto_mora = rp_gcuen.mto_mora,
       ge_cuentas.nro_cuenta = rp_gcuen.nro_cuenta
   where ge_cuentas.nro_cuenta = p_nro_cuenta;

END;
/


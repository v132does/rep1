CREATE OR REPLACE TRIGGER IT.AA_GE_CUENTAS
 AFTER DELETE OR UPDATE
 ON GE_CUENTAS
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CUENTAS';
   r_gaudi.clave := :old.nro_cuenta;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
/*  r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIG_VERIFICADOR',:old.dig_verificador,:new.dig_verificador,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DENOMINACION',:old.denominacion,:new.denominacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_CAM_ESTADO',:old.fec_cam_estado,:new.fec_cam_estado,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_CONTABLE',:old.sal_contable,:new.sal_contable,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_CAU_CANCELACION',:old.cod_cau_cancelacion,:new.cod_cau_cancelacion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TASA',:old.cod_tasa,:new.cod_tasa,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FRE_EXTRACTO',:old.fre_extracto,:new.fre_extracto);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TAS_PERSONALIZADA',:old.tas_personalizada,:new.tas_personalizada);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TRA_PROHIBIDA',:old.tra_prohibida,:new.tra_prohibida);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'RET_PERSONALIZADA',:old.ret_personalizada,:new.ret_personalizada);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIA_ATRASO',:old.dia_atraso,:new.dia_atraso,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MAX_ATRASO',:old.max_atraso,:new.max_atraso,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PRO_ATRASO',:old.pro_atraso,:new.pro_atraso,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_PROMEDIO',:old.sal_promedio,:new.sal_promedio,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_MORA',:old.mto_mora,:new.mto_mora,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'N');
  */ -- NO es necesario porque la auditoria correspondiente se genera en el maestro base a excepcion de los siguientes campos:
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EST_VERIFICACION',:old.est_verificacion,:new.est_verificacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_VERIFICADOR',:old.cod_usu_verificador,:new.cod_usu_verificador);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_VERIFICACION',:old.fec_verificacion,:new.fec_verificacion,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


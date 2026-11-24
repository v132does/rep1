CREATE OR REPLACE TRIGGER IT.AA_GE_OPE_VENCIDAS
 AFTER DELETE OR UPDATE
 ON GE_OPE_VENCIDAS
 FOR EACH ROW

DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_OPE_VENCIDAS';
   r_gaudi.clave := :old.nro_cuenta;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CUENTA',:old.NRO_CUENTA,:new.NRO_CUENTA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CTA_ORIGEN',:old.NRO_CTA_ORIGEN,:new.NRO_CTA_ORIGEN);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.COD_MODULO,:new.COD_MODULO,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.COD_MODALIDAD,:new.COD_MODALIDAD,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFICINA',:old.COD_OFICINA,:new.COD_OFICINA,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.COD_MONEDA,:new.COD_MONEDA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DENOMINACION',:old.DENOMINACION,:new.DENOMINACION);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_APERTURA',:old.FEC_APERTURA,:new.FEC_APERTURA,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_INI_MORA',:old.FEC_INI_MORA,:new.FEC_INI_MORA,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TAS_PERSONALIZADA',:old.TAS_PERSONALIZADA,:new.TAS_PERSONALIZADA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_CAM_ESTADO',:old.FEC_CAM_ESTADO,:new.FEC_CAM_ESTADO,'D');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ULT_MOVIMIENTO',:old.FEC_ULT_MOVIMIENTO,:new.FEC_ULT_MOVIMIENTO,'D');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HOR_ULT_MOVIMIENTO',:old.HOR_ULT_MOVIMIENTO,:new.HOR_ULT_MOVIMIENTO);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_ORIGEN',:old.MTO_ORIGEN,:new.MTO_ORIGEN,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_TOTAL',:old.SAL_TOTAL,:new.SAL_TOTAL,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_TOT_BATCH',:old.SAL_TOT_BATCH,:new.SAL_TOT_BATCH,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_TASA',:old.VAL_TASA,:new.VAL_TASA,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_INTERES',:old.MTO_INTERES,:new.MTO_INTERES,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_INTERES',:old.SAL_INTERES,:new.SAL_INTERES,'M');
    --r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_INT_BATCH',:old.SAL_INT_BATCH,:new.SAL_INT_BATCH,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_INT_PUNITORIO',:old.MTO_INT_PUNITORIO,:new.MTO_INT_PUNITORIO,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_INT_MORATORIO',:old.MTO_INT_MORATORIO,:new.MTO_INT_MORATORIO,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_IMPUESTO',:old.MTO_IMPUESTO,:new.MTO_IMPUESTO,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TRA_PROHIBIDA',:old.TRA_PROHIBIDA,:new.TRA_PROHIBIDA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'REG_FIRMA',:old.REG_FIRMA,:new.REG_FIRMA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIA_ATR_INICIAL', :old.DIA_ATR_INICIAL, :new.DIA_ATR_INICIAL, 'N' );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIA_ATRASO',:old.dia_atraso, :new.dia_atraso, 'N' );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MAX_ATRASO',:old.max_atraso, :new.max_atraso, 'N' );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PRO_ATRASO',:old.pro_atraso, :new.pro_atraso, 'N' );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_MORA',:old.mto_mora, :new.mto_mora, 'M' );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_INT_PUNITORIO',:old.SAL_INT_PUNITORIO,:new.SAL_INT_PUNITORIO,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_INT_MORATORIO',:old.SAL_INT_MORATORIO,:new.SAL_INT_MORATORIO,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_IMPUESTO',:old.SAL_IMPUESTO,:new.SAL_IMPUESTO,'M');
 --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


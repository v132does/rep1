CREATE OR REPLACE TRIGGER IT.AA_AH_CTA_PLAZOS
 BEFORE DELETE OR UPDATE ON AH_CTA_PLAZOS
 FOR EACH ROW

DECLARE
   r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CTA_PLAZOS';
   r_aaudi.clave := :old.NRO_CUENTA;
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_CUENTA',:old.NRO_CUENTA,:new.NRO_CUENTA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'DIG_VERIFICADOR',:old.DIG_VERIFICADOR,:new.DIG_VERIFICADOR,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODULO',:old.COD_MODULO,:new.COD_MODULO,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODALIDAD',:old.COD_MODALIDAD,:new.COD_MODALIDAD,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_OFICINA',:old.COD_OFICINA,:new.COD_OFICINA,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MONEDA',:old.COD_MONEDA,:new.COD_MONEDA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'DENOMINACION',:old.DENOMINACION,:new.DENOMINACION);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_FIR_REQUERIDAS',:old.CAN_FIR_REQUERIDAS,:new.CAN_FIR_REQUERIDAS,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_FIR_REGISTRADAS',:old.CAN_FIR_REGISTRADAS,:new.CAN_FIR_REGISTRADAS,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_APERTURA',:old.FEC_APERTURA,:new.FEC_APERTURA,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_VENCIMIENTO',:old.FEC_VENCIMIENTO,:new.FEC_VENCIMIENTO,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAPITAL',:old.CAPITAL,:new.CAPITAL,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TAS_PERSONALIZADA',:old.TAS_PERSONALIZADA,:new.TAS_PERSONALIZADA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_TASA',:old.COD_TASA,:new.COD_TASA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_CAPITALIZACION',:old.TIP_CAPITALIZACION,:new.TIP_CAPITALIZACION,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'REN_AUTOMATICA',:old.REN_AUTOMATICA,:new.REN_AUTOMATICA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_CTA_CAPITALIZACION',:old.NRO_CTA_CAPITALIZACION,:new.NRO_CTA_CAPITALIZACION);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_USU_PROMOTOR',:old.COD_USU_PROMOTOR,:new.COD_USU_PROMOTOR);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'EST_BATCH',:old.EST_BATCH,:new.EST_BATCH);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_MOVIMIENTO',:old.FEC_ULT_MOVIMIENTO,:new.FEC_ULT_MOVIMIENTO,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'HOR_ULT_MOVIMIENTO',:old.HOR_ULT_MOVIMIENTO,:new.HOR_ULT_MOVIMIENTO);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_CAM_ESTADO',:old.FEC_CAM_ESTADO,:new.FEC_CAM_ESTADO,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_CAPITALIZACION',:old.FEC_ULT_CAPITALIZACION,:new.FEC_ULT_CAPITALIZACION,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'AUT_PENDIENTE',:old.AUT_PENDIENTE,:new.AUT_PENDIENTE);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_RET_BATCH',:old.SAL_RET_BATCH,:new.SAL_RET_BATCH,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_RETENIDO',:old.SAL_RETENIDO,:new.SAL_RETENIDO,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_BLO_BATCH',:old.SAL_BLO_BATCH,:new.SAL_BLO_BATCH,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_BLOQUEADO',:old.SAL_BLOQUEADO,:new.SAL_BLOQUEADO,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_TOT_BATCH',:old.SAL_TOT_BATCH,:new.SAL_TOT_BATCH,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_TOTAL',:old.SAL_TOTAL,:new.SAL_TOTAL,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TRA_PROHIBIDA',:old.TRA_PROHIBIDA,:new.TRA_PROHIBIDA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_CTA_RENOVADA',:old.NRO_CTA_RENOVADA,:new.NRO_CTA_RENOVADA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CANAL',:old.COD_CANAL,:new.COD_CANAL,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CAMPANA',:old.COD_CAMPANA,:new.COD_CAMPANA,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'REG_FIRMA',:old.REG_FIRMA,:new.REG_FIRMA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_PAGO',:old.FEC_PAGO,:new.FEC_PAGO);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CAU_CANCELACION',:old.COD_CAU_CANCELACION,:new.COD_CAU_CANCELACION);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'VAL_TASA',:old.VAL_TASA,:new.VAL_TASA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_PROVISION',:old.FEC_ULT_PROVISION,:new.FEC_ULT_PROVISION);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'PER_DEBITO',:old.PER_DEBITO,:new.PER_DEBITO);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_EXTRACTO',:old.FEC_ULT_EXTRACTO,:new.FEC_ULT_EXTRACTO);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_FOLIO',:old.NRO_FOLIO,:new.NRO_FOLIO); 
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FRE_EXTRACTO',:old.FRE_EXTRACTO,:new.FRE_EXTRACTO); 
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_ULT_EXTRACTO',:old.SAL_ULT_EXTRACTO,:new.SAL_ULT_EXTRACTO); 

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
EXCEPTION
   WHEN OTHERS THEN
     PRA_INS_AH_AUDITORIA(r_aaudi); -- para insertar hasata donde puede
END;
/

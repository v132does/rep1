CREATE OR REPLACE TRIGGER IT.AA_AH_CER_GRUPOS
 AFTER DELETE OR UPDATE
 ON AH_CER_GRUPOS
 FOR EACH ROW
DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CER_GRUPOS';
   r_aaudi.clave := :old.COD_CER_GRUPO;
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_OFICINA',:old.COD_OFICINA,:new.COD_OFICINA,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_USU_RESPONSABLE',:old.COD_USU_RESPONSABLE,:new.COD_USU_RESPONSABLE);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODULO',:old.COD_MODULO,:new.COD_MODULO,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODALIDAD',:old.COD_MODALIDAD,:new.COD_MODALIDAD,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_MONEDA',:old.TIP_MONEDA,:new.TIP_MONEDA);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SERIE',:old.SERIE,:new.SERIE);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_INICIAL',:old.NRO_INICIAL,:new.NRO_INICIAL,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_FINAL',:old.NRO_FINAL,:new.NRO_FINAL,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CANTIDAD',:old.CANTIDAD,:new.CANTIDAD,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'EST_ANTERIOR',:old.EST_ANTERIOR,:new.EST_ANTERIOR);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ULT_NRO_EMITIDO',:old.ULT_NRO_EMITIDO,:new.ULT_NRO_EMITIDO,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_DISPONIBLES',:old.CAN_DISPONIBLES,:new.CAN_DISPONIBLES,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_EMITIDOS',:old.CAN_EMITIDOS,:new.CAN_EMITIDOS,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_ANULADOS',:old.CAN_ANULADOS,:new.CAN_ANULADOS,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_ENTREGADOS',:old.CAN_ENTREGADOS,:new.CAN_ENTREGADOS,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CER_GRU_ORIGEN',:old.COD_CER_GRU_ORIGEN,:new.COD_CER_GRU_ORIGEN,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'OBSERVACION',:old.OBSERVACION,:new.OBSERVACION);
   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


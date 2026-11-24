CREATE OR REPLACE TRIGGER IT.AA_CC_SOBREGIROS
 AFTER DELETE OR UPDATE
 ON CC_SOBREGIROS
 FOR EACH ROW
DECLARE
   r_caudi cc_auditorias%ROWTYPE;
BEGIN
   /* CIE1303_PROD_SKIP_GENERADO */
   IF UPDATING
      AND NVL(pae_cnf.g_programa, 'X') = 'GPPROFIN'
      AND SYS_CONTEXT('USERENV', 'ACTION') = 'PR_LIQ_SOB_BATCH'
      AND (:old.generado <> :new.generado)
   THEN
      RETURN;
   END IF;

   r_caudi.tabla := 'CC_SOBREGIROS';
   r_caudi.clave := :old.nro_cuenta||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   IF UPDATING THEN
      r_caudi.tip_novedad := 'M';
   ELSIF DELETING THEN
      r_caudi.tip_novedad := 'E';
   END IF;

   r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SALDO',:old.saldo,:new.saldo,'M');
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_TOTAL',:old.sal_total,:new.sal_total,'M');
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_RETENIDO',:old.sal_retenido,:new.sal_retenido,'M');
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'LIQUIDADO',:old.liquidado,:new.liquidado);
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_LINEA',:old.mto_linea,:new.mto_linea,'M');
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CAN_DIAS',:old.can_dias,:new.can_dias,'N');
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_LIN_TRANSITORIA',:old.mto_lin_transitoria,:new.mto_lin_transitoria,'M');
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CAN_DIA_SOBREGIRO',:old.can_dia_sobregiro,:new.can_dia_sobregiro,'N');
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'GENERADO',:old.generado,:new.generado);
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/

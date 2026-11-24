CREATE OR REPLACE TRIGGER IT.AA_CC_LIN_SOB_GARANTIAS
 AFTER DELETE OR UPDATE
 ON CC_LIN_SOB_GARANTIAS
 FOR EACH ROW

DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_LIN_SOB_GARANTIAS';
   r_caudi.clave := to_char(:old.nro_secuencia)||'#'||to_char(:old.cod_garantia)||'#'||to_char(:old.nro_garantia);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_APLICADO',:old.mto_aplicado,:new.mto_aplicado,'M');
   r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'MTO_APL_COMPUTABLE', :old.mto_apl_computable, :new.mto_apl_computable, 'M' );
   r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'MTO_CON_COMPUTABLE', :old.mto_con_computable, :new.mto_con_computable, 'M' );
   r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'MTO_CON_NOCOMPUTABLE', :old.mto_con_nocomputable, :new.mto_con_nocomputable, 'M' );

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


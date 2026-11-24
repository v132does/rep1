CREATE OR REPLACE TRIGGER IT.AA_CR_EXP_CLIENTES
 AFTER DELETE OR UPDATE
 ON CR_EXP_CLIENTES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_EXP_CLIENTES';
   r_raudi.clave := :old.cod_persona||'#'||to_char(:old.ano_mes,'ddmmrrrr');
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_USU_OFICIAL',:old.cod_usu_oficial,:new.cod_usu_oficial);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TOT_PASIVO',:old.tot_pasivo,:new.tot_pasivo,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TOT_ACTIVO',:old.tot_activo,:new.tot_activo,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'RENTABILIDAD',:old.rentabilidad,:new.rentabilidad,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAN_PRODUCTOS',:old.can_productos,:new.can_productos,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAN_CTA_PASIVOS',:old.can_cta_pasivos,:new.can_cta_pasivos,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAN_CTA_ACTIVOS',:old.can_cta_activos,:new.can_cta_activos,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'POR_CRUZAMIENTO',:old.por_cruzamiento,:new.por_cruzamiento,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INT_COBRADOS',:old.int_cobrados,:new.int_cobrados,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INT_PAGADOS',:old.int_pagados,:new.int_pagados,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'MTO_COMISION',:old.mto_comision,:new.mto_comision,'M');

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


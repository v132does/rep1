CREATE OR REPLACE TRIGGER IT.AA_GE_CLI_SEGUROS
 AFTER DELETE OR UPDATE
 ON GE_CLI_SEGUROS
 FOR EACH ROW
DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_CLI_SEGUROS';
   r_eaudi.clave := :old.cod_persona||'#'||:old.nro_seguro;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_CUO_PAGADAS',:old.can_cuo_pagadas,:new.can_cuo_pagadas);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_CTA_DEBITO',:old.nro_cta_debito,:new.nro_cta_debito);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MOTIVO',:old.motivo,:new.motivo);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/


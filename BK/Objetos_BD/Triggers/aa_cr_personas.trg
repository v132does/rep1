CREATE OR REPLACE TRIGGER IT.AA_CR_PERSONAS
 AFTER DELETE OR UPDATE
 ON CR_CAM_PERSONAS
 FOR EACH ROW

DECLARE
   r_eaudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'CR_PERSONAS';
   r_eaudi.clave := to_char(:old.cod_campana)||'#'||:old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_CAMPANA',:old.cod_campana,:new.cod_campana,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_RESPONSABLE',:old.cod_usu_responsable,:new.cod_usu_responsable);
   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_eaudi);
END;
/


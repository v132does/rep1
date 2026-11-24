CREATE OR REPLACE TRIGGER IT.AA_CR_CAM_PERSONAS
 AFTER DELETE OR UPDATE
 ON CR_CAM_PERSONAS
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_CAM_PERSONAS';
   r_raudi.clave := to_char(:old.cod_campana)||'#'||:old.cod_persona;
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'ESTADO',:old.estado,:new.estado,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_USU_RESPONSABLE',:old.cod_usu_responsable,:new.cod_usu_responsable);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


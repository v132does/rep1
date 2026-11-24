CREATE OR REPLACE TRIGGER IT.AA_AP_DESARROLLOS
 AFTER DELETE OR UPDATE
 ON AP_DESARROLLOS
 FOR EACH ROW


DECLARE
r_eaudi ap_auditorias%rowtype; -- Registro de la tabla AP_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'AP_DESARROLLOS';
   r_eaudi.clave := to_char(:old.cod_requerimiento)||to_char(:old.cod_desarrollo);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';

   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_RESPONSABLE',:old.cod_usu_responsable,:new.cod_usu_responsable);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PROGRAMA',:old.cod_programa,:new.cod_programa);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TRANSFERIR',:old.transferir,:new.transferir);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'UBI_EJECUTABLE',:old.ubi_ejecutable,:new.ubi_ejecutable);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'UBI_FISICA',:old.ubi_fisica,:new.ubi_fisica);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_INICIO',:old.fec_inicio,:new.fec_inicio,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_FIN',:old.fec_fin,:new.fec_fin,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_TRANSFIERE',:old.cod_usu_transfiere,:new.cod_usu_transfiere);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_TRANSFERIDO',:old.fec_transferido,:new.fec_transferido,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_VERIFICA',:old.cod_usu_verifica,:new.cod_usu_verifica);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VERIFICADO',:old.fec_verificado,:new.fec_verificado,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);

   --- Insertar tabla de auditoria
   PRY_INS_AP_AUDITORIA(r_eaudi);
EXCEPTION
   WHEN OTHERS THEN
         PRY_INS_AP_AUDITORIA(r_eaudi);  -- inserto hasta donde puedo   
END;
/


CREATE OR REPLACE TRIGGER IT."AA_AH_TAR_DEB_PINES"
 BEFORE DELETE OR INSERT OR UPDATE
 ON AH_TAR_DEB_PINES
 FOR EACH ROW

DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_TAR_DEB_PINES';
   r_aaudi.clave := :old.nro_cuenta||'#'||:old.relacion;
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_EMISION',:old.nro_emision,:new.nro_emision);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NOM_EMBOZADO',:old.nom_embozado,:new.nom_embozado);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_PIN',:old.nro_pin,:new.nro_pin,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_PROCESO',:old.fec_proceso,:new.fec_proceso,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_IMPRESION',:old.FEC_IMPRESION,:new.FEC_IMPRESION);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'PIN_ENCRIPTADO',:old.PIN_ENCRIPTADO,:new.PIN_ENCRIPTADO);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'DET_ERROR',:old.DET_ERROR,:new.DET_ERROR);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'REGISTRO',:old.REGISTRO,:new.REGISTRO);	
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ESTADO',:old.Estado,:new.Estado);

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


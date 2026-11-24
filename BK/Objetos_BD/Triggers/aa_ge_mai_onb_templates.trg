CREATE OR REPLACE TRIGGER IT.AA_GE_MAI_ONB_TEMPLATES
 AFTER DELETE OR UPDATE
 ON it.GE_MAI_ONB_TEMPLATES
 FOR EACH ROW


DECLARE
 r_gaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_MAI_ONB_TEMPLATES';
   r_gaudi.clave := to_char(:old.tip_producto);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(1);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_PRODUCTO',:old.tip_producto,:new.tip_producto,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ASUNTO',:old.asunto,:new.asunto);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'INI_VIGENCIA',:old.ini_vigencia,:new.ini_vigencia,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FIN_VIGENCIA',:old.fin_vigencia,:new.fin_vigencia,'F');
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


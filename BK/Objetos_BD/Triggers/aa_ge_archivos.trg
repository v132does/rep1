CREATE OR REPLACE TRIGGER IT.AA_GE_ARCHIVOS
 AFTER DELETE OR UPDATE
 ON GE_ARCHIVOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_ARCHIVOS';
   r_gaudi.clave := :old.referencia||'#'||:old.archivo;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_SECUENCIA',:old.nro_secuencia,:new.nro_secuencia);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FOR_FECHA',:old.for_fecha,:new.for_fecha);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LIN_INICIAL',:old.lin_inicial,:new.lin_inicial,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LIN_FINAL',:old.lin_final,:new.lin_final,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SEPARADOR',:old.separador,:new.separador);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'UTI_LOADER',:old.UTI_LOADER,:new.UTI_LOADER);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


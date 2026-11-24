CREATE OR REPLACE TRIGGER IT.AA_GE_ARC_TABLAS
 AFTER DELETE OR UPDATE
 ON GE_ARC_TABLAS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_ARC_TABLAS';
   r_gaudi.clave := :old.referencia||'#'||:old.nom_tabla||'#'||:old.archivo;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_SECUENCIA',:old.nro_secuencia,:new.nro_secuencia);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


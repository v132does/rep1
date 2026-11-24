CREATE OR REPLACE TRIGGER IT.AA_TA_TAR_ESTADOS
 AFTER DELETE OR UPDATE
 ON TA_TAR_ESTADOS
 FOR EACH ROW


DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_TAR_ESTADOS';
   r_taudi.clave := to_char(:old.cod_estado);
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'BLO_AUTOMATICO',:old.blo_automatico,:new.blo_automatico);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/


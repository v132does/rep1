CREATE OR REPLACE TRIGGER IT.AA_GE_OFE_PRE_APROBADOS
 AFTER DELETE OR UPDATE
 ON GE_OFE_PRE_APROBADOS
 FOR EACH ROW
DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_OFE_PRE_APROBADOS';
   r_eaudi.clave := :old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OFERTA',:old.oferta,:new.oferta);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_ULT_OFERTA',:old.fec_ult_oferta,:new.fec_ult_oferta);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
--
/


CREATE OR REPLACE TRIGGER IT.AA_GE_CLI_INFORMACIONES
 AFTER DELETE OR UPDATE
 ON GE_CLI_INFORMACIONES
 FOR EACH ROW
DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_CLI_INFORMACIONES';
   r_eaudi.clave := :old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'INFORMACION',:old.informacion,:new.informacion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DAT_INFORMACION',:old.dat_informacion,:new.dat_informacion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DAT_INFORMACION_ANT',:old.dat_informacion_ant,:new.dat_informacion_ant);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
   --- verifico si ciertos datos fueron modificados

END;
/


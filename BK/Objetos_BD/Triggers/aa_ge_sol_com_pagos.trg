CREATE OR REPLACE TRIGGER IT.AA_GE_SOL_COM_PAGOS
 AFTER DELETE OR UPDATE
 ON GE_SOL_COM_PAGOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SOL_COM_PAGOS';
   r_gaudi.clave := to_char(:old.cod_referencia)||'#'||:old.tip_referencia||'#'||:old.tipo||'#'||to_char(:old.val_desde);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_HASTA',:old.val_hasta,:new.val_hasta,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


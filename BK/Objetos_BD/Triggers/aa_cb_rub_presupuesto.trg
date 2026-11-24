CREATE OR REPLACE TRIGGER IT.AA_CB_RUB_PRESUPUESTO
 AFTER DELETE OR UPDATE
 ON CB_RUB_PRESUPUESTO
 FOR EACH ROW

DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_RUB_PRESUPUESTO';
   r_baudi.clave := to_char(:old.ano)||'#'||:old.cod_rubro;
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MONTO',to_char(:old.monto),to_char(:new.monto));

   --- Insertar tabla de auditoria
   PRB_INS_CB_AUDITORIA(r_baudi);
END;
/


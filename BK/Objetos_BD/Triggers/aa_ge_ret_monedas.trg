CREATE OR REPLACE TRIGGER IT.AA_GE_RET_MONEDAS
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_RET_MONEDAS
 FOR EACH ROW


DECLARE
r_gaudi pr_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_RET_MONEDAS';
   r_gaudi.clave := to_char(:old.cod_retencion)||'#'||:old.cod_moneda;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CAN_DIAS',:old.can_dias,:new.can_dias,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


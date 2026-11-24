CREATE OR REPLACE TRIGGER IT.AA_GE_PAQ_MODALIDADES
 AFTER DELETE OR UPDATE
 ON GE_PAQ_MODALIDADES
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_PAQ_MODALIDADES';
   r_gaudi.clave := to_char(:old.cod_paquete)||'#'||to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.COD_SUB_MODALIDAD,:new.COD_SUB_MODALIDAD);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SUB_AFINIDAD',:old.SUB_AFINIDAD,:new.SUB_AFINIDAD);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'AFINIDAD',:old.AFINIDAD,:new.AFINIDAD);

--- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


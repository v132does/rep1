CREATE OR REPLACE TRIGGER IT.AA_AH_TAR_CTA_FICTICIAS
 AFTER DELETE OR UPDATE
 ON AH_TAR_CTA_FICTICIAS
 FOR EACH ROW
DECLARE
r_aaudi ah_auditorias%rowtype; 
-- Registro de la tabla AH_AUDITORIAS creado en Proyecto SDBIN8TDD-1
BEGIN
   r_aaudi.tabla := 'AH_TAR_CTA_FICTICIAS';
   r_aaudi.clave := to_char(:old.nro_cuenta)||'#'||to_char(:old.nro_cta_cliente);
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
end if;
   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_CTA_CLIENTE',:old.nro_cta_cliente,:new.nro_cta_cliente);
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_BIN',:old.nro_bin,:new.nro_bin);
   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


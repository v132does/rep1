CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_CERTIFICADOS
 AFTER DELETE OR UPDATE
 ON CC_CHE_CERTIFICADOS
 FOR EACH ROW
DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHE_CERTIFICADOS';
   r_caudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_cheque);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CTA_CERTIFICADO',:old.nro_cta_certificado,:new.nro_cta_certificado);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_PAGO',:old.fec_pago,:new.fec_pago,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_CAU_DEVOLUCION',:old.cod_cau_devolucion,:new.cod_cau_devolucion,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


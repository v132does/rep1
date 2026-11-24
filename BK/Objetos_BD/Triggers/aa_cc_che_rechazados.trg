CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_RECHAZADOS
 AFTER DELETE OR UPDATE
 ON CC_CHE_RECHAZADOS
 FOR EACH ROW

DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHE_RECHAZADOS';
   r_caudi.clave := to_char(:old.fec_proceso,'ddmmrrrr')||'#'||to_char(:old.cod_bco_emisor)||'#'||to_char(:old.nro_cheque);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CHEQUE',:old.nro_cheque,:new.nro_cheque);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CTA_LIBRADORA',:old.cta_libradora,:new.cta_libradora);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_BCO_EMISOR',:old.COD_BCO_EMISOR,:new.COD_BCO_EMISOR,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_BCO_RECEPTOR',:old.cod_ofi_camara,:new.cod_ofi_camara,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_PROCESO',:old.fec_proceso,:new.fec_proceso,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_OFI_CAMARA',:old.cod_ofi_camara,:new.cod_ofi_camara,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_CAU_DEVOLUCION',:old.cod_cau_devolucion,:new.cod_cau_devolucion);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COM_DIRECTA',:old.com_directa,:new.com_directa);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_RUBRO',:old.cod_rubro,:new.cod_rubro);    
    
   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


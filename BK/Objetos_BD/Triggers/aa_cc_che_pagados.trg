CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_PAGADOS
 AFTER DELETE OR UPDATE
 ON CC_CHE_PAGADOS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHE_PAGADOS';
   r_caudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_cheque);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'HORA',:old.hora,:new.hora);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CAJA',:old.nro_caja,:new.nro_caja,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_BANCO',:old.cod_banco,:new.cod_banco,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_OFI_ORIGEN',:old.cod_ofi_origen,:new.cod_ofi_origen,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_CAU_DEVOLUCION',:old.cod_cau_devolucion,:new.cod_cau_devolucion,'N');

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


CREATE OR REPLACE TRIGGER IT.AA_LC_CHE_VIAJEROS_DET
 AFTER DELETE OR UPDATE
 ON LC_CHE_VIAJEROS_DET
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_CHE_VIAJEROS_DET';
   r_laudi.clave := :old.nro_cta_bancaria||'#'||:old.cod_moneda||'#'||:old.serie||'#'||
                    to_char(:old.nro_inicial);
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'VALOR',:old.valor,:new.valor);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_RECEPCION',:old.fec_recepcion,:new.fec_recepcion,'F');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CAN_COMPRA',:old.can_compra,:new.can_compra,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CAN_VENTA',:old.can_venta,:new.can_venta,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_USU_EMISOR',:old.cod_usu_emisor,:new.cod_usu_emisor);
   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


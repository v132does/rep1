CREATE OR REPLACE TRIGGER IT.AA_CC_SOL_CHEQUERAS
 AFTER DELETE OR UPDATE
 ON CC_SOL_CHEQUERAS
 FOR EACH ROW
DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_SOL_CHEQUERAS';
   r_caudi.clave := :old.nro_cuenta||'#'||to_char(:old.fecha,'ddmmrrrr')||'#'||:old.hora;
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_TIP_CHEQUERA',:old.cod_tip_chequera,:new.cod_tip_chequera);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CANTIDAD',:old.cantidad,:new.cantidad,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CAN_HOJAS',:old.can_hojas,:new.can_hojas,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_OFI_RETIRO',:old.cod_ofi_retiro,:new.cod_ofi_retiro,'N');

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


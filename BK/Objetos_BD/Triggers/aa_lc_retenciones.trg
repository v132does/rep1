CREATE OR REPLACE TRIGGER IT.AA_LC_RETENCIONES
 AFTER DELETE OR UPDATE
 ON LC_RETENCIONES
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_RETENCIONES';
   r_laudi.clave := :old.nro_cuenta||'#'||to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||
                    to_char(:old.cod_oficina)||'#'||to_char(:old.nro_boleta)||'#'||to_char(:old.cod_retencion)||'#'||
                    to_char(:old.fec_fin,'ddmmrrrr');
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_INICIO',:old.fec_inicio,:new.fec_inicio,'F');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_OFI_ORIGEN',:old.cod_ofi_origen,:new.cod_ofi_origen,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'LIBERADO',:old.liberado,:new.liberado);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'DETALLADO',:old.detallado,:new.detallado);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TIP_REFERENCIA',:old.cod_tip_referencia,:new.cod_tip_referencia);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_REFERENCIA',:old.nro_referencia,:new.nro_referencia,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'LIB_ANTICIPADA',:old.lib_anticipada,:new.lib_anticipada);
   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


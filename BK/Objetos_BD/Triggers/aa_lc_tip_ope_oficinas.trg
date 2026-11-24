CREATE OR REPLACE TRIGGER IT.AA_LC_TIP_OPE_OFICINAS
 AFTER DELETE OR UPDATE
 ON LC_TIP_OPE_OFICINAS
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_TIP_OPE_OFICINAS';
   r_laudi.clave := :old.cod_tip_operacion||'#'||to_char(:old.cod_oficina)||'#'||:old.cod_moneda;
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_RUBRO',:old.cod_rubro,:new.cod_rubro);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TIP_REFERENCIA',:old.cod_tip_referencia,:new.cod_tip_referencia);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MAD_AFECTADA',:old.cod_mad_afectada,:new.cod_mad_afectada,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'TIP_MOVIMIENTO',:old.tip_movimiento,:new.tip_movimiento);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'TIP_APLICACION',:old.tip_aplicacion,:new.tip_aplicacion);
   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


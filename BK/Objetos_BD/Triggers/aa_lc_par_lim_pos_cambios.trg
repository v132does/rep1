CREATE OR REPLACE TRIGGER IT.AA_LC_PAR_LIM_POS_CAMBIOS
 AFTER DELETE OR UPDATE
 ON LC_PAR_LIM_POS_CAMBIOS
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_PAR_LIM_POS_CAMBIOS';
   r_laudi.clave := :old.codigo||'#'||to_char(:old.codigo);
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_LIM_SOB_COMPRA',:old.MTO_LIM_SOB_COMPRA,:new.MTO_LIM_SOB_COMPRA,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_LIM_SOB_VENTA',:old.MTO_LIM_SOB_VENTA,:new.MTO_LIM_SOB_VENTA,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_INI_VIGENCIA',:old.fec_ini_vigencia,:new.fec_ini_vigencia,'F');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_FIN_VIGENCIA',:old.fec_fin_vigencia,:new.fec_fin_vigencia,'F');
   --
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_PAT_EFECTIVO',:old.MTO_PAT_EFECTIVO,:new.MTO_PAT_EFECTIVO,'M');
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'POR_SOB_COMPRA',:old.POR_SOB_COMPRA,:new.POR_SOB_COMPRA,'N');
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'POR_SOB_VENTA',:old.POR_SOB_VENTA,:new.POR_SOB_VENTA,'N');
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'LIM_SOB_COM_DIARIO',:old.LIM_SOB_COM_DIARIO,:new.LIM_SOB_COM_DIARIO,'M');
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'LIM_SOB_VTA_DIARIO',:old.LIM_SOB_COM_DIARIO,:new.LIM_SOB_VTA_DIARIO,'M');
   --
   
   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


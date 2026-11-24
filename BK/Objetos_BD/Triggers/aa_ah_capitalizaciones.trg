CREATE OR REPLACE TRIGGER IT.AA_AH_CAPITALIZACIONES
 AFTER DELETE OR UPDATE
 ON AH_CAPITALIZACIONES
 FOR EACH ROW


DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CAPITALIZACIONES';
   r_aaudi.clave := :old.nro_cuenta||'#'||to_char(:old.fec_inicio,'ddmmrrrr');
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
end if;

   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_FIN',:old.fec_fin,:new.fec_fin,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_CAPITALIZACION',:old.tip_capitalizacion,:new.tip_capitalizacion,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_TASA',:old.cod_tasa,:new.cod_tasa,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_PROMEDIO',:old.sal_promedio,:new.sal_promedio,'M');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_ACUMULADO',:old.sal_acumulado,:new.sal_acumulado,'M');

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


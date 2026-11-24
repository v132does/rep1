CREATE OR REPLACE TRIGGER IT.AA_AH_CUPONES
 BEFORE DELETE OR UPDATE OF
  nro_cuenta
, tipo
, nro_cupon
, mto_interes
, fec_vencimiento
, estado
, fec_hor_emision
, fec_pago
, bloqueado
, endoso
 ON AH_CUPONES
 FOR EACH ROW
DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CUPONES';
   r_aaudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_cupon);
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
end if;

   --- Registrar Detalle
    r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'EST_BATCH',:old.est_batch,:new.est_batch);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'BLOQUEADO',:old.bloqueado,:new.bloqueado);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_HOR_EMISION',:old.fec_hor_emision,:new.fec_hor_emision,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_PAGO',:old.fec_pago,:new.fec_pago,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ENDOSO',:old.endoso,:new.endoso);
   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


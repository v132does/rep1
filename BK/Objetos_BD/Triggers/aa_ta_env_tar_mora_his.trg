CREATE OR REPLACE TRIGGER IT."AA_TA_ENV_TAR_MORA_HIS"
 AFTER DELETE OR UPDATE
 ON TA_ENV_TAR_MORA_HIS
 FOR EACH ROW


DECLARE
r_aaudi TA_AUDITORIAS%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'TA_ENV_TAR_MORA_HIS';
   r_aaudi.clave := :old.nro_tarjeta||'#'||SUBSTR(:old.fec_valor,1,4)||'#'||SUBSTR(:old.fec_valor,5,2);
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_TARJETA',:old.nro_tarjeta,:new.nro_tarjeta);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_VALOR',:old.fec_valor,:new.fec_valor);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CONCEPTO',:old.concepto,:new.concepto);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_MORA',:old.mto_mora,:new.mto_mora);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_CARGO',:old.tip_cargo,:new.tip_cargo);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_SALDO',:old.tip_saldo,:new.tip_saldo);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_TRAN',:old.tip_tran,:new.tip_tran);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FINANCIA',:old.financia,:new.financia);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'IVA',:old.iva,:new.iva);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'IMPUESTO_IVA',:old.impuesto_iva,:new.impuesto_iva);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MOV_RES1',:old.mov_res1,:new.mov_res1);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_PROCESADORA',:old.cod_procesadora,:new.cod_procesadora);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_PROCESO',:old.fec_proceso,:new.fec_proceso);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'DIA_MORA',:old.dia_mora,:new.dia_mora);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NOM_COMPLETO',:old.nom_completo,:new.nom_completo);

   --- Insertar tabla de auditoria
  PRT_INS_TA_AUDITORIA(r_aaudi);
END;
/


CREATE OR REPLACE TRIGGER IT.AA_CR_PER_VEHICULOS
 AFTER DELETE OR UPDATE
 ON CR_PER_VEHICULOS
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_PER_VEHICULOS';
   r_raudi.clave := :old.cod_persona||'#'||to_char(:old.nro_secuencia);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NRO_CHAPA',:old.nro_chapa,:new.nro_chapa);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_MARCA',:old.cod_marca,:new.cod_marca,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'MODELO',:old.modelo,:new.modelo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'ANO',:old.ano,:new.ano,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'VAL_COMERCIAL',:old.val_comercial,:new.val_comercial,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'PRENDADO',:old.prendado,:new.prendado);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'PRE_A_QUIEN',:old.pre_a_quien,:new.pre_a_quien);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'VAL_PRENDA',:old.val_prenda,:new.val_prenda,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_PRE_DESDE',:old.fec_pre_desde,:new.fec_pre_desde,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_PRE_HASTA',:old.fec_pre_hasta,:new.fec_pre_hasta,'F');

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


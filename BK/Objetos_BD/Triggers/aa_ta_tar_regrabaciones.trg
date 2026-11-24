CREATE OR REPLACE TRIGGER IT.AA_TA_TAR_REGRABACIONES
 AFTER DELETE OR UPDATE
 ON TA_TAR_REGRABACIONES
 FOR EACH ROW


DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_TAR_REGRABACIONES';
   r_taudi.clave := :old.nro_cuenta||'#'||:old.nro_tarjeta;
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle 
    r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_MOTIVO',:old.cod_motivo,:new.cod_motivo);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_TARJETA',:old.nro_tarjeta,:new.nro_tarjeta);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_TARJETA_NUEVA',:old.nro_tarjeta_nueva,:new.nro_tarjeta_nueva);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'MONTO',:old.monto,:new.monto);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COSTO',:old.costo,:new.costo);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'TIP_PLASTICO',:old.tip_plastico,:new.tip_plastico);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'ESTADO',:old.estado,:new.estado);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/


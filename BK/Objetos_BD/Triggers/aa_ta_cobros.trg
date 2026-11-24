CREATE OR REPLACE TRIGGER IT.AA_TA_COBROS
 AFTER DELETE OR UPDATE
 ON TA_COBROS
 FOR EACH ROW


DECLARE

r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_COBROS';
   r_taudi.clave := :old.nro_cuenta;
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_CUENTA',:old.NRO_CUENTA,:new.NRO_CUENTA);
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_TARJETA',:old.NRO_TARJETA,:new.NRO_TARJETA);
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_CTA_DEBITO',:old.NRO_CTA_DEBITO,:new.NRO_CTA_DEBITO);
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_PROCESO',:old.FEC_PROCESO,:new.FEC_PROCESO,'F');
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'MONTO',:old.MONTO,:new.MONTO,'N');
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'EST_ENVIO',:old.EST_ENVIO,:new.EST_ENVIO);
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_VALOR',:old.FEC_VALOR,:new.FEC_VALOR,'F');
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'OBSERVACION',:old.OBSERVACION,:new.OBSERVACION);
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'HORA',:old.HORA,:new.HORA);
   r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_USUARIO',:old.COD_USUARIO,:new.COD_USUARIO);
   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/


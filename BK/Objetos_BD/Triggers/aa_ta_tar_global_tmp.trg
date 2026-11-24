CREATE OR REPLACE TRIGGER IT.AA_TA_TAR_GLOBAL_TMP
AFTER DELETE OR UPDATE
ON TA_TAR_GLOBAL_TMP
FOR EACH ROW

DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   pae_cnf.g_cod_modulo := 5;
   r_taudi.tabla := 'TA_TAR_GLOBAL_TMP';
   r_taudi.clave := :old.nro_cuenta||'#'||:old.nro_tarjeta||'#'||:old.cod_persona;
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
    r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona);
    r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_TARJETA', :old.nro_tarjeta, :new.nro_tarjeta);
    r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento);
    r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_TARJETA', :old.tip_tarjeta, :new.tip_tarjeta);
    r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PRODUCTO', :old.cod_producto, :new.cod_producto);
    r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ESTADO', :old.cod_estado, :new.cod_estado);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/

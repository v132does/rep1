CREATE OR REPLACE TRIGGER IT.AA_TA_BLO_AUT_TARJETAS
 AFTER DELETE OR UPDATE
 ON TA_BLO_AUT_TARJETAS
 FOR EACH ROW


DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_BLO_AUT_TARJETAS';
   r_taudi.clave := :old.cod_persona||'#'||:old.nro_tarjeta;
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;

    -- Registrar Detalle
    r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_TARJETA',:old.nro_tarjeta,:new.nro_tarjeta);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'DAT_BLOQUEO',:old.dat_bloqueo,:new.dat_bloqueo);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'MOT_BLOQUEO',:old.mot_bloqueo,:new.mot_bloqueo);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'ESTADO',:old.estado,:new.estado);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/


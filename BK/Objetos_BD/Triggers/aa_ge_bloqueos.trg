CREATE OR REPLACE TRIGGER IT.AA_GE_BLOQUEOS
 AFTER DELETE OR UPDATE
 ON GE_BLOQUEOS
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_BLOQUEOS';
   r_gaudi.clave := :old.nro_cuenta||'#'||to_char(:old.fec_inicio,'ddmmrrrr');
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);



   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_DOCUMENTO',:old.nro_documento,:new.nro_documento,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_EQUIVALENTE',:old.mto_equivalente,:new.mto_equivalente,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COTIZACION',:old.cotizacion,:new.cotizacion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HOR_INICIO',:old.hor_inicio,:new.hor_inicio);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_FIN',:old.fec_fin,:new.fec_fin,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_BLOQUEO',:old.tip_bloqueo,:new.tip_bloqueo);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


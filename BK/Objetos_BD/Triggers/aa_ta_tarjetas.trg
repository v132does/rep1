CREATE OR REPLACE TRIGGER IT.AA_TA_TARJETAS
 AFTER DELETE OR UPDATE
 ON TA_TARJETAS
 FOR EACH ROW


DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_TARJETAS';
   r_taudi.clave := :old.nro_cuenta||'#'||:old.nro_tarjeta;
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_ESTADO',:old.cod_estado,:new.cod_estado,'N');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NOM_EMBOZAR',:old.nom_embozar,:new.nom_embozar);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NOM_ENVIAR',:old.nom_enviar,:new.nom_enviar);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'VIGENTE',:old.vigente,:new.vigente);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_EMISION',:old.fec_emision,:new.fec_emision,'F');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_SOLICITUD',:old.fec_solicitud,:new.fec_solicitud,'F');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'TIP_ENVIO',:old.tip_envio,:new.tip_envio);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'REFERENCIA',:old.referencia,:new.referencia);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_PLANILLA',:old.nro_planilla,:new.nro_planilla,'N');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'TIP_PLANILLA',:old.tip_planilla,:new.tip_planilla,'N');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_PLA_ANTERIOR',:old.nro_pla_anterior,:new.nro_pla_anterior,'N');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_ENTREGA',:old.fec_entrega,:new.fec_entrega,'F');

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/


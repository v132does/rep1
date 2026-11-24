CREATE OR REPLACE TRIGGER IT.AA_CR_CAMPANAS
 AFTER DELETE OR UPDATE
 ON CR_CAMPANAS
 FOR EACH ROW



DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_CAMPANAS';
   r_raudi.clave := to_char(:old.cod_campana);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_SEGMENTO',:old.cod_segmento,:new.cod_segmento);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'DETALLE',:old.detalle,:new.detalle);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_INICIO',:old.fec_inicio,:new.fec_inicio,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'ESTADO',:old.estado,:new.estado,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'AGE_GENERADA',:old.age_generada,:new.age_generada);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAR_GENERADA',:old.car_generada,:new.car_generada);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'EMA_ENVIADO',:old.ema_enviado,:new.ema_enviado);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NOT_GENERADA',:old.not_generada,:new.not_generada);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TIP_RESPONSABLE',:old.tip_responsable,:new.tip_responsable);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_INI_ACTIVIDAD',:old.fec_ini_actividad,:new.fec_ini_actividad,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_FIN_ACTIVIDAD',:old.fec_fin_actividad,:new.fec_fin_actividad,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_ACTIVIDAD',:old.cod_actividad,:new.cod_actividad);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_MOT_ACTIVIDAD',:old.cod_mot_actividad,:new.cod_mot_actividad);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'AUTOMATICO',:old.automatico,:new.automatico);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FRECUENCIA',:old.frecuencia,:new.frecuencia);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'GEN_AGENDA',:old.gen_agenda,:new.gen_agenda);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'GEN_CARTA',:old.gen_carta,:new.gen_carta);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'GEN_NOTA',:old.gen_nota,:new.gen_nota);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'GEN_MAIL',:old.gen_mail,:new.gen_mail);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAN_ACT_DIARIO',:old.can_act_diario,:new.can_act_diario);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'GEN_INHIBICION',:old.gen_inhibicion ,:new.gen_inhibicion );
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INH_GENERADA',:old.inh_generada,:new.inh_generada);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INH_COD_CAUSA',:old.inh_cod_causa,:new.inh_cod_causa,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INH_ORIGEN',:old.inh_origen,:new.inh_origen);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INH_DETALLE',:old.inh_detalle,:new.inh_detalle);
   r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'NOT_TIPO', :old.not_tipo, :new.not_tipo );
   r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'NOT_MEDIO', :old.not_medio, :new.not_medio );
   r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'EMA_ASUNTO', :old.ema_asunto, :new.ema_asunto );
   r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'EMA_DETALLE', :old.ema_detalle, :new.ema_detalle );
   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
EXCEPTION
  when others then
    prr_ins_cr_auditoria( r_raudi );
END;
/


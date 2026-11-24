CREATE OR REPLACE TRIGGER IT.AA_AP_PROYECTOS
 AFTER DELETE OR UPDATE
 ON AP_PROYECTOS
 FOR EACH ROW


DECLARE
r_eaudi ap_auditorias%rowtype; -- Registro de la tabla AP_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'AP_PROYECTOS';
   r_eaudi.clave := to_char(:old.cod_proyecto)||to_char(:old.cod_plan) ;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';

   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_AREA',:old.cod_area,:new.cod_area,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_INICIO',:old.fec_inicio,:new.fec_inicio,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_FIN',:old.fec_fin,:new.fec_fin,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DURACION',:old.duracion,:new.duracion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SITUACION',:old.situacion,:new.situacion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PRIORIDAD',:old.prioridad,:new.prioridad);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ORDEN',:old.orden,:new.orden);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_PRESUPUESTADO',:old.mto_presupuestado,:new.mto_presupuestado,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_EJECUTADO',:old.mto_ejecutado,:new.mto_ejecutado,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'POR_EJECUTADO',:old.por_ejecutado,:new.por_ejecutado,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'APROBADO',:old.aprobado,:new.aprobado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DES_DETALLADA',:old.des_detallada,:new.des_detallada);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_INI_REAL',:old.fec_ini_real,:new.fec_ini_real,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_FIN_REAL',:old.fec_fin_real,:new.fec_fin_real,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DUR_REAL',:old.dur_real,:new.dur_real);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'POR_AVANCE',:old.por_avance,:new.por_avance,'M');

     --- Insertar tabla de auditoria
   PRY_INS_AP_AUDITORIA(r_eaudi);
END;
/


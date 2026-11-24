CREATE OR REPLACE TRIGGER IT.AA_BA_USUARIOS
 AFTER DELETE OR UPDATE
 ON BA_USUARIOS
 FOR EACH ROW


DECLARE
   r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_USUARIOS';
   r_eaudi.clave := :old.cod_usuario;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NOMBRE',:old.nombre,:new.nombre);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_AREA',:old.cod_area,:new.cod_area,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CATEGORIA',:old.categoria,:new.categoria);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OFICIAL',:old.oficial,:new.oficial);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'VER_CTA_EMPLEADOS',:old.ver_cta_empleados,:new.ver_cta_empleados);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PROMOTOR',:old.promotor,:new.promotor);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ATN_PUBLICO',:old.atn_publico,:new.atn_publico);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_INGRESO',:old.fec_ingreso,:new.fec_ingreso,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CARGO',:old.cargo,:new.cargo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TELEFONO',:old.telefono,:new.telefono);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_INTERNO',:old.nro_interno,:new.nro_interno,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DIR_CORREO',:old.dir_correo,:new.dir_correo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'GRU_AGENDA',:old.gru_agenda,:new.gru_agenda);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_EXP_CLAVE',:old.fec_exp_clave,:new.fec_exp_clave,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_BANCA',:old.cod_banca,:new.cod_banca,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_SUPERVISOR',:old.cod_usu_supervisor,:new.cod_usu_supervisor);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'VER_CLI_CONFIDENCIAL',:old.ver_cli_confidencial,:new.ver_cli_confidencial);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/


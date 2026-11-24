CREATE OR REPLACE TRIGGER IT.AA_CR_REF_PERSONALES
 AFTER DELETE OR UPDATE
 ON CR_REF_PERSONALES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_REF_PERSONALES';
   r_raudi.clave := :old.cod_persona||'#'||to_char(:old.nro_secuencia);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_REFERENCIA',:old.cod_referencia,:new.cod_referencia,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TIP_REFERENCIA',:old.tip_referencia,:new.tip_referencia);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NRO_SECUENCIA',:old.nro_secuencia,:new.nro_secuencia,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NOM_PERSONA',:old.nom_persona,:new.nom_persona);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TELEFONOS',:old.telefonos,:new.telefonos);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'LUG_TRABAJO',:old.lug_trabajo,:new.lug_trabajo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'PUESTO',:old.puesto,:new.puesto);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'REL_PERSONA',:old.rel_persona,:new.rel_persona);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'EST_VERIFICACION',:old.est_verificacion,:new.est_verificacion);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CONOCE',:old.conoce,:new.conoce);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'REC_MENSAJE',:old.rec_mensaje,:new.rec_mensaje);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CNF_DAT_PARTICULARES',:old.cnf_dat_particulares,:new.cnf_dat_particulares);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CNF_DAT_LABORALES',:old.cnf_dat_laborales,:new.cnf_dat_laborales);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_USU_VERIFICADOR',:old.cod_usu_verificador,:new.cod_usu_verificador);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_VERIFICACION',:old.fec_verificacion,:new.fec_verificacion,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_INF_LABORAL',:old.cod_inf_laboral,:new.cod_inf_laboral,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NOM_PER_INFORMO',:old.nom_per_informo,:new.nom_per_informo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAR_PER_INFORMO',:old.car_per_informo,:new.car_per_informo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NOM_PER_CERTIFICO',:old.nom_per_certifico,:new.nom_per_certifico);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAR_PER_CERTIFICO',:old.car_per_certifico,:new.car_per_certifico);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_PAIS',:old.cod_pais,:new.cod_pais);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_CIUDAD',:old.cod_ciudad,:new.cod_ciudad);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'DIRECCION',:old.direccion,:new.direccion);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


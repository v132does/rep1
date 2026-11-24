CREATE OR REPLACE TRIGGER IT.AA_BA_PER_JURIDICAS
 AFTER DELETE OR UPDATE
 ON BA_PER_JURIDICAS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GMPROARC' then
   -- para no generar auditoria de la importacion de datos (OFAC, OSC, ETC)
   r_eaudi.tabla := 'BA_PER_JURIDICAS';
   r_eaudi.clave := :old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'RAZ_SOCIAL',:old.raz_social,:new.raz_social);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NOM_COMERCIAL',:old.nom_comercial,:new.nom_comercial);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NATURALEZA',:old.naturaleza,:new.naturaleza);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_RAMO',:old.cod_ramo,:new.cod_ramo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAP_OPERATIVO',:old.cap_operativo,:new.cap_operativo,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_AREA',:old.cod_area,:new.cod_area);

   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VTO_SOCIEDAD',:old.fec_vto_sociedad,:new.fec_vto_sociedad);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'AGE_RETENCION',:old.age_retencion,:new.age_retencion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_SUCURSALES',:old.can_sucursales,:new.can_sucursales);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_SOCIOS',:old.can_socios,:new.can_socios);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_EMPLEADOS',:old.can_empleados,:new.can_empleados);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIP_ACT_INTERNACIONAL',:old.tip_act_internacional,:new.tip_act_internacional);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
end if;
END;
/


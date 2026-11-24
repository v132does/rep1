CREATE OR REPLACE TRIGGER IT.AA_BA_PER_FISICAS
 AFTER DELETE OR UPDATE
 ON BA_PER_FISICAS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GMPROARC' then 
   -- para no generar auditoria de la importacion de datos (OFAC, OSC, ETC)
   r_eaudi.tabla := 'BA_PER_FISICAS';
   r_eaudi.clave := :old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PRI_NOMBRE',:old.pri_nombre,:new.pri_nombre);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PRI_APELLIDO',:old.pri_apellido,:new.pri_apellido);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'EST_CIVIL',:old.est_civil,:new.est_civil);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_SEXO',:old.cod_sexo,:new.cod_sexo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_NIV_ESTUDIO',:old.cod_niv_estudio,:new.cod_niv_estudio,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_TIP_VIVIENDA',:old.cod_tip_vivienda,:new.cod_tip_vivienda,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PAI_NACIONALIDAD',:old.cod_pai_nacionalidad,:new.cod_pai_nacionalidad,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SEG_NOMBRE',:old.seg_nombre,:new.seg_nombre);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SEG_APELLIDO',:old.seg_apellido,:new.seg_apellido);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_NACIMIENTO',:old.fec_nacimiento,:new.fec_nacimiento,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_HIJOS',:old.can_hijos,:new.can_hijos,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PROFESION',:old.cod_profesion,:new.cod_profesion,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_TITULO',:old.cod_titulo ,:new.cod_titulo ,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_PERSONAS',:old.can_personas ,:new.can_personas ,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PATRIMONIO',:old.patrimonio ,:new.patrimonio ,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_ACTIVIDAD',:old.cod_actividad ,:new.cod_actividad, 'N');
   
   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
End if;   
END;
/


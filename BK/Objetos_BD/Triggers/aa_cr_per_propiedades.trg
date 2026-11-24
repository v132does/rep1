CREATE OR REPLACE TRIGGER IT.AA_CR_PER_PROPIEDADES
 AFTER DELETE OR UPDATE
 ON CR_PER_PROPIEDADES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_PER_PROPIEDADES';
   r_raudi.clave := :old.cod_persona||'#'||:old.nro_finca;
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_DISTRITO',:old.cod_distrito,:new.cod_distrito,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'UBICACION',:old.ubicacion,:new.ubicacion);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CTA_CATASTRAL',:old.cta_catastral,:new.cta_catastral);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'MET_TERRENO',:old.met_terreno,:new.met_terreno,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'MET_CONSTRUIDO',:old.met_construido,:new.met_construido,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'VAL_COMERCIAL',:old.val_comercial,:new.val_comercial,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'HIPOTECADO',:old.hipotecado,:new.hipotecado);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'HIP_A_QUIEN',:old.hip_a_quien,:new.hip_a_quien);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'VAL_HIPOTECA',:old.val_hipoteca,:new.val_hipoteca,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_HIP_DESDE',:old.fec_hip_desde,:new.fec_hip_desde,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_HIP_HASTA',:old.fec_hip_hasta,:new.fec_hip_hasta,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TIP_PROPIEDAD',:old.tip_propiedad,:new.tip_propiedad);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


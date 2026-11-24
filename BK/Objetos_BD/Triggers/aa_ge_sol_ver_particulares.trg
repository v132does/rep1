CREATE OR REPLACE TRIGGER IT.AA_GE_SOL_VER_PARTICULARES
 AFTER DELETE OR UPDATE
 ON GE_SOL_VER_PARTICULARES
 FOR EACH ROW

DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SOL_VER_PARTICULARES';
   r_gaudi.clave := to_char(:old.nro_solicitud);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EXISTE',:old.existe,:new.existe);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_FACHADA',:old.tip_fachada,:new.tip_fachada);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_CONSTRUCCION',:old.tip_construccion,:new.tip_construccion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TIP_VIVIENDA',:old.cod_tip_vivienda,:new.cod_tip_vivienda,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_UBICACION',:old.tip_ubicacion,:new.tip_ubicacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_ACCESO',:old.tip_acceso,:new.tip_acceso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_ZONA',:old.tip_zona,:new.tip_zona);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_RELACION',:old.tip_relacion,:new.tip_relacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NOM_PER_INFORMO',:old.nom_per_informo,:new.nom_per_informo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EVALUACION',:old.evaluacion,:new.evaluacion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_DIRECCION',:old.cod_direccion,:new.cod_direccion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_VERIFICADOR',:old.cod_usu_verificador,:new.cod_usu_verificador);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


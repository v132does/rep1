CREATE OR REPLACE TRIGGER IT.AA_CC_SAL_CAMARA
 AFTER DELETE OR UPDATE
 ON CC_SAL_CAMARA
 FOR EACH ROW




DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_SAL_CAMARA';
   r_caudi.clave :=  to_char(:old.cod_ofi_camara)||'#'||:old.cod_moneda||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'BCP_CHE_ENVIADOS',:old.BCP_CHE_ENVIADOS,:new.BCP_CHE_ENVIADOS,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'BCP_CHE_RECIBIDOS',:old.BCP_CHE_RECIBIDOS,:new.BCP_CHE_RECIBIDOS,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'BCP_CHE_DEV_CAMARA',:old.BCP_CHE_DEV_CAMARA,:new.BCP_CHE_DEV_CAMARA,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'BCP_CHE_DEV_A_CAMARA',:old.BCP_CHE_DEV_A_CAMARA,:new.BCP_CHE_DEV_A_CAMARA,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'BCP_CHE_SUC_ENVIADOS',:old.BCP_CHE_SUC_ENVIADOS,:new.BCP_CHE_SUC_ENVIADOS,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SIS_CHE_ENVIADOS',:old.SIS_CHE_ENVIADOS,:new.SIS_CHE_ENVIADOS,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SIS_CHE_RECIBIDOS',:old.SIS_CHE_RECIBIDOS,:new.SIS_CHE_RECIBIDOS,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SIS_CHE_DEV_CAMARA',:old.SIS_CHE_DEV_CAMARA,:new.SIS_CHE_DEV_CAMARA,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SIS_CHE_DEV_A_CAMARA',:old.SIS_CHE_DEV_A_CAMARA,:new.SIS_CHE_DEV_A_CAMARA,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SIS_CHE_SUC_ENVIADOS',:old.SIS_CHE_SUC_ENVIADOS,:new.SIS_CHE_SUC_ENVIADOS,'M');

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


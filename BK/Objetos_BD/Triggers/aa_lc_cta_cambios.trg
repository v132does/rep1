CREATE OR REPLACE TRIGGER IT.AA_LC_CTA_CAMBIOS
 AFTER DELETE OR UPDATE
 ON LC_CTA_CAMBIOS
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_CTA_CAMBIOS';
   r_laudi.clave := :old.nro_cuenta;
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'DIG_VERIFICADOR',:old.dig_verificador,:new.dig_verificador,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'DENOMINACION',:old.denominacion,:new.denominacion);
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'D');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CHE_VIAJEROS',:old.che_viajeros,:new.che_viajeros);
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'D');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_CAM_ESTADO',:old.fec_cam_estado,:new.fec_cam_estado,'D');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'EST_BATCH',:old.est_batch,:new.est_batch);
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_LINEA',:old.nro_linea,:new.nro_linea,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_BCP',:old.cod_bcp,:new.cod_bcp,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_LIMITE',:old.mto_limite,:new.mto_limite,'M');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_UTILIZADO',:old.mto_utilizado,:new.mto_utilizado,'M');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_UTI_BATCH',:old.mto_uti_batch,:new.mto_uti_batch,'M');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_ULT_MOVIMIENTO',:old.fec_ult_movimiento,:new.fec_ult_movimiento,'D');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CORRESPONSAL',:old.corresponsal,:new.corresponsal);

   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


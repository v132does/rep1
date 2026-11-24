CREATE OR REPLACE TRIGGER IT.AA_CB_RG_90
  before DELETE OR UPDATE 
  on CB_RG_90  
  for each row
declare
   r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
begin
   r_gaudi.tabla := 'CB_RG_90';
   r_gaudi.clave := :old.tipo_registro||'#'||:old.nro_identificador||'#'||
   :old.nro_timbrado||'#'||:old.nro_comprobante;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   -- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIPO_REGISTRO',:old.tipo_registro,:new.tipo_registro);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TIP_DOCUMENTO',:old.cod_tip_documento,:new.cod_tip_documento);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_IDENTIFICADOR',:old.nro_identificador,:new.nro_identificador);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'RAZ_SOCIAL',:old.raz_social,:new.raz_social);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TIP_COMPROBANTE',:old.cod_tipo_comprobante,:new.cod_tipo_comprobante);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FECHA_EMISION',:old.fecha_emision,:new.fecha_emision);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_TIMBRADO',:old.nro_timbrado,:new.nro_timbrado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_COMPROBANTE',:old.nro_comprobante,:new.nro_comprobante);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO_GRABADO_10',:old.monto_gravado_10,:new.monto_gravado_10);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO_GRABADO_5',:old.monto_gravado_5,:new.monto_gravado_5);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO_EXENTO',:old.monto_exento,:new.monto_exento);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO_TOTAL',:old.Monto_Total,:new.Monto_Total);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CONDICION',:old.condicion,:new.condicion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONEDA_EXTRANJERA',:old.moneda_extranjera,:new.moneda_extranjera);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'IMPUTA_IVA',:old.imputa_iva,:new.imputa_iva);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'IMPUTA_IRE',:old.imputa_ire,:new.imputa_ire);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'IMPUTA_IRP_RSP',:old.imputa_irp_rsp,:new.imputa_irp_rsp);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NO_IMPUTA',:old.no_imputa,:new.no_imputa);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FACTURA_ASOCIADA',:old.factura_asociada,:new.factura_asociada);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIMPRADO_ASOCIADO',:old.timbrado_asociado,:new.timbrado_asociado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_PROCESO',:old.fec_proceso,:new.fec_proceso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PERIODO',:old.periodo,:new.periodo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'GENERADO',:old.generado,:new.generado);

   -- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
end AA_CB_RG_90;
/


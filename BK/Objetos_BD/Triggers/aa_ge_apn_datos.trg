CREATE OR REPLACE TRIGGER IT.AA_GE_APN_DATOS
  AFTER DELETE OR UPDATE
     ON IT.GE_APN_DATOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 29/12/2014 a las 10:06:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_APN_DATOS';
  rg_raudi.clave := to_char( :old.COD_MTCN);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MTCN', :old.COD_MTCN, :new.COD_MTCN);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'REFERENCIA', :old.REFERENCIA, :new.REFERENCIA );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'EST_NOTIFICADO', :old.EST_NOTIFICADO, :new.EST_NOTIFICADO);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_NOTIFICADO', :old.FEC_NOTIFICADO, :new.FEC_NOTIFICADO);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_ERR_NOT', :old.COD_ERR_NOT, :new.COD_ERR_NOT);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'SUB_COD_ERR_NOT', :old.SUB_COD_ERR_NOT, :new.SUB_COD_ERR_NOT );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'DESC_ERR_NOT', :old.DESC_ERR_NOT, :new.DESC_ERR_NOT );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_ERR_OPE', :old.COD_ERR_OPE, :new.COD_ERR_OPE);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'DOC_BENEFICIARIO', :old.DOC_BENEFICIARIO, :new.DOC_BENEFICIARIO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CTA_BENEFICIARIO', :old.CTA_BENEFICIARIO, :new.CTA_BENEFICIARIO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MTO_TRANSF', :old.MTO_TRANSF, :new.MTO_TRANSF);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'COD_MONEDA', :old.COD_MONEDA, :new.COD_MONEDA);
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'SWF_BCO_DESTINO', :old.SWF_BCO_DESTINO, :new.SWF_BCO_DESTINO );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_OPERACION', :old.FEC_OPERACION, :new.FEC_OPERACION);


  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/


CREATE OR REPLACE TRIGGER IT.AA_LC_TRANSFERENCIAS
  AFTER DELETE OR UPDATE
     ON LC_TRANSFERENCIAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/10/2006 a las 17:38:27 Hs.
  */
  v_registro LC_AUDITORIAS%ROWTYPE; -- Registro de la tabla LC_AUDITORIAS
BEGIN
  v_registro.tabla := 'LC_TRANSFERENCIAS';
  v_registro.clave := to_char( :old.nro_referencia) || '#' || :old.cod_tip_referencia;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_OPERACION', :old.fec_operacion, :new.fec_operacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_OPERACION', :old.nro_operacion, :new.nro_operacion, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SALDO', :old.saldo, :new.saldo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BANCO', :old.cod_banco, :new.cod_banco, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_BANCO', :old.nom_banco, :new.nom_banco );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAI_BANCO', :old.cod_pai_banco, :new.cod_pai_banco, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CIU_BANCO', :old.cod_ciu_banco, :new.cod_ciu_banco, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ABA_BANCO', :old.cod_aba_banco, :new.cod_aba_banco );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SWI_BANCO', :old.cod_swi_banco, :new.cod_swi_banco );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_CORRESPONSAL', :old.cod_bco_corresponsal, :new.cod_bco_corresponsal, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PER_SOLICITANTE', :old.cod_per_solicitante, :new.cod_per_solicitante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_SOLICITANTE', :old.nom_solicitante, :new.nom_solicitante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIR_SOLICITANTE', :old.dir_solicitante, :new.dir_solicitante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TEL_SOLICITANTE', :old.tel_solicitante, :new.tel_solicitante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAI_SOLICITANTE', :old.cod_pai_solicitante, :new.cod_pai_solicitante, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CIU_SOLICITANTE', :old.cod_ciu_solicitante, :new.cod_ciu_solicitante, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAI_BCO_CONTRA', :old.cod_pai_bco_contra, :new.cod_pai_bco_contra, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CIU_BCO_CONTRA', :old.cod_ciu_bco_contra, :new.cod_ciu_bco_contra, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PER_BENEFICIARIO', :old.cod_per_beneficiario, :new.cod_per_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_BENEFICIARIO', :old.nom_beneficiario, :new.nom_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIR_BENEFICIARIO', :old.dir_beneficiario, :new.dir_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TEL_BENEFICIARIO', :old.tel_beneficiario, :new.tel_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAI_BENEFICIARIO', :old.cod_pai_beneficiario, :new.cod_pai_beneficiario, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CIU_BENEFICIARIO', :old.cod_ciu_beneficiario, :new.cod_ciu_beneficiario, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_REFERENCIA', :old.nro_cta_referencia, :new.nro_cta_referencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ULT_MOVIMIENTO', :old.fec_ult_movimiento, :new.fec_ult_movimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_RECEPCION', :old.fec_recepcion, :new.fec_recepcion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUBRO', :old.cod_rubro, :new.cod_rubro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PLAZO', :old.plazo, :new.plazo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_UID_BANCO', :old.cod_uid_banco, :new.cod_uid_banco );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_CIU_BENEFICIARIO', :old.nom_ciu_beneficiario, :new.nom_ciu_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_CIU_SOLICITANTE', :old.nom_ciu_solicitante, :new.nom_ciu_solicitante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_COR_CONTRA', :old.cod_bco_cor_contra, :new.cod_bco_cor_contra, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_MENSAJE', :old.tip_mensaje, :new.tip_mensaje );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_CARGO', :old.tip_cargo, :new.tip_cargo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REF_EXTERNA', :old.nro_ref_externa, :new.nro_ref_externa );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ENVIADA', :old.enviada, :new.enviada );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VALOR', :old.fec_valor, :new.fec_valor, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MSJ_SWIFT', :old.cod_msj_swift, :new.cod_msj_swift, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ENVIO', :old.fec_envio, :new.fec_envio, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_ENVIO', :old.hor_envio, :new.hor_envio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CARGO', :old.mto_cargo, :new.mto_cargo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FONDEADO', :old.fondeado, :new.fondeado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'AUTORIZADO', :old.autorizado, :new.autorizado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'GPI', :old.gpi, :new.gpi );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CODIGO', :old.codigo, :new.codigo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_ORD_PAG_DNA', :old.nro_ord_pag_dna, :new.nro_ord_pag_dna );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );

  if deleting then
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSJ_SWIFT', :old.msj_swift, :new.msj_swift );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSJ_SWIFT_199', :old.Msj_Swift_199, :new.Msj_Swift_199 );
  end if;
  -- Insertar tabla de auditoria
  prl_ins_lc_auditoria( v_registro );
EXCEPTION
  when others then
    prl_ins_lc_auditoria( v_registro );
END;
/


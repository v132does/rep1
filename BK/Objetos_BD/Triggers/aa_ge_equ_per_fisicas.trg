CREATE OR REPLACE TRIGGER IT.AA_GE_EQU_PER_FISICAS
  AFTER DELETE OR UPDATE
     ON GE_EQU_PER_FISICAS
    FOR EACH ROW
DECLARE
    v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_EQU_PER_FISICAS';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.nro_secuencia || '#' || :old.nro_documento;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_ACCION', :old.tip_accion, :new.tip_accion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SUCURSAL', :old.cod_sucursal, :new.cod_sucursal );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_TRANSACCION', :old.tip_transaccion, :new.tip_transaccion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ID_OPERACION', :old.id_operacion, :new.id_operacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_VINCULACION', :old.tip_vinculacion, :new.tip_vinculacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CLIENTE', :old.nro_cliente, :new.nro_cliente );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_DIA_ATRASO', :old.can_dia_atraso, :new.can_dia_atraso );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OPE_CERRADA', :old.ope_cerrada, :new.ope_cerrada );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PERIODO', :old.periodo, :new.periodo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONSENTIMIENTO', :old.consentimiento, :new.consentimiento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VALOR', :old.fec_valor, :new.fec_valor );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_DOCUMENTO', :old.tip_documento, :new.tip_documento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAI_DOCUMENTO', :old.cod_pai_documento, :new.cod_pai_documento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NACIONALIDAD', :old.nacionalidad, :new.nacionalidad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRI_APELLIDO', :old.pri_apellido, :new.pri_apellido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SEG_APELLIDO', :old.seg_apellido, :new.seg_apellido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'APE_CASADA', :old.ape_casada, :new.ape_casada );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRI_NOMBRE', :old.pri_nombre, :new.pri_nombre );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SEG_NOMBRE', :old.seg_nombre, :new.seg_nombre );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_NACIMIENTO', :old.fec_nacimiento, :new.fec_nacimiento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SEXO', :old.cod_sexo, :new.cod_sexo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_CIVIL', :old.est_civil, :new.est_civil );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CALLE', :old.calle, :new.calle );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_PUERTA', :old.nro_puerta, :new.nro_puerta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'APARTAMENTO', :old.apartamento, :new.apartamento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PISO', :old.piso, :new.piso );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COMPLEMENTO', :old.complemento, :new.complemento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'KILOMETRO', :old.kilometro, :new.kilometro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MANZANA', :old.manzana, :new.manzana );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LOTE', :old.lote, :new.lote );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BLOCK', :old.block, :new.block );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESQUINA1', :old.esquina1, :new.esquina1 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESQUINA2', :old.esquina2, :new.esquina2 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PENSION', :old.pension, :new.pension );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_VIVIENDA', :old.tip_vivienda, :new.tip_vivienda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ID_CIUDAD', :old.id_ciudad, :new.id_ciudad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CIUDAD', :old.ciudad, :new.ciudad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BARRIO', :old.barrio, :new.barrio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEPARTAMENTO', :old.departamento, :new.departamento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_POSTAL', :old.cod_postal, :new.cod_postal );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TELEFONO', :old.telefono, :new.telefono );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EMP_EMPLEO', :old.emp_empleo, :new.emp_empleo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CARGO', :old.cargo, :new.cargo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PROFESION', :old.profesion, :new.profesion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CALLE_LABORAL', :old.calle_laboral, :new.calle_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_PUE_LABORAL', :old.nro_pue_laboral, :new.nro_pue_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'APART_LABORAL', :old.apart_laboral, :new.apart_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PISO_LABORAL', :old.piso_laboral, :new.piso_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COMP_LABORAL', :old.comp_laboral, :new.comp_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'KILO_LABORAL', :old.kilo_laboral, :new.kilo_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MAN_LABORAL', :old.man_laboral, :new.man_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LOTE_LABORAL', :old.lote_laboral, :new.lote_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BLO_LABORAL', :old.blo_laboral, :new.blo_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESQ1_LABORAL', :old.esq1_laboral, :new.esq1_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESQ2_LABORAL', :old.esq2_laboral, :new.esq2_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ID_CIU_LABORAL', :old.id_ciu_laboral, :new.id_ciu_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CIU_LABORAL', :old.ciu_laboral, :new.ciu_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LOC_LABORAL', :old.loc_laboral, :new.loc_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEP_LABORAL', :old.dep_laboral, :new.dep_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_POS_LABORAL', :old.cod_pos_laboral, :new.cod_pos_laboral );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ING_EMPLEO', :old.ing_empleo, :new.ing_empleo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TEL_EMPLEO', :old.tel_empleo, :new.tel_empleo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_DOC_CONYUGE', :old.tip_doc_conyuge, :new.tip_doc_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PAI_DOC_CONYUGE', :old.pai_doc_conyuge, :new.pai_doc_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOC_CONYUGE', :old.nro_doc_conyuge, :new.nro_doc_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NAC_CONYUGE', :old.nac_conyuge, :new.nac_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRI_APE_CONYUGE', :old.pri_ape_conyuge, :new.pri_ape_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SEG_APE_CONYUGE', :old.seg_ape_conyuge, :new.seg_ape_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'APE_CAS_CONYUGE', :old.ape_cas_conyuge, :new.ape_cas_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRI_NOM_CONYUGE', :old.pri_nom_conyuge, :new.pri_nom_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SEG_NOM_CONYUGE', :old.seg_nom_conyuge, :new.seg_nom_conyuge );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PROCESO', :old.tip_proceso, :new.tip_proceso );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/


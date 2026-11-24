CREATE OR REPLACE TRIGGER IT.AA_GE_EQU_PER_JURIDICAS
  AFTER DELETE OR UPDATE
     ON GE_EQU_PER_JURIDICAS
    FOR EACH ROW
DECLARE
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_EQU_PER_JURIDICAS';
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
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RAZ_SOCIAL', :old.raz_social, :new.raz_social );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_EMPRESA', :old.nom_empresa, :new.nom_empresa );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACT_COMERCIAL', :old.act_comercial, :new.act_comercial );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'INI_ACTIVIDADES', :old.ini_actividades, :new.ini_actividades );
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
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_VIVIENDA', :old.tip_vivienda, :new.tip_vivienda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ID_CIUDAD', :old.id_ciudad, :new.id_ciudad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CIUDAD', :old.ciudad, :new.ciudad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BARRIO', :old.barrio, :new.barrio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEPARTAMENTO', :old.departamento, :new.departamento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_POSTAL', :old.cod_postal, :new.cod_postal );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TELEFONO', :old.telefono, :new.telefono );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PROCESO', :old.tip_proceso, :new.tip_proceso );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/


CREATE OR REPLACE TRIGGER IT.AA_CR_INF_FONDOS
  AFTER DELETE OR UPDATE
     ON CR_INF_FONDOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 11/12/2006 a las 17:15:40 Hs.
  */
  v_registro CR_AUDITORIAS%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
  v_registro.tabla := 'CR_INF_FONDOS';
  v_registro.clave := :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_TRANSFERENCIAS', :old.fon_transferencias, :new.fon_transferencias );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_SALARIO', :old.fon_salario, :new.fon_salario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_PRESTAMOS', :old.fon_prestamos, :new.fon_prestamos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_VTA_ACTIVOS', :old.fon_vta_activos, :new.fon_vta_activos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_REN_FINANCIERAS', :old.fon_ren_financieras, :new.fon_ren_financieras );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_HERENCIA', :old.fon_herencia, :new.fon_herencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_AHORRO', :old.fon_ahorro, :new.fon_ahorro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_OTROS', :old.fon_otros, :new.fon_otros );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRO_INGRESOS', :old.pro_ingresos, :new.pro_ingresos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRO_AHORROS', :old.pro_ahorros, :new.pro_ahorros );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRO_VEN_ALQ', :old.pro_ven_alq, :new.pro_ven_alq );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRO_GAS_OPERATIVOS', :old.pro_gas_operativos, :new.pro_gas_operativos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRO_OTROS', :old.pro_otros, :new.pro_otros );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PEP', :old.pep, :new.pep ); 
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CLI_FRECUENTE', :old.cli_frecuente, :new.cli_frecuente );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FON_PROPIO', :old.fon_propio, :new.fon_propio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OPE_GIROS', :old.ope_giros, :new.ope_giros );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OPE_CAMBIOS', :old.ope_cambios, :new.ope_cambios );

  if updating then
    v_registro.detalle := v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'TIP_OPE_OTROS',substr(:old.tip_ope_otros,1,500),substr(:new.tip_ope_otros,1,500));
	v_registro.detalle := v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'PEP_OBSERVACION',substr(:old.pep_observacion,1,500),substr(:new.pep_observacion,1,500));
  end if;
    
  -- Insertar tabla de auditoria
  prr_ins_cr_auditoria( v_registro );
EXCEPTION
  when others then
    prr_ins_cr_auditoria( v_registro );
END;
/


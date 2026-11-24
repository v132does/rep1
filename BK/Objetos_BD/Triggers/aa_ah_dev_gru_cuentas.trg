CREATE OR REPLACE TRIGGER IT.AA_AH_DEV_GRU_CUENTAS
  AFTER DELETE OR UPDATE
     ON AH_DEV_GRU_CUENTAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 04/09/2018 a las 10:05:02 Hs.
  */
  v_registro AH_AUDITORIAS%ROWTYPE; -- Registro de la tabla AH_AUDITORIAS
BEGIN
  v_registro.tabla := 'AH_DEV_GRU_CUENTAS';
  v_registro.clave := :old.cod_persona || '#' || :old.cod_grupo || '#' || :old.nro_cuenta;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FOR_DIS_INTERES', :old.for_dis_interes, :new.for_dis_interes );

  -- Insertar tabla de auditoria
  pra_ins_ah_auditoria( v_registro );
EXCEPTION
  when others then
    pra_ins_ah_auditoria( v_registro );
END;
/


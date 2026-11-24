CREATE OR REPLACE TRIGGER IT.AA_PR_COB_CUO_OTR_BCO
  AFTER DELETE OR UPDATE
     ON PR_COB_CUO_OTR_BCO
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/10/2015 a las 11:33:19 Hs.
  */
  v_registro PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  v_registro.tabla := 'PR_COB_CUO_OTR_BCO';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.nro_cuota) || '#' || :old.estado || '#' || to_char( :old.fec_cobro, 'DD/MM/YYYY HH24:MI:SS');
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_BOLETA', :old.nro_boleta, :new.nro_boleta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CHEQUE', :old.nro_cheque, :new.nro_cheque, 'N' );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( v_registro );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( v_registro );
END;
/


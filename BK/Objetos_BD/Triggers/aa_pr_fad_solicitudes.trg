CREATE OR REPLACE TRIGGER IT.AA_PR_FAD_SOLICITUDES
  AFTER DELETE OR UPDATE
     ON PR_FAD_SOLICITUDES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 26/11/2018 a las 17:30:09 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_FAD_SOLICITUDES';
  r_paudi.clave := to_char( :old.nro_solicitud);
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TOT_PRESTAMO', :old.tot_prestamo, :new.tot_prestamo, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_USU_OFICIAL', :old.cod_usu_oficial, :new.cod_usu_oficial );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_USU_APROBACION', :old.cod_usu_aprobacion, :new.cod_usu_aprobacion );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_SOL_OPERACION', :old.nro_sol_operacion, :new.nro_sol_operacion, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_LINEA', :old.nro_linea, :new.nro_linea, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'OBSERVACIONES', :old.observaciones, :new.observaciones );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_SUB_MODALIDAD', :old.cod_sub_modalidad, :new.cod_sub_modalidad, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COTIZACION', :old.cotizacion, :new.cotizacion, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'IND_LIN_CREDITO', :old.ind_lin_credito, :new.ind_lin_credito );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/


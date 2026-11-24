CREATE OR REPLACE TRIGGER IT.AA_BA_PER_GEN_OFERTAS
  AFTER DELETE OR UPDATE
     ON "IT"."BA_PER_GEN_OFERTAS"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 22/03/2022 a las 18:26:38 Hs.
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_PER_GEN_OFERTAS';
  v_registro.clave := to_char( :old.cod_registro) || '#' || to_char( :old.fec_consulta, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_LIM_PRESTABLE', :old.mto_lim_prestable, :new.mto_lim_prestable, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAT_CRC', :old.cod_cat_crc, :new.cod_cat_crc );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_DEU_CRC', :old.tot_deu_crc, :new.tot_deu_crc, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CUO_APROXIMADO', :old.mto_cuo_aproximado, :new.mto_cuo_aproximado, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FAJA', :old.faja, :new.faja );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ING_SET', :old.fec_ing_set, :new.fec_ing_set, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ANT_INFOMERCIO', :old.ant_infomercio, :new.ant_infomercio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_OFERTA', :old.mto_oferta, :new.mto_oferta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_CUOTAS', :old.can_cuotas, :new.can_cuotas, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RTA_SERVICIO', :old.rta_servicio, :new.rta_servicio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RTA_RRNN', :old.rta_rrnn, :new.rta_rrnn );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_SERVICIOS', :old.est_servicios, :new.est_servicios );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_RRNN', :old.est_rrnn, :new.est_rrnn );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ERROR', :old.error, :new.error );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_INGRESO', :old.mto_ingreso, :new.mto_ingreso, 'N' );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/


CREATE OR REPLACE TRIGGER IT.AA_CS_VISITAS
  AFTER DELETE OR UPDATE
     ON CS_VISITAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/09/2014 a las 10:31:08 Hs.
  */
  v_registro CS_AUDITORIAS%ROWTYPE; -- Registro de la tabla CS_AUDITORIAS
BEGIN
  v_registro.tabla := 'CS_VISITAS';
  v_registro.clave := to_char( :old.nro_visita);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CONTRATO', :old.nro_contrato, :new.nro_contrato );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAJ_SEGURIDAD', :old.cod_caj_seguridad, :new.cod_caj_seguridad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VISITA', :old.fec_visita, :new.fec_visita, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_VISITA', :old.hor_visita, :new.hor_visita );

  -- Insertar tabla de auditoria
  prq_ins_cs_auditoria( v_registro );
EXCEPTION
  when others then
    prq_ins_cs_auditoria( v_registro );
END;
/


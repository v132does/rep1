CREATE OR REPLACE TRIGGER IT.AA_BW_CLI_LIMITES
  AFTER DELETE OR UPDATE
     ON BW_CLI_LIMITES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2014 - IT Consultores
  || Generado el 05/08/2014 a las 17:32:21 Hs.
  */
  r_waudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  r_waudi.tabla := 'BW_CLAVES';
--  r_waudi.clave := :old.cod_persona || '#' || :old.cod_canal;
  r_waudi.clave := :old.cod_canal || '#' || :old.cod_persona || '#' || :old.cod_tip_mensaje || '#' || :old.cod_moneda;
  r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_waudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_waudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
 -- r_waudi.detalle := pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'CLAVE', :old.clave, :new.clave );
  r_waudi.detalle := pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_CANAL', :old.cod_canal, :new.cod_canal );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_TIP_MENSAJE', :old.cod_tip_mensaje, :new.cod_tip_mensaje);
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'MTO_LIMITE', :old.mto_limite, :new.mto_limite, 'N' );
  r_waudi.detalle := r_waudi.detalle || pae_cnf.fu_reg_auditoria( r_waudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda);

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( r_waudi );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( r_waudi );
END;
/


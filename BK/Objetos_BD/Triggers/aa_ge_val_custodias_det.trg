CREATE OR REPLACE TRIGGER IT.AA_GE_VAL_CUSTODIAS_DET
  AFTER DELETE OR UPDATE
     ON GE_VAL_CUSTODIAS_DET
    FOR EACH ROW
DECLARE
   /*
   || Archivo creado por el Generador de Triggers de Auditoría
   || (c) 2005 - IT Consultores
   || Generado el 28/07/2011 a las 10:28:30 Hs.
   */
   r_baudi ge_auditorias%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_baudi.tabla          := 'GE_VAL_CUSTODIAS_DET';
   r_baudi.clave          := to_char(:old.cod_val_custodia) || '#' || to_char(:old.nro_secuencia);
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   IF updating THEN
      r_baudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_baudi.tip_novedad := 'E';
   END IF;

   -- Registrar Detalle
   r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'NRO_SERIE', :old.nro_serie,
                                               :new.nro_serie);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'INI_NRO_VALOR',
                                               :old.ini_nro_valor, :new.ini_nro_valor);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'FIN_NRO_VALOR',
                                               :old.fin_nro_valor, :new.fin_nro_valor);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'CANTIDAD', :old.cantidad,
                                               :new.cantidad, 'N');
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'EN_CUSTODIA', :old.en_custodia,
                                               :new.en_custodia);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'FEC_RETIRO', :old.fec_retiro,
                                               :new.fec_retiro);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'OBSERVACION', :old.Observacion,
                                               :new.Observacion);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'COD_BANCO', :old.cod_banco,
                                               :new.cod_banco);
   r_baudi.detalle := r_baudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad, 'POR_VAL_ACCIONES', :old.por_val_acciones,
                                               :new.por_val_acciones);											   
   -- Insertar tabla de auditoria
   prg_ins_ge_auditoria(r_baudi);
EXCEPTION
   WHEN OTHERS THEN
      prg_ins_ge_auditoria(r_baudi);
END;
/


CREATE OR REPLACE TRIGGER IT.AA_TA_CON_PROMOCIONES_DET
 AFTER DELETE OR UPDATE
 ON TA_CON_PROMOCIONES_DET
 FOR EACH ROW


DECLARE
r_gaudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'TA_CON_PROMOCIONES_DET';
   r_gaudi.clave := :old.nro_convenio||'#'||:old.por_descuento||'#'||:old.fec_inicio||'#'||:old.fec_fin;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'POR_ENTIDAD',:old.por_entidad,:new.por_entidad);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'POR_COMERCIO',:old.por_comercio,:new.por_comercio);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_gaudi);
END;
/


CREATE OR REPLACE TRIGGER IT.AA_CC_CTA_GARANTIAS
 AFTER DELETE OR UPDATE
 ON CC_CTA_GARANTIAS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CTA_GARANTIAS';
   r_caudi.clave := :old.nro_cuenta||'#'||:old.nro_garantia||'#'||:old.cod_garantia;
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_APLICADO',:old.mto_aplicado,:new.mto_aplicado,'M');

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


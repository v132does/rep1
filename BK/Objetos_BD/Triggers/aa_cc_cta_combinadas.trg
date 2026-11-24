CREATE OR REPLACE TRIGGER IT.AA_CC_CTA_COMBINADAS
 AFTER DELETE OR UPDATE OR INSERT
 ON CC_CTA_COMBINADAS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CTA_COMBINADAS';
   r_caudi.clave := :old.nro_cta_cte;
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating or inserting then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;
   if inserting then
      r_caudi.clave := :new.nro_cta_cte;
   end if;   
   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CTA_AHORRO',:old.nro_cta_ahorro,:new.nro_cta_ahorro);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_MINIMO',:old.sal_minimo,:new.sal_minimo,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'OBSERVACIONES',:old.observaciones,:new.observaciones);

    --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


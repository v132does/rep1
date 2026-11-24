CREATE OR REPLACE TRIGGER IT.AA_CR_PER_RIESGO_PLA_HIS
 AFTER DELETE OR UPDATE
 ON CR_PER_RIESGO_PLA_HIS
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_PER_RIESGO_PLA_HIS';
   r_raudi.clave := to_char(:old.cod_persona);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NRO_DOCUMENTO',:old.nro_documento,:new.nro_documento);
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_TIP_DOCUMENTO',:old.cod_tip_documento,:new.cod_tip_documento);
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'NIVEL_RIESGO',:old.nivel_riesgo,:new.nivel_riesgo);
   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/

CREATE OR REPLACE TRIGGER IT.AA_GE_CTA_CLIENTES
 AFTER DELETE OR UPDATE
 ON GE_CTA_CLIENTES
 FOR EACH ROW

DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_CTA_CLIENTES';
   r_eaudi.clave := :old.nro_cuenta||'#'||:old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DIG_VERIFICADOR',:old.dig_verificador,:new.dig_verificador,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'RELACION',:old.relacion,:new.relacion);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/


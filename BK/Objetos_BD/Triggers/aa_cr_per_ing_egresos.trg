CREATE OR REPLACE TRIGGER IT.AA_CR_PER_ING_EGRESOS
 AFTER DELETE OR UPDATE
 ON CR_PER_ING_EGRESOS
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_PER_ING_EGRESOS';
   r_raudi.clave := :old.cod_persona||'#'||to_char(:old.cod_concepto);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'ING_EGRESO',:old.ing_egreso,:new.ing_egreso);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'IMPORTE',:old.importe,:new.importe,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_INFORMACION',:old.fec_informacion,:new.fec_informacion);


   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


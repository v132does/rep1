CREATE OR REPLACE TRIGGER IT.AA_CR_PER_AFICIONES
 AFTER DELETE OR UPDATE
 ON CR_PER_AFICIONES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_PER_AFICIONES';
   r_raudi.clave := :old.cod_persona||'#'||to_char(:old.cod_aficion);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_AFICION',:old.cod_aficion,:new.cod_aficion,'N');

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


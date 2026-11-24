CREATE OR REPLACE TRIGGER IT.AA_CR_PUN_VALORES
 AFTER DELETE OR UPDATE
 ON CR_PUN_VALORES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_PUN_VALORES';
   r_raudi.clave := to_char(:old.cod_puntaje)||'#'||:old.cod_campo||'#'||:old.descripcion;
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'PUNTAJE',:old.puntaje,:new.puntaje,'N');

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


CREATE OR REPLACE TRIGGER IT.AA_CR_AGE_ACTIVIDADES
 AFTER DELETE OR UPDATE
 ON CR_AGE_ACTIVIDADES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_AGE_ACTIVIDADES';
   r_raudi.clave := to_char(:old.cod_actividad);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


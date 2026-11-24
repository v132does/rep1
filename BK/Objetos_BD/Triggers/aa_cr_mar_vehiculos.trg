CREATE OR REPLACE TRIGGER IT.AA_CR_MAR_VEHICULOS
 AFTER DELETE OR UPDATE
 ON CR_MAR_VEHICULOS
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_MAR_VEHICULOS';
   r_raudi.clave := to_char(:old.cod_marca);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_PAIS',:old.cod_pais,:new.cod_pais,'N');

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


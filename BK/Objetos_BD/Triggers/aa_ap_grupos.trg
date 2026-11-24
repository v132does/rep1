CREATE OR REPLACE TRIGGER IT.AA_AP_GRUPOS
 AFTER DELETE OR UPDATE
 ON AP_GRUPOS
 FOR EACH ROW


DECLARE
r_eaudi ap_auditorias%rowtype; -- Registro de la tabla AP_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'AP_GRUPOS';
   r_eaudi.clave := :old.cod_grupo;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';

   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PRINCIPAL',:old.principal,:new.principal);

   --- Insertar tabla de auditoria
   PRY_INS_AP_AUDITORIA(r_eaudi);
END;
/


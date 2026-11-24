CREATE OR REPLACE TRIGGER IT.AA_CJ_LIMITES
 AFTER DELETE OR UPDATE
 ON CJ_LIMITES
 FOR EACH ROW


DECLARE
r_jaudi cj_auditorias%rowtype; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
   r_jaudi.tabla := 'CJ_LIMITES';
   r_jaudi.clave := :old.cod_usuario||'#'||:old.cod_moneda;
   r_jaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_jaudi.tip_novedad := 'M';
   elsif deleting then
      r_jaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_jaudi.detalle := pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'MTO_MAX_PERMITIDO',:old.mto_max_permitido,:new.mto_max_permitido,'M');

   --- Insertar tabla de auditoria
   PRJ_INS_CJ_AUDITORIA(r_jaudi);
END;
/


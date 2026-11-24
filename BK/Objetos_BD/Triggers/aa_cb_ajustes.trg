CREATE OR REPLACE TRIGGER IT.AA_CB_AJUSTES
 AFTER DELETE OR UPDATE
 ON CB_AJUSTES
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_AJUSTES';
   r_baudi.clave := :old.cod_sector||'#'||:old.cod_capitulo||'#'||:old.cod_grupo||'#'||:old.cod_subcuenta;
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUB_UTILIDAD',:old.cod_rub_utilidad,:new.cod_rub_utilidad);
   r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUB_PERDIDA',:old.cod_rub_perdida,:new.cod_rub_perdida);

   --- Insertar tabla de auditoria
   PRB_INS_CB_AUDITORIA(r_baudi);
END;
/


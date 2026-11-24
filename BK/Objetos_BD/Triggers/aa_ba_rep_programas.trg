CREATE OR REPLACE TRIGGER IT.AA_BA_REP_PROGRAMAS
 AFTER DELETE OR UPDATE
 ON BA_REP_PROGRAMAS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_REP_PROGRAMAS';
   r_eaudi.clave := :old.cod_programa||'#'||:old.cod_pro_reporte;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PROGRAMA',:old.cod_programa,:new.cod_programa);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PRO_REPORTE',:old.cod_pro_reporte,:new.cod_pro_reporte);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/


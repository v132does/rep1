CREATE OR REPLACE TRIGGER IT.AA_BA_GRU_OFICINAS
 AFTER DELETE OR UPDATE
 ON BA_GRU_OFICINAS
 FOR EACH ROW


DECLARE
r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_GRU_OFICINAS';
   r_eaudi.clave := to_char(:old.cod_gru_oficina);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_ENCARGADO',:old.cod_usu_encargado,:new.cod_usu_encargado);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/


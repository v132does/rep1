CREATE OR REPLACE TRIGGER IT.AA_BA_OFICINAS
 AFTER DELETE OR UPDATE
 ON BA_OFICINAS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_OFICINAS';
   r_eaudi.clave := to_char(:old.cod_oficina);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_CIUDAD',:old.cod_ciudad,:new.cod_ciudad,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PAIS',:old.cod_pais,:new.cod_pais,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_OFI_CAMBIO',:old.cod_ofi_cambio,:new.cod_ofi_cambio,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DIRECCION',:old.direccion,:new.direccion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TELEFONO',:old.telefono,:new.telefono);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SIGLA',:old.sigla,:new.sigla);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_ENCARGADO',:old.cod_usu_encargado,:new.cod_usu_encargado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_GRU_OFICINA',:old.cod_gru_oficina,:new.cod_gru_oficina,'N');

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/


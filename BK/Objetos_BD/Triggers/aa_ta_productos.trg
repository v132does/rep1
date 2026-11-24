CREATE OR REPLACE TRIGGER "IT".AA_TA_PRODUCTOS
 AFTER DELETE OR UPDATE
 ON "IT".TA_PRODUCTOS
 FOR EACH ROW

DECLARE
   r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_PRODUCTOS';
   
   r_taudi.clave := :old.id_producto || '#' || :old.cod_producto;
   
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;

   r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad, 'COD_PRODUCTO', :old.cod_producto, :new.cod_producto);
   r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad, 'COD_SUB_PRODUCTO', :old.cod_sub_producto, :new.cod_sub_producto);
   r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N');
   r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad, 'AFINIDAD', :old.afinidad, :new.afinidad);
   r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad, 'NRO_BIN', :old.nro_bin, :new.nro_bin);
   r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad, 'ID_PRODUCTO', :old.id_producto, :new.id_producto);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/
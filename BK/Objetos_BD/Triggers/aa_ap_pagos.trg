CREATE OR REPLACE TRIGGER IT.AA_AP_PAGOS
 AFTER DELETE OR UPDATE
 ON AP_PAGOS
 FOR EACH ROW


DECLARE
r_eaudi ap_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'AP_PAGOS';
   r_eaudi.clave := :old.cod_pago;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';

   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PROVEEDOR',:old.cod_proveedor,:new.cod_proveedor,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_REQUERIMIENTO',:old.cod_requerimiento,:new.cod_requerimiento,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_EJECUTADO',:old.mto_ejecutado,:new.mto_ejecutado,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_FACTURA',:old.mto_factura,:new.mto_factura,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_COT_FACTURA',:old.mto_cot_factura,:new.mto_cot_factura,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_COT_DOLAR',:old.mto_cot_dolar,:new.mto_cot_dolar,'M');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_FACTURA',:old.nro_factura,:new.nro_factura);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
    --- Insertar tabla de auditoria
   PRY_INS_AP_AUDITORIA(r_eaudi);

 END;
/


CREATE OR REPLACE TRIGGER IT.AA_CJ_TIP_VALORES
 AFTER DELETE OR UPDATE
 ON CJ_TIP_VALORES
 FOR EACH ROW


DECLARE
r_jaudi cj_auditorias%rowtype; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
   r_jaudi.tabla := 'CJ_TIP_VALORES';
   r_jaudi.clave := to_char(:old.cod_tip_valor);
   r_jaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_jaudi.tip_novedad := 'M';
   elsif deleting then
      r_jaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_jaudi.detalle := pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'VALOR',:old.valor,:new.valor);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'NRO_ORDEN',:old.nro_orden,:new.nro_orden);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'FOR_TOTAL',:old.for_total,:new.for_total);

   --- Insertar tabla de auditoria
   PRJ_INS_CJ_AUDITORIA(r_jaudi);
END;
/


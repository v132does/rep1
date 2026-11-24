CREATE OR REPLACE TRIGGER IT.AA_TA_REF_MOVIMIENTOS
 AFTER DELETE OR UPDATE
 ON TA_REF_MOVIMIENTOS
 FOR EACH ROW


DECLARE
r_gaudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'TA_REF_MOVIMIENTOS';
   r_gaudi.clave := to_char(:old.cod_referencia);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_COD_MODULO',:old.cod_modulo,:new.cod_modulo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_gaudi);
END;
/


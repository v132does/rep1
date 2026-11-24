CREATE OR REPLACE TRIGGER IT.AA_GE_TIP_ASIENTOS
 AFTER DELETE OR UPDATE
 ON GE_TIP_ASIENTOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_TIP_ASIENTOS';
   r_gaudi.clave := to_char(:old.cod_tip_asiento)||'#'||to_char(:old.nro_linea)||'#'||
   :old.tip_movimiento||'#'||:old.cod_moneda||'#'||:old.cod_sec_contable||'#'||
   :old.ind_residente||'#'||:old.ind_deudor||'#'||:old.ind_plazo||'#'||:old.ind_producto||'#'||
   :old.tip_renovacion;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_RUBRO',:old.cod_rubro,:new.cod_rubro);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


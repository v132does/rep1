CREATE OR REPLACE TRIGGER IT.AA_CB_ASIENTOS
  --- Realizado por Ingrid Larraín - 07/10/2011 para que no se dispare por procesos automáticos
 AFTER DELETE OR UPDATE OF fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo,
                           cod_modalidad, reversado, ofi_integrada, cod_ofi_origen,
                           fec_valor, nro_asi_automatico, nro_asi_futuro, cod_cargo
 ON CB_ASIENTOS
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_ASIENTOS';
   r_baudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||to_char(:old.cod_oficina)||'#'||to_char(:old.nro_asiento);
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_CONTROL',:old.tot_control,:new.tot_control,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'ACTUALIZADO',:old.actualizado,:new.actualizado);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'REVERSADO',:old.reversado,:new.reversado);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'OFI_INTEGRADA',:old.ofi_integrada,:new.ofi_integrada);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'CONFIRMADO',:old.confirmado,:new.confirmado);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_OFI_ORIGEN',:old.cod_ofi_origen,:new.cod_ofi_origen,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'NRO_ASI_AUTOMATICO',:old.nro_asi_automatico,:new.nro_asi_automatico,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'NRO_ASI_FUTURO',:old.nro_asi_futuro,:new.nro_asi_futuro,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_CARGO',:old.cod_cargo,:new.cod_cargo,'N');

   --- Insertar tabla de auditoria
   --- Para que no grabe auditoría si el proceso es un cierre
   IF updating or (deleting and pae_cnf.G_PROGRAMA <> 'GPPROFIN') THEN
      PRB_INS_CB_AUDITORIA(r_baudi);
   END IF;
END;
/


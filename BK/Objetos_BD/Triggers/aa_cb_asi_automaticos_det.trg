CREATE OR REPLACE TRIGGER IT."AA_CB_ASI_AUTOMATICOS_DET"
 AFTER DELETE OR UPDATE OF fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro, 
                           mto_mon_local, descripcion, referencia, val_cotizacion, distribuido, ref_movimiento,
                           cod_modulo, cod_modalidad, cod_ofi_origen, cod_tra_padre, fec_valor
 ON CB_ASI_AUTOMATICOS_DET
 FOR EACH ROW

DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  --DESOPIMI-21 - FASE 2 - Optimización PRA_GEN_ASIENTOS
  --- Insertar tabla de auditoria
  --- Para que no grabe auditoría si el proceso es un cierre
  IF (updating or deleting) and (pae_cnf.G_PROGRAMA <> 'GPPROFIN') THEN
       r_baudi.tabla := 'CB_ASI_AUTOMATICOS_DET';
       r_baudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||to_char(:old.cod_oficina)||'#'||to_char(:old.nro_asiento)||'#'||to_char(:old.nro_linea);
       r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

       if updating then
          r_baudi.tip_novedad := 'M';
       elsif deleting then
          r_baudi.tip_novedad := 'E';
       end if;

       --- Registrar Detalle
        r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUBRO',:old.cod_rubro,:new.cod_rubro);
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TIP_MOVIMIENTO',:old.tip_movimiento,:new.tip_movimiento);
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MTO_MON_RUBRO',:old.mto_mon_rubro,:new.mto_mon_rubro,'M');
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MTO_MON_LOCAL',:old.mto_mon_local,:new.mto_mon_local,'M');
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'REFERENCIA',:old.referencia,:new.referencia);
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PROTEGIDO',:old.protegido,:new.protegido);
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'ACTUALIZADO',:old.actualizado,:new.actualizado);
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'VAL_COTIZACION',:old.val_cotizacion,:new.val_cotizacion,'M');
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DISTRIBUIDO',:old.distribuido,:new.distribuido);
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'REF_MOVIMIENTO',:old.ref_movimiento,:new.ref_movimiento,'N');
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
        r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_OFI_ORIGEN',:old.cod_ofi_origen,:new.cod_ofi_origen,'N');
        PRB_INS_CB_AUDITORIA(r_baudi);
   END IF;
END;
/


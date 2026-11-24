CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_RECIBIDOS
 AFTER DELETE OR UPDATE
 ON CC_CHE_RECIBIDOS
 FOR EACH ROW
DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHE_RECIBIDOS';
   r_caudi.clave := to_char(:old.nro_cheque)||'#'||to_char(:old.fec_proceso,'ddmmrrrr');
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CUENTA',:old.NRO_CUENTA,:new.NRO_CUENTA);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_BCO_EMISOR',:old.COD_BCO_EMISOR,:new.COD_BCO_EMISOR,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_BCO_RECEPTOR',:old.COD_BCO_RECEPTOR,:new.COD_BCO_RECEPTOR,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_CAU_DEVOLUCION',:old.cod_cau_devolucion,:new.cod_cau_devolucion,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_OFI_CAMARA',:old.COD_OFI_CAMARA,:new.COD_OFI_CAMARA,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'EST_CHEQUE',:old.EST_CHEQUE,:new.EST_CHEQUE);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'ALERTA_UV', :old.alerta_uv, :new.alerta_uv );
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'DATAMATRIX', :old.datamatrix, :new.datamatrix );
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'TIP_IMPORTE', :old.tip_importe, :new.tip_importe, 'N' );
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'BANDA_CMC7', :old.banda_cmc7, :new.banda_cmc7 );    
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );    

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


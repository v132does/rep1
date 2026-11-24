CREATE OR REPLACE TRIGGER IT.AA_CB_GAS_DIFERIDOS
 AFTER DELETE OR UPDATE
 ON CB_GAS_DIFERIDOS
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_GAS_DIFERIDOS
BEGIN
   r_baudi.tabla := 'CB_GAS_DIFERIDOS';
   r_baudi.clave := to_char(:old.COD_CARGO);
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'FEC_DESDE',:old.FEC_DESDE,:new.FEC_DESDE, 'F');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'FEC_HASTA',:old.FEC_HASTA,:new.FEC_HASTA, 'F');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MONTO',:old.MONTO,:new.MONTO,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DESCRIPCION',:old.DESCRIPCION,:new.DESCRIPCION);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUB_CREDITO',:old.COD_RUB_CREDITO,:new.COD_RUB_CREDITO);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUB_DEBITO',:old.COD_RUB_DEBITO,:new.COD_RUB_DEBITO);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PERIODICIDAD',:old.PERIODICIDAD,:new.PERIODICIDAD);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_OFICINA',:old.COD_OFICINA,:new.COD_OFICINA,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_TIPO_CARGO',:old.COD_TIPO_CARGO,:new.COD_TIPO_CARGO,'N');		
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'NRO_ORDEN',:old.NRO_ORDEN,:new.NRO_ORDEN,'N');		
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'NRO_FACTURA',:old.NRO_FACTURA,:new.NRO_FACTURA);		
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'FECHA',:old.FECHA,:new.FECHA, 'F');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PROCESADO',:old.PROCESADO,:new.PROCESADO);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'NRO_LINEA',:old.NRO_LINEA,:new.NRO_LINEA,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_TRANSACCION',:old.COD_TRANSACCION,:new.COD_TRANSACCION,'N');


   --- Insertar tabla de auditoria
  PRB_INS_CB_AUDITORIA(r_baudi);
END;
/


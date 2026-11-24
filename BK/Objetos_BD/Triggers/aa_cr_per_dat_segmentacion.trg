CREATE OR REPLACE TRIGGER IT.AA_CR_PER_DAT_SEGMENTACION
 AFTER DELETE OR UPDATE
 ON CR_PER_DAT_SEGMENTACION
 FOR EACH ROW
DECLARE
r_caudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CR_PER_DAT_SEGMENTACION';
   r_caudi.clave := to_char(:old.cod_persona);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_RUB_PRIMARIO',:old.COD_RUB_PRIMARIO,:new.COD_RUB_PRIMARIO);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ANO_FACTURACION',:old.ANO_FACTURACION,:new.ANO_FACTURACION);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MES_FACTURACION',:old.MES_FACTURACION,:new.MES_FACTURACION);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_FACTURACION',:old.MTO_FACTURACION,:new.MTO_FACTURACION);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MES_RATING',:old.MES_RATING,:new.MES_RATING);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ANO_RATING',:old.ANO_RATING,:new.ANO_RATING);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'RATING',:old.RATING,:new.RATING);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MES_HATOS',:old.MES_HATOS,:new.MES_HATOS);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ANO_HATOS',:old.ANO_HATOS,:new.ANO_HATOS);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CAN_HATOS',:old.CAN_HATOS,:new.CAN_HATOS);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_caudi);
END;
/


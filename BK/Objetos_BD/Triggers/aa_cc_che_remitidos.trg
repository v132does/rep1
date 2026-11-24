CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_REMITIDOS
 AFTER DELETE OR UPDATE
 ON CC_CHE_REMITIDOS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHE_REMITIDOS';
   r_caudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||to_char(:old.cod_oficina)||'#'||
                    to_char(:old.nro_caja)||'#'||to_char(:old.nro_lote)||'#'||to_char(:old.nro_cheque);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'TIP_DATO',:old.tip_dato,:new.tip_dato,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_BANCO',:old.cod_banco,:new.cod_banco,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'FEC_GIRO', :old.fec_giro, :new.fec_giro, 'F' );
    r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'NRO_LECTORA', :old.nro_lectora, :new.nro_lectora, 'N' );
    r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'USU_CAPTURA', :old.usu_captura, :new.usu_captura );
    r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'COD_BANDACM7', :old.cod_bandacm7, :new.cod_bandacm7 );
    r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'RETENCION', :old.retencion, :new.retencion );
    r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'NRO_REGISTRO', :old.nro_registro, :new.nro_registro, 'N' );    
   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


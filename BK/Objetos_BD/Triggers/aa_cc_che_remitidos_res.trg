CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_REMITIDOS_RES
 AFTER DELETE OR UPDATE
 ON CC_CHE_REMITIDOS_RES
 FOR EACH ROW
DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHE_REMITIDOS_RES';
   /*
   r_caudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||to_char(:old.cod_oficina)||'#'||
                    to_char(:old.nro_caja)||'#'||to_char(:old.nro_lote);
   */
   r_caudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||to_char(:old.cod_oficina)||'#'||to_char(:old.nro_lote);                    
                    
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'TIP_DATO',:old.tip_dato,:new.tip_dato,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_REFERENCIA',:old.nro_referencia,:new.nro_referencia);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_BOLETA',:old.nro_boleta,:new.nro_boleta);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


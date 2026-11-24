CREATE OR REPLACE TRIGGER IT.AA_AH_MOVIMIENTOS_HIS
 AFTER DELETE OR UPDATE OF  MONTO,
                            NRO_CUENTA,
                            COD_MONEDA,
                            COD_OFICINA,
                            ESTADO,
                            COD_RUBRO,
                            COTIZACION,
                            COD_TRANSACCION,
                            NRO_CAJA,
                            NRO_DOCUMENTO
 ON AH_MOVIMIENTOS_HIS
 FOR EACH ROW

DECLARE
r_paudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_paudi.tabla := 'AH_MOVIMIENTOS_HIS';
   r_paudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||:old.hora||'#'||:old.cod_usuario||'#'||to_char(:old.nro_secuencia);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_RUBRO',:old.cod_rubro,:new.cod_rubro);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COTIZACION',:old.cotizacion,:new.cotizacion,'M');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_CAJA',:old.nro_caja,:new.nro_caja);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_DOCUMENTO',:old.nro_documento,:new.nro_documento);
   -- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_paudi);
END;
/

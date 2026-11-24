CREATE OR REPLACE TRIGGER IT.AA_CC_SOB_GASTOS
 AFTER DELETE OR UPDATE
 ON CC_SOB_GASTOS
 FOR EACH ROW
DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_SOB_GASTOS';
   r_caudi.clave := :old.nro_cuenta||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_TRA_PADRE',:old.cod_tra_padre,:new.cod_tra_padre,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MOD_PADRE',:old.cod_mod_padre,:new.cod_mod_padre,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MAD_PADRE',:old.cod_mad_padre,:new.cod_mad_padre,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_COBRO',:old.fec_cobro,:new.fec_cobro,'F');
   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


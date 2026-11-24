CREATE OR REPLACE TRIGGER IT.AA_GE_TAS_FECHAS
 AFTER DELETE OR UPDATE OR INSERT
 ON GE_TAS_FECHAS
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   elsif inserting then
      r_gaudi.tip_novedad := 'I';
   end if;

   r_gaudi.tabla := 'GE_TAS_FECHAS';
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   
   if r_gaudi.tip_novedad in ('M','E') then
      r_gaudi.clave := to_char(:old.cod_tasa)||'#'||to_char(:old.fec_vigencia,'ddmmrrrr')||'#'||
      to_char(:old.cod_oficina)||'#'||:old.cod_moneda||'#'||to_char(:old.cod_modulo)||'#'||
      to_char(:old.cod_modalidad)||'#'||:old.nro_cuenta||'#'||to_char(:old.cod_persona);
   else
      r_gaudi.clave := to_char(:new.cod_tasa)||'#'||to_char(:new.fec_vigencia,'ddmmrrrr')||'#'||
      to_char(:new.cod_oficina)||'#'||:new.cod_moneda||'#'||to_char(:new.cod_modulo)||'#'||
      to_char(:new.cod_modalidad)||'#'||:new.nro_cuenta||'#'||to_char(:new.cod_persona);
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TASA',:old.cod_tasa,:new.cod_tasa,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_VIGENCIA',:old.fec_vigencia,:new.fec_vigencia,'D');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_MAXIMO',:old.val_maximo,:new.val_maximo,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_MINIMO',:old.val_minimo,:new.val_minimo,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_BASE',:old.val_base,:new.val_base,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_EXTENSION',:old.val_extension,:new.val_extension,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'APLICAR',:old.aplicar,:new.aplicar);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'D');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACIONES',:old.observaciones,:new.observaciones);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_IVA',:old.tip_iva,:new.tip_iva);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NO_ACTUALIZABLE',:old.no_actualizable,:new.no_actualizable);

--- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


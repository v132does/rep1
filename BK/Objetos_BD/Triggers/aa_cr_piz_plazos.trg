CREATE OR REPLACE TRIGGER IT.AA_CR_PIZ_PLAZOS
 AFTER DELETE OR UPDATE
 ON CR_PIZ_PLAZOS
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_PIZ_PLAZOS';
   r_raudi.clave := to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||:old.cod_moneda||'#'||to_char(:old.mto_desde)||'#'||to_char(:old.plz_desde)||'#'||to_char(:old.tip_capitalizacion);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'PLZ_HASTA',:old.plz_hasta,:new.plz_hasta,'N');
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TAS_INTERES',:old.tas_interes,:new.tas_interes,'N');
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TAS_MINIMA',:old.tas_minima,:new.tas_minima,'N');
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TAS_MAXIMA',:old.tas_maxima,:new.tas_maxima,'N');
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TAS_EFECTIVA',:old.tas_efectiva,:new.tas_efectiva,'N');
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


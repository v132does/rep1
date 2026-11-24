CREATE OR REPLACE TRIGGER IT.AA_AH_DEVENGADOS_HIS
 AFTER DELETE OR UPDATE
 ON AH_DEVENGADOS_HIS
 FOR EACH ROW


DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_DEVENGADOS_HIS';
   r_aaudi.clave := :old.nro_cuenta||'#'||to_char(:old.ano)||'#'||to_char(:old.mes);
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


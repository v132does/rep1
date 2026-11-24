CREATE OR REPLACE TRIGGER IT.AA_PR_SOL_GARANTIAS
 AFTER DELETE OR UPDATE
 ON PR_SOL_GARANTIAS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SOL_GARANTIAS';
   r_paudi.clave := to_char(:old.nro_solicitud)||'#'||:old.nro_garantia||'#'||
   to_char(:old.cod_garantia);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_APLICADO',:old.mto_aplicado,:new.mto_aplicado,'M');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/


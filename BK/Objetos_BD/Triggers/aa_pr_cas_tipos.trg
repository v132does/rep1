CREATE OR REPLACE TRIGGER IT.AA_PR_CAS_TIPOS
 AFTER DELETE OR UPDATE
 ON PR_CAS_TIPOS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_CAS_TIPOS';
   r_paudi.clave := to_char(:old.cod_cas_tipo);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/


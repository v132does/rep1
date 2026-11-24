CREATE OR REPLACE TRIGGER IT.AA_PR_SEC_CREDITOS
 AFTER DELETE OR UPDATE
 ON PR_SEC_CREDITOS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SEC_CREDITOS';
   r_paudi.clave := to_char(:old.cod_sec_credito);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PREFERENCIAL',:old.preferencial,:new.preferencial);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_SEC_PADRE',:old.cod_sec_padre,:new.cod_sec_padre);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_BCO_CENTRAL',:old.cod_bco_central,:new.cod_bco_central);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_SEC_RUBRO',:old.cod_sec_rubro,:new.cod_sec_rubro);

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/


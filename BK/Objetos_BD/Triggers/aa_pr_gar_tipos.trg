CREATE OR REPLACE TRIGGER IT.AA_PR_GAR_TIPOS
 AFTER DELETE OR UPDATE
 ON PR_GAR_TIPOS
 FOR EACH ROW

DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_GAR_TIPOS';
   r_paudi.clave := to_char(:old.cod_garantia);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_BCO_CENTRAL',:old.por_bco_central,:new.por_bco_central,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_TRANSACCION1',:old.cod_transaccion1,:new.cod_transaccion1,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_TRANSACCION2',:old.cod_transaccion2,:new.cod_transaccion2,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COMPUTABLE',:old.computable,:new.computable);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PLZ_VENCIMIENTO',:old.plz_vencimiento,:new.plz_vencimiento,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'ACTIVO',:old.activo,:new.activo);    
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NOM_TAB_ANEXA',:old.nom_tab_anexa,:new.nom_tab_anexa);    
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_REF_BCO_CENTRAL',:old.cod_ref_bco_central, :new.cod_ref_bco_central);
   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/


CREATE OR REPLACE TRIGGER IT.AA_PR_GAR_TERCEROS
 AFTER DELETE OR UPDATE
 ON PR_GAR_TERCEROS
 FOR EACH ROW

DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_GAR_TERCEROS';
   r_paudi.clave := to_char(:old.nro_garantia) || '#' || :old.cod_persona;
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_UTILIZACION', :old.por_utilizacion, :new.por_utilizacion);
	r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_TERCERO', :old.tip_tercero, :new.tip_tercero);

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/


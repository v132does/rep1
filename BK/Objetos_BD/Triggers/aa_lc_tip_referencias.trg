CREATE OR REPLACE TRIGGER IT.AA_LC_TIP_REFERENCIAS
 AFTER DELETE OR UPDATE
 ON LC_TIP_REFERENCIAS
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_TIP_REFERENCIAS';
   r_laudi.clave := :old.cod_tip_referencia;
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'SIG_NUMERO',:old.sig_numero,:new.sig_numero,'N');

   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


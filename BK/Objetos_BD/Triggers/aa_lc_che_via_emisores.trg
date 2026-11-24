CREATE OR REPLACE TRIGGER IT.AA_LC_CHE_VIA_EMISORES
 AFTER DELETE OR UPDATE
 ON LC_CHE_VIA_EMISORES
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_CHE_VIA_EMISORES';
   r_laudi.clave := :old.cod_usu_emisor||'#'||:old.cod_moneda;
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NOMBRE',:old.nombre,:new.nombre);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_RUB_DEBITO',:old.cod_rub_debito,:new.cod_rub_debito);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_RUB_CREDITO',:old.cod_rub_credito,:new.cod_rub_credito);

   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


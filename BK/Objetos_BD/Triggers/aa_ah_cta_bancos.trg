CREATE OR REPLACE TRIGGER IT.AA_AH_CTA_BANCOS
 AFTER DELETE OR UPDATE
 ON AH_CTA_BANCOS
 FOR EACH ROW


DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CTA_BANCOS';
   r_aaudi.clave := to_char(:old.cod_banco)||'#'||:old.nro_cuenta;
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
end if;

   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


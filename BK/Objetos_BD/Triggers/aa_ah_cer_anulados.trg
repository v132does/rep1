CREATE OR REPLACE TRIGGER IT.AA_AH_CER_ANULADOS
 AFTER DELETE OR UPDATE
 ON AH_CER_ANULADOS
 FOR EACH ROW
DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CER_ANULADOS';
   r_aaudi.clave := to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||:old.serie||'#'||to_char(:old.nro_certificado);
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
end if;

   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


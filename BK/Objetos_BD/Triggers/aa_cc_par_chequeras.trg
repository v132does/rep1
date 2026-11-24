CREATE OR REPLACE TRIGGER IT.AA_CC_PAR_CHEQUERAS
 AFTER DELETE OR UPDATE
 ON CC_PAR_CHEQUERAS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_PAR_CHEQUERAS';
   r_caudi.clave := to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||
   to_char(:old.cod_oficina)||'#'||:old.cod_moneda||'#'||:old.cod_tip_chequera||'#'||to_char(:old.sig_nro_cheque);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SERIE',:old.serie,:new.serie);

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/


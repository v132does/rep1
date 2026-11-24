CREATE OR REPLACE TRIGGER IT.AA_GE_PAQ_CLIENTES
 AFTER DELETE OR UPDATE
 ON GE_PAQ_CLIENTES
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_PAQ_CLIENTES';
   r_gaudi.clave := to_char(:old.cod_paquete)||'#'||to_char(:old.cod_persona)||'#'||to_char(:old.nro_secuencia);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_INICIO',:old.FEC_INICIO,:new.FEC_INICIO,'F');
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_FINAL',:old.FEC_FINAL,:new.FEC_FINAL,'F');
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.ESTADO,:new.ESTADO);

--- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


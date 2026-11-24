CREATE OR REPLACE TRIGGER IT.AA_AH_CUP_BLOQUEADOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AH_CUP_BLOQUEADOS
 FOR EACH ROW
DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CUP_BLOQUEADOS';
   r_aaudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_cupon);
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
end if;

   --- Registrar Detalle
    r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'HORA',:old.hora,:new.hora);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'BLOQUEADO',:old.bloqueado,:new.bloqueado);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/


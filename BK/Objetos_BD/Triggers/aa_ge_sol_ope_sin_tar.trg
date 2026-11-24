CREATE OR REPLACE TRIGGER IT.aa_ge_sol_ope_sin_tar
 AFTER DELETE OR UPDATE
 ON "IT"."GE_SOL_OPE_SIN_TAR"
 FOR EACH ROW
DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GMPROARC' then
   -- para no generar auditoria de la importacion de datos (OFAC, OSC, ETC)
   r_eaudi.tabla := 'GE_SOL_OPE_SIN_TAR';
   r_eaudi.clave := :old.cod_persona;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta ,:new.nro_cuenta );
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_TEL_NUEVO',:old.nro_tel_nuevo,:new.nro_tel_nuevo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_TEL_ANT',:old.nro_tel_ant ,:new.nro_tel_ant);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ACCION',:old.accion,:new.accion);
   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
end if;
END;
/


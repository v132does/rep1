CREATE OR REPLACE TRIGGER IT."AA_CR_PER_TIP_HECTAREAS"
 AFTER DELETE OR UPDATE
 ON CR_PER_TIP_HECTAREAS
 FOR EACH ROW
DECLARE
r_caudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CR_PER_TIP_HECTAREAS';
   r_caudi.clave := to_char(:old.cod_persona);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_RUB_PRIMARIO',:old.COD_RUB_PRIMARIO,:new.COD_RUB_PRIMARIO);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ANHO',:old.ANHO,:new.ANHO);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MES',:old.MES,:new.MES);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'TIP_HEC_CULTIVADAS',:old.TIP_HEC_CULTIVADAS,:new.TIP_HEC_CULTIVADAS);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_HEC_CULTIVADAS',:old.NRO_HEC_CULTIVADAS,:new.NRO_HEC_CULTIVADAS);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_caudi);
END;
/


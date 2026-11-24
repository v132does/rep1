CREATE OR REPLACE TRIGGER IT.AA_CB_RUB_PLZ_MAXIMOS
 AFTER DELETE OR UPDATE
 ON CB_RUB_PLZ_MAXIMOS
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_RUB_PLZ_MAXIMOS';
   r_baudi.clave := :old.cod_rubro;
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'FECHA',:old.fecha ,:new.fecha, 'F');
		r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PLZ_MAXIMO',:old.plz_maximo ,:new.plz_maximo, 'N');
		r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DIA_EXCESO',:old.dia_exceso ,:new.dia_exceso, 'N');
		r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_MON_LOCAL',:old.sal_mon_local ,:new.sal_mon_local, 'M');
		r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_MON_RUBRO',:old.sal_mon_rubro ,:new.sal_mon_rubro, 'M');
		r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_MON_LOC_ANTERIOR',:old.sal_mon_loc_anterior ,:new.sal_mon_loc_anterior, 'M');
		r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_MON_RUB_ANTERIOR',:old.sal_mon_rub_anterior  ,:new.sal_mon_rub_anterior, 'M');


   --- Insertar tabla de auditoria
   PRB_INS_CB_AUDITORIA(r_baudi);
END;
/


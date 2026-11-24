CREATE OR REPLACE TRIGGER IT.AA_GE_CALENDARIOS
 AFTER DELETE OR UPDATE
 ON GE_CALENDARIOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CALENDARIOS';
   r_gaudi.clave := to_char(:old.cod_modulo);
   r_gaudi.fec_calendario := :new.fec_actual;

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ACTUAL',:old.fec_actual,:new.fec_actual,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NOM_DIA',:old.nom_dia,:new.nom_dia);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NOM_MES',:old.nom_mes,:new.nom_mes);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_TRIMESTRE',:old.nro_trimestre,:new.nro_trimestre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_PROXIMA',:old.fec_proxima,:new.fec_proxima,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ANTERIOR',:old.fec_anterior,:new.fec_anterior,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PRI_DIA_MES',:old.pri_dia_mes,:new.pri_dia_mes,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PRI_DIA_MES_HABIL',:old.pri_dia_mes_habil,:new.pri_dia_mes_habil,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ULT_DIA_MES',:old.ult_dia_mes,:new.ult_dia_mes,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ULT_DIA_MES_HABIL',:old.ult_dia_mes_habil,:new.ult_dia_mes_habil,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PRI_DIA_TRIMESTRE',:old.pri_dia_trimestre,:new.pri_dia_trimestre,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PRI_DIA_HAB_TRIMESTRE',:old.pri_dia_hab_trimestre,:new.pri_dia_hab_trimestre,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ULT_DIA_TRIMESTRE',:old.ult_dia_trimestre,:new.ult_dia_trimestre,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ULT_DIA_HAB_TRIMESTRE',:old.ult_dia_hab_trimestre,:new.ult_dia_hab_trimestre,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MES_INI_TRIMESTRE',:old.mes_ini_trimestre,:new.mes_ini_trimestre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MES_FIN_TRIMESTRE',:old.mes_fin_trimestre,:new.mes_fin_trimestre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CAN_DIA_ANO',:old.can_dia_ano,:new.can_dia_ano,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


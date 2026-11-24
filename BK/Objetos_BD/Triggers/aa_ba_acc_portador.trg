CREATE OR REPLACE TRIGGER IT.AA_BA_ACC_PORTADOR
 AFTER DELETE OR UPDATE
 ON BA_ACC_PORTADOR
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_ACC_PORTADOR';
   r_eaudi.clave := to_char(:old.cod_persona);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   -- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'IND_ACC_PORTADOR',:old.ind_acc_portador,:new.ind_acc_portador);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAP_SUSCRITO',:old.cap_suscrito,:new.cap_suscrito);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAP_INTEGRADO',:old.cap_integrado,:new.cap_integrado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_ACC_PORTADOR',:old.can_acc_portador,:new.can_acc_portador);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_ACC_NOMINATIVA',:old.can_acc_nominativa,:new.can_acc_nominativa);


   -- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/


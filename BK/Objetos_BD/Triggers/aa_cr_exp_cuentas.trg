CREATE OR REPLACE TRIGGER IT.AA_CR_EXP_CUENTAS
 AFTER DELETE OR UPDATE
 ON CR_EXP_CUENTAS
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_EXP_CUENTAS';
   r_raudi.clave := :old.cod_persona||'#'||to_char(:old.ano_mes,'ddmmrrrr')||'#'||:old.nro_cuenta;
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TIP_CUENTA',:old.tip_cuenta,:new.tip_cuenta);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'SAL_PROMEDIO',:old.sal_promedio,:new.sal_promedio,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'SAL_CIERRE',:old.sal_cierre,:new.sal_cierre,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INT_COBRADOS',:old.int_cobrados,:new.int_cobrados,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INT_PAGADOS',:old.int_pagados,:new.int_pagados,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COM_COBRADAS',:old.com_cobradas,:new.com_cobradas,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TAS_INTERES',:old.tas_interes,:new.tas_interes,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAN_DEBITOS',:old.can_debitos,:new.can_debitos,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CAN_CREDITOS',:old.can_creditos,:new.can_creditos,'N');

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


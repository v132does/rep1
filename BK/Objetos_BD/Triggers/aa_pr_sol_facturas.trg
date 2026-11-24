CREATE OR REPLACE TRIGGER IT.AA_PR_SOL_FACTURAS
 AFTER DELETE OR UPDATE
 ON PR_SOL_FACTURAS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SOL_FACTURAS';
   r_paudi.clave := :old.nro_factura;
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_SOLICITUD',:old.nro_solicitud,:new.nro_solicitud,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_CUOTA',:old.nro_cuota,:new.nro_cuota,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_OPERACION',:old.tip_operacion,:new.tip_operacion);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_ENTE',:old.cod_ente,:new.cod_ente,'N');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/


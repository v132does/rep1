CREATE OR REPLACE TRIGGER IT.AA_LC_TIP_OPERACIONES
 AFTER DELETE OR UPDATE
 ON LC_TIP_OPERACIONES
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_TIP_OPERACIONES';
   r_laudi.clave := :old.cod_tip_operacion;
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NIVEL',:old.nivel,:new.nivel,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TIP_OPE_BCP',:old.cod_tip_ope_bcp,:new.cod_tip_ope_bcp);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO1',:old.cod_tra_cargo1,:new.cod_tra_cargo1,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO2',:old.cod_tra_cargo2,:new.cod_tra_cargo2,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO3',:old.cod_tra_cargo3,:new.cod_tra_cargo3,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO4',:old.cod_tra_cargo4,:new.cod_tra_cargo4,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MOD_ORIGEN',:old.cod_mod_origen,:new.cod_mod_origen,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MAD_HIJO',:old.cod_mad_hijo,:new.cod_mad_hijo,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_COD_TRANSACCION',:old.afe_cod_transaccion,:new.afe_cod_transaccion,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_POSICION',:old.afe_posicion,:new.afe_posicion);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_LIMITE',:old.afe_limite,:new.afe_limite);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_CHE_VIAJERO',:old.afe_che_viajero,:new.afe_che_viajero);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_OPE_FUTURA',:old.afe_ope_futura,:new.afe_ope_futura);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_TRANSFERENCIA',:old.afe_transferencia,:new.afe_transferencia);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_IMPUESTOS',:old.afe_impuestos,:new.afe_impuestos);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CAJA',:old.caja,:new.caja);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'TIP_VALOR',:old.tip_valor,:new.tip_valor);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MODIFICABLE',:old.modificable,:new.modificable);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'AFE_LIBRANZA',:old.afe_libranza,:new.afe_libranza);

   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/


CREATE OR REPLACE TRIGGER IT.AA_GE_COM_PROMOCIONES
 AFTER DELETE OR UPDATE
 ON "IT"."GE_COM_PROMOCIONES"
 FOR EACH ROW


DECLARE
   r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_COM_PROMOCIONES';
   r_eaudi.clave := :old.cod_ent_comercio||'#'||:old.cod_promo;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(1);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_ENT_COMERCIO',:old.cod_ent_comercio,:new.cod_ent_comercio);
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PROMO',:old.cod_promo,:new.cod_promo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DES_PROMOCION',:old.des_promocion,:new.des_promocion);
   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/


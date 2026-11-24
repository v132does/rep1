CREATE OR REPLACE TRIGGER IT.AA_CO_INF_MONEDAS
 AFTER DELETE OR UPDATE
 ON CO_INF_MONEDAS
 FOR EACH ROW
DECLARE
  r_raudi CO_AUDITORIAS%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CO_INF_MONEDAS';
   r_raudi.clave := to_char( :old.cod_moneda );
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );

   IF updating THEN
     r_raudi.tip_novedad := 'M';
   ELSIF deleting THEN
     r_raudi.tip_novedad := 'E';
   END IF;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
   r_raudi.detalle := r_raudi.detalle || pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'COD_INF_MONEDA', :old.cod_inf_moneda, :new.cod_inf_moneda );
   --- Insertar tabla de auditoria
   pro_ins_co_auditoria( r_raudi );
EXCEPTION
  when others then
    pro_ins_co_auditoria( r_raudi );
END;
/


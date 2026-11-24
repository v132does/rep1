CREATE OR REPLACE TRIGGER IT.AA_CO_INF_OPERACIONES
 AFTER DELETE OR UPDATE
 ON CO_INF_OPERACIONES
 FOR EACH ROW
DECLARE
  r_raudi CO_AUDITORIAS%ROWTYPE; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CO_INF_OPERACIONES';
   r_raudi.clave := to_char( :old.cod_inf_operacion );
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );

   IF updating THEN
     r_raudi.tip_novedad := 'M';
   ELSIF deleting THEN
     r_raudi.tip_novedad := 'E';
   END IF;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria( r_raudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
   --- Insertar tabla de auditoria
   pro_ins_co_auditoria( r_raudi );
EXCEPTION
  when others then
    pro_ins_co_auditoria( r_raudi );
END;
/


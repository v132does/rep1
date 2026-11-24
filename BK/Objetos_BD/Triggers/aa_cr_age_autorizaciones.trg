CREATE OR REPLACE TRIGGER IT.AA_CR_AGE_AUTORIZACIONES
 AFTER DELETE OR UPDATE
 ON CR_AGE_AUTORIZACIONES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_AGE_AUTORIZACIONES';
   r_raudi.clave := :old.cod_usuario||'#'||:old.cod_grupo||'#'||:old.cod_usu_encargado;
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'INSERTA',:old.inserta,:new.inserta);
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'ELIMINA',:old.elimina,:new.elimina);
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'ACTUALIZA',:old.actualiza,:new.actualiza);
    r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'CONSULTA',:old.consulta,:new.consulta);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


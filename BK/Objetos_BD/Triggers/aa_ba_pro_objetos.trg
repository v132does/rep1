CREATE OR REPLACE TRIGGER IT.AA_BA_PRO_OBJETOS
 AFTER DELETE OR UPDATE
 ON BA_PRO_OBJETOS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_PRO_OBJETOS';
   r_eaudi.clave := :old.cod_programa||'#'||:old.objeto;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PROGRAMA ',:old.cod_programa,:new.cod_programa);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OBJETO',:old.objeto,:new.objeto);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIP_OBJETO',:old.tip_objeto,:new.tip_objeto);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'INSERTA',:old.inserta,:new.inserta);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MODIFICA',:old.modifica,:new.modifica);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ELIMINA',:old.elimina,:new.elimina);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CONSULTA',:old.consulta,:new.consulta);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OTRO',:old.otro,:new.otro);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'VERSION',:old.version,:new.version);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_CLIENTE',:old.cod_cliente,:new.cod_cliente);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COMENTARIO',:old.comentario,:new.comentario);
   --- Insertar tabla de auditoria
   PAE_CNF.PR_INS_BA_AUDITORIA(r_eaudi);
END;
/


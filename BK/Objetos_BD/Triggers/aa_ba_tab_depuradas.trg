CREATE OR REPLACE TRIGGER IT.AA_BA_TAB_DEPURADAS
 AFTER DELETE OR UPDATE
 ON BA_TAB_DEPURADAS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_TAB_DEPURADAS';
   r_eaudi.clave := :old.nom_tabla;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NOM_TAB_DESTINO',:old.NOM_TAB_DESTINO,:new.NOM_TAB_DESTINO);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FRECUENCIA',:old.FRECUENCIA,:new.FRECUENCIA);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CONDICION',:old.CONDICION,:new.CONDICION);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_ORDEN',:old.NRO_ORDEN,:new.NRO_ORDEN,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'HOR_INICIO',:old.HOR_INICIO,:new.HOR_INICIO);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'HOR_FIN',:old.HOR_FIN,:new.HOR_FIN);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OBLIGATORIO',:old.OBLIGATORIO,:new.OBLIGATORIO);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAN_REGISTROS',:old.CAN_REGISTROS,:new.CAN_REGISTROS,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USUARIO',:old.COD_USUARIO,:new.COD_USUARIO);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIP_FECHA',:old.TIP_FECHA,:new.TIP_FECHA); 
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'BORRAR',:old.BORRAR,:new.BORRAR);      
  -- r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ERROR',:old.ERROR,:new.ERROR);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/


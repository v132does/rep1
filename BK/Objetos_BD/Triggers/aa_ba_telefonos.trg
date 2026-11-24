CREATE OR REPLACE TRIGGER IT.AA_BA_TELEFONOS
 AFTER DELETE OR UPDATE
 ON BA_TELEFONOS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GMPROARC' then 
   -- para no generar auditoria de la importacion de datos (OFAC, OSC, ETC)
   r_eaudi.tabla := 'BA_TELEFONOS';
   r_eaudi.clave := :old.cod_persona||'#'||to_char(:old.cod_telefono);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIP_LINEA',:old.tip_linea,:new.tip_linea);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TELEFONO',:old.telefono,:new.telefono);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PRINCIPAL',:old.principal,:new.principal);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'AREA',:old.area,:new.area);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'INTERNO',:old.interno,:new.interno);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
end if;   
END;
/


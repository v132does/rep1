CREATE OR REPLACE TRIGGER IT.AA_BA_DIRECCIONES
 AFTER DELETE OR UPDATE
 ON BA_DIRECCIONES
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GMPROARC' then
   -- para no generar auditoria de la importacion de datos (OFAC, OSC, ETC)
   r_eaudi.tabla := 'BA_DIRECCIONES';
   r_eaudi.clave := :old.cod_persona||'#'||to_char(:old.cod_direccion);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PRINCIPAL',:old.principal,:new.principal);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DIRECCION',:old.direccion,:new.direccion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PAIS',:old.cod_pais,:new.cod_pais,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_CIUDAD',:old.cod_ciudad,:new.cod_ciudad,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_BARRIO',:old.cod_barrio,:new.cod_barrio,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NUMERO',:old.numero,:new.numero);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DEPARTAMENTO',:old.departamento,:new.departamento);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PISO',:old.piso,:new.piso);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'EDIFICIO',:old.edificio,:new.edificio);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_POSTAL',:old.cod_postal,:new.cod_postal);
   
   --- Insertar tabla de auditoria
   PAE_CNF.PR_INS_BA_AUDITORIA(r_eaudi);
end if;
END;
/


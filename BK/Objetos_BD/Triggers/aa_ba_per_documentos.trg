CREATE OR REPLACE TRIGGER IT.AA_BA_PER_DOCUMENTOS
 AFTER DELETE OR UPDATE
 ON BA_PER_DOCUMENTOS
 FOR EACH ROW


DECLARE
r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GMPROARC' then 
   -- para no generar auditoria de la importacion de datos (OFAC, OSC, ETC)
   r_eaudi.tabla := 'BA_PER_DOCUMENTOS';
   r_eaudi.clave := :old.cod_persona||'#'||:old.cod_tip_documento;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_DOCUMENTO',:old.nro_documento,:new.nro_documento);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VTO_DOCUMENTO',:old.fec_vto_documento,:new.fec_vto_documento,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DNA',:old.dna,:new.dna);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
end if;   
END;
/


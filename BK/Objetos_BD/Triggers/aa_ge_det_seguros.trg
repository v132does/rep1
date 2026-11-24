CREATE OR REPLACE TRIGGER IT."AA_GE_DET_SEGUROS"
 AFTER DELETE OR UPDATE
 ON GE_DET_SEGUROS
 FOR EACH ROW
DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_DET_SEGUROS';
   r_eaudi.clave := :old.cod_tipo;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_ASEGURADO',:old.mto_asegurado,:new.mto_asegurado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_CUOTA',:old.mto_cuota,:new.mto_cuota);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SEG_CLIENTE',:old.seg_cliente,:new.seg_cliente);
	r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEXTO',:old.texto,:new.texto);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN1',:old.tex_lin1,:new.tex_lin1);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN2',:old.tex_lin2,:new.tex_lin2);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN3',:old.tex_lin3,:new.tex_lin3);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN4',:old.tex_lin4,:new.tex_lin4);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN5',:old.tex_lin5,:new.tex_lin5);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN6',:old.tex_lin6,:new.tex_lin6);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN7',:old.tex_lin7,:new.tex_lin7);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TEX_LIN8',:old.tex_lin8,:new.tex_lin8);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/


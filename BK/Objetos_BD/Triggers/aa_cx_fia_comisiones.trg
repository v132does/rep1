CREATE OR REPLACE TRIGGER IT.AA_CX_FIA_COMISIONES
 AFTER DELETE OR UPDATE
 ON CX_FIA_COMISIONES
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

r_xaudi CX_AUDITORIAS%ROWTYPE; -- Registro de la tabla CX_AUDITORIAS
BEGIN
   r_xaudi.tabla := 'CX_FIA_COMISIONES';
   r_xaudi.clave := :old.cod_fianza||'#'||to_char(:old.nro_cuota);
   r_xaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_xaudi.tip_novedad := 'M';
   elsif deleting then
      r_xaudi.tip_novedad := 'E';

end if;

   --- Registrar Detalle
    r_xaudi.detalle := pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad,'IMPORTE',:old.IMPORTE,:new.IMPORTE,'M');
    r_xaudi.detalle := r_xaudi.detalle||pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_xaudi.detalle := r_xaudi.detalle||pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_xaudi.detalle := r_xaudi.detalle||pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad,'SALDO',:old.SALDO,:new.SALDO,'M');

   --- Insertar tabla de auditoria
   prx_ins_cx_auditoria(r_xaudi);
END;
/


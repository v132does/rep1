CREATE OR REPLACE TRIGGER IT.AA_GE_EMBARGOS
 AFTER DELETE OR UPDATE
 ON GE_EMBARGOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_EMBARGOS';
   r_gaudi.clave := to_char(:old.cod_embargo);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HORA',:old.hora,:new.hora);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_RESOLUCION',:old.nro_resolucion,:new.nro_resolucion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFI_ORIGEN',:old.cod_ofi_origen,:new.cod_ofi_origen,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_OFICIO',:old.nro_oficio,:new.nro_oficio);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_OFICIO',:old.fec_oficio,:new.fec_oficio,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'IMPORTE',:old.importe,:new.importe,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'GAS_JUSTICIA',:old.gas_justicia,:new.gas_justicia,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LEV_NRO_OFICIO',:old.lev_nro_oficio,:new.lev_nro_oficio);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LEV_COD_USUARIO',:old.lev_cod_usuario,:new.lev_cod_usuario);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LEV_COD_AUTORIZADOR',:old.lev_cod_autorizador,:new.lev_cod_autorizador);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LEV_FECHA',:old.lev_fecha,:new.lev_fecha,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LEV_FEC_OFICIO',:old.lev_fec_oficio,:new.lev_fec_oficio,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'JUZGADO',:old.juzgado,:new.juzgado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CIRCUNSCRIPCION',:old.circunscripcion,:new.circunscripcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MOTIO',:old.motivo,:new.motivo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DEMANDANTE',:old.demandante,:new.demandante);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/


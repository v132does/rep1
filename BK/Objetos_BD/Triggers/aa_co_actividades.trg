CREATE OR REPLACE TRIGGER IT.AA_CO_ACTIVIDADES
  AFTER DELETE OR UPDATE
     ON CO_ACTIVIDADES
    FOR EACH ROW


DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2005 a las 10:33:35 Hs.
  */
  v_registro CO_AUDITORIAS%ROWTYPE; -- Registro de la tabla CO_AUDITORIAS
BEGIN
  v_registro.tabla := 'CO_ACTIVIDADES';
  v_registro.clave := to_char( :old.cod_campana ) || '#' || to_char( :old.cod_agenda ) || '#' || :old.nro_cuenta;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
--  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CLIENTE'/*, :old.cod_cliente, :new.cod_cliente*/ );
--  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ASIGNACION', /*:old.fec_asignacion, :new.fec_asignacion, */'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
--  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', /*:old.monto, :new.monto,*/ 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_RESPONSABLE', :old.cod_usu_responsable, :new.cod_usu_responsable );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA_ATRASO', :old.dia_atraso, :new.dia_atraso, 'N' );

  -- Insertar tabla de auditoria
  pro_ins_co_auditoria( v_registro );
EXCEPTION
  when others then
    pro_ins_co_auditoria( v_registro );
END;
/


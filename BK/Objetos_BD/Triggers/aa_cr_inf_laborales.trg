CREATE OR REPLACE TRIGGER IT.AA_CR_INF_LABORALES
 AFTER DELETE OR UPDATE
 ON CR_INF_LABORALES
 FOR EACH ROW


DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_INF_LABORALES';
   r_raudi.clave := :old.cod_persona||'#'||to_char(:old.nro_secuencia);
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'LUG_TRABAJO',:old.lug_trabajo,:new.lug_trabajo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_INGRESO',:old.fec_ingreso,:new.fec_ingreso,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'FEC_SALIDA',:old.fec_salida,:new.fec_salida,'F');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'MTO_INGRESO',:old.mto_ingreso,:new.mto_ingreso,'M');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'DES_PUESTO',:old.des_puesto,:new.des_puesto);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TIP_CARGO',:old.tip_cargo,:new.tip_cargo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TIP_INGRESO',:old.tip_ingreso,:new.tip_ingreso,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'ACTUAL',:old.actual,:new.actual);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'TIP_EMPLEO',:old.tip_empleo,:new.tip_empleo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_RAMO',:old.cod_ramo,:new.cod_ramo,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_DIRECCION',:old.cod_direccion,:new.cod_direccion,'N');
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_TELEFONO',:old.cod_telefono,:new.cod_telefono,'N');
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'MTO_FIJO',:old.mto_fijo,:new.mto_fijo);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/


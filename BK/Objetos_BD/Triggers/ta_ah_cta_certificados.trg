CREATE OR REPLACE TRIGGER IT.TA_AH_CTA_CERTIFICADOS
 AFTER DELETE OR INSERT OR UPDATE
 ON AH_CTA_CERTIFICADOS
 FOR EACH ROW


DECLARE
   r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
   v_nro_cuenta ge_cuentas.nro_cuenta%type;
BEGIN
   if inserting or updating then
      r_gcuen.nro_cuenta        := :new.nro_cuenta;
      v_nro_cuenta              := :new.nro_cuenta;
      r_gcuen.dig_verificador   := :new.dig_verificador;
      r_gcuen.denominacion      := :new.denominacion;
      r_gcuen.cod_modulo        := :new.cod_modulo;
      r_gcuen.cod_modalidad     := :new.cod_modalidad;
      r_gcuen.cod_oficina       := :new.cod_oficina;
      r_gcuen.estado            := :new.estado;
      r_gcuen.fec_cam_estado    := :new.fec_cam_estado;
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_apertura;
      r_gcuen.fec_vencimiento   := :new.fec_vencimiento;
      r_gcuen.cod_tasa          := :new.cod_tasa;
      r_gcuen.tas_personalizada := :new.tas_personalizada;
      r_gcuen.tra_prohibida     := :new.tra_prohibida;
      r_gcuen.sal_contable      := NVL(:new.sal_total,0)/*nvl(:new.sal_total,:new.capital)*/- nvl(:new.sal_retenido,0);
      r_gcuen.fre_extracto      := 'M';
      r_gcuen.ret_personalizada := 'N';
      r_gcuen.cod_cau_cancelacion := :new.cod_cau_cancelacion;      
      if updating and :new.nro_certificado is null and :old.nro_certificado is not null then 
         r_gcuen.est_verificacion := 'N'; -- vuelve a verificacion
      end if;
   end if;
   if inserting then
      --- Insertar tabla de Cuentas
      PAA_CTA.PRA_INS_GE_CUENTAS(r_gcuen);
   elsif updating then
      --- Actualizar datos en Cuentas
      if :new.nro_cuenta <> :old.nro_cuenta then
         v_nro_cuenta := :old.nro_cuenta;
      end if;
      PAA_CTA.PRA_UPD_GE_CUENTAS(v_nro_cuenta, r_gcuen);
   elsif deleting then
     --Borrar..
      Delete
      from GE_CUENTAS
      where nro_cuenta = :old.nro_cuenta;
   end if;
END;
/


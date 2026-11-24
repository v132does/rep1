CREATE OR REPLACE TRIGGER IT.TA_CC_CTA_BANCARIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_CTA_BANCARIAS
 FOR EACH ROW

DECLARE
r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
v_nro_cuenta ge_cuentas.nro_cuenta%type := :new.nro_cuenta;
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
      r_gcuen.sal_contable      := nvl(:new.sal_total,0)-nvl(:new.sal_retenido,0);
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_apertura;
      r_gcuen.fre_extracto      := 'M';
      r_gcuen.tas_personalizada := 'N';
      r_gcuen.tra_prohibida     := 'N';
      r_gcuen.ret_personalizada := 'N';
		r_gcuen.est_verificacion  := 'V';
   end if;
   if inserting then
      --- Insertar tabla de Cuentas
      PAA_CTA.PRA_INS_GE_CUENTAS(r_gcuen);
   elsif updating then
      if :old.nro_cuenta <> :new.nro_cuenta then
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


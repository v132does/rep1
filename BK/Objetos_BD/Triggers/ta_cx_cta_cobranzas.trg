CREATE OR REPLACE TRIGGER IT.TA_CX_CTA_COBRANZAS
 AFTER DELETE OR INSERT OR UPDATE
 ON CX_CTA_COBRANZAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
v_nro_cuenta ge_cuentas.nro_cuenta%type := :new.nro_cuenta;

BEGIN
   if inserting or updating then
      r_gcuen.nro_cuenta        := :new.nro_cuenta;
      r_gcuen.dig_verificador   := 0;
      v_nro_cuenta              := :new.nro_cuenta;
      r_gcuen.denominacion      := :new.denominacion;
      r_gcuen.cod_modulo        := :new.cod_modulo;
      r_gcuen.cod_modalidad     := :new.cod_modalidad;
      r_gcuen.cod_oficina       := :new.cod_oficina;
      r_gcuen.estado            := :new.estado;
      r_gcuen.fre_extracto      := 'M';
      r_gcuen.tas_personalizada := 'N';
      r_gcuen.ret_personalizada := 'N';
      r_gcuen.tra_prohibida     := 'N';
      if :new.estado = 'A' then
         r_gcuen.fec_cam_estado    := :new.fec_aprobacion;
      elsif :new.estado = 'C' then
         r_gcuen.fec_cam_estado    := :new.fec_cancelacion;
      elsif :new.estado = 'S' then
         r_gcuen.fec_cam_estado    := :new.fec_inicio;
      end if;
      r_gcuen.sal_contable      := nvl(:new.saldo,0);
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_aprobacion;
      r_gcuen.fec_vencimiento   := :new.fec_vencimiento;
      -- r_gcuen.val_tasa          := :new.val_tasa;
      r_gcuen.est_verificacion   := 'V';
      r_gcuen.cod_sit_contable  := :new.cod_sit_contable;  

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


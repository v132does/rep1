CREATE OR REPLACE TRIGGER IT.TA_CX_FIANZAS
 AFTER DELETE OR INSERT OR UPDATE
 ON CX_FIANZAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
v_nro_cuenta ge_cuentas.nro_cuenta%type := :new.nro_cuenta;
BEGIN
   if (updating or inserting) and :new.nro_cuenta is not null then
      r_gcuen.nro_cuenta        := :new.nro_cuenta;
      v_nro_cuenta              := :new.nro_cuenta;
      r_gcuen.dig_verificador   := nvl(:new.dig_verificador,0);
      r_gcuen.denominacion      := nvl(:new.descripcion,'.');
      r_gcuen.cod_modulo        := :new.cod_modulo;
      r_gcuen.cod_modalidad     := :new.cod_modalidad;
      r_gcuen.cod_oficina       := :new.cod_oficina;
      r_gcuen.estado            := :new.estado;
      r_gcuen.fre_extracto      := 'M';
      r_gcuen.tas_personalizada := 'N';
      r_gcuen.ret_personalizada := 'N';
      r_gcuen.tra_prohibida     := 'N';
      if :new.estado = 'A' then
         r_gcuen.fec_cam_estado    := :new.fec_concesion;
      elsif :new.estado = 'C' then
         r_gcuen.fec_cam_estado    := :new.fec_cancelacion;
      end if;
      r_gcuen.sal_contable      := nvl(:new.monto,0);
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_concesion;
      r_gcuen.fec_vencimiento   := :new.fec_vencimiento;
      r_gcuen.val_tasa          := :new.val_tas_comision;
      r_gcuen.est_verificacion  :='V'; 
      r_gcuen.cod_sit_contable  := :new.cod_sit_contable; 
            
      if :new.estado = 'A' then
         update cx_fia_comisiones 
            set estado = 'A'
           where cod_fianza = :new.cod_fianza; 
      end if;     
      
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


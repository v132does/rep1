CREATE OR REPLACE TRIGGER IT.TA_LC_CTA_CAMBIOS
 AFTER DELETE OR INSERT OR UPDATE
 ON LC_CTA_CAMBIOS
 FOR EACH ROW




DECLARE
r_gcuen          ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
v_nro_cuenta     ge_cuentas.nro_cuenta%type := :new.nro_cuenta;
v_mto_utilizado  lc_cta_cambios.mto_limite%Type;

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
      r_gcuen.sal_contable      := :new.mto_limite;
      r_gcuen.fec_cam_estado    := :new.fec_cam_estado;
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_apertura;
      r_gcuen.fec_vencimiento   := :new.fec_vencimiento;
      r_gcuen.tas_personalizada := 'N';
      r_gcuen.tra_prohibida     := 'N';
      r_gcuen.fre_extracto      := 'M';
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
   
   -- Al cancelar la cuenta actualizamos el monto en la linea si corresponde - CNF-RABP:05-05-2015
   if updating then
     if :old.nro_linea is not null and :new.estado = 'C' Then
      begin
         --CNF-RABP:04-08-2015:Restamos los totales        
        Select a.mto_aplicado 
          Into v_mto_utilizado
          From pr_lin_tip_gar_mad a
         where a.nro_linea = :old.nro_linea
           and a.cod_modulo = 7
           and a.cod_modalidad = 70;
     
        --'Actualizar monto en detalle.';
        update pr_lin_tip_gar_mad a
           set a.mto_aplicado = nvl(a.mto_aplicado,0) - nvl(v_mto_utilizado,0)
         where a.nro_linea = :old.nro_linea
           and a.cod_modulo = 7
           and a.cod_modalidad = 70;
           
        --'Actualizar monto en cabecera.';
        update pr_lineas b
           set b.mto_aplicado = nvl(b.mto_aplicado,0) - nvl(v_mto_utilizado,0)
         where b.nro_linea = :old.nro_linea;
                                
        --'Actualizar monto en garantia.';
        update pr_lin_tip_garantias c
           set c.mto_aplicado = nvl(c.mto_aplicado,0) - nvl(v_mto_utilizado,0)
         where c.nro_linea = :old.nro_linea
           and c.cod_garantia=1;
     ---DYDMR-10076 Incidencia SAU - ITGF - Error Cierre
     exception
       when no_data_found then
         null;
       when others then
           RAISE_APPLICATION_ERROR(-20000,'ERROR. al Act. Limite Aplicado '||sqlerrm
                                         ||'- Nro. Linea: '||:old.nro_linea||'- Nro. Cuenta: '||v_nro_cuenta);         
     end;
     end if;
   end if;
END;
/


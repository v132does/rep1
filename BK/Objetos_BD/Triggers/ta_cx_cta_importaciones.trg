CREATE OR REPLACE TRIGGER IT.TA_CX_CTA_IMPORTACIONES
 AFTER DELETE OR INSERT OR UPDATE
 ON CX_CTA_IMPORTACIONES
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
v_nro_cuenta ge_cuentas.nro_cuenta%type := :new.nro_cuenta;
v_nom_completo varchar2(200);
  /* CURSOR cash is
   select nro_garantia, mto_aplicado
     from cx_cta_garantias
    where --cod_garantia = 5
      fup_obt_nom_tab_anexa(cod_garantia) = 'PR_GAR_CASH'
      and nro_cuenta   = :new.nro_cuenta;*/
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
         r_gcuen.fec_cam_estado    := :new.fec_solicitud;
      end if;
      r_gcuen.sal_contable      := nvl(:new.saldo,0);
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_aprobacion;
      r_gcuen.fec_vencimiento   := :new.fec_vencimiento;
      r_gcuen.est_verificacion  :='V';      
      -- r_gcuen.val_tasa          := :new.val_tasa;
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
      --********************************
      --if :new.estado <> :old.estado then
        --si reversa la utilización deshacer las cuotas generadas
        /*if :old.estado = 'U' and :new.estado = 'A' then --esto se da en la primera porción utilizada, SE HACE EN LA REVERSION
           --verifica si puede reversar, sólo si no se pagó ninguna cuota
           if (:new.saldo + nvl(:new.mto_prepago,0)) <> :new.nvo_monto then
              raise_application_error(-20440,'No puede deshacer la Utilización de la CCI. Ya fue pagada.');
           end if;
           --eliminar
           delete cx_cuotas where nro_cuenta = v_nro_cuenta;
        end if;*/
        --SE LLEVA A LA APLICACIÓN PORQUE DA MUTATING
        --sólo si se cancela la cci, se desvincula la garantía
        /*if :new.estado ='C' then --se cancela
          --verificar si posee garantias cash
          for reg in cash loop
            if reg.nro_garantia is not null then
              pap_gar.PR_PRO_GAR_CASH(reg.nro_garantia, :new.nro_cuenta, null, :new.fec_vencimiento, :new.cod_modulo,
                     :new.cod_modalidad, :new.cod_oficina, :new.cod_moneda, reg.mto_aplicado,'R');
                     --para q reverse, desaplicar el bloqueo x cash
            end if;
          end loop;
        end if;*/
        --SE TIENE QUE LLEVAR TAMBIÉN
        --si se reversa una cancelación se vuelve a vinculara a la garantía
        /* En la confirmación de la Garantía realiza el bloqueo de la cta.
        if :old.estado ='C' then
          --verificar si posee garantias cash
          for reg in cash loop
            if reg.nro_garantia is not null then
              pap_gar.PR_PRO_GAR_CASH(reg.nro_garantia, :new.nro_cuenta, null, :new.fec_vencimiento, :new.cod_modulo,
                     :new.cod_modalidad, :new.cod_oficina, :new.cod_moneda, reg.mto_aplicado);
                     --para q confirme, aplicar el bloqueo x cash
            end if;
          end loop;
        end if;
      end if;*/
      --*********************************
   elsif deleting then
     --Borrar..
      Delete
      from GE_CUENTAS
      where nro_cuenta = :old.nro_cuenta;
   end if;
END;
/


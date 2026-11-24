CREATE OR REPLACE TRIGGER IT."TA_OV_CTA_VENCIDAS"
 AFTER DELETE OR INSERT OR UPDATE
 ON OV_CTA_VENCIDAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

r_gcuen ge_cuentas%rowtype; -- Registro de la tabla GE_CUENTAS
v_nro_cuenta ge_cuentas.nro_cuenta%type := :new.nro_cuenta;

   CURSOR cash is
   select nro_garantia, mto_aplicado
     from ov_cta_garantias
    where cod_garantia = 5
      and nro_cuenta   = :new.nro_cuenta;

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
      r_gcuen.sal_contable      := nvl(:new.sal_total,0);
      r_gcuen.cod_moneda        := :new.cod_moneda;
      r_gcuen.fec_apertura      := :new.fec_apertura;
      r_gcuen.fre_extracto      := 'M';
      r_gcuen.ret_personalizada := 'N';
      r_gcuen.dia_atraso        := :new.dia_atraso;
      r_gcuen.est_verificacion  := 'V';
      r_gcuen.tas_personalizada := 'N';
      r_gcuen.tra_prohibida     := 'N';
      r_gcuen.en_juicio         := :new.en_juicio;
      r_gcuen.cod_ent_juicio    := :new.cod_ent_juicio;
      r_gcuen.fec_juicio        := :new.fec_juicio;
   end if;
   if inserting then
      --- Insertar tabla de Cuentas
      PAA_CTA.PRA_INS_GE_CUENTAS(r_gcuen);
   elsif updating then
      if :old.nro_cuenta <> :new.nro_cuenta then
         v_nro_cuenta := :old.nro_cuenta;
      end if;
      PAA_CTA.PRA_UPD_GE_CUENTAS(v_nro_cuenta, r_gcuen);
      --- GARANTIAS
       if :new.estado <> :old.estado then
       --sólo si cancela la op.vencida , se desvincula la garantía
       if :new.estado ='N' then --se cancela
         --verificar si posee garantias cash
         for reg in cash loop
           if reg.nro_garantia is not null then
             pap_gar.PR_PRO_GAR_CASH(reg.nro_garantia, :new.nro_cuenta, null, :new.fec_cam_estado, :new.cod_modulo,
                     :new.cod_modalidad, :new.cod_oficina, :new.cod_moneda, reg.mto_aplicado,'R');
                     --para q reverse, desaplicar el bloqueo x cash
           end if;
         end loop;
       end if;
       --si se reversa una cancelación se vuelve a vinculara a la garantía
       if :old.estado ='N' then
         --verificar si posee garantias cash
         for reg in cash loop
           if reg.nro_garantia is not null then
             pap_gar.PR_PRO_GAR_CASH(reg.nro_garantia, :new.nro_cuenta, null, :new.fec_cam_estado, :new.cod_modulo,
                     :new.cod_modalidad, :new.cod_oficina, :new.cod_moneda, reg.mto_aplicado);
                     --para q confirme, aplicar el bloqueo x cash
           end if;
         end loop;
       end if;
     end if;
    -------------------------------------------------
   elsif deleting then
     --Borrar..
      Delete
      from GE_CUENTAS
      where nro_cuenta = :old.nro_cuenta;
   end if;
END;
/


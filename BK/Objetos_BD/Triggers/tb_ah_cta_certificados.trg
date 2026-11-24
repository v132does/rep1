CREATE OR REPLACE TRIGGER IT."TB_AH_CTA_CERTIFICADOS"
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."AH_CTA_CERTIFICADOS"
 FOR EACH ROW

DECLARE
--- Variables del trigger
v_aut_tasa           varchar2(01);
v_cod_autorizacion   ge_autorizaciones.cod_autorizacion%type;
v_cod_usu_autorizador ge_autorizaciones.cod_usu_autorizador%type;
v_mon_local          ba_monedas.cod_moneda%type;
v_tip_moneda         ah_cer_grupos.tip_moneda%type;
v_cnt                number(10);
/* Obtener estado de la verificacion de la cuenta. */
FUNCTION LF_OBT_EST_VERIFICAC
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
   v_tas_minima    cr_piz_plazos.tas_minima%type;
   v_tas_maxima    cr_piz_plazos.tas_maxima%type;
   v_tas_interes   cr_piz_plazos.tas_interes%type;
   v_val_tasa      ge_tas_fechas.val_tasa%type;
   v_fec_vigencia  ge_tas_fechas.fec_vigencia%type;
   v_tip_valor     ge_tasas.tip_valor%type;
   v_tipo          ge_tasas.tipo%type;
/* Obtener estado de la verificacion de la cuenta. */
FUNCTION LF_OBT_EST_VERIFICAC
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
v_est_verificacion ge_cuentas.est_verificacion%type;
BEGIN
   select nvl(est_verificacion,'X')
   into v_est_verificacion
   from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
   return v_est_verificacion;
exception
   when others then
     return null;
END;
--
function fu_obt_max_fec_apertura return date is
   v_can_dias number(5) := 0;
   v_fec_actual date;
begin
   select max(can_dias)
     into v_can_dias
     from ge_ret_monedas
    where cod_moneda = :new.cod_moneda;
   v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
   v_fec_actual := pag_cal.FU_OBT_FEC_FIN_RET(v_fec_actual, :new.cod_oficina, v_can_dias);   Return v_fec_actual;
Exception
   When NO_DATA_FOUND Then
      v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
      Return v_fec_actual;
end fu_obt_max_fec_apertura;
-- Al Rechazar actualiza la Tasa personalizada.
procedure pl_act_tas_personalizada is
begin
  if :new.tas_personalizada = 'S' and :new.cod_modulo = 3 and :new.cod_modalidad = 33 then
    -- Si no esta autorizado y es una tasa personalizada elimina la tasa Personalizada.
    delete ge_tas_fechas where nro_cuenta = :new.nro_cuenta and cod_tasa = :old.cod_tasa;
    --
    select nvl(count(*),0)
      into v_cnt
      from ge_tas_fechas
     where nro_cuenta = :new.nro_cuenta
       and cod_tasa = :old.cod_tasa; -- Busca la Tasa Anterior.
    -- Si no tiene tasas personalizadas cambia el valor del campo.
    if v_cnt = 0 then
      :new.tas_personalizada := 'N';
    end if;
    --- Recuperar tasa
    pag_gen.pr_obt_val_tasa(:new.cod_modulo, :new.cod_modalidad, :new.cod_oficina,
    :new.nro_cuenta, :new.cod_moneda, :new.capital, :new.tas_personalizada, :new.cod_tasa, null,
    :new.fec_apertura, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
  end if;
  --- Recalculo de cupones
  pag_aut.pr_cal_int_cupones(:new.nro_cuenta, :new.fec_apertura, :new.fec_vencimiento, :new.capital, v_val_tasa);
end;
function fu_obt_ser_origen return varchar2 is
   v_ser_origen ah_titulos.ser_origen%type;
begin
   select t.ser_origen
   into   v_ser_origen
   from   ah_titulos t
   where  t.serie = :new.ser_titulo
   and    t.nro_titulo = :new.nro_titulo;
   return v_ser_origen;
exception
   when no_data_found then
        return null;
   when too_many_rows then
        raise_application_error(-20000,'Mas de un registro para el Titulo.');
   when others then
        raise_application_error(-20000,'Error:'||sqlerrm);
end;
-------------------------
--- PROCESO PRINCIPAL ---
-------------------------
BEGIN
   if inserting then
      --- Validar tasas de pizarras
      pag_cta.pr_obt_tas_pizarra(:new.cod_modulo, :new.cod_modalidad, :new.cod_moneda,
      trunc(:new.fec_vencimiento - :new.fec_apertura), :new.capital, v_tas_minima,
      v_tas_maxima, v_tas_interes, :new.tip_capitalizacion);
      --- Recuperar tasa
      pag_gen.pr_obt_val_tasa(:new.cod_modulo, :new.cod_modalidad, :new.cod_oficina,
      :new.nro_cuenta, :new.cod_moneda, :new.capital, :new.tas_personalizada, :new.cod_tasa, null,
      :new.fec_apertura, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
      v_aut_tasa := fug_obt_pardinamico('AUT_TASA', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, :new.cod_oficina);
      if v_aut_tasa = 'N' and (v_val_tasa < v_tas_minima or v_val_tasa > v_tas_maxima) then
         raise_application_error(-20004, 'Tasa fuera de rango de pizarra');
      end if;
      -- Hace la verificacion de la fecha de apertura.
      if :new.fec_apertura > fu_obt_max_fec_apertura Then
         raise_application_error(-20000, 'La fecha de Apertura no puede ser mayor al dia: '||to_char(fu_obt_max_fec_apertura, 'DD/MM/RRRR'));
      end if;
      -- Hasta aqui la verificacion de la fecha de apertura.
      -- Sacar los enters del Beneficiario
      :new.beneficiario := trim(replace(:new.beneficiario,chr(10),' '));
   end if;
   if updating and nvl(pae_cnf.G_PROGRAMA,'X') <> 'GPPROFIN'  then
     -- SDCAMTICDA-1 Se excluye la pantalla de cambio de titularidad de CDA
     if nvl(pae_cnf.G_PROGRAMA,'X') <> 'ALCTICDA' then --
      if :new.beneficiario <> :old.beneficiario then
         -- Sacar los enters del Beneficiario
         :new.beneficiario := trim(replace(:new.beneficiario,chr(10),' '));
      end if;
      if :old.cod_tasa <> :new.cod_tasa
      or (:old.cod_tasa = :new.cod_tasa and :old.aut_pendiente = 'S')
      or :old.capital <> :new.capital
      or :old.fec_apertura <> :new.fec_apertura
      or :old.cod_moneda   <> :new.cod_moneda
      or :old.tip_capitalizacion <> :new.tip_capitalizacion
      or :old.cod_oficina <> :new.cod_oficina
      or :old.tas_personalizada <> :new.tas_personalizada then
         --- Validar tasas de pizarras
         pag_cta.pr_obt_tas_pizarra(:new.cod_modulo, :new.cod_modalidad, :new.cod_moneda,
         trunc(:new.fec_vencimiento - :new.fec_apertura), :new.capital, v_tas_minima,
         v_tas_maxima, v_tas_interes, :new.tip_capitalizacion );
         --- Recuperar tasa
         pag_gen.pr_obt_val_tasa(:new.cod_modulo, :new.cod_modalidad, :new.cod_oficina,
         :new.nro_cuenta, :new.cod_moneda, :new.capital, :new.tas_personalizada, :new.cod_tasa, null,
         :new.fec_apertura, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
         v_aut_tasa := fug_obt_pardinamico('AUT_TASA', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, :new.cod_oficina);
         if v_aut_tasa = 'N' and (v_val_tasa < v_tas_minima or v_val_tasa > v_tas_maxima) then
            raise_application_error(-20005, pae_cnf.G_PROGRAMA||'Tasa fuera de rango de pizarra');
         elsif v_aut_tasa = 'S' and ((v_val_tasa < v_tas_minima or v_val_tasa > v_tas_maxima)) then
            if :old.aut_pendiente = 'S' then
               if :new.cod_tasa = :old.cod_tasa then
                  --- Verificar si posee autorizacion por cambio de tasa
                  if :new.aut_pendiente != 'N' then -- 21-08-2009
                    -- DYDMR-1780 - ITGF - Pago de Cupones - Tasa Fuera de Rango de Pizzarra SC 15120 - EGC19052015
                    if instr(fug_obt_pardinamico('VAL_NOM_PROGRAMA'), '*'||nvl(pae_cnf.G_PROGRAMA,'X')||'*') < 1 then
                      pag_aut.PR_OBT_AUT_PENDIENTE(:new.nro_cuenta, 100, :new.cod_modulo, :new.cod_modalidad, :new.cod_tasa, v_cod_autorizacion, v_cod_usu_autorizador);
                      if v_cod_autorizacion is null then
                         raise_application_error(-20001, pae_cnf.G_PROGRAMA||'Tasa fuera de rango de pizarra '||:new.nro_cuenta);
                      else
                         --- Actualizar utilizacion de la autorizacion
                         pag_aut.pr_uti_autorizacion(v_cod_autorizacion, user, pag_cal.FU_OBT_FEC_ACTUAL(3), to_char(sysdate,'HH24:MI:SS') );
                      end if;
                    end if;
                  else
                     -- Actualiza Tasa Personaliza - Recalcula Cupones.
                    pl_act_tas_personalizada;
                  end if;
                  if not pag_aut.fu_obt_ped_pendiente(:new.nro_cuenta) then
                     --- Si ya no posee autorizacion pendiente la cuenta
                     :new.aut_pendiente := 'N';
                  end if;
               elsif :new.cod_tasa <> :old.cod_tasa then
                  -- Actualiza Tasa Personaliza - Recalcula Cupones.
                  pl_act_tas_personalizada;
               else
                 -- DYDMR-1780 - ITGF - Pago de Cupones - Tasa Fuera de Rango de Pizzarra SC 15120 - EGC19052015 
                 if instr(fug_obt_pardinamico('VAL_NOM_PROGRAMA'), '*'||nvl(pae_cnf.G_PROGRAMA,'X')||'*') < 1 then
                   raise_application_error(-20002, pae_cnf.G_PROGRAMA||'Tasa fuera de rango de pizarra');
                 end if;
               end if;
            elsif :new.aut_pendiente <> 'S' then
               raise_application_error(-20003, pae_cnf.G_PROGRAMA||'Tasa fuera de rango de pizarra');
            end if;
         elsif v_aut_tasa = 'S' and :old.aut_pendiente = 'S' and:new.cod_tasa <> :old.cod_tasa then
             -- Actualiza Tasa Personaliza - Recalcula Cupones.
            pl_act_tas_personalizada;
         end if;
      end if;
    
      if (:new.estado <> :old.estado and :new.estado = 'N' and :new.nro_certificado is null)
      or (:new.nro_certificado is null and :old.est_certificado <> :new.est_certificado and :new.estado = 'N' )
      or (fug_obt_tip_implementacion()not in (1,7) and :new.nro_certificado is  null and :new.estado = 'N' and nvl(:new.sal_retenido,0)=0 and nvl(:new.sal_total,0) <> 0)
      or (fug_obt_tip_implementacion() in (1,7) and :new.estado = 'N' and :new.estado <> :old.estado)
      or (fug_obt_tip_implementacion() = 3 and :new.nro_certificado is not null and :new.estado = 'N' and :old.estado = 'A') then
         --- Por cambio de estado del certificado a normal generar automaticamente
         --- el numero si no tiene saldo retenido.
         If (fug_obt_tip_implementacion() in (1,7) and :old.estado <> :new.estado and :old.estado='A' and :new.estado = 'N')
         or (:new.estado='N' and :old.estado='N' and nvl(:old.sal_total,0)<nvl(:new.capital,0) and nvl(:new.sal_total,0)=nvl(:new.capital,0))
         or (fug_obt_tip_implementacion() = 3 and :new.estado = 'N')
         or (fug_obt_tip_implementacion()not in (1,7) and nvl(:new.sal_retenido,0)=0 and nvl(:new.sal_total,0) <> 0
                                       and nvl(:new.sal_total,0) = :new.capital
            -- y que ademas haya cambiado uno de los saldos ya sea el retenido por una liberacion o un deposito
            -- o se haya anulado el certificado, vuelve a nro_certificado nulo.
            and ((nvl(:new.sal_retenido,0) != nvl(:old.sal_retenido,0)) or
                 (nvl(:new.sal_total,0) != nvl(:old.sal_total,0)) or
                 (:new.nro_certificado is null and :new.est_certificado != :old.est_certificado and :new.est_certificado = 'E'))) then
            IF :new.nro_certificado is null Then
                v_mon_local := PAG_GEN.FU_OBT_MON_LOCAL ;
                If :new.cod_moneda = v_mon_locaL  then
                   v_tip_moneda := 'L';
                else
                   v_tip_moneda := 'E';
                End if;
                if :new.cod_modalidad != 34 then---no utiliza serie ni nro_certrificado en cda-d
                 :new.nro_certificado := FUA_OBT_SIG_NRO_CDA(:new.cod_modulo,
                                                             :new.cod_modalidad,
                                                             v_tip_moneda,
                                                             :new.cod_oficina,
                                                             :new.serie,
                                                             :new.usu_modificacion);
                end if;
            End If;
         End If;
      end if;
      if  lf_obt_est_verificac(:new.nro_cuenta) = 'V'
      and (nvl(:new.capital,0) <> nvl(:old.capital,0)
        or :new.fec_apertura <> :old.fec_apertura
        or :new.cod_moneda <> :old.cod_moneda
        or :new.tip_capitalizacion <> :old.tip_capitalizacion
        or :new.fec_vencimiento <> :old.fec_vencimiento
        or :new.tipo <> :old.tipo) then
        raise_application_error(-20000,
        'No puede modificar datos de cuentas verificadas');
      end if;
      -- Hace la verificacion de la fecha de apertura.
      if  :new.fec_apertura <> :old.fec_apertura
      and :new.fec_apertura > fu_obt_max_fec_apertura Then
         raise_application_error(-20000, 'La fecha de apertura no puede ser mayor a '||to_char(fu_obt_max_fec_apertura, 'DD/MM/RRRR'));
      end if;
      -- Hasta aqui la verificacion de la fecha de apertura.
   end if;
   if :new.cod_modalidad = 36 and nvl(fu_obt_ser_origen,'xxx') = 'SEN' then
      null; -- Para bonos subordinados via SEN no se hace el control
   elsIF (:new.fec_apertura < pag_cal.FU_OBT_FEC_ACTUAL(3) and inserting) or
      (:new.fec_apertura < pag_cal.FU_OBT_FEC_ACTUAL(3) and :new.fec_apertura <> :old.fec_apertura and updating) Then
      raise_application_error(-20000, 'La fecha de Apertura no puede ser menor a hoy');
   End if;
   End if;
   if deleting then
      if :old.est_certificado <> 'C' then
         raise_application_error(-20000,
         'No pueden eliminarse certificados emitidos');
      end if;
   end if;
END;
/

CREATE OR REPLACE TRIGGER IT.TB_CC_SOL_CHEQUERAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_SOL_CHEQUERAS
 FOR EACH ROW

DECLARE
v_existe            varchar2(1);
v_estado	          ge_cuentas.estado%type := 'X';
v_des_est           ge_est_cuentas.descripcion%type;
v_mto_lim_sobregiro NUMBER(18,2) := 0;
v_solicita          BOOLEAN := FALSE;
v_obs               VARCHAR2(1000);
v_atr_prestamo      VARCHAR2(1) := 'N';
v_atr_tarjeta       VARCHAR2(1) := 'N';
v_rec_cheque        VARCHAR2(1) := 'N';
v_mje               VARCHAR2(400);
v_can_sol           NUMBER;
v_can_ent           NUMBER;
v_can_pag           NUMBER;
v_can_onp           NUMBER;
v_can_anu           NUMBER;
v_can_cer           NUMBER;
v_can_tot           NUMBER;
v_por_uti           NUMBER;
v_par_porc          NUMBER(18,2) := 0;

BEGIN
   /*if updating then
      --- Solo pueden modificarse solicitudes en estado Solicitado
      if :old.estado <> 'S' then
         raise_application_error(-20000,'Solo pueden modifcarse solicitudes en estado Solicitado');
      end if;

   els*/
   if deleting then
      --- Solo pueden eliminarse solicitudes en estado Solicitado
      if :old.estado <> 'S' then
         raise_application_error(-20000,'Solo pueden eliminarse solicitudes en estado Solicitado');
      end if;
   elsif inserting then
      -- verifico si ya hay registros grabados en la misma situacion
      begin
      select 'S' into v_existe
        from cc_sol_chequeras
       where nro_cuenta = :new.nro_cuenta
         and cod_tip_chequera = :new.cod_tip_chequera
         and cantidad = :new.cantidad
         and can_hojas = :new.can_hojas
         and estado in ('S','V')
         and rownum = 1;
      exception
         when no_data_found then
            v_existe := 'N';
         when too_many_rows then
            v_existe := 'S';
         when others then
            v_existe := 'N';
      end;
      if v_existe = 'S' then
         raise_application_error(-20000,'Solicitud duplicada. Favor Verifique!');
      end if;
      if :new.fecha > pag_cal.FU_OBT_FEC_ACTUAL(4) or nvl(:new.fecha,sysdate-40) < pag_cal.FU_OBT_FEC_ACTUAL(4)-30 then
         raise_application_error(-20000,'Fecha de solicitud invalida. Verifique!');
      end if;
      -- nuevo control de tipos de chequeras
      declare
          v_can_cheques varchar2(100);
          v_can_minima  number(10) := 0;
          v_can_maxima  number(10) := 999999999;
          v_cod_moneda  varchar2(5);
      begin
         select ','||trim(a.can_cheques)||',', nvl(a.can_minima,1), nvl(a.can_maxima,999999999), a.cod_moneda
           into v_can_cheques, v_can_minima, v_can_maxima, v_cod_moneda
           from cc_tip_chequeras a
          where a.cod_tip_chequera = :new.cod_tip_chequera;
        if v_can_cheques = ',1,' then
           -- es formulario continuo
           if not (:new.can_hojas between v_can_minima and v_can_maxima) then
               raise_application_error(-20000,'Cantidad hojas invalida!!');
           end if;
        else
           -- los demas tipos
           if instr(v_can_cheques,','||:new.can_hojas||',') = 0 then
               raise_application_error(-20000,'Cantidad de hojas invalida!!');
           elsif not (:new.cantidad between v_can_minima and v_can_maxima) then
               raise_application_error(-20000,'Cantidad de Chequeras invalida!!');
           end if;
        end if;
      exception
        when no_data_found then
            raise_application_error(-20000,'Tipo de Chequera invalida!!!');
      end;
      
      -- 27-08-2013/RABP-PCC: VERIFICAMOS LA CUENTA PARA REALIZAR LA VERIFICACION AUTOMATICA --
      -- Verificamos si el cliente esta inhibido por algun causal --
      if FUG_VER_FIR_INHIBIDOS(:new.nro_cuenta) = 'S' then
        v_solicita := TRUE;
        v_obs      := 'Cliente Inhibido';
      end if;
      
      -- Verificamos el estado de la cuenta, si es distinto a Normal
      begin
        select a.estado, b.descripcion 
          into v_estado, v_des_est
          from ge_cuentas a, ge_est_cuentas b 
         where a.cod_modulo = b.cod_modulo 
           and a.cod_modalidad = b.cod_modalidad
           and a.estado = b.estado
           and a.nro_cuenta = :new.nro_cuenta;
      exception
        when others then
          v_estado  := 'Z';
          v_des_est := 'SIN ESTADO';
      end;
      if v_estado != 'N' then
        v_solicita := TRUE;
        v_mje := 'Estado Cuenta: '||v_des_est;
        if v_obs is null then
          v_obs := v_mje;
        else
          v_obs := v_obs||' / '||v_mje;
        end if;
      end if;
         
      -- Verificamos que la cuenta no este sobregirada --
      pag_cta.PR_OBT_CUENTA(:new.nro_cuenta);
      v_mto_lim_sobregiro := pag_cta.fu_obt_lin_sobregiro(:new.nro_cuenta);
      if (pag_cta.G_CTAS.SAL_DISPONIBLE + v_mto_lim_sobregiro) < 0 then
        v_solicita := TRUE;
        v_mje := 'Cuenta Sobregirada';
        if v_obs is null then
          v_obs := v_mje;
        else
          v_obs := v_obs||' / '||v_mje;
        end if;
      end if;
      
      -- Verificamos que la cuenta no tenga dias de atraso en el pago de prestamos --
      begin
        select distinct 'S'
          into v_atr_prestamo 
          from ge_cta_clientes c 
         where c.cod_persona = FUG_OBT_CLI_PRINCIPAL(:new.nro_cuenta)
	   and c.cod_modulo  = 6
           and exists (select 0 
                         from pr_cta_prestamos p 
                        where p.dia_atraso > 0 
                          and p.estado    <> 'N'
                          and p.nro_cuenta = c.nro_cuenta
                      );
      exception
        when others then
          v_atr_prestamo  := 'N';
      end;
      if v_atr_prestamo = 'S' then
        v_solicita := TRUE;
        v_mje := 'Atraso en Pago de Prestamo';
        if v_obs is null then
          v_obs := v_mje;
        else
          v_obs := v_obs||' / '||v_mje;
        end if;
      end if;

      -- Verificamos que la cuenta no tenga dias de atraso en el pago de Tarjetas --
      begin
        select distinct 'S'
          into v_atr_tarjeta 
          from ge_cta_clientes c 
         where c.cod_persona = FUG_OBT_CLI_PRINCIPAL(:new.nro_cuenta)
	   and c.cod_modulo  = 5
           and exists (select 0 
                         from ta_cta_tarjetas t 
                        where t.estado <> 'C' 
                          and t.dia_mora > 0
                          and t.nro_cuenta = c.nro_cuenta
                      );
      exception
        when others then
          v_atr_tarjeta  := 'N';
      end;
      if v_atr_tarjeta = 'S' then
        v_solicita := TRUE;
        v_mje := 'Atraso en Pago de Tarjetas';
        if v_obs is null then
          v_obs := v_mje;
        else
          v_obs := v_obs||' / '||v_mje;
        end if;
      end if;      
         
      -- Verificamos que no haya sido rechazado algun cheque del cliente por insuficiencia de fondos --
      -- en los ultimos 12 meses --
      begin
        select distinct 'S'
          into v_rec_cheque 
          from ge_cta_clientes c 
         where c.cod_persona = FUG_OBT_CLI_PRINCIPAL(:new.nro_cuenta)
	   and c.cod_modulo  = 4
           and exists (select 0 
                         from cc_che_devueltos t 
                        where t.cod_causa  = 106 --INSUFICIENCIA DE FONDOS
                          and t.fecha     >= ADD_MONTHS(pag_cal.FU_OBT_FEC_ACTUAL(1),-12)
                          and t.nro_cuenta = c.nro_cuenta
                      );
      exception
        when others then
          v_rec_cheque := 'N';
      end;                                
      if v_rec_cheque = 'S' then
        v_solicita := TRUE;
        v_mje := 'Cheque Rechazado por Insuficiencia de Fondos en los ultimos 12 meses';
        if v_obs is null then
          v_obs := v_mje;
        else
          v_obs := v_obs||' / '||v_mje;
        end if;
      end if;
      v_par_porc := nvl(fug_obt_pardinamico('POR_UTI_SOL_CHE'),100);
      -- Verificamos que en la cuenta, el porcentaje de utilización de chequeras anteriores NO sea inferior al 50% --
      pac_che.pr_obt_res_chequera(:new.nro_cuenta,v_can_sol,v_can_ent,v_can_pag,
                                  v_can_onp,v_can_anu,v_can_cer,v_can_tot,v_por_uti);
      if TRUNC(v_por_uti) < v_par_porc then
        v_solicita := TRUE;
        v_mje := 'Utilizacion de chequeras menor al '||v_par_porc||'%';
        if v_obs is null then
          v_obs := v_mje;
        else
          v_obs := v_obs||' / '||v_mje;
        end if;
      end if;                     
                    
      -- De acuerdo a la condicion insertamos como estado solicitado o verificado la solicitud --
      if v_solicita = FALSE then
        :new.estado := 'V';
        if :new.observacion is null then
          :new.observacion := 'Verificacion Automatica - Solicitud cargada por '||user;
        else
          :new.observacion := :new.observacion||' / '||'Verificacion Automatica - Solicitud cargada por '||user;
        end if;
      else
        :new.observacion := SUBSTR(v_obs,1,1000);
      end if;
   end if;
END;
/

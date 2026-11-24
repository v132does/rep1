CREATE OR REPLACE TRIGGER IT.TB_AH_CTA_VISTAS
  BEFORE DELETE OR INSERT OR UPDATE
  ON "IT"."AH_CTA_VISTAS"
  FOR EACH ROW
DECLARE
  v_sal_promedio number(18,2);
  v_tie_rol_asociado varchar2(1);
  v_cod_persona      ba_personas.cod_persona%type;
  v_afe_debito       varchar2(1) default 'N';
  v_cod_error        number;
  v_mensaje          varchar2(2000);
  v_obt_usuario 	varchar2(255);
  /* Obtener estado de la verificaci¿n de la cuenta. */
  FUNCTION LF_OBT_EST_VERIFICAC
   (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
   )
   RETURN VARCHAR2;
     v_tas_minima   cr_piz_plazos.tas_minima%type;
     v_tas_maxima   cr_piz_plazos.tas_maxima%type;
     v_tas_interes  cr_piz_plazos.tas_interes%type;
     v_val_tasa     ge_tas_fechas.val_tasa%type;
     v_fec_vigencia ge_tas_fechas.fec_vigencia%type;
     v_tip_valor    ge_tasas.tip_valor%type;
     v_tipo         ge_tasas.tipo%type;
     V_PRUEBA       VARCHAR2(2000);

  /* Obtener estado de la verificaci¿n de la cuenta. */
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
       raise_application_error(-20000,
       'Rec.Cta. '||sqlerrm);
  END LF_OBT_EST_VERIFICAC;

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
BEGIN
  if user <> fue_obt_des_refcodes('USU_CIERRE',user) or user = 'APICAJERO' then
   if inserting then
      If :new.reg_firma is null then
         raise_application_error(-20001, 'Regimen de firma no debe ser nulo');
      end if;
      -- Hace la verificaci¿n de la fecha de apertura.
      if :new.fec_apertura > fu_obt_max_fec_apertura Then
         raise_application_error(-20002, 'La fecha de Apertura no puede ser mayor al d¿a: '||to_char(fu_obt_max_fec_apertura, 'DD/MM/RRRR'));
      end if;
   end if;
   --S¿lo verifica el rango de pizarra si el usuario tiene asignado el rol que permite la modificacion de la misma
   --o si corresponde a una inserci¿n.
     v_tie_rol_asociado:= fug_tie_rol_asociado(user,fug_obt_pardinamico('ROL_PUE_MOD_TASA'));
     if inserting or (updating and :old.cod_tasa <> :new.cod_tasa and v_tie_rol_asociado = 'S') then
         --- Validar tasas de pizarras
         v_sal_promedio := fua_obt_sal_promedio(:new.cod_modulo,
                                                :new.cod_modalidad,
                                                :new.cod_oficina,
                                                :new.nro_cuenta,
                                                pag_cal.fu_obt_fec_pri_dia_mes_habil(3),
                                                last_day(pag_cal.fu_obt_fec_actual(3)));
         V_PRUEBA := ('MOD: '||:new.cod_modulo||' - MODA: '||:new.cod_modalidad||' - MON: '||
                      :new.cod_moneda||' - TIPCAPI: '||:new.tip_capitalizacion||' - TASMIN: '||
                      v_tas_minima||' - TASMAX: '||v_tas_maxima||' - TASINT: '||
                      v_tas_interes||' - CODSUBMO: '||:new.cod_sub_modalidad||' - FECVIG: '||
                      v_fec_vigencia||' - VALTAS: '||v_val_tasa||' - TIPTAS: '||v_tip_valor||' - ESTA: '||
                      :new.estado||' - MTOAP: '||:new.mto_apertura);
         pag_cta.pr_obt_tas_pizarra(:new.cod_modulo,
                                    :new.cod_modalidad,
                                    :new.cod_moneda,
                                    :new.tip_capitalizacion*30,
                                    CASE WHEN :new.estado in ('A','X') THEN nvl(:new.mto_apertura,0) ELSE v_sal_promedio END,
                                    v_tas_minima,
                                    v_tas_maxima,
                                    v_tas_interes,
                                    :new.tip_capitalizacion,
                                    :new.cod_sub_modalidad);
         -- Recuperar tasa
         pag_gen.pr_obt_val_tasa(:new.cod_modulo,
                                 :new.cod_modalidad,
                                 :new.cod_oficina,
                                 :new.nro_cuenta,
                                 :new.cod_moneda,
                                 CASE WHEN :new.estado in ('A','X') THEN nvl(:new.mto_apertura,0) ELSE v_sal_promedio END,
                                 :new.tas_personalizada,
                                 :new.cod_tasa,
                                 null,
                                 nvl(:new.fec_ult_capitalizacion, :new.fec_apertura),
                                 v_val_tasa,
                                 v_fec_vigencia,
                                 v_tip_valor,
                                 v_tipo,
                                 null,
                                 :new.cod_sub_modalidad);

         if v_val_tasa < v_tas_minima or v_val_tasa > v_tas_maxima then
            raise_application_error(-20003, 'Tasa fuera de rango de pizarra '||v_tas_minima||' - '||v_tas_maxima);
         end if;
      end if;
      if updating then
      if :old.estado = 'P' and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
         if :new.NRO_CUENTA          <> :old.NRO_CUENTA
         or :new.DIG_VERIFICADOR     <> :old.DIG_VERIFICADOR
         or :new.COD_MODULO          <> :old.COD_MODULO
         or :new.COD_MODALIDAD       <> :old.COD_MODALIDAD
         or :new.COD_OFICINA         <> :old.COD_OFICINA
         or :new.COD_MONEDA          <> :old.COD_MONEDA
         or :new.DENOMINACION        <> :old.DENOMINACION
         or :new.FRE_EXTRACTO        <> :old.FRE_EXTRACTO
         or :new.CAN_FIR_REQUERIDAS  <> :old.CAN_FIR_REQUERIDAS
         or :new.CAN_FIR_REGISTRADAS <> :old.CAN_FIR_REGISTRADAS
         or :new.FEC_APERTURA        <> :old.FEC_APERTURA
         or :new.TIP_CAPITALIZACION  <> :old.TIP_CAPITALIZACION
         or :new.TAS_PERSONALIZADA   <> :old.TAS_PERSONALIZADA
         or :new.COD_TASA            <> :old.COD_TASA
         or :new.RET_PERSONALIZADA   <> :old.RET_PERSONALIZADA
         or :new.SAL_MINIMO          <> :old.SAL_MINIMO
         or :new.COD_USU_PROMOTOR    <> :old.COD_USU_PROMOTOR
         or :new.TRA_PROHIBIDA       <> :old.TRA_PROHIBIDA
         or :new.CTA_COMBINADA       <> :old.CTA_COMBINADA
         or :new.AUT_PENDIENTE       <> :old.AUT_PENDIENTE
         or :new.COD_ENTE            <> :old.COD_ENTE
         or :new.MTO_APERTURA        <> :old.MTO_APERTURA
         or :new.COD_CANAL           <> :old.COD_CANAL
         or :new.COD_CAMPANA         <> :old.COD_CAMPANA
         or :new.REG_FIRMA           <> :old.REG_FIRMA
         then
           raise_application_error(-20004, 'Datos de Cuentas Pendientes de Cancelaci¿n no pueden modificarse.');
         end if;
      end if;
      If :new.reg_firma is null  then
         raise_application_error(-20005, 'Regimen de firma no debe ser nulo');
      end if;
      if  lf_obt_est_verificac(:new.nro_cuenta) = 'V' and :old.estado not in ('X','A')
      and (nvl(:new.mto_apertura,0) <> nvl(:old.mto_apertura,0)
        or :new.fec_apertura        <> :old.fec_apertura
        or :new.cod_moneda          <> :old.cod_moneda
        or :new.tip_capitalizacion  <> :old.tip_capitalizacion) then
        --- Si la cuenta se encuentra verificada no deben modificarse dichos campos
        raise_application_error(-20006,
        'No puede modificar datos de cuentas verificadas');
      end if;
      -- Hace la verificaci¿n de la fecha de apertura.
      if  :new.fec_apertura <> :old.fec_apertura
      and :new.fec_apertura > fu_obt_max_fec_apertura Then
         raise_application_error(-20007, 'La fecha de Apertura no puede ser mayor al d¿a: '||to_char(fu_obt_max_fec_apertura, 'DD/MM/RRRR'));
      end if;
      -- Hasta aqui la verificaci¿n de la fecha de apertura.

      --Control nuevo para impedir que se cancelen cuentas que estan como cuenta debito automatico para
      --tarjetas, prestamos, solicitudes, cajas de seguridad o certificados de deposito de ahorro
      if :new.estado <> :old.estado AND :new.estado in ('C', 'P') and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
         if fug_val_deb_relacionada(:new.nro_cuenta) = 'S' then
            raise_application_error(-20009, 'La cuenta esta relacionada a D¿bitos Autom¿ticos. Verifique');
         end if;
      end if;

      if (:new.cod_sub_modalidad = 26 or :old.cod_sub_modalidad = 26) and :new.cod_sub_modalidad <> :old.cod_sub_modalidad then
		     v_obt_usuario := fug_obt_pardinamico('USU_MIG_MODALIDAD');
         if v_obt_usuario is null or v_obt_usuario <> user then
             raise_application_error(-20010, 'No puede modificar la sub modalidad de una cuenta b¿sica. Verifique');
         end if;
      end if;
      -- Verifica si el Cliente o la Cta. tiene Inhibici¿n que no permita realizar d¿bito BSEVOCORE-147
	    /*if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then --se comenta el boque por error en el cierre 13-01-2020
         if :new.sal_total < :old.sal_total then
           v_cod_persona :=fug_obt_cli_principal(:new.nro_cuenta);
           v_afe_debito  := fug_obt_val_parcausal('AFE_DEB_CUENTA',v_cod_persona, :new.nro_cuenta);
           if nvl(v_afe_debito,'N') = 'S' then
             raise_application_error(-20000,'Inhibici¿n del Cliente Principal o Vinculados a la Cuenta no permite realizar D¿bito');
           end if;
         end if;
	    end if;*/
   end if;

   if inserting or updating then--si es inserci¿n o actualizaci¿n //gap cuenta b¿sica
     if fug_obt_paradicional(:new.nro_cuenta, 'LIM_CRE_TRANSACCIONES') is not null
                                 and user <> fue_obt_des_refcodes('USU_CIERRE',user) 
                                 and user <> 'MOVEMENTS'
                                 and user <> 'MVMTS' then
      if NVL(:new.sal_total, 0) > NVL(:old.sal_total, 0) and nvl(pas_spi.g_reversion,'N')='N' then --NVB-2806 
          --control solo si es credito
          it.prg_val_cta_baj_riesgo(:new.nro_cuenta,
                      :new.cod_moneda,
                  :new.cod_modulo,
                  :new.cod_modalidad,
                  NVL(:new.sal_total, 0) -
                  NVL(:old.sal_total, 0),
                  v_cod_error,
                  v_mensaje);

          if nvl(v_cod_error, 0) != 0 then
             pag_cta.G_COD_ERROR := 41;
             pag_cta.G_MSJ_ERROR := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ' ||
                     pag_cta.G_COD_ERROR || ' ..';
             raise_application_error(-20000, pag_cta.G_MSJ_ERROR);
          end if;

       end if;
     end if;
   end if;
   If (:new.fec_apertura < pag_cal.FU_OBT_FEC_ACTUAL(3) and inserting) or
      (:new.fec_apertura < pag_cal.FU_OBT_FEC_ACTUAL(3) and :new.fec_apertura <> :old.fec_apertura and updating) Then
      raise_application_error(-20008, 'La fecha de Apertura no puede ser menor a hoy');
   End if;
  end if;
END;
/

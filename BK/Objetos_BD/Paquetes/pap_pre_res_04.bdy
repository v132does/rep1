CREATE OR REPLACE PACKAGE BODY IT.PAP_PRE_RES_04 IS
 v_can_cuo_pagada number;
 v_redondeo_ml number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
 v_gen_boleteo varchar(1) := 'N';
/* Validar desembolso del prestamo */
PROCEDURE PR_VAL_DESEMBOLSO
 (P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
 ,RP_PSOLI IN PR_SOLICITUDES%ROWTYPE
 ,P_FECHA IN DATE
 ,P_ERROR IN OUT NUMBER
 ,P_MENSAJE IN OUT VARCHAR2
 )
 IS
--- Datos del prestamo original -- Desembolsos Parciales
   --- Variables para validacion del prestamo
   v_cantidad             number(05);
   v_mto_capital          pr_sol_cuotas.mto_capital%type;
   v_val_interes          pr_sol_cuotas.val_interes%type;
   v_val_int_adelantado   pr_sol_cuotas.val_int_adelantado%type;
   v_adeudar              varchar2(01);
   v_gar_tipo             pr_garantias.cod_garantia%type;
   v_gar_estado           pr_garantias.estado%type;
   --- Datos del calendario
   r_gcale                ge_calendarios%rowtype;
   --- Variables para validar tasas de pizarra
   v_tas_minima           cr_piz_plazos.tas_minima%type;
   v_tas_maxima           cr_piz_plazos.tas_maxima%type;
   v_tas_interes          cr_piz_plazos.tas_interes%type;
   v_tas_efectiva         cr_piz_plazos.tas_efectiva%type;
   v_val_tasa             pr_sol_tasas.val_tasa%type;
   v_per_ven_int          pr_sol_tasas.per_vencimiento%type;
   v_tae                  number;
   v_tan                  number;
   v_pro_dias             number;
   v_tip_interes          pr_solicitudes.tip_interes%type;
   v_es_des_doc           number := 0;
   v_fec_ini_propuesta    pr_solicitudes.fec_inicio%type;
   v_fec_pri_vto          number := 0;
   v_cta_bancaria         ge_cuentas.nro_cuenta%TYPE;
   v_ofi_cta_ban          ba_oficinas.cod_oficina%TYPE;
BEGIN
   p_error   := 0;
   p_mensaje := null;
/*RI: Se comenta todo lo que tenga nro_sol_original, se reutiliza el campo con
funcionalidad parecida
   if rp_psoli.nro_sol_original is not null then  --- DESEMBOLSOS PARCIALES
      BEGIN
         --- Es un prestamo adicional
         select p.nro_cuenta, s.cod_ori_fondo, s.cod_departamento,
                p.nro_cta_debito, p.tip_documento, p.cob_automatico
           into v_nro_cuenta, v_cod_ori_fondo, v_cod_departamento,
                v_nro_cta_debito, v_tip_documento, v_cob_automatico
           from pr_cta_prestamos p, pr_solicitudes s
          where s.nro_solicitud = p.nro_solicitud
            and s.nro_solicitud = rp_psoli.nro_sol_original;
         --- Verifico si existen cuotas pendientes de pago
         select count(*) into v_can_pendientes
           from pr_cuotas
          where nro_cuenta = v_nro_cuenta
            and nro_cuota > 0
            and estado <> 'N'
            and fec_vencimiento <= p_fecha;
          if v_can_pendientes > 0 then
             p_error   := 1;
             p_mensaje := 'El prestamo tiene cuotas pendientes. Debe pagar antes dichas cuotas';
             return;
          end if;
         --- Veo si las cuotas coinciden
         select count(*) into v_can_nuevas
           from pr_sol_cuotas
          where nro_solicitud = p_nro_solicitud
            and nro_cuota > 0;
         select count(*) into v_can_viejas
           from pr_cuotas
          where nro_cuenta = v_nro_cuenta
            and nro_cuota > 0
            and estado <> 'N';
         if v_can_nuevas <> v_can_viejas then
            p_error   := 2;
            p_mensaje := 'Las nuevas cuotas no coinciden con las restantes del Prestamo. Verificar';
            return;
         end if;
      EXCEPTION
         when no_data_found then
            p_error   := 3;
            p_mensaje := 'No existe Nro. de Prestamo Original de la Prop. '||rp_psoli.nro_sol_original;
            return;
      END;
   end if;*/
   --- VALIDAR SOLICITUD
   --- Validar estados de la solicitud
  /* if rp_psoli.estado = 'R' then
      p_error   := 4;
      p_mensaje := 'Propuesta se encuentra rechazada.';
      return;
   elsif rp_psoli.estado = 'A' then
      p_error   := 5;
      p_mensaje := 'Propuesta ya se ha desembolsado. Verifique..';
      return;
   elsif rp_psoli.estado = 'N' then
      p_error   := 6;
      p_mensaje := 'Prestamo ya ha sido cancelado. Verifique...';
      return;
   end if;*/
   --- Verifico que no tenga interes negativo o int. adelantado negativo */
   select count(*) into v_cantidad
     from pr_sol_cuotas
    where nro_solicitud = p_nro_solicitud
      and nro_cuota > 0
      and nvl(val_interes,0) < 0;
   if v_cantidad > 0 then
      p_error   := 7;
      p_mensaje := 'Propuesta con Int.Vencido Negativo Verifique!!';
      return;
   end if;
   select count(*) into v_cantidad
     from pr_sol_cuotas
    where nro_solicitud = p_nro_solicitud
      and nro_cuota > 0
      and nvl(val_int_adelantado,0) < 0;
   if v_cantidad > 0 then
      p_error   := 7;
      p_mensaje := 'Propuesta con Int.Adelantado Negativo Verifique!!';
      return;
   end if;
   --- sumo los datos de las cuotas para verificacion de grabacion
   select sum(nvl(mto_capital,0)), sum(nvl(val_interes,0)), sum(nvl(val_int_adelantado,0))
     into v_mto_capital, v_val_interes, v_val_int_adelantado
     from pr_sol_cuotas
    where nro_solicitud = p_nro_solicitud
      and nro_cuota > 0;
   if    nvl(v_mto_capital,0) <> nvl(rp_psoli.tot_prestamo,0) then
      p_error   := 8;
      p_mensaje := 'Capitales mal grabados. Verifique propuesta';
      return;
   elsif nvl(v_val_interes,0)+nvl(v_val_int_adelantado,0)
      <> nvl(rp_psoli.mto_interes,0) then
      p_error   := 9;
      p_mensaje := 'Intereses mal grabados. Verifique propuesta';
      return;
   elsif nvl(v_val_interes,0)+nvl(v_val_int_adelantado,0) = 0
   and (((fug_obt_tip_implementacion not in (3,1)) and (fug_obt_tip_implementacion = 9 and rp_psoli.cod_modalidad <> 660))  or
       (fug_obt_tip_implementacion = 1 and  rp_psoli.cod_modalidad not in (627,631))  )
   and nvl(fug_obt_pardinamico('MAD_TAS_CERO',rp_psoli.cod_modulo,rp_psoli.cod_modalidad, rp_psoli.cod_moneda, null, rp_psoli.cod_sub_modalidad),'N') = 'N' then
      p_error   := 10;
      p_mensaje := 'Interes igual a 0(cero). Verifique propuesta '||p_nro_solicitud;
      return;
   end if;
   --- Validar certificado de no adeudar impuestos
   /*v_adeudar := fu_obt_cer_impuesto(rp_psoli.tot_prestamo);
   if v_adeudar = 'S' then
      p_error   := 11;
      p_mensaje := 'El cliente adeuda impuestos';
      return;
   end if;*/
   if rp_psoli.tip_interes = 'A' then --- Interes adelantado
      if v_val_interes > 0 then
         p_error   := 11;
         p_mensaje := 'Esta modalidad no puede tener Int. Vencido';
         return;
      end if;
   end if;
 /*  --- Verifico la garantia
   BEGIN
      select gar.cod_garantia, gar.estado
        into v_gar_tipo, v_gar_estado
        from pr_garantias gar, pr_sol_garantias sol
       where sol.nro_solicitud = p_nro_solicitud
         and sol.nro_garantia  = gar.nro_garantia
         and sol.cod_garantia  = gar.cod_garantia;
      if v_gar_tipo in (6,10) and v_gar_estado <> 'C' then
         p_error   := 12;
         p_mensaje := 'La Garantia Warrants de la propuesta debe ser confirmada para la aceptacion';
         return;
      end if;
   exception
      when no_data_found then null;
      when too_many_rows then null;
      when others then
         if sqlcode <= -20000 then
            raise;
         else
            raise_application_error(-20000,
            'Al leer garantia '||sqlerrm);
         end if;
   END;*/
  /* if fug_obt_pardinamico('PRE_PERSONAL', rp_psoli.cod_modulo, rp_psoli.cod_modalidad) = 'N'
   and p_fecha - rp_psoli.fec_inicio < 0 and nvl(fug_obt_pardinamico('TIP_DES_DOCUMENTOS',rp_psoli.cod_modulo, rp_psoli.cod_modalidad),'X') != 'C' then
      p_error   := 13;
      p_mensaje := 'Fecha Inicio no corresponde a la Fecha del Sistema';
      return;
   end if;*/
   --- La fecha de inicio de la operacion debe estar dentro del mes actual y ser <= a la del Sistema
   pag_cal.pr_obt_dat_calendar(6);
   --VC 04-10-2010 no hace falta controlar que esté dentro del mes, sólo por días podría controlarse
  /* if rp_psoli.fec_inicio < pag_cal.g_pri_dia_mes
    and rp_psoli.cod_modalidad not in (660) --then ---Para el caso de Cheques Devueltos no se debe cumplir esta validacion, porque puede existir un cheque que vence a fin de mes, y recien se devuelva los 1ros dias del sgte. mes
    and NVL(fug_obt_pardinamico('PRE_VISTA',6,rp_psoli.cod_modalidad,NULL,NULL),'N') = 'N' then --RI: 25/05/2010 : Prestamos a la vista se realizan a fecha valor que puede ser menor a la fecha actual
      p_error   := 14;
      p_mensaje := 'Fecha de Inicio debe estar dentro del mes actual';
      return;
   end if;*/
   -- si no es préstamos vistas se controla 30 días a partir del inicio de la propuesta
 /*  if NVL(fug_obt_pardinamico('PRE_VISTA',6,rp_psoli.cod_modalidad,NULL,NULL),'N') = 'N' and nvl(fug_obt_pardinamico('TIP_DES_DOCUMENTOS',rp_psoli.cod_modulo, rp_psoli.cod_modalidad),'X') != 'C' then
     if (p_fecha - rp_psoli.fec_inicio)  > 30 then
        p_error   := 14;
        p_mensaje := 'Fecha de Inicio no puede ser menor a 30 días de la fecha de Desembolso';
        return;
     end if;
   end if;
   --préstamos vistas sólo hasta 60 días atrás
   if NVL(fug_obt_pardinamico('PRE_VISTA',6,rp_psoli.cod_modalidad,NULL,NULL),'N') = 'S' then
     if (p_fecha - rp_psoli.fec_inicio) > 60 then
        p_error   := 23;
        p_mensaje := 'Fecha de Inicio no puede ser menor a 60 días desde la fecha del Sistema';
        return;
     end if;
   end if;*/
   --fecha de inicio no puede ser mayor a fecha actual
   if rp_psoli.fec_inicio > p_fecha then
      p_error   := 15;
      p_mensaje := 'Fecha de Inicio debe ser menor o igual a la fecha del Sistema';
      return;
   end if;
   --- Validar tasas de pizarra
   PAP_PRE_RES_04.pr_obt_tas_pizarra(rp_psoli.cod_modulo, rp_psoli.cod_modalidad, rp_psoli.cod_moneda,
      trunc(rp_psoli.fec_vencimiento - rp_psoli.fec_inicio), rp_psoli.monto, null,
      v_tas_minima, v_tas_maxima, v_tas_interes, v_tas_efectiva, rp_psoli.cod_sub_modalidad);
   --- Recuperar tasa
   v_val_tasa := PAP_PRE_RES_04.fu_obt_tas_sol(rp_psoli.nro_solicitud, v_per_ven_int);
   if v_val_tasa < v_tas_minima or v_val_tasa > v_tas_maxima then
      -- Debe verificar si es que no tiene autorizacion...
      If rp_psoli.cod_autorizacion is null then
         -- Quiere decir que no fue autorizado la tasa menor a la pizarra.
         p_error   := 16;
         p_mensaje := 'Tasa fuera de rango de pizarra';
         return;
      End If;
   end if;
   --- Verifica contra la tasa tae
   PAS_BCP.PR_OBT_TAS_PRESTAMO(rp_psoli.NRO_SOLICITUD,NULL,V_TAE,V_TAN);
   --Inicio Agregado para ajuste de Incidencia DYDMR-2431--
   BEGIN
     select ROUND(AVG(dia_interes),0)
       into v_pro_dias
     from pr_sol_cuotas
     where nro_solicitud = rp_psoli.NRO_SOLICITUD
     and nro_cuota > 0;
   EXCEPTION
     WHEN OTHERS THEN
        p_error   := 24;
        p_mensaje := 'Error al obtener promedio de dias de capital de la propuesta.';
        return;
   END;
   BEGIN
     select tip_interes
       into v_tip_interes
     from pr_solicitudes
     where nro_solicitud = rp_psoli.NRO_SOLICITUD;
   EXCEPTION
     WHEN OTHERS THEN
        p_error   := 25;
        p_mensaje := 'Error al obtener tipo interes de la propuesta.';
        return;
   END;
   v_tae := fus_obt_tae_tasa(v_tan,v_pro_dias,v_tip_interes);
   --Fin Agregado para ajuste de Incidencia DYDMR-2431--
   IF nvl(v_tas_efectiva,0) <> 0 then
      IF v_tae > nvl(v_tas_efectiva,0)  then
         p_error   := 17;
         p_mensaje := 'Propuesta de credito fuera de Rango del TAE. Verifique la Pizarra';
         return;
      END IF;
   END IF;
   --DYDMR-6823 06/06/2017 Sólo se valida que estee verificado sino son canales digitales
  /* if user = 'HBANK' OR USER LIKE '%ATM%' then
           null;
   else
      NULL;*/
      --PARA RESOLUCION 4 NO SE VALIDARA
         /* -- Se debe verificar que la persona este verificada...
          If fug_obt_pardinamico('VER_PERSONA', rp_psoli.cod_modulo, rp_psoli.cod_modalidad, rp_psoli.cod_moneda, rp_psoli.cod_oficina) = 'S' then
           If fug_ver_verificacion(rp_psoli.cod_persona) = 'N' then
               -- La persona no esta verificada...
             p_error   := 18;
             p_mensaje := 'El deudor no esta verificado. Verifique.'||rp_psoli.cod_persona;
             return;
           End if;
           Declare
              -- Debe verificar tambien si es que codeudor esta verificado...
          Cursor co is select nro_garantia cod_persona
                         from pr_sol_garantias
                        where nro_solicitud = rp_psoli.nro_solicitud
                          and cod_garantia = 2;
           Begin
              For ro in co Loop
               If fug_ver_verificacion(ro.cod_persona) = 'N' then
                   -- La persona no esta verificada...
                  p_error   := 19;
                  p_mensaje := 'El codeudor: '||ro.cod_persona||' no esta verificado. Verifique.';
                  return;
               End if;
              End Loop;
           End;
              End if;*/
  /*End if;*/

 /* p_mensaje := fup_ver_cal_interes(rp_psoli.nro_solicitud);
  If p_mensaje is not null then
     p_error := 20;
    return;
  End if;*/
  --
  --si la garantía es obligatoria
  --No se valida en proceso masivo res 04 BCP
  /*if fug_obt_pardinamico('GAR_OBLIGATORIA',rp_psoli.cod_modulo,rp_psoli.cod_modalidad,rp_psoli.cod_moneda,rp_psoli.cod_oficina) = 'S' then
    select count(*) into v_cantidad
      from pr_sol_garantias
     where nro_solicitud = rp_psoli.nro_solicitud;
    If v_cantidad = 0 then
       p_error := 21;
       p_mensaje := 'La Solicitud no posee Garantias. Verifique.';
    End if;
  end if;*/
  --
 /* select count(*) into v_cantidad
    from ge_transacciones_det, pr_sol_cargos
   where ge_transacciones_det.cod_mod_hijo = rp_psoli.cod_modulo
     and ge_transacciones_det.cod_mad_hijo = rp_psoli.cod_modalidad
     and ge_transacciones_det.cod_tra_hijo = pr_sol_cargos.cod_transaccion
     and ge_transacciones_det.cod_transaccion = 358
     and nvl(ge_transacciones_det.obligatorio, 'N') != 'S'
     --
     and nro_solicitud = rp_psoli.nro_solicitud
     and nvl(monto,0) = 0
     and nvl(mto_mon_prestamo, 0) = 0;
  If v_cantidad > 0 then
     p_error := 22;
     p_mensaje := 'La Solicitud posee Cargos con monto 0 (cero). Verifique.';
  End if;*/
  --
  -- DYDMR-2822 - Controles Adicionales para Descuento de Documentos
 /* select count(1)
    into v_es_des_doc
  from ge_modalidades a, pr_solicitudes b
    where a.cod_modulo = b.cod_modulo
      and a.cod_modalidad = b.cod_modalidad
      and b.nro_solicitud = P_NRO_SOLICITUD
      and FUP_OBT_TIP_DESCUENTO(a.cod_modalidad) in ('F','C','D');*/

/*  if v_es_des_doc > 0 then
    -- SC 22546: control fecha de inicio de propuesta para evitar prestamos fuera de rango TAE
    select fec_inicio
           into v_fec_ini_propuesta
    from pr_solicitudes
         where nro_solicitud = P_NRO_SOLICITUD;

    if trunc(v_fec_ini_propuesta) <> trunc(P_FECHA) then
      p_error := 23;
      p_mensaje := 'Fecha de inicio de la propuesta debe ser igual a hoy, modifique la fecha de inicio.';
    End if;

    -- SC 23800: control de fecha de vencimiento de documentos, no deben vencer hoy o estar ya vencidos
    select count(1)
           into v_fec_pri_vto
    from pr_sol_cuotas b
     where b.fec_vto_habil <= P_FECHA
      and b.nro_solicitud = P_NRO_SOLICITUD
      and b.nro_cuota <> 0;

    If v_fec_pri_vto > 0 Then
       p_error   := 24;
       p_mensaje := 'Existen documentos que ya vencidos o que vencen en la fecha. Verifique la propuesta.';
    End If;
  end if;*/
  --
   -- VERIFICO QUE LA PROPUESTA HAYA SIDO APLICADA EN SU TOTALIDAD
   /* IF GRUPOE IS NOT NULL AND GRUPOE <> 0  THEN
            SELECT COUNT(LC_VLMONTO) INTO W_VLMONTO
            FROM FPLINEA
            WHERE (LC_CDGRECO = GRUPOE or
                   lc_cdclien = :abmc.scr_cdclien )
            and lc_cdmodul  <> 7  -- Cambios
            AND LC_FCVALID >= :CABECERA.WFECHA;
            IF W_VLMONTO >  0 THEN
               SELECT SUM(PC_VLMONTO) INTO W_VLMONTO
                FROM FPAPLIC
                WHERE PC_NRPROPU = :ABMC.SCR_NRPROPU;
                IF NVL(W_VLMONTO,0) <> NVL(VLMONTP,0) THEN
                   MESSAGE('ERROR. Propuesta  no ha sido aplicada en su
                         totalidad. No se puede aceptar.');
                   RAISE FORM_TRIGGER_FAILURE;
                END IF;
            END IF;
      END IF; */
      /* IF :ABMC.SCR_MONEDA_LOCAL = :ABMC.SCR_CDMONED THEN
         :ABMC.SCR_MODACAMB := 72;-- VENTA DE DIVISAS
      ELSE
         :ABMC.SCR_MODACAMB := 71; -- COMPRA DE DIVISAS
      END IF;*/
   /*IF rp_psoli.cod_modalidad = 699 THEN
      v_cta_bancaria := fug_obt_pardinamico('CTA_LIB_ANT_CHEQUES', 4, 47, rp_psoli.cod_moneda,
                                            rp_psoli.cod_oficina);
      IF v_cta_bancaria IS NULL THEN
         p_error   := 30;
         p_mensaje := 'Cuenta Operativa de Desembolso no definida.';
      ELSE
         BEGIN
            SELECT cod_oficina
              INTO v_ofi_cta_ban
              FROM ge_cuentas
             WHERE nro_cuenta = v_cta_bancaria;
         EXCEPTION
            WHEN no_data_found THEN
               p_error   := 31;
               p_mensaje := 'Cuenta Operativa de Desembolso no corresponde.';
            WHEN OTHERS THEN
               p_error   := 32;
               p_mensaje := 'Al Obt.Cta.Operativa:' || SQLERRM;
         END;
         IF v_ofi_cta_ban <> rp_psoli.cod_oficina THEN
            p_error   := 33;
            p_mensaje := 'Cuenta Operativa de Desembolso no pertenece a oficina '
                      || rp_psoli.cod_oficina;
         END IF;
      END IF;
   END IF;*/
END;
/* Verifica si adeuda impuestos. */
FUNCTION FU_OBT_CER_IMPUESTO
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 )
 RETURN VARCHAR2
 IS
BEGIN
   RETURN 'N';
END;
/* Insertar datos de cuentas de prestamos */
PROCEDURE PR_INS_CTA_PRESTAMO
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,RP_PCPRE IN PR_CTA_PRESTAMOS%ROWTYPE
 ,P_NRO_CUENTA IN OUT PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 IS
  v_cta_bancaria ge_cuentas.nro_cuenta%TYPE;
  v_ofi_cta_ban  ba_oficinas.cod_oficina%TYPE;
BEGIN
   if rp_pcpre.cod_modalidad = 699 then
      v_cta_bancaria := fug_obt_pardinamico('CTA_LIB_ANT_CHEQUES', 4, 47, rp_pcpre.cod_moneda,
                                            rp_pcpre.cod_oficina);
      IF v_cta_bancaria IS NULL THEN
         raise_application_error(-20000,'Cuenta Operativa de Desembolso no definida.');
      ELSE
         BEGIN
            SELECT cod_oficina
              INTO v_ofi_cta_ban
              FROM ge_cuentas
             WHERE nro_cuenta = v_cta_bancaria;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,'Cuenta Operativa de Desembolso no corresponde.');
            WHEN OTHERS THEN
               raise_application_error(-20000,'Al Obt.Cta.Operativa:' || SQLERRM);
         END;
         IF v_ofi_cta_ban <> rp_pcpre.cod_oficina THEN
            raise_application_error(-20000,'Cuenta Operativa de Desembolso no pertenece a oficina '
                      || rp_pcpre.cod_oficina);
         END IF;
         IF v_cta_bancaria <> rp_pcpre.nro_cta_debito THEN
            raise_application_error(-20000,'Cuenta no Corresponde a Operativa de Desembolso '
                      || rp_pcpre.nro_cta_debito);
         END IF;
      END IF;
   end if;
   p_nro_cuenta := fug_obt_sig_nro_cuenta(rp_pcpre.cod_modulo, rp_pcpre.cod_modalidad,
                   rp_pcpre.cod_oficina, rp_pcpre.cod_moneda, p_cod_persona);
   insert into pr_cta_prestamos
      (nro_cuenta, dig_verificador, cod_modulo, cod_modalidad,
       cod_oficina, nro_cta_debito, nro_cta_renovada, fec_cancelacion,
       estado, mto_capital, sal_capital, sal_interes, val_int_devengar,
       nro_solicitud, est_batch, sal_cap_batch, sal_int_batch,
       nro_documento, est_anterior, dev_acumulado, tip_documento,
       nro_sol_renovada, cob_automatico, sal_int_adelantado,
       sal_int_ade_batch, fec_ult_devengado, dev_no_cobrado,
       nro_linea, cod_moneda, monto, fec_inicio, fec_vencimiento,
       tipo, val_tasa, can_cuotas, can_cuo_pagadas,
       dia_atraso, max_atraso, pro_atraso, exo_impuestos,
       cod_causa, cod_canal, cod_campana, cod_sec_credito,
       descripcion, tip_destino, tip_interes, mto_lin_aplicado,
       cod_ori_fondo, tip_renovacion, per_vto_capital, per_vto_interes,
       dev_suspenso, cat_renovaciones, cod_banca, por_ori_fondo, fec_ren_tas_orig, cod_rub_economico, cod_sub_modalidad)
   values
      (p_nro_cuenta, rp_pcpre.dig_verificador, rp_pcpre.cod_modulo, rp_pcpre.cod_modalidad,
       rp_pcpre.cod_oficina, rp_pcpre.nro_cta_debito, rp_pcpre.nro_cta_renovada, rp_pcpre.fec_cancelacion,
       rp_pcpre.estado, rp_pcpre.mto_capital, rp_pcpre.sal_capital, rp_pcpre.sal_interes, rp_pcpre.val_int_devengar,
       rp_pcpre.nro_solicitud, rp_pcpre.est_batch, rp_pcpre.sal_cap_batch, rp_pcpre.sal_int_batch,
       rp_pcpre.nro_documento, rp_pcpre.est_anterior, rp_pcpre.dev_acumulado, rp_pcpre.tip_documento,
       rp_pcpre.nro_sol_renovada, rp_pcpre.cob_automatico, rp_pcpre.sal_int_adelantado,
       rp_pcpre.sal_int_ade_batch, rp_pcpre.fec_ult_devengado, rp_pcpre.dev_no_cobrado,
       rp_pcpre.nro_linea, rp_pcpre.cod_moneda, rp_pcpre.monto, rp_pcpre.fec_inicio, rp_pcpre.fec_vencimiento,
       rp_pcpre.tipo, rp_pcpre.val_tasa, rp_pcpre.can_cuotas, rp_pcpre.can_cuo_pagadas,
       rp_pcpre.dia_atraso, rp_pcpre.max_atraso, rp_pcpre.pro_atraso, rp_pcpre.exo_impuestos,
       rp_pcpre.cod_causa, rp_pcpre.cod_canal, rp_pcpre.cod_campana, rp_pcpre.cod_sec_credito,
       rp_pcpre.descripcion, rp_pcpre.tip_destino, rp_pcpre.tip_interes, rp_pcpre.mto_lin_aplicado,
       rp_pcpre.cod_ori_fondo, rp_pcpre.tip_renovacion, rp_pcpre.per_vto_capital, rp_pcpre.per_vto_interes,
       rp_pcpre.dev_suspenso, rp_pcpre.cat_renovaciones, rp_pcpre.cod_banca, rp_pcpre.por_ori_fondo, rp_pcpre.fec_ren_tas_orig,rp_pcpre.cod_rub_economico, rp_pcpre.cod_sub_modalidad);
END;
/* Desembolso de Prestamos. */ --AJUSTES Issue 1121
PROCEDURE PR_DES_PRESTAMOS
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_MTO_DESEMBOLSO IN PR_SOLICITUDES.TOT_PRESTAMO%TYPE
 ,P_FECHA IN DATE
 ,P_TIP_DOCUMENTO IN PR_CTA_PRESTAMOS.TIP_DOCUMENTO%TYPE
 ,P_NRO_DOC_DESDE IN PR_CTA_PRESTAMOS.NRO_DOCUMENTO%TYPE
 ,P_NRO_DOC_HASTA IN PR_CTA_PRESTAMOS.NRO_DOCUMENTO%TYPE
 ,P_COD_OFI_ORIGEN IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_COD_ORI_FONDO IN PR_SOLICITUDES.COD_ORI_FONDO%TYPE
 ,P_HORA IN VARCHAR2
 ,P_NRO_SECUENCIA IN OUT VARCHAR2
 ,P_NRO_CUENTA IN OUT VARCHAR2
 )
 IS
  v_fec_actual date :=PAG_CAL.FU_OBT_FEC_ACTUAL(6);
  v_fec_anterior date :=PAG_CAL.FU_OBT_FEC_ANT_HAB(v_fec_actual,p_cod_ofi_origen);
  v_mto_ori_fondo number;
  v_mto_cap_original number;
  v_nro_sec_cargo number(4);
  v_nro_sec_interes number(4);
  v_tip_cap_calculo varchar2(1);
  v_por_cat_mej_original number(2);
  v_fec_ini_cobro date;
  v_dia_atraso ge_par_dinamicos.val_parametro%type;
  v_tip_ref_holding varchar2(1);
  v_mto_deuda pr_cta_prestamos.monto%type;
  v_red_mon_local number(2);
  v_usu_insercion ge_exoneraciones_tmp.usu_insercion%type;
  v_mto_a_cobrar ge_exoneraciones_tmp.mto_a_cobrar%type;
  v_exi_cargo varchar2(1) := 'N';
  -- PCCDEEVO-214 06/2017
  v_est_modulo ba_modulos.estado%TYPE := pae_cnf.fu_obt_est_modulo(6);
  v_es_nocturno varchar2(1);
  v_hor_actual ge_movimientos.hora%type := to_char(sysdate, 'hh24:mi:ss');
  v_acu_mto_desemb varchar2(1) := 'S'; -- Acumular monto de Desembolso
  v_mto_boleteo ge_movimientos.monto%type := 0;

/* Genera movimientos del seguro */
PROCEDURE LP_GEN_MOV_SEGURO;
/* Obtener pago unico de la solicitud. */
FUNCTION LF_OBT_PAG_UNICO
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 )
 RETURN VARCHAR2;
/* Actualiza cuotas restantes */
PROCEDURE LP_ACT_CUO_RESTANTES
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 );
--- Variables de tipo de registro
   r_psoli               pr_solicitudes%rowtype;
   r_pcpre               pr_cta_prestamos%rowtype;
   r_gmovi               ge_movimientos%rowtype;
   --- Variables para movimientos
   v_nro_secuencia       ge_movimientos.nro_secuencia%type;
   v_hora                ge_movimientos.hora%type;
   v_cod_usuario         ge_movimientos.cod_usuario%type;
   ---
   v_int_adelantado      pr_sol_cuotas.val_int_adelantado%type;
   v_cargos              pr_sol_cargos.monto%type;
   v_existe              varchar2(01);
   v_error               number(05);
   v_mensaje             varchar2(1000);
   v_cotizacion          ge_cotizaciones.val_conversion%type;
   v_cot_cambio          ge_cotizaciones.val_conversion%type;
   v_dia_diferencia      number(05);
   v_renovacion          varchar2(01);
   v_capital             pr_solicitudes.tot_prestamo%type;
   v_nro_cuenta          pr_cta_prestamos.nro_cuenta%type;
   v_fec_vencimiento     pr_solicitudes.fec_vencimiento%type;
   v_can_cuotas          pr_cta_prestamos.can_cuotas%type;
   v_val_tasa            pr_cta_prestamos.val_tasa%type;
   v_cod_mon_local       ba_monedas.cod_moneda%type;
   --- Variables para renovaciones
   v_tot_sal_capital     pr_cuotas.sal_capital%type;
   v_tot_sal_interes     pr_cuotas.sal_interes%type;
   v_tot_sal_int_ade     pr_cuotas.sal_interes%type;
   v_tot_mora            pr_cuotas.val_recargo%type;
   v_tot_mor_interes     pr_cuotas.val_recargo%type;
   v_tot_mor_int_ade     pr_cuotas.val_recargo%type;
   v_tot_punitorio       pr_cuotas.val_recargo%type;
   v_tot_impuesto        pr_cuotas.val_recargo%type;
   v_tot_cargo           pr_cuotas.val_recargo%type;
   v_tot_car_iva         pr_cuotas.val_recargo%type;
   v_tot_int_descontado  pr_cuotas.sal_interes%type;
   v_tot_deuda           pr_cta_prestamos.monto%type;
   v_mto_renovar         pr_cta_prestamos.mto_capital%type;
   v_cat_renovaciones    pr_cta_prestamos.cat_renovaciones%type;
   v_cat_operacion       pr_cta_prestamos.cat_renovaciones%type;
   v_tot_pond            pr_cta_prestamos.sal_capital%type;
   --- Variables para desglose de cargos
   v_cod_tra_padre       ge_transacciones.cod_transaccion%type;
   v_cod_mod_padre       ge_transacciones.cod_modulo%type;
   v_cod_mad_padre       ge_transacciones.cod_modalidad%type;
   v_mto_fin_cargo       pr_cuotas.val_recargo%type;
   v_car_desglose        pr_cuotas.val_recargo%type;
   v_fec_vigencia        ge_tas_fechas.fec_vigencia%type;
   v_tip_valor           ge_tasas.tip_valor%type;
   v_tipo                ge_tasas.tipo%type;
   v_porcen              number;
   v_dia_mora            pr_cta_prestamos.dia_atraso%type;
   v_redondeo            number(5);
   v_nro_factura         ge_movimientos.nro_documento2%type;
   v_car_seguro          number;
   v_cli_concesionaria   ge_entes.cod_persona%type;
   v_mto_exonerado       ge_exoneraciones.mto_exoneracion%type; -- DYDMR-9486 IEC04 - Relevamiento y Ajustes a Exoneraciones de Prestamos
   --- Cursor de codeudores
   cursor c_codeudores is
   select nro_garantia, v_nro_cuenta, r_pcpre.dig_verificador,
          r_pcpre.cod_oficina, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,'C',
          porcentaje
     from pr_sol_garantias
    where nro_solicitud = p_nro_solicitud
      and cod_garantia = 2;
   --- Cursor de garantias
   cursor c_garantias is
   select v_nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, porcentaje
     from pr_sol_garantias
    where nro_solicitud = p_nro_solicitud;
   --- Cursor de cargos del prestamo
   cursor c_cargos is
   select cod_moneda, cod_transaccion, monto, val_tasa, mto_mon_prestamo
     from pr_sol_cargos c
    where nro_solicitud = p_nro_solicitud
   and (not exists (select t.cod_transaccion
          from ge_transacciones t
         where t.cod_Transaccion = c.cod_transaccion
           and afecta = 'G')
    OR (c.cod_transaccion = 1521 AND EXISTS
        (SELECT 1
           FROM BA_TAB_DAT_ADICIONALES D
          WHERE D.REFERENCIA = p_nro_solicitud
            AND D.PARAMETRO = 'PRE_IND_CUO_CAL_SEGURO'
            AND D.VAL_PARAMETRO = 'S')))
   -- G= Seguros en cuotas
    order by decode(cod_transaccion, 709, -1, cod_transaccion);
   --- Cursor de prestamos y Oper.Vencidas a renovar o refinanciar
   --- Agregar orden por moneda para realizar el boleteo. COREADRRR-2
   cursor c_renovar is
   select nro_cuenta, nvl(mto_capital,0) mto_capital,
          nvl(sal_capital,0) sal_capital, nvl(pr.val_int_devengar,0) val_int_devengar,
          cod_modulo, cod_modalidad, pr.cod_moneda, decode(pr.cod_moneda, 'GS', 1, 2) orden
     from pr_cta_prestamos pr
    where nro_sol_renovada = p_nro_solicitud
      and estado <> 'N'
    union all
   select nro_cuenta,nvl(v.mto_origen,0),v.sal_total,0, cod_modulo,cod_modalidad, v.cod_moneda,
          decode(v.cod_moneda, 'GS', 1, 2) orden
     from ov_cta_vencidas v
    where nro_sol_renovada = p_nro_solicitud
      and estado <> 'C'
    order by orden;
   --- Cursor de transacciones detalles del cargo
   cursor c_des_cargos is
   select t.cod_tra_hijo, t.cod_mod_hijo, t.cod_mad_hijo, a.cod_tasa
     from ge_transacciones_det t, ge_transacciones a
    where t.cod_transaccion = v_cod_tra_padre
      and t.cod_modulo      = v_cod_mod_padre
      and t.cod_modalidad   = v_cod_mad_padre
      and t.cod_tra_hijo    = a.cod_transaccion
      and t.cod_mod_hijo    = a.cod_modulo
      and t.cod_mad_hijo    = a.cod_modalidad
      and a.cod_tasa   IS NOT NULL;

/* Genera movimientos del seguro */
PROCEDURE LP_GEN_MOV_SEGURO
 IS
-- Cursor de seguros
   cursor c_seguros is
   select car.cod_ent_seguro, car.cod_transaccion,sol.cod_modalidad,
          sum(car.monto) importe, sum(car.mto_mon_prestamo) impousd,
          car.cod_moneda
   from pr_sol_cargos car, pr_solicitudes sol
   where car.nro_solicitud = p_nro_solicitud
     and car.nro_solicitud = sol.nro_solicitud
     and car.cod_ent_seguro is not null
     and not exists (select t.cod_transaccion from ge_transacciones t
                    where t.cod_transaccion = car.cod_transaccion
                      and t.afecta = 'G')  -- G= Afecta Seguro en cuotas
   group by car.cod_ent_seguro, car.cod_transaccion, car.cod_moneda, sol.cod_modalidad;
   v_importe ge_movimientos.monto%type;
   v_cta_cre ge_movimientos.nro_cuenta%type;
   v_nro_comprobante ge_movimientos.nro_documento3%type;
   v_car_desglose        pr_cuotas.val_recargo%type;
   v_fec_vigencia        ge_tas_fechas.fec_vigencia%type;
   v_tip_valor           ge_tasas.tip_valor%type;
   v_tipo                ge_tasas.tipo%type;
   v_porcen              number;
   v_val_tasa            pr_cta_prestamos.val_tasa%type;

   --Proyecto SDSEGVID-144--Seguro Anual de Consumo---
   v_pre_hab_cal_seg_anual ge_par_dinamicos.val_parametro%type;
   r_gmose ge_movimientos%rowtype;
   v_cod_rub_ganancia      cb_rubros.cod_rubro%type;

   --- Cursor de transacciones detalles del cargo -- Realizado por ICL -- 24/10/2013
   cursor c_des_cargos is
   select t.cod_tra_hijo, t.cod_mod_hijo, t.cod_mad_hijo, a.cod_tasa
     from ge_transacciones_det t, ge_transacciones a
    where t.cod_transaccion = v_cod_tra_padre
      and t.cod_modulo      = v_cod_mod_padre
      and t.cod_modalidad   = v_cod_mad_padre
      and t.cod_tra_hijo    = a.cod_transaccion
      and t.cod_mod_hijo    = a.cod_modulo
      and t.cod_mad_hijo    = a.cod_modalidad
      and a.cod_tasa   IS NOT NULL;
BEGIN
   v_pre_hab_cal_seg_anual := nvl(fug_obt_pardinamico('PRE_HAB_CAL_SEG_ANUAL'),'N');
   for seg in c_seguros loop
     /*
     -- Esta parte corresponde al credito del monto a pagar a la Aseguradora
     -- en su cuenta
     --*/
     begin
         v_cta_cre := null;
         if fug_obt_tip_ente(seg.cod_ent_seguro) = 'SE' then
            --v_cta_cre := fug_obt_parentes(seg.cod_ent_seguro, 'NRO_CTA_SEGURO');
            --Verificar la moneda del cargo para seleccionar la cuenta de Crédito
            if seg.cod_moneda = v_cod_mon_local then
               v_cta_cre := fug_obt_parentes(seg.cod_ent_seguro, 'NRO_CTA_SEG_MON_LOCAL');
            else
               v_cta_cre := fug_obt_parentes(seg.cod_ent_seguro, 'NRO_CTA_SEG_MON_FUERTE');
            end if;
         else
            v_cta_cre := fug_obt_parentes(seg.cod_ent_seguro, 'NRO_CTA_ESCRIBANIA');
         end if;
         exception
           when others then v_cta_cre := null;
      end;
      if v_cta_cre is not null then
         /*    IF :ABMC.SCR_MONEDA_LOCAL <> :FPPROPU.SO_CDMONED AND
                :OPE_CAMB.SCR_COTIZAC IS NOT NULL THEN
               W_EQUIVGS:=ROUND(TRUNC(SEG.IMPOUSD,2)*:OPE_CAMB.SCR_COTIZAC,0);
             ELSE
               W_EQUIVGS:=SEG.IMPORTE;
             END IF;*/ --- Cuando se implemente cambios
         pag_cta.PR_OBT_CUENTA(v_cta_cre);
         if pag_cta.G_CTAS.cod_moneda != seg.cod_moneda then
            v_importe := seg.impousd;
         else
            v_importe := seg.importe;
         end if;
         if seg.cod_moneda <> pag_cta.G_CTAS.cod_moneda then
            v_importe := pag_gen.FU_CON_MON_A_MONEDA(seg.cod_moneda,pag_cta.G_CTAS.cod_moneda,v_importe, v_cotizacion);
         end if;


         --- Descontar del cargo a acreditar el impuesto Realizado por ICL -- 24/10/2013
         v_car_desglose  := 0;
         for adi in c_des_cargos loop --- Desglose de cargos
            v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6,seg.cod_modalidad, seg.cod_moneda);
            --- Calcular monto del desglose
            pag_gen.pr_obt_val_tasa(adi.cod_mod_hijo, --  Modulo
                           adi.cod_mad_hijo, --  Modalidad
                           r_psoli.cod_oficina, --  Oficina
                           null, --  Nro de cuenta
                           seg.cod_moneda,  --  Moneda
                           v_importe, --  Monto de la transaccion
                           'N', --  Tasa personalizada
                           adi.cod_tasa, --  Codigo de Tasa
                           adi.cod_tra_hijo, --  Codigo de Transaccion
                           p_fecha, --fecha final
                           v_val_tasa, --  Valor de la tasa
                           v_fec_vigencia,  --  Fecha de Vigencia
                           v_tip_valor, --  Tip_valor
                           v_tipo);--  Tipo
            --- Calcular monto
            if nvl(v_importe,0) <> 0 and adi.cod_tasa is not null and v_val_tasa is not null then
               if v_tip_valor = 'V' then
                  v_car_desglose := nvl(v_val_tasa,0);
               else
                  v_porcen := nvl(v_val_tasa,0) + 100;
                    v_car_desglose := round(nvl(v_importe,0) *
                                             nvl(v_val_tasa,0)/v_porcen,v_redondeo);
                    --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                    v_car_desglose := pag_gen.FU_OBT_VAL_FINAL(v_car_desglose);
               END IF;
            else
               v_car_desglose := 0;
            end if;
            ---
         end loop;
         if v_car_desglose <> 0 then
            v_importe := v_importe - v_car_desglose;
         end if;

         --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
         --Verifica y actualiza rubro contable de cta suspenso--
         if nvl(v_pre_hab_cal_seg_anual,'N') = 'S' then
            --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
            --Inserta parametro adicional--
            prp_pro_dat_seg_anual('I', null, null, p_nro_solicitud, seg.cod_modalidad);

            --Generar movimientos sin cta suspenso--rbpa
            v_cod_rub_ganancia := null;
            v_cod_rub_ganancia := fug_obt_parentes(seg.cod_ent_seguro, 'RUB_GAN_SEG_VID_'||r_pcpre.cod_moneda);
            if v_cod_rub_ganancia is null then
               raise_application_error(-20000, 'Error. Ente '||seg.cod_ent_seguro||' no tiene definido rubro de ganancia p/ credito en '||r_pcpre.cod_moneda);
            end if;

            v_nro_secuencia            := v_nro_secuencia + 1;
            r_gmose.nro_secuencia      := v_nro_secuencia;
            r_gmose.cod_usuario        := v_cod_usuario;
            r_gmose.hora               := v_hora;
            r_gmose.fecha              := v_fec_actual;
            r_gmose.cod_modulo         := r_pcpre.cod_modulo;
            r_gmose.cod_modalidad      := r_pcpre.cod_modalidad;
            r_gmose.cod_oficina        := r_pcpre.cod_oficina;
            r_gmose.nro_cuenta         := null;
            r_gmose.cod_moneda         := r_pcpre.cod_moneda;
            r_gmose.est_cuenta         := null;
            r_gmose.cod_tra_padre      := 358;
            r_gmose.cod_transaccion    := null;
            r_gmose.concepto           := 'Desembolso Cuenta '||r_pcpre.nro_cuenta;
            r_gmose.monto              := v_importe;
            r_gmose.cod_rubro          := v_cod_rub_ganancia;
            if r_pcpre.cod_moneda <> v_cod_mon_local then
               r_gmose.cotizacion      := v_cotizacion;
               r_gmose.mto_equ_local   := round(trunc(v_importe,2)*v_cotizacion,v_redondeo_ml);
            else
               v_cotizacion            := null;
               r_gmose.cotizacion      := null;
               r_gmose.mto_equ_local   := null;
            end if;
            r_gmose.fec_valor          := v_fec_actual;
            r_gmose.emi_aviso          := 'N';
            r_gmose.reversado          := 'N';
            r_gmose.protegido          := 'N';
            r_gmose.estado             := 'N';
            r_gmose.cod_ofi_origen     := p_cod_ofi_origen;
            r_gmose.cod_mod_padre      := r_pcpre.cod_modulo;
            r_gmose.cod_mad_padre      := r_pcpre.cod_modalidad;
            r_gmose.nro_documento      := p_nro_solicitud;
            r_gmose.nro_documento3     := v_nro_comprobante;
            r_gmose.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
            r_gmose.tip_mov_rubro      := 'C';  --Tipo de Movimiento Crédito
            r_gmose.val_tasa           := null;--v_val_tas_prima;
            pag_gen.pr_ins_ge_movimiento(r_gmose, v_es_nocturno);
         else
         --- Acreditar a cuenta de ahorro
         pag_cta.pr_act_operacion(v_cta_cre,
                    v_hora,--HORA
                    'C',
                    pag_cta.g_ctas.cod_moneda,      --Moneda de la Operacion
                    v_importe,
                    358,  -- COD_TRA_PADRE (Desembolso de Prestamo)
                    602,  -- COD_TRA_HIJO (602)
                   p_nro_solicitud,
                    v_cotizacion,  --COTIZACION
                    p_cod_ofi_origen,      --cod_ofi_origen
                    r_psoli.cod_modulo,     --cod_mod_padre
                   r_psoli.cod_modalidad,  --cod_mad_padre
                   null,                       --cod_tasa
                   null,                       --val_tasa
                   'Desembolso Cuenta '||r_pcpre.nro_cuenta, --DYDMR-6535 - Incidencia SAU - ITGF -  Seguro en Transito MAPFRE
                   'S',                        --emi_aviso
                   v_nro_secuencia,
                   p_fecha);
         if pag_cta.fu_obt_cod_error() <> 0 then
            raise_application_error(-20000, 'Acr.Seguro '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
       Else
            --- Graba el numero de comprobante para que pueda imprimir...
            If fug_obt_tip_implementacion in (1,7) then
           select s_nro_debito.nextval into v_nro_comprobante from dual;
           ---
           update ge_movimientos
             set nro_documento3 = v_nro_comprobante,
                 referencia = r_pcpre.nro_cuenta --DYDMR-6535 - Incidencia SAU - ITGF - Diferencia Cuenta Contable - Seguro en Transito MAPFRE
           where hora = v_hora
             and cod_usuario = v_cod_usuario
             and cod_tra_padre = 358
             and nro_cuenta = v_cta_cre;

            End If;
          end if;
         end if;
          /*   IF DUPLICADO = 0 THEN
                :global.error := 'PASO 13.4';
                INSERT INTO FPSEGUR
                       (EG_CDMODUL, EG_CDMODAL, EG_CDOFICI, EG_NROPRES,
                        EG_FCINICI, EG_FCVENCI, EG_IMSEGUR, EG_CDSEGUR)
                VALUES
                       (:GLOBAL.WK_CDMODUL, :GLOBAL.WK_CDMODAL,
                        :GLOBAL.WK_CDOFICI, :ABMC.SCR_NROPRES,
                        :FPPROPU.SO_FCINICI, :FPPROPU.SO_FCVENCI,
                        W_EQUIVGS,SEG.SC_CDSEGUR);
             ELSE
                :global.error := 'PASO 13.5';
                UPDATE FPSEGUR SET EG_IMSEGUR = NVL(EG_IMSEGUR,0) +
                                                NVL(W_EQUIVGS,0)
                WHERE  EG_CDMODUL = :GLOBAL.WK_CDMODUL AND
                       EG_CDMODAL = :GLOBAL.WK_CDMODAL AND
                       EG_CDOFICI = :GLOBAL.WK_CDOFICI AND
                       EG_NROPRES = :ABMC.SCR_NROPRES  AND
                       EG_CDSEGUR = SEG.SC_CDSEGUR;
             END IF;*/ --- OJO no existe fpsegur
      else
         -- no existe cuenta de seguro
         raise_application_error(-20000,'Cuenta de Credito del Seguro o Escribania no definida. Verifique');
      end if;
   end loop;
END;
/* Obtener pago unico de la solicitud. */
FUNCTION LF_OBT_PAG_UNICO
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 )
 RETURN VARCHAR2
 IS
v_cantidad number(05);
BEGIN
   select count(*) into v_cantidad
     from pr_sol_cuotas
    where mto_capital > 0 and nro_cuota > 0
      and nro_solicitud = p_nro_solicitud;
   if v_cantidad = 1 then
      return 'P';
   else
      return 'A';
   end if;
END;
/* Actualiza cuotas restantes */
PROCEDURE LP_ACT_CUO_RESTANTES
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 )
 IS
cursor c_cuotas is
   select c.nro_cuota, nvl(c.mto_capital,0) - decode(s.tipo, 'D', nvl(c.val_int_adelantado,0), 0) capital,
          c.val_interes, c.val_int_adelantado
     from pr_sol_cuotas c, pr_solicitudes s
    where c.nro_solicitud = s.nro_solicitud
      and c.nro_solicitud = p_nro_solicitud
      and c.nro_cuota > 0;
   v_cuo_inicial pr_cuotas.nro_cuota%type;
BEGIN
   --- busco la primera cuota pendiente de pago del prestamo original-
   select min(nro_cuota) into v_cuo_inicial
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and nro_cuota  > 0
      and estado    <> 'N'
      and fec_vencimiento > p_fecha;
   v_cuo_inicial := v_cuo_inicial - 1;
   --- actualizo todas las cuotas pendientes de pago -----------------
   for cc in c_cuotas loop
      update pr_cuotas
         set mto_capital = nvl(mto_capital,0) + nvl(cc.capital,0),
             sal_capital = nvl(sal_capital,0) + nvl(cc.capital,0),
             mto_interes = nvl(mto_interes,0) + nvl(cc.val_interes,0),
             sal_interes = nvl(sal_interes,0) + nvl(cc.val_interes,0),
             mto_int_documentado = nvl(mto_int_documentado,0) + nvl(cc.val_int_adelantado,0),
             sal_int_documentado = nvl(sal_int_documentado,0) + nvl(cc.val_int_adelantado,0)
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = cc.nro_cuota + v_cuo_inicial
         and estado <> 'N';
      if sql%notfound then
         insert into pr_cuotas
            (nro_cuenta, nro_cuota, mto_capital, fec_vencimiento, mto_interes, sal_capital,
             sal_interes, estado, prioridad, mto_int_documentado, sal_int_documentado)
         select p_nro_cuenta, nro_cuota, nvl(c.mto_capital,0)-nvl(c.val_int_adelantado,0), c.fec_vto_habil, nvl(c.val_interes,0),  nvl(c.mto_capital,0)-nvl(c.val_int_adelantado,0),
                nvl(c.val_interes,0), 'C', 'I', c.val_int_adelantado, c.val_int_adelantado
           from pr_sol_cuotas c, pr_solicitudes s
          where s.nro_solicitud = p_nro_solicitud
            and c.nro_solicitud = s.nro_solicitud
            and c.nro_cuota = cc.nro_cuota;
      end if;
   end loop;
END;

BEGIN
   Begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=6;end;
   --- Cargar variables
   v_nro_secuencia := p_nro_secuencia;
   v_nro_cuenta    := Null;
   --Verificar Usuario ATM--
   if substr(user,1,3) = 'ATM' then
      v_cod_usuario := fug_obt_pardinamico('COD_USU_ATM_ACTUAL');
      v_est_modulo := pae_cnf.fu_obt_est_modulo(3); -- CORECTRB-2 ABR/2018
   else
      v_cod_usuario := user;
   end if;

   if v_est_modulo = 2 then -- El modulo está abierto
     v_es_nocturno := 'N';
     v_hora        := p_hora;
   else
     v_es_nocturno := 'S';
     v_fec_actual  := pag_cal.FU_OBT_FEC_PROXIMA(6);
     v_hora        := fug_obt_hor_disponible(v_fec_actual,v_hor_actual,v_cod_usuario,v_es_nocturno);
   end if;
   --- Recuperar datos de la Solicitud
   pr_obt_dat_solicitud(p_nro_solicitud, r_psoli, v_cargos, v_int_adelantado);
   pr_val_desembolso(p_nro_solicitud, r_psoli, p_fecha, v_error, v_mensaje);

   v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,r_psoli.cod_modalidad, r_psoli.cod_moneda);

   if v_error <> 0 then
      raise_application_error(-20000,
      v_mensaje||' '||'error:'||v_error);
   end if;
   --- Recuperar monto total de renovaciones si posee
   --PAP_PRE_RES_04.pr_obt_ren_solicitud(p_nro_solicitud, p_fecha, p_cod_ofi_origen, v_mto_renovar);
   --- Verificar monto de desembolso
   if p_mto_desembolso <> nvl(r_psoli.tot_prestamo,0) - (nvl(v_cargos,0)+nvl(v_int_adelantado,0)+nvl(v_mto_renovar,0))
      and r_psoli.cod_modalidad <> 699 then
      raise_application_error(-20000,
      'Monto a desembolsar no coincide con monto de la solicitud');
   end if;
   if nvl(v_gen_boleteo, 'X') = 'S' then
      -- Dejar las 2 primeras secuencias para el boleteo. A utilizar en PRL_PRO_OPE_CAM_PED.
      v_nro_secuencia := v_nro_secuencia + 2;
   end if;
   --- Inicializar variables de movimientos
   --DYDMR-5803--Modificado por rpavon 03.01.17--
   --Agregado para eliminar la recarga de cod usuario--
   --v_cod_usuario   := user;
   --- busco el valor de la cotizacion, si no hay operac.de cambios---
   v_cot_cambio    := null;
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_cotizacion    := null;
   if r_psoli.cod_moneda <> v_cod_mon_local then
      if v_cot_cambio is null then
         --- Actualizar cargos a la cotizacion del dia.
         v_cotizacion := pag_gen.fu_obt_cotizacion(r_psoli.cod_moneda, p_fecha);
         /*
         || PCCLIANC-4
         || El Monto del Cargo debe ser sin decimales
         || Siempre es en moneda local
         */
        /* if r_psoli.cod_modalidad = 699 then
            v_red_mon_local :=  fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                    r_psoli.cod_modulo,
                                                    r_psoli.cod_modalidad,
                                                    v_cod_mon_local);
         else*/
            v_red_mon_local := v_redondeo;
         --end if;

         update pr_sol_cargos
            set monto = round(nvl(mto_mon_prestamo,0)*v_cotizacion, v_red_mon_local)
          where nro_solicitud = p_nro_solicitud
            and cod_moneda = v_cod_mon_local;
      else
         v_cotizacion := v_cot_cambio;
      end if;
   end if;
   v_capital := NVL(r_psoli.tot_prestamo,0) - NVL(v_int_adelantado,0);
   --- tipo de prestamo ---------------------------------------------
   --if r_psoli.cod_modalidad in (62,608) then
   /* En la propuesta ya carga este dato.
   If FUP_OBT_TIP_DESCUENTO(r_psoli.cod_modalidad) in ('D','C') then
      r_psoli.tipo := 'D';
   else
      r_psoli.tipo := lf_obt_pag_unico(p_nro_solicitud);
   end if;
   */
   -- actualizo las fechas de prestamo si la propuesta <> hoy-------
/*   if fug_obt_pardinamico('PRE_PERSONAL', r_psoli.cod_modulo, r_psoli.cod_modalidad) = 'S'
   or fug_obt_tip_implementacion = 2 then */
   if fug_obt_tip_implementacion <> 3 then
      v_dia_diferencia := p_fecha - r_psoli.fec_inicio;
      if v_dia_diferencia <> 0 and r_psoli.tip_renovacion <> 'V' then --préstamos vista se renueva a fecha valor y debe mantener fec_inicio
         update pr_sol_tasas
            set fec_vigencia = fec_vigencia + v_dia_diferencia
          where nro_solicitud = p_nro_solicitud;
         --if r_psoli.nro_sol_original is null then
            r_psoli.fec_inicio      := r_psoli.fec_inicio + v_dia_diferencia;
            r_psoli.fec_vencimiento := r_psoli.fec_vencimiento + v_dia_diferencia;
            update pr_solicitudes
               set fec_inicio = fec_inicio + v_dia_diferencia,
                   fec_pri_vencimiento = fec_pri_vencimiento + v_dia_diferencia,
                   fec_vencimiento = fec_vencimiento + v_dia_diferencia
                   ---fec_fin_per_gracia = fec_fin_per_gracia + v_dia_diferencia
             where nro_solicitud = p_nro_solicitud;
            If nvl(fug_obt_pardinamico('TIP_DES_DOCUMENTOS',r_psoli.cod_modulo, r_psoli.cod_modalidad),'X') != 'C' Then
        update pr_cuotas
           set fec_vencimiento = fec_vencimiento + v_dia_diferencia
         where nro_cuota = v_nro_cuenta;
        update pr_sol_cuotas
           set fec_vto_habil = fec_vto_habil + v_dia_diferencia,
             fec_vto_exacto = fec_vto_exacto + v_dia_diferencia
         where nro_solicitud = p_nro_solicitud;
      End If;
         /* RI: Se comenta todo lo que tengo nro_sol_original para darle otra funcionalidad
           else
            update pr_solicitudes
               set fec_inicio = fec_inicio + v_dia_diferencia
             where nro_solicitud = p_nro_solicitud;*/
         --end if;
      end if;
   end if;
--   if r_psoli.nro_sol_original is null then --- Prestamo normal
      if r_psoli.nro_sol_renovada is null then
         v_renovacion := 'N';
      else
         v_renovacion := 'S';
         --- CAMBIO DE ESTADO DE LA PROPUESTA --- OJO esto cambiaria segun nuevo formato
         update pr_solicitudes
            set estado = 'N'
          where nro_solicitud = r_psoli.nro_sol_renovada;
      end if;
      --- Recuperar maxima fecha de vencimiento
      select max(fec_vto_habil), count(*)
        into v_fec_vencimiento, v_can_cuotas
        from pr_sol_cuotas
       where nro_solicitud = p_nro_solicitud
         and nro_cuota > 0;
      if v_fec_vencimiento <> r_psoli.fec_vencimiento then
         r_psoli.fec_vencimiento := v_fec_vencimiento;
         r_psoli.dia_plazo       := r_psoli.fec_vencimiento - r_psoli.fec_inicio;
         update pr_solicitudes
            set fec_vencimiento = r_psoli.fec_vencimiento,
                dia_plazo       = r_psoli.dia_plazo
          where nro_solicitud = p_nro_solicitud;
      end if;
      --- Recuperar tasa de la solicitud y periodo de vencimiento de interes
      v_val_tasa := PAP_PRE_RES_04.fu_obt_tas_sol(p_nro_solicitud, r_pcpre.per_vto_interes);
      --- Inserta registro en el maestro de prestamo ----------------------
      r_pcpre.cod_modulo         := r_psoli.cod_modulo;
      r_pcpre.cod_modalidad      := r_psoli.cod_modalidad;
      r_pcpre.cod_oficina        := r_psoli.cod_oficina;
      r_pcpre.cod_moneda         := r_psoli.cod_moneda;
      r_pcpre.nro_cta_debito     := r_psoli.nro_cta_debito;
      r_pcpre.nro_documento      := p_nro_doc_desde;
      r_pcpre.dig_verificador    := 0;
      r_pcpre.nro_solicitud      := r_psoli.nro_solicitud;
      r_pcpre.estado             := 'C';
      r_pcpre.tip_renovacion     := r_psoli.tip_renovacion;
      if r_psoli.cod_modalidad = 699 then
         r_pcpre.mto_capital     := p_mto_desembolso;
         r_pcpre.sal_capital     := p_mto_desembolso;
      else
         r_pcpre.mto_capital     := v_capital;
         r_pcpre.sal_capital     := v_capital;
      end if;
      r_pcpre.sal_interes        := NVL(r_psoli.mto_interes,0) - NVL(v_int_adelantado,0);
      r_pcpre.tip_documento      := p_tip_documento;
      r_pcpre.cob_automatico     := r_psoli.deb_automatico;
      if r_psoli.cod_modalidad = 699 then
         r_pcpre.val_int_devengar := 0;
         r_pcpre.sal_int_adelantado := 0;
      else
         r_pcpre.sal_int_adelantado := v_int_adelantado;
         r_pcpre.val_int_devengar := r_psoli.mto_interes;
      end if;
      r_pcpre.nro_sol_renovada   := r_psoli.nro_sol_renovada;
      r_pcpre.nro_linea          := r_psoli.nro_linea;
      r_pcpre.monto              := p_mto_desembolso;
      r_pcpre.tipo               := r_psoli.tipo;
      r_pcpre.tip_interes        := r_psoli.tip_interes;
      r_pcpre.mto_lin_aplicado   := r_psoli.mto_lin_aplicado;
      r_pcpre.val_tasa           := v_val_tasa;
      r_pcpre.can_cuotas         := v_can_cuotas;
      r_pcpre.can_cuo_pagadas    := 0;
      r_pcpre.cod_canal          := r_psoli.cod_canal;
      r_pcpre.cod_campana        := r_psoli.cod_campana;
      r_pcpre.cod_sec_credito    := r_psoli.cod_sec_credito;
      r_pcpre.descripcion        := substr(r_psoli.descripcion,1,35);
      r_pcpre.fec_inicio         := r_psoli.fec_inicio;
      r_pcpre.fec_vencimiento    := r_psoli.fec_vencimiento;
      r_pcpre.exo_impuestos      := r_psoli.exo_impuesto;
      r_pcpre.cod_ori_fondo      := p_cod_ori_fondo;
      r_pcpre.per_vto_capital    := r_psoli.per_vto_capital;
      r_pcpre.cod_banca          := r_psoli.cod_banca;
      r_pcpre.tip_destino        := r_psoli.tip_destino;
      r_pcpre.por_ori_fondo      := r_psoli.por_ori_fondo;
      r_pcpre.fec_ren_tas_orig   := r_psoli.fec_ren_tasa;
      r_pcpre.cod_rub_economico  := r_psoli.cod_rub_economico;
      r_pcpre.cod_sub_modalidad  := r_psoli.cod_sub_modalidad;
      pr_ins_cta_prestamo(r_psoli.cod_persona, r_pcpre, v_nro_cuenta);
      --- Generar Numeracion de Factura
      /* La factura se genera en el cierre del día P.V. 21-07-2010
      v_nro_factura := fug_obt_lla_pardinamico('NRO_FACTURA', r_psoli.cod_modulo, r_psoli.cod_modalidad,
                       r_psoli.cod_moneda, r_psoli.cod_oficina)+1;
      prg_act_par_dinamico('NRO_FACTURA', r_psoli.cod_modulo, r_psoli.cod_modalidad,
                       r_psoli.cod_moneda, r_psoli.cod_oficina, v_nro_factura);
      */
      --- Generar movimiento de generacion del credito
      v_nro_secuencia := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia      := v_nro_secuencia;
      r_gmovi.cod_usuario        := v_cod_usuario;
      r_gmovi.hora               := v_hora;
      r_gmovi.fecha              := v_fec_actual;
      r_gmovi.cod_modulo         := r_psoli.cod_modulo;
      r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
      r_gmovi.cod_oficina        := r_psoli.cod_oficina;
      r_gmovi.nro_cuenta         := v_nro_cuenta;
      r_gmovi.cod_persona        := r_psoli.cod_persona;
      r_gmovi.cod_moneda         := r_psoli.cod_moneda;
      r_gmovi.est_cuenta         := 'C';
      r_gmovi.cod_tra_padre      := 358;
      r_gmovi.cod_transaccion    := 401;
      r_gmovi.fec_valor          := p_fecha;
      r_gmovi.emi_aviso          := 'N';
      r_gmovi.reversado          := 'N';
      r_gmovi.protegido          := 'N';
      r_gmovi.estado             := 'N';
      r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
      r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
      r_gmovi.nro_documento      := r_psoli.nro_solicitud;
      r_gmovi.nro_documento2     := null; --v_nro_factura;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      -- genera la novedad de la cuenta para poder controlar la reversión
      -- estado nuevo  para que la reversión le vea (est anterior null sino no se pueden reversar históricos xq encuentra)
      PRG_GEN_NOV_CUENTA(r_gmovi.fecha, r_gmovi.hora, r_gmovi.cod_usuario, r_gmovi.nro_cuenta,
                         r_gmovi.cod_modulo, r_gmovi.cod_modalidad, null, r_gmovi.est_cuenta, null);
      --- Genera las cuotas del prestamo y actualizo los documentos
      if r_psoli.cod_modalidad = 699 then
         insert into pr_cuotas
            (nro_cuenta, nro_cuota, mto_capital, fec_vencimiento, mto_interes, sal_capital,
             sal_interes, estado, prioridad, mto_int_documentado, sal_int_documentado,
             nro_documento)
            select v_nro_cuenta, c.nro_cuota, c.mto_capital, c.fec_vto_habil, c.val_interes, c.sal_cap_anterior,
                   c.val_interes, 'C', 'I',0,0,
                   decode(p_nro_doc_desde,p_nro_doc_hasta,p_nro_doc_desde,p_nro_doc_desde+c.nro_cuota)
              from pr_sol_cuotas c, pr_solicitudes s
             where s.nro_solicitud = p_nro_solicitud
               and c.nro_solicitud = s.nro_solicitud;
      else
         insert into pr_cuotas
            (nro_cuenta, nro_cuota, mto_capital,
             fec_vencimiento, mto_interes, sal_capital,
             sal_interes, estado, prioridad, mto_int_documentado, sal_int_documentado,
             nro_documento)
            select v_nro_cuenta, c.nro_cuota, nvl(c.mto_capital,0)-nvl(c.val_int_adelantado,0),
                   c.fec_vto_habil, nvl(c.val_interes,0), nvl(c.mto_capital,0)-nvl(c.val_int_adelantado,0),
                   nvl(c.val_interes,0), 'C', 'I', c.val_int_adelantado, c.val_int_adelantado,
                   decode(p_nro_doc_desde,p_nro_doc_hasta,p_nro_doc_desde,p_nro_doc_desde+c.nro_cuota)
              from pr_sol_cuotas c, pr_solicitudes s
             where s.nro_solicitud = p_nro_solicitud
               and c.nro_solicitud = s.nro_solicitud;
      end if;
      --- si tiene interes adelantado, actualizo la cuota 0 ------------
      if v_int_adelantado > 0 then
         update pr_cuotas
            set fec_ult_pago = p_fecha,
                sal_interes  = 0,
                estado       = 'N'
          where nro_cuenta   = v_nro_cuenta
            and nro_cuota    = 0;
      end if;
      --- Insertar relacion cliente cuentas -----
      --- Cliente Principal
      insert into ge_cta_clientes
         (cod_persona, nro_cuenta, dig_verificador,
          cod_oficina, cod_modulo, cod_modalidad, relacion)
      values
         (r_psoli.cod_persona, v_nro_cuenta, r_pcpre.dig_verificador,
          r_pcpre.cod_oficina, r_pcpre.cod_modulo, r_pcpre.cod_modalidad, 'P');
     /* --- Codeudores si los tuviere
      for gar in c_codeudores loop
         --- Verificar si existe en Ge_clientes, sino insertar
         begin
            v_existe := 'N';
            select 'S' into v_existe
            from ge_clientes
            where cod_persona = gar.nro_garantia;
            exception
               when no_data_found then
                  --- Insertar ge_clientes
                  insert into ge_clientes
                     (cod_persona,cod_oficina, cod_usu_oficial,
                      cod_sec_contable,cod_tip_deudor, residente,
                      cod_departamento)
                  --- Agregar con los datos basicos del cliente principal de la cuenta
                  select gar.nro_garantia, cl.cod_oficina, cl.cod_usu_oficial,
                         cl.cod_sec_contable, cl.cod_tip_deudor, cl.residente,
                         cl.cod_departamento
                    from ge_clientes cl
                   where cl.cod_persona = r_psoli.cod_persona;
         end;
         --- Insertar Relacion Cliente Cuenta
         insert into ge_cta_clientes
            (cod_persona, nro_cuenta, dig_verificador,
             cod_oficina, cod_modulo, cod_modalidad, relacion)
         values(gar.nro_garantia, v_nro_cuenta, r_pcpre.dig_verificador,
             r_pcpre.cod_oficina, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,'C');
      end loop;*/
      ---- Si es cartera comprada Insertar la relacion con la cedente
    /*  if r_psoli.cod_ent_concesionaria is not null then
        Begin
          Select cod_persona into v_cli_concesionaria
            from ge_entes
           where cod_ente = r_psoli.cod_ent_concesionaria;
        Exception
          when others then
            v_cli_concesionaria := null;
        End;
        If v_cli_concesionaria is not null then
        --   if r_pcpre.cod_modalidad <> '609' then --ajustado por ICL para compra cartera
        -- DYDMR-1571 - ITGF - Prestamo con Relacion cedente afecta Activo de Cliente SC 13114 - 02/2015
        -- DYDMR-6649 - Incidencia SAU - ITGF - Vinculo CEDENTE en Préstamo
            if(nvl(fug_obt_pardinamico('COM_CARTERA',r_pcpre.cod_modulo,r_pcpre.cod_modalidad,null,null,null),'N')='S') then
              insert into ge_cta_clientes
              (cod_persona, nro_cuenta, dig_verificador,
               cod_oficina, cod_modulo, cod_modalidad, relacion)
              values(v_cli_concesionaria, v_nro_cuenta, r_pcpre.dig_verificador,
              r_pcpre.cod_oficina, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,'D');
            end if;
        End if;
      End if;*/
      --- Insertar garantias si las posee
      for gar2 in c_garantias loop
        --sys.dbms_lock.sleep(1);
        insert into pr_cta_garantias
           (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, porcentaje)
        values
           (gar2.v_nro_cuenta, gar2.nro_garantia, gar2.cod_garantia, gar2.mto_aplicado, gar2.porcentaje);
      end loop;
      --- Insertar destinos si los tuviere
      insert into pr_cta_destinos
         (nro_cuenta, tip_des_especifico, monto)
      select v_nro_cuenta, tip_des_especifico, monto
        from pr_sol_destinos
       where nro_solicitud = p_nro_solicitud;
   /* Se comenta todo lo que tenga nro_sol_orginal is not null , para darle otra funcionalidad
   ELSE
      --- es un prestamo adicional, actualizar el prestamo original-----
      update pr_cta_prestamos
         set sal_capital = nvl(sal_capital,0) + v_capital,
             sal_interes = nvl(sal_interes,0) + NVL(r_psoli.mto_interes,0) - NVL(v_int_adelantado,0),
             sal_int_adelantado = nvl(sal_Int_adelantado,0) + nvl(v_int_adelantado,0),
             val_int_devengar   = nvl(val_int_devengar,0) + nvl(r_psoli.mto_interes,0)
       where nro_solicitud = r_psoli.nro_sol_original;
      --- actualiza los saldos de las cuotas restantes del prestamo---
      lp_act_cuo_restantes(p_nro_solicitud, v_nro_cuenta, p_fecha);*/
--   END IF;
   --- actualizo el estado y tipo de prestamo -----------------------
   update pr_solicitudes
      set estado = 'A',
          fec_aprobacion = p_fecha,
          cod_usu_aprobacion = v_cod_usuario,
          tipo = r_psoli.tipo,
          cod_ori_fondo = p_cod_ori_fondo,
          tip_documento = p_tip_documento
    where nro_solicitud = p_nro_solicitud;
   --- Actualizo los cheques que corresponden a la solicitud
   /*update ge_che_custodias
      set estado = 'C', nro_referencia = v_nro_cuenta
    where nro_referencia = p_nro_solicitud
      and estado <> 'D'
      and tip_servicio in ('D', 'G');*/

   --- Actualizo los documentos de la solicitud si son : fact.o doc.  13/04/05
   --if r_psoli.cod_modalidad in (62,620) then
  /* If FUP_OBT_TIP_DESCUENTO(r_psoli.cod_modalidad) = 'D' then
     update pr_documentos
       set nro_referencia = v_nro_cuenta
     where nro_referencia = p_nro_solicitud
               and estado = 'C';
   end if;*/

   --determinar el % de origen de fondos para la contabilización
   if r_psoli.cod_ori_fondo = fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,r_psoli.cod_moneda,null,null) then
     --es fondos propios tomar el 100%
     v_mto_cap_original := v_capital; -- todo el capital con fondos propios
   else
     if r_psoli.por_ori_fondo > 0 and r_psoli.por_ori_fondo <= 100 then
        v_mto_ori_fondo := round(v_capital * r_psoli.por_ori_fondo / 100,v_redondeo); --sólo el porcentaje
        v_mto_cap_original := v_capital - v_mto_ori_fondo;
     else
        v_mto_cap_original := v_capital; -- todo el capital con fondos propios
     end if;
   end if;
   if v_mto_cap_original > 0 then
     -- genero el movimiento por el capital (origen de fondo original) a contabilizar -----------
     v_nro_secuencia := v_nro_secuencia + 1;
     r_gmovi.nro_secuencia      := v_nro_secuencia;
     r_gmovi.cod_usuario        := v_cod_usuario;
     r_gmovi.hora               := v_hora;
     r_gmovi.fecha              := v_fec_actual;
     r_gmovi.cod_modulo         := r_psoli.cod_modulo;
     r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
     r_gmovi.cod_oficina        := r_psoli.cod_oficina;
     r_gmovi.nro_cuenta         := v_nro_cuenta;
     r_gmovi.cod_persona        := r_psoli.cod_persona;
     r_gmovi.cod_moneda         := r_psoli.cod_moneda;
     r_gmovi.est_cuenta         := null;
     r_gmovi.cod_tra_padre      := 358;
     if r_psoli.tipo = 'P' then
        r_gmovi.cod_transaccion := 715;
     else
        r_gmovi.cod_transaccion := 711;
     end if;
     if r_psoli.cod_modalidad = 699 then
        r_gmovi.monto           := p_mto_desembolso; --v_capital;
        r_gmovi.mto_equ_local   := round(trunc(p_mto_desembolso,2)*v_cotizacion,v_redondeo_ml);
     else
        r_gmovi.monto           := v_mto_cap_original; --v_capital;
        r_gmovi.mto_equ_local   := round(trunc(v_mto_cap_original,2)*v_cotizacion,v_redondeo_ml);
     end if;
     r_gmovi.fec_valor          := p_fecha;
     r_gmovi.emi_aviso          := 'S';
     r_gmovi.reversado          := 'N';
     r_gmovi.protegido          := 'N';
     r_gmovi.estado             := 'N';
     r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
     r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
     r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
     r_gmovi.nro_documento      := r_psoli.nro_solicitud;
     r_gmovi.concepto           := 'ACEPTACION PRESTAMO '||v_nro_cuenta;
     r_gmovi.cotizacion         := v_cotizacion;
     pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
     v_nro_secuencia := v_nro_secuencia + 1;
     v_nro_sec_interes := v_nro_secuencia;
     v_nro_secuencia := v_nro_secuencia + 1;
   end if;

   if v_mto_ori_fondo > 0 then
     -- genero el movimiento por el origen de fondo específico a contabilizar -----------
     v_nro_secuencia := v_nro_secuencia + 1;
     r_gmovi.nro_secuencia      := v_nro_secuencia;
     r_gmovi.cod_usuario        := v_cod_usuario;
     r_gmovi.hora               := v_hora;
     r_gmovi.fecha              := v_fec_actual;
     r_gmovi.cod_modulo         := r_psoli.cod_modulo;
     r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
     r_gmovi.cod_oficina        := r_psoli.cod_oficina;
     r_gmovi.nro_cuenta         := v_nro_cuenta;
     r_gmovi.cod_persona        := r_psoli.cod_persona;
     r_gmovi.cod_moneda         := r_psoli.cod_moneda;
     r_gmovi.est_cuenta         := null;
     r_gmovi.cod_tra_padre      := 358;
     r_gmovi.cod_transaccion    := fup_obt_tra_ori_fondo(r_psoli.cod_ori_fondo,r_psoli.cod_moneda,'A'); --transacción del origen de fondos
     r_gmovi.monto              := v_mto_ori_fondo; --monto del origen de fondos
     r_gmovi.fec_valor          := p_fecha;
     r_gmovi.emi_aviso          := 'S';
     r_gmovi.reversado          := 'N';
     r_gmovi.protegido          := 'N';
     r_gmovi.estado             := 'N';
     r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
     r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
     r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
     r_gmovi.nro_documento      := r_psoli.nro_solicitud;
     r_gmovi.concepto           := 'Orig. fondo '||r_psoli.cod_ori_fondo||'-'||v_nro_cuenta;
     r_gmovi.cotizacion         := v_cotizacion;
     r_gmovi.mto_equ_local      := round(trunc(v_mto_ori_fondo,2)*v_cotizacion,v_redondeo_ml);
     pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
     v_nro_secuencia := v_nro_secuencia + 1;
     v_nro_sec_interes := v_nro_secuencia;
     v_nro_secuencia := v_nro_secuencia + 1;
   end if;
   --DYDMR-4989
   --se verifica si existe un cargo para los casos en que se exonera 100%.
   begin
   select 'S'
     into v_exi_cargo
     from pr_sol_cargos c
    where nro_solicitud = r_psoli.nro_solicitud
      and not exists (select t.cod_transaccion from ge_transacciones t
                       where t.cod_Transaccion = c.cod_transaccion
                         and t.afecta = 'G');  -- G= Afecta Seguro
   exception
     when no_data_found then
       v_exi_cargo := 'N';
     when too_many_rows then
       v_exi_cargo := 'S';
     when others then
       v_exi_cargo := 'N';
   end;
   -- movimientos por el/los cargos del prestamo ------------------ AJUSTES Issue 1121
   if nvl(v_cargos,0) > 0 or v_exi_cargo = 'S' then
      for reg in c_cargos loop
         v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6,r_psoli.cod_modalidad, reg.cod_moneda);
         v_mto_fin_cargo := nvl(reg.monto,0);
         v_cod_tra_padre := reg.cod_transaccion;
         v_cod_mod_padre := r_psoli.cod_modulo;
         v_cod_mad_padre := r_psoli.cod_modalidad;-- se carga modalidad
         v_nro_secuencia := v_nro_secuencia + 1;
         v_nro_sec_cargo := v_nro_secuencia;

         /*
         || PCCEXECT-248
         || CC Modulo de exoneración y extorno de comisiones y tasas - Comisiones Prestamos
         || Insertar la Exoneración
         */
         begin
            select a.mto_a_cobrar, a.usu_insercion
              into v_mto_a_cobrar, v_usu_insercion
              from ge_exoneraciones_tmp a
             where a.nro_sol_prestamo = r_psoli.nro_solicitud
               and a.cod_transaccion  = reg.cod_transaccion
               and a.cod_modulo       = r_psoli.cod_modulo
               and a.cod_modalidad    = r_psoli.cod_modalidad;
         exception
            when no_data_found then
               v_mto_a_cobrar  := null;
               v_usu_insercion := null;
            when too_many_rows then
               v_mto_a_cobrar  := null;
               v_usu_insercion := null;
         end;
         if v_mto_a_cobrar is not null then
            -- DYDMR-9486 IEC04 Calcula el monto exonerado
            v_mto_exonerado := nvl(v_mto_a_cobrar,0)- nvl(v_mto_fin_cargo,0);
            prg_ins_exoneracion(reg.cod_transaccion,r_psoli.cod_modulo,r_psoli.cod_modalidad,
                                reg.cod_moneda,
                                v_nro_cuenta,null,null,
                                v_mto_exonerado,--mto_exonerado
                                nvl(v_mto_a_cobrar,0),--mto_a_cobrar
                                nvl(v_usu_insercion,user),
                                v_mto_exonerado);--mto_no_cob
         end if;
         if (nvl(v_mto_fin_cargo,0) <> 0) then -- GC - 31/03/2016 - Exoneraciones de Comisiones (Se agrega filtro para cargos exonerados)
           for adi in c_des_cargos loop --- Desglose de cargos
              v_car_desglose  := 0;
              --- Calcular monto del desglose
              pag_gen.pr_obt_val_tasa(adi.cod_mod_hijo, --  Modulo
                             adi.cod_mad_hijo, --  Modalidad
                             r_psoli.cod_oficina, --  Oficina
                             null, --  Nro de cuenta
                             reg.cod_moneda,  --  Moneda
                             reg.monto, --  Monto de la transaccion
                             'N', --  Tasa personalizada
                             adi.cod_tasa, --  Codigo de Tasa
                             adi.cod_tra_hijo, --  Codigo de Transaccion
                             p_fecha, --fecha final
                             v_val_tasa, --  Valor de la tasa
                             v_fec_vigencia,  --  Fecha de Vigencia
                             v_tip_valor, --  Tip_valor
                             v_tipo);--  Tipo

              --- Calcular monto
              if nvl(reg.monto,0) <> 0 and adi.cod_tasa is not null and v_val_tasa is not null then
                 if v_tip_valor = 'V' then
                    v_car_desglose := nvl(v_val_tasa,0);
                 else
                    v_porcen := nvl(v_val_tasa,0) + 100;
  --                  if reg.cod_moneda  = v_cod_mon_local  then
                      v_car_desglose := round(nvl(reg.monto,0) *
                                               nvl(v_val_tasa,0)/v_porcen,v_redondeo);
                      --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                      v_car_desglose := pag_gen.FU_OBT_VAL_FINAL(v_car_desglose);

  /*                  else
                       v_car_desglose := round(nvl(reg.monto,0) *
                                               nvl(v_val_tasa,0)/v_porcen,2);
                    End If;
  */               END IF;
              else
                 v_car_desglose := 0;
              end if;
              ---
              if (v_car_desglose <> 0) then
                 v_nro_secuencia := v_nro_secuencia + 1;
                 r_gmovi.nro_secuencia      := v_nro_secuencia;
                 r_gmovi.cod_usuario        := v_cod_usuario;
                 r_gmovi.hora               := v_hora;
                 r_gmovi.fecha              := v_fec_actual;
                 r_gmovi.cod_modulo         := r_psoli.cod_modulo;
                 r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
                 r_gmovi.cod_oficina        := r_psoli.cod_oficina;
                 r_gmovi.nro_cuenta         := v_nro_cuenta;
                 if v_cod_mad_padre = 64 then
                    r_gmovi.cod_persona := FUX_OBT_CCE_BENEFICIARIO(r_psoli.nro_solicitud,v_nro_cuenta);
                 else
                    r_gmovi.cod_persona := r_psoli.cod_persona;
                 end if; -- Issue 1121
                 r_gmovi.cod_moneda         := reg.cod_moneda;
                 r_gmovi.est_cuenta         := null;
                 r_gmovi.cod_tra_padre      := 358;
                 r_gmovi.cod_transaccion    := adi.cod_tra_hijo;
                 r_gmovi.concepto           := 'Desglose de Cargo';
                 r_gmovi.monto              := v_car_desglose;
                 if reg.cod_moneda <> v_cod_mon_local then
                    r_gmovi.cotizacion         := v_cotizacion;
                    r_gmovi.mto_equ_local      := round(trunc(v_car_desglose,2)*v_cotizacion,v_redondeo_ml);
                 else
                    r_gmovi.cotizacion         := null;
                    r_gmovi.mto_equ_local      := null;
                 end if;
                 r_gmovi.fec_valor          := p_fecha;
                 r_gmovi.emi_aviso          := 'S';
                 r_gmovi.reversado          := 'N';
                 r_gmovi.protegido          := 'N';
                 r_gmovi.estado             := 'N';
                 r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
                 r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
                 r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
                 r_gmovi.nro_documento      := r_psoli.nro_solicitud;
                 r_gmovi.val_tasa           := v_val_tasa;
                 pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
              end if;
              --- Descontar del total del cargo su desglose
              v_mto_fin_cargo := v_mto_fin_cargo - nvl(v_car_desglose,0);
           end loop;
           --v_nro_secuencia := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia      := v_nro_sec_cargo;
           r_gmovi.cod_usuario        := v_cod_usuario;
           r_gmovi.hora               := v_hora;
           r_gmovi.fecha              := v_fec_actual;
           r_gmovi.cod_modulo         := r_psoli.cod_modulo;
           r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
           r_gmovi.cod_oficina        := r_psoli.cod_oficina;
           r_gmovi.nro_cuenta         := v_nro_cuenta;
           if v_cod_mad_padre = 64 then
              r_gmovi.cod_persona := FUX_OBT_CCE_BENEFICIARIO(r_psoli.nro_solicitud,v_nro_cuenta);
           else
              r_gmovi.cod_persona := r_psoli.cod_persona;
           end if; -- Issue 1121
           r_gmovi.cod_moneda         := reg.cod_moneda;
           r_gmovi.est_cuenta         := null;
           r_gmovi.cod_tra_padre      := 358;
           r_gmovi.cod_transaccion    := reg.cod_transaccion;
           r_gmovi.concepto           := 'Cargos';
           r_gmovi.monto              := v_mto_fin_cargo;
           if reg.cod_moneda <> v_cod_mon_local then
              r_gmovi.cotizacion         := v_cotizacion;
              r_gmovi.mto_equ_local      := round(trunc(v_mto_fin_cargo,2)*v_cotizacion,v_redondeo_ml);
           else
              r_gmovi.cotizacion         := null;
              r_gmovi.mto_equ_local      := null;
           end if;
           r_gmovi.fec_valor          := p_fecha;
           r_gmovi.emi_aviso          := 'S';
           r_gmovi.reversado          := 'N';
           r_gmovi.protegido          := 'N';
           r_gmovi.estado             := 'N';
           r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
           r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
           r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
           r_gmovi.nro_documento      := r_psoli.nro_solicitud;
           r_gmovi.val_tasa           := reg.val_tasa;
           pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
           ---
        end if;
      end loop;
      r_gmovi.val_tasa := null;
   end if;
   -- movimientos por el credito a los seguros----------------------
   r_pcpre.nro_cuenta := v_nro_cuenta;
   --LP_GEN_MOV_SEGURO;
   --- Actualizaciones del devengamiento ----------------------------
   --- genero los movimientos por el devengamiento y el interes ----
   /*** Ajuste JIRA 1514***/
  -- si hay interes adelantado en la cuota 0 ----------------------
   if nvl(v_int_adelantado,0) > 0 then
      r_gmovi.nro_secuencia      := v_nro_sec_interes;
      r_gmovi.cod_usuario        := v_cod_usuario;
      r_gmovi.hora               := v_hora;
      r_gmovi.fecha              := v_fec_actual;
      r_gmovi.cod_modulo         := r_psoli.cod_modulo;
      r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
      r_gmovi.cod_oficina        := r_psoli.cod_oficina;
      r_gmovi.nro_cuenta         := v_nro_cuenta;
      r_gmovi.cod_persona        := r_psoli.cod_persona;
      r_gmovi.cod_moneda         := r_psoli.cod_moneda;
      r_gmovi.est_cuenta         := null;
      r_gmovi.cod_tra_padre      := 358;
      r_gmovi.cod_transaccion    := 717;
      r_gmovi.concepto           := 'Prod.Fin. Doc.';
      r_gmovi.monto              := nvl(v_int_adelantado,0);
      r_gmovi.fec_valor          := p_fecha;
      r_gmovi.emi_aviso          := 'S';
      r_gmovi.reversado          := 'N';
      r_gmovi.protegido          := 'N';
      r_gmovi.estado             := 'N';
      r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
      r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
      r_gmovi.nro_documento      := r_psoli.nro_solicitud;
      r_gmovi.cotizacion         := v_cotizacion;
      r_gmovi.mto_equ_local      := round(trunc(nvl(v_int_adelantado,0),2)*v_cotizacion,v_redondeo_ml);
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
   end if;
   r_gmovi.nro_secuencia      := v_nro_sec_interes + 1;
   r_gmovi.cod_usuario        := v_cod_usuario;
   r_gmovi.hora               := v_hora;
   r_gmovi.fecha              := v_fec_actual;
   r_gmovi.cod_modulo         := r_psoli.cod_modulo;
   r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
   r_gmovi.cod_oficina        := r_psoli.cod_oficina;
   r_gmovi.nro_cuenta         := v_nro_cuenta;
   r_gmovi.cod_persona        := r_psoli.cod_persona;
   r_gmovi.cod_moneda         := r_psoli.cod_moneda;
   r_gmovi.est_cuenta         := null;
   r_gmovi.cod_tra_padre      := 358;
   if nvl(v_int_adelantado,0) > 0 then
      r_gmovi.cod_transaccion := 722;
      r_gmovi.concepto        := 'Prod.Fin. Doc.a Dev.';
   else
      r_gmovi.cod_transaccion := 719;
      r_gmovi.concepto        := 'Prod.Fin.No doc.a Dev' ;
   end if;
   r_gmovi.monto              := nvl(r_psoli.mto_interes,0);
   r_gmovi.fec_valor          := p_fecha;
   r_gmovi.emi_aviso          := 'S';
   r_gmovi.reversado          := 'N';
   r_gmovi.protegido          := 'N';
   r_gmovi.estado             := 'N';
   r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
   r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
   r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
   r_gmovi.nro_documento      := r_psoli.nro_solicitud;
   r_gmovi.cotizacion         := v_cotizacion;
   r_gmovi.mto_equ_local      := round(trunc(nvl(r_psoli.mto_interes,0),2)*v_cotizacion,v_redondeo_ml);
   --- PCC-Liberación Anticipada de Cheques
   if nvl(r_psoli.mto_interes,0) > 0 then
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
   end if;
   --- Actualizar cheques en custodia
   --if r_psoli.cod_modalidad in (608, 630) then
   If FUP_OBT_TIP_DESCUENTO(r_psoli.cod_modalidad) = 'C' then
      ---Actualizaciones del estado de cheques si corresponde la modalidad -
      update ge_che_custodias
         set estado = 'C'
       where estado <> 'D'
         and tip_servicio in ('D', 'G')
         and nro_referencia = p_nro_solicitud;
   end if;
   ---PREPARA_MOV_DE_DESEMBOLSO;
  /*      IF :ABMC.SO_NRPRORI IS NULL THEN
          UPDATE FPPARAM SET PA_SIGDOCU = :ABMC.SCR_DOCUM_H WHERE
                 PA_CDMODUL = 6 AND PA_CDMODAL = 999;
        END IF;*/
  ---If :so_cdmodal in (620) Then -- Compra y descuento de facturas
  ---   COMISION_A_EMPRESA;
  ---End If;
   --- Cobrar renovaciones o refinanciaciones
   v_cat_renovaciones := 1;
   v_cat_operacion    := 1;
   v_tot_pond         := 0;
   v_tip_cap_calculo      := fug_obt_pardinamico('SIB_TIP_CAP_CALCULO');
   v_por_cat_mej_original := fug_obt_pardinamico('SIB_POR_CAT_MEJ_ORIGINAL');
/*   for ren in c_renovar loop
      v_cat_renovaciones := 1;
      v_cat_operacion    := 1;
      v_mto_deuda := 0;
      v_tot_deuda := 0;
      --- Recuperar datos de la deuda
      PAP_PRE_RES_04.pr_ini_autorizacion;
      if ren.cod_modulo = 6 then
         PAP_PRE_RES_04.pr_obt_deu_prestamo(ren.nro_cuenta, p_fecha, 0, 999,
                                     p_cod_ofi_origen, null, v_error, v_mensaje,
                                     v_tot_sal_capital, v_tot_sal_interes, v_tot_sal_int_ade,
                                     v_tot_mora, v_tot_mor_interes, v_tot_mor_int_ade,
                                     v_tot_punitorio, v_tot_impuesto,
                                     v_tot_cargo, v_tot_car_iva, v_tot_int_descontado,
                                     v_dia_mora,359,'T','S');
         if v_error <> 0 then
            raise_application_error(-20001,v_mensaje);
         end if;
         ---
         if  r_psoli.tip_renovacion = 'D' then -- desembolso en etapas
           PAP_PRE_RES_04.pr_obt_car_seg_cuotas(ren.nro_cuenta,v_car_seguro);
         End if;
         v_tot_deuda := nvl(v_tot_sal_capital,0) +
                        nvl(v_tot_sal_int_ade,0) +
                        nvl(v_tot_sal_interes,0) +
                        nvl(v_tot_mora,0) +
                        nvl(v_tot_mor_interes,0) +
                        nvl(v_tot_mor_int_ade,0) +
                        nvl(v_tot_punitorio,0) +
                        nvl(v_tot_impuesto,0) +
                        nvl(v_tot_cargo,0);
                        --(nvl(v_tot_cargo,0)-nvl(v_car_seguro,0));
         PAP_PRE_RES_04.pr_ini_var_cobro;
      elsif ren.cod_modulo = 15 then
         pav_ove.pr_obt_deu_ope_vencida(ren.nro_cuenta,p_fecha,null,v_error,v_mensaje,
         v_tot_sal_capital,v_tot_mora,v_tot_punitorio, v_tot_impuesto,
                                     v_tot_cargo,v_tot_car_iva,v_dia_mora,359);
          if v_error <> 0 then
            raise_application_error(-20001,v_mensaje);
          end if;

          v_tot_deuda := nvl(v_tot_sal_capital,0) +
                        nvl(v_tot_mora,0) +
                        nvl(v_tot_punitorio,0) +
                        nvl(v_tot_impuesto,0) +
                        nvl(v_tot_cargo,0);
      end if;
      --- Recuperar categoria de la operacion
      begin
         select round(cat_automatica)
           into v_cat_operacion
           from ge_cla_operaciones_his   -- ge_cla_operaciones --RABF 06/12/2011
          where nro_cuenta = ren.nro_cuenta
            and fecha = v_fec_anterior;
            -- En ge_cla_operaciones luego del cierre se encuentra vacía. Por eso se recupera de ge_cla_operaciones_his
      exception
           when no_data_found then
              v_cat_operacion := 1;
      end;
      v_fec_ini_cobro := to_date('01/'||to_char(r_psoli.fec_inicio,'mm/yyyy'));
      v_dia_atraso := nvl(to_number(fug_obt_pardinamico('DIA_MOR_RRR',ren.cod_modulo,ren.cod_modalidad)),60);
      --- Verificar el tipo de renovacion del nuevo prestamo
      if r_pcpre.tip_renovacion in('D','V') then --- Si es una renovacion, Desembolso en etapas o Prestamos a la Vista
         --- Verificar que haya pagado el 10% de la Deuda Anterior
         if nvl(ren.mto_capital,0)-nvl(ren.sal_capital,0) < nvl(ren.mto_capital,0)*10/100 then
            if fug_obt_tip_implementacion in (7) then --- Banco R
               v_cat_renovaciones := 3;
            else
               if v_cat_operacion > nvl(v_cat_renovaciones,1) then
                  v_cat_renovaciones := v_cat_operacion;
               end if;
            end if;
         end if;
      elsif r_pcpre.tip_renovacion IN ('N','R','E') then --- Si es una renovación/refinanciacion/reestructuracion
            v_cat_renovaciones := v_cat_operacion;
            if round((fup_obt_mto_capital(ren.nro_cuenta,r_psoli.fec_inicio,v_dia_atraso,v_tip_cap_calculo,'M',v_fec_ini_cobro-1) *
               v_por_cat_mej_original / 100), fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,ren.cod_moneda)) <=
               fup_obt_mto_capital(ren.nro_cuenta,null,null,null,'C',v_fec_ini_cobro-1) then
               if v_cat_operacion >= 2 then
                  v_cat_renovaciones := v_cat_operacion - 1;
               else
                  v_cat_renovaciones := 1;
               end if;
            end if;
            IF ren.cod_moneda <> r_psoli.cod_moneda THEN
               pag_gen.pr_con_mon_a_moneda(ren.cod_moneda, r_psoli.cod_moneda, nvl(v_tot_deuda, 0),
                                           v_mto_deuda, v_cotizacion, v_cotizacion);
               v_tot_pond := v_tot_pond + (nvl(v_mto_deuda, 0) * round(v_cat_renovaciones));
            ELSE
               v_tot_pond := v_tot_pond + (nvl(v_tot_deuda, 0) * round(v_cat_renovaciones));
            END IF;
      end if;
      --- RI : 25/08/09 Antes de cancelar los cargos de seguros en cuotas debo
      --- pasar esos cargos a la nueva cuenta
      Declare
        Cursor c_car_anterior is
        Select cod_transaccion,cod_moneda,monto,fec_ingreso,fec_ini_vigencia,
               fec_vencimiento,nro_solicitud
          from pr_cta_gastos g
         where nro_cuenta = ren.nro_cuenta
           and fec_ult_pago is null
           and exists (select cod_Transaccion
                         from ge_transacciones t
                        where t.cod_transaccion = g.cod_transaccion
                          and t.afecta = 'G');  -- G= Afecta Seguros en cuotas
        --
        Cursor c_tot_cargos is
        select cod_transaccion, cod_moneda, sum(monto) monto
          from pr_cta_gastos g
         where nro_cuenta = ren.nro_cuenta
           and fec_ult_pago is null
           and exists (select cod_Transaccion
                         from ge_transacciones t
                        where t.cod_transaccion = g.cod_transaccion
                          and t.afecta = 'G')  -- G= Afecta Seguros en cuotas
        group by cod_transaccion, cod_moneda;
      Begin
        For reg in c_car_anterior loop
          -- Inserto el cargo con la nueva cuenta
          Insert into pr_Cta_gastos
          (nro_cuenta,cod_Transaccion,cod_moneda,monto,fec_ingreso,fec_Vencimiento,
           fec_ini_vigencia,cod_modulo,cod_modalidad,nro_solicitud)
          values
          (v_nro_cuenta,reg.cod_Transaccion,reg.cod_moneda,reg.monto,reg.fec_ingreso,
           reg.fec_vencimiento,reg.fec_ini_vigencia,r_psoli.cod_modulo,r_psoli.cod_modalidad,reg.nro_solicitud);
        End loop;
        For reg in c_tot_cargos loop
          -- Genero los movimientos por el traslado del seguro a la cuenta nueva
            v_nro_secuencia := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia      := v_nro_secuencia;
            r_gmovi.cod_usuario        := v_cod_usuario;
            r_gmovi.hora               := v_hora;
            r_gmovi.fecha              := v_fec_actual;
            r_gmovi.cod_modulo         := r_psoli.cod_modulo;
            r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
            r_gmovi.cod_oficina        := r_psoli.cod_oficina;
            r_gmovi.nro_cuenta         := null;
            r_gmovi.cod_moneda         := reg.cod_moneda;
            r_gmovi.est_cuenta         := null;
            r_gmovi.cod_persona        := null;
            r_gmovi.cod_tra_padre      := 358;
            r_gmovi.cod_transaccion    := 1523;  --Cta. suspenso
            r_gmovi.concepto           := 'Traslado de Cargos de Seguro';
            r_gmovi.monto              := reg.monto;
            r_gmovi.fec_valor          := p_fecha;
            r_gmovi.emi_aviso          := 'N';
            r_gmovi.reversado          := 'N';
            r_gmovi.protegido          := 'N';
            r_gmovi.estado             := 'N';
            r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
            r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
            r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
            r_gmovi.nro_documento      := v_nro_cuenta;
            r_gmovi.cotizacion         := v_cotizacion;
            r_gmovi.mto_equ_local      := round(trunc(nvl(reg.monto,0),2)*v_cotizacion,v_redondeo_ml);
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
        End loop;
      End;
      --- Realizar cobro
      PAP_PRE_RES_04.pr_ini_autorizacion;
      if ren.cod_modulo = 6 then
         PAP_PRE_RES_04.pr_can_prestamo(ren.nro_cuenta,
                                 v_tot_deuda,
                                 'N', --- Se pidio autorizacion
                                 p_cod_ofi_origen, --- oficina origen
                                 'T',
                                 p_fecha,
                                 v_hora,
                                 v_nro_secuencia,
                                 r_pcpre.cod_modalidad,
                                 'S', r_psoli.tip_renovacion);
         PAP_PRE_RES_04.pr_ini_var_cobro;

         --- Actualizar numero de cuenta renovada
         update pr_cta_prestamos
            set nro_cta_renovada = v_nro_cuenta
          where nro_cuenta = ren.nro_cuenta;
       elsif ren.cod_modulo = 15 then
          pav_ove.pr_cob_ope_vencida(ren.nro_cuenta,
                                     v_tot_deuda,
                                     p_cod_ofi_origen,
                                     null,
                                     p_fecha,
                                     v_hora,
                                     v_nro_secuencia,
                                     358,
                                     r_psoli.cod_modulo,
                                     r_psoli.cod_modalidad,
                                     null);
          PAP_PRE_RES_04.pr_ini_var_cobro;
          --- Actualizar numero de cuenta renovada
          update ov_cta_vencidas
             set nro_cta_renovada = v_nro_cuenta
           where nro_cuenta = ren.nro_cuenta;
       end if;
       --- Actualizar numero de cuenta renovada
       IF r_pcpre.tip_renovacion <> 'A' THEN
          UPDATE pr_cta_prestamos
             SET nro_cta_renovada = v_nro_cuenta
           WHERE nro_cuenta = ren.nro_cuenta;
       ELSIF r_pcpre.tip_renovacion = 'A' THEN
          UPDATE pr_cta_prestamos
             SET nro_sol_renovada = NULL, nro_cta_novada = v_nro_cuenta
           WHERE nro_cuenta = ren.nro_cuenta;
       END IF;

       IF v_gen_boleteo = 'S' THEN
          IF r_psoli.cod_moneda <> ren.cod_moneda THEN
             -- Se utiliza una bandera (v_acu_mto_desemb) porque por el desembolso debe hacer una sola vez.
             -- Desembolso. Compra.
             IF r_psoli.cod_moneda <> v_cod_mon_local AND v_acu_mto_desemb = 'S' THEN
                v_acu_mto_desemb := 'N';
                v_mto_boleteo := v_mto_boleteo + v_mto_renovar;
             END IF;
             -- Cuentas a Cancelar. Venta.
             IF ren.cod_moneda <> v_cod_mon_local THEN
                v_mto_boleteo := v_mto_boleteo - v_tot_deuda;
             END IF;
          ELSIF v_acu_mto_desemb = 'N' THEN
             -- Cuentas a Cancelar. Venta.
             IF ren.cod_moneda <> v_cod_mon_local THEN
                v_mto_boleteo := v_mto_boleteo - v_tot_deuda;
             END IF;
          END IF;
       END IF;
   end loop;*/
   -- Generar boleteo
   IF v_mto_boleteo > 0 THEN
      prl_pro_ope_cam_ped(r_psoli.cod_oficina, null, 6, 'USD', null, v_mto_boleteo, v_hora, 'C');
   ELSIF v_mto_boleteo < 0 THEN
      prl_pro_ope_cam_ped(r_psoli.cod_oficina, null, 6, 'USD', null, abs(v_mto_boleteo), v_hora, 'V');
   END IF;

   -- Recalcular linea
   if r_pcpre.tip_renovacion in ('N','E','R','D','V') then --- Si es una renovacion/Refin/Restruc/En Etapas/A la vista
      if r_pcpre.nro_linea is not null then
         prp_rec_apl_limite(r_pcpre.nro_linea);
      end if;
   end if;
   --
   v_tip_ref_holding := fue_tab_dat_adicional('PR_SOLICITUDES', 'TIP_REF_HOLDING', r_psoli.nro_solicitud);
   if v_tip_ref_holding is not null then
      INSERT INTO ge_cta_dat_adicionales
         (nro_cuenta, parametro, val_parametro)
      VALUES
         (v_nro_cuenta, 'TIP_REF_HOLDING', v_tip_ref_holding);
   end if;
   if nvl(v_mto_renovar, 0) > 0 then
      v_cat_renovaciones := round(trunc((v_tot_pond / nvl(v_mto_renovar, 0)), 2), 0);
   end if;
   --- Actualizar el prestamo nuevo la categoria de renovacion si es necesario
   if v_cat_renovaciones is not null then
      update pr_cta_prestamos
         set cat_renovaciones = v_cat_renovaciones
       where nro_cuenta = v_nro_cuenta;
   end if;
   --- Cargar variables de retorno
   p_nro_secuencia := v_nro_secuencia;
   p_nro_cuenta    := v_nro_cuenta;
   --- CROLIANC-4 AT - Liberacion Anticipada Cheques C/O con Creación de Cuentas de Préstamos.
   if r_psoli.cod_modalidad = 699 then
      update cc_lib_ant_cheques
         set nro_cta_prestamo = v_nro_cuenta,
             estado = 'D',
             fec_desembolso = v_fec_actual,
             hor_desembolso = v_hora,
             usu_desembolso = USER
       where nro_sol_prestamo = r_psoli.nro_solicitud;
   end if;
END;
/* Obtener datos de la solicitud */
PROCEDURE PR_OBT_DAT_SOLICITUD
 (NP_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,RP_PSOLI IN OUT PR_SOLICITUDES%ROWTYPE
 ,P_CARGOS IN OUT NUMBER
 ,P_INT_ADELANTADO IN OUT NUMBER
 )
 IS
BEGIN
   select *
     into rp_psoli
     from pr_solicitudes
    where nro_solicitud = np_nro_solicitud;
   --- Recuperar cargos
   p_cargos := 0;
   select nvl(sum(nvl(mto_mon_prestamo,0)),0)
     into p_cargos
     from pr_sol_cargos c
    where nro_solicitud = np_nro_solicitud
   and (not exists (select t.cod_transaccion
          from ge_transacciones t
         where t.cod_Transaccion = c.cod_transaccion
           and afecta = 'G')
    OR (c.cod_transaccion = 1521 AND EXISTS
        (SELECT 1
           FROM BA_TAB_DAT_ADICIONALES D
          WHERE D.REFERENCIA = np_nro_solicitud
            AND D.PARAMETRO = 'PRE_IND_CUO_CAL_SEGURO'
            AND D.VAL_PARAMETRO = 'S')));
   --- Recuperar interes adelantado
   p_int_adelantado := 0;
   if rp_psoli.tip_interes = 'A' then
      select nvl(sum(nvl(val_int_adelantado,0)),0)
        into p_int_adelantado
        from pr_sol_cuotas
       where nro_solicitud = np_nro_solicitud;
   end if;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Solicitud '||np_nro_solicitud||' no registrada');
END;
/* Obtener datos de la cuota de prestamos. */
PROCEDURE PR_OBT_DAT_CUOTA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,RP_PCUOT IN OUT PR_CUOTAS%ROWTYPE
 )
 IS
BEGIN
   select *
     into rp_pcuot
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and nro_cuota  = p_nro_cuota;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Cuota '||p_nro_cuota||' de cuenta '||p_nro_cuenta||' no registrada');
END;
/* Obtener cargos de seguros en cuotas. */
PROCEDURE PR_OBT_CAR_SEG_CUOTAS
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_CAR_SEGURO IN OUT PR_CTA_GASTOS.MONTO%TYPE
 )
 IS
BEGIN
  Select sum(monto) into p_car_seguro
    from pr_Cta_gastos g
   where nro_cuenta = p_nro_cuenta
     and fec_ult_pago is null
     and exists (select t.cod_transaccion from ge_transacciones t
                  where t.cod_transaccion = g.cod_transaccion
                    and t.afecta = 'G');   -- Afecta a Seguro en cuotas
exception
   when no_data_found then
      raise_application_error(-20000,
      'Error al traer cargos de seguro en cuotas de la cuenta '||p_nro_cuenta);
END;
/* Recupera maxima cuota vencida del prestamo. */
FUNCTION FU_OBT_MAX_CUO_VEN
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_VENCIMIENTO%TYPE
 )
 RETURN NUMBER
 IS
v_max_cuota  pr_cuotas.nro_cuota%type;
BEGIN
   select max(nro_cuota)
     into v_max_cuota
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and (nvl(sal_capital,0) <> 0 or
           nvl(sal_interes,0) <> 0 or
           nvl(sal_int_documentado,0) <> 0 ) -- Cuotas con saldo
      and nro_cuota > 0
      and fec_vencimiento <= p_fecha;
   return v_max_cuota;
END;
/* Recupera minima cuota vencida del prestamo. */
FUNCTION FU_OBT_MIN_CUO_VEN
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_VENCIMIENTO%TYPE
 )
 RETURN NUMBER
 IS
v_min_cuota  pr_cuotas.nro_cuota%type;
BEGIN
   select min(nro_cuota)
     into v_min_cuota
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and (nvl(sal_capital,0) <> 0 or
           nvl(sal_interes,0) <> 0 or
           nvl(sal_int_documentado,0) <> 0 ) -- Cuotas con saldo
      and nro_cuota > 0
      and fec_vencimiento <= p_fecha;
   return v_min_cuota;
END;
FUNCTION FU_OBT_MAX_FEC_VTO
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 )
 RETURN DATE
 IS
v_max_fec_vto   pr_cuotas.fec_vencimiento%type;
BEGIN
   select max(fec_vencimiento)
     into v_max_fec_vto
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and (nvl(sal_capital,0) <> 0 or
           nvl(sal_interes,0) <> 0 or
           nvl(sal_int_documentado,0) <> 0 ) -- Cuotas con saldo
      and nro_cuota <= p_cuota;
   return v_max_fec_vto;
END;
FUNCTION FU_OBT_MAX_FEC_CARGO
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
  )
 RETURN DATE
 IS
v_max_fec_vto   pr_Cta_gastos.fec_ini_vigencia%type;
BEGIN
   select max(fec_ini_vigencia)
     into v_max_fec_vto
     from pr_Cta_gastos
    where nro_cuenta = p_nro_cuenta;
   return v_max_fec_vto;
END;
/* Obtener la deuda del prestamo. */
PROCEDURE PR_OBT_DEU_PRESTAMO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN DATE
 ,P_NRO_CUO_DESDE IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_NRO_CUO_HASTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_COD_OFI_ORIGEN IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 ,P_MTO_COBRADO IN PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 ,P_ERROR IN OUT NUMBER
 ,P_MENSAJE IN OUT VARCHAR2
 ,P_TOT_CAPITAL IN OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 ,P_TOT_INTERES IN OUT PR_CTA_PRESTAMOS.SAL_INTERES%TYPE
 ,P_TOT_INT_ADELANTADO IN OUT PR_CTA_PRESTAMOS.SAL_INT_ADELANTADO%TYPE
 ,P_TOT_MORA IN OUT PR_CTA_PRESTAMOS.SAL_INTERES%TYPE
 ,P_TOT_MORA_INTERES IN OUT PR_CTA_PRESTAMOS.SAL_INTERES%TYPE
 ,P_TOT_MORA_INT_ADE IN OUT PR_CTA_PRESTAMOS.SAL_INTERES%TYPE
 ,P_TOT_PUNITORIO IN OUT PR_CTA_PRESTAMOS.SAL_INTERES%TYPE
 ,P_TOT_IMPUESTO IN OUT PR_CTA_PRESTAMOS.SAL_INTERES%TYPE
 ,P_TOT_CARGO IN OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 ,P_TOT_CARGO_IVA IN OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 ,P_TOT_INT_DESCONTADO IN OUT PR_CUOTAS.SAL_INTERES%TYPE
 ,P_DIA_MORA IN OUT PR_CTA_PRESTAMOS.DIA_ATRASO%TYPE
 ,P_COD_TRA_PADRE IN NUMBER default 360
 ,P_CANCELA IN VARCHAR2 default 'N'
 ,P_RENUEVA IN VARCHAR2 default 'N'
 ,P_CANCEL_RRR IN VARCHAR2 DEFAULT 'N'  -- Cancelación por renovación, refinaciación o restructuración del préstamo
 )
 IS
v_fec_ult_pago pr_cuotas.fec_ult_pago%type;
v_car_adic     number;
v_fecha ge_tas_fechas.fec_vigencia%type;
V_EXISTE VARCHAR2(1); --CRO-HO-CROCPCCB-12/08/15 se declara nueva variable para definir si existe la cuota o las cuotas a pagar
v_mto_dev_actual pr_devengados_tmp.mto_dev_actual%type;  -- DYDMR-2829

--Jira DYDMR-1419, para solucionar problemas de bloqueos en pantalla de cobros --
cursor c_tab_temporal is
  select x.rowid registro
    from pr_cobros_tmp x
    where x.nro_cuenta = p_nro_cuenta
    for update nowait;

/* Insertar cobros temporales. */
PROCEDURE LP_INS_PR_COBROS_TMP
 (RP_PCTMP IN PR_COBROS_TMP%ROWTYPE
 );
/* Recuperar autorizaciones previas. */
PROCEDURE LP_REC_AUT_PREV;
/* Utilizar autorizacion previa */
PROCEDURE LP_UTI_AUT_PRE
 (P_COD_AUTORIZACION IN GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_EXIMIDO IN GE_AUTORIZACIONES.EXIMIDO%TYPE
 ,P_VALOR IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 ,P_MONTO IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 );
/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
   r_pcpre             pr_cta_prestamos%rowtype;
   r_pctmp             pr_cobros_tmp%rowtype;
   --- Variables auxiliares
   v_min_cuo_vencida   pr_cuotas.nro_cuota%type;
   v_nro_cuo_hasta     pr_cuotas.nro_cuota%type;
   v_sal_cobrado       pr_cuotas.sal_capital%type;
   v_sal_capital       pr_cuotas.sal_capital%type;
   v_sal_interes       pr_cuotas.sal_interes%type;
   v_sal_int_documentado pr_cuotas.sal_int_documentado%type;
   v_int_descontado    pr_cuotas.sal_interes%type;
   v_cap_adelantado    pr_cuotas.sal_capital%type;
   v_mora              pr_cuotas.sal_interes%type;
   v_mora_interes      pr_cuotas.sal_interes%type;
   v_mora_int_ade      pr_cuotas.sal_interes%type;
   v_impuesto          pr_cuotas.sal_interes%type;
   v_cargo             pr_cuotas.sal_interes%type;
   v_car_seguro        pr_cuotas.sal_interes%type;
   v_car_adicional     pr_cuotas.sal_interes%type;
   v_car_iva_adic      pr_cuotas.sal_interes%type;
   v_car_iva           pr_cuotas.sal_interes%type;
   v_car_des           pr_cuotas.sal_interes%type;
   v_car_des_iva       pr_cuotas.sal_interes%type;
   v_tra_iva           ge_transacciones.cod_transaccion%type;
   v_cargo_iva         pr_cuotas.sal_interes%type;
   v_cargo_iva_aux     pr_cuotas.sal_interes%type;
   v_punitorio         pr_cuotas.sal_interes%type;
   v_seguro            pr_cuotas.sal_interes%type;
   v_tot_capital       pr_cuotas.sal_capital%type;
   v_tot_interes       pr_cuotas.sal_interes%type;
   v_tot_int_descontado pr_cuotas.sal_interes%type;
   v_tot_int_adelantado pr_cuotas.sal_interes%type;
   v_tot_mora          pr_cuotas.sal_interes%type;
   v_tot_mora_interes  pr_cuotas.sal_interes%type;
   v_tot_mora_int_ade  pr_cuotas.sal_interes%type;
   v_tot_impuesto      pr_cuotas.sal_interes%type;
   v_tot_cargo         pr_cuotas.sal_interes%type;
   v_tot_cargo_iva     pr_cuotas.sal_interes%type;
   v_tot_punitorio     pr_cuotas.sal_interes%type;
   v_tot_seguro        pr_cuotas.sal_interes%type;
   v_cod_mon_local     ba_monedas.cod_moneda%type;
   v_mto_cuota         pr_cuotas.sal_capital%type;
   v_car_manual        pr_cuotas.sal_interes%type;
   v_car_manual_iva    pr_cuotas.sal_interes%type;
   v_car_restante      pr_cuotas.sal_interes%type;
   v_car_restante_iva  pr_cuotas.sal_interes%type;
   --- Variables auxiliares para utilizacion de interes
   v_sal_int_ant       pr_cuotas.sal_interes%type;
   v_mto_ant           pr_cuotas.sal_interes%type;
   v_mto_int_mor_des   pr_cobros.mto_int_mor_des%type;
   v_mto_int_mor_int_des pr_cobros.mto_int_mor_int_des%type;
   v_mto_int_mor_ade_des pr_cobros.mto_int_mor_ade_des%type;
   v_mto_int_pun_des   pr_cobros.mto_int_pun_des%type;
   v_mto_car_des       pr_cobros.mto_car_des%type;
   ---
   v_iva     number;
   v_cal_iva number; --EF 09/06/2010
   v_cal_ley number;
   v_cal_dia number(10);
   v_cal_fac number;
   v_cal_fac_iva number;
   v_redondeo number(1);
   v_cod_tasa ge_tasas.cod_tasa%type := null;
   v_val_tasa ge_tas_fechas.val_tasa%type;
   v_val_tas_iva ge_tas_fechas.val_tasa%type;
   v_fec_vigencia ge_tas_fechas.fec_vigencia%type;
   v_tip_valor ge_tasas.tip_valor%type;
   v_tipo ge_tasas.tipo%type;
   v_exo_impuesto pr_cta_prestamos.exo_impuestos%type;

   --- Cursor de cuotas adeudadas
   --- Obs: Si se desea tener toda la deuda del prestamo deben estar en nulos los
   --- rangos de cuotas. Si se desea solo la deuda vencida solo enviar el rango desde
   cursor c_cuotas is
   select *
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and (nvl(sal_capital,0) <> 0 or
           nvl(sal_interes,0) <> 0 or
           nvl(sal_int_documentado,0) <> 0 ) -- Cuotas con saldo
      and ((p_nro_cuo_desde is not null and p_nro_cuo_hasta is not null
            and nro_cuota >= nvl(p_nro_cuo_desde,0)
            and nro_cuota <= nvl(v_nro_cuo_hasta,999))
           or
           (fec_vencimiento <= p_fecha
            and p_nro_cuo_desde is null
            and v_nro_cuo_hasta is null))
    order by fec_vencimiento;
    --- Recuperar prioridad de cobro
    cursor c_prioridades is
    select *
      from pr_cob_prioridades
     where nvl(cod_modulo,nvl(r_pcpre.cod_modulo,6)) = nvl(r_pcpre.cod_modulo,6)
       and nvl(cod_modalidad,nvl(r_pcpre.cod_modalidad,-1)) = nvl(r_pcpre.cod_modalidad,-1)
     order by secuencia;

/* Insertar cobros temporales. */
PROCEDURE LP_INS_PR_COBROS_TMP
 (RP_PCTMP IN PR_COBROS_TMP%ROWTYPE
 )
 IS
BEGIN
   insert into pr_cobros_tmp(
      nro_cuenta, nro_cuota, fec_valor, fec_vencimiento,
      estado, sal_capital_pre, sal_interes_pre, sal_capital_cuo,
      sal_interes_cuo, sal_int_documentado, fec_ult_pago,
      dia_mora, mto_capital, mto_interes, mto_int_documentado,
      mto_int_moratorio, mto_int_mor_interes,
      mto_int_mor_adelantado, mto_int_punitorio,
      mto_cargo, mto_cargo_iva, mto_impuesto,
      mto_int_descontado, nro_documento, mto_int_mor_cal,
      mto_int_mor_int_cal, mto_int_mor_ade_cal,
      mto_int_pun_cal, mto_cargo_cal, mto_car_iva_cal,
      mto_impuesto_cal,
      mto_int_mor_des, mto_int_mor_int_des,
      mto_int_mor_ade_des, mto_int_pun_des, mto_car_des,
      dev_acumulado, dev_no_cobrado, dev_suspenso)
   values (
      rp_pctmp.nro_cuenta, rp_pctmp.nro_cuota, rp_pctmp.fec_valor, rp_pctmp.fec_vencimiento,
      rp_pctmp.estado, rp_pctmp.sal_capital_pre, rp_pctmp.sal_interes_pre, rp_pctmp.sal_capital_cuo,
      rp_pctmp.sal_interes_cuo, rp_pctmp.sal_int_documentado, rp_pctmp.fec_ult_pago,
      rp_pctmp.dia_mora, rp_pctmp.mto_capital, rp_pctmp.mto_interes, rp_pctmp.mto_int_documentado,
      rp_pctmp.mto_int_moratorio, rp_pctmp.mto_int_mor_interes,
      rp_pctmp.mto_int_mor_adelantado, rp_pctmp.mto_int_punitorio,
      rp_pctmp.mto_cargo, rp_pctmp.mto_cargo_iva, rp_pctmp.mto_impuesto,
      rp_pctmp.mto_int_descontado, rp_pctmp.nro_documento, rp_pctmp.mto_int_mor_cal,
      rp_pctmp.mto_int_mor_int_cal, rp_pctmp.mto_int_mor_ade_cal,
      rp_pctmp.mto_int_pun_cal, rp_pctmp.mto_cargo_cal, rp_pctmp.mto_car_iva_cal,
      rp_pctmp.mto_impuesto_cal,
      rp_pctmp.mto_int_mor_des, rp_pctmp.mto_int_mor_int_des,
      rp_pctmp.mto_int_mor_ade_des, rp_pctmp.mto_int_pun_des, rp_pctmp.mto_car_des,
      rp_pctmp.dev_acumulado, rp_pctmp.dev_no_cobrado, rp_pctmp.dev_suspenso);
END;
/* Recuperar autorizaciones previas. */
PROCEDURE LP_REC_AUT_PREV
 IS
BEGIN
   --- Autorizacion descuento de interes
   if pap_cob.g_cod_aut_interes is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('IN',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_interes, pap_cob.g_exi_interes, pap_cob.g_cod_aut_interes, pap_cob.g_cod_usu_aut_int);
   end if;
   --- Autorizacion descuento de interes adelantado
   if pap_cob.g_cod_aut_int_ade is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('IA',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_int_ade, pap_cob.g_exi_int_ade, pap_cob.g_cod_aut_int_ade, pap_cob.g_cod_usu_aut_ina);
   end if;
   --- Autorizacion descuento de mora capital
   if pap_cob.g_cod_aut_mor_cap is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('MO',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_mor_cap, pap_cob.g_exi_mor_cap, pap_cob.g_cod_aut_mor_cap, pap_cob.g_cod_usu_aut_mo);
   end if;
   --- Autorizacion descuento de mora interes
   if pap_cob.g_cod_aut_mor_int is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('MI',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_mor_int, pap_cob.g_exi_mor_int, pap_cob.g_cod_aut_mor_int, pap_cob.g_cod_usu_aut_mi);
   end if;
   --- Autorizacion descuento de mora interes adelantado
   if pap_cob.g_cod_aut_mor_ade is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('MA',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_mor_ade, pap_cob.g_exi_mor_ade, pap_cob.g_cod_aut_mor_ade, pap_cob.g_cod_usu_aut_ma);
   end if;
   --- Autorizacion descuento de punitorio
   if pap_cob.g_cod_aut_punitorio is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('PU',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_punitorio, pap_cob.g_exi_punitorio, pap_cob.g_cod_aut_punitorio, pap_cob.g_cod_usu_aut_pu);
   end if;
   --- Autorizacion descuento de impuestos
   if pap_cob.g_cod_aut_impuesto is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('IM',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_impuesto, pap_cob.g_exi_impuesto, pap_cob.g_cod_aut_impuesto, pap_cob.g_cod_usu_aut_im);
   end if;
   --- Autorizacion descuento de cargos
   if pap_cob.g_cod_aut_cargos is null then
      PAP_PRE_RES_04.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                fu_obt_tra_concepto('CG',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                pap_cob.g_sal_val_cargos, pap_cob.g_exi_cargos, pap_cob.g_cod_aut_cargos, pap_cob.g_cod_usu_aut_cg);
   end if;
END;
/* Utilizar autorizacion previa */
PROCEDURE LP_UTI_AUT_PRE
 (P_COD_AUTORIZACION IN GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_EXIMIDO IN GE_AUTORIZACIONES.EXIMIDO%TYPE
 ,P_VALOR IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 ,P_MONTO IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 )
 IS
BEGIN
   if p_cod_autorizacion is not null then
      if p_eximido = 'S' and nvl(p_monto,0) > 0 then
         p_monto := 0;
      else
         if nvl(p_valor,0) >= nvl(p_monto,0) then
            p_valor := nvl(p_valor,0) - nvl(p_monto,0);
            p_monto := 0;
         else    --- Solo por lo que sobra de la autorizacion
            p_monto := nvl(p_monto,0) - nvl(p_valor,0);
            p_valor := 0;
         end if;
      end if;
   end if;
END;
/* veo si tiene IVA asociada a la transaccion */
PROCEDURE LP_OBT_TRA_IVA_ASOCIADA
 (P_COD_TRANSACCION IN  GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO      IN  GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD   IN  GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_TRA_IVA         OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 )
 IS
BEGIN
  -- Se asume que si tiene una transaccion detallada este es de impuesto.
  select cod_tra_hijo
    into p_tra_iva
    from ge_transacciones_det
   where cod_transaccion = p_cod_transaccion
     and cod_modulo      = p_cod_modulo
     and cod_modalidad   = p_cod_modalidad;
EXCEPTION
      when no_data_found then
           p_tra_iva := null;
END;

/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2 IS
   v_exo_impuestos ge_clientes.exo_impuestos%type;
BEGIN
   select nvl(exo_impuestos,'N')
     into v_exo_impuestos
     from ge_clientes cli, ge_cta_clientes cct
    where cct.cod_persona = cli.cod_persona
      and cct.nro_cuenta  = p_nro_cuenta
      and cct.relacion    = 'P';
    --- Esta opcion es si se toma en cuenta lo del prestamo
/*   if v_exo_impuestos = 'S' then
      return nvl(r_pcpre.exo_impuestos,'N');
   else
      return v_exo_impuestos;
   end if;*/
   return v_exo_impuestos;
END;

BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
   --- Recuperar datos del prestamo
   PAP_PRE_RES_04.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);

   if (nvl(pae_cnf.G_PROGRAMA, 'X') in ('GPPROFIN') and P_COD_TRA_PADRE = 364) --Cobro Automático de préstamos con Débito en cuenta
      OR nvl(pae_cnf.G_PROGRAMA, 'X') not in ('GPPROFIN','AMLIBRET') then --CRO-HO-CROCPCCB-12/08/15 Verifica que exista que exista la cuota y las cuotas en la tabla PR_COB_CUO_OTR_BCO
     BEGIN
          Select distinct('S')
          into v_existe
          from PR_COB_CUO_OTR_BCO a
         where a.nro_cuenta = P_NRO_CUENTA
           and a.nro_cuota  between p_nro_cuo_desde and p_nro_cuo_hasta
           and a.estado     = 'C';
     EXCEPTION
          when no_data_found then
           v_existe := 'N';
          when others Then
           v_existe := 'N';
     END;
     IF V_EXISTE = 'S' THEN --CRO-HO-CROCPCCB-12/08/15 Se carga para envíar error 25
        p_error   := 25;
        p_mensaje := 'Préstamo con cuota Pendiente de Confirmación de Cheque Cargo Otros Bancos.';
        return;
     END IF;
   end if;

   if fup_obt_tip_descuento(r_pcpre.cod_modalidad) not in ('F','D','C') then
   --if r_pcpre.cod_modalidad not in (608,630,62) then --OBS: Ver parametro dinamico
      --- Verificar que la cuota desde corresponda a la minima cuota no pagada
      v_min_cuo_vencida := fu_obt_min_cuo_ven(p_nro_cuenta, p_fecha);
      if p_nro_cuo_desde > v_min_cuo_vencida then
         p_error   := 20;
         p_mensaje := 'No se pueden cancelar cuotas posteriores a la minima pendiente '||v_min_cuo_vencida;
         return;
      end if;
   --end if;
   end if;
   --si es a fecha valor, verificar que sea mayor al último cobro
   --sólo para asociaciones no contemplar xq siempre se cobra atrasado --VC
   if r_pcpre.cod_modalidad = 627 and fug_obt_tip_implementacion = 9 then
     null;
   else
     if p_fecha < pag_cal.fu_obt_fec_actual(6) then
        select max(fec_ult_pago)
          into v_fec_ult_pago
          from pr_cuotas
         where nro_cuenta = p_nro_cuenta;
         /*if v_fec_ult_pago is not null and v_fec_ult_pago > p_fecha then
            raise_application_error(-20000,'Fecha de Cobro no puede ser anterior al último cobro realizado: '||to_char(v_fec_ult_pago,'dd/mm/yyyy'||'.'));
         end if;*/
     end if;
   end if;
   --- Cargar parametros de ser necesario
   if p_nro_cuo_desde is not null and p_nro_cuo_hasta is null then
      v_nro_cuo_hasta := fu_obt_max_cuo_ven(p_nro_cuenta, p_fecha);
   else
      v_nro_cuo_hasta := p_nro_cuo_hasta;
   end if;
   v_cod_mon_local          := pag_gen.fu_obt_mon_local;
   pap_cob.g_cod_mon_local  := v_cod_mon_local;
   pap_cob.g_cod_ofi_origen := p_cod_ofi_origen;
   pap_cob.g_max_fec_calculo_ant := null;
   pap_cob.g_cal_adic := 'S';  --RI : 20/05/2010
   pap_cob.g_iva_interes := 0;
   v_exo_impuesto           := FU_OBT_EXO_IMPUESTO(p_nro_cuenta);
   ---
   v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, r_pcpre.cod_modalidad, r_pcpre.cod_moneda);
   --- Inicializar totales
   v_tot_capital      := 0;
   v_tot_interes      := 0;
   v_tot_mora         := 0;
   v_tot_mora_interes := 0;
   v_tot_mora_int_ade := 0;
   v_tot_impuesto     := 0;
   v_tot_cargo        := 0;
   v_tot_cargo_iva    := 0;
   v_tot_punitorio    := 0;
   v_tot_seguro       := 0;
   v_tot_int_descontado := 0;
   v_tot_int_adelantado := 0; ---08/04/05
  ---RI : 28/05/2010 : Verificar si se cobro iva en la solicitud
  --Si no se cobro v_iva tendra valor cero
   Select count(*) into v_iva
    from pr_sol_cargos
   where nro_solicitud = r_pcpre.nro_solicitud
     and cod_Transaccion = 709;
   --- Monto cobrado --- Si se ingresa el monto cobrado calcular en base al mismo
   v_sal_cobrado := p_mto_cobrado;
   --- Eliminar tabla de cobro temporal
   --delete pr_cobros_tmp where nro_cuenta = p_nro_cuenta;
   for tem in c_tab_temporal loop
     delete pr_cobros_tmp z where rowid = tem.registro;
   end loop;
   --- Recuperar autorizaciones previas
   lp_rec_aut_prev;
   --- Devengar todo el prestamo, solo si falta devengar a la fecha del parametro
  delete pr_devengados_tmp where nro_cuenta = p_nro_cuenta;
/* -- Ajuste CROPPACP-3 20/01/2015 --
  Si el pago es en forma Parcial no debe calcular el devengado del dia del cobro */
   if p_cancela != 'P' then
     if nvl(r_pcpre.fec_ult_devengado,r_pcpre.fec_inicio) < p_fecha then
         pap_cob.PR_PRO_DEV_CUOTAS(p_fecha, p_nro_cuenta);
     end if;
   End If;
   --- Recorrer cuotas
   for cuo in c_cuotas loop
      --- Inicializar variables por cuota
      v_sal_capital           := 0;
      v_sal_interes           := 0;
      v_mora                  := 0;
      v_mora_int_ade          := 0;
      v_mora_interes          := 0;
      v_cargo                 := 0;
      v_cargo_iva             := 0;
      v_car_seguro            := 0;
      v_car_adicional         := 0;
      v_car_manual            := 0;
      v_car_manual_iva        := 0;
      v_Car_restante          := 0;
      v_Car_restante_iva      := 0;
      v_int_descontado        := 0;
      v_cap_adelantado        := 0;
      v_mto_ant               := 0;
      v_mto_int_mor_des       := 0;
      v_mto_int_mor_int_des   := 0;
      v_mto_int_mor_ade_des   := 0;
      v_mto_int_pun_des       := 0;
      v_mto_car_des           := 0;
      v_sal_int_ant           := 0;
      v_mto_dev_actual        := 0;   -- DYDMR-2829

      r_pctmp.nro_cuenta      := p_nro_cuenta;
      r_pctmp.nro_cuota       := cuo.nro_cuota;
      r_pctmp.fec_vencimiento := cuo.fec_vencimiento;
      r_pctmp.estado          := cuo.estado;
      r_pctmp.fec_valor       := p_fecha; --fecha valor
      if p_fecha > cuo.fec_vencimiento then
         r_pctmp.dia_mora := p_fecha - cuo.fec_vencimiento;
      else
         r_pctmp.dia_mora := 0;
      end if;
      --- Recuperar saldo capital
      v_sal_capital := PAP_PRE_RES_04.fu_obt_concepto('CA',r_pcpre, cuo, r_pctmp, p_fecha);
      --- Recuperar saldo interes
      v_sal_interes := PAP_PRE_RES_04.fu_obt_concepto('IN',r_pcpre, cuo, r_pctmp, p_fecha);

      -- CRORRCV-1-CRO-Agregado por MS en fecha 01/07/2014
      IF p_cancel_rrr = 'S' THEN
          r_pctmp.mto_capital := 0;
          v_sal_capital := r_pctmp.mto_capital;
          --  Calcula el interés devengado a la fecha
          --  de la cuota que está próxima a vencer.
          IF cuo.fec_vencimiento > p_fecha
          AND cuo.fec_vencimiento > pag_cal.fu_obt_fec_actual(6) THEN
              r_pctmp.mto_interes := pap_cob.fu_obt_dev_anticipado(p_nro_cuenta, cuo.nro_cuota);
              r_pctmp.mto_interes := NVL(r_pctmp.mto_interes, 0)
                                   + NVL(cuo.dev_no_cobrado, 0)
                                   + NVL(cuo.dev_suspenso, 0);
          END IF;
      END IF;

      -- DYDMR-2829 -- 06/2016 : para tener en cuenta el devengado hasta la fecha de cálculo --
      -- DYDMR-4482
      IF NVL(p_cancel_rrr,'N') != 'S' and NVL(P_CANCELA,'N') = 'T' THEN
          IF cuo.fec_vencimiento > pag_cal.fu_obt_fec_actual(6) THEN
              begin
                select nvl(d.mto_dev_actual,0)
                  into v_mto_dev_actual
                  from pr_devengados_tmp d
                 where nro_cuenta = p_nro_cuenta
                   and nro_cuota = cuo.nro_cuota;
              exception
                when others then
                  v_mto_dev_actual := 0;
              end;
              r_pctmp.mto_interes := r_pctmp.mto_interes + v_mto_dev_actual;
          END IF;
      END IF;
      -- DYDMR-2829 --

      -- Fin de agregado
      --- Calcular descuentos segun tipo de cancelacion --- Solo para intereses vencidos
      pap_cob.g_tip_cancelacion := p_cancela;
      pap_cob.g_renueva         := p_renueva;
      v_int_descontado          := PAP_PRE_RES_04.fu_obt_concepto('DE',r_pcpre, cuo, r_pctmp, p_fecha);
      v_sal_interes             := r_pctmp.mto_interes;
      --- Inicializar temporal
      r_pctmp.sal_capital_pre := r_pcpre.sal_capital;
      r_pctmp.sal_interes_pre := r_pcpre.sal_interes;
      r_pctmp.sal_capital_cuo := cuo.sal_capital;
      r_pctmp.sal_interes_cuo := cuo.sal_interes;
      --- Calcular mora capital e interes
      v_mora         := PAP_PRE_RES_04.fu_obt_concepto('MO',r_pcpre, cuo, r_pctmp, p_fecha);
      v_mora_int_ade := PAP_PRE_RES_04.fu_obt_concepto('MA',r_pcpre, cuo, r_pctmp, p_fecha);
      v_mora_interes := PAP_PRE_RES_04.fu_obt_concepto('MI',r_pcpre, cuo, r_pctmp, p_fecha);
      --- Inicializar auxiliar
      r_pctmp.nro_documento       := cuo.nro_documento;
      r_pctmp.fec_ult_pago        := cuo.fec_ult_pago;
      r_pctmp.sal_int_documentado := cuo.sal_int_documentado;
      r_pctmp.mto_int_mor_cal     := v_mora;
      r_pctmp.mto_int_mor_int_cal := v_mora_interes;
      r_pctmp.mto_int_mor_ade_cal := v_mora_int_ade;
      --- Calcular interes punitorio
      v_punitorio              := PAP_PRE_RES_04.fu_obt_concepto('PU',r_pcpre, cuo, r_pctmp, p_fecha);
      r_pctmp.mto_int_pun_cal  := v_punitorio;
      -- Calcula el impuesto calculado
      v_impuesto := 0;
      IF v_exo_impuesto = 'N' Then
        --- Calcular impuesto ley 125/91
        v_impuesto             := PAP_PRE_RES_04.fu_obt_concepto('IM',r_pcpre, cuo, r_pctmp, p_fecha);
      End if;
      r_pctmp.mto_impuesto_cal := v_impuesto;
      --- Calcular cargos
      -- RI : Cuando es Cancelacion Total enviar en la ultima cuota una fecha superior para que tome los
      -- cargos que tienen fecha de vigencia superior al vto. de la ultima cuota
      if cuo.fec_vencimiento =  fu_obt_max_fec_vto(p_nro_cuenta, 999) then
         pap_cob.g_max_fec_calculo := nvl(fu_obt_max_fec_cargo(p_nro_cuenta),fu_obt_max_fec_vto(p_nro_cuenta, 999));
      else
         pap_cob.g_max_fec_calculo := cuo.fec_vencimiento;
      end if;
      v_cargo := PAP_PRE_RES_04.fu_obt_concepto('CG',r_pcpre, cuo, r_pctmp, p_fecha);
      IF v_exo_impuesto = 'N' Then
         v_cargo_iva              := r_pctmp.mto_car_iva_cal;
      End if;
      r_pctmp.mto_cargo_cal    := v_cargo;
      r_pctmp.mto_car_iva_cal  := v_cargo_iva;
      --- Calcular el monto total de la cuota
      v_mto_cuota        := nvl(v_sal_capital,0) + nvl(v_sal_interes,0) +
                            nvl(v_mora,0) + nvl(v_mora_int_ade,0) + nvl(v_mora_interes,0) +
                            nvl(v_punitorio,0) + nvl(v_impuesto,0);
      --- Calcular pagos adelantados segun tipo de cancelacion -- Solo para cancelacion parcial
      --- solo debe entrar en cuando ya no existan cuotas vencidas, y se debe calcular por el saldo del importe ingresado
      --- la cancelacion parcial
      if p_cancela = 'P' and nvl(v_sal_cobrado,0) > 0
      and cuo.fec_vencimiento > p_fecha then
         --- Cancelacion parcial de capital
         if nvl(pap_cob.g_pri_vez,0) = 0 then
            --- Se debe calcular el devengado no cobrado (incluye suspenso) de las cuotas no vencidas a adelantar
            pap_cob.g_dev_no_cobrado  := nvl(cuo.dev_no_cobrado,0)+nvl(cuo.dev_suspenso,0)/*+ pap_cob.fu_obt_dev_anticipado(p_nro_cuenta, cuo.nro_cuota)*/;--Ajuste CROPPACP-3 20/01/2015
            pap_cob.g_cap_pagado      := nvl(v_sal_cobrado,0) -
               (nvl(pap_cob.g_dev_no_cobrado,0) + nvl(v_cargo,0)) -
               (nvl(pap_cob.g_sal_val_interes,0)/* + nvl(pap_cob.g_sal_val_cargos,0)*/);
            if nvl(pap_cob.g_sal_val_interes,0) >  nvl(pap_cob.g_dev_no_cobrado,0) then
               raise_application_error(-20000, 'Interes descontado no debe ser superior al no cobrado');
            end if;
            if nvl(pap_cob.g_tip_cancelacion,'N') = 'P' then
                -- agregado para el cargo sobre cancelacion anticipada parcial----------------------------------------
                --- re Calcular cargos adicionales
                v_cargo := PAP_PRE_RES_04.fu_obt_concepto('CG',r_pcpre, cuo, r_pctmp, p_fecha);
                IF v_exo_impuesto = 'N' Then
                    v_cargo_iva              := r_pctmp.mto_car_iva_cal;
                End if;
                r_pctmp.mto_cargo_cal    := v_cargo;
                r_pctmp.mto_car_iva_cal  := v_cargo_iva;
                -- Modificado por CB 21/05/2012. AP 2961
                IF nvl(pap_cob.g_sal_val_cargos,0) > nvl(v_cargo, 0) THEN
                   pap_cob.g_sal_val_cargos := v_cargo;
                END IF;
                pap_cob.g_cap_pagado      := nvl(v_sal_cobrado,0) -
                   (nvl(pap_cob.g_dev_no_cobrado,0) + nvl(v_cargo,0)) + --AM:06/09/10 (se cambio - por +)
                   (nvl(pap_cob.g_sal_val_interes,0) + nvl(pap_cob.g_sal_val_cargos,0));
                -- fin del agregado-----------------------------------------------------------------------------------
            end if;
            pap_cob.g_tot_int_pag := nvl(pap_cob.g_dev_no_cobrado,0) - nvl(pap_cob.g_sal_val_interes,0);
            --- Se debe guardar el saldo capital total de la primera cuota que va a empezar a recorrer como capital base para los calculos
            pap_cob.g_sal_capital_pre := nvl(r_pctmp.sal_capital_pre,0);
         end if;
         v_cap_adelantado       := PAP_PRE_RES_04.fu_obt_concepto('AC',r_pcpre, cuo, r_pctmp, p_fecha);
         v_sal_capital          := r_pctmp.mto_capital;
         v_int_descontado       := r_pctmp.mto_int_descontado;
         if nvl(pap_cob.g_pri_vez,0) = 0 then
            v_sal_interes       := nvl(pap_cob.g_dev_no_cobrado,0);
            pap_cob.g_pri_vez   := 1;
         else
            if nvl(pap_cob.g_pri_vez,0) = 1 then
               pap_cob.g_pri_vez   := 2;
            end if;
            v_sal_interes       := nvl(cuo.dev_no_cobrado,0)+nvl(cuo.dev_suspenso,0);
         end if;
      end if;
      --- Utilizar autorizaciones si es que existen
      v_sal_int_ant := v_sal_interes;
      lp_uti_aut_pre(pap_cob.g_cod_aut_interes, pap_cob.g_exi_interes, pap_cob.g_sal_val_interes, v_sal_interes);
      if nvl(v_sal_int_ant,0) <> nvl(v_sal_interes,0) then --- Hubo autorizacion de descuento de intereses
         v_int_descontado := nvl(v_int_descontado,0) + (nvl(v_sal_int_ant,0) - nvl(v_sal_interes,0));
      end if;
      v_mto_ant := v_mora;
      lp_uti_aut_pre(pap_cob.g_cod_aut_mor_cap, pap_cob.g_exi_mor_cap, pap_cob.g_sal_val_mor_cap, v_mora);
      If nvl(v_mora,0) != nvl(v_mto_ant,0) Then
         v_mto_int_mor_des := nvl(v_mto_int_mor_des,0) + (nvl(v_mto_ant,0) - nvl(v_mora,0));
      End if;
      v_mto_ant := v_mora_interes;
      lp_uti_aut_pre(pap_cob.g_cod_aut_mor_int, pap_cob.g_exi_mor_int, pap_cob.g_sal_val_mor_int, v_mora_interes);
      If nvl(v_mora_interes,0) != nvl(v_mto_ant,0) Then
         v_mto_int_mor_int_des := nvl(v_mto_int_mor_int_des,0) + (nvl(v_mto_ant,0) - nvl(v_mora_interes,0));
      End if;
      v_mto_ant := v_mora_int_ade;
      lp_uti_aut_pre(pap_cob.g_cod_aut_mor_ade, pap_cob.g_exi_mor_ade, pap_cob.g_sal_val_mor_ade, v_mora_int_ade);
      If nvl(v_mora_int_ade,0) != nvl(v_mto_ant,0) Then
         v_mto_int_mor_ade_des := nvl(v_mto_int_mor_ade_des,0) + (nvl(v_mto_ant,0) - nvl(v_mora_int_ade,0));
      End if;
      v_mto_ant := v_punitorio;
      lp_uti_aut_pre(pap_cob.g_cod_aut_punitorio, pap_cob.g_exi_punitorio, pap_cob.g_sal_val_punitorio, v_punitorio);
      If nvl(v_punitorio,0) != nvl(v_mto_ant,0) Then
         v_mto_int_pun_des := nvl(v_mto_int_pun_des,0) + (nvl(v_mto_ant,0) - nvl(v_punitorio,0));
      End if;
      -- Sobre impuesto no se descuenta!!!
      ---lp_uti_aut_pre(pap_cob.g_cod_aut_impuesto, pap_cob.g_exi_impuesto, pap_cob.g_sal_val_impuesto, v_impuesto);
      --
      --RI: 25/08/2010: No se debe descontar sobre los Cargos Adicionales
      --- Recorre el Cursor de Cargos Adicionales.
      Declare
      Cursor  gastos_varios is
        select *
          from pr_cta_gastos
         where nro_cuenta    = r_pcpre.nro_cuenta
           and cod_modalidad = r_pcpre.cod_modalidad
           and (((fec_ini_vigencia <= pap_cob.g_max_fec_calculo or fec_ini_vigencia is null )
           and  (fec_ini_vigencia >  pap_cob.g_max_fec_calculo_ant or pap_cob.g_max_fec_calculo_ant is null  or fec_ini_vigencia is null)
           and   nro_solicitud is not null)
            or  ((fec_vencimiento  >= pap_cob.g_fec_calculo or fec_vencimiento is null) and nro_solicitud is null and pap_cob.g_cal_adic = 'S'))
           and fec_ult_pago is null;
      Begin
       v_car_adicional := 0;
       v_car_iva_adic  := 0;
       for reg in gastos_varios loop
          v_tra_iva   := null;
          v_car_manual := reg.monto;
          --- Veo si tiene IVA asociada la transaccion del cargo
          lp_obt_tra_iva_asociada(reg.cod_transaccion,reg.cod_modulo,reg.cod_modalidad,v_tra_iva);
          if nvl(v_car_manual,0) > 0 and v_tra_iva is not null then
           -- Se calcula el I.V.A. s/ el Cargo
           v_cod_tasa := null;
           pag_gen.pr_obt_val_tasa(reg.cod_modulo, reg.cod_modalidad,
                                   r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                   0, 'N', v_cod_tasa, v_tra_iva, --Transaccion
                                   pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
           --
           -- es un porcentaje
           v_car_iva      := round((v_car_manual * v_val_tasa / 100),v_redondeo);
           v_car_iva_adic := nvl(v_car_iva_adic,0)+ nvl(v_car_iva,0);
          end if;
          v_Car_adicional := nvl(v_car_adicional,0) + nvl(v_car_manual,0);
       end loop;
       v_car_adicional := nvl(v_car_adicional,0) + nvl(v_car_iva_adic,0);
      End;
      v_cargo   := nvl(v_cargo,0)-nvl(v_car_adicional,0);
      v_cargo_iva := nvl(v_cargo_iva,0)-nvl(v_car_iva_adic,0);
      --Asignar el valor original sin cargos adicionales
      v_mto_ant := v_cargo;
      lp_uti_aut_pre(pap_cob.g_cod_aut_cargos, pap_cob.g_exi_cargos, pap_cob.g_sal_val_cargos, v_cargo);
      If nvl(v_cargo,0) != nvl(v_mto_ant,0) Then
         v_mto_car_des := nvl(v_mto_car_des,0) + (nvl(v_mto_ant,0) - nvl(v_cargo,0));
         --v_cargo_iva   := 0;
         If nvl(v_cargo,0) > 0 then
           --RI: 31/08/2010: Se debe recalcular el Iva (Como iva incluido)
           v_tra_iva := null;
           lp_obt_tra_iva_asociada(712,r_pcpre.cod_modulo,r_pcpre.cod_modalidad,v_tra_iva);
           if v_tra_iva is not null then
             v_cod_tasa := null;
             pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                0, 'N', v_cod_tasa, 517, --Transaccion
                                pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
              v_car_des  := round((v_cargo*100)/(100+v_Val_tasa),v_redondeo);
              v_car_des_iva := round(nvl(v_car_des,0) * (v_val_tasa / 100), v_redondeo);
           end if;
         End if;
      else  --No se desconto nada
         v_car_des_iva := v_cargo_iva;
      End if;
      v_cargo := nvl(v_cargo,0)+nvl(v_car_adicional,0);
      v_cargo_iva := nvl(v_car_iva_adic,0) + nvl(v_car_des_iva,0);
      -- Solo debe calcular el impuesto si no esta exento
      if r_pctmp.dia_mora > 0 then
         P_DIA_MORA := r_pctmp.dia_mora;
      end if;
      ------------------------------------------------------------------------------------
      --- Calcular montos a pagar en base a saldos
      v_sal_int_documentado          := cuo.sal_int_documentado;
      r_pctmp.mto_capital            := v_sal_capital;
      r_pctmp.mto_interes            := v_sal_interes;
      r_pctmp.mto_int_documentado    := v_sal_int_documentado;
      r_pctmp.mto_int_descontado     := v_int_descontado;

      -- DYDMR-2829 -- 06/2016 : para tener en cuenta el devengado hasta la fecha de cálculo --
      IF NVL(p_cancel_rrr,'N') != 'S' THEN
        IF cuo.fec_vencimiento > pag_cal.fu_obt_fec_actual(6) THEN
           r_pctmp.mto_int_descontado  := v_int_descontado - v_mto_dev_actual;
        END IF;
      END IF;
      --

      r_pctmp.mto_int_moratorio      := v_mora;
      r_pctmp.mto_int_mor_interes    := v_mora_interes;
      r_pctmp.mto_int_mor_adelantado := v_mora_int_ade;
      r_pctmp.mto_int_punitorio      := v_punitorio;

      -- Recien aca debe calcular el impuesto porque recien aca tiene los descuentos.
      -- Calcular impuesto ley 125/91
      --
      IF v_exo_impuesto = 'N' Then
         v_cod_tasa := null;

         pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                 r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                 r_pctmp.dia_mora, 'N', v_cod_tasa, 709, --Transaccion
                                 p_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
         v_cal_dia := r_pctmp.dia_mora;
         if v_cal_dia > 365 then
            v_cal_dia := 365;
         end if;
         v_impuesto := 0;
         if nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_mor_interes,0) +
            nvl(r_pctmp.mto_int_mor_adelantado,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0 then

            ---OJO Sacar capital e interes, el impuesto es sobre moratorio y punitorio (ley nueva)
            v_impuesto := round(nvl(r_pctmp.mto_int_moratorio,0) * (v_val_tasa / 100), v_redondeo) +
                   round(nvl(r_pctmp.mto_int_mor_interes,0) * (v_val_tasa / 100), v_redondeo) +
                   round(nvl(r_pctmp.mto_int_mor_adelantado,0) * (v_val_tasa / 100), v_redondeo) +
                   round(nvl(r_pctmp.mto_int_punitorio,0) * (v_val_tasa / 100), v_redondeo);
/*
            v_impuesto := round((
                          nvl(r_pctmp.mto_int_moratorio,0) + nvl(r_pctmp.mto_int_mor_interes,0) +
                          nvl(r_pctmp.mto_int_mor_adelantado,0)+ nvl(r_pctmp.mto_int_punitorio,0))
                          * (v_val_tasa /100), v_redondeo); ---
*/
/*            v_impuesto := round(((nvl(r_pctmp.mto_capital,0) + nvl(r_pctmp.mto_interes,0) + nvl(r_pctmp.mto_int_documentado,0) +
                          nvl(r_pctmp.mto_int_moratorio,0) + nvl(r_pctmp.mto_int_mor_interes,0) +
                          nvl(r_pctmp.mto_int_mor_adelantado,0)+ nvl(r_pctmp.mto_int_punitorio,0))
                          * v_val_tasa * v_cal_dia / 36500), v_redondeo);
*/       end if;
         ---RI : 28/05/2010 aqui le suma el impuesto sobre el interes si el mismo
         --- no fue cobrado en el desembolso, no se está calculando iva
         --- sobre interes adelantado.
          if nvl(v_iva,0) = 0 then
             -- RI : 15/06/2010: si la cuota esta vencida guardar el monto
             -- del iva en campo auxiliar para generar despues una transaccion
             -- diferenciada por ese monto
             If cuo.fec_vencimiento < p_fecha then
                /*
                || DYDMR-939
                || Para el impuesto sobre el interés
                || Debe tomar la tasa a partir de la fecha de la cuota
                */
                v_cod_tasa := null;
                pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                        r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                        r_pctmp.dia_mora, 'N', v_cod_tasa, 709, --Transaccion
                                        cuo.fec_vencimiento, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
                ---
                pap_cob.g_iva_interes := round(nvl(r_pctmp.mto_interes,0) * (v_val_tasa / 100), v_redondeo);
             else
                pap_cob.g_iva_interes := 0;
             end if;
             v_impuesto := nvl(v_impuesto,0)+
                           round(nvl(r_pctmp.mto_interes,0) * (v_val_tasa / 100), v_redondeo);
          End if;
      End if;

      r_pctmp.mto_cargo           := v_cargo;
      r_pctmp.mto_cargo_iva       := v_cargo_iva;
      r_pctmp.mto_impuesto        := v_impuesto;
      --
      r_pctmp.mto_int_mor_des     := v_mto_int_mor_des;
      r_pctmp.mto_int_mor_int_des := v_mto_int_mor_int_des;
      r_pctmp.mto_int_mor_ade_des := v_mto_int_mor_ade_des;
      r_pctmp.mto_int_pun_des     := v_mto_int_pun_des;
      r_pctmp.mto_car_des         := v_mto_car_des;
      --  Datos del devengado de cada cuota.
      r_pctmp.dev_acumulado  := cuo.dev_acumulado;
      r_pctmp.dev_suspenso   := cuo.dev_suspenso;
      r_pctmp.dev_no_cobrado := cuo.dev_no_cobrado;

      --RI : 28/07/2010 : El monto a pagar debe cubrir por lo menos los cargos
      if v_sal_cobrado < v_cargo then
        p_error   := 21;
        p_mensaje := 'El monto a pagar debe cubrir por lo menos los cargos.';
        return;
      End if;

      if  v_sal_cobrado is not null and v_sal_cobrado <
         (nvl(r_pctmp.mto_capital,0)+nvl(r_pctmp.mto_interes,0)+nvl(r_pctmp.mto_int_documentado,0)+
          nvl(r_pctmp.mto_int_moratorio,0)+nvl(r_pctmp.mto_int_mor_interes,0)+
          nvl(r_pctmp.mto_int_mor_adelantado,0)+nvl(r_pctmp.mto_int_punitorio,0)+
          nvl(r_pctmp.mto_cargo,0)+nvl(r_pctmp.mto_impuesto,0))
          then
         --- Inicializar variables de cobro
         r_pctmp.mto_capital            := 0;
         r_pctmp.mto_interes            := 0;
         r_pctmp.mto_int_documentado    := 0;
         r_pctmp.mto_int_moratorio      := 0;
         r_pctmp.mto_int_mor_interes    := 0;
         r_pctmp.mto_int_mor_adelantado := 0;
         r_pctmp.mto_cargo              := 0;
         r_pctmp.mto_cargo_iva          := 0;
         r_pctmp.mto_impuesto           := 0;
         r_pctmp.mto_int_punitorio      := 0;
         ---
         v_impuesto := 0;
         pap_cob.g_iva_interes := 0;
         --- Recorrer prioridades de cobro
         --- Obtener tasa de impuestos , ojo 709 es para moratorio y punitorio
         v_cal_dia := 0;
         If v_exo_impuesto = 'N' Then
             v_cod_tasa := null;
             v_val_tasa := null;
             pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                     r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                     r_pctmp.dia_mora, 'N', v_cod_tasa, 709, --Transaccion
                                     p_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
             v_cal_dia := r_pctmp.dia_mora;
             if r_pctmp.dia_mora > 365 then
                v_cal_dia := 365;
             end if;
             v_cod_tasa := null;
             pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                             r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                             r_pctmp.dia_mora, 'N', v_cod_tasa, 517, --Transaccion
                             p_fecha, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);
             v_cal_fac_iva := 100 / (100 + v_val_tas_iva);
         End if;
         for pri in c_prioridades loop
            v_cal_ley := 0;
            v_cal_fac := 0;
            v_cal_iva := 0; --EF, 09/06/2010
            if pri.concepto = 'CA' and nvl(v_sal_capital,0) > 0 then --- capital
               -- debe controlar sumando el monto de la ley 125
               v_cal_ley := 0;
               v_cal_fac := 0;
               --- Obtener tasa de impuestos
/*               If v_exo_impuesto = 'N'
               and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_mor_interes,0) +
                    nvl(r_pctmp.mto_int_mor_adelantado,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then --- OBS: Falta confirmar
---                   v_cal_ley := round(v_sal_capital * v_val_tasa * v_cal_dia / 36500, v_redondeo);
---OJO, ya no se cobra impuesto sobre capital
                    v_cal_ley := 0;
               End if;*/
               ---
              if v_sal_cobrado > v_sal_capital+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_sal_capital + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' then
/*                 and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_mor_interes,0) +
                      nvl(r_pctmp.mto_int_mor_adelantado,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0)  Then*/
--OJO, ya no se cobra impuesto sobre capital
--                   v_cal_fac     := (v_val_tasa * v_cal_dia / 36500) + 1;
--                   v_sal_capital := round((v_sal_cobrado/v_cal_fac), v_redondeo);
--                   v_sal_cobrado := v_sal_cobrado - v_sal_capital;--ojo daria negativo
--                   v_impuesto    := v_impuesto + v_sal_cobrado;
                   v_sal_capital := v_sal_cobrado;
                 else
                   v_sal_capital := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;
              r_pctmp.mto_capital  := v_sal_capital;
              r_pctmp.mto_impuesto := v_impuesto;
            elsif pri.concepto = 'IN' and nvl(v_sal_interes,0) > 0 then --- interes
               -- debe controlar sumando el monto de la ley 125
               v_cal_ley := 0;
               v_cal_fac := 0;
               v_cal_iva := 0; --EF, 09/06/2010
               pap_cob.g_iva_interes := 0;
               --- Obtener tasa de impuestos
/*               If v_exo_impuesto = 'N'
               and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_mor_interes,0) +
                    nvl(r_pctmp.mto_int_mor_adelantado,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then --- OBS: Falta confirmar
--                   v_cal_ley := round(v_sal_interes * v_val_tasa * v_cal_dia / 36500, v_redondeo);
---OJO, ya no se cobra impuesto sobre interes
                    v_cal_ley := 0;
               End if;
*/
              ---EF 09/06/2010, sumar el IVA si no se cobro en el Desembolso.
              if nvl(v_iva,0) = 0 then
                 --v_cal_iva := round(nvl(v_sal_interes,0) * (v_val_tasa / 100), v_redondeo);
/*                 --RI : 15/06/2010: si la cuota esta vencida guardar el monto
                 --del iva en campo auxiliar para generar despues una transaccion
                 --diferenciada por ese monto
                 If cuo.fec_vencimiento < p_fecha then
                   pap_cob.g_iva_interes := v_cal_iva;
                 else
                   pap_cob.g_iva_interes := 0;
                 end if;  */

                 If cuo.fec_vencimiento < p_fecha then

                   v_val_tasa := null;
                   v_cod_tasa := null;

                   pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                           r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                           r_pctmp.dia_mora, 'N', v_cod_tasa, 709, --Transaccion
                                           cuo.fec_vencimiento, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
                 else
                   pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                           r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                           r_pctmp.dia_mora, 'N', v_cod_tasa, 709, --Transaccion
                                           p_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
                 end if;

                 v_cal_iva := round(nvl(v_sal_interes,0) * (v_val_tasa / 100), v_redondeo);


              end if;
               ---
              if v_sal_cobrado > v_sal_interes+v_cal_ley+v_cal_iva then
                 v_sal_cobrado := v_sal_cobrado - (v_sal_interes + v_cal_ley + v_cal_iva);
                  v_impuesto    := v_impuesto + v_cal_ley + v_cal_iva;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' then
--RI : 06/08/2010 :se quita esta condicion, debe entrar a evaluar si tiene o no iva y calcular lo que se
--puede cobrar de interes
/*                 and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_mor_interes,0) +
                      nvl(r_pctmp.mto_int_mor_adelantado,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then*/
--OJO, ya no se cobra impuesto sobre interes
--                   v_cal_fac     := (v_val_tasa * v_cal_dia / 36500) + 1;
--                   v_sal_interes := round((v_sal_cobrado/v_cal_fac), v_redondeo);
--                   v_sal_cobrado := v_sal_cobrado - v_sal_interes;
--                   v_impuesto    := v_impuesto + v_sal_cobrado;
--
                   -- RI:29/07/2010: Cuando el saldo no cubre el interes mas el iva
                   -- entonces se asigna el saldo como interes, pero debe recalcularse
                   -- el iva sobre ese interes.
                   If nvl(v_cal_iva,0) > 0 then
                      v_sal_interes := round((v_sal_cobrado*100)/(100+v_Val_tasa),v_redondeo);
                      v_cal_iva := round(nvl(v_sal_interes,0) * (v_val_tasa / 100), v_redondeo);
                      --Ajustar si no da el monto exacto
                      If v_sal_cobrado > v_sal_interes+v_cal_iva then
                         v_sal_interes := v_sal_interes + (v_sal_cobrado-(v_sal_interes+v_cal_iva));
                      elsif v_sal_cobrado < v_sal_interes+v_cal_iva then
                         v_sal_interes := v_sal_interes - ((v_sal_interes+v_cal_iva)-v_sal_cobrado);
                      end if;
/*                      --RI : 15/06/2010: si la cuota esta vencida guardar el monto
                      --del iva en campo auxiliar para generar despues una transaccion
                      --diferenciada por ese monto
                      If cuo.fec_vencimiento < p_fecha then
                        pap_cob.g_iva_interes := v_cal_iva;
                      else
                        pap_cob.g_iva_interes := 0;
                      end if;
*/                      v_impuesto    := nvl(v_impuesto,0) + nvl(v_cal_iva,0);
                   else
                     v_sal_interes := v_sal_cobrado;
                   End if;
                 else
                   v_sal_interes := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;

              r_pctmp.mto_interes  := v_sal_interes;
              r_pctmp.mto_impuesto := v_impuesto;
            elsif pri.concepto = 'IA' and nvl(v_sal_int_documentado,0) > 0 then --- interes adelantado
               -- debe controlar sumando el monto de la ley 125
               v_cal_ley := 0;
               v_cal_fac := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N'
               and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_mor_interes,0) +
                    nvl(r_pctmp.mto_int_mor_adelantado,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then --- OBS: Falta confirmar
--                   v_cal_ley := round(v_sal_int_documentado * v_val_tasa * v_cal_dia / 36500, v_redondeo);
---OJO, ya no se cobra impuesto sobre interes
                     v_cal_ley := 0;
               End if;
               ---
              if v_sal_cobrado > v_sal_int_documentado+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_sal_int_documentado + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N'
                 and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_mor_interes,0) +
                      nvl(r_pctmp.mto_int_mor_adelantado,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then
--OJO,ya no se cobra impuesto sobre interes
--                   v_cal_fac     := (v_val_tasa * v_cal_dia / 36500) + 1;
--                   v_sal_int_documentado := round((v_sal_cobrado/v_cal_fac), v_redondeo);
--                   v_sal_cobrado := v_sal_cobrado - v_sal_int_documentado;
--                   v_impuesto    := v_impuesto + v_sal_cobrado;
                   v_sal_int_documentado := v_sal_cobrado;
                 else
                   v_sal_int_documentado := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;
              r_pctmp.mto_int_documentado := v_sal_int_documentado;
              r_pctmp.mto_impuesto := v_impuesto;
            elsif pri.concepto = 'MO' and nvl(v_mora,0) > 0 then --- mora s/capital
               --
               v_cal_ley := 0;
               v_cal_fac := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                  v_cal_ley := round(v_mora * (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_mora+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_mora + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   --RI: 30/07/2010 : Aca estaba calculando mal la base
                   --y el iva con el saldo restante.
                   /*
                   v_cal_fac     := (v_val_tasa / 100) + 1;
                   v_mora        := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado := v_sal_cobrado - v_mora;
                   v_impuesto    := v_impuesto + v_sal_cobrado;
                   */
                   --
                    v_mora := round((v_sal_cobrado*100)/(100+v_Val_tasa),v_redondeo);
                    v_cal_iva := round(nvl(v_mora,0) * (v_val_tasa / 100), v_redondeo);
                    --Ajustar si no da el monto exacto
                    If v_sal_cobrado > v_mora+v_cal_iva then
                       v_mora := v_mora + (v_sal_cobrado-(v_mora+v_cal_iva));
                    elsif v_sal_cobrado < v_mora+v_cal_iva then
                       v_mora := v_mora - ((v_mora+v_cal_iva)-v_sal_cobrado);
                    end if;
                    v_impuesto := nvl(v_impuesto,0) + nvl(v_cal_iva,0);
                 else
                   v_mora := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;
              r_pctmp.mto_int_moratorio   := v_mora;
              r_pctmp.mto_impuesto        := v_impuesto;
            elsif pri.concepto = 'MI' and nvl(v_mora_interes,0) > 0 then --- mora s/interes
               v_cal_ley := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                  v_cal_ley := round(v_mora_interes * (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_mora_interes+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_mora_interes + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   --RI: 30/07/2010 : Aca estaba calculando mal la base
                   --y el iva con el saldo restante.
                   /*
                   v_cal_fac      := (v_val_tasa / 100) + 1;
                   v_mora_interes := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado  := v_sal_cobrado - v_mora_interes;
                   v_impuesto     := v_impuesto + v_sal_cobrado;
                   */
                   --
                    v_mora_interes := round((v_sal_cobrado*100)/(100+v_Val_tasa),v_redondeo);
                    v_cal_iva := round(nvl(v_mora_interes,0) * (v_val_tasa / 100), v_redondeo);
                    --Ajustar si no da el monto exacto
                    If v_sal_cobrado > v_mora_interes+v_cal_iva then
                       v_mora_interes := v_mora_interes + (v_sal_cobrado-(v_mora_interes+v_cal_iva));
                    elsif v_sal_cobrado < v_mora_interes+v_cal_iva then
                       v_mora_interes := v_mora_interes - ((v_mora_interes+v_cal_iva)-v_sal_cobrado);
                    end if;
                    v_impuesto := nvl(v_impuesto,0) + nvl(v_cal_iva,0);
                 else
                   v_mora_interes := v_sal_cobrado;
                 end if;
                 v_sal_cobrado  := 0;
              end if;
              r_pctmp.mto_int_mor_interes := v_mora_interes;
              r_pctmp.mto_impuesto        := v_impuesto;
            elsif pri.concepto = 'MA' and nvl(v_mora_int_ade,0) > 0 then --- mora s/int.adelantado
               v_cal_ley := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                  v_cal_ley := round(v_mora_int_ade * (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_mora_int_ade+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_mora_int_ade + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   --RI: 30/07/2010 : Aca estaba calculando mal la base
                   --y el iva con el saldo restante.
                   /*
                   v_cal_fac      := (v_val_tasa / 100) + 1;
                   v_mora_int_ade := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado  := v_sal_cobrado - v_mora_int_ade;
                   v_impuesto     := v_impuesto + v_sal_cobrado;*/
                   --
                   v_mora_int_ade := round((v_sal_cobrado*100)/(100+v_Val_tasa),v_redondeo);
                   v_cal_iva := round(nvl(v_mora_int_ade,0) * (v_val_tasa / 100), v_redondeo);
                   --Ajustar si no da el monto exacto
                   If v_sal_cobrado > v_mora_int_ade+v_cal_iva then
                      v_mora_int_ade := v_mora_int_ade + (v_sal_cobrado-(v_mora_int_ade+v_cal_iva));
                   elsif v_sal_cobrado < v_mora_int_ade+v_cal_iva then
                      v_mora_int_ade := v_mora_int_ade - ((v_mora_int_ade+v_cal_iva)-v_sal_cobrado);
                   end if;
                   v_impuesto := nvl(v_impuesto,0) + nvl(v_cal_iva,0);
                 Else
                   v_mora_int_ade := v_sal_cobrado;
                 End if;
                 v_sal_cobrado  := 0;
              end if;
              r_pctmp.mto_int_mor_adelantado := v_mora_int_ade;
              r_pctmp.mto_impuesto        := v_impuesto;
            elsif pri.concepto = 'CG' and nvl(v_cargo,0) > 0 then --- cargos
              -- Calcular el iva y controlar antes de cobrar algo.
              if v_sal_cobrado >= v_cargo then  --RI:28/07/2010 : se agrego la condicion igual (=)
                 v_sal_cobrado := v_sal_cobrado - v_cargo;
              else
                 --- Calcular cuanto corresponde a impuesto
                 v_cargo      := round(v_sal_cobrado * v_cal_fac_iva,v_redondeo);
                 -----
                 v_cargo_iva  := v_sal_cobrado - v_cargo;
                 v_cargo      := v_cargo + v_cargo_iva;
                 v_sal_cobrado := 0;
              end if;
              r_pctmp.mto_cargo           := v_cargo;
              r_pctmp.mto_cargo_iva       := v_cargo_iva;

/*            El impuesto debe calcular por cada concepto.
              elsif pri.concepto = 'IM' and nvl(v_impuesto,0) > 0 then --- impuesto
              if v_sal_cobrado > v_impuesto  then
                 v_sal_cobrado := v_sal_cobrado - v_impuesto;
              else
                 v_impuesto := v_sal_cobrado;
                 v_sal_cobrado := 0;
              end if;
              r_pctmp.mto_impuesto        := v_impuesto;
*/            elsif pri.concepto = 'PU' and nvl(v_punitorio,0) > 0 then --- punitorio
               v_cal_ley := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                   v_cal_ley := round(v_punitorio *  (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_punitorio+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_punitorio + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   --RI: 30/07/2010 : Aca estaba calculando mal la base
                   --y el iva con el saldo restante.
                   /*
                   v_cal_fac      := (v_val_tasa / 100) + 1;
                   v_punitorio := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado  := v_sal_cobrado - v_punitorio;
                   v_impuesto     := v_impuesto + v_sal_cobrado;
                   */
                   --
                   v_punitorio := round((v_sal_cobrado*100)/(100+v_Val_tasa),v_redondeo);
                   v_cal_iva := round(nvl(v_punitorio,0) * (v_val_tasa / 100), v_redondeo);
                   --Ajustar si no da el monto exacto
                   If v_sal_cobrado > v_punitorio+v_cal_iva then
                      v_punitorio := v_punitorio + (v_sal_cobrado-(v_punitorio+v_cal_iva));
                   elsif v_sal_cobrado < v_punitorio+v_cal_iva then
                      v_punitorio := v_punitorio - ((v_punitorio+v_cal_iva)-v_sal_cobrado);
                   end if;
                   v_impuesto := nvl(v_impuesto,0) + nvl(v_cal_iva,0);
                 Else
                   v_punitorio := v_sal_cobrado;
                 End if;
                 v_sal_cobrado  := 0;
              end if;
              r_pctmp.mto_int_punitorio   := v_punitorio;
              r_pctmp.mto_impuesto        := v_impuesto;
            end if;
            if v_sal_cobrado = 0 then
               exit; --- Salir del ciclo si no queda saldo a pagar por el cliente
            end if;
         end loop;
      elsif v_sal_cobrado is not null then
         v_sal_cobrado := v_sal_cobrado - (nvl(r_pctmp.mto_capital,0)+nvl(r_pctmp.mto_interes,0)+nvl(r_pctmp.mto_int_documentado,0)+
                          nvl(r_pctmp.mto_int_moratorio,0)+nvl(r_pctmp.mto_int_mor_interes,0)+
                          nvl(r_pctmp.mto_int_mor_adelantado,0)+nvl(r_pctmp.mto_int_punitorio,0)+
                          nvl(r_pctmp.mto_cargo,0)+nvl(r_pctmp.mto_impuesto,0));
      end if;
      ---Calcular nuevamente el iva s/interes vencido si corresponde
      -- Si la cuota esta vencida guardar el monto
      -- del iva en campo auxiliar para generar despues una transaccion
     -- diferenciada por ese monto
      If cuo.fec_vencimiento < p_fecha and v_iva = 0 then
         pap_cob.g_iva_interes := round(nvl(r_pctmp.mto_interes,0) * (v_val_tasa / 100), v_redondeo);
      else
         pap_cob.g_iva_interes := 0;
      end if;

      -- CRORRCV-1-CRO-Agregado por MS en fecha 01/07/2014
      IF NVL(p_cancel_rrr, 'N') = 'S' THEN
          r_pctmp.mto_capital := 0;
          --  Calcula el interés devengado a la fecha
          --  de la cuota que está próxima a vencer.
          IF cuo.fec_vencimiento > p_fecha
          AND cuo.fec_vencimiento > pag_cal.fu_obt_fec_actual(6) THEN
              r_pctmp.mto_interes := pap_cob.fu_obt_dev_anticipado(p_nro_cuenta, cuo.nro_cuota);
              r_pctmp.mto_interes := NVL(r_pctmp.mto_interes, 0)
                                   + NVL(r_pctmp.dev_no_cobrado, 0)
                                   + NVL(r_pctmp.dev_suspenso, 0);
               IF NVL(pap_cob.g_sal_val_interes,0) >  NVL(r_pctmp.mto_interes,0) THEN
                 RAISE_APPLICATION_ERROR(-20000, 'Interes descontado no debe ser superior al no cobrado (3R)');
              END IF;
          END IF;
      END IF;
      -- Fin de agregado
      --- Insertar tabla de cobro temporal
      lp_ins_pr_cobros_tmp(r_pctmp);
      --- Ajustar saldos del prestamo, esto es cuando se procesa mas de una cuota
      --- puede afectar a los calculos de intereses descontados
      r_pcpre.sal_capital := nvl(r_pcpre.sal_capital,0) - nvl(r_pctmp.mto_capital,0);
      r_pcpre.sal_interes := nvl(r_pcpre.sal_interes,0) - (nvl(r_pctmp.mto_int_descontado,0) +
                             nvl(r_pctmp.mto_interes,0));
      --
      if nvl(r_pcpre.val_int_devengar,0) > 0 then
         if nvl(r_pcpre.val_int_devengar,0) >= nvl(r_pcpre.val_int_devengar,0) - nvl(r_pctmp.mto_int_descontado,0) then
            r_pcpre.val_int_devengar := nvl(r_pcpre.val_int_devengar,0) - nvl(r_pctmp.mto_int_descontado,0);
         else
            r_pcpre.val_int_devengar := 0; --- El descontado cubre todo el a devengar
         end if;
      end if;
      --- Totalizar importes
      v_tot_capital      := nvl(v_tot_capital,0) + nvl(r_pctmp.mto_capital,0);
      v_tot_interes      := nvl(v_tot_interes,0) + nvl(r_pctmp.mto_interes,0);
      v_tot_int_adelantado := nvl(v_tot_int_adelantado,0) + nvl(r_pctmp.mto_int_documentado,0);
      v_tot_int_descontado := nvl(v_tot_int_descontado,0) + nvl(r_pctmp.mto_int_descontado,0);
      v_tot_mora         := nvl(v_tot_mora,0) + nvl(r_pctmp.mto_int_moratorio,0);
      v_tot_mora_int_ade := nvl(v_tot_mora_int_ade,0) + nvl(r_pctmp.mto_int_mor_adelantado,0);
      v_tot_mora_interes := nvl(v_tot_mora_interes,0) + nvl(r_pctmp.mto_int_mor_interes,0);
      v_tot_cargo        := nvl(v_tot_cargo,0) + nvl(r_pctmp.mto_cargo,0);
      v_tot_cargo_iva    := nvl(v_tot_cargo_iva,0) + nvl(r_pctmp.mto_cargo_iva,0);
      v_tot_impuesto     := nvl(v_tot_impuesto,0) + nvl(r_pctmp.mto_impuesto,0);
      v_tot_punitorio    := nvl(v_tot_punitorio,0) + nvl(r_pctmp.mto_int_punitorio,0);
      if v_sal_cobrado is not null and v_sal_cobrado = 0 then
         exit; --- Salir del ciclo si no queda saldo a pagar por el cliente
      end if;
      -- RI : 20/05/2010: Verificar si ya calculo cargos (pr_cta_gastos)
      -- que no corresponden a seguros (nro_solicitud is null)
      -- para que no vuelva a calcular en la sigte. cuota , se debe
      -- calcular una sola vez
      Select sum(monto) into v_car_adic
        from pr_cta_gastos
       where nro_cuenta = r_pcpre.nro_cuenta
         and (fec_vencimiento  >= pap_cob.g_fec_calculo or fec_vencimiento is null)
         and fec_ult_pago is null
         and nro_solicitud is null;
      if v_car_adic > 0 then
         pap_cob.g_cal_adic := 'N';
      end if;
      --
      pap_cob.g_max_fec_calculo_ant := pap_cob.g_max_fec_calculo;
   end loop;
      --
   --- Cargar parametros de salida
   p_tot_capital      := v_tot_capital;
   p_tot_interes      := v_tot_interes;
   p_tot_mora         := v_tot_mora;
   p_tot_mora_interes := v_tot_mora_interes;
   p_tot_mora_int_ade := v_tot_mora_int_ade;
   p_tot_cargo        := v_tot_cargo;
   p_tot_cargo_iva    := v_tot_cargo_iva;
   p_tot_impuesto     := v_tot_impuesto;
   p_tot_punitorio    := v_tot_punitorio;
   p_tot_int_descontado := v_tot_int_descontado;
   p_tot_int_adelantado := v_tot_int_adelantado;
END;
/* Realizar el cobro del prestamo. */
PROCEDURE PR_COB_PRESTAMO
 (P_NRO_CUENTA       IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_MTO_COBRADO      IN PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 ,P_PED_AUTORIZACION IN VARCHAR2
 ,P_COD_OFI_ORIGEN   IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE
 ,P_NRO_CUO_DESDE    IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_NRO_CUO_HASTA    IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_CONCEPTO         IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_FECHA            IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA             IN OUT GE_MOVIMIENTOS.HORA%TYPE
 ,P_NRO_SECUENCIA    IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_COD_TRA_PADRE    IN NUMBER default 360
 ,P_COD_MOD_PADRE    IN NUMBER
 ,P_COD_MAD_PADRE    IN NUMBER
 ,P_CANCELACION      IN VARCHAR2 default 'N'
 ,P_COD_MAD_RRR      IN PR_CTA_PRESTAMOS.COD_MODALIDAD%TYPE DEFAULT NULL
 ,P_RENUEVA          IN VARCHAR2 default 'N'
 ,P_ESTADO           IN VARCHAR2 DEFAULT 'N' -- AJUSTE Control Dual Fase 2
 ,P_CANCEL_RRR        IN VARCHAR2 DEFAULT 'N'
 ,P_COD_USUARIO      IN VARCHAR2 DEFAULT USER
 )
 IS

v_mto_ori_fondo number;
v_mto_cap_original number;
v_redondeo number(2);
v_dev_no_cobrado number;
rv_soli pr_solicitudes%rowtype;
v_sol_cargo number;
v_sol_int_adelantado number;
v_dias_reversar number;
v_mto_dev_total number;
v_dev_diario number;
v_dev_no_cob_rev number;
v_vta_cartera number;
v_una_vez varchar2(1) := 'S';
v_cot_factura cb_lib_ventas_det_tmp.cotizacion%type;
v_ori_fon_propio pr_cta_prestamos.cod_ori_fondo%type;
v_cod_transaccion  ge_movimientos.cod_transaccion%type;
v_fec_tasa  date;
v_iva_desglose varchar2(1);
v_est_modulo ba_modulos.estado%type := 2; -- Modulo Abierto DYDMR-4575 NAF. Sep/2016
v_horario     varchar2(1)  := 'D'; -- Dia normal DYDMR-4575 NAF. Sep/2016
v_es_nocturno varchar2(1) := 'N'; -- No es Nocturno DYDMR-4575 NAF. Sep/2016

/* Actualizar devengado no cobrado */
PROCEDURE LP_ACT_DEV_NOCOB
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_SAL_INTERES IN PR_CUOTAS.SAL_INTERES%TYPE
 ,P_SAL_INT_DOCUMENTADO IN PR_CUOTAS.SAL_INT_DOCUMENTADO%TYPE
 ,P_TIP_INTERES IN PR_CTA_PRESTAMOS.TIP_INTERES%TYPE
 );
/* veo si tiene IVA asociada a la transaccion */
PROCEDURE LP_OBT_TRA_IVA_ASOCIADA
 (P_COD_TRANSACCION IN  GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO      IN  GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD   IN  GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_TRA_IVA         OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 );
/* Obtener monto de la mora original. */
FUNCTION LF_OBT_MORA_ORIGINAL
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 )
 RETURN NUMBER;
/* Insertar cobro de prestamo. */
PROCEDURE LP_INS_PR_COBROS
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 );
/* Utilizar autorizacion */
PROCEDURE LP_UTI_AUTORIZACION
 (P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 );
--- Datos del registros de cuentas
   r_pcpre         pr_cta_prestamos%rowtype;
   r_pcuot         pr_cuotas%rowtype;
   r_gmovi         ge_movimientos%rowtype;
   v_sal_cobrado   pr_cuotas.sal_capital%type;
   v_sal_capital   pr_cuotas.sal_capital%type;
   v_sal_interes   pr_cuotas.sal_interes%type;
   v_sal_int_ade   pr_cuotas.sal_int_documentado%type;
   v_mora          pr_cuotas.sal_interes%type;
   v_mora_interes  pr_cuotas.sal_interes%type;
   v_mora_int_ade  pr_cuotas.sal_interes%type;
   v_impuesto      pr_cuotas.sal_interes%type;
   v_cargo         pr_cuotas.sal_interes%type;
   v_cargo_iva     pr_cuotas.sal_interes%type;
   v_tot_Car_adic  pr_cuotas.sal_interes%type;
   v_car_adic      pr_cuotas.sal_interes%type;
   v_iva_adic      pr_cuotas.sal_interes%type;
   v_otros_Cargos  pr_cuotas.sal_interes%type;
   --v_seguro        pr_cuotas.sal_interes%type;
   v_punitorio     pr_cuotas.sal_interes%type;
   v_int_descontado pr_cuotas.sal_interes%type;
   v_mto_cuota     pr_cuotas.sal_capital%type;
   v_cancela       varchar2(01);
   v_error         number(05);
   v_mensaje       varchar2(1000);
   v_tot_pag_cap   pr_cta_prestamos.sal_capital%type;
   v_pre_sal_cap   pr_cta_prestamos.sal_capital%type;
   v_cal_dev_nocob varchar2(01);
   v_est_cuota     pr_cuotas.estado%type;
   v_can_prestamo  varchar2(01);
   v_mora_original pr_cta_prestamos.sal_interes%type;
   v_dia_mora      number(05);
   --- Variables de movimientos
   v_fecha         ge_movimientos.fecha%type;
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   v_hora          ge_movimientos.hora%type;
   v_est_movim     ge_movimientos.estado%type;
   v_fec_ult_dev   pr_cta_prestamos.fec_ult_devengado%type;
   v_cotizacion    ge_movimientos.cotizacion%type;
   --- variables para ver gastos varios
   v_cta_gastos    pr_cta_gastos.monto%type;
   --tasas
   v_val_tas_impuesto ge_movimientos.val_tasa%type;
   v_val_tas_iva      ge_movimientos.val_tasa%type;
   v_val_tasa         ge_movimientos.val_tasa%type;
   v_fec_vigencia     ge_tas_fechas.fec_vigencia%type;
   v_tip_valor        ge_tasas.tip_valor%type;
   v_tipo             ge_tasas.tipo%type;
   v_cod_tasa         ge_tasas.cod_tasa%type;
   v_tra_iva          ge_transacciones.cod_transaccion%type;
   --Variables para actualizar mto.aplicado de las garantias
   v_tot_sal_cap    pr_cuotas.sal_capital%type;
   v_tot_sal_int    pr_cuotas.sal_interes%type;
   v_tot_desaplicar pr_cta_garantias.mto_aplicado%type;
   v_mens_error     varchar2(100);
   --Variable auxiliar para Calculo de Gastos, Fecha: 13/05/2010
   v_max_fec_cal_ant_aux date;
   --
   v_cal_adic_aux varchar2(1);
   v_cal_iva_interes number;
   v_iva             number;
   v_iva_facturado   number;
   --- Cursor de cuotas a cobrar
   Cursor c_cuotas is
   Select *
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and (nvl(sal_capital,0) <> 0 or
           nvl(sal_interes,0) <> 0 or
           nvl(sal_int_documentado,0) <> 0 ) -- Cuotas con saldo
      and nro_cuota >= nvl(p_nro_cuo_desde,0)
      and nro_cuota <= nvl(p_nro_cuo_hasta,999)
    order by fec_vencimiento;
   --Cursor de garantias
    Cursor garantias is
    Select cod_garantia,nro_garantia,mto_aplicado
     from pr_cta_garantias
     where nro_cuenta = p_nro_cuenta;

/* Actualizar devengado no cobrado */
PROCEDURE LP_ACT_DEV_NOCOB
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_SAL_INTERES IN PR_CUOTAS.SAL_INTERES%TYPE
 ,P_SAL_INT_DOCUMENTADO IN PR_CUOTAS.SAL_INT_DOCUMENTADO%TYPE
 ,P_TIP_INTERES IN PR_CTA_PRESTAMOS.TIP_INTERES%TYPE
 )
 IS
v_val_interes   pr_cta_prestamos.dev_acumulado%type;
BEGIN
   v_val_interes := nvl(p_sal_interes,0) + nvl(p_sal_int_documentado,0);
   if  v_val_interes > 0        -- Se disminuye el dev.no cob., si se cobra
   and p_tip_interes = 'V' then -- el interes y si es NDocumentado
      update pr_cta_prestamos
         set dev_no_cobrado = nvl(dev_no_cobrado,0) - v_val_interes
       where nro_cuenta = p_nro_cuenta;
   end if;
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000,'Act.Dev. '||sqlerrm);
      end if;
END;
/* veo si tiene IVA asociada a la transaccion */
PROCEDURE LP_OBT_TRA_IVA_ASOCIADA
 (P_COD_TRANSACCION IN  GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO      IN  GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD   IN  GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_TRA_IVA         OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 )
 IS
BEGIN
  -- Se asume que si tiene una transaccion detallada este es de impuesto.
  select cod_tra_hijo
    into p_tra_iva
    from ge_transacciones_det
   where cod_transaccion = p_cod_transaccion
     and cod_modulo      = p_cod_modulo
     and cod_modalidad   = p_cod_modalidad;
EXCEPTION
      when no_data_found then
           p_tra_iva := null;
END;
/* Obtener monto de la mora original. */
FUNCTION LF_OBT_MORA_ORIGINAL
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 )
 RETURN NUMBER
 IS
BEGIN
   return 0;
END;
/* Insertar cobro de prestamo. */
PROCEDURE LP_INS_PR_COBROS
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 )
 IS
BEGIN
   insert into pr_cobros
     (nro_cuenta, nro_cuota, fecha, hora, fec_vencimiento, estado,
      sal_capital_pre, sal_interes_pre, sal_capital_cuo, sal_interes_cuo,
      sal_int_documentado, fec_ult_pago, dia_mora,
      mto_capital, mto_interes, mto_int_documentado, mto_int_moratorio,
      mto_int_mor_interes, mto_int_mor_adelantado, mto_int_punitorio,
      mto_cargo, mto_cargo_iva, mto_impuesto, mto_int_descontado,
      nro_documento, mto_int_mor_cal, mto_int_mor_int_cal,
      mto_int_mor_ade_cal, mto_int_pun_cal, mto_cargo_cal,
      mto_car_iva_cal, mto_impuesto_cal, fec_ult_devengado,
      mto_int_mor_des, mto_int_mor_int_des,
      mto_int_mor_ade_des, mto_int_pun_des, mto_car_des,
      dev_acumulado, dev_no_cobrado, dev_suspenso, fec_valor)
   select nro_cuenta, nro_cuota, PAG_CAL.FU_OBT_FEC_ACTUAL(6)/*p_fecha*/, p_hora, fec_vencimiento, estado,
      sal_capital_pre, sal_interes_pre, sal_capital_cuo, sal_interes_cuo,
      sal_int_documentado, fec_ult_pago, dia_mora,
      mto_capital, mto_interes, mto_int_documentado, mto_int_moratorio,
      mto_int_mor_interes, mto_int_mor_adelantado, mto_int_punitorio,
      mto_cargo, mto_cargo_iva, mto_impuesto, mto_int_descontado,
      nro_documento, mto_int_mor_cal, mto_int_mor_int_cal,
      mto_int_mor_ade_cal, mto_int_pun_cal, mto_cargo_cal,
      mto_car_iva_cal, mto_impuesto_cal, r_pcpre.fec_ult_devengado,
      mto_int_mor_des, mto_int_mor_int_des,
      mto_int_mor_ade_des, mto_int_pun_des, mto_car_des,
      dev_acumulado, dev_no_cobrado, dev_suspenso, p_fecha
     from pr_cobros_tmp
    where nro_cuenta = p_nro_cuenta;
END;
/* Utilizar autorizacion */
PROCEDURE LP_UTI_AUTORIZACION
 (P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 )
 IS
BEGIN
   --- Autorizacion descuento de interes
   if pap_cob.g_cod_aut_interes is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_interes;
   end if;
   --- Autorizacion descuento de interes adelantado
   if pap_cob.g_cod_aut_int_ade is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_int_ade;
   end if;
   --- Autorizacion descuento de mora capital
   if pap_cob.g_cod_aut_mor_cap is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_mor_cap;
   end if;
   --- Autorizacion descuento de mora interes
   if pap_cob.g_cod_aut_mor_int is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_mor_int;
   end if;
   --- Autorizacion descuento de mora interes adelantado
   if pap_cob.g_cod_aut_mor_ade is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_mor_ade;
   end if;
   --- Autorizacion descuento de punitorio
   if pap_cob.g_cod_aut_punitorio is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_punitorio;
   end if;
   --- Autorizacion descuento de impuestos
   if pap_cob.g_cod_aut_impuesto is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_impuesto;
   end if;
   --- Autorizacion descuento de cargos
   if pap_cob.g_cod_aut_cargos is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_cargos;
   end if;
END;


BEGIN
   -- DYDMR-4575 NAF. Sep/2016 - logica de pag_sue.lp_ins_mov_sueldo
   if nvl(PAE_CNF.G_PROGRAMA,'x') not in ('GPPAGSUE','GPPROFIN') then -- DYDMR-5190 NAF Oct 2016
       v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
       If v_est_modulo = 2 then
           v_horario := 'D' ; -- N=Cerrado, D=Abierto
           v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
       else
           v_horario := 'N' ; -- N=Cerrado, D=Abierto
           v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
       end if;
       --pag_cta.g_horario := v_horario; -- DYDMR-5190 NAF Oct 2016
   end if ;
   --- Recuperar datos de la cuenta de prestamos
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
   PAP_PRE_RES_04.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);
   v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,r_pcpre.cod_modalidad, r_pcpre.cod_moneda);
   --si es descuento no permitir cancelacion parcial
   if p_cancelacion in ('P') then
     if fup_obt_tip_descuento(r_pcpre.cod_modalidad) in ('F','D','C') then
      raise_application_error(-20011,'La Modalidad no permite Cancelacion Parcial.');
    end if;
   end if;
   v_fec_ult_dev := nvl(r_pcpre.fec_ult_devengado,r_pcpre.fec_inicio);
   --- Inicializar datos del movimiento
   v_fecha         := p_fecha;
   v_hora          := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));

   /* Validación para que en caso de cancelación de un prestamo y el saldo de cuotas pendientes supera 100,
      el nro_secuencia inicialice en -999 para evitar desbordamiento.
   */
   IF (r_pcpre.can_cuotas - nvl(r_pcpre.can_cuo_pagadas,0)) > 100 and p_cancelacion = 'T' then
      v_nro_secuencia := -999;
   ELSE
      v_nro_secuencia := nvl(p_nro_secuencia, 0);
   END IF;
   --
   if nvl(p_ped_autorizacion,'N') = 'S' then
      v_est_movim := 'X';
   else
      v_est_movim := 'N';
   end if;
   --- Recuperar datos de la cuota
   v_sal_cobrado := p_mto_cobrado;
   v_tot_pag_cap := 0;
   --- Inicializar variables de autorizaciones
   PAP_PRE_RES_04.pr_ini_autorizacion;
   v_tot_sal_cap := 0;
   v_tot_sal_int := 0;
   --Inicializar fecha de Calculo, Fecha: 13/05/2010
   pap_cob.g_max_fec_calculo := null;
   pap_cob.g_max_fec_calculo_ant := null;
   pap_cob.g_cal_adic := 'S';
   --pap_cob.g_iva_interes := 0;
   v_max_fec_cal_ant_aux := null;
   v_cal_adic_aux := 'S';
   -- v_cal_iva_interes := 0;

   -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
   -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
   -- Determina si la operación corresponde a una venta de cartera.
   BEGIN
      SELECT 1
        INTO v_vta_cartera
        FROM pr_vta_cartera pr
       WHERE pr.nro_cuenta = r_pcpre.nro_cuenta
         AND rownum = 1;
   EXCEPTION
      WHEN OTHERS THEN
         v_vta_cartera := 0;
   END;

   for cuo in c_cuotas loop
      v_max_fec_cal_ant_aux := pap_cob.g_max_fec_calculo; --Asignar valor anterior, Fecha: 13/05/2010
      v_cal_adic_aux := pap_cob.g_cal_adic;
      --v_cal_iva_interes := pap_cob.g_iva_interes;

      --- Recuperar datos de la cuota
      PAP_PRE_RES_04.pr_obt_dat_cuota(p_nro_cuenta, cuo.nro_cuota, r_pcuot);
      --- Recuperar deuda de la cuota
      PAP_PRE_RES_04.pr_obt_deu_prestamo(p_nro_cuenta, p_fecha, cuo.nro_cuota, cuo.nro_cuota,
         p_cod_ofi_origen, v_sal_cobrado, v_error, v_mensaje,
         v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
         v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
         v_dia_mora, p_cod_tra_padre, p_cancelacion,p_renueva,p_cancel_rrr);
      if v_error <> 0 then
         raise_application_error(-20000, v_mensaje);
      end if;
      --Volver a obtener y asignar fecha de Calculo p/ Gastos, Fecha: 13/05/2010
      pap_cob.g_max_fec_calculo_ant := v_max_fec_cal_ant_aux;
      pap_cob.g_cal_adic := v_cal_adic_aux;
      --pap_cob.g_iva_interes := v_cal_iva_interes;
      if cuo.fec_vencimiento =  fu_obt_max_fec_vto(p_nro_cuenta, 999) then
         pap_cob.g_max_fec_calculo := nvl(fu_obt_max_fec_cargo(p_nro_cuenta),fu_obt_max_fec_vto(p_nro_cuenta, 999));
      else
         pap_cob.g_max_fec_calculo := cuo.fec_vencimiento;
      end if;
      --
      --- Insertar registro de cobro
      lp_ins_pr_cobros(p_nro_cuenta, v_fecha, v_hora);
      v_cancela       := 'N';
      v_cal_dev_nocob := 'N';
      if  r_pcuot.sal_capital = nvl(v_sal_capital,0)
      and (nvl(r_pcuot.sal_interes,0) + nvl(r_pcuot.sal_int_documentado,0)) = (nvl(v_sal_interes,0) + nvl(v_sal_int_ade,0) + nvl(v_int_descontado,0)) then
         v_cancela := 'S'; --- Cancela la cuota
      end if;
      --- Hallar el saldo capital del prestamo de la cuota
      v_pre_sal_cap := nvl(r_pcpre.sal_capital,0) - nvl(v_tot_pag_cap,0);
      v_tot_pag_cap := nvl(v_tot_pag_cap,0) + nvl(v_sal_capital,0);
      -- Modificado 21/06/2013-DI-MB:  Requerimiento: Venta de Cartera.
      -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
      -- Verificar si se calcula interes devengado.
      if  nvl(v_sal_interes,0) + nvl(v_int_descontado,0) + nvl(v_sal_int_ade,0) > 0
      and r_pcpre.estado <> 'I' and v_vta_cartera = 0 then  --- Incobrables no devenga mas
         --- Si se paga interes
         pap_dev.PR_PRO_DEV_COB_CUO(p_nro_cuenta, cuo.nro_cuota,
                                    v_fecha,--r_pcuot.fec_vencimiento - 1,
                                    p_hora,
                                    nvl(v_sal_interes,0) + nvl(v_sal_int_ade,0),
                                    v_int_descontado,
                                    nvl(r_pcuot.sal_interes,0) + nvl(r_pcuot.sal_int_documentado,0),
                                    r_pcuot.fec_vencimiento,
                                    v_nro_secuencia);
      end if;
      if v_cancela = 'S' then
         v_est_cuota := 'N';
      else
         v_est_cuota := 'z';
      end if;
      if v_est_movim = 'X' then
         v_est_cuota := 'X';
      end if;
      --- Actualizar plan de pago o cuota
      update pr_cuotas
         set sal_interes         = nvl(sal_interes,0) - (nvl(v_sal_interes,0) + nvl(v_int_descontado,0)),
             sal_capital         = nvl(sal_capital,0) - nvl(v_sal_capital,0),
             sal_int_documentado = nvl(sal_int_documentado,0) - nvl(v_sal_int_ade,0),
             val_recargo         = nvl(val_recargo,0) + nvl(v_mora,0) + nvl(v_mora_interes,0) +
                                                        nvl(v_mora_int_ade,0) + nvl(v_punitorio,0) +
                                                        nvl(v_impuesto,0) + nvl(v_cargo,0),
             fec_ult_pago        = p_fecha,
             estado              = decode(v_est_cuota,'z',estado,v_est_cuota),
             mto_cap_adelantado  = nvl(mto_cap_adelantado,0) + decode(p_cancelacion, 'P', nvl(v_sal_capital,0),0)
       where nro_cuenta = p_nro_cuenta
         and nro_cuota  = cuo.nro_cuota;
      --DYDMR-6419 - Existen escenarios que alteran el devengado al modificar el campo MTO_INTERES.-
      --DYDMR-3650-ITGF - Valor Cuota no Actualiza las Amortizaciones Parciales Anticipadas SC 27928
      --Una Cancelación Parcial de Capital también debe actualizar el valor de la Cuota (Monto Capital + Monto Interés).
      /*if P_COD_TRA_PADRE ='362' then
         update pr_cuotas
            set mto_interes  = nvl(mto_interes,0) - (nvl(v_sal_interes,0) + nvl(v_int_descontado,0)),
                mto_capital  = nvl(mto_capital,0) - nvl(v_sal_capital,0)
          where nro_cuenta   = p_nro_cuenta
            and nro_cuota    = cuo.nro_cuota;
      end if;*/
      -- SC 12793 - ITGF - Incidencia del Devengamiento de Interes - EP- NAN 2015-06-03
      -- Para cancelacion parcial de capital, se almacena en pr_cob_amo_parcial el monto devengado acumulado de la cuota
      -- fecha, hora y cod_usuario debe ser igual a datos de los movimientos generados para eliminar en caso de reversion
      /*dydmr 2003 fm 08/07/2015*/
      if p_cancelacion='P' and cuo.dev_acumulado <> 0 then
        BEGIN
          insert into PR_COB_AMO_PARCIAL (FECHA,HORA,COD_USUARIO,NRO_CUENTA,NRO_CUOTA,DEV_ACUMULADO)
          values (PAG_CAL.FU_OBT_FEC_ACTUAL(6),v_hora,nvl(p_cod_usuario,user),p_nro_cuenta,cuo.nro_cuota,cuo.dev_acumulado);
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
      end if;
      --- Actualizar ge_che_custodias
      --if r_pcpre.cod_modalidad IN (608, 630) then --- Descuento de Cheques
      If FUP_OBT_TIP_DESCUENTO(r_pcpre.cod_modalidad) = 'C' and v_cancela = 'S' then
         update ge_che_custodias
            set estado = 'D'
          where nro_referencia = p_nro_cuenta
            and nro_cuota = cuo.nro_cuota;
      end if;

      IF v_pre_sal_cap - nvl(v_sal_capital,0) > 0 THEN
         v_can_prestamo := 'N';
      else
         v_can_prestamo := 'S';
      end if;
      if v_est_cuota = 'N' then
         v_can_cuo_pagada := 1;
      else
         v_can_cuo_pagada := 0;
      end if;
      --- Actualizar maestro de prestamos
      update pr_cta_prestamos
         set sal_capital        = nvl(sal_capital,0) - nvl(v_sal_capital,0),
             sal_interes        = nvl(sal_interes,0) - (nvl(v_sal_interes,0) + nvl(v_int_descontado,0)),
             sal_int_adelantado = nvl(sal_int_adelantado,0) - nvl(v_sal_int_ade,0),
             estado             = decode(v_can_prestamo,'S','N',estado),
             fec_cancelacion    = decode(v_can_prestamo,'S',p_fecha,null),
             can_cuo_pagadas    = nvl(can_cuo_pagadas,0) + v_can_cuo_pagada
       where nro_cuenta = p_nro_cuenta;

      v_tot_sal_cap := nvl(v_tot_sal_cap,0) + nvl(v_sal_capital,0) + nvl(v_sal_int_ade,0);
      v_tot_sal_int := nvl(v_tot_sal_int,0) + (nvl(v_sal_interes,0) + nvl(v_int_descontado,0));

     --RI :OJO ACA ESTABA LA CANCELACION DE LOS CARGOS MANUALES, SE PASO MAS ABAJO
     -- POR MOTIVOS FUNCIONALES

      --- GENERAR MOVIMIENTOS
      r_gmovi.cod_usuario    := nvl(p_cod_usuario,user);
      r_gmovi.hora           := v_hora;
      -- DYDMR-4575 NAF. Sep/2016
      -- r_gmovi.fecha          := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
      if (v_est_modulo = 2  and  nvl(v_horario, 'D') = 'D') or -- DYDMR-5190 NAF Oct 2016
          (nvl(PAE_CNF.G_PROGRAMA,'x') in ('GPPAGSUE','GPPROFIN'))  then -- DYDMR-5190 NAF Oct 2016
         r_gmovi.fecha := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
      else
         pag_cal.pr_obt_dat_calendar(6);
         r_gmovi.fecha :=  pag_cal.g_fec_proxima;
      end if;
      r_gmovi.cod_modulo     := r_pcpre.cod_modulo;
      r_gmovi.cod_modalidad  := r_pcpre.cod_modalidad;
      r_gmovi.cod_oficina    := r_pcpre.cod_oficina;
      r_gmovi.nro_cuenta     := p_nro_cuenta;
      r_gmovi.cod_moneda     := r_pcpre.cod_moneda;
      r_gmovi.est_cuenta     := r_pcpre.estado;
      r_gmovi.cod_tra_padre  := p_cod_tra_padre;
      r_gmovi.cod_mod_padre  := p_cod_mod_padre;
      r_gmovi.cod_mad_padre  := nvl(p_cod_mad_rrr, p_cod_mad_padre);
      r_gmovi.fec_valor      := p_fecha;
      r_gmovi.reversado      := 'N';
      r_gmovi.protegido      := 'N';
     -- r_gmovi.estado         := 'N';
      r_gmovi.estado         := p_estado; -- Control Dual FASE II
      r_gmovi.cod_ofi_origen := p_cod_ofi_origen;
      r_gmovi.nro_documento  := r_pcpre.nro_documento;
      r_gmovi.nro_documento2 := r_pcuot.nro_documento;
      r_gmovi.nro_documento3 := r_pcuot.nro_cuota; --- Para poder reversar
      r_gmovi.concepto       := nvl(p_concepto,'Cobro de cuota');
      v_cotizacion           := null;
      if p_cancelacion = 'T' and p_cod_mad_rrr is not null then -- JIRA 2735
         --- Recuperar cotizacion de cuentas a cancelarse
         if r_pcpre.cod_moneda <> pag_gen.fu_obt_mon_local then
            v_cotizacion := pag_gen.fu_obt_cotizacion(r_pcpre.cod_moneda, r_gmovi.fecha);
         end if;
      end if;
      -- limpiar
      v_mto_cap_original := 0;
      v_mto_ori_fondo := 0;

      IF v_sal_Capital > 0 THEN --si paga capital, contabilizar % origen de fondos
         --recuperar origen de fondos propios
         v_ori_fon_propio := fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,r_pcpre.cod_moneda,null,null);
         --determinar el % de origen de fondos para la contabilización
         if r_pcpre.cod_ori_fondo = v_ori_fon_propio then
           --es fondos propios tomar el 100%
           v_mto_cap_original := v_sal_Capital; -- todo el capital con fondos propios
         else -- tiene porción que no es fondos propios
           if r_pcpre.por_ori_fondo > 0 and r_pcpre.por_ori_fondo <= 100 then
              v_mto_ori_fondo := round(v_sal_Capital * r_pcpre.por_ori_fondo / 100,v_redondeo); --sólo el porcentaje
              v_mto_cap_original := v_sal_Capital - v_mto_ori_fondo;
           else
              v_mto_cap_original := v_sal_Capital; -- todo el capital con fondos propios
           end if;
        end if;
      end if;

      IF v_mto_cap_original > 0 THEN -- Amortizo capital, fondos propios
         v_nro_secuencia            := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.emi_aviso          := 'S';
         r_gmovi.cod_transaccion    := fup_obt_transaccion('CA', r_pcuot.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.nro_cuenta, v_ori_fon_propio, null, 'C');
         --r_gmovi.cod_transaccion    := PAP_PRE_RES_04.fu_obt_tra_concepto('CA', r_pcuot.estado,r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         r_gmovi.monto              := v_mto_cap_original; --v_sal_capital;
         r_gmovi.cotizacion         := v_cotizacion;
         r_gmovi.mto_equ_local      := round(r_gmovi.monto * v_cotizacion, v_redondeo_ml);
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
      END IF;

      IF v_mto_ori_fondo > 0 THEN -- x el origen de fondos específico
         v_nro_secuencia            := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.emi_aviso          := 'S';
         r_gmovi.cod_transaccion    := fup_obt_transaccion('CA', r_pcuot.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.nro_cuenta, r_pcpre.cod_ori_fondo, null, 'C');
         --r_gmovi.cod_transaccion    := fup_obt_tra_ori_fondo(r_pcpre.cod_ori_fondo,r_pcpre.cod_moneda,'B');
         r_gmovi.monto              := v_mto_ori_fondo;
         r_gmovi.cotizacion         := v_cotizacion;
         r_gmovi.mto_equ_local      := round(r_gmovi.monto * v_cotizacion, v_redondeo_ml);
         r_gmovi.concepto       := nvl(p_concepto,'Cobro de cuota-ori fondo');
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
      END IF;
      r_gmovi.concepto       := nvl(p_concepto,'Cobro de cuota');
      ---se generan datos de cobro de intereses, mora y devengado -----------
      /** Ajuste JIRA 2735**/
      ---Verificar si se cobro iva
      Select count(*) into v_iva
        from pr_sol_cargos
       where nro_solicitud = r_pcpre.nro_solicitud
         and cod_Transaccion = 709;

      if v_sal_interes > 0 then --- Amortizo interes vencidos
         -- inserta monto interes cobrado
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IN', r_pcuot.estado,
                                        r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         r_gmovi.monto               := v_sal_interes;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_INT;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_INTERES;
         r_gmovi.val_tasa            := NULL;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         /** Ajuste Jira 2735**/
         If nvl(v_iva,0) = 0 then -- No se cobro iva en el desemb.
            If nvl(pap_cob.g_iva_interes,0) > 0 then
               r_gmovi.cod_transaccion  := 708; --Trans.Iva diferenciada
            Else
               -- Modificado 26/06/2013- Requerimiento: Cobro de Préstamos por Caja.
               -- Solamente debe generar el movimiento de iva por cancelaciones que no sean de venta de cartera.
               IF v_vta_cartera = 0 THEN
                  r_gmovi.cod_transaccion  := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado,
                                           r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
               END IF;
            End if;
            -- Modificado 21/06/2013-DI-MB:  Requerimiento: Venta de Cartera.
            -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FCCT.01-AJU_VTA_CARTERA.
            -- Se verifica si se genero la factura en la fecha de vencimiento de la cuota.
        /*
               || Modificado 05/12/2014 - PS: DYDMR-989 SC 8247
               || Los cobros de cuotas vencidas que no sean por venta de cartera se deberán realizar con la cotización del día
               || y no con la cotización de la factura crédito emitida.
               */
         if v_vta_cartera > 0 then
            BEGIN
               SELECT cl.cotizacion
                 INTO v_cot_factura
                 FROM cb_lib_ventas_det cl
                WHERE cl.fecha = cuo.fec_vencimiento
                  AND cl.nro_cuenta = cuo.nro_cuenta
                  AND cl.nro_documento = cuo.nro_cuota
                  AND cl.cod_tra_padre = 391;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cot_factura  := NULL;
            END;
         end if;
            v_cod_tasa := null;
            /*
            || DYDMR-939 SPI-3880 Error Facturacion en el vencimiento de la cuota AP SC 4903
            || Se debe asignar la fecha antes de obtener la tasa,
            || también en los casos de descuento de intereses y cancelación anticipada.
            */
            if nvl(r_gmovi.cod_transaccion,0) = 708 then
               v_fec_tasa := cuo.fec_vencimiento;
            else
               v_fec_tasa := FUP_OBT_FEC_TASA (p_cod_tra_padre, r_gmovi.cod_transaccion,
                             r_pcpre.fec_inicio, p_fecha, r_pcpre.nro_solicitud, v_int_descontado);
            end if;
            ---
            pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                        r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                        r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                        /*p_fecha*/ v_fec_tasa, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

            r_gmovi.val_tasa            := v_val_tas_impuesto;
            r_gmovi.monto               := round( (nvl(v_sal_interes,0) * v_val_tas_impuesto /100),v_redondeo);
            ---------------------------------------------------------------------------------------------------------------------------------------------
            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.emi_aviso           := 'S';
            r_gmovi.cotizacion          := nvl(v_cot_factura,v_cotizacion);
            r_gmovi.mto_equ_local       := round(r_gmovi.monto * nvl(v_cot_factura,v_cotizacion),v_redondeo_ml);
            r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
            r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;

            -- 26/12/2013
            -- Incidencia Venta Cartera - Préstamos, cobro cuotas adelantadas.
            IF nvl(r_gmovi.monto,0) > 0 then
               pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
            END IF;
            --
            -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
            -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FCCT.01-AJU_VTA_CARTERA.
            -- Se genera los movimientos de cancelación de las facturas créditos generadas por cada cuota vencida.
            -- Modificado 26/06/2013- Requerimiento: Cobro de Préstamos por Caja.
            -- Solamente debe generar el movimiento de devolución de iva por venta de cartera.
            IF v_vta_cartera > 0 THEN
               v_nro_secuencia             := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia       := v_nro_secuencia;
               r_gmovi.emi_aviso           := 'S';
               /*
               || DYDMR-944 Registro Cancelaciones Anticipadas de desembolsos con IVA 10% SC 4992
               || Si es 5% debe llevar al rubro correspondiente
               */
               if nvl(v_val_tas_impuesto,0) = 10 then
                  r_gmovi.cod_transaccion     := 2517;
               else
                  r_gmovi.cod_transaccion     := 1708; --IVA.
               end if;
               ---
               r_gmovi.cotizacion          := nvl(v_cot_factura,v_cotizacion);
               r_gmovi.mto_equ_local       := round(r_gmovi.monto * nvl(v_cot_factura,v_cotizacion),v_redondeo_ml);
               r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
               r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
               r_gmovi.val_tasa            := v_val_tas_impuesto;
               -- 26/12/2013
               -- Incidencia Venta Cartera - Préstamos, cobro cuotas adelantadas.
               IF nvl(r_gmovi.monto,0) > 0 then
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
               END IF;
            END IF;


         end if;
      end if;
      --- generar movimiento por el interes descontado
      if nvl(v_int_descontado,0) <> 0 then
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := 803;
         r_gmovi.monto               := v_int_descontado;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_INT;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_INTERES;
         r_gmovi.val_tasa            := NULL;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         --
         /* RI : 05/07/2010: Si no se cobro iva al desembolso y si es cuota vencida de mes anterior al actual
            se asume que el iva ya fue facturado y se debe generar mov. con transaccion diferente (721) para ajuste
            contable. */

         If nvl(v_iva,0) = 0  -- No se cobro iva en el desemb.
         and cuo.fec_vencimiento < pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(6) then
            --Obtener tasa de impuesto s/interes
            v_cod_tasa := null;
            /*
            || DYDMR-939 SPI-3880 Error Facturacion en el vencimiento de la cuota AP SC 4903
            || Se debe asignar la fecha antes de obtener la tasa,
            || también en los casos de descuento de intereses y cancelación anticipada.
            */
            v_fec_tasa := FUP_OBT_FEC_TASA (p_cod_tra_padre, 709,
                          r_pcpre.fec_inicio, p_fecha, r_pcpre.nro_solicitud);
            ---
            pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                         r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                         r_gmovi.monto, 'N', v_cod_tasa, 709, /*p_fecha*/v_fec_tasa,
                         v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);
            v_iva_facturado := round(nvl(v_int_descontado,0) * (v_val_tas_impuesto / 100), v_redondeo);
            --
            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.emi_aviso           := 'S';
            r_gmovi.cod_transaccion     := 721; --Trans.Iva diferenciada
            r_gmovi.monto               := v_iva_facturado;
            r_gmovi.cotizacion          := v_cotizacion;
            r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
            r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
            r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
            r_gmovi.val_tasa            := v_val_tas_impuesto;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         end if;

         -- Genera nota de crédito por el impuestos s/ interes no cuotizados por cancelaciones anticipadas de préstamos.
         -- Modificado 11/08/2011 JF.
         -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
         -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
         -- Si es una venta de cartera no debe generar la nota de crédito por el impuestos s/ interes no cuotizados por cancelaciones anticipadas de préstamos.
         IF nvl(v_iva, 0) > 0 AND v_vta_cartera = 0 THEN
            --Debito del rubro de IVA.
            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.emi_aviso           := 'S';
            r_gmovi.cod_transaccion     := 1708; --IVA.
            r_gmovi.cotizacion          := v_cotizacion;
            r_gmovi.cod_usu_autorizador := pap_cob.g_cod_usu_aut_im;
            r_gmovi.cod_autorizacion    := pap_cob.g_cod_aut_impuesto;
            --recuperar tasa
            v_cod_tasa := NULL;
            v_fec_tasa := FUP_OBT_FEC_TASA (p_cod_tra_padre, r_gmovi.cod_transaccion, r_pcpre.fec_inicio,
                                            p_fecha, r_pcpre.nro_solicitud, v_int_descontado);

            pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                    r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                    v_int_descontado, 'N', v_cod_tasa, r_gmovi.cod_transaccion,
                                    v_fec_tasa, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor,
                                    v_tipo);

            r_gmovi.val_tasa      := v_val_tas_impuesto;
            /*
            || DYDMR-944 Registro Cancelaciones Anticipadas de desembolsos con IVA 10% SC 4992
            || Si es 5% debe llevar al rubro correspondiente
            */
            if nvl(v_val_tas_impuesto,0) = 10 then
               r_gmovi.cod_transaccion     := 2517;
            end if;
            ---
            r_gmovi.monto         := round(nvl(v_int_descontado, 0) * (v_val_tas_impuesto / 100), v_redondeo);
            r_gmovi.mto_equ_local := round(r_gmovi.monto * v_cotizacion, v_redondeo_ml);
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016

            --Acrédito a la cuenta en suspenso de la oficina de la cuenta.

            pag_cta.pr_act_operacion(fug_obt_pardinamico('CTA_CRE_IVA_DESCONTADO',
                                                          NULL,
                                                          NULL,
                                                          r_pcpre.cod_moneda, r_pcpre.cod_oficina),
                                     v_hora,
                                     'C',
                                     r_pcpre.cod_moneda, --Moneda de la Operacion
                                     r_gmovi.monto,
                                     359, -- Transacción Padre (Cancelación Anticipada)
                                     602, -- Transacción Hijo
                                     r_pcpre.nro_documento,
                                     v_cotizacion,
                                     p_cod_ofi_origen, -- Oficina Origen
                                     p_cod_mod_padre, -- Modulo Padre
                                     nvl(p_cod_mad_rrr, p_cod_mad_padre), -- Modalidad Padre
                                     NULL, -- Código Tasa
                                     NULL, -- Valor Tasa
                                     nvl(p_concepto, 'Cobro de cuota'),
                                     'S',
                                     v_nro_secuencia,
                                     p_fecha,
                                     null,
                                     null,
                                     null,
                                     p_estado);-- C.D.Fase II
         END IF;
      End if;
      --si es préstamo a la vista, ver si se renueva con fecha valor para generar mov. x el devengado no cobrado a reversar
      --recuperar datos de la propuesta, una sola vez, para que no haga por cada cuota
      if  nvl(fug_obt_pardinamico('PRE_VISTA',r_pcpre.cod_modulo,r_pcpre.cod_modalidad,null,null,null),'X') = 'S'
       and r_pcpre.nro_sol_renovada is not null  then
        if v_una_vez = 'S' then
           v_una_vez := 'N';
           PAP_PRE_RES_04.PR_OBT_DAT_SOLICITUD(r_pcpre.nro_sol_renovada,rv_soli,v_sol_cargo,v_sol_int_adelantado);
           --
          if rv_soli.tip_renovacion = 'V' then
            --verifica si es con fecha valor (anterior a hoy)
            if rv_soli.fec_inicio < pag_cal.fu_obt_fec_actual(6) then
              --calcular días para asentar la reversasión del devengado no cobrado por los días entre la fecha actual y la fecha valor
              v_dias_reversar := pag_cal.fu_obt_fec_actual(6) - rv_soli.fec_inicio;
              v_mto_dev_total := round(r_pcpre.mto_capital * (r_pcpre.fec_vencimiento - r_pcpre.fec_inicio) * r_pcpre.val_tasa / 36500,v_redondeo);
              v_dev_diario := round(v_mto_dev_total / (r_pcpre.fec_vencimiento - r_pcpre.fec_inicio),v_redondeo);
              v_dev_no_cob_rev := v_dev_diario * v_dias_reversar;
            end if;
          else
            v_dev_no_cob_rev := 0;
          end if;
        end if;
      else
        v_dev_no_cob_rev := 0;
      end if;
      --- generar movimiento por el devengado no cobrado por la porción de días transcurridos
      if nvl(v_dev_no_cob_rev,0) <> 0 then
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := 804;
         r_gmovi.monto               := v_dev_no_cob_rev;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_INT;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_INTERES;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         --limpiar variable para que entre una sola vez
         v_dev_no_cob_rev := 0;
      end if;
       if v_sal_int_ade > 0 then
         -- inserta monto de interes adelantado reconocido --
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IA', r_pcuot.estado,
                                        r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         r_gmovi.monto               := v_sal_int_ade;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_INA;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_INT_ADE;
         r_gmovi.val_tasa            := NULL;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
        /** Ajuste Jira 2735 INTERES ADELANTADO **/
         If nvl(v_iva,0) = 0 then
            r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado,
                                       r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);

            v_cod_tasa := null;
            pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                        r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                        r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                        p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

            r_gmovi.val_tasa           := v_val_tas_impuesto;
            r_gmovi.monto               := round( (nvl(v_sal_int_ade,0) * v_val_tas_impuesto /100),v_redondeo);
          ---------------------------------------------------------------------------------------------------------------------------------------------
            -- Ajuste 08-02-2013 --
            if r_gmovi.monto > 0 then
               v_nro_secuencia             := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia       := v_nro_secuencia;
               r_gmovi.emi_aviso           := 'S';
               r_gmovi.cotizacion          := v_cotizacion;
               r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
               r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
               r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
            end if;
         end if;
      end if;
      -- inserta monto interes moratorio -----------------------------
      /*** Ajuste JIRA 2735***/
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,r_pcpre.cod_modalidad, r_pcpre.cod_moneda);
       if nvl(v_mora,0) > 0 then
          v_nro_secuencia             := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia       := v_nro_secuencia;
          r_gmovi.emi_aviso           := 'S';
          r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('MO', r_pcuot.estado,
                                        r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
          r_gmovi.monto               := v_mora;
          r_gmovi.cotizacion          := v_cotizacion;
          r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
          r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_MO;
          r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_MOR_CAP;
          r_gmovi.val_tasa            := null;
          pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016

          -- Generar el impuesto
          /**** Ajuste JIRA Fase I  03-01-2013 BY PS****/
          ---------------------------------------------------------------------------------------------------------------------------------------------
          r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado,
                                       r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);

          v_cod_tasa := null;
          pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                        r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                        r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                        p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

          r_gmovi.val_tasa           := v_val_tas_impuesto;
          r_gmovi.monto              := round( (nvl(v_mora,0) * v_val_tas_impuesto /100),v_redondeo);
          ---------------------------------------------------------------------------------------------------------------------------------------------
          if nvl(r_gmovi.monto,0) > 0 then
             v_nro_secuencia             := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia       := v_nro_secuencia;
             r_gmovi.emi_aviso           := 'S';
             r_gmovi.cotizacion          := v_cotizacion;
             r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
             r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
             r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
          end if;
       end if;
       -- inserta movimiento diario si es C o A  ----
       /*** AJUSTE JIRA 2735 - 03-01-2013  BY PS ***/
       v_mora_original := lf_obt_mora_original(p_nro_cuenta, cuo.nro_cuota);
       if nvl(v_mora_original,0) > v_mora and v_cancela = 'S' and  r_pcuot.estado in ('C','A') then
         --- esto es la mora no cobrada -------------------------------
         --- solo se genera mora no cobrada si es amortizable -----
          v_nro_secuencia            := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia      := v_nro_secuencia;
          r_gmovi.emi_aviso          := 'N';
          if r_pcpre.tipo = 'A' then
             v_cod_transaccion    := 812;
          else
             v_cod_transaccion    := 809;
          end if;
          r_gmovi.cod_transaccion    := v_cod_transaccion;
          r_gmovi.monto              := v_mora_original - v_mora;
          r_gmovi.cotizacion         := v_cotizacion;
          r_gmovi.mto_equ_local      := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
          r_gmovi.val_tasa           := null;
          pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
          /**** Ajuste JIRA Fase I  03-01-2013 BY PS****/
          --------------------------------------------------------------------------------------------------
          r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
          --recuperar tasa
          v_cod_tasa := null;
          pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                           r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                           r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                           p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

          r_gmovi.val_tasa           := v_val_tas_impuesto;
          r_gmovi.monto              := round((nvl(v_mora_original-v_mora,0) * v_val_tas_impuesto/100),v_redondeo);
          --------------------------------------------------------------------------------------------------
          if nvl(r_gmovi.monto,0) > 0 then
             v_nro_secuencia             := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia       := v_nro_secuencia;
             r_gmovi.emi_aviso           := 'S';
             r_gmovi.cotizacion          := v_cotizacion;
             r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
             r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
             r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
          end if;
       end if;

       /*** AJUSTE JIRA 2735 - 03-01-2013  BY PS ***/
       if nvl(v_mora_original,0) > v_mora and v_cancela = 'S' then
          v_nro_secuencia            := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia      := v_nro_secuencia;
          r_gmovi.emi_aviso          := 'N';
          if r_pcuot.estado = 'V' then
             v_cod_transaccion    := 816;
          elsif r_pcuot.estado = 'G' then
             v_cod_transaccion   := 824;
          elsif r_pcuot.estado in ('M','I') then
             v_cod_transaccion   := 829;
          end if;
          r_gmovi.cod_transaccion    := v_cod_transaccion;
          r_gmovi.monto              := v_mora_original-v_mora;
          r_gmovi.cotizacion         := v_cotizacion;
          r_gmovi.mto_equ_local      := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
          r_gmovi.val_tasa            := null;
          pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016

         /**** Ajuste JIRA Fase I  03-01-2013 BY PS****/
         --- Genera movimiento por el impuesto
         --------------------------------------------------------------------------------------------------
          r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado,
                                          r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
          --recuperar tasa
          v_cod_tasa := null;
          pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                           r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                           r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                           p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

          r_gmovi.val_tasa           := v_val_tas_impuesto;
          r_gmovi.monto              := round((nvl(v_mora_original-v_mora,0) * v_val_tas_impuesto/100),v_redondeo);

          --------------------------------------------------------------------------------------------------
          if nvl( r_gmovi.monto ,0) > 0 then
             v_nro_secuencia             := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia       := v_nro_secuencia;
             r_gmovi.emi_aviso           := 'S';
             r_gmovi.cotizacion          := v_cotizacion;
             r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
             r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
             r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
          end if;
       end if;
    --- Generar movimientos por mora sobre interes
      if nvl(v_mora_interes,0) > 0 then
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('MI', r_pcuot.estado,
                                        r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.monto               := v_mora_interes;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_MI;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_MOR_INT;
         r_gmovi.val_tasa            := null;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016

         /**** Ajuste JIRA Fase I  03-01-2013 BY PS****/
         --- Genera movimiento por el impuesto
         ---------------------------------------------------------------------------------------------------
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado,
                                          r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
        --recuperar tasa
          v_cod_tasa := null;
          pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                           r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                           r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                           p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

          r_gmovi.val_tasa           := v_val_tas_impuesto;
          r_gmovi.monto              := round((nvl(v_mora_interes,0)* v_val_tas_impuesto/100),v_redondeo);
      --------------------------------------------------------------------------------------------------
         if nvl(r_gmovi.monto ,0) > 0 then
            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.emi_aviso           := 'S';
            r_gmovi.cotizacion          := v_cotizacion;
            r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
            r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
            r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         end if;
      end if;
      --- se genera un movimiento si existe mora sobre interes adelantado----
      if nvl(v_mora_int_ade,0) > 0 then
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('MA', r_pcuot.estado,
                                        r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.monto               := v_mora_int_ade;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_MA;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_MOR_ADE;
         r_gmovi.val_tasa            := null;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016

         /**** Ajuste JIRA Fase I  03-01-2013 BY PS****/
         --- Genera movimiento por el impuesto
         --------------------------------------------------------------------------------------------------
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado,
                                        r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         --recuperar tasa
         v_cod_tasa := null;
         pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                           r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                           r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                           p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

         r_gmovi.val_tasa           := v_val_tas_impuesto;
         r_gmovi.monto              := round((nvl(v_mora_int_ade,0) * v_val_tas_impuesto/100),v_redondeo);
       --------------------------------------------------------------------------------------------------
         if nvl(r_gmovi.monto,0) > 0 then
            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.emi_aviso           := 'S';
            r_gmovi.cotizacion          := v_cotizacion;
            r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
            r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
            r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         end if;
     end if;
      --- Genera movimiento por el punitorio
      if nvl(v_punitorio,0) > 0 then
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('PU', r_pcuot.estado,
                                        r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         r_gmovi.monto               := v_punitorio;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_PU;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_PUNITORIO;
         r_gmovi.val_tasa            := null;
         pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016

         /**** Ajuste JIRA Fase I  03-01-2013 BY PS****/
         --- Genera movimiento por el impuesto
         -----------------------------------------------------------------------------------------------
         r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('IM', r_pcuot.estado,
         r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);

         --recuperar tasa
         v_cod_tasa := null;
         pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                           r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                           r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                           p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

         r_gmovi.val_tasa           := v_val_tas_impuesto;
         r_gmovi.monto               := round((nvl( v_punitorio,0) * v_val_tas_impuesto/100),v_redondeo);
       --------------------------------------------------------------------------------------------------
         if nvl( r_gmovi.monto,0) > 0 then
            v_nro_secuencia             := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia       := v_nro_secuencia;
            r_gmovi.emi_aviso           := 'S';
            r_gmovi.cotizacion          := v_cotizacion;
            r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
            r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
            r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
      pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         End if;
      end if;
        ----------------------------------------------------------------------
      --- OBS: Los calculos de utilizacion del origen de fondos se hace
      --- en el trigger TA_PR_CTA_PRESTAMOS
      ----------------------------------------------------------------------
      ----------------------------------------------------------------------
      --- Genera movimiento por los cargos
      ----------------------------------------------------------------------
      --  Primero sobre los cargos manuales que estan la tabla pr_cta_gastos
      --  cada cargo con la transaccion que esta definida en dicha tabla
      if nvl(v_cargo,0) > 0 then     -- ojo: v_cargo es con iva y estan contenido los cargos manuales y comisiones adicionales
        Declare
          cursor c_car_adic is
           select g.cod_Transaccion, sum( nvl( monto, 0 ) ) monto
            from pr_cta_gastos g
           where nro_cuenta    = p_nro_cuenta
             and (((fec_ini_vigencia <= pap_cob.g_max_fec_calculo or fec_ini_vigencia is null )
             and  (fec_ini_vigencia >  pap_cob.g_max_fec_calculo_ant or pap_cob.g_max_fec_calculo_ant is null  or fec_ini_vigencia is null)
             and   nro_solicitud is not null)
              or  ((fec_vencimiento  >= pap_cob.g_fec_calculo or fec_vencimiento is null) and nro_solicitud is null and pap_cob.g_cal_adic = 'S'))
             and fec_ult_pago is null
          Group by g.cod_Transaccion;
         Begin
           v_tot_car_adic := 0;
           For reg in c_car_adic loop
             v_nro_secuencia             := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia       := v_nro_secuencia;
             r_gmovi.emi_aviso           := 'S';
             r_gmovi.cod_transaccion     := reg.cod_Transaccion;
             r_gmovi.monto               := reg.monto;
             r_gmovi.cotizacion          := v_cotizacion;
             r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
             r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_CG;
             r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_CARGOS;
             r_gmovi.val_tasa            := null;
             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
             v_tot_car_adic := nvl(v_tot_Car_Adic,0) + nvl(reg.monto,0);
             If v_tot_car_adic >= v_cargo then
               exit;
             end if;
           End loop;
         End;
         /*
         -- Generar el movimiento por los otros cargos que no estan en Pr_cta_gastos
         */
         v_otros_cargos := v_cargo - nvl(v_cargo_iva,0) - nvl(v_tot_car_Adic,0);

         if  nvl(v_otros_cargos,0) > 0 then
           v_nro_secuencia             := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia       := v_nro_secuencia;
           r_gmovi.emi_aviso           := 'S';
           r_gmovi.cod_transaccion     := PAP_PRE_RES_04.fu_obt_tra_concepto('CG', r_pcuot.estado,
                                          r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
           --r_gmovi.monto               := v_cargo - nvl(v_cargo_iva,0); -- Sin iva
           r_gmovi.monto               := v_otros_cargos;
           r_gmovi.cotizacion          := v_cotizacion;
           r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
           r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_CG;
           r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_CARGOS;
           r_gmovi.val_tasa           := r_gmovi.monto;  -- ??
           pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         end if;

         if  nvl(v_cargo_iva,0) > 0 then
           --- Impuesto sobre cargo
           v_nro_secuencia            := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia      := v_nro_secuencia;
           r_gmovi.emi_aviso          := 'S';
           r_gmovi.cod_transaccion    := 517;
           r_gmovi.monto              := v_cargo_iva;
           r_gmovi.cotizacion          := v_cotizacion;
           r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,v_redondeo_ml);
           --recuperar tasa
           v_cod_tasa := null;
           pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                         r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                         r_gmovi.monto, 'N', v_cod_tasa, 517, --Transaccion
                         p_fecha, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);

           r_gmovi.val_tasa           := v_val_tas_iva;
           pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
         end if;
      end if;

      --- Actualizo pr_Cta_gastos

      IF nvl( v_cargo, 0 ) > 0 THEN
        BEGIN
          select sum( nvl( monto, 0 ) )
            into v_cta_gastos
            from pr_cta_gastos
           where nro_cuenta = p_nro_cuenta
           and (((fec_ini_vigencia <= pap_cob.g_max_fec_calculo or fec_ini_vigencia is null )
           and  (fec_ini_vigencia >  pap_cob.g_max_fec_calculo_ant or pap_cob.g_max_fec_calculo_ant is null  or fec_ini_vigencia is null)
           and   nro_solicitud is not null)
            or  ((fec_vencimiento  >= pap_cob.g_fec_calculo or fec_vencimiento is null) and nro_solicitud is null and pap_cob.g_cal_adic = 'S'))
           and fec_ult_pago is null;
        EXCEPTION
          when no_data_found then
            v_cta_gastos := 0;
        END;
        DECLARE
          CURSOR gastos
              IS select nro_cuenta, monto, rowid
                   from pr_cta_gastos
                  where nro_cuenta = p_nro_cuenta
                    and (((fec_ini_vigencia <= pap_cob.g_max_fec_calculo or fec_ini_vigencia is null )
                    and  (fec_ini_vigencia >  pap_cob.g_max_fec_calculo_ant or pap_cob.g_max_fec_calculo_ant is null  or fec_ini_vigencia is null)
                    and   nro_solicitud is not null)
                     or  ((fec_vencimiento  >= pap_cob.g_fec_calculo or fec_vencimiento is null) and nro_solicitud is null and pap_cob.g_cal_adic = 'S'))
                   and fec_ult_pago is null
                  order by nro_cuenta, cod_modalidad, cod_transaccion, fec_ingreso;
          v_cargo_tmp NUMBER;
        BEGIN
           v_cargo_tmp := v_cta_gastos;      -- RI: Debe ser v_Cta_gastos porque v_cargo tiene otros cargos que no estan en pr_cta_gastos
          FOR g IN gastos LOOP
            -- Si el cargo es mayor al monto, actualizo la tabla pr_cta_gastos como cobrado
            IF nvl( v_cargo_tmp, 0 ) >= nvl( g.monto, 0 ) THEN
              BEGIN
                update pr_cta_gastos
                   set fec_ult_pago = p_fecha,
                       hor_ult_pago = v_hora
                 where nro_cuenta = g.nro_cuenta
                   and rowid = g.rowid;
              EXCEPTION
                when others then
                  NULL;
              END;
              v_cargo_tmp := nvl( v_cargo_tmp, 0 ) - nvl( g.monto, 0 );
            END IF;
          END LOOP;
        END;
      END IF;
     --
      r_gmovi.val_tasa           := null;
      --- Calcular el monto cobrado de la cuota
      v_mto_cuota   := nvl(v_sal_capital,0) + nvl(v_sal_interes,0) + nvl(v_sal_int_ade,0) +
                       nvl(v_mora,0) + nvl(v_mora_int_ade,0) + nvl(v_mora_interes,0) +
                       nvl(v_cargo,0) + nvl(v_punitorio,0) + nvl(v_impuesto,0);
      v_sal_cobrado := v_sal_cobrado - v_mto_cuota;
      if nvl(v_sal_cobrado,0) <= 0 then
         exit;
      end if;
   end loop;

   --Generar novedades de la garantia para poder reversar
   for i in garantias loop
     insert into pr_cta_garantias_nov(fecha,hora,cod_usuario,
                                      nro_cuenta,nro_garantia,
                                      cod_garantia,mto_aplicado)
     values(PAG_CAL.FU_OBT_FEC_ACTUAL(6),v_hora,nvl(p_cod_usuario,user),p_nro_cuenta,
            i.nro_garantia,i.cod_garantia,i.mto_aplicado);
   end loop;
   --- Desaplicar mto. aplicado de la garantia
   if fug_obt_pardinamico('INC_INT_GARANTIA',r_pcpre.cod_modulo,
                                             r_pcpre.cod_modalidad,
                                             r_pcpre.cod_moneda,
                                             r_pcpre.cod_oficina) ='S' then
     v_tot_desaplicar := nvl(v_tot_sal_cap,0) + nvl(v_tot_sal_int,0);
   else
     v_tot_desaplicar := nvl(v_tot_sal_cap,0);
   End if;
   pap_gar.pr_act_apl_garantia(p_nro_cuenta,v_tot_desaplicar,'D',v_mens_error);

   -- Recalcular linea
   if r_pcpre.nro_linea is not null then
      prp_rec_apl_limite(r_pcpre.nro_linea);
   end if;

   --- Generar movimiento del cambio de estado a cancelado
   if v_can_prestamo = 'S' then
      v_nro_secuencia             := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia       := v_nro_secuencia;
      r_gmovi.emi_aviso           := 'N';
      r_gmovi.cod_transaccion     := 429;
      r_gmovi.est_cuenta          := 'N';
      r_gmovi.monto               := null;
      r_gmovi.cotizacion          := null;
      r_gmovi.mto_equ_local       := null;
      r_gmovi.cod_usu_autorizador := null;
      r_gmovi.cod_autorizacion    := null;
      pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno); -- DYDMR-4575 NAF. Sep/2016
   end if;
   --- Actualizar autorizaciones utilizadas
   lp_uti_autorizacion(p_fecha,v_hora);
   PAP_PRE_RES_04.pr_ini_autorizacion;
   --- Verificar si existe cambio de estado -- SOLO POR CIERRES!!!
   /*if r_pcpre.estado <> 'C' and v_can_prestamo = 'N' then --- Vigente
      begin
         select nvl(fup_obt_categoria(cli.cat_automatica,cli.cat_subjetiva),1)
           into v_categoria
           from ge_clientes cli, ge_cta_clientes ccl
          where ccl.nro_cuenta = p_nro_cuenta
            and ccl.cod_persona = cli.cod_persona
            and ccl.relacion = 'P';
      exception
         when no_data_found then
            raise_application_error(-20000,
            'Cliente principal no definido para cuenta '||p_nro_cuenta);
      end;
      pap_mes.pr_cam_situacion (r_pcpre.cod_modulo,
                                r_pcpre.cod_modalidad,
                                r_pcpre.cod_oficina,
                                p_nro_cuenta,
                                v_categoria,
                                p_fecha,
                                v_hora,
                                v_nro_secuencia );
   end if;*/
   p_nro_secuencia := v_nro_secuencia;
END;
/* Recuperar valor del concepto de cobro para los datos del parametro. */
FUNCTION FU_OBT_CONCEPTO
 (P_CONCEPTO IN PR_COB_PRIORIDADES.CONCEPTO%TYPE
 ,RP_PCPRE IN PR_CTA_PRESTAMOS%ROWTYPE
 ,RP_PCUOT IN PR_CUOTAS%ROWTYPE
 ,RP_PCTMP IN OUT PR_COBROS_TMP%ROWTYPE
 ,P_FECHA IN DATE
 )
 RETURN NUMBER
 IS
v_rutina     pr_cob_prioridades.fun_calculo%type;
   v_sentencia  varchar2(1500);
   v_error      varchar2(200) := NULL;
BEGIN
   --- Inicializar variables globales
   pap_cob.g_fec_calculo := p_fecha;
   if nvl(pap_cob.g_tip_cancelacion,'N') not in ('T','P') then
      --- La cancelacion anticipada ya carga el registro con los datos iniciales
      pap_cob.rg_pcpre := rp_pcpre;
   end if;
   pap_cob.rg_pcuot := rp_pcuot;
   pap_cob.rg_pctmp := rp_pctmp;
   if p_concepto = 'DE' then --- Recuperar rutina de descuentos
      v_rutina := fug_obt_pardinamico('RUT_DES_INT_PRE',rp_pcpre.cod_modulo, rp_pcpre.cod_modalidad,
                                      rp_pcpre.cod_moneda, rp_pcpre.cod_oficina);
   elsif p_concepto = 'AC' then --- Recuperar rutina de adelantados de capital
      v_rutina := fug_obt_pardinamico('RUT_ADE_CAPITAL',rp_pcpre.cod_modulo, rp_pcpre.cod_modalidad,
                                      rp_pcpre.cod_moneda, rp_pcpre.cod_oficina);
   else
      --- Recuperar nombre del procedimiento que ejecuta la funcion
      begin
         select fun_calculo into v_rutina
           from pr_cob_prioridades
          where nvl(cod_modulo,nvl(rp_pcpre.cod_modulo,6)) = nvl(rp_pcpre.cod_modulo,6)
            and nvl(cod_modalidad,nvl(rp_pcpre.cod_modalidad,-1)) = nvl(rp_pcpre.cod_modalidad,-1)
            and concepto = p_concepto;
      exception
         when no_data_found then
            raise_application_error(-20000,
            'No existe rutina de calculo para concepto '||p_concepto||' Modalidad '||rp_pcpre.cod_modalidad);
         when too_many_rows then
            begin
               select fun_calculo into v_rutina
                 from pr_cob_prioridades
                where cod_modulo = nvl(rp_pcpre.cod_modulo,6)
                  and cod_modalidad = nvl(rp_pcpre.cod_modalidad,-1)
                  and concepto = p_concepto;
            exception
                when no_data_found then
                   raise_application_error(-20000,
                  'No existe rutina de calculo para concepto '||p_concepto||' Modalidad '||rp_pcpre.cod_modalidad);
            end;
      end;
   end if;
   CASE v_rutina
      WHEN  'PAP_COB.PR_OBT_IMPUESTO' THEN
          PAP_COB.PR_OBT_IMPUESTO;
      WHEN  'PAP_COB.PR_OBT_CARGO_MTO_PLZ' THEN
          PAP_COB.PR_OBT_CARGO_MTO_PLZ;
      WHEN  'PAP_COB.PR_OBT_PUNITORIO' THEN
          PAP_COB.PR_OBT_PUNITORIO;
      WHEN  'PAP_COB.PR_OBT_MOR_INT_CUOTA' THEN
          PAP_COB.PR_OBT_MOR_INT_CUOTA;
      WHEN  'PAP_COB.PR_OBT_MOR_INT_ADE' THEN
          PAP_COB.PR_OBT_MOR_INT_ADE;
      WHEN  'PAP_COB.PR_OBT_MOR_CAP_CUOTA' THEN
          PAP_COB.PR_OBT_MOR_CAP_CUOTA;
      WHEN  'PAP_COB.PR_OBT_SAL_INT_ADE' THEN
          PAP_COB.PR_OBT_SAL_INT_ADE;
      WHEN  'PAP_COB.PR_OBT_SAL_INTERES' THEN
          PAP_COB.PR_OBT_SAL_INTERES;
      WHEN  'PAP_COB.PR_OBT_SAL_CAPITAL' THEN
          PAP_COB.PR_OBT_SAL_CAPITAL;
      ELSE
         v_sentencia := 'BEGIN '||v_rutina||'; END;';
         sql_util.ejecute_dml(v_sentencia, v_error);
         if v_error is not null then
            raise_application_error(-20000,'Ejecutar Concepto '||p_concepto||' '||v_error);
         end if;
   END CASE;

/* --- ejecutar en forma dinamica
   v_sentencia := 'BEGIN '||v_rutina||'; END;';
   sql_util.ejecute_dml(v_sentencia, v_error);
   if v_error is not null then
      raise_application_error(-20000,'Ejecutar Concepto '||p_concepto||' '||v_error);
   end if;
*/
   --- Actualizar parametros de salida
   rp_pctmp := pap_cob.rg_pctmp;
   return pap_cob.g_val_retorno;
END;
/* Obtener la transaccion segun el concepto en base a datos de entrada. */
FUNCTION FU_OBT_TRA_CONCEPTO
 (P_CONCEPTO IN PR_COB_PRIORIDADES.CONCEPTO%TYPE
 ,P_ESTADO IN PR_CTA_PRESTAMOS.ESTADO%TYPE
 ,P_TIPO IN PR_CTA_PRESTAMOS.TIPO%TYPE
 ,P_TIP_INTERES IN PR_CTA_PRESTAMOS.TIP_INTERES%TYPE
 ,P_TIP_RENOVACION IN PR_CTA_PRESTAMOS.TIP_RENOVACION%TYPE
 )
 RETURN NUMBER
 IS
v_cod_transaccion ge_transacciones.cod_transaccion%type := NULL;
BEGIN
   if p_concepto = 'CA' then   --- Capital
      if p_estado in ('C','A') then  --- Cuota Vigente o Vigente atrasada
         if p_tipo <> 'P' then   --- Amortizable
            v_cod_transaccion := 801;
         else
            v_cod_transaccion := 805;
         end if;
      end if;
      if p_estado in ('V') then --- Cuota Vencida
         if p_tipo <> 'P' then  --- Amortizable
            v_cod_transaccion := 820;
         else
            v_cod_transaccion := 821;
         end if;
      end if;
      if p_estado in ('G') then --- Cuota En Gestion
         v_cod_transaccion := 822;
      end if;
      if p_estado in ('M','I') then --- Cuota Morosa o Irrecuperable
         v_cod_transaccion := 823;
      end if;
   end if;
   if p_concepto in ('IA','IN') then   --- Interes o Interes Adelantado
      if p_estado in ('C','A') then
         if p_tip_interes = 'A' and p_concepto = 'IA' then
            v_cod_transaccion := 806;
         elsif p_concepto = 'IN' then
            v_cod_transaccion := 802;
         end if;
      end if;
      if p_estado = 'V' then
         if p_tip_interes = 'A' and p_concepto = 'IA' then
            v_cod_transaccion := 814;
         elsif p_concepto = 'IN' then
            v_cod_transaccion := 817;
         end if;
      end if;
      if p_estado = 'G' then
         if p_tip_interes = 'A' and p_concepto = 'IA' then
            v_cod_transaccion := 818;
         elsif p_concepto = 'IN' then
            v_cod_transaccion := 825;
         end if;
      end if;
      if p_estado in ('M','I') then
         if p_tip_interes = 'A' and p_concepto = 'IA' then
            v_cod_transaccion := 826;
         elsif p_concepto = 'IN' then
            v_cod_transaccion := 828;
         end if;
      end if;
   end if;
   if p_concepto = 'MO' then  --- Mora sobre capital
      if p_estado in ('C','A') then
         if p_tip_interes = 'A' then
            v_cod_transaccion := 810;
         else
            if p_tipo = 'P' then
               v_cod_transaccion := 807;
            else
               v_cod_transaccion := 813;
            end if;
         end if;
      end if;
      if p_estado = 'V' then
         v_cod_transaccion := 815;
      end if;
      if p_estado = 'G' then
         v_cod_transaccion := 819;
      end if;
      if p_estado IN ('M','I') then
         v_cod_transaccion := 827;
      end if;
   end if;
   if p_concepto = 'MI' then   --- Mora sobre interes
      if p_estado in ('C','A') then --- Vigente o Vigente vencida
         if p_tipo = 'P' then
            v_cod_transaccion := 835;
         else
            v_cod_transaccion := 836;
         end if;
      elsif p_estado = 'V' then
         v_cod_transaccion    := 837;
      elsif p_estado = 'G' then
         v_cod_transaccion    := 838;
      elsif p_estado IN ('M','I') then
         v_cod_transaccion    := 839;
      end if;
   end if;
   if p_concepto = 'MA' then --- Mora sobre interes adelantado
      if p_estado in ('C','A') then --- Vigente o Vigente vencida
         if p_tipo = 'P' then
            v_cod_transaccion := 830;
         else
            v_cod_transaccion := 831;
         end if;
      elsif p_estado = 'V' then
         v_cod_transaccion    := 832;
      elsif p_estado = 'G' then
         v_cod_transaccion    := 833;
      elsif p_estado IN ('M','I') then
         v_cod_transaccion    := 834;
      end if;
   end if;
   if p_concepto = 'PU' then --- Punitorio
      v_cod_transaccion    := 849;
   end if;
   if p_concepto = 'IM' then --- Impuestos
      v_cod_transaccion    := 709;
   end if;
   if p_concepto = 'CG' then --- Cargos
      v_cod_transaccion    := 712;
   end if;
   return NVL(v_cod_transaccion,-1); --- Para que de error de transaccion si no recupera nada
END;
--OBS: Transacciones de la cancelacion 359
-- 429: Cambio de estado
-- 801, 805, 820, 821, 822, 823
-- 712, 517
-- Ajustes de interes devengado
-- 902, 907, 904, 718, (719, 720 Comentado), 802, 806
-- 915, 814, 817, 916, 818, 825, 917, 826, 828, 918, 717;
/* Cancelacion de Prestamo. */
PROCEDURE PR_CAN_PRESTAMO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_MTO_CANCELADO IN PR_CTA_PRESTAMOS.MONTO%TYPE
 ,P_PED_AUTORIZACION IN VARCHAR2
 ,P_COD_OFI_ORIGEN IN PR_CTA_PRESTAMOS.COD_OFICINA%TYPE
 ,P_TIP_CANCELACION IN VARCHAR2 default 'T'
 ,P_FECHA IN GE_MOVIMIENTOS.FEC_VALOR%TYPE
 ,P_HORA IN OUT GE_MOVIMIENTOS.HORA%TYPE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_COD_MAD_RRR IN PR_CTA_PRESTAMOS.COD_MODALIDAD%TYPE DEFAULT NULL
 ,P_RENUEVA IN VARCHAR2 default 'N'
 ,P_TIP_RENOVACION IN VARCHAR2 default 'A'
 ,P_EST_MOVIMIENTO IN VARCHAR2 DEFAULT 'N'-- Ajuste Control Dual Fase 2
 )
 IS

/* Recalcular plan de pago por cancelacion parcial. */
PROCEDURE LP_REC_PLA_PAGO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 ,P_NRO_SECUENCIA IN OUT NUMBER
 );
r_pcpre         pr_cta_prestamos%rowtype;
   r_gmovi         ge_movimientos%rowtype;
   --- Variables auxiliares de calculo
   v_sal_capital   pr_cuotas.sal_capital%type;
   v_sal_interes   pr_cuotas.sal_interes%type;
   v_sal_int_ade   pr_cuotas.sal_int_documentado%type;
   v_mora          pr_cuotas.sal_interes%type;
   v_mora_interes  pr_cuotas.sal_interes%type;
   v_mora_int_ade  pr_cuotas.sal_interes%type;
   v_impuesto      pr_cuotas.sal_interes%type;
   v_cargo         pr_cuotas.sal_interes%type;
   v_cargo_iva     pr_cuotas.sal_interes%type;
   --v_seguro        pr_cuotas.sal_interes%type;
   v_punitorio     pr_cuotas.sal_interes%type;
   v_int_descontado pr_cuotas.sal_interes%type;
   v_tot_deuda     pr_cuotas.sal_capital%type;
   --v_cancela       varchar2(01);
   v_error         number(05);
   v_mensaje       varchar2(1000);
   v_dia_mora      pr_cta_prestamos.dia_atraso%type;
   --- Variables de movimientos
   v_fecha         ge_movimientos.fecha%type;
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   v_hora          ge_movimientos.hora%type;
   v_est_movim     ge_movimientos.estado%type;
   v_fec_ult_dev   pr_cta_prestamos.fec_ult_devengado%type;
   v_car_seguro    number;

/* Recalcular plan de pago por cancelacion parcial. */
PROCEDURE LP_REC_PLA_PAGO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 ,P_NRO_SECUENCIA IN OUT NUMBER
 )
 IS

/* Insercion de los cobros por cancelacion parcial. */
PROCEDURE LP_INS_COBRO_CAN_PAR
 (RP_PCOBR IN PR_COBROS%ROWTYPE
 );
--- Declarar registros de prestamos por cancelacion
   r_pcanc           pr_cta_prestamos%rowtype;
   r_pcobr           pr_cobros%rowtype;
   --- Variables auxiliares
   v_nro_cuota           pr_cuotas.nro_cuota%type;
   v_cod_persona         pr_solicitudes.cod_persona%type;
   v_fec_vto_ant_cuota   DATE;
   v_fec_vto_inicio      DATE;
   v_sal_capital         pr_cuotas.sal_capital%type;
   v_interd              number;
   v_interes             pr_cuotas.sal_interes%type;
   v_cant_dias           number(05);
   v_contador            number(06) := 0;
   v_dia                 number(01);
   v_cont_c              number(03) := 1;
   v_per_vto_interes     pr_sol_tasas.per_vencimiento%type;
   v_fec_capital         date;
   v_cont_i              number(03) := 1;
   v_fec_interes         date;
   v_fec_vto_ant         date;
   v_recalcula           varchar2(01) := 'S';
   v_cod_mon_local       ba_monedas.cod_moneda%type;
   v_mto_int_actual      pr_cuotas.mto_interes%type;
   v_mto_int_ade_actual  pr_cuotas.mto_interes%type;
   v_mto_int_ant         pr_cuotas.mto_interes%type;
   v_mto_int_ade_ant     pr_cuotas.mto_interes%type;
   v_fec_vto_cuota       pr_cuotas.fec_vencimiento%type;
   v_sal_int_actual      pr_cuotas.mto_interes%type;
   v_sal_int_ade_actual  pr_cuotas.mto_interes%type;
   v_dif_int             pr_cuotas.mto_interes%type;
   v_dif_int_ade         pr_cuotas.mto_int_documentado%type;
   v_cuota_recalculada   varchar2(01) := 'N';
   v_cuo_recal_inicio    pr_cuotas.nro_cuota%type;
   v_cuo_recal_final     pr_cuotas.nro_cuota%type;
   v_redondeo            number(5);
   --- Declara cuotas del prestamo
   cursor c_cuo_cancela is
   select *
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and nro_cuota >= v_nro_cuota
      and estado <> 'N'
    order by nro_cuota;

/* Insercion de los cobros por cancelacion parcial. */
PROCEDURE LP_INS_COBRO_CAN_PAR
 (RP_PCOBR IN PR_COBROS%ROWTYPE
 )
 IS
BEGIN
   insert into pr_cobros(
      nro_cuenta, nro_cuota, fecha, hora,
      fec_vencimiento, estado, sal_capital_pre,
      sal_interes_pre, sal_capital_cuo, sal_interes_cuo,
      sal_int_documentado, fec_ult_pago, dia_mora,
      mto_capital, mto_interes, mto_int_documentado,
      mto_int_moratorio, mto_int_mor_interes, mto_int_mor_adelantado,
      mto_int_punitorio, mto_cargo, mto_cargo_iva, mto_impuesto,
      mto_int_descontado, nro_documento)
   values(
      rp_pcobr.nro_cuenta, rp_pcobr.nro_cuota, rp_pcobr.fecha, rp_pcobr.hora,
      rp_pcobr.fec_vencimiento, rp_pcobr.estado, rp_pcobr.sal_capital_pre,
      rp_pcobr.sal_interes_pre, rp_pcobr.sal_capital_cuo, rp_pcobr.sal_interes_cuo,
      rp_pcobr.sal_int_documentado, rp_pcobr.fec_ult_pago, rp_pcobr.dia_mora,
      rp_pcobr.mto_capital, rp_pcobr.mto_interes, rp_pcobr.mto_int_documentado,
      rp_pcobr.mto_int_moratorio, rp_pcobr.mto_int_mor_interes, rp_pcobr.mto_int_mor_adelantado,
      rp_pcobr.mto_int_punitorio, rp_pcobr.mto_cargo, rp_pcobr.mto_cargo_iva, rp_pcobr.mto_impuesto,
      rp_pcobr.mto_int_descontado, rp_pcobr.nro_documento);
END;
BEGIN
   --- Recuperar moneda local
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   --- Recuperar datos actuales del prestamo
   PAP_PRE_RES_04.pr_obt_dat_prestamo(p_nro_cuenta, r_pcanc);
   Begin
     Select cod_persona into v_cod_persona
       from pr_solicitudes
      where nro_solicitud = r_pcanc.nro_solicitud;
   Exception
     when others then
       v_cod_persona := null;
   End;
   v_interd := r_pcanc.val_tasa / 36500;
   --- Recuperar datos actuales de intereses
   select sum(mto_interes), sum(mto_int_documentado)
     into v_mto_int_ant, v_mto_int_ade_ant
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta;
   --- Recuperar minima cuota no pagada
   select min(nro_cuota) into v_nro_cuota
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and estado <> 'N';
   --- Cargar periodo de vencimiento de interes
   v_per_vto_interes   := r_pcanc.per_vto_interes;
   --- el calculo se hace a partir del saldo actual----------------
   v_sal_capital       := r_pcanc.sal_capital;
   v_cuota_recalculada := 'N';
   v_cuo_recal_inicio  := null;
   v_cuo_recal_final   := null;
   if r_pcanc.tipo = 'P' then
      begin
         --- Busco vencimiento anterior -----------------------------
         select max(fec_vencimiento)
           into v_fec_vto_ant_cuota
           from pr_cuotas
          where nro_cuenta = p_nro_cuenta
            and nro_cuota > 0
            and nro_cuota <= v_nro_cuota;
         if v_fec_vto_ant_cuota is null then
            v_fec_vto_ant_cuota := r_pcanc.fec_inicio;
         end if;
         v_fec_vto_inicio := v_fec_vto_ant_cuota;
      exception
         when no_data_found then
            v_fec_vto_ant_cuota := r_pcanc.fec_inicio;
            v_fec_vto_inicio    := r_pcanc.fec_inicio;
      end;
   else
      --- el primer venc. sera a partir de la canc. parcial
      v_fec_vto_ant_cuota := p_fecha;
      v_fec_vto_inicio    := p_fecha;
   end if;
   v_fec_capital := p_fecha;
   v_fec_interes := p_fecha;
   v_per_vto_interes := 30;
   for cta in c_cuo_cancela loop
      v_contador := nvl(v_contador,0) + 1;
      if v_contador = 1 then
         v_cont_i := cta.fec_vencimiento - v_fec_interes;
      else
         v_cont_i := cta.fec_vencimiento - v_fec_vto_ant;
      end if;
      v_cont_c      := v_cont_i;
      v_fec_vto_ant := cta.fec_vencimiento;
      v_fec_capital := v_fec_capital + v_cont_c;
      v_fec_interes := v_fec_capital;
      loop
         select decode(cta.mto_capital,0,to_char(v_fec_interes,'d'),to_char(v_fec_capital,'d')),
                decode(cta.mto_capital,0,v_fec_interes,v_fec_capital)
           into v_dia, v_fecha from dual;
         if v_dia in (1,7) or fue_ctr_fec_feriado(p_fecha, r_pcanc.cod_oficina) then
            if cta.mto_capital = 0 then
               v_fec_interes := v_fec_interes + 1;
            else
               v_fec_capital := v_fec_capital + 1;
            end if;
         else
            exit;
         end if;
      end loop;
      if v_contador = 1 then
         if cta.mto_capital = 0 then
            v_cant_dias := (v_fec_interes - p_fecha);
            v_cant_dias := v_cant_dias + p_fecha - p_fecha;
            v_cont_i    := v_cont_i + 1;
         else
            v_cant_dias := (v_fec_capital - p_fecha);
            v_cant_dias := v_cant_dias + p_fecha - p_fecha;
            if v_per_vto_interes * v_cont_i = r_pcanc.per_vto_capital*v_cont_c then
               v_cont_i := v_cont_i + 1;
            end if;
            v_cont_c := v_cont_c + 1;
         end if;
      else
         if cta.mto_capital = 0 then
            v_cant_dias := (v_fec_interes - v_fec_vto_inicio);
            v_cont_i    := v_cont_i + 1;
         else
            v_cant_dias := (v_fec_capital - v_fec_vto_inicio);
            if v_per_vto_interes * v_cont_i = r_pcanc.per_vto_capital * v_cont_c then
               v_cont_i := v_cont_i + 1;
            end if;
            v_cont_c := v_cont_c + 1;
         end if;
      end if;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, r_pcanc.cod_modalidad, r_pcanc.cod_moneda);
      v_interes := round((v_sal_capital * v_interd * v_cant_dias),v_redondeo);
      --- Cargos datos para cobros por si se genera
      r_pcobr.nro_cuenta          := p_nro_cuenta;
      --r_pcobr.nro_cuota           := cta.nro_cuenta;
      --RI:13/07/2010: Estaba asignando mal la cuenta al nro. de cuota
      r_pcobr.nro_cuota           := cta.nro_cuota;
      r_pcobr.fec_valor           := p_fecha; --fecha valor, la otra es fecha actual
      r_pcobr.fecha               := PAG_CAL.FU_OBT_FEC_ACTUAL(6); --p_fecha;
      r_pcobr.hora                := p_hora;
      r_pcobr.fec_vencimiento     := cta.fec_vencimiento;
      r_pcobr.estado              := cta.estado;
      r_pcobr.sal_capital_cuo     := cta.sal_capital;
      r_pcobr.sal_interes_cuo     := cta.sal_interes;
      r_pcobr.sal_int_documentado := cta.sal_int_documentado;
      r_pcobr.fec_ult_pago        := cta.fec_ult_pago;
      r_pcobr.mto_capital         := cta.mto_capital;
      r_pcobr.mto_interes         := cta.mto_interes;
      r_pcobr.mto_int_documentado := cta.mto_int_documentado;
      r_pcobr.nro_documento       := cta.nro_documento;
      if nvl(v_interes,0) > 0 then
         --- Genera cobro antes de modificar la cuota
         v_cuota_recalculada := 'S';
         if v_cuo_recal_inicio is null then
            v_cuo_recal_inicio := cta.nro_cuota;
         end if;
         v_cuo_recal_final     := cta.nro_cuota;
         lp_ins_cobro_can_par(r_pcobr);
         update pr_cuotas
            set mto_interes = decode(cta.mto_interes,0,0,v_interes),
                sal_interes = decode(cta.mto_interes,0,0,v_interes),
                fec_vencimiento = decode(v_recalcula,'S', v_fec_capital, cta.fec_vencimiento)
          where nro_cuenta = p_nro_cuenta
            and nro_cuota  = cta.nro_cuota;
      else
         --- Genera cobro antes de eliminar la cuota
         v_cuota_recalculada := 'S';
         if v_cuo_recal_inicio is null then
            v_cuo_recal_inicio := cta.nro_cuota;
         end if;
         v_cuo_recal_final     := cta.nro_cuota;
         lp_ins_cobro_can_par(r_pcobr);
         delete pr_cuotas
          where nro_cuenta = p_nro_cuenta
            and nro_cuota  = cta.nro_cuota;
      end if;
      v_sal_capital := nvl(v_sal_capital,0) - nvl(cta.sal_capital,0);
      if cta.mto_capital = 0 then
            v_fec_vto_inicio    := v_fec_interes;
            v_fec_vto_ant_cuota := v_fec_interes;
         else
            v_fec_vto_inicio    := v_fec_capital;
            v_fec_vto_ant_cuota := v_fec_capital;
      end if;
   end loop;
   --- Verificar como se actualiza el maestro
   select sum(mto_interes), sum(mto_int_documentado), max(fec_vencimiento),
          sum(sal_interes), sum(sal_int_documentado)
     into v_mto_int_actual, v_mto_int_ade_actual, v_fec_vto_cuota,
          v_sal_int_actual, v_sal_int_ade_actual
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and estado     <> 'N'
      and nro_cuota  > 0;
   --- Verificar diferencias de intereses para generar asientos
   v_dif_int     := v_mto_int_ant - v_mto_int_actual;
   v_dif_int_ade := v_mto_int_ade_ant - v_mto_int_ade_actual;
   --- Actualizar prestamos
   update pr_cta_prestamos
      set fec_vencimiento = v_fec_vto_cuota,
          sal_int_adelantado = v_sal_int_ade_actual,
          sal_interes        = v_sal_int_actual,
          val_int_devengar   = decode(nvl(v_sal_int_actual,0),0,v_sal_Int_ade_actual,v_sal_int_actual)
    where nro_cuenta = p_nro_cuenta;
   --- Generar movimiento por diferencia de intereses
   r_gmovi.cod_usuario    := user;
   r_gmovi.hora           := p_hora;
   r_gmovi.fecha          := PAG_CAL.FU_OBT_FEC_ACTUAL(6); --p_fecha;
   r_gmovi.cod_modulo     := r_pcanc.cod_modulo;
   r_gmovi.cod_modalidad  := r_pcanc.cod_modalidad;
   r_gmovi.cod_oficina    := r_pcanc.cod_oficina;
   r_gmovi.nro_cuenta     := p_nro_cuenta;
   r_gmovi.cod_moneda     := r_pcanc.cod_moneda;
   r_gmovi.est_cuenta     := r_pcanc.estado;
   r_gmovi.cod_persona    := v_cod_persona;
   r_gmovi.cod_tra_padre  := 359;
   r_gmovi.fec_valor      := p_fecha;
   r_gmovi.reversado      := 'N';
   r_gmovi.protegido      := 'N';
   r_gmovi.estado         := 'N';
   r_gmovi.cod_ofi_origen := p_cod_ofi_origen;
   r_gmovi.cod_mod_padre  := r_pcanc.cod_modulo;
   r_gmovi.cod_mad_padre  := r_pcanc.cod_modalidad;
   r_gmovi.nro_documento  := r_pcanc.nro_documento;
   r_gmovi.nro_documento2 := null;
   r_gmovi.nro_documento3 := null;
   r_gmovi.concepto       := 'Cancelacion parcial';
   p_nro_secuencia        := p_nro_secuencia + 1;
   r_gmovi.nro_secuencia  := p_nro_secuencia;
   r_gmovi.emi_aviso      := 'N';
   if v_dif_int <> 0 then
      r_gmovi.monto       := v_dif_int;
   else
      r_gmovi.monto       := v_dif_int_ade;
   end if;
   r_gmovi.cod_transaccion := 746;
   pag_gen.pr_ins_ge_movimiento(r_gmovi);
   --- Movimiento del a devengar
   r_gmovi.cod_usuario    := user;
   r_gmovi.hora           := p_hora;
   r_gmovi.fecha          := PAG_CAL.FU_OBT_FEC_ACTUAL(6);--p_fecha;
   r_gmovi.cod_modulo     := r_pcanc.cod_modulo;
   r_gmovi.cod_modalidad  := r_pcanc.cod_modalidad;
   r_gmovi.cod_oficina    := r_pcanc.cod_oficina;
   r_gmovi.nro_cuenta     := p_nro_cuenta;
   r_gmovi.cod_persona    := v_cod_persona;
   r_gmovi.cod_moneda     := r_pcanc.cod_moneda;
   r_gmovi.est_cuenta     := r_pcanc.estado;
   r_gmovi.cod_tra_padre  := 359;
   r_gmovi.fec_valor      := p_fecha;
   r_gmovi.reversado      := 'N';
   r_gmovi.protegido      := 'N';
   r_gmovi.estado         := 'N';
   r_gmovi.cod_ofi_origen := p_cod_ofi_origen;
   r_gmovi.cod_mod_padre  := r_pcanc.cod_modulo;
   r_gmovi.cod_mad_padre  := r_pcanc.cod_modalidad;
   r_gmovi.nro_documento  := r_pcanc.nro_documento;
   r_gmovi.nro_documento2 := null;
   r_gmovi.nro_documento3 := null;
   r_gmovi.concepto       := 'Cancelacion parcial';
   p_nro_secuencia        := p_nro_secuencia + 1;
   r_gmovi.nro_secuencia  := p_nro_secuencia;
   r_gmovi.emi_aviso      := 'N';
   if v_dif_int <> 0 then
      r_gmovi.monto       := nvl(v_dif_int,0) * -1;
   else
      r_gmovi.monto       := nvl(v_dif_int_ade,0) * -1;
   end if;
   r_gmovi.cod_transaccion := 718;
   pag_gen.pr_ins_ge_movimiento(r_gmovi);
   ---- Insertar Movimiento por el recalculo de las cuotas
   if v_cuota_recalculada = 'S' then
      r_gmovi.cod_usuario     := user;
      r_gmovi.hora            := p_hora;
      r_gmovi.fecha           := PAG_CAL.FU_OBT_FEC_ACTUAL(6);--p_fecha;
      r_gmovi.cod_modulo      := r_pcanc.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcanc.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcanc.cod_oficina;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_persona    := v_cod_persona;
      r_gmovi.cod_moneda      := r_pcanc.cod_moneda;
      r_gmovi.est_cuenta      := r_pcanc.estado;
      r_gmovi.cod_tra_padre   := 359;
      r_gmovi.fec_valor       := p_fecha;
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
      r_gmovi.cod_mod_padre   := r_pcanc.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcanc.cod_modalidad;
      r_gmovi.nro_documento   := v_cuo_recal_inicio;
      r_gmovi.nro_documento2  := v_cuo_recal_final;
      r_gmovi.nro_documento3  := null;
      r_gmovi.concepto        := 'Canc. parcial-restructuracion';
      p_nro_secuencia         := p_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := p_nro_secuencia;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.monto           := null;
      r_gmovi.cod_transaccion := 747; --- Modificacion del plan de pago Original
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   end if;
END;
BEGIN
   --- Recuperar datos de la cuenta de prestamos
   PAP_PRE_RES_04.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);
   pap_cob.rg_pcpre := r_pcpre;
   v_fec_ult_dev := nvl(r_pcpre.fec_ult_devengado,r_pcpre.fec_inicio);
   --- Inicializar datos del movimiento
   v_fecha         := p_fecha;
   v_hora          := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));
   v_nro_secuencia := nvl(p_nro_secuencia,0);
   if nvl(p_ped_autorizacion,'N') = 'S' then
      v_est_movim := 'X';
   else
      v_est_movim := 'N';
   end if;
   --- Recuperar deuda total del prestamo
   PAP_PRE_RES_04.pr_ini_autorizacion;
   if p_tip_cancelacion = 'T' then
      --- Total de las cuotas
      PAP_PRE_RES_04.pr_obt_deu_prestamo(p_nro_cuenta, p_fecha, 0, 999,
         p_cod_ofi_origen, null, v_error, v_mensaje,
         v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
         v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
         v_dia_mora, 359, p_tip_cancelacion,p_renueva); --- Cancelacion Total
   else --- Recuperar deuda a la fecha
      PAP_PRE_RES_04.pr_obt_deu_prestamo(p_nro_cuenta, p_fecha, null, null,
         p_cod_ofi_origen, null, v_error, v_mensaje,
         v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
         v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
         v_dia_mora, 359, p_tip_cancelacion,p_renueva); --- Cancelacion anticipada
   end if;
   if v_error <> 0 then
      raise_application_error(-20000, v_mensaje);
   end if;
   if  p_tip_renovacion = 'D' then -- desembolso en etapas (no cobrar seguro)
      PAP_PRE_RES_04.pr_obt_car_seg_cuotas(p_nro_cuenta,v_car_seguro);
   End if;
   v_tot_deuda := nvl(v_sal_capital,0)  + nvl(v_sal_interes,0)  + nvl(v_sal_int_ade,0)  +
                  nvl(v_mora,0)         + nvl(v_mora_interes,0) + nvl(v_mora_int_ade,0) +
                  nvl(v_punitorio,0)    + nvl(v_impuesto,0)     + nvl(v_cargo,0);
                  --(nvl(v_cargo,0)-nvl(v_car_seguro,0));
   if p_mto_cancelado < v_tot_deuda then
      raise_application_error(-20000,
      'Monto a abonar no alcanza a cancelar la deuda '||v_tot_deuda);
   end if;
   -- Realizar el cobro del prestamo ---
   PAP_PRE_RES_04.pr_cob_prestamo(p_nro_cuenta,
                           p_mto_cancelado,
                           'N', --- Se pidio autorizacion
                           p_cod_ofi_origen, --- oficina origen
                           null,
                           null,
                           'CANCELACION DE PRESTAMO '||p_nro_cuenta,
                           p_fecha,
                           v_hora,
                           v_nro_secuencia,
                           359, 6, r_pcpre.cod_modalidad, p_tip_cancelacion,
                           P_COD_MAD_RRR,p_renueva,p_est_movimiento);
   --- Cancelacion parcial --- regenerar cuotas
   if p_tip_cancelacion = 'P' then
      --- Recuperar saldo actual del prestamo
      lp_rec_pla_pago(p_nro_cuenta, p_fecha, v_hora, v_nro_secuencia);
   end if;
   --- Inicializar variables de cobro
   PAP_PRE_RES_04.pr_ini_var_cobro;
   --- Retornar secuencia
   p_nro_secuencia := v_nro_secuencia;
END;
/* Obtiene la autorizacion previa del concepto. */
PROCEDURE PR_OBT_AUT_PREVIA
 (P_NRO_CUENTA IN GE_AUTORIZACIONES.NRO_CUENTA%TYPE
 ,P_FECHA IN GE_AUTORIZACIONES.FEC_VENCIMIENTO%TYPE
 ,P_COD_TRA_PADRE IN GE_AUTORIZACIONES.COD_TRA_PADRE%TYPE
 ,P_COD_MOD_PADRE IN GE_AUTORIZACIONES.COD_MOD_PADRE%TYPE
 ,P_COD_MAD_PADRE IN GE_AUTORIZACIONES.COD_MAD_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_AUTORIZACIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_AUTORIZACIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_AUTORIZACIONES.COD_MODALIDAD%TYPE
 ,P_MONTO IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 ,P_EXIMIDO IN OUT GE_AUTORIZACIONES.EXIMIDO%TYPE
 ,P_COD_AUTORIZACION IN OUT GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_COD_USU_AUTORIZADOR IN OUT GE_AUTORIZACIONES.COD_USU_AUTORIZADOR%TYPE
 )
 IS
BEGIN
   -- Busco los datos de la autorizacion
   Select COD_AUTORIZACION, VALOR, EXIMIDO, COD_USU_AUTORIZADOR
     into p_cod_autorizacion, P_MONTO, P_EXIMIDO, p_cod_usu_autorizador
     from GE_AUTORIZACIONES
    where NRO_CUENTA      = p_nro_cuenta
      and COD_TRANSACCION = p_cod_transaccion
      and cod_modulo      = p_cod_modulo
      and cod_modalidad   = p_cod_modalidad
      and COD_TRA_padre   = p_cod_tra_padre
      and cod_mod_padre   = p_cod_mod_padre
      and cod_mad_padre   = p_cod_mad_padre
      and cod_usu_utilizador is null    -- que no fue utilizado por nadie
      and fec_vencimiento    >= p_fecha -- que no este vencido
      and rownum = 1;                   -- el primero que exista
EXCEPTION
   when no_data_found then
      p_cod_autorizacion := null;
      p_monto            := null;
      p_eximido          := null;
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20001, 'Error en PR_OBT_AUTORIZACION '||sqlerrm);
      end if;
END;
/* Inicializar variables de autorizacion para procesar x cuotas o total */
PROCEDURE PR_INI_AUTORIZACION
 IS
BEGIN
   pap_cob.g_cod_aut_interes   := null;
   pap_cob.g_cod_aut_int_ade   := null;
   pap_cob.g_cod_aut_mor_cap   := null;
   pap_cob.g_cod_aut_mor_int   := null;
   pap_cob.g_cod_aut_mor_ade   := null;
   pap_cob.g_cod_aut_punitorio := null;
   pap_cob.g_cod_aut_impuesto  := null;
   pap_cob.g_cod_aut_cargos    := null;
   pap_cob.g_sal_val_interes   := null;
   pap_cob.g_sal_val_int_ade   := null;
   pap_cob.g_sal_val_mor_cap   := null;
   pap_cob.g_sal_val_mor_int   := null;
   pap_cob.g_sal_val_mor_ade   := null;
   pap_cob.g_sal_val_punitorio := null;
   pap_cob.g_sal_val_impuesto  := null;
   pap_cob.g_sal_val_cargos    := null;
   pap_cob.g_exi_interes       := null;
   pap_cob.g_exi_int_ade       := null;
   pap_cob.g_exi_mor_cap       := null;
   pap_cob.g_exi_mor_int       := null;
   pap_cob.g_exi_mor_ade       := null;
   pap_cob.g_exi_punitorio     := null;
   pap_cob.g_exi_impuesto      := null;
   pap_cob.g_exi_cargos        := null;
   pap_cob.g_uti_gastos        := 'N';
END;
/* Inicializar variables globales de cobro */
PROCEDURE PR_INI_VAR_COBRO
 IS
BEGIN
   pap_cob.G_TIP_CANCELACION := NULL;
   pap_cob.RG_PCPRE          := null;
   pap_cob.RG_PCUOT          := null;
   pap_cob.RG_PCTMP          := null;
   pap_cob.G_CAP_PAGADO      := null;
   pap_cob.G_TOT_CAP_ADE     := null;
   pap_cob.G_SAL_ANTERIOR    := null;
   pap_cob.G_DEV_NO_COBRADO  := null;
   pap_cob.G_SAL_CAPITAL_PRE := null;
   pap_cob.G_TOT_INT_PAG     := null;
   pap_cob.G_PRI_VEZ         := null;
END;
/* Obtener deuda total de prestamos que se renuevan por la solicitud. */
PROCEDURE PR_OBT_REN_SOLICITUD
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_FECHA IN DATE
 ,P_COD_OFI_ORIGEN IN PR_SOLICITUDES.COD_OFICINA%TYPE
 ,P_MTO_DEUDA IN OUT PR_SOLICITUDES.MONTO%TYPE
 )
 IS
   v_error               number(05);
   v_mensaje             varchar2(250);
   v_tot_sal_capital     pr_cuotas.sal_capital%type;
   v_tot_sal_interes     pr_cuotas.sal_interes%type;
   v_tot_sal_int_ade     pr_cuotas.sal_interes%type;
   v_tot_mora            pr_cuotas.val_recargo%type;
   v_tot_mor_interes     pr_cuotas.val_recargo%type;
   v_tot_mor_int_ade     pr_cuotas.val_recargo%type;
   v_tot_punitorio       pr_cuotas.val_recargo%type;
   v_tot_impuesto        pr_cuotas.val_recargo%type;
   v_tot_cargo           pr_cuotas.val_recargo%type;
   v_tot_car_iva         pr_cuotas.val_recargo%type;
   v_tot_int_descontado  pr_cuotas.sal_interes%type;
   v_tot_deuda           pr_cta_prestamos.monto%type;
   v_dia_mora            pr_cta_prestamos.dia_atraso%type;
   v_deu_cuenta          pr_cta_prestamos.monto%type;
   v_cot_aux             ge_cotizaciones.val_conversion%type;
   v_car_seguro          pr_cuotas.sal_interes%type;
   --- Cursor de prestamos que estan siendo refinanciados o renovados
   cursor c_renovaciones is
   select p.nro_cuenta, p.cod_moneda cod_mon_origen, s.cod_moneda cod_mon_destino,
          s.tip_renovacion, p.cod_modulo
     from pr_cta_prestamos p, pr_solicitudes s
    where p.nro_sol_renovada = p_nro_solicitud
      and s.nro_solicitud = p.nro_sol_renovada
      and p.estado <> 'N'
    union
   select v.nro_cuenta, v.cod_moneda cod_mon_origen, s.cod_moneda cod_mon_destino,
          s.tip_renovacion, v.cod_modulo
     from ov_cta_vencidas v, pr_solicitudes s
    where v.nro_sol_renovada = p_nro_solicitud
      and s.nro_solicitud = v.nro_sol_renovada
      and v.estado <> 'C';
BEGIN
   v_tot_deuda := 0;
   for cta in c_renovaciones loop
      v_cot_aux   := null;
      --- Recuperar datos de la deuda
      if cta.cod_modulo = 6 then
         PAP_PRE_RES_04.pr_ini_autorizacion;
         PAP_PRE_RES_04.pr_obt_deu_prestamo(cta.nro_cuenta, p_fecha, 0, 999,
                                     p_cod_ofi_origen, null, v_error, v_mensaje,
                                     v_tot_sal_capital, v_tot_sal_interes, v_tot_sal_int_ade,
                                     v_tot_mora, v_tot_mor_interes, v_tot_mor_int_ade,
                                     v_tot_punitorio, v_tot_impuesto,
                                     v_tot_cargo, v_tot_car_iva, v_tot_int_descontado,
                                     v_dia_mora, 359, 'T','S');
         if v_error <> 0 then
            raise_application_error(-20001,v_mensaje);
         end if;
         if cta.tip_renovacion = 'D' then   -- desembolso en etapas
           PAP_PRE_RES_04.pr_obt_car_seg_cuotas(cta.nro_cuenta,v_car_seguro);
         end if;
         v_deu_cuenta := nvl(v_tot_sal_capital,0) +
                         nvl(v_tot_sal_int_ade,0) +
                         nvl(v_tot_sal_interes,0) +
                         nvl(v_tot_mora,0)        +
                         nvl(v_tot_mor_interes,0) +
                         nvl(v_tot_mor_int_ade,0) +
                         nvl(v_tot_punitorio,0)   +
                         nvl(v_tot_impuesto,0)    +
                         (nvl(v_tot_cargo,0)-nvl(v_car_seguro,0));
         PAP_PRE_RES_04.pr_ini_var_cobro;
      elsif cta.cod_modulo = 15 then
         pav_ove.pr_obt_deu_ope_vencida(cta.nro_cuenta,p_fecha,null,v_error,v_mensaje,
         v_tot_sal_capital,v_tot_mora,v_tot_punitorio, v_tot_impuesto,
                                     v_tot_cargo,v_tot_car_iva,v_dia_mora,359);
          if v_error <> 0 then
            raise_application_error(-20001,v_mensaje);
          end if;

          v_deu_cuenta := nvl(v_tot_sal_capital,0) +
                        nvl(v_tot_mora,0) +
                        nvl(v_tot_punitorio,0) +
                        nvl(v_tot_impuesto,0) +
                        nvl(v_tot_cargo,0);
      end if;
      --- Convertir la deuda a la moneda de la solicitud si nos diferentes
      if cta.cod_mon_origen <> cta.cod_mon_destino then
         v_gen_boleteo := 'S'; -- Indica si generará boleteo
         pag_gen.PR_CON_MON_A_MONEDA(cta.cod_mon_origen, cta.cod_mon_destino,
                                     v_deu_cuenta, v_deu_cuenta, v_cot_aux, v_cot_aux);
      end if;
      v_tot_deuda := nvl(v_tot_deuda,0) +
                     nvl(v_deu_cuenta,0);
      PAP_PRE_RES_04.pr_ini_var_cobro;
   end loop;
   p_mto_deuda := nvl(v_tot_deuda,0);
END;
/* Permite obtener los datos de la cuenta de prestamos. */
PROCEDURE PR_OBT_DAT_PRESTAMO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_PCPRE IN OUT PR_CTA_PRESTAMOS%ROWTYPE
 )
 IS
BEGIN
   select *
     into rp_pcpre
     from pr_cta_prestamos
    where nro_cuenta = p_nro_cuenta;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Cuenta de prestamo '||p_nro_cuenta||' no registrada');
END;
/* Obtener tasas de pizarra. */
PROCEDURE PR_OBT_TAS_PIZARRA
 (P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_PLAZO IN NUMBER
 ,P_MONTO IN GE_CUENTAS.SAL_PROMEDIO%TYPE
 ,P_TIP_CAPITALIZACION IN CR_PIZ_PLAZOS.TIP_CAPITALIZACION%TYPE
 ,P_TAS_MINIMA IN OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_TAS_MAXIMA IN OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_TAS_INTERES IN OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_TAS_EFECTIVA IN OUT CR_PIZ_PLAZOS.TAS_EFECTIVA%TYPE
 ,P_COD_SUB_MODALIDAD IN GE_CUENTAS.COD_SUB_MODALIDAD%TYPE DEFAULT NULL
 )
 IS
BEGIN
  SELECT tas_minima, tas_maxima, tas_interes, tas_efectiva
    into p_tas_minima, p_tas_maxima, p_tas_interes, p_tas_efectiva
    FROM CR_PIZ_PLAZOS b, CR_PIZ_MONTOS a
   WHERE B.COD_MONEDA      = p_cod_moneda
     AND B.COD_MODULO      = p_cod_modulo
     AND B.COD_MODALIDAD   = p_cod_modalidad
     and p_plazo between b.plz_desde and b.plz_hasta
     and p_monto between a.mto_desde and a.mto_hasta
     and nvl(b.tip_capitalizacion,nvl(p_tip_capitalizacion,0)) = nvl(p_tip_capitalizacion,0)
     AND A.COD_MONEDA      = p_cod_moneda
     AND A.COD_MODULO      = p_cod_modulo
     AND A.COD_MODALIDAD   = p_cod_modalidad
     AND A.MTO_DESDE       = B.MTO_DESDE
     AND nvl(b.cod_sub_modalidad,-1) = nvl(p_cod_sub_modalidad,-1)
     AND nvl(a.cod_sub_modalidad,-1) = nvl(p_cod_sub_modalidad,-1);
exception
   when no_data_found then
      -- se ponen los valores a cero para que no se corte la grabacion
      p_tas_minima   := 0;
      p_tas_maxima   := 0;
      p_tas_interes  := 0;
      p_tas_efectiva := 0;
   when too_many_rows then
      --- Existe especificacion para nulos y tipo de capitalizacion
      BEGIN
         SELECT tas_minima, tas_maxima, tas_interes, tas_efectiva
           into p_tas_minima, p_tas_maxima, p_tas_interes, p_tas_efectiva
           FROM CR_PIZ_MONTOS a ,CR_PIZ_PLAZOS b
          WHERE B.COD_MONEDA      = p_cod_moneda
            AND B.COD_MODULO      = p_cod_modulo
            AND B.COD_MODALIDAD   = p_cod_modalidad
            and p_plazo between b.plz_desde and b.plz_hasta
            and p_monto between a.mto_desde and a.mto_hasta
            and b.tip_capitalizacion IS NULL
            AND A.COD_MONEDA      = p_cod_moneda
            AND A.COD_MODULO      = p_cod_modulo
            AND A.COD_MODALIDAD   = p_cod_modalidad
            AND A.MTO_DESDE       = B.MTO_DESDE;
         exception
            when no_data_found then
               raise_application_error(-20000, 'Tasa de pizarra no definida');
            when too_many_rows then
               raise_application_error(-20000, 'Existe mas de una pizarra definida');
      END;
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000, 'Obt. Tasa Pizarra '||sqlerrm);
      end if;
End;
/* Obtener tasa de la solicitud. */
FUNCTION FU_OBT_TAS_SOL
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_PER_VTO_INTERES IN OUT PR_SOL_TASAS.PER_VENCIMIENTO%TYPE
 )
 RETURN NUMBER
 IS
v_val_tasa pr_sol_tasas.val_tasa%type;
BEGIN
   select val_tasa, per_vencimiento
     into v_val_tasa, p_per_vto_interes
     from pr_sol_tasas
    where nro_solicitud = p_nro_solicitud
      and fec_vigencia = (select max(fec_vigencia)
                            from pr_sol_tasas
                           where nro_solicitud = p_nro_solicitud);
   return v_val_tasa;
END;

PROCEDURE PR_REC_CUOTAS
/*verificar si se usa*/
(p_nro_cuenta     in varchar2,
 p_cap_amortizado in number,
 p_int_amortizado in number,
 p_fec_pago       in date,
 p_nro_secuencia  in out number,
 p_cod_usuario    in varchar2 default user,
 p_hora           in varchar2 default to_char(sysdate,'HH24:MI:SS'),
 p_cod_ofi_origen in number default null
  ) is
-- cuotas pendientes de pago
cursor cuotas is
  select *
     from pr_cuotas
    where nro_cuenta = p_nro_cuenta
      and estado <> 'N'
      and nro_cuota <> 0
    order by nro_cuota
      for update;
  v_fec_ven_anterior date := p_fec_pago;
  v_sal_capital      number := 0;
  v_val_tasa         number := 0;
  v_sal_anterior     number := 0;
  v_dias             number(6);
  v_cap_adelantado   number(18,2);
  v_int_nuevo        number(18,2);
  v_int_descontado   number(18,2);
  v_sal_interes      number(18,2);
  v_int_amortizado   number(18,2);
  v_redondeo         number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6);
  v_cod_moneda       varchar2(5);
  v_int_pagado       number(18,2);
  v_can_cuotas       number(8);
  v_tot_cap_adelantado number(18,2) := 0;
  v_tot_int_descontado number(18,2) := 0;
  r_pcobr            pr_cobros%rowtype;
  r_gmovi            ge_movimientos%rowtype;
  v_cod_modulo       ge_movimientos.cod_modulo%type;
  v_cod_modalidad    ge_movimientos.cod_modalidad%type;
  v_cod_oficina      ge_movimientos.cod_oficina%type;
  v_nro_solicitud    pr_solicitudes.nro_solicitud%type;
  v_cod_persona      pr_solicitudes.cod_persona%type;
  v_estado           pr_cta_prestamos.estado%type;
  v_fec_ult_devengado pr_cta_prestamos.fec_ult_devengado%type;
  v_tipo             pr_cta_prestamos.tipo%type;
  v_tip_interes      pr_cta_prestamos.tip_interes%type;
  v_tip_renovacion   pr_cta_prestamos.tip_renovacion%type;
/* Insercion de los cobros por cancelacion parcial. */
PROCEDURE LP_INS_COBRO_CAN_PAR
 (RP_PCOBR IN PR_COBROS%ROWTYPE
 )
 IS
BEGIN
   insert into pr_cobros
       (nro_cuenta, nro_cuota, fecha, hora, fec_vencimiento, estado, sal_capital_pre,
        sal_interes_pre, sal_capital_cuo, sal_interes_cuo, sal_int_documentado, fec_ult_pago, dia_mora,
        mto_capital, mto_interes, mto_int_documentado, mto_int_moratorio, mto_int_mor_interes, mto_int_mor_adelantado,
        mto_int_punitorio, mto_cargo, mto_cargo_iva, mto_impuesto, mto_int_descontado, nro_documento,
        mto_int_mor_cal, mto_int_mor_int_cal, mto_int_mor_ade_cal, mto_int_pun_cal, mto_cargo_cal,
        mto_car_iva_cal, mto_impuesto_cal, fec_ult_devengado, mto_int_mor_des, mto_int_mor_int_des,
        mto_int_mor_ade_des, mto_int_pun_des, mto_car_des, dev_no_cobrado, dev_suspenso, dev_acumulado)
   values(
        rp_pcobr.nro_cuenta, rp_pcobr.nro_cuota, rp_pcobr.fecha, rp_pcobr.hora, rp_pcobr.fec_vencimiento,
        rp_pcobr.estado, rp_pcobr.sal_capital_pre, rp_pcobr.sal_interes_pre, rp_pcobr.sal_capital_cuo,
        rp_pcobr.sal_interes_cuo, rp_pcobr.sal_int_documentado, rp_pcobr.fec_ult_pago, rp_pcobr.dia_mora,
        rp_pcobr.mto_capital, rp_pcobr.mto_interes, rp_pcobr.mto_int_documentado, rp_pcobr.mto_int_moratorio,
        rp_pcobr.mto_int_mor_interes, rp_pcobr.mto_int_mor_adelantado, rp_pcobr.mto_int_punitorio, rp_pcobr.mto_cargo,
        rp_pcobr.mto_cargo_iva, rp_pcobr.mto_impuesto, rp_pcobr.mto_int_descontado, rp_pcobr.nro_documento,
        rp_pcobr.mto_int_mor_cal, rp_pcobr.mto_int_mor_int_cal, rp_pcobr.mto_int_mor_ade_cal, rp_pcobr.mto_int_pun_cal,
        rp_pcobr.mto_cargo_cal, rp_pcobr.mto_car_iva_cal, rp_pcobr.mto_impuesto_cal, rp_pcobr.fec_ult_devengado,
        rp_pcobr.mto_int_mor_des, rp_pcobr.mto_int_mor_int_des, rp_pcobr.mto_int_mor_ade_des, rp_pcobr.mto_int_pun_des,
        rp_pcobr.mto_car_des, rp_pcobr.dev_no_cobrado, rp_pcobr.dev_suspenso, rp_pcobr.dev_acumulado
      );
END;
begin
   select sal_capital, val_tasa, sal_interes, cod_moneda, can_cuotas, cod_modulo,
          cod_modalidad, cod_oficina, estado, fec_ult_devengado, tipo,
          tip_interes, tip_renovacion, nro_solicitud
     into v_sal_capital, v_val_tasa, v_sal_interes, v_cod_moneda, v_can_cuotas,
          v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_estado, v_fec_ult_devengado,
          v_tipo, v_tip_interes, v_tip_renovacion, v_nro_solicitud
     from pr_cta_prestamos
    where nro_cuenta = p_nro_cuenta;
   v_sal_anterior := nvl(v_sal_capital,0) - p_cap_amortizado;
   v_int_amortizado := p_int_amortizado;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,v_cod_modalidad,v_cod_moneda);

   --- Traer la persona  ---
   Begin
     Select cod_persona into v_cod_persona
       from pr_solicitudes
      where nro_solicitud = v_nro_solicitud;
   Exception
     when others then
        v_cod_persona := null;
   end;
   --- Generar cabecera del Movimiento
   r_gmovi.cod_usuario    := user;
   r_gmovi.hora           := p_hora;
   r_gmovi.fecha          := p_fec_pago;
   r_gmovi.cod_modulo     := v_cod_modulo;
   r_gmovi.cod_modalidad  := v_cod_modalidad;
   r_gmovi.cod_oficina    := v_cod_oficina;
   r_gmovi.nro_cuenta     := p_nro_cuenta;
   r_gmovi.cod_persona    := v_cod_persona;

   r_gmovi.cod_moneda     := v_cod_moneda;
   r_gmovi.est_cuenta     := v_estado;
   r_gmovi.cod_tra_padre  := 362;
   r_gmovi.fec_valor      := p_fec_pago;
   r_gmovi.reversado      := 'N';
   r_gmovi.protegido      := 'N';
   r_gmovi.estado         := 'N';
   r_gmovi.cod_ofi_origen := nvl(p_cod_ofi_origen, v_cod_oficina);
   r_gmovi.cod_mod_padre  := v_cod_modulo;
   r_gmovi.cod_mad_padre  := v_cod_modalidad;
   --- Recorrer cuotas
   for cc in cuotas loop
       -- no pueden existir cuotas vencidas
       if cc.fec_vencimiento <= p_fec_pago then
         raise_application_error(-20000, 'El prestamo '||cc.nro_cuenta||' tiene la cuota '||cc.nro_cuota||' ya vencida al '||p_fec_pago||'. No se puede cancelar');
       end if;
       -- no puede tener interes adelantado
       if cc.mto_int_documentado > 0 then
         raise_application_error(-20000, 'El prestamo '||cc.nro_cuenta||' tiene interes adelantado. No se puede cancelar');
       end if;
       v_dias := cc.fec_vencimiento - v_fec_ven_anterior;
       if cc.nro_cuota = v_can_cuotas then
          -- es la ultima cuota, se aplica el saldo
          v_cap_adelantado := p_cap_amortizado - v_tot_cap_adelantado;
       else
          v_cap_adelantado := round(cc.sal_capital * (p_cap_amortizado / v_sal_capital),v_redondeo);
       end if;

       v_int_nuevo      := round(v_sal_anterior * v_val_tasa * v_dias / 36500,v_redondeo);

       if v_int_amortizado > cc.sal_interes then
          v_int_pagado := cc.sal_interes;
          v_int_amortizado := v_int_amortizado - v_int_pagado;
       else
          v_int_pagado     := v_int_amortizado;
          v_int_amortizado := 0;
       end if;
       v_int_descontado := cc.sal_interes - nvl(v_int_pagado,0) - nvl(v_int_nuevo,0);
       if v_int_descontado < 0 then
          v_int_descontado := 0;
       end if;
       --- actualizo la cuota
       --- Cargos datos para cobros por si se genera
       r_pcobr.nro_cuenta          := p_nro_cuenta;
       r_pcobr.nro_cuota           := cc.nro_cuota;
       r_pcobr.fecha               := p_fec_pago;
       r_pcobr.hora                := p_hora;
       r_pcobr.fec_vencimiento     := cc.fec_vencimiento;
       r_pcobr.estado              := cc.estado;
       r_pcobr.sal_capital_pre     := v_sal_capital;
       r_pcobr.sal_interes_pre     := v_sal_interes;
       r_pcobr.sal_capital_cuo     := cc.sal_capital;
       r_pcobr.sal_interes_cuo     := cc.sal_interes;
       r_pcobr.sal_int_documentado := cc.sal_int_documentado;
       r_pcobr.fec_ult_pago        := cc.fec_ult_pago;
       r_pcobr.dia_mora            := 0;
       r_pcobr.mto_capital         := v_cap_adelantado;
       r_pcobr.mto_interes         := v_int_pagado;
       r_pcobr.mto_int_descontado  := v_int_descontado;
       r_pcobr.mto_int_documentado := cc.mto_int_documentado;
       r_pcobr.mto_int_moratorio   := 0;
       r_pcobr.mto_int_mor_interes := 0;
       r_pcobr.mto_int_mor_adelantado := 0;
       r_pcobr.mto_int_punitorio   := 0;
       r_pcobr.mto_cargo           := 0;
       r_pcobr.mto_cargo_iva       := 0;
       r_pcobr.mto_impuesto        := 0;
       r_pcobr.nro_documento       := cc.nro_documento;
       r_pcobr.mto_int_mor_cal     := 0;
       r_pcobr.mto_int_mor_int_cal := 0;
       r_pcobr.mto_int_mor_ade_cal := 0;
       r_pcobr.mto_int_pun_cal     := 0;
       r_pcobr.mto_cargo_cal       := 0;
       r_pcobr.mto_car_iva_cal     := 0;
       r_pcobr.mto_impuesto_cal    := 0;
       r_pcobr.fec_ult_devengado   := v_fec_ult_devengado;
       r_pcobr.mto_int_mor_des     := 0;
       r_pcobr.mto_int_mor_int_des := 0;
       r_pcobr.mto_int_mor_ade_des := 0;
       r_pcobr.mto_int_pun_des     := 0;
       r_pcobr.mto_car_des         := 0;
       r_pcobr.dev_no_cobrado      := cc.dev_no_cobrado;
       r_pcobr.dev_suspenso        := cc.dev_suspenso;
       r_pcobr.dev_acumulado       := cc.dev_acumulado;
       LP_INS_COBRO_CAN_PAR(r_pcobr);
       -- actualizo la cuota
       update pr_cuotas
          set sal_capital        = nvl(sal_capital,0) - nvl(v_cap_adelantado,0),
              sal_interes        = nvl(sal_interes,0) - nvl(v_int_pagado,0) - nvl(v_int_descontado,0),
              mto_cap_adelantado = nvl(mto_cap_adelantado,0) + nvl(v_cap_adelantado,0),
              mto_int_descontado = nvl(mto_int_descontado,0) + nvl(v_int_descontado,0),
              fec_ult_pago       = p_fec_pago
        where current of cuotas;
       ---
       v_fec_ven_anterior := cc.fec_vencimiento;
       v_sal_anterior     := v_sal_anterior - (nvl(cc.sal_capital,0) - nvl(v_cap_adelantado,0));
       v_tot_cap_adelantado := v_tot_cap_adelantado + v_cap_adelantado;
       v_tot_int_descontado := v_tot_int_descontado + v_int_descontado;
       --- Generar movimiento por el cobro de capital
       --r_gmovi.nro_documento  := v_nro_documento;
       r_gmovi.nro_documento2 := null;
       r_gmovi.nro_documento3 := cc.nro_cuota;
       r_gmovi.concepto       := 'Cancelacion Parcial';
       p_nro_secuencia        := nvl(p_nro_secuencia,0) + 1;
       r_gmovi.nro_secuencia  := p_nro_secuencia;
       r_gmovi.emi_aviso      := 'S';
       r_gmovi.monto          :=  v_cap_adelantado;
       r_gmovi.cod_transaccion := PAP_PRE_RES_04.FU_OBT_TRA_CONCEPTO('CA', v_estado, v_tipo, v_tip_interes, v_tip_renovacion);
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
       --- Generar movimiento por diferencia de intereses
       --r_gmovi.nro_documento  := v_nro_documento;
       r_gmovi.nro_documento2 := null;
       r_gmovi.nro_documento3 := cc.nro_cuota;
       r_gmovi.concepto       := 'Cancelacion Parcial';
       p_nro_secuencia        := nvl(p_nro_secuencia,0) + 1;
       r_gmovi.nro_secuencia  := p_nro_secuencia;
       r_gmovi.emi_aviso      := 'S';
       r_gmovi.monto          :=  v_int_descontado;
       r_gmovi.cod_transaccion := 803;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
   end loop;
   --- Actualizar prestamos con el interes descontado
   update pr_cta_prestamos
      set sal_interes = sal_interes - p_int_amortizado - v_tot_int_descontado,
          sal_capital = sal_capital - p_cap_amortizado,
          val_int_devengar = val_int_devengar - v_tot_int_descontado
    where nro_cuenta = p_nro_cuenta;
end;
/*Obtiene el monto del cargo de seguro de vida*/
FUNCTION FU_OBT_MTO_SEG_VIDA
( P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE,
  P_COD_MODALIDAD IN PR_SOLICITUDES.COD_MODALIDAD%TYPE,
  P_MONTO IN NUMBER,
  P_COD_ENT_SEGURO IN GE_SOL_CARGOS.COD_ENT_SEGURO%TYPE,
  P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE,
  P_FEC_VENCIMIENTO IN PR_CTA_PRESTAMOS.FEC_VENCIMIENTO%TYPE,
  P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 )
 RETURN NUMBER
 IS
 --DECLARE
  v_ent_seguro        ge_sol_cargos.cod_ent_seguro%type;
  v_cod_modalidad     pr_cta_prestamos.cod_modalidad%type;
  v_nro_cuenta        pr_cta_prestamos.nro_cuenta%type;
  v_nro_solicitud     pr_solicitudes.nro_solicitud%type;
  v_cod_transaccion   ge_transacciones.cod_transaccion%type;
  v_cod_modulo    pr_cta_prestamos.cod_modulo%type;
  v_cod_moneda    pr_cta_prestamos.cod_moneda%type;
  v_cod_oficina    pr_cta_prestamos.cod_oficina%type;
  v_fec_vencimiento  pr_cta_prestamos.fec_vencimiento%type;
  v_fec_inicio    pr_cta_prestamos.fec_inicio%type;
   v_cod_tasa      ge_movimientos.cod_tasa%type;
  v_val_tasa      ge_movimientos.val_tasa%type;
  v_redondeo      number;
  v_mto_cargo      number;

  V_FEC_VIGENCIA DATE;
  V_TIP_VALOR GE_TASAS.TIP_VALOR%TYPE;
  V_TIPO GE_TASAS.TIPO%TYPE;

   --Obtener datos del préstamo o solicitud
BEGIN
   begin
      select distinct p.cod_modalidad, p.nro_cuenta, c.cod_transaccion,
           p.cod_modulo, p.cod_moneda, p.cod_oficina, p.fec_vencimiento, p.fec_inicio
     into v_cod_modalidad, v_nro_cuenta, v_cod_transaccion, v_cod_modulo, v_cod_moneda,
          v_cod_oficina, v_fec_vencimiento, v_fec_inicio
     from pr_cta_prestamos p, ge_transacciones c
     where p.estado not in ('N','I') --Prestamos vigentes, que no esten ni cancelados ni incobrable.
       and nvl(p.sal_capital,0) > 0
     and p.cod_modulo = c.cod_modulo
     and p.cod_modalidad = c.cod_modalidad
     and c.cod_transaccion = 1521
     and p.nro_solicitud = P_NRO_SOLICITUD;
   exception
    when no_data_found then
      select distinct p.cod_modalidad, p.nro_solicitud, c.cod_transaccion,
          p.cod_modulo, p.cod_moneda, p.cod_oficina, p.fec_vencimiento, p.fec_inicio
       into v_cod_modalidad, v_nro_solicitud, v_cod_transaccion, v_cod_modulo, v_cod_moneda,
        v_cod_oficina, v_fec_vencimiento, v_fec_inicio
       from pr_solicitudes p, ge_transacciones c
       where p.estado not in ('C', 'R')
       and nvl(p.tot_prestamo,0) > 0
       and p.cod_modulo = c.cod_modulo
       and p.cod_modalidad = c.cod_modalidad
       and c.cod_transaccion = 1521
       and p.nro_solicitud = P_NRO_SOLICITUD;
    when others then
     raise_application_error(-20000,
                'Solicitud '||p_nro_solicitud||' no registrada');
  end;
  if p_cod_ent_seguro is null then
    begin
      select cod_ent_seguro
       into v_ent_seguro
       from pr_sol_cargos
      where nro_solicitud = P_NRO_SOLICITUD
        and cod_transaccion = 1521;
    exception
      when no_data_found then
         v_ent_seguro := FUG_OBT_ENT_SEGURO(6, P_COD_MODALIDAD, 'V');
       when others then
       raise_application_error(-20000,
                  'No encuentra código de Aseguradora. Verifique Solicitud '||P_NRO_SOLICITUD);
    end;
  else
    v_ent_seguro := p_cod_ent_seguro;
  end if;

  v_cod_tasa := fug_obt_parentes(v_ent_seguro,'COD_TAS_SEG_VIDA');
  if v_cod_tasa is not null then
     PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                 v_nro_cuenta,  v_cod_moneda, (p_fec_vencimiento - p_fec_inicio), 'N',
                 v_cod_tasa,  NULL, p_fec_inicio, v_val_tasa,v_fec_vigencia,
                 v_tip_valor, v_tipo);
    if v_val_tasa is null then
      raise_application_error(-20000,'No encuentra valor de la tasa del seguro de vida. Verifique');
    end if;
  else
    raise_application_error(-20000,'No encuentra código de la tasa del seguro de vida. Verifique');
  end if;
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_oficina);
  v_mto_cargo  := ROUND(p_monto * v_val_tasa / 100, v_redondeo);
  P_VAL_TASA := v_val_tasa;
  return(v_mto_cargo);
END;
/* Obtiene el monto del cargo seguro contra incendio*/
FUNCTION FU_OBT_MTO_SEG_INCENDIO
( P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE,
  P_NRO_GARANTIA  IN PR_SOL_GARANTIAS.NRO_GARANTIA%TYPE,
  P_VAL_EDILICIO IN OUT PR_GAR_HIPOTECARIAS.VAL_EDILICIO%TYPE,
  P_COD_ENT_SEGURO IN PR_SOL_CARGOS.COD_ENT_SEGURO%TYPE,
  P_COD_MONEDA IN PR_CTA_PRESTAMOS.COD_MONEDA%TYPE,
  P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE,
  P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
)
 RETURN NUMBER
 IS

 --DECLARE
 v_cod_modalidad       pr_cta_prestamos.cod_modalidad%type;
 v_nro_cuenta          pr_cta_prestamos.nro_cuenta%type;
 v_cod_transaccion    ge_transacciones.cod_transaccion%type;
 v_cod_modulo      pr_solicitudes.cod_modulo%type;
 v_cod_moneda      pr_solicitudes.cod_moneda%type;
 v_cod_oficina      pr_solicitudes.cod_oficina%type;
 v_fec_vencimiento    pr_solicitudes.fec_vencimiento%type;
 v_fec_inicio      pr_solicitudes.fec_inicio%type;
 v_cod_persona      pr_solicitudes.cod_persona%type;
 v_val_edilicio      pr_gar_hipotecarias.val_edilicio%type;
 v_val_edilicio_mon    pr_gar_hipotecarias.val_edilicio%type;
 v_cot1          number;
 v_cot2          number;
 v_tot_val_edilicio    pr_gar_hipotecarias.val_edilicio%type;
 v_cod_ent_seguro    pr_sol_cargos.cod_ent_seguro%type;
 v_cod_mon_cargo    pr_sol_cargos.cod_moneda%type;
 v_cod_tasa        ge_tasas.cod_tasa%type;
 v_redondeo        number;
 v_mto_equivalente    number;
 v_cotizacion      ge_movimientos.cotizacion%type;
 v_monto        number;
 v_val_tasa     ge_movimientos.val_tasa%type;
 v_fec_vigencia  date;
 v_fec_actual date;
 v_tip_valor    ge_tasas.tip_valor%type;
 v_tipo         ge_tasas.tipo%type;

BEGIN
  begin
    select distinct p.cod_modalidad, p.nro_solicitud, c.cod_transaccion,
         p.cod_modulo, p.cod_moneda, p.cod_oficina, p.cod_persona
      into v_cod_modalidad, v_nro_cuenta, v_cod_transaccion,
         v_cod_modulo, v_cod_moneda, v_cod_oficina, v_cod_persona
      from pr_solicitudes p, ge_transacciones c
     where p.estado not in ('N','I') --Prestamos vigentes, que no esten ni cancelados ni incobrable.
         and nvl(p.monto,0) > 0
       and p.cod_modulo = c.cod_modulo
       and p.cod_modalidad = c.cod_modalidad
       and c.cod_transaccion = 1520
       and p.nro_solicitud = P_NRO_SOLICITUD;
  exception
    when others then
      raise_application_error(-20000,
                'Solicitud '||p_nro_solicitud||' no registrada');
  end;
 DECLARE
  Cursor c_cur is
    select cod_mon_tasacion, sum(val_edilicio) val_edilicio
      from pr_garantias g, pr_gar_hipotecarias h
     where h.nro_garantia = P_NRO_GARANTIA
       and g.nro_garantia = h.nro_garantia
     group by cod_mon_tasacion;


  begin
    For c1 in c_cur loop
      v_val_edilicio := c1.val_edilicio + nvl(p_val_edilicio,0);
      v_val_edilicio_mon := c1.val_edilicio;
      if c1.cod_mon_tasacion <> v_cod_moneda then
        v_cot1 := null;
        v_cot2 := null;
        pag_gen.pr_con_mon_a_moneda(c1.cod_mon_tasacion, v_cod_moneda, v_val_edilicio,
                      v_val_edilicio_mon, v_cot1, v_cot2);
        v_val_edilicio := v_val_edilicio_mon;
      end if;
    End loop;
  end;
  v_tot_val_edilicio := nvl(v_tot_val_edilicio,0) + nvl(v_val_edilicio,0);
  --Datos del Cargo
  if p_cod_ent_seguro is null and p_cod_moneda is null then
    Select c.cod_ent_seguro, c.cod_moneda
      into v_cod_ent_seguro, v_cod_mon_cargo
      from pr_sol_cargos c
     where c.nro_solicitud = p_nro_solicitud
       and c.cod_transaccion = 1520;
  else
    v_cod_ent_seguro := p_cod_ent_seguro;
    v_cod_mon_cargo := p_cod_moneda;
  end if;
  -- Obtener valor de tasa
  v_cod_tasa := fug_obt_parentes(v_cod_ent_seguro,'COD_TAS_SEG_INCENDIO');
  pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
              null, v_cod_moneda, null, 'S', v_cod_tasa,
              null, p_fec_inicio, v_val_tasa, v_fec_vigencia,
              v_tip_valor, v_tipo, v_cod_persona);

  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo, v_cod_modalidad,
                    v_cod_moneda, v_cod_oficina);

  v_mto_equivalente := round(v_tot_val_edilicio * v_val_tasa / 100, v_redondeo);

  v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_mon_cargo, v_fec_actual);

  if v_cod_mon_cargo = v_cod_moneda then
    v_monto := v_mto_equivalente;
  else
    v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
  end if;
  if v_monto > 0 then
 --Actualizar valores del cargo en PR_SOL_CARGOS
     update pr_sol_cargos s
        set s.val_tasa = v_val_tasa,
            s.cod_tasa  = v_cod_tasa,
            s.monto = v_monto,
            s.mto_mon_prestamo = v_mto_equivalente
      where s.nro_solicitud = p_nro_solicitud
        and s.cod_transaccion = 1520;
     end if;
  P_VAL_EDILICIO := v_tot_val_edilicio;
  return v_monto;
END;
/*Obtiene el monto del cargo de seguro de vida para la propuesta*/
FUNCTION FU_OBT_CAL_MTO_SEG_VIDA
( P_COD_MODALIDAD IN PR_SOLICITUDES.COD_MODALIDAD%TYPE,
  P_COD_MODULO IN PR_SOLICITUDES.COD_MODULO%TYPE,
  P_COD_MONEDA IN PR_SOLICITUDES.COD_MONEDA%TYPE,
  P_COD_OFICINA IN PR_SOLICITUDES.COD_OFICINA%TYPE,
  P_MONTO IN NUMBER,
  P_COD_ENT_SEGURO IN GE_SOL_CARGOS.COD_ENT_SEGURO%TYPE,
  P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE,
  P_FEC_VENCIMIENTO IN PR_CTA_PRESTAMOS.FEC_VENCIMIENTO%TYPE,
  P_TIP_TASA IN VARCHAR2,
  P_TOT_PRESTAMO IN NUMBER,
  P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE DEFAULT NULL,
  P_NRO_CUOTA     IN PR_SOL_CUOTAS.NRO_CUOTA%TYPE DEFAULT NULL,
  P_DIA_INTERES   IN PR_SOL_CUOTAS.DIA_INTERES%TYPE DEFAULT NULL
 )
 RETURN NUMBER
 IS
 --DECLARE
  v_cod_tasa      ge_movimientos.cod_tasa%type;
  v_val_tasa      ge_movimientos.val_tasa%type;
  v_redondeo      number;
  v_mto_cargo     number;
  v_exi_cal_especial varchar2(1) := 'N';
  v_val_tas_dia   number;
  v_dia_calculo   number := 365/12;
     --Obtener datos del préstamo o solicitud
BEGIN
   ---SDSEGVID-3 - Nueva modalidad de cobro Seg.Vida Hipotecario y Consumo 08/2019
   BEGIN
     select distinct 'S'
       into v_exi_cal_especial
       from pr_cta_gas_seguros r
      where r.nro_solicitud = nvl(p_nro_solicitud,0);
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       v_exi_cal_especial := 'N';
     WHEN OTHERS THEN
       v_exi_cal_especial := 'N';
   END;


If nvl(v_exi_cal_especial,'N') = 'N' then

  if P_TIP_TASA = 'F' then
     v_cod_tasa := fug_obt_parentes(p_cod_ent_seguro,'COD_TAS_SEG_VIDA');
  else
     v_cod_tasa := fug_obt_parentes(p_cod_ent_seguro,'COD_TAS_SEGURO');
  end if;

  if v_cod_tasa is not null then
     if P_TIP_TASA = 'F' then
        v_val_tasa := fug_obt_valtas_rango(v_cod_tasa, P_COD_MODULO, P_COD_MODALIDAD,
                       P_cod_moneda, P_cod_oficina, NULL,
                       p_fec_inicio);
     else
        v_val_tasa := fug_obt_valtas_rango(v_cod_tasa, P_COD_MODULO, P_COD_MODALIDAD,
                       P_cod_moneda, P_cod_oficina, P_TOT_PRESTAMO,
                       p_fec_inicio);
        v_val_tasa := fug_obt_valtas_rango(v_val_tasa, P_COD_MODULO, P_COD_MODALIDAD,
                       P_cod_moneda, P_cod_oficina, p_fec_vencimiento - p_fec_inicio,
                       p_fec_inicio);
    end if;
    if v_val_tasa is null then
      raise_application_error(-20000,'No encuentra valor de la tasa del seguro de vida. Verifique');
    end if;
  else
    raise_application_error(-20000,'No encuentra código de la tasa del seguro de vida. Verifique');
  end if;
  ---Nuevo Calculo para obtener tasa por día y utilizar variable de dia interes de cada cuota
  if P_DIA_INTERES is null then
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', P_COD_MODULO, P_COD_MODALIDAD, P_cod_moneda, P_cod_oficina);
      v_mto_cargo  :=  ROUND(p_monto * v_val_tasa / 100, v_redondeo);
      return(v_mto_cargo);
  else
      v_val_tas_dia := v_val_tasa / v_dia_calculo; --Se obtiene tasa por día
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', P_COD_MODULO, P_COD_MODALIDAD, P_cod_moneda, P_cod_oficina);
      v_mto_cargo  := ROUND(p_monto * v_val_tas_dia * P_DIA_INTERES/ 100, v_redondeo);
      return(v_mto_cargo);
  end if;
 elsif nvl(v_exi_cal_especial,'N') = 'S' then
   ---SDSEGVID-3 - Nueva modalidad de cobro Seg.Vida Hipotecario y Consumo 08/2019
     begin
       select sum(nvl(p.monto, 0))
         into v_mto_cargo
         from pr_cta_gas_seguros p
        where p.nro_solicitud = p_nro_solicitud
          and p.nro_cuota = p_nro_cuota
          group by p.nro_cuota;
     exception
       when no_data_found then
         v_mto_cargo := 0;
       when others then
         v_mto_cargo := 0;
     end;
   return(v_mto_cargo);
 end if;


END;
/* Obtiene el monto del cargo seguro contra incendio calculado*/
FUNCTION FU_OBT_CAL_MTO_SEG_INCENDIO
( P_COD_MODALIDAD    IN PR_SOLICITUDES.COD_MODALIDAD%TYPE,
  P_COD_MODULO       IN PR_SOLICITUDES.COD_MODULO%TYPE,
  P_COD_OFICINA      IN PR_SOLICITUDES.COD_OFICINA%TYPE,
  P_NRO_GARANTIA     IN PR_SOL_GARANTIAS.NRO_GARANTIA%TYPE,
  P_VAL_EDILICIO     IN PR_GAR_HIPOTECARIAS.VAL_EDILICIO%TYPE DEFAULT 0,
  P_COD_ENT_SEGURO   IN PR_SOL_CARGOS.COD_ENT_SEGURO%TYPE,
  P_COD_MONEDA       IN PR_CTA_PRESTAMOS.COD_MONEDA%TYPE,
  P_FEC_INICIO       IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE,
  P_COD_MON_EDILICIO IN PR_SIMULACIONES.COD_MON_EDILICIO%TYPE DEFAULT NULL
)
 RETURN NUMBER
 IS

 --DECLARE
 v_cod_modalidad       pr_cta_prestamos.cod_modalidad%type;
 v_nro_cuenta          pr_cta_prestamos.nro_cuenta%type;
 v_cod_transaccion     ge_transacciones.cod_transaccion%type;
 v_cod_modulo          pr_solicitudes.cod_modulo%type;
 v_cod_moneda          pr_solicitudes.cod_moneda%type;
 v_fec_vencimiento     pr_solicitudes.fec_vencimiento%type;
 v_fec_inicio          pr_solicitudes.fec_inicio%type;
 v_cod_persona         pr_solicitudes.cod_persona%type;
 v_val_edilicio        pr_gar_hipotecarias.val_edilicio%type;
 v_val_edilicio_mon    pr_gar_hipotecarias.val_edilicio%type;
 v_cot1                number;
 v_cot2                number;
 v_tot_val_edilicio    pr_gar_hipotecarias.val_edilicio%type;
 v_cod_ent_seguro      pr_sol_cargos.cod_ent_seguro%type;
 v_cod_mon_cargo       pr_sol_cargos.cod_moneda%type;
 v_cod_tasa            ge_tasas.cod_tasa%type;
 v_redondeo            number;
 v_mto_equivalente     number;
 v_cotizacion          ge_movimientos.cotizacion%type;
 v_monto               number;
 v_val_tasa            ge_movimientos.val_tasa%type;
 v_fec_vigencia        date;
 v_fec_actual          date;
 v_tip_valor           ge_tasas.tip_valor%type;
 v_tipo                ge_tasas.tipo%type;
 v_cancuo number       := fug_obt_pardinamico('CAN_CUO_SEG_INCENDIO');

BEGIN
 DECLARE
  Cursor c_cur is
    select cod_mon_tasacion, sum(val_edilicio) val_edilicio
      from pr_garantias g, pr_gar_hipotecarias h
     where h.nro_garantia = P_NRO_GARANTIA
       and g.nro_garantia = h.nro_garantia
     group by cod_mon_tasacion;
  begin
    v_val_edilicio := 0;
    IF P_NRO_GARANTIA IS NOT NULL THEN
        For c1 in c_cur loop
          v_val_edilicio := c1.val_edilicio + NVL(p_val_edilicio,0);
          v_val_edilicio_mon := c1.val_edilicio;
          if c1.cod_mon_tasacion <> p_cod_moneda then
            v_cot1 := null;
            v_cot2 := null;
            pag_gen.pr_con_mon_a_moneda(c1.cod_mon_tasacion, p_cod_moneda, v_val_edilicio,
                          v_val_edilicio_mon, v_cot1, v_cot2);
            v_val_edilicio := v_val_edilicio_mon;
          end if;
        End loop;
     ELSE
       IF p_val_edilicio IS NOT NULL THEN
          v_val_edilicio := p_val_edilicio;
          v_val_edilicio_mon := 0;
          if NVL(P_COD_MON_EDILICIO,p_cod_moneda) <> p_cod_moneda then
            v_cot1 := null;
            v_cot2 := null;
            pag_gen.pr_con_mon_a_moneda(p_cod_mon_edilicio, p_cod_moneda, v_val_edilicio,
                          v_val_edilicio_mon, v_cot1, v_cot2);
            v_val_edilicio := v_val_edilicio_mon;
          end if;
       END IF;
     END IF;
  end;
  v_tot_val_edilicio := nvl(v_tot_val_edilicio,0) + nvl(v_val_edilicio,0);
  --Datos del Cargo
  IF p_cod_ent_seguro is not null and p_cod_moneda is not null THEN
      v_cod_ent_seguro := p_cod_ent_seguro;
      v_cod_mon_cargo := p_cod_moneda;

      -- Obtener valor de tasa
      v_cod_tasa := fug_obt_parentes(v_cod_ent_seguro,'COD_TAS_SEG_INCENDIO');
      pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad, p_cod_oficina,
                  null, p_cod_moneda, null, 'S', v_cod_tasa,
                  null, p_fec_inicio, v_val_tasa, v_fec_vigencia,
                  v_tip_valor, v_tipo, v_cod_persona);

      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo, p_cod_modalidad,
                        p_cod_moneda, p_cod_oficina);

      v_mto_equivalente := round(v_tot_val_edilicio * v_val_tasa / 100, v_redondeo);

      v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_mon_cargo, v_fec_actual);

      if v_cod_mon_cargo = p_cod_moneda then
        v_monto := v_mto_equivalente;
      else
        v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
      end if;
   ELSE
      v_monto := 0;
   END IF;

   v_monto := round(v_monto / nvl(v_cancuo,12),v_redondeo);
   RETURN nvl(v_monto,0);

END;
END PAP_PRE_RES_04;
/


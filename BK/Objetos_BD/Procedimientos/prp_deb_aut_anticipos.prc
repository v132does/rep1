CREATE OR REPLACE PROCEDURE IT.PRP_DEB_AUT_ANTICIPOS
 (P_COD_PERSONA IN VARCHAR2 default NULL
 ,P_NRO_CUENTA IN VARCHAR2 default NULL
 ,P_FEC_HASTA IN DATE default NULL
 )
 IS

/* Inserta movimiento con error. */
PROCEDURE LP_INS_MOV_ERROR;
   v_fecha          ge_calendarios.fec_actual%type;
   v_hora           ge_movimientos.hora%type;
   v_cod_modulo     ba_modulos.cod_modulo%type;
   v_cod_tra_padre  ge_transacciones.cod_transaccion%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   r_gmovi          ge_movimientos%rowtype;
   --- Datos para recuperar deuda del prestamo
   v_pag_parcial    varchar2(01);
   v_sal_cobrado    pr_cuotas.sal_capital%type;
   v_sal_capital    pr_cuotas.sal_capital%type;
   v_sal_interes    pr_cuotas.sal_interes%type;
   v_sal_int_ade    pr_cuotas.sal_int_documentado%type;
   v_mora           pr_cuotas.sal_interes%type;
   v_mora_interes   pr_cuotas.sal_interes%type;
   v_mora_int_ade   pr_cuotas.sal_interes%type;
   v_impuesto       pr_cuotas.sal_interes%type;
   v_cargo          pr_cuotas.sal_interes%type;
   v_cargo_iva      pr_cuotas.sal_interes%type;
   --v_seguro         pr_cuotas.sal_interes%type;
   v_punitorio      pr_cuotas.sal_interes%type;
   v_int_descontado pr_cuotas.sal_interes%type;
   v_mto_deuda      pr_cuotas.sal_capital%type;
   v_nro_cuenta_ant pr_cta_prestamos.nro_cuenta%type;
   v_dias_mora      number(05);
   --- Datos para utilizar la cuenta de débito
   v_mto_deu_deb    ge_cuentas.sal_contable%type;
   v_cot_mon_pre    ge_cotizaciones.val_conversion%type;
   v_cot_mon_deb    ge_cotizaciones.val_conversion%type;
   v_nvo_estado     ge_cuentas.estado%type;
   v_sal_disponible ge_cuentas.sal_contable%type;
   v_procesa        varchar2(01);
   v_error          varchar2(10);
   v_mensaje        varchar2(1000);
   v_lin_sobregiro  number(18,2);
   v_fec_hasta      date;
   rg_calend        ge_calendarios%rowtype;
   v_cta_exc        varchar2(1000) := fug_obt_pardinamico('CTA_EXC_ANTICIPO');
   --- Cursor de cuentas de préstamos con débito automático
   
   --- Toma todas las cuotas atrasadas de todos los préstamos hasta la fecha actual, y además ordena por 
   --- la fecha de vencimiento y el saldo de la cuota para el débito
   
   cursor c_debitos is
   select pr.nro_cuenta, pr.cod_oficina, cu.nro_cuota, pr.cod_moneda,
          pr.cod_modulo, pr.cod_modalidad, cu.nro_documento, x.cuo_hasta,(nvl(cu.sal_capital,0)+nvl(cu.sal_interes,0)+nvl(cu.sal_int_documentado,0))tot_cuota
     from ge_cta_clientes cl, pr_cta_prestamos pr, pr_cuotas cu,
         (select nro_cuenta cuenta, max(nro_cuota) cuo_hasta
            from pr_cuotas
           where fec_vencimiento <= last_day(v_fec_hasta)
             and estado  <> 'N'
             and nvl(sal_capital,0)+nvl(sal_interes,0)+nvl(sal_int_documentado,0) > 0
           group by nro_cuenta) x
    where pr.nro_cuenta = cu.nro_cuenta
      and pr.nro_cuenta = cl.nro_cuenta
      and pr.cod_modalidad not in (608) --- no incluir asociaciones ni descuentos documentos
      and nvl(fug_obt_pardinamico('MAD_ANTICIPOS',pr.cod_modulo,pr.cod_modalidad),'N') = 'S' --Solo Anticipos al Personal
      and cl.relacion        = 'P'  --- Cliente principal
      and pr.estado          <> 'N' --- Préstamos no cancelados
      --and pr.nro_cta_debito  is not null
      --and pr.cob_automatico  = 'S'
      and cu.fec_vencimiento <= last_day(v_fec_hasta)
      and x.cuenta = cu.nro_cuenta
      and cu.nro_cuota > 0
      /*and cu.nro_cuota = (select min(nro_cuota)
                            from pr_cuotas
                           where nro_cuenta = pr.nro_cuenta
                             and (nvl(sal_capital,0) <> 0 or nvl(sal_interes,0) <> 0) -- Cuotas con saldo
                             and nro_cuota > 0
                         )*/-- comentado para que no se filtre solo la minima cuota atrasada de cada préstamo
      and cu.estado          <> 'N' --- Cuotas no canceladas
      and (p_nro_cuenta  is null or pr.nro_cuenta = p_nro_cuenta)
      and (p_cod_persona is null or cl.cod_persona = p_cod_persona)
      and instr(nvl(v_cta_exc, '0'), pr.nro_cuenta) = 0
    order by cu.fec_vencimiento,tot_cuota desc, cu.nro_cuota;

/* Inserta movimiento con error. */
PROCEDURE LP_INS_MOV_ERROR
 IS
BEGIN
   v_nro_secuencia := v_nro_secuencia + 1;
   --- Cargar registro de movimientos
   r_gmovi.fecha           := v_fecha;
   r_gmovi.fec_valor       := v_fecha;
   r_gmovi.cod_usuario     := user;
   r_gmovi.hora            := v_hora;
   r_gmovi.nro_secuencia   := v_nro_secuencia;
   r_gmovi.cod_tra_padre   := v_cod_tra_padre;
   r_gmovi.reversado       := 'N';
   r_gmovi.emi_aviso       := 'N';
   r_gmovi.protegido       := 'N';
   pag_gen.pr_ins_ge_movimiento(r_gmovi);
END;
BEGIN
   --- Recuperar datos de fecha calendario
   v_cod_modulo     := 6;
   v_fecha          := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
   v_hora           := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_nro_secuencia  := 0;
   v_cod_tra_padre  := 364;
   v_cod_mon_local  := pag_gen.fu_obt_mon_local;
   v_nro_cuenta_ant := null;
   
   --Obtener registro del Calendario
   rg_calend        := pag_cal.fu_obt_reg_cal(6);
   
   --Si no se pasa la fecha como parámetro se toma hasta fin de mes
   v_fec_hasta      := nvl(p_fec_hasta,rg_calend.ult_dia_mes);
      
   for pre in c_debitos loop
      --- Inicializar variables auxiliares
      r_gmovi          := null;
      v_sal_cobrado    := null;
      v_error          := null;
      v_mensaje        := null;
      v_sal_capital    := null;
      v_sal_interes    := null;
      v_sal_int_ade    := null;
      v_mora           := null;
      v_mora_interes   := null;
      v_mora_int_ade   := null;
      v_punitorio      := null;
      v_impuesto       := null;
      v_cargo          := null;
      v_cargo_iva      := null;
      v_int_descontado := null;
      --cotización
      v_cot_mon_pre    := null;
      v_cot_mon_deb    := null;
      if v_nro_cuenta_ant is null then --- Solo la primera vez
         v_nro_cuenta_ant := pre.nro_cuenta;
      end if;
      if pre.nro_cuenta <> v_nro_cuenta_ant then
         --- Para grabar por cada registro procesado y sus movimientos la misma hora
         v_hora           := pag_gen.fu_obt_sig_segundo(v_hora);
         v_nro_secuencia  := 0;
         v_nro_cuenta_ant := pre.nro_cuenta;
      end if;
      --- Inicializar registro de movimiento por si da error
      r_gmovi.cod_ofi_origen  := pre.cod_oficina;
      r_gmovi.cod_mod_padre   := pre.cod_modulo;
      r_gmovi.cod_mad_padre   := pre.cod_modalidad;
      r_gmovi.nro_documento   := pre.nro_documento;
      r_gmovi.concepto        := 'Prest.'||pre.nro_cuenta;
      --- Recuperar deuda a la fecha del proceso
      --- Recuperar deuda de la cuota
      pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota, pre.nro_cuota,--pre.cuo_hasta, -- F.Q. debe traer solo la deuda de la cuota que trae el cursor
         pre.cod_oficina, v_sal_cobrado, v_error, v_mensaje,
         v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
         v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
         v_dias_mora, v_cod_tra_padre);
      if v_error <> 0 then
         --NO GENERAR MOV CON ERROR XQ DA PROBLEMAS EN ASIENTOS
         ---raise_application_error(-20000, v_mensaje); OJO por ahora error ver + adelante
         --- Ir al Siguiente
         GOTO siguiente_registro;
      end if;
      v_mto_deuda := nvl(v_sal_capital,0) + nvl(v_sal_interes,0)  + nvl(v_sal_int_ade,0)  +
                     nvl(v_mora,0)        + nvl(v_mora_interes,0) + nvl(v_mora_int_ade,0) +
                     nvl(v_punitorio,0)   + nvl(v_impuesto,0)     + nvl(v_cargo,0);
      r_gmovi.cod_modulo      := pre.cod_modulo;
      r_gmovi.cod_modalidad   := pre.cod_modalidad;
      r_gmovi.cod_moneda      := pre.cod_moneda;

      -- RI: 30/07/2010: Volver a obtener deuda para controlar que el monto a cobrar
      -- cubra por lo menos los cargos y manejar el error emergente
      pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota, pre.nro_cuota,--pre.cuo_hasta,--F.Q. debe traer solo la deuda de la cuota que trae el cursor
         pre.cod_oficina, v_mto_deuda, v_error, v_mensaje,
         v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
         v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
         v_dias_mora, v_cod_tra_padre);
      if v_error <> 0 then
         GOTO siguiente_registro;
      end if;
      --- Si el prestamo esta en moneda extranjera Calculo el total a debitar en la moneda local 
      v_mto_deu_deb := v_mto_deuda;
      v_cot_mon_pre := null;
      v_cot_mon_deb := null;
      if  pre.cod_moneda <> v_cod_mon_local then     
        pag_gen.pr_con_mon_a_moneda(pre.cod_moneda, v_cod_mon_local,
                                    v_mto_deuda, v_mto_deu_deb,
                                    v_cot_mon_pre, v_cot_mon_deb);
      End if;
      --
      v_nro_secuencia := v_nro_secuencia + 1;
      pap_pre.pr_cob_prestamo(pre.nro_cuenta, v_mto_deuda, 'N', pre.cod_oficina,
                              pre.nro_cuota,pre.nro_cuota,-- pre.cuo_hasta, F.Q. debe cobrar solo la cuota que trae el cursor
                              'Cobro aut. Préstamo '||pre.nro_cuenta, v_fecha,
                              -- in/out
                              v_hora, v_nro_secuencia, v_cod_tra_padre, pre.cod_modulo,
                              pre.cod_modalidad);

      --Debitar a un Rubro Contable (Cuenta Transitoria)
      r_gmovi.cod_usuario     := user;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      -- Aumento la secuencia
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      --
      r_gmovi.nro_cuenta      :=  null;
      r_gmovi.cod_modulo      := 6;
      r_gmovi.cod_modalidad   := pre.cod_modalidad;
      r_gmovi.cod_oficina     := pre.cod_oficina;
      r_gmovi.cod_moneda      := pre.cod_moneda;
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.cod_tra_padre   := v_cod_tra_padre;
      r_gmovi.cod_mod_padre   := 6;
      r_gmovi.cod_mad_padre   := pre.cod_modalidad;
      r_gmovi.cod_transaccion := 843;
      r_gmovi.monto           := nvl(v_mto_deu_deb,0);
      r_gmovi.referencia      := pre.nro_cuenta;
      r_gmovi.cod_ofi_origen  := pre.cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'COBRO AUT. PRESTAMO '||pre.nro_cuenta;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_rubro       :=  null; --:det_cta_contable.cod_rubro;
      r_gmovi.tip_mov_rubro   :=  null; --'D';

      pag_gen.pr_ins_ge_movimiento(r_gmovi);
      
      --- Siguiente registro
      <<siguiente_registro>>
      null;   
   end loop;
END;
/


CREATE OR REPLACE PROCEDURE IT.PRP_DEB_AUTOMATICO_TMP
 (P_COD_PERSONA IN VARCHAR2 default NULL
 ,P_NRO_CUENTA IN VARCHAR2 default NULL
 ,P_PAG_PARCIAL IN VARCHAR2 default NULL
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
   v_imp_cuenta     pr_cuotas.sal_interes%type;
   v_lin_sobregiro  number(18,2);
   --RI: 15/12/2010: Parametro creado para determinar si se procesa cuenta de nomina
   --v_pro_cta_nomina varchar2(1) := nvl(fug_obt_pardinamico('PRO_CTA_NOMINA'),'S'); COMENTADO PORQUE NO ESTÁ IMPLEMENTADO AÚN EL REQUERIMIENTO A PEDIDO DE VCAPRA EL 04/03/2011
   --- Cursor de cuentas de préstamos con débito automático
   
   --- Toma todas las cuotas atrasadas de todos los préstamos hasta la fecha actual, y además ordena por 
   --- la fecha de vencimiento y el saldo de la cuota para el débito
   cursor c_debitos is
   select pr.nro_cuenta, pr.nro_cta_debito, pr.cod_oficina, cu.nro_cuota, pr.cod_moneda,
          pr.cod_modulo, pr.cod_modalidad, cu.nro_documento, x.cuo_hasta,(nvl(cu.sal_capital,
0)+nvl(cu.sal_interes,0)+nvl(cu.sal_int_documentado,0))tot_cuota
     from ge_cta_clientes cl, pr_cta_prestamos pr, pr_cuotas cu, 
         (select nro_cuenta cuenta, max(nro_cuota) cuo_hasta
            from pr_cuotas
           where fec_vencimiento <= v_fecha
             and estado  <> 'N'
             and nvl(sal_capital,0)+nvl(sal_interes,0)+nvl(sal_int_documentado,0) > 0
           group by nro_cuenta) x  
    where pr.nro_cuenta = cu.nro_cuenta
      and pr.nro_cuenta = cl.nro_cuenta
      and pr.cod_modalidad not in (608) --- no incluir asociaciones ni descuentos documentos
      and nvl(fug_obt_pardinamico('MAD_ANTICIPOS',pr.cod_modulo,pr.cod_modalidad),'N') = 'N' --No debe incluir Anticipos al Personal
      and cl.relacion        = 'P'  --- Cliente principal
      and pr.estado          <> 'N' --- Préstamos no cancelados
      and pr.nro_cta_debito  is not null
      and pr.cob_automatico  = 'S'
      and cu.fec_vencimiento <= v_fecha
      and x.cuenta = cu.nro_cuenta
      and cu.nro_cuota > 0
      and  not exists ( select 1 from ge_movimientos m where m.nro_cuenta = pr.nro_cuenta and cod_tra_padre in (360,364) )
      /*and cu.nro_cuota = (select min(nro_cuota)
                            from pr_cuotas
                           where nro_cuenta = pr.nro_cuenta
                             and (nvl(sal_capital,0) <> 0 or nvl(sal_interes,0) <> 0) -- Cuotas con saldo
                             and nro_cuota > 0
                         ) */-- comentado para que no se filtre solo la minima cuota atrasada de cada préstamo
      and cu.estado          <> 'N' --- Cuotas no canceladas
      and (p_nro_cuenta  is null or pr.nro_cuenta = p_nro_cuenta)
      and (p_cod_persona is null or cl.cod_persona = p_cod_persona)
      /*RI: 15/12/2010: para que evalue si procesar o no cuentas de nomina */          
     /* and (not exists (Select 1 from cc_cta_corrientes c
                        where c.nro_cuenta = pr.nro_cta_debito and c.cod_ente is not null
                          and v_pro_cta_nomina = 'N')
       or v_pro_cta_nomina = 'S')                             
      and (not exists(Select 1 from ah_cta_vistas c
                       where c.nro_cuenta = pr.nro_cta_debito and c.cod_ente is not null
                         and v_pro_cta_nomina = 'N') 
       or v_pro_cta_nomina = 'S')*/ --COMENTADO PORQUE NO ESTÁ IMPLEMENTADO AÚN EL REQUERIMIENTO A PEDIDO DE VCAPRA EL 04/03/2011
    order by  cu.fec_vencimiento, tot_cuota desc, cu.nro_cuota;

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
   v_fecha          := '29/04/2013'/*pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo)*/;
   --RI: 18/10/2010: Si no se ejecuta desde el cierre tomar la hora actual
   If nvl(pae_cnf.G_PROGRAMA,'X')  = 'GPPROFIN' then  --cierre
     v_hora   := fug_ini_hora(sysdate,'HH24:MI:SS');
   else    
     v_hora   := to_char(sysdate,'HH24:MI:SS');
   End if; 
   
   v_nro_secuencia  := 0;
   v_cod_tra_padre  := 364;
   v_cod_mon_local  := pag_gen.fu_obt_mon_local;
   v_nro_cuenta_ant := null;
   
     
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
      pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota,pre.nro_cuota,-- pre.cuo_hasta, F.Q. debe traer solo la deuda de la cuota que trae el cursor
         pre.cod_oficina, v_sal_cobrado, v_error, v_mensaje,
         v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
         v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
         v_dias_mora, v_cod_tra_padre);
      if v_error <> 0 then
         --NO GENERAR MOV CON ERROR XQ DA PROBLEMAS EN ASIENTOS
         ---raise_application_error(-20000, v_mensaje); OJO por ahora error ver + adelante
/*         r_gmovi.estado    := 'E';
         r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
         --- Grabar movimiento con error
         lp_ins_mov_error;
*/         --- Ir al Siguiente
         GOTO siguiente_registro;
      end if;
      v_mto_deuda := nvl(v_sal_capital,0) + nvl(v_sal_interes,0)  + nvl(v_sal_int_ade,0)  +
                     nvl(v_mora,0)        + nvl(v_mora_interes,0) + nvl(v_mora_int_ade,0) +
                     nvl(v_punitorio,0)   + nvl(v_impuesto,0)     + nvl(v_cargo,0);
      --- Recuperar datos de la cuenta de ahorro
      pag_cta.pr_obt_cuenta(pre.nro_cta_debito);
      r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.nro_cuenta      := pre.nro_cta_debito;
      r_gmovi.cod_moneda      := pag_cta.g_ctas.cod_moneda;
      r_gmovi.cod_transaccion := 503;
      if pag_cta.g_cod_error <> 0 then
/*         r_gmovi.estado    := 'E';
         r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
         --- Grabar movimiento con error
         lp_ins_mov_error;
*/         --- Ir al Siguiente
         GOTO siguiente_registro;
      end if;
      --- Verificar monedas ----
      if pag_cta.g_ctas.cod_moneda <> pre.cod_moneda and   -- Cta. Débito Vs Préstamo
         pag_cta.g_ctas.cod_moneda <> v_cod_mon_local and  -- Cta. Débito Vs Local
         pre.cod_moneda            <> v_cod_mon_local then -- Préstamo Vs Local
/*         r_gmovi.estado    := 'E';
         r_gmovi.cod_error := 'MON.EXTR.';
         --- Grabar movimiento con error
         lp_ins_mov_error;
*/         --- Ir al Siguiente
         GOTO siguiente_registro;
      end if;
      --- Calculo el total a debitar en la moneda de la cuenta de debito
      pag_gen.pr_con_mon_a_moneda(pre.cod_moneda, pag_cta.g_ctas.cod_moneda,
                                  v_mto_deuda, v_mto_deu_deb,
                                  v_cot_mon_pre, v_cot_mon_deb);
      --- Verificar parámetro de pago para identificar el monto de la deuda
      if p_pag_parcial is null then
         v_pag_parcial := fug_obt_pardinamico('PAG_COB_AUT',pre.cod_modulo, pre.cod_modalidad,
                                              pre.cod_moneda, pre.cod_oficina);
      else
         v_pag_parcial := p_pag_parcial;
      end if;
      -- se tiene en cuenta la linea de sobregiro
      v_lin_sobregiro := 0;
      if pag_cta.g_ctas.cod_modalidad = 41 then
         v_lin_sobregiro := nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(pre.nro_cta_debito, v_fecha),0);
      end if; 
      if (v_pag_parcial = 'N' and nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro < nvl(v_mto_deu_deb,0))
         or (v_pag_parcial = 'S'  and (nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro <= 0 
             or nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro < 
                fug_obt_pardinamico('MIN_COB_AUT',pre.cod_modulo, pre.cod_modalidad,pre.cod_moneda, pre.cod_oficina))) then
         --- Solo se cobra si el saldo de la cuenta cubre toda la deuda
/*         r_gmovi.estado          := 'E';
         r_gmovi.cod_error       := 'PREST';
         --- Grabar movimiento con error
         r_gmovi.cod_modulo      := pre.cod_modulo;
         r_gmovi.cod_modalidad   := pre.cod_modalidad;
         r_gmovi.nro_cuenta      := pre.nro_cuenta;
         r_gmovi.cod_moneda      := pre.cod_moneda;
         r_gmovi.cod_transaccion := 801;
         lp_ins_mov_error;
*/         --- Ir al Siguiente
         GOTO siguiente_registro;
      end if;
      --calcula impuesto si corresponde y genera movimiento, en moneda de cta débito
      begin
        prg_ver_cob_cargos(pre.nro_cta_debito,
                     pre.nro_cuenta,
                     pre.cod_modulo,
                     pre.cod_modalidad,
                     pre.cod_oficina,--oficina del préstamo, oficina origen
                     pag_cta.g_ctas.cod_moneda,
                     v_mto_deu_deb,
                     'Cobro aut. Préstamo '||pre.nro_cuenta,
                     null, --v_nro_documento,
                     v_fecha,
                     v_hora,
                     v_imp_cuenta,
                     v_nro_secuencia,
                     'N'); -- no procesa
      exception
         when others then
            v_imp_cuenta := 0; --para que no caiga
      end;
      
      if v_pag_parcial = 'S' and (nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro) < nvl(v_mto_deu_deb,0)+ nvl(v_imp_cuenta,0) then
         v_imp_cuenta  :=  (nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro)/nvl(v_mto_deu_deb,0) * nvl(v_imp_cuenta,0);
         if pre.cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
            v_imp_cuenta := ceil(v_imp_cuenta);
         end if;   
         v_mto_deu_deb := (nvl(pag_cta.g_ctas.sal_disponible,0)+nvl(pag_cta.g_ctas.sal_dis_combinada,0)+v_lin_sobregiro) - nvl(v_imp_cuenta,0);
         
      else
         v_mto_deu_deb :=  nvl(v_mto_deu_deb,0);   
      end if;
      --- Verificar si puede realizarse la operación sobre la cuenta de débito
      pag_cta.pr_ver_operacion(pre.nro_cta_debito, v_cod_tra_padre,
                               r_gmovi.cod_mod_padre, r_gmovi.cod_mad_padre,
                               'D', pag_cta.g_ctas.cod_moneda, nvl(v_mto_deu_deb,0)+nvl(v_imp_cuenta,0), pre.cod_oficina,
                               -- out
                               pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad,
                               v_nvo_estado, v_sal_disponible, v_procesa, 503);
      if pag_cta.g_cod_error <> 0 or v_procesa = 'N' then
/*         r_gmovi.estado    := 'E';
         r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
         --- Grabar movimiento con error
         lp_ins_mov_error;
*/         --- Ir al Siguiente
         GOTO siguiente_registro;
      end if;
      --- COBRAR prestamos
      --- Convertir monto de la deuda a la del prestamo por si varió segun saldo disponible
      --- de la cuenta
      pag_gen.pr_con_mon_a_moneda(pag_cta.g_ctas.cod_moneda, pre.cod_moneda,
                                  nvl(v_mto_deu_deb,0), v_mto_deuda,
                                  v_cot_mon_deb, v_cot_mon_pre);
      -- RI: 30/07/2010: Volver a obtener deuda para controlar que el monto a cobrar
      -- cubra por lo menos los cargos y manejar el error emergente
      pap_pre.pr_obt_deu_prestamo(pre.nro_cuenta, v_fecha, pre.nro_cuota, pre.nro_cuota,-- pre.cuo_hasta,--F.Q. debe traer solo la deuda de la cuota que trae el cursor
         pre.cod_oficina, v_mto_deuda, v_error, v_mensaje,
         v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
         v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
         v_dias_mora, v_cod_tra_padre);
      if v_error <> 0 then
         GOTO siguiente_registro;
      end if;   
      --                                          
      v_nro_secuencia := v_nro_secuencia + 1;
      pap_pre.pr_cob_prestamo(pre.nro_cuenta, v_mto_deuda, 'N', pre.cod_oficina,
                              pre.nro_cuota,pre.nro_cuota,-- pre.cuo_hasta, F.Q. debe cobrar solo la cuota que trae el cursor
                              'COB. AUT. C/CTA '||pre.nro_cta_debito, v_fecha,
                              -- in/out
                              v_hora, v_nro_secuencia, v_cod_tra_padre, pre.cod_modulo,
                              pre.cod_modalidad);
                             
      -- se vuelve a obtener los datos de la cuenta de debito, porque pudo haber cambiado en el pap_pre (x garantias cash)
      pag_cta.pr_obt_cuenta(pre.nro_cta_debito);
      --calcula impuesto si corresponde y genera movimiento, en moneda de cta débito
      begin
        prg_ver_cob_cargos(pre.nro_cta_debito,
                     pre.nro_cuenta,
                     pre.cod_modulo,
                     pre.cod_modalidad,
                     pre.cod_oficina,--oficina del préstamo, oficina origen
                     pag_cta.g_ctas.cod_moneda,
                     v_mto_deu_deb,
                     'Cobro aut. Préstamo '||pre.nro_cuenta,
                     null, --v_nro_documento,
                     v_fecha,
                     v_hora,
                     v_imp_cuenta,
                     v_nro_secuencia,
                     'S');
      exception
         when others then
            v_imp_cuenta := 0; --para que no caiga
      end;
      --- DEBITAR de la cuenta
      v_nro_secuencia := v_nro_secuencia + 1;
      pag_cta.pr_act_operacion(pre.nro_cta_debito, v_hora, 'D', pag_cta.g_ctas.cod_moneda,
                               nvl(v_mto_deu_deb,0)+nvl(v_imp_cuenta,0), v_cod_tra_padre, 503, pre.nro_documento, null,
                               pre.cod_oficina, pre.cod_modulo, pre.cod_modalidad,
                               null, null, 'COBRO AUT. PRESTAMO '||pre.nro_cuenta,
                               'S', v_nro_secuencia /* in/out */, v_fecha);
           /*-----------------------------------------------------------------
           -- obtiene la cotizacion de la moneda si la moneda no es local --
           -----------------------------------------------------------------
           IF pre.cod_moneda <> v_cod_mon_local THEN
              IF pag_cta.g_ctas.cod_moneda = v_cod_mon_local THEN --  es una venta
                  OBTENER_COTIZACION('V',:ABMC.SCR_CDMONED,:CABECERA.WFECHA,
                                         :ABMC.SCR_COTIZAC);
              ELSE -- es la cotizacion de cierre
                  OBTENER_COTIZACION('X',:ABMC.SCR_CDMONED,:CABECERA.WFECHA,
                                         :ABMC.SCR_COTIZAC);
              END IF;
           ELSE
              :ABMC.SCR_COTIZAC := NULL;
           END IF;
              IF r_gmovi.estado = 'N' AND pag_cta.g_ctas.cod_moneda <> pre.cod_moneda THEN
                 -- realizo la operacion de cambios si es necesario
                 IF pag_cta.g_ctas.cod_moneda = v_cod_mon_local THEN
                    --- ventad de divisas
                    VENTA_DE_DIVISAS(:ABMC.SCR_CDMONED,
                                      NVL(:WK_INTERES,0)+NVL(:WK_CAPITAL,0)+
                                      NVL(:WK_SLINTAD,0) +
                                      NVL(:SCR_MORA_INT,0)+NVL(:SCR_MORA,0)+
                                      NVL(:SCR_MORA_ADE,0)+NVL(:SCR_CARGO,0),
                          ROUND(NVL(:WK_DEBITO,0)-NVL(:SCR_IMPUESTO_GS,0)));
                 ELSIF pre.cod_moneda = v_cod_mon_local THEN
                    --- compra de divisas
                    COMPRA_DE_DIVISAS(:WK_MONEDEB,:WK_DEBITO,
                                      NVL(:WK_INTERES,0)+NVL(:WK_CAPITAL,0)+
                                      NVL(:SCR_IMPUESTO,0)+NVL(:WK_SLINTAD,0) +
                                      NVL(:SCR_MORA_INT,0)+NVL(:SCR_MORA,0)+
                                      NVL(:SCR_MORA_ADE,0)+NVL(:SCR_CARGO,0));
                 ELSE
                    MESSAGE('Operacion de Arbitraje no se permite ');
                    RAISE FORM_TRIGGER_FAILURE;
                 END IF;
              END IF;  */ -- OJO se implementa con Cambios
      --- Siguiente registro
      <<siguiente_registro>>
      null;
   end loop;
END;
/


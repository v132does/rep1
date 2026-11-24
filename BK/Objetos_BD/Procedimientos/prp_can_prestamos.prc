CREATE OR REPLACE PROCEDURE IT.prp_can_prestamos(p_cta_prestamo pr_cta_prestamos.nro_cuenta%type,
                                              p_nro_cuenta ge_cuentas.nro_cuenta%type,
                                              p_exonera varchar2 default 'N')
IS
   v_fec_actual       date default pag_cal.FU_OBT_FEC_ACTUAL(6);
   v_fec_ini_mora     pr_cuotas.fec_vencimiento%type;
   v_fec_fin_mora     pr_cuotas.fec_vencimiento%type;
   v_fec_apertura     cc_cta_corrientes.fec_apertura%type;
   v_hor_c            ge_movimientos.hora%type;
   v_hora             ge_movimientos.hora%type;
   v_cod_oficina      ba_oficinas.cod_oficina%type;
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;
   v_nro_documento    ge_movimientos.nro_documento%type;
   v_nro_factura      cb_lib_ventas.nro_factura%type;
   /** C.D.Fase II**/
   --v_tip_operacion    ge_mov_autorizaciones.tip_operacion%type := 'O';
   v_est_movimiento   ge_movimientos.estado%type default 'N';
   v_cod_persona      ba_personas.cod_persona%type;
   v_tip_cancelacion  varchar2(1) default 'T';
   v_mensaje          varchar2(1500);
   v_error            number(5);
   v_concepto         ge_movimientos.concepto%type;
   rg_pres            pr_cta_prestamos%rowtype;

   v_tot_deuda        number;
   v_tot_sal_capital  number;
   v_tot_sal_interes  number; 
   v_sal_int_ade      number;
   v_tot_mora         number;
   v_tot_mor_interes  number;
   v_tot_mor_int_ade  number;
   v_tot_punitorio    number;
   v_tot_impuesto     number;
   v_tot_cargo        number;
   v_tot_car_iva      number;
   v_tot_int_descontado number;
   v_dia_mora           number;
   v_nro_sec_padre    cc_lin_sobregiros.nro_secuencia%TYPE;
   v_sit_sobregiro    cc_sobregiros_res.sit_deuda%type;
   rg_cal             ge_calendarios%ROWTYPE;
   vg_fec_actual DATE;
   vg_fec_anterior ge_calendarios.fec_anterior%TYPE;
   vg_ult_dia_mes_habil     date;
   vg_ult_dia_mes           date;
   vg_pri_dia_mes           date;
   vg_pri_dia_mes_habil     date;
   vg_dif_dias              number(5);
   vg_dia_mora           number;
   G_CTAS PAG_CTA.RG_CTAS;
   --
   PROCEDURE LP_GEN_NOV_CUENTA
     (P_FECHA IN DATE
     ,P_HORA IN VARCHAR2
     )
     IS
    v_est_anterior    varchar2(01) := null;
    v_est_actual      varchar2(01) := null;
    v_fec_cam_est_ant date         := null;
    v_fec_ult_mov_ant date         := null;
    v_hor_ult_mov_ant varchar2(8)  := null;
    v_insertar        varchar2(1)  := 'N';
    BEGIN
       IF (nvl(g_ctas.nvo_estado,g_ctas.estado) <> g_ctas.estado) then
          -- cambiara de estado
          v_est_anterior    := g_ctas.estado;
          v_est_actual      := g_ctas.nvo_estado;
          v_fec_cam_est_ant := g_ctas.fec_cam_estado;
          v_insertar        := 'S';
       end if;
       if nvl(g_ctas.act_ult_movimiento,'N') = 'S' then
          -- cambio de fecha ultimo movimiento
          v_fec_ult_mov_ant := g_ctas.fec_ult_movimiento;
          v_hor_ult_mov_ant := g_ctas.hor_ult_movimiento;
          v_insertar        := 'S';
       end if;
       if v_insertar = 'S' then
         -- Actualizo el registro si ya existe
         update ge_cuentas_nov
            set est_anterior    = nvl(v_est_anterior,est_anterior),
                est_actual      = nvl(v_est_actual,est_actual),
                fec_cam_est_ant = nvl(v_fec_cam_est_ant,fec_cam_est_ant),
                fec_ult_mov_ant = nvl(v_fec_ult_mov_ant,fec_ult_mov_ant),
                hor_ult_mov_ant = nvl(v_hor_ult_mov_ant,hor_ult_mov_ant)
          where cod_usuario = user
            and fecha       = p_fecha
            and hora        = p_hora
            and nro_cuenta  = p_nro_cuenta;
         if sql%notfound then
            insert into ge_cuentas_nov
               (fecha, hora, cod_usuario,
                nro_cuenta, nro_detalle,
                cod_modulo, cod_modalidad,
                est_anterior, est_actual, fec_cam_est_ant,
                fec_ult_mov_ant, hor_ult_mov_ant, fec_ult_cap_ant )
            values
               (p_fecha, p_hora, USER,
                p_nro_cuenta, null,
                4, 41,
                v_est_anterior, v_est_actual, v_fec_cam_est_ant,
                v_fec_ult_mov_ant, v_hor_ult_mov_ant, g_ctas.fec_ult_capitalizacion);

         end if;
       end if;
    exception
      when others then
         raise_application_error(-20000,'PR_GEN_NOV_CUENTA '||sqlerrm);
    END;

   -- Procedimiento para cambio de Estado.
   PROCEDURE LP_ACT_ESTADO
     (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
     ,P_ESTADO IN GE_CUENTAS.ESTADO%TYPE
     ,P_FEC_PROCESO IN DATE
     ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
     ,P_NRO_DOCUMENTO IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
     ,P_PROCESAR IN VARCHAR2 DEFAULT NULL
     )
     IS

    R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
    V_TRA_CAM_ESTADO NUMBER(3);

    G_MOVS PAG_CTA.RG_MOVS;
    v_nocturno          varchar2(1) := 'N';
    v_ok_procesar       varchar2(1) := 'S';
    v_lugar             varchar2(1000);
    v_fec_inicio        date;
    BEGIN
       IF nvl(pag_cta.g_horario, 'D') = 'D' then
          v_nocturno := 'N';
       ELSE
          v_nocturno := 'S';
       END IF;
      g_ctas.estado      := 'A';
      g_ctas.nvo_estado  := p_estado;
      --
       If P_PROCESAR is not null then
         v_ok_procesar := p_procesar;
       End if;
       IF p_estado = 'N' THEN
          v_tra_cam_estado:= 425; -- Pasar a (N)ormal
       ELSIF p_estado = 'P' THEN
          v_tra_cam_estado:= 405; -- Pasar a (P)endiente de Cancelacion
       ELSIF p_estado = 'C' THEN
          v_tra_cam_estado:= 406; -- Pasar a (C)ancelado
       ELSIF p_estado = 'I' then
          v_tra_cam_estado:= 420; -- Pasar a (I)nactivo
       ELSIF p_estado = 'T' THEN
          v_tra_cam_estado:= 424; -- Pasar a CDA totamente Pagada
       ELSIF p_estado = 'V' then
          v_tra_cam_estado:= 422; -- Pasar a CDA a Vencido
       ELSIF p_estado = 'S' then
          v_tra_cam_estado:= 409; -- Pasa a (S) Bloqueo de Saldo
       END IF;
       --- Agregado cuando la transaccion viene por cambio de verificacion
       IF p_estado in ('A','X') then
          v_tra_cam_estado := 401;
       END IF;
       IF g_movs.cod_usuario is null then
          -- inicializo porque no se cargaron los datos
          g_movs.cod_usuario := UPPER(user);
          g_movs.nro_secuencia := 1;
          g_movs.COD_TRA_PADRE := v_tra_cam_estado;

       END IF;
      /* Si la cuenta cambio o es la primera vez que se llama */
       IF  nvl(p_nro_cuenta,' ') <> nvl(g_ctas.nro_cuenta,' ') THEN
          v_lugar := 'lp_obt_cuenta';
          pag_cta.pr_obt_cuenta(p_nro_cuenta );
          IF v_ok_procesar = 'N' THEN
              pag_cta.g_cod_error := 22; --Hubo error
          ELSE
             pag_cta.g_cod_error := 00; --Sin error
          END IF;
          --v_llamado := 'S';
          --
          g_movs.cod_mod_padre := 4;
          g_movs.cod_mad_padre := 41;
          g_movs.cod_ofi_origen := v_cod_oficina;
          --
       END IF;
      --
       if pag_cta.g_cod_error = 00 then  -- si no hubo error
          v_lugar := 'Llavea_cuenta';
        if pag_cta.fu_llavear_cuenta(41, p_nro_cuenta) = 'N' then
           pag_cta.g_cod_error := 23;
           pag_cta.g_msj_error := 'Cuenta Llaveada';
        end if;
       end if;
       if pag_cta.g_cod_error = 00 then  -- si no hubo error
          v_lugar := 'Pr_act_estado - Update Estado';
          --Actualiza el estado de las Cuentas
          pag_cta.pr_act_est_cta(p_nro_cuenta,
                        41,
                        p_estado,
                        v_fec_apertura);

          v_lugar := 'Pr_act_est_cta - Insert Ge_movimientos' ;
          r_gmovi.cod_modulo := 4;
          r_gmovi.cod_modalidad := 41;
          r_gmovi.cod_oficina := v_cod_oficina;
          r_gmovi.nro_cuenta :=  P_NRO_CUENTA;
          r_gmovi.cod_moneda := rg_pres.cod_moneda;
          r_gmovi.cod_usuario := user;
          -- aumento la secuencia
          g_movs.nro_secuencia := g_movs.nro_secuencia + 1;
          r_gmovi.nro_secuencia  := g_movs.nro_secuencia;
          --
          r_gmovi.hora :=  p_hora    ;
          r_gmovi.fecha := p_fec_proceso   ;
          r_gmovi.fec_valor := p_fec_proceso;
          r_gmovi.cod_tra_padre :=  g_movs.cod_tra_padre;
          r_gmovi.cod_mod_padre :=  4;
          r_gmovi.cod_mad_padre :=  41;
          r_gmovi.cod_transaccion := v_tra_cam_estado;
          r_gmovi.monto := null;
          r_gmovi.nro_documento := p_nro_documento;
          r_gmovi.cod_tasa := null;
          r_gmovi.val_tasa := null;
          r_gmovi.cotizacion := null;
          r_gmovi.cod_ofi_origen := v_cod_oficina;
          r_gmovi.emi_aviso := 'N';
          r_gmovi.concepto :=  'Cambio de Estado al Sobregiro';
          r_gmovi.est_cuenta := p_estado;
          r_gmovi.estado          := g_movs.estado;
          r_gmovi.reversado       := 'N';
          r_gmovi.nro_caja        := null;
          r_gmovi.nro_documento2 := null;
          r_gmovi.nro_documento3 := null;
          r_gmovi.referencia     := null;
          -- genero el movimiento por cambio de estado
          pag_gen.pr_ins_ge_movimiento(r_gmovi,v_nocturno);
          -- inserto la novedad de la cuentas
          LP_GEN_NOV_CUENTA(p_fec_proceso, p_hora);
       end if;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20017,SQLERRM||v_lugar);
    END;
   --

BEGIN
   Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
   --
   v_nro_secuencia :=0;
   rg_cal  := pag_cal.fu_obt_reg_cal(4);
   vg_ult_dia_mes_habil := rg_cal.ult_dia_mes_habil;
   vg_ult_dia_mes       := rg_cal.ult_dia_mes;
   vg_pri_dia_mes       := rg_cal.pri_dia_mes;
   vg_pri_dia_mes_habil := rg_cal.pri_dia_mes_habil;
   vg_fec_actual        := rg_cal.fec_actual;
   vg_fec_anterior      := rg_cal.fec_anterior;


   v_hor_c := fug_obt_hor_disponible(v_fec_actual,to_char(SYSDATE,'HH24:MI:SS'),user,'N');
   v_hora :=fug_obt_hor_disponible(v_fec_actual,v_hor_c,user,'N');
   v_cod_oficina := fug_obt_ofi_usuario(user);
   pap_pre.PR_OBT_DAT_PRESTAMO(p_cta_prestamo,rg_pres);

   --elimina autorizaciones para obtener deuda original (sin descuentos)
   delete from ge_autorizaciones
      where nro_cuenta    = p_nro_cuenta
    and cod_usu_utilizador  is null;  
    
   delete from ge_autorizaciones
	  where nro_cuenta      = p_nro_cuenta 
	    and cod_autorizacion < 0;
    
    /*VER SI SE DEBE INCLUIR CONTROL DUAL?*/
   pap_pre.pr_ini_autorizacion;
   pap_pre.PR_INI_VAR_COBRO;
   pap_pre.pr_obt_deu_prestamo(p_cta_prestamo, v_fec_actual,
                               0, 999,
                               rg_pres.cod_oficina, null, v_error, v_mensaje,
                               v_tot_sal_capital, v_tot_sal_interes, v_sal_int_ade,
                               v_tot_mora, v_tot_mor_interes, v_tot_mor_int_ade,
                               v_tot_punitorio, v_tot_impuesto,
                               v_tot_cargo, v_tot_car_iva, v_tot_int_descontado,
                               v_dia_mora,
                               359, v_tip_cancelacion);
   if v_error <> 0 then
     raise_application_error(-20000,'Error en PRP_CAN_PRESTAMO Al Buscar la Deuda. '||v_mensaje);
   end if;
   
    -- si no se exonera nada, se obtiene la deuda total, si hay exoneracion va Saldo Capital  + Dev. No. Cobrado
   if nvl(p_exonera,'N') = 'N' then
     v_tot_deuda := nvl(v_tot_sal_capital,0) +
                  nvl(v_tot_sal_interes,0) +
                  nvl(v_tot_mora,0)        +
                  nvl(v_tot_mor_interes,0) +
                  nvl(v_tot_mor_int_ade,0) +
                  nvl(v_tot_punitorio,0)   +
                  nvl(v_tot_impuesto,0)    +
                  nvl(v_tot_cargo,0);
   else
     -- saldo capital  + dev. no cobrado es la deuda a trasladar como sobregiro
     v_tot_deuda := nvl(rg_pres.sal_capital,0) + nvl(rg_pres.dev_no_cobrado,0);
   end if;  
   dbms_output.put_line('Deuda '|| v_tot_deuda);           
   v_dia_mora  := rg_pres.dia_atraso; -- dias de atraso del prestamo
   --
   if length('Canc. total Préstamo: '||p_cta_prestamo||'.Pase a Sobregiro.') <= 100 then
     v_concepto := 'Canc. total Préstamo: '||p_cta_prestamo||'.Pase a Sobregiro.';
   else
     v_concepto := substr('Canc. total Préstamo: '||p_cta_prestamo||'.Pase a Sobregiro.',1,100);
   end if;

   BEGIN
     SELECT MIN(a.fec_vencimiento), MAX(a.fec_vencimiento)
       INTO v_fec_ini_mora, v_fec_fin_mora
       FROM pr_cuotas a
      WHERE a.nro_cuenta = p_cta_prestamo
        AND a.estado != 'N'
        AND a.sal_capital > 0;
        /*AND a.fec_vencimiento < pag_cal.fu_obt_fec_actual(6);*/
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       raise_application_error(-20000,'No se encontró Fecha Inicio de Deuda. '||SQLERRM);
     WHEN OTHERS THEN
       raise_application_error(-20000,'Error al buscar Fecha Inicio de Deuda. '||SQLERRM);
   END;
   ---
   -- se toma la fecha de inicio del prestamo como fecha de apertura de la cta cte.
   v_fec_apertura := v_fec_actual; --rg_pres.fec_inicio; --v_fec_ini_mora;--fec apertura ctacte.
   --
   begin
     select a.cod_persona
       into v_cod_persona
       from ge_cta_clientes a
      where a.nro_cuenta = p_cta_prestamo
        and a.relacion = 'P';
   exception
     when others then
     raise_application_error(-20000,'Error al Buscar Persona '||sqlerrm);
   end;

    -- Cancelación del prestamo
    begin
      pag_vta.PR_VTA_CAR_PREAPROBADOS(p_cta_prestamo,v_hora, v_nro_secuencia,nvl(p_exonera,'N'));

      update ge_cta_dat_adicionales
        set val_parametro = p_nro_cuenta
      where nro_cuenta = p_cta_prestamo
        and parametro  = 'PASE_SOB_PPA';
    exception
        when others then
        raise_application_error(-20001,'Error Cancelar la Cta. '||p_cta_prestamo||'-'|| sqlerrm);
   end;



     /*SE CREA LINEA DE SOBREGIRO PARA DEBITAR A LA NVA. CTA CTE.*/
     BEGIN
       --Traer el Nro. de Secuencia--
       SELECT s_nro_lin_sobregiro.nextval
         INTO v_nro_sec_padre
         FROM dual;
     EXCEPTION
       WHEN no_data_found THEN
         v_nro_sec_padre := 1;
       WHEN OTHERS THEN
         raise_application_error(-20034,
                                 'Error al generar secuencia de sobregiro. Persona: ' ||
                                  v_cod_persona || ' ' || SQLERRM);
     END;

     BEGIN
       --v_lugar := '31-Insert CC_LIN_SOBREGIROS';
       INSERT INTO cc_lin_sobregiros
             (nro_cuenta,
              fec_vencimiento,
              fec_inicio,
              nro_secuencia,
              monto,
              tipo,
              cod_persona,
              cod_moneda,
              estado,
              nro_sec_padre,
              observacion,
              niv_aprobacion,
              cotizacion)
      VALUES (p_nro_cuenta,
              v_fec_actual,
              v_fec_actual,
              v_nro_sec_padre,
              v_tot_deuda,
              'T',
              v_cod_persona,
              rg_pres.cod_moneda,
              'A',
              NULL,
              substr('LINEA AUTOMATICA POR CANCELACION DE PRESTAMOS PRE-APROBADO '||
              'OFERTADOS EN CANAL '||fug_obt_des_canal(rg_pres.cod_canal),1,1000),
              7,
              NULL);
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20035,
                                  'Error al insertar datos en CC_LIN_SOBREGIRO. SECUENCIA= ' ||
                                  v_nro_sec_padre || ' Persona: ' ||
                                  v_cod_persona || ' ' || SQLERRM);
     END;
     --
     BEGIN
       INSERT INTO cc_lin_sob_garantias
                  (mto_aplicado, nro_secuencia, cod_garantia)
       VALUES
                  (v_tot_deuda, v_nro_sec_padre, 1);
     EXCEPTION
       WHEN OTHERS THEN
       raise_application_error(-20041,'Error al insertar datos en CC_LIN_SOB_GARANTIAS. Persona: ' ||
                                          v_cod_persona || ' ' || SQLERRM);
     END;
     /****************** FIN LINEA SOBREGIRO ********************/
     -- Movimiento para cambio de Estado de Abierta a Normal.
     ---
     
     lp_act_estado(p_nro_cuenta,
                           'N',
                           v_fec_actual,
                           v_hor_c,
                           NULL,
                           'S');

     -- Actualiza la Cuenta Crédito / Destino
     v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
     pag_cta.pr_act_operacion(p_nro_cuenta,
                               v_hora,--HORA
                               'D',
                              rg_pres.cod_moneda,      --Moneda de la Operación
                              v_tot_deuda,
                              359,-- Cobro de prestamos
                              503,-- Debito
                              p_cta_prestamo,
                              NULL,                       --COTIZACION
                              v_cod_oficina,      --cod_ofi_origen
                              6,      --cod_mod_padre
                              rg_pres.cod_modalidad,   --cod_mad_padre
                              null,                       --cod_tasa
                              null,                       --val_tasa
                              v_concepto,
                              'S',                        --emi_aviso
                              v_nro_secuencia,
                              v_fec_actual,null, null, null,v_est_movimiento );-- C.D.Fase II

     if pag_cta.fu_obt_cod_error() <> 0 then
        raise_application_error(-20000,pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
     end if;
--   end if;
   -- Recibo.
   v_nro_documento := fug_obt_lla_pardinamico('NRO_RECIBO', 6, rg_pres.cod_modalidad, rg_pres.cod_moneda, v_cod_oficina)+1;
   prg_act_par_dinamico('NRO_RECIBO',6, rg_pres.cod_modalidad, rg_pres.cod_moneda, v_cod_oficina, v_nro_documento);
---------------**
   --- Actualizar formas de cobro con el recibo y la factura
   if v_nro_documento is not null or v_nro_factura is not null then
      update ge_movimientos
         set nro_documento = v_nro_documento,
             --nro_documento2 = v_nro_factura  --RI: 30/06/2010, el nro. de factura va ahora al campo referencia
             referencia    = v_nro_factura     --porque es alfanumerico y nro_documento2 (numerico) no permite
       where fecha = v_fec_actual
         and hora = v_hora
         and cod_usuario = user
         and cod_transaccion in (503,842);
   end if;
   ---
   --- Inicializar variables de cobro
   pap_pre.pr_ini_var_cobro;
   ---
  /*SE GENERA EL SOBREGIRO*/
  if vg_fec_actual = vg_ult_dia_mes_habil then
     vg_dif_dias := round(vg_ult_dia_mes - vg_fec_anterior , 0) - 1;
  elsif vg_fec_actual = vg_pri_dia_mes_habil then
     vg_dif_dias := round(vg_pri_dia_mes_habil - vg_pri_dia_mes, 0);
         --v_fecinic := vg_pri_dia_mes - 1;
  else
     vg_dif_dias := round(vg_fec_actual - vg_fec_anterior , 0) - 1;
        -- v_fecinic := vg_fec_anterior;
  end if;
  --
  vg_dia_mora := v_dia_mora - vg_dif_dias;
  --
  FOR K in 1.. vg_dia_mora LOOP

     IF k > 1 then
       v_fec_ini_mora := v_fec_ini_mora + 1;
     END IF;

     BEGIN
       INSERT INTO cc_sobregiros
        (nro_cuenta,
         fecha,
         saldo,
         liquidado,
         sal_total,
         sal_retenido,
         mto_linea,
         can_dias,
         mto_lin_transitoria,
         can_dia_sobregiro,
         generado)
       VALUES
        (p_nro_cuenta,
         v_fec_ini_mora,
         v_tot_deuda,
         'S',
         v_tot_deuda,
         0,
         0, --v_tot_deuda,  -- si lleva mto de linea pone a 0 la cantidad de dias.
         k,
         null,
         k,
         'N'
         );
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000,'Error al Generar cc_sobregiros '||SQLERRM);
     END;

     BEGIN
       INSERT INTO cc_sobregiros_ant
        (nro_cuenta,
         fecha,
         saldo,
         liquidado,
         sal_total,
         sal_retenido,
         mto_linea,
         can_dias,
         mto_lin_transitoria,
         can_dia_sobregiro,
         generado)
       VALUES
        (p_nro_cuenta,
         v_fec_ini_mora,
         v_tot_deuda,
         'S',
         v_tot_deuda,
         0,
         0, --v_tot_deuda,
         k,
         null,
         k,
         'N'
         );
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000,'Error al Generar cc_sobregiros '||SQLERRM);
     END;


   END LOOP;

   --
   --Determinacion de Situacion del sobregiro--
     --campo cc_lin_sobregiros.sit_deuda
   IF nvl(v_dia_mora, 0) < 61 THEN
     v_sit_sobregiro := 'S';
   ELSIF v_dia_mora < 91 THEN
     v_sit_sobregiro := 'V';
   ELSIF v_dia_mora < 181 THEN
     v_sit_sobregiro := 'G';
   ELSIF v_dia_mora < 361 THEN
     v_sit_sobregiro := 'M';
   ELSE
     v_sit_sobregiro := 'I';
   END IF;
   --
   BEGIN
     INSERT INTO cc_sobregiros_res
      (nro_cuenta,
       can_dias,
       sit_deuda,
       can_dia_sobregiro,
       max_atraso,
       pro_atraso,
       mto_sob_suspenso,
       mto_mora
      )
     VALUES
      (p_nro_cuenta,
       vg_dia_mora, --v_dia_mora,
       v_sit_sobregiro,
       vg_dia_mora, --v_dia_mora,
       v_dia_mora,
       v_dia_mora,
       null,
       v_tot_deuda
       );
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000,'Error al Generar cc_sobregiros_res '||SQLERRM);
   END;

   BEGIN
     INSERT INTO cc_sobregiros_res_ant
      (nro_cuenta,
       can_dias,
       sit_deuda,
       usu_insercion,
       fec_insercion,
       usu_modificacion,
       fec_modificacion,
       can_dia_sobregiro,
       max_atraso,
       pro_atraso,
       mto_sob_suspenso,
       mto_mora,
       fecha
      )
     VALUES
      (p_nro_cuenta,
       vg_dia_mora, --v_dia_mora,
       v_sit_sobregiro,
       user,
       sysdate,
       user,
       sysdate,
       vg_dia_mora, --v_dia_mora,
       v_dia_mora,
       v_dia_mora,
       null,
       v_tot_deuda,
       pag_cal.FU_OBT_FEC_ANTERIOR(6)
       );
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000,'Error al Generar cc_sobregiros_res_ant '||SQLERRM);
   END;

   BEGIN
     UPDATE cc_lin_sobregiros a
        SET a.monto = a.monto - v_tot_deuda
      WHERE a.nro_secuencia = v_nro_sec_padre;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000,'Error al Actaulizar cc_lin_sobregiros '||SQLERRM);
   END;
exception
    when others then
       raise_application_error(-20000,'Error en PRP_CAN_PRESTAMO '||sqlerrm);
END;
/


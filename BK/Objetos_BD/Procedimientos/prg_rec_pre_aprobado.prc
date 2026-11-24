CREATE OR REPLACE PROCEDURE IT.PRG_REC_PRE_APROBADO( p_cod_persona in ge_pro_pre_aprobados.cod_persona%type,
                                                  p_nro_solicitud in ge_pro_pre_aprobados.nro_solicitud%type
                                                  ) IS
--pragma autonomous_transaction;
/*---Recalcular Pre-Aprobados--*/
--- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
 C_TASA_REF       NUMBER := 980;
 rg_pre_aprobados ge_pro_pre_aprobados%rowtype;
 v_cod_modulo     ba_modulos.cod_modulo%type;
 v_cod_modalidad  ge_modalidades.cod_modalidad%type;
 v_cod_sub_modalidad ge_pro_pre_aprobados.cod_sub_modalidad%type;
 v_monto          ge_pro_pre_aprobados.mto_max_cuota%type;
 v_mto_maximo     ge_pro_pre_aprobados.mto_max_cuota%type;
 v_mto_minimo     pr_simulaciones.monto%type;
 v_tasa           NUMBER;
 v_plazo          NUMBER;
 v_cod_mon_local  ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
 v_redondeo       NUMBER := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,null, v_cod_mon_local);
 v_usu_hb         ba_usuarios.cod_usuario%type := 'HBANK';  -- HBANK
 v_lugar          varchar2(1000);

 cursor c_rec is
   select a.*
   from ge_pro_pre_aprobados a
   where nvl(fug_obt_pardinamico('MOD_REC_PRE_APR',a.cod_modulo,a.cod_modalidad),'N') = 'S'
     and a.cod_persona = p_cod_persona
     and a.estado = 'V'
     and a.nro_solicitud is null
     and a.cod_modulo = v_cod_modulo
     and a.cod_modalidad != v_cod_modalidad;
--
-- Procedimiento para obtener el registro del Pre-Aprobado tomado --
  PROCEDURE lp_obt_pre_aprobado is
  BEGIN
   select a.*
     into rg_pre_aprobados
     from ge_pro_pre_aprobados a
    where a.cod_persona = p_cod_persona
      and a.nro_solicitud = p_nro_solicitud;
  EXCEPTION
    when others then
      rg_pre_aprobados := null;
      raise_application_error(-20000, 'Error al obtener el Pre-Aprobado. Solicitud Nro. : '||p_nro_solicitud||' - '|| SQLERRM);
  END;
--
--****Para Obtener CARGOS de prestamos
  FUNCTION lf_obt_cargos
 ( p_nro_solicitud  IN pr_solicitudes.nro_solicitud%TYPE,
   p_cod_modulo     IN ba_modulos.cod_modulo%TYPE
 )
 RETURN NUMBER
 IS
v_mto_car_interes number(18,4);
v_mto_seg_vida number(18,4);
v_periodo number;
v_can_periodos number;
V_MTO_SEG_INCENDIO pr_gar_hipotecarias.val_edilicio%type DEFAULT 0;
V_NRO_GARANTIA     pr_sol_garantias.nro_garantia%type;
V_RESULTADO NUMBER:=0;
BEGIN
    --Obtenemos el Mto_car_interes mayor de las cuotas
    Begin
     SELECT max(DECODE(P.IVA_DESGLOSE,
                 'S',
                 (DECODE(P.COD_MONEDA,'GS',ROUND((S.VAL_INTERES*10)/100,0),ROUND((S.VAL_INTERES*10)/100,2))),
                 0
                 )) MTO_CAR_INTERES
           into v_mto_car_interes
          FROM PR_SOL_CUOTAS S, PR_SOLICITUDES P
          WHERE S.NRO_SOLICITUD = P.NRO_SOLICITUD
           -- AND S.NRO_CUOTA =1
            and s.nro_solicitud=p_nro_solicitud;
    exception
        when no_data_found then
           v_mto_car_interes:=0;
        WHEN OTHERS THEN
           v_mto_car_interes:=0;
    END;
    --Obtenemos Datos del Seguro de Vida de la cuota 1
    Begin
        SELECT pap_pre.fu_obt_cal_mto_seg_vida(p.cod_modalidad,
                                               p.cod_modulo,
                                               p.cod_moneda,
                                               NVL(p.cod_oficina,NULL),
                                               decode(s.sal_cap_anterior,0, p.tot_desembolsar,s.sal_cap_anterior),
                                               nvl(c.cod_ent_seguro,fug_obt_ent_seguro(p.cod_modulo, p.cod_modalidad, 'V')),
                                               p.fec_inicio,
                                               null,
                                               decode(c.cod_transaccion,1521,'F','V'),
                                               p.tot_prestamo), s.dia_periodo
          INTO v_mto_seg_vida, v_periodo
          FROM PR_SOL_CUOTAS S,
               PR_SOLICITUDES P,
               PR_SOL_CARGOS C
          WHERE S.NRO_SOLICITUD = P.NRO_SOLICITUD
           AND S.NRO_CUOTA > 0
           AND S.NRO_SOLICITUD = C.NRO_SOLICITUD
           AND C.COD_TRANSACCION = 1521
           AND S.NRO_SOLICITUD = p_nro_solicitud
           AND S.NRO_CUOTA = 1;

           --DYDMR-5855
           if nvl(v_periodo,0) > 30 then
             v_can_periodos := floor(v_periodo / 30);
             v_mto_seg_vida := v_mto_seg_vida*NVL(v_can_periodos,1); --multiplica el monto por los meses obtenidos
           end if;
      Exception
        When no_data_found Then
          v_mto_seg_vida := 0;
      End;
      --Obtenemos Datos del Seguro de Incendio de la cuota 1
      begin
        SELECT DISTINCT NVL(G.NRO_GARANTIA,NULL)
          INTO V_NRO_GARANTIA
          FROM PR_SOL_GARANTIAS G
         WHERE G.NRO_SOLICITUD = p_nro_solicitud
           AND G.COD_GARANTIA IN (3, 13);  -- Res. 12
      exception
        when others then
          V_NRO_GARANTIA := NULL;
      end;

      IF V_NRO_GARANTIA IS NOT NULL THEN
           begin
             SELECT pap_pre.fu_obt_cal_mto_seg_incendio(p.cod_modalidad,
                                                            p.cod_modulo,
                                                            p.cod_oficina,
                                                            V_NRO_GARANTIA,
                                                            NULL,
                                                            fug_obt_ent_seguro(p.cod_modulo, p.cod_modalidad, 'I'),
                                                            p.cod_moneda,
                                                            p.fec_inicio)
                  INTO V_MTO_SEG_INCENDIO
                    FROM  PR_SOLICITUDES P
                       WHERE p.NRO_SOLICITUD = p_nro_solicitud;
          exception
            when no_data_found then
               V_MTO_SEG_INCENDIO:=0;
             when others then
               V_MTO_SEG_INCENDIO:=0;
          end;

       END IF;

     V_RESULTADO:= nvl(v_mto_car_interes,0) + nvl(v_mto_seg_vida,0) +nvl(V_MTO_SEG_INCENDIO,0) ;

    RETURN(V_RESULTADO);
End;
--************************
-- Funcion para obtener el monto de la cuota o monto de la Linea de la Tarjeta del Pre-Aprobado tomado --
  FUNCTION lf_obt_monto( p_nro_solicitud  IN pr_solicitudes.nro_solicitud%TYPE,
                         p_cod_modulo     IN ba_modulos.cod_modulo%TYPE)
          RETURN NUMBER IS
   v_importe pr_solicitudes.monto%TYPE := 0;
   v_cargos  pr_solicitudes.monto%TYPE := 0;
   v_nro_cuota number;
   v_fec_inicio date;
   v_fec_pri_vencimiento_ori date;
   v_fec_pri_vencimiento date;
  BEGIN
   If p_cod_modulo = 6 then
     begin
       select a.fec_inicio
         into v_fec_inicio
         from pr_solicitudes a
        where a.nro_solicitud = p_nro_solicitud;
     end;
     begin
       select a.fec_vto_habil
         into v_fec_pri_vencimiento
         from pr_sol_cuotas a
        where a.nro_solicitud = p_nro_solicitud
          and a.nro_cuota = 1;
     end;
     v_fec_pri_vencimiento_ori := add_months(v_fec_inicio,1);
     
      if v_fec_pri_vencimiento_ori <> v_fec_pri_vencimiento then
        v_nro_cuota := 2;
      else
        v_nro_cuota := 1;
      end if;
      BEGIN
         select nvl(mto_capital,0) + nvl(val_interes,0)
         into v_importe
          from pr_sol_cuotas
            where nro_solicitud = p_nro_solicitud
            and nro_cuota = v_nro_cuota;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 0;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al obtener monto cuota prestamos - ' || SQLERRM);
      END;
      --03/05 Obtenemos los cargos
      v_cargos:= lf_obt_cargos(p_nro_solicitud,p_cod_modulo);
      -- Sumamos el cargo a lo obtenido anteriormente si tiene
      v_importe:= nvl(v_importe,0) + nvl(v_cargos,0);
      RETURN v_importe;

   Else
     If p_cod_modulo = 5 then
        BEGIN
           select nvl(monto,0)
           into v_importe
           from ta_solicitudes
           where nro_solicitud = p_nro_solicitud;
           RETURN v_importe;
        EXCEPTION
           WHEN no_data_found THEN
              RETURN 0;
           WHEN OTHERS THEN
              raise_application_error(-20000, 'Error al obtener monto de tarjetas - ' || SQLERRM);
        END;
     End If;
   End If;
  END;
--
-- Funcion para obtener el Valor Actual o Valor Presente a una Tasa y Plazo dado --
  FUNCTION lf_obt_val_actual( A NUMBER, i NUMBER, n NUMBER ) RETURN NUMBER IS
    -- A = Amortización o monto máximo de cuota.
    -- i = Tasa de interés anual / 12 (para obtener el interés mensual)
    -- n = plazo a calcular en meses
    -- vp = A * [ (1-(1+i)^-n) / i ]
    v_monto NUMBER;
  BEGIN
    v_monto := A * ( (1 - ( (1+ ((i/100)/12))**(-n) )) / ((i/100)/12) );
    RETURN nvl(v_monto,0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;

  FUNCTION lf_obt_val_tasa(p_cod_modulo in ba_modulos.cod_modulo%type
           ,p_cod_modalidad in ge_modalidades.cod_modalidad%type
           ,p_cod_oficina in ba_oficinas.cod_oficina%type
           ,p_nro_cuenta in varchar2
           ,p_cod_moneda in ba_monedas.cod_moneda%type
           ,p_mto_transaccion in number := 0
           ,p_tas_personalizada in varchar2 := 'N'
           ,p_cod_tasa in ge_tasas.cod_tasa%type
           ,p_cod_transaccion in ge_transacciones.cod_transaccion%type
           ,p_fec_final in date
           ,p_cod_sub_modalidad in ge_sub_modalidades.cod_sub_modalidad%type default null)
  return number is
  v_val_tasa ge_tas_fechas.val_tasa%type;
  v_fec_vigencia date;
  v_cod_tasa ge_tasas.cod_tasa%type;
  v_tip_valor ge_tasas.tip_valor%type;
  v_tipo ge_tasas.tipo%type;
  begin
    v_cod_tasa := p_cod_tasa;
    v_fec_vigencia := pae_cnf.fu_obt_fec_actual(1);
    pag_gen.pr_obt_val_tasa(p_cod_modulo,p_cod_modalidad,p_cod_oficina,
                            p_nro_cuenta,  p_cod_moneda, p_mto_transaccion,p_tas_personalizada,
                            v_cod_tasa, p_cod_transaccion,p_fec_final,v_val_tasa,v_fec_vigencia,
                            v_tip_valor, v_tipo, null, p_cod_sub_modalidad );
  return v_val_tasa;
  exception
    when others then
    raise_application_error(-20000,'Error en lf_obt_val_tasa '||p_cod_modalidad||'-'||p_cod_sub_modalidad||'.- '||sqlerrm);
  end;
--
-- Calcular Montos por plazos para Pre-Aprobados de la Modalidad 68 --
  PROCEDURE lp_cal_montos IS
  BEGIN
    if rg_pre_aprobados.max_plazo >= 12 then
      v_plazo := 12;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_12_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_12_meses := round(rg_pre_aprobados.plz_12_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_12_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_12_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_12_meses := null;
    end if;

    if rg_pre_aprobados.max_plazo >= 18 then
      v_plazo := 18;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_18_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_18_meses := round(rg_pre_aprobados.plz_18_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_18_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_18_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_18_meses := null;
    end if;

    if rg_pre_aprobados.max_plazo >= 24 then
      v_plazo := 24;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_24_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_24_meses := round(rg_pre_aprobados.plz_24_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_24_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_24_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_24_meses := null;
    end if;

    if rg_pre_aprobados.max_plazo >= 30 then
      v_plazo := 30;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_30_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_30_meses := round(rg_pre_aprobados.plz_30_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_30_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_30_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_30_meses := null;
    end if;

    if rg_pre_aprobados.max_plazo >= 36 then
      v_plazo := 36;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_36_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_36_meses := round(rg_pre_aprobados.plz_36_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_36_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_36_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_36_meses := null;
    end if;

    if rg_pre_aprobados.max_plazo >= 42 then
      v_plazo := 42;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_42_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_42_meses := round(rg_pre_aprobados.plz_42_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_42_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_42_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_42_meses := null;
    end if;

    if rg_pre_aprobados.max_plazo >= 48 then
      v_plazo := 48;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_48_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_48_meses := round(rg_pre_aprobados.plz_48_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_48_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_48_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_48_meses := null;
    end if;

    if rg_pre_aprobados.max_plazo >= 54 then
      v_plazo := 54;
      v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
      rg_pre_aprobados.plz_54_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
      rg_pre_aprobados.plz_54_meses := round(rg_pre_aprobados.plz_54_meses,v_redondeo);
      if nvl(rg_pre_aprobados.plz_54_meses,0) < rg_pre_aprobados.min_monto then
        rg_pre_aprobados.plz_54_meses := null;
      end if;
    else
      rg_pre_aprobados.plz_54_meses := null;
    end if;

  if rg_pre_aprobados.max_plazo >= 60 then
    v_plazo := 60;
    v_tasa := lf_obt_val_tasa(v_cod_modulo,v_cod_modalidad,null,null,null,v_plazo,'N',C_TASA_REF,null,null,v_cod_sub_modalidad);
    rg_pre_aprobados.plz_60_meses := lf_obt_val_actual(v_mto_maximo, v_tasa, v_plazo);
    rg_pre_aprobados.plz_60_meses := round(rg_pre_aprobados.plz_60_meses,v_redondeo);
    if nvl(rg_pre_aprobados.plz_60_meses,0) < rg_pre_aprobados.min_monto then
      rg_pre_aprobados.plz_60_meses := null;
    end if;
  else
    rg_pre_aprobados.plz_60_meses := null;
  end if;

  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al calcular montos - ' || SQLERRM);
  END;
--
-- Procedimiento para insertar al registro del Pre-Aprobado --
  PROCEDURE lp_ins_pre_aprobados IS
  v_nro_secuencia  ge_pro_pre_aprobados.nro_secuencia%type;
  BEGIN
    Begin
       Select nvl(max(a.nro_secuencia),0) + 1
         into v_nro_secuencia
       from ge_pro_pre_aprobados a
       where a.cod_persona = rg_pre_aprobados.cod_persona
         and a.lote = rg_pre_aprobados.lote
         and a.cod_modulo = rg_pre_aprobados.cod_modulo
         and a.cod_modalidad = rg_pre_aprobados.cod_modalidad  ;
    EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al insertar Pre-Aprobado - ' || SQLERRM);
    END;
    --08/05 al insertar nuevo registro ya no debe insertar la sub-modalidad
    INSERT INTO ge_pro_pre_aprobados( cod_persona, lote, cod_oficina,cod_usu_oficial,
                                      estado, lin_vigente_tc, lin_nueva_tc, mto_max_cuota,
                                      plz_12_meses, plz_18_meses, plz_24_meses, plz_30_meses,
                                      plz_36_meses, plz_42_meses, plz_48_meses, plz_54_meses,
                                      plz_60_meses, cod_segmento, val_min_tasa, val_max_tasa,
                                      cod_campana, cod_modulo, cod_modalidad, min_monto,
                                      max_monto, min_plazo, max_plazo, ind_evaluacion,
                                      ind_hab_atm, ind_hab_hb, nro_secuencia, cod_sub_modalidad,
                                      denominacion,fec_vto_campana )
      VALUES( rg_pre_aprobados.cod_persona, rg_pre_aprobados.lote, rg_pre_aprobados.cod_oficina, rg_pre_aprobados.cod_usu_oficial,
              rg_pre_aprobados.estado, rg_pre_aprobados.lin_vigente_tc, rg_pre_aprobados.lin_nueva_tc, rg_pre_aprobados.mto_max_cuota,
              rg_pre_aprobados.plz_12_meses, rg_pre_aprobados.plz_18_meses, rg_pre_aprobados.plz_24_meses, rg_pre_aprobados.plz_30_meses,
              rg_pre_aprobados.plz_36_meses, rg_pre_aprobados.plz_42_meses, rg_pre_aprobados.plz_48_meses, rg_pre_aprobados.plz_54_meses,
              rg_pre_aprobados.plz_60_meses, rg_pre_aprobados.cod_segmento, rg_pre_aprobados.val_min_tasa, rg_pre_aprobados.val_max_tasa,
              rg_pre_aprobados.cod_campana, rg_pre_aprobados.cod_modulo, rg_pre_aprobados.cod_modalidad, rg_pre_aprobados.min_monto,
              rg_pre_aprobados.max_monto, rg_pre_aprobados.min_plazo, rg_pre_aprobados.max_plazo, rg_pre_aprobados.ind_evaluacion,
              rg_pre_aprobados.ind_hab_atm, rg_pre_aprobados.ind_hab_hb, v_nro_secuencia, rg_pre_aprobados.cod_sub_modalidad,
              rg_pre_aprobados.denominacion, rg_pre_aprobados.fec_vto_campana);
  EXCEPTION
    WHEN dup_val_on_index THEN
      raise_application_error(-20000, 'Registro de Pre-Aprobado Duplicado.');
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al insertar Pre-Aprobado - ' || SQLERRM);
  END;
--
-- Procedimiento para actualizar el registro del Pre-Aprobado --
  PROCEDURE lp_act_pre_aprobados IS
  BEGIN
    update ge_pro_pre_aprobados a
       set a.mto_max_cuota = rg_pre_aprobados.mto_max_cuota,
           a.plz_12_meses  = rg_pre_aprobados.plz_12_meses,
           a.plz_18_meses  = rg_pre_aprobados.plz_18_meses,
           a.plz_24_meses  = rg_pre_aprobados.plz_24_meses,
           a.plz_30_meses  = rg_pre_aprobados.plz_30_meses,
           a.plz_36_meses  = rg_pre_aprobados.plz_36_meses,
           a.plz_42_meses  = rg_pre_aprobados.plz_42_meses,
           a.plz_48_meses  = rg_pre_aprobados.plz_48_meses,
           a.plz_54_meses  = rg_pre_aprobados.plz_54_meses,
           a.plz_60_meses  = rg_pre_aprobados.plz_60_meses
     where a.cod_persona   = rg_pre_aprobados.cod_persona
       and a.lote          = rg_pre_aprobados.lote
       and a.cod_modulo    = rg_pre_aprobados.cod_modulo
       and a.cod_modalidad = rg_pre_aprobados.cod_modalidad
       and a.nro_secuencia = rg_pre_aprobados.nro_secuencia
       and a.estado = 'V';
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al actualizar Pre-Aprobado - ' || SQLERRM);
  END;
--
-- Procedimiento para cancelar registro de Pre-Aprobado recalculado --
  PROCEDURE lp_can_pre_aprobados IS
  BEGIN
    update ge_pro_pre_aprobados a
       set a.estado = 'C',
           a.cod_usu_cancelacion = user
     where a.cod_persona   = rg_pre_aprobados.cod_persona
       and a.lote          = rg_pre_aprobados.lote
       and a.cod_modulo    = rg_pre_aprobados.cod_modulo
       and a.cod_modalidad = rg_pre_aprobados.cod_modalidad
       --and a.nro_secuencia = rg_pre_aprobados.nro_secuencia --Se guarda con Otra secuencia
       and a.estado = 'V';
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,'Error al cancelar Pre-Aprobado - ' || SQLERRM);
  END;


--
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  -- raise_application_error(-20000, 'Solicitud Nro. : '||p_nro_solicitud||' - '||'Persona : '||p_cod_persona);
  if p_cod_persona is null then
    raise_application_error(-20000,'Código de Persona no puede ser nulo.');
  end if;

  if p_nro_solicitud is null then
    raise_application_error(-20000,'Número de Solicitud no puede ser nulo.');
  end if;
  v_lugar:='Obtener Preaprobado:'||p_nro_solicitud;
  lp_obt_pre_aprobado;
  v_cod_modulo    := rg_pre_aprobados.cod_modulo;
  v_cod_modalidad := rg_pre_aprobados.cod_modalidad;
  v_cod_sub_modalidad := rg_pre_aprobados.cod_sub_modalidad;

  if v_cod_modulo = 6 then -- Préstamos
    if rg_pre_aprobados.estado = 'C' then
      rg_pre_aprobados.estado := 'V';
    else
      return;
    end if;
    v_monto := nvl(lf_obt_monto(p_nro_solicitud,6),0);
    --Del monto máximo de la cuota se debe restar el monto de la cuota de la solicitud --
    v_mto_maximo := nvl(rg_pre_aprobados.mto_max_cuota,0) - nvl(v_monto,0);
    -- Redondear --
    v_mto_maximo := round(v_mto_maximo,v_redondeo);
    rg_pre_aprobados.mto_max_cuota := v_mto_maximo;
    rg_pre_aprobados.nro_secuencia := nvl(rg_pre_aprobados.nro_secuencia,1) + 1;

    if v_mto_maximo > 0 then
      -- Para la modalidad 68 (PRESTAMO ATM/WEB) realizar el cálculo de los montos por plazo --
      if nvl(fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',v_cod_modulo,v_cod_modalidad),'N') = 'S' then
        v_lugar:='Calcular Montos:'||p_nro_solicitud;
        lp_cal_montos;
      end if;
      -- Insertar Pre-Aprobado --
      if rg_pre_aprobados.estado = 'V' then
         v_lugar:='Borrar Pre-aprobado:'||p_nro_solicitud;
         begin
            Delete ge_pro_pre_aprobados a
            where a.cod_persona = p_cod_persona
              and a.lote = rg_pre_aprobados.lote
              and a.cod_modulo = rg_pre_aprobados.cod_modulo
              and a.cod_modalidad = rg_pre_aprobados.cod_modalidad
              and a.estado = 'V' ;
          exception
             when others then
                null ;
          end  ;
          v_lugar:='Insertar Pre-aprobado:'||p_nro_solicitud||' Mod: '||rg_pre_aprobados.cod_modalidad;
         lp_ins_pre_aprobados;
      end if;
      -- Monto minimo de la cuota
      v_mto_minimo := nvl(fug_obt_pardinamico('MTO_MIN_CUO_PRE_APR',rg_pre_aprobados.cod_modulo,rg_pre_aprobados.cod_modalidad,v_cod_mon_local),0);
      -- Si el monto maximo de la cuota es menor al monto minimo definido
      if v_mto_minimo > v_mto_maximo  then
        -- Cancelar Pre-Aprobado --
        v_lugar:='Cancelar Pre-aprobado:'||p_nro_solicitud;
        lp_can_pre_aprobados;
      end if;
    end if;

    -- Si un cliente toma un pre-aprobado de las modalidades 65 y 68 se realizará el ajuste también a la otra --
    rg_pre_aprobados := null;

    open c_rec;
    loop
      fetch c_rec into rg_pre_aprobados;
      exit when c_rec%notfound;
         --rg_pre_aprobados.mto_max_cuota := v_mto_maximo;

         --Del monto máximo de la cuota se debe restar el monto de la cuota de la solicitud --
         v_mto_maximo := nvl(rg_pre_aprobados.mto_max_cuota,0) - nvl(v_monto,0);
         -- Redondear --
         v_mto_maximo := round(v_mto_maximo,v_redondeo);
         rg_pre_aprobados.mto_max_cuota := v_mto_maximo;


         v_cod_modulo                   := rg_pre_aprobados.cod_modulo;
         v_cod_modalidad                := rg_pre_aprobados.cod_modalidad;

         if v_mto_maximo > 0 then
            -- Para la modalidad 68 (PRESTAMO ATM/WEB) realizar el cálculo de los montos por plazo --
            if nvl(fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',v_cod_modulo,v_cod_modalidad),'N') = 'S' then
              v_lugar:='Cancelar Montos II:'||p_nro_solicitud;
              lp_cal_montos;
            end if;
            -- Actualizar Pre-Aprobado --
            v_lugar:='Actualizar pre-aprob.:'||p_nro_solicitud;
            lp_act_pre_aprobados;
            -- Monto minimo de la cuota (65/68)
            v_mto_minimo := nvl(fug_obt_pardinamico('MTO_MIN_CUO_PRE_APR',rg_pre_aprobados.cod_modulo,rg_pre_aprobados.cod_modalidad,v_cod_mon_local),0);
            -- Si el monto maximo de la cuota es menor al monto minimo definido
            if v_mto_minimo > v_mto_maximo  then
              -- Cancelar Pre-Aprobado --
               v_lugar:='Cancelar pre-aprob.:'||p_nro_solicitud;
              lp_can_pre_aprobados;
            end if;
            --
         else
           -- Cancelar Pre-Aprobado --
           v_lugar:='Cancelar pre-aprob.II:'||p_nro_solicitud;
           lp_can_pre_aprobados;
         end if;
    end loop;
    --Comitear si es llamado desde ITGF
     if (substr(upper(user),1,3) = 'ATM' OR upper(USER)=v_usu_hb) THEN
       null;
     else
       commit;
     end if;
    close c_rec;
  elsif v_cod_modulo = 5 then -- Tarjetas
    if rg_pre_aprobados.estado = 'C' then
      rg_pre_aprobados.estado := 'V';
    else
      return;
    end if;
    -- Obtener Monto de la Solicitud de TC
    v_monto := nvl(lf_obt_monto(p_nro_solicitud,5),0);
    -- Del monto de la Linea de TC se debe restar el monto de la solicitud --
    v_mto_maximo := nvl(rg_pre_aprobados.lin_nueva_tc,0) - nvl(v_monto,0);
    rg_pre_aprobados.lin_nueva_tc  := v_mto_maximo;
    rg_pre_aprobados.max_monto     := v_mto_maximo;
    rg_pre_aprobados.nro_secuencia := nvl(rg_pre_aprobados.nro_secuencia,1) + 1;

    if v_mto_maximo > 0 then
      -- Insertar Pre-Aprobado --
      if rg_pre_aprobados.estado = 'V' then
         v_lugar:='Insertar pre-aprob.Tarj:'||p_nro_solicitud;
         lp_ins_pre_aprobados;
      end if;
    end if;
  end if;

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error rec.pre-aprobado - ' ||v_lugar||' ' ||SQLERRM);
END;
/


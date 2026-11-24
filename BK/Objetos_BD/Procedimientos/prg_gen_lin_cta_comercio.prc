CREATE OR REPLACE PROCEDURE IT.PRG_GEN_LIN_CTA_COMERCIO
 IS
 v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
 v_can_min_fec_ape ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAN_DIA_MIN_FEC_APE');
 v_can_dia_his_bcp ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAN_DIA_HIS_CAT_BCP');
 v_can_dia_sobregiro ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAN_DIA_SOBREGIRO');
 v_can_dia_mov_his number := nvl(fug_obt_pardinamico('CCO_CAN_DIA_MOV_HIS'),90);
 v_can_dia_val_informconf number := nvl(fug_obt_pardinamico('CCO_CAN_DIA_VAL_INFORMCONF'), 30);
 v_can_dia_val_infocheck number := nvl(fug_obt_pardinamico('CCO_CAN_DIA_VAL_INFOCHECK'), 30);
 v_cam_cta_comercio ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAM_CTA_COMERCIO');
 v_cam_cta_com_dfl ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAM_CTA_COM_DEFAULT');
 v_cod_sec_economico ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_COD_SEC_ECONOMICO');
 v_por_lin_sob number := nvl(fug_obt_pardinamico('CCO_POR_ING_POS_CTA_COM'), 20);
 v_fec_nacimiento ba_per_fisicas.fec_nacimiento%type;
 v_cod_per_ctr ba_personas.cod_persona%type;
 v_men_val_facturacion varchar2(4000);
 v_can_lin_sobregiros number;
 cursor c_cli_lin_sob is
   select g.cod_persona, p.tipo, g.cod_gru_economico
     from ge_clientes g, ba_personas p
    where g.cod_persona = p.cod_persona
      and exists (SELECT 1 FROM cc_cta_corrientes c, ge_cta_clientes cl, ge_cta_dat_adicionales d
                   where c.nro_cuenta = cl.nro_cuenta
                     and cl.relacion = 'P'
                     and c.estado = 'N'
                     and cl.cod_persona = g.cod_persona
                     and c.fec_apertura < v_fec_actual -v_can_min_fec_ape
                     and c.nro_cuenta = d.nro_cuenta
                     and d.parametro = 'IND_CTA_COMERCIO'
                     and d.val_parametro = 'S'
                     and not exists (select * from cc_lin_sobregiros s, cc_lin_sobregiros sd
                                      where s.nro_secuencia = sd.nro_sec_padre
                                        and s.estado = 'A'
                                        and instr(','|| v_cam_cta_comercio ||',' ,  ','||s.cod_campana||',') > 0
                                        and sd.nro_cuenta = c.nro_cuenta));

 cursor c_cta_lin_sob (p_cod_persona ba_personas.cod_persona%type) is
   select c.nro_cuenta, c.cod_moneda
     from cc_cta_corrientes c, ge_cta_clientes g, ge_cta_dat_adicionales d
    where g.cod_persona = p_cod_persona
      and c.nro_cuenta = g.nro_cuenta
      and g.relacion = 'P'
      and c.estado = 'N'
      and c.fec_apertura < v_fec_actual -v_can_min_fec_ape
      and c.nro_cuenta = d.nro_cuenta
      and d.parametro = 'IND_CTA_COMERCIO'
      and d.val_parametro = 'S'
      and not exists (select * from cc_lin_sobregiros s, cc_lin_sobregiros sd
                       where s.nro_secuencia = sd.nro_sec_padre
                         and s.estado = 'A'
                         and instr(','|| v_cam_cta_comercio ||',' ,  ','||s.cod_campana||',') > 0
                         and sd.nro_cuenta = c.nro_cuenta);

  v_ind_gen_lin_sob varchar2(1) := 'S';
  v_faj_buro ge_cli_antecedentes.faj_buro%type;
  v_sit_infocheck ge_cli_antecedentes.sit_infocheck%type;
  v_can_che_rechazado number;
  v_ind_cat_may_uno varchar(1);
  v_cat_rie_max varchar2(1);
  v_cat_sub_max varchar2(1);
  v_ind_den_impago varchar2(1);
  v_mto_ingreso ge_movimientos.monto%type;
  v_pro_ingreso ge_movimientos.monto%type;
  v_mto_sobregiro ge_movimientos.monto%type;
  v_min_pro_com_pos ge_movimientos.monto%type;
  v_max_pro_com_pos ge_movimientos.monto%type;
  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_val_fec_informconf varchar2(1);
  v_val_fec_infocheck varchar2(1);
  -- Procedimiento que inserta el Log del proceso de generación de línea de sobregiro
  PROCEDURE PR_INS_LOG_LIN_SOB ( P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null, P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE default null, P_MENSAJE VARCHAR2, p_error varchar2 default null ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
     insert into GE_LOG_GEN_LIN_SOB (fecha, nro_cuenta, cod_persona, observacion, det_error)
     values (v_fec_actual, p_nro_cuenta, p_cod_persona, p_mensaje, p_error);
     commit;
  EXCEPTION
     WHEN others THEN
       RAISE_APPLICATION_ERROR( -20000, 'No se ha podido insertar el log del proceso: ' || sqlerrm );
  END;

  -- Procedimiento que inserta el log del proceso de generación de línea de sobregiro
  PROCEDURE PR_INS_IMPAGOS ( p_cod_persona ba_personas.cod_persona%type ) IS
    CURSOR c_cuentas is
     SELECT mes, ano, c.cod_modulo, c.cod_modalidad, c.nro_cuenta,
            c.dia_mora dias_mora, c.cod_persona
       FROM ge_cta_dia_mor_tmp c
      WHERE c.cod_persona = p_cod_persona
        and to_date('01/'||mes||'/'||ano, 'DD/MM/YYYY') >= add_months(v_fec_actual, -13);
    v_mes number;
    v_sentencia varchar2(2000);
    v_existe varchar2(1);
 BEGIN
  begin
    delete GE_CTA_DIA_MOR_IMPAGOS
     where cod_persona = p_cod_persona
       and nro_lin_sobregiro = 0;
  exception
    when others then
      raise_application_error(-20000, 'No se ha podido eliminar el registro de impago de la cuenta. '||sqlerrm);
  end;

  For c in c_cuentas Loop
    begin
       begin
         v_mes := 12 - MONTHS_BETWEEN(add_months(trunc(v_fec_actual, 'mm'),-1),trunc(to_date('01/'||c.mes||'/'||c.ano, 'dd/mm/yyyy'), 'mm'));
       exception
         when others then
           v_mes := 0;
       end;

       if v_mes between 1 and 12 then
         begin
           select 'S'
             into v_existe
             from GE_CTA_DIA_MOR_IMPAGOS
            where nro_cuenta = c.nro_cuenta;
         exception
           when others then
              v_existe := 'N';
         END;

         IF nvl(V_EXISTE, 'N') = 'N' THEN
           begin
             v_sentencia := 'insert into GE_CTA_DIA_MOR_IMPAGOS ( cod_modulo,
                                                                  cod_modalidad,
                                                                  nro_cuenta,
                                                                  cod_persona,
                                                                  nro_lin_sobregiro,
                                                                  fec_inicio,
                                                                  fec_vencimiento,
                                                                  dia_mor_mes'||v_mes||')
                                                           values( '||c.cod_modulo||', '||
                                                                    c.cod_modalidad||', '||
                                                                   ''''||c.nro_cuenta||''','||
                                                                   c.cod_persona||', '||
                                                                   0||', '||
                                                                   'to_date('''||to_char(v_fec_actual, 'DD/MM/YYYY')||''', '''||'DD/MM/YYYY''),'||
                                                                   'to_date('''||to_char(v_fec_actual + 365, 'DD/MM/YYYY')||''', '''||'DD/MM/YYYY''),'||
                                                                   c.dias_mora||')';
             execute Immediate v_sentencia;
           exception
             when others then
               RAISE_APPLICATION_ERROR( -20000, 'No se ha podido insertar el registro de impago de la cuenta '||c.nro_cuenta ||'. '|| sqlerrm );
           end;

         ELSE
           begin
             v_sentencia := 'update GE_CTA_DIA_MOR_IMPAGOS set DIA_MOR_MES'||v_mes||' = '||c.dias_mora||
                            ' where nro_cuenta = '||''''||c.nro_cuenta||''' and nro_lin_sobregiro = '|| 0 ||' and nvl(DIA_MOR_MES'||v_mes||',0) < '||c.dias_mora;
             Execute Immediate v_sentencia;
           exception
             when others then
               RAISE_APPLICATION_ERROR( -20000, 'No se ha podido actualizar el registro de impago de la cuenta '||c.nro_cuenta ||'. '|| sqlerrm );
           end;
         END IF;
       end if;
      end;
    end loop;
  EXCEPTION
     WHEN others THEN
       RAISE_APPLICATION_ERROR( -20000, 'No se ha podido insertar el impago: ' || sqlerrm );
  END;
  FUNCTION FU_VAL_SEGMENTOS (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE) RETURN NUMBER IS
    v_can_segmentos number;
  BEGIN
    begin
      select count(*)
        into v_can_segmentos
        FROM ( SELECT nvl(b.significado,a.SGTO_VALOR_2013) SEGMENTO, to_number(a.NU_CTE) cod_persona
                 FROM dw_cli_segmentos a, ba_cod_referencias b
                WHERE a.SGTO_VALOR_2013 = b.val_minimo(+)
                  and b.dominio(+) = 'DES_SEG_ESTRUCTURAL'
                ORDER BY FH_INFORMACION desc) sc
       WHERE rownum = 1
         and sc.cod_persona = p_cod_persona
         and exists(select 1 from ba_cod_referencias
                    where dominio = 'CCO_COD_SEGMENTO'
                      and val_minimo = sc.segmento);
    exception
       when others then
         v_can_segmentos := 0;
     end;
     return nvl(v_can_segmentos,0);
  END;
  FUNCTION FU_VAL_DEN_IMPAGO (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN VARCHAR2 IS
   CURSOR c_impagos  is
      select t.val_minimo, t.val_maximo cant_impago
       from ba_cod_referencias t
      where dominio = 'RAN_CAN_DIA_CTR_IMPAGOS'
     order by 1 desc;

  v_dia_mor_mes1 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes1%type;
  v_dia_mor_mes2 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes2%type;
  v_dia_mor_mes3 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes3%type;
  v_dia_mor_mes4 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes4%type;
  v_dia_mor_mes5 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes5%type;
  v_dia_mor_mes6 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes6%type;
  v_dia_mor_mes7 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes7%type;
  v_dia_mor_mes8 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes8%type;
  v_dia_mor_mes9 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes9%type;
  v_dia_mor_mes10 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes10%type;
  v_dia_mor_mes11 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes11%type;
  v_dia_mor_mes12 GE_CTA_DIA_MOR_IMPAGOS.Dia_Mor_Mes12%type;
  v_can_impago number;
  v_ind_denegar varchar2(1);

  BEGIN
    -- validación de prestamos por impagos
    begin
      select max(nvl(t.dia_mor_mes1,0)), max(nvl(t.dia_mor_mes2,0)), max(nvl(t.dia_mor_mes3,0)),
             max(nvl(t.dia_mor_mes4,0)), max(nvl(t.dia_mor_mes5,0)), max(nvl(t.dia_mor_mes6,0)),
             max(nvl(t.dia_mor_mes7,0)), max(nvl(t.dia_mor_mes8,0)), max(nvl(t.dia_mor_mes9,0)),
             max(nvl(t.dia_mor_mes10,0)), max(nvl(t.dia_mor_mes11,0)), max(nvl(t.dia_mor_mes12,0))
        into v_dia_mor_mes1,v_dia_mor_mes2, v_dia_mor_mes3,
             v_dia_mor_mes4,v_dia_mor_mes5, v_dia_mor_mes6,
             v_dia_mor_mes7,v_dia_mor_mes8, v_dia_mor_mes9,
             v_dia_mor_mes10,v_dia_mor_mes11, v_dia_mor_mes12
        from GE_CTA_DIA_MOR_IMPAGOS t
       WHERE cod_persona = p_cod_persona;
    exception
      when others then
        v_dia_mor_mes1 := 0;
    end;

    v_can_impago := 0;

    For i in c_impagos Loop
      begin
        select case when v_dia_mor_mes1 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes2 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes3 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes4 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes5 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes6 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes7 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes8 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes9 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes10 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes11 >= i.val_minimo then 1 else 0 end+
               case when v_dia_mor_mes12 >= i.val_minimo then 1 else 0 end
          into v_can_impago
          from dual;
       exception
          when others then
            v_can_impago := 0;
       end;
       if v_can_impago >= i.cant_impago then
          v_ind_denegar := 'S';
       end if;
    end loop;
    return nvl(v_ind_denegar, 'N');
  END;

  -- procedimiento que obtiene la faja de informconf
  PROCEDURE PR_OBT_DAT_ANT_CLIENTES (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                     p_tip_persona in ba_personas.tipo%type,
                                     p_faj_buro out ge_cli_antecedentes.faj_buro%type,
                                     p_sit_infocheck out ge_cli_antecedentes.sit_infocheck%type,
                                     p_val_fec_informconf out varchar2,
                                     p_val_fec_infocheck out varchar2)
  IS
     v_faj_buro ge_cli_antecedentes.faj_buro%type;
     v_fec_con_informconf ge_cli_antecedentes.fec_ult_informconf%type;
     v_fec_con_infocheck ge_cli_antecedentes.fec_ult_infocheck%type;
     v_sit_infocheck ge_cli_antecedentes.sit_infocheck%type;
  BEGIN
     --**Obtener últimas consultas a Informconf e Infocheck**--
      BEGIN
         SELECT fec_ult_informconf, faj_buro, fec_ult_infocheck, sit_infocheck
           INTO v_fec_con_informconf, v_faj_buro, v_fec_con_infocheck, v_sit_infocheck
           FROM ge_cli_antecedentes
          WHERE cod_persona =p_cod_persona;
      EXCEPTION
         WHEN others THEN
            v_fec_con_informconf := null;
            v_fec_con_infocheck  := null;
            v_sit_infocheck      := null;
            v_faj_buro           := null;
      END;
      p_faj_buro := v_faj_buro;
      p_sit_infocheck := v_sit_infocheck;
      --** Validar Informconf
      if p_tip_persona = 'F' then
        IF v_fec_con_informconf IS NULL THEN
           p_val_fec_informconf := 'S';
        ELSIF v_fec_actual - trunc(v_fec_con_informconf) > v_can_dia_val_informconf THEN
           p_val_fec_informconf := 'S';
        ELSIF v_faj_buro IS NULL THEN
           p_val_fec_informconf := 'S';
        ELSIF v_faj_buro IS NOT NULL THEN
           p_val_fec_informconf := 'N';
        END IF;
      else
        p_val_fec_informconf := 'N';
      end if;
      --** Validar Infocheck
      IF v_fec_con_infocheck IS NULL THEN
         p_val_fec_infocheck := 'S';
      ELSIF v_fec_actual - trunc(v_fec_con_infocheck) > v_can_dia_val_infocheck THEN
         p_val_fec_infocheck := 'S';
      ELSIF v_sit_infocheck IS NULL THEN
         p_val_fec_infocheck := 'S';
      ELSIF v_sit_infocheck IS NOT NULL THEN
         p_val_fec_infocheck := 'N';
      END IF;
  END;
  FUNCTION FU_VER_VTA_CARTERA (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN VARCHAR2 IS
     v_exi_vta_cartera varchar2(1);
  BEGIN
     SELECT distinct 'S'
       INTO v_exi_vta_cartera
       FROM ge_sal_act_vta_cartera a
      WHERE a.cod_persona = p_cod_persona
        AND a.saldo > 0;

     RETURN v_exi_vta_cartera;
  EXCEPTION
     WHEN others THEN
        RETURN 'N';
  END;

  FUNCTION FU_VER_PRE_REFINANCIADO (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN NUMBER IS
     v_can_prestamo number;
  BEGIN
     SELECT count(*)
       INTO v_can_prestamo
       FROM pr_cta_prestamos p, ge_cta_clientes c
      WHERE p.nro_cuenta = c.nro_cuenta
        and c.cod_persona = p_cod_persona
        and c.relacion = 'P'
        and p.tip_renovacion in ('R', 'E')
        and p.estado <> 'N'
        and nvl(fug_obt_pardinamico('MAD_EXC_REN_AUT_LIN_SOB',p.cod_modulo, p.cod_modalidad,null,null,p.cod_sub_modalidad),'N') <> 'S';

     RETURN v_can_prestamo;
  EXCEPTION
     WHEN others THEN
        RETURN 0;
  END;

  FUNCTION FU_VER_INCOBRABLES (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN NUMBER IS
     v_can_prestamo number;
  BEGIN
     SELECT count(*)
       INTO v_can_prestamo
       FROM pr_cta_prestamos p, ge_cta_clientes c
      WHERE p.nro_cuenta = c.nro_cuenta
        and c.cod_persona = p_cod_persona
        and c.relacion = 'P'
        and p.estado = 'I';

     RETURN v_can_prestamo;
  EXCEPTION
     WHEN others THEN
        RETURN 0;
  END;


  FUNCTION FU_VER_INH_CANCELACION (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN NUMBER IS
     v_can_inhibicion number;
  BEGIN
    begin
     SELECT count(*)
       INTO v_can_inhibicion
       FROM ge_per_inhibidas p
      WHERE p.cod_persona = p_cod_persona
        and p.estado = 'I'
        and p.cod_causa in(select m.cod_causa
                                           from ge_par_causales m, ge_causales c
                                          where m.cod_causa = c.cod_causa
                                            and c.tipo = 'I'
                                            and m.parametro = 'COD_CAU_INH_CAN_CTA_COM');
    exception
      when others then
        v_can_inhibicion := 0;
    end;

     return nvl(v_can_inhibicion,0);
  END;

 FUNCTION FU_VER_CAN_INH_OTORGAR (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN VARCHAR2 IS
     v_ind_otorgar varchar2(1);
     v_con_otr_inhibido number;
  BEGIN
    begin
       begin
          select count(*)
            into v_con_otr_inhibido
            from ge_per_inhibidas x
           where x.cod_persona = p_cod_persona
             and trunc(x.fec_inicio) between add_months(trunc(v_fec_actual, 'mm'),-12) and v_fec_actual
             and not exists (select 1 from ge_par_causales p
                              where p.cod_causa = x.cod_causa
                                and p.parametro = 'COD_CAU_INH_CAN_CTA_COM'
                                and p.val_parametro = 'S');
        exception
          when others then
            v_con_otr_inhibido := 0;
        end;
    exception
      when others then
        v_con_otr_inhibido := 0;
    end;

    if nvl(v_con_otr_inhibido,0) > 6 then
      v_ind_otorgar := 'N';
    else
      v_ind_otorgar := 'S';
    end if;

     return nvl(v_ind_otorgar,0);
  END;


  FUNCTION FU_VER_PRE_SOLUCION (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN NUMBER IS
     v_can_prestamo number;
  BEGIN
     SELECT count(*)
       INTO v_can_prestamo
       FROM pr_cta_prestamos p, ge_cta_clientes c
      WHERE c.cod_persona = p_cod_persona
        and p.nro_cuenta = c.nro_cuenta
        and p.cod_modalidad = 681 -- Producto Solucion
        and c.relacion = 'P'
        and p.estado <> 'N';

     RETURN v_can_prestamo;
  EXCEPTION
     WHEN others THEN
        RETURN 0;
  END;

  FUNCTION FU_VER_OPE_VENCIDA (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN NUMBER IS
     v_can_prestamo number;
  BEGIN
     SELECT count(*)
       INTO v_can_prestamo
       FROM ov_cta_vencidas p, ge_cta_clientes c
      WHERE p.nro_cuenta = c.nro_cuenta
        and c.cod_persona = p_cod_persona
        and c.relacion = 'P'
        and p.estado <> 'C';

     RETURN v_can_prestamo;
  EXCEPTION
     WHEN others THEN
        RETURN 0;
  END;

  PROCEDURE PR_INS_LIN_SOBREGIRO(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                 P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                 P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE,
                                 P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE) IS
     v_mto_sobregiro cc_lin_sobregiros.monto%type;
     v_nro_sec_padre cc_lin_sobregiros.nro_sec_padre%type;
     v_nro_secuencia cc_lin_sobregiros.nro_cuenta%type;
     v_mto_min_sobregiro cc_lin_sobregiros.monto%type;
     v_mto_max_sobregiro cc_lin_sobregiros.monto%type;
     v_cot_original ge_cotizaciones.val_conversion%type;
     v_cot_destino ge_cotizaciones.val_conversion%type;

  BEGIN
    v_mto_sobregiro := round((p_monto / 3 * v_por_lin_sob)/100);

    begin
      select val_minimo, val_maximo
        into v_mto_min_sobregiro, v_mto_max_sobregiro
        from ba_cod_referencias
       where dominio = 'CCO_RAN_MTO_SOBREGIRO';
    exception
      when others then
        v_mto_min_sobregiro := 1000000;
        v_mto_max_sobregiro := 100000000;
    end;

    if v_mto_sobregiro > v_mto_max_sobregiro then
       v_mto_sobregiro := v_mto_max_sobregiro;
    elsif v_mto_sobregiro < v_mto_min_sobregiro then
       v_mto_sobregiro := v_mto_min_sobregiro;
    end if;

    if P_COD_MONEDA <> v_cod_mon_local THEN
      pag_gen.pr_con_mon_a_moneda(v_cod_mon_local,
                                  p_cod_moneda,
                                  nvl(v_mto_sobregiro, 0),
                                  v_mto_sobregiro,
                                  v_cot_original,
                                  v_cot_destino);
     else
       v_cot_original := null;
       v_cot_destino := null;
     end if;

    BEGIN
            --Traer el Nro. de Secuencia--
      SELECT s_nro_lin_sobregiro.nextval
        INTO v_nro_sec_padre
        FROM dual;
    EXCEPTION
       WHEN no_data_found THEN
         v_nro_secuencia := 1;
       WHEN OTHERS THEN
         raise_application_error(-20034,
                                      'Error al generar secuencia de sobregiro. Persona Nro= ' ||
                                      p_cod_persona || ' ' || SQLERRM);
    END;
    BEGIN
      --v_lugar := '31-Insert CC_LIN_SOBREGIROS';
      INSERT INTO cc_lin_sobregiros
                (nro_cuenta,
                 fec_vencimiento,
                 fec_inicio,
                 nro_secuencia,
                 cod_rub_economico,
                 cod_campana,
                 monto,
                 tipo,
                 cod_persona,
                 cod_moneda,
                 estado,
                 nro_sec_padre,
                 observacion,
                 niv_aprobacion,
                 cotizacion)
              VALUES
                (NULL,
                 v_fec_actual + v_can_dia_sobregiro,
                 v_fec_actual,
                 v_nro_sec_padre,
                 v_cod_sec_economico,
                 v_cam_cta_com_dfl,
                 v_mto_sobregiro,
                 'T',
                 p_cod_persona,
                 p_cod_moneda,
                 'A',
                 NULL,
                 'Proceso de Generación de linea de Sobregiro Automatico para CTA. COMERCIO',
                 7,
                 v_cot_destino);
    EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20035,
                                        'Error al insertar datos en CC_LIN_SOBREGIRO. Documento Nro= SECUENCIA= ' ||
                                        v_nro_sec_padre ||  ' ' || SQLERRM);
    END;
    
    BEGIN
      --v_lugar := '33-Insert CC_LIN_SOB_GARANTIAS';
      INSERT INTO cc_lin_sob_garantias
      (mto_aplicado, nro_secuencia, cod_garantia)
      VALUES
       (v_mto_sobregiro, v_nro_sec_padre, 1);
     EXCEPTION
        WHEN OTHERS THEN
           raise_application_error(-20041, 'Error al insertar datos en CC_LIN_SOB_GARANTIAS. ' || SQLERRM);
     END;

     BEGIN
       --Traer el Nro. de Secuencia--
       SELECT s_nro_lin_sobregiro.nextval
         INTO v_nro_secuencia
         FROM dual;
     EXCEPTION
       WHEN no_data_found THEN
          v_nro_secuencia := 1;
       WHEN OTHERS THEN
          raise_application_error(-20034,'Error al generar secuencia de sobregiro. ' || SQLERRM);
     END;

     BEGIN
            --v_lugar := '32-Insert CC_LIN_SOBREGIROS';
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
            VALUES
              (p_nro_cuenta,
               v_fec_actual + v_can_dia_sobregiro,
               v_fec_actual,
               v_nro_secuencia,
               v_mto_sobregiro,
               'T',
               NULL,
               p_cod_moneda,
               'A',
               v_nro_sec_padre,
               NULL,
               7,
               v_cot_destino);

          EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20036,
                                      'Error al insertar datos en CC_LIN_SOBREGIRO. ' || SQLERRM);
          END;
  EXCEPTION
    WHEN OTHERS THEN
      PR_INS_LOG_LIN_SOB(p_nro_cuenta, p_cod_persona, null , substr(sqlerrm,4000));
  END;

BEGIN
-- Procedimiento de otorgación de líneas de sobregiros para PYMES
  begin
    select val_minimo, val_maximo
      into v_min_pro_com_pos, v_max_pro_com_pos
      from ba_cod_referencias
     where dominio = 'CCO_PRO_COM_POS';
  exception
    when others then
       v_min_pro_com_pos := 5000000;
       v_max_pro_com_pos := 500000000;
  end;

  for c in c_cli_lin_sob loop
    v_cod_per_ctr := c.cod_persona;
    v_ind_gen_lin_sob := 'S';
      -- valida si la persona tiene rubro económico
      if v_ind_gen_lin_sob = 'S' then
        if c.cod_gru_economico is not null then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'El cliente pertenece a un grupo económico.', null);
         end if;
      end if;
      --valida la facturación
      if v_ind_gen_lin_sob = 'S' then
        v_men_val_facturacion := fug_val_dat_fac_cta_com(c.cod_persona);
        if v_men_val_facturacion <> 'OK' then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, v_men_val_facturacion, null);
         end if;
      end if;

      -- valida el segmento de la cuenta
      if v_ind_gen_lin_sob = 'S' then
        if FU_VAL_SEGMENTOS(c.cod_persona) = 0 then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'El segmento de la persona no corresponde a los segmentos de Cuenta Comercio.', null);
         end if;
      end if;

      if v_ind_gen_lin_sob = 'S' then
        if FUG_VER_INHIBICION(c.cod_persona, 6)= 'S' then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'El cliente posee inhibición crediticia en ITGF.', null);
        end if;
      end if;
      -- validación de inhibiciones diferentes a los Cancelados
      if v_ind_gen_lin_sob = 'S' then
        if FU_VER_CAN_INH_OTORGAR(c.cod_persona)= 'N' then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'Persona Inhibida mas de 6 veces.', null);
        end if;
      end if;
      --valida rango de edad
      if v_ind_gen_lin_sob = 'S' and c.tipo = 'F' then
        begin
          select fec_nacimiento
            into v_fec_nacimiento
            from ba_per_fisicas
           where cod_persona = c.cod_persona;
        exception
          when others then
            v_fec_nacimiento := null;
        end;
        if trunc((v_fec_actual- v_Fec_nacimiento)/365) < 18  or trunc((v_fec_actual- v_Fec_nacimiento)/365) > 74  then
           v_ind_gen_lin_sob := 'N';
           PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'Filtro por edad.', null);
        end if;
      end if;
      -- valida cantidad de cheques rechazados IF los último 12 meses, validar en infocheck FABRICA
      if v_ind_gen_lin_sob = 'S' then
        begin
         select count(*)
           into v_can_che_rechazado
           from ge_per_inhibidas i
          where i.cod_persona = c.cod_persona
            and i.cod_causa in (246) -- causa de cheque rechazado IF
            and fec_inicio between trunc(add_months(v_fec_actual, -13), 'MM') and v_fec_actual; -- 150: orden Judicial, 279: demanda judicial
        exception
          when others then
            v_can_che_rechazado := 0;
        end;

        if v_can_che_rechazado > 0 then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'Cliente con inhibición de cheques rechazados IF.', null);
        end if;
      end if;
      --valida que el cliente no tenga causal de inhibición de cancelación
      if v_ind_gen_lin_sob = 'S' then
        if FU_VER_INH_CANCELACION(c.cod_persona) > 0 then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'Inhibición por Cancelación.', null);
        end if;
      end if;
      --valida si tiene venta cartera
      if v_ind_gen_lin_sob = 'S' then
        if FU_VER_VTA_CARTERA(c.cod_persona) = 'S' then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'El cliente posee venta de Cartera.', null);
        end if;
      end if;

      --valida que le cliente no posea un prestamo de refinanciacioón o reestructuración
      if v_ind_gen_lin_sob = 'S' then
        if FU_VER_PRE_REFINANCIADO(c.cod_persona) > 0 then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'El cliente cuenta con un préstamo refinanciado o reestructurado.', null);
        end if;
      end if;

      --valida que le cliente no posea un prestamo incobrable
      if v_ind_gen_lin_sob = 'S' then
        if FU_VER_INCOBRABLES(c.cod_persona) > 0 then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona, 'El cliente cuenta con un Préstamo con estado Incobrable.', null);
        end if;
      end if;

      --valida que le cliente no posea un prestamo solución
      if v_ind_gen_lin_sob = 'S' then
        if FU_VER_PRE_SOLUCION(c.cod_persona) > 0 then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null,c.cod_persona, 'El cliente posee un produccto solución.', null);
        end if;
      end if;

      --valida que le cliente posee operación vencida
      if v_ind_gen_lin_sob = 'S' then
        if FU_VER_OPE_VENCIDA(c.cod_persona) > 0 then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null,c.cod_persona, 'El cliente posee una operación vencida .', null);
        end if;
      end if;

      -- valida si el cliente se encuentra en inforconf e infocheck
     if v_ind_gen_lin_sob = 'S' then
       pr_obt_dat_ant_clientes(c.cod_persona, c.tipo, v_faj_buro, v_sit_infocheck, v_val_fec_informconf, v_val_fec_infocheck);

       if c.tipo = 'F' and v_val_fec_informconf = 'S' then
          v_ind_gen_lin_sob := 'N';
          PR_INS_LOG_LIN_SOB(null,c.cod_persona,'Debe validar los datos de Informconf.', null);
       end if;

       if v_val_fec_infocheck = 'S' then
          v_ind_gen_lin_sob := 'N';
          PR_INS_LOG_LIN_SOB(null,c.cod_persona,'Debe validar los datos de Infocheck.', null);
       end if;

       if c.tipo = 'F' then
          IF v_faj_buro is null then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null,c.cod_persona,'No se encuentra datos en Inforconf.', null);
          elsif v_faj_buro > 'L' THEN
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null, c.cod_persona,'Persona Física con Inforconf mayor a L.', null);
          END IF;
       end if;
       if v_ind_gen_lin_sob = 'S' then
          if v_sit_infocheck = 3 then
              v_ind_gen_lin_sob := 'N';
              PR_INS_LOG_LIN_SOB(null,c.cod_persona, 'Inhabilitación en Infocheck.', null);
          end if;
      end if;
     end if;

      -- validación de calificación de crc
      if v_ind_gen_lin_sob = 'S' then
        begin
          select CASE WHEN(cat_subjetiva >= 2 or cat_automatica >= 2 or cat_sistema >= 2) THEN 'S' ELSE 'N' END CASE
            into v_ind_cat_may_uno
            from ge_clientes
           where cod_persona = c.cod_persona;
        exception
          when others then
            v_ind_cat_may_uno := 'N';
        end;
        if nvl(v_ind_cat_may_uno, 'N') = 'N' then
           select max(nvl(substr(cl.cat_riesgo, 1,1), '0')), max(nvl(substr(cl.cat_subjetiva, 1,1), '0'))
             into v_cat_rie_max, v_cat_sub_max
             from sb_crc_clasificaciones_det cl
            where cl.cod_persona = c.cod_persona
              and cl.fecha >= v_fec_actual -v_can_dia_his_bcp;
            if v_cat_rie_max >= 2 or v_cat_sub_max >= 2 then
               v_ind_cat_may_uno := 'S';
            end if;
        end if;

        if nvl(v_ind_cat_may_uno, 'N') = 'S' then
            v_ind_gen_lin_sob := 'N';
            PR_INS_LOG_LIN_SOB(null,c.cod_persona, 'Cliente con categoria mayor a 1.', null);
        end if;
      end if;
      -- validación de impagos
      if v_ind_gen_lin_sob = 'S' then
        PR_INS_IMPAGOS(c.cod_persona);
        v_ind_den_impago := FU_VAL_DEN_IMPAGO(c.cod_persona);
        if nvl(v_ind_den_impago, 'N') = 'S' then
          v_ind_gen_lin_sob := 'N';
          PR_INS_LOG_LIN_SOB(null,c.cod_persona, 'Denegado por impagos.', null);
        end if;
      end if;
      -- validación ingreso
      if v_ind_gen_lin_sob = 'S' then
        for cu in c_cta_lin_sob(c.cod_persona) loop
           v_mto_ingreso := fug_obt_ing_pos_cta_com(cu.nro_cuenta, v_can_dia_mov_his);
           v_pro_ingreso := v_mto_ingreso/3;
           if nvl(v_pro_ingreso,0) < v_min_pro_com_pos then
             v_ind_gen_lin_sob := 'N';
             PR_INS_LOG_LIN_SOB(cu.nro_cuenta,c.cod_persona, 'No cumple condición de Ingreso.', null);
           end if;
           if v_ind_gen_lin_sob = 'S' then
              begin
                select count(*)
                  into v_can_lin_sobregiros
                  from cc_lin_sobregiros s, cc_lin_sobregiros sd
                 where s.nro_secuencia = sd.nro_sec_padre
                   and s.estado = 'A'
                   and sd.nro_cuenta = cu.nro_cuenta;
              exception
                when others then
                  v_can_lin_sobregiros := 0;
              end;
              if v_can_lin_sobregiros > 0 then
                 v_ind_gen_lin_sob := 'N';
                 PR_INS_LOG_LIN_SOB(cu.nro_cuenta, c.cod_persona, 'La cuenta se encuentra dentro de una linea de sobregiro activa.', null);
              end if;
           end if;
           if v_ind_gen_lin_sob = 'S' then
              pr_ins_lin_sobregiro(c.cod_persona, cu.nro_cuenta, cu.cod_moneda, v_mto_ingreso);
           end if;
        end loop;
     end if;
   end loop;
EXCEPTION
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'Error en el Proceso de Generación de Lin. Sobregiros del cliente: ' || v_cod_per_ctr||'. '|| sqlerrm );
END;
/


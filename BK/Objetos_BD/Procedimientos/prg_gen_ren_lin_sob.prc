CREATE OR REPLACE PROCEDURE IT.PRG_GEN_REN_LIN_SOB
 IS
 v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
 v_fec_proxima ge_calendarios.fec_proxima%type := pag_cal.FU_OBT_FEC_PROXIMA(4);
 v_fec_pro_renovacion  ge_calendarios.fec_proxima%type;
 v_can_dia_ant_ven number := fug_obt_pardinamico('CAN_DIA_ANT_VEN_REN_LINSOB');
 v_cod_campanas ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAM_REN_LIN_SOB');
 v_cod_rub_eco_ren ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_RUB_ECO_REN_LIN_SOB');
 v_cam_cta_comercio ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAM_CTA_COMERCIO');
 v_cam_cta_com_dfl ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAM_CTA_COM_DEFAULT');
 v_cod_sec_economico ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_COD_SEC_ECONOMICO');
 v_mon_max_lin_sob cc_lin_sobregiros.monto%type := fug_obt_pardinamico('MTO_MAX_LIN_SOB_RAN_EDA');
 v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
 v_can_dia_sobregiro ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAN_DIA_SOBREGIRO');
 v_min_pro_com_pos ba_cod_referencias.val_minimo%type;
 v_max_pro_com_pos ba_cod_referencias.val_maximo%type;
 v_mto_ingreso ge_movimientos.monto%type;
 v_cot_original ge_cotizaciones.val_conversion%type;
 v_cot_destino ge_cotizaciones.val_conversion%type;
 v_mto_min_sobregiro ba_cod_referencias.val_minimo%type;
 v_mto_max_sobregiro ba_cod_referencias.val_maximo%type;
 v_can_dia_mov_his number := nvl(fug_obt_pardinamico('CCO_CAN_DIA_MOV_HIS'),90);
 v_can_sin_mov_his number := nvl(fug_obt_pardinamico('CCO_CAN_DIA_SIN_MOV_CAN'),30);
 v_fec_origen date;
 v_can_dia_val_informconf number := nvl(fug_obt_pardinamico('CCO_CAN_DIA_VAL_INFORMCONF'), 30);
 v_can_dia_val_infocheck number := nvl(fug_obt_pardinamico('CCO_CAN_DIA_VAL_INFOCHECK'), 30);
 v_val_fec_informconf varchar2(1);
 v_val_fec_infocheck varchar2(1);
 v_eda_minima number;
 v_eda_maxima number;
 CURSOR c_lin_sobregiros (p_fec_proxima date) is
     --Lineas de sobregiro por Pre aprobado
     select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica,
            l.monto, l.cod_moneda, decode(l.cod_moneda, v_cod_mon_local, l.monto, pal_cam.FU_CON_MON_A_MONEDA(l.cod_moneda,v_cod_mon_local, l.monto)) monto_gs,
            'P' tipo, p.tipo tip_persona, l.cod_campana
       from cc_lin_sobregiros l, ge_clientes c, ba_personas p
      where l.fec_vencimiento between v_fec_actual and p_fec_proxima
        and l.nro_sec_padre is null
        and l.tipo = 'T'
        and l.estado = 'A'
        and ( ( instr(','|| v_cod_campanas ||',' ,  ','||l.cod_campana||',') > 0 )
              and v_cod_campanas is not null )
        and l.cod_persona = c.cod_persona
        and c.cod_persona = p.cod_persona
        and p.tipo = 'F'
        and not exists  (select 1
                          from ba_tab_dat_adicionales d
                         where d.tab_relacion = 'CC_LIN_SOBREGIROS'
                           and d.referencia = l.nro_secuencia
                           and d.parametro = 'RENOVAR'
                           and d.val_parametro = 'N')
    union all
    --lineas de sobregiro por Cuenta Comercio
    select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica,
           l.monto, l.cod_moneda, decode(l.cod_moneda, v_cod_mon_local, l.monto, pal_cam.FU_CON_MON_A_MONEDA(l.cod_moneda,v_cod_mon_Local, l.monto)) monto_gs,
           'C' tipo, p.tipo tip_persona, l.cod_campana
       from cc_lin_sobregiros l, ge_clientes c, ba_personas p
      where l.fec_vencimiento between v_fec_actual and p_fec_proxima
        and l.nro_sec_padre is null
        and l.tipo = 'T'
        and l.estado = 'A'
        and ( ( instr(','|| v_cam_cta_comercio ||',' ,  ','||cod_campana||',') > 0 )
            and v_cam_cta_comercio is not null )
        and l.cod_persona = c.cod_persona
        and c.cod_persona = p.cod_persona
        and ( instr(','|| v_cod_rub_eco_ren ||',' ,  ','||l.cod_rub_economico||',') = 0
            and  v_cod_rub_eco_ren is not null )
        and exists (select 1
                      from cc_lin_sobregiros ls, cc_cta_corrientes cc
                     where ls.nro_sec_padre = l.nro_secuencia
                        and ls.nro_cuenta = cc.nro_cuenta
                        and cc.estado = 'N');

 CURSOR c_lin_ver_sob is
     select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica, l.nro_linea,
            'P' tipo
       from cc_lin_sobregiros l, ge_clientes c, ba_personas p
      where l.nro_sec_padre is null
        and l.estado = 'A'
        and l.tipo = 'T'
        and l.cod_persona = c.cod_persona
        and c.cod_persona = p.cod_persona
        and p.tipo = 'F'
        and instr(','|| v_cod_campanas ||',' ,  ','||l.cod_campana||',') > 0
        and not exists  (select 1
                          from ba_tab_dat_adicionales d
                         where d.tab_relacion = 'CC_LIN_SOBREGIROS'
                           and d.referencia = l.nro_secuencia
                           and d.parametro = 'RENOVAR'
                           and d.val_parametro = 'N');


 CURSOR c_can_lin_sobregiros is
     -- control de categoria y rango de edad en pre_aprobados
     select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica, l.nro_linea,
            CASE WHEN(c.cat_subjetiva >= 2 or c.cat_automatica >= 2 or c.cat_sistema >= 2) THEN 'Categor¿a mayor a 1.'
              ELSE 'Edad menor  a 18.' END motivo
       from cc_lin_sobregiros l, ge_clientes c, ba_per_fisicas f
      where l.nro_sec_padre is null
        and l.estado = 'A'
        and l.tipo = 'T'
        and l.cod_persona = c.cod_persona
        and c.cod_persona = f.cod_persona
        and ((c.cat_automatica >= 2 or c.cat_subjetiva >= 2 or c.cat_sistema >= 2 ) or
            (trunc((v_fec_actual- F.Fec_nacimiento)/365) < 18 ))
        and instr(','|| v_cod_campanas ||',' ,  ','||l.cod_campana||',') > 0
        and instr(','|| v_cod_rub_eco_ren ||',' ,  ','||l.cod_rub_economico||',') > 0
     union all
     -- control de categoria en cuenta comercio
     select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica, l.nro_linea,
            CASE WHEN(c.cat_subjetiva >= 2 or c.cat_automatica >= 2 or c.cat_sistema >= 2) THEN 'Categor¿a mayor a 1.' END motivo
       from cc_lin_sobregiros l, ge_clientes c, ba_personas p
       where l.nro_sec_padre is null
        and l.tipo = 'T'
        and l.estado = 'A'
        and instr(','|| v_cam_cta_comercio ||',' ,  ','||cod_campana||',') > 0
        and l.cod_persona = c.cod_persona
        and c.cod_persona = p.cod_persona
        and ((c.cat_automatica >= 2 or c.cat_subjetiva >= 2 or c.cat_sistema >= 2 ))
    union all
     -- valida rando de edad para sobregiros de cuenta comercio
     select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica, l.nro_linea,
            'Fuera de Rango de Edad.'
       from cc_lin_sobregiros l, ge_clientes c, ba_per_fisicas f
       where l.nro_sec_padre is null
        and l.tipo = 'T'
        and l.estado = 'A'
        and instr(','|| v_cam_cta_comercio ||',' ,  ','||cod_campana||',') > 0
        and l.cod_persona = c.cod_persona
        and c.cod_persona = f.cod_persona
        and ((trunc((v_fec_actual- F.Fec_nacimiento)/365) < 18 ) or
            (trunc((v_fec_actual- f.Fec_nacimiento)/365) > 74 ))

    union all
      select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona,0, l.nro_linea,
            'No es Cuenta Comercio.'
       from cc_lin_sobregiros l, cc_lin_sobregiros ls, ge_cta_dat_adicionales t
       where l.nro_sec_padre is null
        and l.tipo = 'T'
        and l.estado = 'A'
        and instr(','|| v_cam_cta_comercio ||',' ,  ','||l.cod_campana||',') > 0
        and ls.nro_sec_padre = l.nro_secuencia
        and ls.nro_cuenta = t.nro_cuenta
        and t.parametro = 'IND_CTA_COMERCIO'
        and t.val_parametro = 'N'
    union
    -- validaci¿n de impagos de pre aprobados y cuenta comercio
    select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica, l.nro_linea,
           'Impagos'
      from GE_CTA_DIA_MOR_IMPAGOS t, cc_lin_sobregiros l, ge_clientes c,
           (select min(val_minimo) can_dias from ba_cod_referencias
             where dominio = 'RAN_CAN_DIA_CTR_IMPAGOS'
               and significado = 'CANCELAR') di
     where t.nro_lin_sobregiro = l.nro_secuencia
       and l.cod_persona = c.cod_persona
       and l.estado = 'A'
       and l.tipo = 'T'
       and (t.dia_mor_mes1 >= di.can_dias or t.dia_mor_mes2 >= di.can_dias or t.dia_mor_mes3 >= di.can_dias or
            t.dia_mor_mes4 >= di.can_dias or t.dia_mor_mes5 >= di.can_dias or t.dia_mor_mes6 >= di.can_dias or
            t.dia_mor_mes7 >= di.can_dias or t.dia_mor_mes8 >= di.can_dias or t.dia_mor_mes9 >= di.can_dias or
            t.dia_mor_mes10 >= di.can_dias or t.dia_mor_mes11 >= di.can_dias or t.dia_mor_mes12 >= di.can_dias)
       and ((instr(','|| v_cod_campanas ||',' ,  ','||l.cod_campana||',') > 0
           and instr(','|| v_cod_rub_eco_ren ||',' ,  ','||l.cod_rub_economico||',') > 0) or
           (instr(','|| v_cam_cta_comercio ||',' ,  ','||l.cod_campana||',') > 0))
       and not exists (select 1
                         from cc_lin_sobregiros ls, cc_cta_corrientes cc
                        where ls.nro_sec_padre = l.nro_secuencia
                          and ls.nro_cuenta = cc.nro_cuenta
                          and cc.cod_ente is not null)
    union
    -- Linea de sobregiro pre aprobado cancelado por inhibici¿n
    select l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, c.cat_automatica, l.nro_linea,
           'Persona Inhibida.'
      from cc_lin_sobregiros l, ge_clientes c
     where l.cod_persona = c.cod_persona
       and l.estado = 'A'
       and l.tipo = 'T'
       and ((exists (select 1
                     from ge_per_inhibidas x
                    where x.cod_persona = c.cod_persona
                      and x.estado = 'I'
                      and x.cod_causa in(select m.cod_causa
                                           from ge_par_causales m, ge_causales c
                                          where m.cod_causa = c.cod_causa
                                            and c.tipo = 'I'
                                            and m.parametro = 'COD_CAU_INH_CAN_LIN_SOB'))
             and instr(','|| v_cod_campanas ||',' ,  ','||l.cod_campana||',') > 0
             and instr(','|| v_cod_rub_eco_ren ||',' ,  ','||l.cod_rub_economico||',') > 0) OR
           (exists (select 1
                     from ge_per_inhibidas x
                    where x.cod_persona = c.cod_persona
                      and x.estado = 'I'
                      and x.cod_causa in(select m.cod_causa
                                           from ge_par_causales m, ge_causales c
                                          where m.cod_causa = c.cod_causa
                                            and c.tipo = 'I'
                                            and m.parametro = 'COD_CAU_INH_CAN_CTA_COM'))
             and instr(','|| v_cam_cta_comercio ||',' ,  ','||l.cod_campana||',') > 0))
    union all
    select distinct l.nro_secuencia, l.fec_inicio, l.fec_vencimiento, l.cod_persona, 0, l.nro_linea,
         'Persona sin ingreso de pos en un mes.' motivo
    from cc_lin_sobregiros l, cc_lin_sobregiros d
   where l.nro_secuencia = d.nro_sec_padre
     and instr(','|| v_cam_cta_comercio ||',' ,  ','||l.cod_campana||',') > 0
     and l.estado = 'A'
     and not exists (select 1
                      from cc_movimientos_his a, ge_transacciones t, ge_gru_transacciones_det d
                      where a.nro_cuenta = d.nro_cuenta
                      and a.fecha >= trunc(v_fec_actual-v_can_sin_mov_his)
                      and d.cod_gru_transaccion = 90
                      and a.cod_mod_padre = d.cod_modulo
                      and a.cod_mad_padre = d.cod_modalidad
                      and a.cod_tra_padre = d.cod_transaccion
                      and a.cod_modulo = t.cod_modulo
                      and a.cod_modalidad = t.cod_modalidad
                      and a.cod_transaccion = t.cod_transaccion
                      and t.tipo = 'C'
                      and a.reversado = 'N');


  CURSOR c_imp_no_renovacion  is
     select t.val_minimo, t.val_maximo cant_impago
       from ba_cod_referencias t
      where dominio = 'RAN_CAN_DIA_CTR_IMPAGOS'
        and significado = 'NO RENOVAR'
     order by 1 desc;
   -- DETALLE DE LINEA

  cursor c_lin_sob_det(p_nro_lin_sobregiro cc_lin_sobregiros.monto%type) is
    select nro_cuenta, cod_moneda, monto,
           decode(cod_moneda, v_cod_mon_local, monto, pal_cam.FU_CON_MON_A_MONEDA(cod_moneda,v_cod_mon_local, monto)) monto_gs
      from cc_lin_sobregiros
     where nro_sec_padre = p_nro_lin_sobregiro;


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
  v_renovar varchar2(1);

  PROCEDURE PP_ACT_MOT_NORENOVACION(p_nro_lin_sobregiro cc_lin_sobregiros.nro_secuencia%type,
                                    p_motivo varchar2) IS
   BEGIN
     begin
       insert into ba_tab_dat_adicionales ( tab_relacion,
                                            referencia,
                                            parametro,
                                            val_parametro)
                                   values ( 'CC_LIN_SOBREGIROS',
                                             p_nro_lin_sobregiro,
                                             'RENOVAR',
                                             'N');
     exception
        when others then
           begin
              update ba_tab_dat_adicionales
                 set val_parametro = 'N'
               where tab_relacion = 'CC_LIN_SOBREGIROS'
                 and parametro = 'RENOVAR'
                 and referencia = p_nro_lin_sobregiro;
            exception
              when others then
                RAISE_APPLICATION_ERROR( -20000, 'Error al insertar el campo de Renovar.: '||p_nro_lin_sobregiro||'. '||sqlerrm );
            end;
     end;
     begin
        insert into ba_tab_dat_adicionales ( tab_relacion,
                                             referencia,
                                             parametro,
                                             val_parametro)
                                   values ( 'CC_LIN_SOBREGIROS',
                                             p_nro_lin_sobregiro,
                                             'DES_MOT_NO_RENOVACION',
                                             p_motivo);
      exception
        when others then
          begin
            update ba_tab_dat_adicionales
               set val_parametro = p_motivo
             where tab_relacion = 'CC_LIN_SOBREGIROS'
               and parametro = 'DES_MOT_NO_RENOVACION'
               and referencia = p_nro_lin_sobregiro;
          exception
            when others then
               RAISE_APPLICATION_ERROR( -20000, 'Error al insertar el campo de Renovar.: '||p_nro_lin_sobregiro||'. '||sqlerrm );
          end;
      end;
      begin
        insert into ba_tab_dat_adicionales ( tab_relacion,
                                             referencia,
                                             parametro,
                                             val_parametro)
                                    values ( 'CC_LIN_SOBREGIROS',
                                              p_nro_lin_sobregiro,
                                              'FEC_NO_RENOVACION',
                                              to_char(v_fec_actual,'dd/mm/yyyy'));
      exception
        when others then
          begin
            update ba_tab_dat_adicionales
               set val_parametro = to_char(v_fec_actual,'dd/mm/yyyy')
             where tab_relacion = 'CC_LIN_SOBREGIROS'
               and parametro = 'FEC_NO_RENOVACION'
               and referencia = p_nro_lin_sobregiro;
        exception
          when others then
            RAISE_APPLICATION_ERROR( -20000, 'Error al insertar el campo de Renovar.: '||p_nro_lin_sobregiro||'. '||sqlerrm );
        end;
      end;
  end;

  FUNCTION FP_RENOVAR(p_cod_persona IN VARCHAR2, p_nro_lin_sobregiro IN NUMBER, p_tipo varchar2) RETURN VARCHAR IS
      v_ind_renovar varchar2(1) := 'S';
      v_con_otr_inhibido number;
      v_motivo varchar2(400);
      v_eda_norenovacion number;
      v_cod_rub_economico cc_lin_sobregiros.cod_rub_economico%type;
      v_fec_vencimiento cc_lin_sobregiros.fec_vencimiento%type;
      v_par_cancelacion ge_par_dinamicos.parametro%type;
      v_tie_inh_cre varchar2(1);
      v_faj_buro ge_cli_antecedentes.faj_buro%type;
      v_sit_infocheck ge_cli_antecedentes.sit_infocheck%type;
      v_tip_persona ba_personas.tipo%type;
      v_cod_gru_economico ge_clientes.cod_gru_economico%type;
      v_can_che_rechazado number;
      v_men_facturacion varchar2(4000);
      v_can_detalle number;

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
         --**Obtener ¿ltimas consultas a Informconf e Infocheck**--
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

     -- Procedimiento interno que valida si el cliente tiene venta cartera
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

     -- Verificaci¿n de Prestamo refinanciado
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

     FUNCTION FU_VER_PRE_SOLUCION (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE ) RETURN NUMBER IS
         v_can_prestamo number;
     BEGIN
         SELECT count(*)
           INTO v_can_prestamo
           FROM pr_cta_prestamos p, ge_cta_clientes c
          WHERE p.nro_cuenta = c.nro_cuenta
            and c.cod_persona = p_cod_persona
            and c.relacion = 'P'
            and p.cod_modalidad = 681 -- Producto Solucion
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

   BEGIN
     --Validaciones de Renovaci¿n de L¿neas de Sobregiro
      v_motivo := null;
      begin
        select count(*)
          into v_can_detalle
          from cc_lin_sobregiros
         where nro_sec_padre = p_nro_lin_sobregiro;
      exception
         when others then
           v_can_detalle := 0;
      end;

      if v_can_detalle > 1 then
         v_ind_renovar := 'N';
         v_motivo := 'Linea de Sobregiro con m¿s de una cuenta. No se puede realizar los controles de monto.';
      end if;

      begin
        select l.cod_rub_economico, fec_vencimiento
          into v_cod_rub_economico, v_fec_vencimiento
          from cc_lin_sobregiros l
         where l.nro_secuencia = p_nro_lin_sobregiro;
      exception
        when others then
         null;
      end;


      if v_ind_renovar = 'S' then
        if p_tipo = 'C' then
          v_par_cancelacion := 'COD_CAU_INH_CAN_CTA_COM';
        else
          v_par_cancelacion := 'COD_CAU_INH_CAN_LIN_SOB';
        end if;

        begin
          select count(*)
            into v_con_otr_inhibido
            from ge_per_inhibidas x
           where x.cod_persona = p_cod_persona
             and trunc(x.fec_inicio) between add_months(trunc(v_fec_actual, 'mm'),-12) and v_fec_actual
             and not exists (select 1 from ge_par_causales p
                              where p.cod_causa = x.cod_causa
                                and p.parametro = v_par_cancelacion
                                and p.val_parametro = 'S');
        exception
          when others then
            v_con_otr_inhibido := 0 ;
        end;

        if nvl(v_con_otr_inhibido, 0) > 6 then
          v_motivo:= 'Persona Inhibida mas de 6 veces.';
          v_ind_renovar := 'N';
        end if;
      end if;

      if nvl(v_ind_renovar, 'S') = 'S' then
         if p_tipo = 'P' then
           if instr(','|| v_cod_rub_eco_ren ||',' ,  ','||v_cod_rub_economico||',') = 0 then
              v_ind_renovar := 'N';
              v_motivo := 'No corresponde a un Rubro Econ¿mico de Consumo.'||v_cod_rub_economico;
           end if;
         else
           if instr(','|| v_cod_rub_eco_ren ||',' ,  ','||v_cod_rub_economico||',') > 0 then
              v_ind_renovar := 'N';
              v_motivo := 'Corresponde a un Rubro Econ¿mico de Consumo.'||v_cod_rub_economico;
           end if;
         end if;
      end if;


      if nvl(v_ind_renovar, 'S') = 'S' then
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
            WHERE t.nro_lin_sobregiro = p_nro_lin_sobregiro ;
         exception
           when others then
             v_dia_mor_mes1 := 0;
         end;

         v_can_impago := 0;

         For i in c_imp_no_renovacion Loop
          if nvl(v_ind_renovar,'S') = 'S' then
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
              v_motivo := 'No renovado por Impagos.';
              v_ind_renovar := 'N';
           end if;
         end if;
        end loop;
      end if;
      if nvl(v_ind_renovar, 'S') = 'S' and p_tipo <> 'C' then -- en caso de cuenta comercio se cancela
          begin
            select trunc((trunc(v_fec_actual)- Fec_nacimiento)/365)
              into v_eda_norenovacion
              from ba_per_fisicas
             where cod_persona = p_cod_persona;
          exception
            when others then
              v_eda_norenovacion := 0;
          end;

          if v_eda_norenovacion >= 74 then
            v_motivo := 'No renovado por Edad mayor o igual a 74.';
            v_ind_renovar := 'N';
          end if;
      end if;
      --valida que le cliente no posea un prestamo de refinanciacio¿n o reestructuraci¿n
      if v_ind_renovar = 'S' then
        if FU_VER_PRE_REFINANCIADO(p_cod_persona) > 0 then
          v_ind_renovar := 'N';
          v_motivo := 'El cliente cuenta con un pr¿stamo refinanciado o reestructurado.';
        end if;
      end if;
      -- validaciones exclusivas de Cuenta comercio
      if p_tipo = 'C' then
         begin
           select tipo
             into v_tip_persona
             from ba_personas
            where cod_persona = p_cod_persona;
         exception
           when others then
             v_tip_persona := 'X';
         end;

         if v_ind_renovar = 'S' then
           begin
             select cod_gru_economico
               into v_cod_gru_economico
               from ge_clientes
              where cod_persona = p_cod_persona;
           exception
             when others then
               v_cod_gru_economico := null;
           end;
           if v_cod_gru_economico is not null then
              v_ind_renovar := 'N';
              v_motivo := 'El cliente pertenece a un grupo econ¿mico.';
           end if;
         end if;
         -- valida el segmento de la cuenta
         if v_ind_renovar = 'S' then
            if FU_VAL_SEGMENTOS(p_cod_persona) = 0 then
               v_ind_renovar := 'N';
               v_motivo := 'El segmento de la persona no corresponde a los segmentos de Cuenta Comercio.';
            end if;
         end if;

         -- verificaci¿n inhibici¿n crediticia
         if v_ind_renovar = 'S' then
            v_tie_inh_cre := FUG_VER_INHIBICION(p_cod_persona, 6);

            if v_tie_inh_cre = 'S' then
               v_ind_renovar := 'N';
               v_motivo := 'El cliente posee inhibici¿n crediticia en ITGF.';
            end if;
         end if;

         if v_ind_renovar = 'S' then
           begin
             select count(*)
               into v_can_che_rechazado
               from ge_per_inhibidas i
              where i.cod_persona = p_cod_persona
                and i.cod_causa in (246) -- causa de cheque rechazado IF
                and fec_inicio between trunc(add_months(v_fec_actual, -13), 'MM') and v_fec_actual; -- 150: orden Judicial, 279: demanda judicial
           exception
            when others then
              v_can_che_rechazado := 0;
           end;

           if v_can_che_rechazado > 0 then
              v_ind_renovar := 'N';
              v_motivo := 'Cliente con inhibici¿n de cheques rechazados IF.';
           end if;
         end if;
         -- verificaci¿n venta cartera
         if v_ind_renovar = 'S' then
            if FU_VER_VTA_CARTERA(p_cod_persona) = 'S' then
               v_ind_renovar := 'N';
               v_motivo := 'El cliente posee venta de Cartera.';
            end if;
         end if;

          --valida que le cliente no posea un prestamo incobrable
          if v_ind_renovar = 'S' then
            if FU_VER_INCOBRABLES(p_cod_persona) > 0 then
               v_ind_renovar := 'N';
               v_motivo :=  'El cliente cuenta con un Pr¿stamo con estado Incobrable.';
            end if;
          end if;

          --valida que le cliente no posea un prestamo de producto soluci¿n
          if v_ind_renovar = 'S' then
            if FU_VER_PRE_SOLUCION(p_cod_persona) > 0 then
               v_ind_renovar := 'N';
               v_motivo := 'El cliente posee un produccto soluci¿n.';
            end if;
          end if;

          --valida que le cliente no posea una operaci¿n vencida
          if v_ind_renovar = 'S' then
            if FU_VER_OPE_VENCIDA(p_cod_persona) > 0 then
               v_ind_renovar := 'N';
               v_motivo := 'El cliente posee una operaci¿n vencida .';
            end if;
          end if;

          -- valida si el cliente se encuentra en inforconf e infocheck
          if v_ind_renovar = 'S' then
             pr_obt_dat_ant_clientes(p_cod_persona, v_tip_persona, v_faj_buro, v_sit_infocheck, v_val_fec_informconf, v_val_fec_infocheck);

             if v_tip_persona = 'F' and v_val_fec_informconf = 'S' then
                v_ind_renovar := 'N';
                v_motivo := 'Debe validar los datos de Informconf.';
             end if;

             if v_val_fec_infocheck = 'S' then
                v_ind_renovar := 'N';
                v_motivo := 'Debe validar los datos de Infocheck.';
             end if;

             if v_tip_persona = 'F' then
                IF v_faj_buro is null then
                   v_ind_renovar := 'N';
                   v_motivo := 'No se encuentra datos en Inforconf.';
                elsif v_faj_buro > 'L' THEN
                   v_ind_renovar := 'N';
                   v_motivo := 'Persona F¿sica con Inforconf mayor a L.';
                END IF;
             end if;
             if v_ind_renovar = 'S' then
                if v_sit_infocheck = 3 then
                   v_ind_renovar := 'N';
                   v_motivo := 'Inhabilitaci¿n en Infocheck.';
                end if;
            end if;
         end if;
         if v_ind_renovar = 'S' then
            v_men_facturacion := fug_val_dat_fac_cta_com(p_cod_persona);
            if v_men_facturacion <> 'OK' then
               v_ind_renovar := 'N';
               v_motivo := v_men_facturacion;
            end if;
         end if;
      end if;
      if v_ind_renovar = 'N' then
         pp_act_mot_norenovacion(p_nro_lin_sobregiro, v_motivo);
      end if;
      return nvl(v_ind_renovar, 'S');
   EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR( -20000, 'Error al validar la renovacion. Nro de L¿nea de Sobregiro: '||p_nro_lin_sobregiro||'. '||sqlerrm );
   END;


   PROCEDURE PP_DEL_REG_IMPAGO(p_nro_lin_sobregiro IN NUMBER) IS
   BEGIN
     BEGIN
       insert into GE_CTA_DIA_MOR_IMPAGOS_HIS
         (fecha, cod_modulo, cod_modalidad, nro_cuenta, cod_persona,
          nro_lin_sobregiro, fec_inicio, fec_vencimiento,
          dia_mor_mes1, dia_mor_mes2, dia_mor_mes3, dia_mor_mes4,
          dia_mor_mes5, dia_mor_mes6, dia_mor_mes7, dia_mor_mes8,
          dia_mor_mes9, dia_mor_mes10, dia_mor_mes11, dia_mor_mes12)

         (select v_fec_actual, m.cod_modulo, m.cod_modalidad, m.nro_cuenta, m.cod_persona,
                 m.nro_lin_sobregiro, m.fec_inicio, m.fec_vencimiento,
                 m.dia_mor_mes1, m.dia_mor_mes2, m.dia_mor_mes3, m.dia_mor_mes4,
                 m.dia_mor_mes5, m.dia_mor_mes6, m.dia_mor_mes7, m.dia_mor_mes8,
                 m.dia_mor_mes9, m.dia_mor_mes10, m.dia_mor_mes11, m.dia_mor_mes12
            from GE_CTA_DIA_MOR_IMPAGOS m
           where nro_lin_sobregiro = p_nro_lin_sobregiro);
     exception
       when others then
          RAISE_APPLICATION_ERROR( -20000, 'No se ha podido insertar el hist¿rico de impagos: '||p_nro_lin_sobregiro ||'. '|| sqlerrm );
     end;

     BEGIN
       delete GE_CTA_DIA_MOR_IMPAGOS
        where nro_lin_sobregiro = p_nro_lin_sobregiro;
     EXCEPTION
       when others then
          RAISE_APPLICATION_ERROR( -20000, 'No se ha podido eliminar el registro de impagos: '||p_nro_lin_sobregiro ||'. '|| sqlerrm );
     end;
   END;
   PROCEDURE PP_REN_LIN_SOBREGIRO(P_NRO_SEC_PADRE IN CC_LIN_SOBREGIROS.NRO_SECUENCIA%TYPE,
                                  P_FEC_INICIO IN CC_LIN_SOBREGIROS.FEC_INICIO%TYPE,
                                  P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE,
                                  P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,
                                  P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE DEFAULT NULL,
                                  P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE,
                                  P_TIPO IN VARCHAR2,
                                  P_COD_CAMPANA IN VARCHAR2 DEFAULT NULL) IS
     v_mto_sobregiro cc_lin_sobregiros.monto%type;
     v_nro_sec_padre cc_lin_sobregiros.nro_sec_padre%type;
     v_nro_secuencia cc_lin_sobregiros.nro_cuenta%type;
     v_mto_min_sobregiro cc_lin_sobregiros.monto%type;
     v_mto_max_sobregiro cc_lin_sobregiros.monto%type;
     v_cot_original ge_cotizaciones.val_conversion%type;
     v_cot_destino ge_cotizaciones.val_conversion%type;
     v_por_lin_sob number := nvl(fug_obt_pardinamico('CCO_POR_ING_POS_CTA_COM'), 20);
   BEGIN
     IF P_tipo = 'P' THEN
        begin
          update cc_lin_sobregiros
             set fec_inicio = v_fec_actual,
                 fec_vencimiento = v_fec_actual + 364,
                 monto = p_monto
           where nro_secuencia = p_nro_sec_padre;
        exception
          when others then
            RAISE_APPLICATION_ERROR( -20000, 'No se ha podido renovar la cabecera de la l¿nea de Sobregiro: '|| p_nro_sec_padre||'. ' || sqlerrm );
        end;
        begin
          update cc_lin_sobregiros
             set fec_inicio = v_fec_actual,
                 fec_vencimiento = v_fec_actual + 364
           where nro_sec_padre = p_nro_sec_padre;
        exception
           when others then
             RAISE_APPLICATION_ERROR( -20000, 'No se ha podido renovar el detalle de la l¿nea de Sobregiro: '|| p_nro_sec_padre||'. ' || sqlerrm );
        end;

        begin
          select to_date(val_parametro, 'DD/MM/YYYY')
            into v_fec_origen
            from ba_tab_dat_adicionales t
           where t.tab_relacion = 'CC_LIN_SOBREGIROS'
             and t.referencia = p_nro_sec_padre
             and t.parametro = 'FEC_ORIGEN';
        exception
          when no_data_found then
            BEGIN
               insert into ba_tab_dat_adicionales ( tab_relacion,
                                                    referencia,
                                                    parametro,
                                                    val_parametro)
                                           values ( 'CC_LIN_SOBREGIROS',
                                                     p_nro_sec_padre,
                                                     'FEC_ORIGEN',
                                                     to_char(p_fec_inicio, 'DD/MM/YYYY'));
            EXCEPTION
              WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR( -20000, 'No se puede actualizar la fecha de origen de la L¿nea de Sobregiro: '|| p_nro_sec_padre||'. ' ||sqlerrm );
            END;
          when others then
            RAISE_APPLICATION_ERROR( -20000, 'Error al buscar la fecha de origen de la L¿nea de Sobregiro: '|| p_nro_sec_padre||'. ' || sqlerrm );
        end;
     ELSE
       v_mto_sobregiro := p_monto;
       BEGIN
         update cc_lin_sobregiros a
            set a.estado = 'C',
                a.observacion = a.observacion||'* -Cancelado por el Proceso Autom¿tico de Renovaci¿n. Motivo: Se gener¿ una nueva Linea por Cuenta comercio.'
          where (a.nro_secuencia = P_NRO_SEC_PADRE
                or a.nro_sec_padre = P_NRO_SEC_PADRE); --DYDMR-8738 - Incidencia SAU - ITGF - Inconveniente Sobregiro Cancelada
       EXCEPTION
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR( -20000, 'No se ha podido Cancelar la l¿nea de sobrigiro Nro.: '||P_NRO_SEC_PADRE||'. '||sqlerrm );
       END;

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
                 nvl(p_cod_campana,v_cam_cta_com_dfl),
                 v_mto_sobregiro,
                 'T',
                 p_cod_persona,
                 p_cod_moneda,
                 'A',
                 NULL,
                 'Proceso de Renovaci¿n de linea de Sobregiro Automatico para CTA. COMERCIO',
                 7,
                 v_cot_destino);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20035,'Error al insertar datos en CC_LIN_SOBREGIRO. Documento Nro= SECUENCIA= ' ||
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
            raise_application_error(-20036, 'Error al insertar datos en CC_LIN_SOBREGIRO. ' || SQLERRM);
        END;
     END IF;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
BEGIN
  v_fec_pro_renovacion := v_fec_actual + nvl(v_can_dia_ant_ven, 0);
  if v_fec_pro_renovacion < v_fec_proxima then
     v_fec_pro_renovacion := v_fec_proxima;
  end if;

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
  begin
    select min(val_minimo), max(val_maximo)
      into v_eda_minima, v_eda_maxima
      from ba_cod_referencias r
     where r.dominio = 'RAN_EDA_CTR_REN';
  exception
    when others then
      v_eda_minima := 0;
      v_eda_maxima := 0;
  end;
  --CANCELACION DE LINEAS DE SOBREGIRO
  For c in c_can_lin_sobregiros Loop

    BEGIN
      update cc_lin_sobregiros a
         set a.estado = 'C',
             a.observacion = a.observacion||'* -Cancelado por el Proceso Autom¿tico de Renovaci¿n. Motivo: '||c.motivo
       where (a.nro_secuencia = c.nro_secuencia
             or a.nro_sec_padre = c.nro_secuencia); --DYDMR-8738 - Incidencia SAU - ITGF - Inconveniente Sobregiro Cancelada
    EXCEPTION
      WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR( -20000, 'No se ha podido Cancelar la l¿nea de sobrigiro Nro.: '||c.nro_secuencia||'. '||sqlerrm );
    END;

    begin
      insert into ba_tab_dat_adicionales ( tab_relacion,
                                           referencia,
                                           parametro,
                                           val_parametro)
                                  values ( 'CC_LIN_SOBREGIROS',
                                           c.nro_secuencia,
                                           'DES_MOT_NO_RENOVACION',
                                           'Cancelado por el Proceso Autom¿tico de Renovaci¿n. Motivo: '||c.motivo);
    exception
      when others then
        begin
          update ba_tab_dat_adicionales
             set val_parametro = 'Cancelado por el Proceso Autom¿tico de Renovaci¿n. Motivo: '||c.motivo
           where tab_relacion = 'CC_LIN_SOBREGIROS'
             and parametro = 'DES_MOT_NO_RENOVACION'
             and referencia = c.nro_secuencia;
        exception
          when others then
            RAISE_APPLICATION_ERROR( -20000, 'Error al insertar el motivo de Cancelaci¿n del sobregiro: '||c.nro_secuencia||'. '||sqlerrm );
        end;
    end;
    BEGIN
      insert into ba_tab_dat_adicionales ( tab_relacion,
                                           referencia,
                                           parametro,
                                           val_parametro)
                                  values ( 'CC_LIN_SOBREGIROS',
                                            c.nro_secuencia,
                                           'FEC_CANCELACION',
                                           to_char(v_fec_actual, 'DD/MM/YYYY'));
    exception
       when others then
         begin
           update ba_tab_dat_adicionales
              set val_parametro = to_char(v_fec_actual, 'DD/MM/YYYY')
            where tab_relacion = 'CC_LIN_SOBREGIROS'
              and parametro = 'FEC_CANCELACION'
              and referencia = c.nro_secuencia;
         exception
           when others then
             RAISE_APPLICATION_ERROR( -20000, 'Error actualizar la fecha de Cancelaci¿n.: '||c.nro_secuencia||'. '||sqlerrm );
         end;
    end;
    pp_del_reg_impago(c.nro_secuencia);
  end loop;

  --CONTROL DE RENOVACI¿N EN FORMA DIARIA, SOLO PARA PREAPROBADOS
  For c in c_lin_ver_sob Loop
    v_renovar := fp_renovar(c.cod_persona, c.nro_secuencia, c.tipo);
    if nvl(v_renovar, 'S') = 'N' then
       pp_del_reg_impago(c.nro_secuencia);
    end if;
  end loop;
  --PROCESO DE RENOVACION
  For c in c_lin_sobregiros(v_fec_pro_renovacion) Loop
    declare
       v_edad number;
       v_mto_lin_sob cc_lin_sobregiros.monto%type;
       v_por_lin_sob number := nvl(fug_obt_pardinamico('CCO_POR_ING_POS_CTA_COM'), 20);
    begin

      v_renovar := nvl(fp_renovar(c.cod_persona, c.nro_secuencia, c.tipo), 'S');

      if v_renovar = 'S' then
         for cu in c_lin_sob_det(c.nro_secuencia) loop
            if c.tipo = 'C' then
               v_mto_ingreso := fug_obt_ing_pos_cta_com(cu.nro_cuenta, v_can_dia_mov_his);

               if nvl(v_mto_ingreso/3,0) < v_min_pro_com_pos then
                  v_renovar := 'N';
                  pp_act_mot_norenovacion(c.nro_secuencia,'No cumple condici¿n de Ingreso.');
               else
                  v_mto_lin_sob := round((v_mto_ingreso / 3 * v_por_lin_sob)/100);
                  if v_mto_lin_sob > v_mto_max_sobregiro then
                     v_mto_lin_sob := v_mto_max_sobregiro;
                  elsif v_mto_lin_sob < v_mto_min_sobregiro then
                     v_mto_lin_sob := v_mto_min_sobregiro;
                  end if;
               end if;
            else
               v_mto_lin_sob := cu.monto_gs;
            end if;
            if v_renovar = 'S' then
               if c.tip_persona = 'F' then
                  begin
                    select trunc((trunc(v_fec_actual)- Fec_nacimiento)/365)
                      into v_edad
                      from ba_per_fisicas
                     where cod_persona = c.cod_persona;
                  exception
                    when others then
                      v_edad := 0;
                  end;

                  if v_edad between v_eda_minima and v_eda_maxima  and cu.monto_gs >=  v_mon_max_lin_sob then
                     if cu.cod_moneda = v_cod_mon_local then
                        v_mto_lin_sob := v_mon_max_lin_sob;
                     else
                        v_mto_lin_sob := pal_cam.FU_CON_MON_A_MONEDA(v_cod_mon_local,cu.cod_moneda, v_mon_max_lin_sob);
                     end if;
                  else
                     if c.tipo = 'P' then
                        v_mto_lin_sob := cu.monto;
                     /*else
                        if c.cod_moneda <> v_cod_mon_local THEN
                           pag_gen.pr_con_mon_a_moneda(v_cod_mon_local,
                                                       c.cod_moneda,
                                                       nvl(v_mto_lin_sob, 0),
                                                       v_mto_lin_sob,
                                                       v_cot_original,
                                                       v_cot_destino);
                        else
                           v_cot_original := null;
                           v_cot_destino := null;
                        end if;*/
                      end if;
                   end if;
                 else -- si es persona Juridica
                   if c.tipo = 'P' then
                      v_mto_lin_sob := cu.monto;
                   /*else
                      if cu.cod_moneda <> v_cod_mon_local THEN
                         pag_gen.pr_con_mon_a_moneda(v_cod_mon_local,
                                                     cu.cod_moneda,
                                                     nvl(v_mto_lin_sob, 0),
                                                     v_mto_lin_sob,
                                                     v_cot_original,
                                                     v_cot_destino);
                      else
                         v_cot_original := null;
                         v_cot_destino := null;
                      end if;*/
                   end if;
                 end if;

                PP_REN_LIN_SOBREGIRO(c.nro_secuencia, c.fec_inicio, c.cod_persona, cu.nro_cuenta, cu.cod_moneda,nvl(v_mto_lin_sob,0), c.tipo, c.cod_campana);
                pp_del_reg_impago(c.nro_secuencia);
              ELSE
                if c.tipo = 'C' then
                  pp_del_reg_impago(c.nro_secuencia);
                end if;
              END IF;
          END LOOP;
        END IF;
      END;
   END LOOP;
EXCEPTION
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'Error en el Proceso de Registro de Impagos: ' || sqlerrm );
END;
/


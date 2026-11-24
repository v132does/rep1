create or replace procedure it."PRV_GEN_PREVISIONES" is

  /* obtener garantia computable. */
  function lf_obt_gar_com(p_nro_cuenta    in ov_cta_vencidas.nro_cuenta%type,
                          p_cod_moneda    in ba_monedas.cod_moneda%type,
                          p_cod_mon_local in ba_monedas.cod_moneda%type,
                          p_tot_deuda     in pr_cta_prestamos.sal_capital%type,
                          p_tot_cash      out pr_cta_prestamos.sal_capital%type -- me indica si tiene un importe correspondiente a cash collateral para aplicar 100%.
                          ) return number;
  /* obtener prevision anterior. */
  function lf_obt_prv_ant(p_nro_cuenta in ov_cta_vencidas.nro_cuenta%type,
                          p_fec_actual in date) return number;
  /* obtener prevision de año anterior */
  function lf_obt_prv_per_ant(p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type,
                              p_fec_actual in date) return number;
  /* obtener la categoría de previsión de clientes para categoría 1(uno)*/
  function lf_obt_cat_prevision(p_cod_persona in ge_cla_operaciones.cod_persona%type)
    return number;
  /* insertar registros en la tabla de previsiones de operaciones vencidas . */
  procedure lp_ins_prevision(rp_vprev in ov_previsiones%rowtype);
  /* proceso de previsiones: consideraciones a tener en cuenta con el analisis:
  - debe tomar las operaciones que tienen algo previsionado o pueden previsionar en el sistema, es decir, desde el inicio y aun despues de ser canceladas y aun tener prevision aplicada.
  - la prevision actual debe calcularse luego de la categorizacion, ya que se ve influido por este.
  - la prevision debe poder ajustar la prevision contable, esto afectar o desafectar previsiones de acuerdo a lo ya previsionado por la operacion.
  - debe mantenerse una tabla independiente de prevision para saber cuando se afecto o desafecto a una fecha dada.
  secuencia de procesos
  - cambio de estado
  - devengado
  - categorizacion
  - prevision */
  v_fec_actual       ge_calendarios.fec_actual%type;
  v_cod_mon_local    ba_monedas.cod_moneda%type;
  v_por_riesgo_1a    pr_parametros.por_riesgo_1a%type;
  v_por_riesgo_1b    pr_parametros.por_riesgo_1b%type;
  v_por_riesgo_2     pr_parametros.por_riesgo_2%type;
  v_por_riesgo_3     pr_parametros.por_riesgo_3%type;
  v_por_riesgo_4     pr_parametros.por_riesgo_4%type;
  v_por_riesgo_5     pr_parametros.por_riesgo_5%type;
  v_por_riesgo_6     pr_parametros.por_riesgo_6%type;
  v_porcentaje       number(5, 2);
  v_capital          ov_cta_vencidas.sal_tot_batch%type;
  v_garantia         ov_cta_garantias.mto_apl_computable%type;
  v_prevision        ov_previsiones.monto%type;
  v_prv_anterior     ov_previsiones.monto%type;
  v_diferencia       ov_previsiones.monto%type;
  v_prv_per_anterior pr_previsiones.monto%type;
  v_dif_prevision    pr_previsiones.monto%type;
  r_vprev            ov_previsiones%rowtype;
  r_gmovi            ge_movimientos%rowtype;
  v_nro_secuencia    ge_movimientos.nro_secuencia%type;
  v_hora             ge_movimientos.hora%type;
  v_categoria        ge_clientes.cat_automatica%type;
  v_cot_auxiliar     ge_cotizaciones.val_conversion%type;
  --- variables para res 1
  v_pri_prevision     number(18, 2);
  v_neto              ge_cla_operaciones.tot_deu_real%type;
  v_dias_cat          number(10);
  v_tot_cash          pr_cta_garantias.mto_apl_computable%type; -- total de garantias tipo cash collateral
  v_tot_apl           pr_cta_garantias.mto_con_computable%type; -- saldo de riesgo a previsionar
  v_cat_cli_prevision ge_cla_operaciones.cat_automatica%type;
  --- cursor de op. vencidas  a calcular
  cursor c_ope_vencidas is
    select p.nro_cuenta,
           p.cod_moneda,
           c.cod_persona,
           c.cat_riesgo cat_automatica,
           p.estado situacion,
           p.estado,
           p.cod_modalidad,
           p.cod_oficina,
           nvl(p.sal_total, 0) saldo,
           p.est_batch,
           p.cod_modulo,
           c.cod_gru_economico,
           nvl(p.dia_atraso, 0) dia_atraso,
           c.fec_ult_clasif
      from ge_clientes c, ge_cta_clientes cc, ov_cta_vencidas p
     where p.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = c.cod_persona
       and (p.estado not in ('C', 'I') or
           (p.estado = 'C' and exists
            (select 1
                from ov_previsiones t1
               where t1.nro_cuenta = p.nro_cuenta
                 and nvl(t1.monto, 0) > 0
                 and t1.fecha = (select max(t2.fecha)
                                   from ov_previsiones t2
                                  where t2.nro_cuenta = t1.nro_cuenta
                                    and t2.fecha <= v_fec_actual))));

  /* obtener garantia computable. */
  function lf_obt_gar_com(p_nro_cuenta    in ov_cta_vencidas.nro_cuenta%type,
                          p_cod_moneda    in ba_monedas.cod_moneda%type,
                          p_cod_mon_local in ba_monedas.cod_moneda%type,
                          p_tot_deuda     in pr_cta_prestamos.sal_capital%type,
                          p_tot_cash      out pr_cta_prestamos.sal_capital%type -- me indica si tiene un importe correspondiente a cash collateral para aplicar 100%.
                          ) return number is
    v_gar_compu ov_cta_garantias.mto_apl_computable%type := 0;
    v_gar_cash  pr_cta_garantias.mto_con_computable%type := 0;
    v_tot_gara  ov_cta_garantias.mto_apl_computable%type := 0;
    v_cot_aux   ge_cotizaciones.val_conversion%type;
    cursor c_garantias is
      select g.mto_apl_computable, t.cod_garantia
        from ov_cta_garantias g, pr_gar_tipos t
       where g.nro_cuenta = p_nro_cuenta
         and g.cod_garantia = t.cod_garantia
         and t.computable = 'S'
         and nvl(g.mto_apl_computable, 0) > 0;
  begin
    v_tot_gara := 0;
    for reg in c_garantias loop
      v_cot_aux   := null;
      v_gar_compu := nvl(reg.mto_apl_computable, 0);
      /*--- agregado por icl dic/2008 por cambios a la resoluc.
      if v_categoria > 2 and reg.cod_garantia not in (5,11) then
         if v_gar_compu > round(nvl(p_tot_deuda,0)/2,0) then
            v_gar_compu := round(nvl(p_tot_deuda,0)/2,0);
         end if;
      end if;*/
      --- totalizar garantias computables en moneda de la cuenta ---------
      v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
      if reg.cod_garantia in (5, 19, 21) then
        v_gar_cash := v_gar_cash + nvl(v_gar_compu, 0);
      end if;
      p_tot_cash := v_gar_cash;
    end loop;
    return v_tot_gara;
  end;
  /* obtener prevision anterior. */
  function lf_obt_prv_ant(p_nro_cuenta in ov_cta_vencidas.nro_cuenta%type,
                          p_fec_actual in date) return number is
    v_monto ov_previsiones.monto%type;
  begin
    select sum(nvl(monto, 0))
      into v_monto
      from ov_previsiones
     where nro_cuenta = p_nro_cuenta
       and fecha = (select max(fecha)
                      from ov_previsiones
                     where nro_cuenta = p_nro_cuenta
                       and fecha <= p_fec_actual);
    return v_monto;
  end;
  /* obtener prevision año anterior */
  function lf_obt_prv_per_ant(p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type,
                              p_fec_actual in date) return number is
    v_monto pr_previsiones.monto%type;
  begin
    select nvl(sum(monto), 0)
      into v_monto
      from ov_previsiones
     where nro_cuenta = p_nro_cuenta
       and fecha = (select max(fecha)
                      from ov_previsiones
                     where nro_cuenta = p_nro_cuenta
                       and fecha <= round(p_fec_actual, 'year'))
       and not exists (select 1
              from ov_previsiones
             where nro_cuenta = p_nro_cuenta
               and fecha >= round(p_fec_actual, 'year')
               and monto = 0);
    return v_monto;
  exception
    when others then
      v_monto := 0;
      return v_monto;
  end;
  /* obtener la categoría de previsión de clientes para categoría 1(uno)*/
  function lf_obt_cat_prevision(p_cod_persona in ge_cla_operaciones.cod_persona%type)
    return number as
    v_categoria ge_cla_operaciones.cat_automatica%type;
  begin
    --verifico las operaciones que posee el cliente.
    select nvl(max(a.cat_automatica), 1)
      into v_categoria
      from ge_cla_operaciones a
     where a.cod_persona = p_cod_persona;
    return v_categoria;
  exception
    when others then
      v_categoria := 1;
      return v_categoria;
  end;

  /* insertar registros en la tabla de previsiones de operaciones vencidas . */
  procedure lp_ins_prevision(rp_vprev in ov_previsiones%rowtype) is
  begin
    insert into ov_previsiones
      (fecha,
       nro_cuenta,
       monto,
       saldo,
       porcentaje,
       tot_gar_computables,
       tot_pri_prevision)
    values
      (rp_vprev.fecha,
       rp_vprev.nro_cuenta,
       rp_vprev.monto,
       rp_vprev.saldo,
       rp_vprev.porcentaje,
       rp_vprev.tot_gar_computables,
       rp_vprev.tot_pri_prevision);
  exception
    when others then
      raise_application_error(-20000, 'Ins.Prev. ' || sqlerrm);
  end;
begin
  v_fec_actual    := pag_cal.fu_obt_fec_actual(6);
  v_hora          := to_char(sysdate, 'HH24:MI:SS');
  v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');--pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  v_cod_mon_local := pag_gen.fu_obt_mon_local;
  begin
    select por_riesgo_1a,
           por_riesgo_1b,
           por_riesgo_2,
           por_riesgo_3,
           por_riesgo_4,
           por_riesgo_5,
           por_riesgo_6
      into v_por_riesgo_1a,
           v_por_riesgo_1b,
           v_por_riesgo_2,
           v_por_riesgo_3,
           v_por_riesgo_4,
           v_por_riesgo_5,
           v_por_riesgo_6
      from pr_parametros
     where rownum = 1;
  exception
    when no_data_found then
      raise_application_error(-20000, 'Parametros de riesgos no definidos');
  end;
  v_nro_secuencia := 0;
  for reg in c_ope_vencidas loop
    --- convertir el monto de la oper. a la moneda local
    v_cot_auxiliar := null;
    v_capital      := nvl(reg.saldo, 0);
    v_garantia     := lf_obt_gar_com(reg.nro_cuenta,
                                     reg.cod_moneda,
                                     v_cod_mon_local,
                                     v_capital,
                                     v_tot_cash);
    v_categoria    := trunc(reg.cat_automatica);
    v_prevision    := 0;
    v_tot_cash     := 0;
    /*      if reg.cod_gru_economico is not null then
       --- buscar la categoria del grupo
       select trunc(g.cat_automatica)
         into v_categoria
         from ge_gru_economicos g
        where cod_gru_economico = reg.cod_gru_economico;
       if v_categoria is null then
          v_categoria := trunc(reg.cat_automatica);
       end if;
    end if;*/
    if v_categoria = 1 then
      v_cat_cli_prevision := lf_obt_cat_prevision(reg.cod_persona);
      if v_cat_cli_prevision < 2 then
        -- solo cat 1, 1a, 1b
        v_porcentaje := (case
                          when reg.dia_atraso > 0 and v_cat_cli_prevision = 1.1 then
                           v_por_riesgo_1a
                          when reg.dia_atraso > 0 and v_cat_cli_prevision > 1.1 then
                           v_por_riesgo_1b
                          else
                           0
                        end);
      else
        --cat 2..6
        v_porcentaje := v_por_riesgo_1b;
      end if;
    elsif v_categoria = 2 then
      v_porcentaje := v_por_riesgo_2;
    elsif v_categoria = 3 then
      v_porcentaje := v_por_riesgo_3;
    elsif v_categoria = 4 then
      v_porcentaje := v_por_riesgo_4;
    elsif v_categoria = 5 then
      v_porcentaje := v_por_riesgo_5;
    elsif v_categoria = 6 then
      v_porcentaje := v_por_riesgo_6;
    else
      v_porcentaje := 0;
    end if;
    --- realizar primera prevision
    --- aplicar el 50% de la prevision obtenida al neto de la deuda
    v_porcentaje := v_porcentaje / 2;
    v_tot_apl    := nvl(v_capital, 0);
    if v_tot_cash > 0 then
      -- si tiene garantia cash
      if v_tot_cash >= v_tot_apl then
        -- el cash es mayor que la deuda, cubre todo
        v_tot_apl  := 0;
        v_garantia := v_garantia - v_tot_apl; -- restar lo utilizado
      else
        -- la deuda es mayor que el cash
        v_tot_apl  := v_tot_apl - v_tot_cash;
        v_garantia := v_garantia - v_tot_cash; -- restar el cash de la garantia total
      end if;
    end if; -- si no tiene cash, el total aplicar es la deuda total
    -- hallar primera prevision s/ el saldo a aplicar
    if v_cod_mon_local = reg.cod_moneda then
      v_prevision := round(nvl(v_tot_apl, 0) * v_porcentaje / 100, 0);
    else
      v_prevision := round(nvl(v_tot_apl, 0) * v_porcentaje / 100, 2);
    end if;
  
    --- hallar valor computable de la garantia
    if nvl(v_garantia, 0) = 0 and nvl(v_tot_cash, 0) = 0 then
      --- segun modificacion a res. 8 ix. regimenes de previsiones inc. 29.
      --- esta metodologia de calculo no se aplicara cuando los prestamos carezcan de garantia
      --- en cuyo caso el % de prevision se aplicara sobre el saldo total de la deuda
      v_prevision  := 0;
      v_porcentaje := v_porcentaje * 2;
    else
      if v_categoria = 6 then
        v_porcentaje := v_porcentaje * 2;
      end if;
    end if;
    v_pri_prevision := v_prevision;
    --- realizar segunda prevision
    v_neto := nvl(v_capital, 0) - nvl(v_garantia, 0) - nvl(v_tot_cash, 0) -
              v_prevision;
    if v_neto < 0 then
      v_neto := 0;
    end if;
    --- calcular cantidad de dias desde la ultima clasificacion
    v_dias_cat := v_fec_actual - reg.fec_ult_clasif;
    if reg.cat_automatica = 6 and v_garantia > 0 and v_dias_cat > 365 then
      --- previsiones genericas - solo si tiene garantia
      if v_dias_cat > 365 then
        -- si permenezco mas de un a?o en esa cateroai
        if v_dias_cat >= 365 + 360 then
          -- al a?o tengo que previsionar el 100% de la deuda
          --- se debe previsionar el 100% de la deuda
          v_prevision  := reg.saldo;
          v_porcentaje := 100;
        elsif v_dias_cat >= 365 + 180 then
          -- a los 6 primeros meses tengo que previsionar 25% mas es decir 75% de la deuda
          if v_cod_mon_local = reg.cod_moneda then
            v_prevision := round(nvl(reg.saldo, 0) * 75 / 100, 0);
          else
            v_prevision := round(nvl(reg.saldo, 0) * 75 / 100, 2);
          end if;
          v_porcentaje := 75;
        end if;
      end if;
    else
      if v_cod_mon_local = reg.cod_moneda then
        v_prevision := v_prevision +
                       round(nvl(v_neto, 0) * v_porcentaje / 100, 0);
      else
        v_prevision := v_prevision +
                       round(nvl(v_neto, 0) * v_porcentaje / 100, 2);
      end if;
    end if;
    --- recuperar prevision anterior si la tuviere
    v_prv_anterior     := lf_obt_prv_ant(reg.nro_cuenta, v_fec_actual);
    v_prv_per_anterior := lf_obt_prv_per_ant(reg.nro_cuenta, v_fec_actual);
    v_diferencia       := 0;
    v_dif_prevision    := 0;
    --- inicializar datos cabecera del movimiento
    r_gmovi.cod_usuario    := user;
    r_gmovi.hora           := v_hora;
    r_gmovi.fecha          := v_fec_actual;
    r_gmovi.fec_valor      := v_fec_actual;
    r_gmovi.cod_mod_padre  := reg.cod_modulo;
    r_gmovi.cod_mad_padre  := reg.cod_modalidad;
    r_gmovi.cod_modulo     := reg.cod_modulo;
    r_gmovi.cod_modalidad  := reg.cod_modalidad;
    r_gmovi.cod_oficina    := reg.cod_oficina;
    r_gmovi.cod_ofi_origen := reg.cod_oficina;
    r_gmovi.cod_moneda     := reg.cod_moneda;
    r_gmovi.estado         := 'N';
    r_gmovi.reversado      := 'N';
    r_gmovi.emi_aviso      := 'N';
    r_gmovi.protegido      := 'N';
    r_gmovi.nro_cuenta     := reg.nro_cuenta;
    r_gmovi.est_cuenta     := reg.estado;
    if v_nro_secuencia + 2 > 999 then
      v_nro_secuencia := 0;
      v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
      r_gmovi.hora    := v_hora;
    end if;
    if reg.estado = 'C' then
      if nvl(v_prv_anterior, 0) > 0 then
        if v_prv_anterior >= v_prv_per_anterior then
          --- reversar la prevision por cancelacion de op.
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_tra_padre   := 731;
          r_gmovi.cod_transaccion := 731;
          r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES';
          r_gmovi.monto           := v_prv_per_anterior;
          r_gmovi.est_cuenta      := reg.est_batch;
          if r_gmovi.monto != 0 then
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          end if;
        
          --- desafectar la prevision por cancelacion de op.
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_tra_padre   := 731;
          r_gmovi.cod_transaccion := 731;
          r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
          r_gmovi.monto           := (nvl(v_prv_anterior, 0) -
                                     nvl(v_prv_per_anterior, 0));
          r_gmovi.est_cuenta      := reg.est_batch;
          if r_gmovi.monto != 0 then
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          end if;
        else
          --- reversar la prevision por cancelacion de op.
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_tra_padre   := 731;
          r_gmovi.cod_transaccion := 731;
          r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
          r_gmovi.monto           := v_prv_anterior;
          r_gmovi.est_cuenta      := reg.est_batch;
          if r_gmovi.monto != 0 then
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
          end if;
        end if;
        --- insertar prevision
        r_vprev.nro_cuenta          := reg.nro_cuenta;
        r_vprev.fecha               := v_fec_actual;
        r_vprev.monto               := nvl(v_prevision, 0);
        r_vprev.saldo               := nvl(reg.saldo, 0);
        r_vprev.porcentaje          := nvl(v_porcentaje, 0);
        r_vprev.tot_gar_computables := nvl(v_garantia, 0);
        r_vprev.tot_pri_prevision   := nvl(v_pri_prevision, 0);
        lp_ins_prevision(r_vprev);
      end if;
      --------------------------
    else
      v_diferencia := nvl(v_prevision, 0) - nvl(v_prv_anterior, 0);
      if nvl(v_prevision, 0) > nvl(v_prv_per_anterior, 0) then
        v_dif_prevision := nvl(v_prevision, 0) - nvl(v_prv_per_anterior, 0);
      else
        v_dif_prevision := nvl(v_prv_anterior, 0) -
                           nvl(v_prv_per_anterior, 0);
      end if;
      r_gmovi.monto := nvl(v_diferencia, 0);
    
      if v_diferencia <> 0 then
        --- insertar prevision
        r_vprev.nro_cuenta          := reg.nro_cuenta;
        r_vprev.fecha               := v_fec_actual;
        r_vprev.monto               := nvl(v_prevision, 0);
        r_vprev.saldo               := nvl(reg.saldo, 0);
        r_vprev.porcentaje          := nvl(v_porcentaje, 0);
        r_vprev.tot_gar_computables := nvl(v_garantia, 0);
        r_vprev.tot_pri_prevision   := nvl(v_pri_prevision, 0);
        lp_ins_prevision(r_vprev);
        if v_diferencia < 0 then
          if abs(v_diferencia) > abs(v_dif_prevision) then
            --- reversar previsiones
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := nvl(abs(v_dif_prevision), 0);
            r_gmovi.cod_tra_padre   := 731;
            r_gmovi.cod_transaccion := 731;
            r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
            if r_gmovi.monto != 0 then
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            end if;
          
            --- desafectar previsiones
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := (nvl(v_diferencia * -1, 0) -
                                       nvl(abs(v_dif_prevision), 0));
            r_gmovi.cod_tra_padre   := 731;
            r_gmovi.cod_transaccion := 731;
            r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES';
            if r_gmovi.monto != 0 then
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            end if;
          elsif abs(v_diferencia) = abs(v_dif_prevision) then
            --- desafectar previsiones
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := nvl(abs(v_dif_prevision), 0);
            r_gmovi.cod_tra_padre   := 731;
            r_gmovi.cod_transaccion := 731;
            r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES';
            if r_gmovi.monto != 0 then
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            end if;
          else
            --- reversar previsiones
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := nvl(v_diferencia * -1, 0);
            r_gmovi.cod_tra_padre   := 731;
            r_gmovi.cod_transaccion := 731;
            r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
            if r_gmovi.monto != 0 then
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            end if;
          end if;
        elsif v_diferencia > 0 then
          --- constituir previsiones
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          r_gmovi.cod_tra_padre   := 730;
          r_gmovi.cod_transaccion := 730;
          r_gmovi.concepto        := 'PREVISIONES DEL MES';
          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        end if;
        -- si hay diferencia se debe actualizar aqui
        update ge_cla_operaciones
           set tot_prevision     = pag_gen.fu_con_mon_a_moneda(cod_moneda,
                                                               v_cod_mon_local,
                                                               nvl(r_vprev.monto,
                                                                   0)),
               tot_pri_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda,
                                                               v_cod_mon_local,
                                                               nvl(r_vprev.tot_pri_prevision,
                                                                   0))
         where nro_cuenta = r_vprev.nro_cuenta;
      
      else
        -- si no varia nada actualiza al calculo que realizo previamente de prevision
        update ge_cla_operaciones
           set tot_prevision     = pag_gen.fu_con_mon_a_moneda(cod_moneda,
                                                               v_cod_mon_local,
                                                               nvl(v_prevision,
                                                                   0)),
               tot_pri_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda,
                                                               v_cod_mon_local,
                                                               nvl(v_pri_prevision,
                                                                   0))
         where nro_cuenta = reg.nro_cuenta; 
      end if;
    end if;
  end loop;
end;
/


CREATE OR REPLACE PROCEDURE IT.PRT_GEN_PREVISIONES(p_nro_cuenta ta_cta_tarjetas.nro_cuenta%Type Default Null)
 IS

/* Obtener garantia computable. */
FUNCTION LF_OBT_GAR_COM
 (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_LOCAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_TOT_DEUDA IN PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 )
 RETURN NUMBER;
/* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
FUNCTION LF_OBT_CAT_PREVISION (P_COD_PERSONA IN GE_CLA_OPERACIONES.COD_PERSONA%TYPE)
 RETURN NUMBER;
/* Insertar registros en la tabla de previsiones de prestamos. */
PROCEDURE LP_INS_PREVISION
 (RP_TPREV IN TA_PREVISIONES%ROWTYPE
 );
PROCEDURE LP_OBT_PRV_ANT_CONTINGENCIA
 (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE
 ,P_FEC_ACTUAL IN DATE
 ,P_MTO_ANT_CONTINGENCIA OUT NUMBER
 ,P_MTO_ANTERIOR OUT NUMBER
 );
/* Proceso de previsiones: Consideraciones a tener en cuenta con el analisis:
- Debe tomar las operaciones que tienen algo previsionado o pueden previsionar en el sistema, es decir, desde el inicio y aun despues de ser canceladas y aun tener prevision aplicada.
- La prevision actual debe calcularse luego de la categorizacion, ya que se ve influido por este.
- La prevision debe poder ajustar la prevision contable, esto afectar o desafectar previsiones de acuerdo a lo ya previsionado por la operacion.
- Debe mantenerse una tabla independiente de prevision para saber cuando se afecto o desafecto a una fecha dada.
Secuencia de Procesos
- Cambio de Estado
- Devengado
- Categorizacion
- Prevision */
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   -- NGRANCE - Resolución N°37
   v_riesgo1a       pr_parametros.por_riesgo_1a%type;
   v_riesgo1b       pr_parametros.por_riesgo_1b%type;
   --
   v_riesgo2        pr_parametros.por_riesgo_2%type;
   v_riesgo3        pr_parametros.por_riesgo_3%type;
   v_riesgo4        pr_parametros.por_riesgo_4%type;
   v_riesgo5        pr_parametros.por_riesgo_5%type;
   v_riesgo6        pr_parametros.por_riesgo_6%type;
   v_capital        TA_CTA_TARJETAS.SAL_FACTURAR%type;
   v_garantia       ta_cta_garantias.mto_apl_computable%type;
   v_prevision      TA_PREVISIONES.monto%type;
   v_prv_anterior   TA_PREVISIONES.monto%type;
   v_diferencia     TA_PREVISIONES.monto%type;
   v_prv_contingencia   ta_previsiones.tot_prv_contingencia%type; -- prevision de contingencia
   v_prv_con_anterior   ta_previsiones.tot_prv_contingencia%type; -- prevision anterior de contingencia
   v_con_diferencia     ta_previsiones.monto%type;                -- diferencia de contingencia
   v_contingencia       ta_cta_tarjetas.sal_facturar%type;        -- valor de contingencia
   v_net_contingencia   ge_cla_operaciones.tot_deu_contingente%type; -- neto de contingencia
   r_TPREV          TA_PREVISIONES%rowtype;
   r_gmovi          ge_movimientos%rowtype;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   v_hora           ge_movimientos.hora%type;
   v_categoria      ge_clientes.cat_automatica%type;
   v_cot_auxiliar   ge_cotizaciones.val_conversion%type;
   v_porcentaje     number(14,2);
   --- Variables para Res 37
   v_cat_cli_prevision   ge_cla_operaciones.cat_automatica%type; -- NGRANCE - Resolución N°37
   v_neto                GE_CLA_OPERACIONES.tot_deu_real%type;
   v_dias_cat            number(10);
   v_pri_prevision       number(18,2);
   v_lugar               varchar2(1000); -- NGRANCE - Para el control del proceso
   v_usu_mig_excluir     varchar2(30);

   --- Cursor de tarjetas a calcular
   cursor c_tarjetas is
   select p.nro_cuenta, p.cod_moneda, c.cod_persona,
          c.cat_riesgo cat_automatica, p.cat_automatica situacion,
          p.estado, p.cod_modalidad, p.cod_oficina,
          NVL(p.SAL_FACTURAR,0)+NVL(p.SAL_FACTURADO,0)+NVL(p.SAL_FINANCIADO,0)+NVL(p.SAL_CUO_PENDIENTES,0) SALDO,
          NVL(p.LIN_CREDITO,0)+NVL(p.LIN_CUOTAS,0) LINEA_DE_CREDITO,
          p.cod_modulo, c.cod_gru_economico, nvl(p.dia_mora,0) dia_atraso, c.fec_ult_clasif
     from ge_clientes c, ge_cta_clientes cc, TA_CTA_TARJETAS p
    where p.nro_cuenta = cc.nro_cuenta
      and cc.relacion = 'P'
      and cc.cod_persona = c.cod_persona
      --and (v_usu_mig_excluir is null or p.usu_insercion <> v_usu_mig_excluir)
      --and (p.nro_cuenta = p_nro_cuenta or p_nro_cuenta is null)
      --and p.estado <> 'I' --- No procesar los incobrables
      and (p.estado <> 'C' or
           (    p.estado = 'C'
      and exists (select 1 from ta_previsiones t1
                   where t1.nro_cuenta = p.nro_cuenta
                     and nvl(t1.monto,0) > 0
                     and t1.fecha = (select max(t2.fecha)
                                       from ta_previsiones t2
                                      where t2.nro_cuenta = t1.nro_cuenta
                                        and t2.fecha <= v_fec_actual))
          )
          );
TYPE cursor2_type IS TABLE OF c_tarjetas%ROWTYPE;
reg cursor2_type;
TYPE cursor4_type IS TABLE OF ge_cla_operaciones%ROWTYPE;
reg_ge_cla_operaciones_type cursor4_type := cursor4_type(); -- Inicializar la colección
v_indice PLS_INTEGER := 0; -- Índice para cargar datos en la colección
/* Obtener garantia computable. */
FUNCTION LF_OBT_GAR_COM
 (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_LOCAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_TOT_DEUDA IN PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 )
 RETURN NUMBER
 IS
   v_gar_compu  ta_cta_garantias.mto_apl_computable%type := 0;
   v_tot_gara   ta_cta_garantias.mto_apl_computable%type := 0;
   v_cot_aux ge_cotizaciones.val_conversion%type;
   CURSOR c_garantias IS
   SELECT g.mto_apl_computable, t.cod_garantia
     FROM ta_cta_garantias g, pr_gar_tipos t
    WHERE g.nro_cuenta = p_nro_cuenta
      and g.cod_garantia = t.cod_garantia
      and t.computable = 'S'
      AND nvl(g.mto_apl_computable,0) > 0;
BEGIN
   v_tot_gara := 0;
   FOR reg IN c_garantias LOOP
      v_cot_aux := null;
      v_gar_compu := nvl(reg.mto_apl_computable,0);
      --- Agregado por ICL Dic/2008 por cambios a la Resoluc.
      if v_categoria > 2 and reg.cod_garantia not in (5,11) then
         if v_gar_compu > round(nvl(P_TOT_DEUDA,0)/2,0) then
            v_gar_compu := round(nvl(P_TOT_DEUDA,0)/2,0);
         end if;
      end if;
      --- totalizar garantias computables en moneda de la cuenta ---------
      v_tot_gara := NVL(v_tot_gara,0) + NVL(v_gar_compu,0);
   END LOOP;
   RETURN v_tot_gara;
END;

/*Obtener prevision anterior y anterior contingencia..*/
PROCEDURE LP_OBT_PRV_ANT_CONTINGENCIA
 (P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE
 ,P_FEC_ACTUAL IN DATE
 ,P_MTO_ANT_CONTINGENCIA OUT NUMBER
 ,P_MTO_ANTERIOR OUT NUMBER)
 IS
   v_mto_anterior TA_PREVISIONES.monto%type;
   v_mto_ant_contingencia TA_PREVISIONES.monto%type;
BEGIN
   SELECT SUM(NVL(monto, 0)) AS suma_monto, SUM(NVL(tot_prv_contingencia, 0)) AS suma_tot_prv_contingencia
     INTO v_mto_anterior, v_mto_ant_contingencia
     FROM TA_PREVISIONES
    WHERE nro_cuenta = p_nro_cuenta
   AND fecha = (SELECT MAX(fecha)
                  FROM TA_PREVISIONES
                 WHERE nro_cuenta = p_nro_cuenta
                 AND   fecha <= p_fec_actual);
   P_MTO_ANT_CONTINGENCIA:= v_mto_ant_contingencia;
   P_MTO_ANTERIOR:= v_mto_anterior;
END;
/* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/ -- Resolución N°37
FUNCTION LF_OBT_CAT_PREVISION(P_COD_PERSONA IN GE_CLA_OPERACIONES.COD_PERSONA%TYPE)
RETURN NUMBER
AS
v_categoria   ge_cla_operaciones.cat_automatica%type;
BEGIN
   --Verifico las operaciones que posee el cliente.
   SELECT nvl(MAX(a.cat_automatica),1)
     INTO v_categoria
     FROM ge_cla_operaciones a
    WHERE a.cod_persona = P_COD_PERSONA;
   RETURN v_categoria;
EXCEPTION
   WHEN OTHERS THEN
      v_categoria := 1;
      RETURN v_categoria;
END;

/* Insertar registros en la tabla de previsiones de prestamos. */
PROCEDURE LP_INS_PREVISION

 (RP_TPREV IN TA_PREVISIONES%ROWTYPE
 )
 IS
BEGIN
   insert into TA_PREVISIONES
     (fecha, nro_cuenta, monto,
      saldo, linea, porcentaje, situacion,
      tot_gar_computables, tot_pri_prevision,tot_prv_contingencia)
   values
     (rp_TPREV.fecha, rp_TPREV.nro_cuenta, rp_TPREV.monto,
      rp_TPREV.saldo, rp_TPREV.linea, rp_TPREV.porcentaje, rp_tprev.situacion,
      rp_tprev.tot_gar_computables, rp_tprev.tot_pri_prevision,rp_tprev.tot_prv_contingencia);
exception
   when others then
      raise_application_error(-20000,'Ins.Prev. '||sqlerrm);
END;
BEGIN
   v_fec_actual    := pag_cal.fu_obt_fec_actual(6);
   v_hora          := fug_ini_hora(v_fec_actual);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   --v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
   begin
      -- NGRANCE - Resolución N°37
      select por_riesgo_1a, por_riesgo_1b, por_riesgo_2, por_riesgo_3,
             por_riesgo_4, por_riesgo_5, por_riesgo_6
        into v_riesgo1a, v_riesgo1b, v_riesgo2, v_riesgo3,
             v_riesgo4, v_riesgo5, v_riesgo6
      --
        from pr_parametros
       where rownum = 1;
   exception
      when no_data_found then
         raise_application_error(-20000,'Parametros de riesgos no definidos');
   end;
   v_nro_secuencia := 0;
   v_lugar := 'Cursor Principal';
   IF c_tarjetas%ISOPEN THEN
      CLOSE c_tarjetas;
   END IF;
   -------------------------------------------------------
   OPEN c_tarjetas;
   LOOP
   FETCH c_tarjetas BULK COLLECT
        INTO reg LIMIT 500000 ;
   FOR i IN 1 .. reg.count LOOP
      --- Convertir el monto de la tarjeta a la moneda local
      v_cot_auxiliar := null;
/*    if nvl(reg.saldo,0) > nvl(reg.linea_de_credito,0)
      or reg.estado = 'C' then
         v_capital := nvl(reg.saldo,0);
      else
         v_capital := nvl(reg.linea_de_credito,0);
      end if;
*/
      -- Prevision deuda HA-22316
      if nvl(reg(i).saldo,0) < 0 then
        v_capital := 0;
      else
        v_capital := nvl(reg(i).saldo,0);
      end if;
      -- Prevision contingencia HA-2316
      if nvl(reg(i).linea_de_credito, 0) > nvl(reg(i).saldo, 0)  then
		if reg(i).estado != 'B' then --> FIELDESK-155975
           v_contingencia := nvl(reg(i).linea_de_credito, 0) - v_capital;
		else
		   v_contingencia := 0;
		end if;
      else
         v_contingencia := 0;
      end if;
      v_garantia  := lf_obt_gar_com(reg(i).nro_cuenta, reg(i).cod_moneda, v_cod_mon_local, v_capital);
      v_categoria := trunc(reg(i).cat_automatica);
      if reg(i).cod_gru_economico is not null then
         --- Buscar la categoria del grupo
       Begin
         select round(g.cat_automatica)
           into v_categoria
           from ge_gru_economicos g
          where cod_gru_economico = reg(i).cod_gru_economico;
         if v_categoria is null then
            v_categoria := trunc(reg(i).cat_automatica);
         end if;
       exception
         when no_data_found then
           v_categoria := trunc(reg(i).cat_automatica);
       end;
      end if;
      -- NGRANCE - Resolución N°37
      if v_categoria    = 1 then
         v_cat_cli_prevision := LF_OBT_CAT_PREVISION(reg(i).cod_persona);
         IF v_cat_cli_prevision < 2 THEN -- Solo Cat 1, 1a, 1b
            v_porcentaje := (Case when reg(i).dia_atraso > 0 and v_cat_cli_prevision = 1.1 then  v_riesgo1a
                               when reg(i).dia_atraso > 0 and v_cat_cli_prevision > 1.1 then  v_riesgo1b
                               else 0 end);
         ELSE --Cat 2..6
            v_porcentaje := v_riesgo1b;
         END IF;
      --
      elsif v_categoria = 2 then
         v_porcentaje := v_riesgo2;
      elsif v_categoria = 3 then
         v_porcentaje := v_riesgo3;
      elsif v_categoria = 4 then
         v_porcentaje := v_riesgo4;
      elsif v_categoria = 5 then
         v_porcentaje := v_riesgo5;
      elsif v_categoria = 6 then
         v_porcentaje := v_riesgo6;
      else
         v_porcentaje := 0;
      end if;

      --- REALIZAR PRIMERA PREVISION
      --- Aplicar el 50% de la prevision obtenida al neto de la deuda
      v_porcentaje := v_porcentaje/2;
      if v_cod_mon_local = reg(i).cod_moneda then
         v_prevision := round(nvl(v_capital,0)*v_porcentaje/100,0);
         v_prv_contingencia := round(nvl(v_contingencia,0)*v_porcentaje/100,0);
      else
         v_prevision := round(nvl(v_capital,0)*v_porcentaje/100,2);
         v_prv_contingencia := round(nvl(v_contingencia,0)*v_porcentaje/100,0);

      end if;
      --- HALLAR VALOR COMPUTABLE DE LA GARANTIA
      if v_garantia = 0 then
         --- Esta metodologia de calculo no se aplicara cuando los prestamos carezcan de garantia
         --- en cuyo caso el % de prevision se aplicara sobre el saldo total de la deuda
         v_prevision := 0;
         v_prv_contingencia := 0;
         v_porcentaje := v_porcentaje*2;
      end if;
      v_pri_prevision := v_prevision;
      --- REALIZAR SEGUNDA PREVISION
      v_neto := nvl(v_capital,0) - nvl(v_garantia,0) - v_prevision;
      v_net_contingencia :=  nvl(v_contingencia,0) - nvl(v_garantia,0) - v_prv_contingencia;
      if v_neto < 0 then
          v_neto := 0;
      end if;
      if v_net_contingencia < 0 then
          v_net_contingencia := 0;
      end if;
      --- Calcular cantidad de dias desde la ultima clasificacion
      v_dias_cat := v_fec_actual - reg(i).fec_ult_clasif;
      if reg(i).cat_automatica = 6 and v_garantia > 0 and v_dias_cat > 365 then
          --- Previsiones Genericas - Solo si tiene garantia
          if v_dias_cat > 365 then -- Si permenezco mas de un a?o en esa cateroai
             if v_dias_cat >= 365+360 then -- al a?o tengo que previsionar el 100% de la deuda
                --- Se debe previsionar el 100% de la deuda
                v_prevision := reg(i).saldo;
                v_prv_contingencia := v_contingencia;
                v_porcentaje := 100;
             elsif v_dias_cat >= 365+180 then -- a los 6 primeros meses tengo que previsionar 25% mas es decir 75% de la deuda
                if v_cod_mon_local = reg(i).cod_moneda then
                  v_prevision := round(nvl(reg(i).saldo,0)*75/100,0);
                  v_prv_contingencia := round(nvl(v_contingencia,0)*75/100,0);
                else
                  v_prevision := round(nvl(reg(i).saldo,0)*75/100,2);
                  v_prv_contingencia := round(nvl(v_contingencia,0)*75/100,0);
                end if;
                v_porcentaje := 75;
             end if;
          end if;
      else
          if v_cod_mon_local = reg(i).cod_moneda then
            v_prevision := v_prevision + round(nvl(v_neto,0)*v_porcentaje/100,0);
            v_prv_contingencia := v_prv_contingencia + round(nvl(v_net_contingencia,0)*v_porcentaje/100,0);
          else
            v_prevision := v_prevision + round(nvl(v_neto,0)*v_porcentaje/100,2);
            v_prv_contingencia := v_prv_contingencia + round(nvl(v_net_contingencia,0)*v_porcentaje/100,0);
          end if;
      end if;
      --- Recuperar prevision anterior si la tuviere
      LP_OBT_PRV_ANT_CONTINGENCIA(reg(i).nro_cuenta, v_fec_actual,v_prv_con_anterior,v_prv_anterior);
      v_con_diferencia := 0;
      v_diferencia   := 0;
      --- Inicializar datos cabecera del movimiento
      r_gmovi.cod_usuario    := user;
      r_gmovi.hora           := v_hora;
      r_gmovi.fecha          := v_fec_actual;
      r_gmovi.fec_valor      := v_fec_actual;
      r_gmovi.cod_mod_padre  := reg(i).cod_modulo;
      r_gmovi.cod_mad_padre  := reg(i).cod_modalidad;
      r_gmovi.cod_modulo     := reg(i).cod_modulo;
      r_gmovi.cod_modalidad  := reg(i).cod_modalidad;
      r_gmovi.cod_oficina    := reg(i).cod_oficina;
      r_gmovi.cod_ofi_origen := reg(i).cod_oficina;
      r_gmovi.cod_moneda     := reg(i).cod_moneda;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.protegido      := 'N';
      r_gmovi.nro_cuenta     := reg(i).nro_cuenta;
      IF v_nro_secuencia + 2 > 999 THEN
         v_nro_secuencia := 0;
         v_hora          := fug_ini_hora(v_fec_actual);
         r_gmovi.hora    := v_hora;
      END IF;
      if reg(i).estado = 'C' then
         if nvl(v_prv_anterior,0) > 0 then
            --- Desafectar la prevision por cancelacion de tarjeta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_tra_padre   := 731;
            r_gmovi.cod_transaccion := 731;
            r_gmovi.concepto        := 'EXTORNO DE PREVISION';
            r_gmovi.monto           := v_prv_anterior;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            --- Insertar prevision
            r_TPREV.nro_cuenta := reg(i).nro_cuenta;
            r_TPREV.fecha      := v_fec_actual;
            r_TPREV.monto      := nvl(v_prevision,0);
            r_TPREV.saldo      := nvl(reg(i).saldo,0);
            r_TPREV.linea      := nvl(reg(i).linea_de_credito,0);
            r_TPREV.porcentaje := nvl(v_porcentaje,0);
            r_tprev.situacion  := reg(i).situacion;
            r_tprev.tot_gar_computables := nvl(v_garantia,0);
            r_tprev.tot_pri_prevision   := nvl(v_pri_prevision,0);
            r_tprev.tot_prv_contingencia := nvl(v_prv_contingencia,0);  -- prevision contingencia
            lp_ins_prevision(r_TPREV);
         end if;
         if nvl(v_prv_con_anterior,0) > 0 then
            --- Desafectar la prevision de contigencia por cancelacion de tarjeta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_tra_padre   := 7731;
            r_gmovi.cod_transaccion := 7731;
            r_gmovi.concepto        := 'EXTORNO DE PREVISION CONTINGENCIA';
            r_gmovi.monto           := v_prv_con_anterior;
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         end if;
      else
         v_diferencia  := nvl(v_prevision,0) - nvl(v_prv_anterior,0);
         v_con_diferencia := nvl(v_prv_contingencia,0) - nvl(v_prv_con_anterior,0);
         r_gmovi.monto := nvl(v_diferencia,0);
         if v_diferencia <> 0 then
            --- Insertar prevision
            r_TPREV.nro_cuenta := reg(i).nro_cuenta;
            r_TPREV.fecha      := v_fec_actual;
            r_TPREV.monto      := nvl(v_prevision,0);
            r_TPREV.saldo      := nvl(reg(i).saldo,0);
            r_TPREV.linea      := nvl(reg(i).linea_de_credito,0);
            r_TPREV.porcentaje := nvl(v_porcentaje,0);
            r_tprev.situacion  := reg(i).situacion;
            r_tprev.tot_gar_computables := nvl(v_garantia,0);
            r_tprev.tot_pri_prevision   := nvl(v_pri_prevision,0);
            r_tprev.tot_prv_contingencia := nvl(v_prv_contingencia,0); -- prevision contingencia
            lp_ins_prevision(r_TPREV);
            if v_diferencia < 0 then
               --- Desafectar previsiones
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.monto           := nvl(v_diferencia*-1,0);
               r_gmovi.cod_tra_padre   := 731;
               r_gmovi.cod_transaccion := 731;
               r_gmovi.concepto        := 'EXTORNO DE PREVISION';
               pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            elsif v_diferencia > 0 then
               --- Constituir previsiones
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.cod_tra_padre   := 730;
               r_gmovi.cod_transaccion := 730;
               r_gmovi.concepto        := 'CONSTITUCION DE PREVISION';
               pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            end if;
         end if;
         -- HA-2316
         if v_con_diferencia <> 0 then
            if v_diferencia = 0 then -- valida que no haya insertado ya en la linea 439
            --- Insertar prevision
            r_TPREV.nro_cuenta := reg(i).nro_cuenta;
            r_TPREV.fecha      := v_fec_actual;
            r_TPREV.monto      := nvl(v_prevision,0);
            r_TPREV.saldo      := nvl(reg(i).saldo,0);
            r_TPREV.linea      := nvl(reg(i).linea_de_credito,0);
            r_TPREV.porcentaje := nvl(v_porcentaje,0);
            r_tprev.situacion  := reg(i).situacion;
            r_tprev.tot_gar_computables := nvl(v_garantia,0);
            r_tprev.tot_pri_prevision   := nvl(v_pri_prevision,0);
            r_tprev.tot_prv_contingencia := nvl(v_prv_contingencia,0); -- prevision contingencia
            lp_ins_prevision(r_TPREV);
            end if;
            if v_con_diferencia < 0 then
               --- Desafectar previsiones contingencia
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.monto           := v_con_diferencia * -1;
               r_gmovi.cod_tra_padre   := 7731;
               r_gmovi.cod_transaccion := 7731;
               r_gmovi.concepto        := 'EXTORNO DE PREVISION CONTINGENCIA';
               pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

            elsif v_con_diferencia > 0 then
               --- Constituir previsiones contingencia
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.monto           := v_con_diferencia;
               r_gmovi.cod_tra_padre   := 7730;
               r_gmovi.cod_transaccion := 7730;
               r_gmovi.concepto        := 'CONSTITUCION DE PREVISION CONTINGENCIA';
               pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            end if;
         end if;

         v_indice := v_indice + 1;
         reg_ge_cla_operaciones_type.EXTEND;
         reg_ge_cla_operaciones_type(v_indice).nro_cuenta := reg(i).nro_cuenta;
         reg_ge_cla_operaciones_type(v_indice).tot_prevision := NVL(v_prevision, 0) + NVL(v_prv_contingencia, 0);
         reg_ge_cla_operaciones_type(v_indice).tot_pri_prevision := NVL(v_pri_prevision, 0);
         reg_ge_cla_operaciones_type(v_indice).tot_cap_pri_prevision := NVL(v_pri_prevision, 0);
         reg_ge_cla_operaciones_type(v_indice).tot_cap_seg_prevision := (NVL(v_prevision, 0) + NVL(v_prv_contingencia, 0)) - NVL(v_pri_prevision, 0);

      end if;
   END LOOP;
   EXIT WHEN c_tarjetas%NOTFOUND;
   END LOOP;
   CLOSE c_tarjetas;
   -- Ejecutar el UPDATE fuera del loop usando FORALL
   FORALL i IN reg_ge_cla_operaciones_type.FIRST .. reg_ge_cla_operaciones_type.LAST
      UPDATE ge_cla_operaciones
         SET tot_prevision = reg_ge_cla_operaciones_type(i).tot_prevision,
             tot_pri_prevision = reg_ge_cla_operaciones_type(i).tot_pri_prevision,
             tot_cap_pri_prevision = reg_ge_cla_operaciones_type(i).tot_cap_pri_prevision,
             tot_cap_seg_prevision = reg_ge_cla_operaciones_type(i).tot_cap_seg_prevision
       WHERE nro_cuenta = reg_ge_cla_operaciones_type(i).nro_cuenta;

END;
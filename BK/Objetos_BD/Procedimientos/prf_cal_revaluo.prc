CREATE OR REPLACE PROCEDURE IT.PRF_CAL_REVALUO (
  p_fec_proceso af_coe_revaluos.fec_proceso%type,
  p_tipo_coe    af_coe_revaluos.tipo%type)
is
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(13); -- fecha de hoy
  -- Variables calculo de revaluo
  v_rev_anterior      af_bienes.rev_anterior%type;
  v_rev_ano_anterior  af_bienes.rev_ano_anterior%type;
  v_rev_ano_acumulado       af_bienes.rev_ano_acumulado%type;
  v_rev_mes           af_bienes.rev_ano_acumulado%type;
  v_rev_actual        af_bienes.rev_actual%type;
  v_coeficiente       af_coe_revaluos.coeficiente%type;
  -- Variables calculo de depreciacion
  v_dep_anterior      af_bienes.dep_anterior%type;
  v_dep_anual         af_bienes.dep_anual%type;
  v_dep_mensual       af_bienes.dep_mensual%type;
  v_dep_mensual_anterior af_bienes.dep_mensual%type;
  v_rev_dev           af_bienes.rev_depreciacion%type;
  v_dep_actual        af_bienes.dep_actual%type;
  v_dep_acumulada     af_bienes.dep_acumulada%type;
  v_dep_anual_acelerada af_bienes.dep_anual%type;
  v_dep_mensual_acelerada af_bienes.dep_mensual%type;
  v_dep_actual_acelerada af_bienes.dep_actual%type;
  v_dep_acumulada_acelerada af_bienes.dep_acumulada%type;
  --
  v_val_neto          af_bienes.val_neto%type;
  v_val_neto_acelerado af_bienes.val_neto%type;
  --
  v_mes               number(2);
  v_redondeo        number(5);
  v_cod_mon_base    ba_monedas.cod_moneda%type;
  --Monto a ajustar para los casos que el valor neto vaya a quedar negativo
  v_mto_ajustar       af_bienes.dep_acumulada%type;
  v_mto_ajustar_1     af_bienes.dep_acumulada%type;

  --Nuevas Variables--
  v_cal_ipc_revaluo  varchar2(1);
  v_fec_fin_año_ant  date;
  v_val_dep_actual af_bienes.dep_actual%type;
  v_val_dep_mensual af_bienes.val_neto%type;

  --Bienes adquiridos antes del mes procesado
  cursor c_bienes is
   select b.cod_bien, b.cod_articulo, b.val_compra, b.fec_compra,
   b.rev_actual, b.rev_anterior, b.dep_actual, b.dep_anterior, b.dep_acumulada,b.dep_ano_acu_anterior,
   b.fec_vto_depreciacion, a.ind_depreciacion, a.ind_revaluo, a.ano_depreciacion, a.ano_dep_acelerado,
   b.rev_ano_anterior, b.rev_ano_acumulado, b.val_neto,
   ---
   case
         when b.fec_compra <= v_fec_fin_año_ant then
           (to_number(to_char(b.fec_vto_depreciacion,'yyyy'))-
            to_number(to_char(v_fec_fin_año_ant,'yyyy')))*12-
            (12-to_number(to_char(b.fec_vto_depreciacion,'mm')))
         else
           --Sie tiene nueva fecha de venc de depreciacion--
           (to_number(to_char(b.fec_vto_depreciacion,'yyyy'))-
            to_number(to_char(b.fec_compra,'yyyy')))*12
         end mes_viu_restan, b.por_val_dep_bien val_depreciable,
         dep_mensual,
         case
         when to_char(p_fec_proceso,'yyyymm') > to_char(b.fec_vto_depreciacion,'yyyymm') then
         'N' else 'S' end deprecia 
   ----
   from   af_bienes b, af_articulos a
   where  a.cod_articulo = b.cod_articulo
   and    TO_NUMBER(TO_CHAR(p_fec_proceso,'YYYYMM')) >= TO_NUMBER(TO_CHAR(b.fec_compra,'YYYYMM')) + 1
   and    b.estado = 'A'
   and   (a.ind_depreciacion = 'S' or a.ind_revaluo = 'S')
   order  by b.cod_bien;

  --Bienes adquiridos durante el mes procesado
  cursor c_bienes_mes_actual is
   select b.cod_bien, b.cod_articulo, b.descripcion, b.cod_oficina, b.cod_area,
   b.nro_serie, b.val_compra, b.cod_moneda, b.fec_compra, b.cod_ent_proveedor,
   b.nro_factura, b.tipo, b.coeficiente, b.fec_vto_depreciacion, b.val_compra rev_anterior,
   b.val_compra rev_actual, 0 dep_anterior, 0 dep_anual , 0 dep_mensual, 0 rev_depreciacion,
   0 dep_actual, 0 dep_acumulada, 0 dep_mensual_normal,0 dep_ano_acu_anterior, b.val_compra val_neto, p_fec_proceso fec_proceso, p_tipo_coe tip_proceso,
   'A' estado, null fec_enajenacion, b.rev_ano_anterior, b.rev_ano_acumulado,
   (to_number(to_char(b.fec_vto_depreciacion,'yyyy'))-
    to_number(to_char(b.fec_compra,'yyyy')))*12 mes_vid_util,
    b.por_val_dep_bien
   from   af_bienes b, af_articulos a
   where  a.cod_articulo = b.cod_articulo
   and    TO_NUMBER(TO_CHAR(p_fec_proceso,'YYYYMM')) < TO_NUMBER(TO_CHAR(b.fec_compra,'YYYYMM')) + 1
   and    b.estado = 'A'
   and   (a.ind_depreciacion = 'S' or a.ind_revaluo = 'S')
   order  by b.cod_bien;

begin
  --- Limpio la tabla temporal
  delete from af_bienes_tmp;
  v_cod_mon_base  := pag_gen.fu_obt_mon_local();
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_base);
  v_cal_ipc_revaluo := nvl(fug_obt_pardinamico('IND_CAL_IPC_REVALUO'),'N');
  v_fec_fin_año_ant := to_date('01/01/'||to_char(p_fec_proceso,'yyyy'),'dd/mm/yyyy')-1;
  --- Recorro los bienes a actualizar
for r_bien in c_bienes loop
    /*
    || Cálculo por la diferencia que pasa el Ministerio de Hacienda
    */
   if fug_obt_tip_implementacion in (1,9) then
      if v_cal_ipc_revaluo = 'S' then
      if p_tipo_coe = 'A' then
        if to_char(r_bien.fec_compra,'YYYY') < to_char(p_fec_proceso,'YYYY') then
          --- si la fecha de compra es anterior al periodo, se toma el coeficiente de enero
          if to_char(r_bien.fec_vto_depreciacion,'YYYY') >= to_char(p_fec_proceso,'YYYY') then
            --- si el bien no tiene fecha de depreciacion dentro del perido,
            --- se toma el coeficiente de hacienda de enero.
             begin
              select coe_hacienda
               into   v_coeficiente
               from   af_coe_revaluos
               where  to_char(fec_proceso,'MM')   = '01'
               and    to_char(fec_proceso,'YYYY') = to_char(p_fec_proceso,'YYYY')
               and    tipo  = 'M';
             exception
                when no_data_found then
                  raise_application_error(-20000,
                  'No se pudo obtener el coeficiente de Hacienda para Enero');
                when others then
                  raise_application_error(-20000,
                  'Error al obtener el coeficiente de Haciendo para Enero');
             end;
          --Se comenta este bloque ya que debe entrar en el anterior. CB. 27/12/2013. DYDMR-164
          /*elsif to_char(r_bien.fec_vto_depreciacion,'YYYY') = to_char(p_fec_proceso,'YYYY') then
            --- si la fecha de vto. de la depreción es dentro del periodo,
            --- se toma el coeficiente provisto por Hacienda para aquellos Bienes que fueron enajenados durante el período
             begin
              select coe_fin_depreciacion
              into   v_coeficiente
              from   af_coe_revaluos
              where  to_number(to_char(fec_proceso,'MM')) = to_number(to_char(r_bien.fec_vto_depreciacion,'MM'))
              and    to_char(fec_proceso,'YYYY') = to_char(p_fec_proceso,'YYYY');
            exception
              when no_data_found then
                 raise_application_error(-20000,
                 'No se pudo obtener el coeficiente de Hacienda para Enero');
              when others then
                 raise_application_error(-20000,
                 'Error al obtener el coeficiente de Haciendo para Enero');
             end;*/
          elsif r_bien.ind_depreciacion = 'N' and r_bien.fec_vto_depreciacion is null then
             --- si el bien no tiene fecha de depreciacion dentro del perido,
             --- se toma el coeficiente de hacienda de enero.
             begin
               select coe_hacienda
               into   v_coeficiente
               from   af_coe_revaluos
               where  to_char(fec_proceso,'MM')   = '01'
               and    to_char(fec_proceso,'YYYY') = to_char(p_fec_proceso,'YYYY')
               and    tipo  = 'M';
             exception
                when no_data_found then
                  raise_application_error(-20000,
                  'No se pudo obtener el coeficiente de Hacienda para Enero');
                when others then
                  raise_application_error(-20000,
                  'Error al obtener el coeficiente de Hacienda para Enero');
             end;
         end if;
        else
        -- si el bien se compró dentro del periodo,
        -- el cálculo se hace por el coef. de hacienda de acuerdo a la fecha de compra del bien
            begin
              select coe_hacienda
              into   v_coeficiente
              from   af_coe_revaluos
              where  to_number(to_char(fec_proceso,'MM')) = to_number(to_char(r_bien.fec_compra,'MM')) + 1
              and    to_char(fec_proceso,'YYYY') = to_char(p_fec_proceso,'YYYY');
            exception
               when no_data_found then
                 raise_application_error(-20000,
                 'No se pudo obtener el coeficiente de Hacienda para Enero');
               when others then
                 raise_application_error(-20000,
                 'Error al obtener el coeficiente de Hacienda para Enero');
            end;
        end if;
       ---
      else
       --- Obtengo el coeficiente de revaluo para este ejercicio
        begin
          select coeficiente
          into   v_coeficiente
          from   af_coe_revaluos
          where  fec_proceso = p_fec_proceso
          and    tipo        = p_tipo_coe
          and    nvl(ind_procesado,'N') = 'N';
        exception
          when no_data_found then
           raise_application_error(-20000,
            'No se pudo obtener el coeficiente de revaluo para el periodo '||to_char(p_fec_proceso,'YYYY/MM'));
        end;
     end if;
     end if;
   end if;
    --- Paso el registro actual al Temporal para calcular
    PRF_INS_BIEN_TMP(r_bien.cod_bien);

    --- Inicializo las variables
    v_rev_anterior  := 0;
    v_rev_actual    := 0;
    v_dep_anterior  := 0;
    v_dep_anual     := 0;
    v_dep_mensual   := 0;
    v_rev_dev       := 0;
    v_dep_actual    := 0;
    v_dep_acumulada := 0;
    v_val_neto      := 0;
    v_dep_mensual_acelerada := 0;
    v_dep_actual_acelerada := 0;
    v_dep_mensual_anterior := 0;
    v_val_neto_acelerado := 0;
    v_dep_anual_acelerada := 0;
    v_dep_acumulada_acelerada := 0;
    v_rev_mes := 0;
    v_rev_ano_anterior := 0;
    v_rev_ano_acumulado := 0;
    v_mto_ajustar := 0;
    V_MTO_AJUSTAR_1 := 0;
    v_val_dep_actual := 0;
    v_mto_ajustar := 0;
    ---
   if to_char(v_fec_actual,'yyyymm') > /* =  FM dydmr 1484 29/12/2014 (solo si el mes es mayor)*/ to_char(r_bien.fec_vto_depreciacion,'yyyymm') AND p_tipo_coe <> 'A' and fug_obt_tip_implementacion = 1 then -- Solo si es mensual debe entrar. CB. 27/12/2013. DYDMR-164
      ---Ya no se debe revaluar ni depreciar
      --- rabf - 02/02/2012 - AP 2797
      v_rev_anterior := r_bien.rev_anterior;
      v_rev_actual   := r_bien.rev_actual;
      ---
      v_dep_anterior := r_bien.dep_anterior;
      v_rev_dev      := 0;
      ---
      if ((nvl(r_bien.val_neto,0) = 1) or
          (r_bien.deprecia = 'N')) then
         if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
            --v_dep_actual_acelerada    := r_bien.dep_actual;
            v_dep_mensual_acelerada   := v_dep_actual_acelerada;
            v_dep_acumulada_acelerada := r_bien.dep_acumulada;
            v_val_neto_acelerado      := 1;
         else
            --v_dep_actual    := r_bien.dep_actual;
            v_dep_actual    := 0;
            v_dep_mensual   := v_dep_actual;
            v_dep_acumulada := r_bien.dep_acumulada;
            v_val_neto      := 1;
         end if;
      else
         --v_mto_ajustar := r_bien.val_neto - 1;
         if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
            v_dep_actual_acelerada    := v_mto_ajustar + r_bien.dep_actual;
            v_dep_mensual_acelerada   := v_dep_actual_acelerada;
            v_dep_acumulada_acelerada := r_bien.rev_actual - v_mto_ajustar;
            v_val_neto_acelerado      := 1;
         else
            if to_char(p_fec_proceso,'yyyymm') > to_char(r_bien.fec_vto_depreciacion,'yyyymm') then
               v_dep_actual := 0;
            else
               --v_dep_actual := v_mto_ajustar + r_bien.dep_actual;
               v_dep_actual := r_bien.dep_mensual;
            end if;
            v_dep_mensual   := v_dep_actual;
            v_dep_acumulada := r_bien.rev_actual - v_mto_ajustar;
            v_val_neto      := 1;
         end if;
         v_mto_ajustar  := 0;
      end if;
      ---
      v_coeficiente  := 0;
   elsif ( fug_obt_tip_implementacion = 1 and ( nvl(r_bien.rev_actual,0) - nvl(r_bien.dep_acumulada,0) ) <= 1 and p_tipo_coe = 'M' )  then
      ---Ya no se debe revaluar ni depreciar
      if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
          v_rev_anterior := r_bien.rev_anterior;
          v_rev_actual   := r_bien.rev_actual;
          ---
          v_dep_anterior := r_bien.dep_anterior;
          v_dep_mensual_acelerada := 0;
          v_dep_actual_acelerada := r_bien.dep_actual;
          v_dep_acumulada_acelerada := r_bien.dep_acumulada;
          ---
          v_val_neto_acelerado := 1;
          v_rev_dev := 0;
          ---
          v_coeficiente  := 0;
      else
          v_rev_anterior := r_bien.rev_anterior;
          v_rev_actual   := r_bien.rev_actual;
          ---
          v_dep_anterior := r_bien.dep_anterior;
          v_dep_mensual  := 0;
          v_dep_actual   := r_bien.dep_mensual;
          v_dep_acumulada:= r_bien.dep_acumulada;
          ---
          v_val_neto     := 1;
          v_rev_dev      := 0;
          ---
          v_coeficiente  := 0;
      end if;
   elsif to_char(r_bien.fec_vto_depreciacion,'YYYY') = to_char(p_fec_proceso,'YYYY') and ( fug_obt_tip_implementacion = 1 and ( nvl(r_bien.rev_actual,0) - nvl(r_bien.dep_acumulada,0) ) <= 1 and p_tipo_coe = 'M')  then
        ---Ya no se debe revaluar ni depreciar
     if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
          v_rev_anterior := r_bien.rev_anterior;
          v_rev_actual   := r_bien.rev_actual;
          ---
          v_dep_anterior := r_bien.dep_anterior;
          v_dep_mensual_acelerada := 0;
          v_dep_actual_acelerada := r_bien.dep_actual;
          v_dep_acumulada_acelerada := r_bien.dep_acumulada;
          ---
          v_val_neto_acelerado := 1;
          v_rev_dev := 0;
          ---
          v_coeficiente  := 0;
     else
          v_rev_anterior := r_bien.rev_anterior;
          v_rev_actual   := r_bien.rev_actual;
          ---
          v_dep_anterior := r_bien.dep_anterior;
          v_dep_mensual  := 0;
          v_dep_actual   := r_bien.dep_actual;
          v_dep_acumulada:= r_bien.dep_acumulada;
          ---
          v_val_neto     := 1;
          v_rev_dev      := 0;
          ---
          v_coeficiente  := 0;
     end if;
   elsif to_char(r_bien.fec_vto_depreciacion,'YYYY') < to_char(p_fec_proceso,'YYYY') and ( fug_obt_tip_implementacion = 1 and ( nvl(r_bien.rev_actual,0) - nvl(r_bien.dep_acumulada,0) ) <= 1 ) then
        ---Ya no se debe revaluar ni depreciar
     if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
          v_rev_anterior := r_bien.rev_anterior;
          v_rev_actual   := r_bien.rev_actual;
          ---
          v_dep_anterior := r_bien.dep_anterior;
          v_dep_mensual_acelerada := 0;
          v_dep_actual_acelerada := r_bien.dep_actual;
          v_dep_acumulada_acelerada := r_bien.dep_acumulada;
          ---
          v_val_neto_acelerado := 1;
          v_rev_dev := 0;
          ---
          v_coeficiente  := 0;
     else
          v_rev_anterior := r_bien.rev_anterior;
          v_rev_actual   := r_bien.rev_actual;
          ---
          v_dep_anterior := r_bien.dep_anterior;
          v_dep_mensual  := 0;
          v_dep_actual   := r_bien.dep_actual;
          v_dep_acumulada:= r_bien.dep_acumulada;
          ---
          v_val_neto     := 1;
          v_rev_dev      := 0;
          ---
          v_coeficiente  := 0;
     end if;
   else
     if fug_obt_tip_implementacion in (1,9) then ---VERIFICAR KF
          --- Obtengo el revaluo anterior
        if nvl(r_bien.rev_actual,0) = 0 then
          v_rev_anterior := r_bien.val_compra;
        else
          v_rev_anterior := r_bien.rev_actual;
        end if;
     end if;
    /*************************
     *** CALCULO DE REVALUO ***
    *************************/
     if r_bien.ind_revaluo = 'S' and v_cal_ipc_revaluo = 'S' then
        if p_tipo_coe = 'M' then
          --- rabf 02/03/2011. Debe tomar el revaluo anterior, de lo contrario el asiento sale negativo
            if nvl(r_bien.rev_ano_anterior,0) = 0 then
               v_rev_ano_anterior := nvl(r_bien.val_compra,0); /*KF Para los bienes nuevos debe tomar el valor de compra*/
            else
               v_rev_ano_anterior := nvl(r_bien.rev_ano_anterior,0);
            end if;
            v_rev_mes := round ((v_rev_ano_anterior * nvl(v_coeficiente,1 )) -  v_rev_ano_anterior,v_redondeo);
            v_rev_ano_acumulado := round(nvl(r_bien.rev_ano_acumulado ,0) + nvl(v_rev_mes,0),0);
            --- Calculo el revaluo actual
            v_rev_actual := round( nvl(v_rev_ano_acumulado ,0) + v_rev_ano_anterior,v_redondeo);
        else
           --- rabf/kf - 27/12/2011
           if to_number(to_char(r_bien.fec_compra, 'YYYY')) = to_number(to_char(p_fec_proceso, 'YYYY')) then
              v_rev_ano_anterior := nvl(r_bien.val_compra,0);
           elsif nvl(r_bien.rev_ano_anterior, 0) = 0 then
              select max(rev_ano_anterior)
              into   v_rev_ano_anterior
              from   af_bienes_his a
              where  a.cod_bien = r_bien.cod_bien
              and    a.rev_ano_anterior <> 0
              and    to_number(to_char(a.fec_proceso,'YYYY')) = to_number(to_char(p_fec_proceso, 'YYYY'));
           else
              v_rev_ano_anterior := nvl(r_bien.rev_ano_anterior,0);
           end if;
           --- Calculo el revaluo actual anual
           v_rev_actual := round((v_rev_ano_anterior ) * (v_coeficiente), v_redondeo);
        end if;
     else
        v_rev_actual := v_rev_anterior;
     end if;

    /******************************
    *** CALCULO DE DEPRECIACION ***
    ******************************/
     if r_bien.ind_depreciacion = 'S' then
        /* KF Obtengo la depreciacion anterior, en el caso de los Bienes nuevos comprados durante el año,
         debe acumular la primera depreciacion actual, es decir la depreciación del segundo mes de vida útil*/
      /*  if last_day(add_months(r_bien.fec_compra,2))  = last_day(p_fec_proceso) then
            v_dep_anterior := r_bien.dep_actual;
        else  */
            v_dep_anterior := nvl(r_bien.dep_ano_acu_anterior,0); --- Depreciacion Acumulada del Año Anterior.
       /* end if;   */
        v_dep_mensual_anterior := r_bien.dep_actual; --- Depreciacion Actual del mes anterior al proceso, esto se obtiene para ir acumulando en la dep acumulada mes a mes la dep actual

        /* Obtengo los años de vida util para el articulo*/
        if nvl(r_bien.ano_depreciacion,0) = 0 then
            raise_application_error(-20000,
            'No se pudo obtener los años de vida util para el articulo '||
            to_char(r_bien.cod_articulo));
        end if;

        /*Obtengo los años de vida util acelerado para el articulo KF*/
        if nvl(r_bien.ano_dep_acelerado,0) = 0 then
            raise_application_error(-20000,
            'No se pudo obtener los años de vida util para el articulo '||
            to_char(r_bien.cod_articulo));
        end if;
        /*Obtengo la depreciación Anual*/
        --v_dep_anual := round(v_rev_actual / r_bien.ano_depreciacion,0); --- OK
        v_val_dep_actual := round((v_rev_actual - r_bien.dep_acumulada) * (r_bien.val_depreciable/100));
        if r_bien.mes_viu_restan > 12 then
           --v_dep_anual :=  round((v_val_dep_actual / r_bien.mes_viu_restan))*12;
           v_dep_anual := r_bien.dep_mensual * 12;
           v_dep_anual_acelerada := r_bien.dep_mensual * 12;
        else
           v_dep_anual := r_bien.dep_mensual * r_bien.mes_viu_restan;
           v_dep_anual_acelerada := r_bien.dep_mensual * r_bien.mes_viu_restan;
        end if;
        --v_dep_anual :=  round((v_val_dep_actual / r_bien.mes_viu_restan));
        --v_dep_anual_acelerada := r_bien.dep_mensual * 12;
        --------------
        --v_dep_anual := round(v_rev_actual / r_bien.ano_depreciacion,0);
        /*Obtengo la depreciacion Anual Acelerada KF*/
        --v_dep_anual_acelerada := round (v_rev_actual / r_bien.ano_dep_acelerado);
        /*Obtengo la depreciación Mensual*/
        if p_tipo_coe = 'M' then
            v_dep_mensual := r_bien.dep_mensual;
            /*Obtengo la depreciacion Mensual Acelerada KF*/
            v_dep_mensual_acelerada := r_bien.dep_mensual;
            /*Obtengo el revaluo de la depreciación*/
            if r_bien.ind_revaluo = 'S' and v_cal_ipc_revaluo = 'S' then
               v_rev_dev := trunc(nvl(v_dep_anterior,0) * (nvl(v_coeficiente,1)-1),0); --- KF L dep acumulada corresponde a la dep acumulada del mes ---
            end if;
        else
            if to_char(p_fec_proceso,'YYYY') = to_char(r_bien.fec_vto_depreciacion,'YYYY') then
               v_mes := to_number(to_char(r_bien.fec_vto_depreciacion,'MM'));
              /*agregado por T*/
            elsif to_char(p_fec_proceso,'YYYY') = to_char(r_bien.fec_compra,'YYYY') then
               v_mes := to_char(p_fec_proceso,'MM') - to_char(r_bien.fec_compra,'MM');
            else
               v_mes := 12;
            end if;
            /*Obtengo la dep mensual */
            v_dep_mensual :=  r_bien.dep_mensual;
            --v_dep_mensual := round((v_dep_anual / 12) * v_mes,0);
            /*Obtengo la dep mensual acelerada KF */
            v_dep_mensual_acelerada := r_bien.dep_mensual;
            /*Obtengo el revaluo de la depreciación*/
            if r_bien.ind_revaluo = 'S' and v_cal_ipc_revaluo = 'S' then
               v_rev_dev := trunc(nvl(v_dep_anterior,0) * (nvl(v_coeficiente,1)-1),0); --- Depreciacion Acumulada del mes anterior.
            end if;
        end if;
        /*Obtengo la depreciación actual*/
        v_dep_actual := v_dep_mensual + v_rev_dev;
        /*Obtengo la depreciación actual acelerada KF*/
        v_dep_actual_acelerada := v_dep_mensual_acelerada + v_rev_dev;
        /*Obtengo la depreciacion acumulada del proceso mensual*/
        --if p_tipo_coe = 'M' and to_char(p_fec_proceso,'MM') <> '01' then
           v_dep_acumulada := nvl(r_bien.dep_acumulada,0) + nvl(v_dep_actual,0); /*KF Para los Bienes la dep acumulada debe ser la dep acumulada del mes anterior mas la actual*/
        --else
        /*Obtengo la depreciación acumulada*/
           --v_dep_acumulada := v_dep_anterior + v_dep_actual;
           --v_dep_acumulada := v_dep_anterior + v_dep_anual;
        --end if;
        /*Obtengo la depreciacion acumulada acelerada del proceso mensual*/
        --if p_tipo_coe = 'M' and to_char(p_fec_proceso,'MM') <> '01' then
           v_dep_acumulada_acelerada := r_bien.dep_acumulada + v_dep_actual_acelerada;  /*KF Para los Bienes la dep acumulada debe ser la dep acumulada del mes anterior mas la actual*/
        --else
        /*Obtengo la depreciación acumulada acelerada KF*/
        --   v_dep_acumulada_acelerada := v_dep_anterior + v_dep_actual_acelerada;
        --end if;
        /*Obtengo el valor neto del proceso*/
        v_val_neto := v_rev_actual - v_dep_acumulada;
        /*Obtengo el valor neto acelerado del proceso  KF*/
        v_val_neto_acelerado := v_rev_actual - v_dep_acumulada_acelerada;
        -----
        if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
           if v_dep_acumulada_acelerada >= v_rev_actual then
              v_dep_mensual_acelerada   := v_dep_mensual_acelerada + v_val_neto_acelerado - 1 ;
              v_dep_actual_acelerada    := v_dep_mensual_acelerada + v_rev_dev;
               if to_char(p_fec_proceso,'MM') <> '01' then
                  v_dep_acumulada_acelerada := r_bien.dep_acumulada + v_dep_actual_acelerada; --v_dep_anterior + v_dep_actual_acelerada + v_dep_mensual_anterior;
               else
                  v_dep_acumulada_acelerada := v_dep_anterior + v_dep_actual_acelerada;
               end if;
               v_val_neto_acelerado      := v_rev_actual - v_dep_acumulada_acelerada;
           end if;
        else
           if  v_dep_acumulada >= v_rev_actual then
              v_dep_mensual   := v_dep_mensual + v_val_neto - 1 ;
              v_dep_actual    := v_dep_mensual + v_rev_dev;
              if to_char(p_fec_proceso,'MM') <> '01' then
                 v_dep_acumulada := r_bien.dep_acumulada + v_dep_actual; --v_dep_anterior + v_dep_actual + v_dep_mensual_anterior;
              else
                 v_dep_acumulada := v_dep_anterior + v_dep_actual;
              end if;
              v_val_neto      := v_rev_actual - v_dep_acumulada;
           end if;
        end if;
        -----
     elsif r_bien.ind_depreciacion = 'N' then ---
          /*Obtengo el valor neto del proceso*/
        v_val_neto := v_rev_actual - v_dep_acumulada;
          /*Obtengo el valor neto acelerado del proceso  KF*/
        v_val_neto_acelerado := v_rev_actual - v_dep_acumulada_acelerada;
      -----
        if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
           if v_dep_acumulada_acelerada >= v_rev_actual then
              v_dep_mensual_acelerada   := v_dep_mensual_acelerada + v_val_neto_acelerado - 1 ;
              v_dep_actual_acelerada    := v_dep_mensual_acelerada + v_rev_dev;
              if to_char(p_fec_proceso,'MM') <> '01' then
                 v_dep_acumulada_acelerada := r_bien.dep_acumulada + v_dep_actual_acelerada; --v_dep_anterior + v_dep_actual_acelerada + v_dep_mensual_anterior;
              else
                 v_dep_acumulada_acelerada := v_dep_anterior + v_dep_actual_acelerada;
              end if;
                 v_val_neto_acelerado      := v_rev_actual - v_dep_acumulada_acelerada;
           end if;
        else
           if v_dep_acumulada >= v_rev_actual then
              v_dep_mensual   := v_dep_mensual + v_val_neto - 1 ;
              v_dep_actual    := v_dep_mensual + v_rev_dev;
              if to_char(p_fec_proceso,'MM') <> '01' then
                 v_dep_acumulada :=  r_bien.dep_acumulada + v_dep_actual;-- v_dep_anterior + v_dep_actual + v_dep_mensual_anterior;
              else
                 v_dep_acumulada := v_dep_anterior + v_dep_actual;
              end if;
                 v_val_neto      := v_rev_actual - v_dep_acumulada;
          end if;
       end if;
        -----
     end if;
   end if;
    /*
    || Cuando el bien ya se deprecia por completo, el saldo debe ser 0
    || y se ajusta la depreciación acumulada para que no supere al valor revaluado.
    */
   if fug_obt_tip_implementacion <> 1 then
      if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then
         if v_dep_acumulada_acelerada > v_rev_actual then
            v_mto_ajustar := v_dep_acumulada_acelerada - v_rev_actual;
            v_dep_acumulada_acelerada := v_rev_actual;
            v_val_neto_acelerado := 1;
            v_dep_actual_acelerada := v_dep_actual_acelerada - v_mto_ajustar;
            v_dep_mensual_acelerada := v_dep_actual_acelerada;
            v_rev_dev := 0;
         end if;
      else
         if v_dep_acumulada > v_rev_actual  then
            v_mto_ajustar := v_dep_acumulada - v_rev_actual;
            v_dep_acumulada := v_rev_actual;
            v_val_neto := 1;
            v_dep_actual := v_dep_actual - v_mto_ajustar;
            v_dep_mensual := v_dep_actual;
            v_rev_dev := 0;
          end if;
      end if;
   end if;
   -- al.ferreira - 26/01/2012
   -- Cuando el bien ya se deprecia por completo, el revaluo anterior debe ser el rev. actual
   /*if v_fec_actual > r_bien.fec_vto_depreciacion and fug_obt_tip_implementacion = 1 then
      v_rev_anterior := v_rev_actual;
   end if;*/ --ya no aplica, solucionado con AP 2797 - 02/02/2012
   if ((nvl(r_bien.val_neto,0) = 1) or 
       (r_bien.deprecia = 'N'))
     and fug_obt_tip_implementacion = 1 and
      r_bien.rev_anterior - r_bien.dep_acumulada <> 1 and
      r_bien.rev_actual - r_bien.dep_acumulada = 1 and
      v_fec_actual < r_bien.fec_vto_depreciacion then
      v_rev_anterior := v_rev_actual;
   end if;
   --- rabf/KF - 27/12/2011 - Proceso anual deja Valor Neto en Negativo
   if p_tipo_coe = 'A' then
      if v_val_neto_acelerado < 1 then
         v_val_neto_acelerado := 1;
         v_dep_acumulada_acelerada := v_rev_actual - v_val_neto_acelerado;
      end if;
      if v_val_neto < 1 then
         v_val_neto := 1;
         v_dep_acumulada := v_rev_actual - v_val_neto;
      end if;

    /* FM dydmr 1484 29/12/2014 */
   if to_number(to_char(r_bien.fec_vto_depreciacion,'yyyymm')) < to_number(to_char(p_fec_proceso,'yyyymm'))
     and v_val_neto <> 1 then
       v_mto_ajustar_1   := nvl(v_rev_actual,0) - nvl(v_dep_acumulada,0) - 1;
       v_dep_acumulada := nvl(v_dep_acumulada,0) + nvl(v_mto_ajustar_1,0);
       v_dep_actual    := nvl(v_dep_actual,0) + nvl(v_mto_ajustar_1,0);
       v_val_neto := 1;
   end if; /*FM dydmr 1484*/

  end if;
  /*
  || DYDMR-868 - SC 4883 SPI-2591 Vencimiento Depreciación AP
  || Cumplido el plazo del vencimiento de la depreciación (FEC_VTO_DEPRECIACION)
  || depreciar totalmente el bien en ese mes (DEP_MENSUAL)
  || y ajustar la depreciacion acumulada (DEP_ACUMULADA).
  || La diferencia entre el valor revaluado y la depreciación acumulada debe ser 1
  || (REV_ACTUAL - DEP_ACUMULADA = 1).
  */
   if to_number(to_char(r_bien.fec_vto_depreciacion,'yyyymm')) = to_number(to_char(p_fec_proceso,'yyyymm'))/*and
      v_val_neto = 1  /*FM dydmr 1484 29/12/2014 */ then
      if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado then --bien con Depreciación Acelada
         if nvl(v_rev_actual,0) - nvl(v_dep_acumulada_acelerada,0) <> 1 then
            v_mto_ajustar             := nvl(v_rev_actual,0) - nvl(v_dep_acumulada_acelerada,0) - 1;
            v_dep_acumulada_acelerada := nvl(v_dep_acumulada_acelerada,0) + v_mto_ajustar;
            v_dep_actual_acelerada    := nvl(v_dep_actual_acelerada,0) + v_mto_ajustar;
            v_dep_mensual_acelerada   := nvl(v_dep_actual_acelerada,0);
         end if;
      else
         if nvl(v_rev_actual,0) - nvl(v_dep_acumulada,0) <> 1 then
            --v_mto_ajustar   := nvl(v_rev_actual,0) - nvl(v_dep_acumulada,0) - 1;
            v_dep_acumulada := nvl(v_dep_acumulada,0) + nvl(v_mto_ajustar,0);
            v_dep_actual    := nvl(v_dep_actual,0) + nvl(v_mto_ajustar,0);
            --v_dep_mensual   := nvl(v_dep_actual,0);
            -- El calculo real debe ser la depresiacion mensual más el mto ajustar --
            v_dep_mensual    := nvl(v_dep_mensual,0) + nvl(v_mto_ajustar,0); -- RABP - DYDMR-3281 (05-2016)
         end if;
      end if;
      v_val_neto := 1; /*FM dydmr 1484 29/12/2014  */
   end if;
   --- Actualizo el bien con Depreciación Normal
   if r_bien.ano_depreciacion > r_bien.ano_dep_acelerado and fug_obt_tip_implementacion = 1 then
      update af_bienes_tmp
      set rev_anterior   = v_rev_anterior,
      rev_actual         = v_rev_actual,
      ---
      coeficiente        = v_coeficiente,
      fec_proceso        = p_fec_proceso,
      tip_proceso        = p_tipo_coe,
      ---
      dep_anterior       = v_dep_anterior,
      dep_anual          = v_dep_anual_acelerada,
      dep_mensual        = v_dep_mensual_acelerada,
      rev_depreciacion   = nvl(v_rev_dev,0),
      dep_actual         = v_dep_actual_acelerada,
      dep_acumulada      = v_dep_acumulada_acelerada,
      dep_mensual_normal = v_dep_mensual,
      ---
      val_neto         = v_val_neto_acelerado
      where  cod_bien  = r_bien.cod_bien;
      ---
      if p_tipo_coe = 'A' then
        update af_bienes_tmp
        set rev_ano_acumulado  = 0,
            rev_ano_anterior = v_rev_actual,
            dep_ano_acu_anterior = v_dep_actual_acelerada
        where cod_bien = r_bien.cod_bien;
      /* Para los Bienes nuevos debe tomar la depreciacion anterior para actualizar
          la depreciación anterior */
      elsif p_tipo_coe = 'M' and last_day(add_months(r_bien.fec_compra,2))  = last_day(p_fec_proceso) then
        update af_bienes_tmp
        set rev_ano_Anterior   = v_rev_ano_anterior,
            rev_ano_acumulado  = v_rev_ano_acumulado
           -- dep_ano_acu_anterior = v_dep_anterior
        where cod_bien = r_bien.cod_bien;
      elsif p_tipo_coe = 'M' then
        update af_bienes_tmp
        set rev_ano_Anterior   = v_rev_ano_anterior,
            rev_ano_acumulado  = v_rev_ano_acumulado,
            dep_ano_acu_anterior = r_bien.dep_ano_acu_anterior
        where cod_bien = r_bien.cod_bien;
      end if;
    ---
   else
      --- Actualizo el Bien con Depreciación Acelerada
      update af_bienes_tmp
      set    rev_anterior  = v_rev_anterior,
      rev_actual           = v_rev_actual,
      ---
      coeficiente      = v_coeficiente,
      fec_proceso      = p_fec_proceso,
      tip_proceso      = p_tipo_coe,
      ---
      dep_anterior     = v_dep_anterior,
      dep_anual        = v_dep_anual,
      dep_mensual      = v_dep_mensual,
      rev_depreciacion = v_rev_dev,
      dep_actual       = v_dep_actual,
      dep_acumulada    = v_dep_acumulada,
      dep_mensual_normal = v_dep_mensual,
      ---
      val_neto         = v_val_neto
      where  cod_bien  = r_bien.cod_bien;
      ---
      if p_tipo_coe = 'A' then
        update af_bienes_tmp
        set rev_ano_acumulado  = 0,
            rev_ano_anterior = v_rev_actual,
            dep_ano_acu_anterior = v_dep_actual
        where cod_bien = r_bien.cod_bien;
       /* Para los Bienes nuevos debe tomar la depreciacion anterior para actualizar
          la depreciación anterior */
      elsif p_tipo_coe = 'M' and last_day(add_months(r_bien.fec_compra,2))  = last_day(p_fec_proceso) then
        update af_bienes_tmp
        set rev_ano_Anterior = v_rev_ano_anterior,
            rev_ano_acumulado  = v_rev_ano_acumulado
           -- dep_ano_acu_anterior = v_dep_anterior
        where cod_bien = r_bien.cod_bien;
      elsif p_tipo_coe = 'M' then
        update af_bienes_tmp
        set rev_ano_Anterior = v_rev_ano_anterior,
            rev_ano_acumulado  = v_rev_ano_acumulado,
            dep_ano_acu_anterior = r_bien.dep_ano_acu_anterior
        where cod_bien = r_bien.cod_bien;
      end if;
   end if;
   --- rabf/KF - 27/12/2011
   --- Si el bien se compró dentro del periodo se debe tomar la depreciación actual
   if p_tipo_coe = 'A' and
      to_number(to_char(r_bien.fec_compra, 'yyyy')) = to_number(to_char(p_fec_proceso, 'yyyy')) then
      update af_bienes_tmp set dep_acumulada = dep_actual where cod_bien = r_bien.cod_bien;
   end if;
end loop;

   --Bienes adquiridos durante el mes
for reg in c_bienes_mes_actual loop
    --Halla Dep Mensual s/ Porc Depreciable - Decreto 2019--
    v_val_dep_mensual := 0;
    v_val_dep_mensual := round((reg.val_compra*(reg.por_val_dep_bien/100))/reg.mes_vid_util);
    -----------
    insert into af_bienes_tmp
    (cod_bien, cod_articulo, descripcion, cod_oficina, cod_area,
    nro_serie, val_compra, cod_moneda, fec_compra, cod_ent_proveedor,
    nro_factura, tipo, coeficiente, fec_vto_depreciacion, rev_anterior,
    rev_actual, dep_anterior, dep_anual, dep_mensual, rev_depreciacion,
    dep_actual, dep_acumulada, val_neto, fec_proceso, tip_proceso,
    estado, fec_enajenacion, dep_mensual_normal)
    values
    (reg.cod_bien, reg.cod_articulo, reg.descripcion, reg.cod_oficina, reg.cod_area,
    reg.nro_serie, reg.val_compra, reg.cod_moneda, reg.fec_compra, reg.cod_ent_proveedor,
    reg.nro_factura, reg.tipo, reg.coeficiente, reg.fec_vto_depreciacion, reg.rev_anterior,
    reg.val_compra, reg.dep_anterior, reg.dep_anual, v_val_dep_mensual, reg.rev_depreciacion,
    0, 0, reg.val_compra, reg.fec_proceso, reg.tip_proceso,
    reg.estado, reg.fec_enajenacion, reg.dep_mensual_normal);
end loop;

    --Actualizacion del Valor Neto para inmuebles
  if fug_obt_tip_implementacion <> 1 then
    update af_bienes_tmp x set x.val_neto = x.rev_actual
    where exists (select y.cod_bien
                  from af_bienes_tmp y, af_articulos z
                   where y.cod_articulo = z.cod_articulo
                   and z.cod_tip_articulo = 7
                   and y.cod_bien = x.cod_bien);
  end if;
  --Actualizar val neto de fec_ven_dep del mes--
  if p_tipo_coe = 'M' then
     update af_bienes_tmp x
        set x.val_neto = nvl(x.rev_actual,0) - nvl(x.dep_acumulada,0);
  end if;

end;
/


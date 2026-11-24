CREATE OR REPLACE PROCEDURE IT.PRP_REN_PRE_TAS_VAR_CIERRE
IS
 v_fec_actual       date:=pag_cal.FU_OBT_FEC_ACTUAL(6);
 v_nro_sol number(20);
 v_nro_cta number(20);
 v_rec_afd ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('REC_AFD_TASA_VARIABLE'),'N');
 v_fec_afd date;
 v_lugar   varchar2(3000);
 v_error   varchar2(1);
 
 v_cod_periodo_afd varchar2(10);
 v_cod_modulo_afd number;
 v_cod_modalidad_afd number;
 v_cod_sub_modalidad_afd number;
 v_cod_moneda_afd varchar2(10);


/*Para prestamos que no son AFD*/
Cursor g_principal IS
    select a.nro_cuota,b.cod_modulo,b.cod_modalidad,b.cod_moneda,
       b.nro_solicitud, c.nro_cuenta, b.cod_persona, b.cod_periodo,b.cod_sub_modalidad
       from pr_tas_variables_det a, pr_tas_variables b, pr_cta_prestamos c, pr_tip_operaciones d
         where a.fec_vencimiento <= v_fec_actual
          and a.renegociacion='S'
          and a.nro_solicitud=b.nro_solicitud
          and a.nro_solicitud=c.nro_solicitud
          and a.fec_renegociacion is null
          --
          and b.cod_modulo= d.cod_modulo
          and b.cod_modalidad= d.cod_modalidad
          and b.cod_sub_modalidad= d.cod_sub_modalidad
          and d.re_calcular='S'
          AND C.ESTADO <> 'N'
          --
          and b.nro_cuenta is not null; --Ya tiene una cuenta de prestamos

/*Para AFD*/
Cursor g_afd IS
    select  distinct c.nro_cuenta,b.cod_persona, a.nro_solicitud
       from pr_tas_variables_det a, pr_tas_variables b, pr_cta_prestamos c, pr_tip_operaciones d
        where a.fec_vencimiento <= v_fec_afd --Afd es al primero de Enero del A¿o Actual el re-calculo
          and a.nro_solicitud=b.nro_solicitud
          and a.nro_solicitud=c.nro_solicitud
          and b.cod_modulo= d.cod_modulo
          and b.cod_modalidad= d.cod_modalidad
          and b.cod_sub_modalidad= d.cod_sub_modalidad
          and d.re_calcular='N'
          AND C.ESTADO <> 'N'
          and b.nro_cuenta is not null; --Ya tiene una cuenta de prestamos;


 /*Inserta Log de Error*/
   PROCEDURE LP_INS_LOG_ERROR(p_fec_reproceso    in date default null,
                           p_nro_solicitud     in  varchar2 default null,
                           p_nro_cuenta        in  varchar2 default null,
                           p_lugar             in  varchar2 default null,
                           p_det_error         in  varchar2 default null
                           );

/*Inserta Log de Error*/
 PROCEDURE LP_INS_LOG_ERROR(p_fec_reproceso    in date default null,
                           p_nro_solicitud     in  varchar2 default null,
                           p_nro_cuenta        in  varchar2 default null,
                           p_lugar             in  varchar2 default null,
                           p_det_error         in  varchar2 default null
                           )
  is
  PRAGMA AUTONOMOUS_TRANSACTION;
v_hora varchar2(8);
BEGIN
  v_hora:=  to_char(sysdate, 'hh24:mi:ss');
insert into pr_log_tas_variables(fecha,nro_solicitud,nro_cuenta, lugar,
       det_error,hora,usuario,  fec_error,automatico)
values (p_fec_reproceso, p_nro_solicitud, p_nro_cuenta, p_lugar,
       p_det_error,v_hora,user,  sysdate,'S');
       commit;

exception
   when others then
     null;
End;

/* Verifica si es inhibido judicialmente*/
FUNCTION FU_ES_CLI_INHIBIDO(p_cod_persona varchar2)  RETURN VARCHAR2 IS
  v_tiene varchar2(1) := 'N';
BEGIN
  begin
   Select 'S'
     into v_tiene
       from ge_per_inhibidas b
         where  estado = 'I'
           and b.cod_persona= p_cod_persona
           and b.cod_causa=279; --279 demanda Judicial
  exception
    when no_data_found then
      v_tiene:='N';
    when too_many_rows then
      v_tiene:='S';
    when others then
      v_tiene:='N';
  end ;

  RETURN v_tiene;
END;

/* Validamos los que se pueda validar*/
FUNCTION FU_VAL_DATOS(p_cod_persona varchar2, p_nro_solicitud varchar2, 
  p_nro_cuenta varchar2,p_cod_periodo varchar2, p_es_afd varchar, p_nro_cuota number,
  p_cod_modulo number, p_cod_modalidad number, p_cod_sub_modalidad number, p_cod_moneda varchar2)
  RETURN VARCHAR2 IS
PRAGMA AUTONOMOUS_TRANSACTION;--Variables
  v_pue_procesar varchar2(1) := 'S';
  v_procesar varchar2(1) := 'N';
    ---
  v_val_tasa_nva     number(18,4);
  v_val_spread       number(18,4);
  v_val_tas_variable number(18,4);
  v_cod_persona      ba_personas.cod_persona%type;
  v_cod_periodo      pr_tas_variables.cod_periodo%type;
  v_lugar            varchar2(3000);
  v_cod_tasa_fondo   number(20);
  v_nro_cuenta       ge_cuentas.nro_cuenta%type;
  v_mto_capital_tas  pr_cta_prestamos.mto_capital%type;
  v_fec_actual       date:=pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_rec_afd          ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('REC_AFD_TASA_VARIABLE'),'N');
  v_fec_afd       date;
  v_cod_sub_modalidad varchar2(10);
  v_nro_sol varchar2(100);
  v_nro_cta varchar2(100);
  v_exi_sol_cuotas      varchar2(1);
  v_cod_tas_variable VARCHAR2(20);
  WW_DIA_CALCULO     NUMBER;
  v_val_tas_piso pr_solicitudes.tas_piso%type;
  v_valor number(18,4);
  v_valor1 number(18,4);
  v_per_act_tasa varchar2(10);
  v_fec_act_tasa date;
  v_fec_max_neg_tasa date;
  v_tas_actual number(18,4);
  v_tas_actual_v varchar2(30);

  v_prox_fec_ren date;
  v_nro_cuo_afd number(18);
  v_pri_vez    number(15);
  v_tot_prestamo      number;
   v_plazo            pr_solicitudes.dia_plazo%type;
  v_estado           pr_cta_prestamos.estado%type;
  v_tipo             pr_cta_prestamos.tipo%type;
  v_tip_interes      pr_cta_prestamos.tip_interes%type;
  v_tip_renovacion   pr_cta_prestamos.tip_renovacion%type;
  v_piz_tasa_min     cr_piz_plazos.tas_minima%type;
  v_piz_tasa_max     cr_piz_plazos.tas_maxima%type;
  v_piz_tasa_actual  cr_piz_plazos.tas_interes%type;
  v_piz_tasa_tae     cr_piz_plazos.tas_efectiva%type;
BEGIN
  --Si es Inhibido, no procesa
  if FU_ES_CLI_INHIBIDO(p_cod_persona)='S' then
     LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,'Cliente Inhibido');
    v_pue_procesar:= 'N';
    return v_pue_procesar;
  end if; 
  --Sinotiene cod_periodo, no procesa
  IF p_cod_periodo is null then
        v_lugar:='No encuentra datos de solicitud en Tasa Variable. Nro.Sol:'||p_nro_solicitud || 'Nro.Cuenta:'||p_nro_cuenta;
        LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,'Periodo no Cargado');
        v_pue_procesar:= 'N';
        return v_pue_procesar;
  end if;

  if p_es_afd='N' then 
         v_per_act_tasa:= null;
         v_cod_periodo:= null;
        --Obtenemos el periodo
        begin
         select b.abreviatura,a.cod_periodo
             into v_per_act_tasa,v_cod_periodo
             from pr_tas_variables a, ba_cod_referencias b
            where a.nro_cuenta = p_nro_cuenta
              and b.dominio='PER_REP_TAS_VARIABLE'
              and a.cod_periodo= b.val_minimo;
         exception
           when no_data_found then
              v_per_act_tasa := null;
           when others then
              v_per_act_tasa := null;
         end;
         --Verificamos si la tasa se actualiz¿ en el a¿o
         -- Valores A- Anual / M- Mensual/ S-Semestral
         v_procesar := 'N';
         v_fec_act_tasa:= null;
         v_lugar:='Validando act de Tasa de Periodo';
         if v_per_act_tasa is not null then
                 begin
                     select max(a.fecha)
                         into v_fec_act_tasa
                         from PR_TAS_REFERENCIAS A
                        where a.Cod_Periodo= v_cod_periodo;
                     exception
                       when no_data_found then
                          v_fec_act_tasa := null;
                       when others then
                          v_fec_act_tasa := null;
                 end;

                 if v_fec_act_tasa is null then
                    v_procesar := 'N';
                    v_lugar:='Val.Act.Tas- No se encuentra tasa parametrizada p/ Periodo: '||v_cod_periodo;
                 else
                   if  v_per_act_tasa = 'A' then
                       --Anual
                       if to_char(v_fec_act_tasa,'yyyy')=  to_char(v_fec_actual,'yyyy') then
                          v_procesar := 'S';
                       else
                          v_lugar:='Val.Act.Tas- No se encuentra tasa Anual parametrizada p/ Periodo: '||v_cod_periodo;
                          v_procesar := 'N';
                       end if;
                   elsif  v_per_act_tasa = 'M' then
                       --Mensual
                       if to_char(v_fec_act_tasa,'yyyymm')=  to_char(v_fec_actual,'yyyymm') then
                          v_procesar := 'S';
                       else
                         v_lugar:='Val.Act.Tas- No se encuentra tasa Mensual parametrizada p/ Periodo: '||v_cod_periodo;
                          v_procesar := 'N';
                       end if;
                   elsif  v_per_act_tasa = 'S' then
                       --Semestral
                        if to_char(v_fec_act_tasa,'yyyy')=  to_char(v_fec_actual,'yyyy') then
                           --Si es el mismo semestre
                           if floor (((to_char (v_fec_act_tasa, 'mm')) - 1) / 6) + 1 =  floor (((to_char (v_fec_actual, 'mm')) - 1) / 6) + 1 then
                             v_procesar := 'S';
                           else
                             v_lugar:='Val.Act.Tas- No se encuentra tasa Semestral parametrizada p/ Periodo: '||v_cod_periodo;
                             v_procesar := 'N';
                           end if;

                       else
                          v_lugar:='Val.Act.Tas- No se encuentra tasa Semestral. parametrizada p/ Periodo: '||v_cod_periodo;
                          v_procesar := 'N';
                       end if;
                   elsif  v_per_act_tasa = 'T' then
                       --TRIMESTRAL
                       if to_char(v_fec_act_tasa,'yyyy')=  to_char(v_fec_actual,'yyyy') then
                         if to_char(v_fec_act_tasa,'q')=  to_char(v_fec_actual,'q') then
                           v_procesar := 'S';
                         else
                           v_lugar:='Val.Act.Tas- No se encuentra tasa trimestral parametrizada p/ Periodo: '||v_cod_periodo;
                           v_procesar := 'N';
                         end if;

                       else
                          v_lugar:='Val.Act.Tas- No se encuentra tasa trimestral. parametrizada p/ Periodo: '||v_cod_periodo;
                          v_procesar := 'N';
                       end if;
                   else
                       v_procesar := 'N';
                   end if;
                 end if;
         else
           v_procesar := 'N';
           v_lugar:='Val.Act.Tas- No se encuentra Periodo parametrizado: '||v_cod_periodo;

         end if;
      --Si es N,no purde procesar, se guarda error   
      If v_procesar = 'N' then
         LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,v_lugar);
         v_pue_procesar:='N';
         RETURN v_pue_procesar;
       end if;
     --Seguimos con validaciones para no AFD
      
     --**************OBTENEMOS VALORES DE TASAS A APLICAR *******
     --v_val_tasa_nva:= p_val_tasa_nva;
     v_lugar:='Obtener Tasa Variable. Nro.Sol:'||p_nro_solicitud|| 'Nro.Cuenta:'||p_nro_cuenta;
     PRG_OBT_VAL_TAS_VARIABLE(p_nro_solicitud,v_fec_actual,'T',NULL,NULL,NULL,v_cod_tas_variable,v_val_tas_variable) ;
     v_lugar:='Obtener Spread. Nro.Sol:'||p_nro_solicitud || 'Nro.Cuenta:'|| p_nro_cuenta;
     PRG_OBT_VAL_TAS_VARIABLE(p_nro_solicitud,v_fec_actual,'S',NULL,NULL,NULL,v_cod_tas_variable,v_val_spread) ;
     v_lugar:='Tasa Nueva. Nro.Sol:'||p_nro_solicitud || 'Nro.Cuenta:'|| p_nro_cuenta;
     PRG_OBT_VAL_TAS_VARIABLE(p_nro_solicitud,v_fec_actual,'F',NULL,NULL,NULL,v_cod_tas_variable,v_val_tasa_nva);
     --*************************************************************
     --Verificamos la Tasa anterior (Con la que se negocio la ultima vez)
     --*****Buscamos del Detalle de Tasa Variable
     v_fec_max_neg_tasa:=null;
     v_tas_actual:=null;
     begin
        select max(a.fec_vencimiento)
         into v_fec_max_neg_tasa
          from pr_tas_variables_det a
            where a.nro_solicitud= p_nro_solicitud
              and a.renegociacion='S'
              and a.tas_utilizada is not null
              and a.tas_referencia is not null
              and a.spread is not null;
     exception
       when no_data_found then
          v_fec_max_neg_tasa:=null;
       when others then
          v_fec_max_neg_tasa:=null;
     end;

     if v_fec_max_neg_tasa is not null then
         begin
         select a.tas_utilizada
           into v_tas_actual
            from pr_tas_variables_det a
              where a.nro_solicitud= p_nro_solicitud
                and a.renegociacion='S'
                and a.tas_utilizada is not null
                and a.fec_vencimiento=v_fec_max_neg_tasa;
          exception
             when others then
               v_tas_actual:= null;
          end;

       if v_tas_actual = v_val_tasa_nva then
          update pr_tas_variables_det a
            set a.fec_renegociacion= v_fec_actual,
               a.spread=  v_val_spread,
               a.tas_referencia= v_val_tas_variable,
               a.tas_utilizada= v_val_tasa_nva
           where nro_solicitud  = p_nro_solicitud
              and nro_cuota   = p_nro_cuota;
           commit;
            LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,'Tasa Actual igual a la nueva I: '||v_tas_actual||' Nro.Cuenta:'||p_nro_cuenta || 'No se re-procesara.');
            v_pue_procesar:='N';
            RETURN v_pue_procesar;
           -- raise_application_error(-20000,'Tasa Actual igual a la nueva: '||v_tas_actual||' Nro.Cuenta:'||w.nro_cuenta|| 'No se re-procesara.');
       end if;
     else
        --Buscamos en la cabecera
          begin
           select a.tas_interes
             into v_tas_actual/*v_tas_actual*/
              from pr_tas_variables a
                where a.nro_solicitud= p_nro_solicitud;
            exception
               when others then
                 v_tas_actual:= null;
            end;

          if nvl(v_tas_actual/*v_tas_actual*/,0) = nvl(to_char(v_val_tasa_nva),0) then
            update pr_tas_variables_det a
              set a.fec_renegociacion= v_fec_actual,
                 a.spread=  v_val_spread,
                 a.tas_referencia= v_val_tas_variable,
                 a.tas_utilizada= v_val_tasa_nva
              where nro_solicitud  = p_nro_solicitud
                 and nro_cuota   = p_nro_cuota;
             commit;
            LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,'Tasa Actual igual a la nueva II: '||v_tas_actual||' Nro.Cuenta:'||p_nro_cuenta || 'No se re-procesara.');
            v_pue_procesar:='N';
            RETURN v_pue_procesar;  
            --raise_application_error(-20000,'Tasa Actual igual a la nueva: '||v_tas_actual||' Nro.Cuenta:'||w.nro_cuenta|| 'No se re-procesara..');
          end if;
      end if;

     --Validar Tasa piso
     v_lugar:='Validar Tasa Piso. Nro.Sol:'||P_nro_solicitud || 'Nro.Cuenta:'|| P_nro_cuenta;
     if nvl(v_val_tas_piso,0) > 0 then
       if nvl(v_cod_tas_variable,'N')= 'N' then
          if v_val_tasa_nva < v_val_tas_piso then
              v_val_tasa_nva:=v_val_tas_piso;
          end if;

          if v_tas_actual = v_val_tasa_nva then
              update pr_tas_variables_det a
                set a.fec_renegociacion= v_fec_actual,
                   a.spread=  v_val_spread,
                   a.tas_referencia= v_val_tas_variable,
                   a.tas_utilizada= v_val_tasa_nva
               where nro_solicitud  = p_nro_solicitud
                  and nro_cuota   =p_nro_cuota;
               commit;
              LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,'Tasa Actual igual a la nueva III: '||v_tas_actual||' Nro.Cuenta:'||p_nro_cuenta || 'No se re-procesara.');
              v_pue_procesar:='N';
              RETURN v_pue_procesar;
             --raise_application_error(-20000,'Tasa Actual igual a la nueva: '||v_tas_actual||' Nro.Cuenta:'||w.nro_cuenta|| 'No se re-procesara...');
          end if;
       end if;
     end if;
    --************ Fin de ajuste para Tasa Variable  
  end if;
     --Seguimos validando
     --Traer cantidad de cuotas
  begin 
    select sum(sal_capital)
       into v_tot_prestamo
       from pr_cuotas o
      where o.nro_cuenta = P_nro_cuenta
        --Se ajusta para Tasa Variable a pedido de usuario
        and o.fec_vencimiento > v_fec_actual
        --and o.estado = 'C'
        and o.estado <> 'N' --DYDMR-7316 y DYDMR-7300
        and o.sal_interes <> 0;
    exception
       when others then
        v_tot_prestamo:= null;
    end;    
        
        
    begin    
     select a.dia_plazo
       into v_plazo
      from pr_solicitudes a 
        where a.nro_solicitud=p_nro_solicitud;   
     exception
       when others then
          v_plazo:= null;
     end;   
    -- 
    v_lugar:='Para pap_pre.pr_obt_tas_pizarra. Nro.Sol: '||p_nro_solicitud || ' Nro.Cuenta: '|| p_nro_cuenta;
     pap_pre.pr_obt_tas_pizarra(p_cod_modulo, p_cod_modalidad, p_cod_moneda,
                                v_plazo, v_tot_prestamo, null,
                                v_piz_tasa_min,
                                v_piz_tasa_max,
                                v_piz_tasa_actual,
                                v_piz_tasa_tae,
                                p_cod_sub_modalidad); -- JIRA 1559

     If nvl(v_piz_tasa_min,0) = 0 and nvl(v_piz_tasa_max,0) = 0 and nvl(v_piz_tasa_actual,0) = 0 then
        v_lugar:='Debe definir la Pizarra para el Tipo de Pr¿stamo. Nro.Sol:'||p_nro_solicitud || 'Nro.Cuenta:'|| p_nro_cuenta;
        LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,'Verificar Pizarra');
        v_pue_procesar:='N';
        RETURN v_pue_procesar;
     End if;

  RETURN v_pue_procesar;
exception
    when others then
     v_lugar:='Error al validar:'|| sqlerrm;
     LP_INS_LOG_ERROR(sysdate,null,p_nro_cuenta,v_lugar,' Validacion Inicial');
     v_pue_procesar:='N';
    RETURN v_pue_procesar; 
END;
--*****************************



/* Obtiene Tasa Piso*/
FUNCTION FU_OBT_TAS_PISO(p_nro_solicitud number)  RETURN number IS
  v_tas_piso number(20,4);
BEGIN
  begin
   Select nvl(b.tas_piso,0)
     into v_tas_piso
       from pr_solicitudes b
         where b.nro_solicitud= p_nro_solicitud;
  exception
    when no_data_found then
      v_tas_piso:=0;
    when too_many_rows then
      v_tas_piso:=0;
    when others then
      v_tas_piso:=0;
  end ;

  RETURN v_tas_piso;
END;


/*Notificamos que debe renegociar con el cliente*/
PROCEDURE lp_not_ren_tasa is
PRAGMA AUTONOMOUS_TRANSACTION;  
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  v_texto    varchar2(32000);
  v_det_error varchar2(4000);
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
   -- Variables para mail
  v_conn            utl_smtp.connection;
  v_asunto          VARCHAR2(2000);
  v_mje_mail        LONG;
  v_notificacion1   number(10):= nvl(fug_obt_pardinamico('DIAS_ANT_AVI_REN_TAS_VARIABLE'),9999);
  v_notificacion2   number(10):= nvl(fug_obt_pardinamico('DIAS_ANT_AVI_REN_TAS_VARIABLE1'),9999);
  v_fec_actual        date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
  --
  v_cod_gestor       varchar2(30);
  v_dir_correo_ges   varchar2(100);
  v_spread           number(18,4);
  v_tas_referencia   number(18,4);
  v_nro_solicitud    number(20);
  v_nro_not          number(20);
  v_val_tasa_nva     number(18,4);
  v_val_spread       number(18,4);
  v_cod_tas_variable number(18,4);
  v_cod_tas_var      varchar2(30);
  v_notificacion     varchar2(3000);
  v_sig_fec_reneg    date;
  v_tas_piso         number(20,4);

CURSOR g_noti_1 is
     select a.fec_vencimiento,a.nro_solicitud, b.cod_persona,a.nro_cuota,a.dia,
        b.cod_modalidad,b.cod_sub_modalidad,b.cod_moneda, b.descripcion,b.monto,b.tot_prestamo,
        c.nom_completo as cliente,a.renegociacion, b.cod_periodo, b.nro_cuenta, c.nom_completo
      from pr_tas_variables_det a, pr_tas_variables b, ba_personas c,  pr_tip_operaciones d
        where a.nro_solicitud=b.nro_solicitud
           and b.cod_persona=c.cod_persona
           and b.cod_modulo= d.cod_modulo
           and b.cod_modalidad= d.cod_modalidad
           and b.cod_sub_modalidad= d.cod_sub_modalidad
           and d.re_calcular='S'
           and a.renegociacion='S'
           and TRUNC(a.fec_vencimiento - v_notificacion1) <= v_fec_actual
           and not exists (select 1 from pr_not_tas_variables w
                 where w.nro_solicitud= a.nro_solicitud
                       and w.nro_cuota= a.nro_cuota
                       and w.nro_not=1 )
           and b.nro_cuenta is not null --Ya tiene una cuenta de prestamos
           and exists (select 1 from pr_Cta_prestamos p  --DYDMR-12583 que no incluya prestamos ya cancelados
                            where p.nro_cuenta = b.nro_cuenta
                            and p.estado <>'N'); 

CURSOR g_noti_2 is
     select a.fec_vencimiento,a.nro_solicitud, b.cod_persona,a.nro_cuota,a.dia,
        b.cod_modalidad,b.cod_sub_modalidad,b.cod_moneda, b.descripcion,b.monto,b.tot_prestamo,
        c.nom_completo as cliente,a.renegociacion, b.cod_periodo, b.nro_cuenta, c.nom_completo
      from pr_tas_variables_det a, pr_tas_variables b, ba_personas c,  pr_tip_operaciones d
        where a.nro_solicitud=b.nro_solicitud
           and b.cod_persona=c.cod_persona
           and b.cod_modulo= d.cod_modulo
           and b.cod_modalidad= d.cod_modalidad
           and b.cod_sub_modalidad= d.cod_sub_modalidad
           and d.re_calcular='S'
           and a.renegociacion='S'
           and TRUNC(a.fec_vencimiento - v_notificacion2) <= v_fec_actual
           and not exists (select 1 from pr_not_tas_variables w
                 where w.nro_solicitud= a.nro_solicitud
                       and w.nro_cuota= a.nro_cuota
                       and w.nro_not=2 )
           and b.nro_cuenta is not null --Ya tiene una cuenta de prestamos
           and exists (select 1 from pr_Cta_prestamos p  --DYDMR-12583 que no incluya prestamos ya cancelados
                            where p.nro_cuenta = b.nro_cuenta
                            and p.estado <>'N'); 
  
--Mejoras, notificación en el día que se re-procesa
CURSOR g_noti_3 is
     select a.fec_vencimiento,a.nro_solicitud, b.cod_persona,a.nro_cuota,a.dia,
        b.cod_modalidad,b.cod_sub_modalidad,b.cod_moneda, b.descripcion,b.monto,b.tot_prestamo,
        c.nom_completo as cliente,a.renegociacion, b.cod_periodo, b.nro_cuenta, c.nom_completo
      from pr_tas_variables_det a, pr_tas_variables b, ba_personas c,  pr_tip_operaciones d
        where a.nro_solicitud=b.nro_solicitud
           and b.cod_persona=c.cod_persona
           and b.cod_modulo= d.cod_modulo
           and b.cod_modalidad= d.cod_modalidad
           and b.cod_sub_modalidad= d.cod_sub_modalidad
           and d.re_calcular='S'
           and a.renegociacion='S'
           --Fecha de re-negociacion en el dia de sistema
           and TRUNC(a.fec_renegociacion) = v_fec_actual
           and not exists (select 1 from pr_not_tas_variables w
                 where w.nro_solicitud= a.nro_solicitud
                       and w.nro_cuota= a.nro_cuota
                       and w.nro_not=3 )
           and b.nro_cuenta is not null --Ya tiene una cuenta de prestamos
           and exists (select 1 from pr_Cta_prestamos p  --DYDMR-12583 que no incluya prestamos ya cancelados
                            where p.nro_cuenta = b.nro_cuenta
                            and p.estado <>'N'); 



BEGIN
--Notificaci¿n I,sino se parametriza no se envia la notificacion
if  v_notificacion1 <> 9999 then
 --Notificacion 1

   for a in g_noti_1 loop
   begin
    v_lugar:='Not 1.Verificar si es inhibido:'|| a.nro_solicitud;
    if FU_ES_CLI_INHIBIDO(a.cod_persona)='N' then --Es inhibido judicialmente
        --Obtener el gestor  del cliente
          v_lugar:='Not 1.Obtener codigo de oficial:'|| a.nro_solicitud||' Cod_persona: '||a.cod_persona;
          v_cod_gestor:= fug_obt_cod_usu_oficial(a.cod_persona);
          if v_cod_gestor is not null then
              v_lugar:='Not 1.Obtener mail de oficial:'|| a.nro_solicitud||' Cod_persona: '||a.cod_persona;
             --Dir mail del oficial o gestor
             begin
                v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
             exception
                when others then
                 v_dir_correo_ges:=null;
             end;
             if v_dir_correo_ges is not null then
                v_nro_solicitud:= a.nro_solicitud;
                v_nro_not:= 1;
                --No se envia estos datos en la noti de 20 dias antes
                --v_spread:= FUG_OBT_VAL_TAS_VARIABLE(a.cod_moneda,a.cod_persona,a.cod_periodo,a.nro_solicitud,v_fec_actual,'S','A',null) ;
                --v_tas_referencia:=FUG_OBT_VAL_TAS_VARIABLE(a.cod_moneda,a.cod_persona,a.cod_periodo,a.nro_solicitud,v_fec_actual,'T','A',null);
                  v_texto := '<br><br>
                           <br><br>
                           Buenas:
                           <br><br>'||
                           '  Le informamos que en ' ||v_notificacion1 || ' días, se debe renegociar el préstamo con tasa variable del cliente: '||
                           '( '||a.cod_persona ||' ) ' || a.cliente ||'<br>'||
                           ' Número de Propuesta: ' || a.nro_solicitud ||'<br>'||
                           ' Número de Cuenta: '   || a.nro_cuenta ||'<br>'||
                           ' Tipo: '||a.descripcion ||'<br>'||
                           ' Fecha de Renegociación: ' || to_char(a.fec_vencimiento, 'DD/MM/YYYY')||'<br>'||
                           ' Moneda: '|| a.cod_moneda|| '<br>'||
                           ' Monto: '|| trim(to_char(a.monto,'9G999G999G999G990D99')) ||'<br>'||
                           ' Favor gestionar con el cliente la variación de Tasa.' ||'<br><br>'||
                           '<br><br>
                           Atentamente.
                           <br><br>
                           <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                           <br><br>
                           <br><br>';

                  v_asunto   := 'Renegociación de Tasa Variable, Cliente: '|| a.nom_completo || ' Nro.Cuenta: '||a.nro_cuenta|| '(Not.1)';
                  v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                          chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
                  v_lugar:='Not 1.Insertar en log de Notif.:'|| a.nro_solicitud||' Cod_persona: '||a.cod_persona;
                   --insertamos en Tabla de Log antes de enviar
                  insert into pr_not_tas_variables(NRO_SOLICITUD,COD_PERSONA,NRO_CUOTA,COD_GESTOR,
                   FEC_VENCIMIENTO,FEC_NOTIFICACION,NRO_NOT,TEXTO,COD_SUPERIOR,DIR_MAIL_GES,
                   DIR_MAIL_SUP, TAS_REF_INFORMADA,SPREAD_INICIAL,SPREAD_FINAL, ASUNTO,
                   usu_insercion, fec_insercion,usu_modificacion, fec_modificacion,HUBO_ERROR)
                  values(a.nro_solicitud,a.cod_persona,a.nro_cuota,v_cod_gestor,
                   a.fec_vencimiento,v_fec_actual, v_nro_not, v_texto, null, v_dir_correo_ges,
                   null, v_tas_referencia,v_spread,v_spread, v_asunto,
                   user, sysdate, user, sysdate,'N');
                   commit;
                   v_lugar:='Not 1.Enviar mail:'|| a.nro_solicitud||' Cod_persona: '||a.cod_persona;
                  --atachamos y enviamos
                  v_conn     := it_mail.begin_mail(c_dir_mail,
                                                   v_dir_correo_ges,
                                                   v_asunto,
                                                   IT_MAIL.MULTIPART_MIME_TYPE);
                  it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                  it_mail.end_mail(v_conn);
              end if;
           end if;
  end if;
  exception
   when others then
      it_mail.end_mail(v_conn);
      v_det_error:=sqlerrm;
      LP_INS_LOG_ERROR(sysdate,v_nro_solicitud,'9999',v_lugar,sqlerrm);
      update pr_not_tas_variables c
        set c.det_error = v_det_error,
            c.fec_modificacion = sysdate,
            c.hubo_error='S'
         where c.nro_solicitud= v_nro_solicitud
           and c.nro_not= v_nro_not
           and trunc(c.fec_insercion)= trunc(sysdate);
        commit;
   end;
   end loop;

end if;
--Notificacion II,sino se parametriza no se envia la notificacion
if  v_notificacion2 <> 9999 then
    --Notificacion 2
  for b in g_noti_2 loop
   begin
    v_lugar:='Not 2.Obtener codigo de oficial:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
   if FU_ES_CLI_INHIBIDO(b.cod_persona)='N' then --Es inhibido judicialmente
         --Obtener el gestor  del cliente
          v_cod_gestor:= fug_obt_cod_usu_oficial(b.cod_persona);
          if v_cod_gestor is not null then
             --Dir mail del oficial o gestor
              v_lugar:='Not 2.Obtener mail de oficial:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
             begin
                v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
             exception
                when others then
                   v_dir_correo_ges:=null;
             end;
             v_notificacion:='Notif. 2';
             if v_dir_correo_ges is not null then
                v_lugar:='Not 2.Obtener valores de Spread:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                PRG_OBT_VAL_TAS_VARIABLE(b.nro_solicitud,v_fec_actual,'S',NULL,NULL,NULL,v_cod_tas_var,v_spread) ;
                v_lugar:='Not 2.Obtener valores de Tasa Ref.:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                PRG_OBT_VAL_TAS_VARIABLE(b.nro_solicitud,v_fec_actual,'T',NULL,NULL,NULL,v_cod_tas_var,v_tas_referencia) ;
                v_lugar:='Not 2.Obtener valores de Tasa Nueva:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                PRG_OBT_VAL_TAS_VARIABLE(b.nro_solicitud,v_fec_actual,'F',NULL,NULL,NULL,v_cod_tas_var,v_val_tasa_nva) ;
                --Obtenemos la tasa Piso
                v_tas_piso:=0;
                v_tas_piso:= FU_OBT_TAS_PISO(b.nro_solicitud);
                --Si es menor a la tasa obtenida, asignamos tasa Piso(Logica del re-calculo)
                if nvl(v_val_tasa_nva,0) < nvl(v_tas_piso,0) then
                   v_val_tasa_nva:= v_tas_piso;
                end if;
                v_nro_solicitud:= b.nro_solicitud;
                v_nro_not:= 2;
                v_texto := '<br><br>
                           <br><br>
                           Buenas:
                           <br><br>'||
                           '  Le informamos que en ' ||v_notificacion2 || ' días, se debe renegociar el préstamo con tasa variable del cliente: '||
                           '( '||B.cod_persona ||' ) ' || B.cliente ||'<br>'||
                           ' Número de Propuesta: ' || B.nro_solicitud ||'<br>'||
                           ' Número de Cuenta: '   || b.nro_cuenta ||'<br>'||
                           ' Tipo: '||B.descripcion ||'<br>'||
                           ' Fecha de Renegociación: ' || to_char(B.fec_vencimiento, 'DD/MM/YYYY')||'<br>'||
                           ' Moneda: '|| B.cod_moneda|| '<br>'||
                           ' Monto: '||trim(to_char(b.monto,'9G999G999G999G990D99')) ||'<br>'||
                           ' Spread Actual: '|| v_spread||'<br>'||
                           ' Tasa de Referencia: '|| v_tas_referencia||'<br><b>'||
                           ' Nueva Tasa: '|| v_val_tasa_nva||'</b><br><br>'||
                           ' Favor gestionar con el cliente la variación de Tasa.' ||'<br><br>'||
                           '<br><br>
                           Atentamente.
                           <br><br>
                           <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                           <br><br>
                           <br><br>';


                  v_asunto   := 'Renegociación de Tasa Variable, Cliente: '|| b.nom_completo || ' Nro.Cuenta: '||b.nro_cuenta|| '(Not.2)';
                  v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                          chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

                   v_lugar:='Not 2.Insertar en Log.:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                  --insertamos en Tabla de Log antes de enviar
                  insert into pr_not_tas_variables(NRO_SOLICITUD,COD_PERSONA,NRO_CUOTA,COD_GESTOR,
                   FEC_VENCIMIENTO,FEC_NOTIFICACION,NRO_NOT,TEXTO,COD_SUPERIOR,DIR_MAIL_GES,
                   DIR_MAIL_SUP, TAS_REF_INFORMADA,SPREAD_INICIAL,SPREAD_FINAL, ASUNTO,
                   usu_insercion, fec_insercion,usu_modificacion, fec_modificacion,HUBO_ERROR)
                  values(b.nro_solicitud,b.cod_persona,b.nro_cuota,v_cod_gestor,
                   b.fec_vencimiento,v_fec_actual, v_nro_not, v_texto, null, v_dir_correo_ges,
                   null, v_tas_referencia,v_spread,v_spread, v_asunto,
                   user, sysdate, user, sysdate,'N');
                   commit;
                  --atachamos y enviamos
                   v_lugar:='Not 2.Enviar email:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                  v_conn     := it_mail.begin_mail(c_dir_mail,
                                                   v_dir_correo_ges,
                                                   v_asunto,
                                                   IT_MAIL.MULTIPART_MIME_TYPE);
                  it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                  it_mail.end_mail(v_conn);
             end if;
           end if;
   end if;


  exception
   when others then
      it_mail.end_mail(v_conn);
      v_det_error:=sqlerrm;
      LP_INS_LOG_ERROR(sysdate,v_nro_solicitud,'9999',v_lugar,sqlerrm);
      update pr_not_tas_variables c
        set c.det_error = v_det_error,
            c.fec_modificacion = sysdate,
            c.hubo_error='S'
         where c.nro_solicitud= v_nro_solicitud
           and c.nro_not= v_nro_not
           and trunc(c.fec_insercion)= trunc(sysdate);
        commit;
   end;



  end loop;
end if;

 --Notificacion IIi,siempre se envia la notificacion
  for b in g_noti_3 loop
        begin
         v_lugar:='Not 3.Obtener codigo de oficial:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
         if FU_ES_CLI_INHIBIDO(b.cod_persona)='N' then --Es inhibido judicialmente
         --Obtener el gestor  del cliente
                v_cod_gestor:= fug_obt_cod_usu_oficial(b.cod_persona);
                if v_cod_gestor is not null then
                   --Dir mail del oficial o gestor
                    v_lugar:='Not 3.Obtener mail de oficial:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                   begin
                      v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
                   exception
                      when others then
                         v_dir_correo_ges:=null;
                   end;
                   v_notificacion:='Notif. 3';
                   if v_dir_correo_ges is not null then
                      --Obtenemos la proxima fecha de Renegociacion
                        begin
                          select min(a.fec_vencimiento)
                            into v_sig_fec_reneg
                             from pr_tas_variables_det a
                               where a.nro_solicitud= b.nro_solicitud
                                 and a.renegociacion='S'
                                  and a.fec_renegociacion is null
                                  and a.fec_vencimiento > trunc(v_fec_actual);
                          exception
                            when no_data_found then
                              v_sig_fec_reneg := null;
                             when others then
                              v_sig_fec_reneg := null;
                          end;
                      v_lugar:='Not 3.Obtener valores de Spread:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                        --Spread
                         begin
                           select w.spread
                             into v_spread
                              from pr_solicitudes w
                                where w.nro_solicitud= b.nro_solicitud;
                          exception
                            when no_data_found then
                              v_spread := null;
                             when others then
                              v_spread := null;
                          end;
                           v_lugar:='Not 3.Obtener valores de Tasa Nueva:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                         --Nueva Tasa aplicada
                          begin
                           select x.tas_utilizada
                             into v_val_tasa_nva
                              from pr_tas_variables_det x
                                where x.nro_solicitud= b.nro_solicitud
                                 and trunc(x.fec_renegociacion)= v_fec_actual;
                          exception
                            when no_data_found then
                              v_val_tasa_nva := null;
                             when others then
                              v_val_tasa_nva := null;
                          end;
                      v_nro_solicitud:= b.nro_solicitud;
                      v_nro_not:= 3;
                      v_texto := '<br><br>
                                 <br><br>
                                 Buenas:
                                 <br><br>'||
                                 '  Le informamos que fue modificada la nueva tasa del cliente Nro.: '||
                                 '( '||B.cod_persona ||' ) ' || B.cliente ||'<br>'||
                                 ' Número de Propuesta: ' || B.nro_solicitud ||'<br>'||
                                 ' Número de Cuenta: '   || b.nro_cuenta ||'<br>'||
                                 ' Tipo: '||B.descripcion ||'<br>'||
                                 ' Fecha de Renegociación: ' || to_char(v_sig_fec_reneg, 'DD/MM/YYYY')||'<br>'||
                                 ' Moneda: '|| B.cod_moneda|| '<br>'||
                                 ' Monto: '||trim(to_char(b.monto,'9G999G999G999G990D99')) ||'<br>'||
                                 ' Spread Actual: '|| v_spread||'<br>'||
                                 ' Tasa Aplicada: '|| v_val_tasa_nva||'</b><br><br>'||
                                 ' Favor informar al cliente la variación de Tasa.' ||'<br><br>'||
                                 '<br><br>
                                 Atentamente.
                                 <br><br>
                                 <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                                 <br><br>
                                 <br><br>';


                        v_asunto   := 'Renegociación de Tasa Variable, Cliente: '|| b.nom_completo || ' Nro.Cuenta: '||b.nro_cuenta|| '(Not.3)';
                        v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                                chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

                         v_lugar:='Not 3.Insertar en Log.:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                        --insertamos en Tabla de Log antes de enviar
                        insert into pr_not_tas_variables(NRO_SOLICITUD,COD_PERSONA,NRO_CUOTA,COD_GESTOR,
                         FEC_VENCIMIENTO,FEC_NOTIFICACION,NRO_NOT,TEXTO,COD_SUPERIOR,DIR_MAIL_GES,
                         DIR_MAIL_SUP, TAS_REF_INFORMADA,SPREAD_INICIAL,SPREAD_FINAL, ASUNTO,
                         usu_insercion, fec_insercion,usu_modificacion, fec_modificacion,HUBO_ERROR)
                        values(b.nro_solicitud,b.cod_persona,b.nro_cuota,v_cod_gestor,
                         b.fec_vencimiento,v_fec_actual, v_nro_not, v_texto, null, v_dir_correo_ges,
                         null, v_tas_referencia,v_spread,v_spread, v_asunto,
                         user, sysdate, user, sysdate,'N');
                         commit;
                        --atachamos y enviamos
                         v_lugar:='Not 3.Enviar email:'|| b.nro_solicitud||' Cod_persona: '||b.cod_persona;
                        v_conn     := it_mail.begin_mail(c_dir_mail,
                                                         v_dir_correo_ges,
                                                         v_asunto,
                                                         IT_MAIL.MULTIPART_MIME_TYPE);
                        it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                        it_mail.end_mail(v_conn);
                   end if;
              end if;
           end if;
        exception
         when others then
            it_mail.end_mail(v_conn);
            v_det_error:=sqlerrm;
            LP_INS_LOG_ERROR(sysdate,v_nro_solicitud,'9999',v_lugar,sqlerrm);
            update pr_not_tas_variables c
              set c.det_error = v_det_error,
                  c.fec_modificacion = sysdate,
                  c.hubo_error='S'
               where c.nro_solicitud= v_nro_solicitud
                 and c.nro_not= v_nro_not
                 and trunc(c.fec_insercion)= trunc(sysdate);
              commit;
        end;

  end loop;

End;

/********************
|| Proceso Principal
*********************/
BEGIN
 v_lugar:='Inicio de proceso de cierre';
 begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
 for w in g_principal loop
   v_nro_sol:=null;
   v_nro_cta:=null;
   v_nro_sol:= w.nro_solicitud;
   v_nro_cta:= w.nro_cuenta;

   --******************************
   v_lugar:='Re-Normal-Nro.Cta: '||v_nro_cta||' Nro.Sol:'||v_nro_sol;
   
   
   if  FU_VAL_DATOS(w.cod_persona, w.nro_solicitud, 
       w.nro_cuenta,w.cod_periodo, 'N', W.NRO_CUOTA,
       w.cod_modulo, w.cod_modalidad, w.cod_sub_modalidad, w.cod_moneda) ='S' then
           PRP_REN_PRE_TAS_VARIABLE(w.nro_cuenta,'S');
        v_error:='N';
       begin
        select 'S'
          into v_error
           from pr_log_tas_variables a 
            where trunc(a.fec_error)= trunc(sysdate)
               and a.nro_cuenta= v_nro_cta
                and a.usuario= user;
       exception
         when no_data_found then
           v_error:='N';
         when others then 
           v_error:='S';
       end;
       if v_error='N' then
         commit;
       end if;
  end if;
 end loop;
IF nvl(v_rec_afd,'N') ='S' then
   v_fec_afd:= to_date('01/01/'||to_char(v_fec_actual,'yyyy'),'dd/mm/yyyy');
   for x in g_afd loop
     v_nro_sol:= x.nro_solicitud;
     v_nro_cta:= x.nro_cuenta;
     begin
       select a.cod_periodo,a.cod_modulo,a.cod_modalidad,a.cod_sub_modalidad,a.cod_moneda
         into v_cod_periodo_afd,v_cod_modulo_afd,v_cod_modalidad_afd,v_cod_sub_modalidad_afd,v_cod_moneda_afd
           from pr_tas_variables a 
             where a.nro_solicitud= x.nro_solicitud;
      exception
       when others then
       v_cod_periodo_afd:= null;
     end;
     if  FU_VAL_DATOS(x.cod_persona, x.nro_solicitud, 
       x.nro_cuenta,v_cod_periodo_afd, 'S', null,
       v_cod_modulo_afd, v_cod_modalidad_afd, v_cod_sub_modalidad_afd, v_cod_moneda_afd) ='S' then
       v_lugar:='Re-AFD-Nro.Cta: '||v_nro_cta||' Nro.Sol:'||v_nro_sol;
       PRP_REN_PRE_TAS_VARIABLE(x.nro_cuenta,'S');
       v_error:='N';
       begin
        select 'S'
          into v_error
           from pr_log_tas_variables a 
            where trunc(a.fec_error)= trunc(sysdate)
               and a.nro_cuenta= v_nro_cta
                and a.usuario= user;
       exception
         when no_data_found then
           v_error:='N';
         when others then 
           v_error:='S';
       end;
       if v_error='N' then
         commit;
       end if;
     
     end if;

   end loop;
   --Una vez procesado borramos el parametro dinamico
   v_lugar:='Borrar par.dinamico AFD';
   delete from ge_par_dinamicos a where upper(a.parametro)= 'REC_AFD_TASA_VARIABLE';
end if;
v_lugar:='Al enviar Notificaciones';
--Notificamos si Corresponde
lp_not_ren_tasa;

EXCEPTION
  WHEN OTHERS THEN
       LP_INS_LOG_ERROR(sysdate,v_nro_sol,v_nro_cta,v_lugar,sqlerrm);
       -- raise_application_error(-20001,'Error en el Proc. PRP_REN_PRE_TAS_VAR_CIERRE '||SQLERRM);

END;
/


CREATE OR REPLACE PROCEDURE IT.PRP_INS_DEV_RES4
 (P_NRO_CUENTA       IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_NRO_CUO_DESDE    IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_NRO_CUO_HASTA    IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_FEC_CANCELACION  IN PR_CTA_PRESTAMOS.FEC_CANCELACION%TYPE)
IS
 /*Proceso de Insercion de Prestamos en tabla auxiliar para devengamiento paralelo de cuotas*/
 /*Solo se devengan préstamos*/
   v_fec_actual      date := pag_cal.fu_obt_fec_actual(6);
   v_fec_ant_cal     date := pag_cal.FU_OBT_FEC_ANTERIOR(6);
   v_lugar           varchar2(3000);
   v_fec_ult_devengado date:= null;
   v_fec_dev_inicio date;
   v_tip_interes   varchar2(10);
   v_mto_interes   pr_cuotas.sal_interes%type;
   v_mto_capital   pr_cuotas.mto_capital%type;
   v_mto_cap_cuo_actual   pr_cuotas.mto_capital%type;
   v_mto_int_cuo_actual   pr_cuotas.mto_interes%type;
   v_nro_orden     number(10);
   v_mto_int_mov_dev pr_cuotas.mto_capital%type;
   v_nro_cuota_dev number(10);
   v_devengar        varchar2(1):='S';
   v_fec_vto_ult_cuo  date;
   v_fec_vto_cuo_dev  date;
   v_fec_vto_cuo_actual  date;
   v_cod_modulo      number;
   v_nro_cuo_dev     number;
   v_nro_cuo_desde   number;
   v_fec_dev_final   date;
   v_fec_anterior    date;
   v_cod_mon_local   varchar2(10):= pag_gen.FU_OBT_MON_LOCAL;
   v_cod_moneda      varchar2(10);
   v_can_dia_actual  number(3);
   v_can_dia_acumulado  number(3);
   v_can_dia_anterior number(3);
   v_mto_dev_anterior  pr_cuotas.mto_capital%type;
   v_mto_dev_acumulado pr_cuotas.mto_capital%type;
   v_mto_dev_dia       number(18,4);
   v_tot_dias          number(3);
   v_dif_dia_ant          number(3);
   v_dif_dia_act         number(3);
   v_pri_registro      varchar2(1);
   v_mto_dev_actual    number(18,2);
   v_can_dia_dev_actual    number(6);
   v_dia_devengar       number(4);
   v_dia_devengado       number(4);
   v_ult_proceso        varchar2(1);
   v_fec_utilizar       date;
   v_gra_registro       varchar2(1);
   v_pri_eje_res4       varchar2(100):=nvl(fug_obt_pardinamico('PRI_ACT_DEV_RE4',null,null,null, null,null),'N');
   v_cat_cancelacion   number(3);
--Cursor de Prestamos
 cursor c_prestamos is
     select a.* from pr_cta_prestamos a
       where a.nro_cuenta= P_NRO_CUENTA
        and a.cod_modalidad not in (670,671,699) --- No debe devengarse VENTA DE BIENES ADJUDICADOS
         AND a.estado not in (/*'N',*/'I');  --- No incluir Canceladas ni Irrecuperables

--- Cursor de cuotas
   cursor c_cuotas is
     select a.* from pr_cuotas a, pr_cta_prestamos b
       where a.nro_cuenta= P_NRO_CUENTA
        and  (a.nro_cuota >= (v_nro_cuo_dev/*v_nro_cuo_desde*/) and a.nro_cuota <= P_NRO_CUO_HASTA)
        and a.nro_cuenta=b.nro_cuenta
         and b.cod_modalidad not in (670,671,699) --- No debe devengarse VENTA DE BIENES ADJUDICADOS
         AND b.estado not in (/*'N',*/'I')  --- No incluir Canceladas ni Irrecuperables
         --
         and nvl(a.mto_interes,0) > 0
        order by a.nro_cuenta,a.nro_cuota;

BEGIN
   /** INICIO DE PROCESO PRINCIPAL **/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;

   v_lugar:='Insertar Prestamo RE4. Nro.Cuenta: '||p_nro_cuenta;
   v_nro_orden:=0;
   v_nro_cuota_dev:=null;
   v_devengar:='S';
   v_fec_vto_cuo_dev := null;
   v_fec_vto_cuo_actual:=null;
   v_cod_modulo:=null;
   v_nro_cuo_dev:=null;
   v_fec_dev_inicio:= null;
   v_nro_cuo_desde:= null;
   v_mto_interes:= 0;
   v_mto_capital:=0;
   v_mto_cap_cuo_actual:=0;
   v_mto_int_cuo_actual:=0;
   v_cod_moneda:=null;
   v_mto_dev_anterior:=0;
   v_mto_dev_actual:=0;
   v_mto_dev_acumulado:=0;
   v_mto_dev_dia:=0;
   v_tot_dias:=0;
   v_can_dia_acumulado:=0;
   v_dif_dia_ant:=0;
   v_dif_dia_act:=0;
   v_mto_dev_actual:=0;
   v_can_dia_dev_actual:=0;
   v_ult_proceso:=null;
   v_gra_registro:='N';
   --Verificamos si ya existe para agregar registro de orden de insercion
    begin
      select nvl(max(d.nro_orden),0)
       into v_nro_orden
         from GE_DEV_RES4 d
          where d.nro_cuenta= P_NRO_CUENTA;
    exception
      when no_data_found then
         v_nro_orden:=0;
    end;
   --Le sumamos uno al ultimo orden.
   v_nro_orden:= v_nro_orden + 1;
   v_lugar:='Obtener Cuota Dev.Actual:'|| p_nro_cuenta;

   --Obtenemos el modulo de la cuenta
    begin
      select d.cod_modulo,e.cod_moneda
       into v_cod_modulo,v_cod_moneda
         from ge_cta_clientes d, ge_cuentas e
          where d.nro_cuenta= P_NRO_CUENTA
             and d.relacion='P'
             and d.nro_cuenta= e.nro_cuenta;
    exception
      when no_data_found then
         v_cod_modulo:=null;
    end;
   --Si es préstamo
   if v_cod_modulo = 6 then
       --No es del dia
       if trunc(v_fec_actual) > trunc(p_fec_cancelacion) then
         v_fec_utilizar:= trunc(v_fec_actual) ;
       else
         v_fec_utilizar:=trunc(p_fec_cancelacion);
       end if;


       --Obtenemos la primera Fecha de Vencimiento, luego de la cancelación
       v_lugar:='Obtener Pri.Fec.Vto:'|| p_nro_cuenta;
       select min(a.fec_vencimiento)
         into v_fec_vto_cuo_actual
         from pr_cuotas a
            where a.nro_cuenta=P_NRO_CUENTA and a.nro_cuota >=P_NRO_CUO_DESDE and a.nro_cuota <=P_NRO_CUO_HASTA
                 and trunc(a.fec_vencimiento) >= trunc(v_fec_utilizar)/*P_FEC_CANCELACION*/;


       if v_fec_vto_cuo_actual is not null then
         --Traemos que Nro de Cuota es el actual
          v_lugar:='Obtener Nro.Cuo.Act:'|| p_nro_cuenta;
          begin
            select d.nro_cuota, d.mto_capital,d.mto_interes
             into v_nro_cuo_dev,v_mto_cap_cuo_actual,v_mto_int_cuo_actual
               from pr_cuotas d
                where d.nro_cuenta= P_NRO_CUENTA
                  and d.fec_vencimiento= v_fec_vto_cuo_actual;
           exception
              when no_data_found then
               v_nro_cuo_dev:=null;
           end;


          if v_nro_cuo_dev is not null then
               v_lugar:='Obtener Cuo.Ant:'|| p_nro_cuenta;
               begin
                  select d.nro_cuota, d.fec_vencimiento
                   into v_nro_cuo_desde, v_fec_dev_inicio
                     from pr_cuotas d
                      where d.nro_cuenta= P_NRO_CUENTA
                        and d.nro_cuota= v_nro_cuo_dev-1;
               exception
                    when no_data_found then
                     v_nro_cuo_desde:=null;
               end;
           end if;
           v_tot_dias:= trunc(v_fec_vto_cuo_actual) - trunc(v_fec_dev_inicio);
           --traemos la fecha de devengamiento final
            v_lugar:='Obtener Max.Fec.Vto:'|| p_nro_cuenta;
           select max(a.fec_vencimiento)
               into v_fec_dev_final
               from pr_cuotas a
                  where a.nro_cuenta=P_NRO_CUENTA and a.nro_cuota >=P_NRO_CUO_DESDE and a.nro_cuota <=P_NRO_CUO_HASTA
                       and a.fec_vencimiento >= P_FEC_CANCELACION;
            --Obtenemos total de capital e interes
           v_lugar:='Obtener Int.+ Capital'|| p_nro_cuenta;
           select sum(a.mto_interes) , sum(a.mto_capital)
            into v_mto_interes, v_mto_capital
             from pr_cuotas a
                  where a.nro_cuenta=P_NRO_CUENTA
                  and a.nro_cuota >=v_nro_cuo_dev and a.nro_cuota <=P_NRO_CUO_HASTA;

        else
          --ya no devengamos si la fecha es menor a la fecha de Cancelacion
          v_devengar:='N';
        end if;

   end if;


 If  v_devengar='S' THEN
/*   for pre in c_prestamos loop
     v_lugar:='Insertar en GE_DEV_RE4. Nro.Cuenta:'|| pre.nro_cuenta;
     v_fec_anterior:= v_fec_actual-1;
     insert into GE_DEV_RES4
          ( NRO_CUENTA,NRO_ORDEN,COD_MODULO,COD_MODALIDAD,COD_SUB_MODALIDAD,
            COD_OFICINA,MTO_CAPITAL,MTO_INTERES,COD_MONEDA,MTO_DEV_ACTUAL,
            FEC_CANCELACION,HOR_CANCELACION,FEC_DEV_INICIO,FEC_DEV_FIN,FEC_ULT_DEVENGADO,
            DEVENGAR,DESCRIPCION,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,
            FEC_MODIFICACION,
            CATEGORIA,ESTADO,COD_SEC_CREDITO,TIPO,TIP_INTERES,TIP_RENOVACION,MTO_DEV_ACUMULADO
            )
        values
            (pre.nro_cuenta,v_nro_orden,pre.cod_modulo,pre.cod_modalidad,pre.cod_sub_modalidad,
            pre.cod_oficina,v_mto_capital,v_mto_interes,pre.cod_moneda,0, --Mto_dev_actual
            P_FEC_CANCELACION,null,v_fec_dev_inicio,v_fec_dev_final,v_fec_anterior,
            v_devengar, pre.descripcion,user,sysdate, user,
            sysdate,
            pre.cat_renovaciones,pre.ESTADO,pre.COD_SEC_CREDITO,pre.TIPO,pre.TIP_INTERES,pre.TIP_RENOVACION,
            0);
    end loop;*/
   v_lugar:='Insertar Cuotas RE4. Nro.Cuenta:'|| p_nro_cuenta;
   v_pri_registro:='S';
   v_gra_registro:='N';
   for cuo in c_cuotas loop
           v_lugar:='Insertar en Cuotas RE4. Nro.Cuenta:'|| cuo.nro_cuenta|| 'Nro.Cuota:'||cuo.nro_cuota;
           /* Calculamos los datos de Devengado e Insertamos */
            v_lugar:='calc.datos GE_DEV_RE4_DET. Nro.Cuenta:'||p_nro_cuenta;
            v_can_dia_anterior:=0;

          if v_pri_registro ='S' then
                v_mto_dev_actual:=0;
                v_can_dia_dev_actual:=0;
                v_dia_devengar:=0;
                v_dia_devengado:=0;
                v_dia_devengado:= v_fec_ant_cal - v_fec_dev_inicio;

                v_mto_dev_dia:= v_mto_int_cuo_actual/v_tot_dias;
                v_can_dia_acumulado:= v_fec_actual- v_fec_dev_inicio;
                v_dia_devengar:=(v_can_dia_acumulado - v_dia_devengado)-1;
                --Si solo es entre 2 dias consecutivos, no se le debe restar
                if v_dia_devengar= 0 then
                  v_dia_devengar:= 1;
                end if;
                if v_dia_devengar=1 then
                  v_ult_proceso:='F';
                else
                  v_ult_proceso:='I';
                end if;

                --Solo para la primera vez, ya que se devenga desde el 1 de Noviembre
                if nvl(v_pri_eje_res4,'N')='S' then
                  v_dia_devengar:= 1;
                end if;

                v_mto_dev_actual:= v_mto_dev_dia * v_dia_devengar;
                 if v_cod_moneda = v_cod_mon_local then
                   v_mto_dev_acumulado:= round(v_mto_dev_dia * v_can_dia_acumulado,0);
                   v_mto_dev_dia:= round(v_mto_dev_dia,2);
                   v_mto_dev_actual:= round(v_mto_dev_actual,0);
                else
                    v_mto_dev_acumulado:= round(v_mto_dev_dia * v_can_dia_acumulado,2);
                    v_mto_dev_dia:= round(v_mto_dev_dia,2);
                    v_mto_dev_actual:= round(v_mto_dev_actual,0);
                 end if;

                v_lugar:='Insertar en ge_devengados RE4. Nro.Cuenta:'||p_nro_cuenta;
                v_gra_registro:='S';
                insert into GE_DEV_RES4_DET
                   (NRO_CUENTA,
                    NRO_ORDEN,
                    FEC_INICIO,
                    FEC_FINAL,
                    MTO_DEV_ACTUAL,
                    CAN_DIA_DEV_ACTUAL,
                    MTO_DEV_ACUMULADO,
                    CAN_DIA_ACUMULADO,
                    TOT_DIAS,
                    MTO_INTERES,
                    MTO_DEV_DIARIO,
                    ESTADO,
                    COD_MONEDA,
                    NRO_CUOTA,
                    ULT_PROCESO,
                    USU_INSERCION,
                    FEC_INSERCION,
                    USU_MODIFICACION,
                    FEC_MODIFICACION)
                values
                    (p_nro_cuenta,
                    v_nro_orden,
                    v_fec_dev_inicio, --Fecha de Inicio
                    cuo.fec_vencimiento, --Fecha Final
                    v_mto_dev_actual, --Mto.Dev_Actual
                    v_dia_devengar, --Dia.Dev_Actual
                    v_mto_dev_acumulado,
                    v_can_dia_acumulado,
                    v_tot_dias,
                    cuo.mto_interes,--v_mto_int_cuo_actual,
                    v_mto_dev_dia,
                    'DE', --Estado
                    v_cod_moneda,
                    cuo.nro_cuota,--v_nro_cuo_dev,
                    v_ult_proceso,
                    user,
                    sysdate,
                    user,
                    sysdate);
                    v_pri_registro :='N';
                   /* --Actualizamos Cabecera
                    update GE_DEV_RES4 s
                      set s.mto_dev_actual=v_mto_dev_actual,
                          s.mto_dev_acumulado=v_mto_dev_acumulado
                     where s.nro_cuenta= P_NRO_CUENTA
                       and s.nro_orden= v_nro_orden;*/



            else
                --Obtenemos datos de la cuota anterior
                begin
                  select d.fec_vencimiento
                   into  v_fec_dev_inicio
                     from pr_cuotas d
                      where d.nro_cuenta= P_NRO_CUENTA
                        and d.nro_cuota= cuo.nro_cuota-1;
               exception
                    when no_data_found then
                      v_fec_dev_inicio:=null;
               end;


                v_tot_dias:= cuo.fec_vencimiento- v_fec_dev_inicio;
                v_mto_dev_dia:= cuo.mto_interes / v_tot_dias;
                if v_cod_moneda = v_cod_mon_local then
                   v_mto_dev_dia:= round(v_mto_dev_dia,0);
                else
                    v_mto_dev_dia:= round(v_mto_dev_dia,2);
                end if;
                v_gra_registro:='S';
                v_lugar:='Insertar en ge_devengados RE4. Nro.Cuenta:'||p_nro_cuenta;
                insert into GE_DEV_RES4_DET
                   (NRO_CUENTA,
                    NRO_ORDEN,
                    FEC_INICIO,
                    FEC_FINAL,
                    MTO_DEV_ACTUAL,
                    CAN_DIA_DEV_ACTUAL,
                    MTO_DEV_ACUMULADO,
                    CAN_DIA_ACUMULADO,
                    TOT_DIAS,
                    MTO_INTERES,
                    MTO_DEV_DIARIO,
                    ESTADO,
                    COD_MONEDA,
                    NRO_CUOTA,
                    ULT_PROCESO,
                    USU_INSERCION,
                    FEC_INSERCION,
                    USU_MODIFICACION,
                    FEC_MODIFICACION)
                values
                    (p_nro_cuenta,
                    v_nro_orden,
                    v_fec_dev_inicio, --Fecha de Inicio
                    cuo.fec_vencimiento, --Fecha Final
                    0, --Mto.Dev_Actual
                    0, --Dia.Dev_Actual
                    0, --Mto.Dev_Acumulado
                    0, --Dia. Acumulado
                    v_tot_dias,
                    cuo.mto_interes,--v_mto_int_cuo_actual,
                    v_mto_dev_dia,
                    'AD', --Estado
                    v_cod_moneda,
                    cuo.nro_cuota,--v_nro_cuo_dev,
                    NULL,
                    user,
                    sysdate,
                    user,
                    sysdate);

            end if;
  end loop;
  IF  v_gra_registro='S' then
  for pre in c_prestamos loop
     v_lugar:='Insertar en GE_DEV_RE4. Nro.Cuenta:'|| pre.nro_cuenta;
     v_fec_anterior:= v_fec_actual-1;
     --10/11/2020 sino tiene la categoria asignada buscamos en la tabla espejo de covid 19.
     if pre.cat_renovaciones is null then
        begin 
         select a.cat_rie_cliente
            into v_cat_cancelacion
              from (select w.*
                      from PR_CTA_PRE_REF_RES4 w
                        where w.nro_cuenta=pre.nro_cuenta
                           and w.nro_cta_nueva is not null
                           order by w.fec_insercion desc ) a
            where a.nro_cuenta= pre.nro_cuenta
             and rownum=1;
        exception
           when no_data_found then
             v_cat_cancelacion:= null;
           when others then
             v_cat_cancelacion:= null;
        end; 
     else
       v_cat_cancelacion:=pre.cat_renovaciones;
     end if;
     
     
     
     insert into GE_DEV_RES4
          ( NRO_CUENTA,NRO_ORDEN,COD_MODULO,COD_MODALIDAD,COD_SUB_MODALIDAD,
            COD_OFICINA,MTO_CAPITAL,MTO_INTERES,COD_MONEDA,MTO_DEV_ACTUAL,
            FEC_CANCELACION,HOR_CANCELACION,FEC_DEV_INICIO,FEC_DEV_FIN,FEC_ULT_DEVENGADO,
            DEVENGAR,DESCRIPCION,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,
            FEC_MODIFICACION,
            CATEGORIA,ESTADO,COD_SEC_CREDITO,TIPO,TIP_INTERES,TIP_RENOVACION,MTO_DEV_ACUMULADO
            )
        values
            (pre.nro_cuenta,v_nro_orden,pre.cod_modulo,pre.cod_modalidad,pre.cod_sub_modalidad,
            pre.cod_oficina,v_mto_capital,v_mto_interes,pre.cod_moneda,v_mto_dev_actual, --Mto_dev_actual
            P_FEC_CANCELACION,null,v_fec_dev_inicio,v_fec_dev_final,v_fec_anterior,
            v_devengar, pre.descripcion,user,sysdate, user,
            sysdate,
            /*pre.cat_renovaciones*/v_cat_cancelacion,pre.ESTADO,pre.COD_SEC_CREDITO,pre.TIPO,pre.TIP_INTERES,pre.TIP_RENOVACION,
            v_mto_dev_acumulado);
    end loop;
 end if;

 end if;


exception
 WHEN OTHERS THEN
   raise_application_error(-20000,'Error prp_ins_Dev_Re4-Lugar: '||v_lugar||'-'||sqlerrm);
END;
/


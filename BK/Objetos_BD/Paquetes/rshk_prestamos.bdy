create or replace package body it.RSHK_Prestamos is


  -- Private type declarations
  --type <TypeName> is <Datatype>;

  -- Private constant declarations
  --<ConstantName> constant <Datatype> := <Value>;

  -- Private variable declarations
  --<VariableName> <Datatype>;
  --vRunId integer;

  -- Function and procedure implementations
 --function <FunctionName>(<Parameter> <Datatype>) return <Datatype> is
 --   <LocalVariable> <Datatype>;
 -- begin
 --   <Statement>;
 --   return(<Result>);
 -- end;

--HELPER PROCS AND FUNCS

PROCEDURE "MIG_PR_ERROR_LOG_REGISTRAR" (p_procedim in varchar2, p_cliente in varchar2, p_mensaje in varchar2, p_modulo in varchar2) is
PRAGMA AUTONOMOUS_TRANSACTION;
v_orden number:=0;
begin

/*
create table mig_pr_log
(

  FECHA       DATE,
  DESCRIPCION VARCHAR2(2000),
  MODULO      VARCHAR2(10),
  ORDEN       NUMBER(10),
  FASE       NUMBER(4),
  TIPO       VARCHAR(10), --ERROR,INFO,ETC
  ID      NUMBER(10),
  ID_NAME    VARCHAR(100)
)
*/
   select MIG_PR_LOG2_SEQ.NEXTVAL
     into v_orden
     from dual;

/*   insert into MIG_PR_LOG2 (PROCEDIMIENTO,FECHA,DESCRIPCION,ID,MODULO,orden)
      values (trim(p_procedim), sysdate, trim(p_mensaje), p_cliente, p_modulo, v_orden);
   commit;*/
end;




PROCEDURE "MIG_PR_LOG_REGISTRAR" (p_mensaje in varchar2, p_modulo in varchar2) is
PRAGMA AUTONOMOUS_TRANSACTION;
v_orden number:=0;
begin
  select mig_pr_log2_seq.nextval
  into  v_orden
  from dual;
     select MIG_PR_LOG2_SEQ.NEXTVAL
     into v_orden
     from dual;

/*   insert into MIG_PR_LOG2 (FECHA,DESCRIPCION,MODULO,orden)
      values               (sysdate, trim(p_mensaje), p_modulo, v_orden);

  commit;*/
end;


FUNCTION "PR_OBTENER_SGTE_VENC_CUOTA" (p_nro_cuenta varchar2, p_vencimiento date)
return date
is
   v_sgte_venc date := null;
begin
       /*select c.FEC_VENCIMIENTO into v_sgte_venc
       from view_pr_cuotas c where c.NRO_CUENTA = p_nro_cuenta
       and c.FEC_VENCIMIENTO > p_vencimiento and rownum < 2;*/
       
       select c.FEC_VENCIMIENTO into v_sgte_venc
       from pr_cuotas c where c.NRO_CUENTA = p_nro_cuenta
       and c.FEC_VENCIMIENTO > p_vencimiento and rownum < 2;

       return v_sgte_venc;
exception
       when no_data_found then
            select ln.fec_vencimiento into v_sgte_venc  from view_pr_cta_prestamos ln
                    where ln.nro_cuenta = p_nro_cuenta;
            --raise_application_error(-20001,'No hay sgte. vencimiento para el prestamo '||p_nro_cuenta);
            --registrar_error_fase2('pr_obtener_sgte_venc_cuota',
              --                    null,
                --                  'No hay sgte. vencimiento para el prestamo '||p_nro_cuenta,
                  --                'PR');

      when others then
            raise_application_error(-20001,sqlerrm||' préstamo: '||p_nro_cuenta);
           --registrar_error_fase2('pr_obtener_sgte_venc_cuota',
             --                     null,
               --                   sqlerrm||' préstamo: '||p_nro_cuenta,
                 --                 'PR');
end;


PROCEDURE "MI_MIG_PR_CUOTAS_V3"
IS
  CURSOR cur_cuotas IS
    select t.*
    from  pr_cuotas t
    --from  view_pr_cuotas t
   -- inner join mi_pr_cta_prestamos p
    --on (t.nro_cuenta = p.nro_cuenta)
    order by t.nro_cuenta, t.fec_vencimiento;

    cr_cuotas cur_cuotas%ROWTYPE;
    var_total_registros number := 0;
    var_total_insertados number := null;
    v_nro_cuota number:= 0;
    var_cta_anterior varchar2(10) := null;
    v_mto_int_vencido number(18,2);
    v_mto_int_adelantado number(18,2);
    v_estado_cuota varchar2(2);
    v_sgte_venc_cuota date;
    v_mto_capital number(18,2);
    v_mto_interes number(18,2);
    v_mto_int_documentado number(18,2);
    v_update_data boolean := false;
    v_prest_aleman_ade_venc boolean := false;
    v_can_cuotas_pagadas number(3) := 0;
    v_fec_venc_anterior date := null;
    v_estado_cuota_ant_rep varchar2(2);--Estado de una cuota que aparece 2 veces en la vista (maecartera y maeicpc con la misma fecha)
    v_cancelado_por_def boolean := false;

BEGIN

    --Cantidad total de registros de cuotas pendientes de pago que deberían ser cargados
   -- select count(*) into var_total_registros
      --    from  view_pr_cuotas t
    --inner join mi_pr_cta_prestamos p
--    on (t.nro_cuenta = p.nro_cuenta);

    mig_pr_log_registrar('Inicio mig_pr_cuotas ','TP2');

    OPEN cur_cuotas;
    LOOP
      FETCH cur_cuotas INTO cr_cuotas;
      EXIT WHEN cur_cuotas%NOTFOUND;
      BEGIN

      var_total_registros := var_total_registros +1;

      v_mto_int_vencido := 0;
      v_mto_int_adelantado := 0;
      v_estado_cuota := cr_cuotas.estado;
      v_sgte_venc_cuota :=cr_cuotas.fec_vencimiento;
      v_mto_capital  := cr_cuotas.mto_capital;
      v_mto_interes  := cr_cuotas.mto_interes;
      v_update_data := false;
      v_prest_aleman_ade_venc := false;
      v_can_cuotas_pagadas := 0;
      v_estado_cuota_ant_rep := null;
      v_cancelado_por_def := false;

      --Si es la primera cuota de un préstamo
      if(var_cta_anterior is null or var_cta_anterior <> cr_cuotas.nro_cuenta)then

         if(var_cta_anterior is not null) then
             --Se actualiza la cantidad total de cuotas y la cantidad de cuotas pagadas del préstamo anterior
             NULL;
             /*update mi_pr_cta_prestamos p set p.can_cuotas = v_nro_cuota, p.can_cuo_pagadas = v_can_cuotas_pagadas
                    where p.nro_cuenta =  var_cta_anterior;

           commit;*/
         end if;

         v_nro_cuota := 1;
         v_fec_venc_anterior := null;

         --Se verifica si tiene tanto intereses adelantados como vencidos
         select sum(mto_interes), sum(mto_int_documentado) into
          v_mto_int_vencido,v_mto_int_adelantado
          --from view_pr_cuotas
          from pr_cuotas
          where nro_cuenta = cr_cuotas.nro_cuenta;

          /*if(v_mto_int_vencido > 0 and v_mto_int_adelantado > 0) then
                      --Si el préstamo es alemán
                      if(trim(cr_cuotas.modalidad) = 'A')then

                             v_prest_aleman_ade_venc := true;
                              --Si tiene interes adelantado y no tiene interes vencido
                             --es correcto, que se aplique lo definido para la migracion
                             begin
                               if(cr_cuotas.MTO_INTERES = 0 and
                                       cr_cuotas.MTO_INT_DOCUMENTADO > 0)then
                                  v_cancelado_por_def := true;
                                  --Se migra como cancelada, si es la primera cuota de
                                   v_estado_cuota := 'N';
                                   v_sgte_venc_cuota := pr_obtener_sgte_venc_cuota(cr_cuotas.nro_cuenta,cr_cuotas.fec_vencimiento);
                               \*else
                                   raise_application_error(-20001,'Préstamo con intereses adelantados y vencidos con primera cuota '
                                     ||' con Interés VENCIDO: '||cr_cuotas.nro_cuenta
                                   );*\
                               end if;
                            end;
                      end if;
          end if;*/
      -- Si NO es la primera CUOTA
      else
           begin
             --Si ya se cargó una cuota con la misma fecha de vencimiento que la cuota que se está
             --analizando ahora, se obtiene el monto de la cuota cargada
            -- dbms_output.put_line('v_fec_venc_anterior: '||v_fec_venc_anterior);
            -- dbms_output.put_line('fec_vencimiento: '||cr_cuotas.fec_vencimiento);
             if((v_fec_venc_anterior is not null)
                        and (v_fec_venc_anterior = cr_cuotas.fec_vencimiento)) then
               select mto_capital,mto_interes, mto_int_documentado, estado
                 into v_mto_capital, v_mto_interes, v_mto_int_documentado,v_estado_cuota_ant_rep
                     from pr_cuotas cu where
                     --from mi_pr_cuotas cu where
                         nro_cuenta = cr_cuotas.nro_cuenta and
                             fec_vencimiento = cr_cuotas.fec_vencimiento
                                                and nro_cuota  = v_nro_cuota - 1;

                v_mto_capital := v_mto_capital +cr_cuotas.mto_capital;
                v_mto_interes := v_mto_interes + cr_cuotas.mto_interes;
                v_mto_int_documentado := v_mto_int_documentado + cr_cuotas.mto_int_documentado;

                if(v_estado_cuota_ant_rep <> v_estado_cuota ) then

                     if(v_estado_cuota_ant_rep <> 'N' and v_estado_cuota = 'N' and v_cancelado_por_def=false) then
                         v_estado_cuota := v_estado_cuota_ant_rep;
                     end if;

                end if;
                v_update_data := true;
             end if;
             exception
                   when no_data_found then v_mto_capital := cr_cuotas.mto_capital;
             end;

         /*if(trim(cr_cuotas.modalidad) <> 'F') then --Si NO es un préstamo Francés
               --Si es un préstamo alemán que tiene intereses adelantados y vencidos
               if(v_prest_aleman_ade_venc = true) then
                   v_sgte_venc_cuota := pr_obtener_sgte_venc_cuota(cr_cuotas.nro_cuenta,cr_cuotas.fec_vencimiento);
               end if;
         end if;*/
      end if;

      /*if(v_update_data = true) then
          update mi_pr_cuotas set mto_capital = v_mto_capital,
                 sal_capital = v_mto_capital, mto_interes = v_mto_interes,
                         sal_interes = v_mto_interes,
                          mto_int_documentado = v_mto_int_documentado,
                           sal_int_documentado = v_mto_int_documentado, estado = v_estado_cuota  where
                           nro_cuenta = cr_cuotas.nro_cuenta and
                                   fec_vencimiento = cr_cuotas.fec_vencimiento;
                                   --and nro_cuota  = v_nro_cuota - 1;

      else
          insert into mi_PR_CUOTAS(
              NRO_CUENTA,
              NRO_CUOTA,
              MTO_CAPITAL,
              FEC_VENCIMIENTO,
              MTO_INTERES,
              ESTADO,
              SAL_CAPITAL,
              SAL_INTERES,
              PRIORIDAD,
              FEC_ULT_PAGO,
              VAL_RECARGO,
              MTO_INT_DOCUMENTADO,
              NRO_DOCUMENTO,
              SAL_INT_DOCUMENTADO,
              DEV_NO_COBRADO,
              DEV_SUSPENSO,
              DEV_ACUMULADO,
              MTO_INT_DESCONTADO,
              MTO_CAP_ADELANTADO
          )values(
              cr_cuotas.NRO_CUENTA,
              v_nro_cuota,
              v_mto_capital,--MTO_CAPITAL,
              v_sgte_venc_cuota,
              cr_cuotas.MTO_INTERES,
              v_estado_cuota,
              v_mto_capital,--SAL_CAPITAL,
              cr_cuotas.MTO_INTERES,
              cr_cuotas.PRIORIDAD,
              null,--FEC_ULT_PAGO,
              null,--VAL_RECARGO,
              cr_cuotas.MTO_INT_DOCUMENTADO,
              cr_cuotas.NRO_DOCUMENTO,
              cr_cuotas.MTO_INT_DOCUMENTADO,
              cr_cuotas.DEV_NO_COBRADO,
              cr_cuotas.DEV_SUSPENSO,
              cr_cuotas.DEV_ACUMULADO,
              null,--MTO_INT_DESCONTADO,
              null--MTO_CAP_ADELANTADO
          );
          v_nro_cuota := v_nro_cuota + 1;

      end if;*/

       var_cta_anterior :=  cr_cuotas.NRO_CUENTA;
       v_fec_venc_anterior := v_sgte_venc_cuota;

      EXCEPTION when others then
                mig_pr_error_log_registrar('mig_pr_cuotas', cr_cuotas.nro_cuenta, sqlerrm,'TP2');

      END;
      END LOOP;
      CLOSE cur_cuotas;

      --select count(*) into var_total_insertados  from mi_pr_cuotas;
      mig_pr_log_registrar('FIN mig_pr_cuotas - Insertados: '||var_total_insertados||' De: ' ||var_total_registros,'TP2');

EXCEPTION
    when others then
         mig_pr_error_log_registrar('mig_pr_cuotas',null, sqlerrm, 'TP2');
END;


PROCEDURE "MI_MIG_PR_CTA_PRESTAMOS"
IS
  CURSOR cur_prestamos IS
    select*
    from  view_pr_cta_prestamos;

    cr_pres cur_prestamos%ROWTYPE;
    var_total_registros number := null;
    var_total_insertados number := null;
BEGIN

    select count(*) into var_total_registros
           from  view_pr_cta_prestamos;
    mig_pr_log_registrar('Inicio mig_pr_cta_prestamos - Registros a Insertar: '||var_total_registros,'TP2');


    OPEN cur_prestamos;
    LOOP
      FETCH cur_prestamos INTO cr_pres;
      EXIT WHEN cur_prestamos%NOTFOUND;
      BEGIN
      NULL;
      /*insert into mi_pr_cta_prestamos(nro_cuenta,dig_verificador,cod_modulo, cod_modalidad,
             cod_oficina,
             nro_cta_debito,
             NRO_CTA_RENOVADA,
             FEC_CANCELACION,
             ESTADO,
             MTO_CAPITAL,
             SAL_CAPITAL,
             SAL_INTERES,
             VAL_INT_DEVENGAR,
             NRO_SOLICITUD,
             EST_BATCH,
             SAL_CAP_BATCH,
             SAL_INT_BATCH,
             NRO_DOCUMENTO,
             EST_ANTERIOR,
             DEV_ACUMULADO,
             TIP_DOCUMENTO,
             NRO_SOL_RENOVADA,
             COB_AUTOMATICO,
             SAL_INT_ADELANTADO,
             FEC_ULT_DEVENGADO,
             DEV_NO_COBRADO,
             NRO_LINEA,
             COD_MONEDA,
             MONTO,
             FEC_INICIO,
             FEC_VENCIMIENTO,
             TIPO,
             VAL_TASA,
             CAN_CUOTAS,
             CAN_CUO_PAGADAS,
             DIA_ATRASO,
             MAX_ATRASO,
             PRO_ATRASO,
             EXO_IMPUESTOS,
             COD_CAUSA,
             COD_CANAL,
             COD_CAMPANA,
             COD_SEC_CREDITO,
             DESCRIPCION,
             TIP_DESTINO,
             TIP_INTERES,
             MTO_LIN_APLICADO,
             TIP_RENOVACION,
             SAL_INT_ADE_BATCH,
             COD_ORI_FONDO,
             PER_VTO_CAPITAL,
             DEV_SUSPENSO,
             EN_JUICIO,
             FEC_JUICIO,
             COD_ENT_JUICIO,
             CAT_RENOVACIONES,
             MTO_MORA,
             COD_BANCA
         ) VALUES (cr_pres.nro_cuenta,cr_pres.dig_verificador,cr_pres.cod_modulo, cr_pres.cod_modalidad,
             cr_pres.cod_oficina,
             cr_pres.nro_cta_debito,
             cr_pres.NRO_CTA_RENOVADA,
             cr_pres.FEC_CANCELACION,
             cr_pres.ESTADO,
             cr_pres.MTO_CAPITAL,
             cr_pres.SAL_CAPITAL,
             cr_pres.SAL_INTERES,
             cr_pres.VAL_INT_DEVENGAR,
             --cr_pres.NRO_SOLICITUD,
             NULL,
             cr_pres.EST_BATCH,
             cr_pres.SAL_CAP_BATCH,
             cr_pres.SAL_INT_BATCH,
             cr_pres.NRO_DOCUMENTO,
             cr_pres.EST_ANTERIOR,
             cr_pres.DEV_ACUMULADO,
             cr_pres.TIP_DOCUMENTO,
             cr_pres.NRO_SOL_RENOVADA,
              cr_pres.COB_AUTOMATICO,
             cr_pres.SAL_INT_ADELANTADO,
             cr_pres.FEC_ULT_DEVENGADO,
             cr_pres.DEV_NO_COBRADO,
             cr_pres.NRO_LINEA,
             cr_pres.COD_MONEDA,
             cr_pres.MONTO,
             cr_pres.FEC_INICIO,
             cr_pres.FEC_VENCIMIENTO,
             cr_pres.TIPO,
             cr_pres.VAL_TASA,
             cr_pres.CAN_CUOTAS,
             cr_pres.CAN_CUO_PAGADAS,
             cr_pres.DIA_ATRASO,
             cr_pres.MAX_ATRASO,
             cr_pres.PRO_ATRASO,
             cr_pres.EXO_IMPUESTOS,
             cr_pres.COD_CAUSA,
             cr_pres.COD_CANAL,
             cr_pres.COD_CAMPANA,
             cr_pres.COD_SEC_CREDITO,
             cr_pres.DESCRIPCION,
             cr_pres.TIP_DESTINO,
             cr_pres.TIP_INTERES,
             cr_pres.MTO_LIN_APLICADO,
             cr_pres.TIP_RENOVACION,
             cr_pres.SAL_INT_ADE_BATCH,
             cr_pres.COD_ORI_FONDO,
             cr_pres.PER_VTO_CAPITAL,
             cr_pres.DEV_SUSPENSO,
             cr_pres.EN_JUICIO,
             cr_pres.FEC_JUICIO,
             cr_pres.COD_ENT_JUICIO,
             cr_pres.CAT_RENOVACIONES,
             cr_pres.MTO_MORA,
             cr_pres.COD_BANCA
         );
         --mig_pr_cuotas(cr_pres.nro_cuenta);
         commit;*/
      EXCEPTION when others then
                mig_pr_error_log_registrar('mig_pr_cta_prestamos', cr_pres.nro_cuenta, sqlerrm,'TP2');

      END;
      END LOOP;
      CLOSE cur_prestamos;
      --select count(*) into var_total_insertados  from mi_pr_cta_prestamos;
      mig_pr_log_registrar('FIN pr_cta_prestamos - Insertados: '||var_total_insertados||' De: ' ||var_total_registros,'TP2');

EXCEPTION
    when others then
         mig_pr_error_log_registrar('mig_pr_cta_prestamos',null, sqlerrm, 'TP2');
END;

PROCEDURE "OBTENER_INFO_SOLICITUD_PR"
is
  /*   CURSOR cur_prestamos IS
              select ln.nuries, ln.sucursalfu, ln.propuesta,ln.tipo_prestamo, ln.propfecha, ln.congru
              from loans_numero_cuenta ln  --where ln.propuesta = 15209
              order by ln.propfecha desc;*/

   c_riesgo number(12,0);
   c_sucursal number(3,0);
   c_propuesta number(15,0);
   c_tip_prestamo varchar2(2);
   c_propfecha date;
   c_congru varchar2(15);
   v_mes varchar2(2);
   v_mes_actual varchar2(2);
   v_anho varchar2(4);
   v_dia varchar2(2);
   v_biblioteca varchar2(12):='MAEACT';
   v_encontrado number(2) := 0;
   v_finalizado  number(2) := 0;
   v_ade_venc varchar2(5):= null;
   v_stmt varchar2(200);
   v_modalidad varchar2(5);
   v_pal_prop_nro number(10);
   v_num_cuota number(5);
   v_pal_cta_abo number(12);
   v_pal_ven_cuo varchar2(4);
   v_pal_com_des number(18,2);
   v_pal_com_otros number(18,2);

begin

    v_mes_actual := to_char(sysdate,'MM');
    v_mes := to_char(sysdate,'MM');
    v_anho := to_char(sysdate,'yyyy');
    /*mig_pr_log_registrar('Inicio OBTENER_INFO_SOLICITUD_PR','TP2');
    delete from pr_info_solicitud;
    commit;
    OPEN cur_prestamos;
    LOOP
    FETCH cur_prestamos INTO c_riesgo, c_sucursal, c_propuesta,c_tip_prestamo,c_propfecha,c_congru;
    EXIT WHEN cur_prestamos%NOTFOUND;*/

      v_encontrado := 0;
      v_finalizado := 0;
      v_modalidad  := null;
      v_ade_venc   := null;
      v_pal_prop_nro := null;
      v_pal_cta_abo  := null;
      v_pal_ven_cuo  := null;
      v_pal_com_des  := null;
      v_pal_com_otros:= null;

/*
      v_mes_actual := to_char(sysdate,'MM');
      v_mes        := to_char(sysdate,'MM');
      v_anho       := to_char(sysdate,'yyyy');

      while( v_encontrado = 0 and v_finalizado = 0)
      loop
          if( v_mes_actual <> v_mes)  then--Si es el mes actual, se busca en MAEACT*/
      /*v_mes_actual := to_char(to_date('31/12/2009','dd/MM/yyyy'),'MM');
      v_mes        := to_char(to_date('31/12/2009','dd/MM/yyyy'),'MM') - 1;
      v_anho       := to_char(to_date('31/12/2009','dd/MM/yyyy'),'yyyy');*/
      v_mes_actual := to_char(sysdate,'MM');
      v_mes        := to_char(sysdate,'MM');
      v_anho       := to_char(sysdate,'yyyy');

    /*  while( v_encontrado = 0 and v_finalizado = 0)
      loop
          if( v_mes_actual <> v_mes)  then--Si es el mes actual, se busca en MAEACT

            if(v_mes <> '01') then  --Si no es enero
                  v_mes := lpad(to_char(to_number(v_mes)-1),2,'0');--Se resta 1, para verificar el mes anterior
            else--Es enero
                  v_mes := '12';--El nuevo mes es diciembre
                  v_anho := to_char(to_number(v_anho)-1);--Se comienzan a ver los del año anterior
            end if;
                --Se obtiene el último dia para el mes cuya biblioteca ase va a analizar
             v_dia := to_char(last_day(to_date('01/'||v_mes||'/'||v_anho,'dd/MM/yyyy')),'dd');
             v_biblioteca := 'MAE'||v_dia||v_mes||substr(v_anho,3,2);
          else
             v_mes_actual := -1;

          end if;

          --dbms_output.put_line('Se analizará el cliente: '||c_riesgo||' sucursal: '
                                             --||c_sucursal||' propuesta: '||c_propuesta);
          --dbms_output.put_line('Se analizará la biblioteca '||v_biblioteca);

          begin
            v_stmt := 'select trim(palaov), trim(PALMODLIQ), palpropnro, palnumcuo, palctaabo, palvencuo, PALCOMDSMB, PALCOMOTR from '
                              || v_biblioteca||'_PROPALIQ where palsuc = '||c_sucursal||
                                 ' and palpropnro = '||c_propuesta||' and palcliente ='||c_riesgo;

            execute immediate v_stmt into v_ade_venc,v_modalidad,v_pal_prop_nro,
                              v_num_cuota,v_pal_cta_abo,v_pal_ven_cuo, v_pal_com_des, v_pal_com_otros;

            --dbms_output.put_line('Luego de la llamada palpropnro'||v_pal_prop_nro||'');
           -- if(v_pal_prop_nro is not null) then
            v_encontrado := 1;
            --end if;

          exception
                when no_data_found  then null;
             --   dbms_output.put_line('No se encontro la informacion en '||v_biblioteca);

          end;

          --Ya se buscaron en todas las bibliotecas
          if(trim(v_biblioteca) = 'MAE310106') then
             v_finalizado := 1;
          end if;

          if(v_encontrado = 1 or v_finalizado = 1) then

          --   v_mes_actual := to_char(sysdate,'MM');
          --   v_mes := to_char(sysdate,'MM');


             insert into pr_info_solicitud(riesgo,sucursal,propuesta,propfecha,
                         ade_venc,encontrado,tipo_prest,biblioteca,congru,modalidad,
                         num_cuotas, cta_abono, per_venc_cap,com_des,com_otros)
                    values (c_riesgo,c_sucursal,c_propuesta,
                            c_propfecha,v_ade_venc,decode(v_encontrado,1,'S','N'),
                            trim(c_tip_prestamo),v_biblioteca, c_congru,
                                 v_modalidad,v_num_cuota,v_pal_cta_abo,v_pal_ven_cuo,
                                 v_pal_com_des, v_pal_com_otros);
             commit;

             v_biblioteca := 'MAEACT';
          end if;

       --   dbms_output.put_line('finalizado: '||to_char(v_finalizado)||' Encontrado: '||v_encontrado);
    end loop;
    END LOOP;
    CLOSE cur_prestamos;
    mig_pr_log_registrar('Fin OBTENER_INFO_SOLICITUD_PR','TP2');*/
exception
       when others then
            raise_application_error(-20000,'Error inesperado - '||sqlcode||' Msg: '||sqlerrm||'Biblioteca: '||v_biblioteca||
                                                  ' v_mes_actual: '||v_mes_actual||' v_mes: '||v_mes);
           -- registrar_error_fase3('OBTENER_INFO_SOLICITUD_PR',
             --                     null,
               --                   'Error inesperado - '||sqlcode||' Msg: '||sqlerrm,'PR'
                 --                 );
end;

FUNCTION "RSHK_NUM2DATE_AAAAMMDD" (p_date number)
return date
is
  cdate date;
  cyear varchar2(4);
  cmonth varchar2(2);
  cday varchar2(2);
  vdate varchar2(12);
begin
  if (p_date = 0) then
     return null;
  end if;
  if (p_date is null) then
     return null;
  end if;

  vdate := to_char(p_date);

  if (LENGTH(vdate) = 8) then
    cday:=substr(vdate,7,2);

    --if(cday = '00') then
      --cday := '01';
-- end if;

    cmonth:=substr(vdate,5,2);
  --  if(cmonth = '00') then
    --  cmonth := '01';
    --end if;
    if(cday = '00' or cmonth = '00') then
       return null;
    end if;
    cyear:=substr(vdate,1,4);
    select to_date(cday||cmonth||cyear,'ddMMyyyy') into cdate from dual;
    return cdate;
  else
    --raise_application_error(-20000,'La fecha '||vdate||' no tiene el formato apropiado');
    return null;
  end if;
  exception
  WHEN OTHERS THEN return null;
  --raise_application_error(-20001,'error al convertir fecha'||p_date||' - '||cday||cmonth||cyear);
end;

FUNCTION "GET_PRINCIPAL" (p_divisa IN NUMBER, p_riesgo IN NUMBER,
p_suc IN NUMBER, p_propuesta IN NUMBER, p_congru IN NUMBER)
RETURN NUMBER
IS
       v_principal NUMBER(18,5) := 0;
BEGIN

        /*  if(p_divisa is null or p_divisa = 0) then
                 select nvl(sum(guaranies),0) into v_principal from maeact_maecartera
                  where NURIES = p_riesgo
                     and SUCURSALFU = p_suc and PROPUESTA = p_propuesta
                         and substr(trim(congru),1,3) <> '257';
          else
                 select nvl(sum(contravalo),0) into v_principal from maeact_maecartera
                  where NURIES = p_riesgo
                     and SUCURSALFU = p_suc and PROPUESTA = p_propuesta
                          and substr(trim(congru),1,3) <> '257';
          end if;*/

        RETURN v_principal;
EXCEPTION
        when no_data_found then
             mig_pr_error_log_registrar('GET_PRINCIPAL',p_riesgo,
             'No se encontró información en MAECARTERA - cliente: '||p_riesgo||' - sucursal: '||p_suc||' - propuesta: '||p_propuesta,
             'TP2');
        when others then
             mig_pr_error_log_registrar('GET_PRINCIPAL',p_riesgo,
             'Error inesperado - cliente: '||p_riesgo||' - sucursal: '||p_suc||' - propuesta: '||p_propuesta,
             'TP2');
END;


FUNCTION "GET_INTERESES_PR" (p_riesgo IN NUMBER, p_suc IN NUMBER, p_propuesta IN NUMBER, p_congru IN NUMBER, v_iadinteres OUT NUMBER, v_intereses OUT NUMBER)
RETURN NUMBER
IS

   /*v_iadinteres NUMBER(18,5) := 0;
   v_intereses NUMBER(18,5)  := 0;*/

BEGIN

  /* select nvl(sum(mc.iadinteres),0) into v_iadinteres from
   maeact_maecartera mc
   where mc.nuries = p_riesgo
   and mc.sucursalfu = p_suc
   and mc.propuesta = p_propuesta
   and substr(trim(mc.congru),1,3) <> '257';

   select nvl(sum(mp.interes),0) into v_intereses from maeact_maeicpc mp
   where mp.riesgo = p_riesgo
   and mp.sucursal = p_suc
   and mp.propuesta = p_propuesta
   and substr(trim(mp.rubrocr),1,3) <> '257';*/

    return (v_iadinteres+v_intereses);
END;

FUNCTION "PR_OBTENER_CTA_ORIGINAL" (p_filler varchar2, p_propren number, p_cta_original varchar2, p_divisa number)
return varchar2
/*
Se puede obtener la cuenta original del préstamo mirando los dígitos 8 al 11 de la cuenta del préstamo y
asociándolo con el campo filler de MAEACT/CTASGES.
*/
is
       v_cantidad number(5);
       v_cta_original varchar2(15);
       v_grupo varchar2(3);
       v_d5d6  varchar2(2);
begin
       /*Se ve cuantas cuentas diferentes están asociadas para el filler
       (dígitos 8 al 11 de la cuenta actual)*/
       /*select count(*) into v_cantidad from maeact_ctasges
              where trim(filler) = p_filler;*/
/*
       --Si no hay ninguna, se retorna nll
       if(v_cantidad = 0)then
          raise_application_error(-20001, 'No hay cuenta asociada al filler: '||p_filler
                                          ||'- Cuenta original: '||p_cta_original);

       --Si hay solo una, se obtiene la cuenta original, para ese filler
       elsif(v_cantidad = 1) then

          select trim(cuenta) into v_cta_original
                 from maeact_ctasges where trim(filler) = p_filler;
       else

           select substr(trim(cuenta),1,3) into v_grupo
                  from maeact_ctasges where trim(filler) = p_filler and rownum < 2;

          if(p_propren > 3) then
             raise_application_error(-20001, 'Valor de PROPREN inválido: '
                                             ||p_propren||'- Cuenta original: '||p_cta_original);
           end if;
           if(p_filler = '7353') then--Este filler indica préstamos al personal,para este tipo de préstamos
              v_d5d6 := '04';  --no importa el valor de propren para el varlor de los digitos 5 y 6
           elsif(v_grupo = '169') then
              if(p_propren = 0) then --Préstamo Nuevo
                 v_d5d6 := '02';
              elsif(p_propren = 1)then--Préstamo Renovado
                 v_d5d6 := '04';
              elsif(p_propren = 2)then--Refinanciado
                 v_d5d6 := '06';
              elsif(p_propren = 3) then--Reestructurado
                 v_d5d6 := '08';
              end if;
           elsif(v_grupo = '173')then
              if(p_propren = 0) then --Préstamo Nuevo
                 v_d5d6 := '02';
              elsif(p_propren = 1)then--Préstamo Renovado
                 v_d5d6 := '06';
              elsif(p_propren = 2)then--Refinanciado
                 v_d5d6 := '08';
              elsif(p_propren = 3) then--Reestructurado
                 v_d5d6 := '10';
              end if;
           else
             raise_application_error(-20001, 'Grupo con mas de una cuenta original, no manejado '||v_grupo
                                             ||p_propren||'- Cuenta original: '||p_cta_original);

           end if;
          --Si no es un préstamo al personal
          if(p_filler <> '7353') then
            select trim(cuenta) into v_cta_original
                   from maeact_ctasges where trim(filler) = p_filler
                        and substr(trim(cuenta),1,3)= v_grupo
                            and substr(trim(cuenta),5,2)= v_d5d6;
          else --Es un préstamo al personal

            select trim(cuenta) into v_cta_original
                   from maeact_ctasges where trim(filler) = p_filler
                        and substr(trim(cuenta),1,3)= v_grupo
                            and substr(trim(cuenta),5,2)= v_d5d6
                                and substr(trim(cuenta),7,5) = decode(p_divisa,0,'00104','00105');
          end if;
       end if;*/

       return v_cta_original;
exception
      when too_many_rows then
             raise_application_error(-20001, 'Demasiadas cuentas originales encontradas para el filler: '||p_filler||'- grupo:'||v_grupo||'- digs 5 y 6: '||v_d5d6
                                             ||p_propren||'- Cuenta original: '||p_cta_original);
      when others then
             raise_application_error(-20001, 'Error inesperado - Cuenta original: '||p_cta_original||' p_filler: '
             ||p_filler||' v_grupo: '||v_grupo||' v_d5d6: '||v_d5d6||sqlerrm);

end;


FUNCTION "GET_SCHEME_CODE" (p_congru varchar2, p_nuries number, p_sucursalfu number,
p_propuesta number, p_sector out varchar2, p_propren in number, p_divisa number, p_procdnt number) RETURN VARCHAR2
IS
  v_gl varchar2(3);
  v_scheme_code varchar2(5);
  v_propcednt number;
  v_propren number;
  v_temp varchar2(5);
  v_congru varchar2(15);
BEGIN
  v_gl := substr(p_congru,1,3);
  v_congru := p_congru;
  v_propren := p_propren;
  v_propcednt := p_procdnt;
  v_scheme_code := '-1';
  p_sector := '-1';

  v_temp := substr(trim(p_congru),7,5);
  --Para los casos de préstamos Vencidos (Congru 265 - 61 a 90 dias de mora),
  --En Gestión (Congru 269 - 91 a 180 días de mora) y Morosos  (Congru 275 - Más de 180 días de mora),
  --se tiene que tener la cuenta contable original para poder asociar a alguna modalidad
  if(v_gl = '265' or v_gl = '269' or v_gl = '275') then
      v_congru := pr_obtener_cta_original(substr(trim(p_congru),8,4),p_propren,p_congru,p_divisa);
      v_temp := substr(trim(v_congru),7,5);
      v_gl := substr(v_congru,1,3);
  end if;
  --Si es un prestamo del sector financiero
  if(v_gl = '131' or v_gl = '141' or v_gl = '417') then

        case v_gl
             when '131' then--Sector financiero, Corporativos
                  if(v_propcednt <> 0) then --Compra de Cartera
                      v_scheme_code := '622';
                  elsif(v_temp in ('50402','50502','50501','70102')) then--Prestamos a la Vista  -  Sect. Financiero
                      v_scheme_code := '61';
                      p_sector := '602';
                  elsif(v_temp = '10002') then--Fomento Agricola USD
                      v_scheme_code := '61';
                      p_sector := '102';
                  elsif(v_temp = '50051') then --Otros fines GS.
                      v_scheme_code := '61';
                      p_sector := '901';
                  else
                      v_scheme_code := '-1';
                 end if;
               when '141' then
                         if(substr(trim(v_congru),5,2) = '07' and v_temp in('00041','00042')) then --ANTICIPO DOC.EXPORTACION
                            v_scheme_code := '64';
                            p_sector := '602';
                         elsif(v_temp in('00041','00042','50041','50042')) then
                            v_scheme_code := '62'; --Sector Finanaciero,Descuento de Documentos
                            p_sector := '602';
                         end if;
               when '417' then--Sector Financiero, Reestructurados, Refinanciados, Renovados
                  p_sector := '602';
                  begin
                    case v_propren
                       when 1 then v_scheme_code := '617'; --Renovado
                       when 2 then v_scheme_code := '618';--Refinanciado
                       when 3 then v_scheme_code := '619'; --Reestructurado
                    end case;
                 exception when no_data_found then null;
                 end;
        end case;

   --Descuento de cheques
   elsif(v_gl = '405') then
       if(v_temp = '50041') then --Cheques de Pago Diferidos - Descontados
            v_scheme_code := '608';
            p_sector := '602';
       end if;
   --Descuento de documentos, No financiero
   elsif(v_gl = '351') then
          if( v_temp in ('50041','50042')) then
            v_scheme_code := '62';
            p_sector := '602';
          elsif(v_temp in ('50043','50044')) then --Doc. S/ Ext. Descontados L. AVAL,Doc. S/ Ext. Descontados LC
            v_scheme_code := '64';
            p_sector := '602';
          end if;
   --Adelantos de importaciones
   elsif(v_gl = '197') then
       if(substr(trim(v_congru),5,2) = '01' and
            v_temp in ('50101','50111','50112','50113','50114')) then--Adel. De Importadores - Credito Irrevocable
            v_scheme_code := '63';
            p_sector := '998';
       elsif(substr(trim(v_congru),5,2) = '01' and v_temp = '50121') then --Adel. De Importadores - Credito Irrevocable Conv. ALADI
            v_scheme_code := '63';
            p_sector := '999';
       end if;
   elsif(v_gl = '209') then
        if(substr(trim(v_congru),5,2) = '04') then
           v_scheme_code := '628';

          if(v_temp in ('10001','10002','10121')) then p_sector := '102'; --AGRICOLA - EMPRESAS
          elsif(v_temp in ('20021','20022')) then p_sector := '202';--GANADERO - EMPRESAS
          elsif(v_temp in ('30101','30111')) then p_sector := '302'; --INDUSTRIAL - EMPRESAS
          elsif(v_temp in ('40041','40042')) then p_sector := '501'; --CONSTRUCCION - PARTICULARES
          elsif(v_temp in ('50061','50062')) then p_sector := '402'; --EXPORTACION - EMPRESAS
          elsif(v_temp in ('50471','50472')) then p_sector := '901'; --OTROS FINES - PARTICULARES
          elsif(v_temp in ('50401','50501')) then p_sector := '602'; --COMERCIAL - EMPRESAS
          elsif(v_temp ='50411') then p_sector := '704'; --PTMOS.PNLES. OTRAS FINALIDADES
          elsif(v_temp ='50421') then p_sector := '602'; --COMERCIO-OTRAS FINALIDADES
          elsif(v_temp in ('50431','50531')) then p_sector := '701'; --PRESTAMOS - BEX VIVIENDA
          elsif(v_temp in ('50432','50532')) then p_sector := '702'; --H20 HIPOTECARIO FACIL
          elsif(v_temp in ('50441','50541','50442','50542')) then p_sector := '703'; --BEX AUTO, CREDITON AUTO
          elsif(v_temp in ('50561','50601')) then p_sector := '602'; --PARA ADQUISIC.Y EQUIP.P/SERV.PROF.,PREST.PAG.M/E-CARTA D/CRED.
          end if;

        end if;
   --Prestamo del Sector Publico
   elsif(v_gl = '215') then

           if(v_temp in('50401','50501','50421')) then--Prestamos C/Pagare - Sector Publico
                  v_scheme_code := '61';
                  p_sector := 602;
           elsif(v_propcednt <> 0) then--Compra de Cartera del sector puslico
                  v_scheme_code := '622';
           else--Prestamo corporativo normal al sector publico
                  v_scheme_code := '-1';
           end if;

   --Prestamo amortizable  No financiero, No al sector publico
    elsif(v_gl = '173') then
        v_temp := substr(trim(v_congru),7,5);

       if(substr(v_congru,5,2) = '04') then--Prestamos o Adelantos al Personal
            case
                 when v_temp = '00104' or v_temp = '00105' --Prestamos al personal
                      then  v_scheme_code := '60';
                 when v_temp = '00001'
                      then v_scheme_code := '672'; --Adelantos de Salario
                  else v_scheme_code := '-1';
            end case;
       --Prestamos Nuevos
       elsif(substr(v_congru,5,2) = '02') then

           if(v_propcednt <> 0) then--Compra de Cartera, No Financiero
              v_scheme_code := '622';
           elsif(v_temp = '50402' or v_temp = '50502') then  --Prestamos Amort. a la Vista
                v_scheme_code:='61';
                p_sector := '602';
           elsif(v_temp = '50401' or v_temp = '50501') then --Prestamos Amort. - Comercial
                v_scheme_code:='61';
                p_sector := '602';
           elsif(v_temp = '50421') then --Prestamos Amort. - Comercio Otras Finalidades
                v_scheme_code:='61';
                p_sector := '602';
           elsif(v_temp = '50561') then --Prestamos Amort. - Adquis. Y Equipos Prof.
                v_scheme_code:='61';
                p_sector := '602';
           elsif(v_temp = '50601') then --Prestamos Amort. - Carta de Credito
                v_scheme_code:='61';
                p_sector := '602';
           elsif(v_temp = '50431' or v_temp = '50531') then --BEX Vivienda
                v_scheme_code:='610';
                p_sector := '701';
           elsif(v_temp = '50432' or v_temp = '50532') then--Prestamos H20/H30 todavia esta pendiente como
                v_scheme_code:='673';                --identificar los distintos tipos de prestamos hipotecarios
                p_sector := '-1';
           elsif(v_temp in('10001','10002','10121'))then--Prestamos Amortizable C/ Pagare  AGRICOLA - EMPRESAS
                v_scheme_code := '61';
                p_sector := '102';
           elsif(v_temp in('20021','20022'))then --Prestamos Amortizable C/ Pagare  GANADERO - EMPRESAS
                 v_scheme_code := '61';
                 p_sector := '202';
           elsif(v_temp in('30101','30111'))then --Prestamos Amortizable C/ Pagare  INDUSTRIAL - EMPRESAS
                 v_scheme_code := '61';
                 p_sector := '302';
           elsif(v_temp in('40041','40042'))then --Prestamos Amortizable C/ Pagare  CONSTRUCCION - PARTICULARES
                 v_scheme_code := '61';
                 p_sector := '501';
           elsif(v_temp in('50061','50062'))then --Prestamos Amortizable C/ Pagare  EXPORTACION - EMPRESAS
                 v_scheme_code := '61';
                 p_sector := '402';
           elsif(v_temp in('50471','50472'))then --Prestamos Amortizable C/ Pagare  OTROS FINES - PARTICULARES
                 v_scheme_code := '61';
                 p_sector := '901';
           elsif( v_temp = '50051' or v_temp = '50052') then--Prestamo p/ Consumo
                 v_scheme_code := '65';
                 p_sector := '701';
           elsif(v_temp = '50433' or v_temp = '50533') then --Prestamo Personal Facil
                 v_scheme_code := '68';
                 p_sector := '701';
           elsif(v_temp in('50451','50551'))then --BEX Informatica
                 v_scheme_code := '65';
                 p_sector := '701';
           elsif(v_temp = '50411') then --Prestamos Personales - Otra Finalidad
                 v_scheme_code := '65';
                 p_sector := '704';
           elsif(v_temp in('50441','50541','50442','50542'))then --BEX Informatica
                 v_scheme_code := '65';
                 p_sector := '703';
           end if;
       elsif(substr(v_congru,5,2) in ('06','08','10')) then --Prestamos renovados

          if(v_temp in ('10001','10002','10121')) then p_sector := '102';
          elsif(v_temp in ('20021','20022')) then p_sector := '202';
          elsif(v_temp in ('30101','30111')) then p_sector := '302'; --INDUSTRIAL - EMPRESAS
          elsif(v_temp in ('40041','40042')) then p_sector := '501'; --CONSTRUCCION - PARTICULARES
          elsif(v_temp in ('50061','50062')) then p_sector := '402'; --EXPORTACION - EMPRESAS
          elsif(v_temp in ('50471','50472')) then p_sector := '901'; --OTROS FINES - PARTICULARES
          end if;

          if(substr(v_congru,5,2) = '06') then
             v_scheme_code := '623';
          elsif(substr(v_congru,5,2) = '08') then --Refinanciados
             v_scheme_code := '624';
          elsif(substr(v_congru,5,2) = '10') then -- Reestructurados
              v_scheme_code := '625';
          end if;
       end if;
   --?Prestamos con Vencimiento Unico, No financiero, No al Sector Publico
   elsif(v_gl = '169') then
        v_temp := substr(trim(v_congru),7,5);

        --Prestamos Nuevos
        if(substr(v_congru,5,2) = '02') then
          if(v_temp = '50402' or v_temp = '50502') then --Prestamos No Amort. a la Vista
                v_scheme_code := '61';
                p_sector := '602';
          elsif(v_temp = '50401' or v_temp = '50501') then --Prestamos No Amort. - Comercial
                v_scheme_code := '61';
                p_sector := '602';
          elsif(v_temp = '50601')then --Prestamos No Amort. Carta de Credito
                v_scheme_code := '61';
                p_sector := '602';
          elsif(v_temp in ('50441','50541')) then   --BEX AUTO - No Amort.
                v_scheme_code := '65';
                p_sector := '703';
          else  --Otros préstamos a plazo fijo
                v_scheme_code := '61';

                if( v_temp in ('10001','10002','10121')) then --AGRICOLA - EMPRESAS
                    p_sector := '102';
                elsif( v_temp in ('20021','20022')) then  --GANADERO - EMPRESAS
                    p_sector := '202';
                elsif( v_temp in ('30101','30111')) then  --INDUSTRIAL - EMPRESAS
                    p_sector := '302';
                elsif( v_temp in ('40041','40042')) then  --CONSTRUCCION - PARTICULARES
                    p_sector := '501';
                elsif( v_temp in ('50061','50062')) then  --EXPORTACION - EMPRESAS
                    p_sector := '402';
                elsif( v_temp in ('50471','50472')) then  --OTROS FINES - PARTICULARES
                    p_sector := '901';
                end if;

          end if;
        elsif(substr(v_congru,5,2) in ('04','06','08')) then --Renovados
          if(v_temp in ('10001','10002','10121')) then p_sector := '102';
          elsif(v_temp in ('20021','20022')) then p_sector := '202';
          elsif(v_temp in ('30101','30111')) then p_sector := '302'; --INDUSTRIAL - EMPRESAS
          elsif(v_temp in ('40041','40042')) then p_sector := '501'; --CONSTRUCCION - PARTICULARES
          elsif(v_temp in ('50061','50062')) then p_sector := '402'; --EXPORTACION - EMPRESAS
          elsif(v_temp in ('50471','50472')) then p_sector := '901'; --OTROS FINES - PARTICULARES
          end if;

          if(substr(v_congru,5,2) = '04') then
               v_scheme_code := '623';
          elsif(substr(v_congru,5,2) = '06') then --Refinanciados
             v_scheme_code := '624';
          elsif(substr(v_congru,5,2) = '08') then --Reestructurados
             v_scheme_code := '625';
          end if;

        end if;
   elsif(v_gl = '273') then-- Deudores en plan de regularizaciòn
         v_temp := substr(trim(v_congru),7,5);
         if(v_temp = '10001') then
                v_scheme_code := '674';
                p_sector := '102';   --Agricola - Empresas
         elsif(v_temp = '16950') then
                v_scheme_code := '674';
                p_sector := '602';--Comercial - Empresas
         else
                v_scheme_code := '-1';
                p_sector := '-1';
         end if;
   end if;
  return v_scheme_code;
 EXCEPTION
   when others then raise_application_error(-20000,'Error al obtener modalidad: '||sqlerrm);
END;

FUNCTION "RSHK_OBTENER_NUM_CUENTA" (p_ctasuc IN NUMBER, p_tipocta IN NUMBER, p_subcta IN NUMBER)
RETURN VARCHAR2
IS
  v_accnumber varchar2(15) := null;
  v_sub_tmp VARCHAR2(10) := NULL;
BEGIN

  v_accnumber:=TO_CHAR(p_ctasuc);
  if( length(v_accnumber)=1 ) Then
      v_accnumber := '0'||v_accnumber;
  end if;
  if( p_tipocta = 210100 or p_tipocta = 215000 or p_tipocta = 700 or p_tipocta = 709 ) then
    v_accnumber:=v_accnumber||'01';
  elsif( p_tipocta = 210500 or p_tipocta = 711 or p_tipocta = 215500 or p_tipocta = 719 ) then
    v_accnumber:=v_accnumber||'02';
  else
    RAISE_APPLICATION_ERROR(-20000,'NO SE PUEDE DETERMINAR EL TIPO DE CUENTA');
  end if;

  v_sub_tmp := TO_CHAR(p_subcta);
  WHILE (length(v_sub_tmp)<6) LOOP
        v_sub_tmp := '0'||v_sub_tmp;
  END LOOP;
  v_accnumber := v_accnumber||v_sub_tmp;

  return v_accnumber;
EXCEPTION
   when others then
      raise_application_error(-20001,'Error imprevisto al obtener un numero de cuenta para la sucursal'
       || p_ctasuc||' Tipo '||p_tipocta||' y numero '||p_subcta);
END;

FUNCTION "RSHK_NUM2DATE_AMMDD" (p_date number)
return date
is
  cdate date;
  cyear varchar2(4);
  cmonth varchar2(2);
  cday varchar2(2);
  vdate varchar2(12);
begin
  if (p_date = 0) then
     return null;
  end if;
  if (p_date is null) then
     return null;
  end if;

  vdate := to_char(p_date);

  if (LENGTH(vdate) = 5) then
    cday:=substr(vdate,4,2);
    cmonth:=substr(vdate,2,2);
    cyear:='200'||substr(vdate,1,1);
    select to_date(cday||cmonth||cyear,'ddMMyyyy') into cdate from dual;
  end if;

  return cdate;

  exception
    when others then
        ---raise_application_error(-20001,'error al convertir fecha'||p_date||' - '||cday||cmonth||cyear);
      return null;
end;

PROCEDURE "ACTUALIZAR_INFO_PRESTAMOS"
IS

       /*CURSOR cur_prestamos IS
              select ln.nuries, ln.sucursalfu, ln.propuesta
              from loans_numero_cuenta ln;*/

       c_riesgo number;
       c_sucursal number;
       c_propuesta number;
       c_propfecha number:=null;
       c_propmonto number(18,4):=null;
       c_propdivisa number := null;
       c_tasamax number(18,4) := null;
       c_propvto number;
       v_cuenta_debito varchar2(15):=null;
       v_suc number;
       v_cta number;
       v_sub number;
       v_loan_cat varchar2(3);
       v_loan_subcat varchar2(5);
       v_loan_descripcion varchar2(120);
       v_filler varchar2(60);
       v_tipo_prestamo char(1):= 'A';
       v_congru varchar2(40);
       v_scheme_code varchar2(5);
       v_total_interes number(18,5);
       v_total_principal number(18,5);
       v_iaddias number;
       v_sgte_venc_cuota date;
       v_sgte_venc_cuota_pos_mig date;
       v_tot_gastosgc number(18,5);
       v_tasa_cuota_pos_mig number(5,3);
       v_propren number(5);
       v_procdnt number(10);
       v_nrofact number(10);
       v_observ varchar2(1000);
       v_sector varchar2(10);
       v_monto_total_riesgo number(20,2);
       v_propdestin number(5);
       v_es_afd varchar2(1);
       v_can_cuotas number(5);
       v_total_props_cliente number(20,2);
       v_temp varchar2(5);
       v_intmaecartera number(18,2);
       v_intmaeicpc number(18,2);
       v_fechaemisi number(18,2);
       v_primera_fecha_venc number(10);
       v_can_misma_fecha number(10);
       v_propmonto_me number(18,2);
       v_max_vto_maecartera date;
       v_max_vto_maeicpc date;
       v_propvto date;
       v_fec_emision date := null;
       v_fec_contabiliz date := null;
       v_fec_propuesta date := null;
BEGIN

  /*  OPEN cur_prestamos;
    LOOP
    FETCH cur_prestamos INTO c_riesgo, c_sucursal, c_propuesta;
    EXIT WHEN cur_prestamos%NOTFOUND;

    c_propfecha  := null;
    c_propmonto  := null;
    c_propdivisa := null;
    c_tasamax := null;
    c_propvto := null;
    v_suc     := null;
    v_cta     := null;
    v_sub     := null;
    v_congru  := null;
    v_loan_cat    := null;
    v_loan_subcat := null;
    v_filler      := null;
    v_loan_descripcion := null;
    v_iaddias := null;
    v_propren := null;
    v_procdnt := null;
    v_nrofact := null;
    v_observ  := null;
    v_monto_total_riesgo := 0;
    v_propdestin      := null;
    v_can_cuotas      := null;
    v_es_afd          := null;
    v_total_props_cliente := null;
    v_temp            := null;
    v_intmaecartera   := 0;
    v_intmaeicpc      := 0;
    v_primera_fecha_venc := null;
    v_can_misma_fecha := 0;
    v_propmonto_me    := 0;
    v_fechaemisi      := 0;
    v_max_vto_maecartera := null;
    v_max_vto_maeicpc := null;
    v_propvto        := null;
    v_fec_emision    := null;
    v_fec_contabiliz := null;
    v_fec_propuesta  := null;

    begin
        select sum(mp.propmonto) into
                v_monto_total_riesgo from maeperm_propuemae mp
                      where  mp.propclien = c_riesgo;
    exception
           when no_data_found then v_monto_total_riesgo := 0;
    end;

      begin
        -- Se obtiene informacion del tipo de prestamo (categoria, subcategoria y descripcion)
        select m.congru, substr(m.congru,1,3), substr(m.congru, 7,5),
               m.filler, p.plantitulo, m.iaddias, m.iaddivisa, m.fechaemisi
               into v_congru, v_loan_cat, v_loan_subcat,
               v_filler, v_loan_descripcion,v_iaddias,c_propdivisa,v_fechaemisi
          from maeact_maecartera m inner join maeact_plan95 p on(m.congru = p.clavebex)
             where m.sucursalfu = c_sucursal and m.nuries = c_riesgo and m.propuesta = c_propuesta
                  and
                   (((substr(to_char(p.clavebcp1),1,2) in ('13','14'))
                     or
                    (substr(to_char(p.clavebcp1),1,2) in ('16','51') and
                     substr(to_char(m.congru),7,5) not in ('10031','10032','20031', '20032', '30031', '30032','10041','20041','30041'))
                    ) and substr(to_char(m.congru),1,3) != '205'
                      and substr(to_char(m.congru),1,3) not like '6%')
                and rownum < 2;

                if(substr(trim(v_filler),1,1) = '3')then
                    v_tipo_prestamo := 'F';
                else
                    v_tipo_prestamo := 'A';
                end if;
      EXCEPTION
          when NO_DATA_FOUND then
               mig_pr_error_log_registrar( 'ACTUALIZAR_INFO_PRESTAMOS',c_riesgo,
               'No se encontro ningun dato en MAECARTERA para el riesgo: '||
                c_riesgo ||' la sucursal: '||c_sucursal||' y la propuesta: '||c_propuesta,'TP2');

      end;
      --Se calcula el total de intereses pendientes de pago
      v_total_interes := get_intereses_pr(c_riesgo, c_sucursal, c_propuesta,v_congru,v_intmaecartera,v_intmaeicpc);
      --Se calcula el total de capital pendientes de pago
      v_total_principal := get_principal(c_propdivisa,c_riesgo,c_sucursal,c_propuesta,v_congru);

      begin
       --Se obtiene informacion de MAEPERM/PROPUEMAE para guardar en la tabla
       --temporal loans_numero_cuenta, y  poder acceder rapidamente en el procedimiento de migracion
        select mp.propfecha, mp.propmonto, mp.proptasamx, mp.propvto, mp.propren,mp.propcednt,
               mp.propnrofac, mp.propobs1||' '||mp.propobs2||' '||mp.propobs3||' '||mp.propobs4, mp.propdestin, mp.propme
             into c_propfecha, c_propmonto, c_tasamax, c_propvto,
             v_propren,v_procdnt,v_nrofact,v_observ,v_propdestin,v_propmonto_me
             from maeperm_propuemae mp where mp.propclien = c_riesgo
                  and mp.propsuc = c_sucursal and mp.propnro = c_propuesta;

             if(c_propdivisa <> 0) then
                c_propmonto := v_propmonto_me;
             end if;

      EXCEPTION
          when TOO_MANY_ROWS then
             mig_pr_error_log_registrar('ACTUALIZAR_INFO_PRESTAMOS',c_propuesta,
             'Aparece mas de una vez en MAEPERM/PROPUEMAE suc: '||c_sucursal||' riesgo: '||c_riesgo||' propuesta: '||c_propuesta,'TP2');
          when NO_DATA_FOUND then

          v_temp := substr(v_congru,7,5);--Los digs 7 al 11 de la cta suelen indicar el tipo de préstamo
                                         --Comercial, Ganadero, De Consumo, etc.

          --Si es un préstamo a la vista, se saca la información necesaria, de la única cuota que tiene
          --el préstamo
          if(trim(v_temp) = '50402'or v_temp = '50502'
                    or (substr(v_congru,1,3)<>'197' and substr(v_congru,4,1) = '1')) then

               --Fecha de la propuesta
               --(M.A indicó q debe ser la fecha de contabilización,
               --R.G indicó que en FECHAMISI de MAEACT/MAECARTERA se guarda la fecha de contabilización)
               c_propfecha := v_fechaemisi;

                --Fecha de vencimiento de la propuesta
                select to_number(to_char(rshk_num2date_aaaammdd(c.vencim),'ddMMyy')), c.iaddivisa
                into c_propvto,c_propdivisa
                    from maeact_maecartera c where c.nuries = c_riesgo and c.sucursalfu = c_sucursal
                          and c.propuesta = c_propuesta
                              and substr(trim(c.congru),1,3)  <> '257' and rownum < 2;
               --Monto de la propuesta
               c_propmonto := v_total_principal;
               v_monto_total_riesgo := v_monto_total_riesgo + c_propmonto;
          else --No es un préstamo vista, entonces se obtiene la informacion de una tabla especial
               --en las cuales se cargaron datos de los préstamos cuya información no podemos sacar del sistema
              begin
                 select to_number(to_char(r.propfecha,'ddMMyy')), r.propmonto,
                        to_number(to_char(r.propvto,'ddMMyy')), decode(trim(r.divisa),'GS',0,'USD',5)
                 into  c_propfecha,c_propmonto,c_propvto,c_propdivisa
                 from pr_sin_nro_propuesta r
                 where r.riesgo = c_riesgo and r.sucursal = c_sucursal and r.propuesta = c_propuesta;

                  v_monto_total_riesgo := v_monto_total_riesgo + c_propmonto;

             exception
                when too_many_rows then
                   mig_pr_error_log_registrar('ACTUALIZAR_INFO_PRESTAMOS',c_propuesta,
                   'Aparece mas de una vez en PR_SIN_NRO_PROPUESTA suc: '||c_sucursal||' riesgo: '||c_riesgo||' propuesta: '||c_propuesta,'TP2');

                when no_data_found then
                    mig_pr_error_log_registrar( 'ACTUALIZAR_INFO_PRESTAMOS',c_riesgo,
                    'No se encontro ningun dato en PROPUEMAE para el riesgo: '||
                    c_riesgo ||' la sucursal: '||c_sucursal||' y la propuesta: '||c_propuesta,'TP2');
              end;
          end if;
      end;

      begin
        --Se obtiene la modalidad del préstamo
        v_scheme_code := get_scheme_code(v_congru,c_riesgo,c_sucursal,c_propuesta, v_sector, v_propren,c_propdivisa,v_procdnt);
      exception
         when others then
           mig_pr_error_log_registrar('ACTUALIZAR_INFO_PRESTAMOS',c_riesgo, sqlerrm||'- Error al obtener MODALIDAD para el riesgo: '||
           c_riesgo ||' la sucursal: '||c_sucursal||' y la propuesta: '||c_propuesta,'TP2');
           v_scheme_code := '-1';
      end;
      begin
       --Se obtiene informacion de la cuenta asociada al prestamo, en caso de que el
       --prestamo tenga DEBITO AUTOMATICO y se guarda en la tabla, loans_numero_cuenta
       --para acceder de forma mas rapida
       select od.desuc, od.decta, od.desub into v_suc, v_cta, v_sub
          from olmaeact_deautocar od
              where od.deriesgo = c_riesgo and od.deprop = c_propuesta;

          v_cuenta_debito := rshk_obtener_num_cuenta(v_suc,v_cta,v_sub);

      EXCEPTION
          when too_many_rows then
             MIG_pr_error_log_registrar('ACTUALIZAR_INFO_PRESTAMOS',c_propuesta,
             'Aparece mas de una vez en OLMAEACT/DEAUTOCAR suc: '||c_sucursal||' riesgo: '||c_riesgo||' propuesta: '||c_propuesta,'PR');

          when NO_DATA_FOUND then NULL;

      end;


      --Se suma el total de gastos que tiene el préstamo
      select nvl(sum(gastosgc),0), min(rshk_num2date_aaaammdd(c.vencim)),count(*), min(c.vencim),
             max(rshk_num2date_aaaammdd(c.vencim))
             into v_tot_gastosgc,v_sgte_venc_cuota, v_can_cuotas,v_primera_fecha_venc,
                  v_max_vto_maecartera
             from maeact_maecartera c where c.nuries = c_riesgo and c.sucursalfu = c_sucursal
                  and c.propuesta = c_propuesta  and substr(trim(c.congru),1,3) <> '257'
                     group by c.nuries,c.sucursalfu,c.propuesta;

        begin
           --Se obtiene el maximo vencimiento de maeicpc para comparar con el maximo de maecartera
           --y asì sacar la fecha de vencimiento del prèstamo
           select max(rshk_num2date_aaaammdd(mi.vto)), min(rshk_num2date_ammdd(mi.fechcont))
            into v_max_vto_maeicpc, v_fec_contabiliz
                  from maeact_maeicpc mi
                       where mi.riesgo = c_riesgo
                             and mi.sucursal = c_sucursal
                                 and mi.propuesta = c_propuesta;
         exception
          when no_data_found then v_max_vto_maeicpc := null;
         end;
        --Se obtiene la fecha de vencimiento del prèstamo de acuerdo a la maxima fecha de vencimiento
        --encontrada en el detalle de las cuotas de maeicpc y maecartera
        if(v_max_vto_maeicpc is null or v_max_vto_maecartera >= v_max_vto_maeicpc) then
           v_propvto := v_max_vto_maecartera;
        else
           v_propvto := v_max_vto_maeicpc;
        end if;

        --Formula definida por L.A. para la fecha de inicio del prestamo
        v_fec_emision   := rshk_num2date_ddmmaa(v_fechaemisi);
        v_fec_propuesta := rshk_num2date_ddmmaa(c_propfecha);
        if(v_fec_emision < (v_fec_propuesta + 35))then
           v_fec_propuesta := v_fec_emision;
        elsif (v_fec_contabiliz is not null and v_fec_contabiliz < (v_fec_propuesta + 35))then
           v_fec_propuesta := v_fec_contabiliz;
        end if;
        --Si fue definido como un préstamo H20/H30 se verifica si no es un préstamo a la construcción
        --en periodo de construcción v_can_misma_fecha
        if(v_scheme_code = '673') then

          --Si la cantidad de registros de maecartera es igual a la cantidad de registros con la
          --misma fecha de vencimiento, entonces todos vencen en la misma fecha
          select count(*) into v_can_misma_fecha
             from maeact_maecartera c where c.nuries = c_riesgo and c.sucursalfu = c_sucursal
                  and c.propuesta = c_propuesta  and substr(trim(c.congru),1,3) <> '257'
                      and c.vencim = v_primera_fecha_venc;

            if(v_intmaecartera = 0 and v_intmaeicpc > 0 and v_can_cuotas = v_can_misma_fecha)then
               v_scheme_code := '612';
            end if;
        end if;

      begin
        --Fecha del sigte vencimiento de cuota, posterior a la migración
        select min(rshk_num2date_aaaammdd(c.vencim)) into v_sgte_venc_cuota_pos_mig
            from maeact_maecartera c where c.nuries = c_riesgo and c.sucursalfu = c_sucursal
                  and c.propuesta = c_propuesta
                      and substr(trim(c.congru),1,3) <> '257'
                        and rshk_num2date_aaaammdd(c.vencim) >= sysdate;
      exception
         when no_data_found then v_sgte_venc_cuota_pos_mig := null;
      end;

      begin
       --Si no hay cuota pendiente de pago posterior a la migracion (todas las cuotas están atradadas)
       --Se obtiene la fecha de la última cuota vencida
        if(v_sgte_venc_cuota_pos_mig is null) then
          select max(rshk_num2date_aaaammdd(c.vencim)) into v_sgte_venc_cuota_pos_mig
              from maeact_maecartera c where c.nuries = c_riesgo and c.sucursalfu = c_sucursal
                    and c.propuesta = c_propuesta
                        and substr(trim(c.congru),1,3)  <> '257';

        end if;

       select codtasa into v_tasa_cuota_pos_mig
                 from  maeact_maecartera c1 where c1.nuries = c_riesgo and c1.sucursalfu = c_sucursal
                      and c1.propuesta = c_propuesta
                          and substr(trim(c1.congru),1,3) <> '257'
                             and rshk_num2date_aaaammdd(c1.vencim) = v_sgte_venc_cuota_pos_mig
                              and rownum < 2;

      exception
             when no_data_found then null;
      end;

      --Para determinar si el préstamo es o no financiado por la AFD, se hace de esta forma
      --porque puede ser sólo parcialmente financiado por la AFD.
      select nvl(
        (select 'S' from dual where 209 in
                (select substr(trim(mc.congru),1,3)
                from maeact_maecartera mc
                inner join loans_numero_cuenta ln
                on (mc.nuries = ln.nuries and
                mc.sucursalfu = ln.sucursalfu and mc.propuesta = ln.propuesta)
                where mc.nuries = c_riesgo and mc.sucursalfu = c_sucursal and mc.propuesta = c_propuesta and substr(trim(mc.congru),1,3) <> '257'))
        ,'N') into v_es_afd from dual;


       --Se actualizan los datos en la tabla de numeros de cuenta de prestamos
      update loans_numero_cuenta lt set lt.propfecha = v_fec_propuesta, lt.propmonto = c_propmonto, lt.propvto = v_propvto,
             lt.divisa = c_propdivisa,  lt.tasa = v_tasa_cuota_pos_mig, lt.cuenta_debito = v_cuenta_debito, lt.cuenta_suc = v_suc,
             lt.tipo_cat_princ = v_loan_cat, lt.tipo_sub_cat = v_loan_subcat, lt.descripcion = v_loan_descripcion,
             lt.tipo_prestamo = v_tipo_prestamo, lt.congru = v_congru, lt.scheme_code = v_scheme_code,
             lt.total_interes = v_total_interes, lt.iaddias = v_iaddias, lt.sgte_venc_cuota = v_sgte_venc_cuota,
             lt.tot_gastosgc = v_tot_gastosgc, lt.total_principal = v_total_principal, lt.propren = v_propren,
             lt.propcdent = v_procdnt, lt.propnrofac = v_nrofact, lt.observaciones = v_observ, lt.sector = v_sector,
             lt.monto_total_riesgo = v_monto_total_riesgo, lt.propdestin = v_propdestin, lt.afd = v_es_afd,
             lt.can_cuotas_pen = v_can_cuotas, lt.total_props_cliente = null, lt.fec_contabilizacion = v_fechaemisi
             where lt.nuries = c_riesgo and lt.sucursalfu = c_sucursal and  lt.propuesta = c_propuesta;
      COMMIT;

    END LOOP;
    CLOSE cur_prestamos;*/
    NULL;

EXCEPTION WHEN OTHERS THEN
--raise_application_error(-20000,'Error inesperado '||SQLCODE||' '||SQLERRM);
MIG_pr_error_log_registrar('ACTUALIZAR_INFO_PRESTAMOS',null,'Error inesperado '||SQLCODE||' '||SQLERRM,'PR');
END;


PROCEDURE "RSHK_GENERAR_NUMEROS_CUENTA" (p_sucursal IN NUMBER, p_tipo varchar2)
IS

  /*CURSOR cur_maecartera(p_ctasuc number) IS
    select distinct m.nuries, m.propuesta
          from maeact_maecartera m inner join maeact_plan95 p on(m.congru = p.clavebex)
             where m.sucursalfu = p_ctasuc and
                   (((substr(to_char(p.clavebcp1),1,2) in ('13','14'))
                     or
                    (substr(to_char(p.clavebcp1),1,2) in ('16','51') and
                     substr(to_char(m.congru),7,5) not in ('10031','10032','20031', '20032', '30031', '30032','10041','20041','30041'))
                    ) and substr(to_char(m.congru),1,3) not in ('205','157')
                      and substr(to_char(m.congru),1,3) not like '6%'
                      and substr(to_char(m.congru),1,3) not like '0%');*/


  c_ctasuc number; --Oficina o sucursal de la cuenta
  c_tipocta number;--Tipo de cuenta
  c_subcta number;--Nro de cuenta
  c_divisa number;--Moneda

  c_serie varchar2(5);--Numero de serie (usado para la migracion de CDAs y PLF)
  c_riesgo number;--Numero cliente

  v_divisa char(2);
  v_seqnumber number; --Numero de secuencia
  v_accnumber char(12); --Numero de cuenta generado
  v_long_propuesta number;
  v_cantidad number := 0;
  v_cant_mismo_num_prop number := 0;
BEGIN

  IF(p_tipo = 'LAA') then

    /*OPEN cur_maecartera(p_sucursal);
    LOOP
       FETCH cur_maecartera INTO c_riesgo, c_subcta;
       EXIT WHEN cur_maecartera%NOTFOUND;
        v_cant_mismo_num_prop := 0;
        v_cantidad := 0;
        v_accnumber :=  lpad(trim(to_char(p_sucursal)),2,'0')||lpad(trim(to_char(c_subcta)),7,'0');

       --Se inserta en una tabla el numero de cuenta
      begin

        insert into loans_numero_cuenta(nuries,sucursalfu,propuesta,account_number)
        values(c_riesgo,p_sucursal,c_subcta,trim(v_accnumber));
        COMMIT;

      exception
          when others then
          loop
               --Se controla si ya se cargó otra propuesta con el mismo número
               select count(*) into v_cantidad from loans_numero_cuenta  ln
               where trim(ln.account_number) =  trim(v_accnumber);

              if(v_cantidad > 0)then
                  v_cant_mismo_num_prop := v_cant_mismo_num_prop + 1;
                  v_accnumber :=  lpad(trim(to_char(p_sucursal)),2,'0')||v_cant_mismo_num_prop||lpad((trim(to_char(c_subcta))),6,'0');
              end if;
           exit when v_cantidad = 0;
           end loop;

          if(v_cantidad > 0) then --Se crea el numero de propuesta, según lo definido ()
                insert into loans_numero_cuenta(nuries,sucursalfu,propuesta,account_number)
                values(c_riesgo,p_sucursal,c_subcta,trim(v_accnumber));
                COMMIT;
          else
              mig_pr_error_log_registrar('RSHK_GENERAR_NUMEROS_CUENTA',v_accnumber,'No se pudo generar el número de cuenta','PR');
          end if;
      end;

    END LOOP;
    CLOSE cur_maecartera;*/
    NULL;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
  raise_application_error(-20000,'Ha ocurrido un error '||SQLCODE||' -ERROR- '||SQLERRM);
END;

PROCEDURE "GENERAR_NUMEROS_CUENTA_SUC" (p_tipo in varchar2)
IS
BEGIN

  mig_pr_log_registrar('Inicio GENERAR_NUMEROS_CUENTA_SUC','TP2');
  /*IF(p_tipo = 'LAA') then
      delete from loans_numero_cuenta;
      commit;
  END IF;*/

  RSHK_GENERAR_NUMEROS_CUENTA(1,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(3,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(4,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(6,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(7,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(8,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(9,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(11,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(10,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(12,p_tipo);
   RSHK_GENERAR_NUMEROS_CUENTA(13,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(15,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(16,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(21,p_tipo);
  RSHK_GENERAR_NUMEROS_CUENTA(31,p_tipo);


  IF(p_tipo = 'LAA') then
    ACTUALIZAR_INFO_PRESTAMOS();
   END IF;
   mig_pr_log_registrar('Fin GENERAR_NUMEROS_CUENTA_SUC','TP2');
END;


PROCEDURE "RSHK_EXECUTE_CREATE_INDEX" (p_stmt in varchar2)
IS
BEGIN
  begin
    execute immediate p_stmt;
    mig_pr_log_registrar(p_stmt,'TP2');
  exception
  When Others Then
    mig_pr_error_log_registrar('TODO_PRESTAMOS2'
       ,0
       ,'Error al crear indice... '||' sqlerrm: '||sqlerrm||' stmt was: '||p_stmt
       ,'TP2');
  end;
END;

-- PROCS AND FUNCS PRINCIPALES

PROCEDURE "TODO_PRESTAMOS2"
as
begin
   pae_cnf.g_cod_modulo := 1;
  --Se borran los datos de las tablas a migrar
  /*delete mig_pr_log2 where modulo = 'TP2';
  commit;

  mig_pr_log_registrar('Borrados mig_pr_log2 where modulo = TP2','TP2');

  delete from mi_pr_cuotas;
  mig_pr_log_registrar('Borrado MI_PR_CUOTAS','TP2');
  delete from mi_pr_cta_prestamos;
  mig_pr_log_registrar('Borrado MI_PR_CTA_PRESTAMOS','TP2');
  commit;
*/
  mig_pr_log_registrar('creando indices','TP2');
  declare
    stmt varchar2(1000);
   begin
       stmt:='create index IDX_PR_MAECARTERA on MAEACT_MAECARTERA (NURIES, SUCURSALFU, PROPUESTA)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_PR_CONGRU on MAEACT_MAECARTERA (CONGRU)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_CLAVE_BCP1 on MAEACT_PLAN95 (CLAVEBCP1)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_PR_PROPUEMAE on MAEPERM_PROPUEMAE (PROPCLIEN, PROPSUC, PROPNRO)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_PR_DEAUTOCAR on OLMAEACT_DEAUTOCAR (DERIESGO, DEPROP)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_PR_MAEICPC on MAEACT_MAEICPC (RIESGO, SUCURSAL, PROPUESTA)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_FILLER on MAEACT_CTASGES (TRIM(FILLER))';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_PROPALIQ_ACT on MAEACT_PROPALIQ (PALSUC, PALPROPNRO, PALCLIENTE)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index IDX_PR_RIESGO on MAEPERM_PROPUEMAE (PROPCLIEN)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
       stmt:='create index idx_clavebex_plan on maeact_plan95(clavebex)';
       RSHK_EXECUTE_CREATE_INDEX(stmt);
  end;

  --Se generan los números de cuenta de préstamos y se cargan en la tabla
  --LOANS_NUMERO_CUENTA varios datos necesarios para la migración a IT
   generar_numeros_cuenta_suc('LAA');

  --Se busca información histórica de las solicitudes de préstamo y se carga dicha información
  --en la tabla PR_INFO_SOLICITUD
    obtener_info_solicitud_pr;

  --Los sectores que no pudieron ser mapeados, quedan con el códig -1 en el campo SECTOR
  --de la tabla LOANS_NUMERO_CUENTA, se actualiza ese dato para la migración
/*  update loans_numero_cuenta set sector = '999' where sector = '-1';
  commit;*/

  --Por si acaso, habilitar el trigger que carga la tabla GE_CUENTAS
  --execute immediate 'alter trigger it.ta_pr_cta_prestamos enable';

  --Llamada a los procedimientos de migración
  -- CF mig_pr_lineas;
  -- CF mig_pr_lin_aplicaciones;
  mi_mig_pr_cta_prestamos;
  mi_mig_pr_cuotas_v3;
  -- CF mig_pr_chq_libradores;
  -- CF mig_pr_cta_gastos;
  -- CF mig_pr_previsiones;
  -- CF mig_pr_solicitudes;

  -- CF crear_pr_nros_cta;
  --Procedimiento creado por Daissy para cargar en IT.GE_CTAS_CLIENTES
  -- CF it_ge_cta_clientes_pr;

end;

PROCEDURE "REGISTRAR_CAMBIO_CUOTA" (vNroCuenta in number, vFechaVenc in date, action in varchar2, text in varchar2) is
PRAGMA AUTONOMOUS_TRANSACTION;
  vID integer:=0;
begin
  NULL;
  /*SELECT migl_cambio_cuota_seq.nextval
    INTO  vID
    FROM dual;

  INSERT INTO migl_cambio_cuota (lcc_id,run_date,cuota_fec_vencimiento,cuota_nro_cuenta,action,text)
  VALUES (vID,sysdate,vFechaVenc,vNroCuenta,action,text);
  commit;*/
end;


PROCEDURE "REGISTRAR_CAMBIO_PRESTAMO" (vNroCuenta in number, action in varchar2, text in varchar2) is
PRAGMA AUTONOMOUS_TRANSACTION;
  vID integer:=0;
begin
  NULL;
  /*SELECT migl_cambio_prestamo_seq.nextval
    INTO  vID
    FROM dual;

  INSERT INTO migl_cambio_prestamo (lcp_id,run_date,prestamo_nro_cuenta,action,text)
  VALUES (vID,sysdate,vNroCuenta,action,text);

  COMMIT;*/
end;


PROCEDURE "TODO_PR_MEZCLADOR"
IS

CURSOR c is SELECT * FROM it.pr_cta_prestamos;
  CURSOR cMig
      IS
    SELECT *
      --FROM mi_pr_cta_prestamos;
      FROM pr_cta_prestamos;

  cuenta it.pr_cta_prestamos%ROWTYPE;
  --cuentaMig mi_pr_cta_prestamos%ROWTYPE;
  cuentaMig pr_cta_prestamos%ROWTYPE;

  CURSOR cuotasIt
      IS
    SELECT *
      FROM it.pr_cuotas;

  cuotaErrorCount integer := 0;
  prestamoErrorCount integer:= 0;
  newPrestamosCount integer := 0;

  newCuotasCount integer := 0;
  errorCount integer := 0;

  NoSePudoUpdateCuota EXCEPTION;
  NoSePudoUpdatePrestamos EXCEPTION;

  cuotaIt it.pr_cuotas%ROWTYPE;
  tmp number;
BEGIN
--  delete from mig_pr_log where modulo='PRM';
--  delete from mig_pr_error_log where modulo='PRM';
--  COMMIT;
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;



  mig_pr_log_registrar('TODO_PR_MEZCLADOR: INICIO','TP2');

  -- borramos logs viejos
/*  delete from migl_cambio_prestamo where run_date < (sysdate - 5);
  delete from migl_cambio_cuota where run_date < (sysdate - 5);*/


/*  select count(1)
    into tmp
    from mi_pr_cta_prestamos;*/

  if( tmp=0 ) then
      raise_application_error(-20001,'no hay prestamos at all');
  end if;

/*  select count(1)
    into tmp
    from mi_pr_cuotas;*/

  if( tmp=0 ) then
      raise_application_error(-20001,'no hay cuotas at all');
  end if;


  --Buscamos cuotas que **existen** en IT
  --y que no existen en MIG para cancelarlas
  mig_pr_log_registrar('Buscando cuotas que existen en IT '
                  ||'que no existen en MIG','TP2');
  OPEN cuotasIt;
  LOOP
       BEGIN
         FETCH cuotasIt INTO cuotaIt;
         EXIT WHEN cuotasIt%NOTFOUND;
         DECLARE
           --cuotaMig mi_pr_cuotas%ROWTYPE;
           cuotaMig pr_cuotas%ROWTYPE;
         BEGIN
           SELECT * INTO cuotaMig
             --FROM mi_pr_cuotas mc
             FROM pr_cuotas mc
            --WHERE mc.nro_cuota=cuotaIt.Nro_Cuota  Modificado por MC(15/01/2010)
              WHERE mc.fec_vencimiento = cuotaIt.Fec_Vencimiento
              AND mc.nro_cuenta=cuotaIt.Nro_Cuenta;

           IF( cuotaMig.sal_interes<>cuotaIt.Sal_Interes
              OR cuotaMig.sal_capital<>cuotaIt.Sal_Capital
              OR cuotaMig.sal_int_documentado<>cuotaIt.sal_int_documentado
              OR cuotaMig.val_recargo<>cuotaIt.val_recargo
              OR cuotaMig.estado<>cuotaIt.estado)
           THEN

             UPDATE it.pr_cuotas p
              --  SET ROW=cuotaIt Modificado por MC(15/01/2010)
              --  SET ROW=cuotaMig
                SET p.sal_interes=cuotaMig.sal_interes
                   ,p.sal_capital=cuotaMig.sal_capital
                   ,p.sal_int_documentado=cuotaMig.sal_int_documentado
                   ,p.val_recargo=cuotaMig.val_recargo
                   ,p.estado=cuotaMig.estado
              WHERE p.nro_cuenta = cuotaIt.Nro_Cuenta
                --AND p.nro_cuota = cuotaIt.Nro_Cuota;  Modificado por MC(15/01/2010)
                  AND p.fec_vencimiento = cuotaIt.Fec_Vencimiento;

            registrar_cambio_cuota(cuotaIt.nro_cuenta,cuotaIt.Fec_Vencimiento,'UpdateDatosCuota',null);
            COMMIT;
           END IF;

         EXCEPTION
         WHEN NO_DATA_FOUND THEN
              newCuotasCount := newCuotasCount+1;
              -- update cuotas
              UPDATE it.pr_cuotas c
                 SET c.estado='N'
                    ,SAL_CAPITAL=0
                    ,SAL_INTERES=0
              -- WHERE c.nro_cuota=cuotaIt.nro_cuota Modificado por MC(15/01/2010)
               WHERE c.fec_vencimiento = cuotaIt.Fec_Vencimiento
                 AND c.nro_cuenta=cuotaIt.nro_cuenta;
              IF( SQL%NOTFOUND ) THEN
                RAISE NoSePudoUpdateCuota;
              END IF;
              registrar_cambio_cuota(cuotaIt.nro_cuenta,cuotaIt.Fec_Vencimiento,'SetCuotaPaid',null);
              COMMIT;
         END;

       EXCEPTION
       WHEN Others THEN
            rollback;
            registrar_cambio_cuota(cuotaIt.nro_cuenta,cuotaIt.Fec_Vencimiento,'CuotaErrorRollback',sqlerrm);
            cuotaErrorCount := cuotaErrorCount + 1;
       END;
  END LOOP;
  CLOSE cuotasIt;
  mig_pr_log_registrar('Fin de busqueda de cuotas, nuevas cuotas='||newCuotasCount||', errores='||cuotaErrorCount,'TP2');
  --checkeamos los prestamos que existen en IT que ya
  --no existen en MIG para cancelar el prestamo

  mig_pr_log_registrar('Iniciando busqueda de prestamos que existen en IT y que no existen en MIG','TP2');
  OPEN c;
  LOOP
     BEGIN
       FETCH c INTO cuenta;
       EXIT WHEN c%NOTFOUND;
       DECLARE
       cuentaMig it.pr_cta_prestamos%ROWTYPE;
       BEGIN
         NULL;
          /*SELECT * INTO cuentaMig
            FROM mi_pr_cta_prestamos
           WHERE nro_cuenta = cuenta.nro_cuenta;

           IF( cuenta.sal_capital<>cuentaMig.sal_capital
            OR cuenta.sal_interes<>cuentaMig.sal_interes
            OR cuenta.estado<>cuentaMig.estado
            OR cuenta.can_cuo_pagadas<>cuentaMig.can_cuo_pagadas
            ) THEN

               UPDATE it.pr_cta_prestamos p
--                  SET ROW=cuenta
--                    SET ROW=cuentaMig
                    SET p.sal_capital = cuentaMig.sal_capital
                    ,p.sal_interes = cuentaMig.sal_interes
                    ,p.estado=cuentaMig.estado
                    ,p.can_cuo_pagadas=cuentaMig.Can_Cuo_Pagadas
                WHERE p.nro_cuenta = cuenta.nro_cuenta;
               COMMIT;

               registrar_cambio_prestamo(cuenta.nro_cuenta,'PrestamoActualizado',null);

            END IF;
       EXCEPTION
       WHEN NO_DATA_FOUND THEN
         newPrestamosCount := newPrestamosCount +1;
          -- El prestamos no existe mas, lo cual significa
          -- que se pago entero
          -- Hacemos un UPDATE prestamo
         UPDATE it.pr_cta_prestamos p
            SET p.estado='N'
               ,p.est_anterior=p.estado
               ,p.sal_capital=0
               ,p.sal_interes=0
          WHERE p.nro_cuenta=cuenta.nro_cuenta;
          COMMIT;
          -- LOGEAMOS
          registrar_cambio_prestamo(cuenta.nro_cuenta,'PrestamoPagado',null);
          */
       END;
     EXCEPTION
     WHEN Others THEN
       rollback;
       registrar_cambio_prestamo(cuenta.nro_cuenta,'PrestamoRollbackError',sqlerrm);
       prestamoErrorCount := prestamoErrorCount + 1;
     END;
  END LOOP;
  CLOSE c;

  mig_pr_log_registrar('Fin busqueda de prestamos, pagados='||newPrestamosCount||' errores='||prestamoErrorCount,'TP2');

  newPrestamosCount := 0;
  -- Buscamos prestamos que existan en MIG
  -- que no existan en IT para agregar.
  mig_pr_log_registrar('Inicio de busqueda de prestamos nuevos','TP2');

  OPEN cMig;
  LOOP
     BEGIN
         FETCH cMig INTO cuentaMig;
         EXIT WHEN cMig%NOTFOUND;
         DECLARE
            nroCuenta it.pr_cta_prestamos.nro_cuenta%TYPE;
         BEGIN
            SELECT nro_cuenta INTO nroCuenta
              FROM it.pr_cta_prestamos
             WHERE nro_cuenta = cuentaMig.nro_cuenta;

         EXCEPTION
         WHEN NO_DATA_FOUND THEN
            newPrestamosCount := newPrestamosCount +1;
            -- Cuenta nueva.
            -- La cuenta que esta en MIG no esta
            -- en IT. Hay que agregar.
            /*DECLARE
              CURSOR cuotas IS
                 SELECT *
                   FROM mi_pr_cuotas c
                  WHERE c.nro_cuenta=cuentaMig.nro_cuenta;

               cuota mi_pr_cuotas%ROWTYPE;
               nroCuotas int :=0;
               NoHayCuotas EXCEPTION;
               ClienteNoEncontradoEnLoans EXCEPTION;
               NoSePudoInsertarElCliente EXCEPTION;
            BEGIN

               registrar_cambio_prestamo(cuentaMig.nro_cuenta,'PrestamoNuevoEncontrado',null);
               -- insertamos el prestamo
               INSERT INTO it.pr_cta_prestamos
               VALUES cuentaMig;
               registrar_cambio_prestamo(cuentaMig.nro_cuenta,'PrestamoNuevoInsertado',null);
               --insertamos las cuotas
               OPEN cuotas;
               LOOP
                      FETCH cuotas INTO cuota;
                      EXIT WHEN cuotas%NOTFOUND;
                      INSERT INTO it.pr_cuotas VALUES cuota;
                      nroCuotas := nroCuotas+1;
               END LOOP;
               CLOSE cuotas;

               if( nroCuotas=0 ) THEN
                   RAISE NoHayCuotas;
               END IF;
               registrar_cambio_prestamo(cuentaMig.nro_cuenta,'CuotasInsertadas',''||nroCuotas);

               -- insertamos la relacion prestamo-cliente
               -- para la cuenta en cuestion
               DECLARE
                  ctaCliente it.ge_cta_clientes%ROWTYPE;
               BEGIN
                  SELECT  ln.sucursalfu
                         ,ln.account_number
                         ,0
                         ,6
                         ,ln.scheme_code
                         ,nuries
                         ,'P'
                    INTO  ctaCliente.cod_oficina
                         ,ctaCliente.nro_cuenta
                         ,ctaCliente.dig_verificador
                         ,ctaCliente.cod_modulo
                         ,ctaCliente.cod_modalidad
                         ,ctaCliente.cod_persona
                         ,ctaCliente.relacion
                    FROM loans_numero_cuenta ln
                   WHERE ln.account_number=cuentaMig.nro_cuenta;

                   INSERT INTO it.ge_cta_clientes
                   (cod_persona,nro_cuenta,dig_verificador,cod_oficina
                   ,cod_modulo,cod_modalidad,relacion)
                   VALUES
                   (ctaCliente.cod_persona,ctaCliente.nro_cuenta
                   ,ctaCliente.dig_verificador,ctaCliente.cod_oficina
                   ,ctaCliente.cod_modulo,ctaCliente.cod_modalidad
                   ,ctaCliente.relacion);

                   registrar_cambio_prestamo(cuentaMig.nro_cuenta,'DatosClienteInsertados',null);
                EXCEPTION
                WHEN NO_DATA_FOUND THEN
                -- SELECT INTO no devolvio un row
                   --DBMS_OUTPUT.put_line(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
                   RAISE ClienteNoEncontradoEnLoans;
                END;

                COMMIT;
            EXCEPTION
            WHEN ClienteNoEncontradoEnLoans THEN
                 errorCount := errorCount + 1;
                 rollback;
                 registrar_cambio_prestamo(cuentaMig.nro_cuenta,'PrestamoErrorClientDataNF',sqlerrm);
            WHEN NoHayCuotas THEN
                 errorCount := errorCount + 1;
                 rollback;
                 registrar_cambio_prestamo(cuentaMig.nro_cuenta,'PrestamoErrorNoCuotas',sqlerrm);
            WHEN NoSePudoInsertarElCliente THEN
                 errorCount := errorCount + 1;
                 rollback;
                 registrar_cambio_prestamo(cuentaMig.nro_cuenta,'PrestamoErrorClientInsertError',sqlerrm);
            WHEN Others THEN
                 errorCount := errorCount + 1;
                 rollback;
                 registrar_cambio_prestamo(cuentaMig.nro_cuenta,'PrestamoErrorUnknown1',sqlerrm);
            END;*/
         END;
       EXCEPTION
         When Others Then
             errorCount := errorCount + 1;
             rollback;
             registrar_cambio_prestamo(cuentaMig.nro_cuenta,'PrestamoErrorUnknown2',sqlerrm);
       END;
  END LOOP;
  CLOSE cMig;
  mig_pr_log_registrar('Fin de busqueda de prestamos nuevos, cantidad de nuevos='||newPrestamosCount||', errores='||errorCount,'TP2');

  mig_pr_log_registrar('FIN del procedimiento','TP2');
END;

begin
  -- Initialization
  --<Statement>;
  null;
end RSHK_Prestamos;
/


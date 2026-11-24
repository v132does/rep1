CREATE OR REPLACE PROCEDURE IT.PRP_COB_CUO_PRE_RES4(
p_nro_cuenta in varchar2 default null,
p_hora       in varchar2 default null,
p_nro_cuota  in number default null,
p_est_cuota  in varchar2 default 'C',
p_nro_secuencia in out varchar2)
IS
   v_fec_actual DATE := pag_cal.fu_obt_fec_actual(6);
   v_nro_cuenta GE_cuentas.nro_cuenta%type;
   v_cod_usuario varchar2(10):= upper(user);
   v_fec_valor date;
   v_lugar varchar2(3000);
   v_hora  ge_movimientos.hora%type := to_char(sysdate, 'HH24:MI:SS');
   v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
   v_nro_ult_secuencia ge_movimientos.nro_secuencia%type := 0;
   v_mon_ges_cobro number(18,2);
   v_mon_ges_impuesto number(18,2);
   v_mon_cargo number(18,2);
   --
   v_sal_inv_interes      PR_CTA_PRE_CAN_RES4.Inv_Interes%type;
   v_sal_inv_moratorio    PR_CTA_PRE_CAN_RES4.Inv_Int_Moratorio%type;
   v_sal_inv_punitorio    PR_CTA_PRE_CAN_RES4.inv_int_punitorio%type;
   v_sal_inv_ges_cobranza PR_CTA_PRE_CAN_RES4.inv_ges_cobranza%type;
   v_sal_inv_sobregiro    PR_CTA_PRE_CAN_RES4.Inv_Sobregiro%type;
   v_inv_interes          PR_CTA_PRE_CAN_RES4.Inv_Interes%type;
   v_inv_moratorio        PR_CTA_PRE_CAN_RES4.Inv_Int_Moratorio%type;
   v_inv_punitorio        PR_CTA_PRE_CAN_RES4.inv_int_punitorio%type;
   v_inv_ges_cobranza     PR_CTA_PRE_CAN_RES4.inv_ges_cobranza%type;
   v_inv_sobregiro        PR_CTA_PRE_CAN_RES4.Sal_Inv_Sobregiro%type;

   v_mto_inv_interes      PR_CTA_PRE_CAN_RES4.Inv_Interes%type;
   v_mto_inv_moratorio    PR_CTA_PRE_CAN_RES4.Inv_Int_Moratorio%type;
   v_mto_inv_punitorio    PR_CTA_PRE_CAN_RES4.inv_int_punitorio%type;
   v_mto_inv_ges_cobranza PR_CTA_PRE_CAN_RES4.inv_ges_cobranza%type;
   v_cod_mon_local        varchar2(10):=pag_gen.FU_OBT_MON_LOCAL;
   v_tabla                varchar2(10);
   v_nro_cta_ant          varchar2(100);

   v_cap_prestamo         pr_cta_prestamos.mto_capital%type;
   v_cap_cuota            pr_cta_prestamos.mto_capital%type;
   v_tot_deuda            pr_cta_prestamos.mto_capital%type;
   v_cod_persona          ba_personas.cod_persona%type;
   v_cod_transaccion      ge_transacciones.cod_transaccion%type;
   v_est_cuota            pr_cuotas.estado%type;
   v_cap_restante         pr_cta_prestamos.mto_capital%type;
   v_tot_gastos           pr_cta_prestamos.mto_capital%type;
   v_max_secuencia        ge_movimientos.nro_secuencia%type;

   --Rubros pasivos a utilizar
   v_cod_rubro_cob_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_COB_RE4',null,null,'GS', null,null);
   v_cod_rubro_cob_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_COB_RE4',null,null,'USD', null,null);

   v_cod_rubro_int_sus_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_SUS_RE4',null,null,'GS', null,null);
   v_cod_rubro_int_sus_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_SUS_RE4',null,null,'USD', null,null);

  v_cod_rubro_int_mor_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_MOR_RE4',null,null,'GS', null,null);
   v_cod_rubro_int_mor_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_MOR_RE4',null,null,'USD', null,null);

   v_cod_rubro_int_pun_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_PUN_RE4',null,null,'GS', null,null);
   v_cod_rubro_int_pun_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_PUN_RE4',null,null,'USD', null,null);

   v_cod_rubro_sob_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_SOB_RE4',null,null,'GS', null,null);
   v_cod_rubro_sob_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_SOB_RE4',null,null,'USD', null,null);

   v_fec_cancelacion       date;
   v_cod_mon_can           varchar(10);
   v_cotizacion            ge_movimientos.cotizacion%type;
   v_nro_cta_nue           GE_cuentas.nro_cuenta%type;
   v_procesar              varchar2(1);
   v_rub_cre_sobregiro     varchar2(40);
   v_cod_per_sob          varchar2(20);

cursor c_mov_cob_covid_19 is
   select a.*
        from ge_movimientos a
             where a.fecha = v_fec_actual
               and a.cod_modulo = 6
               and a.reversado = 'N'
               and a.monto > 0
               AND A.NRO_CUENTA=NVL(p_nro_cuenta, A.NRO_CUENTA)
               and a.hora= nvl(p_hora,a.hora)
               and a.cod_tra_padre in (360,359, 364) --Si cancela tambien
               and (exists (select 1 from
                            PR_CTA_PRE_CAN_RES4 b
                             where b.nro_cta_nueva= a.nro_cuenta
                             --
                             and( nvl(b.sal_inv_interes,0) > 0
                             or  nvl(b.sal_inv_int_moratorio,0) > 0
                             or  nvl(b.sal_inv_int_punitorio,0) > 0
                             or  nvl(b.sal_inv_ges_cobranza,0) > 0
                             or  nvl(b.sal_inv_sobregiro,0) > 0)
                             and nvl(b.inventariar,'N')='S')
                    or  exists (select 1 from
                            PR_CTA_PRE_REF_RES4 b
                             where b.nro_cta_nueva= a.nro_cuenta
                             and( nvl(b.sal_inv_interes,0) > 0
                             or  nvl(b.sal_inv_int_moratorio,0) > 0
                             or  nvl(b.sal_inv_int_punitorio,0) > 0
                             or  nvl(b.sal_inv_ges_cobranza,0) > 0
                             or  nvl(b.sal_inv_sobregiro,0) > 0)
                             and nvl(b.inventariar,'N')='S'))
               and a.nro_documento3 =p_nro_cuota
               and a.cod_transaccion IN (801,820)
               order by a.nro_cuenta,a.nro_documento3;


cursor c_mov_can_covid_19 is
   select a.*
        from pr_movimientos_res4 a
             where a.nro_cuenta= v_nro_cta_ant
               --Fecha de cancelación de tabla espejo
               and a.fecha= v_fec_cancelacion
               order by a.fecha,a.hora,a.nro_secuencia;

cursor c_tab_espejo is
    select b.inv_interes,b.inv_int_moratorio,b.inv_int_punitorio, b.inv_ges_cobranza,
                    b.sal_inv_interes,b.sal_inv_int_moratorio,b.sal_inv_int_punitorio, b.sal_inv_ges_cobranza, 'REF' as tabla,
                    b.tot_deuda,b.cod_persona,  nvl(b.fec_proceso,B.FEC_MOV_CAN) fec_proceso /*b.fec_proceso*/, b.nro_cuenta,
                    b.cod_moneda, b.sal_inv_sobregiro,b.inv_sobregiro, b.fec_mov_can, b.hor_mov_can,b.usu_mov_can, b.tip_carga
                from  PR_CTA_PRE_REF_RES4 b
                  where b.nro_cta_nueva= v_nro_cta_nue
     union all
     select b.inv_interes,b.inv_int_moratorio,b.inv_int_punitorio, b.inv_ges_cobranza,
                    b.sal_inv_interes,b.sal_inv_int_moratorio,b.sal_inv_int_punitorio, b.sal_inv_ges_cobranza, 'CAN' as tabla,
                    b.tot_deuda,b.cod_persona,  nvl(b.fec_proceso,B.FEC_MOV_CAN) fec_proceso/*b.fec_proceso*/, b.nro_cuenta,
                    b.cod_moneda, 0 as sal_inv_sobregiro,0 as inv_sobregiro,null,null,null,null
            from  PR_CTA_PRE_CAN_RES4 b
                  where b.nro_cta_nueva= v_nro_cta_nue;




BEGIN
  /************Proceso Principal*************************************************************/
   Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:= 1; pae_cnf.G_PROGRAMA := 'GPPROFIN';  End;
   v_hora := p_hora; /*fug_obt_hor_disponible(v_fec_actual, v_hora, v_cod_usuario, 'N');*/
   v_nro_secuencia :=0;
   v_max_secuencia:=0;
   --Obtenemos la máxima secuencia
   if nvl(p_nro_secuencia,0) = 0 then
      begin
       select max(a.nro_secuencia)
         into v_max_secuencia
         from ge_movimientos a
          where a.fecha=v_fec_actual
            and a.hora=p_hora
            and a.cod_usuario= user;
      exception
        when others then
          v_max_secuencia:=0;
      end;
      v_nro_secuencia := nvl(v_max_secuencia,0);
    else
      v_nro_secuencia := p_nro_secuencia;

    end if;

   for i in c_mov_cob_covid_19 loop
     v_nro_cta_nue:= null;
     v_nro_cta_nue:= i.nro_cuenta;
     v_rub_cre_sobregiro:= null;

     for w in c_tab_espejo loop
       --Verificamos si se procesa o No, si es carga operativa
       v_procesar:='S';
       if w.tabla='REF' AND upper(W.TIP_CARGA)='O' then
         --Sino se guardó los movimientos de cancelación no se procesará
         if w.fec_mov_can is null or w.hor_mov_can is null or w.usu_mov_can is null then
             v_procesar:='N';
         end if;
       end if;

      if  v_procesar='S' THEN
         v_sal_inv_interes:=0;
         v_sal_inv_moratorio:=0;
         v_sal_inv_punitorio:=0;
         v_sal_inv_ges_cobranza:=0;
         v_inv_interes:=0;
         v_inv_moratorio:=0;
         v_inv_punitorio:=0;
         v_inv_ges_cobranza:=0;
         v_mto_inv_interes:=0;
         v_mto_inv_moratorio:=0;
         v_mto_inv_punitorio:=0;
         v_mto_inv_ges_cobranza:=0;
         v_tabla:= null;
         v_cap_prestamo:= 0;
         v_cap_cuota:= 0;
         v_tot_deuda:=0;
         v_fec_cancelacion:=null;
         v_cap_restante:=0;
         v_tot_gastos:= 0;
         v_cod_mon_can:= null;
         v_sal_inv_sobregiro:= 0;
         v_inv_sobregiro:=0;
         v_nro_cta_ant:= null;
          --Traemos los datos de las tablas espejo
         v_lugar:='Obt.Datos Tab Espejo:'||i.nro_cuenta;
         v_inv_interes:=w.inv_interes;
         v_inv_moratorio:=w.inv_int_moratorio;
         v_inv_punitorio:=w.inv_int_punitorio;
         v_inv_ges_cobranza:=w.inv_ges_cobranza;
         v_sal_inv_interes:=w.sal_inv_interes;
         v_sal_inv_moratorio:=w.sal_inv_int_moratorio;
         v_sal_inv_punitorio:=w.sal_inv_int_punitorio;
         v_sal_inv_ges_cobranza:= w.sal_inv_ges_cobranza;
         v_tabla:= w.tabla;
         v_tot_deuda:=w.tot_deuda;
         v_cod_persona:=w.cod_persona;
         v_fec_cancelacion:=w.fec_proceso;
         v_nro_cta_ant:=w.nro_cuenta;
         v_cod_mon_can:=w.cod_moneda;
         v_sal_inv_sobregiro:= w.sal_inv_sobregiro;
         v_inv_sobregiro :=w. inv_sobregiro;



          v_lugar:='Obt.Datos Cobro:'||i.nro_cuenta;
          --Obtenemos los datos del Cobro
          begin
            select v.sal_capital_pre,v.mto_capital/*v.sal_capital_cuo*/
              into v_cap_prestamo,v_cap_cuota
                from pr_cobros v
                 where v.nro_cuenta= i.nro_cuenta
                   and v.nro_cuota= i.nro_documento3
                   and v.fecha= i.fecha
                   and v.hora= i.hora;
         exception
            when no_data_found then
               v_cap_prestamo:= 0;
               v_cap_cuota:= 0;
          end;
          v_lugar:='Calculamos Capital a Tomar:'||i.nro_cuenta;
          --v_cap_prestamo:= v_cap_prestamo - v_cap_cuota;

          --Verificamos si la moneda de la cancelacion es distinta de la nueva Cta
          if v_cod_mon_can <> i.cod_moneda then
             --Si el cancelado es Distinto a Moneda Local
             if v_cod_mon_can <> v_cod_mon_local then
               --Si la cuenta nueva es en moneda Local
               if i.cod_moneda =  v_cod_mon_local then
                  v_cotizacion:= pag_gen.FU_OBT_COTIZACION(v_cod_mon_Can);
                  v_cap_prestamo:= round(v_cap_prestamo/v_cotizacion,2);
                  v_cap_cuota:= round(v_cap_cuota/v_cotizacion,2);
               end if;
                --Si la cuenta vieja es en moneda local
             elsif v_cod_mon_can = v_cod_mon_local then
                --Si la moneda nueva es en otra moneda
                if i.cod_moneda <>  v_cod_mon_local then
                   v_cotizacion:= pag_gen.FU_OBT_COTIZACION(i.cod_moneda);
                   v_cap_prestamo:= v_cap_prestamo*v_cotizacion;
                   v_cap_cuota:= v_cap_cuota*v_cotizacion;
                end if;
             end if;

          end if;


          v_est_cuota:=null;
          v_lugar:='Obtenermos Estado de Cuota:'||i.nro_cuenta;
          --Obtenemos estado de la cuota
          begin
            select v.estado
              into v_est_cuota
                from pr_cuotas v
                 where v.nro_cuenta= i.nro_cuenta
                   and v.nro_cuota= i.nro_documento3;

          exception
            when no_data_found then
              v_est_cuota:= null;
          end;

               v_lugar:='Calculamos Interes:'||i.nro_cuenta;
         --Si tiene inventario Interesy el saldoes mayor a cero
          if nvl(v_inv_interes,0) > 0 and nvl(v_sal_inv_interes,0) > 0  then
            if nvl(v_cap_prestamo,0) = 0 then
               v_mto_inv_interes:= v_sal_inv_interes;
            else
              if v_cod_mon_can= v_cod_mon_local then
                  --v_mto_inv_interes:= v_sal_inv_interes - round((v_cap_prestamo*v_inv_interes/v_tot_deuda));
                  v_mto_inv_interes:= round(v_sal_inv_interes * v_cap_cuota/v_cap_prestamo);
              else
                  --v_mto_inv_interes:= v_sal_inv_interes - round((v_cap_prestamo*v_inv_interes/v_tot_deuda),2);
                  v_mto_inv_interes:= round(v_sal_inv_interes * v_cap_cuota/v_cap_prestamo,2);
              end if;
            end if;
          end if;
          v_lugar:='Calculamos Moratorio:'||i.nro_cuenta;
          --Moratorio
          if nvl(v_inv_moratorio,0) > 0 and nvl(v_sal_inv_moratorio,0) > 0  then
            if nvl(v_cap_prestamo,0) = 0 then
               v_mto_inv_moratorio:= v_sal_inv_moratorio;
            else
              if v_cod_mon_can= v_cod_mon_local then
                 --v_mto_inv_moratorio:= v_sal_inv_moratorio - round((v_cap_prestamo*v_inv_moratorio/v_tot_deuda));
                  v_mto_inv_moratorio:= round(v_sal_inv_moratorio * v_cap_cuota/v_cap_prestamo);
              else
                 --v_mto_inv_moratorio:= v_sal_inv_moratorio - round((v_cap_prestamo*v_inv_moratorio/v_tot_deuda),2);
                  v_mto_inv_moratorio:= round(v_sal_inv_moratorio * v_cap_cuota/v_cap_prestamo,2);
              end if;
            end if;
          end if;
          v_lugar:='Calculamos Punitorio:'||i.nro_cuenta;
          --Punitorio
          if nvl(v_inv_punitorio,0) > 0 and nvl(v_sal_inv_punitorio,0) > 0  then
             if nvl(v_cap_prestamo,0) = 0 then
               v_mto_inv_punitorio:= v_sal_inv_punitorio;
             else
                if v_cod_mon_can= v_cod_mon_local then
                   --v_mto_inv_punitorio:= v_sal_inv_punitorio - round((v_cap_prestamo*v_inv_punitorio/v_tot_deuda));
                   v_mto_inv_punitorio:= round(v_sal_inv_punitorio * v_cap_cuota/v_cap_prestamo);
                else
                   --v_mto_inv_punitorio:= v_sal_inv_punitorio - round((v_cap_prestamo*v_inv_punitorio/v_tot_deuda),2);
                   v_mto_inv_punitorio:= round(v_sal_inv_punitorio * v_cap_cuota/v_cap_prestamo,2);
                end if;
             end if;
          end if;
           v_lugar:='Calculamos Gest.Cob:'||i.nro_cuenta;
          --Gestion de Cobranza
          if nvl(v_inv_ges_cobranza,0) > 0 and nvl(v_sal_inv_ges_cobranza,0) > 0  then
             if nvl(v_cap_prestamo,0) = 0 then
               v_mto_inv_ges_cobranza:= v_sal_inv_ges_cobranza;
             else
                if v_cod_mon_can= v_cod_mon_local then
                  --v_mto_inv_ges_cobranza:= v_sal_inv_ges_cobranza - round((v_cap_prestamo*v_inv_ges_cobranza/v_tot_deuda));
                  v_mto_inv_ges_cobranza:= round(v_sal_inv_ges_cobranza * v_cap_cuota/v_cap_prestamo);
                else
                  --v_mto_inv_ges_cobranza:= v_sal_inv_ges_cobranza - round((v_cap_prestamo*v_inv_ges_cobranza/v_tot_deuda),2);
                  v_mto_inv_ges_cobranza:= round(v_sal_inv_ges_cobranza * v_cap_cuota/v_cap_prestamo,2);
                end if;
             end if;
          end if;

           --Sobregiro
           v_lugar:='Calculamos Sobregiro:'||i.nro_cuenta;
          if nvl(v_sal_inv_sobregiro,0) > 0 and nvl(v_inv_sobregiro,0) > 0  then
            if nvl(v_cap_prestamo,0) = 0 then
               v_inv_sobregiro:= v_sal_inv_sobregiro;
            else
              if v_cod_mon_can= v_cod_mon_local then
                 -- v_inv_sobregiro:= v_sal_inv_sobregiro - round((v_cap_prestamo*v_inv_sobregiro/v_tot_deuda));
                 v_inv_sobregiro:= round(v_sal_inv_sobregiro * v_cap_cuota/v_cap_prestamo);
              else
                  --v_inv_sobregiro:= v_sal_inv_sobregiro - round((v_cap_prestamo*v_inv_sobregiro/v_tot_deuda),2);
                 v_inv_sobregiro:= round(v_sal_inv_sobregiro * v_cap_cuota/v_cap_prestamo,2);

              end if;
            end if;
          end if;

         for z in c_mov_can_covid_19 loop
                v_lugar:='Ins.Mov.Ges.Cobro:'||z.nro_cuenta;
                --Para Gestion de Cobranza
                if nvl(v_mto_inv_ges_cobranza,0) > 0 and z.cod_transaccion = 7712 then
                   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                   --Para Rubro de Resultado
                     insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,z.cod_transaccion,i.fecha,i.fec_valor,
                             v_mto_inv_ges_cobranza,decode(i.mto_equ_local, null, null,v_mto_inv_ges_cobranza* i.cotizacion),
                             i.estado,'Gestion de Cobranza RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             null,null,
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*z.nro_documento4*/);
                     v_lugar:='Ins.Mov.Ges.Cobro 2:'||i.nro_cuenta;
                     v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                      insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,null,i.fecha,i.fec_valor,
                             v_mto_inv_ges_cobranza,decode(i.mto_equ_local, null, null,v_mto_inv_ges_cobranza* i.cotizacion),
                             i.estado,'Gestion de Cobranza RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_cob_gs,v_cod_rubro_cob_usd),'D',
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*z.nro_documento4*/);
                          --commit;
                end if;

               --7713 Moratorio
               v_lugar:='Ins.Mov.Moratorio:'||i.nro_cuenta;
               --v_cod_transaccion:= null;
               if nvl(v_mto_inv_moratorio,0) > 0
                    and z.cod_Transaccion  not in (849,7712)
                    and z.cod_Transaccion  is not null
                 then
                 --v_cod_transaccion  := pap_pre.fu_obt_tra_concepto('MO', p_est_cuota, v_tipo, v_tip_interes, v_tip_renovacion);
                 v_lugar:='Ins.Mov.Mor-Cta: '||p_nro_cuenta||' Nro.Cuota:'||p_nro_cuota ||'-'||v_cod_transaccion;
                 v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                 --v_lugar:='Ins.Mov.Moratorio:'||i.nro_cuenta||' Transaccion:' ||v_cod_transaccion;
                  --Para Rubro de Resultado
                  insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,z.cod_transaccion,i.fecha,i.fec_valor,
                             v_mto_inv_moratorio,decode(i.mto_equ_local, null, null,v_mto_inv_moratorio* i.cotizacion),
                             i.estado,'Interes Moratorio RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             null,null,
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,i.nro_documento2,i.nro_documento3,null/*i.nro_documento4*/);

                   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                   v_lugar:='Ins.Mov.Moratorio 2:'||i.nro_cuenta;
                   insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,NULL,i.fecha,i.fec_valor,
                             v_mto_inv_moratorio,decode(i.mto_equ_local, null, null,v_mto_inv_moratorio* i.cotizacion),
                             i.estado,'Interes Moratorio RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_int_mor_gs,v_cod_rubro_int_mor_usd),'D',
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,z.nro_documento2,z.nro_documento3,null/*i.nro_documento4*/);

                   -- commit;

               end if;
               --7714 Punitorio
               v_lugar:='Ins.Mov.Punitorio:'||i.nro_cuenta;
               --v_cod_transaccion  := null;
               if nvl(v_mto_inv_punitorio,0) > 0 and z.cod_Transaccion = 849 then
                   --Punitorio--
                   --v_cod_transaccion  := pap_pre.fu_obt_tra_concepto('PU', p_est_cuota, v_tipo, v_tip_interes, v_tip_renovacion);
                   v_lugar:='Ins.Mov.Pun.-Cta: '||p_nro_cuenta||' Nro.Cuota:'||p_nro_cuota ||'-'||v_cod_transaccion;
                   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                   insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,z.cod_transaccion,i.fecha,i.fec_valor,
                             v_mto_inv_punitorio,decode(i.mto_equ_local, null, null,v_mto_inv_punitorio* i.cotizacion),
                             i.estado,'Interes Punitorio RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             null,null,
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, z.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*i.nro_documento4*/);
                   v_lugar:='Ins.Mov.Punitorio 2:'||i.nro_cuenta;
                   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                   insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,NULL,i.fecha,i.fec_valor,
                             v_mto_inv_punitorio,decode(i.mto_equ_local, null, null,v_mto_inv_punitorio* i.cotizacion),
                             i.estado,'Interes Punitorio RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_int_pun_gs,v_cod_rubro_int_pun_usd),'D',
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*i.nro_documento4*/);
                    --commit;

               end if;

                --Para Interes (Devengado en Suspenso)
                v_lugar:='Ins.Mov.Dev.Sus I:'||i.nro_cuenta;
                if nvl(v_mto_inv_interes,0) > 0  and z.cod_tra_padre=900 and z.tip_mov_rubro='C'  then
                  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                   insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,null,i.fecha,i.fec_valor,
                             v_mto_inv_interes,decode(i.mto_equ_local, null, null,v_mto_inv_interes* i.cotizacion),
                             i.estado,'DEVENGADO EN SUSPENSO  RE4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             z.cod_rubro,'C',
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, z.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*i.nro_documento4*/);

                 END IF;

                 if nvl(v_mto_inv_interes,0) > 0  and z.cod_tra_padre=900 and z.tip_mov_rubro='D'  then
                    v_lugar:='Ins.Mov.Dev.Sus 2:'||i.nro_cuenta;
                   v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                   insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,NULL,i.fecha,i.fec_valor,
                             v_mto_inv_interes,decode(i.mto_equ_local, null, null,v_mto_inv_interes* i.cotizacion),
                             i.estado,'DEVENGADO EN SUSPENSO RE4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_int_sus_gs,v_cod_rubro_int_sus_usd),'D',
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*i.nro_documento4*/);

                   END IF;

                if nvl(v_inv_sobregiro,0) > 0 and z.cod_tra_padre=550   then
                    --Para Sobregiro
                    v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                    v_lugar:='Ins.Mov.Sobregiro 1:'||i.nro_cuenta;
                    v_rub_cre_sobregiro:=null;
                    v_cod_per_sob:= null;
                    v_lugar:='Obt.Per:'||i.nro_cuenta;
                    begin
                      select d.cod_persona
                       into v_cod_per_sob
                        from ge_cta_clientes d
                         where d.nro_cuenta= i.nro_cuenta
                           and d.relacion='P'
                           and rownum=1;
                    exception
                      when no_data_found then
                        v_cod_per_sob:= null;

                    end;
                    v_lugar:='Obt.Rub.Sob:'||i.nro_cuenta;
                    if v_cod_per_sob is not null then
                        begin
                           v_rub_cre_sobregiro:= fub_obt_rub_transaccion(4,
                                         41,
                                         550,
                                         i.cod_moneda,
                                         v_cod_per_sob,
                                         null,
                                         'C',
                                         null,
                                         null,
                                         null,
                                         null,
                                         null,
                                         null,
                                         null);
                        exception
                          when others then
                            raise_application_error(-20000, 'Obt.Rub.Sob.Cr:'||i.nro_cuenta);

                        end;
                    end if;


                    insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,null,i.fecha,i.fec_valor,
                             v_inv_sobregiro,decode(i.mto_equ_local, null, null,v_inv_sobregiro* i.cotizacion),
                             i.estado,'Cob.Sobregiro RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             v_rub_cre_sobregiro,'C',
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*z.nro_documento4*/);
                     v_lugar:='Ins.Mov.Sobregiro 2:'||i.nro_cuenta;
                     v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
                      insert into ge_movimientos
                            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
                             cod_tra_padre,cod_transaccion,fecha,fec_valor,
                             monto,mto_equ_local, estado,concepto,reversado,
                             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
                             nro_secuencia,nro_cuenta,cod_ofi_origen,
                             cod_rubro,tip_mov_rubro, referencia, cod_persona,
                             est_cuenta,protegido,cotizacion,
                             nro_documento,nro_documento2,nro_documento3,nro_documento4)
                    values(z.cod_modulo,z.cod_modalidad,z.cod_oficina,z.cod_moneda,
                             z.cod_tra_padre,null,i.fecha,i.fec_valor,
                             v_inv_sobregiro,decode(i.mto_equ_local, null, null,v_inv_sobregiro* i.cotizacion),
                             i.estado,'Cob.Sobregiro RES4',z.reversado,
                             z.cod_mod_padre,z.cod_mad_padre,user, v_hora,
                             v_nro_secuencia,z.nro_cuenta,z.cod_ofi_origen,
                             decode(i.cod_moneda, v_cod_mon_local,v_cod_rubro_sob_gs,v_cod_rubro_sob_usd),'D',
                             z.referencia, z.cod_persona,
                             z.est_cuenta, z.protegido, i.cotizacion,
                             i.nro_documento,z.nro_documento2,i.nro_documento3,null/*z.nro_documento4*/);

                end if;

         end loop;
              --Actualizamos Tablas Espejo
         v_lugar:='Ins.Tablas Espejo('||v_tabla||'):'||i.nro_cuenta;
          if v_tabla = 'CAN' then
            update PR_CTA_PRE_CAN_RES4 w
             set w.sal_inv_interes=nvl(w.sal_inv_interes,0) - nvl(v_mto_inv_interes,0)  ,
                 w.sal_inv_int_moratorio=nvl(w.sal_inv_int_moratorio,0)- nvl(v_mto_inv_moratorio,0),
                 w.sal_inv_int_punitorio=nvl(w.sal_inv_int_punitorio,0)- nvl(v_mto_inv_punitorio,0),
                 w.sal_inv_ges_cobranza=nvl(w.sal_inv_ges_cobranza,0) - nvl(v_mto_inv_ges_cobranza,0)
              where w.nro_cta_nueva= i.nro_cuenta
                 and w.nro_cuenta= v_nro_cta_ant;
          elsif v_tabla = 'REF' then
            update PR_CTA_PRE_REF_RES4 w
             set w.sal_inv_interes=nvl(w.sal_inv_interes,0) - nvl(v_mto_inv_interes,0)  ,
                 w.sal_inv_int_moratorio=nvl(w.sal_inv_int_moratorio,0)- nvl(v_mto_inv_moratorio,0),
                 w.sal_inv_int_punitorio=nvl(w.sal_inv_int_punitorio,0)- nvl(v_mto_inv_punitorio,0),
                 w.sal_inv_ges_cobranza=nvl(w.sal_inv_ges_cobranza,0) - nvl(v_mto_inv_ges_cobranza,0),
                 w.sal_inv_sobregiro=nvl(w.sal_inv_sobregiro,0) - nvl(v_inv_sobregiro,0)
              where w.nro_cta_nueva= i.nro_cuenta
                and w.nro_cuenta= v_nro_cta_ant;

          end if;

       END IF;
   end loop;

   v_nro_secuencia:= v_nro_secuencia;
   v_nro_cta_ant:= i.nro_cuenta;
  end loop;
   p_nro_secuencia:= v_nro_secuencia;



EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR.Cob.Cuo.RE4.- '||v_lugar||'-'||SQLERRM);
END PRP_COB_CUO_PRE_RES4;
/


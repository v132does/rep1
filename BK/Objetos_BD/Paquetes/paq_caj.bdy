CREATE OR REPLACE PACKAGE BODY IT.PAQ_CAJ is

-- Permite obtener los datos del Contrato
PROCEDURE PR_OBT_DAT_CONTRATO
 (P_NRO_CONTRATO In CS_CONTRATOS.NRO_CONTRATO%TYPE
 ,RP_CON         In OUT CS_CONTRATOS%ROWTYPE
 )
 IS
BEGIN
   select *
     into rp_con
     from cs_contratos
    where nro_contrato = p_nro_contrato;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Nro. de Contrato '||p_nro_contrato||' no registrado');
END;

-- Recupera minima cuota vencida del contrato.
FUNCTION FU_OBT_MIN_CUO_VEN
 (P_NRO_CONTRATO In CS_CONTRATOS.NRO_CONTRATO%TYPE
 ,P_FECHA        In CS_CONTRATOS.FEC_APERTURA%TYPE
 )
 RETURN NUMBER
 IS
v_min_cuota cs_con_cuotas.nro_cuota%type;
BEGIN
   select min(nro_cuota)
     into v_min_cuota
     from cs_con_cuotas
    where nro_contrato = p_nro_contrato
      and nvl(monto,0) <> 0
      and fec_vencimiento <= p_fecha;
   return v_min_cuota;
END;

/* Recupera maxima cuota vencida del contrato. */
FUNCTION FU_OBT_MAX_CUO_VEN
 (P_NRO_CONTRATO In CS_CONTRATOS.NRO_CONTRATO%TYPE
 ,P_FECHA        In CS_CON_CUOTAS.FEC_VENCIMIENTO%TYPE
 )
 RETURN NUMBER
 IS
v_max_cuota  cs_con_cuotas.nro_cuota%type;
BEGIN
   select max(nro_cuota)
     into v_max_cuota
     from cs_con_cuotas
    where nro_contrato = p_nro_contrato
      and nvl(monto,0) <> 0 -- Cuotas con saldo
      and fec_vencimiento <= p_fecha;
   return v_max_cuota;
END;

--Generación de cuotas
PROCEDURE PR_GEN_CUOTAS
  (P_NRO_CONTRATO IN CS_CONTRATOS.NRO_CONTRATO%Type Default Null
  )
  Is
  
  v_fec_vcto       Date;
  v_fec_sig_pago   Date;
  v_fec_ant        Date;
  v_nro_cuota     cs_con_cuotas.nro_cuota%Type;
  v_mto_cuota     cs_con_cuotas.monto%Type;
  --caja de seguridad fase 2 sergio servín 1/10/2014
  v_periodo number(3);
  v_mon_cuota number(18,3):= 0;

  v_cod_moneda varchar2(3);
  v_tipo_Caja number;
  v_cod_modulo number;
  v_cod_modalidad number;
  v_cod_transaccion number := to_number(fug_obt_pardinamico('CAJ_SEG_COD_TRA_CUOTA'));
  v_aux number;
  v_val_tasa number;
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(16);
  v_redondeo number;
  v_mto_deuda number;
  
  
  --cursor de contratos, no considerar contratos cancelados,rechazados,
   Cursor con Is
   Select *
     From cs_contratos t
    Where t.nro_contrato = nvl(p_nro_contrato,t.nro_contrato)
      And t.estado Not In ('C','R','I','B')--cancelado/rechazado/ingresado/bloqueado
      and t.nro_cta_debito is not null
      and (t.fec_sig_pago is null or t.fec_sig_pago <= v_fec_actual)
      --controlamos para no generar cuotas repetidas
      and not exists  (select * 
                         from cs_con_cuotas cu
                         where cu.nro_contrato = t.nro_contrato
                         and   cu.fec_desde = nvl(t.fec_sig_pago, t.fec_apertura)
                         AND   cu.fec_vencimiento = nvl(t.fec_sig_pago, t.fec_apertura)
                         and   cu.nro_cob_exc_visitas = 0
                         and   cu.nro_cuota > 0);

Begin
  
  
  

  For c In con Loop
     --se busca el código de la moneda de , módulo y modalidad de la cuenta para obtener el monto de la cuota
     begin
        select t.cod_moneda, t.cod_modulo, t.cod_modalidad
        into v_cod_moneda, v_cod_modulo, v_cod_modalidad
        from ge_cuentas t
        where t.nro_cuenta = c.nro_cta_debito;
     exception
        when no_data_found then
           v_cod_moneda := null;
           
           raise_application_error(-20000,'No existe la cuenta N° '||c.nro_cta_debito);
        when others then
           raise_application_error(-20000,'Error al buscar el código de moneda de la cuenta N°'||c.nro_cta_debito||' - '||sqlerrm);
     end;
     PAG_CTA.PR_OBT_CUENTA(c.nro_cta_debito);
     v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,pag_cta.g_ctas.COD_MONEDA);
     
   -- buscamos el tipo de caja
     begin
        select t.val_maximo
        into v_tipo_Caja
        from Ba_Cod_Referencias t,
             cs_caj_seguridad ca
        where t.dominio = 'TIP_CAJ_SEGURIDAD'
        and    t.val_minimo = ca.tipo
        and   ca.cod_caj_seguridad = c.cod_caj_seguridad;
     exception
        when no_data_found then
           v_tipo_Caja := null;
           raise_application_error(-20000,'No se encuentra el tipo de caja de seguridad');
        when others then
           raise_application_error(-20000,'Error al buscar el tipo de caja de seguridad,  -  '||sqlerrm);
     end;   

     --obtenemos el monto de la cuota según el tipo de caja y la transacción
       prg_obt_cargos(null,
                 c.nro_cta_debito,
                 c.cod_moneda,
                 v_tipo_Caja,
                 nvl(v_cod_modulo,3),
                 nvl(v_cod_modalidad,31),
                 v_cod_transaccion,
                 v_aux,
                 v_mto_cuota,
                 v_aux,
                 v_aux,
                 v_aux,
                 v_val_tasa,
                 v_aux);

     
     

     
    If nvl(c.FEC_SIG_PAGO,c.fec_apertura) <= v_fec_actual  Then--genera el registro de cuota


      v_nro_cuota     := 0;
     -- v_contador      := 0;
      --Obtener el maximo vencimiento de las cuotas
      Begin
        Select nvl((Max(nro_cuota)+1),1)
          Into v_nro_cuota
          From cs_con_cuotas
         Where nro_contrato = c.nro_contrato;
      Exception
        When no_data_found Then
          v_fec_vcto := c.fec_apertura;
          v_nro_cuota  := 1;
        when others then
          raise_application_error(-20000,'Error al buscar el nro de la sgte cuota,  -  '||sqlerrm);     
      End;
       
      --
      v_fec_vcto := nvl(c.FEC_SIG_PAGO,c.fec_apertura);


      if v_mto_cuota > 0 then 
         
         --cálculo de acuerdo al periodo
          select decode(c.per_pago,3,4,6,2,c.per_pago) 
          into v_periodo
          from dual;

          v_mto_cuota := v_mto_cuota / v_periodo;
         --controla para sumarle el iva a la cuota.
         if v_val_tasa is not null then
            v_mto_cuota := round((v_mto_cuota*1.1),v_redondeo);
         end if;

            v_fec_ant   := v_fec_vcto;

            if c.per_pago = 12 then
               v_fec_sig_pago  := pag_cal.fu_obt_fec_habil(add_months(v_fec_ant, 1),1,2);
               
               
            elsif c.per_pago = 1 then
               v_fec_sig_pago  := pag_cal.fu_obt_fec_habil(add_months(v_fec_ant, 12),1,2);
            else
               v_fec_sig_pago  := pag_cal.fu_obt_fec_habil(add_months(v_fec_ant, c.per_pago),1,2);
            end if;

              --se inserta el registro de la cuota del alquiler de la caja de seguridad
              Begin
                Insert Into cs_con_cuotas(nro_contrato, nro_cuota, fec_desde, fec_hasta,
                                          fec_vencimiento, fec_pago, monto, estado, cod_transaccion, Nro_Cob_Exc_Visitas)
                                   Values(c.nro_contrato,v_nro_cuota,v_fec_actual,v_fec_sig_pago-1,
                                          v_fec_actual,Null,v_mto_cuota,'P',
                                          v_cod_transaccion,0);
              exception
                when others Then
                  raise_application_error(-20000,'Error al registrar la cuota, Error: '||sqlerrm);
              End;
              
              --obtenemos la deuda del contrato
              paq_caj.PR_OBT_DEU_CONTRATO(c.nro_contrato,v_mto_deuda);

              --actualizamos la fecha del siguiente pago en el contrato
              begin
                 update cs_contratos t set t.fec_sig_pago = v_fec_sig_pago,
                                           t.mto_adeudado = v_mto_deuda
                 where t.nro_contrato = c.nro_contrato;
              exception
                when others Then
                  raise_application_error(-40000,'Error al registrar la cuota, Error: '||sqlerrm);
              End;


      End If;
    End If;
    --Activar el contrato si esta ingresado
   /* If c.estado = 'I' Then
      Update cs_contratos
         Set estado = 'A'
       Where nro_contrato = c.nro_contrato;
    End If;*/

  End Loop;
End;
--generación automática de recargos--
PROCEDURE PR_GEN_RECARGOS
 (P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%Type  DEFAULT NULL)is
 v_cant_visita number;
 v_cant_visita_max number;
 v_cod_transaccion number := to_number(fug_obt_pardinamico('CAJ_SEG_COD_TRA_RECAR'));
 v_mon_recargo number(18,3):= 0;--recargo cantidad de visita
 v_cod_moneda varchar2(3);
 v_cod_modulo number;
 v_cod_modalidad number;
 v_aux number;
 v_val_tasa number;
 v_nro_cobro number;
 v_fec_desde date;
 v_fec_hasta date;
 
 v_fec_pri_dia_habil date := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(16);
 v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(16);
 v_fec_mes_ant_des date:= add_months(to_date('01/'||to_char(v_fec_ACTUAL,'MM')||'/'||to_char(v_fec_ACTUAL,'yyyy'),'dd/mm/yyyy'),-1);
 v_fec_mes_ant_has date:= LAST_DAY(v_fec_mes_ant_des);
 v_redondeo number;
 v_mto_deuda number;
 
  --cursor de contratos, no considerar contratos cancelados,rechazados,
   Cursor con Is
   Select t.*,
          (Select nvl(count(DISTINCT vi.nro_visita), 0) cant_visita
              from cs_visitas      vi,
                   cs_contratos    con
             WHERE con.nro_contrato = vi.nro_contrato
             and   con.nro_contrato = t.nro_contrato
             and   vi.fec_visita between v_fec_mes_ant_des and v_fec_mes_ant_has

             group by con.nro_contrato) cant_visita
          
     From cs_contratos t
    Where t.nro_contrato = nvl(p_nro_contrato,t.nro_contrato)
      And t.estado Not In ('C','R','I','B')--cancelado/rechazado/ingresado/bloquedo
      and   t.nro_cta_debito is not null
      --condición del mes anterior.. que exista en cs_visitas
      and (Select nvl(count(DISTINCT vi.nro_visita), 0) cant_visita
              from cs_visitas      vi,
                   cs_contratos    con
             WHERE con.nro_contrato = vi.nro_contrato
             and   con.nro_contrato = t.nro_contrato
             and   vi.fec_visita between v_fec_mes_ant_des and v_fec_mes_ant_has
             group by con.nro_contrato)> 0--vemos solo los que tuvieron visita en el mes anterior
      --para que no gener doble recargo de exceso de visita
      and not exists  (select * 
                         from cs_con_cuotas cu
                         where cu.nro_contrato = t.nro_contrato
                         and   cu.fec_desde = v_fec_mes_ant_des
                         AND   cu.fec_hasta = v_fec_mes_ant_has
                         and   cu.nro_cob_exc_visitas >0
                         and   cu.nro_cuota = 0);
      
 
 begin
    --validamos que sea el primer día del mes
    if  v_fec_pri_dia_habil = v_fec_actual then
       for c in con loop
             
                --se busca el código de la moneda de , módulo y modalidad de la cuenta 
                 begin
                    select t.cod_moneda, t.cod_modulo, t.cod_modalidad
                    into v_cod_moneda, v_cod_modulo, v_cod_modalidad
                    from ge_cuentas t
                    where t.nro_cuenta = c.nro_cta_debito;
                 exception
                    when no_data_found then
                       v_cod_moneda := null;
                       
                       raise_application_error(-20000,'No se encuentra el código de moneda de la cuenta N° '||c.nro_cta_debito);
                    when others then
                       raise_application_error(-20000,'Error al buscar el código de moneda,  -  '||sqlerrm);
                 end;
                 PAG_CTA.PR_OBT_CUENTA(c.nro_cta_debito);
     v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,pag_cta.g_ctas.COD_MONEDA);
                 
                     --se obtiene el recargo
                      prg_obt_cargos(null,
                                 c.nro_cta_debito,
                                 c.cod_moneda,
                                 c.cant_visita,
                                 nvl(v_cod_modulo,3),
                                 nvl(v_cod_modalidad,31),
                                 v_cod_transaccion,
                                 v_aux,
                                 v_mon_recargo,
                                 v_aux,
                                 v_aux,
                                 v_aux,
                                 v_val_tasa,
                                 v_aux);
                                 
                        if v_mon_recargo > 0 then
                            --controla si se tiene sumarle el iva
                            if v_val_tasa is not null then
                                 --v_mon_recargo := round(v_mon_recargo*1.1);
                                 v_mon_recargo := round((v_mon_recargo*1.1),v_redondeo);
                             end if;
                        --buscamos el nro sgte 
                            begin
                               select nvl((Max(t.nro_cob_exc_visitas)+1),1)
                               into v_nro_cobro
                               from cs_con_cuotas t
                               where t.nro_contrato = c.nro_contrato;
                            exception
                            when no_data_found then
                                 v_nro_cobro := 1;
                            when others then
                               raise_application_error(-20000,'Error al buscar el nro de cobro del contrato error: '||sqlerrm);
                            end;  
                            --
                            begin
                              Insert Into cs_con_cuotas(nro_contrato, nro_cuota, fec_desde, fec_hasta,
                              fec_vencimiento, fec_pago, monto, estado, cod_transaccion, nro_cob_exc_visitas)
                              Values(c.nro_contrato,0,v_fec_mes_ant_des,v_fec_mes_ant_has,
                              v_fec_actual,Null,v_mon_recargo,'P', v_cod_transaccion, v_nro_cobro);
                            exception
                              when others then
                                raise_application_error(-20000,'Error al insertar el registro de recargo: '||sqlerrm);
                            end;
                            --obtenemos la deuda del contrato
                            paq_caj.PR_OBT_DEU_CONTRATO(c.nro_contrato,v_mto_deuda);
                            
                            --actualizamos la deuda del contrato
                            begin
                               update cs_contratos t set t.mto_adeudado = v_mto_deuda
                               where t.nro_contrato = c.nro_contrato;
                            exception
                              when others Then
                                raise_application_error(-40000,'Error al registrar la cuota, Error: '||sqlerrm);
                            End;
                            
                        end if;         
       end loop;
    
    end if;

 end; 
--Obtener la deuda del contrato
Procedure PR_OBT_DEU_CONTRATO
 (P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%Type
 ,P_SALDO        IN OUT CS_CON_CUOTAS.MONTO%Type
 )
  Is

   r_cont  CS_CONTRATOS%rowtype;
   v_saldo CS_CONTRATOS.MTO_ADEUDADO%type := 0;

BEGIN
  --- Recuperar datos del contrato
  paq_caj.PR_OBT_DAT_CONTRATO(p_nro_contrato, r_cont);

  --Obtener monto adeudado hasta la fecha
  Begin
    Select Sum(t.monto)
      Into v_saldo
      From cs_con_cuotas t
     Where t.nro_contrato = P_NRO_CONTRATO
       And t.estado = 'P'
       and t.fec_pago is null;
       --And fec_vencimiento <= P_FECHA;
    /*if nvl(v_saldo,0) = 0 then -- No tiene cuota vencida
        Select Sum(saldo)
          Into v_saldo
          From cs_con_cuotas a
         Where nro_contrato = P_NRO_CONTRATO
           And nvl(saldo,0) > 0
           And nro_cuota = (select min(b.nro_cuota)
                              from cs_con_cuotas b
                             where b.nro_contrato = a.nro_contrato
                               and nvl(b.saldo,0) > 0
                               and b.fec_pago is null)
           And fec_pago is null;
    end if;*/
  End;
  p_saldo := v_saldo;
End;
PROCEDURE PR_OBT_MON_CUOTA
 (P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%Type
 ,P_FECHA        In Date
 ,P_CUOTA        IN OUT CS_CON_CUOTAS.MONTO%Type
 )
 IS
   r_cont  CS_CONTRATOS%rowtype;
   v_saldo CS_CONTRATOS.MTO_ADEUDADO%type;

BEGIN
  --- Recuperar datos del contrato
  paq_caj.PR_OBT_DAT_CONTRATO(p_nro_contrato, r_cont);

  --Obtener monto de la cuota hasta la fecha
  Begin
    Select c.monto
      Into v_saldo
      From cs_con_cuotas c
     Where nro_contrato = P_NRO_CONTRATO
       And nvl(monto,0) <> 0
       And c.fec_vencimiento = (select min(sc.fec_vencimiento)
                                 from cs_con_cuotas sc
                                where sc.nro_contrato = c.nro_contrato
                                  and nvl(sc.monto,0) <> 0);
  End;
  p_cuota := nvl(v_saldo,0);
exception
  when others then
     p_cuota := 0;
End;
--Cobro de Cuotas
PROCEDURE PR_COB_CUOTAS
   (P_NRO_CONTRATO  IN CS_CON_CUOTAS.NRO_CONTRATO%TYPE
   ,P_MTO_COBRADO   IN CS_CON_CUOTAS.MONTO%TYPE
   ,P_COD_TRA_PADRE In GE_MOVIMIENTOS.COD_TRA_PADRE%Type Default Null
   ,P_NRO_CUOTA     In VARCHAR2 DEFAULT NULL
   ,P_NRO_COB_EXC_VISITAS IN VARCHAR2 DEFAULT NULL
   ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
   )
   IS

   --- Variables de movimientos
   r_gmovi          ge_movimientos%Rowtype;
   v_cod_tra_padre  ge_movimientos.cod_tra_padre%Type := nvl(p_cod_tra_padre,369);
   v_mto_cuota      cs_con_cuotas.monto%type;
   v_fec_actual     Date:= pag_cal.FU_OBT_FEC_ACTUAL(16);
   v_fec_pag_ant    Date;
   v_pro_vcto       Date;
   --DYDMR-1476: Sergio Servín - 20/01/2015 (se modifica el cursor para contemplar pagos parciales de cuotas y recargos)
   cursor cuotas is
   Select cuo.*, con.nro_cta_debito, con.cod_oficina, con.cod_caj_seguridad,
          con.estado est_contrato, per.cod_persona
     From cs_contratos con,
          cs_Con_Cuotas cuo,
          cs_con_personas per
    Where con.Nro_Contrato = p_Nro_Contrato
      And con.nro_contrato = cuo.nro_contrato
      and con.nro_contrato = per.nro_contrato
      and per.tip_relacion = 'T' -- Principal
      And con.estado Not In ('C','R','I','B')--cancelado/rechazado/ingresado
      AND (( instr( P_NRO_CUOTA, '*' || cuo.NRO_CUOTA || '*', 1, 1 ) > 0 ) or P_NRO_CUOTA is null)
      AND nvl(CUO.NRO_COB_EXC_VISITAS,0) = 0
      And cuo.Estado ='P'--solo los pendientes de pago
      and cuo.fec_pago is null
      and cuo.cod_transaccion = P_COD_TRA_PADRE
   UNION ALL
      Select cuo.*, con.nro_cta_debito, con.cod_oficina, con.cod_caj_seguridad,
          con.estado est_contrato, per.cod_persona
     From cs_contratos con,
          cs_Con_Cuotas cuo,
          cs_con_personas per
    Where con.Nro_Contrato = p_Nro_Contrato
      And con.nro_contrato = cuo.nro_contrato
      and con.nro_contrato = per.nro_contrato
      and per.tip_relacion = 'T' -- Principal
      And con.estado Not In ('C','R','I','B')--cancelado/rechazado/ingresado
      AND (( instr( nvl(P_NRO_COB_EXC_VISITAS,'*0*'), '*' || nvl(cuo.Nro_Cob_Exc_Visitas,0) || '*', 1, 1 ) > 0 ) or P_NRO_COB_EXC_VISITAS is null)
      AND nvl(CUO.NRO_CUOTA,0) = 0
      And cuo.Estado ='P'--solo los pendientes de pago
      and cuo.fec_pago is null
      and cuo.cod_transaccion = P_COD_TRA_PADRE;
Begin
   for ct in cuotas loop
       --DYDMR-1476:Sergio Servín - 20/01/2015 (se calcula el monto de la deuda)
       --actualizamos la deuda del contrato
      begin
        update cs_contratos t set t.mto_adeudado = (Select sum(t.monto) - ct.monto
                                                    from cs_con_cuotas t
                                                    where t.nro_contrato = P_NRO_CONTRATO
                                                    and   t.estado = 'P'
                                                    and   t.fec_pago is null) 
        where t.nro_contrato = ct.nro_contrato;
      exception
      when others Then
           raise_application_error(-40000,'Error al registrar la cuota, Error: '||sqlerrm);
      End;

       
      --actualizamos la cuota o recargo como pagado
      ---Sergio esta parte cambie saldo por monto ... LC 
      begin
         update cs_con_cuotas t set t.fec_pago = v_fec_actual,
                                    t.estado = 'C',
                                    t.hora = P_HORA
         where t.nro_contrato = ct.nro_contrato
         and   t.nro_cuota    = ct.nro_cuota 
         and   t.cod_transaccion = ct.cod_transaccion
         and   nvl(t.nro_cob_exc_visitas,0) = nvl(ct.nro_cob_exc_visitas,0);                 
      end; 
  
   end loop;
   
END;

FUNCTION FU_OBT_MTO_CAJA
 (P_COD_OFICINA   In  CS_CAJ_SEGURIDAD.COD_OFICINA%Type
 ,P_COD_CAJA      In  CS_CAJ_SEGURIDAD.COD_CAJ_SEGURIDAD%Type)
return number is
begin
  null;

end;

PROCEDURE PR_GEN_REVERSION
  (P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%TYPE,
   P_HORA IN CS_CON_CUOTAS.HORA%TYPE,
   P_FECHA IN CS_CON_CUOTAS.FEC_PAGO%TYPE)IS
   monto_reversado cs_contratos.mto_adeudado%type;
  BEGIN
    begin
    --suma el monto total a reversar
    select  sum(t.monto) into monto_reversado 
      from  cs_con_cuotas t
     where  t.nro_contrato = P_NRO_CONTRATO
       and  t.fec_pago = P_FECHA
       and  t.hora = P_HORA
       and  t.estado = 'C'
       and  t.fec_pago is not null
       and  t.hora is not null;
      --actualiza cuota
      update cs_con_cuotas t set t.fec_pago = null,
                                 t.estado = 'P',
                                 t.hora = null
       where t.nro_contrato = P_NRO_CONTRATO
         and t.fec_pago = P_FECHA
         and t.hora = P_HORA
         and t.estado = 'C'
         and t.fec_pago is not null
         and t.hora is not null;
       --actualiza contrato
       update cs_contratos t set t.mto_adeudado= t.mto_adeudado +nvl(monto_reversado,0)
        where t.nro_contrato = P_NRO_CONTRATO;
                                 
    exception
    when others then
      raise_application_error(-40000,'Error al Reversar cobro de cuotas/recargo Contrato Nro '||P_NRO_CONTRATO
                                     ||'Error: '||sqlerrm);
    end;
    
    
  END;    
--Generar movimientos
PROCEDURE PR_GEN_MOVIMIENTOS
 (P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%Type,
  P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
  P_COD_TRA_PADRE IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
  P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE,
  P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
  P_COD_OFICNA IN BA_OFICINAS.COD_OFICINA%TYPE,
  P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
  P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE,
  P_HORA IN GE_MOVIMIENTOS.HORA%TYPE,
  P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE,
  P_COD_PERSONA IN GE_MOVIMIENTOS.COD_PERSONA%TYPE Default Null)
  IS
     V_EXI_IVA VARCHAR2(1);--si la transaccion debe de tener registro de iva
     V_MTO_GRAVADA NUMBER;
     V_MTO_IVA NUMBER;
     v_redondeo number;
     r_gmovi ge_movimientos%rowtype;
     v_nro_secuencia number := P_NRO_SECUENCIA;
     V_MOD_PADRE      GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE;
     V_MAD_PADRE      GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
     V_COD_MODULO     GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE;
     V_COD_MODALIDAD  GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
     V_FECHA          GE_MOVIMIENTOS.FECHA%TYPE:= P_FECHA;
     --control de moneda
     v_cot_mon_destino number;

     v_mto_equ_local  ge_movimientos.mto_equ_local%type;
     v_cotizacion     ge_cotizaciones.val_conversion%type;
     
  
     
  BEGIN
     --obtenemos modulo/modalidad padre
     IF P_COD_TRA_PADRE = 369 THEN
        V_MOD_PADRE := 9;
        V_MAD_PADRE := 91;
     ELSE
        V_MOD_PADRE := 16;
        V_MAD_PADRE := 161;
     END IF;
     
     --se busca el código de la moneda de , módulo y modalidad de la cuenta 
     begin
         select t.cod_modulo, t.cod_modalidad
         into V_COD_MODULO, V_COD_MODALIDAD
         from ge_cuentas t, cs_contratos c
         where t.nro_cuenta = c.nro_cta_debito
         and   c.nro_contrato = P_NRO_CONTRATO;
      exception
         when no_data_found then        
            raise_application_error(-20000,'No se encuentra el módulo y modalidad 
                                            cuenta Débito del contrato '||P_NRO_CONTRATO);
         when others then
            raise_application_error(-20000,'Error al buscar el código de moneda,  -  '||sqlerrm);
      end;
      --OBTENEMOS EL VALOR DE REDONDEO
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',V_COD_MODULO,V_COD_MODALIDAD,P_COD_MONEDA);
      
     --buscamos si posee registro de iva
     BEGIN
       SELECT 'S'
       INTO V_EXI_IVA
       FROM GE_TRANSACCIONES_DET T
       WHERE T.COD_TRANSACCION = P_COD_TRANSACCION
       AND   T.COD_MODULO = V_COD_MODULO
       AND   T.COD_MODALIDAD = V_COD_MODALIDAD

       AND   T.COD_TRA_HIJO =518;--TRANSACCION IVA
     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           V_EXI_IVA := 'N';
        WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20000,'Error al buscar si la transacción debe 
                                                 tener registros de IVA'||sqlerrm);
     END;
     
     
     IF V_EXI_IVA = 'S' THEN--debe registrar movimientos con iva desglosado
       V_MTO_GRAVADA := ROUND((P_MONTO/1.1),V_REDONDEO);
       V_MTO_IVA := ROUND((P_MONTO/11),V_REDONDEO);
       --CONTROL DE MOVIMIENTOS EN MONEDA EXTRANJERA
       IF P_COD_MONEDA != PAG_GEN.FU_OBT_MON_LOCAL then--cta débito moneda extranjera
          pag_gen.pr_con_mon_a_moneda(P_COD_MONEDA,--moneda original
                                       PAG_GEN.FU_OBT_MON_LOCAL,  --moneda destino (GS)
                                      V_MTO_GRAVADA, --monto original
                                      v_mto_equ_local, -- monto destino
                                      v_cotizacion, 
                                      v_cot_mon_destino);    
        ELSE
             v_cotizacion := null;
             v_mto_equ_local :=  null;            
        END IF;

       
       --SE REGISTRA EL MOVIMIENTO DEL IVA Y LA GRAVADA
       
         --MOVIMIENTO GRAVADA
         r_gmovi.cod_usuario     := USER;
         r_gmovi.hora            := P_HORA;
         r_gmovi.fecha           := V_FECHA;
         -- Aumento la secuencia
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := V_COD_MODULO;
         r_gmovi.cod_modalidad   := V_COD_MODALIDAD;
         r_gmovi.cod_oficina     := P_COD_OFICNA;

         r_gmovi.cod_moneda      := P_COD_MONEDA;
         r_gmovi.fec_valor       := V_FECHA;
         r_gmovi.cod_tra_padre   := P_COD_TRA_PADRE;
         r_gmovi.cod_mod_padre   := V_MOD_PADRE;
         r_gmovi.cod_mad_padre   := V_MAD_PADRE;
         r_gmovi.cod_transaccion := P_COD_TRANSACCION;
         r_gmovi.monto           := V_MTO_GRAVADA;
         r_gmovi.nro_documento   := P_NRO_CONTRATO;        
         r_gmovi.cod_ofi_origen  := P_COD_OFICNA;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := P_CONCEPTO||' Contrato Nro.: '||P_NRO_CONTRATO;
         r_gmovi.estado          := 'N';    
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_rubro       := null;
         r_gmovi.cod_tasa        := NULL;
         r_gmovi.val_tasa        := NULL;
         r_gmovi.tip_mov_rubro   := null;--'C';
         r_gmovi.cod_persona     := p_cod_persona;
         r_gmovi.referencia      := NULL;
         r_gmovi.fec_fin_retencion := NULL;
         r_gmovi.cotizacion      := v_cotizacion;
         r_gmovi.mto_equ_local   := v_mto_equ_local;

         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);

         --CONTROL DE MOVIMIENTOS EN MONEDA EXTRANJERA
         IF P_COD_MONEDA != PAG_GEN.FU_OBT_MON_LOCAL then--cta débito moneda extranjera
            pag_gen.pr_con_mon_a_moneda(P_COD_MONEDA,--moneda original
                                        PAG_GEN.FU_OBT_MON_LOCAL,  --moneda destino (GS)
                                        V_MTO_IVA, --monto original
                                        v_mto_equ_local, -- monto destino
                                        v_cotizacion, 
                                        v_cot_mon_destino);    
          ELSE
               v_cotizacion := null;
               v_mto_equ_local :=  null;            
          END IF;
         
         
         --MOVIMIENTO IVA
         r_gmovi.cod_usuario     := USER;
         r_gmovi.hora            := P_HORA;
         r_gmovi.fecha           := V_FECHA;
         -- Aumento la secuencia
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := V_COD_MODULO;
         r_gmovi.cod_modalidad   := V_COD_MODALIDAD;
         r_gmovi.cod_oficina     := P_COD_OFICNA;

         r_gmovi.cod_moneda      := P_COD_MONEDA;
         r_gmovi.fec_valor       := V_FECHA;
         r_gmovi.cod_tra_padre   := P_COD_TRA_PADRE;
         r_gmovi.cod_mod_padre   := V_MOD_PADRE;
         r_gmovi.cod_mad_padre   := V_MAD_PADRE;
         r_gmovi.cod_transaccion := 518;
         r_gmovi.monto           := V_MTO_IVA;
         r_gmovi.nro_documento   := P_NRO_CONTRATO;        
         r_gmovi.cod_ofi_origen  := P_COD_OFICNA;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'IVA/'||P_CONCEPTO||' Contrato Nro.: '||P_NRO_CONTRATO;
         r_gmovi.estado          := 'N';    
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_rubro       := null;
         r_gmovi.cod_tasa        := 323;
         r_gmovi.val_tasa        := 10;
         r_gmovi.tip_mov_rubro   := null;--'C';
         r_gmovi.cod_persona     := p_cod_persona;
         r_gmovi.referencia      := NULL;
         r_gmovi.fec_fin_retencion := NULL;
         r_gmovi.cotizacion      := v_cotizacion;
         r_gmovi.mto_equ_local   := v_mto_equ_local;         

         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        
       
     ELSIF V_EXI_IVA = 'N'THEN--no se registra con iva
         --CONTROL DE MOVIMIENTOS EN MONEDA EXTRANJERA
         IF P_COD_MONEDA != PAG_GEN.FU_OBT_MON_LOCAL then--cta débito moneda extranjera
            pag_gen.pr_con_mon_a_moneda(P_COD_MONEDA,--moneda original
                                        PAG_GEN.FU_OBT_MON_LOCAL,  --moneda destino (GS)
                                        P_MONTO, --monto original
                                        v_mto_equ_local, -- monto destino
                                        v_cotizacion, 
                                        v_cot_mon_destino);    
          ELSE
               v_cotizacion := null;
               v_mto_equ_local :=  null;            
          END IF;     
     
        --MOVIMIENTO monto TOTAL
         r_gmovi.cod_usuario     := USER;
         r_gmovi.hora            := P_HORA;
         r_gmovi.fecha           := V_FECHA;
         -- Aumento la secuencia
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := V_COD_MODULO;
         r_gmovi.cod_modalidad   := V_COD_MODALIDAD;
         r_gmovi.cod_oficina     := P_COD_OFICNA;

         r_gmovi.cod_moneda      := P_COD_MONEDA;
         r_gmovi.fec_valor       := V_FECHA;
         r_gmovi.cod_tra_padre   := P_COD_TRA_PADRE;
         r_gmovi.cod_mod_padre   := V_MOD_PADRE;
         r_gmovi.cod_mad_padre   := V_MAD_PADRE;
         r_gmovi.cod_transaccion := P_COD_TRANSACCION;
         r_gmovi.monto           := P_MONTO;
         r_gmovi.nro_documento   := P_NRO_CONTRATO;        
         r_gmovi.cod_ofi_origen  := P_COD_OFICNA;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := P_CONCEPTO||' Contrato Nro.: '||P_NRO_CONTRATO;
         r_gmovi.estado          := 'N';    
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_rubro       := null;
         r_gmovi.cod_tasa        := NULL;
         r_gmovi.val_tasa        := NULL;
         r_gmovi.tip_mov_rubro   := null;--'C';
         r_gmovi.cod_persona     := NULL;
         r_gmovi.referencia      := NULL;
         r_gmovi.fec_fin_retencion := NULL;
         r_gmovi.cotizacion      := v_cotizacion;
         r_gmovi.mto_equ_local   := v_mto_equ_local;          

         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);

     
     END IF;
    
  P_NRO_SECUENCIA := v_nro_secuencia;
  

  END;      

end PAQ_CAJ;
/


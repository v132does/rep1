CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_369
 (P_NRO_OPERACION  In VARCHAR2,
 P_NRO_CAJA        In VARCHAR2,
 p_nro_documento   in varchar2 default null, -- Nro. de Documento del Titular del Contrato 
 P_NRO_CONTRATO    In VARCHAR2,
 p_mto_total       In number default null, -- total a cobrar
 p_mto_efectivo    In number default null, --total efectivo
 P_CHQ_NBCO        In number default null) -- total de cheq 24 hs

 RETURN long IS
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo      number(3)      := 9;    -- Caja
  v_cod_modalidad   number(3)      := 91;   -- Caja
  v_cod_transaccion number(4)      := 369;  -- transaccion
  v_cod_usuario     varchar2(10)   := upper(user); --usuario
  v_cod_persona     ge_movimientos.cod_persona%type;  
  
  -- Datos de la caja
  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_existe            varchar2(1);

  -- Datos de salida
  v_msj_salida    varchar2(8000);                          -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';                   -- sin errores
  v_msj_respuesta varchar2(4000) := 'Operacion Confirmada'; -- sin errores

  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'D' ;     -- 'C' credito para la caja (egreso) o vice versa
  v_nro_secuencia number(3) := 0;           -- secuencia del mov.

  -- datos que se cargan en la pantalla
  v_mto_total     number(18,2) := nvl(to_number(p_mto_total),0);
  v_mto_cobrado   number(18,2) := nvl(p_mto_efectivo,0) + nvl(P_CHQ_NBCO,0);
  r_gmovi          ge_movimientos%rowtype;
  
  -- datos de la cuota pagada
 -- v_nro_cuotas    cs_con_cuotas.nro_cuota%Type;--
  v_nro_cuota    cs_con_cuotas.nro_cuota%Type;--desde
 -- v_nro_cuota_des    cs_con_cuotas.nro_cuota%Type;--desde
  --v_nro_cuota_has    cs_con_cuotas.nro_cuota%Type;--hasta
  v_concepto ge_movimientos.concepto%type;
  --v_concepto_rec ge_movimientos.concepto%type;
  
  --datos del nro de recargo cobrado
 -- v_nro_recargo  cs_con_cuotas.nro_cob_exc_visitas%type;--desde
  --v_nro_recargo_has  cs_con_cuotas.nro_cob_exc_visitas%type;--hasta
  
  -- Datos para el proceso de calculo de cuotas a cobrar
  v_fcdehoy         date:= pag_cal.fu_obt_fec_actual(16);
  v_tot_cuo_pagar   number(18,2);
  v_cuo_pagar       varchar2(40);
  v_con_exc_visitas varchar2(40);
  v_mto_cobro       number(18,2);
  v_mto_recargo     number(18,2);
  v_cod_transaccion_cob ge_transacciones.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_COB_CAJ_SEG');
  v_cod_tra_recargo ge_transacciones.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_REC_CAJ_SEG');
  v_des_transaccion varchar2(100) := 'Deb.Caj.Seg.Con.:';
  v_des_tra_recargo varchar2(100) := 'Deb.Caj.Seg.Rec.Con.:';

  --cursor de cuotas pendientes a pagar
  /* cursor cuotas is
  select *
  from cs_con_cuotas t
  where t.nro_contrato = P_NRO_CONTRATO
  and   t.fec_pago is null
  and   t.estado = 'P';*/
  /*cursor cuotas is

      select sum(t.monto) monto,
             T.nro_contrato,
             t.cod_transaccion,
             -- t.nro_cuota,
             --  nvl(t.nro_cob_exc_visitas,0) nro_cob_exc_visitas,
             decode(t.cod_transaccion,1536,'Cobro.Caj.Seg.Con. Nro:','Cobro.Caj.Seg.Recargo.Con. Nro:')det_transaccion
      from   cs_con_cuotas t
      where  t.nro_contrato = P_NRO_CONTRATO
      and    t.fec_pago is null
      and    t.estado = 'P'
      group  by t.nro_contrato,
             t.cod_transaccion,
             decode(t.cod_transaccion,1536,'Cobro.Caj.Seg.Con. Nro:','Cobro.Caj.Seg.Recargo.Con. Nro:');
  */
  
  
  --cursor que traiga las cuotas a pagar

    
    -------------------
  cursor c_cuotas is
    select cuo.nro_contrato,
       cuo.nro_cuota,-- DYDMR-1759/ se agrega el numero de cuota para poder pasar el parametro a paq_caj.pr_cob_cuotas
       cuo.cod_transaccion,
       cuo.fec_desde fec_desde,  
       cuo.fec_hasta fec_hasta,
       nvl(cuo.monto,0) monto,
       cuo.nro_cob_exc_visitas
      From cs_Con_Cuotas cuo
     Where cuo.nro_contrato = P_NRO_CONTRATO
       and cuo.fec_vencimiento <= v_fcdehoy
       and cuo.fec_pago is null
       and cuo.estado = 'P'
     order by cuo.nro_cuota;
    
  procedure pr_gen_cobros(p_cod_transaccion in number, 
                               p_monto in number, 
                               p_des_transaccion in varchar2,
                               p_cuo_pagar in varchar2,
                               p_vis_exesiva in varchar2) is 
  begin

PAQ_CAJ.PR_GEN_MOVIMIENTOS
           (p_nro_contrato,--P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%Type,
            p_cod_transaccion,--P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
            v_cod_transaccion,--P_COD_TRA_PADRE IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
            v_cod_moneda,--P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE,
            v_nro_secuencia,--P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
            v_cod_oficina,--P_COD_OFICNA IN BA_OFICINAS.COD_OFICINA%TYPE,
            p_des_transaccion,--P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
            v_fec_actual,--P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE,
            v_hor_actual,--P_HORA IN GE_MOVIMIENTOS.FECHA%TYPE,
            p_monto,
            v_cod_persona);--P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE)
            
      paq_caj.pr_cob_cuotas(P_NRO_CONTRATO,p_monto,p_cod_transaccion,p_cuo_pagar, p_vis_exesiva,v_hor_actual);
        
  end ;
  
  procedure pr_pro_cuotas is
  begin
          --v_nro_cuotas := 0;
          --v_nro_cuota_des := 0;
          --v_nro_cuota_has := 0;
          v_tot_cuo_pagar := 0;
          v_cuo_pagar     := '*';
          v_mto_cobro     := 0;
          v_mto_recargo   := 0;
          v_con_exc_visitas := '*';
          for cuo in c_cuotas loop
              --v_con_cuotas := nvl(v_con_cuotas,0) + 1;
              if (nvl(v_tot_cuo_pagar,0) + nvl(cuo.monto,0)) <= p_mto_total then
                -- v_nro_cuota_has := cuo.nro_cuota;
                 v_tot_cuo_pagar := nvl(v_tot_cuo_pagar,0) + nvl(cuo.monto,0);
                -- v_cuo_pagar     := v_cuo_pagar||cuo.nro_cuota||'*';
                 --v_con_exc_visitas := v_con_exc_visitas||nvl(cuo.nro_cob_exc_visitas,0)||'*';
                 ------------
                 if cuo.cod_transaccion = v_cod_transaccion_cob then --Cobro--
                    v_mto_cobro := nvl(v_mto_cobro,0) + nvl(cuo.monto,0);
                    v_cuo_pagar     := v_cuo_pagar||cuo.nro_cuota||'*';
                 else --Recargo--
                    v_mto_recargo := nvl(v_mto_recargo,0) + nvl(cuo.monto,0);
                    v_con_exc_visitas := v_con_exc_visitas||nvl(cuo.nro_cob_exc_visitas,0)||'*';
                 end if;
                 ------------
              else
                 --Salir del ciclo de Cuotas--
                 exit;
              end if;
          end loop;
  end;
     
    --------------------
    

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
       update cj_controles
         set tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(P_CHQ_NBCO,0),
             sal_actual = nvl(sal_actual,0) + nvl(p_mto_efectivo,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(p_mto_efectivo,0),
             can_debitos = nvl(can_debitos,0) + decode(p_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;

      v_nro_secuencia := 0;

      if p_mto_efectivo > 0 then
        -- genero el movimiento por el efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, monto, tip_monto, tipo)
        values
           ( v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia,
            v_cod_transaccion,v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_contrato, p_mto_efectivo,'E', v_tipo);  -- es debito
      end if;

      if P_CHQ_NBCO > 0 then
        -- genero el movimiento por el deposito en cheques (local - 24 hs.)
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_contrato, Null, P_CHQ_NBCO,'C' ,v_tipo); /* es debito */
      end if;
  end lp_gen_transaccion;
---------------- INICIO DEL PROCESO PRINCIPAL ------------------

----
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 -- Valido la moneda
     if p_nro_documento is null then
        v_cod_respuesta := '001'; -- error
        v_msj_respuesta := 'ERROR: Ingrese el Nro. de Documento del Titula.';     
     elsif P_NRO_CONTRATO is null then
        v_cod_respuesta := '002'; -- error
        v_msj_respuesta := 'ERROR: Ingrese el Nro. de Contrato.';
     elsif v_mto_cobrado is null or v_mto_cobrado <= 0 then
        v_cod_respuesta := '003'; -- error
        v_msj_respuesta := 'ERROR: Ingrese el importe.';
     elsif v_mto_total  <> v_mto_cobrado then
        v_cod_respuesta := '004'; -- error
        v_msj_respuesta := 'ERROR: Monto Total no suma Detalles.';
     end if;


 if v_cod_respuesta = '000' then
   --validar los datos ingresados
   v_msj_respuesta:= FUJ_VAL_TRANSACCION_369(p_nro_operacion, p_nro_caja, p_nro_documento, P_NRO_CONTRATO,
         p_mto_total, p_mto_efectivo, P_CHQ_NBCO);
   if v_msj_respuesta NOT LIKE '%~OK~%' THEN
      return v_msj_respuesta;
      --v_msj_respuesta
   END IF;
 end if;

 if v_cod_respuesta = '000' then -- si no hubo problemas, verifico el contrato
    Begin
       select 'S', con.cod_moneda
         into v_existe, v_cod_moneda
        from cs_contratos con
       where nro_contrato = p_nro_contrato
         and estado in ('A', 'M', 'J') -- Activo o Moroso
         --and fec_vencimiento <= v_fec_actual
         And Exists (Select 'S'
                      From Cs_Con_Cuotas Cuo
                     Where Con.Nro_Contrato = Cuo.Nro_Contrato
                       And cuo.estado = 'P'
                       And cuo.fec_pago is null);
       -- Captura el nro de cuota a cobrar   (desde hasta)             
      
     -----------------2
     --Procesamiento de Cuotas--
     pr_pro_cuotas;
     -----------------2
     /*select MIN(nro_cuota)
         into v_nro_cuota
         from cs_con_cuotas
        where nro_contrato = P_NRO_CONTRATO
          And estado = 'P' and nro_cuota != 0
          And fec_pago is null; 
          
       select max(nro_cuota)
         into v_nro_cuota_has
         from cs_con_cuotas
        where nro_contrato = P_NRO_CONTRATO
          And estado = 'P' and nro_cuota != 0
          And fec_pago is null; 
          
       --captura el nro de recargo a cobrar (desde - hasta)
       select MIN(t.nro_cob_exc_visitas)
         into v_nro_recargo
         from cs_con_cuotas t
        where t.nro_contrato = P_NRO_CONTRATO
          And t.estado = 'P' and t.nro_cuota = 0
          And t.fec_pago is null; 
          
       select max(t.nro_cob_exc_visitas)
         into v_nro_recargo_has
         from cs_con_cuotas t
        where t.nro_contrato = P_NRO_CONTRATO
          And t.estado = 'P' and t.nro_cuota = 0
          And t.fec_pago is null;  
     */   --preparamos el mensaje para el registro de movimientos 
        -----------------2
        if nvl(v_mto_cobro,0)>0 then
           v_concepto:= 'Cuota.Nro. '||replace(v_cuo_pagar,'*',',');
        end if;
        if nvl(v_mto_recargo,0)>0 then
           v_concepto:=v_concepto||' Recargo.Nro. '||replace(v_con_exc_visitas,'*',',');
        end if;
--         este codigo reemplaza el codigo de abajo
        -----------------2   
     /*   if nvl(v_nro_cuota,0) != nvl(v_nro_cuota_has,0) then
           v_concepto:= 'Cuota.Nro. '||v_nro_cuota||' a '||v_nro_cuota_has;
           v_nro_cuota := v_nro_cuota_has;
        end if;
        
        if nvl(v_nro_recargo,0) != nvl(v_nro_recargo_has,0) then
           v_concepto:= v_concepto||' Recargo.Nro. '||v_nro_recargo||' a '||v_nro_recargo_has;
          -- v_nro_recargo := v_nro_recargo_has;
        end if;    */
          
    exception
         when no_data_found then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'ERROR: Nro. de Contrato no existe!';
         when others then
           v_cod_respuesta := '003';
           v_msj_respuesta := 'ERROR' || sqlerrm;
    end;
    if v_cod_respuesta = '000' then
       if v_cod_respuesta = '000' then
          --v_cod_moneda := pag_gen.FU_OBT_MON_LOCAL;
         -- Obtengo los datos de la caja --
          prj_obt_datos_caja(p_nro_caja,
                              v_cod_moneda,
                              v_cod_oficina,
                              v_fec_caja,
                              v_estado,
                              v_sal_actual,
                              v_sal_cheques);
         if v_estado = -1 then
            v_cod_respuesta := '006'; -- error, no existe registro de caja
            v_msj_respuesta := 'Caja inexistente!!';
         elsif v_estado in (0,2) then
            v_cod_respuesta := '004'; -- error
            v_msj_respuesta := 'Realice la Apertura de Caja previamente';
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
         end if;
         -- verifico los decimales del importe en cheques
         if P_CHQ_NBCO > 0 then
            v_msj_respuesta := fuj_val_importe(v_tipo, 'C',v_cod_moneda, P_CHQ_NBCO);
            if v_msj_respuesta is not null then 
               v_cod_respuesta := '005';  -- error      
            end if;
         elsif P_MTO_EFECTIVO > 0 then  -- valido el importe en efectivo
            v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda, P_MTO_EFECTIVO);
            if v_msj_respuesta is not null then 
               v_cod_respuesta := '005';  -- error      
            end if;
         end if;
       end if;
     end if;
 end if;
 
 --   end if;
-- end if;
 
 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   -- Asigno el nro de caja a los movimientos
   pag_cta.pr_nro_caja(to_number(p_nro_caja));
   
   begin
     select cod_persona
       into v_cod_persona
       from cs_con_personas per
      where per.nro_contrato = p_nro_contrato
        and per.tip_relacion = 'T';
   exception
      --En caso de que posea 2 titulares
      when others then
          begin
             select per.cod_persona
               into v_cod_persona
               from cs_contratos con, cs_con_personas per, ge_cta_clientes cta
              where con.nro_contrato = p_nro_contrato
                and per.nro_contrato = con.nro_contrato
                and cta.nro_cuenta = con.nro_cta_debito
                and cta.relacion = 'P'
                and cta.cod_persona = per.cod_persona
                and per.tip_relacion = 'T';
           exception
              when others then
                v_cod_persona := null;
           end;
   end;

   
   -- genero movimiento por el cobro en efectivo --
   if p_mto_efectivo  > 0 Then
      v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;

      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hor_actual;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_modulo      := 16;
      r_gmovi.cod_modalidad   := 161;
      r_gmovi.cod_oficina     := v_cod_oficina;
      r_gmovi.cod_moneda      := v_cod_moneda;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := v_cod_transaccion;
      r_gmovi.cod_mod_padre   := v_cod_modulo;
      r_gmovi.cod_mad_padre   := v_cod_modalidad;
      r_gmovi.nro_caja        := to_number(p_nro_caja);
      r_gmovi.cod_transaccion := 740; --- Efectivo
      r_gmovi.monto           := p_mto_efectivo;
      r_gmovi.nro_documento   := P_NRO_CONTRATO;
      r_gmovi.nro_documento3  := v_nro_cuota;
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Cobro Contrato :'||p_nro_contrato||'-'||v_concepto;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.nro_cuenta      := NULL;
      r_gmovi.tip_mov_rubro   := NULL;
      r_gmovi.cod_persona     := v_cod_persona;
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
   end if;
   -- genero movimiento por el cobro en cheque --
   if P_CHQ_NBCO > 0 then
      v_nro_secuencia := v_nro_secuencia + 1;

      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hor_actual;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_modulo      := 16;
      r_gmovi.cod_modalidad   := 161;
      r_gmovi.cod_oficina     := v_cod_oficina;
      r_gmovi.cod_moneda      := v_cod_moneda;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := v_cod_transaccion;
      r_gmovi.cod_mod_padre   := v_cod_modulo;
      r_gmovi.cod_mad_padre   := v_cod_modalidad;
      r_gmovi.nro_caja        := to_number(p_nro_caja);
      r_gmovi.cod_transaccion := 606; --- Cheques
      r_gmovi.monto           := P_CHQ_NBCO;
      r_gmovi.nro_documento   := p_nro_contrato;
      r_gmovi.nro_documento3  := v_nro_cuota;
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Cobro Contrato :'||p_nro_contrato||'-'||v_concepto;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.nro_cuenta      := NULL;
      r_gmovi.tip_mov_rubro   := NULL;
      r_gmovi.cod_persona     := v_cod_persona;
      ---- Recuperar datos de la retencion
      pag_cta.PR_OBT_RETENCION(v_fec_actual,Null,
              Null, Null, 606, v_cod_moneda,
              r_gmovi.cod_retencion, r_gmovi.fec_fin_retencion);
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
   end if;
   
   -- Actualiza las cuotas
   if nvl(v_tot_cuo_pagar,0) > 0 then --Puede Debitar algo--
         if(nvl(v_tot_cuo_pagar,0)=p_mto_total) then    
             --Procesamiento de Recargo--
             if nvl(v_mto_recargo,0) > 0 THEN
                pr_gen_cobros(v_cod_tra_recargo, v_mto_recargo, v_des_tra_recargo, '*0*', v_con_exc_visitas);
             end if;
             --Procesamiento de Cobro--             
             if nvl(v_mto_cobro,0) > 0 THEN
                pr_gen_cobros(v_cod_transaccion_cob, v_mto_cobro, v_des_transaccion, v_cuo_pagar,'*0*');
             end if;
          else
             v_cod_respuesta := '004'; -- error
              
             v_msj_respuesta := 'ERROR: El Monto Total a Cobrar debe ser igual a la suma de cuotas completas y no parciales.'||chr(10)||'El mayor monto que puede pagar es '||trim(to_char(nvl(v_tot_cuo_pagar,0),'999,999,999,990.99'))||' correspondientes a las cuotas '||replace(v_cuo_pagar,'*','-');
             if length(v_con_exc_visitas)>2 then
                   v_msj_respuesta :=v_msj_respuesta || ' mas regargos por visitas ';
             end if;    
          end if;
    else
          v_cod_respuesta := '004'; -- error
          v_msj_respuesta := 'ERROR: Monto insuficiente para pagar cuotas.';
    end if;   
  /* begin
     for a in cuotas loop
       --paq_caj.pr_cob_cuotas(a.nro_contrato,a.monto,v_fec_actual,v_hor_actual,v_nro_secuencia,v_cod_transaccion);
       paq_caj.pr_cob_cuotas(a.nro_contrato,a.monto,a.cod_transaccion,null, null,v_hor_actual);
       
       PAQ_CAJ.PR_GEN_MOVIMIENTOS
           (a.nro_contrato,--P_NRO_CONTRATO IN CS_CON_CUOTAS.NRO_CONTRATO%Type,
            a.cod_transaccion,--P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
            v_cod_transaccion,--P_COD_TRA_PADRE IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
            v_cod_moneda,--P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE,
            v_nro_secuencia,--P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE,
            v_cod_oficina,--P_COD_OFICNA IN BA_OFICINAS.COD_OFICINA%TYPE,
            a.det_transaccion,--P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
            v_fec_actual,--P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE,
            v_hor_actual,--P_HORA IN GE_MOVIMIENTOS.FECHA%TYPE,
            a.monto,
            v_cod_persona);--P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE)
       
     end loop;
   end;*/
 end if;

 if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos para grabar
   --actualizar caja
   lp_gen_transaccion;
 end if;

 if v_cod_respuesta = '000' then
   v_msj_respuesta := 'Operación Confirmada.';
 end if;

 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
exception
   when others then
     v_cod_respuesta := '999';
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     nvl(v_msj_respuesta,SQLERRM);
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_369;
/


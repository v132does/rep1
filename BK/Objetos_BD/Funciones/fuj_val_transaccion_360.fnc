CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_360
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_COMPROBANTE IN NUMBER default null --nro de comprobante manual
-- ,P_NOMBRE IN VARCHAR2
 ,P_NRO_DOCUMENTO IN VARCHAR2 default null
 ,P_NRO_CUENTA IN VARCHAR2 default null
 ,P_NRO_CUOTA_DESDE IN NUMBER default null
 ,P_NRO_CUOTA_HASTA IN NUMBER default null
 ,P_EFECTIVO IN VARCHAR2 default null
 ,P_CHQ_NBCO IN VARCHAR2 DEFAULT NULL
 ,P_CHQ_OBCO IN VARCHAR2 DEFAULT NULL
 )
 RETURN long 
 IS

  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;                         -- modulo Caja
  v_cod_modalidad number(3) := 91;                 -- modalidad Caja
  v_cod_transaccion number(4) := 360;            -- cod de transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  --
  v_msj_salida    long;--varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := 'OK'; -- sin errores
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    varchar2(4000) := null;
  v_dia_mora      pr_cta_prestamos.dia_atraso%type;
  v_lis_valores   varchar2(4000) := null;
  -- Datos de la caja
  v_fec_actual         date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hora               varchar2(8);
  v_cod_oficina        number(3);         -- Codigo de oficina
  v_estado             number(1);         -- estado de la caja
  v_fec_caja           date;              -- fecha de la caja
  v_sal_actual         number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta de préstamo
  v_denominacion       varchar2(100);     -- Nombre de la cuenta
  v_mto_cobrado        number(18,2);      -- Mto cobrado (no se despliega)
  v_tot_capital        number(18,2);      -- Capital (no se despliega )
  v_tot_interes        number(18,2);      -- Interés (no se despliega )
  v_tot_cap_int        number(18,2);      -- Capital + interés + int.adel (DESPLIEGA : importe )
  v_tot_int_adelantado number(18,2);      -- Interes adelantado (no despliega)
  v_tot_mora           number(18,2);      -- Mora s/capital (no despliega)
  v_tot_mora_interes   number(18,2);      -- Mora s/Interés (DESPLIEGA : Mora s/interés )
  v_tot_mora_int_adel  number(18,2);      -- Mora interés adelantado (no desp)
  v_tot_impuesto       number(18,2);      -- Total impuesto (DESPLIEGA : ley 125/91)
  v_tot_cargo          number(18,2);      -- Total cargo (DESPLIEGA : Cargo + IVA )
  v_tot_cargo_iva      number(18,2);      -- Total cargo IVA  (no desp)
  v_tot_int_descontado number(18,2);      -- Total interes descontado (no desp)
  v_tot_iva_descontado number(18,2);
  v_tot_seg_descontado number(18,2);
  v_tot_a_cobrar       number(18,2);      -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
  v_tot_mora_cap       number(18,2);      -- Total mora s/capital (DESPLIEGA: v_tot_mora+v_tot_mora_int_adel)
  v_tot_punitorio      number(18,2);      -- Total monto punitorio (DESPLIEGA : Punitorio)
  v_tot_cre_cta        number(18,2);      -- Total pagado contra cuenta de ahorro
  v_tot_cre_cta_con    number(18,2);      -- Total pagado contra cuenta contable

  v_tip_cuenta              number(3);         -- modalidad cta
  v_cod_moneda           varchar2(3);       -- moneda de la cta
  v_est_cuenta               varchar2(1);       -- estado de la cuenta
  v_nro_cuota_desde    number(3);         -- nro. cuota a pagar desde
  v_nro_cuota_hasta     number(3);         -- nro. cuota a pagar hasta
  v_can_tot_cuotas      number(3);         -- cantidad total de cuotas
  v_estado_cuota           varchar2(1);         -- estado de la cuota

  v_nro_documento          cj_movimientos.nro_documento%type;         -- nro. documento de la cuota
  v_lov_nro_documento      ba_personas.nro_documento%type;         -- nro. documento de la cuota
  v_lov_nro_cuenta         ge_cuentas.nro_cuenta%type;
  v_lov_nombre             ba_personas.nom_completo%type;

  -- Contenedor de la lista de valores a devolver
  v_val_posibles  varchar2(3000) := null;

  v_efectivo      number(18,2) := 0;
  v_chq_obco      number(18,2) := 0;
  v_chq_nbco      number(18,2) := 0;

  v_cod_tran_pend  number(4);    --- transaccion operacion pend.(efect 740 - cheq 607)
  --v_monto_efectivo number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  --v_monto_cheque   number(18,2) :=0; --- importe pagado operacion pendiente cheque
  --v_monto_cheque_n number(18,2) :=0;
  v_monto_efectivo number(18,2) := nvl(p_efectivo,0); --- importe pagado operacion pendiente efectivo
  v_monto_cheque   number(18,2) := nvl(p_chq_obco,0); --- importe pagado operacion pendiente cheque
  v_monto_cheque_n number(18,2) := nvl(p_chq_nbco,0);  
  
  v_tip_retencion  ge_movimientos.cod_retencion%type;

  cursor c_cobros is 
    select cod_transaccion, monto 
      from ge_movimientos 
     where cod_tra_padre = v_cod_transaccion  
       and fecha         = v_fec_actual 
       and cod_usuario   = v_cod_usuario 
       and hora          = v_hora  
       and estado        = 'J'  
       and reversado     = 'N';

--- para activar campo cheque nuestro banco si tiene habilitado el modulo de cta.cte.

 v_estado_modulo        ba_modulos.estado%type ;
 v_tip_dato             ge_tra_campos.tip_dato%type;
 v_existe               number;
Begin
-------------------------PROCESO PRINCIPAL-------------------------
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
/* if p_nro_documento is NOT null then
 if p_nro_cuenta is null then
 null;*/
   -- reemplazo el nro de documento en el select
  /* if p_nro_documento is NOT null then
      v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA');
      v_det_campos := v_det_campos ||fuj_des_campo('NRO_CUENTA','X',
                        fuj_pro_val_posibles(replace(v_val_posibles,'&NRO_DOCUMENTO',P_NRO_DOCUMENTO)));
   end if;*/

/*   if p_nro_documento is not null then
      -- busca el numero de cuenta
      select a.nro_cuenta
        into v_lov_nro_cuenta
        from ba_personas p,  ge_cta_clientes b, ge_cuentas a
       where p.cod_persona = b.cod_persona
         and a.nro_cuenta = b.nro_cuenta
         and a.cod_modulo = 6
         and b.relacion= 'P'
         and p.nro_documento = p_nro_documento;
         \*and a.nro_cuenta in
          (select nro_cuenta
             from ge_movimientos mov
            where mov.reversado = 'N'
                and mov.cod_tra_padre = 360
                and  (mov.fecha, mov.hora, mov.cod_usuario) in
                (select d.fecha, d.hora, d.cod_usuario
                   from ge_movimientos d
                  where d.cod_modulo = 6
                    and d.estado = 'J'
                    and d.cod_tra_padre = 360));*\
   end if;
   -- Obtengo el select de la lista de valores para el documento
   If p_nro_documento is not null then
       v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA');
       v_val_posibles := replace(v_val_posibles,'&NRO_DOCUMENTO',p_nro_documento);
       if v_cod_respuesta = '000' then
         v_det_campos := v_det_campos ||
                          '[' ||
                          'NRO_CUENTA'||'~'||nvl(v_lov_nro_cuenta, 'X')||'~'||
                          fuj_pro_val_posibles(replace(fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA'),'&NRO_DOCUMENTO',p_nro_documento)) ||
                          ']';
         v_can_campos := v_can_campos + 1;
       end if;
   end if;*/
 --else
 if p_nro_documento is not null and p_nro_cuenta is null then
   v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA');
   v_lis_valores   := fuj_pro_val_posibles(replace(v_val_posibles,'&NRO_DOCUMENTO',P_NRO_DOCUMENTO));
   begin
     select fuj_des_campo('NRO_CUENTA',a.nro_cuenta,v_lis_valores)
       into v_det_campos
      from pr_cuotas d, pr_cta_prestamos a, ge_cta_clientes b, ba_personas c 
      where d.nro_cuenta = a.nro_cuenta
      and d.nro_cuota = (Select min(x.nro_cuota)
                           from pr_cuotas x
                          where x.nro_cuenta = a.nro_cuenta
                            and x.nro_cuota > 0 
                            and x.estado != 'N')
      and a.nro_cuenta = b.nro_cuenta 
      and a.cod_modulo = 6  
      and a.estado <> 'N' 
      and b.cod_persona = c.cod_persona 
      and b.relacion= 'P' 
      and c.nro_documento = p_nro_documento
      order by a.nro_cuenta;
   exception
      when no_data_found then
         v_det_campos := fuj_des_campo('NRO_CUENTA',' ',v_lis_valores);
      when too_many_rows then
         v_det_campos := fuj_des_campo('NRO_CUENTA',' ',v_lis_valores);
      when others then
         v_det_campos := fuj_des_campo('NRO_CUENTA',' ',v_lis_valores);
         v_cod_respuesta := '007';
         v_msj_respuesta := 'ERROR: Buscando cuenta '||sqlerrm;
   end;
 elsif p_nro_cuenta is not null then
   v_can_campos := 13;
   v_det_campos :=
           '[' || 'DES_CUENTA' ||'~ ]' ||
           '[' || 'COD_MONEDA' ||'~ ]' ||
           '[' || 'TOT_CAP_INT' ||'~ ]' ||
           '[' || 'TOT_MORA_INTERES' ||'~ ]' ||
           '[' || 'TOT_MORA' ||'~ ]' ||
           '[' || 'TOT_PUNITORIO' ||'~ ]' ||
           '[' || 'TOT_IMPUESTO' ||'~ ]' ||
           '[' || 'TOT_CARGO_IVA' ||'~ ]' ||
           '[' || 'TOT_A_COBRAR' ||'~ ]' ;

   -- obtengo datos de la cuenta  --
    begin
     select denominacion, cod_modulo, cod_moneda
     into v_denominacion, v_tip_cuenta, v_cod_moneda
     from ge_cuentas a
     where a.nro_cuenta = p_nro_cuenta;
     v_cod_respuesta := '000';
    exception
     when no_data_found then
       v_cod_respuesta := '004';
       v_msj_respuesta := 'ERROR: Cuenta no existe ';
     when others then
       v_cod_respuesta := '003';
       v_msj_respuesta := 'ERROR: Al buscar la cuenta ';
    end;
    
    if v_cod_respuesta = '000' then
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
      if v_cod_respuesta = '000' then
        --verificar comprobante
         if v_cod_respuesta = '000' then
           If p_nro_comprobante is not null then
             -- Verifico la duplicacion del registro
             prj_val_duplicacion(p_nro_caja,
                                 v_cod_transaccion,
                                 v_cod_moneda,
                                 p_nro_comprobante,
                                 v_cod_respuesta,
                                 v_msj_respuesta);
           End if;
         end if;
      end if;
      if v_cod_respuesta = '000' then
        if v_tip_cuenta <> 6 then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Tipo de cuenta no es de Préstamos ';
        else

  ---- raise_application_error(-20000,'c:'||to_char(p_nro_cuota_desde)||' '||to_char(p_nro_cuota_hasta));

             --- verifica la cuota a pagar
          if nvl(p_nro_cuota_desde,0) = 0 then  -- ingreso 0 en cuota desde, busca cuota minima
             v_nro_cuota_desde := 1;
             v_nro_cuota_hasta := 999;
          elsif p_nro_cuota_desde > 0 and p_nro_cuota_hasta = 0 then -- solo ingreso cuota desde
             v_nro_cuota_desde := p_nro_cuota_desde;
             v_nro_cuota_hasta := p_nro_cuota_desde;
          elsif p_nro_cuota_Desde   >  p_nro_cuota_hasta then --ingreso las 2 pero mal
             v_cod_respuesta := '003';
             v_msj_respuesta := 'ERROR: Cuota hasta debe ser mayor ';
          else                                                    --- ambos ok
             v_nro_cuota_desde := p_nro_cuota_desde;
             v_nro_cuota_hasta := p_nro_cuota_hasta;
          end if;

          --verificar si hay 359 pendiente de pasar x caja, para avisar al cajero la operación a realizar
          begin
            Select count(*) 
              into v_existe
              from ge_movimientos g
             where g.cod_tra_padre = 359
               and g.fecha         = v_fec_actual 
               and g.reversado     = 'N' 
               and g.estado        = 'J'
               and exists (select 1 
                             from ge_movimientos mov
                            where  mov.nro_cuenta    = p_nro_cuenta
                              and mov.cod_tra_padre = 359
                              and mov.fecha         = g.fecha
                              and mov.hora          = g.hora
                              and mov.reversado     = 'N');
             if v_existe > 0 then 
                v_cod_respuesta := '001';  ---- debe retomar 359 hay pendientes 'J'
                v_msj_respuesta := 'ERROR: Utilice Transacción 359 ';
             end if;
          exception
            when others then
               v_cod_respuesta := '000';
          end;
          if v_cod_respuesta = '000' then
          -- AQUI LA VALIDACION DE SI ES PARA RETOMAR EN CAJA, SINO SIGUE ABAJO
             prj_ver_pen_caja(p_nro_cuenta,
                           v_cod_transaccion,
                           v_fec_actual,
                           v_cod_usuario,
                           v_hora,
                           v_cod_tran_pend,
                           v_cod_respuesta,
                           v_msj_respuesta);
             if v_cod_respuesta = '001' then  ---- debe retomar hay pendientes 'J'
                v_cod_respuesta := '000';
                prj_obt_dat_pend(p_nro_cuenta,
                            v_nro_cuota_desde,
                            v_nro_cuota_hasta,
                            v_fec_actual,
                            v_hora,
                            v_tot_capital,
                            v_tot_interes,
                            v_tot_int_adelantado,
                            v_tot_mora,
                            v_tot_mora_interes,
                            v_tot_mora_int_adel,
                            v_tot_impuesto,
                            v_tot_cargo,
                            v_tot_cargo_iva,
                            v_tot_int_descontado,
                            v_tot_iva_descontado,
                            v_tot_seg_descontado,
                            v_tot_punitorio,
                            v_tot_cre_cta,
                            v_tot_cre_cta_con,
                            v_cod_transaccion,
                            v_cod_respuesta,
                            v_msj_respuesta);

                if to_number(v_cod_respuesta) = 0 then
                   v_cod_respuesta :='000';
                end if;
             else    ---  transaccion 360 normal
                v_cod_usuario := user;
                if v_nro_cuota_desde = 1 and v_nro_cuota_hasta = 999 then
                 --- busca la minima a pagar porque no cargo cuotas
                   begin
                    select nro_cuota, nro_cuota, nro_cuenta into
                     v_nro_cuota_desde, v_nro_cuota_hasta, v_nro_documento --- nro.documento p/cj_mov la 1ra.
                     from pr_cuotas  where
                      nro_cuenta = p_nro_cuenta and
                      nro_cuota  = (select min(nro_cuota) from pr_cuotas p1 where
                                      p1.nro_cuenta = p_nro_cuenta and
                                      p1.nro_cuota  <> 0 and
                                      p1.estado     <> 'N'  ) and
                      nro_cuota <> 0 and
                      estado    <> 'N';
                      v_cod_respuesta := '000';
                   exception
                    when others then
                     v_cod_respuesta := '009';
                     v_msj_respuesta := 'ERROR: No existe cuota a pagar ';
                   end;
                else    --- ingreso rango de cuota a pagar y busco nro.documento unico p/mov.cj
                   begin
                    select estado, nro_cuenta into v_estado_cuota, v_nro_documento
                     from pr_cuotas  where
                     nro_cuenta = p_nro_cuenta and
                     nro_cuota  = v_nro_cuota_desde and
                     nro_cuota <> 0;

                     if v_estado_cuota = 'N' then
                       v_cod_respuesta := '011';
                       v_msj_respuesta := 'ERROR: Cuota '||p_nro_cuota_desde||' ya fue pagada ';
                     else
                       v_cod_respuesta := '000';
                     end if;
                   exception
                    when no_data_found then
                     --- si la 1ra. cuota del rango ya esta pagada , busca la minima
                        select nro_cuota, nro_cuota, nro_cuenta  into
                         v_nro_cuota_desde, v_nro_cuota_hasta, v_nro_documento
                         from pr_cuotas  where
                          nro_cuenta = p_nro_cuenta and
                          nro_cuota  = (select min(nro_cuota) from pr_cuotas p1 where
                                      p1.nro_cuenta = p_nro_cuenta and
                                      p1.nro_cuota  <> 0 and
                                      p1.estado     <> 'N'  ) and
                           nro_cuota <> 0 and
                           estado    <> 'N';
                           v_cod_respuesta := '000';
                    when others then
                     v_cod_respuesta := '009';
                     v_msj_respuesta := 'ERROR: al Buscar Cuota a pagar '||sqlerrm;
                   end;
                end if;
                if v_cod_respuesta = '000' then
                  -- Verifico la duplicacion del registro
                  prj_val_duplicacion(p_nro_caja,
                               v_cod_transaccion,
                              v_cod_moneda,
                              v_nro_documento,
                              v_cod_respuesta,
                              v_msj_respuesta);
                  v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                     v_tip_cuenta,
                                                     v_cod_transaccion,
                                                     v_est_cuenta,
                                                     'C'); -- 'C'== CREDITO
                  if v_msj_respuesta is not null then
                    v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
                  end if;
                end if;
                if v_cod_respuesta = '000' then -- sino hubo ERROR se arma los datos de la cuenta
                   pap_pre.PR_INI_AUTORIZACION;
                   pap_pre.PR_OBT_DEU_PRESTAMO(p_nro_cuenta,
                                     v_fec_actual,
                                     v_nro_cuota_desde,
                                     v_nro_cuota_hasta,
                                     v_cod_oficina,
                                     v_mto_cobrado,
                                     v_cod_respuesta,
                                     v_msj_respuesta,
                                     v_tot_capital,
                                     v_tot_interes,
                                     v_tot_int_adelantado,
                                     v_tot_mora,
                                     v_tot_mora_interes,
                                     v_tot_mora_int_adel,
                                     v_tot_punitorio,
                                     v_tot_impuesto,
                                     v_tot_cargo,
                                     v_tot_cargo_iva,
                                     v_tot_int_descontado,
                                     v_dia_mora,
                                     360,  --- cod_tra_padre
                                     'N'); --- cancela
                   if to_number(v_cod_respuesta) = 0 then
                     v_cod_respuesta :='000';
                   end if;
                end if; -- fin sino hubo error para sacar datos de cobros
             end if; -- fin de transaccion normal o pendiente
         end if;
           ---- A PARTIR DE AQUI ES IGUAL PARA LA SALIDA DE AMBOS CASOS ---
         if v_cod_respuesta = '000' then
            -- Busco la cantidad de cuotas.
            Select nvl(max(nro_cuota), 0)
              into v_can_tot_cuotas
              from pr_cuotas
             where nro_cuenta = p_nro_cuenta
               and nro_cuota > 0;

           v_tot_cap_int  := nvl(v_tot_capital,0) + nvl(v_tot_interes,0)+ nvl(v_tot_int_adelantado,0);
           v_tot_mora_cap := nvl(v_tot_mora,0) + nvl(v_tot_mora_int_adel,0);

           v_tot_a_cobrar:= nvl(v_tot_cap_int,0) +
                           nvl(v_tot_mora_interes,0) +
                           nvl(v_tot_mora_cap,0) +
                           nvl(v_tot_punitorio,0) +
                           nvl(v_tot_impuesto,0) +
                           nvl(v_tot_cargo,0) ;

           if v_hora is null then       --- transaccion 360 normal
               v_det_campos :=
                  /*'[' || 'DES_CUENTA' ||'~'||v_denominacion||'~ ]' ||
                  '[' || 'NRO_CUOTA_DESDE' ||'~'||ltrim(to_char(v_nro_cuota_desde))||'~ ]' ||
                  '[' || 'NRO_CUOTA_HASTA' ||'~'||ltrim(to_char(v_nro_cuota_hasta))||'~ ]' ||
                  '[' || 'CAN_TOT_CUOTAS' ||'~'||ltrim(to_char(v_can_tot_cuotas))||'~ ]' ||
                  '[' || 'COD_MONEDA' ||'~'||ltrim(v_cod_moneda)||'~ ]' ||
                  '[' || 'TOT_CAP_INT' ||'~'||ltrim(to_char(v_tot_cap_int))||'~ ]' ||
                  '[' || 'TOT_MORA_INTERES' ||'~'||ltrim(to_char(v_tot_mora_interes))||'~ ]' ||
                  '[' || 'TOT_MORA' ||'~'||ltrim(to_char(v_tot_mora_cap))||'~ ]' ||
                  '[' || 'TOT_PUNITORIO' ||'~'||ltrim(to_char(v_tot_punitorio))||'~ ]' ||
                  '[' || 'TOT_IMPUESTO' ||'~'||ltrim(to_char(v_tot_impuesto))||'~ ]' ||
                  '[' || 'TOT_CARGO_IVA' ||'~'||ltrim(to_char(v_tot_cargo))||'~ ]' ||
                  '[' || 'TOT_A_COBRAR' ||'~'||ltrim(to_char(v_tot_a_cobrar))||'~ ]' ||
                  '[' || 'EFECTIVO' ||'~'||ltrim(to_char(v_tot_a_cobrar))||'~ ]';*/

                  fuj_des_campo('DES_CUENTA', v_denominacion, null, null) ||
                  fuj_des_campo('NRO_CUOTA_DESDE', ltrim(to_char(v_nro_cuota_desde)), null, 'I') ||
                  fuj_des_campo('NRO_CUOTA_HASTA', ltrim(to_char(v_nro_cuota_hasta)), null, 'I') ||
                  fuj_des_campo('CAN_TOT_CUOTAS', ltrim(to_char(v_can_tot_cuotas)), null, null) ||
                  fuj_des_campo('COD_MONEDA', ltrim(v_cod_moneda), null, null) ||
                  fuj_des_campo('TOT_CAP_INT', ltrim(to_char(v_tot_cap_int)), null, null) ||
                  fuj_des_campo('TOT_MORA_INTERES', ltrim(to_char(v_tot_mora_interes)), null, null) ||
                  fuj_des_campo('TOT_MORA', ltrim(to_char(v_tot_mora_cap)), null, null) ||
                  fuj_des_campo('TOT_PUNITORIO', ltrim(to_char(v_tot_punitorio)), null, null) ||
                  fuj_des_campo('TOT_IMPUESTO', ltrim(to_char(v_tot_impuesto)), null, null) ||
                  fuj_des_campo('TOT_CARGO_IVA', ltrim(to_char(v_tot_cargo)), null, null) ||
                  fuj_des_campo('TOT_A_COBRAR', ltrim(to_char(v_tot_a_cobrar)), null, null) ||
                  fuj_des_campo('EFECTIVO', ltrim(to_char(v_monto_efectivo)), null, 'I') ||
                  fuj_des_campo('CHQ_OBCO', ltrim(to_char(v_monto_cheque)), null, 'I') ||
                  fuj_des_campo('CHQ_NBCO', ltrim(to_char(v_monto_cheque_n)), null, 'I') ||
                  fuj_des_campo('CRE_CUENTA', ltrim(to_char(v_tot_cre_cta)), null, null) ||
                  fuj_des_campo('CRE_CTA_CON', ltrim(to_char(v_tot_cre_cta_con)), null, null) ||
                  fuj_des_campo('TIP_RETEN', ltrim(to_char(v_tip_retencion)), null, 'I');
                  
                  if nvl(v_monto_cheque,0) > 0 then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := 'ERROR: Para cobros con Cheque c/Otro Bco debe utilizar la transacción 361.';
                  end if;                  
                  
                  --Verificar que no se realice Cobro mixto con Cheque
                  if nvl(v_monto_cheque,0) + nvl(v_monto_cheque_n,0) > 0 and nvl(v_monto_efectivo,0) > 0 then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := 'ERROR: No se puede combinar el Cobro en Cheque c/Otro Bco. con otra forma de Cobro';
                  end if;    
                  
                  
/*              if NVL(P_CHQ_OBCO,0)<= 0 then -- no tiene cheque otro banco
                 v_det_campos := v_det_campos || fuj_des_campo('TIP_RETEN',null,null,'D');
              else 
                 v_det_campos := v_det_campos || fuj_des_campo('TIP_RETEN',1,null,'I');
--   v_lis_valores   := fuj_pro_val_posibles(replace(v_val_posibles,'&NRO_DOCUMENTO',P_NRO_DOCUMENTO));

              end if;
*/           else
                -- busca las operaciones pendientes para actualizar
                for reg in c_cobros loop
                   if reg.cod_transaccion = 740 then
                      v_monto_efectivo := reg.monto;
                   elsif reg.cod_transaccion in (607, 610, 632) then --retencion 1,2,3
                      v_monto_cheque   := reg.monto;
                      if reg.cod_transaccion = 607 then
                         v_tip_retencion := 1;
                      elsif reg.cod_transaccion = 610 then
                         v_tip_retencion := 2;
                      elsif reg.cod_transaccion = 632 then
                         v_tip_retencion := 3;
                      end if;
                   elsif reg.cod_transaccion = 606 then
                      v_monto_cheque_n   := reg.monto;
                      
                   end if;
                end loop;
                --solo despliegue
                v_det_campos :=
                  fuj_des_campo('DES_CUENTA', v_denominacion, null, null) ||
                  fuj_des_campo('NRO_CUOTA_DESDE', ltrim(to_char(v_nro_cuota_desde)), null, 'D') ||
                  fuj_des_campo('NRO_CUOTA_HASTA', ltrim(to_char(v_nro_cuota_hasta)), null, 'D') ||
                  fuj_des_campo('CAN_TOT_CUOTAS', ltrim(to_char(v_can_tot_cuotas)), null, null) ||
                  fuj_des_campo('COD_MONEDA', ltrim(v_cod_moneda), null, null) ||
                  fuj_des_campo('TOT_CAP_INT', ltrim(to_char(v_tot_cap_int)), null, null) ||
                  fuj_des_campo('TOT_MORA_INTERES', ltrim(to_char(v_tot_mora_interes)), null, null) ||
                  fuj_des_campo('TOT_MORA', ltrim(to_char(v_tot_mora_cap)), null, null) ||
                  fuj_des_campo('TOT_PUNITORIO', ltrim(to_char(v_tot_punitorio)), null, null) ||
                  fuj_des_campo('TOT_IMPUESTO', ltrim(to_char(v_tot_impuesto)), null, null) ||
                  fuj_des_campo('TOT_CARGO_IVA', ltrim(to_char(v_tot_cargo)), null, null) ||
                  fuj_des_campo('TOT_A_COBRAR', ltrim(to_char(v_tot_a_cobrar)), null, null) ||
                  fuj_des_campo('EFECTIVO', ltrim(to_char(v_monto_efectivo)), null, 'D') ||
                  fuj_des_campo('CHQ_OBCO', ltrim(to_char(v_monto_cheque)), null, 'D') ||
                  fuj_des_campo('CHQ_NBCO', ltrim(to_char(v_monto_cheque_n)), null, 'D') ||
                  fuj_des_campo('CRE_CUENTA', ltrim(to_char(v_tot_cre_cta)), null, null) ||
                  fuj_des_campo('CRE_CTA_CON', ltrim(to_char(v_tot_cre_cta_con)), null, null) ||
                  fuj_des_campo('TIP_RETEN', ltrim(to_char(v_tip_retencion)), null, 'D');
                  
                  --
                  if nvl(v_monto_cheque,0) > 0 then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := 'ERROR: Para cobros con Cheque c/Otro Bco debe utilizar la transacción 361.';
                  end if;
                  
                  --Verificar que no se realice Cobro mixto con Cheque
                  if nvl(v_monto_cheque,0) + nvl(v_monto_cheque_n,0) > 0 and nvl(v_monto_efectivo,0) > 0 then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := 'ERROR: No se puede combinar el Cobro en Cheque c/Otro Bco. con otra forma de Cobro';
                  end if;   
                  
 /*             if NVL(P_CHQ_OBCO,0)<= 0 then -- no tiene cheque otro banco
                 v_det_campos := v_det_campos || fuj_des_campo('TIP_RETEN',null,null,'D');
              else 
                 v_det_campos := v_det_campos || fuj_des_campo('TIP_RETEN',1,null,'I');
              end if;
*//*                 if p_efectivo + nvl(p_cheque,0) <> v_total then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := 'ERROR: Total no coincide con montos detallados';
                 end if;
              end if;
*/               
           end if;     ---trans 360 normal p/actualizar
         end if;  -- sino hubo error para salida final
        end if; -- sino fue tipo cuenta 6 prestamo
      end if; -- fin de respuesta = '000'
     end if;  -- fin de select de ge_cuentas <> a 000
 end if;     -- fin de 1ra.pregunta de cuenta
 v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
 return(v_msj_salida);
exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                       v_cod_respuesta||'~'||
                       SQLERRM;
       return(v_msj_salida);
end;
/


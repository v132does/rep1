CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_102
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_COMPROBANTE IN NUMBER default null --nro de comprobante manual
-- ,P_NOMBRE IN VARCHAR2
 ,P_NRO_DOCUMENTO IN VARCHAR2 default null
 ,P_NRO_CUENTA IN VARCHAR2 default null
 ,P_EFECTIVO IN VARCHAR2 default null
 ,P_CHQ_OBCO IN VARCHAR2 default Null
 ,p_tip_retencion In Varchar2 default null
 ,P_CHQ_NBCO IN VARCHAR2 default Null
 )
 RETURN VARCHAR2
 IS

  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;                         -- modulo Caja
  v_cod_modalidad number(3) := 91;                 -- modalidad Caja
  v_cod_transaccion number(4) := 102;            -- cod de transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;
  v_lis_valores   varchar2(4000) := null;
  -- Datos de la caja
  v_fec_actual         date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hora               varchar2(8);
  v_cod_oficina        number(3);         -- Codigo de oficina
  v_estado             number(1);         -- estado de la caja
  v_fec_caja           date;              -- fecha de la caja
  v_sal_actual         number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta de prestamo
  v_denominacion       varchar2(100);     -- Nombre de la cuenta
  v_mto_cobrado        number(18,2);      -- Mto cobrado (no se despliega)
  v_tot_capital        number(18,2);      -- Capital (no se despliega )
  v_tot_interes        number(18,2);      -- Interes (no se despliega )
  v_tot_cap_int        number(18,2);      -- Capital + interes + int.adel (DESPLIEGA : importe )
  v_tot_a_cobrar       number(18,2);      -- Total a cobrar (DESPLIEGA: cap+int+morai+morac+imp+cargo)
  v_tot_cre_cta        number(18,2);      -- Total pagado contra cuenta de ahorro
  v_tot_cre_cta_con    number(18,2);      -- Total pagado contra cuenta contable

  v_tip_cuenta         number(3);         -- modalidad cta
  v_cod_moneda         varchar2(3);       -- moneda de la cta
  v_est_cuenta         varchar2(1);       -- estado de la cuenta
  v_est_docum          varchar2(1);                   

  v_nro_documento      cj_movimientos.nro_documento%type;         -- nro. documento de la cuota
  v_lov_nro_documento  ba_personas.nro_documento%type;         -- nro. documento de la cuota
  v_lov_nro_cuenta     ge_cuentas.nro_cuenta%type;
  v_lov_nombre         ba_personas.nom_completo%type;

  -- Contenedor de la lista de valores a devolver
  v_val_posibles  varchar2(3000) := null;

  v_efectivo       number(18,2) := 0;
  v_chq_obco       number(18,2) := 0;
  v_chq_nbco       number(18,2) := 0;
                   
  v_cod_tran_pend  number(4);    --- transaccion operacion pend.(efect 740 - cheq 607)
  v_monto_efectivo number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  v_monto_cheque   number(18,2) :=0; --- importe pagado operacion pendiente cheque
  v_monto_cheque_n number(18,2) :=0;
  v_tip_retencion  number(3);---ge_movimientos.cod_retencion%type;

  cursor c_cobros is 
    select cod_transaccion, monto 
     from ge_movimientos 
     where cod_tra_padre = v_cod_transaccion  
       and fecha         = v_fec_actual  
       and estado        = 'J'  
       and hora          = v_hora;
       
  cursor c_mto_cobrados is 
    select cod_transaccion, monto 
     from ge_movimientos 
     where cod_tra_padre = v_cod_transaccion  
       and fecha         = v_fec_actual  
       and hora          = v_hora;

--- para activar campo cheque nuestro banco si tiene habilitado el modulo de cta.cte.

 v_estado_modulo        ba_modulos.estado%type ;
 v_tip_dato             ge_tra_campos.tip_dato%type;

Begin
-------------------------PROCESO PRINCIPAL-------------------------
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;
 if p_nro_documento is not null and p_nro_cuenta is null then
   v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA');
   v_lis_valores   := fuj_pro_val_posibles(replace(v_val_posibles,'&NRO_DOCUMENTO',P_NRO_DOCUMENTO));
   begin
     select fuj_des_campo('NRO_CUENTA',a.nro_cuenta,v_lis_valores)
       into v_det_campos
      from md_cta_documentos a, ge_cta_clientes b, ba_personas c 
      where a.nro_cuenta = b.nro_cuenta 
      and a.cod_modulo = 10  
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
   v_can_campos := 3;
   v_det_campos :=
           '[' || 'DES_CUENTA' ||'~ ]' ||
           '[' || 'COD_MONEDA' ||'~ ]' ||
           '[' || 'TOT_A_COBRAR' ||'~ ]' ;

   -- obtengo datos de la cuenta  --
    begin
     select denominacion, cod_modulo, cod_moneda
       into v_denominacion, v_tip_cuenta, v_cod_moneda
       from ge_cuentas a
      where a.nro_cuenta = p_nro_cuenta;
     v_cod_respuesta := '000';
    exception
     when others then
       v_cod_respuesta := '003';
       v_msj_respuesta := 'ERROR: La cuenta no existe.';
    end;
    
   Begin
     /*Select estado 
       Into v_est_docum
       From md_cta_documentos
       Where nro_cuenta = p_nro_cuenta;*/
     Select estado 
       Into v_est_docum
       From Md_Cta_Documentos c
       Where c.nro_cuenta = p_nro_cuenta
         And c.Nro_Cuenta Not In
             (Select Nro_Cuenta
                From Ge_Movimientos Mov
               Where Mov.Reversado = 'N'
                 And Mov.Cod_Tra_Padre = 102
                 And (Mov.Fecha, Mov.Hora, Mov.Cod_Usuario) In
                     (Select d.Fecha, d.Hora, d.Cod_Usuario
                        From Ge_Movimientos d
                       Where d.Cod_Modulo = 10
                         And d.Estado = 'J'
                         And d.Reversado = 'N'
                         And d.Cod_Tra_Padre = 102));  
     If v_est_docum = 'N' Then
       v_cod_respuesta := '003';
       v_msj_respuesta := 'ERROR: La cuenta esta cancelada';
     End If;
   exception
     when no_data_found then
       v_cod_respuesta := '003';
       v_msj_respuesta := 'ERROR: La cuenta no existe.';
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
        v_msj_respuesta := 'Caja no esta habilitada para esta Operacion';
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
        if v_tip_cuenta <> 10 then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Tipo de cuenta no es de Mesa de Dinero ';
        else
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
                For c In c_mto_cobrados Loop
                  If c.cod_transaccion = 801 Then
                    v_tot_capital := c.monto;
                  Elsif c.cod_transaccion = 802 Then
                    v_tot_interes := c.monto;
                  End If;
                End Loop;
             else    ---  transaccion 102 normal
                v_cod_respuesta := '003';
                v_msj_respuesta := 'ERROR: No existe movimiento pendiente para esta cuenta ';
                /*v_cod_usuario := user;
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
                   pam_doc.pr_obt_mto_venta(p_nro_cuenta, v_mto_cobrado,
                                            v_tot_capital,v_tot_interes);
                end if; -- fin sino hubo error para sacar datos de cobros*/
             end if; -- fin de transaccion normal o pendiente

           ---- A PARTIR DE AQUI ES IGUAL PARA LA SALIDA DE AMBOS CASOS ---
         if v_cod_respuesta = '000' then

           v_tot_cap_int  := nvl(v_tot_capital,0) + nvl(v_tot_interes,0);

           v_tot_a_cobrar:= nvl(v_tot_cap_int,0);

           if v_hora is null then       --- transaccion 102 normal
               v_det_campos :=
                  '[' || 'DES_CUENTA' ||'~'||v_denominacion||'~ ]' ||
                  '[' || 'COD_MONEDA' ||'~'||ltrim(v_cod_moneda)||'~ ]' ||
                  '[' || 'TOT_A_COBRAR' ||'~'||ltrim(to_char(v_tot_a_cobrar))||'~ ]';
                  if p_efectivo is null then
                     v_det_campos := v_det_campos||
                       '[' || 'EFECTIVO' ||'~'||ltrim(to_char(v_tot_a_cobrar))||'~ ]';
                  else
                     v_det_campos := v_det_campos||
                       '[' || 'EFECTIVO' ||'~'||ltrim(to_char(p_efectivo))||'~ ]';
                  end if;
           else
              -- busca las operaciones pendientes para actualizar
              for reg in c_cobros Loop
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
              --- Recuperar formas de cobro
              Begin
                select nvl(sum(decode(cod_transaccion,503,nvl(monto,0),0)),0),
                       nvl(sum(decode(cod_transaccion,842,nvl(monto,0),0)),0)
                  into v_tot_cre_cta, v_tot_cre_cta_con
                  from ge_movimientos
                 where fecha = v_fec_actual
                   and hora = v_hora
                   and cod_transaccion in (503,842);
              End;
              v_det_campos :=
                '[' || 'DES_CUENTA' ||'~'||v_denominacion||'~ ]' ||
                '[' || 'COD_MONEDA' ||'~'||ltrim(v_cod_moneda)||'~ ]' ||
                '[' || 'TOT_A_COBRAR' ||'~'||ltrim(to_char(v_tot_a_cobrar))||'~ ]' ||
                '[' || 'EFECTIVO' ||'~'||ltrim(to_char(v_monto_efectivo))||'~ ]' ||
                '[' || 'CHQ_OBCO' ||'~'||ltrim(to_char(v_monto_cheque))||'~ ]' ||
                '[' || 'TIP_RETEN' ||'~'||nvl(ltrim(to_char(v_tip_retencion)),'X')||'~ ]' ||
                '[' || 'CHQ_NBCO' ||'~'||ltrim(to_char(v_monto_cheque_n))||'~ ]' ||
                '[' || 'CRE_CUENTA' ||'~'||ltrim(to_char(v_tot_cre_cta))||'~ ]' ||
                '[' || 'CRE_CTA_CON' ||'~'||ltrim(to_char(v_tot_cre_cta_con))||'~ ]';
           end if;     ---trans 102 normal p/actualizar
         end if;  -- sino hubo error para salida final
        end if; -- sino fue tipo cuenta 10 mesa de dinero
      end if; -- fin de respuesta = '000'
     end if;  -- fin de select de ge_cuentas <> a 000
  end if;     -- fin de 1ra.pregunta de cuenta
  if nvl(P_CHQ_OBCO,0) <> 0 then
     v_det_campos := v_det_campos||
                '[' || 'IMP_CHEQUE' ||'~'||ltrim(to_char(P_CHQ_OBCO))||'~ ]';
  end if;

 v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
 return(v_msj_salida);
end;
/


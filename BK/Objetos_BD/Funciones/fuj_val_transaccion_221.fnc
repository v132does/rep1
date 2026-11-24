create or replace function it.FUJ_VAL_TRANSACCION_221(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_tip_busqueda in varchar2,
      p_dat_busqueda in varchar2,
      p_nro_referencia in varchar2 default null,
      p_cod_moneda     in varchar2 default null,
      p_nro_documento  in varchar2 default null)
return LONG is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 221;    -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  v_cod_moneda  varchar2(4);
  v_cot_compra  ge_cotizaciones.val_conversion%type;
  v_cot_venta   ge_cotizaciones.val_conversion%type;
  v_monto       number(18,2);
  v_mto_equ_local number(18,2);

  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 4;        -- cantidad de campos
  v_det_campos    long ;      -- valores devueltos por defecto
                     
  --Datos anexos
  v_val_posibles varchar2(4000);
  v_det_libranzas long;
  v_cod_tra_cargo1 number(6);
  v_mon_local varchar2(5) := pag_gen.fu_obt_mon_local;
  v_mad_operacion number(5);
  v_tip_ope_cpra  varchar2(5);
  v_tip_ope_vta   varchar2(5);
  v_mto_cargo1 number(18,2);  
  v_mto_venta   number(18,2);
  v_can1        number(18);
  v_nro_referencia varchar2(20);
  v_nro_documento    lc_transferencias.nro_doc_beneficiario%type;
  v_nro_doc_benef    lc_transferencias.nro_doc_beneficiario%type;
  v_per_beneficiario lc_transferencias.cod_per_beneficiario%type;
  v_cod_persona      lc_transferencias.cod_per_beneficiario%type;
  v_redondeo_ml number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,v_mon_local);
  v_redondeo number(2):= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,null,p_cod_moneda);
  v_cta_cambios ge_cuentas.nro_cuenta%type;
  
/*recupera cta límite del cliente */
FUNCTION lf_obt_cta_cliente RETURN varchar2 IS
v_nro_cuenta lc_cta_cambios.nro_cuenta%type;
BEGIN
  SELECT B.NRO_CUENTA
    INTO v_nro_cuenta
    FROM LC_CTA_CAMBIOS B, GE_CTA_CLIENTES  A
   WHERE ESTADO in('N','A')
     AND A.NRO_CUENTA = B.NRO_CUENTA
     AND RELACION = 'P'
     AND A.COD_MODULO = 7
     AND A.COD_MODALIDAD = 70
     AND A.COD_PERSONA = v_per_beneficiario
     AND ROWNUM = 1;--en teoria debe haber un solo límite x cliente,siempre en USD
   return v_nro_cuenta;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    --recuperar par dinamico para cuenta bolsa x la oficina
    v_nro_cuenta:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina);
    return v_nro_cuenta;
  WHEN OTHERS THEN
    raise_application_error(-200800,'Al recup.Cta Límite Cliente '||v_per_beneficiario||sqlerrm);
END;

/*principal*/
begin
 if p_nro_referencia is null then
    if p_tip_busqueda is null  then
       v_cod_respuesta := '001'; -- error
       v_msj_respuesta := 'ERROR: Ingrese El tipo de Búsqueda.';
    elsif p_dat_busqueda is null then
       v_cod_respuesta := '001'; -- error
       v_msj_respuesta := 'ERROR: Ingrese El tipo de Búsqueda.';
    else
       -- se buscan los datos 
       v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'REF_EXTERNA');
       -- reemplazo el tipo y valor de busqueda
       v_val_posibles := replace(v_val_posibles,'&BUSCAR_POR' ,p_tip_busqueda);
       v_val_posibles := replace(v_val_posibles,'&DAT_BUSQUEDA',p_dat_busqueda); 
       v_det_libranzas := fuj_pro_val_posibles(v_val_posibles); 
       if v_det_libranzas = 'X' then
         -- 
         v_cod_respuesta := '002'; -- error
         v_msj_respuesta := 'ERROR: No existen datos para la condición ingresada.';         
       else
         -- se tiene lista de valores 
         v_can_campos := 1;
         v_can1 := to_number(substr(v_det_libranzas,1,instr(v_det_libranzas,'#')-1))+2;
         v_nro_referencia := substr(v_det_libranzas,instr(v_det_libranzas,'#',1,v_can1)+1,
         instr(v_det_libranzas,'#',1,v_can1+1) - instr(v_det_libranzas,'#',1,v_can1) -1);
         v_det_campos := fuj_des_campo('REF_EXTERNA', v_nro_referencia, v_det_libranzas);   
       end if;
    end if;   
 elsif p_cod_moneda is null then
    v_can_campos := 10;
    begin
      select  fuj_des_campo('NOM_BENEF',a.nom_beneficiario,null)||
              fuj_des_campo('DIR_BENEF',a.dir_beneficiario,null)||
              fuj_des_campo('TEL_BENEF',a.tel_beneficiario,null)||
              fuj_des_campo('CIU_BENEF',fue_obt_des_ciudad(a.cod_pai_beneficiario,a.cod_ciu_beneficiario),null)||
              fuj_des_campo('COD_MON',a.cod_moneda,null)||
              fuj_des_campo('IMPORTE',a.monto,null)||
              fuj_des_campo('TOT_CARGO',0,null)||
              fuj_des_campo('NRO_DOC',a.nro_doc_beneficiario,null,decode(a.nro_doc_beneficiario,null,'O','D')),
              cod_moneda, monto
         into v_det_campos, v_cod_moneda, v_monto
         from lc_transferencias a
        where nro_ref_externa = p_nro_referencia
          and cod_modalidad = 75
          and nro_cta_referencia is null --efectivo
          and estado not in ('OK','DE','AN') ;
        v_cot_compra    := pag_gen.FU_OBT_COT_COMPRA(v_cod_moneda);
        v_mto_equ_local := round(v_monto * v_cot_compra,v_redondeo_ml);
        v_det_campos := v_det_campos ||fuj_des_campo('COTIZACION',v_cot_compra,null)||
                                       fuj_des_campo('EQUIVALE',v_mto_equ_local,null);
    exception
       when no_data_found then
          v_cod_respuesta := '003'; -- 
          v_msj_respuesta := 'Transferencia no existe!!';   
          v_det_campos := fuj_des_campo('NOM_BENEF',null,null)||
                          fuj_des_campo('DIR_BENEF',null,null)||
                          fuj_des_campo('TEL_BENEF',null,null)||
                          fuj_des_campo('CIU_BENEF',null,null)||
                          fuj_des_campo('COD_MON',null,null)||
                          fuj_des_campo('IMPORTE',null,null)||
                          fuj_des_campo('COTIZACION',null,null)||
                          fuj_des_campo('EQUIVALE',null,null)||
                          fuj_des_campo('TOT_CARGO',null,null)||
                          fuj_des_campo('NRO_DOC',null,null); 
       when others then
          v_cod_respuesta := '004'; -- 
          v_msj_respuesta := 'Transferencia con problemas '||sqlerrm;     
    end;        
 else
    begin
      select  cod_moneda, monto, nro_doc_beneficiario, cod_per_beneficiario
         into v_cod_moneda, v_monto, v_nro_documento, v_per_beneficiario
         from lc_transferencias a
        where nro_ref_externa = p_nro_referencia
          and cod_modalidad = 75
          and nro_cta_referencia is null --efectivo          
          and estado not in ('OK','DE','AN') ;
        v_cot_compra    := pag_gen.FU_OBT_COT_COMPRA(v_cod_moneda);
        v_mto_equ_local := round(v_monto * v_cot_compra,v_redondeo_ml); 
    exception
       when no_data_found then
          v_cod_respuesta := '004'; -- 
          v_msj_respuesta := 'Transferencia con problemas '||sqlerrm; 
    end;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          p_cod_moneda,
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
          v_msj_respuesta := 'Caja no fue habilitada el día de hoy';                
       end if;
    end if; 
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja                          
      -- cargo
      --recuperar cotización
      v_cot_compra    := pag_gen.FU_OBT_COT_COMPRA(v_cod_moneda);
      v_mto_equ_local := round(v_monto * v_cot_compra,v_redondeo_ml);
      --ver qué operación hacer de acuerdo a la moneda
      if p_cod_moneda = v_mon_local  then
        --compra
        v_tip_ope_cpra := 34; --compra de transferencia
        v_mad_operacion := 71;
        v_cot_venta     := 1;
      else
        if p_cod_moneda <> v_cod_moneda then
           --arbitraje
           v_tip_ope_cpra := 59; --arbitraje -compra transferencia
           v_tip_ope_vta  := 45; --arbitraje -venta dep.en cuenta m/e
           v_mad_operacion := 73;
           v_cot_venta := pal_cam.FU_OBT_COT_VENTA(p_cod_moneda);         
        else
           --canje
           v_tip_ope_cpra := 89; --canje -compra transferencia
           v_tip_ope_vta  := 75; --canje -venta dep.en cuenta m/e
           v_mad_operacion := 74;
           v_cot_venta := v_cot_compra;
        end if;
      end if;

      --recuperar los datos de la operación, de compra debe haber
      begin
        select  cod_tra_cargo1
          into  v_cod_tra_cargo1
          from lc_tip_ope_oficinas b, lc_tip_operaciones a
         where b.cod_tip_operacion = a.cod_tip_operacion
           and b.cod_moneda = v_cod_moneda --moneda de la transf
           and b.cod_oficina = v_cod_oficina --oficina del usuario
           and a.cod_tip_operacion = v_tip_ope_cpra --operación compra
           and nivel = 1;
      exception
         when no_data_found then
            raise_application_error(-20007,'Tipo de Operacion invalido. '||v_tip_ope_cpra);
      end;
      --recup. cargo 1
      if v_cod_tra_cargo1 is not null then
        declare
           v_des_cargo varchar2(200);
           v_cod_tasa1 number;
           v_val_tasa1 number;
        begin
	        --obtiene cta de cambios del cliente
          v_cta_cambios := lf_obt_cta_cliente;
          --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
          if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina) 
           or v_per_beneficiario is null then
            pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_mto_equ_local, 
                                 v_cod_oficina, v_cta_cambios, null, v_des_cargo, v_mto_cargo1, v_cod_tasa1, v_val_tasa1);
          elsif v_per_beneficiario is not null then
             pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_mad_operacion, v_cod_moneda, v_monto, v_mto_equ_local, 
                                   v_cod_oficina, null, v_per_beneficiario, v_des_cargo, v_mto_cargo1, v_cod_tasa1, v_val_tasa1);
          end if;        
        exception
           when others then
              raise_application_error(-20008,'Recup.Cargo. Oper. '||v_tip_ope_cpra||' - Trans.'||v_cod_tra_cargo1);
        end;
      end if;
      v_mto_cargo1 := nvl(v_mto_cargo1,0);
      v_mto_venta  := round((v_mto_equ_local - v_mto_cargo1) / v_cot_venta,v_redondeo);
      -- 
      v_det_campos := v_det_campos ||fuj_des_campo('TOT_CARGO',v_mto_cargo1,null)||
                                     fuj_des_campo('IMP_VENTA',v_mto_venta,null)||
                                     fuj_des_campo('COT_VENTA',v_cot_venta,null)||
                                     fuj_des_campo('TOTAL_GS',(v_mto_equ_local - v_mto_cargo1),null);    
   end if;
   --validar nro documento
   if v_nro_documento is not null then
      --poner como display
      v_det_campos := v_det_campos || fuj_des_campo('NRO_DOC',v_nro_documento,null,'D');--
   else
      v_det_campos := v_det_campos || fuj_des_campo('NRO_DOC',p_nro_documento,null,'O');
      if p_nro_documento is not null and v_per_beneficiario is not null then --si tiene beneficiario registrado
         begin
            --verificar que sea de la persona
            select nro_documento
              into v_nro_doc_benef
              from ba_personas
             where cod_persona = v_per_beneficiario;
            if v_nro_doc_benef <> p_nro_documento then
              v_cod_respuesta := '012';
              v_msj_respuesta := 'Nro. de CI no corresponde al Beneficiario';
            end if;                
         exception
            when no_data_found then
              v_cod_respuesta := '013';
              v_msj_respuesta := 'Persona inexistente con el Nro. de CI.';
            when too_many_rows then            
              v_cod_respuesta := '014';
              v_msj_respuesta := 'Varias personas con el mismo Nro. de CI.';
            when others then
              v_cod_respuesta := '015';
              v_msj_respuesta := 'Recup. Beneficiario '||sqlerrm;
         end;
      end if;
   end if;
 end if;         
 v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
 return(v_msj_salida);
end FUJ_VAL_TRANSACCION_221;
/


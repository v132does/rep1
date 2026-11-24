CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_245 (
      p_nro_operacion     in varchar2,     -- Nro de referencia de la operacion
      p_nro_caja          in varchar2,          -- Nro de Caja
      --p_nro_comprobante   in number default null, --nro de comprobante manual
      p_cod_tip_operacion in number,   -- codigo del tipo de operacion
      --p_cod_ope_bcp       in varchar2 default null,  -- codigo bcp
      p_nro_documento     in varchar2 default null,  -- nro de documento
      p_nombre            in varchar2 default null,  --nombre de la persona
      p_apellido          in varchar2 default null,  --apellido de la persona
      p_tip_documento     in varchar2 default null,  --tip_documento
      p_pai_documento     in varchar2 default null,  --pais documento
      p_cod_moneda        in varchar2 default null,  -- moneda
      p_importe           in number   default null,  -- importe de la operacion
      p_cotizacion        in number   default null,  -- cotización
      p_efectivo          in number   default null,  --mto efectivo
      p_tip_retencion     in number default null,    --retención
      p_cheque            in number default -2,      --mto cheque
      --agregado cheq nstro bco
      p_nro_che_ntro      in varchar2 default null,  --nro cheq ntro bco
      p_che_ntro_bco      in number default -2,      --mto cheq ntro bco
      --agregado para credito en cuenta
      p_cta_credito       in varchar2 default null,  --cta crédito
      p_mto_cuenta        in number default -2,      --mto cta crédito
      p_cta_cliente       in varchar2 default null,
      -- Agregado para detalle de cheques, si es uno solo,(de despliegue x defecto)
      p_cod_banco         in varchar2 DEFAULT NULL,  -- código del banco
      p_nro_cheque        in varchar2 DEFAULT NULL)  -- número de cheque

return VARCHAR2 is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 245;    -- transacción de operación de cambios 
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Código de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  v_cod_moneda varchar2(3);
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(500) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 3;        -- cantidad de campos
  v_det_campos    varchar2(4000) :=      -- valores devueltos por defecto
           '[' || 'DES_OPERA' ||'~ ]' ||
           '[' || 'COD_BCP'   ||'~ ]';
  v_val_posibles  varchar2(1000);
  --Datos de la operacion
  v_cod_tip_ope_bcp      lc_tip_operaciones.cod_tip_ope_bcp%type;
  v_afe_posicion         lc_tip_operaciones.afe_posicion%type;
  v_afe_limite           lc_tip_operaciones.afe_limite%type;
  v_afe_che_viajero      lc_tip_operaciones.afe_che_viajero%type;
  v_afe_transferencia    lc_tip_operaciones.afe_transferencia%type;
  v_caja                 lc_tip_operaciones.caja%type;
  v_tip_valor            lc_tip_operaciones.tip_valor%type;
  v_cod_mod_origen       lc_tip_operaciones.cod_mod_origen%type;
  v_cod_mod_operacion    lc_tip_operaciones.cod_modulo%type;
  v_cod_mad_operacion    lc_tip_operaciones.cod_modalidad%type;
  v_cod_tra_operacion    lc_tip_operaciones.cod_transaccion%type;
  v_cod_mad_hijo         lc_tip_operaciones.cod_mad_hijo%type;
  v_afe_cod_transaccion  lc_tip_operaciones.afe_cod_transaccion%type;
  v_cod_tra_cargo1       lc_tip_operaciones.cod_tra_cargo1%type;
  v_cod_tra_cargo2       lc_tip_operaciones.cod_tra_cargo2%type;
  v_cod_tra_cargo3       lc_tip_operaciones.cod_tra_cargo3%type;
  v_existe               varchar2(1);
  v_cotizacion           ge_cotizaciones.val_conversion%type;
  v_equivalente          number;
  v_mto_cargo1           number;
  v_mto_cargo2           number;
  v_mto_cargo3           number;
  v_total                number;
  v_cod_tasa             number;
  v_val_tasa             number;
  v_des_cargo            ge_transacciones.descripcion%type;
  v_tip_documento   ba_personas.cod_tip_documento%type;
  v_cod_pais     ba_personas.cod_pais%type;
  v_nombre       ba_personas.nom_completo%type;
  v_apellido     ba_personas.nom_completo%type;
  v_tipo         ba_personas.tipo%type;
  v_fec_nacimiento date;
  v_error varchar2(2000);
  v_tip_implementacion number := fug_obt_tip_implementacion;
  v_redondeo_ml   number(05);
  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;

  v_cod_persona  ba_personas.cod_persona%type;
  v_cta_cambios ge_cuentas.nro_cuenta%type;
   /*CROCLIJUD-5*/
  --v_cod_persona        ba_personas.cod_persona%type;
  v_cod_cau_judicial	 ge_causales.cod_causa%type := fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL');
  v_cliente varchar2(1) := 'N'; 
  v_abr_tip_doc ba_tip_documentos.abreviatura%type;
  v_abr_cod_pai_iso ba_paises.cod_pai_iso%type;
  v_tip_persona ba_personas.tipo%type;
  v_mto_max_ope ge_movimientos.monto%type := fug_obt_pardinamico('MTO_MAX_OPE_CAM_NO_CLIENTE');
  v_tip_doc_persona ba_personas.cod_tip_documento%type;
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
     AND A.COD_PERSONA = v_cod_persona
     AND ROWNUM = 1;--en teoria debe haber un solo límite x cliente,siempre en USD
   return v_nro_cuenta;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    --recuperar par dinamico para cuenta bolsa x la oficina
    v_nro_cuenta:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina);
    return v_nro_cuenta;
  WHEN OTHERS THEN
    raise_application_error(-200800,'Al recup.Cta Límite Cliente '||v_cod_persona||sqlerrm);
END;

begin
  if p_cod_tip_operacion is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Tipo de operacion a realizar.';
  else
    if p_cotizacion is not null then
       if p_nro_documento is null or p_importe is null or p_cod_moneda is null then
          v_cod_respuesta := '002';
          v_msj_respuesta := 'Faltan datos';
       end if;
    end if;
    if p_cotizacion is not null then
       if p_importe is null or p_cod_moneda is null then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'Faltan datos';
       end if;
    end if;
    if p_importe is not null  then
       if p_cod_moneda is null then
          v_cod_respuesta := '004';
          v_msj_respuesta := 'Faltan datos';
       end if;
    end if;
    -- Obtengo los datos de la caja x moneda local------------------
    prj_obt_datos_caja(p_nro_caja,
                       pag_gen.fu_obt_mon_local,
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
      v_msj_respuesta := 'Caja no esta habilitada para esta Operacion en '||pag_gen.fu_obt_mon_local;
    elsif v_fec_caja <> v_fec_actual then
      v_cod_respuesta := '005'; -- error
      v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
    end if;
    if v_cod_respuesta = '000' then
       --recuperar los datos de la operacion
       begin
         select fuj_des_campo('DES_OPERA',a.descripcion)||fuj_des_campo('COD_BCP',a.cod_tip_ope_bcp),
                a.cod_tip_ope_bcp,
                afe_posicion, afe_limite, afe_che_viajero, afe_transferencia,
                caja, tip_valor, cod_mod_origen, cod_modulo, cod_modalidad,
                cod_transaccion, cod_mad_hijo, afe_cod_transaccion,
                cod_tra_cargo1, cod_tra_cargo2, cod_tra_cargo3
           into v_det_campos,
                v_cod_tip_ope_bcp,
                v_afe_posicion, v_afe_limite, v_afe_che_viajero, v_afe_transferencia,
                v_caja, v_tip_valor, v_cod_mod_origen, v_cod_mod_operacion, v_cod_mad_operacion,
                v_cod_tra_operacion, v_cod_mad_hijo, v_afe_cod_transaccion,
                v_cod_tra_cargo1, v_cod_tra_cargo2, v_cod_tra_cargo3
           from lc_tip_operaciones a
          where cod_tip_operacion = p_cod_tip_operacion
            and cod_tip_operacion in (11,26,18,30)--compra y vta efectivo, compra cheque,venta cuenta
            and FUG_VER_USU_PERMISO(user,cod_modulo,cod_modalidad,cod_transaccion)='S'
            and nivel = 1
            and cod_modalidad in (71,72);

            v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_mad_operacion,v_cod_mon_local);
            
            v_det_campos := v_det_campos ||
                              fuj_des_campo('TIP_DOCUMENTO',null,null,'D')||
                              fuj_des_campo('PAI_DOCUMENTO',null,null,'D');
                              
            --habilitar o deshabilitar los campos de cheque y banco sólo para compra de cheques
            if v_cod_mad_operacion = 71 then
              --apagar campos
              v_det_campos := v_det_campos ||
                               fuj_des_campo('CTA_CLIENTE',null,null,'D')||
                               fuj_des_campo('COD_MONEDA',p_cod_moneda,null,'O')||
                               fuj_des_campo('TIP_RETEN',null,null,'D')||
                               fuj_des_campo('CHEQUE',null,null,'D')||
                               fuj_des_campo('CHEQ_NTRO',null,null,'D')||
                               fuj_des_campo('NRO_CHE_NTRO',null,null,'D')||
                               fuj_des_campo('CTA_CREDITO',p_cta_credito,null,'I');
               --xq tiene valor negativo default
               if nvl(p_mto_cuenta,0) <= 0 then
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('MTO_CTA',null,null,'I');
               else
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('MTO_CTA',p_mto_cuenta,null,'I');
               end if;

              if p_cod_tip_operacion <> 18 then --si no es compra cheque, apagar
                 v_det_campos := v_det_campos ||
                                 fuj_des_campo('COD_BANCO',null,null,'D')||
                                 fuj_des_campo('NRO_CHEQ',null,null,'D');
              else
                 --solo si no cargo
                 if nvl(p_cod_banco,0) <= 0 then
                    v_det_campos := v_det_campos ||
                                    fuj_des_campo('COD_BANCO',null,null,'I')||
                                    fuj_des_campo('NRO_CHEQ',null,null,'I');
                 end if;
              end if;
            else--venta, solo si tiene imp en cheque permitir ingresar
               --apagar cta credito
               v_det_campos := v_det_campos || fuj_des_campo('CTA_CREDITO',null,null,'D')||
                                 fuj_des_campo('MTO_CTA',NULL,null,'D');
               if p_cod_tip_operacion = 30 then --habilitar cta
                      v_det_campos := v_det_campos ||
                                       fuj_des_campo('CTA_CLIENTE',p_cta_cliente,null,'O');                   
               else
                  v_det_campos := v_det_campos ||
                                   fuj_des_campo('CTA_CLIENTE',null,null,'D');
               end if;
               --prender los campos
               --si no cargo nada mostrar null,sino mantener lo q cargo
               if nvl(p_tip_retencion,0) <= 0 then
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('TIP_RETEN',null,null,'I');
               else
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('TIP_RETEN',p_tip_retencion,null,'I');
               end if;
               if nvl(p_cheque,0) <= 0 then
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('CHEQUE',null,null,'I');
               else
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('CHEQUE',p_cheque,null,'I');
               end if;
               if nvl(p_che_ntro_bco,0) <= 0 then
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('CHEQ_NTRO',null,null,'I');
               else
                  v_det_campos := v_det_campos ||
                                  fuj_des_campo('CHEQ_NTRO',p_che_ntro_bco,null,'I');
               end if;

               --si no tiene importes en cheque limpiar
               if nvl(p_cheque,0) <= 0 then
                 v_det_campos := v_det_campos ||
                       fuj_des_campo('COD_BANCO',null,null,'D')||
                       fuj_des_campo('NRO_CHEQ',null,null,'D');
               else
                 --si ya no cargó banco
                 if p_cod_banco is null then
                   v_det_campos := v_det_campos ||
                         fuj_des_campo('COD_BANCO',null,null,'I')||
                         fuj_des_campo('NRO_CHEQ',null,null,'I');
                 else
                   v_det_campos := v_det_campos ||
                       fuj_des_campo('COD_BANCO',p_cod_banco,null,'I')||
                       fuj_des_campo('NRO_CHEQ',p_nro_cheque,null,'I');
                 end if;
               end if;
            end if;

       exception
         when no_data_found then
           v_cod_respuesta := '007';
           v_msj_respuesta := 'Tipo de Operacion no valido.';
       end;
    end if;

    -- verifico el nro_documento
    if v_cod_respuesta = '000' then
       if p_nro_documento is not null then
           begin
              select cod_persona,TIPO,cod_pais,cod_tip_documento
                into v_cod_persona,v_tip_persona,v_cod_pais,v_tip_doc_persona
                from ba_personas
               where nro_documento = p_nro_documento;
               if v_tip_persona = 'F' then
                   select v_det_campos ||fuj_des_campo('NOMBRE',substr((PRI_NOMBRE||' '||SEG_NOMBRE),1,100),' ')
                                       ||fuj_des_campo('APELLIDO',substr((PRI_APELLIDO||' '||SEG_APELLIDO),1,100),' ')
                    into v_det_campos 
                    from ba_per_fisicas
                   where cod_persona = v_cod_persona;
               else
                 select v_det_campos ||fuj_des_campo('NOMBRE',substr(raz_social,1,100),' ')
                                     ||fuj_des_campo('APELLIDO',substr(nom_comercial,1,100),' ')
                    into v_det_campos 
                    from ba_per_juridicas
                   where cod_persona = v_cod_persona;
               end if;
              Begin
                select v_det_campos ||fuj_des_campo('TIP_DOCUMENTO',t.abreviatura)
                  into v_det_campos
                  from ba_per_documentos p, ba_tip_documentos t
                 where p.cod_persona = v_cod_persona
                   and p.cod_tip_documento = t.cod_tip_documento;
                 Exception when no_data_found then
                    v_det_campos:= v_det_campos ||fuj_des_campo('TIP_DOCUMENTO','OTR');
                    when too_many_rows then
                      begin
                          select v_det_campos ||fuj_des_campo('TIP_DOCUMENTO',t.abreviatura)
                            into v_det_campos
                            from ba_per_documentos p, ba_tip_documentos t
                           where p.cod_persona = v_cod_persona
                             and p.cod_tip_documento = t.cod_tip_documento
                             and p.cod_tip_documento = v_tip_doc_persona;
                          exception
                             when others then  
                                  v_det_campos:= v_det_campos ||fuj_des_campo('TIP_DOCUMENTO','OTR');                               
                      end;  
              End;
              Begin   
                select v_det_campos ||fuj_des_campo('PAI_DOCUMENTO',t.cod_pai_iso)
                  into v_det_campos
                  from ba_paises t
                 where t.cod_pais = v_cod_pais;              
               Exception when no_data_found then
                    v_det_campos:= v_det_campos ||fuj_des_campo('PAI_DOCUMENTO','OTR');     
              End;  
           exception
              when too_many_rows then
                v_cod_respuesta := '016';
                v_msj_respuesta := 'Varias Personas con igual nro.documento '||p_nro_documento;
              when no_data_found then
               
            if v_cod_persona is null  then --Si no está en la tabla ba_personas busco en la base del BCP 
               PRL_OBT_DAT_PER_BCP(p_nro_documento, v_tip_documento, v_cod_pais,
                                   v_nombre,v_apellido, v_error,v_abr_tip_doc,v_abr_cod_pai_iso);                     
               if v_nombre is not null and v_apellido is not null then 
                  v_det_campos := v_det_campos ||fuj_des_campo('NOMBRE',substr(v_nombre,1,100),' ');                    
                  v_det_campos := v_det_campos ||fuj_des_campo('APELLIDO',substr(v_apellido,1,100),' ');
                  v_det_campos := v_det_campos ||fuj_des_campo('TIP_DOCUMENTO',v_abr_tip_doc);                    
                  v_det_campos := v_det_campos ||fuj_des_campo('PAI_DOCUMENTO',v_abr_cod_pai_iso); 
                 /*Insertar en ba_personas*/
                 PRL_INS_PER_NO_CLIENTE(p_nro_documento,v_tip_documento,v_cod_pais,
                                        v_nombre,v_apellido,'F',v_cod_persona);                                        
               end if;                 
             if v_error = 'Inexistente' then
                   v_det_campos := v_det_campos ||                               
                               fuj_des_campo('TIP_DOCUMENTO',P_TIP_DOCUMENTO,NULL,'O')||
                               fuj_des_campo('PAI_DOCUMENTO',P_PAI_DOCUMENTO,NULL,'O');      
               end if; 
          
            end if;   
            
            /*--si no existe en ba_personas buscar en la base del BCP
            prl_obt_per_bdbcp(p_nro_documento, v_tip_documento, v_cod_pais, v_nombre,
                            v_apellido, v_tipo, v_fec_nacimiento, v_error);
                if v_error is not null then
                    v_cod_respuesta := '017';
                   v_msj_respuesta := v_error;
                else -- si no retorna msj de error ni nombre -> no existe la persona
                   if p_nombre is null then -- x si ya cargo, para q no reescriba
                      v_det_campos := v_det_campos || fuj_des_campo('NOMBRE',substr(v_nombre||' '||v_apellido,1,100),' ');
                   end if;
                   if v_nombre is null then -- no existe en bcp
                      if pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,pag_gen.fu_obt_mon_fuerte,p_IMPORTE) >
                          fug_obt_pardinamico('MTO_MIN_CAM_DOCUMENTO',7,v_cod_mad_operacion,null,null) then
                         v_cod_respuesta := '017';
                         v_msj_respuesta := 'No existe Persona con el nro.documento '||p_nro_documento||'. Ingrese una persona existente.';
                      else
                         if p_nombre is null then
                            v_det_campos := v_det_campos||'5';--para q vaya al campo nombre
                             v_cod_respuesta := '018';
                            v_msj_respuesta := 'ERROR: Ingrese el Nombre de la Persona';
                         end if;
                      end if;
                   end if;
                end if;*/               
           end;
           
           if v_cod_persona is not null then 
              v_cliente := fug_es_cliente(v_cod_persona);
           end if;   
           
           DECLARE
             v_exist varchar2(1) := 'N';
           BEGIN
             begin
              select 'S'
                into v_exist
                from ba_usuarios a
               where a.cod_usuario = user
                 and a.cod_persona = v_cod_persona;
              exception
                when no_data_found then
                  v_exist := 'N';
             end;
             if v_exist = 'S' then
               v_cod_respuesta := '018';
               v_msj_respuesta := 'No puede cargar una operacion para UD. mismo.';
             end if;
           END;   
       end if;
    end if;--v_cod_respuesta
    if v_cod_respuesta = '000' then
    ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
     v_cod_persona := fue_obt_cod_persona(p_nro_documento);
       if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona) Then
           v_cod_respuesta := '009';
           v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico';
       end If;
    end if;

    --moneda
    if v_cod_respuesta = '000' then
      if p_cod_moneda is null then
         v_val_posibles := fuj_obt_val_posibles(v_cod_transaccion,'COD_MONEDA');
         v_det_campos := v_det_campos||fuj_des_campo('COD_MONEDA',pag_gen.fu_obt_mon_fuerte,
                          fuj_pro_val_posibles(replace(v_val_posibles,'',p_cod_tip_operacion)));
      else -- validar la moneda
         -- Obtengo los datos de la caja ---------------------------------------
         prj_obt_datos_caja(p_nro_caja,
                             p_cod_moneda,
                             v_cod_oficina,
                             v_fec_caja,
                             v_estado,
                             v_sal_actual,
                             v_sal_cheques);
         if v_estado = -1 then
           v_cod_respuesta := '009'; -- error, no existe registro de caja
           v_msj_respuesta := 'Caja inexistente!!';
         elsif v_estado in (0,2) then
           v_cod_respuesta := '010'; -- error
           v_msj_respuesta := 'Caja no esta habilitada para esta Operacion en '||p_cod_moneda||'.'||p_importe||'.'||p_nombre;
         elsif v_fec_caja <> v_fec_actual then
           v_cod_respuesta := '011'; -- error
           v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
         end if;
         --verificar comprobante
/*         if v_cod_respuesta = '000' then
           If p_nro_comprobante is not null then
             -- Verifico la duplicacion del registro
             prj_val_duplicacion(p_nro_caja,
                                 v_cod_transaccion,
                                 p_cod_moneda,
                                 p_nro_comprobante,
                                 v_cod_respuesta,
                                 v_msj_respuesta);
           End if;
         end if;*/
         if v_cod_respuesta = '000' then
            -- valido el tipo de operacion en la moneda y la oficina
            begin
               select 's'
                 into v_existe
                 from lc_tip_ope_oficinas
                where cod_tip_operacion = p_cod_tip_operacion
                  and cod_oficina = v_cod_oficina
                  and cod_moneda = p_cod_moneda;
            exception
               when no_data_found then
                 v_cod_respuesta := '012';
                 v_msj_respuesta := 'Moneda invalida para Operacion y Oficina';
            end;
         end if;
         -- busco la cotizacion por defecto
         if v_cod_respuesta = '000' then
            if v_cod_mad_operacion = 71 then --compra
               v_cotizacion := pal_cam.FU_OBT_COT_COMPRA(p_cod_moneda);
            elsif v_cod_mad_operacion = 72 then --venta
              v_cotizacion := pal_cam.FU_OBT_COT_VENTA(p_cod_moneda);
            else
               v_cod_respuesta := '013';
               v_msj_respuesta := 'Modalidad '||v_cod_mad_operacion||' no permitida.';
            end if;
            if v_cod_respuesta = '000' then
               if p_cotizacion is null then
                  if v_cod_mad_operacion = 71 then
                     v_det_campos := v_det_campos ||fuj_des_campo('COTIZACION',v_cotizacion,' ');
                  elsif v_cod_mad_operacion = 72 then
                     v_det_campos := v_det_campos ||fuj_des_campo('COTIZACION',v_cotizacion,' ');
                  end if;
               end if;
            end if;
         end if;

         -- verifico si ya introdujo el importe
         if v_cod_respuesta = '000' then
            if p_importe is not null  then
               -- valido el importe
               if p_importe <= 0 then
                  v_cod_respuesta := '015';
                  v_msj_respuesta := 'Importe debe ser mayor a cero';
               end if;
               If v_cliente = 'N' then
                  if pal_cam.FU_CON_MON_A_MONEDA(p_cod_moneda,pag_gen.fu_obt_mon_fuerte,p_IMPORTE) > v_mto_max_ope then
                     v_cod_respuesta := '015';
                     v_msj_respuesta := 'Monto supera para Opereación de No Cliente';
                  end if;
               End if;   
               --muestra los cargos
               if v_cod_respuesta = '000' then
                  v_equivalente :=round(P_IMPORTE * P_COTIZACION,v_redondeo_ml);
                  v_det_campos := v_det_campos ||fuj_des_campo('EQUIVALE',v_equivalente,' ');
                   --obtiene cta de cambios del cliente
                  v_cta_cambios := lf_obt_cta_cliente;

                  -----cargo 1
                  if v_cod_tra_cargo1 is not null then
                     begin
                       --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
                       if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
                        or v_cod_persona is null then
                          pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, p_cod_moneda,
                               p_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null, v_des_cargo,
                               v_mto_cargo1, v_cod_tasa, v_val_tasa);
                      elsif v_cod_persona is not null then
                          pal_cam.pr_obt_cargos(v_cod_tra_cargo1, v_cod_mad_operacion, p_cod_moneda,
                               p_importe, v_equivalente, v_cod_oficina, null, v_cod_persona, v_des_cargo,
                               v_mto_cargo1, v_cod_tasa, v_val_tasa);
                      end if;
                        if v_mto_cargo1 is not null then
                           v_det_campos := v_det_campos ||fuj_des_campo('CARGO1',v_des_cargo,' ');
                           v_det_campos := v_det_campos ||fuj_des_campo('TOT_CAR1',round(v_mto_cargo1,v_redondeo_ml),' ');
                        end if;

                     exception
                        when others then
                           v_cod_respuesta := '016';
                           v_msj_respuesta := 'Error Cargos1 '||substr(sqlerrm,1,400);
                     end;
                  end if;
                  if v_cod_respuesta = '000' then
                     --cargo 2
                     if v_cod_tra_cargo2 is not null then
                        begin
                           --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
                           if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
                            or v_cod_persona is null then
                               pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_cod_mad_operacion, p_cod_moneda,
                                    p_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa, v_val_tasa);
                           elsif v_cod_persona is not null then
                               pal_cam.pr_obt_cargos(v_cod_tra_cargo2, v_cod_mad_operacion, p_cod_moneda,
                                    p_importe, v_equivalente, v_cod_oficina, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo2, v_cod_tasa, v_val_tasa);
                           end if;
                           if v_mto_cargo2 is not null then
                              v_det_campos := v_det_campos ||fuj_des_campo('CARGO2',v_des_cargo,' ');
                              v_det_campos := v_det_campos ||fuj_des_campo('TOT_CAR2',round(v_mto_cargo2,v_redondeo_ml),' ');
                           end if;
                        exception
                           when others then
                              v_cod_respuesta := '017';
                              v_msj_respuesta := 'Error Cargos2 '||substr(sqlerrm,1,400);
                        end;
                     end if;
                  end if;
                  if v_cod_respuesta = '000' then
                     --cargo 3
                     if v_cod_tra_cargo3 is not null then
                        begin
                           --si la cta de cambios no es la bolsa y no tiene persona identificada, llamar x nro cuenta, sino x persona
                           if v_cta_cambios <> fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina)
                            or v_cod_persona is null then
                               pal_cam.pr_obt_cargos(v_cod_tra_cargo3, v_cod_mad_operacion, p_cod_moneda,
                                    p_importe, v_equivalente, v_cod_oficina, v_cta_cambios, null, v_des_cargo,
                                    v_mto_cargo3, v_cod_tasa, v_val_tasa);
                           elsif v_cod_persona is not null then
                               pal_cam.pr_obt_cargos(v_cod_tra_cargo3, v_cod_mad_operacion, p_cod_moneda,
                                    p_importe, v_equivalente, v_cod_oficina, null, v_cod_persona, v_des_cargo,
                                    v_mto_cargo3, v_cod_tasa, v_val_tasa);
                           end if;
                           if v_mto_cargo3 is not null then
                              v_det_campos := v_det_campos ||fuj_des_campo('CARGO3',v_des_cargo,' ');
                              v_det_campos := v_det_campos ||fuj_des_campo('TOT_CAR3',round(v_mto_cargo3,v_redondeo_ml),' ');
                           end if;
                        exception
                           when others then
                              v_cod_respuesta := '018';
                              v_msj_respuesta := 'Error Cargos3 '||substr(sqlerrm,1,400);
                        end;
                     end if;
                  end if;
                  -----hasta aqui cargos
                  --si es compra se restan los cargos, si es venta se suman
                  if v_cod_respuesta = '000' then
                     v_mto_cargo1 := nvl(round(v_mto_cargo1,v_redondeo_ml),0) + nvl(round(v_mto_cargo2,v_redondeo_ml),0) + nvl(round(v_mto_cargo3,v_redondeo_ml),0);
                     if v_cod_mad_operacion = 71 then
                        v_total := nvl(v_equivalente,0) - nvl(v_mto_cargo1,0);
                     elsif v_cod_mad_operacion = 72 then
                        v_total := nvl(v_equivalente,0) + nvl(v_mto_cargo1,0);
                     end if;
                     v_det_campos := v_det_campos ||fuj_des_campo('TOTAL',v_total,' ');
                     IF p_efectivo is null then
                        v_det_campos := v_det_campos ||fuj_des_campo('EFECTIVO',v_total,' ');
                     end if;
                     --sólo en venta controlar los montos, si es compra de cheque no se ingresa monto,
                     --el monto es el de la operación
                     if v_cod_mad_operacion = 72 then
                         if p_efectivo = v_total then -- ya se completo en efectivo
                            v_det_campos := v_det_campos ||
                                  fuj_des_campo('COD_BANCO',null,null,'D')||
                                  fuj_des_campo('NRO_CHEQ',null,null,'D');--||
                            if nvl(p_che_ntro_bco,0) > 0 or nvl(p_cheque,0) > 0 then
                                v_cod_respuesta := '016';
                                v_msj_respuesta := 'ERROR: Total no coincide con montos detallados';
                            end if;
                         ELSE
                           if nvl(p_cheque,0) > 0 and nvl(p_tip_retencion,0) =0 then
                              v_det_campos := v_det_campos||'13';--para q vaya al campo retención
                              v_cod_respuesta := '007';
                              v_msj_respuesta := 'Ingrese Retencion o Tipo de Cheque';
                           elsif nvl(p_tip_retencion,0) > 0 and nvl(p_cheque,0) =0 then--si es = 0 paso x aca
                              v_det_campos := v_det_campos||'14';--para q vaya al campo cheque
                              v_cod_respuesta := '007';
                              v_msj_respuesta := 'Ingrese Monto del Cheque';
                           end if;
                           --NO ES OBLIGATORIO EL NRO DE CHEQUE,PUEDE DETALLAR DESPUES
                           /*if nvl(p_che_ntro_bco,0) > 0 and nvl(p_nro_che_ntro,0) =0 then
                              v_det_campos := v_det_campos||'13';--para q vaya al campo retencion
                              v_cod_respuesta := '007';
                              v_msj_respuesta := 'Ingrese Nro. de cheque';
                           elsif nvl(p_nro_che_ntro,0) > 0 and nvl(p_che_ntro_bco,0) =0 then--si es = 0 paso x aca
                              v_det_campos := v_det_campos||'14';--para q vaya al campo cheque
                              v_cod_respuesta := '007';
                              v_msj_respuesta := 'Ingrese Monto del Cheque';
                           end if;*/
                         end if;


                         if nvl(p_cheque,0) > 0 and nvl(p_che_ntro_bco,0) > 0 and nvl(p_efectivo,0) > 0 then
                            if p_efectivo + nvl(p_cheque,0) + nvl(p_che_ntro_bco,0) <> v_total then
                                v_cod_respuesta := '015';
                                v_msj_respuesta := 'ERROR: Total no coincide con montos detallados';
                            end if;
                         end if;
                         --no puede tener crédito en cta
                         if nvl(p_mto_cuenta,0) > 0 then
                           --nular crédito en cta
                           v_det_campos := v_det_campos ||fuj_des_campo('CTA_CREDITO',null,null,'D')||
                                           fuj_des_campo('MTO_CTA',null,null,'D');
                           v_cod_respuesta := '016';
                           v_msj_respuesta := 'ERROR: La operacion no permite credito en cuenta';
                         end if;
                     else-- si es compra no detallar montos en cheque
                        --validar el efectivo + crédito en cta si hubiera
                        if nvl(p_efectivo,0) > v_total then -- debe igualar al efectivo
                           v_det_campos := v_det_campos ||
                              fuj_des_campo('COD_BANCO',null,null,'D')||
                              fuj_des_campo('NRO_CHEQ',null,null,'D');--||
                           v_cod_respuesta := '019';
                           v_msj_respuesta := 'Total Efectivo supera el Total de la operacion';
                        end if;

                        if nvl(p_mto_cuenta,0) > 0 and nvl(p_cta_credito,0) =0 then
                           v_det_campos := v_det_campos||'17';--para q vaya al campo cuenta
                           v_cod_respuesta := '016';
                           v_msj_respuesta := 'Ingrese Cuenta de Credito';
                        elsif nvl(p_cta_credito,0) > 0 and nvl(p_mto_cuenta,0) =0 then--si es = 0 paso x aca
                           v_det_campos := v_det_campos||'18';--para q vaya al campo monto cta
                           v_cod_respuesta := '016';
                           v_msj_respuesta := 'Ingrese Monto de Credito en Cuenta';
                        end if;

                        if nvl(p_mto_cuenta,0) > 0 then
                           if p_efectivo + nvl(p_mto_cuenta,0) <> v_total then
                               v_cod_respuesta := '015';
                               v_msj_respuesta := 'ERROR: Total no coincide con montos detallados';
                           end if;
                        end if;

                        if nvl(p_cheque,0) > 0 or nvl(p_tip_retencion,0) >0 then
                           --nular el monto cheque
                           v_det_campos := v_det_campos ||fuj_des_campo('CHEQUE',null,null,'D');
                           v_det_campos := v_det_campos ||fuj_des_campo('TIP_RETEN',null,null,'D');
                           v_cod_respuesta := '015';
                           v_msj_respuesta := 'ERROR: La operacion no permite ingresar monto en cheque, ni retencion';
                        end if;
                        if nvl(p_che_ntro_bco,0) > 0 then
                           --nular el monto cheque
                           v_det_campos := v_det_campos ||fuj_des_campo('CHEQ_NTRO',null,null,'D')||
                                           fuj_des_campo('NRO_CHE_NTRO',null,null,'D');
                           v_cod_respuesta := '016';
                           v_msj_respuesta := 'ERROR: La operacion no permite ingresar monto en cheque, ni nro. de cheque';
                        end if;
                     end if;
                  end if;
               end if;
            else--no ingreso importe
               if p_cotizacion is not null and p_cod_moneda is not null then
                  v_cod_respuesta := '015';
                  v_msj_respuesta := 'ERROR: Ingrese importe';
               end if;
            end if;
         end if;

        --validar la cuenta crédito del cliente (para forma de pago en compras)
        if v_cod_respuesta = '000' then
           if p_cta_credito is not null and v_cod_mad_operacion = 71 then
              pag_cta.pr_obt_cuenta(p_cta_credito);
              if pag_cta.fu_obt_cod_error() <> 0 then
                  v_cod_respuesta := '030';
                  v_msj_respuesta := pag_cta.fu_obt_msj_error();
              end if;
              --verificar moneda
              if v_cod_respuesta = '000' then
                 if pag_cta.G_CTAS.cod_moneda <> pag_gen.fu_obt_mon_local then
                    v_cod_respuesta := '032';
                    v_msj_respuesta := 'Cuenta debe ser en Moneda Local ';
                 end if;
              end if;

              if v_cod_respuesta = '000' then
                 --nro doc y nombre del principal de cuenta
                 --puede modificar el cliente, elegir otro q no sea el principal
                 if p_nro_documento is null then
                   begin
                      select v_det_campos ||fuj_des_campo('NRO_DOC',nro_documento,null)||
                             fuj_des_campo('NOMBRE',substr(nom_completo,1,100),' ')
                        into v_det_campos
                        from ba_personas
                       where cod_persona = fug_obt_cli_principal(p_cta_credito);
                   exception
                      when too_many_rows then
                        v_cod_respuesta := '024';
                        v_msj_respuesta := 'Varias Personas con igual codigo ';
                      when no_data_found then
                        v_cod_respuesta := '025';
                        v_msj_respuesta := 'Varias Personas con igual codigo ';
                      when others then
                        v_cod_respuesta := '026';
                        v_msj_respuesta := 'Recup.Cliente '||sqlerrm;
                   end;
                end if;
              end if;
           end if;
        end if;

    --validar la cuenta del cliente (para venta de depósitos)
    if v_cod_respuesta = '000' then
       if p_cta_cliente is not null then
          pag_cta.pr_obt_cuenta(p_cta_cliente);
          if pag_cta.fu_obt_cod_error() <> 0 then
              v_cod_respuesta := '008';
              v_msj_respuesta := pag_cta.fu_obt_msj_error();
          end if;
           --verificar moneda
          if v_cod_respuesta = '000' then
             /*v_det_campos := v_det_campos||
                              fuj_des_campo('COD_MONEDA',pag_cta.G_CTAS.cod_moneda,null,'D');*/
             if pag_cta.G_CTAS.cod_moneda <> p_cod_moneda then
                v_cod_respuesta := '009';
                v_msj_respuesta := 'Cuenta debe ser de la misma Moneda que la Operacion ';
             end if;
          end if;

          if v_cod_respuesta = '000' then
             --nro doc y nombre del principal de cuenta
             --puede modificar el cliente, elegir otro q no sea el principal
             if p_nro_documento is null then
               begin
                  select v_det_campos ||fuj_des_campo('NRO_DOC',nro_documento,null)||
                         fuj_des_campo('NOMBRE',substr(nom_completo,1,100),' ')
                    into v_det_campos
                    from ba_personas
                   where cod_persona = fug_obt_cli_principal(p_cta_cliente);
               exception
                  when too_many_rows then
                    v_cod_respuesta := '024';
                    v_msj_respuesta := 'Varias Personas con igual codigo ';
                  when no_data_found then
                    v_cod_respuesta := '025';
                    v_msj_respuesta := 'Varias Personas con igual codigo ';
                  when others then
                    v_cod_respuesta := '026';
                    v_msj_respuesta := 'Recup.Cliente '||sqlerrm;
               end;
            else --validar que sea del principal
               if v_cod_persona is not null then
                  if v_cod_persona <> fug_obt_cli_principal(p_cta_cliente) then
                     v_cod_respuesta := '029';
                     v_msj_respuesta := 'El Cliente no es Principal de la Cuenta';
                  end if;
               end if;
            end if;
          end if;
          ---Verifica si el Cliente o un Vinculado a la Cuenta está inhibido y la causa es por Demanda Judicial --CROCLIJUD-5
         if v_cod_respuesta = '000' then
           if fug_obt_inhibicion(v_cod_cau_judicial,v_cod_persona,p_cta_cliente) Then
             v_cod_respuesta := '029';
             v_msj_respuesta := 'ERROR: Cliente Principal o Vinc. a la Cuenta con Demanda Judicial. Consulte con el asesor Jurídico';
           end if;  
         end if;
    
       --para validar que la cuenta seleccionada no tenga relacion al usuario que carga
          DECLARE
            v_cod_per ba_personas.cod_persona%type;
            v_exists  varchar2(1);
          BEGIN
              BEGIN
                select a.cod_persona
                  into v_cod_per
                  from ba_usuarios a
                 where a.cod_usuario = user;
                select 'S'
                  into v_exists	  
                  from ge_cta_clientes c
                 where c.cod_persona = v_cod_per
                   and c.nro_cuenta = p_cta_cliente;
              exception
                when no_data_found then
                  v_exists := 'N';
              END;
              if v_exists = 'S' then
                v_cod_respuesta := '029';
                v_msj_respuesta := 'No puede seleccionar la cuenta '||p_cta_cliente||' que tiene relacion con UD.';
              end if;
          END;          
       end if;
    end if;


        --banco
       if v_cod_respuesta = '000' then
          if p_cod_banco is not null then--and p_nro_cheque is not null then
             --determinar si el banco es local o extranjero
             begin
               select '*'
                 into v_existe
                from ge_bancos
                where cod_banco = p_cod_banco
                  and estado = 'A';
                if p_cod_banco = fug_obt_cod_banco then -- nuestro bco
                   if p_cod_tip_operacion = 18 then --compra de cheque
                      v_cod_respuesta := '025'; -- error
                      v_msj_respuesta := 'ERROR: No se puede Comprar Cheque de Nuestro Bco';
                   end if;
                   --si es venta
                   if v_cod_mad_operacion = 72 then
                      if nvl(p_cheque,0) > 0 then
                        v_cod_respuesta := '028'; -- error
                        v_msj_respuesta := 'ERROR: El Banco no puede ser Nuestro Banco';
                      end if;
                   end if;
                 end if;
             exception
                when no_data_found then
                  v_cod_respuesta := '026'; -- error
                  v_msj_respuesta := 'ERROR: Codigo de Banco inexistente.';
                when others then
                  v_cod_respuesta := '027'; -- error
                  v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
             end;
          end if;
       end if;

      end if;
    end if;
  end if; --operacion
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;

  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_245;
/


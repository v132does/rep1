CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_253(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de la boleta
      p_cod_moneda  in varchar2,     -- codigo de la moneda
      p_mto_efectivo in varchar2 default null,    -- importe en efectivo
      p_concepto    in varchar2 default null)     -- concepto de la operacion
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9 ;    -- Caja
  v_cod_modalidad number(3)   := 91 ;   -- Caja
  v_cod_transaccion number(4) := 253 ;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo               varchar2(01) := 'D';  -- Debito para la caja (ingreso)
  v_tip_monto          varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_mto_efectivo       number := nvl(to_number(p_mto_efectivo),0); -- importe  en efectivo
  v_nro_secuencia      number(3) := 0;  -- secuencia del mov.
  -- datos de la lista
  v_can_campos    number(3) := 1;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;
  v_val_posibles  varchar2(3000) := null;
  
  v_cod_rubro cb_rubros.cod_rubro%type := null ;
  v_des_rubro varchar2(300) := null ;
  v_nro_boleta      cj_movimientos.nro_documento%type ;

begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 -- Valido la moneda
 elsif p_cod_moneda is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda de la Operacion.';
 elsif v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
    if p_cod_moneda = 'GS' then
       v_cod_rubro := '240402600210899' ;
    elsif p_cod_moneda = 'EUR' then
       v_cod_rubro := '240402600210817' ;
    elsif p_cod_moneda = 'USD' then
       v_cod_rubro := '240402600210805' ;
    elsif p_cod_moneda = 'BRL' then
       v_cod_rubro := '240402600210803' ;
    elsif p_cod_moneda = 'ARS' then
       v_cod_rubro := '240402600210815' ;
    end if ;
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    -- Verifico la duplicacion del registro
    prj_val_duplicacion(p_nro_caja,
                        v_cod_transaccion,
                        p_cod_moneda,
                        p_nro_boleta,
                        v_cod_respuesta,
                        v_msj_respuesta);
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
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
       end if;
                /*begin
                    v_nro_boleta := fug_obt_lla_pardinamico('NRO_RECIBO', 9)+1 ;
                    prg_act_par_dinamico('NRO_RECIBO',9, null, null, null, v_nro_boleta) ;
                    prj_ins_con_documento(v_nro_boleta, p_nro_caja, v_cod_oficina, p_cod_moneda, 
                                          v_fec_actual, v_hor_actual, v_cod_transaccion) ;
                 exception
                    when others then
                         if sqlcode <= -20000 then
                            v_cod_respuesta := '015';
                            v_msj_respuesta := 'Error en Asigna Nro.Operación '||sqlerrm;
                         end if;
                 end;*/
    end if;

    if v_cod_respuesta = '000' then
         if v_cod_respuesta <> '000' then
          v_cod_respuesta := '005';  -- error
       else
         if v_cod_respuesta = '000' then
              begin
                 select v_cod_rubro||' - '||descripcion
                   into v_des_rubro
                   from cb_rubros
                  where imputable = 'S'
                    and cod_rubro = v_cod_rubro
                    and cod_moneda = p_cod_moneda ;
               exception
                  when no_data_found then
                      v_det_campos := fuj_des_campo('DES_RUBRO',null);
                      v_cod_respuesta := '005'; -- error
                      v_msj_respuesta := 'Rubro contable no valido. Presione F9 para lista de Valores';
                  when others then
                      v_cod_respuesta := '005'; -- error
                      v_msj_respuesta := 'Rubro contable '||sqlerrm;
              end;
        end if;
      end if;
    end if;
 end if;
                
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Ok';
           v_det_campos := '[' || 'DES_RUBRO' ||'~'||v_des_rubro|| ']'||
                           '[' || 'NRO_DOCUMEN' ||'~'||p_nro_boleta|| ']' ;
 end if;
 /* falta armar el mensaje de respuesta */
v_msj_salida := p_nro_operacion||'~'||
                v_cod_respuesta||'~'||
                nvl(v_msj_respuesta,'OK')||'~'||
                ltrim(to_char(v_can_campos,'000'))||'~'||
                v_det_campos ;
 return(v_msj_salida);
end FUJ_VAL_TRANSACCION_253;
/


CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_246 (
      p_nro_operacion     in varchar2,     -- Nro de referencia de la operacion
      p_nro_caja          in varchar2,     -- Nro de Caja
      p_nro_ope_pendiente in number,
      -- Agregado para detalle de cheques, si es uno solo
      p_cod_banco         in varchar2 DEFAULT NULL)   -- codigo del banco
      --p_nro_cheque        in varchar2 DEFAULT NULL, -- numero de cheque
      --Agregado para detalle de cheque nuestro bco
      --p_nro_che_ntro      in number default null)

      --código de la operación pendiente q se retoma
return long is
  -- Datos de la transaccion
  v_cod_modulo number(3)      := 9;      -- Caja
  v_cod_modalidad number(3)   := 91;     -- Caja
  v_cod_transaccion number(4) := 245;    -- transaccion de operación de cambios
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);     -- saldo actual de la caja en cheques
  v_cod_moneda varchar2(3);
  -- Datos de salida
  v_msj_salida    long;        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(500) := 'OK'; -- sin errores
  -- Datos de campos a devolver
  v_can_campos    number(3) := 3;        -- cantidad de campos
  v_det_campos    long :=      -- valores devueltos por defecto
           '[' || 'DES_OPERA' ||'~ ]' ||
           '[' || 'COD_BCP'   ||'~ ]';
  v_val_posibles  varchar2(1000);
  --Datos de la operación
  v_cod_mad_operacion lc_tip_operaciones.cod_modalidad%type;
  v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type;
  v_equivalente       number;
  v_importe           number;
  v_mto_cheque        number;
  v_cod_banco  ge_bancos.cod_banco%type;
  v_des_banco  ge_bancos.descripcion%type;
  v_nro_cheque lc_ope_pendientes.nro_cheque%type;
  v_existe varchar2(1);
  v_che_ntro_bco lc_ope_pendientes.mto_contra5%type;
  v_cod_retencion ge_movimientos.cod_retencion%type;
begin
   -- Valido la operación pendiente
   if p_nro_ope_pendiente is null then
      v_cod_respuesta := '001'; -- error
      v_msj_respuesta := 'ERROR: Ingrese Nro. de Operación Pendiente.';
   else
      --busca la operación pendiente
      begin
         select fuj_des_campo('TIP_OPERA', a.cod_tip_operacion,null) ||
                fuj_des_campo('DES_OPERA', e.descripcion,null) ||
                fuj_des_campo('COD_BCP', a.cod_tip_ope_bcp,null) ||
                fuj_des_campo('COD_MONEDA',a.cod_moneda, null) ||
                fuj_des_campo('IMPORTE',monto,null) ||
                fuj_des_campo('COTIZACION',cotizacion, null) ||
                fuj_des_campo('EQUIVALE',a.mto_equ_local,null) ||
                fuj_des_campo('NRO_DOC',a.nro_documento,null) ||
                fuj_des_campo('TOT_CAR1',nvl(a.mto_cargo1,0) + nvl(a.mto_cargo2,0) + nvl(a.mto_cargo3,0),null) ||
                fuj_des_campo('EFECTIVO',a.mto_contra1,null) ||
                fuj_des_campo('TIP_RETEN',a.cod_retencion,null) ||
                fuj_des_campo('CHEQUE',a.mto_contra2,null) ||
                fuj_des_campo('MTO_CTA',a.mto_contra3,null) ||
                fuj_des_campo('MTO_CTBLE',a.mto_contra4,null) ||
                fuj_des_campo('CTA_CLIENTE',a.cta_ref_contra3,null) ||
                fuj_des_campo('CTA_CTBLE',a.cta_ref_contra4,null) ||
                fuj_des_campo('CHE_NTRO',a.mto_contra5,null) ||
                fuj_des_campo('TOTAL',nvl(a.mto_contra1,0) + nvl(a.mto_contra2,0) +
                                      nvl(a.mto_contra3,0) + nvl(a.mto_contra4,0) + nvl(a.mto_contra5,0),null) ||
                fuj_des_campo('NOMBRE',decode(nvl(a.cod_persona,'xx'),'xx',a.concepto,b.nom_completo),null) ||
                fuj_des_campo('NRO_CHEQ',a.nro_cheque,null)||
                fuj_des_campo('CTA_CLIENTE1',(case when a.cod_tip_operacion = 30 then a.cta_referencia
                                                   when a.cod_tip_operacion = 16 then a.cta_referencia
                                                   else null end),null),
                a.cod_moneda, a.monto, a.mto_equ_local, e.cod_modalidad, a.cod_tip_operacion,
                a.mto_contra2, to_number(a.nro_cta_bancaria), (select descripcion from ge_bancos where cod_banco =a.nro_cta_bancaria), a.nro_cheque, a.mto_contra5, a.cod_retencion
           into v_det_campos, v_cod_moneda, v_importe, v_equivalente, v_cod_mad_operacion, v_cod_tip_operacion,
                v_mto_cheque, v_cod_banco, v_des_banco, v_nro_cheque, v_che_ntro_bco, v_cod_retencion
           from lc_tip_operaciones e, ba_monedas c, ba_personas b, lc_ope_pendientes a
          where nro_operacion = p_nro_ope_pendiente
            and b.cod_persona(+) = a.cod_persona
            and c.cod_moneda = a.cod_moneda
            and e.cod_tip_operacion = a.cod_tip_operacion
            and e.cod_tip_operacion <> 27 --venta de cheque se retoma x gf
            --18/11/2014 WA: Solo si esta parametrizado que pasa por Caja
            --and (e.caja = 'S') se comenta para que se pueda retomar por caja
            and (e.caja = 'S' or a.mto_contra1 > 0 or a.mto_contra2 > 0 or a.mto_contra5 > 0)
            and (nvl(a.mto_contra2,0) = 0 or --compra de cheque o pago en cheque (si se recibe cheque) se retoma aca
                (nvl(a.mto_contra2,0) > 0 and e.cod_modalidad =72))
            and a.liquidado = 'N'
            and nvl(e.afe_libranza,'N') <> 'S'/* FB. AP 1775*/
            and (a.cod_tip_operacion not in (30,16) or --compra/venta d cta si posee algo para pasar x caja
                (a.cod_tip_operacion in (30,16) and (a.mto_contra2 >0 or a.mto_contra2>0 or a.mto_contra1>0 or a.mto_contra5>0)));

           if v_cod_mad_operacion = 71 then
              if v_cod_tip_operacion <> 18 then --si no es compra cheque, apagar
                 v_det_campos := v_det_campos ||
                                 fuj_des_campo('COD_BANCO',null,null,'D')||
                                 fuj_des_campo('NRO_CHEQ',null,null,'D');
              else--permitir cargar
                 v_det_campos := v_det_campos ||
                                 fuj_des_campo('COD_BANCO',v_cod_banco,fuj_pro_val_posibles(replace(fuj_obt_val_posibles(246,'COD_BANCO'),'&TIP_OPERA',v_cod_tip_operacion)),'O')||
                                 fuj_des_campo('NRO_CHEQ',v_nro_cheque,null,'O')||
                                 fuj_des_campo('DES_BANCO',v_des_banco,null);
              end if;
              --apagar cheq ntro bco
              v_det_campos := v_det_campos ||
                                 fuj_des_campo('NRO_CHE_NTRO',null,null,'D');
           else--venta, sólo si tiene imp en cheque permitir ingresar
              --apagar nro cheq ntro bco
              if nvl(v_che_ntro_bco,0) <= 0 then
                 v_det_campos := v_det_campos ||
                                 fuj_des_campo('NRO_CHE_NTRO',null,null,'D');
              else --tiene ntro bco
                 v_det_campos := v_det_campos ||
                                 fuj_des_campo('NRO_CHE_NTRO',null,null,'D'); --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
              end if;
              if nvl(v_mto_cheque,0) <= 0 then
                 v_det_campos := v_det_campos ||
                                 fuj_des_campo('COD_BANCO',null,null,'D')||
                                 fuj_des_campo('NRO_CHEQ',null,null,'D');
              else--tiene mto cheque
                 --si ya no cargo
                 if nvl(p_cod_banco,0) > 0 then
                    v_det_campos := v_det_campos ||
                                    fuj_des_campo('COD_BANCO',p_cod_banco,fuj_pro_val_posibles(replace(fuj_obt_val_posibles(246,'COD_BANCO'),'&TIP_OPERA',v_cod_tip_operacion)),'O')||
                                    fuj_des_campo('NRO_CHEQ',null,null,'O');
                 else
                    v_det_campos := v_det_campos ||
                                    fuj_des_campo('COD_BANCO',null,fuj_pro_val_posibles(replace(fuj_obt_val_posibles(246,'COD_BANCO'),'&TIP_OPERA',v_cod_tip_operacion)),'O')||
                                    fuj_des_campo('NRO_CHEQ',null,null,'O');
                 end if;
                 --validar montos cheques
/*                 if  nvl(v_mto_cheque,0) > 0 and nvl(v_che_ntro_bco,0) > 0 then
                    v_cod_respuesta := '015';
                    v_msj_respuesta := 'ERROR: No se pueden combinar Montos en Cheque';
                 end if;
*/
              end if;
           end if;
      exception
         when no_data_found then
            v_cod_respuesta := '001'; -- error
            v_msj_respuesta := 'ERROR: No existe la Operación '||p_nro_ope_pendiente||', o no se puede retomar.';
            v_det_campos:=fuj_des_campo('TIP_OPERA', ' ',null) ||
                fuj_des_campo('DES_OPERA',' ',null) ||
                fuj_des_campo('COD_BCP', ' ',null) ||
                fuj_des_campo('COD_MONEDA',' ', null) ||
                fuj_des_campo('IMPORTE',' ',null) ||
                fuj_des_campo('COTIZACION',' ', null) ||
                fuj_des_campo('EQUIVALE',' ',null) ||
                fuj_des_campo('NRO_DOC',' ',null) ||
                fuj_des_campo('TOT_CAR1',' ',null) ||
                fuj_des_campo('EFECTIVO',' ',null) ||
                fuj_des_campo('CHEQUE',' ',null) ||
                fuj_des_campo('MTO_CTA',' ',null) ||
                fuj_des_campo('MTO_CTBLE',' ',null) ||
                fuj_des_campo('CTA_CLIENTE',' ',null) ||
                fuj_des_campo('CTA_CLIENTE1',' ',null) ||
                fuj_des_campo('CTA_CTBLE',' ',null) ||
                fuj_des_campo('TOTAL',' ',null) ||
                fuj_des_campo('COD_BANCO',' ',null) ||
                fuj_des_campo('NRO_CHEQ',' ',null) ||
                fuj_des_campo('TIP_RETEN',' ',null) ||
                fuj_des_campo('CHE_NTRO',' ',null) ||
                fuj_des_campo('NRO_CHE_NTRO',' ',null) ||
                fuj_des_campo('NOMBRE',' ',null);
      end;

      if v_cod_respuesta = '000' then
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
            v_msj_respuesta := 'Caja no está habilitada para esta Operación en '||pag_gen.fu_obt_mon_local;
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el día de hoy';
         end if;
      end if;

      if v_cod_respuesta = '000' then
         -- Obtengo los datos de la caja en la moneda de la operación----------
         prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
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
            v_msj_respuesta := 'Caja no está habilitada para esta Operación en '||v_cod_moneda;
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '011'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el día de hoy';
         end if;
      end if;
      --banco
       if v_cod_respuesta = '000' then
          if nvl(p_cod_banco,0) >0  then
             --determinar si el banco es local o extranjero
             begin
               select '*'
                 into v_existe
                from ge_bancos
                where cod_banco = p_cod_banco
                  and estado = 'A';
                if p_cod_banco = fug_obt_cod_banco then -- nuestro bco
                   if v_cod_tip_operacion = 18 then --compra de cheque
                      v_cod_respuesta := '025'; -- error
                      v_msj_respuesta := 'ERROR: No se puede Comprar Cheque de Nuestro Bco';
                   end if;
                   --si es venta
                   if v_cod_mad_operacion = 72 then
                      if nvl(v_mto_cheque,0) > 0 then
                        v_cod_respuesta := '028'; -- error
                        v_msj_respuesta := 'ERROR: El Banco no puede ser Nuestro Banco';
                      end if;
                   end if;
                else
                    if nvl(v_che_ntro_bco,0) > 0 then
                      v_cod_respuesta := '029'; -- error
                      v_msj_respuesta := 'ERROR: El Banco debe ser Nuestro Banco';
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

  end if;--pendiente retomada

  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_246;
/


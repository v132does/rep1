create or replace function it.FUJ_VAL_TRANSACCION_371(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in number,      -- Nro de la boleta de depósito
      p_cod_ente in number,
      p_depositante in number default null,
      p_cod_moneda in varchar2 default null,
      p_nro_cuenta in varchar2 default null,
      p_nro_cheque in varchar2 default null,
      p_serie in cc_chequeras.serie%type default null
      ) 
return VARCHAR2 is
  v_cod_transaccion number := 371;
  v_val_posibles  varchar2(8000) := null;
  v_cta_cre_gs    varchar2(100);
  v_cta_cre_usd   varchar2(100);
  v_fec_actual    date := pag_cal.fu_obt_fec_actual(9); 
  v_cod_oficina   number(3);         -- Codigo de oficina
  v_estado        number(1);         -- estado de la caja
  v_fec_caja      date;              -- fecha de la caja
  v_sal_actual    number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques   number(18,2);     -- saldo actual de la caja en cheques
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  v_can_campos    number(3) := 4;        -- cantidad de campos
  v_det_campos    varchar2(8000);
  v_cod_moneda    ba_monedas.cod_moneda%type;
  v_denominacion  varchar2(200);     -- Nombre de la cuenta
  v_cod_mon_cta   varchar2(3);       -- moneda de la cuenta
  v_est_cuenta    varchar2(1);       -- estado de la cuenta
  v_tip_cuenta    number(3);         -- tipo de cuenta(modalidad)
  v_error         varchar2(4000);
  v_est_cheque    varchar2(01);      -- estado del cheque
  
  Function fu_obt_des_ente return varchar2 is
    v_return varchar2(1000);
    begin
       select fuj_des_campo('DES_ENTE',descripcion)
         into v_return
         from ge_entes
        where cod_ente = p_cod_ente
          and tipo = 'SV';
       return v_return;
    exception
      when no_data_found then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'Código de Ente Recaudador Inválido o no Existe.';
        return null;
      when others then
        v_cod_respuesta := '004';
        v_msj_respuesta := sqlerrm;
        return null;
    end;
  Function fu_obt_nom_depositante return varchar2 is
    v_return varchar2(1000);
    begin
      select fuj_des_campo('NOM_DEPOSITANTE',a.nom_depositante)
        into v_return
        from ge_rec_depositantes a
       where a.cod_ente = p_cod_ente
         and a.cod_depositante = p_depositante
         and a.activo = 'S';
      return v_return;
    exception
      when no_data_found then
        v_cod_respuesta := '005';
        v_msj_respuesta := 'Código de Depositante Inválido o no Existe.';
        return null;
      when others then
        v_cod_respuesta := '006';
        v_msj_respuesta := sqlerrm;
        return null;
    end;

begin
 if p_cod_moneda is null then
   v_cod_moneda := pag_gen.fu_obt_mon_local;
 else
   v_cod_moneda := p_cod_moneda;
 end if;
 
 
 if p_cod_ente is not null then  
    v_det_campos := fu_obt_des_ente;
    if p_depositante is null then
      v_val_posibles  := replace(fuj_obt_val_posibles(v_cod_transaccion,'DEPOSITANTE'),'&COD_ENTE',p_cod_ente);
      -- cargo la lista de valores
      v_val_posibles := fuj_pro_val_posibles(v_val_posibles);
      --
      v_det_campos := v_det_campos||fuj_des_campo('DEPOSITANTE',null,v_val_posibles);     
    else
      v_det_campos := fu_obt_nom_depositante;
    end if;
 end if;

 if p_cod_moneda is not null then
   
    if p_cod_moneda = pag_gen.fu_obt_mon_local then
      v_cta_cre_gs  := fug_obt_parentes(p_cod_ente,'NRO_CTA_CRE_GS');
      if v_cta_cre_gs is null then
        v_cod_respuesta := 007;
        v_msj_respuesta := 'Número de Cuenta no definido para la Moneda '||p_cod_moneda||'.';
      end if;
    else
      v_cta_cre_usd := fug_obt_parentes(p_cod_ente,'NRO_CTA_CRE_USD');
      if v_cta_cre_usd is null then
        v_cod_respuesta := 008;
        v_msj_respuesta := 'Número de Cuenta no definido para la Moneda '||p_cod_moneda||'.';
      end if;
    end if;
    --
 end if;
    
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- Verifico la duplicacion del registro
            /*prj_val_duplicacion(p_nro_caja,
                                v_cod_transaccion,
                                v_cod_moneda,
                                p_nro_boleta,
                                v_cod_respuesta,
                                v_msj_respuesta);*/
       -- Obtengo los datos de la caja ---------------------------------------
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
          v_msj_respuesta := 'Realice la Apertura de Caja previamente';
       elsif v_fec_caja <> v_fec_actual then
          v_cod_respuesta := '011'; -- error
          v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
       end if;
     end if;
  --**
  if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta de Depósito.';
  else
    -- obtengo datos de la cuenta  ------------------------------------------
  if v_cod_respuesta = '000' and p_nro_cuenta is not null then
        begin
          select substr(replace(denominacion,'~','N'),1,50), cod_moneda, estado, cod_modalidad
            into v_denominacion, v_cod_mon_cta, v_est_cuenta, v_tip_cuenta
            from ge_cuentas a
           where a.nro_cuenta = p_nro_cuenta;
          if v_tip_cuenta not in (41,42,43,44,45) then
            v_cod_respuesta := '003';
            v_msj_respuesta := 'ERROR: Tipo de cuenta no permite pago de Cheques';
          elsif v_cod_mon_cta <> p_cod_moneda then
            v_cod_respuesta := '004';
            v_msj_respuesta := 'ERROR: Moneda del Cheque no corresponde al del Deposito';
          else
            -- Verifico la duplicacion del registro
            prj_val_duplicacion(p_nro_caja,
                                v_cod_transaccion,
                                v_cod_moneda,
                                        p_nro_cheque,
                                v_cod_respuesta,
                                v_msj_respuesta);
            if v_cod_respuesta = '000' then
               v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                       v_tip_cuenta,
                                                       v_cod_transaccion,
                                                       v_est_cuenta,
                                                      'D'); -- 'D'== debito en cuenta
               if v_msj_respuesta is not null and v_est_cuenta NOT IN ('P','C') THEN --RE  DE-567 25/06/2015
                  v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
               end if;
            end if;
          end if;
          if v_cod_respuesta = '000' then -- sino hubo problemas se arma los datos de la cuenta
           --RE DE-567 25/06/2015 -------------------------
            v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                                   p_nro_cheque,
                                                   v_error,
                                        p_serie);
           --------------------------------------------------
           IF v_est_cheque = 'O' OR v_est_cuenta IN ('P','C') THEN --RE DE-567 25/06/2015
            v_det_campos := v_det_campos ||
                            '[' || 'DES_MENSAJE' ||'~'||'Cheque con ONP ó Cta.Cancelada'|| ']' ||
                            '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']';
           ELSE
             v_det_campos := v_det_campos ||
                            '[' || 'DES_MENSAJE' ||'~'||' '|| ']' ||
                            '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']';
           END IF;
          end if;
        exception
          when no_data_found then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: Nro de cuenta '||p_nro_cuenta||' no existe!';
          when others then
            v_cod_respuesta := '003';
            v_msj_respuesta := sqlerrm;
        end;
        if v_cod_respuesta = '000' THEN -- sino hubo errores veo el cheque
            v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                                   p_nro_cheque,
                                                   v_msj_respuesta,
                                                   p_serie); --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
            -- verifico el estado del cheque
            if v_msj_respuesta is null then
                if v_est_cheque = 'A' then
                    v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' ha sido anulado';
                elsif v_est_cheque = 'P' then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' ya fue pagado';
                elsif v_est_cheque = 'S' then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' no se ha Entregado';
                elsif v_est_cheque not in ('E','C','G') then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' con estado incorrecto.';
                end if;
            end if;
            if v_msj_respuesta is not null then
              v_cod_respuesta := '009';
            end if;
        end if;
    end if;
    ---
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       -- Obtengo los datos de la caja ---------------------------------------
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
     end if;
  end if;
  --**
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
exception
   when others then
      v_msj_salida := p_nro_operacion||'~'||'999'||'~!'||sqlerrm;
      return(v_msj_salida);

end FUJ_VAL_TRANSACCION_371;
/


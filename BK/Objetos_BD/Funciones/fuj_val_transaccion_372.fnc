create or replace function it.FUJ_VAL_TRANSACCION_372(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in number,      -- Nro de la boleta de deposito
      p_cod_ente in number,
      p_depositante in number default null,
      p_cod_moneda in varchar2 default null,
      p_mto_che24 in number default null,
      p_mto_che48 in number default null,
      p_mto_che72 in number default null,
      p_cod_banco in varchar2 default null
      )
return VARCHAR2 is
  v_cod_transaccion number := 372;
  v_val_posibles  varchar2(8000) := null;
  v_cta_cre_gs    varchar2(100);
  v_cta_cre_usd   varchar2(100);
  v_fec_actual    date := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
  v_cod_oficina   number(3);         -- Codigo de oficina
  v_estado        number(1);         -- estado de la caja
  v_fec_caja      date;              -- fecha de la caja
  v_sal_actual    number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques   number(18,2);     -- saldo actual de la caja en cheques
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(100) := 'OK'; -- sin errores
  v_can_campos    number(3) := 5;        -- cantidad de campos
  v_det_campos    varchar2(8000);
  v_des_banco     varchar2(100);
  v_cod_moneda    ba_monedas.cod_moneda%type;
  ----
  v_mto24         number;
  v_tot_det24     number;
  v_mto48         number;
  v_tot_det48     number;
  v_mto72         number;
  v_tot_det72     number;
  v_msj_ret48h    varchar2(20);
  v_msj_ret72h    varchar2(20);
  v_mto_che_ret_cero cj_movimientos.monto%type;
  v_cod_mon_local ba_monedas.cod_moneda%type;

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
  if p_nro_boleta is null then
    v_cod_respuesta := '001';
    v_msj_respuesta := 'Debe Ingresar el Número de Boleta.';
  end if;
 v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL; 
 if p_cod_moneda is null then
   v_cod_moneda := v_cod_mon_local;
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
       --
       -- Validación de Retenciones
       begin
         select a.monto, a.tot_detallado
           into v_mto24, v_tot_det24
           from cj_movimientos a
          where a.fecha = v_fec_actual
            and a.cod_usuario = user
            and a.cod_tra_padre = 372
            and a.cod_moneda = p_cod_moneda
            and a.nro_documento = p_nro_boleta
            and a.monto = p_mto_che24;
       exception
         when no_data_found then
           v_mto24 := 1;
         when others then
           null;
       end;
       --
       begin
         select a.monto, a.tot_detallado
           into v_mto48, v_tot_det48
           from cj_movimientos a
          where a.fecha = v_fec_actual
            and a.cod_usuario = user
            and a.cod_tra_padre = 372
            and a.cod_moneda = p_cod_moneda
            and a.nro_documento = p_nro_boleta
            and a.monto = p_mto_che48;
       exception
         when no_data_found then
           v_mto48 := 1;
         when others then
           null;
       end;
       --
       begin
         select a.monto, a.tot_detallado
           into v_mto72, v_tot_det72
           from cj_movimientos a
          where a.fecha = v_fec_actual
            and a.cod_usuario = user
            and a.cod_tra_padre = 372
            and a.cod_moneda = p_cod_moneda
            and a.nro_documento = p_nro_boleta
            and a.monto = p_mto_che72;
       exception
         when no_data_found then
           v_mto72 := 1;
         when others then
           null;
       end;
       --
       if p_cod_banco is not null then
         begin
           select '[' || 'DES_BANCO' ||'~'||descripcion|| ']'
             into v_des_banco
            from ge_bancos
            where cod_banco = p_cod_banco
              and ubicacion = 'L'
              and estado = 'A'
              and cod_banco <> fug_obt_cod_banco;
         exception
            when no_data_found then
              v_cod_respuesta := '001'; -- error
              v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
            when others then
              v_cod_respuesta := '001'; -- error
              v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
         end;
         if v_des_banco is not null then
           v_det_campos := v_det_campos||v_des_banco;
         end if;
       else
         if nvl(p_mto_che24,0) > 0 and (nvl(v_mto24,0) - nvl(v_tot_det24,0) > 0) then
           v_det_campos := v_det_campos||'[' || 'TIP_RET' ||'~1]';
         elsif nvl(p_mto_che48,0) > 0 and (nvl(v_mto48,0) - nvl(v_tot_det48,0) > 0) then
           v_det_campos := v_det_campos||'[' || 'TIP_RET' ||'~2]';
         elsif nvl(p_mto_che72,0) > 0 and (nvl(v_mto72,0) - nvl(v_tot_det72,0) > 0) then
           v_det_campos := v_det_campos||'[' || 'TIP_RET' ||'~3]';
         end if;
       end if;
       --Despliegue Mensaje Cheque Alto Valor / CORETRCH-1-Truncamiento / rpavon--
       v_msj_ret48h := null;
       v_msj_ret72h := null;
       if v_cod_moneda = v_cod_mon_local then
          v_mto_che_ret_cero := to_number(fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda));
          if nvl(p_mto_che48,0) >= v_mto_che_ret_cero then
             v_msj_ret48h := 'Alto Valor,verificar';
          end if;
          if nvl(p_mto_che72,0) >= v_mto_che_ret_cero then
             v_msj_ret72h := 'Alto Valor,verificar';
          end if;
       end if;
       v_det_campos := v_det_campos||'[' || 'MSJ_CHE_48' ||'~'||v_msj_ret48h||']'||
                                      '[' || 'MSJ_CHE_72' ||'~'||v_msj_ret72h||']';
      -------------------------------------------------------------------
    end if;
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

end FUJ_VAL_TRANSACCION_372;
/


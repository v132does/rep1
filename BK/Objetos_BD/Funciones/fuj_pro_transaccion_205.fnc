create or replace function it.FUJ_PRO_TRANSACCION_205 (
      p_nro_operacion   in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja        in varchar2,   -- Nro de Caja
      p_nro_boleta      in varchar2 default null,
      p_cod_moneda      in varchar2 default null,   -- Moneda
      p_cod_ofi_destino in varchar2 default null,   -- Caja destino
      p_nro_caj_afecta  in varchar2 default null, -- Número de Caja a la que debe Afectar
      p_monto           in varchar2 default null)   -- Monto de la operacion
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)     := 9;               -- Caja
  v_cod_modalidad number(3)  := 91;           -- Caja
  v_cod_tra_padre number(3)  := 205;
  v_cod_transaccion number(4):= 205;   -- Transaccion
  --
  v_cod_oficina number(3);                   -- oficina de la caja
  v_cod_usuario varchar2(10) := upper(user); -- usuario
  --
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado            number(1);             -- estado de la caja
  v_est_transito      varchar2(1);
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  --
  v_monto             number := to_number(p_monto); -- importe de la transf
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'Operacion confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';  -- credito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'E';  -- efectivo
  v_descripcion   varchar2(50);
  v_nro_boleta           cj_movimientos.nro_documento%type := to_number(p_nro_boleta);
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  r_gmovi                ge_movimientos%rowtype;
  --
  v_nro_caj_afecta cj_cajas.nro_caja%type;
  v_des_caj_afecta cj_cajas.descripcion%type;
  v_tip_caja       cj_cajas.tipo%type;
  -- Procedimiento interno para generar movimiento de transfrencia
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja origen
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_monto,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_monto,0),
             can_creditos = nvl(can_creditos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento para la caja origen
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, cod_rubro, monto, tip_monto, tipo,
          nro_doc_referencia)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
          v_nro_boleta, 'A OFI:'||TRIM(p_cod_ofi_destino)||'-'||trim(fug_obt_abr_oficina(to_number(p_cod_ofi_destino))),
          v_monto,v_tip_monto /* efectivo */, v_tipo,
          to_number(p_cod_ofi_destino)); /* es credito */
  end lp_gen_transaccion;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda y el monto de cierre
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la moneda.';
 elsif p_cod_ofi_destino is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Caja a la cual transferir';
 elsif p_monto is null or v_monto <= 0 then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Monto a transferir.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- no hubo errores
    v_tip_caja := fuj_obt_tip_caja(p_nro_caja);
    -- Si la caja de tipo P(Prosegur) usa la transacción 1205
    if nvl(v_tip_caja,'x') = 'P' then
      v_cod_transaccion := 1205;
    end if;    
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
    elsif v_sal_actual < v_monto then
          v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja no tiene saldo para esta Operacion';
    elsif v_cod_oficina = p_cod_ofi_destino then
          v_cod_respuesta := '001'; -- error
          v_msj_respuesta := 'ERROR: Oficina Origen y Destino son Iguales.';
    end if;
    -- verifico los datos de la caja destino
    if v_cod_respuesta = '000' then
       begin
         select a.descripcion
           into v_descripcion
           from ba_oficinas a, ba_usuarios b
          where a.cod_oficina = to_number(p_cod_ofi_destino)
            and a.estado = 'A'
            and b.cod_usuario = user
            and b.cod_oficina <> a.cod_oficina;
        exception
          when no_data_found then
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: Caja Destino no Existe o No Abierta en la Moneda!';
          when others then
            v_cod_respuesta := '003';
            v_msj_respuesta := sqlerrm;
        end;
    end if;
    If p_nro_boleta is not null then
       if v_cod_respuesta = '000' then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_tra_padre,
                              p_cod_moneda,
                              p_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
       end if;
    End if;
    --
    if v_cod_respuesta = '000' then
       begin
         select c.nro_caja, c.descripcion 
           into v_nro_caj_afecta, v_des_caj_afecta
           from cj_cajas c
          where c.tipo = 'P'
            and c.cod_oficina = v_cod_oficina;
       exception
         when no_data_found then
           if p_nro_caj_afecta is not null then
             -- Sino tiene caja prosegur en su oficina, verifica que la caja ingresada sea correcta.
             v_nro_caj_afecta := p_nro_caj_afecta;
             --
             begin
               select descripcion
                 into v_des_caj_afecta
                 from cj_cajas 
                where tipo in ('P','T')
                  and nro_caja = v_nro_caj_afecta;
             exception
               when no_data_found then
                 v_cod_respuesta := '004';
                 v_msj_respuesta := 'Debe ingresar un Número de Caja válido.';
               when others then
                 v_cod_respuesta := '004';
                 v_msj_respuesta := substr(sqlerrm,1,100);  
             end;
           else
             v_cod_respuesta := '004';
             v_msj_respuesta := 'Debe ingresar un Número de Caja válido.';
           end if;
         when others then
            v_cod_respuesta := '005';
            v_msj_respuesta := substr(sqlerrm,1,100);       
       end;
    end if;
    --
    if v_cod_respuesta = '000' then
      --if v_msj_respuesta is null then -- valido el efectivo
      --   v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,v_monto);
      --end if;
      --if v_msj_respuesta is not null then
      --   v_cod_respuesta := '005';  -- error
      --else
      -- Asigno el nro de caja a los movimientos
      pag_cta.pr_nro_caja(to_number(p_nro_caja));
      -- Acualizo la cuenta con el efectivo depositado
      v_nro_secuencia := 0;
      if v_monto > 0 then
        --generar movimiento
        v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hor_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := p_cod_ofi_destino;
        r_gmovi.cod_moneda      := p_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_cod_modulo;--9
        r_gmovi.cod_mad_padre   := v_cod_modalidad;--91
        r_gmovi.nro_caja        := to_number(p_nro_caja);
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.monto           := v_monto;
        r_gmovi.nro_documento   := to_number(v_nro_boleta);
        r_gmovi.nro_documento2  := v_nro_caj_afecta; 
        r_gmovi.nro_documento3  := null; 
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Enviar Valores en Transito';
        r_gmovi.referencia      := null; 
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.nro_cuenta      := null; 
        r_gmovi.tip_mov_rubro   := NULL;
        --
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        --
        if nvl(v_tip_caja,'x') = 'P' then
          v_est_transito := 'E';
        else
          v_est_transito := 'X';
        end if;
        --Insertar Tabla de Valores en Transito--
        INSERT INTO CJ_VAL_TRANSITO
        (nro_caja,cod_moneda,fecha,monto,cod_ofi_destino,
         estado,nro_caj_proceso,fec_proceso,nro_documento,
         cod_oficina,hora,nro_caj_afecta)
        VALUES
        (TO_NUMBER(P_NRO_CAJA),P_COD_MONEDA,v_fec_actual,
         v_monto,to_number(p_cod_ofi_destino),v_est_transito,null,null,
         v_nro_boleta, v_cod_oficina,v_hor_actual,v_nro_caj_afecta); --I-Ingresado--
      end if;
      -- Actualizo la cuenta con el cheque depositado plaza local sino hubo errores
      if pag_cta.g_cod_error <> 0 then
        -- actualizacion con problemas
        v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
        v_msj_respuesta := pag_cta.g_msj_error;
      else -- genero la transaccion en caja
        lp_gen_transaccion();
      end if;
     --end if;
    end if;
  end if;
 /* armo finalmente el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_205;
/


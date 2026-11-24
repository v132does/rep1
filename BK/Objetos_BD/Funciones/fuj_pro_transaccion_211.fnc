create or replace function it.FUJ_PRO_TRANSACCION_211(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja      in varchar2,   -- Nro de Caja
      p_nro_boleta    in varchar2 default null,
      p_confirma      in varchar2 default null)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo    number(3) := 9;            -- Caja
  v_cod_transaccion number(3) := 211;        -- Transaccion
  v_cod_modalidad number(3) := 91;           -- Caja
  v_cod_tra_padre number(4) := 211;
  --
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_cod_oficina   number(3);                   -- oficina de la caja
  v_cod_usuario   varchar2(10) := upper(user); -- usuario
  --
  v_fec_actual    date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual    varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado        number(1);             -- estado de la caja
  v_fec_caja      date;                  -- fecha de la caja
  v_sal_actual    number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques   number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000';     -- sin errores
  v_msj_respuesta varchar2(100) := 'Operacion confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_nro_boleta    cj_movimientos.nro_documento%type := to_number(p_nro_boleta);
  v_cod_moneda    varchar2(3);
  --
  --v_tipo          varchar2(01) := 'D';  -- credito para la caja (egreso)
  v_tipo          varchar2(01) := 'N';  --No afecta el Saldo, Fecha: 26/05/2010
  v_tip_monto     varchar2(01) := 'E';  -- efectivo
  v_monto         number(18,2);
  --
  v_cod_ofi_origen number(3);
  v_nro_caj_origen number(3);
  v_cod_usu_origen ba_usuarios.cod_usuario%type;
  v_cod_ofi_destino number(3);
  --
  r_gmovi ge_movimientos%rowtype;
  -- CJ_VAL_TRANSACITO
  cursor tran is

      select a.*
        from cj_val_transito a
       where a.nro_documento = v_nro_boleta
         and a.estado = 'X'
         and a.nro_caj_afecta = p_nro_caja;  --Pendiente de Aprobación--
  --
  r_jvalt tran%rowtype;
  -- Procedimiento interno para generar movimiento de transfrencia
  procedure lp_gen_transaccion  is
  begin
      --Se modifico para que no afecte el saldo.... Fecha: 26/05/2010
      /*
      -- Actualizo el control de caja origen
      update cj_controles
         set sal_actual = nvl(sal_actual,0) + nvl(v_monto,0),
             tot_debitos = nvl(tot_debitos,0) + nvl(v_monto,0),
             can_debitos = nvl(can_debitos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      */
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
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          v_nro_boleta,
          substr('OF:'||to_char(v_cod_ofi_origen)||'-'||TO_CHAR(v_nro_caj_origen)||'-'||v_cod_usu_origen,1,15),

          v_monto,v_tip_monto, -- efectivo
          v_tipo,
          v_cod_ofi_origen);
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido que tenga nro. de boleta.
 if p_nro_boleta is null then
   v_cod_respuesta := '001'; -- error
   v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 end if;
 -- Valida que tenga Confirmación o No.
 if nvl(p_confirma,'x') not in ('SI','NO') then
   v_cod_respuesta := '002'; -- error
   v_msj_respuesta := 'ERROR: Ingrese Si Cofirma la Transferencia.';
 end if;
 --
 if v_cod_respuesta = '000' then -- no hubo errores
    -- Carga el registro con los datos de CJ_VAL_TRANSITO
    if tran%isopen then
      close tran;
    end if;
    open tran;
    fetch tran into r_jvalt;
    --
    v_monto           := r_jvalt.monto;
    v_cod_moneda      := r_jvalt.cod_moneda;
    v_cod_ofi_origen  := r_jvalt.cod_oficina;
    v_nro_caj_origen  := r_jvalt.nro_caja;
    v_cod_usu_origen  := r_jvalt.usu_insercion;
    v_cod_ofi_destino := r_jvalt.cod_ofi_destino;
    --
    if r_jvalt.nro_documento is null then
      v_cod_respuesta := '002';
      v_msj_respuesta := 'ERROR: Nro.de Documento no Existe!';
    end if;
    -- Obtengo los datos de la caja ---------------------------------------
    prj_obt_datos_caja(p_nro_caja,
                       r_jvalt.cod_moneda,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques,'N');
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
    -- verifico los datos de la caja destino
    If p_nro_boleta is not null then
       if v_cod_respuesta = '000' then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_transaccion,
                              v_cod_moneda,
                              p_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
       end if;
    End if;
    if v_cod_respuesta = '000' then
      if r_jvalt.monto > 0 then
        if p_confirma = 'SI' then
         --Actualizar Tabla de Valores en Transito--
          update cj_val_transito a
             set a.estado = 'E',  --Enviar
                 a.cod_usu_autorizacion = v_cod_usuario,
                 a.fec_autorizacion = to_date(v_fec_actual||' '||v_hor_actual,'dd/mm/yyyy hh24:mi:ss')
           where a.nro_documento = v_nro_boleta
             and a.nro_caj_afecta = p_nro_caja;
        else
          -- Reversa la operación
          begin
            v_msj_respuesta :=  fuj_pro_transaccion_200(r_jvalt.nro_documento,
                                    r_jvalt.nro_caja,
                                    205,
                                    r_jvalt.nro_documento,
                                    r_jvalt.hora,
                                    'Rechazo Traslado Sucursal');
          exception
            when others then
              v_cod_respuesta := '001'; -- error
              v_msj_respuesta := 'Error en Reversión. '||sqlerrm;
          end;
        end if;
      end if;
    end if;
    --
    if v_cod_respuesta = '000' then
      -- Acualizo la cuenta con el efectivo depositado
      v_nro_secuencia := 0;
      if p_confirma = 'SI' AND v_monto > 0 then
        --generar movimiento
        v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hor_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_ofi_origen;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_cod_modulo;--9
        r_gmovi.cod_mad_padre   := v_cod_modalidad;--91
        r_gmovi.nro_caja        := to_number(p_nro_caja);
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.monto           := v_monto;
        r_gmovi.nro_documento   := to_number(v_nro_boleta);
        r_gmovi.nro_documento2  := v_nro_caj_origen; -- Número Caja Origen
        r_gmovi.nro_documento3  := v_cod_ofi_destino; -- Oficina Destino;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Oficina-Caja-Usuario Origen:'||to_char(v_cod_ofi_origen)||'-'||TO_CHAR(v_nro_caj_origen)||'-'||v_cod_usu_origen||
                                   ' Oficina Destino:'||to_char(v_cod_ofi_destino);
        r_gmovi.referencia      := null; --p_nro_tarjeta;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.nro_cuenta      := null; --v_nro_cuenta;
        r_gmovi.tip_mov_rubro   := NULL;
        --
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
      --
    end if;
    --
    if v_cod_respuesta = '000' then
       lp_gen_transaccion();
    end if;
 end if;
 -- armo finalmente el mensaje de respuesta
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  return(v_msj_salida);
exception
 when others then
     -- armo finalmente el mensaje de respuesta
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_211;
/


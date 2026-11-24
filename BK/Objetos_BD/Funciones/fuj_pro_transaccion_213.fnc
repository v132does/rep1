create or replace function it.FUJ_PRO_TRANSACCION_213(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de la boleta
      p_cod_moneda  in varchar2,     -- codigo de la moneda
      p_mto_efectivo in varchar2,    -- importe en efectivo
      p_concepto    in varchar2)     -- concepto de la operacion
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_tra_padre number(4)   := 213;  -- Transación Padre
  v_cod_tra_efectivo number(4):= 213;  -- Transaccion
  v_cod_tra_cheque number(4);  -- Transaccion Mto. Cheque
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);      -- saldo actual de la caja en cheques
  v_descripcion       varchar2(200);
  -- Datos de salida
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'C';  -- credito para la caja (egreso)
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_mto_efectivo  number := nvl(to_number(p_mto_efectivo),0); -- importe  en efectivo
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_tip_caja      cj_cajas.tipo%type;
  -- Registro de movimientos diarios
  R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_mto_efectivo,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_efectivo,0),
             can_creditos = nvl(can_creditos,0) + decode(v_mto_efectivo,0,0,1),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = p_cod_moneda
         and fecha = v_fec_caja;
      v_nro_secuencia := 0;
      if v_mto_efectivo > 0 then
        -- genero el movimiento por el egreso en efectivo
        v_nro_secuencia := v_nro_secuencia + 1;
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, cod_rubro,cod_ofi_rubro)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
            v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, p_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta, null, v_mto_efectivo,'E' /* efectivo */, v_tipo, null,v_cod_oficina); /* es credito */
      end if;
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_cod_moneda is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Moneda de la Operacion.';
 elsif v_mto_efectivo is null or v_mto_efectivo < 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Efectivo.';
 else
    -- Valido la moneda ingresada
    prj_val_moneda(p_cod_moneda, v_cod_respuesta,v_msj_respuesta);
 end if;
 if v_cod_respuesta = '000' then -- sin errores
   v_tip_caja := fuj_obt_tip_caja(p_nro_caja);
   --Verificar que sea una caja tipo Prosegur
   if nvl(v_tip_caja,'x') != 'P' then
      v_cod_respuesta := '007'; -- error, debe ser una caja tipo Prosegur
      v_msj_respuesta := 'ERROR: Esta operación debe ser realizada desde una caja tipo PROSEGUR.';
    end if;
    -- Verifico la duplicacion del registro
    prj_val_duplicacion(p_nro_caja,
                        v_cod_tra_padre,
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
       elsif v_sal_actual < v_mto_efectivo then
        v_cod_respuesta := '006'; -- error
          v_msj_respuesta := 'Caja no tiene saldo en Efectivo para esta Operacion';
       end if;
    end if;
    if v_cod_respuesta = '000' then
       --Valido el efectivo
       v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,v_mto_efectivo);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          if v_cod_respuesta = '000' then
            begin
              -- Acualizo la cuenta con el efectivo
              if v_mto_efectivo > 0 then
                 -- Aumento la secuencia
                 v_nro_secuencia         := v_nro_secuencia + 1;
                 -- Carga los parametros de movimientos de efectivo
                 r_gmovi.cod_modulo      := v_cod_modulo;
                 r_gmovi.cod_modalidad   := v_cod_modalidad;
                 r_gmovi.cod_oficina     := v_cod_oficina;
                 r_gmovi.nro_cuenta      := null;
                 r_gmovi.cod_moneda      := p_cod_moneda;
                 r_gmovi.cod_usuario     := v_cod_usuario;
                 r_gmovi.hora            := v_hor_actual;
                 r_gmovi.fecha           := v_fec_actual;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 --
                 r_gmovi.fec_valor       := v_fec_actual;
                 r_gmovi.cod_tra_padre   := v_cod_tra_padre;
                 r_gmovi.cod_mod_padre   := v_cod_modulo;
                 r_gmovi.cod_mad_padre   := v_cod_modalidad;
                 r_gmovi.cod_transaccion := v_cod_tra_efectivo; -- transaccion de efectivo
                 r_gmovi.monto           := v_mto_efectivo;
                 r_gmovi.nro_documento   := to_number(p_nro_boleta);
                 r_gmovi.cod_tasa        := null;
                 r_gmovi.val_tasa        := null;
                 r_gmovi.cotizacion      := null;
                 r_gmovi.cod_ofi_origen  := v_cod_oficina;
                 r_gmovi.emi_aviso       := 'N';
                 r_gmovi.concepto        := substr(p_concepto,1,35);
                 r_gmovi.estado          := 'N';
                 r_gmovi.reversado       := 'N';
                 r_gmovi.nro_caja        := to_number(p_nro_caja);
                 r_gmovi.cod_rubro       := null;
                 r_gmovi.tip_mov_rubro   := null;
                 PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
             end if;
           exception
              when others then
                 -- hubo error en la insercion de registros ge_movimientos
                 v_msj_respuesta := sqlerrm;
                 v_cod_respuesta := '007';
           end;
         end if;
         if v_cod_respuesta = '000' then
            -- no hubo problemas hasta aqui, genero la transaccion en caja
           lp_gen_transaccion();
         end if;
      end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_213;
/


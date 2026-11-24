create or replace function it.FUJ_PRO_TRANSACCION_131(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de la boleta
      p_nro_cheque in varchar2,      -- Nro de cheque
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      P_importe in varchar2,         -- Importe de la extraccion
      p_insert IN OUT BOOLEAN, -- para verificar si se inserto en cj_movimientos -- RE DE-567 25/06/2015
      p_hora   IN VARCHAR2 DEFAULT NULL,-- para coincidir la hora en ge_movimientos -- RE DE-567 19/08/2015
      p_es_che_btw in varchar2 default 'N')
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 131;  -- transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        varchar2(08) := nvl(p_hora,to_char(sysdate,'HH24:MI:SS')); -- Hora actual -- RE DE-567 19/08/2015
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
  v_mod_cta           number(3);          -- Modulo de la cuenta
  v_est_cuenta        varchar2(1);       -- estado de la cuenta
  v_tip_cuenta        number(3);         -- tipo de cuenta(modalidad)
  v_cod_banco         number(3);         -- codigo del banco
  v_rowid             varchar2(50);
  -- Datos del cheque
  v_est_cheque        varchar2(01);      -- estado del cheque
  v_nro_che_inicial   number(10);        -- nro inicial del cheque
  v_est_anterior      varchar2(1);       -- estado anterior del cheque
  v_nro_cta_certificado varchar2(20) := null;      -- numero del cta certificacion
  -- Datos de salida
  v_msj_salida    varchar2(4000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(1000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'N';  -- no afecta al saldo
  v_tip_monto     varchar2(01) := 'C';  -- cheque ntro bco
  --DYDMR-2403 ITGF -Deposito de Cheque en Custodia - Error Conversión de Carácter a Número Numérico o de Valor SC 20293
  --v_importe       number := to_number(p_importe); -- importe del cheque
  v_importe       number := fug_con_numero(nvl(p_importe,0));-- importe del cheque
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  --
  v_cod_mon_dep  varchar2(4);
  v_imp_total   number(18,2) := 0;
  v_imp_detalle  number(18,2) := 0;
  v_nro_cta_dep  varchar2(20);
  v_fecha_mvto    cj_movimientos.fecha%type;
  v_hora_mvto     cj_movimientos.hora%type;
  v_cod_usu_mvto  cj_movimientos.cod_usuario%type;
  v_cod_tra_padre ge_transacciones.cod_transaccion%type;
  v_nro_operacion ge_movimientos.nro_secuencia%type := 0;
  v_cod_ofi_cta   number(5);

  r_gmovi         ge_movimientos%rowtype;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set det_che_nue_bco = nvl(det_che_nue_bco,0) +  nvl(v_importe,0),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por la extraccion
     if p_es_che_btw = 'N' then
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja, nro_doc_referencia,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, nro_ref_externo) --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta,
            p_nro_cheque, p_nro_cuenta,
            v_importe,v_tip_monto /* no afecta */, v_tipo, p_nro_operacion); /* es credito */
      else
                insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja, nro_doc_referencia,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, nro_ref_externo, --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicación Externa.-
            cod_rubro)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta,
            p_nro_cheque, null /*p_nro_cuenta*/,
            v_importe,v_tip_monto /* no afecta */, v_tipo, p_nro_operacion, /* es credito */
            fug_obt_pardinamico('COD_RUB_DEP_BTW',null,null,v_cod_mon_dep,null,null));
      end if;
          p_insert := TRUE; -- RE DE-567 25/06/2015 - Se utiliza luego en FUJ_PRO_TRANSACCION_355 si es un cheque con ONP.
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 IF p_insert IS NULL THEN -- RE DE-567 25/06/2015
   p_insert := FALSE;
 END IF;
 -- Valido la moneda
 if p_nro_cheque is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de cheque.';
 elsif p_nro_cuenta is null then  -- valido la cuenta
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Cuenta Corriente del cliente.';
 elsif v_importe is null or v_importe <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe del cheque.';
 elsif p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    begin
        select a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0), a.nro_cuenta,
               a.tip_monto, rowid,
               a.fecha, a.hora, a.cod_usuario, cod_tra_padre
          into v_cod_mon_dep, v_imp_total, v_imp_detalle, v_nro_cta_dep,
               v_tip_monto, v_rowid,
               v_fecha_mvto, v_hora_mvto, v_cod_usu_mvto, v_cod_tra_padre
          from cj_movimientos a
         where a.estado = 'N' -- estado normal
           and a.tip_monto in ('C') -- Cheque ntro bco
           and a.tipo = 'D' -- ingreso a la caja
           and a.nro_caja = to_number(p_nro_caja)
           and a.nro_documento = to_number(p_nro_boleta)
           and nvl(a.monto,0) > nvl(tot_detallado,0) -- que no fue totalmente detallado
           and rownum = 1;  -- por si hay duplicaciones
        -- Verifico la duplicacion del registro

        prj_val_duplicacion(p_nro_caja,
                            v_cod_transaccion,
                            v_cod_moneda,
                            p_nro_cheque,
                            v_cod_respuesta,
                            v_msj_respuesta);

    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Boleta no registrada en el sistema o ya fue detallada!';
      when too_many_rows then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Boleta duplicada!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    if v_cod_respuesta = '000' then -- sino hubo problemas
      -- veo si el importe detallado esta dentro del limite
       if v_importe > v_imp_total - v_imp_detalle then
           v_cod_respuesta := '004';
           v_msj_respuesta := 'ERROR: Monto detallado ya supera al Total deposito!';
       end if;
    end if;
    if v_cod_respuesta = '000' and p_es_che_btw ='N' then -- sino hubo problemas
      -- obtengo datos de la cuenta  ------------------------------------------
      begin
        select denominacion, cod_moneda, estado, cod_modalidad,cod_modulo, cod_oficina
          into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta,v_mod_cta, v_cod_ofi_cta
          from ge_cuentas a
         where a.nro_cuenta = p_nro_cuenta;
        if v_tip_cuenta not in (41,42,43,44) then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR: Tipo de cuenta no permite pago de Cheques';
        elsif v_cod_moneda <> v_cod_mon_dep then
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
        end if;
      exception
        when no_data_found then
          v_cod_respuesta := '002';
          v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
        when others then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR' || sqlerrm;
      end;
      if v_cod_respuesta = '000' THEN -- sino hubo errores veo el cheque
            v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                                   p_nro_cheque,
                                                   v_msj_respuesta);
            -- verifico el estado del cheque
            if v_msj_respuesta is null then
                if v_est_cheque <> 'O' and v_est_cuenta not in ('P','C','T') then
                   v_msj_respuesta := 'El cheque '||p_nro_cheque||' de la cuenta '||p_nro_cuenta||' no tiene Orden de NO Pagar';
                end if;
            end if;
            if v_msj_respuesta is not null then
              v_cod_respuesta := '009';
            end if;
      end if;
    end if;
    --
    if p_es_che_btw ='S' then
     select cod_moneda, 'N' /*v_est_cuenta*/, 41 /*v_tip_cuenta*/, 4 /*v_mod_cta*/, 31 /*v_cod_ofi_cta*/
          into v_cod_moneda, v_est_cuenta, v_tip_cuenta, v_mod_cta, v_cod_ofi_cta
          from cc_che_hibridos a
         where a.nro_cuenta = p_nro_cuenta
           and a.nro_cheque = p_nro_cheque
           and a.nro_caja   = p_nro_caja
           and a.fecha      = v_fec_actual
           and a.hora       = p_hora;
    end if;
    --
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

    if v_cod_respuesta = '000' then
       -- verifico los decimales del importe
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_importe);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          -- Asigno el nro de caja a los movimientos
          pag_cta.pr_nro_caja(to_number(p_nro_caja));
          --Obtener codido del banco
          begin
            select substr(cod_entidad,3,2)
              into v_cod_banco
              from ge_par_generales ;
          exception
            when no_data_found then
              v_cod_respuesta := '010';
              v_msj_respuesta := 'ERROR: Codigo del banco no encontrado!';
            when others then
              v_cod_respuesta := '011';
              v_msj_respuesta := 'ERROR' || sqlerrm;
          end;

          if v_msj_respuesta is not null then
              v_cod_respuesta := '005';  -- error
          else
              --Genero movimiento
              v_nro_operacion := v_nro_operacion + 1 ;

              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_mod_cta;
              r_gmovi.cod_modalidad   := v_tip_cuenta;
              r_gmovi.cod_oficina     := v_cod_ofi_cta;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := 131;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.nro_caja        := to_number(p_nro_caja);
              r_gmovi.cod_transaccion := 131;
              r_gmovi.monto           := p_importe;
              r_gmovi.nro_documento   := p_nro_cheque;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;
              r_gmovi.emi_aviso       := 'N';
			        r_gmovi.concepto        := 'Detalle de Cheques ';
              --
              if p_es_che_btw ='N' then
                r_gmovi.nro_cuenta      := p_nro_cuenta;
              else
                r_gmovi.referencia      := p_nro_cuenta;
              end if;
              --
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              r_gmovi.cod_rubro       := NULL;

              r_gmovi.tip_mov_rubro   := NULL;

              IF v_est_cuenta NOT IN ('C','T') THEN --RE DE-567 Si la cuenta no está cancelada / Bloqueada
                 PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
              END IF;
              -- Asigno el nro de caja a los movimientos
              pag_cta.pr_nro_caja(to_number(p_nro_caja));
              -- Actualiza la operacion en la base
              if v_nro_cta_dep is not null and nvl(p_es_che_btw,'N') ='N' then
                pag_cta.pr_act_operacion(v_nro_cta_dep,
                                         v_hor_actual,
                                         'D', -- debito a la cuenta del cliente
                                         v_cod_moneda,
                                         p_importe,
                                         v_cod_transaccion,
                                         505, -- trans. hijo
                                         p_nro_cheque,
                                         null, -- cotizacion
                                         v_cod_oficina,
                                         v_cod_modulo,
                                         v_cod_modalidad,
                                         null, -- tasa
                                         null, -- valor de tasa
                                         'Debito por Cheque devuelto', --concepto
                                         'N', -- emitir aviso
                                         v_nro_secuencia, -- nro de secuencia
                                         v_fec_actual);
              elsif  v_nro_cta_dep is not null and nvl(p_es_che_btw,'N') ='S' then 
                v_nro_secuencia := v_nro_secuencia + 1;
                pag_cta.pr_act_operacion(v_nro_cta_dep,
                                         v_hor_actual,
                                         'D', -- debito a la cuenta del cliente
                                         v_cod_moneda,
                                         p_importe,
                                         v_cod_transaccion,
                                         791, -- trans. hijo
                                         p_nro_cheque,
                                         null, -- cotizacion
                                         v_cod_oficina,
                                         v_cod_modulo,
                                         v_cod_modalidad,
                                         null, -- tasa
                                         null, -- valor de tasa
                                         'Debito por Cheque devuelto', --concepto
                                         'N', -- emitir aviso
                                         v_nro_secuencia, -- nro de secuencia
                                         v_fec_actual);                           
              else
                  -- no se puede hacer el debito, se aborta
                 v_cod_respuesta := '099';
                 v_msj_respuesta := 'Cheque no puede ser debitado';
              end if;
              if pag_cta.g_cod_error <> 0 then
                 -- actualizacion con problemas
                 v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
                 v_msj_respuesta := pag_cta.g_msj_error;
              else
                -- actualizo el total detallado en la boleta del deposito
                update cj_movimientos
                   set tot_detallado = nvl(tot_detallado,0) + nvl(v_importe,0)
                  where rowid = v_rowid;
                lp_gen_transaccion();
              end if;
          end if;
       end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
    if v_importe +  v_imp_detalle < v_imp_total and p_es_che_btw ='N' then
      -- vuelve a quedar en la pantalla
      v_msj_salida := fuj_val_transaccion_131(p_nro_operacion,
                                              p_nro_caja,
                                              p_nro_boleta);
      if substr(v_msj_salida,1,3) = '000' then
         -- agrego la limpieza de los campos del cheque
         v_msj_salida := v_msj_salida ||fuj_des_campo('NRO_CHEQUE',' ')||
         fuj_des_campo('NRO_CUENTA',' ')||
         fuj_des_campo('DES_CUENTA',' ')||
         fuj_des_campo('COD_MONEDA2',' ')||
         fuj_des_campo('SERIE',' ')      ||--RE  DE-567 25/06/2015
         fuj_des_campo('DES_MENSAJE',' ')||--RE  DE-567 25/06/2015
         fuj_des_campo('IMP_CHEQUE',' ')||'6';
         -- el 6 indica que se quedara en el campo NRO DE cheque
      end if;
      return (v_msj_salida);  -- sale directamente
    end if;

 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_131;
/

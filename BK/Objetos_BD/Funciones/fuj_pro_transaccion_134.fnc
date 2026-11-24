create or replace function it.FUJ_PRO_TRANSACCION_134(
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de la boleta
      p_cod_banco  in varchar2,      -- codigo del banco
      p_des_banco  in varchar2,
      p_nro_cheque in varchar2,      -- numero de cheque
      p_mto_cheque in varchar2,      -- monto del cheque
      p_cod_ofi_camara  in number   default FUG_OBT_OFI_MATRIZ -- camara
      )
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 134;  -- transaccion
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
  v_msj_respuesta varchar2(2000) := 'Operacion Confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'N';  -- no afecta al saldo
  v_tip_monto     varchar2(01) := 'X';  -- Cheq. Otros Bancos plaza extranjera
  v_cod_moneda    varchar2(03);         -- moneda del movimiento
  v_mto_cheque    number := nvl(to_number(p_mto_cheque),0); -- importe  en cheques
  v_nro_secuencia number(3) := 0;  -- secuencia del mov.
  -- datos del movimiento
  v_imp_total   number(18,2) := 0;
  v_imp_detalle number(18,2) := 0;
  v_nro_cuenta  varchar2(20);
  v_rowid       varchar2(50);
  v_cod_retencion ge_movimientos.cod_retencion%type;
  v_fec_final     date;
  v_fecha_mvto    cj_movimientos.fecha%type;
  v_hora_mvto     cj_movimientos.hora%type;
  v_cod_usu_mvto  cj_movimientos.cod_usuario%type;
  v_existe        number(8) := 0 ;-- para controlar si ya existen cheques detallados
  v_cod_tra_padre ge_transacciones.cod_transaccion%type;
  v_des_banco     varchar2(200);

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
      -- Actualizo el control de caja
      update cj_controles
         set det_che_otr_bco = nvl(det_che_otr_bco,0) + nvl(v_mto_cheque,0),
             estado = 1 -- abierto
       where nro_caja = to_number(p_nro_caja)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caja;
      -- genero el movimiento por el  cheque
      if v_hora_mvto = v_hor_actual then
         v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
      end if;
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, nro_cuenta, monto, tip_monto, tipo,nro_doc_referencia)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1, -- secuencia 1
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          p_nro_cheque, v_nro_cuenta, v_mto_cheque,v_tip_monto /* cheq.otros bcos */, v_tipo,
          p_nro_boleta); /* no es debito ni credito */
  end lp_gen_transaccion;
  --
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_cod_banco is null and p_des_banco is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Codigo o Descripcion del Banco.';
 elsif p_nro_cheque is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Numero de cheque.';
 elsif v_mto_cheque is null or v_mto_cheque <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques.';
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    begin
        select a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0), a.nro_cuenta,
               a.tip_monto, rowid,
               a.fecha, a.hora, a.cod_usuario, cod_tra_padre
          into v_cod_moneda, v_imp_total, v_imp_detalle, v_nro_cuenta,
               v_tip_monto, v_rowid,
               v_fecha_mvto, v_hora_mvto, v_cod_usu_mvto, v_cod_tra_padre
          from cj_movimientos a
         where a.estado = 'N' -- estado normal
           and a.tip_monto in ('X') -- tipo cheque otros bcos plaza extranjera
           and a.tipo = 'D' -- ingreso a la caja
           --and a.cod_usuario = v_cod_usuario -- ingresado por el usuario
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
    -- veo si el importe detallado esta dentro del limite
    if v_mto_cheque > v_imp_total - v_imp_detalle then
        v_cod_respuesta := '004';
        v_msj_respuesta := 'ERROR: Monto detallado ya supera al Total deposito!';
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
      declare
         v_existe number;
      begin
         SELECT 0 into v_existe
           from ba_oficinas
          where cod_oficina in (select distinct cod_ofi_camara from ba_oficinas)
            and cod_oficina = p_cod_ofi_camara;
      exception
        when no_data_found then
          v_cod_respuesta := '004';
          v_msj_respuesta := 'ERROR: Codigo de oficina de compensacion inexistente!';
      end;
    end if;
    if v_cod_respuesta = '000' then
           begin
             select descripcion
               into v_des_banco
               from ge_bancos
              where cod_banco = p_cod_banco
                and ubicacion = 'E'
                and estado = 'A';
           exception
              when no_data_found then
                v_cod_respuesta := '001'; -- error
                v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
              when others then
                v_cod_respuesta := '001'; -- error
                v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
           end;
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
      -- verificar si el cheque no fue ya ingresado en el detalle de los cheques
      begin
        select count(1)
          into v_existe
          from ge_che_exterior
         where nro_cuenta = v_nro_cuenta
           and nro_cheque = p_nro_cheque
           and cod_banco  = p_cod_banco
           and fecha >= v_fec_actual;
        If v_existe > 0 then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'ERROR: Documento ya ingresado al sistema.';
        End if;
      exception
        when no_data_found then null;
      end;
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
       -- verifico los decimales del importe en cheques
       v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_mto_cheque);
       if v_msj_respuesta is not null then
          v_cod_respuesta := '005';  -- error
       else
          begin
            -- Recuperar retencion del movimiento
            begin
                select cod_retencion, fec_fin_retencion into v_cod_retencion, v_fec_final
                from ge_movimientos
                where /*fecha = v_fecha_mvto
                and hora = v_hora_mvto
                and cod_usuario = v_cod_usu_mvto*/
                    nro_caja = to_number(p_nro_caja)
                and nro_documento = to_number(p_nro_boleta)
                and monto = v_imp_total
                and cod_retencion = 4
                and cod_transaccion IN (633)
                and reversado ='N';
            exception
              when others then
                 v_cod_respuesta := '009';
                 v_msj_respuesta := 'Mov.respectivo con Nro.Doc '||p_nro_boleta||' Caja '||p_nro_caja||' Importe '||v_imp_total||' Error '||sqlerrm;
            end;

            if v_fec_final is null then
              --obtiene fecha fin de retenci¿n
              begin
              select fec_final
                into v_fec_final
               from ah_retenciones
               where cod_ofi_origen   = v_cod_oficina
                 and nro_documento = to_number(p_nro_boleta)
                 and cod_retencion = v_cod_retencion
                 and cod_moneda    = v_cod_moneda;
              exception
                 when others then
                   v_cod_respuesta := '010';
                   v_msj_respuesta := 'Error al leer ah_retenciones p/ la Of '||v_cod_oficina||' Bol '||p_nro_boleta||' Ret '||v_cod_retencion||' mon '||v_cod_moneda||'-'||sqlerrm;
              end;
            end if;
            if v_cod_respuesta = '000' then
                -- genero el registro en detalle de cheques
                insert into ge_che_exterior
                  (cod_banco, nro_cheque, cta_libradora,
                   cod_moneda, monto, nro_cuenta,  estado,
                   fecha, nro_boleta, cod_ofi_origen,
                   cod_retencion,cod_usuario,hora,fec_final,des_banco,
                   cod_ofi_compensacion)
                values
                  (to_number(p_cod_banco),to_number(p_nro_cheque), null,
                   v_cod_moneda, v_mto_cheque, v_nro_cuenta, 'I', --ingresado
                   v_fec_actual, to_number(p_nro_boleta), v_cod_oficina,
                   v_cod_retencion,v_cod_usuario,v_hor_actual,v_fec_final,
                   nvl(p_des_banco,fug_obt_des_banco(p_cod_banco)),p_cod_ofi_camara);
                -- actualizo el total detallado en la boleta del deposito
                update cj_movimientos
                   set tot_detallado = nvl(tot_detallado,0) + nvl(v_mto_cheque,0)
                 where rowid = v_rowid;
                update ah_retenciones
                   set detallado = 'S'
                 where cod_ofi_origen   = v_cod_oficina
                   and nro_documento = to_number(p_nro_boleta)
                   and cod_retencion = v_cod_retencion
                   and cod_moneda    = v_cod_moneda;
                -- no hubo problemas hasta aqui, genero la transaccion en caja
                lp_gen_transaccion();
            end if;
          exception
            when others then
              -- hubo problemas en las actualizaciones
              v_cod_respuesta := '009';
              v_msj_respuesta := 'Error '||sqlerrm;
          end;
        end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
    if v_mto_cheque +  v_imp_detalle < v_imp_total  then
      -- vuelve a quedar en la pantalla
      v_msj_salida := fuj_val_transaccion_134(p_nro_operacion,
                                              p_nro_caja,
                                              p_nro_boleta);
     if v_msj_salida  LIKE '%~000~%'  then
         -- agbrego la limpieza de los campos del cheque
         v_msj_salida := v_msj_salida ||'[' || 'COD_BANCO' ||'~ ]'  ||
                                        '[' || 'NRO_CHEQUE' ||'~ ]'||
                                        '[' || 'DES_BANCO' ||'~ ]'||
                                        '[' || 'IMP_CHEQUE' ||'~ ]6';
         -- el 6 indica que se quedara en el campo cod_banco
      end if;
      return (v_msj_salida);  -- sale directamente
    end if;
 end if;
 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRANSACCION_134;
/


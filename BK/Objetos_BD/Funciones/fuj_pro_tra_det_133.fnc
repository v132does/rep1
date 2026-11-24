CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRA_DET_133 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de la boleta
      p_tip_reten  in number,        -- tipo de retencion
      p_cod_banco  in varchar2,      -- codigo del banco
      p_nro_cheque in varchar2,      -- numero de cheque
      p_mto_cheque in varchar2,      -- monto del cheque
      p_cod_ofi_camara in number     default 31, -- oficina donde compensa el cheque
      p_nro_pedido in number         default 0, -- C.D.FASE III
      p_cod_usuario in varchar2      default null, -- usuario de caja para webservice Prodep
      p_mon_total in number          default 0 -- monto total del depósito
      )
return VARCHAR2  is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 133;  -- Transaccion
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
  v_tip_monto     varchar2(01) := 'O';  -- Cheq. Otros Bancos
  v_cod_moneda    varchar2(03);         -- moneda del movimiento
  v_mto_cheque    number :=  fug_con_numero (nvl(p_mto_cheque, 0));  --nvl(to_number(p_mto_cheque),0); -- importe  en cheques
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
  v_detallado     varchar2(1);
  v_est_movimiento varchar2(1) default 'N';
  v_mto_boleta     number;
  v_mto_detallado  number;
  v_retencion      number;
  v_val_usu_resp   varchar2(1);
  v_hor_detalle    cj_mov_prodep.hora%type;
  v_exis_cjmov    varchar2(1);
  c_tra_custodia  constant ge_transacciones.cod_transaccion%type:=141;

  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion is
  begin
      -- Actualizo el control de caja
      If nvl(p_nro_pedido,0) = 0 Then
          update cj_controles
             set det_che_otr_bco = nvl(det_che_otr_bco,0) + nvl(v_mto_cheque,0),
                 estado = 1 -- abierto
           where nro_caja = to_number(p_nro_caja)
             and cod_moneda = v_cod_moneda
             and fecha = v_fec_caja;
      End IF;
      -- genero el movimiento por el  cheque
      if v_hora_mvto = v_hor_actual then
         v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_actual);
      end if;
      IF nvl(p_nro_operacion, 0) = 99999 THEN
         BEGIN
           SELECT MAX(hora)
             INTO v_hor_detalle
             FROM cj_movimientos
            WHERE fecha = v_fec_actual
              AND cod_usuario = v_cod_usuario;
         EXCEPTION
           WHEN OTHERS THEN     
             v_hor_detalle := null;
         END;
         IF v_hor_detalle IS NOT NULL THEN
            v_hor_actual := pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_detalle); 
         END IF;
      END IF;
      If nvl(v_exis_cjmov,'N') <> 'S' then   
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja,
            nro_documento, nro_cuenta, monto, tip_monto, tipo,nro_doc_referencia,estado)
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, 1, -- secuencia 1
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_cheque, v_nro_cuenta, v_mto_cheque,v_tip_monto /* cheq.otros bcos */, v_tipo,
            p_nro_boleta,decode(p_nro_pedido,0,'N','P')); /* no es debito ni credito */
       End if;
  end lp_gen_transaccion;
  --
 -- C.D.Fase III--
 procedure lp_act_can_impresion is
  begin
    update cj_movimientos c
       set c.can_impresion = nvl(c.can_impresion, 0) + 1
     where c.fecha = v_fec_actual
       and c.cod_usuario = v_cod_usuario
       and c.hora = v_hor_actual
       and c.cod_tra_padre = v_cod_transaccion;
  exception
    when no_data_found then
      v_cod_respuesta := '006'; -- error
      v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
    when others then
      v_cod_respuesta := '006'; -- error
      v_msj_respuesta := 'ERROR: Al actualizar movimiento de Caja.';
  end lp_act_can_impresion;
  --
  -- Para que coincida el número de cheque detallado con el cheque de cámara
  PROCEDURE lp_rev_che_detallado IS
  BEGIN
    IF v_cod_tra_padre IS NULL THEN
       BEGIN
          SELECT a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0), a.nro_cuenta,
                 a.tip_monto, rowid,
                 a.fecha, a.hora, a.cod_usuario, cod_tra_padre, decode(tip_monto,'O',1,'T',2,'S',3)
            INTO v_cod_moneda, v_imp_total, v_imp_detalle, v_nro_cuenta,
                 v_tip_monto, v_rowid,
                 v_fecha_mvto, v_hora_mvto, v_cod_usu_mvto, v_cod_tra_padre, v_cod_retencion
            FROM cj_movimientos a
           WHERE a.estado IN ('P','N')/*= 'N' */-- estado normal -- C. D Fase III
             AND a.tip_monto IN ('O', 'S', 'T') 
             AND a.tipo = 'D' -- ingreso a la caja
             AND a.nro_caja = to_number(p_nro_caja)
             AND a.nro_documento = to_number(p_nro_boleta)
             AND a.monto = p_mon_total
             AND decode(tip_monto,'O',1,'T',2,'S',3) = p_tip_reten
             AND rownum = 1  -- por si hay duplicaciones
           ORDER BY decode(tip_monto,'O',1,'T',2,'S',3);
       EXCEPTION
         WHEN OTHERS THEN
           BEGIN
              SELECT a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0), a.nro_cuenta,
                     a.tip_monto, rowid,
                     a.fecha, a.hora, a.cod_usuario, cod_tra_padre, decode(tip_monto,'O',1,'T',2,'S',3)
                INTO v_cod_moneda, v_imp_total, v_imp_detalle, v_nro_cuenta,
                     v_tip_monto, v_rowid,
                     v_fecha_mvto, v_hora_mvto, v_cod_usu_mvto, v_cod_tra_padre, v_cod_retencion
                FROM cj_movimientos a
               WHERE a.estado IN ('P','N')/*= 'N' */-- estado normal -- C. D Fase III
                 AND a.tip_monto IN ('O', 'S', 'T') 
                 AND a.tipo = 'D' -- ingreso a la caja
                 AND a.nro_caja = to_number(p_nro_caja)
                 AND a.nro_documento = to_number(p_nro_boleta)
                 AND decode(tip_monto,'O',1,'T',2,'S',3) = p_tip_reten
                 AND rownum = 1  -- por si hay duplicaciones
               ORDER BY decode(tip_monto,'O',1,'T',2,'S',3);
           EXCEPTION
             WHEN OTHERS THEN
               v_cod_tra_padre := null;
           END;
       END;      
    END IF;   
    IF (FUP_EXI_GRU_TRANSAC(804, v_cod_tra_padre, v_cod_modulo, v_cod_modalidad) = 'S' 
       OR v_cod_tra_padre IN (359, 362, 361) OR v_cod_moneda <> pag_gen.fu_obt_mon_local)
       AND v_cod_tra_padre <> 141 THEN
      -- para volver a insertar el detalle de los cheques escaneados
      DELETE cc_che_enviados
       WHERE fecha = v_fec_actual
         AND nro_boleta = p_nro_boleta
         AND nro_cuenta = v_nro_cuenta
         AND nro_caja = to_number(p_nro_caja)
         AND cod_retencion = p_tip_reten;
      -- cerar para volver a detallar   
      UPDATE cj_movimientos
         SET tot_detallado = 0
       WHERE rowid = v_rowid;  
      -- Actualizar el control de caja
      IF nvl(p_nro_pedido, 0) = 0 THEN
         UPDATE cj_controles
            SET det_che_otr_bco = nvl(det_che_otr_bco, 0) - nvl(v_imp_total, 0)
          WHERE nro_caja = to_number(p_nro_caja)
            AND cod_moneda = v_cod_moneda
            AND fecha = v_fec_actual;
      END IF; 
      --eliminar el detalle de los cheques
      DELETE cj_movimientos
       WHERE fecha = v_fec_actual
         AND nro_doc_referencia = p_nro_boleta
         AND nro_cuenta = v_nro_cuenta
         AND nro_caja = to_number(p_nro_caja)
         AND decode(tip_monto,'O',1,'T',2,'S',3) = p_tip_reten;
      v_cod_respuesta := '000';
    END IF;  
  END lp_rev_che_detallado;  
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 elsif p_cod_banco is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Codigo del Banco.';
 elsif p_tip_reten is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Tipo de Retencion.';
 elsif p_nro_cheque is null then
    v_cod_respuesta := '002'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Numero de cheque.';
 elsif v_mto_cheque is null or v_mto_cheque <= 0 then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques.';
 elsif p_cod_ofi_camara is null then
    v_cod_respuesta := '003'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la oficina donde se compensara el cheque.';
 end if;
 if v_cod_respuesta = '000' then -- sin errores
    begin
        select a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0), a.nro_cuenta,
               a.tip_monto, rowid,
               a.fecha, a.hora, a.cod_usuario, cod_tra_padre, decode(tip_monto,'O',1,'T',2,'S',3)
          into v_cod_moneda, v_imp_total, v_imp_detalle, v_nro_cuenta,
               v_tip_monto, v_rowid,
               v_fecha_mvto, v_hora_mvto, v_cod_usu_mvto, v_cod_tra_padre, v_cod_retencion
          from cj_movimientos a
         where a.estado in ('P','N')/*= 'N' */-- estado normal -- C. D Fase III
           and (a.tip_monto in ('S','T') or -- tipo cheque otros bcos suc.
                a.tip_monto = 'O' /*and a.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL*/)
           and a.tipo = 'D' -- ingreso a la caja
           --and a.cod_usuario = v_cod_usuario -- ingresado por el usuario
           and a.nro_caja = to_number(p_nro_caja)
           and a.nro_documento = to_number(p_nro_boleta)
           and ((nvl(a.monto,0) > nvl(tot_detallado,0)) or 
           (nvl(a.monto,0)=nvl(tot_detallado,0) and a.cod_tra_padre=c_tra_custodia)) -- que no fue totalmente detallado
           and decode(tip_monto,'O',1,'T',2,'S',3) = p_tip_reten
           and rownum = 1  -- por si hay duplicaciones
           order by decode(tip_monto,'O',1,'T',2,'S',3);
           
           if v_cod_tra_padre=c_tra_custodia then
               return '~000~La operacion corresponde a un descuento de cheque';
           end if;
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
        --v_msj_respuesta := 'ERROR: Boleta no registrada en el sistema o ya fue detallada!';
        v_msj_respuesta := 'ERROR: Boleta no registrada '||p_nro_boleta||'-'||p_tip_reten;
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
        IF p_nro_operacion = 99999 THEN 
           lp_rev_che_detallado;
        END IF;
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
          v_msj_respuesta := 'ERROR: Codigo de oficina '||p_cod_ofi_camara||' de compensacion inexistente!';
      end;
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
      -- verificar si el cheque no fue ya ingresado en el detalle de los cheques
      begin
        select count(1)
          into v_existe
          from cc_che_enviados
         where nro_cuenta = v_nro_cuenta
           and nro_cheque = to_number(p_nro_cheque)
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
    --WA: 30/09/2013 Se debe validar si son operaciones de Cambio, sino
    --esta pendiente de autorizar, no se debe dejar detallar
    if v_cod_tra_padre in (241,242,245,246) then
          v_existe:=0;
          begin
            select count(*)
             into v_existe
             FROM ge_movimientos a
              where a.nro_documento=p_nro_boleta
              and a.nro_secuencia=1
              and a.estado not in ('J','N')
        and nvl(reversado,'N')='N';
          exception
            when no_data_found then
                v_existe:=0;
            when others then
                v_existe:=0;
          end;
          if nvl(v_existe,0)> 0  then
             v_cod_respuesta := '099';
             v_msj_respuesta := 'ERROR: Operación Pendiente de Autorización !!!';
          end if;

    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
       IF p_nro_operacion = 99999 THEN --viene del webservice de Prodep
          v_val_usu_resp := 'N';
          v_cod_usuario  := p_cod_usuario;
       END IF;
       -- Obtengo los datos de la caja ---------------------------------------
       prj_obt_datos_caja(p_nro_caja,
                          v_cod_moneda,
                          v_cod_oficina,
                          v_fec_caja,
                          v_estado,
                          v_sal_actual,
                          v_sal_cheques,
                          v_val_usu_resp);
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
            declare
               v_retencion ge_movimientos.cod_retencion%type := v_cod_retencion;
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
                and cod_retencion = v_retencion
                and cod_transaccion IN (607,610,632)
                and reversado ='N';
            exception
              when others then
                 v_cod_respuesta := '009';
                 v_msj_respuesta := 'Mov.respectivo con Nro.Doc '||p_nro_boleta||' Caja '||p_nro_caja||' Importe '||v_imp_total||' Error '||sqlerrm;
            end;
            if v_cod_respuesta = '000' then
              --obtiene fecha fin de retención, si ya no obtuvo del movimiento

                begin
                  if v_fec_final is null then
                      select fec_final, detallado
                        into v_fec_final, v_detallado
                       from ah_retenciones
                       where cod_ofi_origen   = v_cod_oficina
                         and nro_documento = to_number(p_nro_boleta)
                         and cod_retencion = v_cod_retencion
                         and cod_moneda    = v_cod_moneda;
                  else
                      begin
                        select detallado
                          into v_detallado
                         from ah_retenciones
                         where cod_ofi_origen   = v_cod_oficina
                           and nro_documento = to_number(p_nro_boleta)
                           and cod_retencion = v_cod_retencion
                           and cod_moneda    = v_cod_moneda;
                      exception
                        when others then
                           v_detallado := 'N';
                      end;
                  end if;
                exception
                   when no_data_found then
                      v_fec_final := v_fec_actual;
                   when others then
                      v_cod_respuesta := '009';
                      v_msj_respuesta := ' Error en ah_retenciones '||sqlerrm;
                end;
                --if v_detallado = 'S' then
                --   v_cod_respuesta := '009';
                --   v_msj_respuesta := ' Boleta ya fue detallada en Operaciones';
                --end if;
            end if;
            if v_cod_respuesta = '000' then
              -- genero el registro en detalle de cheques
              insert into cc_che_enviados
                (cod_banco, nro_cheque, cta_libradora,
                 cod_moneda, monto, nro_cuenta,  estado,
                 fecha, nro_boleta, cod_ofi_origen,
                 cod_retencion,cod_usuario,hora,fec_final,
                 cod_ofi_compensacion,nro_caja)
              values
                (to_number(p_cod_banco),to_number(p_nro_cheque), null,
                 v_cod_moneda, v_mto_cheque, v_nro_cuenta, decode(p_nro_pedido,0,'I','P'), --ingresado -- poner estado P-C.D.FASE III
                 v_fec_actual, to_number(p_nro_boleta), v_cod_oficina,
                 v_cod_retencion,v_cod_usuario,v_hor_actual,v_fec_final,
                 p_cod_ofi_camara,p_nro_caja);
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
              If v_cod_tra_padre in (359,362,361) Then
                  Begin
                      update pr_cob_cuo_otr_bco a
                         set a.nro_cheque  = p_nro_cheque
                       where a.nro_cuenta  = v_nro_cuenta
                         and a.fec_proceso = v_fec_actual
                         and a.nro_boleta  = to_number(p_nro_boleta)
                         and a.estado      = 'C';
                  End Loop;
              End IF;
              -- no hubo problemas hasta aqui, genero la transaccion en caja
              lp_gen_transaccion();

            end if;
          exception
            when others then
              -- hubo problemas en las actualizaciones
              v_cod_respuesta := '009';
              v_msj_respuesta := sqlerrm;
          end;
        end if;
    end if;
 end if;
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' -- sino hubo problemas, se carga mensaje por defecto
    and nvl(p_nro_operacion, 0) <> 99999 then -- si viene de Prodep no se imprime comprobante 
    v_msj_respuesta := 'Operacion confirmada';
    -- IMPRESION DEL COMPROBANTE DE PAGO - SOLO PRESTAMOS
    if  v_mto_cheque = v_imp_total - v_imp_detalle
    and v_cod_tra_padre in (359,360,362)
    and fug_obt_tip_implementacion IN (1,3,7) then
       lp_act_can_impresion; -- C.D.Fase III--
       --- Si ya detallo toda la operacion
       v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
       v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
       fuj_imp_transaccion_360(v_cod_oficina, -- oficina
                               p_nro_boleta,
                               null,--nro de factura
                               p_nro_caja, -- Caja
                               v_cod_moneda, -- Moneda
                               v_nro_cuenta, -- cuenta
                               v_fecha_mvto,
                               v_hora_mvto -- hora
                               );
    elsif v_mto_cheque +  v_imp_detalle < v_imp_total  then
      If v_cod_tra_padre in (359,362) Then
         v_cod_respuesta := '007'; -- error
         v_msj_respuesta := 'No puede desglosar cheque cargo otros bancos para cancelación de préstamos';
      Else
          if p_nro_pedido = 0 then
            v_est_movimiento := 'N';
          else
            v_est_movimiento := 'P';
          end if;
          -- vuelve a quedar en la pantalla
          v_msj_salida := fuj_val_transaccion_133(p_nro_operacion,
                                              p_nro_caja,
                                              p_nro_boleta,
                                              p_tip_reten,
                                              null,
                                              v_est_movimiento);
          if v_msj_salida  LIKE '%~000~%'  then
             -- agbrego la limpieza de los campos del cheque
             v_msj_salida := v_msj_salida ||'[' || 'COD_BANCO' ||'~ ]'  ||
                                            '[' || 'NRO_CHEQUE' ||'~ ]'||
                                            '[' || 'DES_BANCO' ||'~ ]'||
                                            '[' || 'IMP_CHEQUE' ||'~ ]7';
             -- el 7 indica que se quedara en el campo cod_banco
          end if;
          return (v_msj_salida);  -- sale directamente
      End IF;
    else
      begin
        select nvl(a.monto, 0),
               nvl(a.tot_detallado, 0),
               decode(tip_monto, 'O', 1, 'T', 2, 'S', 3)
          into v_mto_boleta, v_mto_detallado, v_retencion
          from cj_movimientos a
         where a.estado in ('P', 'N')
           and (a.tip_monto in ('S', 'T') or a.tip_monto = 'O')
           and a.tipo = 'D'
           and a.nro_caja = to_number(p_nro_caja)
           and a.nro_documento = to_number(p_nro_boleta)
           and nvl(a.monto, 0) > nvl(tot_detallado, 0)
           and rownum = 1
         order by decode(tip_monto, 'O', 1, 'T', 2, 'S', 3);

      exception
        when no_data_found then
          v_mto_boleta := null;
          v_mto_detallado := null;
          v_retencion := null;
        when others then null;
      end;
        if p_nro_pedido = 0 then
          v_est_movimiento := 'N';
        else
          v_est_movimiento := 'P';
        end if;
        -- vuelve a quedar en la pantalla
        v_msj_salida := fuj_val_transaccion_133(p_nro_operacion,
                                            p_nro_caja,
                                            p_nro_boleta,
                                            v_retencion,
                                            null,
                                            v_est_movimiento);
        if v_msj_salida  LIKE '%~000~%'  then
           -- agbrego la limpieza de los campos del cheque
           v_msj_salida := v_msj_salida ||'[' || 'TIP_RET' ||'~'||to_char(v_retencion)|| ']'||
                                          '[' || 'COD_BANCO' ||'~ ]'  ||
                                          '[' || 'NRO_CHEQUE' ||'~ ]'||
                                          '[' || 'DES_BANCO' ||'~ ]'||
                                          '[' || 'IMP_CHEQUE' ||'~ ]7';
           -- el 7 indica que se quedara en el campo cod_banco
        return (v_msj_salida);  -- sale directamente
      end if;
    end if;
 end if;

 /* falta armar el mensaje de respuesta */
 v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 nvl(v_msj_respuesta,'Operacion confirmada');
 return(v_msj_salida);
end FUJ_PRO_TRA_DET_133;
/

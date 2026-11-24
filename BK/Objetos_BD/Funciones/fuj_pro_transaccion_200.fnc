CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_200 (
    p_nro_operacion   in varchar2,                                       -- Nro de referencia de la operacion
    p_nro_caja        in cj_movimientos.nro_caja%type,                   -- Nro de Caja
    p_cod_tra_padre   in cj_movimientos.cod_tra_padre%type,              -- Codigo de transaccion
    p_nro_documento   in cj_movimientos.nro_documento%type default null, -- Nro. de Boleta
    p_hora            in cj_movimientos.hora%type default null,          -- hora de la transaccion a reversar
    p_motivo          in varchar2 default null,
    p_autorizado      in varchar2 default 'N')
return VARCHAR2  is

  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo        cj_movimientos.cod_mod_padre%type := 9;            -- Caja
  v_cod_modalidad     cj_movimientos.cod_mad_padre%type := 91;           -- Caja
  --
  v_cod_oficina       cj_movimientos.cod_oficina%type;                   -- oficina de la caja
  v_cod_usuario       cj_movimientos.cod_usuario%type   := upper(user);  -- usuario
  v_cod_usu_operacion cj_movimientos.cod_usuario%type;
  v_cod_mon_local     cj_movimientos.cod_moneda%type    := pag_gen.fu_obt_mon_local;
  v_solicita          varchar2(1) := 'N';
  v_nro_doc_original  cj_movimientos.nro_documento%type;
  v_motivo            varchar2(100);
  -- Datos de los movimientos
  v_nro_documento     cj_movimientos.nro_documento%type;
  cursor cj_movs ( p_nro_caj_princ number ) is
    SELECT a.cod_moneda, a.monto, a.tipo, a.tip_monto, a.tot_detallado,
           a.nro_doc_referencia, a.rowid, a.nro_documento, a.cod_mod_padre,
           a.cod_mad_padre, a.cod_usuario, a.nro_cuenta, a.fecha, a.hora
      FROM cj_movimientos a
     WHERE a.nro_caja = p_nro_caj_princ
       AND a.hora     = p_hora
       AND a.cod_tra_padre IN (to_number(p_cod_tra_padre), 598, 137, 393, 394, 395)
       AND a.estado   = 'N' -- normal
          --Agregado para controlar tarjetas ya enviadas a procesadora--
       AND ((a.cod_tra_padre <> 250) OR (a.cod_tra_padre = 250 AND NOT EXISTS
            (SELECT 1
               FROM ta_cobros x
               WHERE x.fec_proceso = a.fecha
                 -- DYDMR-728 Reversion cobro tarjeta de credito SC - 4685
                 AND nvl(x.hora,a.hora) = a.hora
                 AND x.nro_cuenta  = a.nro_cuenta
                 AND x.estado IN ('P', 'C')
                 AND x.est_envio <> 'P')))FOR UPDATE;
  --
  v_fec_actual        ge_movimientos.fecha%type         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual        ge_movimientos.hor_reversion%type := to_char(sysdate,'HH24:MI:SS');           -- Hora actual
  v_estado            number(1);               -- estado de la caja
  v_fec_caja          cj_controles.fecha%type; -- fecha de la caja
  v_sal_actual        number(18,2);            -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);            -- saldo actual de la caja en cheques
  --
  v_msj_salida        varchar2(8000);          -- mensaje final retornado
  v_cod_respuesta     varchar2(03)   := '000'; -- sin errores
  v_msj_respuesta     varchar2(4000) := 'Operacion confirmada'; -- sin errores
  --
  v_nro_secuencia     cj_movimientos.nro_secuencia%type := 0;   -- secuencia del mov.
  v_nro_caj_princ     cj_movimientos.nro_caja%type;
  --
  v_cantidad          number(3) := 0;
  --
  v_monto             number := 0;  -- monto
  v_efectivo          number := 0;  -- importe en efectivo
  v_che_nue_bco       number := 0;  -- importe en cheques
  v_che_otr_bco       number := 0;  -- importe en otros cheques
  v_tot_debitos       number := 0;  -- total de debitos
  v_tot_creditos      number := 0;  -- total de creditos
  v_det_otr_bco       number := 0;  -- detalle de cheques
  v_det_nue_bco       number := 0;  -- detalle de ntro bco

  -- variables para guardar los datos de la operacion principal de cambios
  v_ope_cod_usuario   ge_movimientos.cod_usuario%type;
  v_ope_hora          ge_movimientos.hora%type;
  v_ope_fecha         ge_movimientos.fecha%type;
  v_ope_cod_moneda    ge_movimientos.cod_moneda%type;
  v_ope_monto         ge_movimientos.monto%type;
  v_ope_tip_operacion ge_movimientos.cod_tip_ope_cambio%type;
  v_ope_cod_bcp       ge_movimientos.cod_bco_central%type;
  v_ope_mto_mon_local ge_movimientos.mto_equ_local%type;
  v_ope_ofi_cambio    ba_oficinas.cod_ofi_cambio%type;
  v_nro_cuenta        ge_aut_reversiones.nro_cuenta%type;
  v_nro_solicitud     ge_aut_reversiones.nro_pedido%type;
  v_cod_moneda        ge_movimientos.cod_moneda%type;
  v_nro_caja          number(4);
  
  --variables cobrador 24x7
  v_nro_cta_atraso    ge_movimientos.nro_cuenta%type;
  v_nro_cta_credito   ge_movimientos.nro_cuenta%type;
  v_cod_tra_pad_24x7  ge_movimientos.nro_cuenta%type;
  v_can_cob_24x7      number(3) := 0;
  v_ope_fec_cob       ge_movimientos.fecha%type;
  v_ope_hor_cob       ge_movimientos.hora%type;
  v_ope_cod_usu_cob   ge_movimientos.cod_usuario%type;
  v_cod_mod_cob       ge_movimientos.cod_modulo%type;
  v_cod_mad_cob       ge_movimientos.cod_modalidad%type;
  v_cod_tra_pad_cob   ge_movimientos.cod_tra_padre%type;
  v_cod_mod_cta_cob   ge_movimientos.cod_modulo%type;
  v_cod_mad_cta_cob   ge_movimientos.cod_modalidad%type; 

  --obtiene el numero de caja del movimiento principal
  procedure lp_obt_nro_caja ( p_fecha_01       in  date,
                              p_hora_01        in  varchar2,
                              p_cod_usuario_01 in  varchar2,
                              p_nro_caja_01    out number
                            ) is
    begin
      Select nro_caja
        into p_nro_caja_01
        from cj_movimientos
       where estado        = 'N'
         and fecha         = p_fecha_01
         and hora          = p_hora_01
         and cod_usuario   = p_cod_usuario_01
         and tipo          <> 'N' --No afecta saldo
         and nro_secuencia = 1;
       if p_nro_caja_01 is null then
          v_cod_respuesta := '001';
          v_msj_respuesta := 'ERROR: Existe Nro. Caja en movimiento con Fecha: '||p_fecha_01||', hora:'||p_hora_01||', usuario:'||p_cod_usuario_01;
       end if;
    exception
      when no_data_found then
          v_cod_respuesta := '001';
          v_msj_respuesta := 'ERROR: No existe movimiento. Fecha: '||p_fecha_01||', hora:'||p_hora_01||', usuario:'||p_cod_usuario_01||', Caja:'||p_nro_caja_01;
      when others then
          v_cod_respuesta := '001';
          v_msj_respuesta := 'ERROR: Existen varios movimientos con Fecha: '||p_fecha_01||', hora:'||p_hora_01||', usuario:'||p_cod_usuario_01||', Caja:'||p_nro_caja_01;
  end lp_obt_nro_caja;

  -- Procedimiento interno para reversar el movimiento
  procedure lp_rev_transaccion ( p_rowid in varchar2,
                                 p_cod_moneda in varchar2,
                                 p_monto in number,
                                 p_tipo in varchar2,
                                 p_tip_monto in varchar2,
                                 p_nro_doc_referencia in number,
                                 p_nro_documento in number,
                                 p_cod_mod_padre in number,
                                 p_cod_mad_padre in number,
                                 p_fec_mov in date,
                                 p_hor_mov in varchar2,
                                 p_usu_mov in varchar2,
                                 p_nro_cuenta in varchar2
                                ) is
    -- actualiza los datos del control
    procedure lp_act_con_caja ( p_nro_caja_01 in number ) is
    begin
      update cj_controles
         set sal_actual      = nvl(sal_actual,0)      + nvl(v_efectivo,0),
             tot_debitos     = nvl(tot_debitos,0)     + nvl(v_tot_debitos,0),
             tot_creditos    = nvl(tot_creditos,0)    + nvl(v_tot_creditos,0),
             can_debitos     = nvl(can_debitos,0)     - decode(v_tot_debitos,0,0,1),
             can_creditos    = nvl(can_creditos,0)    - decode(v_tot_creditos,0,0,1),
             tot_che_nue_bco = nvl(tot_che_nue_bco,0) + nvl(v_che_nue_bco,0),
             det_che_nue_bco = nvl(det_che_nue_bco,0) - nvl(v_det_nue_bco,0),
             sal_che_otr_bco = nvl(sal_che_otr_bco,0) + nvl(v_che_otr_bco,0),
             tot_che_otr_bco = nvl(tot_che_otr_bco,0) + decode(p_tipo,'D',nvl(v_che_otr_bco,0),0), -- SOLO SI FUE UN INGRESO
             det_che_otr_bco = nvl(det_che_otr_bco,0) - nvl(v_det_otr_bco,0),
             estado          = 1 -- abierto
       where nro_caja   = p_nro_caja_01
         and cod_moneda = p_cod_moneda
         and fecha      = v_fec_caja;
       if sql%notfound then
          v_cod_respuesta := '008';
          v_msj_respuesta := 'No existe Control de Caja';
       end if;
    end lp_act_con_caja;
  begin
      -- inicializo los datos
       v_efectivo      := 0;
       v_che_nue_bco   := 0;
       v_che_otr_bco   := 0;
       v_tot_debitos   := 0;
       v_tot_creditos  := 0;
       v_det_otr_bco   := 0;
       v_det_nue_bco   := 0;
       v_monto         := 0;
       v_cod_moneda    := p_cod_moneda;
       -- Actualizo el control de caja
       if p_tipo = 'D' then  -- es un debito
         v_monto := p_monto * -1;
         if p_tip_monto = 'E' then
            v_tot_debitos := v_monto;
         end if;
       elsif p_tipo = 'C' then  -- es credito
         v_monto := p_monto;
         if p_tip_monto = 'E' then
            v_tot_creditos := v_monto * -1;
         end if;
       end if;
       if p_tip_monto = 'E' then
          v_efectivo := v_monto;
       elsif p_tip_monto = 'C' then
         if p_tipo in ('C','D') then  -- solo si es debito o credito
            v_che_nue_bco := v_monto;
         else
            -- es un detalle de cheques lo que se reversa
            v_det_nue_bco := p_monto;
            -- actualizo la boleta del deposito
            update cj_movimientos a
               set a.tot_detallado = nvl(tot_detallado,0) - nvl(v_det_nue_bco,0)
             where a.nro_documento = p_nro_doc_referencia
               and a.estado = 'N' -- estado normal
               and a.tip_monto = p_tip_monto -- tipo cheque otros bcos
               and a.tipo = 'D' -- ingreso a la caja
               and a.nro_caja = v_nro_caj_princ;
            if sql%notfound then
               v_cod_respuesta := '008';
               v_msj_respuesta := 'No existe boleta para reversar';
            end if;
         end if;

       elsif p_tip_monto in ('O','T','S','X') then
         if p_tipo in ('C','D') then  -- solo si es debito o credito
            v_che_otr_bco := v_monto;
            If p_cod_tra_padre in (359, 362) Then
               delete pr_cob_cuo_otr_bco a
                where a.nro_cuenta = p_nro_cuenta
                  and a.nro_boleta = p_nro_documento
                  and a.estado     = 'C';
            End If;
         else
            -- es un detalle de cheques lo que se reversa
            v_det_otr_bco := p_monto;
            -- actualizo la boleta del deposito
            update cj_movimientos a
               set a.tot_detallado = nvl(tot_detallado,0) - nvl(v_det_otr_bco,0)
             where a.nro_documento = p_nro_doc_referencia
               and a.estado = 'N' -- estado normal
               and a.tip_monto = p_tip_monto -- tipo cheque otros bcos
               and a.tipo = 'D' -- ingreso a la caja
               and a.nro_caja = v_nro_caj_princ;
            if sql%notfound then
               v_cod_respuesta := '008';
               v_msj_respuesta := 'No existe boleta para reversar';
            end if;
            -- borro el cheque
            delete from ge_cheques_det a
             where a.nro_cheque = p_nro_documento
               and a.nro_documento = p_nro_doc_referencia
               and a.fec_ingreso = v_fec_actual
               and a.estado = 'I';
            if sql%notfound then
              delete from cc_che_enviados a
               where a.nro_cheque = p_nro_documento
                 and a.nro_boleta = p_nro_doc_referencia
                 and fecha = v_fec_actual
                 -- 06/06/2025 SE agrega este cambio
                 and ((a.estado = 'I'
                 and a.cod_moneda = 'USD') OR (a.estado IN( 'E','I') and a.cod_moneda = 'GS'));
                 -- fin del cambio
                 --and a.estado = 'I';
                 /*and ((a.estado = 'I'
                 and a.cod_moneda = 'USD') OR (a.estado = 'E' and a.cod_moneda = 'GS'));*/
              if sql%notfound then
                delete from ge_che_exterior a
                 where a.nro_cheque = p_nro_documento
                   and a.nro_boleta = p_nro_doc_referencia
                   and fecha = v_fec_actual
                   and a.estado = 'I';
                if sql%notfound then
                   v_cod_respuesta := '009';
                   v_msj_respuesta := 'El cheque Nro '||to_char(p_nro_documento)||' no se puede Eliminar';
                End if;
              End if;
            end if;
            -->
            if p_cod_tra_padre in (133) Then
              Declare
                 v_cob_prestamo  varchar2(1) := 'N';
                 v_nro_cuenta    cj_movimientos.nro_cuenta%type;
                 v_hora          cj_movimientos.hora%type;
                 v_cod_tra_padre cj_movimientos.cod_tra_padre%type;
              Begin
                   select distinct('S') , a.nro_cuenta, a.hora, a.cod_tra_padre
                     into v_cob_prestamo, v_nro_cuenta, v_hora, v_cod_tra_padre
                     from cj_movimientos a
                    where a.fecha         = p_fec_mov
                      and a.nro_documento = p_nro_doc_referencia
                      and a.cod_tra_padre in (361,359,362)
                      and a.estado        <> 'R';
                    if sql%found Then
                       If v_cod_tra_padre = 361 Then
                           v_msj_salida := fuj_pro_transaccion_200(p_nro_operacion,
                                                                   p_nro_caja,
                                                                   v_cod_tra_padre,
                                                                   p_nro_doc_referencia,
                                                                   v_hora,
                                                                   p_motivo,
                                                                   'S');
                           IF instr(v_msj_salida, '~999~') > 0 THEN
                              v_cod_respuesta := '999';
                           END IF;
                           delete pr_cob_cuo_otr_bco a
                            where a.nro_cuenta = v_nro_cuenta
                              and a.nro_cheque = p_nro_documento
                              and a.nro_boleta = p_nro_doc_referencia
                              and a.estado     = 'C';
                       Else
                           update pr_cob_cuo_otr_bco a
                              set a.nro_cheque = null
                            where a.nro_cuenta = v_nro_cuenta
                              and a.nro_cheque = p_nro_documento
                              and a.nro_boleta = p_nro_doc_referencia
                              and a.estado     = 'C';
                       End If;
                    End IF;
              Exception
                   When no_data_found Then
                        v_cob_prestamo := 'N';
              End;
            End IF;
            -->
         end if;
       end if;
       if v_cod_respuesta = '000' then
           -- Actualiza en CJ_CONTROLES los saldos.
           lp_act_con_caja(v_nro_caj_princ);

           -- actualizo los movimientos reversado
           if p_cod_tra_padre in (358,359,362) or (p_cod_tra_padre = 360 and p_cod_mod_padre <> 9) then
              --buscar nro_sec para q no duplique
              begin
                select nro_secuencia
                into v_nro_secuencia
                from cj_movimientos a
                where a.fecha = v_fec_actual
                and a.hora = p_hora
                and a.nro_caja = v_nro_caj_princ
                and a.cod_tra_padre = p_cod_tra_padre
                and a.nro_secuencia = (select max(nro_secuencia)
                                         from cj_movimientos b
                                        where b.fecha = v_fec_actual
                                          and b.hora = p_hora
                                          and b.nro_caja = v_nro_caj_princ
                                          and b.cod_tra_padre = p_cod_tra_padre);
                if sql%found then
                  v_nro_secuencia := v_nro_secuencia + 1;
                end if;
               exception
                 when no_data_found then
                   v_nro_secuencia := 1;
                 when others then
                   v_cod_respuesta := '999';
                   v_msj_respuesta := 'ERROR al traer.nro.secuencia :'||SQLERRM;
               end;

              --actualiza nro_sec y estado
              update cj_movimientos
                 set estado = 'R',   -- reversado
                     nro_secuencia = v_nro_secuencia
               where rowid = p_rowid;
           else
              update cj_movimientos
                 set estado = 'R' -- reversado
               where rowid = p_rowid;
              --Si es 304, se debe reversar tambien el registro generado en CJ_MOVIMIENTOS con TIPO N= No afecta saldo
              if p_cod_tra_padre = 304 then
                  update cj_movimientos d
                     set d.estado = 'R'
                   where d.fecha         = p_fec_mov
                     and d.hora          = p_hor_mov
                     and d.cod_usuario   = p_usu_mov
                     and d.cod_mod_padre = p_cod_mod_padre
                     and d.cod_mad_padre = p_cod_mad_padre
                     and d.cod_tra_padre = p_cod_tra_padre
                     and d.nro_documento = p_nro_documento
                     and estado          = 'N' --Normal
                     and d.rowid        <> p_rowid;
              end if;
           end if;
       end if;
  end lp_rev_transaccion;
  
  Procedure lp_rev_cobrador_24x7 (P_NRO_CTA_CREDITO in varchar2 ) is 
      v_hor_act_cob ge_movimientos.hor_reversion%type; 
    Cursor cobros_automaticos is
          SELECT A.NRO_CUENTA,A.FEC_MOV_DEB24X7,A.HOR_MOV_DEB24X7,A.COD_USU_DEB24X7,
                 A.COD_MODULO, A.COD_MODALIDAD, A.COD_TRA_PAD_DEB24X7
           FROM GE_CLI_CTA_ATRASOS A
          WHERE A.NRO_CTA_CREDITO = P_NRO_CTA_CREDITO
            AND A.PROCESADO <> 'E'
            AND A.FEC_MOV_DEB24X7 IS NOT NULL 
            AND A.HOR_MOV_DEB24X7 IS NOT NULL 
            AND A.COD_USU_DEB24X7 IS NOT NULL 
           ORDER BY A.HOR_MOV_DEB24X7 ASC;
  Begin
    For cob_aut in cobros_automaticos loop
        if cob_aut.cod_modulo = 6 then
           commit;
           v_hor_act_cob := to_char(sysdate,'HH24:MI:SS');-- Hora actual           
            --Reversar Debito automático de Cobrador 24x7.
            PRG_REV_OPERACION(cob_aut.fec_mov_deb24x7,
                              cob_aut.hor_mov_deb24x7,
                              cob_aut.cod_usu_deb24x7,
                              cob_aut.cod_modulo,
                              cob_aut.cod_modalidad,
                              cob_aut.cod_tra_pad_deb24x7,
                              V_COD_USUARIO,
                              v_hor_act_cob,
                              'N',
                              V_MOTIVO); -- NO ES NOCTURNO
             PRG_ACT_TAB_CTA_ATRASOS(P_NRO_CTA_CREDITO,'S',cob_aut.fec_mov_deb24x7,cob_aut.hor_mov_deb24x7,
                                     cob_aut.cod_usu_deb24x7,cob_aut.cod_tra_pad_deb24x7);                 
        else
           v_cod_respuesta := '008'; -- error
            v_msj_respuesta := 'La Cta. '||cob_aut.nro_cuenta|| ' tiene un cobro automático por atrasos, relacionado a la Cta. de ésta operación.'||chr(10)||
                                'Reverse el cobro automático previamente!';             
        end if;
    End loop;
  End lp_rev_cobrador_24x7;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;

 --DYDMR-1937: ITCAJA - Presiona F2 y no Ocurre Nada - Reversión de Operacion SC 16650
 IF nvl(fug_val_es_numerico(p_motivo),'N') = 'S' THEN
 -- Se realiza La validación debido a que la reversión para los casos en que la funcion es llamada
 -- directamente desde la caja, caso contrario indica que es llamado desde el PAG_RIE, y retorna el concepto del mismo
   BEGIN
     SELECT a.val_minimo ||'-'|| a.significado
       INTO v_motivo
       FROM ba_cod_referencias a
      WHERE a.dominio = 'MOT_REVERSION'
        AND a.val_minimo = p_motivo;
   EXCEPTION
     WHEN OTHERS THEN
       v_cod_respuesta := '001'; -- error
       v_msj_respuesta := 'ERROR: No se encuentra el motivo de la reversion.';
   END;
 ELSE
 -- reversión realiza desde workflow
   v_motivo := p_motivo;
 END IF;



 -- Valido los datos ingresados
 if p_cod_tra_padre is  null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la Transaccion a reversar.';
 elsif p_cod_tra_padre in (201,202,203,204,240,212,211) then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Transaccion no se puede reversar.';
 elsif p_hora is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese la hora de la Operacion. Presione F9 para ver Lista de Operaciones';
 elsif p_motivo is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el motivo de la Reversion.';
 else
    v_nro_caj_princ := to_number(p_nro_caja);
    if p_cod_tra_padre = 304 then
       --Se debe recuperar la caja del movimiento que actualizó saldo.
       lp_obt_nro_caja (v_fec_actual, p_hora, v_cod_usuario, v_nro_caj_princ);
       -- DYDMR-8167 Se agrega el nro de caja, por que no recupera al autorizar
       if nvl(v_nro_caj_princ, 0) = 0 then
          v_nro_caj_princ := to_number(p_nro_caja);
       end if ;
    end if;
    -- verifico previamente si ya fue detallado la operación
    v_cantidad := 0;
    select count(*) into v_cantidad
     from cj_movimientos o
    where nro_caja = v_nro_caj_princ
      and hora = p_hora
      and cod_tra_padre = to_number(p_cod_tra_padre)
      and estado = 'N' -- normal
      and (tot_detallado) > 0
      and ( (cod_moneda = v_cod_mon_local and tip_monto = 'C')
            or (cod_moneda <> v_cod_mon_local)
            or (tip_monto in ('O','S','T','X')
              and exists ( select 0
                             from cj_movimientos m
                            where m.cod_tra_padre = 133
                              and m.estado = 'N'
                              and m.nro_doc_referencia = o.nro_documento 
                and m.nro_caja = v_nro_caj_princ)));

    if v_cantidad > 0 then
       v_cod_respuesta := '008'; -- error, no existe registro de caja
       v_msj_respuesta := 'Operacion ya fue detallada. Reverse los detalles previamente.';
    else
      v_cantidad := 0;
      --WA:10/09/2013 Validamos para Operaciones de Cambio, 246,245,241,242
          select count(*) into v_cantidad
          from cj_movimientos
        where nro_caja = v_nro_caj_princ
      and hora = p_hora
       and cod_tra_padre = to_number(p_cod_tra_padre)
       and estado = 'N' -- normal
       and nvl(tot_detallado,0) > 0
       and (cod_tra_padre in (246,241,242,245) and tip_monto in('O','S','T'));

      if v_cantidad > 0 then
        v_cod_respuesta := '008'; -- error, no existe registro de caja
        v_msj_respuesta := 'Operacion de Cambios ya fue detallada. Reverse los Cheques Cargados previamente.';
      end if;
       v_cantidad := 0;

       /**
       || CRO - Control Dual - Se verifica si existe autorización pendiente
       || Ramon Angel Battaglia - 06/diciembre/2013
       **/
       SELECT COUNT(*)
         INTO v_cantidad
         FROM ge_aut_pedidos
        WHERE fecha = v_fec_actual
          AND hora = p_hora
          AND cod_usuario = fuj_obt_usu_caja(v_nro_caj_princ)
          AND estado = 'S';
       if v_cantidad > 0 then
          v_cod_respuesta := '019';
          v_msj_respuesta := 'Operacion pendiente de Aprobación. Solicite rechazo del pedido de autorización.';
       else
          v_cantidad := 0;



      -- Hago el ciclo por cada registro a reversar ----------------------------
      -- inicio del CICLO GENERAL DE REVERSION----------------------------------
      for cj in cj_movs ( v_nro_caj_princ ) loop
         v_cantidad := v_cantidad + 1;
         v_cod_usu_operacion := cj.cod_usuario;
         v_nro_cuenta := cj.nro_cuenta;
         v_nro_cta_credito := cj.nro_cuenta;
         if v_cantidad = 1 then
            v_nro_documento := cj.nro_documento; -- guardo la operacion de cambios
         end if;
         -- verifico si ya se detallo
         if cj.tot_detallado > 0 and cj.cod_moneda<>v_cod_mon_local and ((cj.tip_monto <> 'O' and cj.cod_moneda=v_cod_mon_local) ) then --verificar retención 1
            v_cod_respuesta := '008'; -- error, no existe registro de caja
            v_msj_respuesta := 'Operacion ya fue detallada. Reverse los detalles previamente.';
         else
           -- Obtengo los datos de la caja ---------------------------------------
           prj_obt_datos_caja(v_nro_caj_princ,
                              cj.cod_moneda,
                              v_cod_oficina,
                              v_fec_caja,
                              v_estado,
                              v_sal_actual,
                              v_sal_cheques,
                              'N');
           if v_estado = -1 then
              v_cod_respuesta := '006'; -- error, no existe registro de caja
              v_msj_respuesta := 'Caja inexistente!!';
           elsif v_estado in (0,2) then  -- error, la caja no esta abierta
              v_cod_respuesta := '003'; -- error
              v_msj_respuesta := 'Caja aun no fue abierta en '||cj.cod_moneda;
           elsif v_estado in (1,3,4) then -- caja
              if v_cod_respuesta = '000' then
                  if nvl(p_autorizado,'N') = 'N' and nvl(v_solicita,'N') = 'N' then --18/09/2013-MB-CRO: Control Dual.
                      begin
                            pag_rie.pr_rev_operacion(v_nro_cuenta,
                                                     v_fec_actual,
                                                     p_hora,
                                                     v_cod_usu_operacion,
                                                     p_cod_tra_padre,
                                                     v_cod_modulo,
                                                     v_cod_modalidad,
                                                     cj.cod_moneda,
                                                     abs(cj.monto),
                                                     v_motivo,
                                                     v_nro_solicitud);
                            v_solicita := 'S';
                      end;
                   End If;
                 if p_cod_tra_padre in (304,354,355) then
                    -- Rerversion del estado del cheque
                    if ((nvl(p_autorizado,'N') = 'S' or nvl(v_nro_solicitud,0) = 0)  -- Se aprobo en el Workflow
                      and cj.nro_cuenta is not null) then  -- para cheques hibridos no guardamos la cta debito 
                       v_msj_respuesta := pac_che.fu_rev_pag_cheque(cj.nro_cuenta,
                                                                    cj.nro_documento,
                                                                    cj.monto,
                                                                    cj.fecha,
                                                                    p_hora);
                       if v_msj_respuesta is not null then
                          v_cod_respuesta := '010';
                          if nvl(p_autorizado,'N') = 'S' then -- Viene del WorkFlow
                             raise_application_error(-20202,'Error reversar cheque:'||v_msj_respuesta);
                          end if;
                       end if;
                    end if;
                 end if;
                 -->>
                 if v_cod_respuesta = '000' then
                   if nvl(v_nro_solicitud,0) = 0 or nvl(p_autorizado,'N') = 'S' then --18/09/2013-MB-CRO: Control Dual.
                        -- No se necesita de Autorización o ya fue Autorizado
                        -- procedo a reversar los movimientos de caja
                        lp_rev_transaccion(cj.rowid             ,
                                           cj.cod_moneda        ,
                                           cj.monto             ,
                                           cj.tipo              ,
                                           cj.tip_monto         ,
                                           cj.nro_doc_referencia,
                                           cj.nro_documento     ,
                                           cj.cod_mod_padre     ,
                                           cj.cod_mad_padre     ,
                                           cj.fecha             ,
                                           cj.hora              ,
                                           cj.cod_usuario       ,
                                           cj.nro_cuenta        );

                   Else
                       v_msj_respuesta := 'Se creó la Solicitud de Autorización de Reversión Número: '||v_nro_solicitud;
                   End If;
              end if;
           end if;
              -->>
           end if;
         end if;
       end loop;
       if v_cantidad = 0 then
          v_cod_respuesta := '009';
          v_msj_respuesta := 'No existen datos a reversar! Caja: '||v_nro_caj_princ||
                             ' Hora: '||p_hora||' Tran: '||p_cod_tra_padre||
                             ' Usu: '||v_cod_usuario;
       end if;
       if p_cod_tra_padre = 218 then
           If nvl(v_nro_solicitud,0) = 0 or nvl(p_autorizado,'N') = 'S' Then --18/09/2013-MB-CRO: Control Dual.
               -- No se necesita de Autorización o ya fue Autorizado.
               -- actualizo el monto como cobrado
               update cc_che_devueltos b
                  set sal_multa = (select mto_pagado from ge_telegramas_det a
                                   where a.nro_cuenta = b.nro_cuenta
                                     and a.nro_cheque = b.nro_cheque
                                     and a.fecha = b.fecha
                                     and a.hora = b.hora
                                     and a.cod_telegrama = v_nro_documento)
                where exists (select 0 from ge_telegramas_det a
                               where a.nro_cuenta = b.nro_cuenta
                                 and a.nro_cheque = b.nro_cheque
                                 and a.fecha = b.fecha
                                 and a.hora = b.hora
                                 and a.cod_telegrama = v_nro_documento);
               -- actualizo los montos cobrados en cheques
               update ge_telegramas_det a
                  set mto_pagado  = 0
                where a.cod_telegrama = v_nro_documento;
        End If;
           End If;
       End If;

     end if;
     if v_cod_respuesta = '000' then
          -- procedo a reversar los movimientos y los saldos y estados de las cuentas
     --!!!!!!!!!VERIFICAR!!!!!!!!!!
     --usuario operacion
        -->>>
        if p_cod_tra_padre in (219,220,222,226) then
           -- operaciones de sofia
           declare
             v_est_dna varchar2(1);
           begin
             select estado
               into v_est_dna
               from ge_movimientos
              where fecha = v_fec_actual
                and cod_usuario = v_cod_usu_operacion
                and hora = p_hora
                and cod_tra_padre = to_number(p_cod_tra_padre)
                and rownum = 1;
             if v_est_dna = 'N' then
                v_cod_respuesta := '017';
                v_msj_respuesta := 'Operacion ya no puede ser reversada. La misma ya fue enviada a la D.N.A.';
             end if;
           exception
             when others then
                v_cod_respuesta := '018';
                v_msj_respuesta := 'Al buscar datos del Movimiento '||sqlerrm;
           end;
        end if;
        -->>>

        if p_cod_tra_padre in (205,210) then --Eliminar/Modificar Registros--
           If nvl(v_nro_solicitud,0) = 0 or nvl(p_autorizado,'N') = 'S' Then --18/09/2013-MB-CRO: Control Dual.
               if p_cod_tra_padre = 205 then     --Enviar Valores en Transito--
                  delete from cj_val_transito a
                   where a.nro_documento = to_number(p_nro_documento);
               else --210-Recibir Valores en Transito--
                  update cj_val_transito a
                     set a.estado = 'E',
                         a.fec_proceso = null,
                         a.nro_caj_proceso = null,
                         a.cod_usu_proceso = null
                   where a.nro_documento = to_number(p_nro_documento);
               end if;
           End If;
        end if;

        if p_cod_tra_padre in (241,242,243,244) then
            -- operaciones retomadas de cambios, debe deshacer lo que se hizo
            -- tomo los datos de la operacion principal
            declare
               v_nro_caja number(4);
            begin
              Select cod_usuario,  hora,  fecha,  cod_moneda,   monto,
                     cod_tip_ope_cambio,  cod_bco_central,  mto_equ_local,
                     b.cod_ofi_cambio, nro_caja
                into v_ope_cod_usuario,  v_ope_hora,  v_ope_fecha,  v_ope_cod_moneda,
                     v_ope_monto, v_ope_tip_operacion, v_ope_cod_bcp,
                     v_ope_mto_mon_local, v_ope_ofi_cambio, v_nro_caja
                from ba_oficinas b, ge_movimientos a
               where nro_documento = v_nro_documento
                 and cod_mod_padre = 7
                 and cod_mad_padre in (71,72,73,74)
                 and reversado = 'N'
                 and a.cod_ofi_origen = b.cod_oficina
                 and a.nro_secuencia = 1
                 and a.nro_caja is not null;
              if v_nro_caja <> v_nro_caj_princ then
                 v_cod_respuesta := '008';
                 v_msj_respuesta := 'Operacion esta registrada en la Caja '||v_nro_caja;
              end if;
            exception
               when no_data_found then
                  v_cod_respuesta := '001';
                  v_msj_respuesta := 'Operacion no registrada';
            end;

            if nvl(v_nro_solicitud,0) = 0 or nvl(p_autorizado,'N') = 'S' then --18/09/2013-MB-CRO: Control Dual.
                --> No se necesita de Autorización o ya fue Autorizado.
                if v_cod_respuesta = '000' then
                   -- actualizo los movimientos a 'N' y las cuentas asociadas a cada movimiento
                   pal_cam.pr_act_movimientos(v_ope_cod_usuario,
                                              v_ope_fecha,
                                              v_ope_hora,
                                              'J',  -- pasa a 'J-pendiente de caja
                                              v_nro_caj_princ);
                   -- actualizo la posicion
                   pal_cam.pr_act_posiciones(v_ope_tip_operacion,
                                             v_ope_cod_moneda,
                                             v_ope_ofi_cambio,
                                             v_ope_monto * -1,
                                             v_ope_mto_mon_local * -1,
                                             v_ope_cod_bcp);
                end if;
                --recupero los datos de la parte de venta del arbitraje/canje para actualizar la posicion
                if p_cod_tra_padre in (243,244) then
                   begin
                     Select cod_usuario,  hora,  fecha,  cod_moneda,   monto,
                            cod_tip_ope_cambio,  cod_bco_central,  mto_equ_local,
                            b.cod_ofi_cambio
                       into v_ope_cod_usuario,  v_ope_hora,  v_ope_fecha,  v_ope_cod_moneda,
                            v_ope_monto, v_ope_tip_operacion, v_ope_cod_bcp,
                            v_ope_mto_mon_local, v_ope_ofi_cambio
                       from ba_oficinas b, ge_movimientos a
                      where nro_documento = v_nro_documento
                        and cod_mod_padre = 7
                        and cod_mad_padre in (73,74)
                        and reversado = 'N'
                        and a.cod_ofi_origen = b.cod_oficina
                        and a.nro_secuencia = 2
                        and a.cod_usuario = v_ope_cod_usuario
                        and a.fecha = v_ope_fecha
                        and a.hora = v_ope_hora;
                   exception
                      when no_data_found then
                         v_cod_respuesta := '001';
                         v_msj_respuesta := 'Operacion no registrada';
                   end;
                   if v_cod_respuesta = '000' then
                     -- actualizo la posición
                     pal_cam.pr_act_posiciones(v_ope_tip_operacion,
                                               v_ope_cod_moneda,
                                               v_ope_ofi_cambio,
                                               v_ope_monto * -1,
                                               v_ope_mto_mon_local * -1,
                                               v_ope_cod_bcp);
                   end if;
                end if;
            End If;
        elsif p_cod_tra_padre = 247 and nvl(p_autorizado,'N') = 'N' then--Retoma de cobro de cargos
          begin
            Select cod_usuario,  hora,  fecha,  cod_moneda, nro_caja
              into v_ope_cod_usuario,  v_ope_hora,  v_ope_fecha,  v_ope_cod_moneda,
                   v_nro_caja
              from ge_movimientos a
             where nro_documento = v_nro_documento
               and cod_tra_padre in (150,323,324,536,309,305)
               and reversado = 'N'
               --and a.nro_secuencia = 1
               and a.nro_caja is not null
               and rownum = 1;
          exception
             when no_data_found then
                begin
                   SELECT nro_documento
                     INTO v_nro_doc_original
                     FROM ge_aut_reversiones b
                    WHERE b.nro_pedido = v_nro_solicitud;
                exception
                   when no_data_found then
                      v_nro_doc_original := null;
                end;
                begin
                  Select cod_usuario,  hora,  fecha,  cod_moneda, nro_caja
                    into v_ope_cod_usuario,  v_ope_hora,  v_ope_fecha,  v_ope_cod_moneda,
                         v_nro_caja
                    from ge_movimientos a
                   where nro_documento = v_nro_doc_original
                     and reversado = 'N'
                     --and a.nro_secuencia = 1
                     and a.nro_caja is not null
                     and rownum = 1;
                exception
                   when no_data_found then
                      v_cod_respuesta := '001';
                      v_msj_respuesta := 'Operacion no registrada';
                end;
          end;
          if v_nro_caja is not null and v_nro_caja <> v_nro_caj_princ then
             v_cod_respuesta := '008';
             v_msj_respuesta := 'Operacion esta registrada en la Caja '||v_nro_caja;
          end if;

          if nvl(v_nro_solicitud,0) = 0 or nvl(p_autorizado,'N') = 'S' then --18/09/2013-MB-CRO: Control Dual.
              --> No se necesita de Autorización o ya fue Autorizado.
              if v_cod_respuesta = '000' then
                -- actualizo los movimientos a 'N' y las cuentas asociadas a cada movimiento
                pal_cam.pr_act_movimientos(v_ope_cod_usuario,
                                           v_ope_fecha,
                                           v_ope_hora,
                                           'J',  -- pasa a 'J-pendiente de caja
                                           v_nro_caj_princ);
              end if;
          End If;
        else
            if nvl(v_nro_solicitud,0) = 0 or nvl(p_autorizado,'N') = 'S' then --18/09/2013-MB-CRO: Control Dual.
              IF p_cod_tra_padre = 247 and nvl(p_autorizado,'N') = 'S' THEN -- DYDMR-45. CB. 26/03/2014
                BEGIN
                  Select cod_usuario,  hora,  fecha
                    into v_ope_cod_usuario,  v_ope_hora,  v_ope_fecha
                    from ge_movimientos a
                   where nro_documento = v_nro_documento
                     and cod_tra_padre in (150,323,324,536,309,305)
                     and reversado = 'N'
                     and a.nro_caja is not null
                     and rownum = 1;
                     --> No se necesita de Autorización o ya fue Autorizado.
                     prg_rev_operacion(v_ope_fecha,
                                       v_ope_hora,
                                       v_ope_cod_usuario,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       p_cod_tra_padre,
                                       v_cod_usuario,
                                       v_hor_actual,
                                       'N',
                                       v_motivo); -- No es nocturno
                EXCEPTION
                  WHEN no_data_found THEN
                    v_cod_respuesta := '001';
                    v_msj_respuesta := 'Operacion no registrada';
                END;
              ELSE
                --> No se necesita de Autorización o ya fue Autorizado.
                prg_rev_operacion(v_fec_actual,
                                  p_hora,
                                  v_cod_usu_operacion,
                                  v_cod_modulo,
                                  v_cod_modalidad,
                                  p_cod_tra_padre,
                                  v_cod_usuario,
                                  v_hor_actual,
                                  'N',
                                  v_motivo); -- No es nocturno
              END IF;
            END IF;
        end if;
      end if;
      if p_cod_tra_padre in (371,372) then
        update ge_rec_movimientos a
           set a.estado = 'R'
         where a.fec_operacion = v_fec_actual
           and a.nro_operacion = p_nro_documento
           and a.hora = p_hora;
      end if;
    /*VERIFICO SI EL MOVIMIENTO A REVERSAR TIENE DEBITOS AUTOMÁTICOS POR CTAS CON ATRASOS*/
    IF FUP_EXI_GRU_TRANSAC(201,p_cod_tra_padre,v_cod_modulo, v_cod_modalidad) = 'S' then
       v_can_cob_24x7 := 0;
       Begin
         Select count(1)
          into v_can_cob_24x7
           from ge_movimientos t
          where t.nro_cuenta =v_nro_cta_credito
            and t.cod_tra_padre in (364,186) -- Cobro de Prestamos o Tarjetas
            and t.cod_transaccion = 503
            and t.reversado = 'N';
       Exception 
         when too_many_rows then 
             v_can_cob_24x7 := 1;
         when others then    
             v_can_cob_24x7 := 0; 
       End;
       if v_can_cob_24x7 > 0 then
          lp_rev_cobrador_24x7(v_nro_cta_credito);               
       end if;
    END IF; 
      --
  end if;
  /* armo finalmente el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'Operacion reversada');
  return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_200;
/

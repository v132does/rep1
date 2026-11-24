CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_355 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja  in varchar2,       -- Nro de Caja
      p_nro_boleta in varchar2,      -- Nro de la boleta
      p_nro_cheque in varchar2,      -- Nro de cheque
      p_nro_cuenta in varchar2,      -- Nro de cuenta del cliente
      p_importe in varchar2,         -- Importe de la extraccion
      p_serie in cc_chequeras.serie%type default null, --BBVADES-3137
      p_hora in varchar2 default null, --hora del movimiento
      p_opcion  in varchar2 default null)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3)      := 9;    -- Caja
  v_cod_modalidad number(3)   := 91;   -- Caja
  v_cod_transaccion number(4) := 355;  -- transaccion
  v_cod_usuario varchar2(10)  := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  --v_hor_actual        varchar2(08) := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));   -- Hora actual
  v_hor_actual        varchar2(08);
  v_cod_oficina       number(3);         -- Codigo de oficina
  v_estado            number(1);         -- estado de la caja
  v_fec_caja          date;              -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);          -- saldo actual de la caja en cheques
  -- Datos de la cuenta
  v_denominacion      varchar2(200);     -- Nombre de la cuenta
  v_cod_moneda        varchar2(3);       -- moneda de la cuenta
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
  v_msj_respuesta varchar2(4000) := 'Operacion Confirmada'; -- sin errores
  v_error varchar2(4000);
  -- datos de la operacion convertidos
  v_tipo          varchar2(01) := 'N';  -- no afecta al saldo
  v_tip_monto     varchar2(01) := 'C';  -- cheque ntro bco
  --DYDMR-2403 ITGF -Deposito de Cheque en Custodia - Error Conversi¿n de Car¿cter a N¿mero Num¿rico o de Valor SC 20293
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
  --Notificaciones Fase 3
  v_ret          NUMBER(3) := 0;
  -- C.D Fase III --
  v_tip_operacion   ge_mov_autorizaciones.tip_operacion%type := 'O';-- Todos Tipos Operacional
  --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
  v_cod_mod_cuenta     number(6);
  v_cod_mad_cuenta     number(6);
  v_nvo_estado         varchar2(1);
  v_sal_disponible     number;
  v_procesa            varchar2(1);
  v_msj_autorizacion   varchar2(300) := null;
  v_sal_linea          cc_cta_corrientes.sal_total%type;
  v_est_movimiento     ge_movimientos.estado%type;
  v_sal_combinada      cc_cta_corrientes.sal_total%type;
  v_usu_autorizador    ba_usuarios.cod_usuario%type;
  v_nro_pedido         ge_mov_autorizaciones.nro_pedido%type;
  -- RE DE-567
  v_insert BOOLEAN;
  -- CROPCFCS-1 --
  v_ban_inhibidos      Varchar2(1) := fuc_ver_fir_inhibidos(p_nro_cuenta);
  --
  v_cod_res_btw varchar2(30);
  v_msj_res_btw varchar2(100);
  v_pro_che_btw     char(1):= 'N';
  v_es_che_btw     char(1):= 'N';
  v_es_onp         char(1):= 'N';
  v_hab_che_hib    char(1):= fug_obt_pardinamico('HAB_CHE_HIBRIDOS');
  v_cta_can        char(1):= 'N';
  v_cod_causa      number(3);
  v_cod_rubro ge_movimientos.cod_rubro%type;
  r_gmovi     ge_movimientos%rowtype;
  v_cotizacion ge_movimientos.cotizacion%type;
  v_redondeo  number(5);
  v_tip_autorizacion ge_aut_pedidos.tip_autorizacion%type := 'T';
  v_can_ope          number(3):=0; 
  --Rechazo automatico
  v_rec_aut         varchar2(1);
  v_cod_cau_rechazo varchar2(10);
  v_des_cau_rechazo varchar2(100);
  v_sec_rechazados  number(10):= -999;
  v_sec_rechazados_out  number(10);
  v_nro_lote        number(10);
  v_tip_importe     varchar2(10);
  rp_rch_aut        cc_che_rec_automaticos%ROWTYPE;
  v_texto           VARCHAR2(100);
  --Sobregiro Cta.Cte.
  v_opcion          varchar2(10);
  v_opc_rta         varchar2(200);
  v_opc_importe     varchar2(30);
  v_opc_nro_cta     varchar2(50);
  v_cod_opcion      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC');  
  
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion (p_estado varchar2) is
  begin
      -- Actualizo el control de caja
     if p_estado <> 'P' then -- C.D.Fase III
        update cj_controles
           set det_che_nue_bco = nvl(det_che_nue_bco,0) +  nvl(v_importe,0),
               estado = 1 -- abierto
         where nro_caja = to_number(p_nro_caja)
           and cod_moneda = v_cod_moneda
           and fecha = v_fec_caja;
     end if;

     if v_es_che_btw = 'N' then -- si no es cheque de BanTotal
        -- genero el movimiento por la extraccion
        insert into cj_movimientos
           (fecha, hora, cod_usuario, nro_secuencia,
            cod_tra_padre, cod_mod_padre, cod_mad_padre,
            cod_oficina, cod_moneda, nro_caja, nro_doc_referencia,
            nro_documento, nro_cuenta, monto, tip_monto, tipo, estado,/* C.D.Fase 3*/
        nro_ref_externo) --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicaci¿n Externa.-
        values
           (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
            v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
            v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
            p_nro_boleta,
            p_nro_cheque, nvl(v_nro_cta_certificado,p_nro_cuenta),
            v_importe,v_tip_monto /* no afecta */, v_tipo/* es credito */, p_estado, /* C.D.Fase 3*/
        p_nro_operacion);
     else -- si es cheque de Bantotal
      -- genero el movimiento por el debito en el rubro puente.
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja, nro_doc_referencia,
          nro_documento, nro_cuenta, monto, tip_monto, tipo, estado,/* C.D.Fase 3*/
          nro_ref_externo, --> CRO-FACPOD: Para Almacenar la respuesta de la Aplicaci¿n Externa.-
          cod_rubro)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          p_nro_boleta,
          p_nro_cheque, null /*nro_cuenta*/,
          v_importe,v_tip_monto /* no afecta */, v_tipo/* es credito */, p_estado, /* C.D.Fase 3*/
          p_nro_operacion,
          v_cod_rubro);
    end if;
  end lp_gen_transaccion;

  --
    procedure lp_act_can_impresion is -- C.D.Fase III--
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


begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
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
 --valido p_hora
 if p_hora is not null then
   begin
    select to_char(p_hora,'HH24:MI:SS')
    into   v_hor_actual
    from   dual;
   exception
     when others then
       v_hor_actual := to_char(sysdate,'HH24:MI:SS');
   end;
 else
   v_hor_actual := to_char(sysdate,'HH24:MI:SS');-- Hora actual
 end if;
 -- se extrae la opcion SI/NO seleccionada
 v_opcion := substr(p_opcion, 1, 2);
 -- se extrae el nro de cta
  if (instr(p_opcion, '{', 1, 1) > 0) then
    v_opc_nro_cta := substr(p_opcion,
                            instr(p_opcion, '{', 1, 1) + 1,
                            (instr(p_opcion, '}', 1, 1) - 1) -
                            instr(p_opcion, '{', 1, 1));
  end if;
  -- se extrae el importe
  if (instr(p_opcion, '{', 1, 2) > 0) then
    v_opc_importe := substr(p_opcion,
                            instr(p_opcion, '{', 1, 2) + 1,
                            (instr(p_opcion, '}', 1, 2) - 1) -
                            instr(p_opcion, '{', 1, 2));
  end if;
   
 if v_cod_respuesta = '000' then -- sin errores
    begin
      --CROEFEBCO-28: Mejoras en la Operativa de Efectivo; Se captura el estado del movimiento las operaciones ingresadas por el TAS
    -- ya que estas tambi¿n se deben liberar o solicitar confirmaci¿n.-
        select a.cod_moneda Moneda, nvl(a.monto,0), nvl(a.tot_detallado,0), a.nro_cuenta,
               a.tip_monto, rowid,
               a.fecha, a.hora, a.cod_usuario, cod_tra_padre, estado
          into v_cod_mon_dep, v_imp_total, v_imp_detalle, v_nro_cta_dep,
               v_tip_monto, v_rowid,
               v_fecha_mvto, v_hora_mvto, v_cod_usu_mvto, v_cod_tra_padre, v_est_movimiento
          from cj_movimientos a
         where a.estado in ('X', 'N') -- estado normal ¿ operaciones ingresadas por TAS
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
        v_msj_respuesta := 'ERROR: Boleta no registrada en el sistema o ya fue detallada*!';
      when too_many_rows then
        v_cod_respuesta := '003';
        v_msj_respuesta := 'ERROR: Boleta duplicada!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
    --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
  if v_est_movimiento = 'X' then --Movimiento pendiente de confirmaci¿n.
        v_cod_respuesta := '003';
        v_msj_respuesta := 'Para detallar debe confirmar esta boleta';
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas
      -- veo si el importe detallado esta dentro del limite
       if v_importe > v_imp_total - v_imp_detalle then
           v_cod_respuesta := '004';
           v_msj_respuesta := 'ERROR: Monto detallado ya supera al Total deposito!';
       end if;
    end if;
    if v_cod_respuesta = '000' then -- sino hubo problemas
      -- obtengo datos de la cuenta  ------------------------------------------
      begin
        select denominacion, cod_moneda, estado, cod_modalidad
          into v_denominacion, v_cod_moneda, v_est_cuenta, v_tip_cuenta
          from ge_cuentas a
         where a.nro_cuenta = p_nro_cuenta;
        if v_tip_cuenta not in (41,42,43,44,45) then
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
          if v_cod_respuesta = '000' then
             v_msj_respuesta := fuj_ver_impedimentos(p_nro_cuenta,
                                                     v_tip_cuenta,
                                                     v_cod_transaccion,
                                                     v_est_cuenta,
                                                     'D'); -- 'D'== DEBITO EN CUENTA
             --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
             if v_msj_respuesta is not null and v_est_cuenta not in ('C','P','T') THEN
                v_cod_respuesta := '004';  -- la cuenta tiene impedimentos
             end if;
          end if;
        end if;
      exception
        when no_data_found then
          -- si no existe en ge_cuentas va y busca en BT
          if fug_obt_pardinamico('HAB_CHE_HIBRIDOS') = 'S' then
             begin
               v_cod_moneda := v_cod_mon_dep;  -- setamos este valor
               v_cod_rubro := fug_obt_pardinamico('COD_RUB_DEP_BTW',null,null,v_cod_mon_dep,null,null);
               
               Select COUNT(*) into v_can_ope
                  from cj_movimientos
                where nro_caja = p_nro_caja
                  and cod_tra_padre = v_cod_transaccion 
                  and cod_moneda = v_cod_mon_dep
                  and nro_documento = p_nro_cheque
                  and nro_doc_referencia = p_nro_boleta
                  and estado <> 'R';
               
               if v_can_ope = 0 then
                 pag_btw.pr_val_che_btw(p_nro_cuenta, p_nro_cheque, v_cod_mon_dep, p_importe,'V', p_nro_caja, v_cod_res_btw, v_msj_res_btw,v_pro_che_btw);
                 if upper(v_msj_res_btw) like '%ORDEN%NO%PAGO%' then
                   v_es_onp :='S';
                   v_cod_causa := 128;
                 end if;

                 if upper(v_msj_res_btw) like '%CUENTA%CANCELADA%' then
                   v_cta_can :='S';
                   v_cod_causa :=  107;
                 end if;
                 --- si la validacion es Ok, entonces confirmamos
                 if (v_pro_che_btw ='S' or (v_pro_che_btw = 'N' and v_es_onp='S') ) then
                    v_pro_che_btw := 'N'; ---
                    -- invocamos al proceso que confirma el cheque en BT
                    if v_es_onp='S' then 
                       pag_btw.pr_pro_che_btw(p_nro_cuenta, p_nro_cheque, v_cod_mon_dep, p_importe,'D', p_nro_caja,v_cod_res_btw, v_msj_res_btw, v_pro_che_btw, 128);
                    else
                       pag_btw.pr_pro_che_btw(p_nro_cuenta, p_nro_cheque, v_cod_mon_dep, p_importe,'C', p_nro_caja,v_cod_res_btw, v_msj_res_btw, v_pro_che_btw);
                    end if;   
                    -- si el proceso de confirmacion me responde P, significa que va quedar P de confimacion
                    if v_pro_che_btw = 'S' then
                      v_es_che_btw :='S';
                      v_est_movimiento := 'N';
                      v_msj_respuesta :=  v_msj_respuesta ||'-'||v_msj_res_btw;
                    elsif v_pro_che_btw = 'P' then
                       v_tip_autorizacion := 'H';  --- hibrido
                       v_est_movimiento   := 'X';
                       v_msj_autorizacion := v_msj_res_btw;
                       v_es_che_btw :='S';
                    elsif v_pro_che_btw = 'N' then
                       v_cod_respuesta := '011';
                       v_msj_respuesta := v_msj_res_btw;
                    else
                       v_cod_respuesta := '013';
                       v_msj_respuesta := nvl(v_msj_res_btw,'Ha ocurrido un error inesperado al confirmar en BT.');
                    end if;
                 else
                    -- la validacion respondio con error y es ONP o CTA Cancelada igual se procesa
                    if v_pro_che_btw = 'N' and (v_es_onp ='S' or v_cta_can='S') then
                       v_pro_che_btw :='S';
                       v_es_che_btw :='S';
                    else
                      v_cod_respuesta := '012';
                      v_msj_respuesta := nvl(v_msj_res_btw,'Ha ocurrido un error inesperado.');
                      pag_btw.pr_ins_log_btw(p_nro_cuenta, p_nro_cheque, p_importe, 'C', p_nro_caja,
                           v_pro_che_btw, null, v_cod_respuesta, v_msj_res_btw, sqlerrm);
                    end if;
                 end if;
              else
                  v_cod_respuesta := '017';
                  v_msj_respuesta := nvl(v_msj_res_btw,'El cheque '||p_nro_cheque||' ya fue detallado.');
                   pag_btw.pr_ins_log_btw(p_nro_cuenta, p_nro_cheque, p_importe, 'C', p_nro_caja,
                           v_pro_che_btw, null, v_cod_respuesta, v_msj_res_btw, v_msj_respuesta);
              end if;     
            exception
              when others then
                  v_cod_respuesta := '015';
                  v_msj_respuesta := sqlerrm;
                   pag_btw.pr_ins_log_btw(p_nro_cuenta, p_nro_cheque, p_importe, 'C', p_nro_caja,
                           v_pro_che_btw, null, v_cod_respuesta, v_msj_res_btw, v_msj_respuesta);
            end;
          else -- si no esta habilitado cheques hibridos sale por el no data found de ge_cuentas  
            v_es_che_btw    := 'N';
            v_cod_respuesta := '002';
            v_msj_respuesta := 'ERROR: Nro de cuenta no existe!';
          end if;  
        when others then
          v_cod_respuesta := '003';
          v_msj_respuesta := 'ERROR' || sqlerrm;
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
    if v_cod_respuesta = '000' and v_es_che_btw ='N' THEN -- sino hubo errores veo el cheque
       v_est_anterior := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                                  p_nro_cheque,
                                                  'P',  -- quiero pagar
                                                  v_importe,
                                                  v_nro_che_inicial,
                                                  v_msj_respuesta,
                                                  v_nro_cta_certificado,
                                                  p_serie); --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
       if v_msj_respuesta is not null then
          if v_est_anterior <> 'O' then
             v_cod_respuesta := '009';
          else
            -- Verifico la duplicacion del registro
             prj_val_duplicacion(p_nro_caja,
                                    131,
                                    v_cod_moneda,
                                    p_nro_cheque,
                                    v_cod_respuesta,
                                    v_msj_respuesta);
          end if;
       end if;
    end if;

    if v_cod_respuesta = '000' and v_es_che_btw ='N' THEN
       -- verifico los decimales del importe
      v_msj_respuesta := fuj_val_importe(v_tipo, v_tip_monto,v_cod_moneda,v_importe);

       if v_msj_respuesta is not NULL AND v_msj_respuesta != 'Cuenta Cancelada' THEN --RE DE-567 25/06/2015
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
          pag_cta.PR_SET_EST_MOVIMIENTO('N'); --> DYDMR-3194: Se Limpia Variable Global
         --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
             if v_est_cuenta not in ('P','C','T')  THEN
            --- IF v_est_anterior != 'O' then -- solo si la cuenta no esta cancelada o el cheque no tiene orden de NO pago.--RE DE-567 09/07/2015 se coment¿ para que deje pasar los cheques con ONP
                 v_sal_linea := fuc_obt_mto_lin_sob(nvl(v_nro_cta_certificado,p_nro_cuenta));
                 -- Si es dep¿sito en Cta. y la Libradora tiene saldo suficiente debe liberar autom¿ticamente.-
                 pag_cta.pr_ver_operacion(nvl(v_nro_cta_certificado,p_nro_cuenta),
                                               v_cod_transaccion,
                                               v_cod_modulo,
                                               v_cod_modalidad,
                                               'D',
                                               v_cod_moneda,
                                               v_importe,
                                               v_cod_oficina,
                                               v_cod_mod_cuenta,
                                               v_cod_mad_cuenta,
                                               v_nvo_estado,
                                               v_sal_disponible,
                                               v_procesa,
                                               591);
                 if pag_cta.g_ctas.cta_combinada = 'S' then
                    v_sal_combinada := pag_cta.g_ctas.sal_dis_combinada;
                 End If;
                 If v_cod_tra_padre not in (219,220,222) Then -- Para aduanas se mantiene el proceso actual
                    IF v_est_anterior != 'O' THEN --DE-567 19/08/2015 solo verificar si es diferente a cheque con ONP
                      If ( (v_procesa = 'N'
                            and pag_cta.g_cod_error in (25,29)
                            and (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_importe,0))
                          or (pag_cta.g_ctas.cod_autorizacion is null and (nvl(v_sal_disponible,0) + nvl(v_sal_linea,0) + nvl(v_sal_combinada,0)) < nvl(v_importe,0))) Then

                         -- problemas de saldo insuficiente
                         pag_cta.PR_SET_EST_MOVIMIENTO('X');
                         pag_cta.g_sobregira := 'S';
                         v_cod_respuesta := '000';
                         IF ((nvl(v_opcion, 'NO') = 'SI') and
                             (nvl(v_opc_nro_cta, 'N') = p_nro_cuenta) and
                             (nvl(v_opc_importe, 'N') = p_importe)) THEN
                           v_msj_autorizacion := 'Solicitud de Autorizacion por Sobregiro generada.';
                         ELSE
                           --v_msj_autorizacion := 'Cuenta '||nvl(v_nro_cta_certificado,p_nro_cuenta)||' requiere Autorizacion por Sobregiro.';
                           -- a confirmar por el usuario.
                           v_opc_rta       := '[¿?{'||p_nro_cuenta||'}{'||v_importe||'}]';
                           v_cod_respuesta := v_cod_opcion;--'777';
                           v_msj_respuesta := 'Desea solicitar Autorizacion por Sobregiro para la Cuenta: '||
                                               nvl(v_nro_cta_certificado,p_nro_cuenta)||
                                               '?.{OPCION}' ||v_opc_rta; -- entre {} el campo correspondiente al campo de opcion.
                         END IF; 
                      End If;
                    END IF;
                 end if;
                 --CROEFEBCO-28: Mejoras en la Operativa de Efectivo: Lo que estaba en la l¿nea 198 se trae aqui.-
                 If v_cod_respuesta = '000' Then
                    -- actualiza el cheque
                    v_msj_respuesta := pac_che.fu_act_pag_che(p_nro_cuenta,
                                                              p_nro_cheque,
                                                              v_importe,
                                                              v_cod_usuario,
                                                              v_fec_actual,
                                                              v_hor_actual,
                                                              to_number(p_nro_caja),
                                                              v_cod_banco,
                                                              v_cod_transaccion,
                                                              v_cod_moneda,
                                                              v_cod_oficina,
                                                              v_cod_modulo,
                                                              v_cod_modalidad,
                                                              p_serie);
                     If v_msj_respuesta is not null AND v_msj_respuesta != 'Cuenta Cancelada' THEN --RE DE-567 25/06/2015
                        v_cod_respuesta := '005';  -- error
                     End If;
                 End IF;

              -- end if;
             end if;
          /* C.D.Fase III*/
        --CROEFEBCO-28: Mejoras en la Operativa de Efectivo: Cuando va sobregirar no debe ir al WorkFlow, solicitaron que sea confirmaci¿n de Sobregiro.-
          IF nvl(pae_cnf.G_PROGRAMA,'X') not in ( 'CMDEPNBC','GMCONNBC')
             and v_msj_autorizacion      is null
             and v_cod_respuesta         = '000'
             and nvl(v_ban_inhibidos,'X') <> 'S' THEN -- Para que no genere un Pedido de Autorizaci¿n si la funci¿n es llamada desde ITGF
             --RE 22/10/2015. No debe insertar en el workflow si es una cuenta cancelada o el cheque tiene ONP
             IF v_est_anterior != 'O' THEN
                 IF v_est_cuenta not in ('P','C','T') THEN
                    PAG_RIE.PR_OPE_RIESGO(v_fec_actual     ,
                                          v_hor_actual     ,
                                          v_cod_usuario    ,
                                          v_cod_transaccion, -- transacci¿n padre
                                          v_cod_modulo     , -- M¿dulo
                                          v_cod_modalidad  , -- Modalidad
                                          p_nro_cuenta     , -- Nro_cuena
                                          null             , -- Persona
                                          v_tip_operacion  , -- Tip_operacion
                                          v_importe        , -- Monto
                                          null             , -- N¿mero de Documento
                                          v_cod_moneda     , -- Moneda
                                          null             , -- Cotizaci¿n
                                          v_nro_pedido     );
                 END IF;
             END IF;

          END IF;
          If v_msj_autorizacion is null and nvl(v_nro_pedido,0) = 0 and v_cod_respuesta = '000' AND v_est_cuenta not in ('P','C','T') THEN
              pra_lib_retencion( v_nro_cta_dep, null, null, 'S', p_nro_boleta,v_importe,v_hor_actual);--14/11/14 VV. Actualizar Saldo Retenido correctamente
          End If;
          if nvl(v_nro_pedido,0) > 0 then
              v_est_movimiento := 'P';
              pag_cta.pr_set_est_movimiento('P');-- Para que vaya a Saldo Bloqueado si se genera un Circuito de WK
          else
              v_est_movimiento := 'N';
          end if;
          --CROPCFCS-1: Si el cliente esta Inhibido por la Ley 3711, debe generar autorizaci¿n y el movimiento debe quedar pendiente.-
          --if fuc_ver_fir_inhibidos(p_nro_cuenta) = 'S' then
          --DYDMR-3087: Cuando el cheque tiene orden de NO pago, deja el movimiento pendiente y no genera una autorizaci¿n. La operaci¿n se debe concretar sin dejar pendiente
          If NVL(v_ban_inhibidos,'X') = 'S' and v_est_cuenta not in ('P','C','T')  Then
             v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                                    p_nro_cheque,
                                                    v_error     ,
                                                    p_serie     );
             If v_error is not null Then
                 v_msj_respuesta := v_error;
             End If;
             If v_est_cheque <> 'O' Then --> Si el cheque tiene Orden de no pago debe procesar normalmente sin dejar pendiente
                pag_cta.PR_SET_EST_MOVIMIENTO('X');
                v_est_movimiento := 'X';
             End IF;
          End If;
          if v_cod_respuesta = '000' THEN
              -- Asigno el nro de caja a los movimientos
              pag_cta.pr_nro_caja(to_number(p_nro_caja));
              -- Si genera autorizaci¿n por sobregiro y no entra entre los valores de Control Dual
              -- el estado del movimiento de ser "X" porque se debe aprobar de la pantalla de GMAPRAUT
              If v_msj_autorizacion is not null and nvl(v_nro_pedido,0) = 0 Then
                 v_est_movimiento := null;
              End If;
              -- Actualiza la operacion en la base
              pag_cta.pr_act_operacion(nvl(v_nro_cta_certificado,p_nro_cuenta),
                                       v_hor_actual,
                                       'D', -- debito a la cuenta del cliente
                                       v_cod_moneda,
                                       v_importe,
                                       v_cod_transaccion,
                                       591, -- trans. hijo
                                       p_nro_cheque,
                                       null, -- cotizacion
                                       v_cod_oficina,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       null, -- tasa
                                       null, -- valor de tasa
                                       'Detalle de Cheque en Caja', --concepto
                                       'N', -- emitir aviso
                                       v_nro_secuencia, -- nro de secuencia
                                       v_fec_actual, null, null, null, v_est_movimiento);-- C.D.Fase III
              if pag_cta.g_cod_error <> 0 then
                 -- actualizacion con problemas
                 v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
                 v_msj_respuesta := pag_cta.g_msj_error;
              else -- genero la transaccion en caja
                 -- actualizo el total detallado en la boleta del deposito
                 -- C.D.Fase III -- El monto detallado ya debe ir actualizando para que el cajero pueda visualizar si existen varios cheques
                 update cj_movimientos
                    set tot_detallado = nvl(tot_detallado,0) + nvl(v_importe,0)
                  where rowid = v_rowid;
                 if  nvl(v_nro_pedido,0) = 0 then /*C.D.Fase 3 Si se genera un pedido de autorizaci¿n no debe actualizar el campo hasta que se autorice*/
                 update ah_retenciones
                    set detallado = 'S'
                  where cod_ofi_origen   = v_cod_oficina
                   and nro_documento = to_number(p_nro_boleta)
                   and cod_retencion in (0,8)
                   and cod_moneda    = v_cod_moneda;
                    lp_gen_transaccion('N');-- C.D.Fase III
                 else
                    lp_gen_transaccion('P');-- C.D.Fase III
                 end if;
              end if;
              --Notificaciones Fase 3
              v_ret := paw_not.fu_che_pag_girado(p_nro_cuenta,p_nro_cheque,v_importe,v_cod_moneda,'S',v_fec_actual);
           end if;
       end if;
    elsif v_cod_respuesta = '000' and v_es_che_btw ='S' then
       If  v_pro_che_btw in ('S','P') and nvl(v_es_onp,'N') = 'N' and nvl(v_cta_can,'N') ='N' THEN
            -- se hace el debito del rubro transitorio
            v_nro_secuencia := v_nro_secuencia +1;
            begin
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := 4;
              r_gmovi.cod_modalidad   := 41;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := v_cod_transaccion;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              --
              r_gmovi.cod_transaccion := 691;
              --r_gmovi.cod_rubro       := v_cod_rubro;
              --r_gmovi.tip_mov_rubro   := 'D';
              --
              r_gmovi.monto           := v_importe;
              r_gmovi.nro_documento   := p_nro_cheque;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;  -- confirmar
              r_gmovi.emi_aviso       := 'N';
              ---
              if nvl(v_es_onp,'N') = 'N' and nvl(v_cta_can,'N') = 'N' then
                r_gmovi.concepto      := 'Detalle Cheque GNBPY '||p_nro_cuenta;
              elsif nvl(v_es_onp,'N') = 'S' then
                r_gmovi.concepto      := 'Detalle Cheque GNBPY ONP '||p_nro_cuenta;
              elsif nvl(v_cta_can,'N') = 'S' then  
                r_gmovi.concepto      := 'Detalle Cheque GNBPY Cta.Cancelada '||p_nro_cuenta;
              end if;  
              ---
              r_gmovi.estado          := nvl(v_est_movimiento,'N');
              r_gmovi.reversado       := 'N';
              r_gmovi.referencia      := p_nro_cuenta;
              r_gmovi.nro_caja        := p_nro_caja;
              ---
              if v_cod_moneda <>  pag_gen.FU_OBT_MON_LOCAL then
                 v_cotizacion := nvl(pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual),2);
                 --
                 r_gmovi.cotizacion := v_cotizacion;
                 r_gmovi.mto_equ_local := round(nvl(v_importe,0) * nvl(v_cotizacion,0), 0);
              else
                 r_gmovi.mto_equ_local := null;
              end if;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           exception
             when others then
               v_error := sqlerrm;
               v_cod_respuesta := '014'; --ltrim(to_char(pag_cta.g_cod_error,'000'));
               v_msj_respuesta := substr(v_error, 1,200);
               pag_btw.pr_ins_log_btw(p_nro_cuenta, p_nro_cheque, p_importe, 'C', p_nro_caja,
                   v_pro_che_btw, null, v_cod_respuesta, v_msj_res_btw, v_error);

           end;
           ----
           if v_cod_respuesta = '000' then
             begin
               update cj_movimientos
                   set tot_detallado = nvl(tot_detallado,0) + nvl(v_importe,0)
                where rowid = v_rowid;
               
               --- si no queda pend de autorizacion liberamos la porcion que corresponde a este cheqe
               if v_msj_autorizacion is null then
                  pra_lib_retencion( v_nro_cta_dep, null, null, 'S', p_nro_boleta,v_importe,v_hor_actual);--14/11/14 VV. Actualizar Saldo Retenido correctamente
               end if;
              

               update ah_retenciones
                  set detallado = 'S'
                where cod_ofi_origen   = v_cod_oficina
                 and nro_documento = to_number(p_nro_boleta)
                 and cod_retencion in (0,8)
                 and cod_moneda    = v_cod_moneda;
                 -- genera la transaccion en cj_movimientos
                 lp_gen_transaccion('N');

                 -- inserta tabla de cheques hibridos
                 pag_btw.pr_ins_che_hibridos(v_fec_actual, v_hor_actual, v_cod_usuario,
                                             p_nro_cuenta, p_nro_cheque, v_cod_moneda,
                                             p_importe, p_nro_caja, v_pro_che_btw);
                                             
             exception
                when others then
                   v_error := sqlerrm;
                   v_cod_respuesta := '016'; --ltrim(to_char(pag_cta.g_cod_error,'000'));
                   v_msj_respuesta := substr(v_error, 1,200);
                   pag_btw.pr_ins_log_btw(p_nro_cuenta, p_nro_cheque, p_importe, 'C', p_nro_caja,
                       v_pro_che_btw, null, v_cod_respuesta, v_msj_res_btw, v_error);

             end;
          end if;   
       else
         -- si es un cheque ONP o cuenta Cancelada insertamos con la transaccion 691 que afecta
         -- transitorio camara interna y transitorio cheques hibridos
         if v_pro_che_btw ='S' and v_es_che_btw='S' and (v_es_onp = 'S' or v_cta_can ='S') then
            v_nro_secuencia := v_nro_secuencia +1;
            begin
              r_gmovi.cod_usuario     := v_cod_usuario;
              r_gmovi.hora            := v_hor_actual;
              r_gmovi.fecha           := v_fec_actual;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := 4;
              r_gmovi.cod_modalidad   := 41;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_actual;
              r_gmovi.cod_tra_padre   := v_cod_transaccion;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              --
              r_gmovi.cod_transaccion := 691;
              --r_gmovi.cod_rubro       := v_cod_rubro;
              --r_gmovi.tip_mov_rubro   := 'D';
              --
              r_gmovi.monto           := v_importe;
              r_gmovi.nro_documento   := p_nro_cheque;
              r_gmovi.cod_ofi_origen  := v_cod_oficina;  -- confirmar
              r_gmovi.emi_aviso       := 'N';
              ---
              if nvl(v_es_onp,'N') = 'S' then
                r_gmovi.concepto      := 'Detalle Cheque GNBPY ONP '||p_nro_cuenta;
              elsif nvl(v_cta_can,'N') = 'S' then  
                r_gmovi.concepto      := 'Detalle Cheque GNBPY Cta.Cancelada '||p_nro_cuenta;
              end if;  
              ---
              r_gmovi.estado          := nvl(v_est_movimiento,'N');
              r_gmovi.reversado       := 'N';
              r_gmovi.referencia      := p_nro_cuenta;
              r_gmovi.nro_caja        := p_nro_caja;
              ---
              if v_cod_moneda <>  pag_gen.FU_OBT_MON_LOCAL then
                 v_cotizacion := nvl(pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual),2);
                 --
                 r_gmovi.cotizacion := v_cotizacion;
                 r_gmovi.mto_equ_local := round(nvl(v_importe,0) * nvl(v_cotizacion,0), 0);
              else
                 r_gmovi.mto_equ_local := null;
              end if;
              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
           exception
             when others then
               v_error := sqlerrm;
               v_cod_respuesta := '014'; --ltrim(to_char(pag_cta.g_cod_error,'000'));
               v_msj_respuesta := substr(v_error, 1,200);
               pag_btw.pr_ins_log_btw(p_nro_cuenta, p_nro_cheque, p_importe, 'C', p_nro_caja,
                       v_pro_che_btw, null, v_cod_respuesta, v_msj_res_btw, v_error);

           end;
           ---  
         
           if v_cod_respuesta ='000' then
             ---- inserto en la tabla para luego poder obtener los datos
             ---- inserta tabla de cheques hibridos
               pag_btw.pr_ins_che_hibridos(v_fec_actual, v_hor_actual, v_cod_usuario,
                                           p_nro_cuenta, p_nro_cheque, v_cod_moneda,
                                           p_importe, p_nro_caja, v_pro_che_btw);

              -- llamo al que graba el cheque devuelto
               v_msj_respuesta := fuj_pro_transaccion_131(p_nro_operacion,
                                                        p_nro_caja,
                                                        p_nro_boleta,
                                                        p_nro_cheque,
                                                        p_nro_cuenta,
                                                        p_importe,
                                                        V_INSERT,
                                                        v_hor_actual,
                                                        v_es_che_btw);
              if v_msj_respuesta NOT LIKE '%~000~%' THEN
                -- 
                pag_btw.pr_ins_log_btw(p_nro_cuenta, p_nro_cheque, p_importe, 'C', p_nro_caja,
                 v_pro_che_btw, null, substr(v_msj_respuesta, 1,5), 'fuj_pro_transaccion_131', v_msj_respuesta);
                -- 
                 pag_cta.pr_nro_caja(null);
                 RETURN v_msj_respuesta;
              end if;
             
              if v_es_onp = 'S' then
                  v_msj_respuesta := '!Cheque se encuentra con Orden de No Pago. Fue registrado como Devuelto!';
              end if;
              if v_cta_can ='S' then
                  v_msj_respuesta := '!Cuenta Cancelada. El Cheque fue registrado como devuelto';
              end if;
              --actualizamos el estado a Devuelto            
              pag_btw.pr_upd_che_hibridos(v_fec_actual,v_hor_actual, v_cod_usuario,
                           p_nro_cuenta, p_nro_cheque, p_importe, 'D', v_cod_causa);
           end if;              
           
           if v_importe +  v_imp_detalle < v_imp_total  THEN
               --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
                -- vuelve a quedar en la pantalla
                v_msj_salida := fuj_val_transaccion_355(p_nro_operacion,
                                                        p_nro_caja,
                                                        p_nro_boleta,
                                                        p_nro_cheque,
                                                        p_nro_cuenta,
                                                        p_importe,
                                                        p_serie,
                                                        NULL,
                                                        V_INSERT); --RE DE-567 25/06/2015
               if substr(v_msj_salida,1,3) = '000' THEN
                   v_msj_salida := substr(v_msj_salida,1,15)||v_msj_respuesta||substr(v_msj_salida,18);
                   -- agrego la limpieza de los campos del cheque
                   v_msj_salida := v_msj_salida ||fuj_des_campo('NRO_CHEQUE',' ')||
                   fuj_des_campo('NRO_CUENTA',' ')||
                   fuj_des_campo('DES_CUENTA',' ')||
                   fuj_des_campo('COD_MONEDA2',' ')||
                   fuj_des_campo('SERIE',' ')||
                   fuj_des_campo('DES_MENSAJE',' ')||
                   fuj_des_campo('IMP_CHEQUE',' ')||'6';
                   -- el 6 indica que se quedara en el campo NRO DE cheque
                ELSE --RE DE-567 25/06/2015 -- Para que limpie los campos si es cheque con ONP
                    if v_msj_salida  LIKE '%~000~%'  then
                       v_msj_salida := v_msj_salida ||fuj_des_campo('NRO_CHEQUE',' ')||
                       -- agrego la limpieza de los campos del cheque
                       fuj_des_campo('NRO_CUENTA',' ')||
                       fuj_des_campo('DES_CUENTA',' ')||
                       fuj_des_campo('COD_MONEDA2',' ')||
                       fuj_des_campo('IMP_CHEQUE',' ')||
                       fuj_des_campo('SERIE',' ')||
                       fuj_des_campo('DES_MENSAJE',' ')||'6';
                       -- el 6 indica que se quedara en el campo NRO DE cheque
                     end if;
                end if;
           end if;
            -- se libera el cheque
            IF v_cod_respuesta = '000' and v_cod_tra_padre in (351, 394) THEN --RE DE-567 25/06/2015
               pra_lib_retencion(v_nro_cta_dep, v_nro_cta_dep, NULL, 'S', p_nro_boleta, p_importe,v_hor_actual);
            END IF;
            --
        End If;
      end if;
    else
       -- hubo error de validacion, ya salgo
       v_msj_salida := p_nro_operacion||'~'||
                      v_cod_respuesta||'~'||
                      nvl(v_msj_respuesta,'Operacion confirmada');
       pag_cta.pr_nro_caja(null);
       return(v_msj_salida);
    end if;
 end if;
 pag_cta.PR_SET_EST_MOVIMIENTO('N'); --> DYDMR-3194: Se Limpia Variable Global
 -- mensaje final sino hubo errores
 if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
    --if fuc_ver_fir_inhibidos(p_nro_cuenta) = 'S' then
    If NVL(v_ban_inhibidos,'X') = 'S' Then
       -- cuenta tiene firmantes inhibidos
       --CROPCFCS-1: Si la variable esta vacia se debe agregar el mensaje a emitir, caso contrario se debe concatenar el mensaje al ya existente.-
       If v_msj_autorizacion is null Then
          v_msj_respuesta    := 'Cuenta con firmantes Inhibidos-Ley de Cheques';
          v_msj_autorizacion := v_msj_respuesta;
       Else
          v_msj_autorizacion := v_msj_autorizacion||chr(10);
          v_msj_autorizacion := v_msj_autorizacion||'Cuenta con firmantes Inhibidos-Ley de Cheques.';
       End If;
    end if;
    if v_importe +  v_imp_detalle < v_imp_total  then
       --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
     -- vuelve a quedar en la pantalla
       if v_cod_respuesta = '000'  then
         v_msj_salida := fuj_val_transaccion_355(p_nro_operacion,
                                               p_nro_caja,
                                               p_nro_boleta,
                                               --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
                                               null,  --p_nro_cheque,
                                               null,  --p_nro_cuenta,
                                               null,  --p_importe,
                                               NULL); --p_serie);
       end if;
       if v_nro_pedido > 0 then -- C.D.Fase III
          v_msj_respuesta:= 'Se ha generado el Pedido de Autorizacion Nro:'||v_nro_pedido;
          v_msj_salida := p_nro_operacion||'~'||
                          v_cod_respuesta||'~'||'!'||
                          v_msj_respuesta||'~'||
                          v_msj_salida;
          pag_cta.pr_nro_caja(null);

          if v_msj_salida  LIKE '%~000~%'  then
            v_msj_salida := v_msj_salida || fuj_des_campo('NRO_CHEQUE'  ,' ')||
                                            fuj_des_campo('NRO_CUENTA'  ,' ')||
                                            fuj_des_campo('DES_CUENTA'  ,' ')||
                                            fuj_des_campo('COD_MONEDA2' ,' ')||
                                            fuj_des_campo('SERIE',' ')||--RE DE-567 25/06/2015
                                            fuj_des_campo('DES_MENSAJE',' ')||--RE DE-567 25/06/2015
                                            fuj_des_campo('IMP_CHEQUE'  ,' ');
          end if;

          return v_msj_salida;
        else
       if v_msj_salida  LIKE '%~000~%'  then
         v_msj_salida := v_msj_salida ||fuj_des_campo('NRO_CHEQUE',' ')||
         -- agrego la limpieza de los campos del cheque
         fuj_des_campo('NRO_CUENTA',' ')||
         fuj_des_campo('DES_CUENTA',' ')||
         fuj_des_campo('COD_MONEDA2',' ')||
         fuj_des_campo('SERIE',' ')|| --RE DE-567 25/06/2015 , LIMPIA EL CAMPO
         fuj_des_campo('DES_MENSAJE',' ')|| --RE DE-567 25/06/2015 , LIMPIA EL CAMPO
         fuj_des_campo('IMP_CHEQUE',' ')||'6';
         -- el 6 indica que se quedara en el campo NRO DE cheque
       end if;
       pag_cta.pr_nro_caja(null);

       --return v_msj_salida;
       end if;
    else
--       v_msj_respuesta := 'Operacion confirmada';
--       v_cod_respuesta := '000';

       -- IMPRESION DEL COMPROBANTE DE PAGO - SOLO PRESTAMOS
     --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
       if nvl(v_nro_pedido,0) = 0 and v_msj_autorizacion is null then /* C.D.Fase III*/
          lp_act_can_impresion; -- C.D.Fase III
           if v_cod_tra_padre in (359,360) and fug_obt_tip_implementacion IN (1,3,7) and v_cod_respuesta = '000' then
                --- Si ya detallo toda la operacion
                v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
                v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
                fuj_imp_transaccion_360(v_cod_oficina, -- oficina
                                         p_nro_boleta,
                                         null,--nro de factura
                                         p_nro_caja, -- Caja
                                         v_cod_moneda, -- Moneda
                                         v_nro_cta_dep, -- cuenta
                                         v_fecha_mvto,
                                         v_hora_mvto -- hora
                                         );
           end if;
       else
           v_msj_respuesta := 'Se ha generado el Pedido de Autorizacion Nro.:'||v_nro_pedido;
       end if;
    end if;
--    return (v_msj_salida);  -- sale directamente
 elsif v_msj_autorizacion is null then --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
    -- verifico el estado del cheque y de la cuenta
    v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,
                                           p_nro_cheque,
                                           v_error,
                                           p_serie);
    if v_error is not null then
       v_msj_respuesta := v_error;
    end if;
    if (v_est_cheque = 'O' OR  v_est_cuenta in ('P','C','T')) and v_error is null then
       -- llamo al grabador de cheques onp y cuenta cancelada
       V_INSERT := FALSE;  --RE DE-567 25/06/2015
       v_msj_respuesta := fuj_pro_transaccion_131(p_nro_operacion,
                                                  p_nro_caja,
                                                  p_nro_boleta,
                                                  p_nro_cheque,
                                                  p_nro_cuenta,
                                                  p_importe,
                                                  V_INSERT,
                                                  v_hor_actual); --RE DE-567 19/08/2015 se agrega la hora
        if v_msj_respuesta NOT LIKE '%~000~%' THEN
           pag_cta.pr_nro_caja(null);
           RETURN v_msj_respuesta;
        end if;
        v_cod_respuesta := '000';
        if v_est_cheque = 'O' then
          v_msj_respuesta := '!Cheque se encuentra con Orden de No Pago. Fue registrado como Devuelto!';
        else
          IF v_est_cuenta = 'T' THEN
              v_texto := 'Bloqueada';
            ELSE
              v_texto := 'Cancelada';
            END IF;
          v_msj_respuesta := '!Cuenta '||v_texto||'. El Cheque fue registrado como devuelto';
        end if;
        --Rechazo automático
        IF v_cod_respuesta = '000' AND
           nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' THEN
           --ver rechazo automatico
           PRC_VER_CHE_REC_AUT(p_nro_cuenta, p_nro_cheque,v_est_cuenta, v_rec_aut,v_cod_cau_rechazo,v_des_cau_rechazo);
           IF v_rec_aut = 'S' THEN    
            --obtener el ultimo numero de lote
            begin
             select nvl(max(a.nro_lote),0)
                 into v_nro_lote
                  from cc_che_rec_automaticos a;
            exception
              when others then
                v_nro_lote:=0;
            end;
            v_nro_lote:= nvl(v_nro_lote,0) + 1;
            
            --obtener tip_importe (Alto/Bajo Valor)
            if v_cod_moneda = pag_gen.fu_obt_mon_local then
               if v_importe >= nvl(fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,v_cod_moneda),0) then
                 v_tip_importe:=1;
               else
                 v_tip_importe:=0;
               end if;
             else
               v_tip_importe:=0;
             end if; 
           
             BEGIN
               --inserta rechazos automaticos
               rp_rch_aut.nro_cheque         := p_nro_cheque;
               rp_rch_aut.fec_proceso        := v_fec_actual;
               rp_rch_aut.nro_cuenta         := p_nro_cuenta; 
               rp_rch_aut.monto              := v_importe; 
               rp_rch_aut.cod_bco_receptor   := fug_obt_cod_banco; --nuestro banco
               rp_rch_aut.cod_ofi_camara     := FUG_OBT_OFI_CAMARA(v_cod_oficina);
               rp_rch_aut.cod_oficina        := v_cod_oficina; 
               rp_rch_aut.cod_cau_devolucion := v_cod_cau_rechazo; 
               rp_rch_aut.des_cau_devolucion := v_des_cau_rechazo; 
               rp_rch_aut.cod_usuario        := v_cod_usuario; 
               rp_rch_aut.tip_importe        := v_tip_importe; 
               rp_rch_aut.cod_moneda         := v_cod_moneda;
               rp_rch_aut.des_error          := v_msj_respuesta;
               rp_rch_aut.nro_lote           := v_nro_lote;
               rp_rch_aut.origen             := 'C';--Caja
               --inserta registro
               prc_ins_aut_rch_clearing(rp_rch_aut);
               --procesa rechazo automático
               prc_aut_rch_clearing(p_nro_cuenta,p_nro_cheque,v_cod_moneda, v_fec_actual, v_sec_rechazados,v_sec_rechazados_out);              
             EXCEPTION 
               WHEN OTHERS THEN
                v_cod_respuesta := '012';
                v_msj_respuesta := 'ERROR' || sqlerrm;
             END;
            END IF;
        END IF;---hasta aqui rechazo automatico   
             
        if v_importe +  v_imp_detalle < v_imp_total  THEN
         --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
          -- vuelve a quedar en la pantalla
          v_msj_salida := fuj_val_transaccion_355(p_nro_operacion,
                                                  p_nro_caja,
                                                  p_nro_boleta,
                                                  p_nro_cheque,
                                                  p_nro_cuenta,
                                                  p_importe,
                                                  p_serie,
                                                  NULL,
                                                  V_INSERT); --RE DE-567 25/06/2015
         if substr(v_msj_salida,1,3) = '000' THEN
             v_msj_salida := substr(v_msj_salida,1,15)||v_msj_respuesta||substr(v_msj_salida,18);
             -- agrego la limpieza de los campos del cheque
             v_msj_salida := v_msj_salida ||fuj_des_campo('NRO_CHEQUE',' ')||
             fuj_des_campo('NRO_CUENTA',' ')||
             fuj_des_campo('DES_CUENTA',' ')||
             fuj_des_campo('COD_MONEDA2',' ')||
             fuj_des_campo('SERIE',' ')||
             fuj_des_campo('DES_MENSAJE',' ')||
             fuj_des_campo('IMP_CHEQUE',' ')||'6';
             -- el 6 indica que se quedara en el campo NRO DE cheque
          ELSE --RE DE-567 25/06/2015 -- Para que limpie los campos si es cheque con ONP
              if v_msj_salida  LIKE '%~000~%'  then
                 v_msj_salida := v_msj_salida ||fuj_des_campo('NRO_CHEQUE',' ')||
                 -- agrego la limpieza de los campos del cheque
                 fuj_des_campo('NRO_CUENTA',' ')||
                 fuj_des_campo('DES_CUENTA',' ')||
                 fuj_des_campo('COD_MONEDA2',' ')||
                 fuj_des_campo('IMP_CHEQUE',' ')||
                 fuj_des_campo('SERIE',' ')||
                 fuj_des_campo('DES_MENSAJE',' ')||'6';
                 -- el 6 indica que se quedara en el campo NRO DE cheque
               end if;

          end if;
          --
          IF v_cod_tra_padre = 351 THEN --RE DE-567 25/06/2015
             pra_lib_retencion(v_nro_cta_dep, v_nro_cta_dep, NULL, 'S', p_nro_boleta, p_importe,v_hor_actual);--RE DE-567 19/08/2015 se agrega la hora para realizar la reversion correctamente
          END IF;
      --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
         -- pag_cta.pr_nro_caja(null);--RE DE-567 25/06/2015-- SE COMENTA PARA QUE SIGA QUEDANDO EN LA PANTALLA
         -- return v_msj_salida; --RE DE-567 25/06/2015-- SE COMENTA PARA QUE SIGA QUEDANDO EN LA PANTALLA
        else
--          v_msj_respuesta := 'Operacion confirmada';
--          v_cod_respuesta := '000';
            ---- libera el cheque autom¿ticamente al ser de nuestro banco------
            IF v_cod_tra_padre IN (351, 394, 371) THEN
               pra_lib_retencion(v_nro_cta_dep, v_nro_cta_dep, NULL, 'S', p_nro_boleta,NULL,v_hor_actual);--RE DE-567 19/08/2015 se agrega la hora para realizar la reversion correctamente
            END IF;
          -- IMPRESION DEL COMPROBANTE DE PAGO - SOLO PRESTAMOS
          if v_cod_tra_padre in (359,360) and fug_obt_tip_implementacion IN (1,3,7) then
             --- Si ya detallo toda la operacion
             v_cod_respuesta := 'IMP'; -- para indicar que esta ok y se puede imprimir
             v_msj_respuesta := 'Operacion Confirmada. Comprobante de Pago ha sido impreso.'||'~'||
             fuj_imp_transaccion_360(v_cod_oficina, -- oficina
                                     p_nro_boleta,
                                     null,--nro de factura
                                     p_nro_caja, -- Caja
                                     v_cod_moneda, -- Moneda
                                     v_nro_cta_dep, -- cuenta
                                     v_fecha_mvto,
                                     v_hora_mvto -- hora
                                     );
          end if;
        end if;
--        return (v_msj_salida);  -- sale directamente
          
    end if;
 end if;
 --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
 IF v_msj_autorizacion is not null then
     begin
     v_usu_autorizador := pag_aut.fu_obt_usu_autorizador(v_cod_transaccion,9,91,v_cod_oficina,p_importe,p_nro_cuenta);
     Exception
       When others then
       If v_cod_oficina in (7,1) Then
           Begin
               select a.cod_usuario
               into v_usu_autorizador
               from ge_autorizadores a, ba_usuarios u, ba_usu_roles b
               where a.cod_usuario = u.cod_usuario
                 and u.cod_oficina = v_cod_oficina
                 and nvl(a.monto,nvl(p_importe,-1)) >= nvl(p_importe,-1)
                 and rownum        = 1
                 and u.cod_usuario = b.cod_usuario
                 and b.cod_rol     = fug_obt_pardinamico('ROL_AUT_SOB_MATRIZ')
               order by fue_ver_sesion(cod_usuario);
           Exception
              When no_data_found then
                   Begin
                       select a.cod_usuario
                       into v_usu_autorizador
                       from ge_autorizadores a, ba_usuarios u, ba_usu_roles b
                       where a.cod_usuario = u.cod_usuario
                         and u.cod_oficina = v_cod_oficina
                         and nvl(a.monto,nvl(p_importe,-1)) >= nvl(p_importe,-1)
                         and rownum        = 1
                         and u.cod_usuario = b.cod_usuario
                         --and b.cod_rol     = 'TESORERO_NW'
                         order by fue_ver_sesion(cod_usuario);
                   Exception
                      When others then
                         v_cod_respuesta := '015';
                         v_msj_respuesta := 'Obt.Usu.Aut. '||substr(sqlerrm,1,400);
                    End;
              When others then
                 v_cod_respuesta := '016';
                 v_msj_respuesta := 'Obt.Usu.Aut. '||substr(sqlerrm,1,400);
            End;
         ELSE
       Begin
         select a.cod_usuario
         into v_usu_autorizador
         from ge_autorizadores a, ba_usuarios u
         where a.cod_usuario = u.cod_usuario
           and u.cod_oficina = v_cod_oficina
           and nvl(a.monto,nvl(p_importe,-1)) >= nvl(p_importe,-1)
           and rownum        = 1
           order by fue_ver_sesion(cod_usuario);
       Exception
        When no_data_found then
           Begin
             select a.cod_usuario
             into v_usu_autorizador
             from ge_autorizadores a, ba_usuarios u
             where a.cod_usuario = u.cod_usuario
               and u.cod_oficina = 7
               and nvl(a.monto,nvl(p_importe,-1)) >= nvl(p_importe,-1)
               and rownum        = 1
               order by fue_ver_sesion(cod_usuario);
           Exception
            When others then
               v_cod_respuesta := '015';
               v_msj_respuesta := 'Obt.Usu.Aut. '||substr(sqlerrm,1,400);
            End;
        When others then
           v_cod_respuesta := '016';
           v_msj_respuesta := 'Obt.Usu.Aut. '||substr(sqlerrm,1,400);
        End;
         End IF;
   end;
     if v_cod_respuesta = '000' then
         begin
           INSERT INTO GE_AUT_PEDIDOS (COD_USU_AUTORIZADOR,
                                       FECHA              ,
                                       HORA               ,
                                       COD_USUARIO        ,
                                       MENSAJE            ,
                                       ESTADO             ,
                                       RESPUESTA          ,
                                       MTO_MON_FUERTE     ,
                                       TIP_AUTORIZACION)
                               VALUES (v_usu_autorizador/*pag_aut.fu_obt_usu_autorizador(v_cod_transaccion,9,91,v_cod_oficina,p_importe,p_nro_cuenta)*/,
                                       v_fec_actual,
                                       v_hor_actual,
                                       v_cod_usuario,
                                       v_msj_autorizacion,
                                       'S',
                                       'P',
                                       pag_gen.FU_CON_MON_A_MONEDA(v_cod_moneda,'USD',v_importe),
                                       v_tip_autorizacion);
         exception
            when others then
                   v_cod_respuesta := '017';
                   v_msj_respuesta := 'Ins.Pedido Aut. '||substr(sqlerrm,1,400);
         end;
         --v_msj_respuesta := '!'||v_msj_autorizacion||'.'||chr(10)||'Autorizacion Solicitada al Encargado.';
     End If;
 End If;
 if v_cod_respuesta = '000' then
     if v_msj_autorizacion is not null then
         v_msj_respuesta := '!'||v_msj_autorizacion||'.'||chr(10)||'Autorizacion Solicitada al Encargado.';
     end if;
 end if;

 /* falta armar el mensaje de respuesta */
 --> Se agrega este filtro para el pedido que Rodrigo va realizar
 if v_importe +  v_imp_detalle < v_imp_total and v_msj_autorizacion is null then
   v_msj_salida := p_nro_operacion||'~'||
                   v_cod_respuesta||'~'||
                   v_msj_respuesta;
    pag_cta.pr_nro_caja(null);
    return(v_msj_salida);

 ElsIf v_importe +  v_imp_detalle < v_imp_total and v_msj_autorizacion is not null then
    v_msj_salida := p_nro_operacion||'~'||v_cod_respuesta||'~'||v_msj_respuesta;
    pag_cta.pr_nro_caja(null);
    return(v_msj_salida);

 Else
    v_msj_salida := p_nro_operacion||'~'||
                   v_cod_respuesta||'~'||
                   nvl(v_msj_respuesta,'Operacion confirmada');
    pag_cta.pr_nro_caja(null);
    return(v_msj_salida);
 End If;
exception
    when others then
       v_cod_respuesta := '999';
       v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 '!'||nvl(v_msj_respuesta,SQLERRM);
       pag_cta.pr_nro_caja(null);
       return(v_msj_salida);
end FUJ_PRO_TRANSACCION_355;
/

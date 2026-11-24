create or replace package body it.paw_cel is
  --- definiciones generales
  v_cod_pais number(4) := FUG_OBT_PAI_ENTIDAD;  -- 1-It    586-Atlas( pais para la creacion de personas)
  -----------***  FUNCIONES Y PROCEDIMIENTOS INTERNOS ***------------
  procedure lp_reg_operacion(p_nro_operacion    in number,
                             p_fec_operacion    in varchar2,
                             p_nro_ref_externo  in varchar2,
                             p_nro_celular      in varchar2,
                             p_tip_transaccion  in number,
                             p_det_parametros   in varchar2 default null) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  begin
     insert into bw_mov_celulares
       (nro_operacion, fec_hora, cod_tip_transaccion, nro_ref_externo,
        nro_celular, det_parametros, cod_respuesta, msj_respuesta)
     values
       (p_nro_operacion, nvl(to_date(p_fec_operacion,'YYYYMMDDHH24MISS'),sysdate), p_tip_transaccion,p_nro_ref_externo,
        p_nro_celular, p_det_parametros, v_cod_respuesta, v_msj_respuesta);
     commit;
  exception
     when dup_val_on_index then
         paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
         paw_cel.v_msj_respuesta := 'Operacion ya registrada anteriormente';
     when others then
         paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
         paw_cel.v_msj_respuesta := 'Error al insertar BW_MOV_CELULARES. '||substr(sqlerrm,1,500);
  end;

  procedure lp_pro_cur_pedidos(p_nro_operacion in number,     -- numero de operacion
                               p_tip_transaccion in varchar2, -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                               p_fec_transaccion in varchar2,
                               p_detalles in varchar2,
                               p_nro_secuencia in number default 0) is
  v_pos_ini number(5) := 0;
  v_pos_fin number(5) := 0;
  v_fila number(5) := 0;
  v_registro varchar2(100);
  v_pos      number(3);
  v_sum_debitos number(18,2) := 0;
  v_sum_creditos number(18,2) := 0;
  v_nro_cta_debito varchar2(20);
  v_nro_cta_credito varchar2(20);
  begin
    -- ejemplo de estructura recibida
    -- 2[<991720382~989899~2425~2~C~12000.0><991720382~987652~256~1~D~45600.0>]
    -- Cant.Rec[<nroReferencia~Celular~IdMovimiento~idConcepto~tipMov~Monto>...
    -- seteo las variables
    v_nro_secuencia := nvl(p_nro_secuencia,0);
    --
    v_can_pedidos := 0;
    v_pos_ini := instr(p_detalles,'[');
    if v_pos_ini > 1 then
       v_can_pedidos := substr(p_detalles,1,v_pos_ini-1);
       while v_fila < v_can_pedidos loop
          v_pos_ini := instr(p_detalles,'<',v_pos_ini);
          v_pos_fin := instr(p_detalles,'>',v_pos_ini);
          v_registro := substr(p_detalles, v_pos_ini+1, v_pos_fin - v_pos_ini-1);
          v_fila := v_fila + 1;
          v_pos_ini := v_pos_fin+1;
          v_pos := instr(v_registro,'~');
          if v_pos > 1 then
             pedidos(v_fila).nro_ref_externo := substr(v_registro,1,v_pos-1);
             v_registro := substr(v_registro,v_pos+1);
             v_pos := instr(v_registro,'~');
             if v_pos > 1 then
                pedidos(v_fila).nro_celular := substr(v_registro,1,v_pos-1);
                v_registro := substr(v_registro,v_pos+1);
                v_pos := instr(v_registro,'~');
                if v_pos > 1 then
                    pedidos(v_fila).nro_movimiento := substr(v_registro,1,v_pos-1);
                    v_registro := substr(v_registro,v_pos+1);
                    v_pos := instr(v_registro,'~');
                    if v_pos > 1 then
                       pedidos(v_fila).tip_concepto := substr(v_registro,1,v_pos-1);
                       v_registro := substr(v_registro,v_pos+1);
                       v_pos := instr(v_registro,'~');
                       if v_pos > 1 then
                           pedidos(v_fila).tip_movimiento := substr(v_registro,1,v_pos-1);
                           v_registro := substr(v_registro,v_pos+1);
                           pedidos(v_fila).monto := to_number(v_registro);
                       end if;
                    end if;
                end if;
             end if;
           end if;
       end loop;
       -- fin del armado, ahora, se procesa
       for i in 1..v_can_pedidos
       loop

           pr_act_operacion(p_nro_operacion,     -- numero de operacion
                            p_tip_transaccion, -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                            pedidos(i).nro_ref_externo, -- nro unico de identificacion de la cuenta
                            pedidos(i).tip_movimiento,  -- puede ser: d-debito o c-credito
                            pedidos(i).monto,             -- Monto de la operacion
                            pedidos(i).tip_concepto,    -- Puede ser: 1-Cred.Comision, 2-Deb.Cargo, 3-Debito, 4-Credito
                            substr('Fec:'||p_fec_transaccion||' Nro:'||pedidos(i).nro_movimiento,1,35));
           if pedidos(i).tip_movimiento = 'D' then
              v_sum_debitos := nvl(v_sum_debitos,0) + nvl(pedidos(i).monto,0);
              if v_nro_cta_debito is null then
                 v_nro_cta_debito := v_nro_cuenta;
              end if;
           else
              v_sum_creditos := nvl(v_sum_creditos,0) + nvl(pedidos(i).monto,0);
              if v_nro_cta_credito is null then
                 v_nro_cta_credito := v_nro_cuenta;
              end if;
           end if;
       end loop;
       --
       if v_cod_respuesta = v_cod_aprobado then
          -- verifico los totales
          if nvl(v_sum_debitos,0) <> nvl(v_sum_creditos,0) then
             v_cod_respuesta := paw_cel.v_cod_mto_invalido;
             v_msj_respuesta := 'Sumatoria de Debitos no coincide con Sumatoria de Creditos';
          else
             -- cargo los saldos actualizados
             if v_nro_cta_debito is not null then
                pag_cta.pr_obt_cuenta(v_nro_cta_debito);
                v_saldo  := pag_cta.FU_SAL_DISPONIBLE;
             end if;
             if v_nro_cta_credito is not null then
                pag_cta.pr_obt_cuenta(v_nro_cta_credito);
                v_sal_destino  := pag_cta.FU_SAL_DISPONIBLE;
             end if;

          end if;
       end if;

    end if;

  end;

  -- Funcion que arma el mensaje de salida
  function lf_gen_respuesta(v_dato in varchar2) return varchar2 is
  begin
      if v_dato is not null then
         return paw_cel.v_cod_respuesta||'~'||paw_cel.v_msj_respuesta||'~'||v_dato;
      else
         return paw_cel.v_cod_respuesta||'~'||paw_cel.v_msj_respuesta;
      end if;
  end;


  -- Inicializo la respuesta del mensaje
  procedure lp_ini_respuesta is
  begin
     paw_cel.v_cod_respuesta := paw_cel.v_cod_aprobado;
     paw_cel.v_msj_respuesta := '';
     -- Inicializacion de la aplicacion y el modulo
     BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
     --
     pre_cam_for_numerico('.,');
     --
     v_hor_actual  := to_char(sysdate,'HH24:MI:SS');

  end;

  -- devuelve el campo char formateado
  function lf_for_char(p_dato in varchar2,
                       p_longitud in number)
     return char is
  begin
    return substr(rpad(nvl(p_dato,' '),p_longitud,' '),1,p_longitud);
  end;

  -- devuelve el campo date formateado
  function lf_for_date(p_dato in date)
     return char is
  begin
    return rpad(nvl(to_char(p_dato,'ddmmyyyy'),' '),8,' ');
  end;

  -- devuelve el campo monto formateado
  function lf_for_money(p_dato in number,
                        p_longitud in number default 16)
     return varchar2 is
  begin
    return ltrim(to_char(nvl(p_dato,0),'99999999999999.99'));
  end;

  -- devuelve el campo numero formateado
  function lf_for_number(p_dato in number,
                        p_longitud in number default 3)
     return char is
  begin
    return ltrim(to_char(nvl(p_dato,0),'9999999999999'));
  end;
  --
  function fu_es_conjunta(p_nro_cuenta in varchar2)
  return varchar2 is
  v_can_conjunta  number;
  begin
     -- veo si la cuenta no es conjunta
     select count(*) into v_can_conjunta
       from ge_cta_clientes
      where nro_cuenta = p_nro_cuenta
        and relacion = 'Y'
        and rownum = 1;
     if v_can_conjunta > 0  then
       /* no requiere autorizacion y la cuenta es conjunta, no debe acceder*/
        return 'S';
     else
        return 'N';
     end if;
  end;
  --
  -- devuelve el indicador del horario de
  procedure lp_ver_horario is
    v_est_modulo ba_modulos.estado%type;
  begin
    v_horario := 'D'; -- Dia normal
    v_es_mov_noc  := 'N'; -- Para grabar en las tablas nocturnas
    v_es_cta_noc  := 'N';
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

    If v_est_modulo in (6) Then  -- En cierre.
       v_cod_respuesta := paw_cel.v_cod_sis_cierre;
    elsif v_est_modulo = 2 Then -- El modulo esta abierto
       -- Verifica la hora --
       null;
    else
       v_horario := 'N'; -- Noche
       if v_est_modulo <> 1 then
          v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual+1, 1, v_cod_ofi_origen);
       end if;
       v_es_mov_noc  := 'S'; -- Para grabar en las tablas nocturnas
       v_es_cta_noc  := 'S'; -- Solo para que llavee la cuenta nocturna
    end if;
    v_fec_valor       := trunc(sysdate); --v_fec_actual;
    --pag_cta.g_horario := v_horario;
  end lp_ver_horario;
  -- Funcion que registra un movimiento de debito/credito a una cuenta celular
  procedure pr_act_operacion(p_nro_operacion in number,     -- numero de operacion
                             p_tip_transaccion in varchar2, -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                             p_nro_ref_externo in varchar2, -- nro unico de identificacion de la cuenta
                             p_tip_movimiento in varchar2,  -- puede ser: d-debito o c-credito
                             p_monto in number,             -- Monto de la operacion
                             p_tip_concepto in varchar2,    -- Puede ser: 1-Cred.Comision, 2-Deb.Cargo, 3-Debito, 4-Credito
                             p_concepto     in varchar2) is
      v_cod_moneda       varchar2(5);
      v_estado           varchar2(1);

      --

      v_cod_modulo       number(4);
      v_cod_modalidad    number(4);
      v_nvo_estado       varchar2(1) := null; -- cambio de estado de cuenta
      v_procesa          varchar2(1) := 'N';
      v_sal_disponible   number(18,2);
      --
      v_cod_tra_padre    number(5);
      v_cod_transaccion  number(5);
      v_cotizacion       number(18,2) := null;
      v_mto_equ_local    number(18,2) := null;

      begin
        v_nro_cuenta := null;
        --
        if p_tip_transaccion not in ('1','2','3','4','5','6','7','8','9','10','11','12','13','15') then
           paw_cel.v_cod_respuesta := paw_cel.v_cod_tra_invalida;
           paw_cel.v_msj_respuesta := 'Transaccion debe ser 1,2,3,4,5,6,7,8,9,10,11,12,13,15 -> '||p_tip_transaccion;
           raise fin_por_error;
        elsif p_tip_movimiento not in ('D','C') then
           paw_cel.v_cod_respuesta := paw_cel.v_cod_ope_no_permitida;
           paw_cel.v_msj_respuesta := 'Tipo de Movimiento debe ser D/C. -> '||p_tip_movimiento;
           raise fin_por_error;
        elsif p_monto <= 0 then
           paw_cel.v_cod_respuesta := paw_cel.v_cod_mto_invalido;
           paw_cel.v_msj_respuesta := 'Monto invalido';
           raise fin_por_error;
        elsif p_tip_concepto not in ('1','2','3','4') then
           paw_cel.v_cod_respuesta := paw_cel.v_cod_tra_invalida;
           paw_cel.v_msj_respuesta := 'Concepto debe ser 1,2,3, 0 4. -> '||p_tip_concepto;
           raise fin_por_error;
        else
          --
          select a.nro_cuenta, a.cod_moneda cod_moneda,  estado
            into v_nro_cuenta, v_cod_moneda,  v_estado
            from ah_cta_vistas a
           where a.nro_ref_externo = p_nro_ref_externo;

           if v_estado in ('X','C','P') then
              paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
              paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
              raise fin_por_error;
           elsif v_estado in ('A') and p_tip_movimiento = 'D' then
              paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
              paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
              raise fin_por_error;
           elsif v_cod_moneda <> paw_cel.v_cod_mon_local then
              paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
              paw_cel.v_msj_respuesta := 'Moneda de la Cuenta invalida';
              raise fin_por_error;
           else
             -- Veo si se puede realizar la operacion
             --461 a 470
             if p_tip_transaccion = '1' then
                v_cod_tra_padre := 461;
             elsif p_tip_transaccion = '2' then
                v_cod_tra_padre := 462;
             elsif p_tip_transaccion = '3' then
                v_cod_tra_padre := 463;
             elsif p_tip_transaccion in ('4','13') then
                v_cod_tra_padre := 464;
             elsif p_tip_transaccion = '6' then
                v_cod_tra_padre := 465;
             elsif p_tip_transaccion = '7' then
                v_cod_tra_padre := 466;
             elsif p_tip_transaccion = '10' then
                v_cod_tra_padre := 467;
             elsif p_tip_transaccion = '15' then
                v_cod_tra_padre := 468;
             elsif p_tip_transaccion in ('11','12') then -- reversiones
                v_cod_tra_padre := 469;
             else
               paw_cel.v_cod_respuesta := paw_cel.v_cod_tra_invalida;
               paw_cel.v_msj_respuesta := 'Transacción '||p_tip_transaccion||' no definida';
               raise fin_por_error;
             end if;
             -- Puede ser: 1-Cred.Comision, 2-Deb.Cargo, 3-Debito, 4-Credito
             if p_tip_concepto = '1' then
                v_cod_transaccion := 472;
             elsif p_tip_concepto = '2' then
                v_cod_transaccion := 471;
             elsif p_tip_concepto = '3' then
                v_cod_transaccion := 473;
             elsif p_tip_concepto = '4' then
                v_cod_transaccion := 474;
             else
               paw_cel.v_cod_respuesta := paw_cel.v_cod_tra_invalida;
               paw_cel.v_msj_respuesta := ' idConcepto '||p_tip_concepto||' no definido';
               raise fin_por_error;
             end if;
             -- verifico si el tipo de movimiento corresponde a la transaccion recibida
             declare
                v_tipo varchar2(1);
             begin
                select tipo
                  into v_tipo
                  from ge_transacciones
                 where cod_transaccion = v_cod_transaccion
                   and cod_modulo = 3
                   and cod_modalidad = 31;
                if v_tipo <> p_tip_movimiento then
                   v_cod_respuesta := paw_cel.v_cod_tra_invalida;
                   v_msj_respuesta := 'Tipo de Mov. '||p_tip_movimiento||' no coincide con la Transaccion 3-31-'||v_cod_transaccion||' es de tipo '||v_tipo;
                   raise fin_por_error;
                end if;
             exception
                when  fin_por_error then
                   raise fin_por_error;
                when no_data_found then
                   v_cod_respuesta := paw_cel.v_cod_tra_invalida;
                   v_msj_respuesta := 'Transaccion 3-31-'||v_cod_transaccion||' no definida ';
                   raise fin_por_error;
                when others then
                   v_cod_respuesta := paw_cel.v_cod_tra_invalida;
                   v_msj_respuesta := 'Transaccion 3-31-'||v_cod_transaccion||' con el error: '||sqlerrm;
                   raise fin_por_error;

             end;
             --
             if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then

               if pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,v_cod_tra_padre, 3, 31) = 'S' then
                  v_cod_respuesta := paw_cel.v_cod_tra_prohibida;
                  v_msj_respuesta := 'Transaccion 3-31-'||v_cod_tra_padre||' prohibida para la Cta. '||v_nro_cuenta;
                  raise fin_por_error;
               elsif fu_es_conjunta(v_nro_cuenta) = 'S' and p_tip_movimiento = 'D' then
                  v_cod_respuesta := paw_cel.v_cod_tra_invalida;
                  v_msj_respuesta := 'Cuenta conjunta no permite debitos';
                  raise fin_por_error;
               else
                  pag_cta.pr_ver_operacion(v_nro_cuenta,v_cod_tra_padre,3,31,p_tip_movimiento,v_cod_moneda, p_monto, v_cod_ofi_origen,
                                           v_cod_modulo, v_cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesa,v_cod_transaccion);
                  if v_procesa = 'N' then
                     -- no se puede debitar
                     if instr(upper(pag_cta.G_MSJ_ERROR),'INSUFIC') > 0 then
                        -- saldo insuficiente
                        v_cod_respuesta := paw_cel.v_cod_sal_insuficiente;
                        v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
                        raise fin_por_error;
                     else
                        v_cod_respuesta := paw_cel.v_cod_cta_bloqueada;
                        v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
                        raise fin_por_error;
                     end if;
                  else
                     -- se puede hacer la operacion
                     lp_ver_horario;
                     -- valido la duplicacion de movimientos
                     if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                         declare
                            v_existe varchar2(1) := null;
                         begin
                               if v_es_mov_noc = 'S' then
                                  select distinct 'S'
                                    into v_existe
                                    from ge_movimientos_noc
                                   where nro_cuenta = v_nro_cuenta
                                     and cod_tra_padre = v_cod_tra_padre
                                     and cod_transaccion = v_cod_transaccion
                                     and nro_documento = p_nro_operacion
                                     and monto = p_monto
                                     and reversado = 'N'
                                     and cod_usuario = v_cod_usuario
                                     and concepto = p_concepto
                                     and rownum = 1;
                               else
                                  select distinct 'S'
                                    into v_existe
                                    from ge_movimientos
                                   where nro_cuenta = v_nro_cuenta
                                     and cod_tra_padre = v_cod_tra_padre
                                     and cod_transaccion = v_cod_transaccion
                                     and nro_documento = p_nro_operacion
                                     and monto = p_monto
                                     and reversado = 'N'
                                     and cod_usuario = v_cod_usuario
                                     and concepto = p_concepto
                                     and rownum = 1;

                               end if;
                               raise too_many_rows;
                         exception
                            when no_data_found then
                               null;
                            when too_many_rows then
                               paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
                               paw_cel.v_msj_respuesta := 'Movimiento ya ingresado';
                               raise fin_por_error;

                         end;
                     end if;
                     if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                        -- se puede registrar
                        pag_cta.PR_SET_VARIABLES(v_cod_usuario,
                                                  v_fec_valor,
                                                  v_cod_tra_padre, 'N', 'N',
                                                  v_nro_secuencia,
                                                  null, v_cod_ofi_origen, 3, 31);
                        -- actualizo la cuenta de debito
                        v_cotizacion     := null;
                        v_mto_equ_local  := null;
                        pag_cta.PR_ACT_OPERACION(v_nro_cuenta, v_hor_actual,p_tip_movimiento,
                                                 v_cod_moneda, p_monto,
                                                 v_cod_tra_padre, v_cod_transaccion, p_nro_operacion,
                                                 v_cotizacion, v_cod_ofi_origen, 3, 31,
                                                 null, null, p_concepto,
                                                 'N', v_nro_secuencia, v_fec_valor,
                                                 null, null, v_mto_equ_local);
                         if nvl(pag_cta.g_cod_error,0)<> 0 then
                             -- hubo error en el registro del debito o credito
                            v_cod_respuesta := paw_cel.v_cod_tra_invalida;
                            v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
                            raise fin_por_error;
                         end if;

                     end if;

                  end if;

               end if;
             end if;


           end if;
         end if;
        return;
      exception
         when fin_por_error then
            return;
         when no_data_found then
            paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
            paw_cel.v_msj_respuesta := 'Cuenta inexistente';
            return;
         when others then
            paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
            paw_cel.v_msj_respuesta := 'Otro error: '||substr(sqlerrm,1,500);
            return;
      end;
  -- fin de pr_act_operacion

  -- Funcion que registra el cambio de PIN
  function cambiarPin(p_nro_operacion   in number,
                      p_fec_transaccion in varchar2,
                      p_nro_ref_externo in varchar2,
                      p_nro_celular     in varchar2,
                      p_detalles        in varchar2) return varchar2 is
  v_nro_cuenta varchar2(20);
  v_cod_moneda varchar2(5);
  v_estado     varchar2(1);

  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    select a.nro_cuenta, a.cod_moneda cod_moneda,  estado
      into v_nro_cuenta, v_cod_moneda,  v_estado
      from ah_cta_vistas a
     where a.nro_ref_externo = p_nro_ref_externo;
    if v_estado in ('X','C','P') then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
        raise fin_por_error;
    elsif v_cod_moneda <> paw_cel.v_cod_mon_local then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Moneda de la Cuenta invalida';
        raise fin_por_error;
    else
       -- veo si hay cargos
       if p_detalles is not null then
          lp_pro_cur_pedidos(p_nro_operacion,
                             15,  -- tip_transaccion
                             p_fec_transaccion,
                             p_detalles);
       end if;

    end if;
    lp_reg_operacion(p_nro_operacion,
                     p_fec_transaccion,
                     p_nro_ref_externo,
                     p_nro_celular,
                     15 /*p_tip_transaccion*/,
                     p_detalles);
    return lf_gen_respuesta(lf_for_money(v_saldo));
  exception
     when fin_por_error then
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         15 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_saldo);
     when no_data_found then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
        paw_cel.v_msj_respuesta := 'Cuenta inexistente';
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         15 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_saldo);
     when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
        paw_cel.v_msj_respuesta := 'Otro error: '||substr(sqlerrm,1,500);
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         15 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_saldo);
  end;


  -- Funcion que retorna el saldo de una cuenta celular
  function consultarSaldo(p_nro_operacion   in number,
                          p_fec_transaccion in varchar2,
                          p_nro_ref_externo in varchar2,
                          p_nro_celular     in varchar2,
                          p_detalles        in varchar2) return varchar2 is
  v_nro_cuenta varchar2(20);
  v_cod_moneda varchar2(5);
  v_estado     varchar2(1);

  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    select a.nro_cuenta, a.cod_moneda cod_moneda,  estado
      into v_nro_cuenta, v_cod_moneda,  v_estado
      from ah_cta_vistas a
     where a.nro_ref_externo = p_nro_ref_externo;
    if v_estado in ('X','C','P') then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
        raise fin_por_error;
    elsif v_cod_moneda <> paw_cel.v_cod_mon_local then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Moneda de la Cuenta invalida';
        raise fin_por_error;
    else
       -- veo si hay cargos
       if p_detalles is not null then
          lp_pro_cur_pedidos(p_nro_operacion,
                             6,  -- tip_transaccion
                             p_fec_transaccion,
                             p_detalles);
       end if;
       -- obtengo el saldo
       if paw_cel.v_cod_respuesta = v_cod_aprobado then
          pag_cta.pr_obt_cuenta(v_nro_cuenta);
          v_saldo  := pag_cta.FU_SAL_DISPONIBLE;
       end if;

    end if;
    lp_reg_operacion(p_nro_operacion,
                     p_fec_transaccion,
                     p_nro_ref_externo,
                     p_nro_celular,
                     6 /*p_tip_transaccion*/,
                     p_detalles);
    return lf_gen_respuesta(lf_for_money(v_saldo));
  exception
     when fin_por_error then
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         6 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_saldo);
     when no_data_found then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
        paw_cel.v_msj_respuesta := 'Cuenta inexistente';
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         6 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_saldo);
     when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
        paw_cel.v_msj_respuesta := 'Otro error: '||substr(sqlerrm,1,500);
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         6 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_saldo);
  end;
  --
  -- Funcion que retorna los ultimos tres movimientos de la cuenta
  function resumirMovimientos(p_nro_operacion   in number,
                              p_fec_transaccion in varchar2,
                              p_nro_ref_externo in varchar2,
                              p_nro_celular     in varchar2,
                              p_can_movimientos in number,
                              p_fec_movimiento  in varchar2,
                              p_detalles        in varchar2
                              ) return varchar2 is
  v_nro_cuenta   varchar2(20);
  v_cod_moneda   varchar2(5);
  v_estado       varchar2(1);
  v_can_detalles number(3) := 0;
  v_detalles     varchar2(1000) := '';
  v_can_limite   number(3) := 3; -- cantidad maxima a responder
  --
  cursor movimientos(p_nro_cuenta in varchar2) is
  select fecha, nro_documento, abr_tra_padre des_tra_padre, cod_tip_movimiento, monto, hora
    from ge_transacciones b, gv_movimientos a
   where nro_cuenta = p_nro_cuenta
     and estado = 'N'
     and reversado = 'N'
     and monto <> 0
     and cod_tip_movimiento in ('D','C')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.ve_cliente = 'S'
     and not exists (select 0 from ah_retenciones x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.nro_documento = a.nro_documento
                        and x.cod_retencion = a.cod_retencion
                        and x.fec_final = a.fec_fin_retencion
                        and x.liberado = 'N')
   order by a.fec_insercion desc, nro_secuencia desc;

  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    select a.nro_cuenta, a.cod_moneda cod_moneda, estado
      into v_nro_cuenta, v_cod_moneda, v_estado
      from ah_cta_vistas a
     where a.nro_ref_externo = p_nro_ref_externo;
     if v_estado in ('X','C','P') then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
        raise fin_por_error;
     elsif v_cod_moneda <> paw_cel.v_cod_mon_local then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Moneda de la Cuenta invalida';
        raise fin_por_error;
     else
       -- obtengo los movimientos
       v_can_detalles := 0;
       v_detalles     := '[';
       for mv in movimientos(v_nro_cuenta) loop
             v_can_detalles := v_can_detalles + 1;
             v_detalles := v_detalles ||
                           lf_for_date(mv.fecha)||'~'||
                           lf_for_char(mv.des_tra_padre,6)||'~'||
                           lf_for_number(mv.nro_documento,7)||'~'||
                           lf_for_char(mv.cod_tip_movimiento,1)||'~'||
                           lf_for_money(mv.monto,16)||'~';
             exit when v_can_detalles >= v_can_limite;
       end loop;
       if v_can_detalles > 0 then
          v_detalles := substr(v_detalles,1,length(v_detalles)-1)||']';
       else
          --paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_sin_mov;
          paw_cel.v_msj_respuesta := 'Cuenta sin movimientos';
          v_detalles := '';
          raise fin_por_error;
       end if;
     end if;
     -- veo si hay cargos
     if p_detalles is not null then
        lp_pro_cur_pedidos(p_nro_operacion,
                           7,  -- tip_transaccion
                           p_fec_transaccion,
                           p_detalles);
     end if;
    lp_reg_operacion(p_nro_operacion,
                     p_fec_transaccion,
                     p_nro_ref_externo,
                     p_nro_celular,
                     7 /*p_tip_transaccion*/,
                     p_detalles);
     if v_cod_respuesta <> v_cod_aprobado then
        -- si hay problemas, no se devuelven los movimientos
        v_can_detalles := 0;
        v_detalles := '';
     end if;
     return lf_gen_respuesta(v_can_detalles||'~'||v_detalles);
  exception
     when fin_por_error then
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         7 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_can_detalles||'~'||v_detalles);
     when no_data_found then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
        paw_cel.v_msj_respuesta := 'Cuenta inexistente';
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         7 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_can_detalles||'~'||v_detalles);
     when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
        paw_cel.v_msj_respuesta := 'Otro error: '||substr(sqlerrm,1,500);
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         7 /*p_tip_transaccion*/,
                         p_detalles);
        return lf_gen_respuesta(v_can_detalles||'~'||v_detalles);
  end;

  -- Funcion que procesa las operaciones enviadas desde el WebService
  function realizarOperacion(p_nro_operacion   in number,
                             p_fec_transaccion in varchar2,
                             p_nro_ref_externo in varchar2,
                             p_nro_celular     in varchar2,
                             p_tip_transaccion in varchar2,     -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                             p_detalles        in varchar2)
    return varchar2 is
  v_cod_moneda varchar2(5);
  v_estado     varchar2(1);
  v_nro_cuenta varchar2(30);

  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    select a.cod_moneda cod_moneda,  estado, nro_cuenta
      into v_cod_moneda,  v_estado, v_nro_cuenta
      from ah_cta_vistas a
     where a.nro_ref_externo = p_nro_ref_externo;
     if v_estado in ('C','P') then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
        raise fin_por_error;
     elsif v_cod_moneda <> paw_cel.v_cod_mon_local then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Moneda de la Cuenta invalida';
        raise fin_por_error;
     else
       --debo llamar a la actualizacion de las operaciones
       lp_pro_cur_pedidos(p_nro_operacion,     -- numero de operacion
                          p_tip_transaccion, -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                          p_fec_transaccion,
                          p_detalles);

     end if;
     lp_reg_operacion(p_nro_operacion,
                      p_fec_transaccion,
                      p_nro_ref_externo,
                      p_nro_celular,
                      p_tip_transaccion,
                      p_detalles);
     return lf_gen_respuesta(v_saldo||'~'||v_sal_destino);
  exception
     when fin_por_error then
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         p_tip_transaccion,
                         p_detalles);
        return lf_gen_respuesta('');

     when no_data_found then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
        paw_cel.v_msj_respuesta := 'Cuenta inexistente';
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         p_tip_transaccion,
                         p_detalles);
        return lf_gen_respuesta('');
     when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
        paw_cel.v_msj_respuesta := 'Otro error: '||substr(sqlerrm,1,500);
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         p_tip_transaccion,
                         p_detalles);
        return lf_gen_respuesta('');

  end;


  -- Funcion que asocia la cuenta con el numero de Celular
  function asociarCuenta(p_nro_operacion   in number,
                         p_fec_transaccion in varchar2,
                         p_nro_ref_externo in varchar2,
                         p_nro_celular     in varchar2,
                         p_nro_cuenta       in varchar2,
                         p_tip_usuario     in varchar2
                         ) return varchar2 is
  v_cod_moneda varchar2(5);
  v_estado     varchar2(1);
  v_nro_ref_externo varchar2(30);

  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    select a.cod_moneda cod_moneda,  estado, nro_ref_externo
      into v_cod_moneda,  v_estado, v_nro_ref_externo
      from ah_cta_vistas a
     where a.nro_cuenta = p_nro_cuenta;
     if v_estado in ('C','P') then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
        raise fin_por_error;
     elsif v_cod_moneda <> paw_cel.v_cod_mon_local then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Moneda de la Cuenta invalida';
        raise fin_por_error;
     elsif v_nro_ref_externo is not null then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_ope_no_permitida;
        paw_cel.v_msj_respuesta := 'Ya se tiene registrado un IdCuenta para la Cuenta '||p_nro_cuenta;
        raise fin_por_error;
     else
       -- actualizo el nro de referencia
       update ah_cta_vistas
          set nro_ref_externo = p_nro_ref_externo
        where nro_cuenta = p_nro_cuenta;
     end if;
    lp_reg_operacion(p_nro_operacion,
                     p_fec_transaccion,
                     p_nro_ref_externo,
                     p_nro_celular,
                     14 /*p_tip_transaccion*/
                     );
    return lf_gen_respuesta('');
  exception
     when fin_por_error then
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         14 /*p_tip_transaccion*/
                         );
        return lf_gen_respuesta('');
     when dup_val_on_index then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_duplicada;
        paw_cel.v_msj_respuesta := 'Nro. de Celular duplicado';
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         14 /*p_tip_transaccion*/
                         );
        return lf_gen_respuesta('');
     when no_data_found then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
        paw_cel.v_msj_respuesta := 'Cuenta inexistente';
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         14 /*p_tip_transaccion*/
                         );
        return lf_gen_respuesta('');
     when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
        paw_cel.v_msj_respuesta := 'Otro error: '||substr(sqlerrm,1,500);
        lp_reg_operacion(p_nro_operacion,
                         p_fec_transaccion,
                         p_nro_ref_externo,
                         p_nro_celular,
                         14 /*p_tip_transaccion*/
                         );
        return lf_gen_respuesta('');
  end;
  --

  -- Funcion que inserta datos de la Persona, Cliente y Cuentas de Ahorro Vista.
  function crearCuenta(p_nro_operacion   in number,
                       p_fec_transaccion in varchar2,
                       p_nro_ref_externo in varchar2,
                       p_nro_celular     in varchar2,
                       p_tip_usuario     in varchar2,
                       p_pri_nombre      in varchar2,
                       p_seg_nombre      in varchar2 default null,
                       p_pri_apellido    in varchar2,
                       p_seg_apellido    in varchar2 default null,
                       p_nro_documento   in varchar2,
                       p_fec_nacimiento  in varchar2,
                       p_est_civil       in varchar2,
                       p_nro_ruc         in varchar2 default null,
                       p_direccion       in varchar2,
                       p_departamento    in varchar2 default null,
                       p_ciudad          in varchar2,
                       p_barrio          in varchar2 default null,
                       p_piso            in varchar2 default null,
                       p_cod_postal      in varchar2 default null,
                       p_sexo            in varchar2,
                       p_telefono        in varchar2,
                       p_detalles        in varchar2)
  return varchar2
  is

    rg_par_cuentas       ge_seg_par_cuentas%rowtype;
    --
    v_cod_persona        ba_personas.cod_persona%type;
    v_codigo             ba_personas.cod_persona%type;
    v_cod_actividad      ba_personas.cod_actividad%type := 701;
    --
    v_cod_sexo           ba_per_fisicas.cod_sexo%type  := upper(p_sexo);
    v_est_civil          ba_per_fisicas.est_civil%type := upper(p_est_civil);
    --
    v_area               ba_telefonos.area%type;
    v_tipo               ba_telefonos.tipo%type;
    v_num_telefono       ba_telefonos.telefono%type;
    --
    v_direccion          ba_direcciones.direccion%type;
    v_obs_direccion      ba_direcciones.observacion%type;
    --
    v_cod_ciudad         ba_ciudades.cod_ciudad%type;
    v_cod_barrio         ba_barrios.cod_barrio%type;
    --
    v_cod_seg_cliente    ge_clientes.cod_seg_cliente%type := 971;
    v_cli_existe         ge_clientes.cli_especial%type := 'N';
    --
    v_nro_sec_movimiento ge_movimientos.nro_secuencia%type :=0;
    v_cod_tra_padre      ge_movimientos.cod_tra_padre%type := 401;
    --
    v_nro_cuenta         ah_cta_vistas.nro_cuenta%type;
    v_cod_modulo         ah_cta_vistas.cod_modulo%type    := 3;
    v_cod_modalidad      ah_cta_vistas.cod_modalidad%type := 31;
    v_estado             ah_cta_vistas.estado%type        := 'A'; -- Estado de la Cuenta
    v_denominacion       ah_cta_vistas.denominacion%type;
    v_tas_existe         ah_cta_vistas.tas_personalizada%type := 'N';
    v_ret_existe         ah_cta_vistas.ret_personalizada%type := 'N';
    v_tra_existe         ah_cta_vistas.tra_prohibida%type     := 'N';
    --
    v_embozado           ah_tar_debitos.embozado%type;
    v_fec_vencimiento    ah_tar_debitos.fec_vencimiento%type;
    --
    v_observacion        varchar2(50):= 'MONEDERO ELECTRONICO';
    v_anio               varchar2(10);
    v_valor              number(30);
    v_fec_nacimiento date := to_date(p_fec_nacimiento,'YYYYMMDD');

    -- Obtiene los Parámetros de las Tasa y Tarifas.
    cursor cta_tas is
        select cod_tasa, valor
          from ge_seg_par_cta_tas
         where cod_modulo      = v_cod_modulo
           and cod_modalidad   = v_cod_modalidad
           and cod_seg_cliente = v_cod_seg_cliente
           and cod_moneda      = v_cod_mon_local;
    -- Obtiene parámetros de Retenciones.
    cursor cta_ret is
        select cod_retencion, can_dia_retencion
          from ge_seg_par_cta_ret
         where cod_modulo      = v_cod_modulo
           and cod_modalidad   = v_cod_modalidad
           and cod_seg_cliente = v_cod_seg_cliente
           and cod_moneda      = v_cod_mon_local;
    -- Obtiene parámetros de Transacciones Prohibidas.
    cursor cta_tra is
        select cod_transaccion, cod_mod_transaccion, cod_mad_transaccion
          from ge_seg_par_cta_tra
         where cod_modulo      = v_cod_modulo
           and cod_modalidad   = v_cod_modalidad
           and cod_seg_cliente = v_cod_seg_cliente
           and cod_moneda      = v_cod_mon_local;
    -- Busca si ya existe la persona o cliente
    function lf_obt_personas(p_nro_documento  varchar2,
                             p_pri_nombre     varchar2,
                             p_pri_apellido   varchar2,
                             p_seg_nombre     varchar2,
                             p_seg_apellido   varchar2,
                             v_cod_sexo           varchar2,
                             p_fec_nacimiento date) return varchar2 is
      v_per_existe    varchar2(1):= 'N';
      v_nro_documento ba_personas.nro_documento%type;
    begin
      -- Busca la personas en Gestión
      begin
        select cod_persona
          into v_codigo
          from ba_personas
         where nro_documento = p_nro_documento
           and cod_tip_documento = 1;
           v_per_existe := 'S';
      exception
        when no_data_found then
          v_per_existe := 'N';
        when others then
          paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
          paw_cel.v_msj_respuesta := 'Error al buscar la persona. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
          raise fin_por_error;
      end;
      if v_per_existe = 'S' then
        -- Si el documento existe busca si el primer nombre y primer apellido son iguales con el ingresado.
        begin
          select 'S'
            into v_per_existe
            from ba_per_fisicas
           where upper(ltrim(rtrim(pri_nombre)))  = upper(ltrim(rtrim(p_pri_nombre)))
             and upper(ltrim(rtrim(pri_apellido))) = upper(ltrim(rtrim(p_pri_apellido)))
             and cod_persona = v_codigo;
        exception
          when no_data_found then
            paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
            paw_cel.v_msj_respuesta := 'Existe una persona con el Documento Nro='||p_nro_documento;
            raise fin_por_error;
          when others then
            paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
            paw_cel.v_msj_respuesta := 'Error al buscar la Persona Física. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
            raise fin_por_error;
        end;
        begin
          select distinct 'S'
            into v_cli_existe
            from ge_clientes
           where cod_persona = v_codigo;
        exception
          when no_data_found then
            v_cli_existe := 'N';
          when others then
            paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
            paw_cel.v_msj_respuesta := 'Error al buscar el Cliente. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
            raise fin_por_error;
        end;
      else
        declare

        begin
          select p.nro_documento
            into v_nro_documento
            from ba_personas p,
                 ba_per_fisicas pf
           where p.cod_persona = pf.cod_persona
             and upper(ltrim(rtrim(pri_nombre)))  = upper(ltrim(rtrim(p_pri_nombre)))
             and upper(ltrim(rtrim(pri_apellido))) = upper(ltrim(rtrim(p_pri_apellido)))
             and upper(ltrim(rtrim(nvl(seg_nombre,'XX'))))  = upper(ltrim(rtrim(nvl(p_seg_nombre,'XX'))))
             and upper(ltrim(rtrim(nvl(seg_apellido,'XX')))) = upper(ltrim(rtrim(nvl(p_seg_apellido,'XX'))))
             and fec_nacimiento = v_fec_nacimiento
             and cod_sexo = nvl(v_cod_sexo,'X')
             and rownum = 1;
         exception
           when no_data_found then
             v_per_existe := 'N';
           when others then
             paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
             paw_cel.v_msj_respuesta := 'Error al buscar Personas Parecidas. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
             raise fin_por_error;
         end;
         if v_nro_documento is not null then
             paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
             paw_cel.v_msj_respuesta := 'Existen personas parecidas para '||p_pri_nombre||' '||p_pri_apellido||' verifique en el sistema el Documento Nro='||v_nro_documento||' '||substr(sqlerrm,1,500);
             raise fin_por_error;
         end if;
      end if;
      return v_per_existe;
    end;
    -- Recupera el nombre que puede ser almacenado dependiendo de la cantidad de caracteres permitidos
    function lf_obt_nombre(p_pri_nombre   varchar2,
                           p_seg_nombre   varchar2,
                           p_pri_apellido varchar2,
                           p_seg_apellido varchar2,
                           p_tamano       number) return varchar2 is
     v_nombre varchar2(120);
    begin
      if length(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano then
        if length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano then
          if length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano then
            v_nombre := p_pri_nombre||' '||p_pri_apellido;
          else
            v_nombre := p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido;
          end if;
        else
          v_nombre := p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido;
        end if;
      else
        v_nombre := p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido;
      end if;
      return v_nombre;
    end;
    --
    procedure lp_obt_dat_cuentas is
    begin
      -- Obtiene parámetros de la Cuenta.
      begin
        select tip_extracto, cod_ente,
               min_pactado, tip_capitalizacion,
               cod_tasa, gen_tar_debito
          into rg_par_cuentas.tip_extracto, rg_par_cuentas.cod_ente,
               rg_par_cuentas.min_pactado, rg_par_cuentas.tip_capitalizacion,
               rg_par_cuentas.cod_tasa, rg_par_cuentas.gen_tar_debito
          from ge_seg_par_cuentas
         where cod_modulo      = v_cod_modulo
           and cod_modalidad   = v_cod_modalidad
           and cod_seg_cliente = v_cod_seg_cliente
           and cod_moneda      = v_cod_mon_local;
      exception
        when others then
          paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
          paw_cel.v_msj_respuesta := 'Error al buscar Parámetros de Segmento del '||initcap(v_observacion)||substr(sqlerrm,1,500);
          raise fin_por_error;
      end;
    end;
    --
    function lf_obt_tie_cuenta(p_cod_persona varchar2) return varchar2 is
      v_existe varchar2(1);
    begin
      -- Busca cuentas de ahorros activas de la persona.
      select distinct('S')
        into v_existe
        from ah_cta_vistas v,
             ge_est_cuentas e,
             ge_cta_clientes c
       where v.nro_cuenta    = c.nro_cuenta
         and v.Cod_Modulo    = e.cod_modulo
         and v.cod_modalidad = e.cod_modalidad
         and v.estado        = e.estado
         and v.cod_modalidad = 31
         and v.cod_moneda    = v_cod_mon_local
         and e.activo        = 'S'
         and c.cod_persona   = p_cod_persona;

      return v_existe;
    exception
      when no_data_found then
        return 'N';
      when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cta_duplicada;
        paw_cel.v_msj_respuesta := 'Error al buscar Cuentas de Ahorro activas';
        raise fin_por_error;
    end;
    -- INICIO PROCESO PRINCIPAL --
  BEGIN
    --
    paw_cel.lp_ini_respuesta;
    --
    -- Validaciones de los parámetros --
    if length(p_nro_ref_externo)< 1 or length(p_nro_ref_externo) > 10 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'El parámetro Número de Referencia Externo es Incorrecto.';
      raise fin_por_error;
    elsif length(p_telefono) < 6 or length(p_telefono) > 10 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'El parámetro Número de Teléfono es Incorrecto.';
      raise fin_por_error;
    elsif length(p_pri_nombre) > 30 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'La longitud del Parámetro Primer Nombre es superior a 30 caracteres.';
      raise fin_por_error;
    elsif length(p_pri_apellido) > 30 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'La longitud del Parámetro Primer Apellido es superior a 30 caracteres.';
      raise fin_por_error;
    elsif length(p_seg_nombre) > 30   then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'La longitud del Parámetro Segundo Nombre es superior a 30 caracteres.';
      raise fin_por_error;
    elsif length(p_seg_apellido) > 30 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'La longitud del Parámetro Segundo Apellido es superior a 30 caracteres.';
      raise fin_por_error;
    elsif v_fec_nacimiento > v_fec_actual or v_fec_nacimiento < to_date('01011908','ddmmyyyy') then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'El parámetro de fecha de Nacimiento es Incorrecta.';
      raise fin_por_error;
    elsif length(p_direccion) > 80 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'La longitud del parámetro de dirección es mayor a 80 caracteres.';
      raise fin_por_error;
    elsif length(p_ciudad) > 35 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'La longitud de la Ciudad es mayor a 35 caracteres.';
      raise fin_por_error;
    elsif length(p_barrio) > 40 then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'La longitud del Barrio es mayor a 35 caracteres.';
      raise fin_por_error;
    elsif p_tip_usuario not in (1,2,3) then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'El tipo de usuario solo puedes ser 1,2 o 3.';
      raise fin_por_error;
    end if;
    --
    declare
      v_parametro varchar2(30);
    begin
      v_parametro := ' Número de Referencia Externo ';
      v_valor     := to_number(p_nro_ref_externo);
      --
      v_parametro := ' Número de Teléfono ';
      v_valor     := to_number(p_telefono);
    exception
      when others then
        paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
        paw_cel.v_msj_respuesta := 'El parámetro '||v_parametro||'debe contener solo números.';
        raise fin_por_error;
    end;
    --
    declare
      v_existe varchar2(1);
    begin
      select distinct 'S'
        into v_existe
        from ba_cod_referencias
       where dominio = 'COD_SEXO'
         and val_minimo = v_cod_sexo;
    exception
      when others then
        paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
        paw_cel.v_msj_respuesta := 'El parámetro de Sexo es incorrecto.';
        raise fin_por_error;
    end;
    --
    declare
      v_existe varchar2(1);
    begin
      select distinct 'S'
        into v_existe
        from ba_cod_referencias
       where dominio = 'COD_EST_CIVIL'
         and val_minimo = v_est_civil;
    exception
      when others then
        paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
        paw_cel.v_msj_respuesta := 'El parámetro de Estado Civil es incorrecto.';
        raise fin_por_error;
    end;
    --
    if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
      -- Carga el segmento según el tipo de usuario.
      if p_tip_usuario = 1 then
        v_cod_seg_cliente := 971;
      elsif p_tip_usuario = 2 then
        v_cod_seg_cliente := 972;
      elsif p_tip_usuario = 3 then
        v_cod_seg_cliente := 973;
      end if;
      -- **DATOS PERSONAS** --
      if lf_obt_personas(p_nro_documento,p_pri_nombre,p_pri_apellido,p_seg_nombre,p_seg_apellido,v_cod_sexo,v_fec_nacimiento) = 'N' then
        -- ba_personas
        select s_cod_persona.nextval into v_cod_persona from dual;
        begin
          insert into ba_personas
            (cod_persona, nom_completo,
             tipo, cod_tip_documento,
             nro_documento, cod_pais, cod_actividad,
             est_verificacion, obs_verificacion)
          values
            (v_cod_persona, upper(p_pri_nombre)||' '||upper(p_seg_nombre)||' '||upper(p_pri_apellido)||' '||upper(p_seg_apellido),
             'F',1,
             p_nro_documento, v_cod_pais,v_cod_actividad,
             'V',v_observacion);
        exception
          when others then
            paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
            paw_cel.v_msj_respuesta := 'Error al insertar datos en BA_PERSONAS. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
            raise fin_por_error;
        end;
        --
        if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
          -- ba_per_fisicas
          begin
            insert into ba_per_fisicas
              (cod_persona, pri_nombre, pri_apellido,
               est_civil, cod_sexo, cod_pai_nacionalidad,
               seg_nombre, seg_apellido, fec_nacimiento)
            values
              (v_cod_persona,upper(p_pri_nombre),upper(p_pri_apellido),
               v_est_civil,v_cod_sexo, v_cod_pais,
               upper(p_seg_nombre),upper(p_seg_apellido), v_fec_nacimiento);
          exception
            when others then
              paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
              paw_cel.v_msj_respuesta := 'Error al insertar datos en BA_PER_FISICAS. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
              raise fin_por_error;
          end;
          --
          if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
            -- ba_direcciones
            if p_direccion is not null then
              -- Busca Ciudad
              if p_ciudad is not null then
                begin
                  select max(cod_ciudad)
                    into v_cod_ciudad
                    from ba_ciudades
                   where translate(upper(descripcion),'ÁÉÍÓÚ','AEIOU') like
                         '%'||ltrim(rtrim(translate(upper(p_ciudad),'ÁÉÍÓÚ','AEIOU')))||'%'
                     and cod_pais = v_cod_pais;
                exception
                  when no_data_found then
                    paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
                    paw_cel.v_msj_respuesta := 'La Ciudad ingresada no existe en el sistema.';
                    raise fin_por_error;
                  when others then
                    paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
                    paw_cel.v_msj_respuesta := 'Error al buscar la ciudad '||p_ciudad||'. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                    raise fin_por_error;
                end;
              else
                v_cod_ciudad := null;
              end if;
              --
              if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                -- Busca Barrio
                if p_barrio is not null and p_ciudad is not null then
                  begin
                    select cod_barrio
                      into v_cod_barrio
                      from ba_barrios
                     where cod_ciudad = v_cod_ciudad
                       and translate(upper(descripcion),'ÁÉÍÓÚ','AEIOU') like
                           '%'||ltrim(rtrim(translate(upper(p_barrio),'ÁÉÍÓÚ','AEIOU')))||'%'
                           AND ROWNUM = 1;
                  exception
                    when no_data_found then
                      v_cod_barrio := null;
                    when others then
                      paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
                      paw_cel.v_msj_respuesta := 'Error al buscar el barrio '||p_barrio||'. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                      raise fin_por_error;
                  end;
                else
                  v_cod_barrio := null;
                end if;
                --
                if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                  if p_departamento is not null then
                    v_obs_direccion := 'Departamento '||p_departamento;
                  end if;
                  --
                  if p_piso is not null then
                    v_obs_direccion := v_obs_direccion||' Piso '||p_piso;
                  end if;
                  --
                  if p_cod_postal is not null then
                    v_obs_direccion := v_obs_direccion||' Cod. Postal '||p_cod_postal;
                  end if;
                  --
                  begin
                    v_direccion     := substr(upper(p_direccion),1,80);
                    --
                    insert into ba_direcciones
                      (cod_persona, cod_direccion, tipo, principal,
                       direccion, cod_pais, cod_ciudad, cod_barrio, observacion)
                    values
                      (v_cod_persona, 1, 'P', 'S',
                       v_direccion, v_cod_pais, v_cod_ciudad, v_cod_barrio, v_obs_direccion);
                    -- inserto la direccion de envio
                    insert into ge_dir_envios
                      (cod_persona,tip_envio, referencia)
                    values
                      (v_cod_persona, 'D', 1);
                  exception
                    when others then
                      paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
                      paw_cel.v_msj_respuesta := 'Error al insertar datos en BA_DIRECCIONES. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                      raise fin_por_error;
                  end;
                end if; -- fin control
              end if; -- fin control
            end if;
            --
            if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
              -- ba_telefonos
              if p_telefono is not null then
                if p_telefono like '09%' then
                  v_area := substr(p_telefono,1,4);
                  v_tipo := 'C';
                  v_num_telefono := substr(substr(p_telefono,5),1,10);
                else
                  v_area := null;
                  v_tipo := 'B';
                  v_num_telefono := substr(p_telefono,1,10);
                end if;
                begin
                  insert into ba_telefonos
                    (cod_persona, tipo, tip_linea, telefono, principal, area, cod_telefono)
                  values
                    (v_cod_persona, 'P', v_tipo, v_num_telefono, 'S',v_area, 1);
                exception
                  when others then
                    paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
                    paw_cel.v_msj_respuesta := 'Error al insertar datos en BA_TELEFONOS. Nro Documento='||p_nro_documento||' '||substr(sqlerrm,1,500);
                    raise fin_por_error;
                end;
              end if;
            end if; -- fin control
          end if; -- fin control
        end if; -- fin control
      else
        -- Si la persona existe carga la variable
        v_cod_persona := v_codigo;
      end if;
      --
      if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
        -- **CLIENTES** --
        if v_cli_existe = 'N' then
          begin
            insert into ge_clientes
              (cod_persona, cod_oficina, cod_usu_oficial,
               cod_seg_cliente,residente,cod_sec_contable,cod_tip_deudor)
            values
              (v_cod_persona, v_cod_ofi_origen, v_cod_usuario,
               v_cod_seg_cliente,'S','N',2);
          exception
            when others then
              paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
              paw_cel.v_msj_respuesta := 'Error al insertar datos en GE_CLIENTES. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
              raise fin_por_error;
          end;
        else
          begin
            update ge_clientes
               set cod_seg_cliente = v_cod_seg_cliente
             where cod_persona = v_cod_persona;
          exception
            when others then
              paw_cel.v_cod_respuesta := paw_cel.v_dat_per_invalido;
              paw_cel.v_msj_respuesta := 'Error al modificar datos en GE_CLIENTES. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
              raise fin_por_error;
          end;
        end if;
        if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
          /* se anula, porque siempre debe generar una cuenta nueva
          if lf_obt_tie_cuenta(v_cod_persona) = 'S' then
            paw_cel.v_cod_respuesta := paw_cel.v_cta_duplicada;
            paw_cel.v_msj_respuesta := 'El Cliente tiene Cuentas de Ahorro Vista Activa. Verifique.';
            raise fin_por_error;
          end if;
          */
          --
          if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
            -- ** CUENTA VISTAS ** --
            lp_obt_dat_cuentas;
            v_nro_cuenta := fug_obt_sig_nro_cuenta(v_cod_modulo,
                                                   v_cod_modalidad,
                                                   v_cod_ofi_origen,
                                                   v_cod_mon_local,
                                                   v_cod_persona);

            v_denominacion := upper(p_pri_nombre)||' '||upper(p_pri_apellido);
            -- ah_cta_vistas
            begin
              insert into ah_cta_vistas(nro_cuenta, dig_verificador, cod_modulo,
                                        cod_modalidad, cod_oficina, cod_moneda,
                                        denominacion, fre_extracto, fec_apertura,
                                        tip_capitalizacion, cod_tasa, est_batch,
                                        estado, nro_ref_externo,sal_minimo,reg_firma)
                                values (v_nro_cuenta, 0, v_cod_modulo,
                                        v_cod_modalidad, v_cod_ofi_origen, v_cod_mon_local,
                                        v_denominacion, rg_par_cuentas.tip_extracto, v_fec_actual,
                                        rg_par_cuentas.tip_capitalizacion, rg_par_cuentas.cod_tasa, v_estado,
                                        v_estado, p_nro_ref_externo,rg_par_cuentas.min_pactado,'INDIVIDUAL');
            exception
              when others then
                paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                paw_cel.v_msj_respuesta := 'Error al insertar Cuentas Vistas '||substr(sqlerrm,1,500);
                raise fin_por_error;
            end;
            --
            if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
              -- ge_cta_clientes
              begin
                insert into ge_cta_clientes
                  (cod_persona, nro_cuenta, dig_verificador,
                   cod_oficina, cod_modulo, cod_modalidad, relacion)
                values
                  (v_cod_persona, v_nro_cuenta, 0,
                   v_cod_ofi_origen, v_cod_modulo, v_cod_modalidad, 'P');
              exception
                when others then
                  paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                  paw_cel.v_msj_respuesta := 'Error al insertar datos en GE_CTA_CLIENTES. Documento Nro='||p_nro_documento||substr(sqlerrm,1,500);
                  raise fin_por_error;
              end;
              --
              if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                -- ge_movimientos
                v_nro_sec_movimiento := substr(v_nro_cuenta,-2,length(v_nro_cuenta));
                begin
                  insert into ge_movimientos
                    (fecha, hora, cod_usuario, nro_secuencia,
                     fec_valor, nro_cuenta, cod_moneda, cod_oficina,
                     est_cuenta, estado, cod_ofi_origen, concepto,
                     cod_tra_padre, cod_mod_padre, cod_mad_padre,
                     cod_transaccion, cod_modulo, cod_modalidad)
                  values
                    (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_sec_movimiento,
                     v_fec_actual, v_nro_cuenta, v_cod_mon_local, v_cod_ofi_origen,
                     'A', 'N',v_cod_ofi_origen, 'Cambio de Estado',
                     v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
                     v_cod_tra_padre, v_cod_modulo, v_cod_modalidad);
                exception
                  when others then
                    paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                    paw_cel.v_msj_respuesta := 'Error al insertar en GE_MOVIMIENTOS. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                    raise fin_por_error;
                end;
                --
                if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                  -- ge_ret_cuentas
                  for ret in cta_ret loop
                    v_ret_existe := 'S';
                    begin
                      insert into ge_ret_cuentas
                        (cod_retencion, nro_cuenta, can_dia_retencion,  observaciones)
                      values
                        (ret.cod_retencion, v_nro_cuenta, ret.can_dia_retencion, v_observacion);
                    exception
                      when others then
                        paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                        paw_cel.v_msj_respuesta := 'Error al insertar datos en GE_RET_CUENTAS. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                        raise fin_por_error;
                    end;
                  end loop;
                  --
                  if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                    -- ge_tra_prohibidas
                    for tra in cta_tra loop
                      v_tra_existe := 'S';
                      begin
                        insert into ge_tra_prohibidas
                          (cod_transaccion, cod_modulo, cod_modalidad,
                           nro_cuenta, observaciones)
                        values
                          (tra.cod_transaccion, tra.cod_mod_transaccion, tra.cod_mad_transaccion,
                           v_nro_cuenta, v_observacion);
                      exception
                        when others then
                          paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                          paw_cel.v_msj_respuesta := 'Error al insertar datos en GE_TRA_PROHIBIDAS. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                          raise fin_por_error;
                      end;
                    end loop;
                    if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                      -- ge_tas_fechas
                      for tas in cta_tas loop
                        v_tas_existe := 'S';
                        begin
                          insert into ge_tas_fechas
                            (cod_tasa, fec_vigencia, nro_cuenta, val_tasa, aplicar,  observaciones)
                          values
                            (tas.cod_tasa, v_fec_actual, v_nro_cuenta, tas.valor, 'ST', v_observacion);
                        exception
                          when others then
                            paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                            paw_cel.v_msj_respuesta := 'Error al insertar datos en GE_TAS_FECHAS. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                            raise fin_por_error;
                        end;
                      end loop;
                      --
                      if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                        if v_ret_existe <> 'N' or v_tas_existe <> 'N' or v_tra_existe <> 'N' then
                          -- actualiza la cuenta vista --
                          begin
                            update ah_cta_vistas
                               set ret_personalizada = v_ret_existe,
                                   tas_personalizada = v_tas_existe,
                                   tra_prohibida     = v_tra_existe
                             where nro_cuenta = v_nro_cuenta;
                          exception
                            when others then
                              paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                              paw_cel.v_msj_respuesta := 'Error al modificar AH_CTA_VISTAS. Documento Nro='||p_nro_documento||' '||substr(sqlerrm,1,500);
                              raise fin_por_error;
                          end;
                        end if;
                        if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                          -- Genera Tarjeta si en el parámetro lo inidica y no tiene Tarjeta de Débito --
                          if nvl(rg_par_cuentas.gen_tar_debito,'N') = 'S'  then
                            v_embozado := lf_obt_nombre(upper(p_pri_nombre),upper(p_seg_nombre),upper(p_pri_apellido),upper(p_seg_apellido),25);
                            --
                            begin
                              v_anio := fug_obt_pardinamico('VEN_TAR_DEBITOS',v_cod_modulo,v_cod_modalidad,v_cod_mon_local,v_cod_ofi_origen);
                              v_fec_vencimiento := last_day(add_months(v_fec_actual, (nvl(v_anio,3)*12)));
                              insert into ah_tar_debitos
                                (nro_cuenta, tar_activa, fec_ingreso,
                                 cod_persona, embozado, cod_usuario,
                                 fec_grabacion,  nro_emision,  cod_ofi_origen,
                                 fec_vencimiento, tip_envio, referencia, cod_est_solicitud)
                              values
                                (v_nro_cuenta, 'N', v_fec_actual,
                                 v_cod_persona, v_embozado, v_cod_usuario,
                                 v_fec_actual, '01', v_cod_ofi_origen,
                                 v_fec_vencimiento, 'D', 1, 2);
                            exception
                              when others then
                                paw_cel.v_cod_respuesta := paw_cel.v_dat_cta_invalida;
                                paw_cel.v_msj_respuesta := 'Error al insertar en AH_TAR_DEBITOS. Documento ='||p_nro_documento||' '||substr(sqlerrm,1,500);
                                raise fin_por_error;
                            end;
                          end if;
                        end if; -- fin control
                      end if; -- fin control
                    end if; -- fin control
                  end if; -- fin control
                end if; -- fin control
              end if; -- fin control
            end if; -- fin control
          end if; -- fin control
        end if; -- fin Control
      end if; -- fin Control
    end if; -- fin Control
    --
    if v_cod_respuesta = v_cod_aprobado then
       -- veo si hay cargos
       if p_detalles is not null then
          lp_pro_cur_pedidos(p_nro_operacion,
                             10,  -- tip_transaccion
                             p_fec_transaccion,
                             p_detalles);
       end if;
    end if;
    --
    lp_reg_operacion(p_nro_operacion,
                     p_fec_transaccion,
                     p_nro_ref_externo,
                     p_nro_celular,
                     10 /*p_tip_transaccion*/,
                     p_detalles);
    return lf_gen_respuesta(null);
  exception
    when fin_por_error then
     lp_reg_operacion(p_nro_operacion,
                      p_fec_transaccion,
                      p_nro_ref_externo,
                      p_nro_celular,
                      10 /*p_tip_transaccion*/,
                      p_detalles);
      return lf_gen_respuesta(null);
  end;
  -- Función que verifica si el registro fue conciliado o no
  function conciliado(p_nro_operacion   in number,   -- numero de operacion
                      p_tip_transaccion in varchar2, -- puede ser: 1-Extraccion, 2-Deposito, 3-Compra 4-Transferencia
                      p_nro_ref_externo in varchar2, -- nro unico de identificacion de la cuenta
                      p_tip_movimiento  in varchar2, -- puede ser: d-debito o c-credito
                      p_monto           in number,   -- Monto de la operacion
                      p_tip_concepto    in varchar2, -- Puede ser: 1-Cred.Comision, 2-Deb.Cargo, 3-Debito, 4-Credito
                      p_concepto        in varchar2)
  return varchar2 is
    v_monto            ge_movimientos.monto%type;
    v_cod_moneda       varchar2(5);
    v_estado           varchar2(1);
    v_nro_cuenta       varchar2(30);
    --
    v_cod_modulo       number(4);
    v_cod_modalidad    number(4);
    v_nvo_estado       varchar2(1) := null; -- cambio de estado de cuenta
    v_procesa          varchar2(1) := 'N';
    v_sal_disponible   number(18,2);
    --
    v_cod_tra_padre    number(5);
    v_cod_transaccion  number(5);
    v_existe           varchar2(1)  := null;
  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    if p_tip_transaccion not in ('1','2','3','4','5','6','7','8','9','10','11','12','13','15') then
       paw_cel.v_cod_respuesta := paw_cel.v_cod_tra_invalida;
       paw_cel.v_msj_respuesta := 'Transaccion debe ser 1,2,3,4,5,6,7,8,9,10,11,12,15 -> '||p_tip_transaccion;
       raise fin_por_error;
    elsif p_tip_movimiento not in ('D','C') then
       paw_cel.v_cod_respuesta := paw_cel.v_cod_ope_no_permitida;
       paw_cel.v_msj_respuesta := 'Tipo de Movimiento debe ser D/C. -> '||p_tip_movimiento;
       raise fin_por_error;
    elsif p_monto <= 0 then
       paw_cel.v_cod_respuesta := paw_cel.v_cod_mto_invalido;
       paw_cel.v_msj_respuesta := 'Monto invalido';
       raise fin_por_error;
    elsif p_tip_concepto not in ('1','2','3','4') then
       paw_cel.v_cod_respuesta := paw_cel.v_cod_tra_invalida;
       paw_cel.v_msj_respuesta := 'Concepto debe ser 1,2,3, 0 4. -> '||p_tip_concepto;
       raise fin_por_error;
    else
      --
      begin
        select a.nro_cuenta, a.cod_moneda cod_moneda,  estado
          into v_nro_cuenta, v_cod_moneda, v_estado
          from ah_cta_vistas a
         where a.nro_ref_externo = p_nro_ref_externo;
      exception
        when no_data_found then
            paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
            paw_cel.v_msj_respuesta := 'Cuenta inexistente con el Nro: '||p_nro_ref_externo;
            raise fin_por_error;
        when others then
          paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_inexistente;
          paw_cel.v_msj_respuesta := 'Error al buscar AH_CTA_VISTAS. '||substr(sqlerrm,1,500);
          raise fin_por_error;
      end;
      --
      if v_estado in ('X','A','C','P') then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Estado de la Cuenta invalido';
        raise fin_por_error;
      elsif v_cod_moneda <> paw_cel.v_cod_mon_local then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_cta_invalida;
        paw_cel.v_msj_respuesta := 'Moneda de la Cuenta invalida';
        raise fin_por_error;
      else
        -- Veo si se puede realizar la operacion
        --461 a 470
         if p_tip_transaccion = '1' then
            v_cod_tra_padre := 461;
         elsif p_tip_transaccion = '2' then
            v_cod_tra_padre := 462;
         elsif p_tip_transaccion = '3' then
            v_cod_tra_padre := 463;
         elsif p_tip_transaccion in ('4','13') then
            v_cod_tra_padre := 464;
         elsif p_tip_transaccion = '6' then
            v_cod_tra_padre := 465;
         elsif p_tip_transaccion = '7' then
            v_cod_tra_padre := 466;
         elsif p_tip_transaccion = '10' then
            v_cod_tra_padre := 467;
         elsif p_tip_transaccion = '15' then
            v_cod_tra_padre := 468;
         elsif p_tip_transaccion in ('11','12') then -- reversiones
            v_cod_tra_padre := 469;
         else
           paw_cel.v_cod_respuesta := paw_cel.v_cod_tra_invalida;
           paw_cel.v_msj_respuesta := 'Transacción '||p_tip_transaccion||' no definida';
           raise fin_por_error;
         end if;
         -- Puede ser: 1-Cred.Comision, 2-Deb.Cargo, 3-Debito, 4-Credito
         if p_tip_concepto = '1' then
            v_cod_transaccion := 472;
         elsif p_tip_concepto = '2' then
            v_cod_transaccion := 471;
         elsif p_tip_concepto = '3' then
            v_cod_transaccion := 473;
         elsif p_tip_concepto = '4' then
            v_cod_transaccion := 474;
         end if;
        -- verifico si el tipo de movimiento corresponde a la transaccion recibida
        declare
          v_tipo varchar2(1);
        begin
          select tipo
            into v_tipo
            from ge_transacciones
           where cod_transaccion = v_cod_transaccion
             and cod_modulo = 3
             and cod_modalidad = 31;
          if v_tipo <> p_tip_movimiento then
            v_cod_respuesta := paw_cel.v_cod_tra_invalida;
            v_msj_respuesta := 'Tipo de Mov. '||p_tip_movimiento||' no coincide con la Transaccion 3-31-'||v_cod_transaccion||' es de tipo '||v_tipo;
            raise fin_por_error;
          end if;
        exception
          when  fin_por_error then
             raise fin_por_error;
          when no_data_found then
             v_cod_respuesta := paw_cel.v_cod_tra_invalida;
             v_msj_respuesta := 'Transaccion 3-31-'||v_cod_transaccion||' no definida ';
             raise fin_por_error;
          when others then
             v_cod_respuesta := paw_cel.v_cod_tra_invalida;
             v_msj_respuesta := 'Transaccion 3-31-'||v_cod_transaccion||' con el error: '||sqlerrm;
             raise fin_por_error;
        end;
        --
        if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
          if pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,v_cod_tra_padre, 3, 31) = 'S' then
            v_cod_respuesta := paw_cel.v_cod_tra_prohibida;
            v_msj_respuesta := 'Transaccion 3-31-'||v_cod_tra_padre||' prohibida para la Cta. '||v_nro_cuenta;
            raise fin_por_error;
          elsif fu_es_conjunta(v_nro_cuenta) = 'S' and p_tip_movimiento = 'D' then
            v_cod_respuesta := paw_cel.v_cod_tra_invalida;
            v_msj_respuesta := 'Cuenta conjunta no permite debitos';
            raise fin_por_error;
          else
            pag_cta.pr_ver_operacion(v_nro_cuenta,v_cod_tra_padre,3,31,p_tip_movimiento,v_cod_moneda, p_monto, v_cod_ofi_origen,
                                     v_cod_modulo, v_cod_modalidad, v_nvo_estado, v_sal_disponible, v_procesa,v_cod_transaccion);
            if v_procesa = 'N' then
              -- no se puede debitar
              if instr(upper(pag_cta.G_MSJ_ERROR),'INSUFIC') > 0 then
                -- saldo insuficiente
                v_cod_respuesta := paw_cel.v_cod_sal_insuficiente;
                v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
                raise fin_por_error;
              else
                v_cod_respuesta := paw_cel.v_cod_cta_bloqueada;
                v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
                raise fin_por_error;
              end if;
            else
              -- se puede hacer la operacion
              lp_ver_horario;
              -- valido la duplicacion de movimientos
              if paw_cel.v_cod_respuesta = paw_cel.v_cod_aprobado then
                begin
                  if v_es_mov_noc = 'S' then
                    select distinct 'S', monto
                      into v_existe, v_monto
                      from ge_movimientos_noc
                     where nro_cuenta      = v_nro_cuenta
                       and cod_tra_padre   = v_cod_tra_padre
                       and cod_transaccion = v_cod_transaccion
                       and nro_documento   = p_nro_operacion
                       and reversado       = 'N'
                       and cod_usuario     = v_cod_usuario
                       and monto           = p_monto
                       and concepto        like p_concepto||'%'
                       and rownum          = 1;
                  else
                    select distinct 'S'
                      into v_existe
                      from ge_movimientos
                     where nro_cuenta      = v_nro_cuenta
                       and cod_tra_padre   = v_cod_tra_padre
                       and cod_transaccion = v_cod_transaccion
                       and nro_documento   = p_nro_operacion
                       and reversado       = 'N'
                       and cod_usuario     = v_cod_usuario
                       and monto           = p_monto
                       and concepto        like p_concepto||'%'
                       and rownum          = 1;
                  end if;
                exception
                  when no_data_found then
                    begin
                      if v_es_mov_noc = 'S' then
                        select distinct 'S', monto
                          into v_existe, v_monto
                          from ge_movimientos_noc
                         where nro_cuenta      = v_nro_cuenta
                           and cod_tra_padre   = v_cod_tra_padre
                           and cod_transaccion = v_cod_transaccion
                           and nro_documento   = p_nro_operacion
                           and reversado       = 'N'
                           and cod_usuario     = v_cod_usuario
                           and concepto        like p_concepto||'%'
                           and rownum          = 1;
                      else
                        select distinct 'S', monto
                          into v_existe, v_monto
                          from ge_movimientos
                         where nro_cuenta      = v_nro_cuenta
                           and cod_tra_padre   = v_cod_tra_padre
                           and cod_transaccion = v_cod_transaccion
                           and nro_documento   = p_nro_operacion
                           and reversado       = 'N'
                           and cod_usuario     = v_cod_usuario
                           and concepto        like p_concepto||'%'
                           and rownum          = 1;
                      end if;
                      -- Controla si el monto es diferente.
                      if v_existe = 'S' and p_monto <> v_monto then
                        v_existe := 'N';
                        paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
                        paw_cel.v_msj_respuesta := 'Montos diferentes para el Movimiento';
                        raise fin_por_error;
                      end if;
                    exception
                      when no_data_found then
                        v_existe := 'N';
                        paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
                        paw_cel.v_msj_respuesta := 'Movimiento no registrado';
                        raise fin_por_error;
                      when others then
                         paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
                         paw_cel.v_msj_respuesta := 'Movimiento ya ingresado';
                         raise fin_por_error;
                    end;
                  when others then
                    paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
                    paw_cel.v_msj_respuesta := 'Movimiento ya ingresado';
                    raise fin_por_error;
                end;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
    return v_existe;
  exception
    when fin_por_error then
      return 'N';
  end;
  --
  -- Reversión de Operaciones
  function revertirTransaccion(p_nro_operacion     in number,
                               p_fec_transaccion   in varchar2,
                               p_nro_ope_revertir  in number,
                               p_fec_tra_revertir  in varchar2,
                               p_tip_reversion     in number, -- 11-manual 12- automático
                               p_motivo            in varchar2,
                               p_detalles          in varchar2 default null)
  return varchar2 is
    v_fecha         ge_movimientos.fecha%type;
    v_hora          ge_movimientos.hora%type;
    v_cod_usuario   ge_movimientos.cod_usuario%type;
    v_cod_mod_padre ge_movimientos.cod_mod_padre%type;
    v_cod_mad_padre ge_movimientos.cod_mad_padre%type;
    v_cod_tra_padre ge_movimientos.cod_tra_padre%type;
  begin
    --
    paw_cel.lp_ini_respuesta;
    if p_tip_reversion not in (11,12) then
      paw_cel.v_cod_respuesta := paw_cel.v_par_invalido;
      paw_cel.v_msj_respuesta := 'Tipo de reversión debe ser 11 o 12.';
    end if;
    -- Busca el movimiento.
    begin
      select distinct m.fecha, m.hora, m.cod_usuario, m.cod_mod_padre, m.cod_mad_padre, m.cod_tra_padre
        into v_fecha, v_hora, v_cod_usuario, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre
        from ge_movimientos m
       where m.nro_documento = p_nro_ope_revertir
         and m.concepto like 'Fec:'||p_fec_tra_revertir||'%'
         and m.reversado = 'N';
    exception
      when no_data_found then
        begin
          select distinct m.fecha, m.hora, m.cod_usuario, m.cod_mod_padre, m.cod_mad_padre, m.cod_tra_padre
            into v_fecha, v_hora, v_cod_usuario, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre
            from ge_movimientos_noc m
           where m.nro_documento = p_nro_ope_revertir
             and m.concepto like 'Fec:'||p_fec_tra_revertir||'%'
             and m.reversado = 'N';
        exception
          when no_data_found then
            begin
              select distinct m.fecha, m.hora, m.cod_usuario, m.cod_mod_padre, m.cod_mad_padre, m.cod_tra_padre
                into v_fecha, v_hora, v_cod_usuario, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre
                from ah_movimientos_his m
               where m.nro_documento = p_nro_ope_revertir
                 and m.concepto like 'Fec:'||p_fec_tra_revertir||'%'
                 and m.reversado = 'N';
            exception
              when no_data_found then
                paw_cel.v_cod_respuesta := v_cod_aprobado;
                paw_cel.v_msj_respuesta := 'No existen movimientos para reversion';
                raise fin_por_error;
              when others then
                paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
                paw_cel.v_msj_respuesta := 'Error al Buscar el movimiento. '||substr(sqlerrm,1,500);
                raise fin_por_error;
            end;
          when too_many_rows then
            paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
            paw_cel.v_msj_respuesta := 'Existe más de una operacion con el Nro: '||p_nro_ope_revertir;
            raise fin_por_error;
          when others then
            paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
            paw_cel.v_msj_respuesta := 'Error al Buscar el movimiento. '||substr(sqlerrm,1,500);
            raise fin_por_error;
        end;

      when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
        paw_cel.v_msj_respuesta := 'Error al Buscar el movimiento. '||substr(sqlerrm,1,500);
        raise fin_por_error;
    end;
    -- Genera la Reversión.
    begin
      prg_rev_operacion( v_fecha, v_hora, v_cod_usuario,
                         v_cod_mod_padre, v_cod_mad_padre,
                         v_cod_tra_padre,v_cod_usuario,v_hor_actual,v_es_mov_noc,p_motivo);
    exception
      when others then
        paw_cel.v_cod_respuesta := paw_cel.v_cod_mov_ya_ingresado;
        paw_cel.v_msj_respuesta := 'Error en Reversion: '||translate(substr(sqlerrm,1,500),'1234567890',' ');
        raise fin_por_error;
    end;
    -- veo si hay cargos
    if p_detalles is not null then
      lp_pro_cur_pedidos(p_nro_operacion,
                         p_tip_reversion,
                         p_fec_transaccion,
                         p_detalles,
                         100);
    end if;
    --
    lp_reg_operacion(p_nro_operacion,
                     p_fec_transaccion,
                     '',
                     '',
                     p_tip_reversion,
                     p_detalles);
    --
    return lf_gen_respuesta(null);
    --
  exception
    when fin_por_error then
     lp_reg_operacion(p_nro_operacion,
                     p_fec_transaccion,
                     '',
                     '',
                     p_tip_reversion,
                     p_detalles);
      return lf_gen_respuesta(null);
  end;

  -- Actualiza código del Resumen Diario
  function procesarResumenDiario(p_nro_ope_grupo number default null,
                                 p_fecha         date   default null)
  return varchar2 is
    v_fec_actual      date := pag_cal.fu_obt_fec_actual(9);
    v_fecha           date;
    v_cod_error       varchar2(3);
    v_nro_ref_externo varchar2(20);
    v_nro_operacion   number(20);
    fin_por_error     exception;
    v_proceso         varchar2(1);
    --
    cursor res_dia is select a.*, rowid fila from bw_res_dia_servicios a
                       where fec_proceso = v_fecha
                         and nro_ope_grupo = nvl(p_nro_ope_grupo,nro_ope_grupo)
                         and nvl(cod_error,'x') <> '0';
  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    if p_fecha is not null then
      v_fecha := p_fecha;
    else
      v_fecha := v_fec_actual;
    end if;
    --
    /* anulado porque no debe hacer nada
    for r in res_dia loop
      v_proceso := 'S';
      paw_cel.pr_act_operacion(r.nro_operacion,r.tip_transaccion,
                               r.nro_ref_externo,r.tip_movimiento,
                               r.monto,r.tip_concepto,
                               substr('Fec:'||r.fec_transaccion||' Nro:'||r.nro_movimiento,1,35));
     -- Solo si el error es diferente al original hace la modificación
      if nvl(r.cod_error,'x') <> paw_cel.v_cod_respuesta then
        begin
          update bw_res_dia_servicios
             set cod_error = paw_cel.v_cod_respuesta,
                 msj_error = paw_cel.v_msj_respuesta
           where rowid = r.fila;
        exception
          when others then
            paw_cel.v_cod_respuesta := paw_cel.v_err_dat_res_servicio;
            paw_cel.v_msj_respuesta := 'Error al Modificar Resumen del Día. '||substr(sqlerrm,1,500);
            raise fin_por_error;
        end;
      end if;
    end loop;
    --
    if v_proceso is null then
      paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
      paw_cel.v_msj_respuesta := 'No existen registros a procesar.';
      raise fin_por_error;
    end if;
    */
    --
    if p_nro_ope_grupo is not null then
      lp_reg_operacion(p_nro_ope_grupo,
                       to_char(v_fecha,'YYYYMMDDHH24MISS'),
                       '',
                       '',
                       16,
                       '');
    end if;
    --
    return lf_gen_respuesta(null);
    --
  exception
    when fin_por_error then
      if p_nro_ope_grupo is not null then
        lp_reg_operacion(p_nro_ope_grupo,
                         to_char(v_fecha,'YYYYMMDDHH24MISS'),
                         '',
                         '',
                         16,
                         '');
      end if;
      return lf_gen_respuesta(null);
  end;

  -- Actualiza el código de Conciliado
  function procesarConciliado(p_nro_ope_grupo number default null,
                             p_fecha         date   default null)
  return varchar2 is
    cursor res_dia is select s.*, rowid fila from bw_con_servicios s
                       where fec_proceso   = nvl(p_fecha,fec_proceso)
                         and nro_ope_grupo = nvl(p_nro_ope_grupo,nro_ope_grupo)
                         and conciliado    = 'N';
    v_conciliado  varchar2(1);
    fin_por_error exception;
  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    for r in res_dia loop
      v_conciliado := paw_cel.conciliado(r.nro_operacion,r.tip_transaccion,
                                         r.nro_ref_externo,r.tip_movimiento,
                                         r.monto,r.tip_concepto,
                                         substr('Fec:'||r.fec_transaccion||' Nro:'||r.nro_movimiento,1,35));
      if nvl(r.cod_error,'x') <> paw_cel.v_cod_respuesta then
        begin
          update bw_con_servicios c
             set cod_error  = paw_cel.v_cod_respuesta,
                 msj_error  = paw_cel.v_msj_respuesta,
                 conciliado = v_conciliado
           where rowid = r.fila;
        exception
          when others then
            paw_cel.v_cod_respuesta := paw_cel.v_err_dat_conciliado;
            paw_cel.v_msj_respuesta := 'Error al Modificar Concilido. '||substr(sqlerrm,1,500);
            raise fin_por_error;
        end;
      end if;
    end loop;
    --
    if v_conciliado is null then
      paw_cel.v_cod_respuesta := paw_cel.v_cod_otr_error;
      paw_cel.v_msj_respuesta := 'No existen registros a procesar.';
      raise fin_por_error;
    end if;

    if p_nro_ope_grupo is not null then
      lp_reg_operacion(p_nro_ope_grupo,
                       to_char(p_fecha,'YYYYMMDDHH24MISS'),
                       '',
                       '',
                       17,
                       '');
    end if;
    --

    return lf_gen_respuesta(null);
    --
  exception
    when fin_por_error then
      if p_nro_ope_grupo is not null then
         lp_reg_operacion(p_nro_ope_grupo,
                         to_char(p_fecha,'YYYYMMDDHH24MISS'),
                         '',
                         '',
                         17,
                         '');
      end if;
      return lf_gen_respuesta(null);
  end;

  -- Función que inserta registros en BW_RES_DIA_SERVICIOS
  function insertarResumenDiario(p_nro_grupo number,
                                p_nro_ref_externo varchar2,
                                p_nro_movil       varchar2,
                                p_tipo            varchar2, -- Tipo de Movimiento
                                p_monto           number,
                                p_tip_concepto    varchar2,
                                p_tip_transaccion varchar2,
                                p_nro_operacion   number,
                                p_fec_transaccion varchar2,
                                p_nro_movimiento  number)
  return varchar2 is
  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    insert into bw_res_dia_servicios(nro_ref_externo,
                                     tip_movimiento,
                                     monto,
                                     tip_concepto,
                                     nro_operacion,
                                     tip_transaccion,
                                     fec_proceso,
                                     usu_proceso,
                                     nro_ope_grupo,
                                     nro_movil,
                                     fec_transaccion,
                                     nro_movimiento)
                             values (p_nro_ref_externo,
                                     p_tipo,
                                     p_monto,
                                     p_tip_concepto,
                                     p_nro_operacion,
                                     p_tip_transaccion,
                                     v_fec_actual,
                                     v_cod_usuario,
                                     p_nro_grupo,
                                     p_nro_movil,
                                     p_fec_transaccion,
                                     p_nro_movimiento);
    return lf_gen_respuesta(null);
  exception
    when others then
      paw_cel.v_cod_respuesta := paw_cel.v_err_dat_res_servicio;
      paw_cel.v_msj_respuesta := 'Error al Insertar en BW_RES_DIA_SERVICIOS. '||substr(sqlerrm,1,500);
      return lf_gen_respuesta(null);
  end;
  -- Función que elimina registros de BW_RES_DIA_SERVICIOS
  function eliminarResumenDiario(p_nro_grupo number)
  return varchar2 is
  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    delete bw_res_dia_servicios
     where nro_ope_grupo = p_nro_grupo
       and not exists (select 1 from bw_res_dia_servicios
                        where nro_ope_grupo = p_nro_grupo
                          and cod_error is not null);
    --
    If sql%notfound then
      paw_cel.v_cod_respuesta := v_cod_aprobado; --paw_cel.v_cod_otr_error;
      --paw_cel.v_msj_respuesta := 'No existen Datos a Eliminar.';
      paw_cel.v_msj_respuesta :=  '';
    end if;
    --
    return lf_gen_respuesta(null);
  exception
    when others then
      paw_cel.v_cod_respuesta := paw_cel.v_err_dat_res_servicio;
      paw_cel.v_msj_respuesta := 'Error al Eliminar en BW_RES_DIA_SERVICIOS. '||substr(sqlerrm,1,500);
      return lf_gen_respuesta(null);
  end;
  -- Función que inserta registros en BW_CON_SERVICIOS
  function insertarConciliado(p_nro_grupo number,
                             p_nro_ref_externo varchar2,
                             p_nro_movil       varchar2,
                             p_tipo            varchar2, -- Tipo de Movimiento
                             p_monto           number,
                             p_tip_concepto    varchar2,
                             p_tip_transaccion varchar2,
                             p_nro_operacion   number,
                             p_fec_transaccion varchar2,
                             p_nro_movimiento  number)
  return varchar2 is
  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    insert into bw_con_servicios (nro_ref_externo,
                                  tip_movimiento,
                                  monto,
                                  tip_concepto,
                                  nro_operacion,
                                  tip_transaccion,
                                  fec_proceso,
                                  usu_proceso,
                                  nro_ope_grupo,
                                  nro_movil,
                                  fec_transaccion,
                                  nro_movimiento)
                           values(p_nro_ref_externo,
                                  p_tipo,
                                  p_monto,
                                  p_tip_concepto,
                                  p_nro_operacion,
                                  p_tip_transaccion,
                                  v_fec_actual,
                                  v_cod_usuario,
                                  p_nro_grupo,
                                  p_nro_movil,
                                  p_fec_transaccion,
                                  p_nro_movimiento);
    return lf_gen_respuesta(null);
  exception
    when others then
      paw_cel.v_cod_respuesta := paw_cel.v_err_dat_conciliado;
      paw_cel.v_msj_respuesta := 'Error al Insertar en BW_CON_SERVICIOS. '||substr(sqlerrm,1,500);
      return lf_gen_respuesta(null);
  end;
  -- Función que elimina registros de BW_CON_SERVICIOS
  function eliminarConciliado(p_nro_grupo number)
  return varchar2 is
  begin
    --
    paw_cel.lp_ini_respuesta;
    --
    delete bw_con_servicios
     where nro_ope_grupo = p_nro_grupo
       and not exists (select 0 from bw_con_servicios
                        where nro_ope_grupo = p_nro_grupo
                          and cod_error is not null);
    --
    If sql%notfound then
      paw_cel.v_cod_respuesta := v_cod_aprobado; -- paw_cel.v_cod_otr_error;
      paw_cel.v_msj_respuesta := ''; -- 'No existen Datos a Eliminar.';
    end if;
    --
    return lf_gen_respuesta(null);
  exception
    when others then
      paw_cel.v_cod_respuesta := paw_cel.v_err_dat_conciliado;
      paw_cel.v_msj_respuesta := 'Error al Eliminar en BW_CON_SERVICIOS. '||substr(sqlerrm,1,500);
      return lf_gen_respuesta(null);
  end;
end paw_cel;
/


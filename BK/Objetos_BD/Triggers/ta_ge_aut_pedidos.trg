CREATE OR REPLACE TRIGGER IT."TA_GE_AUT_PEDIDOS"
  after INSERT OR UPDATE OR DELETE on GE_AUT_PEDIDOS
  for each row


declare
   v_cod_persona ba_personas.cod_persona%type;
   v_dir_correo  ba_usuarios.dir_correo%type;
   v_dir_correo_ent ge_par_generales.dir_correo%type;
   v_respuesta   varchar2(100);
   v_cod_gestor  ba_personas.cod_persona%type;
   v_nro_cuenta  lc_cta_cambios.nro_cuenta%type;
   v_nom_completo ba_personas.nom_completo%type;
   v_dir_correo_ges  ba_usuarios.dir_correo%type;
   v_cta_lim_glo    lc_cta_cambios.nro_cuenta%type;

  j_nro_cuenta       ge_movimientos.nro_cuenta%type;
   j_nro_documento    ge_movimientos.nro_documento%type;
   j_monto            ge_movimientos.monto%type;
   j_existe           varchar2(1);
   j_cod_moneda       ba_monedas.cod_moneda%type;
   j_cod_che_custodia cc_che_custodias_det.cod_che_custodia%type;
   j_cod_emisor       cc_che_custodias_det.cod_emisor%type;
   j_nro_cta_debito   cc_che_custodias_det.nro_cta_debito%type;
   k_nro_documento    cc_che_custodias_det.nro_documento%type;

begin

   v_dir_correo_ent := fug_obt_dir_correo;
   /*
   if inserting then
      --- Busco el email del autorizador
      begin
         select dir_correo
           into v_dir_correo
           from ba_usuarios
          where cod_usuario = :new.cod_usu_autorizador;
      exception
         when others then v_dir_correo := null;
      end;
      --- Generar agenda al autorizador solo si encuentra el mov.
      begin
        v_cod_persona := pag_aut.FU_OBT_PER_PEDIDO(:new.cod_usuario, :new.fecha, :new.hora);
      exception
      when others then
        null; --para q no caiga si no encuentra la persona
      end;
      if v_cod_persona is not null then
         insert into cr_agendas
           (cod_agenda, cod_persona, cod_usu_encargado,
            cod_actividad, cod_estado, cod_mot_actividad, fec_actividad,
            det_actividad)
         values
           (s_cod_agenda.nextval, v_cod_persona, :new.cod_usu_autorizador,
            3, 1, 20, pag_cal.FU_OBT_FEC_ACTUAL(3),
            'El usuario '||:new.cod_usuario||' solicita aprobación de operación excepcional'
           );
      end if;
      --- Enviar mail al autorizador
      if v_dir_correo is not null and v_dir_correo_ent is not null then
        it_mail.mail(v_dir_correo_ent,
                     v_dir_correo,
                     'Solicitud de autorizacion',
                     'El usuario '||:new.cod_usuario||' solicita autorización. '||chr(10)||
                     :new.mensaje);
      end if;
    --**************************************************
    --WA:07/2013 Enviar mail al Gestor de la cuenta , si es por superar Limite de Cambios
    if :new.tip_autorizacion ='L' then
         v_cod_persona:=null;
         v_nom_completo:=null;
         v_cod_gestor:=null;
         v_dir_correo_ges:=null;
         v_nro_cuenta:= null;
         begin
           --Bucamos el codigo de Persona del Cliente
           select  trim(a.cod_persona), trim(b.nom_completo) ,a.nro_cuenta
            into v_cod_persona,v_nom_completo,v_nro_cuenta
             from ge_movimientos a, ba_personas b
             where a.fecha= :new.fecha
              and a.hora= :new.hora
              and a.nro_secuencia=2
              and a.cod_persona=b.cod_persona;
         exception
          when no_data_found then
            v_cod_persona:=null;
            v_nom_completo:=null;
          when others then
            v_cod_persona:=null;
            v_nom_completo:=null;
         end;
         --Obtenemos el codigo del gestor, su direccion de Mail y enviamos el mail
         --Siempre y cuando no sea la Cuenta de Cambios Bolsa del Banco(0107010003)
         if v_cod_persona is not null and v_nro_cuenta <> '0107010003' then
            v_cod_gestor:= FUG_OBT_COD_USU_OFICIAL(v_cod_persona);
            if v_cod_gestor is not null then
              v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
            end if;

             --- Enviar mail al autorizador
             if v_dir_correo_ges is not null and v_dir_correo_ent is not null then
                it_mail.mail(v_dir_correo_ent,
                         v_dir_correo_ges,
                         'Informe de Pedido de Autorización de Cliente que Supera su Limite Asignado de Cta.de Cambios',
                         'Le informamos que se solicita Autorización para el Cliente: '||v_nom_completo || chr(10)||
                         :new.mensaje);
             end if;
         end if;
   end if;
    --**************************************
   elsif updating and nvl(:new.respuesta,' ') <> nvl(:old.respuesta,' ') then
      -- si se actualiza el pedido, se informa al solicitante
      --- Busco el email del solicitante del pedido----
      begin
         select dir_correo
           into v_dir_correo
           from ba_usuarios
          where cod_usuario = :new.cod_usuario;
      exception
         when others then v_dir_correo := null;
      end;
      if :new.respuesta = 'A' then
         v_respuesta := 'aprobado';
      elsif :new.respuesta = 'R' then
         v_respuesta := 'rechazado';
      end if;
      --- Enviar mail al solicitante de la autorizacion
      if v_dir_correo is not null and v_dir_correo_ent is not null then
        it_mail.mail(v_dir_correo_ent,
                     v_dir_correo,
                     'Pedido de Autorización '||v_respuesta,
                     'El usuario '||:new.cod_usu_autorizador||
                     ' ha '||v_respuesta||' su pedido de Autorizacion: '||chr(10)||
                     :new.mensaje||chr(10)||' Comentario del Autorizador: '||chr(10)||
                     :new.observacion);


      end if;
  */
  --wa: 07/2013 Para enviar mail por superar Limite de Cambios
  if updating and :old.tip_autorizacion ='L' then
        v_cod_persona:=null;
        v_nom_completo:=null;
        v_cod_gestor:=null;
        v_dir_correo_ges:=null;
        v_nro_cuenta:= null;
        begin
           --Bucamos el codigo de Persona del Cliente
           select  trim(a.cod_persona), trim(b.nom_completo),a.nro_cuenta
            into v_cod_persona,v_nom_completo,v_nro_cuenta
             from ge_movimientos a, ba_personas b
             where a.fecha= :new.fecha
              and a.hora= :new.hora
              and a.nro_secuencia=2
              and a.cod_persona=b.cod_persona;
         exception
          when no_data_found then
            v_cod_persona:=null;
            v_nom_completo:=null;
          when others then
            v_cod_persona:=null;
            v_nom_completo:=null;
         end;
         --Obtenemos el codigo del gestor, su direccion de Mail y enviamos el mail
         --Siempre y cuando no sea la Cuenta de Cambios Bolsa del Banco(0107010003)
         v_cta_lim_glo:= fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL');
         if v_cod_persona is not null and v_nro_cuenta <> v_cta_lim_glo then
            v_cod_gestor:= FUG_OBT_COD_USU_OFICIAL(v_cod_persona);
            if v_cod_gestor is not null then
              v_dir_correo_ges:= FUG_OBT_DIR_MAIL_USU(v_cod_gestor);
            end if;

             --- Enviar mail al autorizador
             if v_dir_correo_ges is not null and v_dir_correo_ent is not null then
                it_mail.mail(v_dir_correo_ent,
                         v_dir_correo_ges,
                         'Informe de Respuesta a Pedido de Autorización de Cliente que Supera su Limite Asignado de Cta.de Cambios',
                         'Le informamos que la solicitud de Autorización para el Cliente: '||v_nom_completo || chr(10)||
                         'Ha sido: '|| case :new.RESPUESTA when 'R' then 'RECHAZADO' when 'A' then 'APROBADO' end|| ' por el Autorizador');
             end if;
         end if;


   end if;
 -- CRO-JM-09/2014
 -- Cambia el estado de los cheques si los pedidos son aprobados, entonces cambiamos los estados del detalle de los cheques:
  if (updating or inserting) and :new.estado = 'C' then
    begin
      select b.nro_cuenta, b.nro_documento, b.monto, b.cod_moneda -- buscamos en ge_movimientos
        into j_nro_cuenta, j_nro_documento, j_monto, j_cod_moneda
        from ge_movimientos b
       where b.cod_usuario = :new.cod_usuario
         and b.fecha = :new.fecha
         and b.hora = :new.hora
         and nvl(b.estado, 'N') = 'X';
    exception
      when others then
        j_nro_cuenta    := null;
        j_nro_documento := null;
        j_monto         := null;
        j_cod_moneda    := null;
    end;

    begin
      -- con los datos de ge_movimientos buscamos la custodia en cuestion:
      select 'S',
             b.cod_che_custodia,
             b.cod_emisor,
             b.nro_cta_debito,
             b.nro_documento
        into j_existe,
             j_cod_che_custodia,
             j_cod_emisor,
             j_nro_cta_debito,
             k_nro_documento
        from cc_che_custodias a, cc_che_custodias_det b
       where a.cod_che_custodia = b.cod_che_custodia
         and b.nro_cta_debito = j_nro_cuenta
         and b.nro_documento = j_nro_documento
         and b.val_nominal = j_monto
         and b.cod_moneda = j_cod_moneda;
    exception
      when others then
        j_existe := 'N';
    end;
    if nvl(j_existe, 'N') = 'S' then
      -- si existe, actualizamos:
      begin
        update cc_che_custodias_det g
           set g.estado = 'D' -- confirmado en cuenta
         where g.cod_che_custodia = j_cod_che_custodia
           and g.cod_emisor = j_cod_emisor
           and g.nro_cta_debito = j_nro_cta_debito
           and g.nro_documento = k_nro_documento;
      exception
        when others then
          null;
      end;
    end if;
  end if;

  -- CRO-JM-03/2015: CROGEFIT-3
  -- Para los casos de compra/venta de efectivo (transaccion 245):
  if updating and :new.estado = 'A' then -- si es rechazada la autorizacion
      declare
        l_cod_persona         cj_acu_imp_transacciones.cod_persona%type;
        l_nro_cuenta          cj_acu_imp_transacciones.nro_cuenta%type;
        v_cod_tra_formularios varchar2(2000) := fug_obt_pardinamico('COD_TRA_FORMULARIOS'); --242,243,NNN
        v_cod_tra_personas    varchar2(2000) := fug_obt_pardinamico('COD_TRA_FOR_PERSONAS'); --245, NNN
        v_fec_actual          ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(1); --fecha actual del sistema
        v_pri_dia_habil       ge_movimientos.fecha%type := pag_cal.fu_obt_fec_pri_dia_mes_habil(1); --primer día hábil del mes actual
        l_cod_transaccion     cj_acu_imp_transacciones.cod_transaccion%type;

        procedure pr_act_personas(p_cod_persona in cj_acu_imp_transacciones.cod_persona%type) is
          -- se actualiza los registros cuyas funciones son parametrizadas por código de persona:
        begin
          if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
            --buscamos diariamente:
            update cj_acu_imp_transacciones a
               set a.impreso = 'R'
             where a.cod_persona = p_cod_persona
               and a.fecha = v_fec_actual
               and a.cod_usuario = :new.cod_usuario
               and a.fecha = :new.fecha
               and a.hora = :new.hora
               and nvl(a.impreso, 'N') = 'N';
          elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
            update cj_acu_imp_transacciones a
               set a.impreso = 'R'
             where a.cod_persona = p_cod_persona
               and a.fecha = v_fec_actual
               and a.cod_usuario = :new.cod_usuario
               and a.fecha = :new.fecha
               and a.hora = :new.hora
               and nvl(a.impreso, 'N') = 'N';
            if SQL%NOTFOUND then
              update cj_acu_imp_transacciones_his a
                 set a.impreso = 'R'
               where a.cod_persona = p_cod_persona
                 and a.fecha >= v_pri_dia_habil
                 and a.cod_usuario = :new.cod_usuario
                 and a.fecha = :new.fecha
                 and a.hora = :new.hora
                 and nvl(a.impreso, 'N') = 'N';
            end if;
          end if;
        end pr_act_personas;

        procedure pr_act_cli_persona(p_cod_persona in cj_acu_imp_transacciones.cod_persona%type,
                                     p_nro_cuenta  in cj_acu_imp_transacciones.nro_cuenta%type) is
        -- se actualiza los registros cuyas funciones son parametrizadas por código de persona y cliente:
        begin
          if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
            --buscamos diariamente:
            update cj_acu_imp_transacciones a
               set a.impreso = 'R'
             where a.nro_cuenta = p_nro_cuenta
               and a.cod_persona = p_cod_persona
               and a.fecha = v_fec_actual
               and a.cod_usuario = :new.cod_usuario
               and a.fecha = :new.fecha
               and a.hora = :new.hora
               and nvl(a.impreso, 'N') = 'N';
          elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
            update cj_acu_imp_transacciones a
               set a.impreso = 'R'
             where a.nro_cuenta = p_nro_cuenta
               and a.cod_persona = p_cod_persona
               and a.fecha = v_fec_actual
               and a.cod_usuario = :new.cod_usuario
               and a.fecha = :new.fecha
               and a.hora = :new.hora
               and nvl(a.impreso, 'N') = 'N';
            if SQL%NOTFOUND then
              update cj_acu_imp_transacciones_his a
                 set a.impreso = 'R'
               where a.nro_cuenta = p_nro_cuenta
                 and a.cod_persona = p_cod_persona
                 and a.fecha >= v_pri_dia_habil
                 and a.cod_usuario = :new.cod_usuario
                 and a.fecha = :new.fecha
                 and a.hora = :new.hora
                 and nvl(a.impreso, 'N') = 'N';
            end if;
          end if;
        end pr_act_cli_persona;

    -- inicio del programa principal
    begin
        --buscamos la transaccion que posea el numero de cuenta del cliente
        begin
          select g.cod_persona,
             (case -- aquí elegimos si existe una cuenta distinta a la cuenta de cambios del banco, sino elegimos esa cuenta de cambios:
               when ((select count(a.nro_cuenta)
                        from ge_movimientos a
                       where a.fecha = g.fecha
                         and a.cod_usuario = g.cod_usuario
                         and a.hora = g.hora
                         and not exists
                       (select a.nro_cuenta
                                from LC_CTA_CAMBIOS b
                               where a.nro_cuenta = b.nro_cuenta)) > 0) then
                (select a.nro_cuenta
                   from ge_movimientos a
                  where a.fecha = g.fecha
                    and a.cod_usuario = g.cod_usuario
                    and a.hora = g.hora
                    and a.nro_cuenta is not null
                    and a.nro_secuencia =
                        (select min(a.nro_secuencia) --elegimos la menor secuencia en caso que se repita
                           from ge_movimientos g
                          where a.fecha = g.fecha
                            and a.hora = g.hora
                            and a.cod_usuario = g.cod_usuario
                            and not exists
                          (select a.nro_cuenta
                                   from LC_CTA_CAMBIOS b
                                  where a.nro_cuenta = b.nro_cuenta))
                  group by a.nro_cuenta)
               else
                (select a.nro_cuenta
                   from ge_movimientos a
                  where a.fecha = g.fecha
                    and a.cod_usuario = g.cod_usuario
                    and a.hora = g.hora
                    and exists (select a.nro_cuenta
                           from LC_CTA_CAMBIOS b
                          where a.nro_cuenta = b.nro_cuenta)
                  group by a.nro_cuenta)
             end) as nro_cuenta,
             -- recuperamos el código de transaccion:
             case
               when (Select distinct 'S'
                       from lc_tip_ope_oficinas c,
                            lc_tip_operaciones  b,
                            ge_movimientos      a
                      where a.nro_documento = to_number(g.nro_documento)
                       and  a.hora =  g.hora
                       and  a.cod_usuario = g.cod_usuario
                       and  a.fecha = g.fecha
                        and b.caja = 'S' -- solo si pasa por caja
                        and b.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_oficina = a.cod_ofi_origen
                        and c.cod_moneda = a.cod_moneda
                        and a.cod_mad_padre = 71 -- compra
                      group by to_number(a.nro_documento)) = 'S' then
                '241' -- La operacion se realizó utilizadno esta funcion fuj_pro_transaccion_241
               when (Select 'S'
                       from lc_tip_ope_oficinas c,
                            lc_tip_operaciones  b,
                            ge_movimientos      a
                      where nro_documento = to_number(g.nro_documento)
                        and  a.hora =  g.hora
                        and  a.cod_usuario = g.cod_usuario
                        and  a.fecha = g.fecha
                        and b.caja = 'S' -- solo si pasa por caja
                        and b.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_oficina = a.cod_ofi_origen
                        and c.cod_moneda = a.cod_moneda
                        and a.cod_mad_padre = 72 -- venta
                        and (a.nro_documento4 <> 245)
                      group by to_number(a.nro_documento)) = 'S' then
                '242' -- La operacion se realizó utilizadno esta funcion fuj_pro_transaccion_242
               when (Select 'S'
                       from lc_tip_ope_oficinas c,
                            lc_tip_operaciones  b,
                            ge_movimientos      a
                      where nro_documento = to_number(g.nro_documento)
                        and  a.hora =  g.hora
                        and  a.cod_usuario = g.cod_usuario
                        and  a.fecha = g.fecha
                        and (b.caja = 'S' or a.cod_transaccion <> 760) --solo si pasa por caja,puede pasar 1solo
                        and b.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_oficina = a.cod_ofi_origen
                        and c.cod_moneda = a.cod_moneda
                        and a.cod_mad_padre in (73) -- arb
                      group by to_number(a.nro_documento)) = 'S' then
                '243' -- La operacion se realizó utilizadno esta funcion fuj_pro_transaccion_243
               when (Select distinct 'S'
                       from lc_tip_ope_oficinas c,
                            lc_tip_operaciones  b,
                            ge_movimientos      a
                      where nro_documento = to_number(g.nro_documento)
                        and  a.hora =  g.hora
                        and  a.cod_usuario = g.cod_usuario
                        and  a.fecha = g.fecha
                        and (b.caja = 'S' or a.cod_transaccion <> 760) --solo si pasa por caja,puede pasar 1solo
                        and b.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_tip_operacion = a.cod_tip_ope_cambio
                        and c.cod_oficina = a.cod_ofi_origen
                        and c.cod_moneda = a.cod_moneda
                        and a.cod_mad_padre in (74) -- canje
                      group by to_number(a.nro_documento)) = 'S' then
                '244' -- La operacion se realizó utilizadno esta funcion fuj_pro_transaccion_244
               when (select 'S'
                       from lc_tip_ope_oficinas b,
                            lc_tip_operaciones  a,
                            ge_movimientos      c
                      where b.cod_tip_operacion = a.cod_tip_operacion
                        and a.cod_tip_operacion = c.cod_tip_ope_cambio
                        and b.cod_tip_operacion = c.cod_tip_ope_cambio
                        and c.nro_documento = to_number(g.nro_documento)
                        and c.hora =  g.hora
                        and c.cod_usuario = g.cod_usuario
                        and c.fecha = g.fecha
                        and a.cod_tip_operacion in (11, 26, 18, 30) --compra y vta efectivo,compra de cheques
                        and nivel = 1
                        and a.cod_modalidad in (71, 72)
                      group by to_number(c.nro_documento)) = 'S' then
                '245' -- La operacion se realizó utilizadno esta funcion fuj_pro_transaccion_245
               else
                null
             end as cod_transaccion
            into l_cod_persona, l_nro_cuenta, l_cod_transaccion
            from ge_movimientos g
           where g.fecha = :new.fecha               
             and g.cod_usuario = :new.cod_usuario   
             and g.hora = :new.hora                 
             and g.nro_cuenta is not null
           group by g.cod_persona,
                    g.fecha,
                    g.cod_usuario,
                    g.hora,
                    g.nro_documento,
                    g.nro_documento4;
        exception
          when others then
            l_cod_persona := null;
            l_nro_cuenta  := null;
        end;

        if l_cod_persona is not null or l_nro_cuenta is not null then
          if fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CUE' then
            -- por cuenta o por persona
            if (instr(',' || v_cod_tra_formularios || ',',
                      ',' || l_cod_transaccion || ',') > 0) then
              pr_act_cli_persona(l_cod_persona, l_nro_cuenta);
            elsif (instr(',' || v_cod_tra_personas || ',', -- si la búsqueda se hará solo por el código de personas:
                         ',' || l_cod_transaccion || ',') > 0) then
              pr_act_personas(l_cod_persona);
            else
              -- busqueda normal
              if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                --buscamos diariamente:
                update cj_acu_imp_transacciones a
                   set a.impreso = 'R'
                 where a.nro_cuenta = l_nro_cuenta
                   and a.fecha = v_fec_actual
                   and a.cod_usuario = :new.cod_usuario
                   and a.fecha = :new.fecha
                   and a.hora = :new.hora
                   and nvl(a.impreso, 'N') = 'N'
                   and (instr(',' || v_cod_tra_formularios || ',',
                              ',' || a.cod_transaccion || ',') = 0);
              elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                update cj_acu_imp_transacciones a
                   set a.impreso = 'R'
                 where a.nro_cuenta = l_nro_cuenta
                   and a.fecha = v_fec_actual
                   and a.cod_usuario = :new.cod_usuario
                   and a.fecha = :new.fecha
                   and a.hora = :new.hora
                   and nvl(a.impreso, 'N') = 'N'
                   and (instr(',' || v_cod_tra_formularios || ',',
                              ',' || a.cod_transaccion || ',') = 0);
                if SQL%NOTFOUND then
                  update cj_acu_imp_transacciones_his a
                     set a.impreso = 'R'
                   where a.nro_cuenta = l_nro_cuenta
                     and a.fecha >= v_pri_dia_habil
                     and a.cod_usuario = :new.cod_usuario
                     and a.fecha = :new.fecha
                     and a.hora = :new.hora
                     and nvl(a.impreso, 'N') = 'N'
                     and (instr(',' || v_cod_tra_formularios || ',',
                                ',' || a.cod_transaccion || ',') = 0);
                end if;
              end if;
            end if;

            -- Se  verifica si hay que imprimir el formulario, pero por cliente:
          elsif fug_obt_pardinamico('CUE_CLI_FORMULARIO') = 'CLI' then
            if (instr(',' || v_cod_tra_formularios || ',',
                      ',' || l_cod_transaccion || ',') > 0) then
              pr_act_cli_persona(l_cod_persona, l_nro_cuenta);
            elsif (instr(',' || v_cod_tra_personas || ',', -- si la búsqueda se hará solo por el código de personas:
                         ',' || l_cod_transaccion || ',') > 0) then
              pr_act_personas(l_cod_persona);
            else
              -- busqueda normal
              if fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'D' then
                --buscamos diariamente:
                update cj_acu_imp_transacciones a
                   set a.impreso = 'R'
                 where a.cod_persona = l_cod_persona
                   and a.fecha = v_fec_actual
                   and a.cod_usuario = :new.cod_usuario
                   and a.fecha = :new.fecha
                   and a.hora = :new.hora
                   and nvl(a.impreso, 'N') = 'N'
                   and (instr(',' || v_cod_tra_formularios || ',',
                              ',' || a.cod_transaccion || ',') = 0);
              elsif fug_obt_pardinamico('CLI_CUE_DIA_MENSUAL') = 'M' then
                update cj_acu_imp_transacciones a
                   set a.impreso = 'R'
                 where a.cod_persona = l_cod_persona
                   and a.fecha = v_fec_actual
                   and a.cod_usuario = :new.cod_usuario
                   and a.fecha = :new.fecha
                   and a.hora = :new.hora
                   and nvl(a.impreso, 'N') = 'N'
                   and (instr(',' || v_cod_tra_formularios || ',',
                              ',' || a.cod_transaccion || ',') = 0);
                if SQL%NOTFOUND then
                  update cj_acu_imp_transacciones_his a
                     set a.impreso = 'R'
                   where a.cod_persona = l_cod_persona
                     and a.fecha >= v_pri_dia_habil
                     and a.cod_usuario = :new.cod_usuario
                     and a.fecha = :new.fecha
                     and a.hora = :new.hora
                     and nvl(a.impreso, 'N') = 'N'
                     and (instr(',' || v_cod_tra_formularios || ',',
                                ',' || a.cod_transaccion || ',') = 0);
                end if;
              end if;
            end if;
          end if;
        end if;
      end;
end if;
end TA_GE_AUT_PEDIDOS;
/


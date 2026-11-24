CREATE OR REPLACE TRIGGER IT."TA_GE_MOV_AUTORIZACIONES"
  AFTER UPDATE ON "IT"."GE_MOV_AUTORIZACIONES"
  FOR EACH ROW

DECLARE
  v_cod_circuito wf_circuitos.cod_circuito%type;
  v_cod_tarea    wf_cir_tareas.cod_tarea%type;
  v_nro_cuenta    cj_movimientos.nro_cuenta%type;
  v_nro_documento cj_movimientos.nro_doc_referencia%type;
  v_mto_movimiento cj_movimientos.monto%type;
  v_hor_movimiento varchar2(8);
  v_cod_usuario    ba_usuarios.cod_usuario%type;
  rg_exo_tmp       ge_exoneraciones_tmp%rowtype;
  ---
BEGIN
  IF updating THEN
     IF :new.estado = 'A' THEN
        pag_rie.pr_apr_pedido(:new.nro_pedido,
                            :new.fecha,
                            :new.hora,
                            :new.cod_usuario,
                            :new.cod_tra_padre,
                            :new.cod_mod_padre,
                            :new.cod_mad_padre,
                            :new.nro_cuenta,
                            :new.cod_persona,
                            :new.mto_mon_fuerte,
                            :new.tip_operacion,
                            :new.nro_documento,
                            :new.cod_usu_autorizador,
                            :new.concepto,
                            :new.estado,
                            nvl(:new.est_movimiento, :old.est_movimiento),
                            nvl(:new.est_cuenta, :old.est_cuenta),
                            :new.observacion );
        --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
        If :new.cod_tra_padre = 355 then
           --> Debe Buscar la cuenta donde se realizó el depósito
           Begin
                select ax.nro_cuenta
                  into v_nro_cuenta
                  from cj_movimientos ax
                  where ax.estado != 'R'
                    and ax.tip_monto = 'C'
                    and ax.cod_tra_padre not in (206,207,355)
                    and ax.nro_documento = (Select rt.nro_doc_referencia
                                                 from cj_movimientos rt
                                                where rt.hora        = :new.hora
                                                  and rt.nro_cuenta  = :new.nro_cuenta
                                                  and rt.cod_usuario = :new.cod_usuario);
                Select rt.nro_doc_referencia,rt.monto,rt.hora,rt.cod_usuario
                  into v_nro_documento,v_mto_movimiento,v_hor_movimiento,v_cod_usuario
                   from cj_movimientos rt
                  where rt.hora        = :new.hora
                    and rt.nro_cuenta  = :new.nro_cuenta
                    and rt.cod_usuario = :new.cod_usuario;
           Exception
               When no_data_found Then
                    v_nro_cuenta    := null;
                    v_nro_documento := null;
                    v_hor_movimiento:= null;
		    v_cod_usuario   := null; 
               when others then
                    raise_application_error(-20000,'Error al obtener el número de cuenta. '||sqlerrm);
           End;
           If v_nro_cuenta is not null and v_nro_documento is not null Then
              pra_lib_retencion( v_nro_cuenta, null, null, 'S', v_nro_documento,v_mto_movimiento,v_hor_movimiento,v_cod_usuario );
           End If;
        End If;
        --Para Cheques Hibridos, actualizamos el estado del cheque si se aprobó DYDMR-24590
        If :new.cod_tra_padre = 345 then
            
            update cc_che_hibridos h
               set h.situacion = 'C'
              where h.fecha = :new.fecha
                and h.hora = :new.hora
                and h.monto= :new.monto
                and h.cod_moneda= :new.cod_moneda
                and h.situacion ='P';
        
        end if;
        
        
        
        
    ELSIF :new.estado in ('R','C') THEN

      pag_rie.pr_apr_pedido(:new.nro_pedido,
                            :new.fecha,
                            :new.hora,
                            :new.cod_usuario,
                            :new.cod_tra_padre,
                            :new.cod_mod_padre,
                            :new.cod_mad_padre,
                            :new.nro_cuenta,
                            :new.cod_persona,
                            :new.mto_mon_fuerte,
                            :new.tip_operacion,
                            :new.nro_documento,
                            :new.cod_usu_autorizador,
                            :new.concepto,
                            'A',
                            nvl(:new.est_movimiento, :old.est_movimiento),
                            nvl(:new.est_cuenta, :old.est_cuenta),
                            :new.observacion );

      begin
        select cod_circuito
          into v_cod_circuito
          from wf_circuitos
         where referencia = :new.nro_pedido
           and cod_tip_circuito = fug_obt_pardinamico('COD_TIP_CIR_CON_DUAL');
      exception
        when others then
        raise_application_error(-20000,'Error al obtener el número de Cicuito. '||sqlerrm);
      end;

      begin
        select max(a.cod_tarea)
          into v_cod_tarea
          from wf_cir_tareas a
         where cod_circuito = v_cod_circuito
           and cod_tip_circuito = fug_obt_pardinamico('COD_TIP_CIR_CON_DUAL');
      exception
        when others then
        raise_application_error(-20000,'Error al obtener el código de Tarea. '||sqlerrm);
      end;
      -- Finaliza el Circuito.
      update wf_circuitos
         set fec_fin = sysdate,
             estado = 'C'
       where cod_circuito = v_cod_circuito;

      update wf_cir_tareas a
         set estado = 'C',
             comentario = 'RECHAZO DEL CIRCUITO DEL WORKFLOW'
       where a.cod_circuito = v_cod_circuito
         and a.cod_tip_circuito = fug_obt_pardinamico('COD_TIP_CIR_CON_DUAL')
         and a.cod_tarea = v_cod_tarea;
       --> 18/09/2013-MB-CRO: Control Dual.-
       /*PN 23/04/2014 DI: Se agrega el If, debido a que en caso de Debito en cuenta de Préstamos si
                           el estado del Movimiento es P, no actualiza correctamente el Saldo*/
      -- Comentado C.D.Fase III--
     /*  if :new.cod_mod_padre = 6 and :new.cod_tra_padre in (359,360,362) then
          begin
            update ge_movimientos
               set estado = 'N'
             where cod_usuario = :new.cod_usuario
               and fecha = :new.fecha
               and hora = :new.hora
               and estado = 'P'
               and cod_mod_padre = :new.cod_mod_padre
               and cod_tra_padre = :new.cod_tra_padre\*
               and cod_transaccion = 503*\; -- MB 12/05/2014 SPI 3473: INCENDENCIA RECHAZO DE AUTORIZACION DE COBRO - CONTROL DUAL
          exception
            when others then
              raise_application_error(-20000, 'No se pudo actualizar el Movimiento de Debito en cuenta. '|| sqlerrm);
          end;
       end if;*/
       Begin
          update ge_aut_pedidos a
             set a.estado      = 'A',
                 a.respuesta   = 'R',
                 a.observacion = 'Rechazado desde el Workflow por '||:new.cod_usu_autorizador
           where a.fecha       = :new.fecha
             and a.hora        = :new.hora
             and a.cod_usuario = :new.cod_usuario
             and a.estado      = 'S';
       Exception
           When Others Then
                raise_application_error(-20000,'Error al Rechazar Pedido de Autorización '||sqlerrm);
       End;





          pag_rie.pr_rch_pedido(:new.nro_pedido,
                            :new.fecha,
                            :new.hora,
                            :new.cod_usuario,
                            :new.cod_tra_padre,
                            :new.cod_mod_padre,
                            :new.cod_mad_padre,
                            :new.nro_cuenta,
                            :new.cod_persona,
                            :new.mto_mon_fuerte,
                            :new.tip_operacion,
                            :new.nro_documento,
                            :new.cod_usu_autorizador,
                            :new.concepto,
                            :new.estado,
                            :new.observacion);



    END IF;
    /*
    || PCC-Exoneración y Extorno de Comisiones y Tasas
    */
    begin
       select * 
         into rg_exo_tmp
         from ge_exoneraciones_tmp a
        where a.nro_pedido = :old.nro_pedido;
    exception
       when no_data_found then
          rg_exo_tmp.nro_pedido := null;
       when too_many_rows then
          raise_application_error(-20000,'Mas de 1 solicitud pendiente para '||:old.nro_pedido);
       when others then
          raise_application_error(-20000,'Al Obt.Exoneracion:'||sqlerrm);
    end;
    if rg_exo_tmp.nro_pedido is not null then
       if :new.estado = 'A' then
          prg_ins_exoneracion(rg_exo_tmp.cod_transaccion,
                              rg_exo_tmp.cod_modulo,
                              rg_exo_tmp.cod_modalidad,
                              rg_exo_tmp.cod_moneda,
                              rg_exo_tmp.nro_cuenta,
                              rg_exo_tmp.cod_persona,
                              rg_exo_tmp.cod_tasa,
                              rg_exo_tmp.mto_exoneracion,
                              rg_exo_tmp.mto_a_cobrar,
                              rg_exo_tmp.usu_insercion,
                              rg_exo_tmp.mto_exoneracion);
       end if;
       update ge_exoneraciones_tmp a
          set a.estado = :new.estado
        where a.nro_pedido = :old.nro_pedido;
    end if;
    ---
  END IF;
END;
/


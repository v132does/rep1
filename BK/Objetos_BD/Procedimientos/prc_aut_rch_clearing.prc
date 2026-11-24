CREATE OR REPLACE PROCEDURE IT.prc_aut_rch_clearing ( p_nro_cuenta  in varchar2,
                                                      p_nro_cheque in NUMBER,
                                                      p_cod_moneda in varchar2,
                                                      p_fec_proceso in varchar2,
                                                      p_nro_secuencia in number,
                                                      p_nro_sec_out out number) is
----
v_cantidad             number(3);
v_mto_multa            ge_movimientos.monto%type;
v_nro_che_inicial      cc_che_Recibidos.Nro_Cheque%type;
v_error                varchar2(3000);
v_cta_certificada      cc_che_Recibidos.Nro_Cuenta%type;
v_estado               cc_che_recibidos.est_cheque%type;
v_hora                 ge_movimientos.hora%type;
v_nro_secuencia        ge_movimientos.nro_secuencia%type;
v_tip_importe          varchar2(10);
v_sub_motivo           varchar2(10);
v_lugar                varchar2(3000);
v_procesar             varchar2(1);
v_nro_lote             number(10);
--
v_sc_cod_bco_receptor  ge_bancos.cod_banco%type;
v_sc_compensacion      varchar2(1);
v_importe              number(21,2);
v_desc_transaccion     ge_transacciones.descripcion%TYPE;
v_cod_modulo           ge_movimientos.cod_modulo%type;
v_cod_modalidad        ge_movimientos.cod_modalidad%TYPE;
v_fec_actual           ge_calendarios.fec_actual%type:= pag_Cal.Fu_Obt_Fec_Actual(4);
v_che_cert             varchar2(1);
v_cta_cert             cc_che_certificados.nro_cuenta%type;
v_cod_ofi_cert         ba_oficinas.cod_oficina%TYPE;
---
 cursor clrecaut_cur is
     select   a.NRO_CHEQUE, a.FEC_PROCESO,
              a.NRO_CUENTA,a.MONTO,
              a.COD_BCO_RECEPTOR, a.COD_CAU_DEVOLUCION,
              a.DES_CAU_DEVOLUCION, a.COD_USUARIO,
              a.TIP_IMPORTE,  a.COD_MONEDA,
              a.cod_ofi_camara,
              a.cod_oficina,
              a.rowid registro,
              b.cod_moneda cod_mon_cta,
              b.cod_oficina cod_ofi_cta,
              b.cod_modulo,
              b.cod_modalidad
       from cc_che_rec_automaticos a, ge_cuentas b
      where upper(a.cod_usuario) = upper(user)
        and a.fec_proceso = p_fec_proceso
        and a.cod_moneda  = p_cod_moneda
        and a.nro_cuenta  = p_nro_cuenta
        and a.nro_cheque  = p_nro_cheque
        and nvl(a.procesado,'N')='N'
        and a.nro_lote    = v_nro_lote
        and a.nro_cuenta  = b.nro_cuenta;

--Verificar si se cobra multa o no
PROCEDURE pp_cal_multa( p_cod_causa in varchar2
                       ,P_COD_OFICINA    IN GE_CUENTAS.COD_OFICINA%TYPE
                       ,P_NRO_CUENTA     IN GE_CUENTAS.NRO_CUENTA%TYPE
                       ,P_NRO_CHEQUE     IN CC_CHE_RECIBIDOS.NRO_CHEQUE%TYPE
                       ,P_COD_MONEDA     IN GE_CUENTAS.COD_MONEDA%TYPE
                       ,P_MONTO          IN GE_MOVIMIENTOS.MONTO%TYPE
                       ,P_COD_MODULO     IN GE_CUENTAS.COD_MODULO%TYPE
                       ,P_COD_MODALIDAD  IN GE_CUENTAS.COD_MODALIDAD%TYPE
                       ,p_val_multa      out number) IS

v_cod_tra_multa     ge_movimientos.cod_transaccion%type;
v_cod_tas_multa     ge_movimientos.cod_tasa%type;
v_val_tas_multa     ge_movimientos.val_tasa%type;
v_cod_tra_impuesto  ge_movimientos.cod_transaccion%type;
v_cod_tas_impuesto  ge_movimientos.cod_tasa%type;
v_val_tas_impuesto  ge_movimientos.val_tasa%type;
v_val_impuesto      ge_movimientos.monto%type;
begin
    --verificar si el motivo cobra multa
  v_cod_tra_multa := FUG_OBT_PARCAUSALES(P_COD_CAUSA,'COD_TRA_MULTA');
  if v_cod_tra_multa is not null then
    --solo si ya no se le cobro multa, ya q se cobra una sola vez por Insuf.de fondos
    if FUC_VER_COB_MULTA(p_nro_cuenta, P_NRO_CHEQUE) = 'N' then
      --nunca cobro, se le cobra
      prg_obt_cargos(P_COD_OFICINA,
                     P_NRO_CUENTA,
                     P_COD_MONEDA,
                     P_MONTO,
                     P_COD_MODULO,
                     P_COD_MODALIDAD,
                     v_cod_tra_multa,--multa
                     v_cod_tas_multa,
                     v_val_tas_multa,
                     p_val_multa,
                     v_cod_tra_impuesto,
                     v_cod_tas_impuesto,
                     v_val_tas_impuesto,
                     v_val_impuesto);
     else
      p_val_multa := 0;
    end if;
  end if;
end;
--Insertar movimiento
PROCEDURE pp_gen_movimiento (p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                             p_monto           in ge_movimientos.monto%type,
                             p_concepto        in ge_movimientos.concepto%type,
                             p_cod_usuario     in ge_movimientos.cod_usuario%type,
                             p_hora            in ge_movimientos.hora%type,
                             p_nro_secuencia   in ge_movimientos.nro_secuencia%type,
                             p_cod_oficina     in ge_movimientos.cod_oficina%type,
                             p_cod_ofi_camara  in ge_movimientos.cod_ofi_origen%type,
                             p_nro_cuenta      in ge_movimientos.nro_cuenta%type,
                             p_cod_moneda      in ge_movimientos.cod_moneda%type,
                             p_fecha           in ge_movimientos.fecha%type,
                             p_nro_cheque      in cc_che_devueltos.nro_cheque%type,
                             p_cod_devolucion  in cc_che_devueltos.Cod_Causa%type
                             )IS
 r_gmovi ge_movimientos%rowtype;
 v_nro_sec number(10);
 v_nro_sec number(10);
BEGIN
  v_nro_secuencia:= to_number(v_nro_secuencia) + 1;
  if v_nro_secuencia > 900 then
    v_hora := pag_gen.fu_obt_sig_segundo(to_char(sysdate,'hh24:mi:ss'));
    v_nro_secuencia := 1;
  end if;
  --:global.nrsecue := to_number(nvl(:global.nrsecue,0)) + 1;
  r_gmovi.cod_usuario     := p_cod_usuario;
  r_gmovi.hora            := v_hora;
  r_gmovi.nro_secuencia   := v_nro_secuencia;--to_number(:global.nrsecue);
  r_gmovi.cod_oficina     := p_cod_oficina;
  r_gmovi.nro_cuenta      := p_nro_cuenta;
  r_gmovi.cod_modulo      := 4;
  r_gmovi.cod_modalidad   := 41;
  r_gmovi.cod_moneda      := p_cod_moneda;
  r_gmovi.fec_valor       := p_fecha;
  r_gmovi.fecha           := p_fecha;
  r_gmovi.cod_tra_padre   := 138;
  r_gmovi.cod_transaccion := p_cod_transaccion;
  r_gmovi.nro_documento   := p_nro_cheque;
  r_gmovi.monto           := p_monto;
  r_gmovi.emi_aviso       := 'N';
  r_gmovi.cod_causa       := p_cod_devolucion;
  r_gmovi.cod_ofi_origen  := p_cod_ofi_camara;
  r_gmovi.concepto        := p_concepto;
  r_gmovi.estado          := 'N';
  r_gmovi.reversado       := 'N';
  r_gmovi.protegido       := 'N';
  r_gmovi.cod_mod_padre   := 4;
  r_gmovi.cod_mad_padre   := 41;
  v_lugar:= 'Ins.Mov.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');

end;

/*********PROCESO PRINCIPAL*************************/
begin

begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
--Verificamos si esta activo el rechazo automatico
if nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' then
    v_cantidad:=0;
    v_lugar:= 'Verif.Canti. Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
    --Verificar que no se haya registrado la misma devolucion en la fecha, agregado el 17/02/2010
    select nvl(count(1),0)
      into v_cantidad
      from cc_che_devueltos d
     where d.fecha      = p_fec_proceso
       and d.nro_cuenta = p_nro_cuenta
       and d.nro_cheque = p_nro_cheque
       and d.fecha      = p_fec_proceso;
    -- Si aun no se proceso
    if nvl(v_cantidad,0) =  0 then
       v_hora:= pag_gen.fu_obt_sig_segundo(to_char(sysdate,'hh24:mi:ss'));   -- Hora actual
       v_nro_secuencia:= nvl(p_nro_secuencia,0)+1;
       if  nvl(v_nro_secuencia,0) > 998 then
           v_hora:= pag_gen.fu_obt_sig_segundo(to_char(sysdate,'hh24:mi:ss'));   -- Hora actual
           v_nro_secuencia:=1;
       end if;
       --Obtenemos el numero de Lote del cheque a procesar
       begin
           select a.nro_lote
             into v_nro_lote
                 from cc_che_rec_automaticos a
                 where upper(a.cod_usuario) = upper(user)
                        and a.fec_proceso = p_fec_proceso
                        and a.cod_moneda = p_cod_moneda
                        and a.nro_cuenta= p_nro_cuenta
                        and a.nro_cheque= p_nro_cheque
                        and nvl(a.procesado,'N')='N';
       exception
          when others then
            v_nro_lote := 0;
       end;
          --cargamos si se encuentra en la tabla de rechazos automaticos aun no procesado
       FOR r1 IN clrecaut_cur LOOP
          --Limpiar variables
          v_che_cert := 'N';
          v_sub_motivo := null;
          v_cta_cert:=null;
          v_cod_ofi_cert:=NULL;
          v_importe:=0;
          v_sc_cod_bco_receptor:=0;
          v_sc_compensacion:=null;
          v_cod_modulo:= null;
          v_cod_modalidad:= null;
          v_desc_transaccion:= null;
          --
          if r1.cod_cau_devolucion is not null  then
                 -- INICIO actualiza CC_CHE_DEVUELTOS_RES y CC_CHE_DEVUELTOS
                 --Obtener tipo de Importe(Aplica a Todos)
                 v_tip_importe:=0;
                 v_lugar:= 'Asig.Tip.Importe - Nro.Che:' ||r1.nro_cheque;
                 if r1.cod_moneda = pag_gen.fu_obt_mon_local then
                     if r1.monto >= nvl(fug_obt_pardinamico('MTO_CHE_RET_CERO',null,null,r1.cod_moneda),0) then
                        v_tip_importe:=1;
                     else
                        v_tip_importe:=0;
                     end if;
                 else
                     v_tip_importe:=0;
                 end if;

            --Aqui logica anterior
             --Obtenemos si se le tiene que cobrar multa o no
                            v_lugar := 'Cal.Multa Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
            begin
               pp_cal_multa(r1.cod_cau_devolucion,
                            r1.cod_ofi_camara,
                            r1.nro_cuenta,
                            r1.nro_cheque,
                            r1.cod_moneda,
                            r1.monto,
                            4,
                            41,
                            v_mto_multa);
            exception
               when others then
                  -- Un fallo calculando la multa NO debe abortar el rechazo automatico
                  v_mto_multa := 0;
                  it.prg_ins_log_programas(
                     p_cod_programa => 'PRC_AUT_RCH_CLEARING',
                     p_det_error    => 'Error al calcular multa. Cta:'||r1.nro_cuenta||
                                       ' Che:'||r1.nro_cheque||
                                       ' Causa:'||r1.cod_cau_devolucion||' - '||sqlerrm,
                     p_cod_persona  => null,
                     p_nro_cuenta   => r1.nro_cuenta);
            end;
               --validamos el estado del cheque
               v_lugar:= 'Val.ESTADO.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
               v_estado := pac_che.FU_CON_CAM_EST_CHE(r1.nro_cuenta,r1.nro_CHEQUE,
                                         NULL,NULL,v_nro_che_inicial,
                                         v_error,v_cta_certificada);

               v_procesar:='N';
               if length(v_error) > 0 then
                   If instr(upper(v_error),'INEXISTENTE') =  0 then
                      v_procesar:='S';
                   end if;
               else
                 v_procesar:='S';
               end if;
               --Si encontro el cheque y es un estado que se puede devolver
               If nvl(v_procesar,0) = 'S' and v_estado in ('E','O','A','C','G') then
                  ----genera movimiento por la devolucion de un cheque no pagado - no afecta al saldo
                  v_lugar:= 'Gen.Mov.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
                  pp_gen_movimiento  (138,
                                     r1.monto,
                                     'Devolucion de cheq.:'||to_char(r1.nro_cheque),
                                     r1.cod_usuario,
                                     v_hora,
                                     v_nro_secuencia,
                                     r1.cod_oficina,
                                     r1.cod_ofi_camara,
                                     r1.nro_cuenta,
                                     r1.cod_moneda,
                                     r1.fec_proceso ,
                                     r1.nro_cheque,
                                     r1.cod_cau_devolucion
                                     );

                   IF fug_obt_pardinamico('COD_CAU_ORD_NO_PAGO') = r1.cod_cau_devolucion then
                       v_lugar:= 'Obt.Cau.No .Pago.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
                          begin
                            select cod_causa
                              into v_sub_motivo
                              from cc_che_ord_no_pagos
                             where nro_cuenta = r1.nro_cuenta
                               and nro_cheque = r1.nro_cheque;
                          exception
                            when others then
                              v_sub_motivo := null;
                          end;
                   END IF;
                  v_lugar:= 'insert CC_CHE_DEVUELTOS.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
                  insert into CC_CHE_DEVUELTOS(FECHA, HORA, COD_USUARIO,
                                      NRO_Cuenta, NRO_CHEQUE, COD_MONEDA, MONTO,
                                      COD_CAUSA, MULTA, SAL_MULTA, TIP_IMPORTE,
                                      COD_BCO_RECEPTOR, NRO_CAJA, COD_OFI_CAMARA,TIPO,
                                      COD_SUB_MOTIVO)
                               values(r1.fec_proceso, v_hora, USER,
                                      r1.nro_cuenta, r1.nro_cheque,
                                      r1.cod_moneda,r1.monto,
                                      r1.cod_cau_Devolucion,   nvl(v_mto_multa,0),
                                      nvl(v_mto_multa,0), v_tip_importe,
                                      r1.cod_bco_receptor,null,r1.cod_ofi_camara,
                                      FUG_OBT_PARCAUSALES(r1.cod_cau_devolucion,'TIP_DEVOLUCION'),v_sub_motivo);
                   -- vuelvo a no regularizado todos los cheques similares devueltos anteriormente
                   v_lugar:= 'regularizar CC_CHE_DEVUELTOS.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
                   begin
                     update cc_che_devueltos
                        set regularizado = 'N',
                            fec_modificacion = fec_modificacion
                      where nro_cuenta = r1.nro_cuenta
                        and nro_cheque = r1.nro_cheque;
                   exception
                     when others then
                       null;
                   end;
                   -- fin actualiza
                   v_lugar:= 'insert cc_che_dev_firmantes.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta||'- Cli: '|| FUG_OBT_CLI_PRINCIPAL(r1.nro_cuenta) ;
                   begin
                     INSERT INTO cc_che_dev_firmantes
                       (nro_cuenta, nro_cheque, cod_persona)
                     VALUES
                       (r1.nro_cuenta,
                        r1.nro_cheque,
                        fug_obt_cli_principal(r1.nro_cuenta));
                  exception
                     when others then
                       null;
                   end;

                  /*--Verificamos si recupera que se cobra multa, de ser asi, cobramos
                  if nvl(v_mto_multa,0) > 0 then
                    v_nro_secuencia:=nvl(v_nro_secuencia,0) +1;
                    --verificar si el saldo cubre la multa, entonces generar movimiento, sino no.
                    v_lugar:= 'Cobrar Multa.Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
                    prc_cob_multa(r1.nro_cuenta, r1.nro_cheque, r1.fec_proceso, v_hora, v_nro_secuencia);
                  end if;*/
                  v_lugar:= 'Act. Tabla maestra. Nro.Che:' ||p_nro_cheque ||'- Cta: '|| p_nro_cuenta ;
                  --Actualizamos el registro en la tabla maestra
                    update cc_che_rec_automaticos a
                            set a.procesado='S'
                          where a.rowid= r1.registro;

               end if;

           end if;
       end loop;
    end if;

    p_nro_sec_out:= v_nro_secuencia;
end if;
exception
   when others then
    Raise_application_error(-20030, 'Error Rec.Aut: '||v_lugar||'- '||sqlerrm);
end;

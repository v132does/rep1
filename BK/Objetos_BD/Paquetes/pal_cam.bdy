CREATE OR REPLACE PACKAGE BODY IT.PAL_CAM Is

v_cod_mon_fuerte varchar2(4) := pag_gen.FU_OBT_MON_FUERTE;
v_cod_mon_local varchar2(4) := pag_gen.FU_OBT_MON_LOCAL;

/* obtiene datos de la transaccion */
PROCEDURE LP_OBT_TIP_TRANSACCION
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,p_tipo out varchar2
 ,p_afecta out varchar2
 ,p_afe_ult_movimiento out varchar2
 ) IS
BEGIN
  SELECT tipo, afecta,DECODE(INTERNO,'S','N','N','S')
    INTO p_tipo, p_afecta,p_afe_ult_movimiento
    FROM GE_TRANSACCIONES
   WHERE cod_modulo = p_cod_modulo
     and cod_modalidad = p_cod_modalidad
     and cod_transaccion = p_cod_transaccion;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20004,'Transaccion inexistente '||
                    to_char(nvl(p_cod_modulo,0))||'-'||
                    to_char(nvl(p_cod_modalidad,0))||'-'||
                    to_char(p_cod_transaccion));
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20005,sqlerrm);
END;
-- Actualizacion de movimientos pendientes de pasar por Caja
PROCEDURE PR_ACT_MOVIMIENTOS
         (P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE,
          P_FECHA       IN GE_MOVIMIENTOS.FECHA%TYPE,
          P_HORA        IN GE_MOVIMIENTOS.HORA%TYPE,
          P_ESTADO      IN GE_MOVIMIENTOS.ESTADO%TYPE,
          P_NRO_CAJA    IN GE_MOVIMIENTOS.NRO_CAJA%TYPE,
          P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE DEFAULT NULL) is
  -- cursor de movimientos
  cursor movimientos is
    SELECT fecha,hora,cod_usuario,nro_secuencia,fec_valor,monto,nro_cuenta,cod_moneda,
           cod_oficina,cod_error,cod_retencion,fec_fin_retencion,est_cuenta,estado,cod_causa,
           cod_banco,cod_ofi_origen,concepto,cod_tasa,val_tasa,cod_rubro,cod_ref_cambio,reversado,
           cod_usu_reversion,hor_reversion,emi_aviso,cod_tra_padre,cod_mod_padre,cod_mad_padre,
           cod_transaccion,cod_modulo,cod_modalidad,mto_equ_local,nro_caja,cotizacion,cod_bco_central,
           nro_documento,nro_documento2,nro_documento3,nro_documento4,protegido,cod_autorizacion,
           cod_usu_autorizador,usu_insercion,fec_insercion,usu_modificacion,fec_modificacion,
           tip_mov_rubro,cod_tip_ope_cambio, rowid fila
      FROM GE_MOVIMIENTOS
     WHERE FECHA = P_FECHA
       AND HORA = P_HORA
       AND COD_USUARIO = P_COD_USUARIO
       AND REVERSADO     = 'N'
       AND ESTADO <> P_ESTADO
    union
    SELECT fecha,hora,cod_usuario,nro_secuencia,fec_valor,monto,nro_cuenta,cod_moneda,
           cod_oficina,cod_error,cod_retencion,fec_fin_retencion,est_cuenta,estado,cod_causa,
           cod_banco,cod_ofi_origen,concepto,cod_tasa,val_tasa,cod_rubro,cod_ref_cambio,reversado,
           cod_usu_reversion,hor_reversion,emi_aviso,cod_tra_padre,cod_mod_padre,cod_mad_padre,
           cod_transaccion,cod_modulo,cod_modalidad,mto_equ_local,nro_caja,cotizacion,cod_bco_central,
           nro_documento,nro_documento2,nro_documento3,nro_documento4,protegido,cod_autorizacion,
           cod_usu_autorizador,usu_insercion,fec_insercion,usu_modificacion,fec_modificacion,
           tip_mov_rubro,cod_tip_ope_cambio, rowid fila
      FROM GE_MOVIMIENTOS_NOC
     WHERE FECHA = P_FECHA
       AND HORA = P_HORA
       AND COD_USUARIO = P_COD_USUARIO
       AND REVERSADO     = 'N'
       AND ESTADO <> P_ESTADO
     ORDER BY NRO_SECUENCIA;

v_afecta varchar2(1) := 'N';
v_afe_sal_total      number := 0;
v_afe_sal_retenido   number := 0;
v_afe_sal_bloqueado  number := 0;
v_act_ult_movimiento varchar2(1) := 'N';
v_tip_movimiento     varchar2(1);
v_nvo_estado         varchar2(1);
v_nro_secuencia      number;
v_fec_envio          date;
v_cod_mad_hijo       lc_tip_operaciones.cod_mad_hijo%type;
v_afe_transferencias lc_tip_operaciones.afe_transferencia%type;
v_nro_tarjeta        ta_tarjetas.nro_tarjeta%type;
v_cod_procesadora     ta_tipos.cod_ent_procesadora%type;
v_est_modulo         varchar2(1) := pae_cnf.fu_obt_est_modulo(3);
--
BEGIN
  if v_est_modulo = 2 then-- El modulo esta abierto
    -- busco la maxima secuencia de los movimientos
    select nvl(max(nro_secuencia),0)
      into v_nro_secuencia
      from ge_movimientos
     where fecha = p_fecha
       and hora = p_hora
       and cod_usuario = p_cod_usuario;
       IT.PAG_CTA.G_HORARIO := 'D';
  else
    -- busco la maxima secuencia de los movimientos nocturnos
    select nvl(max(nro_secuencia),0)
      into v_nro_secuencia
      from ge_movimientos_noc
     where fecha = p_fecha
       and hora = p_hora
       and cod_usuario = p_cod_usuario;
    --setear el parametro global a 'N' nocturno
    IT.PAG_CTA.G_HORARIO := 'N';
  end if;
  for r_gmovi in movimientos loop
     v_afe_sal_total     := 0;
     v_afe_sal_retenido  := 0;
     v_afe_sal_bloqueado := 0;
     if r_gmovi.cod_modulo in (3,4) and r_gmovi.monto is not null and
        r_gmovi.nro_cuenta is not null then
         -- obtengo el tipo d/c y a que saldo afecto
         lp_obt_tip_transaccion(r_gmovi.cod_transaccion,
                                r_gmovi.cod_modulo,
                                r_gmovi.cod_modalidad,
                                v_tip_movimiento, v_afecta,
                                v_act_ult_movimiento
                                );
         -- se pasa de pendiente de caja a normal
         if v_afecta = 'R' then -- afecta al saldo retenido
            if v_tip_movimiento = 'C' then
               v_afe_sal_total     := r_gmovi.monto;
               v_afe_sal_retenido  := r_gmovi.monto;
               v_afe_sal_bloqueado := 0;
            elsif v_tip_movimiento = 'D' then
               v_afe_sal_total     := 0;
               v_afe_sal_retenido  := 0; --r_gmovi.monto; -- ya no se debe tocar los saldos
               v_afe_sal_bloqueado := 0;
            end if;
         elsif v_afecta in ('C','I','S') then  -- afecta al saldo total,capital o interes
            if v_tip_movimiento = 'C' then
               v_afe_sal_total     := r_gmovi.monto;
               v_afe_sal_retenido  := 0;
               v_afe_sal_bloqueado := 0;
            elsif v_tip_movimiento = 'D' then
               v_afe_sal_total     := r_gmovi.monto;
               v_afe_sal_retenido  := 0;
               v_afe_sal_bloqueado := r_gmovi.monto;  -- se desblquea el monto
            end if;
         elsif v_afecta = 'B' then -- afecta al saldo bloqueado
            if v_tip_movimiento = 'C' then
               v_afe_sal_total     := 0;
               v_afe_sal_retenido  := 0;
               v_afe_sal_bloqueado := r_gmovi.monto;
            elsif v_tip_movimiento = 'D' then
               v_afe_sal_total     := 0;
               v_afe_sal_retenido  := 0;
               v_afe_sal_bloqueado := r_gmovi.monto;
            end if;
         end if;
         if r_gmovi.estado = 'N' and p_estado = 'J' then
            -- se esta reversando el paso por caja
            v_afe_sal_total     :=  v_afe_sal_total * -1;
            v_afe_sal_retenido  :=  v_afe_sal_retenido * -1;
            v_afe_sal_bloqueado :=  v_afe_sal_bloqueado * -1;
         end if;
         if r_gmovi.nro_cuenta is not null and
            (nvl(v_afe_sal_total,0) <> 0 or
             nvl(v_afe_sal_retenido,0) <> 0 or
             nvl(v_afe_sal_bloqueado,0) <> 0)  then
             -- retorno el monto al saldo
             pag_cta.pr_act_sal_cta(r_gmovi.nro_cuenta,
                                    r_gmovi.cod_modalidad,
                                    v_tip_movimiento,
                                    r_gmovi.fecha,
                                    r_gmovi.hora,
                                    v_afe_sal_total,
                                    v_afe_sal_retenido,
                                    v_afe_sal_bloqueado,
                                    null, /* autorizacion pendiente */
                                    v_act_ult_movimiento);
             -- obtengo los datos de la cuenta, para ver si se cambia de estado
             if p_estado = 'N' then -- pasa al estado 'N'

               pag_cta.pr_obt_cuenta(r_gmovi.nro_cuenta);
               v_nvo_estado := null;
               if v_tip_movimiento = 'C' then
                  -- credito, se puede pasar a 'N'
                  IF pag_cta.g_ctas.estado = 'I' and v_act_ult_movimiento = 'S' THEN
                     v_nvo_estado := 'N'; -- (N)ormal
                  ELSIF pag_cta.g_ctas.estado = 'A' THEN
                    if pag_cta.g_ctas.cod_modalidad = 33 and (pag_cta.g_ctas.capital <> pag_cta.g_ctas.sal_total)  then
                       v_nvo_estado := null; -- BBVASOP-1117 CDA debe fondear 100% para pasar a N-ormal
                    else
                       v_nvo_estado :=  'N'; --(N)ormal
                    end if;
                  ELSIF pag_cta.g_ctas.sal_total = 0 and pag_cta.g_ctas.estado = 'P' THEN
                     v_nvo_estado  := 'C'; -- (C)ancelada
                  END IF;
               elsif v_tip_movimiento = 'D' then
                  IF pag_cta.g_ctas.estado = 'I' and v_act_ult_movimiento = 'S' THEN
                     v_nvo_estado := 'N'; -- (N)ormal
                  ELSIF pag_cta.g_ctas.sal_total = 0 and pag_cta.g_ctas.estado = 'P' THEN
                     v_nvo_estado  := 'C'; -- (C)ancelada
                  END IF;
               end if;
               -- restauro el estado de la cuenta --
               if r_gmovi.nro_cuenta is not null and
                   r_gmovi.cod_modulo in (3,4)   and
                   v_nvo_estado is not null  then
                   v_nro_secuencia := v_nro_secuencia + 1;
                   pag_cta.pr_set_variables(r_gmovi.cod_usuario,
                                            r_gmovi.fec_valor,
                                            r_gmovi.cod_tra_padre,
                                            p_estado,--r_gmovi.estado,---deber?a pasar el estado nuevo del mov 'N' para q la act.del estado quede confirmada
                                            r_gmovi.reversado,
                                            v_nro_secuencia,
                                            v_nvo_estado,
                                            r_gmovi.cod_ofi_origen,
                                            r_gmovi.cod_mod_padre,
                                            r_gmovi.cod_mad_padre);
                  /* Actualiza el estado y genera el movimiento */
                   pag_cta.pr_act_estado(r_gmovi.nro_cuenta,
                                         v_nvo_estado,
                                         r_gmovi.fecha,
                                         r_gmovi.hora,
                                         r_gmovi.nro_documento,
                                         'S');
                   -- anulo las variables
                   pag_cta.pr_set_variables(user,
                                            null,
                                            null,
                                            null,--r_gmovi.estado,---deber?a pasar el estado nuevo del mov 'N' para q la act.del estado quede confirmada
                                            'N',
                                            v_nro_secuencia,
                                            null,
                                            null,
                                            null,
                                            null);
                   if pag_cta.g_cod_error <> 0 then
                      raise_application_error(-20008,'Error en act.estado '||pag_cta.G_MSJ_ERROR);
                   end if;
               end if;
             end if;
         end if;
     end if;
     if p_estado <> 'N' and r_gmovi.est_cuenta is not null and
        r_gmovi.monto is null and r_gmovi.cod_modulo in (3,4) then
        if v_est_modulo = 2 then-- El modulo esta abierto
          update ge_movimientos  -- no se reversa el estado, porque se hara en la reversion general
             set nro_caja = null
           where rowid = r_gmovi.fila;
        else
          update ge_movimientos_noc  -- no se reversa el estado, porque se hara en la reversion general
             set nro_caja = null
           where rowid = r_gmovi.fila;
        end if;
     else
         -- actualizo el movimiento al estado nuevo
         if r_gmovi.cod_modulo = 4 and r_gmovi.cod_modalidad = 43 and
            r_gmovi.cod_transaccion = 603 and p_estado = 'J' then -- Cheque Generencia no debe cambiar de Estado.
            if v_est_modulo = 2 then-- El modulo esta abierto
               update ge_movimientos
                  set nro_caja = decode(p_estado,'N',p_nro_caja,null),
                      cod_ofi_origen = decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),
                      cod_oficina = decode(nro_cuenta,null,decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),cod_oficina)
                where rowid = r_gmovi.fila;
            else
              update ge_movimientos_noc
                  set nro_caja = decode(p_estado,'N',p_nro_caja,null),
                      cod_ofi_origen = decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),
                      cod_oficina = decode(nro_cuenta,null,decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),cod_oficina)
                where rowid = r_gmovi.fila;
            end if;
         else
           if v_est_modulo = 2 then-- El modulo esta abierto
             update ge_movimientos
                set estado = p_estado,
                    nro_caja = decode(p_estado,'N',p_nro_caja,null),
                    cod_ofi_origen = decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),
                    cod_oficina = decode(cod_transaccion, 254, cod_oficina,-- CB. 11/10/2013. SPI 2409. No se debe cambiar, siempre debe ser 31 (lmcompra)
                                  decode(nro_cuenta,null,decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),cod_oficina))
              where rowid = r_gmovi.fila;
           else
             update ge_movimientos_noc
                set estado = p_estado,
                    nro_caja = decode(p_estado,'N',p_nro_caja,null),
                    cod_ofi_origen = decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),
                    cod_oficina = decode(cod_transaccion, 254, cod_oficina,-- CB. 11/10/2013. SPI 2409. No se debe cambiar, siempre debe ser 31 (lmcompra)
                                  decode(nro_cuenta,null,decode(p_estado,'N',nvl(p_cod_ofi_origen,cod_ofi_origen),cod_ofi_origen),cod_oficina))
              where rowid = r_gmovi.fila;
           end if;
         end if;
          ---
          /* RI : 11/02/2010 : Si se trata de Pago de Tarjeta de Credito
           Se agrega la grabacion en Ta_cobros que antes estaba en el
           Formulario TMCOBROS */
          if r_gmovi.cod_tra_padre = 250 and r_gmovi.monto is not null and
             r_gmovi.nro_cuenta is not null and r_gmovi.cod_mod_padre <> 7  then
             v_nro_Tarjeta := substr(r_gmovi.concepto,20,25);
             if  v_nro_Tarjeta is null then
               raise_application_error(-20008,'Error al traer nro. de tarjeta.');
             end if;
             pat_val.G_PROCESO := 'FUJ_PRO_TRANSACCION_250';

             --Obtengo la procesadora de la cuenta TC
             v_cod_procesadora:= fut_obt_procesadora(r_gmovi.nro_documento);

             If v_cod_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL') then
               insert into ta_cobros_gp
                           (nro_cuenta,nro_tarjeta,monto,estado,observacion,
                           fec_proceso,fec_valor,hora,cod_usuario,tipo,canal)
                    values
                           (r_gmovi.nro_documento,v_nro_tarjeta,
                           r_gmovi.monto,'P','Procesado a Requerimiento',
                           r_gmovi.fecha,r_gmovi.fec_valor,r_gmovi.hora,r_gmovi.cod_usuario,'P','C');
             Else
               insert into ta_cobros
                           (nro_cuenta,nro_tarjeta,monto,estado,observacion,
                           fec_proceso,fec_valor,hora,cod_usuario)
                    values
                           (r_gmovi.nro_documento,v_nro_tarjeta,
                           r_gmovi.monto,'P','Procesado a Requerimiento',
                           r_gmovi.fecha,r_gmovi.fec_valor,r_gmovi.hora,r_gmovi.cod_usuario);
             End If;
           End if;

     end if;
     --actualizar la transferecia si corresponde
     if (r_gmovi.nro_secuencia = 1 and r_gmovi.cod_mad_padre in (72)) --venta
      or (r_gmovi.nro_secuencia = 2 and r_gmovi.cod_mad_padre in (73,74)) then --arb/cje
        begin
           select cod_mad_hijo, afe_transferencia
             into v_cod_mad_hijo, v_afe_transferencias
             from lc_tip_operaciones
            where cod_tip_operacion = r_gmovi.cod_tip_ope_cambio;
        exception
           when others then
              raise_application_error(-20011,'Tipo Ope. Cambio '||r_gmovi.cod_tip_ope_cambio||'. '||sqlerrm);
        end;
        if v_afe_transferencias = 'S' and v_cod_mad_hijo = 72 then
          if p_estado ='N' then-- est? confirmando
             if r_gmovi.cod_tip_ope_cambio <> 140 then
                begin
                  update lc_transferencias
                     set estado = 'C'
                   where nro_operacion = to_number(r_gmovi.nro_documento)
                     and cod_modalidad <> 75;
                exception
                    when others then
                       raise_application_error(-20012,'Operaci?n Nro. '||r_gmovi.nro_documento||'. '||sqlerrm);
                end;
                if sql%notfound then
                   raise_application_error(-20013,'No se encuentra Transferencia Nro. '||r_gmovi.nro_documento);
                end if;
             end if;
          elsif p_estado ='J' then --reversa el pase x caja
             update lc_transferencias
                set estado = est_anterior
              where nro_operacion = to_number(r_gmovi.nro_documento)
                and cod_modalidad <> 75
             returning fec_envio into v_fec_envio;
          end if;
          if v_fec_envio is not null then
             raise_application_error(-20000,'No puede reversar. La transferencia ha sido enviada');
          else
             if p_estado ='J' then
               begin
                 it_mail.mail(fug_obt_dir_correo,
                              fug_obt_dir_mail_usu(FUG_OBT_PARDINAMICO('COD_USU_ENC_COMEX')),
                              'Reversi?n de Transferencia',
                              'La Operaci?n Nro. '||to_number(r_gmovi.nro_documento)||' que involucra a una Transferencia Emitida '||
                              'ha sido reversada.');
               exception
                  when others then
                     null;
               end;
             end if;
          end if;
        end if;
     end if;
   end loop;
exception
   when others then
      raise_application_error(-20000,'Pr_act_movimientos '|| ' - ' ||sqlerrm);
END;
-- actualizacion de posicion de cambios
PROCEDURE PR_ACT_POSICIONES
(p_cod_tip_operacion in varchar2,
 p_cod_moneda in varchar2,
 p_cod_ofi_cambio in number,
 p_monto in number,
 p_mto_equiv in number,
 p_cod_tip_ope_bcp in varchar2 default null)
 IS
v_mto_com_efe_act     lc_posiciones.mto_com_efe_act%type;
v_mto_com_nef_act     lc_posiciones.mto_com_efe_act%type;
v_mto_vta_efe_act     lc_posiciones.mto_com_efe_act%type;
v_mto_vta_nef_act     lc_posiciones.mto_com_efe_act%type;
v_mto_arb_com_efe_act lc_posiciones.mto_com_efe_act%type;
v_mto_arb_com_nef_act lc_posiciones.mto_com_efe_act%type;
v_mto_arb_vta_efe_act lc_posiciones.mto_com_efe_act%type;
v_mto_arb_vta_nef_act lc_posiciones.mto_com_efe_act%type;
v_mto_cje_com_efe_act lc_posiciones.mto_com_efe_act%type;
v_mto_cje_com_nef_act lc_posiciones.mto_com_efe_act%type;
v_mto_cje_vta_efe_act lc_posiciones.mto_com_efe_act%type;
v_mto_cje_vta_nef_act lc_posiciones.mto_com_efe_act%type;
v_mto_com_efe_loc     lc_posiciones.mto_com_efe_act%type;
v_mto_com_nef_loc     lc_posiciones.mto_com_efe_act%type;
v_mto_vta_efe_loc     lc_posiciones.mto_com_efe_act%type;
v_mto_vta_nef_loc     lc_posiciones.mto_com_efe_act%type;
v_afe_posicion        lc_tip_operaciones.afe_posicion%type;
v_cod_modalidad       lc_tip_operaciones.cod_modalidad%type;
v_cod_mad_hijo        lc_tip_operaciones.cod_mad_hijo%type;
v_cod_tip_ope_bcp     lc_tip_operaciones.cod_tip_ope_bcp%type;
BEGIN
  --recuperar par?metros para determinar a qu? afecta
  select afe_posicion, cod_modalidad, cod_mad_hijo, nvl(p_cod_tip_ope_bcp,cod_tip_ope_bcp)
  into v_afe_posicion, v_cod_modalidad, v_cod_mad_hijo, v_cod_tip_ope_bcp
  from lc_tip_operaciones
  where cod_tip_operacion = p_cod_tip_operacion;
  --solo si afecta posici?n
  if v_afe_posicion not in ('E','O') then
     return;
  end if;
  --evaluar campos a actualizar
  if v_cod_modalidad = 71 then --compra
    if v_afe_posicion = 'E' then --efectivo
      v_mto_com_efe_act := p_monto;
       v_mto_com_efe_loc := p_mto_equiv;
    else
      v_mto_com_nef_act := p_monto;
       v_mto_com_nef_loc := p_mto_equiv;
    end if;
  elsif v_cod_modalidad = 72 then --venta
    if v_afe_posicion = 'E' then --efectivo
      v_mto_vta_efe_act := p_monto;
       v_mto_vta_efe_loc := p_mto_equiv;
    else
      v_mto_vta_nef_act := p_monto;
       v_mto_vta_nef_loc := p_mto_equiv;
    end if;
  elsif v_cod_modalidad = 73 then --arbitraje
    if v_cod_mad_hijo = 71 then --compra
      if v_afe_posicion = 'E' then --efectivo
        v_mto_arb_com_efe_act := p_monto;
         v_mto_com_efe_loc := p_mto_equiv;
      else
        v_mto_arb_com_nef_act := p_monto;
         v_mto_com_nef_loc := p_mto_equiv;
      end if;
    elsif v_cod_mad_hijo = 72 then --venta
      if v_afe_posicion = 'E' then --efectivo
        v_mto_arb_vta_efe_act := p_monto;
         v_mto_vta_efe_loc := p_mto_equiv;
      else
        v_mto_arb_vta_nef_act := p_monto;
         v_mto_vta_nef_loc := p_mto_equiv;
      end if;
    end if;
  elsif v_cod_modalidad = 74 then --canje
    if v_cod_mad_hijo = 71 then --compra
      if v_afe_posicion = 'E' then --efectivo
        v_mto_cje_com_efe_act := p_monto;
         v_mto_com_efe_loc := p_mto_equiv;
      else
        v_mto_cje_com_nef_act := p_monto;
         v_mto_com_nef_loc := p_mto_equiv;
      end if;
    elsif v_cod_mad_hijo = 72 then --venta
      if v_afe_posicion = 'E' then --efectivo
        v_mto_cje_vta_efe_act := p_monto;
         v_mto_vta_efe_loc := p_mto_equiv;
      else
        v_mto_cje_vta_nef_act := p_monto;
         v_mto_vta_nef_loc := p_mto_equiv;
      end if;
    end if;
  end if;
  --ACTUALIZACION
  begin
    update lc_posiciones
       set mto_com_efe_act = nvl(mto_com_efe_act,0) + nvl(v_mto_com_efe_act,0),
           mto_com_nef_act = nvl(mto_com_nef_act,0) + nvl(v_mto_com_nef_act,0),
           mto_vta_efe_act = nvl(mto_vta_efe_act,0) + nvl(v_mto_vta_efe_act,0),
           mto_vta_nef_act = nvl(mto_vta_nef_act,0) + nvl(v_mto_vta_nef_act,0),
           mto_arb_com_efe_act = nvl(mto_arb_com_efe_act,0) + nvl(v_mto_arb_com_efe_act,0),
           mto_arb_com_nef_act = nvl(mto_arb_com_nef_act,0) + nvl(v_mto_arb_com_nef_act,0),
           mto_arb_vta_efe_act = nvl(mto_arb_vta_efe_act,0) + nvl(v_mto_arb_vta_efe_act,0),
           mto_arb_vta_nef_act = nvl(mto_arb_vta_nef_act,0) + nvl(v_mto_arb_vta_nef_act,0),
           mto_cje_com_efe_act = nvl(mto_cje_com_efe_act,0) + nvl(v_mto_cje_com_efe_act,0),
           mto_cje_com_nef_act = nvl(mto_cje_com_nef_act,0) + nvl(v_mto_cje_com_nef_act,0),
           mto_cje_vta_efe_act = nvl(mto_cje_vta_efe_act,0) + nvl(v_mto_cje_vta_efe_act,0),
           mto_cje_vta_nef_act = nvl(mto_cje_vta_nef_act,0) + nvl(v_mto_cje_vta_nef_act,0),
           mto_com_efe_loc = nvl(mto_com_efe_loc,0) + nvl(v_mto_com_efe_loc,0),
           mto_com_nef_loc = nvl(mto_com_nef_loc,0) + nvl(v_mto_com_nef_loc,0),
           mto_vta_efe_loc = nvl(mto_vta_efe_loc,0) + nvl(v_mto_vta_efe_loc,0),
           mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + nvl(v_mto_vta_nef_loc,0)
     where cod_tip_ope_bcp = v_cod_tip_ope_bcp
       and cod_moneda      = p_cod_moneda
       and cod_ofi_cambio  = p_cod_ofi_cambio;

       If sql%notfound then
         --insertar la posici?n
         insert into lc_posiciones
          (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
          mto_com_efe_act, mto_com_nef_act,
          mto_vta_efe_act, mto_vta_nef_act,
          mto_arb_com_efe_act, mto_arb_com_nef_act,
          mto_arb_vta_efe_act, mto_arb_vta_nef_act,
          mto_cje_com_efe_act, mto_cje_com_nef_act,
          mto_cje_vta_efe_act, mto_cje_vta_nef_act,
          mto_com_efe_loc, mto_com_nef_loc,
          mto_vta_efe_loc, mto_vta_nef_loc)
        values
          (p_cod_moneda, v_cod_tip_ope_bcp, p_cod_ofi_cambio,
          nvl(v_mto_com_efe_act,0), nvl(v_mto_com_nef_act,0),
          nvl(v_mto_vta_efe_act,0), nvl(v_mto_vta_nef_act,0),
          nvl(v_mto_arb_com_efe_act,0), nvl(v_mto_arb_com_nef_act,0),
          nvl(v_mto_arb_vta_efe_act,0), nvl(v_mto_arb_vta_nef_act,0),
          nvl(v_mto_cje_com_efe_act,0), nvl(v_mto_cje_com_nef_act,0),
          nvl(v_mto_cje_vta_efe_act,0), nvl(v_mto_cje_vta_nef_act,0),
          nvl(v_mto_com_efe_loc,0), nvl(v_mto_com_nef_loc,0),
          nvl(v_mto_vta_efe_loc,0), nvl(v_mto_vta_nef_loc,0));
       end if;
  exception
     WHEN OTHERS THEN
      if sqlcode = -54 then
        raise_application_error(-20000,'Reg. Lc_posiciones '||p_cod_ofi_cambio||'-'||v_cod_tip_ope_bcp||' bloqueado por otro usuario');
      else
        RAISE_APPLICATION_ERROR(-20000,SQLERRM||'Actu. Posiciones '||p_cod_ofi_cambio||'-'||v_cod_tip_ope_bcp||'-'||p_cod_moneda);
      end if;
    END;
exception
  when no_data_found then
    raise_application_error(-20000,'No existe Operaci?n '||p_cod_tip_operacion);
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
      raise;
    else
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'PRL_ACT_POSICIONES '||p_cod_ofi_cambio||'-'||v_cod_tip_ope_bcp||'-'||p_cod_moneda);
    end if;
END;
-- fin de actualizacion de posicion

-- retorna la oficina de cambio de una oficina dada
function FU_OBT_OFI_CAMBIO(p_cod_oficina in ba_oficinas.cod_oficina%type)
   return number is
 v_cod_ofi_cambio  ba_oficinas.cod_oficina%type;
begin
   select cod_ofi_cambio
     into v_cod_ofi_cambio
     from ba_oficinas
    where cod_oficina = p_cod_oficina;
   return v_cod_ofi_cambio;
exception
   when others then
      return null;
end;

/* Obtiene la cotizaci?n de venta de una moneda */
FUNCTION FU_OBT_COT_VENTA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS

V_VAL_VENTA GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   IF fug_obt_tip_implementacion <> 2 then
      BEGIN
         SELECT  val_venta
         INTO  v_val_venta
         FROM  ge_cotizaciones a
         WHERE  fecha  = (SELECT max(fecha)
                            FROM ge_cotizaciones
                           WHERE cod_moneda = a.cod_moneda
                             AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
         AND  cod_moneda = p_cod_moneda;
         Return v_val_venta;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_val_venta := NULL;
            Return v_val_venta;
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Cotizacion de Venta ');
      END;
   ELSE
      BEGIN
         SELECT val_venta
           INTO v_val_venta
           FROM lc_cot_oficinas a
          WHERE fecha  = (SELECT max(fecha)
                            FROM lc_cot_oficinas
                           WHERE cod_moneda = a.cod_moneda
                             AND cod_oficina = a.cod_oficina
                             AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
            AND cod_moneda = p_cod_moneda
            AND cod_oficina = (select cod_oficina
                                 from ba_usuarios
                                where cod_usuario = user);
         Return v_val_venta;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
              BEGIN
                 SELECT  val_venta
                 INTO  v_val_venta
                 FROM  ge_cotizaciones a
                 WHERE  fecha  = (SELECT max(fecha)
                                    FROM ge_cotizaciones
                                   WHERE cod_moneda = a.cod_moneda
                                     AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
                 AND  cod_moneda = p_cod_moneda;
                 Return v_val_venta;
              EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                    v_val_venta := NULL;
                    Return v_val_venta;
                 WHEN OTHERS THEN
                    RAISE_APPLICATION_ERROR(-20002,SQLERRM||'ERROR. Al buscar Cotizacion de Venta ');
              END;
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001,SQLERRM||'ERROR. Al buscar Cotizacion de Venta ');
      END;
   END IF;
END;
/* Obtiene la cotizaci?n de compra de una moneda */
FUNCTION FU_OBT_COT_COMPRA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS

V_VAL_COMPRA GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   IF fug_obt_tip_implementacion <> 2 then
      BEGIN
         SELECT  val_compra
         INTO  v_val_compra
         FROM  ge_cotizaciones a
         WHERE  fecha  = (SELECT max(fecha)
                            FROM ge_cotizaciones
                           WHERE cod_moneda = a.cod_moneda
                             AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
         AND  cod_moneda = p_cod_moneda;
         Return v_val_compra;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_val_compra := NULL;
            Return v_val_compra;
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Cotizacion de Compra ');
      END;
   ELSE
      BEGIN
         SELECT val_compra
           INTO v_val_compra
           FROM lc_cot_oficinas a
          WHERE fecha  = (SELECT max(fecha)
                            FROM lc_cot_oficinas
                           WHERE cod_moneda = a.cod_moneda
                             AND cod_oficina = a.cod_oficina
                             AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
            AND cod_moneda = p_cod_moneda
            AND cod_oficina = (select cod_oficina
                                 from ba_usuarios
                                where cod_usuario = user);
         Return v_val_compra;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            BEGIN
               SELECT  val_compra
               INTO  v_val_compra
               FROM  ge_cotizaciones a
               WHERE  fecha  = (SELECT max(fecha)
                                  FROM ge_cotizaciones
                                 WHERE cod_moneda = a.cod_moneda
                                   AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
               AND  cod_moneda = p_cod_moneda;
               Return v_val_compra;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_val_compra := NULL;
                  Return v_val_compra;
               WHEN OTHERS THEN
                  RAISE_APPLICATION_ERROR(-20002,SQLERRM||'ERROR. Al buscar Cotizacion de Compra ');
            END;
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001,SQLERRM||'ERROR. Al buscar Cotizacion de Compra ');
      END;
   END IF;
END;
/*Obtiene la cotizacion de compra cheque de una moneda */
FUNCTION FU_OBT_COT_COM_CHEQUE
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS

V_VAL_COM_CHEQUE GE_COTIZACIONES.VAL_COM_CHEQUE%TYPE;
BEGIN
   SELECT val_com_cheque
     INTO v_val_com_cheque
    FROM ge_cotizaciones a
   WHERE fecha = (SELECT max(fecha)
                     FROM ge_cotizaciones
                     WHERE cod_moneda = a.cod_moneda
                       AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
   AND cod_moneda = p_cod_moneda;
   Return v_val_com_cheque;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_com_cheque := NULL;
      Return v_val_com_cheque;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Cotizacion de Compra Cheque. ');
END;
/*Obtiene la cotizacion de venta cheque de una moneda */
FUNCTION FU_OBT_COT_VEN_CHEQUE
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS

V_VAL_VEN_CHEQUE GE_COTIZACIONES.VAL_VEN_CHEQUE%TYPE;
BEGIN
   SELECT val_ven_cheque
     INTO v_val_ven_cheque
    FROM ge_cotizaciones a
   WHERE fecha = (SELECT max(fecha)
                      FROM ge_cotizaciones
                     WHERE cod_moneda = a.cod_moneda
                       AND fecha <= NVL(P_FEC_TRANSACCION,SYSDATE))
   AND cod_moneda = p_cod_moneda;
   Return v_val_ven_cheque;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_ven_cheque := NULL;
      Return v_val_ven_cheque;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Cotizacion de Venta Cheque. ');
END;

/* Inicializa la posici?n de cambios del d?a */
PROCEDURE PR_INI_DIA_POSICION
IS
v_fec_actual date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy

BEGIN
  if v_fec_actual = pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(7) then
    -- es el primer dia del mes y se borraran todos los datos ---
    DELETE LC_POSICIONES;
  else
    --actualiza todos los d?as
    UPDATE LC_POSICIONES a
    SET (MTO_COM_EFE_ANT, MTO_VTA_EFE_ANT, MTO_COM_NEF_ANT, MTO_VTA_NEF_ANT,
         MTO_ARB_COM_EFE_ANT, MTO_ARB_VTA_EFE_ANT, MTO_ARB_COM_NEF_ANT, MTO_ARB_VTA_NEF_ANT,
         MTO_CJE_COM_EFE_ANT, MTO_CJE_VTA_EFE_ANT, MTO_CJE_COM_NEF_ANT, MTO_CJE_VTA_NEF_ANT,
         MTO_COM_EFE_LOC, MTO_COM_NEF_LOC, MTO_VTA_EFE_LOC, MTO_VTA_NEF_LOC) =
      (SELECT nvl(MTO_COM_EFE_ANT,0) + nvl(MTO_COM_EFE_ACT,0),
            nvl(MTO_VTA_EFE_ANT,0) + nvl(MTO_VTA_EFE_ACT,0),
            nvl(MTO_COM_NEF_ANT,0) + nvl(MTO_COM_NEF_ACT,0),
            nvl(MTO_VTA_NEF_ANT,0) + nvl(MTO_VTA_NEF_ACT,0),
            nvl(MTO_ARB_COM_EFE_ANT,0) + nvl(MTO_ARB_COM_EFE_ACT,0),
            nvl(MTO_ARB_VTA_EFE_ANT,0) + nvl(MTO_ARB_VTA_EFE_ACT,0),
            nvl(MTO_ARB_COM_NEF_ANT,0) + nvl(MTO_ARB_COM_NEF_ACT,0),
            nvl(MTO_ARB_VTA_NEF_ANT,0) + nvl(MTO_ARB_VTA_NEF_ACT,0),
            nvl(MTO_CJE_COM_EFE_ANT,0) + nvl(MTO_CJE_COM_EFE_ACT,0),
            nvl(MTO_CJE_VTA_EFE_ANT,0) + nvl(MTO_CJE_VTA_EFE_ACT,0),
            nvl(MTO_CJE_COM_NEF_ANT,0) + nvl(MTO_CJE_COM_NEF_ACT,0),
            nvl(MTO_CJE_VTA_NEF_ANT,0) + nvl(MTO_CJE_VTA_NEF_ACT,0),
            0, 0, 0, 0
    FROM LC_POSICIONES b
    WHERE a.rowid = b.rowid);
    ---- cera datos del dia
    UPDATE LC_POSICIONES
    SET  MTO_COM_EFE_ACT = 0, MTO_VTA_EFE_ACT = 0, MTO_COM_NEF_ACT = 0, MTO_VTA_NEF_ACT = 0,
         MTO_ARB_COM_EFE_ACT = 0, MTO_ARB_VTA_EFE_ACT = 0, MTO_ARB_COM_NEF_ACT = 0, MTO_ARB_VTA_NEF_ACT = 0,
         MTO_CJE_COM_EFE_ACT = 0, MTO_CJE_VTA_EFE_ACT = 0, MTO_CJE_COM_NEF_ACT = 0, MTO_CJE_VTA_NEF_ACT = 0;
  end if;
EXCEPTION
   WHEN OTHERS THEN
     raise_application_error(-20000,'Inicializa Posici?n '||sqlerrm);
END;

/*Liberaci?n de retenci?n de los l?mites de cambios*/
PROCEDURE PR_LIB_RET_CAMBIOS
(p_fecha in date default null,
 p_nro_cuenta in varchar default null,
 p_anticipada in varchar2 default null,
 --wa:recibimos Nro de Boleta
 p_nro_boleta in varchar2 default null,
 --Recibimos tipo
 p_tipo in varchar2 default null,
 p_clasificacion in varchar2 default null
 )
IS
  v_fecha date;
  v_fec_actual date:=pag_cal.FU_OBT_FEC_ACTUAL(7);
  v_lugar varchar2(3000);

  CURSOR ret IS
    SELECT *
    FROM LC_RETENCIONES
    WHERE
     LIBERADO  = 'N' AND
    ((FEC_FIN <= v_fecha and P_ANTICIPADA IS NULL)
      OR (FEC_FIN >=  v_fecha and NVL(lib_anticipada,'N')=P_ANTICIPADA and NRO_CUENTA = P_NRO_CUENTA
      and nro_boleta=p_nro_boleta))
    FOR UPDATE OF LIBERADO;

 CURSOR ret1 IS
       SELECT A.COD_MODULO,A.COD_MODALIDAD,A.NRO_BOLETA,
        A.COD_OFICINA,A.NRO_CUENTA,A.COD_MONEDA,
        A.SAL_RETENIDO,A.FEC_FIN,A.LIBERADO,A.COD_RETENCION,A.COD_USUARIO,
        A.FEC_INICIO,A.DETALLADO,A.COD_OFI_ORIGEN,'NORMAL' TIPO,'TR' CLA,a.cotizacion, A.MONTO
        FROM LC_RETENCIONES A, lc_transferencias w
        WHERE A.LIBERADO = 'N'
        and A.NRO_BOLETA= w.nro_operacion
        and w.cod_modalidad=75 and w.estado = 'OK'
        AND (a.FEC_FIN <= v_fecha )
      union all
        SELECT A.COD_MODULO,A.COD_MODALIDAD,A.NRO_BOLETA,
        A.COD_OFICINA,A.NRO_CUENTA,A.COD_MONEDA,
        A.SAL_RETENIDO,A.FEC_FIN,A.LIBERADO,A.COD_RETENCION,A.COD_USUARIO,
        A.FEC_INICIO,A.DETALLADO,A.COD_OFI_ORIGEN,'NORMAL' TIPO,'OF' CLA,a.cotizacion, A.MONTO
        FROM LC_RETENCIONES A, lc_ope_futuras f
        WHERE A.LIBERADO = 'N'
        and A.nro_boleta= f.nro_operacion
        AND (a.FEC_FIN <= v_fecha )
      union all
        SELECT  DISTINCT A.COD_MODULO,A.COD_MODALIDAD,A.NRO_BOLETA,
        A.COD_OFICINA,A.NRO_CUENTA,A.COD_MONEDA,
        A.SAL_RETENIDO,A.FEC_FIN,A.LIBERADO,A.COD_RETENCION,A.COD_USUARIO,
        A.FEC_INICIO,A.DETALLADO,A.COD_OFI_ORIGEN,UPPER(DECODE(X.ESTADO,'C','NORMAL','D','DEVUELTO')) TIPO,'CH' CLA,a.cotizacion, A.MONTO
        FROM LC_RETENCIONES A,cc_che_enviados x
        where A.LIBERADO = 'N'
        and (X.estado = 'C'
        or (x.estado= nvl(fug_obt_pardinamico('CAM_EST_CHE_CIERRE',7),'C')))
        AND A.NRO_CUENTA= X.NRO_CUENTA
        and a.nro_boleta=x.nro_boleta
        AND (trunc(a.FEC_FIN) <= trunc(v_fecha) )
      union all
        SELECT  DISTINCT A.COD_MODULO,A.COD_MODALIDAD,A.NRO_BOLETA,
        A.COD_OFICINA,A.NRO_CUENTA,A.COD_MONEDA,
        A.SAL_RETENIDO,A.FEC_FIN,A.LIBERADO,A.COD_RETENCION,A.COD_USUARIO,
        A.FEC_INICIO,A.DETALLADO,A.COD_OFI_ORIGEN,'NORMAL' TIPO,'EB' CLA,a.cotizacion, A.MONTO
        FROM LC_RETENCIONES A
        where A.LIBERADO = 'N'
        AND (trunc(a.FEC_FIN) <= trunc(v_fecha))        
        AND EXISTS (select distinct 1 
                     from ba_cod_referencias r
                    where r.dominio = 'CAM_TIP_OPE_CAM_BANCOS'
                      and r.val_maximo = a.cod_retencion);

  --se puede liberar anticipadamente el l?mite
  r_reten LC_RETENCIONES%ROWTYPE;
  r_gmovi ge_movimientos%rowtype;
  v_nro_secuencia ge_movimientos.nro_secuencia%type :=0;
  v_hora ge_movimientos.hora%type := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_tipo VARCHAR2(1);
  v_mto_retenido number(18,2):=0;
BEGIN
  if p_fecha is null then
    v_fecha := pag_cal.fu_obt_fec_actual(7);
  else
    v_fecha := p_fecha;
  end if;
  --WA:12/09/2013 Si recibe Nro de Cuenta es del formulario de Lib.Ret.Manual
  --Por lo que debe Liberar Nomas, Sino es en el cierre de Sistema, por
  --Lo que tiene que validar y no liberaer nomas
  if p_nro_cuenta is not null and p_nro_boleta is not null then
        --Proceso Nuevo
        for r_reten in ret loop
           v_lugar:='Entra cursor Ret';

            IF p_clasificacion='CH' THEN
               if p_tipo='DEVUELTO' THEN
                  V_TIPO:='D';
               ELSE
                  V_TIPO:='C';
               END IF;
               v_lugar:='Al buscar Mto.Cheque';

               begin
                 select sum(decode(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.monto/r_reten.cotizacion,a.monto ))
                  into v_mto_retenido
                  from cc_che_enviados a
                   where a.nro_boleta=p_nro_boleta
                   and a.nro_cuenta=p_nro_cuenta
                    and a.estado=V_TIPO;
               exception
                when no_data_found then
                  v_mto_retenido:='0';
               end;
               if v_mto_retenido> 0 then
                  v_lugar:='Al act. saldo retenido';

                   if nvl(r_reten.sal_retenido,0)-nvl(v_mto_retenido,0)< 1  then
                              -----------------
                        UPDATE LC_RETENCIONES A
                           SET A.LIBERADO = 'S',
                           a.sal_retenido=0
                         WHERE CURRENT OF ret;
                   else
                          UPDATE LC_RETENCIONES A
                           set a.sal_retenido=a.sal_retenido- nvl(v_mto_retenido,0)
                         WHERE CURRENT OF ret;

                   end if;
                     --Actualizamos los Cheques, si estan confirmados
                    if V_TIPO='C' THEN
                         UPDATE CC_CHE_ENVIADOS A
                          SET --A.ESTADO = 'L',
                           a.liberado='S'
                        WHERE A.NRO_BOLETA= r_reten.nro_boleta
                         AND A.NRO_CUENTA=R_RETEN.NRO_CUENTA
                          AND A.ESTADO=V_TIPO;
                    END IF;



                   BEGIN
                      --Siempre Hace
                      UPDATE LC_CTA_CAMBIOS
                         SET MTO_UTILIZADO = NVL(MTO_UTILIZADO,0)- NVL(v_mto_retenido,0)  -- - NVL(r_reten.MONTO,0)
                       WHERE NRO_CUENTA = r_reten.NRO_CUENTA;
                         IF SQL%NOTFOUND THEN
                           raise_application_error(-20000,'No se encontr? cta. de cambios'||r_reten.NRO_CUENTA);
                         END IF;
                   END;
               end if;

            ELSE
             v_lugar:='Al act. saldo retenido Ope.Fut/tra.';

              -----------------
              UPDATE LC_RETENCIONES A
                 SET A.LIBERADO = 'S',
                 a.sal_retenido=0
               WHERE CURRENT OF ret;

             --Actualizamos el monto utilizado de la Cta. de Cambios. DYDMR-3208-12/04/16
               UPDATE LC_CTA_CAMBIOS
                  SET MTO_UTILIZADO = NVL(MTO_UTILIZADO,0)- NVL(r_reten.monto,0)
                WHERE NRO_CUENTA = r_reten.NRO_CUENTA;
                  IF SQL%NOTFOUND THEN
                    raise_application_error(-20000,'No se encontr? cta. de cambios'||r_reten.NRO_CUENTA);
                  END IF;

            END IF;

            --- genera movimiento ---
            v_nro_secuencia       := v_nro_secuencia + 1;
            --sig segundo x si hay mas de 999 reg.
            if v_nro_secuencia >= 999 then
               v_hora := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
               v_nro_secuencia := 1;
            end if;
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_modulo    := r_reten.cod_modulo;
            r_gmovi.cod_modalidad := r_reten.cod_modalidad;
            r_gmovi.cod_oficina   := r_reten.cod_oficina;
            r_gmovi.nro_cuenta    := r_reten.nro_cuenta;
            r_gmovi.cod_moneda    := r_reten.COD_MONEDA;
            r_gmovi.fec_valor     := v_fecha;
            r_gmovi.fecha         := v_fecha;
            r_gmovi.cod_tra_padre   := 515;
            r_gmovi.cod_transaccion := 515;
            r_gmovi.nro_documento := r_reten.nro_boleta;
            r_gmovi.monto         := NVL(v_mto_retenido,0);--r_reten.Sal_Retenido;
            r_gmovi.cod_retencion := r_reten.cod_retencion;
            r_gmovi.fec_fin_retencion := r_reten.fec_fin;
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := r_reten.cod_ofi_origen;
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := r_reten.cod_modulo;
            r_gmovi.cod_mad_padre := r_reten.cod_modalidad;
            r_gmovi.concepto      := 'Liberacion de limite de clientes';
            v_lugar:='Al insertar Movimiento';
           pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         END LOOP;
   else
         --Proceso Anterior
         for r_reten in ret1 loop
            v_lugar:='Al act. en Cta.Cam. ret1';

          BEGIN
                --******************************
                IF r_reten.cla='CH' THEN
                   V_TIPO:='C';
                   v_lugar:='Al buscar Mto.Cheque';

                   begin
                     select sum(decode(a.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,a.monto/r_reten.cotizacion,a.monto ))
                      into v_mto_retenido
                       from cc_che_enviados a
                        where a.nro_boleta=R_RETEN.NRO_BOLETA
                          and a.nro_cuenta=R_RETEN.NRO_CUENTA
                          and a.estado=V_TIPO;
                   exception
                    when no_data_found then
                      v_mto_retenido:='0';
                   end;
                   if v_mto_retenido> 0 then
                      v_lugar:='Al act. saldo retenido';

                       if nvl(r_reten.sal_retenido,0)-nvl(v_mto_retenido,0)< 1  then
                                  -----------------
                            UPDATE LC_RETENCIONES A
                               SET A.LIBERADO = 'S',
                               a.sal_retenido=0
                             WHERE A.NRO_BOLETA= r_reten.nro_boleta
                              AND A.nro_cuenta= r_reten.nro_cuenta;
                       else
                              UPDATE LC_RETENCIONES A
                               set a.sal_retenido=a.sal_retenido- nvl(v_mto_retenido,0)
                             WHERE A.NRO_BOLETA= r_reten.nro_boleta
                              AND A.nro_cuenta= r_reten.nro_cuenta;

                       end if;
                         --Actualizamos los Cheques, si estan confirmados
                        if V_TIPO='C' THEN
                             UPDATE CC_CHE_ENVIADOS A
                              SET --A.ESTADO = 'L',
                               a.liberado='S'
                            WHERE A.NRO_BOLETA= r_reten.nro_boleta
                              AND A.NRO_CUENTA=R_RETEN.NRO_CUENTA
                              AND A.ESTADO=V_TIPO;
                        END IF;

                       BEGIN
                          --Siempre Hace
                          UPDATE LC_CTA_CAMBIOS
                             SET MTO_UTILIZADO = NVL(MTO_UTILIZADO,0)- NVL(v_mto_retenido,0)  -- - NVL(r_reten.MONTO,0)
                           WHERE NRO_CUENTA = r_reten.NRO_CUENTA;
                             IF SQL%NOTFOUND THEN
                               raise_application_error(-20000,'No se encontr? cta. de cambios'||r_reten.NRO_CUENTA);
                             END IF;
                       END;
                   end if;

                ELSE
                 v_lugar:='Al act. saldo retenido Ope.Fut/tra.';

                  -----------------

                  UPDATE LC_RETENCIONES A
                     SET A.LIBERADO = 'S',
                     a.sal_retenido=0
                   WHERE a.nro_cuenta= r_reten.nro_cuenta
                    and a.nro_boleta= r_reten.nro_boleta;

                   --Actualizamos el monto utilizado de la Cta. de Cambios. DYDMR-3208-12/04/16
                 UPDATE LC_CTA_CAMBIOS
                    SET MTO_UTILIZADO = NVL(MTO_UTILIZADO,0)- NVL(r_reten.MONTO,0)
                  WHERE NRO_CUENTA = r_reten.NRO_CUENTA;
                    IF SQL%NOTFOUND THEN
                      raise_application_error(-20000,'No se encontr? cta. de cambios'||r_reten.NRO_CUENTA);
                    END IF;
            END IF;

             --- genera movimiento ---
            v_nro_secuencia       := v_nro_secuencia + 1;
            --sig segundo x si hay mas de 999 reg.
            if v_nro_secuencia >= 999 then
               v_hora := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
               v_nro_secuencia := 1;
            end if;
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_modulo    := r_reten.cod_modulo;
            r_gmovi.cod_modalidad := r_reten.cod_modalidad;
            r_gmovi.cod_oficina   := r_reten.cod_oficina;
            r_gmovi.nro_cuenta    := r_reten.nro_cuenta;
            r_gmovi.cod_moneda    := r_reten.COD_MONEDA;
            r_gmovi.fec_valor     := v_fecha;
            r_gmovi.fecha         := v_fecha;
            r_gmovi.cod_tra_padre   := 515;
            r_gmovi.cod_transaccion := 515;
            r_gmovi.nro_documento := r_reten.nro_boleta;
            r_gmovi.monto         := r_reten.Sal_Retenido;
            r_gmovi.cod_retencion := r_reten.cod_retencion;
            r_gmovi.fec_fin_retencion := r_reten.fec_fin;
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := r_reten.cod_ofi_origen;
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := r_reten.cod_modulo;
            r_gmovi.cod_mad_padre := r_reten.cod_modalidad;
            r_gmovi.concepto      := 'Liberacion de limite de clientes';
            v_lugar:=' Al insertar Mov. ret1';
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
           end;
         END LOOP;


   end if;
exception
  when others then
    raise_application_error(-20000,'Al Lib.Cheque'||r_reten.NRO_CUENTA||'-'||v_lugar||sqlerrm);


END;

/*Inserta la retenci?n de los l?mites de cambios*/
PROCEDURE PR_INS_RET_CAMBIOS
(P_FECHA IN DATE DEFAULT NULL)
IS
  v_fecha date;
begin
insert into lc_retenciones
         (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
          cod_ofi_origen, nro_boleta, cod_retencion, monto,
          fec_inicio, fec_fin, cod_usuario, liberado,
          detallado, cod_moneda, cod_tip_referencia, nro_referencia)
         SELECT
          a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
          a.cod_ofi_origen, a.nro_documento, a.cod_retencion, a.monto,
          a.fecha, nvl(a.fec_fin_retencion,a.fecha+1),a.cod_usuario,'N',
          'S', a.cod_moneda, a.cod_ref_cambio, b.nro_documento2
         FROM  ge_movimientos b, ge_movimientos a
         WHERE a.cod_mod_padre =  7
         AND   a.cod_transaccion = 760
         AND   a.reversado = 'N'
         AND   a.estado = 'N'
         AND   a.monto > 0
         AND   b.cod_usuario = a.cod_usuario
         and   b.fecha = a.fecha
         and   b.hora = a.hora
         and   b.nro_secuencia = 1;
end;

/*Obtiene los cargos de las operaciones de cambios*/
PROCEDURE PR_OBT_CARGOS
( p_cod_transaccion  in number,
  p_cod_modalidad in number,
  p_cod_moneda in varchar2,
  p_importe in number,
  p_imp_equivalente in number,
  p_cod_oficina in number,
  p_nro_cuenta in varchar2,
  p_cod_persona in varchar2,
  p_descripcion  in out varchar2,
  p_mto_cargo in out number,
  p_cod_tasa in out number,
  p_val_tasa in out number)
IS
  v_fec_vigencia  GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
  v_tip_valor     GE_TASAS.TIP_VALOR%TYPE;
  v_tipo          GE_TASAS.TIPO%TYPE;
  v_importe       NUMBER;
  v_redondeo      NUMBER(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local);

  cursor monedas is
         select cod_moneda
           from ba_monedas
          where cod_moneda in (p_cod_moneda, v_cod_mon_fuerte, v_cod_mon_local,'EUR')
           order by decode(cod_moneda,p_cod_moneda,1,v_cod_mon_fuerte,2,'EUR',3,4);
BEGIN
  SELECT DESCRIPCION
    INTO p_descripcion
    FROM GE_TRANSACCIONES
   WHERE GE_TRANSACCIONES.COD_TRANSACCION = p_cod_transaccion
     AND GE_TRANSACCIONES.COD_MODULO = 7
     AND GE_TRANSACCIONES.COD_MODALIDAD = p_cod_modalidad;

  -- VEO SI HAY ALGUNA PARAMETRIZACION DE TASAS PARA LAS MONEDAS
  FOR mn in monedas LOOP
      IF MN.COD_MONEDA = p_cod_moneda  THEN
          v_importe := p_importe;
      ELSIF MN.COD_MONEDA = v_cod_mon_local  THEN
          v_importe := p_imp_equivalente;
      ELSe
        v_IMPORTE:=pal_cam.FU_CON_MON_A_MONEDA(v_cod_mon_local, -- moneda origen local
                                                mn.cod_moneda, -- moneda destino
                                               p_imp_equivalente);
      END IF;

      BEGIN
         p_val_tasa := null;
         pag_gen.pr_obt_val_tasa(7, p_cod_modalidad, p_cod_oficina, p_nro_cuenta,
                                 mn.cod_moneda, v_importe, 'N', p_cod_tasa, p_cod_transaccion,
                                 pae_cnf.fu_obt_fec_actual(7), p_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo, p_cod_persona);
      EXCEPTION
         WHEN OTHERS THEN
           NULL;
      END;

      IF p_val_tasa IS NOT NULL THEN
          p_descripcion := substr(trim(p_descripcion)|| ' ('||mn.cod_moneda||' '|| trim(p_val_tasa)||')',1,60);
         IF v_tip_valor = 'V' THEN
             IF mn.cod_moneda = p_cod_moneda THEN
                p_mto_cargo:= ROUND(p_val_tasa*(p_imp_equivalente/p_importe),v_redondeo);
            ELSIF mn.cod_moneda <> v_cod_mon_local THEN
               p_mto_cargo := pal_cam.FU_CON_MON_A_MONEDA(mn.cod_moneda, -- moneda origen
                                                          v_cod_mon_local, -- moneda destino
                                                          p_val_tasa);
            ELSE
               p_mto_cargo := p_val_Tasa;
            END IF;
         ELSE
            p_descripcion := replace(p_descripcion,')','%)');
            p_mto_cargo := ROUND((p_imp_equivalente*p_val_tasa)/100,v_redondeo);
            --verificar si el monto a cobrar est? limitado x el m?nimo y m?ximo de la tasa
            p_mto_cargo := pag_gen.FU_OBT_VAL_FINAL(p_mto_cargo);
         END IF;
         EXIT;
      END IF;
   END LOOP;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;
  WHEN OTHERS THEN
    raise_application_error(-20000,'Obt.gastos '||p_cod_transaccion||'-'||SQLERRM);
END;

/*Obtiene los impuestos de los cargos de las operaciones de cambios*/
PROCEDURE PR_OBT_IMPUESTOS
  (p_cod_transaccion in number,
   p_cod_modalidad in number,
   p_monto in number,
   p_cod_oficina in number,
   p_tra_impuesto in out number,
   p_impuesto in out number,
   p_cod_tasa in out number,
   p_val_tasa in out number,
   p_cod_moneda in varchar2 default null,
   p_cod_persona in varchar2 default null)
IS
   v_fec_vigencia   ge_tas_fechas.fec_vigencia%type;
   v_tip_valor      ge_tasas.tip_valor%type;
   v_tipo           ge_tasas.tipo%type;
   v_porcen         number(10);
   v_modulo         ge_movimientos.cod_modulo%type;
   v_modalidad      ge_movimientos.cod_modalidad%type;
   v_redondeo number(2); --SC 18760
   v_nro_cuenta     ge_movimientos.nro_cuenta%type;
BEGIN
  -- DYDMR-5780 05/2018 NAF si recibe cod_persona, no utiliza cta generica CTA_CAM_CLI_TEMPORAL
  if p_cod_persona is null then
     v_nro_cuenta := fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,p_cod_oficina);
  else
     v_nro_cuenta := NULL;
  end if;
  if p_cod_moneda is null then
    v_redondeo := 0;
  else
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,p_cod_moneda);
  end if;
-- Recup los impuestos, puede haber un s?lo imp x cargo.
  select cod_mod_hijo, cod_mad_hijo, cod_tra_hijo
    into v_modulo, v_modalidad, p_tra_impuesto
    from ge_transacciones_det
   where cod_modulo = 7
     and cod_modalidad = p_cod_modalidad
     and cod_transaccion = p_cod_transaccion
     and rownum=1;
  --variables para movimientos
  pag_gen.pr_obt_val_tasa(v_modulo,v_modalidad,p_cod_oficina,
    v_nro_cuenta,
    pag_gen.FU_OBT_MON_LOCAL, p_monto, 'N', p_cod_tasa,
    p_tra_impuesto, pae_cnf.fu_obt_fec_actual(7), p_val_tasa, v_fec_vigencia,
    v_tip_valor, v_tipo, p_cod_persona);    ---OUT
  if v_tip_valor = 'V' then
     raise_application_error(-20000,'Impuesto debe ser Porcentaje '||p_tra_impuesto||'-'||p_cod_tasa||'-'||p_val_tasa);
   else
     v_porcen := nvl(p_val_tasa,0) + 100; --- Iva incluido
     p_impuesto:= round(nvl(p_monto,0)* nvl(p_val_tasa,0)/v_porcen,v_redondeo);
     --verificar si el monto a cobrar est? limitado x el m?nimo y m?ximo de la tasa
     p_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_impuesto);
   end if;


exception
  when no_data_found then
    --no tiene impuesto
    null;
  when others then
    raise_application_error(-20000,'Recup Impuesto '||sqlerrm);
END;
-- devuelve el codigo de retencion valido para un tipo de operacion
function FU_OBT_COD_RETENCION(p_cod_tip_operacion in varchar2,
                              p_cod_banco in number)
return number is
v_ubicacion ge_bancos.ubicacion%type;
begin
   select ubicacion
     into v_ubicacion
     from ge_bancos
    where cod_banco = p_cod_banco;
   if v_ubicacion = 'L' then
      return 3;
   else
      return 4;
   end if;
/*
   if p_cod_banco = 999 then
      return 3;
   else
      return 1;
   end if;*/
exception
  when others then
     return 4;
end;
-- proc. para obtener el codigo y fin de retencion
procedure PR_OBT_RETENCION(p_cod_tip_operacion in varchar2,
                           p_cod_banco in number,
                           p_nro_cuenta   in varchar2,
                           p_cod_moneda in varchar2,
                           p_cod_ofi_origen in number,
                           p_cod_retencion out number,
                           p_fec_fin_retencion out date) is
v_can_dia_retencion number(4) := -1;
begin
      -- obtengo el codigo de retencion
     p_cod_retencion := fu_obt_cod_retencion(p_cod_tip_operacion, p_cod_banco);
     If p_cod_moneda is null Then
        raise_application_error(-20000,'Moneda no definida');
     ElsIf p_cod_retencion is null Then
         raise_application_error(-20000,'Retencion no definida');
     elsif p_cod_ofi_origen is null then
         raise_application_error(-20000,'Codigo de Oficina Origen no definida');
     End If;
     -- busco en primer lugar sino tiene retencion personalizada la cuenta
     Begin
        Select can_dia_retencion
          into v_can_dia_retencion
          from GE_RET_CUENTAS
         where NRO_CUENTA = p_nro_cuenta
           and COD_RETENCION = p_cod_retencion;
     Exception
          When NO_DATA_FOUND Then
               v_can_dia_retencion := -1;
     End;
     If v_can_dia_retencion = -1 Then
         -- no tiene retencion personalizada, busco la retencion general
         Select CAN_DIAS
           into v_can_dia_retencion
           from GE_RET_MONEDAS
          where COD_MONEDA = p_cod_moneda
            and COD_RETENCION = p_cod_retencion;
     End If;
     -- obtiene la fecha habil sgte de la retencion
     p_fec_fin_retencion := pag_cal.fu_obt_fec_fin_ret(pag_cal.fu_obt_fec_actual(7),
                                                   p_cod_ofi_origen,
                                                   v_can_dia_retencion);
end;

/* Convertir un monto de una moneda a otra */
FUNCTION FU_CON_MON_A_MONEDA
 (P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_MON_ORIGINAL IN NUMBER
 ,P_COT_MON_ORIGINAL IN NUMBER default null
 )
 RETURN NUMBER
  IS
  v_mto_mon_destino  NUMBER;
  v_lugar varchar2(100);
BEGIN
   v_lugar := 'obtener moneda base';
   v_mto_mon_destino := pag_gen.fu_con_mon_a_moneda(P_COD_MON_ORIGINAL, P_COD_MON_DESTINO, P_MTO_MON_ORIGINAL, P_COT_MON_ORIGINAL);
   return v_mto_mon_destino;
exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
END;

/*Inserta la retenci?n de los l?mites de cambios on line*/
PROCEDURE PR_INS_LC_RETENCIONES
(P_LIMITE IN LC_RETENCIONES%ROWTYPE)
IS
begin
  insert into lc_retenciones
         (cod_modulo, cod_modalidad, cod_oficina,
          nro_cuenta, cod_ofi_origen, nro_boleta,
          cod_retencion, monto, fec_inicio,
          fec_fin, cod_usuario, liberado,
          detallado, cod_moneda, cod_tip_referencia,
          nro_referencia, sal_retenido,cotizacion)
  values(p_limite.cod_modulo, p_limite.cod_modalidad, p_limite.cod_oficina,
          p_limite.nro_cuenta, p_limite.cod_ofi_origen, p_limite.nro_boleta,
          p_limite.cod_retencion, p_limite.monto, p_limite.fec_inicio,
          p_limite.fec_fin, p_limite.cod_usuario, p_limite.liberado,
          p_limite.detallado, p_limite.cod_moneda, p_limite.cod_tip_referencia,
          p_limite.nro_referencia,p_limite.sal_retenido,p_limite.cotizacion);
exception
   when others then
     raise_application_error(-20000,'Ins.Retenciones '||sqlerrm);
end;


/*Liberaci?n de retenci?n de los l?mites de cambios*/
PROCEDURE PR_LIB_RET_CAM_CHEQUES
(
p_nro_cuenta in varchar2,
p_nro_boleta in varchar2,
p_mensaje in out varchar2)
IS
  Cursor che is select 'L' origen,a.nro_boleta nro_documento,a.fec_inicio,a.cod_modulo,
                    a.cod_modalidad,c.cod_moneda,a.cod_oficina,c.cod_retencion,
                    a.nro_cuenta,to_char(c.nro_cheque) nro_cheque,c.cod_banco,
                    c.fecha,c.monto,c.rowid fila_cheque,a.rowid fila_retencion
               from cc_che_enviados c, lc_retenciones a
              where c.nro_boleta = a.nro_boleta
                and c.cod_retencion = a.cod_retencion
                and c.nro_cuenta = a.nro_cuenta
                and a.liberado = 'N'
                and c.liberado = 'N'
                 and ((c.estado not in ('D','I') and c.cod_moneda=pag_gen.FU_OBT_MON_LOCAL())
                    OR (c.estado not in ('D','I','E') and c.cod_moneda=pag_gen.FU_OBT_MON_FUERTE())
                   )
                --and c.lib_posterior = 'S'
                --and c.usu_modificacion = user
                and c.nro_boleta=p_nro_boleta;


  CURSOR ret IS
    SELECT *
    FROM LC_RETENCIONES
    WHERE LIBERADO  = 'N'
    AND nro_boleta=p_nro_boleta
    and nro_cuenta=p_nro_cuenta
    FOR UPDATE OF LIBERADO;


  --se puede liberar anticipadamente el l?mite
  r_reten LC_RETENCIONES%ROWTYPE;
  r_gmovi ge_movimientos%rowtype;
  v_nro_secuencia ge_movimientos.nro_secuencia%type :=0;
  v_hora ge_movimientos.hora%type := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_mon_fuerte          ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
  v_mon_local          ge_movimientos.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
  v_fecha date;
  v_monto number(18,2);
  v_mto_ret number(18,2);
  v_mto_utilizado number(18,2);
  v_sal_retenido number(18,2):=0;
  v_cant_cheque number(3):=0;
  v_cant_che_lib number(3):=0;


BEGIN
    v_fecha := pag_cal.fu_obt_fec_actual(7);

    --raise_application_error(-20000,' Nro.Cuenta: '||p_nro_cuenta||' Nro.Boleta: '||p_nro_boleta);

    for c in che loop
      for r_reten in ret loop
           v_monto:=0;
           v_mto_utilizado:=0;
           --Traemos el monto de la cuentad e Cambios
           BEGIN
            select a.mto_utilizado
              into v_mto_utilizado
              from LC_CTA_CAMBIOS a
             WHERE NRO_CUENTA = r_reten.NRO_CUENTA;
            exception
               when no_data_found then
                 raise_application_error(-20000,'No se encontr? cta. de cambios'||r_reten.NRO_CUENTA);
               when others then
                 raise_application_error(-20000,'Error al Obt.Cta.Cambios(Lib.Ret.Che)'||r_reten.NRO_CUENTA||' ' ||sqlerrm);
            END;
             --Verificamos la moneda del cheque
             if c.cod_moneda <> v_mon_fuerte THEN
                if c.cod_moneda = v_mon_local then
                  --Si es GS se DIVIDE
                  v_monto:= c.monto / r_reten.cotizacion ;
                end if;
             ELSE
                v_monto:= c.monto;
             end if;
             --Verificamos el mto
             v_mto_utilizado:= nvl(v_mto_utilizado,0) - nvl(v_monto,0);
             ---- Actualizamos la Cuenta de Cambios
             UPDATE LC_CTA_CAMBIOS
               SET MTO_UTILIZADO = NVL(v_mto_utilizado,0)
             WHERE NRO_CUENTA = r_reten.NRO_CUENTA;
            -- Restamos la Retencion
              v_mto_ret:=0;
              v_mto_ret:= nvl(r_reten.Sal_Retenido,0) - nvl(v_monto,0);
              if v_mto_ret < 1 then
                 v_mto_ret:=0;
              end if;
            --Si es Cero, ya se libera la retenci?n
            if v_mto_ret= 0  then
               UPDATE LC_RETENCIONES a
                  SET a.LIBERADO = 'S',
                   a.sal_retenido=v_mto_ret
                WHERE CURRENT OF ret;
            else
                UPDATE LC_RETENCIONES a
                  SET a.sal_retenido= v_mto_ret
                 WHERE CURRENT OF ret;
            end if;
            -- Liberamos el Cheque
            begin
               UPDATE cc_che_enviados a
                  SET a.LIBERADO = 'S'--,
                  --a.estado='L'
                  where a.nro_cheque= c.nro_cheque
                  and  a.nro_cuenta=c.nro_cuenta;
            exception
              when others then
               raise_application_error(-20000,'Error al Lib.Cheque(Lib.Ret.Che)'||c.NRO_CHEQUE||' ' ||sqlerrm);
            end;
            --- genera movimiento ---
            v_nro_secuencia       := v_nro_secuencia + 1;
            --sig segundo x si hay mas de 999 reg.
            if v_nro_secuencia >= 999 then
               v_hora := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);
               v_nro_secuencia := 1;
            end if;
            r_gmovi.cod_usuario   := user;
            r_gmovi.hora          := v_hora;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_modulo    := r_reten.cod_modulo;
            r_gmovi.cod_modalidad := r_reten.cod_modalidad;
            r_gmovi.cod_oficina   := r_reten.cod_oficina;
            r_gmovi.nro_cuenta    := r_reten.nro_cuenta;
            r_gmovi.cod_moneda    := r_reten.COD_MONEDA;
            r_gmovi.fec_valor     := v_fecha;
            r_gmovi.fecha         := v_fecha;
            r_gmovi.cod_tra_padre   := 515;
            r_gmovi.cod_transaccion := 515;
            r_gmovi.nro_documento := r_reten.nro_boleta;
            r_gmovi.monto         := v_monto;--c.monto;--r_reten.monto;
            r_gmovi.cod_retencion := r_reten.cod_retencion;
            r_gmovi.fec_fin_retencion := r_reten.fec_fin;
            r_gmovi.estado        := 'N';
            r_gmovi.cod_ofi_origen := r_reten.cod_ofi_origen;
            r_gmovi.reversado     := 'N';
            r_gmovi.emi_aviso     := 'N';
            r_gmovi.protegido     := 'N';
            r_gmovi.cod_mod_padre := r_reten.cod_modulo;
            r_gmovi.cod_mad_padre := r_reten.cod_modalidad;
            r_gmovi.concepto      := 'Liberacion de limite de clientes';
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
     END LOOP;
  END LOOP;
  --Buscamos si por redondeo nomas no liber? la retencion
  v_cant_cheque:=0;
  v_cant_che_lib:=0;
  v_sal_retenido:=0;

  begin
    select a.sal_retenido
     into v_sal_retenido
     from lc_retenciones a
      where a.nro_boleta=p_nro_boleta
        and a.nro_cuenta= p_nro_cuenta
        and liberado='N';

  exception
     when no_data_found then
        v_sal_retenido:=0;
     when too_many_rows then
        v_sal_retenido:=0;
     when others then
        v_sal_retenido:=0;
  end;
  --Solo si aun tiene saldo retenido hacemos las verificaciones
  IF NVL(v_sal_retenido,0) > 0 THEN
      --Contamos si tiene Cheques No Liberados
      begin
      select count(*)
        into v_cant_cheque
          from cc_che_enviados a
      where
           a.nro_boleta=p_nro_boleta;
      exception
       when others then
         v_cant_cheque:=0;
      end;
       --Contamos cantidad de Cheques Liberados
      begin
      select count(*)
        into v_cant_che_lib
          from cc_che_enviados a
      where
           a.nro_boleta=p_nro_boleta
           and a.liberado='S';
      exception
       when others then
         v_cant_che_lib:=99;
      end;
      --Si tiene aun monto Retenido y ya liber? todos los Cheques
      --Solo es por redondeo de Monedas
      if nvl(v_sal_retenido,0)> 0 and v_cant_cheque= v_cant_che_lib  then
         --Actualizamos lc_retenciones
         update lc_retenciones  a
          set a.sal_retenido= nvl(a.sal_retenido,0)-nvl(v_sal_retenido,0),
              a.liberado='S'
          where a.nro_boleta=p_nro_boleta
            and a.nro_cuenta= p_nro_cuenta
            and liberado='N';
           --Actualizamos Cuenta de Cambios,
           --es em dolares como la retenci?n por lo que se resta directo
           UPDATE LC_CTA_CAMBIOS
               SET MTO_UTILIZADO = NVL(mto_utilizado,0)- nvl(v_sal_retenido,0)
             WHERE NRO_CUENTA = p_nro_cuenta;
      end if;
  END IF;


END;

/*genera el movimiento y actualizacion de saldo de una cuenta y muestra coomo salida el mensaje y codigo error*/
PROCEDURE PR_ACT_OPERACION_CON_SALIDA
     (P_FECHA     IN GE_MOVIMIENTOS.FECHA%TYPE DEFAULT NULL
     ,P_HORA      IN GE_MOVIMIENTOS.HORA%TYPE  DEFAULT NULL
     ,P_USUARIO   IN GE_MOVIMIENTOS.COD_USUARIO%TYPE DEFAULT NULL
     ,P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
     ,P_TIP_MOVIMIENTO IN VARCHAR2
     ,P_COD_MONEDA IN GE_MOVIMIENTOS.COD_MONEDA%TYPE
     ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
     ,P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
     ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
     ,P_REFERENCIA IN GE_MOVIMIENTOS.REFERENCIA%TYPE
     ,P_COTIZACION IN GE_MOVIMIENTOS.COTIZACION%TYPE
     ,P_COD_MOD_PADRE IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE
     ,P_COD_MAD_PADRE IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE
     ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
     ,P_NRO_SECUENCIA IN GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
     ,P_MTO_EQU_LOCAL IN GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE DEFAULT NULL
     ,P_NRO_DOCUMENTO IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE DEFAULT NULL
     ,P_COD_ERROR     OUT NUMBER
     ,P_MSG_ERROR     OUT VARCHAR2
     ,P_RES_FECHA     OUT GE_MOVIMIENTOS.FECHA%TYPE
     ,P_RES_HORA      OUT GE_MOVIMIENTOS.HORA%TYPE
     ,P_RES_SECUENCIA OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
     ,P_RES_USUARIO   OUT GE_MOVIMIENTOS.COD_USUARIO%TYPE
     ,P_RES_NRO_DOCUMENTO OUT GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE) IS
     
     v_hora  GE_MOVIMIENTOS.HORA%TYPE ;
     v_fecha            DATE;
     v_usuario          VARCHAR2(10);
     v_cod_oficina      NUMBER := 61;
     v_ind_usuario      NUMBER;
     v_nro_min_usuarios NUMBER;
     v_nro_max_usuarios NUMBER;
     v_can_usuarios     NUMBER;
     v_est_modulo       BA_MODULOS.ESTADO%TYPE;
     v_nro_secuencia    GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE := P_NRO_SECUENCIA;
    
     e_salir EXCEPTION;
 
 BEGIN
 
     -- Inicializamos la aplicación
     PRE_INI_APLICACION;
     PAE_CNF.G_COD_MODULO := 1;



     -- Obtenemos la fecha actual
     IF P_FECHA IS NULL THEN
        v_fecha := PAG_CAL.FU_OBT_FEC_ACTUAL(P_COD_MOD_PADRE);
     ELSE
        v_fecha := P_FECHA;
     END IF;

     -- Obtenemos el estado actual del modulo
     v_est_modulo := PAE_CNF.FU_OBT_EST_MODULO(P_COD_MOD_PADRE);

     -- Comprobamos el estado actual o lanzamos un error
     IF (FUG_OBT_PARDINAMICO('ACT_NOCTURNO') = 'N' OR v_est_modulo IN (1, 6)) THEN
        RAISE_APPLICATION_ERROR(-20999, 'Modulo en proceso de cierre');
     END IF;

     -- Si el modulo esta en estado 2 
     IF (v_est_modulo = 2) THEN
        PAG_CTA.G_HORARIO := 'D';
     ELSE
        PAG_CTA.G_HORARIO := 'N';
        -- Si el horario actual es nocturno debemos obtener la nueva fecha
        v_fecha := PAG_CAL.FU_OBT_FEC_HABIL(v_fecha + 1, 1, v_cod_oficina);
     END IF;

     -- Obtenemos el usuario rotativo para el movimiento
     v_nro_min_usuarios := NVL(FUG_OBT_PARDINAMICO('CEXCHANGE_CAN_MIN_USU'), 0);
     v_nro_max_usuarios := NVL(FUG_OBT_PARDINAMICO('CEXCHANGE_CAN_MAX_USU'), 9);
     v_ind_usuario      := ROUND(DBMS_RANDOM.value(v_nro_min_usuarios, v_nro_max_usuarios));
     
     IF P_USUARIO IS NULL THEN
         IF (v_ind_usuario > 0) THEN
            v_usuario := 'CEXCHANGE' || v_ind_usuario;
         ELSE
            v_usuario := 'CEXCHANGE';
         END IF;

         SELECT COUNT(*)
          INTO v_can_usuarios
          FROM BA_USUARIOS
         WHERE COD_USUARIO = v_usuario;

         IF (v_can_usuarios = 0) THEN
            RAISE_APPLICATION_ERROR(-20999, 'El usuario ' || v_usuario || ' no se encuentra registrado');
         END IF;

         -- Obtenemos la hora actual para el movimiento
         v_hora := FUW_OBT_MOV_HORA('S_HOR_MOV_' || v_usuario);
    ELSE
        v_usuario := P_USUARIO;
        v_hora    := P_HORA;
    END IF;
 
     -- Inicializamos al procedimiento SET_VARIABLES del PAG_CTA para inicializar el movimiento a insertar
     PAG_CTA.PR_SET_VARIABLES(
        v_usuario,
        v_fecha,
        P_COD_TRA_PADRE,
        'N',
        'N',
        v_nro_secuencia,
        NULL,
        v_cod_oficina,
        P_COD_MOD_PADRE,
        P_COD_MAD_PADRE
     );
    
    IF P_NRO_DOCUMENTO IS NULL THEN 
        BEGIN
          P_RES_NRO_DOCUMENTO := fug_obt_lla_pardinamico('NRO_RECIBO', P_COD_MOD_PADRE, P_COD_MAD_PADRE, 'USD', v_cod_oficina) + 1;
          PRG_ACT_PAR_DINAMICO (P_PARAMETRO       => 'NRO_RECIBO',
                                 P_COD_MODULO      => P_COD_MOD_PADRE,
                                 P_COD_MODALIDAD   => P_COD_MAD_PADRE,
                                 P_COD_MONEDA      => 'USD',
                                 P_COD_OFICINA     => v_cod_oficina,
                                 P_VALOR           => P_RES_NRO_DOCUMENTO);
        EXCEPTION
         WHEN OTHERS THEN
            P_MSG_ERROR:= 'Error: Generando el numero de recibo'     ; 
            P_COD_ERROR:= 999;   
            raise e_salir; 
        END;
    ELSE
        P_RES_NRO_DOCUMENTO := P_NRO_DOCUMENTO;
    END IF;
     
    pag_cta.pr_set_referencia (P_REFERENCIA); -- A utilizar para id Mongo

    -- Proceso que realiza el validacion, movimientos y actualizacion de Saldos de la cuenta
    pag_cta.pr_act_operacion    (p_nro_cuenta        => P_NRO_CUENTA,
                                 p_hora              => v_hora,
                                 p_tip_movimiento    => P_TIP_MOVIMIENTO,
                                 p_cod_moneda        => P_COD_MONEDA,
                                 p_monto             => P_MONTO,
                                 p_cod_tra_padre     => P_COD_TRA_PADRE,
                                 p_cod_transaccion   => P_COD_TRANSACCION,
                                 p_nro_documento     => P_RES_NRO_DOCUMENTO,
                                 p_cotizacion        => P_COTIZACION,
                                 p_cod_ofi_origen    => v_cod_oficina,
                                 p_cod_mod_padre     => P_COD_MOD_PADRE,
                                 p_cod_mad_padre     => P_COD_MAD_PADRE,
                                 p_cod_tasa          => null,
                                 p_val_tasa          => null,
                                 p_concepto          => P_CONCEPTO,
                                 p_emi_aviso         => 'N',
                                 p_nro_secuencia     => v_nro_secuencia,
                                 p_fec_valor         => v_fecha,
                                 p_cod_banco         => null,
                                 p_cod_causa         => null,
                                 p_mto_equ_local     => P_MTO_EQU_LOCAL,
                                 p_estado            => null);
                                 
        
    P_COD_ERROR := pag_cta.fu_obt_cod_error ;
    P_MSG_ERROR := pag_cta.fu_obt_msj_error ;
    
    P_RES_FECHA     := v_fecha;
    P_RES_HORA      := v_hora; 
    P_RES_SECUENCIA := v_nro_secuencia; 
    P_RES_USUARIO   := v_usuario ; 
    
    
    
    IF P_COD_ERROR <> 0 THEN
        raise e_salir; 
    END IF;
   
EXCEPTION
   WHEN  e_salir THEN
         ROLLBACK;                        
   WHEN OTHERS THEN
        P_MSG_ERROR:= SQLERRM     ; 
        P_COD_ERROR:= 999;  
        ROLLBACK;                              
 END;
 
end PAL_CAM;
/

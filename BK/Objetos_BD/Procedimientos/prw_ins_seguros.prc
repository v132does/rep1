create or replace procedure it.PRW_INS_SEGUROS(p_cod_persona in varchar2,
                                            p_nro_cta_debito in varchar2,
                                            p_mto_capital in number,
                                            p_mto_cuota in number,
                                            p_cod_canal in number,
                                            p_cod_tip_seguro in number,
                                            p_cod_ente in number,
                                            p_nro_seguro out number,
                                            p_error out number,
                                            p_nom_beneficiario in varchar2 default null,
                                            p_nro_doc_beneficiario in varchar2 default null,
                                            p_nro_renovacion in ge_ren_pol_seguros.nro_renovacion%type default 0,
                                            p_origen varchar2 default 'W',
                                            p_nro_poliza_madre in varchar2 default null) is
  v_nro_seguro      ge_cli_seguros.nro_seguro%type;
  v_fec_inicio      date := pae_cnf.FU_OBT_FEC_ACTUAL(1);
  v_retorno         number;
  v_dat_seguro      pag_pre.tp_datosSeguro;
  v_procesar        varchar2(1) := 'S';
  v_cod_tra_padre   ge_transacciones.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_SEGUROS');--nueva transaccion
  v_sal_disponible  ge_cuentas.sal_contable%type;
  v_nvo_estado      ge_cuentas.estado%type;
  v_cod_mod_deb     ge_cuentas.cod_modulo%type;
  v_cod_mad_deb     ge_cuentas.cod_modalidad%type;
  v_cod_ofi_deb     ge_cuentas.cod_oficina%type;
  v_cod_mon_deb     ge_cuentas.cod_moneda%type;
  v_nro_documento   ge_movimientos.nro_documento%type;
  v_nro_secuencia   ge_movimientos.nro_secuencia%type default 0;
  v_cod_ofi_origen  ge_movimientos.cod_ofi_origen%type;
  v_mto_cargo       ge_movimientos.monto%type;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
  v_val_tas_impuesto ge_movimientos.val_tasa%type;
  v_mto_impuesto     ge_movimientos.monto%type;
  r_gmovi           ge_movimientos%rowtype;
  v_iva             number(3,1) := 1.1;
  v_mto_capital     ge_cli_seguros.mto_capital%type;
  v_mto_cuota       ge_cuo_seguros.monto%type;
  v_cod_tip_seguro  ge_tip_seguros.cod_tipo%type;
  v_cod_canal       ge_tip_seguros.cod_canal%type;
  v_cod_ente        ge_tip_seguros.cod_ente%type;
  v_cod_usuario ba_usuarios.cod_usuario%type;
  v_nom_beneficiario ge_cli_seguros.beneficiario%type;
  v_nro_doc_beneficiario ge_cli_seguros.nro_doc_beneficiario%type;
  v_cod_pol_madre  ge_cli_seguros.nro_poliza_madre%type;
  v_cod_error       number;
  v_msj_error       varchar2(1000);
  COD_SEG_INVALIDO EXCEPTION;
  -- PCCDEEVO-214 06/2017.
  v_can_cuotas     number;
  v_can_dias       number;
  v_fec_ven_seg_ori ge_pol_seguros.fec_final%type;
  v_nro_seg_ori     ge_pol_seguros.codigo%type;
  v_est_modulo     ba_modulos.estado%TYPE := pae_cnf.FU_OBT_EST_MODULO(3);
  v_es_nocturno    VARCHAR2(1);
  v_horario        varchar2(1) default 'D';
  v_hora            ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');  
  v_fec_actual      date default pag_cal.fu_obt_fec_actual(1);
begin

  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

   IF v_est_modulo = 2 THEN -- El modulo está abierto
     v_es_nocturno := 'N';
     v_horario     := 'D';
   ELSE
     v_fec_actual := pag_cal.FU_OBT_FEC_PROXIMA(3);
     v_es_nocturno := 'S';
     v_horario     := 'N' ; 
   END IF;

  --DYDMR-5803--Modificado por rpavon 03.01.17--
  --Agregado para evaluacion correcta de usuario si proviene de ATM--
  v_cod_usuario := user;
  
  v_retorno := pag_pre.fu_tie_seguro(p_cod_persona,v_dat_seguro);
  -- Obtener datos cta débito
  begin
    select a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda
      into v_cod_mod_deb, v_cod_mad_deb, v_cod_ofi_deb, v_cod_mon_deb
      from ge_cuentas a
     where a.nro_cuenta = p_nro_cta_debito;
  exception
    when no_data_found then
      v_cod_mod_deb := null;
      v_cod_mad_deb := null;
      v_cod_ofi_deb := null;
      v_cod_mon_deb := null;
    when others then
      v_cod_mod_deb := null;
      v_cod_mad_deb := null;
      v_cod_ofi_deb := null;
      v_cod_mon_deb := null;
  end;
  --verificar cuenta para pagar la primera cuota
  BEGIN
    v_mto_capital    := p_mto_capital;
    v_mto_cuota      := p_mto_cuota;
    v_cod_canal      := p_cod_canal;
    v_cod_tip_seguro := p_cod_tip_seguro;
    v_cod_ente       := p_cod_ente;
    v_cod_pol_madre  := p_nro_poliza_madre;

    IF v_cod_tip_seguro in (2,4,5) THEN
       v_cod_tra_padre  := fug_obt_pardinamico('COD_TRA_SEGUROS_WEB');
    ELSIF v_cod_tip_seguro = 3 THEN
       v_cod_tra_padre  := fug_obt_pardinamico('COD_TRA_SEG_VIDA');
    ELSE
       RAISE COD_SEG_INVALIDO ;
    END IF;

    v_nom_beneficiario := p_nom_beneficiario;
    v_nro_doc_beneficiario := p_nro_doc_beneficiario;
  EXCEPTION
        WHEN COD_SEG_INVALIDO THEN
          RAISE_APPLICATION_ERROR(-99,SQLERRM||' - No existe el código de seguro');
  END;

  BEGIN
    select val_maximo
      into v_can_cuotas
      from ba_cod_referencias
     where dominio = 'CAN_CUO_SEGUROS'
       and val_minimo = v_cod_tip_seguro;
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        select val_maximo
          into v_can_cuotas
          from ba_cod_referencias
         where dominio = 'CAN_CUO_SEGUROS'
           and val_minimo = 0;
      EXCEPTION
        WHEN OTHERS THEN
          v_can_cuotas := 12;
      END;
  END;
  
  if  nvl(p_nro_renovacion, 0) = 0 and p_cod_tip_seguro  in ( 2, 3) then
    pag_cta.pr_ver_operacion(p_nro_cta_debito,
                               v_cod_tra_padre,
                               v_cod_mod_deb,
                               v_cod_mad_deb,
                               'D',
                               v_cod_mon_deb,
                               v_mto_cuota,
                               v_cod_ofi_deb,
                               -- out
                               pag_cta.g_ctas.cod_modulo,
                               pag_cta.g_ctas.cod_modalidad,
                               v_nvo_estado,
                               v_sal_disponible,
                               v_procesar,
                               503);
      v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,v_cod_usuario,v_es_nocturno);
      v_cod_error := pag_cta.g_cod_error;
      v_msj_error := pag_cta.G_MSJ_ERROR;
      p_error     := v_cod_error;

  else
     v_cod_error := 0;
     v_procesar := 'S';
  end if;
  
  if p_cod_tip_seguro in ( 2, 3) then
    if v_cod_error = 0 or v_procesar = 'S' then
      v_can_dias := round((365 * v_can_cuotas)/12);
      
      if v_dat_seguro.codigoSeguro is not null or p_cod_canal is not null then
         begin
           select s_nro_seguro.nextval
             into v_nro_seguro
             from dual;
         end;
         begin
           select r.nro_seg_ant
             into v_nro_seg_ori
             from ge_ren_pol_seguros r
            where r.nro_renovacion = p_nro_renovacion;
         exception
           when others then
              v_nro_seg_ori := 0;
         end;
         begin
           select nvl(p.fec_final, v_fec_inicio)
             into v_fec_ven_seg_ori
             from ge_pol_seguros p
            where codigo = v_nro_seg_ori;
         exception
           when others then
             v_fec_ven_seg_ori := v_fec_inicio;
         end;
         v_fec_inicio := PAG_CAL.FU_OBT_FEC_SIG_HAB(v_fec_ven_seg_ori, 1);
       end if;
       
       if nvl(p_nro_renovacion, 0) = 0 then
         v_fec_inicio := v_fec_actual;
       end if;
             --  end
       begin
         insert into ge_cli_seguros
                     (cod_persona, nro_seguro, cod_tip_seguro, mto_capital,
                      can_cuo_pagadas, cod_ente, fec_inicio, fec_vencimiento,
                      nro_cta_debito,estado, cod_canal,beneficiario, nro_doc_beneficiario,nro_poliza_madre)
          values (p_cod_persona, v_nro_seguro, v_cod_tip_seguro, v_mto_capital,
                  0, v_cod_ente, v_fec_inicio,v_fec_inicio+v_can_dias, p_nro_cta_debito,
                  'V', v_cod_canal, v_nom_beneficiario, v_nro_doc_beneficiario,v_cod_pol_madre);
       exception
         when others then
            null;
       end;
       
       for i in 1..v_can_cuotas loop
          begin
            insert into ge_cuo_seguros (nro_seguro, nro_cuota, monto, estado, fec_vencimiento)
                  values(v_nro_seguro, i, v_mto_cuota, 'V', add_months(v_fec_inicio,i));
          exception
            when others then
               null;
          end;
       end loop;
       if p_origen <> 'C' then -- Formulario Call
          update ge_ren_pol_seguros
             set nro_seguro = v_nro_seguro,
                 estado = 'P',
                 fec_confirmacion = v_fec_actual
           where nro_renovacion = p_nro_renovacion;
       end if;
       if v_procesar = 'S' then 
          if nvl(p_nro_renovacion, 0) = 0 then
            if v_nro_secuencia > 990 then
               v_nro_secuencia := 1;
               v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,v_cod_usuario,v_es_nocturno);
            end if;

            v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);

            --Setear variables para cargar usuario correcto--
            PAG_CTA.PR_SET_VARIABLES(v_cod_usuario,
                                     v_fec_actual,
                                     v_cod_tra_padre,
                                     'N',-- estado
                                     'N',-- reversado
                                     v_nro_secuencia,
                                     null,
                                     v_cod_ofi_origen,
                                     v_cod_mod_deb,
                                     v_cod_mad_deb);

            -- Actualiza el horario del pag_cta según estado del modulo -- PCCDEEVO-214 abr/2017
            pag_cta.g_horario := v_horario;
               
            --Actualizar el Saldo cta débito--
            pag_cta.pr_act_operacion(p_nro_cta_debito,
                                     v_hora,
                                     'D',
                                     pag_cta.g_ctas.cod_moneda,
                                     v_mto_cuota,
                                     v_cod_tra_padre,
                                     503,
                                     v_nro_documento,          --nro documento
                                     null,
                                     fug_obt_ofi_usuario(v_cod_usuario), --cod_ofi_origen
                                     v_cod_mod_deb,             --cod_mod_padre
                                     v_cod_mad_deb,             --cod_mad_padre
                                     null,                      --cod_tasa
                                     null,                      --val_tasa
                                     substr('DÉBITO POR COBRO DE SEGURO.',1,99) ,
                                     'S',                       --emi_aviso
                                     v_nro_secuencia,
                                     v_fec_actual);
             v_mto_cargo        := null;
             v_cod_tra_impuesto := null;
             v_cod_tas_impuesto := null;
             v_mto_impuesto     := null;
             v_val_tas_impuesto := null;
             
             --calcular impuesto
             prg_obt_car_impuesto(v_cod_ofi_origen, p_nro_cta_debito, v_cod_mon_deb, v_cod_mod_deb, v_cod_mad_deb,
                                  v_cod_tra_padre, v_mto_cargo, v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto, v_mto_impuesto);
                                  v_mto_impuesto := nvl(v_mto_impuesto,0);
             if v_mto_impuesto = 0 then
                v_mto_cargo := round(v_mto_cuota / v_iva);
                v_mto_impuesto := round((round(v_mto_cargo*v_val_tas_impuesto))/100);
             end if;
                
             --Insertar el Movimiento Por el Cargo
             r_gmovi.cod_usuario     := substr(v_cod_usuario,1,10);
             r_gmovi.hora            := v_hora;
             r_gmovi.fecha           := v_fec_actual;
             -- Aumento la secuencia
             v_nro_secuencia         := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia   := v_nro_secuencia;
             --
             r_gmovi.cod_modulo      := v_cod_mod_deb;
             r_gmovi.cod_modalidad   := v_cod_mad_deb;
             r_gmovi.cod_oficina     := v_cod_ofi_origen;
             r_gmovi.nro_cuenta      := p_nro_cta_debito;
             r_gmovi.cod_moneda      := v_cod_mon_deb;
             r_gmovi.fec_valor       := v_fec_actual;
             r_gmovi.cod_tra_padre   := v_cod_tra_padre;--nvl(reg.cod_tra_padre,150);
             r_gmovi.cod_mod_padre   := v_cod_mod_deb;--nvl(reg.cod_mod_padre,3);
             r_gmovi.cod_mad_padre   := v_cod_mad_deb;--nvl(reg.cod_mad_padre,31);
             r_gmovi.cod_transaccion := v_cod_tra_padre;
             r_gmovi.monto           := v_mto_cargo;
             r_gmovi.nro_documento   := v_nro_documento;
             r_gmovi.nro_documento2  := null;
             r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
             r_gmovi.emi_aviso       := 'N';
             r_gmovi.concepto        := 'DÉBITO POR COBRO DE SEGURO.';
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             r_gmovi.cod_rubro       := null;
             r_gmovi.cod_tasa        := null;
             r_gmovi.val_tasa        := null;
             r_gmovi.tip_mov_rubro   := null;

             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);

             --Insertar el Movimiento Por el Impuesto
             r_gmovi.cod_usuario     := substr(v_cod_usuario,1,10);
             r_gmovi.hora            := v_hora;
             r_gmovi.fecha           := v_fec_actual;
             -- Aumento la secuencia
             v_nro_secuencia         := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia   := v_nro_secuencia;
             --
             r_gmovi.cod_modulo      := v_cod_mod_deb;
             r_gmovi.cod_modalidad   := v_cod_mad_deb;
             r_gmovi.cod_oficina     := v_cod_ofi_origen;
             r_gmovi.nro_cuenta      := p_nro_cta_debito;
             r_gmovi.cod_moneda      := v_cod_mon_deb;
             r_gmovi.fec_valor       := v_fec_actual;
             r_gmovi.cod_tra_padre   := v_cod_tra_padre;--nvl(reg.cod_tra_padre,150);
             r_gmovi.cod_mod_padre   := v_cod_mod_deb;--nvl(reg.cod_mod_padre,3);
             r_gmovi.cod_mad_padre   := v_cod_mad_deb;--nvl(reg.cod_mad_padre,31);
             r_gmovi.cod_transaccion := v_cod_tra_impuesto;
             r_gmovi.monto           := v_mto_impuesto;
             r_gmovi.nro_documento   := v_nro_documento;
             r_gmovi.nro_documento2  := null;
             r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
             r_gmovi.emi_aviso       := 'N';
             r_gmovi.concepto        := 'DÉBITO POR COBRO DE SEGURO.';
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             r_gmovi.cod_rubro       := null;
             r_gmovi.cod_tasa        := v_cod_tas_impuesto;
             r_gmovi.val_tasa        := v_val_tas_impuesto;
             r_gmovi.tip_mov_rubro   := null;

             pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
             if pag_cta.fu_obt_cod_error() = 0 then
                insert into ge_cob_seguros a
                  (nro_seguro, nro_cuota, monto, fecha, hora, fec_vencimiento, estado)
                values
                  (v_nro_seguro, 1, v_mto_cuota, v_fec_actual, v_hora, add_months(v_fec_inicio,1),'P');
                   p_nro_seguro := v_nro_seguro;
                   p_error      := v_cod_error;
             end if;
         else
           p_nro_seguro := v_nro_seguro;
         end if;
      else
        p_error := 99;
      end if;
    end if;    
    if p_error <> 0 then
    insert into ge_seg_mensajes_tmp
      (cod_seg_error_msg, descripcion, cod_persona, cod_seguro, fec_insercion)
    values
      (p_error, v_msj_error, p_cod_persona, p_nro_seguro, sysdate);  
    end if;  
  else
    if nvl(p_nro_renovacion, 0) <> 0 and p_origen <> 'C' then -- Formulario Call
       update ge_ren_pol_seguros
          set estado = 'P',
              fec_confirmacion = v_fec_actual
        where nro_renovacion = p_nro_renovacion;
     end if;
  end if;

end PRW_INS_SEGUROS;
/


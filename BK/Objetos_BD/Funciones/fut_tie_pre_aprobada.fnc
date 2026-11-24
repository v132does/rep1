create or replace function it.fut_tie_pre_aprobada( p_cod_persona  ba_personas.cod_persona%type,
                                                 p_cod_moneda   ba_monedas.cod_moneda%type default null,
                                                 p_nro_cuenta   ge_cta_clientes.nro_cuenta%type default null,
                                                 p_cod_producto varchar2 default null)

return varchar2 is
  v_lin_aprobada ge_cli_aprobados_atm_tmp.lin_aprobada%type;
  v_afinidad     ge_cli_aprobados_atm_tmp.afinidad%type;
  v_sub_afinidad ge_cli_aprobados_atm_tmp.clase%type;
  v_significado  varchar2(100);
  v_respuesta    varchar2(400):= 'N';
  v_indice       number(4);
  v_char         varchar2(2) := 'N ';
  v_resp         varchar2(320);
  ----para prestamos
  v_evento            varchar2(2);
  v_sal_min_vigente   pr_parametros.sal_min_vigente%type;
  v_can_sal_min_atm   number;
  v_cod_oficina       ge_pro_pre_aprobados.cod_oficina%type;
  v_retorno           number;
  v_can_tarjetas      number;
  v_datos             pag_pre.tp_datosCuota;
  v_cod_modalidad     ge_cta_clientes.cod_modalidad%type;
  v_linea             varchar2(100);
  v_usuario           varchar2(10) := user;
  v_dat_seguro        pag_pre.tp_datosSeguro;
  v_fecha             date := sysdate; --pae_cnf.FU_OBT_FEC_ACTUAL(1);
  v_est_modulo        ba_modulos.estado%type;
  v_pri_oferta        varchar2(50);--ge_ofe_pre_aprobados.oferta%type;
  v_nro_telefono      varchar2(12);

  cursor c_prioridad is
    select a.val_maximo,a.val_minimo
      from ba_cod_referencias a
     where a.dominio = 'PRI_ROT_OFE_ATM'
     order by a.val_maximo;

  FUNCTION lf_obt_sal_min_vigente RETURN pr_parametros.sal_min_vigente%type IS
    v_result pr_parametros.sal_min_vigente%type;
    BEGIN
      select sal_min_vigente
        into v_result
        from pr_parametros
        where rownum = 1;
      RETURN v_result;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 0; -- Ante algun error se opta por no ofrecer el Pre-Aprobado
    END;
  --
  --Verifica si el cliente no tiene alguna solicitud de tarjeta en curso o cuenta tarjeta activa
  PROCEDURE lp_ver_tar_activas
    (p_cod_persona  in varchar2,
     p_sub_afinidad out varchar2,
     p_afinidad     out varchar2,
     p_lin_aprobada out number,
     p_significado  out varchar2,
     p_cantidad     out number)
    is
    v_afinidad      ta_cta_tarjetas.afinidad%type;
    v_sub_afinidad  ta_cta_tarjetas.sub_afinidad%type;
    v_cod_modalidad ta_cta_tarjetas.cod_modalidad%type;
    v_retorno       number;
    v_cod_moneda    ba_monedas.cod_moneda%type;
    begin

      v_retorno := pag_pre.fu_tie_tar_aprobada(p_cod_persona,
                                               p_lin_aprobada,
                                               v_afinidad, --p_afinidad,
                                               v_sub_afinidad, --p_sub_afinidad,
                                               v_cod_moneda);

      pag_pre.pr_obt_tar_afinidad(v_sub_afinidad,
                                  v_afinidad,
                                  p_afinidad,
                                  p_sub_afinidad,
                                  p_significado);
      if p_afinidad is null then
         p_cantidad := 1;
      end if;

      v_cod_modalidad := pag_pre.fu_obt_mad_tarjeta(p_afinidad, p_sub_afinidad);

      if v_cod_modalidad is null then
         p_cantidad := 1;
      end if;
      if v_retorno = -1 then
        p_cantidad := 1;
      else
        SELECT COUNT(*)
          INTO p_cantidad
          FROM ta_solicitudes
         WHERE cod_persona = p_cod_persona
           AND cod_modalidad = v_cod_modalidad
           AND afinidad = p_afinidad
           AND nvl(sub_afinidad, 'ZZ') = nvl(p_sub_afinidad, 'ZZ')
           AND cod_estado <> 'RCH';

        if p_cantidad = 0 then
          SELECT COUNT(*)
            INTO p_cantidad
            FROM ta_cta_tarjetas c, ta_tarjetas t
           WHERE t.cod_persona = p_cod_persona
             AND t.cod_estado <> 10
             AND c.nro_cuenta = t.nro_cuenta
             AND c.cod_modalidad = v_cod_modalidad
             AND c.afinidad = p_afinidad
             AND nvl(c.sub_afinidad, 'ZZ') = nvl(p_sub_afinidad, 'ZZ');
        end if;
      end if;
    end;

  function lf_ver_tel_actualizado(p_cod_persona varchar2)
    return varchar2 is
    v_existe varchar2(1);
    begin
      select 'N'
        into v_existe
        from ba_dat_atm a
       where a.cod_persona = p_cod_persona
         and a.actualizado = 'S'
         and trunc(sysdate)- a.fecha > fug_obt_pardinamico('PLZ_DIAS')
      union
      select 'S'
        from ba_dat_atm a
       where a.cod_persona = p_cod_persona
         and a.actualizado = 'S'
         and trunc(sysdate)- a.fecha <= fug_obt_pardinamico('PLZ_DIAS');
      return v_existe;
    exception
      when no_data_found then
        v_existe := 'N';
        return v_existe;
      when too_many_rows then
        v_existe := 'S';
        return v_existe;
      when others then
        v_existe := 'N';
        return v_existe;
    end;

  function lf_ver_act_celular(p_cod_persona varchar2, p_nro_telefono out varchar2)
    return varchar2 is
    v_existe varchar2(1);
    begin
      select 'S', a.tel_area||a.tel_numero
        into v_existe,p_nro_telefono
        from ba_act_dat_clientes a
       where a.estado = 'P'
         and a.tel_tip_linea = 'C'
         and a.tip_solicitud = 'C'
         and a.cod_persona = p_cod_persona;
         return v_existe;
    exception
      when no_data_found then
        v_existe := 'N';
        return v_existe;
      when too_many_rows then
        v_existe := 'S';
        return v_existe;
      when others then
        v_existe := 'N';
        return v_existe;
    end;

  procedure lp_act_prioridad
    (p_cod_persona varchar2,
     v_oferta      varchar2,
     v_fec_oferta  date) is
    v_existe    varchar2(1) := 'N';
    v_prioridad ge_ofe_pre_aprobados.oferta%type;

    begin
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
     if substr(v_usuario,1,3) = 'ATM' then --debe ser atm
      select a.oferta
        into v_prioridad
        from GE_OFE_PRE_APROBADOS a
       where a.cod_persona = p_cod_persona;
       if v_oferta is not null then
          if v_prioridad = 5 then
             v_prioridad := 1;
          else
             v_prioridad := v_prioridad + 1;
          end if;
          update ge_ofe_pre_aprobados a
             set a.FEC_ULT_OFERTA = nvl(v_fec_oferta,a.fec_ult_oferta),
                 a.oferta = v_prioridad
           where a.cod_persona = p_cod_persona;
       end if;
      end if;
    exception
      when no_data_found then
        insert into ge_ofe_pre_aprobados(cod_persona, oferta, fec_ult_oferta)
        values (p_cod_persona, v_oferta, v_fecha);
        --v_oferta = 1;
        --v_fec_oferta := v_fecha;
    end;

  procedure lp_ver_prioridad
    (p_cod_persona varchar2,
     v_prioridad   in out varchar2) is
    v_oferta ge_ofe_pre_aprobados.oferta%type;
    begin
      select a.oferta
        into v_oferta
        from ge_ofe_pre_aprobados a
       where a.cod_persona = p_cod_persona;
       if v_oferta is not null then
         if v_oferta = 5 then
           v_prioridad := 1;
         else
           v_prioridad := v_oferta + 1;
         end if;
       end if;
    exception
      when no_data_found then
        v_prioridad := nvl(v_prioridad,0)+1;
    end;

begin
  for c in c_prioridad loop
  --verifica parametro mis productos
    if nvl(trim(p_cod_producto),'0') = '0' then
       lp_ver_prioridad(p_cod_persona,v_pri_oferta);
    else
       v_pri_oferta := fue_obt_val_max_refcodes('COD_MIS_PRODUCTOS',p_cod_producto);
    end if;
    
    --lp_ver_prioridad(p_cod_persona,c.val_maximo,v_fecha);
    if fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_ACT_DATOS') = c.val_maximo and v_pri_oferta = c.val_maximo then
      if lf_ver_act_celular(p_cod_persona, v_nro_telefono) = 'S' then
         v_respuesta := '08'||fug_obt_pardinamico('MSJ_ATM_MOD_CEL');
         v_respuesta := rpad(rpad(v_respuesta,282,' ')||'N Nro. Telefono: '||v_nro_telefono,320,' ');
         v_evento    := '#I';
         v_respuesta := v_respuesta||v_evento;
         lp_act_prioridad(p_cod_persona,c.val_maximo,v_fecha);
         exit;
      else
         v_respuesta := 'N';
         lp_act_prioridad(p_cod_persona,c.val_maximo,null);
      end if;
      if v_respuesta = 'N' and nvl(trim(p_cod_producto),'0') != '0' then
           v_respuesta := fug_obt_pardinamico('MSJ_ATM_DES_MEN');
      end if;
    elsif fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_PRESTAMOS') = c.val_maximo and v_pri_oferta = c.val_maximo then
      --else
        v_retorno := pag_pre.fu_tie_pre_aprobado(p_cod_persona, 6, 68, 'S', v_datos /*v_monto, v_min_monto, v_max_plazo, v_min_plazo, v_max_cuota*/);

        begin
          select distinct(a.cod_modalidad)
            into v_cod_modalidad
            from ge_cta_clientes a
           where a.cod_persona = p_cod_persona
             and a.nro_cuenta = p_nro_cuenta;
        exception
          when no_data_found then
            null;
        end;
        --- controles previos --
  if nvl(v_datos.montoMaximo,0) > 0 and (pag_pre.fu_es_cta_nomina(p_cod_persona,p_nro_cuenta,v_cod_modalidad) = 'S' or p_nro_cuenta is null or nvl(fug_obt_pardinamico('VAL_CLI_NOM_PRE_APR'),'N') = 'N') then
      if fug_ver_pue_des_preaprob(p_nro_cuenta) = 'S' then
          if p_cod_moneda = 'GS' then -- Solo para Cuentas en Guaranies -- PCCOPPAA-9 - Pre-Aprobados ATM
            -- Validar cantidad máxima cantidad de salario minimo permitido en atm
            -- Si el monto del pre-aprobado es mayor a la cantidad de salarios mínimos definida se opta por no ofrecer por ATM
            v_sal_min_vigente   := lf_obt_sal_min_vigente;
            v_can_sal_min_atm   := to_number(fug_obt_pardinamico('MAX_CAN_SAL_MIN_PRE_APR_ATM'));
            if nvl(v_sal_min_vigente,0)>0 and nvl(v_can_sal_min_atm,0)>0 then
              if v_datos.montoMaximo <= round((v_sal_min_vigente*v_can_sal_min_atm)) then
                v_cod_oficina := FUG_OBT_OFI_OFICIAL(p_cod_persona);
                if fut_val_req_pre_aprobados(p_cod_persona)
                  -- Se debe validar que la persona este verificada...
                  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 09/2016 -- Se quita la validación --
                   /* and fug_obt_pardinamico('VER_PERSONA', 6, 68, p_cod_moneda, v_cod_oficina) = 'S'
                    and fug_ver_verificacion(p_cod_persona) = 'S'*/ then
                    v_linea     := ' Tenes un prestamo aprobado ';
                    v_respuesta := v_respuesta || rpad(v_linea,39,' ');
                    v_linea     := 'N Desde '||trim(to_char(v_datos.montoMinimo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
                    v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                    v_linea     := 'N Hasta '||trim(to_char(v_datos.montoMaximo,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
                    v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                    v_linea     := 'N Hasta en '||v_datos.plazoMaximo||' meses de plazo.';
                    v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                    v_linea     := 'N ¿Queres obtenerlo? ';
                    v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                    v_linea     := 'N ';
                    v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                    v_linea     := 'N ';
                    v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                    v_linea     := 'N ';
                    v_respuesta := '08'||v_respuesta || rpad(v_linea,38,' ')||'#F';
                  v_evento := '#F';
                  lp_act_prioridad(p_cod_persona,c.val_maximo,v_fecha);
                  exit;
                else
                  v_respuesta := 'N';
                  lp_act_prioridad(p_cod_persona,c.val_maximo,null);
                end if;
              else
                v_respuesta := 'N';
                lp_act_prioridad(p_cod_persona,c.val_maximo,null);
              end if;
            else
              v_respuesta := 'N';
              lp_act_prioridad(p_cod_persona,c.val_maximo,null);
            end if;
          else
            v_respuesta := 'N';
            lp_act_prioridad(p_cod_persona,c.val_maximo,null);
          end if;
         end if;
        else
          lp_act_prioridad(p_cod_persona,c.val_maximo,null);
        end if;
        if v_respuesta = 'N' and nvl(trim(p_cod_producto),'0') != '0' then
           --Cliente interesado generar caso en crm
           v_respuesta := fug_obt_pardinamico('MSJ_NO_PRE_APR');
           prg_gen_crm_lead(p_cod_persona,'1',28,6,68,null,null,v_datos.montoMaximo,null,v_pri_oferta);
        end if;
    elsif fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_TARJETAS') = c.val_maximo and v_pri_oferta = c.val_maximo then
      --if v_retorno <= 0 then
           lp_ver_tar_activas(p_cod_persona, v_sub_afinidad, v_afinidad, v_lin_aprobada, v_significado, v_can_tarjetas);

            if v_can_tarjetas = 0 then
               /*if lf_ver_tel_actualizado(p_cod_persona) = 'N' and substr(v_usuario,1,3) = 'ATM' then
                  v_respuesta := '08'||fug_obt_pardinamico('MSJ_ATM');
                  v_evento    := '#S';
               else*/
                if v_afinidad is not null then
                  /*v_respuesta := 'Ud. tiene una tarjeta '||v_significado||' Pre-Aprobada. Linea Crédito: '||
                                  trim(to_char(v_lin_aprobada,
                                   '99G999G999G990',
                                   'NLS_NUMERIC_CHARACTERS = ''.,'''))||'. ¿Desea solicitarla?';*/
                  v_linea     := ' Tenes una tarjeta preaprobada';
                  v_respuesta := v_respuesta || rpad(v_linea,39,' ');
                  v_linea     := 'N '||v_significado;--afinidad;
                  v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                  v_linea     := 'N con linea de credito';
                  v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                  v_linea     := 'N '||trim(to_char(v_lin_aprobada,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''));
                  v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                  v_linea     := 'N ¿Queres Obtenerla?';
                  v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                  v_linea     := 'N ';
                  v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                  v_linea     := 'N ';
                  v_respuesta := v_respuesta || rpad(v_linea,40,' ');
                  v_linea     := 'N ';
                  v_respuesta := '08'||v_respuesta || rpad(v_linea,38,' ')||'#D';
                  v_evento := '#D';
                  lp_act_prioridad(p_cod_persona,c.val_maximo,v_fecha);
                  exit;
                else
                  v_respuesta := 'N';
                  lp_act_prioridad(p_cod_persona,c.val_maximo,null);
                end if;
               --end if;
            else
              v_respuesta := 'N';
              lp_act_prioridad(p_cod_persona,c.val_maximo,null);
            end if;
        --end if;
        if v_respuesta = 'N' and nvl(trim(p_cod_producto),'0') != '0' then
           --Cliente interesado generar caso en crm
           v_respuesta := fug_obt_pardinamico('MSJ_NO_PRE_APR');
           prg_gen_crm_lead(p_cod_persona,'1',28,5,null,null,null,v_datos.montoMaximo,null,v_pri_oferta);
        end if;
    elsif fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_ACT_TELEFONOS') = c.val_maximo and v_pri_oferta = c.val_maximo then
       if substr(v_usuario,1,3) = 'ATM' then
          if nvl(trim(p_cod_producto),'0') != '0' or lf_ver_tel_actualizado(p_cod_persona) = 'N' then
            v_respuesta := '08'||fug_obt_pardinamico('MSJ_ATM');
            v_evento    := '#S';
            lp_act_prioridad(p_cod_persona,c.val_maximo,v_fecha);
          end if;
          exit;
       else
          v_respuesta := 'N';
          lp_act_prioridad(p_cod_persona,c.val_maximo,null);
       end if;
    elsif fue_obt_val_max_refcodes('PRI_ROT_OFE_ATM','ATM_SEGUROS') = c.val_maximo and v_pri_oferta = c.val_maximo then
        --verificar ofrecimiento seguro
        if v_respuesta = 'N' and p_cod_moneda = 'GS' then
           v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
           if v_est_modulo not in (1, 6) Then -- PCCDEEVO-214 06/2017
             v_retorno := pag_pre.fu_tie_seguro(p_cod_persona,v_dat_seguro);
             if v_dat_seguro.texto is not null then
                v_respuesta := v_dat_seguro.texto;
                v_evento    := '#E';
                lp_act_prioridad(p_cod_persona,c.val_maximo,v_fecha);
                exit;
             else
                v_respuesta := 'N';
                lp_act_prioridad(p_cod_persona,c.val_maximo,null);
             end if;
           else
             v_respuesta := 'N';
             lp_act_prioridad(p_cod_persona,c.val_maximo,null);
           end if;
        else
          v_respuesta := 'N';
          lp_act_prioridad(p_cod_persona,c.val_maximo,null);
        end if;
        if v_respuesta = 'N' and nvl(trim(p_cod_producto),'0') != '0' then
           --Cliente interesado generar caso en crm
           v_respuesta := fug_obt_pardinamico('MSJ_NO_PRE_APR');
           prg_gen_crm_lead(p_cod_persona,'1',28,null,null,null,null,v_datos.montoMaximo,null,v_pri_oferta);
        end if;
    end if;
  --
  end loop;
  --para armar el envio de mensaje
    if nvl(v_respuesta,'N') != 'N' and v_evento in ('#E') /*not in ('#F','#S','#I','#D')*/ then
        if length(v_respuesta) > 318 then
          v_respuesta := substr(v_respuesta,1,318);
        end if;

        v_indice := 1;

        for i in 1..8--v_lineas
          loop
            if i = 8 then
              v_resp := v_resp||v_char||substr(rpad(v_respuesta,318,' '),v_indice,36);
            else
              v_resp := v_resp||v_char||substr(rpad(v_respuesta,318,' '),v_indice,38);
              v_indice := v_indice + 38;
            end if;
          end loop;
        v_respuesta := '08'||v_resp||v_evento;
    end if;
  return(v_respuesta);

end fut_tie_pre_aprobada;
/


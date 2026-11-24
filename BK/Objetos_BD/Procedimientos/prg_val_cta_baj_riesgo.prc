create or replace procedure it.prg_val_cta_baj_riesgo(p_cuenta          in ge_cuentas.nro_cuenta%type,
                                                      p_moneda          in ge_cuentas.cod_moneda%type,
                                                      p_cod_modulo      in ge_cuentas.cod_modulo%type,
                                                      p_cod_modalidad   in ge_cuentas.cod_modalidad%type,
                                                      p_monto           in ge_movimientos.monto%type,
                                                      p_cod_error       out number,
                                                      p_mensaje         out varchar2) is

  v_anho                   number := to_number(to_char(SYSDATE, 'yyyy'));

  v_mes                    number := to_number(to_char(SYSDATE, 'mm'));

  v_per_principal          ba_personas.cod_persona%type;
  v_can_doc_req_cliente    number := 0;
  v_can_doc_requeridos     number := 0;
  v_respuesta              varchar2(1);
  v_mto_lim_cta_baj_riesgo number(18, 2) := 0;
  v_mto_lim_cred_cta       number(18, 2) := 0;
  v_sal_acu_mes            number(18, 2);
  v_sal_acu_diario         number(18, 2);
  v_moneda                 ge_cuentas.cod_moneda%type;
  v_cod_modulo             ge_cuentas.cod_modulo%type;
  v_cod_modalidad          ge_cuentas.cod_modalidad%type;
  v_cod_sub_modalidad      ge_cuentas.cod_sub_modalidad%type;
  v_es_cue_mipyme          boolean;
  v_sal_noc_acu_diario     number(18, 2);
  v_sal_excluido           number(18, 2);-- Monto de transacciones excluidas en el mes

begin
    p_cod_error := 0;
    begin
      select c.cod_moneda, c.cod_modalidad, c.cod_modulo, c.cod_sub_modalidad
        into v_moneda, v_cod_modalidad, v_cod_modulo, v_cod_sub_modalidad
        from ge_cuentas c
       where nro_cuenta = p_cuenta;
    exception
      when no_data_found then
        p_cod_error := 6;
        p_mensaje   := 'Cuenta no existe ' || p_cuenta;
      when others then
        p_cod_error := 6;
        p_mensaje   := sqlerrm;
    end;
    v_moneda        := nvl(p_moneda, v_moneda);
    v_cod_modulo    := nvl(p_cod_modulo, v_cod_modulo);
    v_cod_modalidad := nvl(p_cod_modalidad, v_cod_modalidad);
    --control solo si es credito

    v_es_cue_mipyme := (v_cod_modulo = 3 and v_cod_modalidad = 334 and v_cod_sub_modalidad = 2);

    v_mto_lim_cta_baj_riesgo := to_number(nvl(fug_obt_pardinamico('MAD_LIM_TRANSACCIONAL',
                                                                  v_cod_modulo,
                                                                  v_cod_modalidad,
                                                                  v_moneda),
                                              '0')); --Limite por modalidad
    v_mto_lim_cred_cta       := to_number(nvl(fug_obt_paradicional(p_cuenta,
                                                                   'LIM_CRE_TRANSACCIONES'),
                                              '0')); --Limite por cuenta

    v_per_principal := fug_obt_cli_principal(p_cuenta);

    if nvl(fug_obt_paradicional(p_cuenta, 'BLO_CTA_BAJ_RIESGO'), 'N') = 'S' then
      p_cod_error := 5;
      p_mensaje   := 'La cuenta se encuentra con bloqueo de creditos';
    end if;
    if nvl(p_cod_error, 0) = 0 then
      /* Controlar que el limite transaccional actual de la cuenta cliente no supere el limite transaccional configurado para la modalidad
      este caso podría darse cuando el cliente solicita aumento de LT de su cuenta, se realiza la modificación y se encuentra pendiente el cambio de modalidad  */
     
     -- CÁLCULO DE SALDO EXCLUIDO POR TRANSACCIONES PARAMETRIZADAS EN EL MES ACTUAL
     -- Este monto se restará del acumulado mensual para no contabilizar transacciones excluidas
     -- en el cálculo de límites (ej: reintegros, devoluciones, etc.)
     begin
       select nvl(sum(m.monto), 0)
         into v_sal_excluido
         from ah_movimientos_his m
        where m.nro_cuenta = p_cuenta
          and nvl(m.reversado, 'N') = 'N'
          and m.cod_moneda = v_moneda
          and nvl(m.monto, 0) != 0
          and fec_insercion >= trunc(sysdate, 'MM')  -- Solo del mes actual
          and exists
        (select 1
                 from ge_par_tra_excluidas a
                where m.cod_tra_padre = a.cod_tra_padre
                  and m.cod_mod_padre = a.cod_mod_padre
                  and m.cod_mad_padre = a.cod_mad_padre
                  and m.cod_transaccion = a.cod_transaccion);
     exception
       when no_data_found then
         v_sal_excluido := 0;
       when others then
         v_sal_excluido := 0;
     end; 
    
     /*mensual*/
      begin
        select nvl(sum(a.tot_creditos), 0)
          into v_sal_acu_mes
          from ah_sal_mensuales a
         where a.nro_cuenta = p_cuenta
           and a.ano = v_anho
           and a.mes = v_mes;
      exception
        when no_data_found then
          v_sal_acu_mes := 0;
        when others then
          v_sal_acu_mes := 0;
      end;
      
      -- Restar las transacciones excluidas del acumulado mensual
      -- Esto permite que transacciones como reintegros no impacten en el límite
      v_sal_acu_mes := v_sal_acu_mes - v_sal_excluido;

      /*diario*/

      begin
        select nvl(sum(m.monto), 0)
          into v_sal_acu_diario
          from ge_movimientos m, ge_transacciones t
         where m.nro_cuenta = p_cuenta
           and m.cod_transaccion = t.cod_transaccion
           and m.cod_modulo = t.cod_modulo
           and m.cod_modalidad = t.cod_modalidad
           and nvl(m.reversado, 'N') = 'N'
           and m.cod_moneda = v_moneda
           and nvl(m.monto, 0) != 0
           and t.tipo = 'C'
           and not exists (  -- Excluir transacciones parametrizadas
               select 1
               from  ge_par_tra_excluidas a
               where m.cod_tra_padre = a.cod_tra_padre
                 and m.cod_mod_padre = a.cod_mod_padre
                 and m.cod_mad_padre = a.cod_mad_padre
                 and m.cod_transaccion = a.cod_transaccion);
      exception
        when no_data_found then
          v_sal_acu_diario := 0;
        when others then
          v_sal_acu_diario := 0;
      end;
      
      /*nocturno*/

      begin
        select nvl(sum(m.monto), 0)
          into v_sal_noc_acu_diario
          from ge_movimientos_noc m, ge_transacciones t
         where m.nro_cuenta = p_cuenta
           and m.cod_transaccion = t.cod_transaccion
           and m.cod_modulo = t.cod_modulo
           and m.cod_modalidad = t.cod_modalidad
           and nvl(m.reversado, 'N') = 'N'
           and m.cod_moneda = v_moneda
           and nvl(m.monto, 0) != 0
           and t.tipo = 'C'
           and not exists (  -- Excluir transacciones parametrizadas
               select 1
               from  ge_par_tra_excluidas a
               where m.cod_tra_padre = a.cod_tra_padre
                 and m.cod_mod_padre = a.cod_mod_padre
                 and m.cod_mad_padre = a.cod_mad_padre
                 and m.cod_transaccion = a.cod_transaccion);
      exception
        when no_data_found then
          v_sal_acu_diario := 0;
        when others then
          v_sal_acu_diario := 0;
      end;
      
      -- Validacion de Monedas.
      if p_moneda <> pag_gen.FU_OBT_MON_LOCAL then
        begin
          v_mto_lim_cta_baj_riesgo := pag_gen.FU_CON_MON_A_MONEDA(pag_gen.FU_OBT_MON_LOCAL,
                                                                  v_moneda,
                                                                  v_mto_lim_cta_baj_riesgo);
          v_mto_lim_cred_cta       := pag_gen.FU_CON_MON_A_MONEDA(pag_gen.FU_OBT_MON_LOCAL,
                                                                  v_moneda,
                                                                  v_mto_lim_cred_cta);
        exception
          when others then
            v_mto_lim_cta_baj_riesgo := 0;
        end;
      end if;

      begin
        select count(b.val_minimo)
          into v_can_doc_requeridos
          from ba_cod_referencias b
         where b.dominio = 'DOC_REQ_LIM_TRN_BAJORIESGO'
           and b.activo = 'S';
      exception
        when no_data_found then
          v_can_doc_requeridos := 0;
      end;

      begin
        select count(cod_tip_documento)
          into v_can_doc_req_cliente
          from (select i.cod_persona,
                       i.est_doc,
                       i.nro_referencia,
                       i.cod_tip_documento,
                       i.url_crear,
                       i.cod_id_crear
                  from ba_cod_referencias b, ba_per_ima_documentos i
                 where b.dominio = 'DOC_REQ_LIM_TRN_BAJORIESGO'
                   and b.activo = 'S'
                   and i.cod_tip_documento = b.val_minimo
                   and i.cod_persona = v_per_principal
                   and i.nro_referencia =
                       (SELECT max(b.nro_referencia)
                          FROM ba_per_ima_documentos b
                         WHERE b.cod_persona = i.cod_persona
                           and b.cod_tip_documento = i.cod_tip_documento))
         where url_crear is not null
           and cod_id_crear is not null;
      exception
        when no_data_found then
          v_can_doc_req_cliente := 0;
        when too_many_rows then
          v_can_doc_req_cliente := 1;
      end;

      if nvl(v_mto_lim_cred_cta, 0) <= nvl(v_mto_lim_cta_baj_riesgo, 0) then
        -- Control de Limite de Cuenta Basica por operación.

        if NVL(p_monto, 0) + nvl(v_sal_acu_mes, 0) +
           nvl(v_sal_acu_diario, 0) + nvl(v_sal_noc_acu_diario, 0) > nvl(v_mto_lim_cred_cta, 0) then
          /* El sistema controla si el cliente cuenta con todos los documentos requeridos en estado A (Aprobado) en la tabla ba_per_ima_documentos*/

          if v_es_cue_mipyme then
            p_cod_error := 7;
            p_mensaje   := 'Monto acreditado supera el limite de cuenta mipyme';

          else
            if nvl(v_can_doc_req_cliente, 0) < nvl(v_can_doc_requeridos, 0) then

              v_respuesta := it.fug_env_mai_cta_baj_riesgo(v_per_principal);
              p_cod_error := 1;
              p_mensaje   := 'El Cliente no cuenta con todos los documentos requeridos ' ||
                            p_monto || ' - ' || v_sal_acu_mes || ' - ' ||
                            v_sal_acu_diario || ' - ' ||
                            nvl(v_mto_lim_cta_baj_riesgo, 0);
              prg_ins_log_programas('PRG_VAL_CTA_BAJ_RIESGO',
                                    substr(p_mensaje || ' Monto ' || p_monto ||
                                          ' Limite de cta ' ||
                                          v_mto_lim_cred_cta ||
                                          ' Limite de modalidad ' ||
                                          v_mto_lim_cta_baj_riesgo ||
                                          ' Cant.documentos cliente ' ||
                                          v_can_doc_req_cliente ||
                                          ' Cant doc requeridos ' ||
                                          v_can_doc_requeridos ||
                                          ' Suma mensual ' || v_sal_acu_mes ||
                                          ' Suma diaria ' ||
                                          v_sal_acu_diario,
                                          1,
                                          4000),
                                    v_per_principal,
                                    p_cuenta);
            else
              if NVL(p_monto, 0) + nvl(v_sal_acu_mes, 0) +
                nvl(v_sal_acu_diario, 0) + nvl(v_sal_noc_acu_diario, 0) > nvl(v_mto_lim_cta_baj_riesgo, 0) 
                and USER <> fue_obt_des_refcodes('USU_CIERRE',USER) then
                p_cod_error         := 2;
                p_mensaje           := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ';
                pag_cta.G_COD_ERROR := 41;
                pag_cta.G_MSJ_ERROR := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ' ||
                                      pag_cta.G_COD_ERROR || ' ..';
                prg_ins_log_programas('PRG_VAL_CTA_BAJ_RIESGO',
                                      substr(p_mensaje || ' Monto ' ||
                                            p_monto || ' Limite de cta ' ||
                                            v_mto_lim_cred_cta ||
                                            ' Limite de modalidad ' ||
                                            v_mto_lim_cta_baj_riesgo ||
                                            ' Cant.documentos cliente ' ||
                                            v_can_doc_req_cliente ||
                                            ' Cant doc requeridos ' ||
                                            v_can_doc_requeridos ||
                                            ' Suma mensual ' ||
                                            v_sal_acu_mes || ' Suma diaria ' ||
                                            v_sal_acu_diario,
                                            1,
                                            4000),
                                      v_per_principal,
                                      p_cuenta);
              end if;
            end if;
          end if;
        end if;

      else
        if nvl(v_can_doc_req_cliente, 0) = nvl(v_can_doc_requeridos, 0) then
          if NVL(p_monto, 0) + nvl(v_sal_acu_mes, 0) +
             nvl(v_sal_acu_diario, 0) + nvl(v_sal_noc_acu_diario, 0) > nvl(v_mto_lim_cta_baj_riesgo, 0) then
            p_cod_error := 3;
            p_mensaje   := 'Aumento de limite transaccional pendiente';
          end if;
        else
          p_cod_error := 4;
          p_mensaje   := 'Aumento de limite transaccional pendiente';
        end if;
      end if;
    end if;
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
       nvl(p_cod_error, 0) != 0 then
      prg_ins_log_programas('PRG_VAL_CTA_BAJ_RIESGO',
                            substr(p_mensaje || ' Monto ' || p_monto ||
                                   ' Limite de cta ' || v_mto_lim_cred_cta ||
                                   ' Limite de modalidad ' ||
                                   v_mto_lim_cta_baj_riesgo ||
                                   ' Cant.documentos cliente ' ||
                                   v_can_doc_req_cliente ||
                                   ' Cant doc requeridos ' ||
                                   v_can_doc_requeridos || ' Suma mensual ' ||
                                   v_sal_acu_mes || ' Suma diaria ' ||
                                   v_sal_acu_diario,
                                   1,
                                   4000),
                            v_per_principal,
                            p_cuenta);
    end if;
end prg_val_cta_baj_riesgo;
/

create or replace procedure it.prg_val_tra_cta_baj_riesgo(p_cuenta          in ge_cuentas.nro_cuenta%type,
                                                          p_moneda          in ge_cuentas.cod_moneda%type,
                                                          p_cod_modulo      in ge_cuentas.cod_modulo%type,
                                                          p_cod_modalidad   in ge_cuentas.cod_modalidad%type,
                                                          p_monto           in ge_movimientos.monto%type,
                                                          p_cod_tra_padre   in ge_movimientos.cod_tra_padre%type,
                                                          p_cod_mod_padre   in ge_movimientos.cod_mod_padre%type,
                                                          p_cod_mad_padre   in ge_movimientos.cod_mad_padre%type,
                                                          p_cod_transaccion in ge_movimientos.cod_transaccion%type,
                                                          p_cod_error       out number,
                                                          p_mensaje         out varchar2) is
/*
 * Propósito: Validar transacciones de crédito en cuentas marcadas como "bajo riesgo"
 * 
 * Este procedimiento es ulizado específicamente
 * por movements-api, permitiendo implementar lógica de exclusión de transacciones sin impactar
 * la operatoria general del banco.
 */

  -- Variables para control de fechas
  v_anho                   number := to_number(to_char(SYSDATE, 'yyyy'));
  v_mes                    number := to_number(to_char(SYSDATE, 'mm'));

  -- Variables para control de cliente y documentación
  v_per_principal          ba_personas.cod_persona%type;  -- Código del cliente principal de la cuenta
  v_can_doc_req_cliente    number := 0;                   -- Cantidad de documentos que tiene el cliente
  v_can_doc_requeridos     number := 0;                   -- Cantidad de documentos requeridos por normativa
  
  -- Variables para control de límites transaccionales
  v_mto_lim_cta_baj_riesgo number(18, 2) := 0;           -- Límite configurado para modalidad bajo riesgo
  v_mto_lim_cred_cta       number(18, 2) := 0;           -- Límite específico de la cuenta
  v_sal_acu_mes            number(18, 2);                 -- Acumulado de créditos del mes actual
  v_sal_acu_diario         number(18, 2);                 -- Acumulado de créditos del día actual
  
  -- Variables para datos de la cuenta
  v_moneda                 ge_cuentas.cod_moneda%type;    -- Moneda de la cuenta
  v_cod_modulo             ge_cuentas.cod_modulo%type;    -- Módulo de la cuenta
  v_cod_modalidad          ge_cuentas.cod_modalidad%type; -- Modalidad de la cuenta
  
  -- Variables para control de transacciones excluidas
  v_sal_excluido           number(18, 2);                 -- Monto de transacciones excluidas en el mes
  v_tra_exc_actual         varchar2(1);                   -- Flag que indica si la transacción actual está excluida 

  v_cod_sub_modalidad      ge_cuentas.cod_sub_modalidad%type;
  v_es_cue_mipyme          boolean;
  
  v_sal_noc_acu_diario     number(18, 2); -- Acumulado de créditos de la tabla nocturna

begin
    -- Inicialización del código de error
    p_cod_error := 0;
    
    -- ========================================
    -- OBTENCIÓN DE DATOS BÁSICOS DE LA CUENTA
    -- ========================================
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
    -- Usar parámetros pasados o los obtenidos de la cuenta
    v_moneda        := nvl(p_moneda, v_moneda);
    v_cod_modulo    := nvl(p_cod_modulo, v_cod_modulo);
    v_cod_modalidad := nvl(p_cod_modalidad, v_cod_modalidad);
    
    -- =====================================
    -- OBTENCIÓN DE LÍMITES TRANSACCIONALES
    -- =====================================
    -- Obtener límite configurado para la modalidad (parámetro dinámico)
    v_mto_lim_cta_baj_riesgo := to_number(nvl(fug_obt_pardinamico('MAD_LIM_TRANSACCIONAL',
                                                                  v_cod_modulo,
                                                                  v_cod_modalidad,
                                                                  v_moneda,
                                                                  null,
                                                                  v_cod_sub_modalidad),
                                              '0'));
    
    -- Obtener límite específico de la cuenta (parámetro adicional)
    v_mto_lim_cred_cta       := to_number(nvl(fug_obt_paradicional(p_cuenta,
                                                                   'LIM_CRE_TRANSACCIONES'),
                                              '0'));

    -- Obtener el código del cliente principal de la cuenta
    v_per_principal := fug_obt_cli_principal(p_cuenta);

    v_es_cue_mipyme := (v_cod_modulo = 3 and v_cod_modalidad = 334 and v_cod_sub_modalidad = 2);

    -- =======================================
    -- VALIDACIÓN DE BLOQUEO DE LA CUENTA
    -- =======================================
    if nvl(fug_obt_paradicional(p_cuenta, 'BLO_CTA_BAJ_RIESGO'), 'N') = 'S' then
      p_cod_error := 5;
      p_mensaje   := 'La cuenta se encuentra con bloqueo de creditos';
    end if;
    
    -- =====================================================
    -- VERIFICACIÓN DE TRANSACCIONES EXCLUIDAS
    -- =====================================================
    -- Determinar si la transacción actual está en la tabla de transacciones excluidas
    -- Estas transacciones no deben ser controladas por límites bajo riesgo
    -- (ej: reintegros por beneficios, devoluciones, etc.)
    begin
        select 'S'
        into v_tra_exc_actual
        from ge_par_tra_excluidas a
        where a.cod_tra_padre   = p_cod_tra_padre
          and a.cod_mod_padre   = p_cod_mod_padre
          and a.cod_mad_padre   = p_cod_mad_padre
          and a.cod_transaccion = p_cod_transaccion
          and a.cod_modulo = v_cod_modulo
          and a.cod_modalidad = v_cod_modalidad
          and a.cod_sub_modalidad = v_cod_sub_modalidad
          and rownum = 1;
    exception
        when no_data_found then
            v_tra_exc_actual := 'N';
        when others then
            p_cod_error := 99;
            p_mensaje   := 'Error al verificar transacciones excluidas: ' || sqlerrm;
            return;
    end;
    
    if nvl(p_cod_error, 0) = 0 then
      -- ================================================
      -- CÁLCULO DE ACUMULADOS Y TRANSACCIONES EXCLUIDAS
      -- ================================================
      -- Controlar que el limite transaccional actual de la cuenta cliente no supere el limite transaccional configurado para la modalidad
      -- Este caso podría darse cuando el cliente solicita aumento de LT de su cuenta, se realiza la modificación y se encuentra pendiente el cambio de modalidad

     -- Cálculo de saldo excluido por transacciones parametrizadas en el mes actual
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
          and m.fec_insercion >= trunc(sysdate, 'MM')  -- Solo del mes actual
          and exists
        (select 1
                 from ge_par_tra_excluidas a
                where m.cod_tra_padre = a.cod_tra_padre
                  and m.cod_mod_padre = a.cod_mod_padre
                  and m.cod_mad_padre = a.cod_mad_padre
                  and m.cod_transaccion = a.cod_transaccion
                  and a.cod_modulo = v_cod_modulo
                  and a.cod_modalidad = v_cod_modalidad
                  and a.cod_sub_modalidad = v_cod_sub_modalidad);
     exception
       when no_data_found then
         v_sal_excluido := 0;
       when others then
         v_sal_excluido := 0;
     end;

      -- ===============================
      -- CÁLCULO DE ACUMULADO MENSUAL
      -- ===============================
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

      -- ==============================
      -- CÁLCULO DE ACUMULADO DIARIO
      -- ==============================
      -- Obtener la suma de créditos del día actual, excluyendo transacciones parametrizadas
      -- Solo se consideran transacciones de tipo 'C' (crédito) que no estén en la tabla de excluidas
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
           and t.tipo = 'C'  -- Solo transacciones de crédito
           and not exists (  -- Excluir transacciones parametrizadas
               select 1
               from  ge_par_tra_excluidas a
               where m.cod_tra_padre = a.cod_tra_padre
                 and m.cod_mod_padre = a.cod_mod_padre
                 and m.cod_mad_padre = a.cod_mad_padre
                 and m.cod_transaccion = a.cod_transaccion
                 and a.cod_modulo = v_cod_modulo
                 and a.cod_modalidad = v_cod_modalidad
                 and a.cod_sub_modalidad = v_cod_sub_modalidad);
      exception
        when no_data_found then
          v_sal_acu_diario := 0;
        when others then
          v_sal_acu_diario := 0;
      end;
     -- ==============================
      -- CÁLCULO DE ACUMULADO NOCTURNO
      -- ==============================
      -- Obtener la suma de créditos del nocturno, excluyendo transacciones parametrizadas
      -- Solo se consideran transacciones de tipo 'C' (crédito) que no estén en la tabla de excluidas
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
           and t.tipo = 'C'  -- Solo transacciones de crédito
           and not exists (  -- Excluir transacciones parametrizadas
               select 1
               from  ge_par_tra_excluidas a
               where m.cod_tra_padre = a.cod_tra_padre
                 and m.cod_mod_padre = a.cod_mod_padre
                 and m.cod_mad_padre = a.cod_mad_padre
                 and m.cod_transaccion = a.cod_transaccion
                 and a.cod_modulo = v_cod_modulo
                 and a.cod_modalidad = v_cod_modalidad
                 and a.cod_sub_modalidad = v_cod_sub_modalidad);
      exception
        when no_data_found then
          v_sal_acu_diario := 0;
        when others then
          v_sal_acu_diario := 0;
      end;

      -- ==============================
      -- CONVERSIÓN DE MONEDAS
      -- ==============================
      -- Si la moneda de la transacción no es la moneda local, convertir los límites
      -- para comparar en la misma moneda
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

      -- =====================================
      -- VALIDACIÓN DE DOCUMENTACIÓN
      -- =====================================
      -- Obtener cantidad total de documentos requeridos según normativa
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

      -- Obtener cantidad de documentos que el cliente tiene subidos y aprobados
      -- Solo se cuentan documentos con url_crear y cod_id_crear (completos)
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
                       (SELECT max(b.nro_referencia)  -- Última versión del documento
                          FROM ba_per_ima_documentos b
                         WHERE b.cod_persona = i.cod_persona
                           and b.cod_tip_documento = i.cod_tip_documento))
         where url_crear is not null    -- Documento cargado
           and cod_id_crear is not null; -- Documento procesado
      exception
        when no_data_found then
          v_can_doc_req_cliente := 0;
        when too_many_rows then
          v_can_doc_req_cliente := 1;
      end;
      -- ==========================================
      -- APLICACIÓN DE VALIDACIONES DE LÍMITES
      -- ==========================================
      -- Solo aplica la validación del límite si la transacción actual NO está excluida
      -- Las transacciones excluidas (reintegros, devoluciones, etc.) pasan sin validación
      if v_tra_exc_actual='N' then
        -- Determinar qué límite usar: el menor entre límite de cuenta y límite de modalidad
        if nvl(v_mto_lim_cred_cta, 0) <= nvl(v_mto_lim_cta_baj_riesgo, 0) then
          -- Control usando límite específico de la cuenta (más restrictivo)

          -- Verificar si el monto actual + acumulados supera el límite de la cuenta
          if NVL(p_monto, 0) + nvl(v_sal_acu_mes, 0) +
             nvl(v_sal_acu_diario, 0) + nvl(v_sal_noc_acu_diario, 0) > nvl(v_mto_lim_cred_cta, 0) then
            
             if v_es_cue_mipyme then
              p_cod_error := 7;
              p_mensaje   := 'Monto acreditado supera el limite de cuenta mipyme';
            else
            -- Verificar si el cliente tiene toda la documentación requerida
              if nvl(v_can_doc_req_cliente, 0) < nvl(v_can_doc_requeridos, 0) then
                -- ERROR 1: Cliente sin documentación suficiente
                p_cod_error := 1;
                p_mensaje   := 'El Cliente no cuenta con todos los documentos requeridos ' ||
                              p_monto || ' - ' || v_sal_acu_mes || ' - ' ||
                              v_sal_acu_diario || ' - ' ||
                              nvl(v_mto_lim_cta_baj_riesgo, 0);
              prg_ins_log_programas('prg_val_tra_cta_baj_riesgo',
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
                -- Cliente tiene documentación completa, verificar límite de modalidad
                if NVL(p_monto, 0) + nvl(v_sal_acu_mes, 0) +
                  nvl(v_sal_acu_diario, 0) + nvl(v_sal_noc_acu_diario, 0) > nvl(v_mto_lim_cta_baj_riesgo, 0) then
                  -- ERROR 2: Supera límite de modalidad bajo riesgo
                  p_cod_error         := 2;
                  p_mensaje           := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ';
                  pag_cta.G_COD_ERROR := 41;
                  pag_cta.G_MSJ_ERROR := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ' ||
                                        pag_cta.G_COD_ERROR || ' ..';
                  prg_ins_log_programas('prg_val_tra_cta_baj_riesgo',
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
          -- Control usando límite de modalidad (cuenta con límite mayor al de modalidad)
          -- Esto ocurre cuando hay un aumento de límite pendiente de aplicar
          if nvl(v_can_doc_req_cliente, 0) = nvl(v_can_doc_requeridos, 0) then
            -- Cliente tiene documentación completa
            if NVL(p_monto, 0) + nvl(v_sal_acu_mes, 0) +
               nvl(v_sal_acu_diario, 0) + nvl(v_sal_noc_acu_diario, 0) > nvl(v_mto_lim_cta_baj_riesgo, 0) then
              -- ERROR 3: Supera límite con documentación completa (aumento pendiente)
              p_cod_error := 3;
              p_mensaje   := 'Aumento de limite transaccional pendiente';
            end if;
          else
            -- ERROR 4: Falta documentación y hay aumento pendiente
            p_cod_error := 4;
            p_mensaje   := 'Aumento de limite transaccional pendiente';
          end if;
        end if;
      end if; -- Fin validación transacción no excluida
    end if;
    
    -- ====================
    -- REGISTRO DE LOGS
    -- ====================
    -- Si está habilitado el registro de logs y hay algún error, registrar el evento
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
       nvl(p_cod_error, 0) != 0 then
      prg_ins_log_programas('prg_val_tra_cta_baj_riesgo',
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
end prg_val_tra_cta_baj_riesgo;
/

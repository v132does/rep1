create or replace package body    IT.PAS_DEP is

  /*Datos de conexion al socket*/
  -- DEPO
  g_servidor   constant varchar2(20) := fug_obt_pardinamico('SNP_DEPO_SCK_DIR');
  g_puerto     constant number(4) := fug_obt_pardinamico('SNP_DEPO_SCK_PUERTO');
  g_tie_espera constant number(4) := fug_obt_pardinamico('SNP_DEPO_SCK_TIE_ESPERA');
  --
  --X-Adapter
  g_ser_xadapter     constant varchar2(20) := fug_obt_pardinamico('SNP_SCK_DIR');
  g_pto_xadapter     constant number(4) := fug_obt_pardinamico('SNP_SCK_PUERTO');
  g_tie_esp_xadapter constant number(4) := fug_obt_pardinamico('SNP_SCK_TIE_ESPERA');
  --
  g_ok       varchar2(1) := 'N';
  rg_mensaje pas_snp.rg_msj;

  --Usuario DEPO
  g_usu_depo constant varchar2(20) := fug_obt_pardinamico('SNP_USU_DEPO');

  --Monto unitario título
  --g_mto_uni_titulo constant number := fug_obt_pardinamico('SNP_MTO_UNI_TITULO');--FIELDESK-113732
    g_mto_uni_titulo number := fug_obt_pardinamico('SNP_MTO_UNI_TITULO');

  FUNCTION fu_obt_bic_sis_depo return varchar2 is
    /*
    || Halla el BIC del Sistema para DEPO
    */
    v_valor ba_cod_referencias.abreviatura%type := fue_obt_des_refcodes('SNP_BIC_SISTEMA',
                                                                        'D');

  begin
    if upper(v_valor) like 'REF%NO%REG%SIS%' then
      raise_application_error(-20801,
                              'BIC del Sistema DEPO no está parametrizado.');
    end if;
    return v_valor;
  end fu_obt_bic_sis_depo;

FUNCTION fu_obt_cta_depo(p_cod_moneda in ba_monedas.cod_moneda%type default 'GS'  ) return varchar2 is
         v_nro_cta_pte  ge_snp_cta_bancos.nro_cta_bancaria%type;
         v_nro_cta_depo ge_snp_cta_bancos.nro_cta_bancaria%type;

 begin
    select cb.nro_cta_bancaria
      into v_nro_cta_pte
      from cc_cta_bancarias cb, ge_cta_clientes cc, gv_snp_participantes v
     where cb.nro_cuenta = cc.nro_cuenta
       and cb.cod_moneda = trim(p_cod_moneda)
       and cc.relacion = 'P'
       and cb.estado IN ('A', 'N', 'S') /*Abierta, Normal, Bloqueo de Saldo*/
       and cb.cod_modulo = pas_snp.fu_obt_cod_mod_padre
       and cb.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
       and cc.cod_persona = v.cod_persona
       and v.cod_swift = trim(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad))
       and exists (select 1
              from sb_snp_lim_depo s
             where s.val_parametro = cb.nro_cuenta
               and s.estado = 'S'
               and s.cod_moneda = cb.cod_moneda);

    IF v_nro_cta_pte is not null then 
       v_nro_cta_depo := v_nro_cta_pte;      
    ELSE
       v_nro_cta_depo := pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),p_cod_moneda);
    END IF;

    RETURN v_nro_cta_depo;                                                                                                                                                 

  end fu_obt_cta_depo;  

  /*Genera MT920*/
  PROCEDURE pr_obt_msj_MT920(p_cod_tip_mensaje    in sb_snp_tip_mensajes.cod_mensaje%type,
                             p_nro_cta_bancaria   in ge_snp_cta_bancos.nro_cta_bancaria%type,
                             p_tip_rep_solicitado in number default null,
                             p_ind_debito         in varchar2 default null,
                             p_ind_credito        in varchar2 default null,
                             p_mto_debito         in ge_snp_transferencias.monto%type default 0,
                             p_mto_credito        in ge_snp_transferencias.monto%type default 0,
                             p_cod_moneda         in ge_snp_transferencias.cod_moneda%type,
                             p_tipo_identificador in varchar2) is

    --v_nro_referencia ge_snp_mensajes.nro_referencia%type := pas_snp.fu_obt_sig_nro_referencia || '/D';
    v_nro_referencia ge_snp_mensajes.nro_referencia%type;
    v_cta_ban_hab    ge_snp_cta_bancos.nro_cta_bancaria%type;  
    v_mensaje        ge_snp_mensajes.msj_swift%type;
    v_resp           varchar2(4000) := null;

  begin
    --SPI
    --validamos que tipo de indicador tiene para generar el nro de referencia--
    --D := Deposito
    --F := Fondeo
    if p_tipo_identificador = 'D' then
      v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia || '/D';
    elsif p_tipo_identificador = 'F' then
      v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia||'F';
    end if;
    --
    pas_snp.pr_ini_registros;

    --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
    pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
    --
    pas_dep.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       'CAB',
                                       '{1:F01' ||
                                       rpad(pas_snp.g_usu_xadapter, 12, 'X') || '}' ||
                                       '{2:I920' || rpad(pas_snp.fu_obt_bic_sistema,
                                                         12,
                                                         'X') || 'N}' ||
                                       '{3:{113' || ':' ||
                                       lpad('30', 4, '0') || '}}{4:');
    -- Detalle
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       '20',
                                       v_nro_referencia);
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       '12',
                                       p_tip_rep_solicitado);
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       '25',
                                       p_nro_cta_bancaria);
    if p_tip_rep_solicitado = 942 then
      if p_mto_debito >= 0 and p_mto_credito = 0 then
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '34F',
                                           substr(p_nro_cta_bancaria, -3, 3) ||
                                           trim(to_char(p_mto_debito,
                                                        pas_snp.fu_obt_mascara ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                     p_cod_moneda => p_cod_moneda),
                                                                 2),
                                                             '9'))));
      elsif p_mto_debito > 0 and p_mto_credito > 0 then
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '34F',
                                           substr(p_nro_cta_bancaria, -3, 3) ||
                                           p_ind_debito ||
                                           trim(to_char(p_mto_debito,
                                                        pas_snp.fu_obt_mascara ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                     p_cod_moneda => p_cod_moneda),
                                                                 2),
                                                             '9'))));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '34F',
                                           ':34F:' ||
                                           substr(p_nro_cta_bancaria, -3, 3) ||
                                           p_ind_credito ||
                                           trim(to_char(p_mto_credito,
                                                        pas_snp.fu_obt_mascara ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                     p_cod_moneda => p_cod_moneda),
                                                                 2),
                                                             '9'))));
      else
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '34F',
                                           substr(p_nro_cta_bancaria, -3, 3) ||
                                           p_ind_debito ||
                                           trim(to_char(p_mto_debito,
                                                        pas_snp.fu_obt_mascara ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                     p_cod_moneda => p_cod_moneda),
                                                                 2),
                                                             '9'))));
      end if;
    end if;
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');
    begin
      pas_dep.g_lugar := 'Creando la mensajería, ';
      pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);
      pas_dep.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
      insert into ge_snp_mensajes
        (nro_referencia,
         nro_ref_externa,
         cod_msj_swift,
         fec_valor,
         msj_swift,
         cod_moneda,
         monto,
         situacion,
         error,
         msj_swi_original)
      values
        (v_nro_referencia,
         null,
         920,
         pas_snp.g_fec_actual,
         v_mensaje,
         null,
         null,
         'V',
         null,
         v_mensaje);
      --
      pas_dep.g_lugar  := 'Enviando mensaje swift al socket, ';
      if p_tipo_identificador = 'D' then
       v_nro_referencia := substr(v_nro_referencia,
                                 1,
                                 instr(v_nro_referencia, '/', 1) - 1);
       pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
       else
       --SPI
       v_nro_referencia := substr(v_nro_referencia, 1, length(v_nro_referencia) - 1);
       pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');

      end if;  
      --TRFS-564
          if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
            g_lugar := 'Insertando en ge_men_env_sipap';
            begin
                         insert into ge_men_env_sipap
                           (nro_referencia, estado, msj_swift)
                         values
                           (v_nro_referencia,
                            'PENDING',
                            REPLACE(REPLACE(v_mensaje,
                                            chr(10),
                                            pas_snp.fu_obt_sal_socket),
                                    chr(13),
                                    ''));
              exception
               when others then
               -- Hubo problema en la insercion
                          v_resp:=SQLERRM;      
                          pas_snp.g_cod_error := 49;
                          pas_snp.g_msj_error := v_resp;
                          g_lugar             := 'Actualizando Error en el LOG, ';
                          pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                                           'A',
                                                           'N',
                                                           pas_snp.g_msj_error);
                          raise ex_salir;

               end;
               if pas_snp.fu_obt_cod_error = 0 then
                  g_lugar := 'Actualizando datos en ge_snp_transferencias';
                else
                  pas_snp.g_cod_error := 49;
                  pas_snp.g_msj_error := substr('Archivo no generado ' || v_resp,
                                        1,
                                        1000);
                   raise ex_salir;
                end if;

     else     
      g_lugar := 'Conectándose al socket';
      -- Envia el mensaje al servidor
      pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => g_ser_xadapter,
                                           p_puerto     => g_pto_xadapter,
                                           p_tie_espera => g_tie_esp_xadapter,
                                           p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                           p_respuesta  => v_resp);
      if pas_dep.g_ok != 'S' THEN
        -- Hubo problema en el envio
        pas_snp.g_cod_error := 49;
        pas_snp.g_msj_error := v_resp;
        g_lugar             := 'Actualizando Error en el LOG, ';
        pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                         'A',
                                         'N',
                                         pas_snp.g_msj_error);
        raise ex_salir;
      else
        if substr(v_resp, 1, 2) = '00' then
          g_lugar := 'Actualizando datos en ge_snp_transferencias';
        else
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := substr('Archivo no generado ' || v_resp,
                                        1,
                                        1000);
          raise ex_salir;
        end if;
      end if;
      end if;
      --
    exception
      when others then
        raise_application_error(-20809,
                                'Generando y enviando el mensaje' ||
                                sqlerrm);
    end;
  exception
    when others then
      pas_dep.g_cod_error := 90;
      pas_dep.g_msj_error := 'Error al Generar MT: ' || pas_snp.g_lugar || ' ' ||
                             sqlerrm;
  end pr_obt_msj_mt920;

  -- Obtiene el monto y la tasa predefindos para las operaciones Depo
  PROCEDURE pr_obt_dat_depo(p_cod_moneda in ba_monedas.cod_mon_iso%type,
                            p_monto      out sb_snp_lim_depo.monto%type,
                            p_tasa       out sb_snp_lim_depo.tasa%type)
  /*
    || Obtiene el monto y la tasa predefindos para las operaciones Depo
    */
   IS

    v_mto_bcp_disponible sb_snp_lim_depo.monto%type;
    v_cod_moneda         ba_monedas.cod_mon_iso /*ba_monedas.cod_moneda*/
    %type;

  BEGIN
    -- Inicializa variables de error
    pas_snp.pr_ini_variables;
    --

    --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
    pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
    --

    BEGIN
      select distinct substr(x.valor, 11, length(x.valor)) /*substr(x.valor, 11, length(x.valor))*/
                      /*distinct to_number(replace(substr(x.valor, 11, length(x.valor)),
                      ',',
                      '.'))*/ monto,
                      substr(x.valor, 8, 3) cod_mon_iso
        into v_mto_bcp_disponible, v_cod_moneda
        from sb_snp_mensajes x
       where x.campo = '64'
         and x.cod_mensaje = 'MT941'
         and to_char(substr(x.valor, 8, 3)) = p_cod_moneda
         and trunc(x.fec_insercion) = trunc(sysdate)
         and x.nro_referencia in
             (select s.nro_referencia
                from sb_snp_mensajes s
               where s.cod_mensaje = 'MT941'
                 and s.campo = '21'
                 and trunc(x.fec_insercion) = trunc(sysdate)
                 and s.valor like '%/D%');
    EXCEPTION
      when no_data_found then
        v_cod_moneda         := NULL;
        v_mto_bcp_disponible := 0;
    END;
    --
    v_cod_moneda := p_cod_moneda;

    v_cod_moneda := CASE v_cod_moneda
                      WHEN pas_snp.g_cod_mon_iso_local THEN
                       pas_snp.g_cod_mon_local
                      ELSE
                       v_cod_moneda
                    END;
    --
    --p_cod_moneda := v_cod_moneda;
    if v_cod_moneda is not NULL then
      BEGIN
        select d.monto, d.tasa
          into p_monto, p_tasa
          from sb_snp_lim_depo d
         where d.cod_moneda = v_cod_moneda
           and d.transaccion <> 'CTA_DEPOX' --SPI
           and d.fecha = (select max(x.fecha) from sb_snp_lim_depo x where x.transaccion <> 'CTA_DEPOX' );
           --and d.fecha = (select max(x.fecha) from sb_snp_lim_depo x); 
      EXCEPTION
        when no_data_found then
          p_monto := 0;
          p_tasa  := 0;
      END;

      if pas_dep.fu_obt_cod_error <> 0 then
        v_cod_moneda := NULL;
        p_monto      := 0;
        p_tasa       := 0;
      end if;
    end if;

    if v_mto_bcp_disponible <= p_monto then
      p_monto := v_mto_bcp_disponible;
    end if;

    -- Control del Redondeo
    if nvl(fug_obt_pardinamico('SNP_DEPO_MTO_REDONDO'), 'N') = 'S' and
       p_monto > 1000000 then
      p_monto := trunc(p_monto / 1000000) * 1000000;
    end if;

  EXCEPTION
    when ex_salir then
      v_cod_moneda := NULL;
      p_monto      := 0;
      p_tasa       := 0;
    when others then
      v_cod_moneda        := NULL;
      p_monto             := 0;
      p_tasa              := 0;
      pas_dep.g_cod_error := 66;
      pas_dep.g_msj_error := 'Error al recuperar el monto y la tasa para la operación Depo. ' ||
                             SQLERRM;
  END pr_obt_dat_depo;

 -- Obtiene el monto para el fonde de la tarde
  PROCEDURE pr_obt_dat_fondeo(p_cod_moneda in ba_monedas.cod_mon_iso%type,
                            p_monto      out sb_snp_lim_depo.monto%type)
  /*
    || Obtiene el monto para el fondeo de la tarde
    */
   IS

    v_mto_bcp_disponible sb_snp_lim_depo.monto%type;

  BEGIN
    -- Inicializa variables de error
    pas_snp.pr_ini_variables;
    --

    --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
    pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
    --

    BEGIN
      select distinct substr(x.valor, 11, length(x.valor)) /*substr(x.valor, 11, length(x.valor))*/
                      /*distinct to_number(replace(substr(x.valor, 11, length(x.valor)),
                      ',',
                      '.'))*/ monto
        into v_mto_bcp_disponible
        from sb_snp_mensajes x
       where x.campo = '64'
         and x.cod_mensaje = 'MT941'
         and to_char(substr(x.valor, 8, 3)) = p_cod_moneda
         and trunc(x.fec_insercion) = trunc(sysdate)
         and x.nro_referencia in
             (select s.nro_referencia
                from sb_snp_mensajes s
               where s.cod_mensaje = 'MT941'
                 and s.campo = '21'
                 and trunc(x.fec_insercion) = trunc(sysdate)
                 and s.valor like '%F%');
    EXCEPTION
      when no_data_found then
        v_mto_bcp_disponible := 0;
    END;
    --

      p_monto := v_mto_bcp_disponible;

    -- Control del Redondeo
    if nvl(fug_obt_pardinamico('SNP_DEPO_MTO_REDONDO'), 'N') = 'S' and
       p_monto > 1000000 then
      p_monto := trunc(p_monto / 1000000) * 1000000;
    end if;

  EXCEPTION
    when ex_salir then
      p_monto      := 0;
    when others then
      p_monto             := 0;
      pas_dep.g_cod_error := 66;
      pas_dep.g_msj_error := 'Error al recuperar el monto para el fondeo de la tarde. ' ||
                             SQLERRM;
  END pr_obt_dat_fondeo;

  /*Genera MT524*/
  PROCEDURE pr_obt_msj_MT524(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT524',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in md_cta_documentos.nro_documento%type,
                             p_nro_referencia  in md_cta_documentos.nro_documento%type default null,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N') is

    v_nro_referencia ge_snp_mensajes.nro_referencia%type := pas_snp.fu_obt_sig_nro_referencia;
    v_mensaje        ge_snp_mensajes.msj_swift%type;
    v_cod_moneda     ba_monedas.cod_moneda%type;
    v_monto          ge_snp_transferencias.monto%type;
    v_mto_neto       ge_snp_transferencias.monto%type;
    v_mto_rnd        ge_snp_transferencias.monto%type;
    v_tasa           varchar2(20);

    v_fecha              ge_snp_transferencias.fecha%type := pas_snp.g_fec_actual;
    v_fec_valor          ge_snp_transferencias.fec_valor%type := trunc(sysdate);
    v_cod_msj_swift      ge_snp_transferencias.cod_msj_swift%type := '524';
    v_tip_operacion      ge_snp_transferencias.cod_tip_operacion%type := '001';
    v_sub_tip_operacion  ge_snp_transferencias.cod_sub_tip_operacion%type := '001';
    v_ind_valor          ge_snp_transferencias.ind_valor%type := 'S';
    v_nro_cta_benef      ge_snp_transferencias.nro_cta_beneficiario%type;
    v_prioridad          ge_snp_transferencias.prioridad%type := 11;
    v_nro_cta_sol        ge_cuentas.nro_cuenta%type;
    v_cod_modulo         ba_modulos.cod_modulo%type;
    v_cod_modalidad      ge_modalidades.cod_modalidad%type;
    v_cod_oficina        ba_oficinas.cod_oficina%type;
    v_concepto           ge_movimientos.concepto%type;
    v_con_movimiento     ge_movimientos.concepto%type;
    v_cod_persona        ba_personas.cod_persona%type;
    v_cod_transaccion    ge_transacciones.cod_transaccion%type;
    v_resp               varchar2(4000) := null;
    v_cta_bancaria       cc_cta_bancarias.nro_cuenta%TYPE;
    v_nro_secuencia      NUMBER := 0;
    v_ind_transaccion    VARCHAR2(1) := 'R';
    v_hora               VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_cod_tra_padre      ge_transacciones.cod_transaccion%TYPE := 303;
    v_tip_movimiento     ge_transacciones.tipo%TYPE;
    v_opcion             NUMBER;
    v_return             NUMBER;
    v_des_tip_movimiento VARCHAR2(60);
    v_bic_sis_depo       varchar2(20);
    v_nro_documento      VARCHAR2(60);
    v_situacion          ge_snp_transferencias.situacion%type := 'P';
    v_estado             ge_snp_transferencias.estado%type := 'S';
    g_msj                pas_snp.rg_msj;



    /*cursor restringidos is
    SELECT to_number(nvl((((length(p_nro_documento) -
                         length(REPLACE(p_nro_documento, ',', ''))) /
                         length(',')) - 1),
                         0)) cantidad,
           substr(p_nro_documento, 2, length(p_nro_documento) - 2) ref_oid
      FROM dual;*/

  begin
    IF p_nro_documento is NOT NULL THEN
      --FOR reg in restringidos loop
      /*FOR e IN 1 .. reg.cantidad LOOP
      v_nro_documento := pae_uti.fu_obt_valor(reg.ref_oid, e);*/

      /*select m.nro_referencia
       into v_nro_ref_986
       from ge_snp_mensajes m
      where m.cod_msj_swift = '543'
        and m.fec_valor = pag_cal.fu_obt_fec_actual(1)
        and m.nro_ref_externa = v_nro_documento;*/

        BEGIN --FIELDESK-113732
          Begin
            Select distinct t.cod_modulo, t.cod_modalidad
            into v_cod_modulo, v_cod_modalidad
            from md_cta_documentos t 
            where t.nro_documento = trim(p_nro_documento);--v_letras ; 
          exception
            when no_data_found then
              v_cod_modulo    := null;
              v_cod_modalidad := null;
          end;
          SELECT fug_obt_pardinamico('SNP_MTO_UNI_TITULO',
                                     v_cod_modulo,
                                     v_cod_modalidad)
            INTO g_mto_uni_titulo
            FROM md_cta_documentos m
           WHERE m.nro_documento = p_nro_documento
             and rownum = 1;
        EXCEPTION
          WHEN OTHERS THEN
            g_mto_uni_titulo := fug_obt_pardinamico('SNP_MTO_UNI_TITULO');
        END;

      pas_snp.pr_ini_registros;

      --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
      pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
      --

      v_cod_moneda := p_cod_moneda;
      v_cod_moneda := CASE v_cod_moneda
                        WHEN pas_snp.g_cod_mon_iso_local THEN
                         pas_snp.g_cod_mon_local
                        ELSE
                         v_cod_moneda
                      END;
      --
      v_monto := p_monto;


      -- Redondeos para tomar las unidades correctas por letras
      v_mto_rnd := round(v_monto / g_mto_uni_titulo);

      v_mto_neto := (v_monto / g_mto_uni_titulo);

      if (v_mto_neto - v_mto_rnd) > 0 then
        v_monto := (v_mto_rnd + 1) * g_mto_uni_titulo;
      else
        v_monto := v_mto_rnd * g_mto_uni_titulo;
      end if;
      --

      -- BIC
      if fug_es_produccion = 'S' then
        v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'D');
      else
        v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'T');
      end if;
      --
      if v_monto > 0 then

        pas_dep.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           'CAB',
                                           '{1:F01' ||
                                           rpad(g_usu_depo, 12, 'X') || '}' ||
                                           '{2:I524' ||
                                           rpad(v_bic_sis_depo, 12, 'X') || 'N}' ||
                                           '{3:{113' || ':' ||
                                           lpad('30', 4, '0') || '}}{4:');
        -- Detalle
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'GENL');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '20C',
                                           ':SEME//' || v_nro_referencia);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '23G',
                                           'NEWM');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '98C',
                                           ':PREP//' ||
                                           to_char(sysdate,
                                                   'YYYYMMDDHH24MISS'));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'GENL');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'INPOSDET');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '97A',
                                           ':SAFE//' ||
                                           substr(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                  1,
                                                  4) || '/DEPO/DEPO');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '36B',
                                           ':SETT//UNIT/' ||
                                           trim(to_char((v_monto /
                                                        g_mto_uni_titulo),
                                                        pas_snp.fu_obt_mascara ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                     p_cod_moneda => v_cod_moneda),
                                                                 2),
                                                             '9'))));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '35B',
                                           '/XX/' || p_nro_documento
                                           /*substr(p_nro_documento,
                                                                                                                                            2,
                                                                                                                                            length(p_nro_documento) - 2)*/); -- Aquí va el código de la letra
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '98A',
                                           ':SETT//' ||
                                           to_char(SYSDATE, 'YYYYMMDD'));
        IF p_cancela = 'S' THEN
          pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                             '93A',
                                             ':FROM//AVAI');
          pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                             '93A',
                                             ':93A::TOBA//RSTR');
        ELSE
          pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                             '93A',
                                             ':FROM//RSTR');
          pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                             '93A',
                                             ':93A::TOBA//AVAI');
        END IF;
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'INPOSDET');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');

        begin
          pas_dep.g_lugar := 'Creando la mensajería, ';
          pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);

          --
          --if p_nro_referencia is null then
            --
            insert into sb_snp_mensajes
              (cod_mensaje,
               nro_referencia,
               nro_lote,
               orden,
               nro_linea,
               campo,
               valor,
               descripcion,
               ind_requerido,
               nro_detalle,
               err_formato,
               err_validacion)
              (select cod_mensaje,
                      v_nro_referencia,
                      null,
                      orden,
                      nro_linea,
                      campo,
                      valor,
                      descripcion,
                      ind_requerido,
                      nro_detalle,
                      err_formato,
                      err_validacion
                 from sb_snp_mensajes_tmp
                where cod_mensaje = p_cod_tip_mensaje
                  and valor is not null);
            --

            pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
            --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
            pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
            g_lugar := 'Conectándose al socket';
            -- Envia el mensaje al servidor
            pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                                 p_puerto     => pas_dep.g_puerto,
                                                 p_tie_espera => pas_dep.g_tie_espera,
                                                 p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                                 p_respuesta  => v_resp);
            if pas_dep.g_ok != 'S' THEN
              -- Hubo problema en el envio
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'N',
                                               pas_snp.g_msj_error);
              raise ex_salir;
            else
              if substr(v_resp, 1, 2) = '00' then
                g_lugar     := 'Actualizando estado y situación';
                v_situacion := 'V';
                v_estado    := 'A';
              else
                pas_snp.g_cod_error := 49;
                pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                              v_resp,
                                              1,
                                              1000);
                raise ex_salir;
              end if;
            end if;
            --end if;
            --

            -- Obtiene la transacción hija de la Cta. Interbancaria según el tipo/subtipo de operación de GE_PAR_MENSAJES.
            g_lugar := 'Buscando Transacción de GE_PAR_MENSAJES, ';
            pas_snp.pr_obt_par_mensajes(v_cod_msj_swift,
                                        v_tip_operacion,
                                        v_sub_tip_operacion,
                                        'E',
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        v_cod_transaccion);

            begin
              -- Datos a registrar en GE_SNP_TRANSFERENCIAS
              pas_snp.g_msj.nro_referencia        := v_nro_referencia;
              pas_snp.g_msj.cod_modulo            := v_cod_modulo;
              pas_snp.g_msj.cod_modalidad         := v_cod_modalidad;
              pas_snp.g_msj.cod_oficina           := nvl(fug_obt_ofi_usuario(USER),
                                                         1); --v_cod_oficina;
              pas_snp.g_msj.fec_valor             := v_fec_valor;
              pas_snp.g_msj.fec_ingreso           := v_fecha;
              pas_snp.g_msj.fecha                 := v_fecha;
              pas_snp.g_msj.hora                  := to_char(sysdate,
                                                             'HH24:MI:SS');
              pas_snp.g_msj.cod_usuario           := USER;
              pas_snp.g_msj.nro_operacion         := v_nro_referencia;
              pas_snp.g_msj.cod_moneda            := v_cod_moneda;
              pas_snp.g_msj.cod_tip_operacion     := v_tip_operacion;
              pas_snp.g_msj.cod_sub_tip_operacion := v_sub_tip_operacion;
              pas_snp.g_msj.monto                 := v_monto;
              pas_snp.g_msj.ref_oid               := p_nro_referencia;

              --

              pas_snp.g_msj.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
         --     pas_snp.g_msj.nro_cta_pte_solicitante  := pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),             
         --                                                                                   v_cod_moneda);
              pas_snp.g_msj.nro_cta_pte_solicitante  :=  fu_obt_cta_depo(v_cod_moneda);
              pas_snp.g_msj.cod_swi_pte_beneficiario := fug_obt_pardinamico('SNP_BIC_BCP');
              pas_snp.g_msj.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                                                            v_cod_moneda);

              pas_snp.g_msj.concepto      := pas_snp.fu_val_cadena(nvl(v_concepto,
                                                                       v_con_movimiento));
              pas_snp.g_msj.cod_msj_swift := v_cod_msj_swift;
              pas_snp.g_msj.msj_swift     := v_mensaje;
              pas_snp.g_msj.ind_valor     := v_ind_valor;
              pas_snp.g_msj.prioridad     := v_prioridad;
              pas_snp.g_msj.situacion     := v_situacion;
              pas_snp.g_msj.estado        := v_estado;
              pas_snp.g_msj.origen        := 'I';
              pas_snp.g_msj.plataforma    := 'D';
              pas_snp.g_msj.indemnizado   := 'N';
              pas_snp.g_msj.observacion   := p_cancela;

              pas_dep.g_lugar := 'Insertando Mensajería.., ';
              pas_snp.pr_ins_transferencias(pas_snp.g_msj);
              if pas_snp.fu_obt_cod_error <> 0 then
                raise_application_error(-20001, pas_dep.fu_obt_msj_error);
              end if;
            end;

            /*if nvl(fug_obt_pardinamico('SIB_SNP_VER_WORKFLOW'), 'N') = 'S' THEN
              pas_snp.pr_ini_workflow(pas_snp.g_msj);
            end if;*/

            -- Operación de mesa de dinero.
            -- Operación de mesa de dinero.
            if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
              NULL; --Actualiza montos de letras en Mesa--prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda);
            end if;
            --else
            -- Si se actualiza el monto o tasa manualmente
            -- Se actualiza también el estado y la situación
            --Se comenta llamado al socket para transaccion de mesa de dinero, ver mas adelante.
            /*pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
            --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
            --pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
            g_lugar := 'Conectándose al socket';
            -- Envia el mensaje al servidor
            pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                                 p_puerto     => pas_dep.g_puerto,
                                                 p_tie_espera => pas_dep.g_tie_espera,
                                                 p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                                 p_respuesta  => v_resp);
            if pas_dep.g_ok != 'S' THEN
              -- Hubo problema en el envio
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'N',
                                               pas_snp.g_msj_error);
              raise ex_salir;
            else
              if substr(v_resp, 1, 2) = '00' then
                g_lugar     := 'Actualizando estado y situación';
                BEGIN
                  UPDATE ge_snp_transferencias
                     SET situacion = 'V',
             estado    = 'A'
                   WHERE nro_referencia = p_nro_referencia;
                END;
              else
                pas_snp.g_cod_error := 49;
                pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                              v_resp,
                                              1,
                                              1000);
                raise ex_salir;
              end if;
            end if;*/
            --end if;
            --

            -- Operación de mesa de dinero.
            if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
              NULL; --prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda, p_monto, p_tasa);
            end if;
            --
            /*else
            NULL;*/
            -- Se cancela la operación Depo
            /*BEGIN
              UPDATE ge_snp_transferencias
                 SET situacion = 'C', estado = 'C'
               WHERE nro_referencia = p_nro_referencia;
            END;
            -- Se elimina la operación de Compra
            BEGIN
              DELETE md_cta_documentos c
               WHERE c.nro_documento = p_nro_referencia
                 AND trunc(c.fec_insercion) = trunc(sysdate);
            END;*/
          --end if;
          --end if;
        exception
          when others then
            pas_dep.g_cod_error := 90;
            pas_dep.g_msj_error := 'Error insertando en GE_SNP_TRANSFERENCIAS: ' ||
                                   pas_dep.g_lugar || ' ' || SQLERRM;
        end;
      end if;
      --END LOOP;
      --END LOOP;
    END IF;
  exception
    when others then
      pas_dep.g_cod_error := 91;
      pas_dep.g_msj_error := 'Error al Generar MT: ' || pas_dep.g_lugar || ' ' ||
                             SQLERRM;
  end pr_obt_msj_mt524;

  /*Genera MT549*/
  PROCEDURE pr_obt_msj_MT549(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT549',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_nro_documento   in md_cta_documentos.nro_documento%type default NULL,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N') is

    v_nro_referencia ge_snp_mensajes.nro_referencia%type := pas_snp.fu_obt_sig_nro_referencia;
    v_mensaje        ge_snp_mensajes.msj_swift%type;
    v_cod_moneda     ba_monedas.cod_moneda%type;
    v_monto          ge_snp_transferencias.monto%type;
    v_tasa           varchar2(20);

    v_fecha              ge_snp_transferencias.fecha%type := pas_snp.g_fec_actual;
    v_fec_valor          ge_snp_transferencias.fec_valor%type := trunc(sysdate);
    v_cod_msj_swift      ge_snp_transferencias.cod_msj_swift%type := '549';
    v_tip_operacion      ge_snp_transferencias.cod_tip_operacion%type := '001';
    v_sub_tip_operacion  ge_snp_transferencias.cod_sub_tip_operacion%type := '001';
    v_ind_valor          ge_snp_transferencias.ind_valor%type := 'S';
    v_nro_cta_benef      ge_snp_transferencias.nro_cta_beneficiario%type;
    v_prioridad          ge_snp_transferencias.prioridad%type := 11;
    v_nro_cta_sol        ge_cuentas.nro_cuenta%type;
    v_cod_modulo         ba_modulos.cod_modulo%type;
    v_cod_modalidad      ge_modalidades.cod_modalidad%type;
    v_cod_oficina        ba_oficinas.cod_oficina%type;
    v_concepto           ge_movimientos.concepto%type;
    v_con_movimiento     ge_movimientos.concepto%type;
    v_cod_persona        ba_personas.cod_persona%type;
    v_cod_transaccion    ge_transacciones.cod_transaccion%type;
    v_resp               varchar2(4000) := null;
    v_cta_bancaria       cc_cta_bancarias.nro_cuenta%TYPE;
    v_nro_secuencia      NUMBER := 0;
    v_ind_transaccion    VARCHAR2(1) := 'R';
    v_hora               VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_cod_tra_padre      ge_transacciones.cod_transaccion%TYPE := 303;
    v_tip_movimiento     ge_transacciones.tipo%TYPE;
    v_opcion             NUMBER;
    v_return             NUMBER;
    v_des_tip_movimiento VARCHAR2(60);
    v_bic_sis_depo       varchar2(20);
    v_situacion          ge_snp_transferencias.situacion%type := 'P';
    v_estado             ge_snp_transferencias.estado%type := 'S';
    g_msj                pas_snp.rg_msj;

  begin
    pas_snp.pr_ini_registros;

    --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
    pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
    --

    -- Se obtienen los datos para la operación Depo
    /*    if p_monto = 0 then
          pr_obt_dat_depo(p_cod_moneda, v_monto, v_tasa);
        else
          v_cod_moneda     := p_cod_moneda;
          v_monto          := p_monto;
          v_tasa           := p_tasa;
          v_nro_referencia := p_nro_referencia;
        end if;
    */ --
    v_cod_moneda := p_cod_moneda;
    v_cod_moneda := CASE v_cod_moneda
                      WHEN pas_snp.g_cod_mon_iso_local THEN
                       pas_snp.g_cod_mon_local
                      ELSE
                       v_cod_moneda
                    END;

    --v_monto      := p_monto;

    -- BIC
    if fug_es_produccion = 'S' then
      v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'D');
    else
      v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'T');
    end if;
    --
    --if v_monto > 0 then

    pas_dep.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       'CAB',
                                       '{1:F01' ||
                                       rpad(g_usu_depo, 12, 'X') || '}' ||
                                       '{2:I549' ||
                                       rpad(v_bic_sis_depo, 12, 'X') || 'N}' ||
                                       '{3:{113' || ':' ||
                                       lpad('30', 4, '0') || '}}{4:');

    -- Detalle
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16R', 'GENL');
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       '20C',
                                       ':SEME//' || v_nro_referencia);
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '23G', 'NEWM');
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       '13A',
                                       ':REQU//' || p_nro_documento);
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                       '97A',
                                       ':SAFE//' || substr(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                           1,
                                                           4) ||
                                       '/DEPO/DEPO');
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16S', 'GENL');
    pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');

    begin
      pas_dep.g_lugar := 'Creando la mensajería, ';
      pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);

      --
      insert into sb_snp_mensajes
        (cod_mensaje,
         nro_referencia,
         nro_lote,
         orden,
         nro_linea,
         campo,
         valor,
         descripcion,
         ind_requerido,
         nro_detalle,
         err_formato,
         err_validacion)
        (select cod_mensaje,
                v_nro_referencia,
                null,
                orden,
                nro_linea,
                campo,
                valor,
                descripcion,
                nvl(ind_requerido,'N'),
                nro_detalle,
                err_formato,
                err_validacion
           from sb_snp_mensajes_tmp
          where cod_mensaje = p_cod_tip_mensaje
            and valor is not null);
      --

      pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
      --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
      pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
      g_lugar := 'Conectándose al socket';
      -- Envia el mensaje al servidor
      pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                           p_puerto     => pas_dep.g_puerto,
                                           p_tie_espera => pas_dep.g_tie_espera,
                                           p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                           p_respuesta  => v_resp);
      if pas_dep.g_ok != 'S' THEN
        -- Hubo problema en el envio
        pas_snp.g_cod_error := 49;
        pas_snp.g_msj_error := v_resp;
        g_lugar             := 'Actualizando Error en el LOG, ';
        pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                         'A',
                                         'N',
                                         pas_snp.g_msj_error);
        raise ex_salir;
      else
        if substr(v_resp, 1, 2) = '00' then
          g_lugar     := 'Actualizando estado y situación';
          v_situacion := 'V';
          v_estado    := 'A';
        else
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := substr('Archivo no generado ' || v_resp,
                                        1,
                                        1000);
          raise ex_salir;
        end if;
      end if;
      --end if;
      --

      pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
      insert into ge_snp_mensajes
        (nro_referencia,
         nro_ref_externa,
         cod_msj_swift,
         fec_valor,
         msj_swift,
         cod_moneda,
         monto,
         situacion,
         error,
         msj_swi_original)
      values
        (v_nro_referencia,
         null,
         v_cod_msj_swift,
         pas_snp.g_fec_actual,
         v_mensaje,
         null,
         null,
         'V',
         null,
         v_mensaje);
      --
      if pas_snp.fu_obt_cod_error <> 0 then
        raise_application_error(-20001, pas_dep.fu_obt_msj_error);
      end if;

    exception
      when others then
        pas_dep.g_cod_error := 90;
        pas_dep.g_msj_error := 'Error insertando en GE_SNP_MENSAJES: ' ||
                               pas_dep.g_lugar || ' ' || SQLERRM;
    end;
    --end if;
  exception
    when others then
      pas_dep.g_cod_error := 91;
      pas_dep.g_msj_error := 'Error al Generar MT: ' || pas_dep.g_lugar || ' ' ||
                             SQLERRM;
  end pr_obt_msj_mt549;

  /*Genera MT986*/
  PROCEDURE pr_obt_msj_MT986(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT986',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in ge_snp_transferencias.ref_oid%type,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N') is

    v_nro_referencia ge_snp_mensajes.nro_referencia%type := pas_snp.fu_obt_sig_nro_referencia;
    v_mensaje        ge_snp_mensajes.msj_swift%type;
    v_cod_moneda     ba_monedas.cod_moneda%type;
    v_monto          ge_snp_transferencias.monto%type;
    v_tasa           varchar2(20);

    v_fecha              ge_snp_transferencias.fecha%type := pas_snp.g_fec_actual;
    v_fec_valor          ge_snp_transferencias.fec_valor%type := trunc(sysdate);
    v_cod_msj_swift      ge_snp_transferencias.cod_msj_swift%type := '986';
    v_tip_operacion      ge_snp_transferencias.cod_tip_operacion%type := '001';
    v_sub_tip_operacion  ge_snp_transferencias.cod_sub_tip_operacion%type := '001';
    v_ind_valor          ge_snp_transferencias.ind_valor%type := 'S';
    v_nro_cta_benef      ge_snp_transferencias.nro_cta_beneficiario%type;
    v_prioridad          ge_snp_transferencias.prioridad%type := 11;
    v_nro_cta_sol        ge_cuentas.nro_cuenta%type;
    v_cod_modulo         ba_modulos.cod_modulo%type;
    v_cod_modalidad      ge_modalidades.cod_modalidad%type;
    v_cod_oficina        ba_oficinas.cod_oficina%type;
    v_concepto           ge_movimientos.concepto%type;
    v_con_movimiento     ge_movimientos.concepto%type;
    v_cod_persona        ba_personas.cod_persona%type;
    v_cod_transaccion    ge_transacciones.cod_transaccion%type;
    v_resp               varchar2(4000) := null;
    v_cta_bancaria       cc_cta_bancarias.nro_cuenta%TYPE;
    v_nro_secuencia      NUMBER := 0;
    v_ind_transaccion    VARCHAR2(1) := 'R';
    v_hora               VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_cod_tra_padre      ge_transacciones.cod_transaccion%TYPE := 303;
    v_tip_movimiento     ge_transacciones.tipo%TYPE;
    v_opcion             NUMBER;
    v_return             NUMBER;
    v_des_tip_movimiento VARCHAR2(60);
    v_bic_sis_depo       varchar2(20);
    v_nro_documento      VARCHAR2(60);
    v_nro_doc            VARCHAR2(60);
    v_nro_cuenta         md_cta_documentos.nro_cuenta%type;
    v_situacion          ge_snp_transferencias.situacion%type := 'P';
    v_estado             ge_snp_transferencias.estado%type := 'S';
    g_msj                pas_snp.rg_msj;

    --declare
    /*CURSOR documentos IS
    SELECT to_number(nvl((((length(p_nro_documento) -
                         length(REPLACE(p_nro_documento, ',', ''))) /
                         length(',')) - 1),
                         0)) cantidad,
           substr(p_nro_documento, 2, length(p_nro_documento) - 2) ref_oid
      FROM dual;*/
  begin
    pas_snp.pr_ini_registros;

    --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
    pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
    --
    v_cod_moneda := p_cod_moneda;
    v_cod_moneda := CASE v_cod_moneda
                      WHEN pas_snp.g_cod_mon_iso_local THEN
                       pas_snp.g_cod_mon_local
                      ELSE
                       v_cod_moneda
                    END;

    v_monto := p_monto;

    -- BIC
    if fug_es_produccion = 'S' then
      v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'D');
    else
      v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'T');
    end if;
    --

    -- Actualización de estado del título restringido
    /*IF p_nro_documento is NOT NULL THEN
    FOR reg in documentos loop
      FOR e IN 1 .. reg.cantidad LOOP
        v_nro_documento := pae_uti.fu_obt_valor(reg.ref_oid, e);*/

    /*SELECT m.nro_documento
      INTO v_nro_documento
      FROM md_cta_documentos m
     WHERE m.nro_cuenta = v_nro_cuenta;

    IF reg.cantidad > 1 then
      v_nro_doc := v_nro_doc ||
                   pae_uti.fu_obt_valor(v_nro_documento, e) || ',';

    ELSE
      v_nro_doc := v_nro_documento || ',';
    END IF;

    BEGIN
      UPDATE md_cta_documentos m
         SET m.estado = 'T'
       WHERE m.nro_cuenta = v_nro_cuenta;
    END;*/
    /*END LOOP;
      END LOOP;
    END IF;
    v_nro_doc := substr(v_nro_doc, 1, length(v_nro_doc) - 1);*/

    --v_nro_documento := substr(v_nro_documento, 2, length(v_nro_documento) - 2);
    if v_monto > 0 then

      pas_dep.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         'CAB',
                                         '{1:F01' || rpad(g_usu_depo, /*pas_snp.g_usu_xadapter*/
                                                          12,
                                                          'X') || '}' ||
                                         '{2:I986' ||
                                         rpad(v_bic_sis_depo, 12, 'X') || 'N}' ||
                                         '{3:{113' || ':' ||
                                         lpad('30', 4, '0') || '}}{4:');
      -- Detalle
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '20',
                                         v_nro_referencia);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '21', 'NONREF');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '59',
                                         '/' ||
                                        -- pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                          --                                   v_cod_moneda)
                                          --fu_obt_cta_depo(v_cod_moneda)
                                          fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ')
                                          );
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '59',
                                         pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'ILFR/' ||
                                         to_char(sysdate, 'YYYYMMDDHH24MI'));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'RA' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'SD' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'SC' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'ED' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(v_monto,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'EC' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'LD' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'LC' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'CC' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '79',
                                         'AC' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(0,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');

      begin
        pas_dep.g_lugar := 'Creando la mensajería, ';
        pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);

        --
        if p_nro_referencia is null then
          --
          insert into sb_snp_mensajes
            (cod_mensaje,
             nro_referencia,
             nro_lote,
             orden,
             nro_linea,
             campo,
             valor,
             descripcion,
             ind_requerido,
             nro_detalle,
             err_formato,
             err_validacion)
            (select cod_mensaje,
                    v_nro_referencia,
                    null,
                    orden,
                    nro_linea,
                    campo,
                    valor,
                    descripcion,
                    ind_requerido,
                    nro_detalle,
                    err_formato,
                    err_validacion
               from sb_snp_mensajes_tmp
              where cod_mensaje = p_cod_tip_mensaje
                and valor is not null);
          --

          pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
          --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
          pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
          g_lugar := 'Conectándose al socket';
          -- Envia el mensaje al servidor
          pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                               p_puerto     => pas_dep.g_puerto,
                                               p_tie_espera => pas_dep.g_tie_espera,
                                               p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                               p_respuesta  => v_resp);
          if pas_dep.g_ok != 'S' THEN
            -- Hubo problema en el envio
            pas_snp.g_cod_error := 49;
            pas_snp.g_msj_error := v_resp;
            g_lugar             := 'Actualizando Error en el LOG, ';
            pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                             'A',
                                             'N',
                                             pas_snp.g_msj_error);
            raise ex_salir;
          else
            if substr(v_resp, 1, 2) = '00' then
              g_lugar     := 'Actualizando estado y situación';
              v_situacion := 'V';
              v_estado    := 'A';
            else
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                            v_resp,
                                            1,
                                            1000);
              raise ex_salir;
            end if;
          end if;
          --end if;
          --

          -- Obtiene la transacción hija de la Cta. Interbancaria según el tipo/subtipo de operación de GE_PAR_MENSAJES.
          g_lugar := 'Buscando Transacción de GE_PAR_MENSAJES, ';
          pas_snp.pr_obt_par_mensajes(v_cod_msj_swift,
                                      v_tip_operacion,
                                      v_sub_tip_operacion,
                                      'E',
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      v_cod_transaccion);

          begin
            -- Datos a registrar en GE_SNP_TRANSFERENCIAS
            pas_snp.g_msj.nro_referencia        := v_nro_referencia;
            pas_snp.g_msj.cod_modulo            := v_cod_modulo;
            pas_snp.g_msj.cod_modalidad         := v_cod_modalidad;
            pas_snp.g_msj.cod_oficina           := nvl(fug_obt_ofi_usuario(USER),
                                                       1); --v_cod_oficina;
            pas_snp.g_msj.fec_valor             := v_fec_valor;
            pas_snp.g_msj.fec_ingreso           := v_fecha;
            pas_snp.g_msj.fecha                 := v_fecha;
            pas_snp.g_msj.hora                  := to_char(sysdate,
                                                           'HH24:MI:SS');
            pas_snp.g_msj.cod_usuario           := USER;
            pas_snp.g_msj.nro_operacion         := v_nro_referencia;
            pas_snp.g_msj.cod_moneda            := v_cod_moneda;
            pas_snp.g_msj.cod_tip_operacion     := v_tip_operacion;
            pas_snp.g_msj.cod_sub_tip_operacion := v_sub_tip_operacion;
            pas_snp.g_msj.monto                 := v_monto;
            pas_snp.g_msj.ref_oid               := p_nro_documento; --v_nro_documento;

            --
            pas_snp.g_msj.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
            pas_snp.g_msj.nro_cta_pte_solicitante  := fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ'); --fu_obt_cta_depo(v_cod_moneda);
            --pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
              --                                                                            v_cod_moneda);
            pas_snp.g_msj.cod_swi_pte_beneficiario := fug_obt_pardinamico('SNP_BIC_BCP');
            pas_snp.g_msj.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                                                          v_cod_moneda);

            pas_snp.g_msj.concepto      := pas_snp.fu_val_cadena(nvl(v_concepto,
                                                                     v_con_movimiento));
            pas_snp.g_msj.cod_msj_swift := v_cod_msj_swift;
            pas_snp.g_msj.msj_swift     := v_mensaje;
            pas_snp.g_msj.ind_valor     := v_ind_valor;
            pas_snp.g_msj.prioridad     := v_prioridad;
            pas_snp.g_msj.situacion     := v_situacion;
            pas_snp.g_msj.estado        := v_estado;
            pas_snp.g_msj.origen        := 'I';
            pas_snp.g_msj.plataforma    := 'D';
            pas_snp.g_msj.indemnizado   := 'N';
            pas_snp.g_msj.observacion   := 'N';

            pas_dep.g_lugar := 'Insertando Mensajería.., ';
            pas_snp.pr_ins_transferencias(pas_snp.g_msj);
            if pas_snp.fu_obt_cod_error <> 0 then
              raise_application_error(-20001, pas_dep.fu_obt_msj_error);
            end if;
          end;

          /*if nvl(fug_obt_pardinamico('SIB_SNP_VER_WORKFLOW'), 'N') = 'S' THEN
            pas_snp.pr_ini_workflow(pas_snp.g_msj);
          end if;*/

          -- Operación de mesa de dinero.
          if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
            NULL; --Actualiza montos de letras en Mesa--prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda);
          end if;
          --else
          -- Si se actualiza el monto o tasa manualmente
          -- Se actualiza también el estado y la situación

          pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
          --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
          --pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
          g_lugar := 'Conectándose al socket';
          -- Envia el mensaje al servidor
          /*pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                               p_puerto     => pas_dep.g_puerto,
                                               p_tie_espera => pas_dep.g_tie_espera,
                                               p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                               p_respuesta  => v_resp);
          if pas_dep.g_ok != 'S' THEN
            -- Hubo problema en el envio
            pas_snp.g_cod_error := 49;
            pas_snp.g_msj_error := v_resp;
            g_lugar             := 'Actualizando Error en el LOG, ';
            pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                             'A',
                                             'N',
                                             pas_snp.g_msj_error);
            raise ex_salir;
          else
            if substr(v_resp, 1, 2) = '00' then
              g_lugar     := 'Actualizando estado y situación';
              BEGIN
                UPDATE ge_snp_transferencias
                   SET situacion = 'V',
           estado    = 'A'
                 WHERE nro_referencia = p_nro_referencia;
              END;
            else
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                            v_resp,
                                            1,
                                            1000);
              raise ex_salir;
            end if;
          end if;*/
          --end if;
          --

          -- Operación de mesa de dinero.
          if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
            NULL; --prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda, p_monto, p_tasa);
          end if;
          --
          /*else
          NULL;*/
          -- Se cancela la operación Depo
          /*BEGIN
            UPDATE ge_snp_transferencias
               SET situacion = 'C', estado = 'C'
             WHERE nro_referencia = p_nro_referencia;
          END;
          -- Se elimina la operación de Compra
          BEGIN
            DELETE md_cta_documentos c
             WHERE c.nro_documento = p_nro_referencia
               AND trunc(c.fec_insercion) = trunc(sysdate);
          END;*/
        end if;
        --end if;
      exception
        when others then
          pas_dep.g_cod_error := 90;
          pas_dep.g_msj_error := 'Error insertando en GE_SNP_TRANSFERENCIAS: ' ||
                                 pas_dep.g_lugar || ' ' || SQLERRM;
      end;
    end if;
  exception
    when others then
      pas_dep.g_cod_error := 91;
      pas_dep.g_msj_error := 'Error al Generar MT: ' || pas_dep.g_lugar || ' ' ||
                             SQLERRM;
  end pr_obt_msj_mt986;

  /*Genera MT595*/
  PROCEDURE pr_obt_msj_MT595(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT595',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in md_cta_documentos.nro_documento%type,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N') is

    v_nro_referencia ge_snp_mensajes.nro_referencia%type /* := pas_snp.fu_obt_sig_nro_referencia*/
    ;
    v_mensaje        ge_snp_mensajes.msj_swift%type;
    v_cod_moneda     ba_monedas.cod_moneda%type;
    v_monto          ge_snp_transferencias.monto%type;
    v_tasa           varchar2(20);

    v_fecha              ge_snp_transferencias.fecha%type := pas_snp.g_fec_actual;
    v_fec_valor          ge_snp_transferencias.fec_valor%type := trunc(sysdate);
    v_cod_msj_swift      ge_snp_transferencias.cod_msj_swift%type := '595';
    v_tip_operacion      ge_snp_transferencias.cod_tip_operacion%type := '001';
    v_sub_tip_operacion  ge_snp_transferencias.cod_sub_tip_operacion%type := '001';
    v_ind_valor          ge_snp_transferencias.ind_valor%type := 'S';
    v_nro_cta_benef      ge_snp_transferencias.nro_cta_beneficiario%type;
    v_prioridad          ge_snp_transferencias.prioridad%type := 11;
    v_nro_cta_sol        ge_cuentas.nro_cuenta%type;
    v_cod_modulo         ba_modulos.cod_modulo%type;
    v_cod_modalidad      ge_modalidades.cod_modalidad%type;
    v_cod_oficina        ba_oficinas.cod_oficina%type;
    v_concepto           ge_movimientos.concepto%type;
    v_con_movimiento     ge_movimientos.concepto%type;
    v_cod_persona        ba_personas.cod_persona%type;
    v_cod_transaccion    ge_transacciones.cod_transaccion%type;
    v_resp               varchar2(4000) := null;
    v_cta_bancaria       cc_cta_bancarias.nro_cuenta%TYPE;
    v_nro_secuencia      NUMBER := 0;
    v_ind_transaccion    VARCHAR2(1) := 'R';
    v_hora               VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_cod_tra_padre      ge_transacciones.cod_transaccion%TYPE := 303;
    v_tip_movimiento     ge_transacciones.tipo%TYPE;
    v_opcion             NUMBER;
    v_return             NUMBER;
    v_des_tip_movimiento VARCHAR2(60);
    v_nro_documento      VARCHAR2(60);
    v_nro_ref_986        VARCHAR2(60); --ge_snp_mensajes.nro_referencia%type;
    v_bic_sis_depo       varchar2(20);
    v_situacion          ge_snp_transferencias.situacion%type := 'P';
    v_estado             ge_snp_transferencias.estado%type := 'S';
    g_msj                pas_snp.rg_msj;

    --declare
    cursor recompra is
      SELECT to_number(nvl((((length(p_nro_documento) -
                           length(REPLACE(p_nro_documento, ',', ''))) /
                           length(',')) - 1),
                           0)) cantidad,
             substr(p_nro_documento, 2, length(p_nro_documento) - 2) ref_oid
        FROM dual;
    /*select to_number(nvl((((length(ref_oid) -
                       length(REPLACE(ref_oid, ',', ''))) / length(',')) - 1),
                       0)) cantidad,
          substr(ref_oid, 2, length(ref_oid) - 2) ref_oid,
          nro_referencia
     from ge_snp_transferencias ge
    where ge.cod_msj_swift = '986'
      and ge.fec_recepcion is null
      and ge.fecha = pag_cal.fu_obt_fec_actual(1)
      and ge.estado = 'A'
      and ge.situacion = 'L';*/
    --and ge.nro_referencia = p_nro_documento;

  begin
    IF p_nro_documento is NOT NULL THEN
      FOR reg in recompra loop
        FOR e IN 1 .. reg.cantidad LOOP
          v_nro_documento := pae_uti.fu_obt_valor(reg.ref_oid, e);

          select m.nro_referencia
            into v_nro_ref_986
            from ge_snp_mensajes m
           where m.cod_msj_swift = '543'
             and m.fec_valor = pag_cal.fu_obt_fec_actual(1)
             and m.nro_ref_externa = v_nro_documento;

          pas_snp.pr_ini_registros;

          --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
          pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
          --
          v_cod_moneda := p_cod_moneda;
          v_cod_moneda := CASE v_cod_moneda
                            WHEN pas_snp.g_cod_mon_iso_local THEN
                             pas_snp.g_cod_mon_local
                            ELSE
                             v_cod_moneda
                          END;

          v_monto := p_monto;

          -- BIC
          if fug_es_produccion = 'S' then
            v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'D');
          else
            v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'T');
          end if;
          --
          if v_monto > 0 then

            v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia;

            pas_dep.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                               'CAB',
                                               '{1:F01' ||
                                               rpad(g_usu_depo, 12, 'X') || '}' ||
                                               '{2:I595' ||
                                               rpad(v_bic_sis_depo, 12, 'X') || 'N}' ||
                                               '{3:{113' || ':' ||
                                               lpad('30', 4, '0') ||
                                               '}}{4:');
            -- Detalle
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                               '20',
                                               v_nro_referencia);
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                               '21',
                                               v_nro_ref_986);
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                               '75',
                                               'BBRQ');
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                               '11S',
                                               '543');
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                               '11S',
                                               to_char(sysdate, 'YYMMDD'));
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                               'PIE',
                                               '-}');

            begin
              pas_dep.g_lugar := 'Creando la mensajería, ';
              pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);

              --
              if p_nro_referencia is null then
                --
                insert into sb_snp_mensajes
                  (cod_mensaje,
                   nro_referencia,
                   nro_lote,
                   orden,
                   nro_linea,
                   campo,
                   valor,
                   descripcion,
                   ind_requerido,
                   nro_detalle,
                   err_formato,
                   err_validacion)
                  (select cod_mensaje,
                          v_nro_referencia,
                          null,
                          orden,
                          nro_linea,
                          campo,
                          valor,
                          descripcion,
                          ind_requerido,
                          nro_detalle,
                          err_formato,
                          err_validacion
                     from sb_snp_mensajes_tmp
                    where cod_mensaje = p_cod_tip_mensaje
                      and valor is not null);
                --

                pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
                --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
                pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                                 'I',
                                                 'N');
                g_lugar := 'Conectándose al socket';
                -- Envia el mensaje al servidor
                pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                                     p_puerto     => pas_dep.g_puerto,
                                                     p_tie_espera => pas_dep.g_tie_espera,
                                                     p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                                     p_respuesta  => v_resp);
                if pas_dep.g_ok != 'S' THEN
                  -- Hubo problema en el envio
                  pas_snp.g_cod_error := 49;
                  pas_snp.g_msj_error := v_resp;
                  g_lugar             := 'Actualizando Error en el LOG, ';
                  pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                                   'A',
                                                   'N',
                                                   pas_snp.g_msj_error);
                  raise ex_salir;
                else
                  if substr(v_resp, 1, 2) = '00' then
                    g_lugar     := 'Actualizando estado y situación';
                    v_situacion := 'V';
                    v_estado    := 'A';
                  else
                    pas_snp.g_cod_error := 49;
                    pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                                  v_resp,
                                                  1,
                                                  1000);
                    raise ex_salir;
                  end if;
                end if;
                --end if;
                --

                -- Obtiene la transacción hija de la Cta. Interbancaria según el tipo/subtipo de operación de GE_PAR_MENSAJES.
                g_lugar := 'Buscando Transacción de GE_PAR_MENSAJES, ';
                pas_snp.pr_obt_par_mensajes(v_cod_msj_swift,
                                            v_tip_operacion,
                                            v_sub_tip_operacion,
                                            'E',
                                            v_cod_modulo,
                                            v_cod_modalidad,
                                            v_cod_transaccion);

                begin
                  -- Datos a registrar en GE_SNP_TRANSFERENCIAS
                  pas_snp.g_msj.nro_referencia        := v_nro_referencia;
                  pas_snp.g_msj.nro_ref_externa       := v_nro_ref_986;
                  pas_snp.g_msj.cod_modulo            := v_cod_modulo;
                  pas_snp.g_msj.cod_modalidad         := v_cod_modalidad;
                  pas_snp.g_msj.cod_oficina           := nvl(fug_obt_ofi_usuario(USER),
                                                             1); --v_cod_oficina;
                  pas_snp.g_msj.fec_valor             := v_fec_valor;
                  pas_snp.g_msj.fec_ingreso           := v_fecha;
                  pas_snp.g_msj.fecha                 := v_fecha;
                  pas_snp.g_msj.hora                  := to_char(sysdate,
                                                                 'HH24:MI:SS');
                  pas_snp.g_msj.cod_usuario           := USER;
                  pas_snp.g_msj.nro_operacion         := v_nro_referencia;
                  pas_snp.g_msj.cod_moneda            := v_cod_moneda;
                  pas_snp.g_msj.cod_tip_operacion     := v_tip_operacion;
                  pas_snp.g_msj.cod_sub_tip_operacion := v_sub_tip_operacion;
                  pas_snp.g_msj.monto                 := v_monto;
                  pas_snp.g_msj.ref_oid               := v_nro_documento;

                  --
                  pas_snp.g_msj.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
                  pas_snp.g_msj.nro_cta_pte_solicitante  := fu_obt_cta_depo(v_cod_moneda);-- pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                                                          --      v_cod_moneda);
                  pas_snp.g_msj.cod_swi_pte_beneficiario := fug_obt_pardinamico('SNP_BIC_BCP');
                  pas_snp.g_msj.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                                                                v_cod_moneda);

                  pas_snp.g_msj.concepto      := pas_snp.fu_val_cadena(nvl(v_concepto,
                                                                           v_con_movimiento));
                  pas_snp.g_msj.cod_msj_swift := v_cod_msj_swift;
                  pas_snp.g_msj.msj_swift     := v_mensaje;
                  pas_snp.g_msj.ind_valor     := v_ind_valor;
                  pas_snp.g_msj.prioridad     := v_prioridad;
                  pas_snp.g_msj.situacion     := v_situacion;
                  pas_snp.g_msj.estado        := v_estado;
                  pas_snp.g_msj.origen        := 'I';
                  pas_snp.g_msj.plataforma    := 'D';
                  pas_snp.g_msj.indemnizado   := 'N';

                  pas_dep.g_lugar := 'Insertando Mensajería.., ';
                  pas_snp.pr_ins_transferencias(pas_snp.g_msj);
                  if pas_snp.fu_obt_cod_error <> 0 then
                    raise_application_error(-20001,
                                            pas_dep.fu_obt_msj_error);
                  end if;
                end;

                /*if nvl(fug_obt_pardinamico('SIB_SNP_VER_WORKFLOW'), 'N') = 'S' THEN
                  pas_snp.pr_ini_workflow(pas_snp.g_msj);
                end if;*/

                -- Operación de mesa de dinero.
                if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
                  NULL; --Actualiza montos de letras en Mesa--prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda);
                end if;
                --else
                -- Si se actualiza el monto o tasa manualmente
                -- Se actualiza también el estado y la situación

                pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
                --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
                --pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
                g_lugar := 'Conectándose al socket';
                -- Envia el mensaje al servidor
                /*pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                                     p_puerto     => pas_dep.g_puerto,
                                                     p_tie_espera => pas_dep.g_tie_espera,
                                                     p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                                     p_respuesta  => v_resp);
                if pas_dep.g_ok != 'S' THEN
                  -- Hubo problema en el envio
                  pas_snp.g_cod_error := 49;
                  pas_snp.g_msj_error := v_resp;
                  g_lugar             := 'Actualizando Error en el LOG, ';
                  pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                                   'A',
                                                   'N',
                                                   pas_snp.g_msj_error);
                  raise ex_salir;
                else
                  if substr(v_resp, 1, 2) = '00' then
                    g_lugar     := 'Actualizando estado y situación';
                    BEGIN
                      UPDATE ge_snp_transferencias
                         SET situacion = 'V',
                 estado    = 'A'
                       WHERE nro_referencia = p_nro_referencia;
                    END;
                  else
                    pas_snp.g_cod_error := 49;
                    pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                                  v_resp,
                                                  1,
                                                  1000);
                    raise ex_salir;
                  end if;
                end if;*/
                --end if;
                --

                -- Operación de mesa de dinero.
                if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
                  NULL; --prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda, p_monto, p_tasa);
                end if;
                --
                /*else
                NULL;*/
                -- Se cancela la operación Depo
                /*BEGIN
                  UPDATE ge_snp_transferencias
                     SET situacion = 'C', estado = 'C'
                   WHERE nro_referencia = p_nro_referencia;
                END;
                -- Se elimina la operación de Compra
                BEGIN
                  DELETE md_cta_documentos c
                   WHERE c.nro_documento = p_nro_referencia
                     AND trunc(c.fec_insercion) = trunc(sysdate);
                END;*/
              end if;
              --end if;
            exception
              when others then
                pas_dep.g_cod_error := 90;
                pas_dep.g_msj_error := 'Error insertando en GE_SNP_TRANSFERENCIAS: ' ||
                                       pas_dep.g_lugar || ' ' || SQLERRM;
            end;
          end if;
        END LOOP;
      END LOOP;
    END IF;
  exception
    when others then
      pas_dep.g_cod_error := 91;
      pas_dep.g_msj_error := 'Error al Generar MT: ' || pas_dep.g_lugar || ' ' ||
                             SQLERRM;
  end pr_obt_msj_mt595;

  /*Genera MT542*/
  PROCEDURE pr_obt_msj_MT542(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT542',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_nro_documento   in md_cta_documentos.nro_documento%type,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N') is

    v_nro_referencia ge_snp_mensajes.nro_referencia%type /* := pas_snp.fu_obt_sig_nro_referencia*/
    ;
    v_mensaje        ge_snp_mensajes.msj_swift%type;
    v_cod_moneda     ba_monedas.cod_moneda%type;
    v_monto          ge_snp_transferencias.monto%type;
    v_tasa           varchar2(20);

    v_fecha              ge_snp_transferencias.fecha%type := pas_snp.g_fec_actual;
    v_fec_valor          ge_snp_transferencias.fec_valor%type := trunc(sysdate);
    v_cod_msj_swift      ge_snp_transferencias.cod_msj_swift%type := '542';
    v_tip_operacion      ge_snp_transferencias.cod_tip_operacion%type := '001';
    v_sub_tip_operacion  ge_snp_transferencias.cod_sub_tip_operacion%type := '001';
    v_ind_valor          ge_snp_transferencias.ind_valor%type := 'S';
    v_nro_cta_benef      ge_snp_transferencias.nro_cta_beneficiario%type;
    v_prioridad          ge_snp_transferencias.prioridad%type := 11;
    v_nro_cta_sol        ge_cuentas.nro_cuenta%type;
    v_cod_modulo         ba_modulos.cod_modulo%type;
    v_cod_modalidad      ge_modalidades.cod_modalidad%type;
    v_cod_oficina        ba_oficinas.cod_oficina%type;
    v_concepto           ge_movimientos.concepto%type;
    v_con_movimiento     ge_movimientos.concepto%type;
    v_cod_persona        ba_personas.cod_persona%type;
    v_cod_transaccion    ge_transacciones.cod_transaccion%type;
    v_resp               varchar2(4000) := null;
    v_cta_bancaria       cc_cta_bancarias.nro_cuenta%TYPE;
    v_nro_secuencia      NUMBER := 0;
    v_ind_transaccion    VARCHAR2(1) := 'R';
    v_hora               VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_cod_tra_padre      ge_transacciones.cod_transaccion%TYPE := 303;
    v_tip_movimiento     ge_transacciones.tipo%TYPE;
    v_opcion             NUMBER;
    v_return             NUMBER;
    v_des_tip_movimiento VARCHAR2(60);
    v_nro_documento      VARCHAR2(60);
    v_nro_ref_986        VARCHAR2(60); --ge_snp_mensajes.nro_referencia%type;
    v_bic_sis_depo       varchar2(20);
    v_situacion          ge_snp_transferencias.situacion%type := 'P';
    v_estado             ge_snp_transferencias.estado%type := 'S';
    g_msj                pas_snp.rg_msj;

    --proceso documento por documento del string concatenado si tuviera mas de 1
    cursor repo is
      WITH datos AS (
                     SELECT p_nro_documento AS nro_doc
                       FROM dual)
      SELECT REGEXP_SUBSTR(nro_doc, '[^,]+', 1, LEVEL) AS nro_documento
        FROM datos
     CONNECT BY LEVEL <= REGEXP_COUNT(nro_doc, ',') - 1;

  begin
  -- En p_nro_documento se reciben los FLI seleccionados.
  --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'p_nro_documento: '||p_nro_documento||
                                        ' | p_nro_referencia: '||p_nro_referencia,
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

    IF p_nro_documento is NOT NULL THEN

      FOR reg in repo loop
      v_nro_documento := reg.nro_documento;
      --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                          P_DET_ERROR    => 'Loop v_nro_documento: '||v_nro_documento,
                          P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

      select m.nro_referencia,
             t.monto,
             t.cod_moneda
        into v_nro_ref_986,
             v_monto,
             v_cod_moneda
        from ge_snp_mensajes m,
             ge_snp_transferencias t
       where m.cod_msj_swift = '543'
         and m.fec_valor = pag_cal.fu_obt_fec_actual(1)-- '07/05/2025'--
         and m.nro_ref_externa = t.nro_referencia
         and m.nro_ref_externa = v_nro_documento;

      --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                          P_DET_ERROR    => 'Loop v_nro_ref_986: '||v_nro_ref_986||
                                            ' | v_monto: '||v_monto||
                                            ' | v_cod_moneda: '||v_cod_moneda,
                          P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

      pas_snp.pr_ini_registros;

      --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
      pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
      --

      if v_cod_moneda is null then
         v_cod_moneda := p_cod_moneda;
      end if;

      v_cod_moneda := CASE v_cod_moneda
                        WHEN pas_snp.g_cod_mon_iso_local THEN
                         pas_snp.g_cod_mon_local
                        ELSE
                         v_cod_moneda
                      END;

      if v_monto is null then
         v_monto := p_monto;
      end if;

      -- BIC
      if fug_es_produccion = 'S' then
        v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'D');
      else
        v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'T');
      end if;
      --

      --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                          P_DET_ERROR    => 'Loop v_cod_moneda: '||v_cod_moneda||
                                            ' | v_bic_sis_depo: '||v_bic_sis_depo||
                                            ' | v_monto: '||v_monto,
                          P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

      if v_monto > 0 then

        v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia;

        pas_dep.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
          --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Loop v_nro_referencia: '||v_nro_referencia,
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           'CAB',
                                           '{1:F01' ||
                                           rpad(g_usu_depo, 12, 'X') || '}' ||
                                           '{2:I542' ||
                                           rpad(v_bic_sis_depo, 12, 'X') || 'N}' ||
                                           '{3:{113' || ':' ||
                                           lpad('30', 4, '0') ||
                                           '}}{4:');
        -- Detalle
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'GENL');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '20C',
                                           ':SEME//' ||
                                           v_nro_referencia);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '23G',
                                           'NEWM');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '98C',
                                           ':PREP//' ||
                                           to_char(sysdate,
                                                   'YYYYMMDDHH24MISS'));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'LINK');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '13A',
                                           ':LINK//543');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '20C',
                                           ':PREV//' || v_nro_ref_986);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'LINK');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'LINK');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '20C',
                                           ':COMM//' ||
                                           v_nro_referencia);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'LINK');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           ':16S:GENL');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'TRADDET');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '94B',
                                           ':TRAD//OTCO');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '98A',
                                           ':SETT//' ||
                                           to_char(SYSDATE, 'YYYYMMDD'));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '35B',
                                           '/XX/ILF');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'FIA');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '12A',
                                           ':CLAS//ILF');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'FIA');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           ':16S:TRADDET');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'FIAC');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '36B',
                                           ':SETT//UNIT/' ||
                                           trim(to_char(round(v_monto),
                                                        pas_snp.fu_obt_mascara ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                     p_cod_moneda => v_cod_moneda),
                                                                 2),
                                                             '9'))));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '97A',
                                           ':SAFE//' ||
                                           substr(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                  1,
                                                  4) || '/ILF');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'FIAC');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'REPO');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '98A',
                                           ':TERM//' ||
                                           to_char(pag_cal.fu_obt_fec_sig_hab(trunc(SYSDATE),
                                                                              1),
                                                   'YYYYMMDD'));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'REPO');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'SETDET');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '22F',
                                           ':SETR//REPU');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '22F',
                                           ':22F::STCO//DLWM');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '22F',
                                           ':22F::CCPT//YCCP');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '22F',
                                           ':22F::COLA//LIQU');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '22F',
                                           ':22F::REPT//ROLP');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '95Q',
                                           ':DEAG//' ||
                                           pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
        --pas_dep.fu_obt_bic_sis_depo);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '95Q',
                                           ':DECU//' ||
                                           pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) /*fug_obt_pardinamico('SNP_BIC_BCP')*/);
        --pas_dep.fu_obt_bic_sis_depo);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '97A',
                                           ':SAFE//' ||
                                           substr(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                  1,
                                                  4) || '/DEPO');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '95Q',
                                           ':SELL//' ||
                                           pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) /*fug_obt_pardinamico('SNP_BIC_BCP')*/);
        --pas_dep.fu_obt_bic_sis_depo);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '97A',
                                           ':SAFE//RSTR/' ||
                                           substr(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                  1,
                                                  4) || '/DEPO/DEPO');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '95Q',
                                           ':REAG//' ||
                                           fug_obt_pardinamico('SNP_BIC_BCP') /*pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad)*/);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '95Q',
                                           ':RECU//' ||
                                           fug_obt_pardinamico('SNP_BIC_BCP') /*pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad)*/);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '97A',
                                           ':SAFE//' ||
                                           substr(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                  1,
                                                  4) || '/ILF');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '95Q',
                                           ':BUYR//' ||
                                           fug_obt_pardinamico('SNP_BIC_BCP') /*pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad)*/);
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '97A',
                                           ':SAFE//BORR/' ||
                                           substr(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                  1,
                                                  4) || '/ILF/ILF');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'SETPRTY');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16R',
                                           'AMT');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '19A',
                                           ':DEAL//' ||
                                           pas_snp.g_cod_mon_iso_local ||
                                           trim(to_char(v_monto,
                                                        pas_snp.fu_obt_mascara ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                     p_cod_moneda => v_cod_moneda),
                                                                 2),
                                                             '9'))));
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           'AMT');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           '16S',
                                           ':16S:SETDET');
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                           'PIE',
                                           '-}');

          --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Escribió archivo en tabla temporal.',
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        begin
          pas_dep.g_lugar := 'Creando la mensajería, ';
          pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);

          --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Mensaje guardado en v_mensaje: '||v_mensaje,
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

          -- Comentar y volver a probar
--          if p_nro_referencia is null then
            --
            insert into sb_snp_mensajes
              (cod_mensaje,
               nro_referencia,
               nro_lote,
               orden,
               nro_linea,
               campo,
               valor,
               descripcion,
               ind_requerido,
               nro_detalle,
               err_formato,
               err_validacion)
              (select cod_mensaje,
                      v_nro_referencia,
                      null,
                      orden,
                      nro_linea,
                      campo,
                      valor,
                      descripcion,
                      ind_requerido,
                      nro_detalle,
                      err_formato,
                      err_validacion
                 from sb_snp_mensajes_tmp
                where cod_mensaje = p_cod_tip_mensaje
                  and valor is not null);
            --

          --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Mensaje insertado sb_snp_mensajes',
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

            pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
            --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
            pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                             'I',
                                             'N');
            g_lugar := 'Conectándose al socket';
            -- Envia el mensaje al servidor
            pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                                 p_puerto     => pas_dep.g_puerto,
                                                 p_tie_espera => pas_dep.g_tie_espera,
                                                 p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                                 p_respuesta  => v_resp);
          --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Enviando al servidor',
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
            if pas_dep.g_ok != 'S' THEN
              -- Hubo problema en el envio
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'N',
                                               pas_snp.g_msj_error);
              raise ex_salir;
            else
              if substr(v_resp, 1, 2) = '00' then
                g_lugar     := 'Actualizando estado y situación';
                v_situacion := 'V';
                v_estado    := 'A';
              else
                pas_snp.g_cod_error := 49;
                pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                              v_resp,
                                              1,
                                              1000);
                raise ex_salir;
              end if;
            end if;
            --end if;
            --
            -- Obtiene la transacción hija de la Cta. Interbancaria según el tipo/subtipo de operación de GE_PAR_MENSAJES.

                      --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Buscando Transacción de GE_PAR_MENSAJES',
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

            g_lugar := 'Buscando Transacción de GE_PAR_MENSAJES, ';
            pas_snp.pr_obt_par_mensajes(v_cod_msj_swift,
                                        v_tip_operacion,
                                        v_sub_tip_operacion,
                                        'E',
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        v_cod_transaccion);

            begin

              --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Datos a registrar en GE_SNP_TRANSFERENCIAS',
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
              -- Datos a registrar en GE_SNP_TRANSFERENCIAS
              pas_snp.g_msj.nro_referencia        := v_nro_referencia;
              pas_snp.g_msj.cod_modulo            := v_cod_modulo;
              pas_snp.g_msj.cod_modalidad         := v_cod_modalidad;
              pas_snp.g_msj.cod_oficina           := nvl(fug_obt_ofi_usuario(USER),
                                                         1); --v_cod_oficina;
              pas_snp.g_msj.fec_valor             := v_fec_valor;
              pas_snp.g_msj.fec_ingreso           := v_fecha;
              pas_snp.g_msj.fecha                 := v_fecha;
              pas_snp.g_msj.hora                  := to_char(sysdate,
                                                             'HH24:MI:SS');
              pas_snp.g_msj.cod_usuario           := USER;
              pas_snp.g_msj.nro_operacion         := v_nro_referencia;
              pas_snp.g_msj.cod_moneda            := v_cod_moneda;
              pas_snp.g_msj.cod_tip_operacion     := v_tip_operacion;
              pas_snp.g_msj.cod_sub_tip_operacion := v_sub_tip_operacion;
              pas_snp.g_msj.monto                 := v_monto;
              pas_snp.g_msj.ref_oid               := v_tasa;

              --
              pas_snp.g_msj.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
              pas_snp.g_msj.nro_cta_pte_solicitante  :=  fu_obt_cta_depo(v_cod_moneda);--pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                        --                                    v_cod_moneda);
              pas_snp.g_msj.cod_swi_pte_beneficiario := fug_obt_pardinamico('SNP_BIC_BCP');
              pas_snp.g_msj.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                                                            v_cod_moneda);

              pas_snp.g_msj.concepto      := pas_snp.fu_val_cadena(nvl(v_concepto,
                                                                       v_con_movimiento));
              pas_snp.g_msj.cod_msj_swift := v_cod_msj_swift;
              pas_snp.g_msj.msj_swift     := v_mensaje;
              pas_snp.g_msj.ind_valor     := v_ind_valor;
              pas_snp.g_msj.prioridad     := v_prioridad;
              pas_snp.g_msj.situacion     := v_situacion;
              pas_snp.g_msj.estado        := v_estado;
              pas_snp.g_msj.origen        := 'I';
              pas_snp.g_msj.plataforma    := 'D';
              pas_snp.g_msj.indemnizado   := 'N';

              pas_dep.g_lugar := 'Insertando Mensajería.., ';
                --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Insertando Mensajería..,',
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
              pas_snp.pr_ins_transferencias(pas_snp.g_msj);
              if pas_snp.fu_obt_cod_error <> 0 then
                raise_application_error(-20001,
                                        pas_dep.fu_obt_msj_error);
              end if;
            end;

            /*if nvl(fug_obt_pardinamico('SIB_SNP_VER_WORKFLOW'), 'N') = 'S' THEN
              pas_snp.pr_ini_workflow(pas_snp.g_msj);
            end if;*/

            -- Operación de mesa de dinero.
            if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
              NULL; --Actualiza montos de letras en Mesa--prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda);
            end if;
            --else
            -- Si se actualiza el monto o tasa manualmente
            -- Se actualiza también el estado y la situación

            --
            /*else
            NULL;*/
            -- Se cancela la operación Depo
            /*BEGIN
              UPDATE ge_snp_transferencias
                 SET situacion = 'C', estado = 'C'
               WHERE nro_referencia = p_nro_referencia;
            END;
            -- Se elimina la operación de Compra
            BEGIN
              DELETE md_cta_documentos c
               WHERE c.nro_documento = p_nro_referencia
                 AND trunc(c.fec_insercion) = trunc(sysdate);
            END;*/
--          end if;
          --end if;
        exception
          when others then
            pas_dep.g_cod_error := 90;
            pas_dep.g_msj_error := 'Error insertando en GE_SNP_TRANSFERENCIAS: ' ||
                                   pas_dep.g_lugar || ' ' || SQLERRM;
            --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Error insertando en GE_SNP_TRANSFERENCIAS: ' ||
                                   pas_dep.g_lugar || ' ' || SQLERRM,
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        end;
      end if;
      END LOOP;
    END IF;
       --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                      P_DET_ERROR    => 'Fin OK',
                      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
  exception
    when others then
      pas_dep.g_cod_error := 91;
      pas_dep.g_msj_error := 'Error al Generar MT: ' || pas_dep.g_lugar || ' ' ||
                             SQLERRM;

      --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.pr_obt_msj_MT542',
                          P_DET_ERROR    => 'Error al Generar MT: ' || pas_dep.g_lugar || ' ' || SQLERRM,
                          P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

  end pr_obt_msj_mt542;

  /*Genera MT541*/
  PROCEDURE pr_obt_msj_MT541(p_cod_tip_mensaje in sb_snp_tip_mensajes.cod_mensaje%type default 'MT541',
                             p_cod_moneda      in sb_snp_lim_depo.cod_moneda%type default pag_gen.FU_OBT_MON_LOCAL,
                             p_monto           in sb_snp_lim_depo.monto%type default 0,
                             p_tasa            in sb_snp_lim_depo.tasa%type default 0,
                             p_nro_referencia  in ge_snp_transferencias.nro_referencia%type default NULL,
                             p_cancela         in ge_snp_transferencias.estado%type default 'N') is
    v_nro_referencia     ge_snp_mensajes.nro_referencia%type := pas_snp.fu_obt_sig_nro_referencia;
    v_mensaje            ge_snp_mensajes.msj_swift%type;
    v_cod_moneda         ba_monedas.cod_moneda%type;
    v_monto              ge_snp_transferencias.monto%type;
    v_tasa               varchar2(20);
    v_fecha              ge_snp_transferencias.fecha%type := pas_snp.g_fec_actual;
    v_fec_valor          ge_snp_transferencias.fec_valor%type := trunc(sysdate);
    v_cod_msj_swift      ge_snp_transferencias.cod_msj_swift%type := '541';
    v_tip_operacion      ge_snp_transferencias.cod_tip_operacion%type := '001';
    v_sub_tip_operacion  ge_snp_transferencias.cod_sub_tip_operacion%type := '001';
    v_ind_valor          ge_snp_transferencias.ind_valor%type := 'S';
    v_nro_cta_benef      ge_snp_transferencias.nro_cta_beneficiario%type;
    v_prioridad          ge_snp_transferencias.prioridad%type := 11;
    v_nro_cta_sol        ge_cuentas.nro_cuenta%type;
    v_cod_modulo         ba_modulos.cod_modulo%type;
    v_cod_modalidad      ge_modalidades.cod_modalidad%type;
    v_cod_oficina        ba_oficinas.cod_oficina%type;
    v_concepto           ge_movimientos.concepto%type;
    v_con_movimiento     ge_movimientos.concepto%type;
    v_cod_persona        ba_personas.cod_persona%type;
    v_cod_transaccion    ge_transacciones.cod_transaccion%type;
    v_resp               varchar2(4000) := null;
    v_cta_bancaria       cc_cta_bancarias.nro_cuenta%TYPE;
    v_nro_secuencia      NUMBER := 0;
    v_ind_transaccion    VARCHAR2(1) := 'R';
    v_hora               VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_cod_tra_padre      ge_transacciones.cod_transaccion%TYPE := 303;
    v_tip_movimiento     ge_transacciones.tipo%TYPE;
    v_opcion             NUMBER;
    v_return             NUMBER;
    v_des_tip_movimiento VARCHAR2(60);
    v_bic_sis_depo       varchar2(20);
    v_situacion          ge_snp_transferencias.situacion%type := 'P';
    v_estado             ge_snp_transferencias.estado%type := 'S';
    g_msj                pas_snp.rg_msj;
    v_error              varchar2(4000);
    server               varchar2(100);
    puerto               varchar2(100);
    v_fec_termino        varchar2(10);
    v_tag_35B            varchar2(50);
    v_tag_12A            varchar2(50);
  begin
    pas_snp.pr_ini_registros;

    --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
    pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)

    --Se obtienen los datos para la operación Depo
    if p_monto = 0 then
      pr_obt_dat_depo(p_cod_moneda, v_monto, v_tasa);
    else
      v_cod_moneda     := p_cod_moneda;
      v_monto          := p_monto;
      v_tasa           := p_tasa;
      v_nro_referencia := p_nro_referencia;
    end if;
    --
    v_cod_moneda := p_cod_moneda;
    v_cod_moneda := CASE v_cod_moneda
                      WHEN pas_snp.g_cod_mon_iso_local THEN
                       pas_snp.g_cod_mon_local
                      ELSE
                       v_cod_moneda
                    END;

    --Obtenemos la cta por el cual se enviara el Deposito
    if fu_obt_cta_depo(v_cod_moneda) = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
      v_tag_35B := '/XX/DEPOSITO'||'IPS'||pas_snp.g_cod_mon_iso_local;
      v_tag_12A := ':CLAS//DEPO-IPS';
    elsif fu_obt_cta_depo(v_cod_moneda) = fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ') then
      v_tag_35B := '/XX/DEPOSITO'||pas_snp.g_cod_mon_iso_local;
      v_tag_12A := ':CLAS//DEPO-BCP';
    end if;  

    --BIC
    if fug_es_produccion = 'S' then
      v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'D');
    else
      v_bic_sis_depo := fue_obt_des_refcodes('SNP_BIC_SISTEMA', 'T');
    end if;
    --
    if v_monto > 0 then
     -- Restar del total a enviar la Reserva parametrizada
       if fug_obt_pardinamico('SNP_DEPO_MTO_RESERVA') is not null then
          v_monto := v_monto - nvl(fug_obt_pardinamico('SNP_DEPO_MTO_RESERVA'),0);
       end if;
       --
      pas_dep.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         'CAB',
                                         '{1:F01' || rpad(g_usu_depo,
                                                          12,
                                                          'X') || '}' ||
                                         '{2:I541' ||
                                         rpad(v_bic_sis_depo, 12, 'X') || 'N}' ||
                                         '{3:{113' || ':' ||
                                         lpad('30', 4, '0') || '}}{4:');
      -- Detalle
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16R', 'GENL');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '20C',
                                         ':SEME//' || v_nro_referencia);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '23G', 'NEWM');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '98C',
                                         ':PREP//' ||
                                         to_char(sysdate,
                                                 'YYYYMMDDHH24MISS'));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16R', 'LINK');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '20C',
                                         ':COMM//' || v_nro_referencia);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16S', 'LINK');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         ':16S:GENL');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'TRADDET');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '94B',
                                         ':TRAD//OTCO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '98A',
                                         ':SETT//' ||
                                         to_char(SYSDATE, 'YYYYMMDD'));
     /*pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,'35B','/XX/DEPOSITO' ||pas_snp.g_cod_mon_iso_local);*/
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,'35B',v_tag_35B);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16R', 'FIA');
      /*pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,'12A',':CLAS//DEPO-BCP');*/
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,'12A',v_tag_12A);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16S', 'FIA');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '22F',
                                         ':BORR//YBOR');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'TRADDET');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16R', 'FIAC');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '36B',
                                         ':SETT//UNIT/' ||
                                         trim(to_char(v_monto,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '97A',
                                         ':SAFE//' ||
                                         substr(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                1,
                                                4) || '/DEPO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16S', 'FIAC');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16R', 'REPO');

      if trim(to_char(pag_cal.fu_obt_fec_sig_hab(trunc(SYSDATE), 1),'DAY')) in ('SATURDAY', 'SABADO', 'SÁBADO') then
        v_fec_termino := to_char(pag_cal.fu_obt_fec_sig_hab(trunc(SYSDATE), 1, 2), 'YYYYMMDD');
      else
        v_fec_termino := to_char(pag_cal.fu_obt_fec_sig_hab(trunc(SYSDATE), 1), 'YYYYMMDD');
      end if;

      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '98A',
                                         ':TERM//' ||trim(v_fec_termino));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '92A',
                                         ':REPO//' || 
                                         case when (length(v_tasa-floor(v_tasa))-1) > 0 then
                                             case when v_tasa < 1 then
                                               trim('0'||to_char(v_tasa))
                                              else
                                                trim(to_char(v_tasa))
                                              end
                                         else
                                              trim(to_char(v_tasa, pas_snp.fu_obt_mascara))
                                         end


                                         /*trim(to_char(v_tasa,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                pas_snp.fu_obt_mascara ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                rpad('9',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_cod_moneda => v_cod_moneda),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         2),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     '9')))*/);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '70C',
                                         ':SECO//TERM');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16S', 'REPO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'SETDET');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '22F',
                                         ':STCO//DLWM');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '22F',
                                         ':22F::SETR//RVPO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '22F',
                                         ':22F::CCPT//YCCP');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '22F',
                                         ':22F::COLA//CRSP');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':DEAG//' ||
                                         fug_obt_pardinamico('SNP_BIC_BCP'));
      --pas_dep.fu_obt_bic_sis_depo);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':DECU//' ||
                                         fug_obt_pardinamico('SNP_BIC_BCP'));
      --pas_dep.fu_obt_bic_sis_depo);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '97A',
                                         ':SAFE//' ||
                                         substr(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                1,
                                                4) || '/DEPO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':SELL//' ||
                                         fug_obt_pardinamico('SNP_BIC_BCP'));
      --pas_dep.fu_obt_bic_sis_depo);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '97A',
                                         ':SAFE//AVAI/' ||
                                         substr(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                1,
                                                4) || '/DEPO/DEPO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':REAG//' ||
                                         pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':RECU//' ||
                                         pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '97A',
                                         ':SAFE//' ||
                                         substr(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                1,
                                                4) || '/DEPO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':BUYR//' ||
                                         pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '97A',
                                         ':SAFE//AVAI/' ||
                                         substr(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                1,
                                                4) || '/DEPO/DEPO');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'SETPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'CSHPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':PAYE//' ||
                                         pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '97A',
                                         ':CASH//' ||
                                         --pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                         --                                    v_cod_moneda)
                                         fu_obt_cta_depo(v_cod_moneda)
                                         );
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'CSHPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16R',
                                         'CSHPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '95Q',
                                         ':BENM//' ||
                                         fug_obt_pardinamico('SNP_BIC_BCP'));
      --pas_dep.fu_obt_bic_sis_depo);
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '97A',
                                         ':CASH//' ||
                                         pas_snp.fu_obt_cta_ban_participante(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                                             v_cod_moneda));
      /*pas_snp.fu_obt_cta_ban_participante(pas_dep.fu_obt_bic_sis_depo,
      v_cod_moneda));*/
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         'CSHPRTY');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16R', 'AMT');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '19A',
                                         ':DEAL//' ||
                                         pas_snp.g_cod_mon_iso_local ||
                                         trim(to_char(v_monto,
                                                      pas_snp.fu_obt_mascara ||
                                                      rpad('9',
                                                           nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                                                   p_cod_moneda => v_cod_moneda),
                                                               2),
                                                           '9'))));
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '16S', 'AMT');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                         '16S',
                                         ':16S:SETDET');
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');

      begin
        pas_dep.g_lugar := 'Creando la mensajería, ';
        pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);

        --
        if p_nro_referencia is null then
          --
          insert into sb_snp_mensajes
            (cod_mensaje,
             nro_referencia,
             nro_lote,
             orden,
             nro_linea,
             campo,
             valor,
             descripcion,
             ind_requerido,
             nro_detalle,
             err_formato,
             err_validacion)
            (select cod_mensaje,
                    v_nro_referencia,
                    null,
                    orden,
                    nro_linea,
                    campo,
                    valor,
                    descripcion,
                    ind_requerido,
                    nro_detalle,
                    err_formato,
                    err_validacion
               from sb_snp_mensajes_tmp
              where cod_mensaje = p_cod_tip_mensaje
                and valor is not null);
          --

          pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
          if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
            pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
            g_lugar := 'Conectándose al socket';
            -- Envia el mensaje al servidor
            server := pas_dep.g_servidor;
            puerto := pas_dep.g_puerto;
            pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                                 p_puerto     => pas_dep.g_puerto,
                                                 p_tie_espera => pas_dep.g_tie_espera,
                                                 p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                                 p_respuesta  => v_resp);
            if pas_dep.g_ok != 'S' THEN
              -- Hubo problema en el envio
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'N',
                                               pas_snp.g_msj_error);
              raise ex_salir;
            else
              if substr(v_resp, 1, 2) = '00' then
                g_lugar     := 'Actualizando estado y situación';
                v_situacion := 'V';
                v_estado    := 'A';
              else
                pas_snp.g_cod_error := 49;
                pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                              v_resp,
                                              1,
                                              1000);
                raise ex_salir;
              end if;
            end if;
          end if;
          --

          -- Obtiene la transacción hija de la Cta. Interbancaria según el tipo/subtipo de operación de GE_PAR_MENSAJES.
          g_lugar := 'Buscando Transacción de GE_PAR_MENSAJES, ';
          pas_snp.pr_obt_par_mensajes(v_cod_msj_swift,
                                      v_tip_operacion,
                                      v_sub_tip_operacion,
                                      'E',
                                      v_cod_modulo,
                                      v_cod_modalidad,
                                      v_cod_transaccion);

          begin
            -- Datos a registrar en GE_SNP_TRANSFERENCIAS
            pas_snp.g_msj.nro_referencia        := v_nro_referencia;
            pas_snp.g_msj.cod_modulo            := v_cod_modulo;
            pas_snp.g_msj.cod_modalidad         := v_cod_modalidad;
            pas_snp.g_msj.cod_oficina           := nvl(fug_obt_ofi_usuario(USER),
                                                       1); --v_cod_oficina;
            pas_snp.g_msj.fec_valor             := v_fec_valor;
            pas_snp.g_msj.fec_ingreso           := v_fecha;
            pas_snp.g_msj.fecha                 := v_fecha;
            pas_snp.g_msj.hora                  := to_char(sysdate,
                                                           'HH24:MI:SS');
            pas_snp.g_msj.cod_usuario           := USER;
            pas_snp.g_msj.nro_operacion         := v_nro_referencia;
            pas_snp.g_msj.cod_moneda            := v_cod_moneda;
            pas_snp.g_msj.cod_tip_operacion     := v_tip_operacion;
            pas_snp.g_msj.cod_sub_tip_operacion := v_sub_tip_operacion;
            pas_snp.g_msj.monto                 := v_monto;
            pas_snp.g_msj.ref_oid               := v_tasa;

            --
            pas_snp.g_msj.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
            pas_snp.g_msj.nro_cta_pte_solicitante  :=  fu_obt_cta_depo(v_cod_moneda);-- pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),
                                                      --                                    v_cod_moneda);
            pas_snp.g_msj.cod_swi_pte_beneficiario := fug_obt_pardinamico('SNP_BIC_BCP');
            pas_snp.g_msj.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante(fug_obt_pardinamico('SNP_BIC_BCP'),
                                                                                          v_cod_moneda);

            pas_snp.g_msj.concepto      := pas_snp.fu_val_cadena(nvl(v_concepto,
                                                                     v_con_movimiento));
            pas_snp.g_msj.cod_msj_swift := v_cod_msj_swift;
            pas_snp.g_msj.msj_swift     := v_mensaje;
            pas_snp.g_msj.ind_valor     := v_ind_valor;
            pas_snp.g_msj.prioridad     := v_prioridad;
            pas_snp.g_msj.situacion     := v_situacion;
            pas_snp.g_msj.estado        := v_estado;
            pas_snp.g_msj.origen        := 'I';
            pas_snp.g_msj.plataforma    := 'D';
            pas_snp.g_msj.indemnizado   := 'N';

            pas_dep.g_lugar := 'Insertando Mensajería.., ';
            pas_snp.pr_ins_transferencias(pas_snp.g_msj);
            if pas_snp.fu_obt_cod_error <> 0 then
              raise_application_error(-20001, pas_dep.fu_obt_msj_error);
            end if;
          end;

          if nvl(fug_obt_pardinamico('SIB_SNP_VER_WORKFLOW'), 'N') = 'S' THEN
            pas_snp.pr_ini_workflow(pas_snp.g_msj);
          end if;

          -- Operación de mesa de dinero.
          if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
            prs_ins_ope_mesa(v_nro_referencia, p_cod_moneda);
          end if;
        else
          -- Si se actualiza el monto o tasa manualmente
          -- Se actualiza también el estado y la situación
          if p_cancela <> 'S' then
            /*BEGIN
              UPDATE ge_snp_transferencias
                 SET monto     = v_monto,
                     ref_oid   = v_tasa,
                     msj_swift = v_mensaje,
                     situacion = 'V',
                     estado    = 'A'
               WHERE nro_referencia = p_nro_referencia;
            END;*/
            -- Actualizamos también la tabla de campos del mensaje generado
            BEGIN
              For i in (select s1.cod_mensaje,
                               s1.orden,
                               s1.nro_linea,
                               s1.campo,
                               s1.valor,
                               s1.descripcion,
                               s1.ind_requerido,
                               s1.nro_detalle,
                               s1.err_formato,
                               s1.err_validacion
                          from sb_snp_mensajes_tmp s1) LOOP
                update sb_snp_mensajes s2
                   set s2.cod_mensaje    = i.cod_mensaje,
                       s2.orden          = i.orden,
                       s2.nro_linea      = i.nro_linea,
                       s2.campo          = i.campo,
                       s2.valor          = i.valor,
                       s2.descripcion    = i.descripcion,
                       s2.ind_requerido  = i.ind_requerido,
                       s2.nro_detalle    = i.nro_detalle,
                       s2.err_formato    = i.err_formato,
                       s2.err_validacion = i.err_validacion
                 where s2.cod_mensaje = i.cod_mensaje
                   and s2.orden = i.orden
                   and s2.nro_linea = i.nro_linea
                   and s2.campo = i.campo
                   and s2.nro_referencia = to_char(p_nro_referencia);
              END LOOP;
            END;

            -- Actualizamos los datos de la transferencia
            BEGIN
              UPDATE ge_snp_transferencias
                 SET monto     = v_monto,
                     ref_oid   = v_tasa,
                     msj_swift = v_mensaje
               WHERE nro_referencia = p_nro_referencia;
            END;

            pas_dep.g_lugar := 'Enviando mensaje swift al socket, ';
            --if nvl(fug_obt_pardinamico('SIB_SNP_ENV_DEPO'), 'N') = 'S' THEN
            --pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
            g_lugar := 'Conectándose al socket';
            -- Envia el mensaje al servidor
            pas_dep.g_ok := fue_env_tcp_mensajes(p_servidor   => pas_dep.g_servidor,
                                                 p_puerto     => pas_dep.g_puerto,
                                                 p_tie_espera => pas_dep.g_tie_espera,
                                                 p_mensaje    => pas_snp.fu_con_mensaje(v_mensaje),
                                                 p_respuesta  => v_resp);
            if pas_dep.g_ok != 'S' THEN
              -- Hubo problema en el envio
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'N',
                                               pas_snp.g_msj_error);
              raise ex_salir;
            else
              if substr(v_resp, 1, 2) = '00' then
                g_lugar := 'Actualizando estado y situación';
                BEGIN
                  UPDATE ge_snp_transferencias
                     SET situacion = 'V', estado = 'A'
                   WHERE nro_referencia = p_nro_referencia;
                END;
              else
                pas_snp.g_cod_error := 49;
                pas_snp.g_msj_error := substr('Archivo no generado ' ||
                                              v_resp,
                                              1,
                                              1000);
                raise ex_salir;
              end if;
            end if;
            --end if;
            --

            -- Operación de mesa de dinero.
            if nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
              prs_ins_ope_mesa(v_nro_referencia,
                               p_cod_moneda,
                               p_monto,
                               p_tasa);
            end if;
            --
          else
            NULL;
            -- Se cancela la operación Depo
            /*BEGIN
              UPDATE ge_snp_transferencias
                 SET situacion = 'C', estado = 'C'
               WHERE nro_referencia = p_nro_referencia;
            END;
            -- Se elimina la operación de Compra
            BEGIN
              DELETE md_cta_documentos c
               WHERE c.nro_documento = p_nro_referencia
                 AND trunc(c.fec_insercion) = trunc(sysdate);
            END;*/
          end if;
        end if;
      exception
        when others then
          pas_dep.g_cod_error := 90;
          pas_dep.g_msj_error := 'Error insertando en GE_SNP_TRANSFERENCIAS: ' ||
                                 pas_dep.g_lugar || ' ' || SQLERRM;
          v_error := sqlerrm;
      end;
    end if;
  exception
    when others then
      pas_dep.g_cod_error := 91;
      pas_dep.g_msj_error := 'Error al Generar MT: ' || pas_dep.g_lugar || ' ' ||
                             SQLERRM;
  end pr_obt_msj_mt541;

  ---------------------------------------------------------------------------
  -- Error bloqueante PAM_FRC: log pas_dep, copia g_cod_error/g_msj_error, ex_salir
  -- invocar solo si FU_OBT_COD_ERROR <> 0)
  ---------------------------------------------------------------------------
  PROCEDURE pr_set_error_pam_frc (
    p_cod_mensaje    IN VARCHAR2,
    p_nro_referencia IN VARCHAR2
  ) IS
  BEGIN
    PRG_INS_LOG_ERRORES(
      P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
      P_DET_ERROR    => 'PAM_FRC | mt=' || p_cod_mensaje
                        || ' nro_ref=' || p_nro_referencia
                        || ' cod=' || IT.PAM_FRC.FU_OBT_COD_ERROR
                        || ' | ' || IT.PAM_FRC.FU_OBT_MSJ_ERROR,
      P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF')
    );
    pas_dep.g_cod_error := IT.PAM_FRC.FU_OBT_COD_ERROR;
    pas_dep.g_msj_error := IT.PAM_FRC.FU_OBT_MSJ_ERROR;
    RAISE ex_salir;
  END pr_set_error_pam_frc;

  function fu_reg_msj_rec_depo(p_mensaje          in clob,
                               p_ind_msj_recibido in varchar2 default 'S',
                               p_env_mail         in varchar2 default 'S')
    return varchar2 is

    v_cod_mensaje        sb_snp_mensajes_tmp.cod_mensaje%type;
    v_nro_referencia     ge_snp_mensajes.nro_referencia%type;
    v_nro_ref_externa    ge_snp_mensajes.nro_referencia%type;
    v_dir_correo         ge_par_dinamicos.val_parametro%type := nvl(pas_snp.g_gru_dir_correo,
                                                                    pas_snp.g_err_dir_correo);
    v_det_msj_error      g_det_msj_error%type;
    v_cod_msj_swift      ge_snp_transferencias.cod_msj_swift%type;
    v_env_mail_depo      varchar2(1);
    v_txt_mail           varchar2(4000);
    v_asunto             varchar2(4000);
    v_msj_swift          varchar2(4000);
    v_txt_mas_detalles   varchar2(100);
    v_msj_swi_original   clob := null;
    v_contador           number;
    v_qualifier          varchar2(4000);
    v_tip_operacion      varchar2(4000);
    v_tip_ope_rela_506   varchar2(4000);
    v_campo_70D          varchar2(4000);
    v_lack_of_funds      number := 0;
    v_mot_rechazo        varchar2(4000);
    v_cod_modulo         ba_modulos.cod_modulo%TYPE;
    v_cod_modalidad      ge_modalidades.cod_modalidad%TYPE;
    v_cod_oficina        ba_oficinas.cod_oficina%TYPE;
    v_concepto           ge_movimientos.concepto%TYPE;
    v_cta_bancaria       cc_cta_bancarias.nro_cuenta%TYPE;
    v_nro_secuencia      NUMBER := 0;
    v_ind_transaccion    VARCHAR2(1) := 'R';
    v_cod_transaccion    ge_transacciones.cod_transaccion%TYPE;
    v_hora               VARCHAR2(8) := to_char(SYSDATE, 'hh24:mi:ss');
    v_cod_tra_padre      ge_transacciones.cod_transaccion%TYPE := 303;
    v_tip_movimiento     ge_transacciones.tipo%TYPE;
    v_mto_fli            ge_snp_transferencias.monto%type;
    v_opcion             NUMBER;
    v_return             NUMBER;
    v_sal_restringido    NUMBER;
    v_des_tip_movimiento VARCHAR2(60);
    v_nro_documento      VARCHAR2(60);
    v_nro_ref_986        VARCHAR2(60);
    v_nro_ref_fli        VARCHAR2(60);--19122024
    v_nro_cta_fli        VARCHAR2(1000);--19122024
    v_nro_doc_ref        VARCHAR2(60);
    v_nro_ref_595        VARCHAR2(60);
    v_nro_ref_543        VARCHAR2(60);
    g_msj                pas_snp.rg_msj;
    v_letras             VARCHAR2(200);
    v_fli_letras         VARCHAR2(200);
    v_nro_cuenta         md_cta_documentos.nro_cuenta%type;
    v_mto_letra          VARCHAR2(200);--ge_snp_transferencias.monto%type;
    v_mto_por_letra      ge_snp_transferencias.monto%type := 0;
    v_mto_506            ge_snp_transferencias.monto%type;
    v_error              varchar2(100) := 'No se han encontrado transacciones para procesar ';
    md_rec               md_cta_documentos%rowtype;
    md_fli               md_cta_documentos%rowtype;
    v_cta_letras         ge_snp_transferencias.ref_oid%type; --TCE-159
    v_cta_letras_fli     ge_snp_transferencias.ref_oid%type; --TCE-159
    v_hay_colateral_506  VARCHAR2(1) := 'N';

--ELIMINAR X LOG
v_ctas_doc     varchar2(4000);
v_ctas_doc_sal varchar2(4000);



    cursor cu_msj_temporal is
      select a.cod_mensaje,
             a.campo,
             a.valor,
             a.descripcion,
             a.err_formato,
             a.orden
        from sb_snp_mensajes_tmp a
       where a.campo not in ('CAB', 'PIE')
         and a.descripcion is not null
       order by orden;
  begin
    pre_cam_for_numerico(',.');
    --
    pas_snp.pr_ini_variables;
    v_det_msj_error := NULL;
    --
    pas_snp.pr_set_texto(v_txt_mas_detalles, '....', pas_snp.fu_obt_salto);
    pas_snp.pr_set_texto(v_txt_mas_detalles, '....', pas_snp.fu_obt_salto);
    pas_snp.pr_set_texto(v_txt_mas_detalles, '....', pas_snp.fu_obt_salto);

    -- Se recupera valores comunes para la inserción en GE_SNP_MENSAJES cuando no está esquematizado.
    v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift(pao_pmt.fu_obt_linea(replace(p_mensaje,
                                                                               pas_snp.fu_obt_sal_socket,
                                                                               pas_snp.fu_obt_salto),
                                                                       1));

    if dbms_lob.getlength(p_mensaje) > 4000 then
      v_msj_swift := dbms_lob.substr(replace(p_mensaje,
                                             pas_snp.fu_obt_sal_socket,
                                             pas_snp.fu_obt_salto),
                                     3800,
                                     1) || v_txt_mas_detalles;
    else
      v_msj_swift := replace(p_mensaje,
                             pas_snp.fu_obt_sal_socket,
                             pas_snp.fu_obt_salto);
    end if;
    v_msj_swi_original := replace(p_mensaje,
                                  pas_snp.fu_obt_sal_socket,
                                  pas_snp.fu_obt_salto);
    --
    select count(*) into v_contador from sb_snp_mensajes_tmp;
    --
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'v_cod_mensaje: '||v_cod_mensaje||
                                          ' | v_contador: '||v_contador,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

    if v_contador = 0 then
      -- No está esquematizado

      --Se obtiene el campo 20C:SEME (nro_referencia)
      v_qualifier := substr(pao_pmt.fu_obt_val_campo(replace(p_mensaje,
                                                             pas_snp.fu_obt_sal_socket,
                                                             pas_snp.fu_obt_salto),
                                                     '20C'),
                            2,
                            4);
      if v_qualifier = 'SEME' then
        v_nro_referencia := substr(replace(replace(pao_pmt.fu_obt_val_campo(replace(p_mensaje,
                                                                    pas_snp.fu_obt_sal_socket,
                                                                    pas_snp.fu_obt_salto),
                                                            '20C'),CHR(10),''),CHR(13),''),
                                   8,
                                   20);

        --Se obtiene el campo 20C:RELA (nro_ref_externa)
      elsif v_qualifier = 'RELA' then
        v_nro_ref_externa := substr(pao_pmt.fu_obt_val_campo(replace(p_mensaje,
                                                                     pas_snp.fu_obt_sal_socket,
                                                                     pas_snp.fu_obt_salto),
                                                             '20C'),
                                    8,
                                    20);
      end if;
      --
      -- Identificador de Tipo de operación
      v_tip_operacion := substr(pao_pmt.fu_obt_val_campo(replace(p_mensaje,
                                                                 pas_snp.fu_obt_sal_socket,
                                                                 pas_snp.fu_obt_salto),
                                                         '12A'),
                                2,
                                4);
      --
      pas_snp.pr_set_texto(v_asunto,
                           'Mensajería ' ||
                           nvl(v_cod_mensaje, 'sin formato') || ' Recibida',
                           NULL);
      pas_snp.pr_set_texto(v_txt_mail,
                           'Se recibió un MT con el siguiente detalle:',
                           pas_snp.fu_obt_salto || pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_txt_mail,
                           'Nro. Referencia     : ' || v_nro_referencia,
                           pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_txt_mail,
                           'Nro. Ref. Original  : ' || v_nro_ref_externa,
                           pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_txt_mail,
                           'Fec Valor           : ' ||
                           to_char(pas_snp.g_fec_actual, 'DD/MM/YYYY'),
                           pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_txt_mail,
                           'Detalle del mensaje : ' || v_msj_swift,
                           pas_snp.fu_obt_salto || pas_snp.fu_obt_salto ||
                           pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_txt_mail,
                           'Atentamente.',
                           pas_snp.fu_obt_salto);
      --
    else
      -- Si está esquematizado
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Esquematizado',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

      for msj in cu_msj_temporal loop
        --Creo la cabecera del mail
        if v_asunto is null then
          v_asunto := 'Mensajería ' || msj.cod_mensaje || ' Recibida';
        end if;
        --Se concatena los datos disponibles para el envío del Mail.
        pas_snp.pr_set_texto(v_txt_mail,
                             msj.descripcion || ': ' || msj.valor,
                             pas_snp.fu_obt_salto);
        --Se concatenan los errores de formato que pudieron ocurrir
        if msj.err_formato is not null then
          pas_snp.pr_set_texto(v_det_msj_error,
                               msj.err_formato,
                               pas_snp.fu_obt_salto);
        end if;

        --Se obtiene el campo 20C:SEME (nro_referencia)
        if msj.campo = '20C' then
          v_qualifier := substr(msj.valor, 2, 4);
          if v_qualifier = 'SEME' then
            v_nro_referencia := substr(msj.valor, 8, 20);
            --Se obtiene el campo 20C:RELA (nro_ref_externa)
          elsif v_qualifier = 'RELA' then
            v_nro_ref_externa := substr(msj.valor, 8, 20);
          end if;
        end if;

        --Se obtiene el campo 13A (Código de MT solicitado)
        if msj.campo = '13A' /*and msj.descripcion = 'Código de MT solicitado' */
         then
          v_qualifier := substr(msj.valor, 2, 4);
          if v_qualifier = 'LINK' then
            v_cod_msj_swift := substr(msj.valor, 8, 3);
          end if;
        end if;
        
        if msj.campo = '35B' and (v_cod_mensaje = 543 OR v_cod_mensaje = 548 OR v_cod_mensaje = 545) and substr(msj.valor, 5, 6) = 'TPREPO'
         then
            v_tip_operacion := substr(msj.valor, 5, 6);
        else
            if msj.campo = '12A' and NVL(v_tip_operacion, 'X') != 'TPREPO'/*and msj.descripcion = 'Código de MT solicitado' */
             then

              v_tip_operacion := substr(msj.valor, 2, 4);
              if v_tip_operacion = 'CLAS' then
                v_tip_operacion := substr(msj.valor, 8, 8);
              end if;
            end if;
        end if;

        IF v_cod_mensaje = '548' AND msj.campo = '70D'
           AND (   msj.valor LIKE '%Transacciones de pata de efectivo%'
                OR msj.valor LIKE '%cola de espera%'
                OR msj.valor LIKE '%Lack of funds%') THEN
            v_lack_of_funds := v_lack_of_funds + 1;
            PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                              P_DET_ERROR    => '548 Lack of funds = 1',
                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
        END IF;
        --Se obtiene el campo 35B (Letras)
        if v_cod_mensaje = '506' then

           if msj.campo = '35B' /*and msj.descripcion = 'Código de MT solicitado' */
            then
              v_letras := trim(substr(msj.valor, 5, 20));
              v_fli_letras := v_fli_letras||''||v_letras||',';

PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '506, 35B v_letras: '||v_letras||', v_fli_letras: '||v_fli_letras,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

            BEGIN
            select DISTINCT  
                   LISTAGG(NRO_CUENTA, ', ') WITHIN GROUP (ORDER BY NRO_CUENTA) over (partition by NRO_DOCUMENTO) LISTA_CUENTAS,
                   LISTAGG(NVL(SAL_RESTRINGIDO,0), ', ') WITHIN GROUP (ORDER BY NRO_CUENTA) over (partition by NRO_DOCUMENTO) LISTA_MONTOS
              into  v_ctas_doc,
                    v_ctas_doc_sal
              from md_cta_documentos
             where nro_documento = trim(v_letras);
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '506, 35B v_letras: '||v_letras||
                                          ', v_ctas_doc: '||v_ctas_doc||
                                          ', v_ctas_doc_sal: '||v_ctas_doc_sal,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));


           end if;
           if msj.campo = '36B' /*and msj.descripcion = 'Código de MT solicitado' */
            then
		/*Cambiamos el orden de los caracteres en el replace de la siguiente linea MGF 16/10/2024 */ --FIELDESK-113732 --FIELDESK-92937
		--v_mto_letra := REPLACE(substr(msj.valor, 13, 25), ',', '.');
		v_mto_letra := REPLACE(substr(msj.valor, 13, 25), '.', ',');

PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '506, 36B v_mto_letra: '||v_mto_letra,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

              BEGIN
                Begin
                  Select distinct t.cod_modulo, t.cod_modalidad
                  into v_cod_modulo, v_cod_modalidad
                  from md_cta_documentos t 
                  where t.nro_documento = trim(v_letras); 
                exception
                  when no_data_found then
                    v_cod_modulo    := null;
                    v_cod_modalidad := null;
                end;    

                g_mto_uni_titulo := fug_obt_pardinamico('SNP_MTO_UNI_TITULO',
                                                        v_cod_modulo,
                                                        v_cod_modalidad);

              EXCEPTION
                WHEN OTHERS THEN
                  g_mto_uni_titulo := fug_obt_pardinamico('SNP_MTO_UNI_TITULO');
              END;
              ---
              v_mto_letra := to_number(v_mto_letra) * g_mto_uni_titulo;

PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '506, 36B v_mto_letra * g_mto_uni_titulo: '||v_mto_letra,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

               if v_mto_letra is not null then 
               ---  NVB-4142
               begin
                 select m.nro_ref_externa
                   into v_nro_ref_fli
                   from ge_snp_mensajes m
                  where m.cod_msj_swift = '543'
                    and m.fec_valor = pag_cal.fu_obt_fec_actual(1)
                    and m.nro_referencia = v_nro_ref_externa;
               exception
                 when no_data_found then
                    v_nro_ref_fli := null;
                 when others then
                    v_nro_ref_fli := null;
               end;       
               ---  

               begin
                  select substr(valor, 5, 6)
                    into v_tip_ope_rela_506
                    from sb_snp_mensajes
                   where nro_referencia = v_nro_ref_externa
                     and campo = '35B';
               exception
                 when no_data_found then
                    v_tip_ope_rela_506 := null;
                 when others then
                    v_tip_ope_rela_506 := null;
               end;

               --TCE-159
               pr_obt_cta_instrumento_bcp(p_instrumento     => trim(v_letras),
                                          p_mto_instrumento => v_mto_letra,
                                          p_cuenta          => v_cta_letras);

               v_cta_letras_fli := v_cta_letras_fli || v_cta_letras;                          
               --TCE-159
PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '506, 36B v_mto_letra: '||v_mto_letra||', v_cta_letras: '||v_cta_letras,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

                  DECLARE CURSOR cu_recompra IS
                    with lista as(
                      select v_cta_letras as str from dual)
                     select m.*
                      from md_cta_documentos m
                     where m.nro_documento = trim(v_letras)
                       and m.nro_cuenta in
                           (select regexp_substr(str, '[^,]+', 1, level) as val
                              from lista
                            connect by level <= regexp_count(str, '[^,]+'))
                       and m.sal_restringido > 0
                     order by m.sal_restringido desc;

                  BEGIN

                   WHILE v_mto_letra > 0
                      LOOP
                   open cu_recompra;
                   loop
                     fetch cu_recompra into md_rec;
                     if cu_recompra%NOTFOUND then
                       v_mto_letra := 0;
                       EXIT;
                     else 

 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '506 sal_restringido: '||v_mto_letra,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

                       IF md_rec.sal_restringido - v_mto_letra = 0 THEN
                            UPDATE md_cta_documentos m
                               SET m.sal_restringido = abs(md_rec.sal_restringido - v_mto_letra),
                                   m.estado          = 'C'
                             WHERE m.nro_cuenta = md_rec.nro_cuenta;
                            v_mto_506 := v_mto_letra;
                            v_mto_letra := 0;
                       ELSIF md_rec.sal_restringido - v_mto_letra < 0 THEN
                            UPDATE md_cta_documentos m
                               SET m.sal_restringido = 0,
                                   m.estado          = 'C'
                             WHERE m.nro_cuenta = md_rec.nro_cuenta;
                            v_mto_506 := md_rec.sal_restringido;
                            v_mto_letra := abs(md_rec.sal_restringido - v_mto_letra);
                       ELSIF abs(md_rec.sal_restringido - v_mto_letra) > 0 THEN
                            UPDATE md_cta_documentos m
                               SET m.sal_restringido = abs(md_rec.sal_restringido - v_mto_letra)
                             WHERE m.nro_cuenta = md_rec.nro_cuenta;
                            v_mto_506 := v_mto_letra;
                            v_mto_letra := 0;
                       END IF;

                    -- Registramos la operación en la tabla de FLI
                    --if v_mto_letra > 0 then
                      insert into sb_snp_fli
                             (nro_referencia,
                              nro_cuenta,
                              nro_ref_externa,
                              nro_documento,
                              cod_msj_swift,
                              fecha,
                              cod_moneda,
                              monto,
                              mto_letra,
                              error,
                              situacion)
                           values
                             (v_nro_referencia,
                              md_rec.nro_cuenta,
                              v_nro_ref_externa,
                              v_letras,
                              506,
                              pas_snp.g_fec_actual,
                              null,
                              v_mto_506,--v_mto_letra,
                              (md_rec.sal_restringido - v_mto_letra),
                              null,
                              'V');

                      v_hay_colateral_506 := 'S';

                      PRG_INS_LOG_ERRORES(
                        P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '506 sb_snp_fli v_nro_referencia: '
                                          || v_nro_referencia || '|'
                                          || md_rec.nro_cuenta || '|'
                                          || v_letras || '|'
                                          || '506|'
                                          || pas_snp.g_fec_actual || '|'
                                          || null || '|'
                                          || v_mto_506 || '|'
                                          || (md_rec.sal_restringido - v_mto_letra) || '|'
                                          || null || '|'
                                          || 'V',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF')
                      );

                      --end if;
                     end if;
                    END LOOP;
                    close cu_recompra;
                   END LOOP;
                 END;
               end if;
           end if;
        end if; --506
      end loop; --Loop lineas de mensaje

      -- Alta 138/140: una vez por 506, solo si hubo colateral elegible (sb_snp_fli).
      -- Sin letras/colateral no se crea cuenta producto y el mensaje no falla.
      IF v_cod_mensaje = '506' AND v_hay_colateral_506 = 'S' THEN
        IT.PAM_FRC.PR_PRO_CTA_MSJ_RECIBIDO(
          p_cod_msj_swift  => '506',
          p_nro_referencia => v_nro_referencia,
          p_ref_543        => v_nro_ref_externa,
          p_tip_producto   => v_tip_ope_rela_506
        );
        IF IT.PAM_FRC.FU_OBT_COD_ERROR <> 0 THEN
          pr_set_error_pam_frc(v_cod_mensaje, v_nro_referencia);
        END IF;
      END IF;

    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Campos analizados. v_tip_operacion: '||v_tip_operacion||'Msj RELA '||v_nro_ref_externa||' Tipo Operacion RELA '||v_tip_ope_rela_506,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));



      IF v_cod_mensaje = '506' and NVL(v_tip_ope_rela_506, 'X') != 'TPREPO' then 
         v_cta_letras_fli := replace(v_cta_letras_fli, ',,', ',');

         update ge_snp_transferencias t
            set t.ref_oid = v_cta_letras_fli 
          where t.nro_referencia = v_nro_ref_fli;

      ELSIF v_cod_mensaje = '508' then
        -- Canal de contingencia DEPO --
        IF REGEXP_LIKE(v_nro_ref_externa, '^D[0-9]+$') THEN
          DECLARE
            v_es_restr VARCHAR2(1)  := 'N'; -- 'S'=AVAI->RSTR  'N'=RSTR->AVAI
            v_n_93a    PLS_INTEGER  := 0;
            v_from     VARCHAR2(4);         -- FROM: AVAI o RSTR (primer 93A)
            v_toba     VARCHAR2(4);         -- TO: RSTR o AVAI (segundo 93A)
            v_resto      NUMBER;
            v_a_aplicar  NUMBER;

            -- Restringir (AVAI->RSTR): cuentas del ISIN con cupo libre
            -- (disponible = monto - sal_restringido - fli_vigente > 0).
            -- FLI vigente = situacion 'V' (N=cancelado / L=liquidado no restan cupo).
            CURSOR cu_cta_disponibles(p_letras IN VARCHAR2) IS
              SELECT m.nro_cuenta,
                     (NVL(m.monto, 0)
                      - NVL(m.sal_restringido, 0)
                      - NVL((SELECT SUM(f.monto)
                               FROM sb_snp_fli f
                              WHERE f.nro_cuenta = m.nro_cuenta
                                AND f.situacion = 'V'), 0)
                     ) AS disponible
                FROM md_cta_documentos m
               WHERE m.nro_documento = TRIM(p_letras)
                 AND m.estado IN ('C','T','E','R', 'I') 
                 AND (NVL(m.monto, 0)
                      - NVL(m.sal_restringido, 0)
                      - NVL((SELECT SUM(f.monto)
                               FROM sb_snp_fli f
                              WHERE f.nro_cuenta = m.nro_cuenta
                                AND f.situacion = 'V'), 0)
                     ) > 0
               ORDER BY m.fec_vencimiento ASC,
                        disponible DESC;

            -- Liberar (RSTR->AVAI): cuentas del ISIN con saldo restringido
            -- (sal_restringido > 0) para descontar hasta agotar el monto.
            CURSOR cu_cta_sal_restringido(p_letras IN VARCHAR2) IS
              SELECT m.nro_cuenta,
                     NVL(m.sal_restringido, 0) AS sal_restringido
                FROM md_cta_documentos m
               WHERE m.nro_documento = TRIM(p_letras)
                 AND m.estado = 'T'
                 AND NVL(m.sal_restringido, 0) > 0
               ORDER BY m.fec_vencimiento ASC NULLS LAST,
                        NVL(m.sal_restringido, 0) DESC;
                        
          BEGIN
            FOR c IN (SELECT campo, valor, orden
                        FROM sb_snp_mensajes_tmp
                       WHERE campo IN ('35B', '93A')
                       ORDER BY orden) LOOP
              IF c.campo = '35B' THEN
                v_letras := TRIM(SUBSTR(c.valor, 5, 20));
              ELSIF c.campo = '93A' THEN
                v_n_93a := v_n_93a + 1;
                -- Valida combinacion de estados FROM/TOBA --
                IF v_n_93a = 1 THEN
                  -- Primer 93A = FROM: ':FROM//AVAI' o ':FROM//RSTR'
                  v_from := SUBSTR(c.valor, INSTR(c.valor, '//') + 2, 4);
                ELSIF v_n_93a = 2 THEN
                  -- Segundo 93A = TOBA: ':TOBA//RSTR' o ':TOBA//AVAI'
                  v_toba := SUBSTR(c.valor, INSTR(c.valor, '//') + 2, 4);
                END IF;
              END IF;
            END LOOP;
            
            -- Valida combinacion --
            IF (v_from = 'AVAI' AND v_toba = 'RSTR') THEN
              v_es_restr := 'S'; -- Restriccion valida
            ELSIF (v_from = 'RSTR' AND v_toba = 'AVAI') THEN
              v_es_restr := 'N'; -- Liberacion valida
            ELSE
              raise_application_error(-20802,
                'MT508 contingencia: combinacion de estados invalida. '||
                'FROM:'||v_from||' TOBA:'||v_toba||
                '. Validas: (AVAI,RSTR) o (RSTR,AVAI).');
            END IF;
              
            IF v_letras IS NULL THEN
              raise_application_error(-20803,
                'MT508 contingencia: falta campo 35B (ISIN).');
            END IF;
            
            BEGIN
              SELECT TO_NUMBER(RTRIM(SUBSTR(valor, INSTR(valor, '/', -1) + 1), ','))
                INTO v_mto_letra
                FROM sb_snp_mensajes_tmp
               WHERE campo = '36B'
               ORDER BY orden
               FETCH FIRST 1 ROW ONLY;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                raise_application_error(-20804,
                  'MT508 contingencia: falta campo 36B (unidades).');
            END;
            
            BEGIN
              SELECT DISTINCT t.cod_modulo, t.cod_modalidad
                INTO v_cod_modulo, v_cod_modalidad
                FROM md_cta_documentos t
               WHERE t.nro_documento = TRIM(v_letras);
            EXCEPTION
              WHEN OTHERS THEN
                v_cod_modulo    := NULL;
                v_cod_modalidad := NULL;
            END;
            
            g_mto_uni_titulo := NVL(
              fug_obt_pardinamico('SNP_MTO_UNI_TITULO', v_cod_modulo, v_cod_modalidad),
              fug_obt_pardinamico('SNP_MTO_UNI_TITULO')
            );
            
            v_mto_letra := v_mto_letra * g_mto_uni_titulo;
            ------------------------------------------------------------------
            -- reparto multi-cuenta
            ------------------------------------------------------------------
            IF v_mto_letra IS NOT NULL AND v_mto_letra > 0 THEN
              v_resto := v_mto_letra;
              IF v_es_restr = 'S' THEN
                ------------------------------------------------------------
                -- RESTRINGIR: repartir por disponible (monto - sal_restringido - fli)
                ------------------------------------------------------------
                FOR r IN cu_cta_disponibles(v_letras) LOOP
                  EXIT WHEN v_resto <= 0;
                  v_a_aplicar := LEAST(v_resto, r.disponible);
                  pas_dep.pr_act_sal_restringido(p_nro_cuenta => r.nro_cuenta,
                                                 p_monto      => v_a_aplicar,
                                                 p_es_restr   => 'S');
                  v_resto := v_resto - v_a_aplicar;
                END LOOP;
                
                IF v_resto > 0 THEN
                  -- Resto sin cupo en ninguna cuenta del ISIN, se graba en el log para posterior seguimiento --
                  PRG_INS_LOG_ERRORES(
                    P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                    P_DET_ERROR    => 'Contingencia 508 RELA '||v_nro_ref_externa||
                                      ': ISIN '||v_letras||
                                      ', monto original '||v_mto_letra||
                                      ', resto sin atribuir '||v_resto,
                    P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF')
                  );
                  -- No hay saldo suficiente para restringir lo pedido por el 508 --
                  raise_application_error(-20801,
                    'Saldo menor a cero (0). Por favor verifique.');          
                END IF;
                
              ELSE
                ------------------------------------------------------------
                -- LIBERAR: repartir por sal_restringido
                ------------------------------------------------------------
                FOR r IN cu_cta_sal_restringido(v_letras) LOOP
                  EXIT WHEN v_resto <= 0;
                  v_a_aplicar := LEAST(v_resto, r.sal_restringido);
                  pas_dep.pr_act_sal_restringido(p_nro_cuenta => r.nro_cuenta,
                                                 p_monto      => v_a_aplicar,
                                                 p_es_restr   => 'N');
                  v_resto := v_resto - v_a_aplicar;
                END LOOP;
                
                IF v_resto > 0 THEN
                  -- Resto sin cupo en ninguna cuenta del ISIN, se graba en el log para posterior seguimiento --
                  PRG_INS_LOG_ERRORES(
                    P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                    P_DET_ERROR    => 'Contingencia 508 RELA '||v_nro_ref_externa||
                                      ': ISIN '||v_letras||
                                      ', monto original '||v_mto_letra||
                                      ', resto sin atribuir '||v_resto,
                    P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF')
                  );        
                  -- Mismo criterio que Bankitti: no habia sal_restringido
                  -- suficiente para liberar lo pedido por el 508.
                  raise_application_error(-20801,
                    'Saldo menor a cero (0). Por favor verifique.');
                END IF;
                
              END IF;
            END IF;
          END; -- FIN MT508 contingencia --
        ELSE --MT508  Generado desde BANKITTI --
          declare
            cursor cu_msj_tra is
              select /*to_number(nvl((((length(ref_oid) -
                                                           length(REPLACE(ref_oid, ',', ''))) /
                                                           length(',')) - 1),
                                                           0)) cantidad,
                                             substr(ref_oid, 2, length(ref_oid) - 2) ref_oid,*/
               ref_oid,
               nro_referencia,
               cod_modulo,
               cod_modalidad,
               cod_oficina,
               cod_msj_swift,
               cod_tip_operacion,
               cod_sub_tip_operacion,
               msj_swift,
               fec_valor,
               fec_ingreso,
               fec_recepcion,
               fecha,
               hora,
               cod_usuario,
               cod_moneda,
               monto,
               observacion
                from ge_snp_transferencias ge
               where ge.nro_referencia = v_nro_ref_externa
                 and ge.cod_msj_swift = '524' --v_cod_msj_swift
                 and ge.fec_recepcion is null
                 and ge.estado = 'A'
                 and ge.situacion = 'V';
          begin
            g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
            for reg in cu_msj_tra loop
              pas_snp.pr_ini_variables;

              -- Verifica que no tenga Workflow para liquidar automáticamente.
              if not pas_snp.fu_ver_workflow(to_char(reg.nro_referencia)) then
                v_error := null;
                -- Cambia la situación del MT524 a LIQUIDADO y estado APROBADO.
                -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS
                BEGIN
                  UPDATE ge_snp_transferencias
                     SET situacion = 'L', estado = 'A', error = NULL
                   WHERE nro_referencia = reg.nro_referencia;
                END;

                -- Actualización de estado del título restringido
                pas_dep.pr_act_sal_restringido(p_nro_cuenta => reg.ref_oid,
                                               p_monto      => reg.monto,
                                               p_es_restr   => nvl(reg.observacion, 'N'));
                --
              END IF;
            END LOOP;

            pas_snp.pr_set_texto(g_det_msj_error,
                                 v_error,
                                 pas_snp.fu_obt_salto);
            END; 
        END IF; -- FIN DE MT508 BANKITTI --
        
      ELSIF v_cod_mensaje = '535'  THEN

        begin
         insert into ge_snp_mensajes( cod_msj_swift,
                                      nro_referencia,
                                      nro_ref_externa,
                                      fec_valor,
                                      msj_swift,
                                      msj_swi_original,
                                      error,
                                      fec_recepcion,
                                      situacion
                                    )
                              values( 535,--v_cod_mensaje,
                                      v_nro_referencia,
                                      v_nro_ref_externa,
                                      pas_snp.g_fec_actual,
                                      v_msj_swift,
                                      v_msj_swi_original,
                                      v_det_msj_error,
                                      sysdate,
                                      'R'
                                    );
        exception
           when dup_val_on_index then
              pas_snp.g_cod_error := 55;
              pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el número de Ref.Externa '|| v_nro_ref_externa ||'!';
              raise ex_salir;
           when others then
              pas_snp.g_cod_error := 55;
              pas_snp.g_msj_error := 'Error al insertar el mensaje en GE_SNP_MENSAJES: '||sqlerrm;
              raise ex_salir;
        end;

      ELSIF v_cod_mensaje = '543' and NVL(v_tip_operacion, 'X') != 'TPREPO' THEN 
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'IF 543 TRUE g_det_msj_error: '||g_det_msj_error,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        /* Confirmación de Lote.
        * Setea Situación = 'L' y Estado = 'A' al lote.*/
        declare
          cursor cu_msj_tra is
            select to_number(nvl((((length(ref_oid) -
                                 length(REPLACE(ref_oid, ',', ''))) /
                                 length(',')) - 1),
                                 0)) cantidad,
                   substr(ref_oid, 2, length(ref_oid) - 2) ref_oid,
                   nro_referencia,
                   cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   cod_msj_swift,
                   cod_tip_operacion,
                   cod_sub_tip_operacion,
                   msj_swift,
                   fec_valor,
                   fec_ingreso,
                   fec_recepcion,
                   fecha,
                   hora,
                   cod_usuario,
                   cod_moneda,
                   monto
              from ge_snp_transferencias ge
             where ge.nro_referencia = v_nro_ref_externa
               and ge.cod_msj_swift = '986' --v_cod_msj_swift
               and ge.fec_recepcion is null
               and ge.estado = 'A'
               and ge.situacion = 'V';

          /*select * --ge.nro_referencia
           from ge_snp_transferencias ge
          where ge.nro_referencia = v_nro_ref_externa
            and ge.cod_msj_swift = '986' --v_cod_msj_swift
            and ge.fec_recepcion is null
            and ge.estado = 'A'
            and ge.situacion = 'V';*/
        begin
          g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';

    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'pre_cursor cu_msj_tra v_nro_ref_externa: '||v_nro_ref_externa
                                          ||' v_cod_msj_swift: '||v_cod_msj_swift,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

          if v_cod_msj_swift = '986' then
              for reg in cu_msj_tra loop
                pas_snp.pr_ini_variables;

                -- Verifica que no tenga Workflow para liquidar automáticamente.
                if not pas_snp.fu_ver_workflow(to_char(reg.nro_referencia)) then
                  v_error := null;
                  -- Cambia la situación del MT986 a LIQUIDADO y estado APROBADO.
                  -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS

        --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                            P_DET_ERROR    => 'pre UPDATE ge_snp_transferencias',
                            P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
                  BEGIN
                    UPDATE ge_snp_transferencias
                       SET situacion = 'L', estado = 'A', error = NULL
                     WHERE nro_referencia = reg.nro_referencia;
                  END;

                  /*IF reg.ref_oid is NOT NULL THEN
                    FOR e IN 1 .. reg.cantidad LOOP
                      v_nro_documento := pae_uti.fu_obt_valor(reg.ref_oid, e);
                      BEGIN
                        select nvl(m.sal_restringido, 0)
                          into v_sal_restringido
                          from md_cta_documentos m
                         where m.nro_cuenta = v_nro_documento;

                        IF (v_sal_restringido - reg.monto) < 0 THEN
                          raise_application_error(-20801,
                                                  'Saldo menor a cero (0). Por favor verifique.');
                        ELSIF (v_sal_restringido - reg.monto) = 0 THEN
                          UPDATE md_cta_documentos m
                             SET m.sal_restringido = v_sal_restringido -
                                                     reg.monto,
                                 m.estado          = 'C'
                           WHERE m.nro_cuenta = v_nro_documento;
                        ELSE
                          UPDATE md_cta_documentos m
                             SET m.sal_restringido = v_sal_restringido -
                                                     reg.monto
                           WHERE m.nro_cuenta = v_nro_documento;
                        END IF;
                      END;
                    END LOOP;
                  END IF;*/

                  -- Se realiza el traslado contable por Depo
                  /*IF nvl(fug_obt_pardinamico('SIB_SNP_UTI_ASIENTO'), 'N') = 'S' THEN
                  prs_gen_asi_depo('N', reg.nro_referencia, reg.cod_moneda, reg.monto, REPLACE(reg.ref_oid, ',', '.'));
                       END IF;*/

                  -- Operación de confirmación de documento Mesa de Dinero.
                  /*IF nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
                    prs_pro_com_doc(v_nro_ref_externa);
                  END IF;*/
                END IF; -- if not pas_snp.fu_ver_workflow
              END LOOP;
              --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'post_cursor cu_msj_tra ',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
            ELSIF v_cod_msj_swift = '543' THEN
                --Mensaje de recompra de REPO
                if not pas_snp.fu_ver_workflow(to_char(v_nro_ref_externa)) then
                  v_error := null;
                END IF;  
            END IF;
          pas_snp.pr_set_texto(g_det_msj_error,
                               v_error,
                               pas_snp.fu_obt_salto);
        END;
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => '543 v_tip_operacion: '||v_tip_operacion,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        IF NVL(v_tip_operacion, 'X') like '%DEPO-BCP%' THEN
           -- Operación de recompra de documento mesa de dinero.
           IF nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
              prs_pro_vta_doc(v_nro_ref_externa);
           END IF;
        END IF;
      --SPI
      elsif v_cod_mensaje = '545' and NVL(v_tip_operacion, 'X') like '%DEPO-BCP%' or NVL(v_tip_operacion, 'X') like '%DEPO-IPS%' then

                PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                              P_DET_ERROR    => '545 RECOMPRA'||v_nro_ref_externa,
                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        /* Confirmación de Lote.
        * Setea Situación = 'L' y Estado = 'A' al lote.*/
        declare
          cursor cu_msj_tra is
            select * --ge.nro_referencia
              from ge_snp_transferencias ge
             where ge.nro_referencia = v_nro_ref_externa
               and ge.cod_msj_swift = v_cod_msj_swift
               and ge.fec_recepcion is null
               and ge.estado = 'A'
               and ge.situacion = 'V';
        begin
          g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
          for reg in cu_msj_tra loop
                PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                              P_DET_ERROR    => '545 RECOMPRA dentro de loop cu_msj_tra nro_ref_externa: '||v_nro_ref_externa|| ' cod_msj_swift: '||v_cod_msj_swift,
                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
            pas_snp.pr_ini_variables;

            -- Verifica que no tenga Workflow para liquidar automáticamente.
            if not pas_snp.fu_ver_workflow(to_char(reg.nro_referencia)) then
                            PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                              P_DET_ERROR    => '545 Recompra no hay Workflow pendiente',
                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
            pas_snp.pr_ini_variables;
              v_error := null;
              -- Cambia la situación del MT541 a LIQUIDADO y estado APROBADO.
              -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS
              BEGIN
                            PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                              P_DET_ERROR    => '545 Recompra update ge_snp_transferencias ',
                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
                UPDATE ge_snp_transferencias
                   SET situacion = 'L', estado = 'A', error = NULL
                 WHERE nro_referencia = reg.nro_referencia;
              END;

              -- Se realiza el traslado contable por Depo
              /*IF nvl(fug_obt_pardinamico('SIB_SNP_UTI_ASIENTO'), 'N') = 'S' THEN
              prs_gen_asi_depo('N', reg.nro_referencia, reg.cod_moneda, reg.monto, REPLACE(reg.ref_oid, ',', '.'));
                   END IF;*/

              -- Operación de confirmación de documento Mesa de Dinero.
              IF nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
                prs_pro_com_doc(v_nro_ref_externa);
              END IF;
            END IF;
          END LOOP;
          pas_snp.pr_set_texto(g_det_msj_error,
                               v_error,
                               pas_snp.fu_obt_salto);
        END;
      elsif v_cod_mensaje = '548' and v_lack_of_funds = 3 then
          PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                              P_DET_ERROR    => '548 Lack of funds Nro Referencia'||v_nro_ref_externa,
                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
          select m.nro_ref_externa --ref543
            into v_nro_ref_543
            from ge_snp_mensajes m
           where m.nro_referencia = v_nro_ref_externa; --548  

          PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                              P_DET_ERROR    => '548 Lack of funds Ref a 543 = '||v_nro_ref_543,
                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

          begin
            select m.nro_referencia
              into v_nro_ref_595
              from ge_snp_transferencias m
             where m.cod_msj_swift = '595'
               and m.nro_ref_externa = v_nro_ref_543;
          exception
            when no_data_found then
              v_nro_ref_595 := null;
          end;
          IF v_nro_ref_595 IS NOT NULL THEN
            UPDATE ge_snp_transferencias s
               SET situacion = 'L', estado = 'A', error = NULL
             WHERE s.nro_referencia = v_nro_ref_595
               AND s.situacion != 'L';
          END IF;
          
          declare cursor mto_fli is
                  select nro_referencia, nro_cuenta, nro_documento, monto, situacion
                    from sb_snp_fli t
                   where t.cod_msj_swift = '506'
                     and t.nro_ref_externa = v_nro_ref_543
                     and t.situacion = 'V'  -- vigente; N=cancelado no recomprar
                     FOR UPDATE;
          -- Actualizo el saldo de la recompra
          BEGIN
             FOR REG IN mto_fli LOOP
                 --FSOP-60451 
                 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                 P_DET_ERROR    => 'Entro en FOR REG IN mto_fli LOOP Mensaje 548 cta: '||reg.nro_cuenta||' monto: '||reg.monto,
                 P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

                 BEGIN
                    UPDATE md_cta_documentos m
                       SET m.sal_restringido = nvl(m.sal_restringido,0) +
                                                     reg.monto,
                                 m.estado = 'T'
                           WHERE m.nro_cuenta = reg.nro_cuenta;
                           --FSOP-60451 
                           PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                           P_DET_ERROR    => 'mensaje 548 Hizo el update',
                           P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
                        END;
                    END LOOP;

                    UPDATE sb_snp_fli t
                       SET t.situacion = 'L'
                     WHERE t.cod_msj_swift = '506'
                       AND t.nro_ref_externa = v_nro_ref_543
                       AND t.situacion = 'V';  -- no tocar N (cancelado) ni L
                    PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                                           P_DET_ERROR    => 'mensaje 548 Hizo el update snp fli situacion L',
                                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));   

                  END;
             
        elsif v_cod_mensaje = '545' and (NVL(v_tip_operacion, 'X') like '%ILF%' or NVL(v_tip_operacion, 'X') like '%ONREPO%' or NVL(v_tip_operacion, 'X') like '%TPREPO%') then --TCE-159, TCE-550
          --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Entro al 545 ILF o ONREPO ',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
          --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'v_nro_ref_externa: '||v_nro_ref_externa||' v_cod_msj_swift: '||v_cod_msj_swift,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        declare
          cursor cu_msj_tra is
            select nro_referencia, nro_ref_externa
              from ge_snp_mensajes ge
             where ge.nro_referencia = v_nro_ref_externa
               and ge.cod_msj_swift = v_cod_msj_swift /*
                           and ge.fec_valor = pag_cal.fu_obt_fec_actual(1)*/
            ;

        begin
          g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
          for reg in cu_msj_tra loop
            pas_snp.pr_ini_variables;

            --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Entro en for reg in cu_msj_tra loop',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

            -- Verifica que no tenga Workflow para liquidar automáticamente.
            if not pas_snp.fu_ver_workflow(to_char(reg.nro_referencia)) then
              v_error := null;

            --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'No hay workflox',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

              IF v_cod_msj_swift in ('541','543') THEN

            --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Entro a v_cod_msj_swift in (541,543)',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));


                --Busco el 543 del FLI inicial
                select m.nro_referencia, m.nro_ref_externa
                  into v_nro_ref_543, v_nro_ref_986
                  from ge_snp_mensajes m
                 where m.cod_msj_swift = '543'
                   and m.nro_referencia = reg.nro_ref_externa;

            --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Encontro FLI inicial v_nro_ref_543: '||v_nro_ref_543||' v_nro_ref_986: '||v_nro_ref_986,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));


                -- Cambia la situación del MT595 a LIQUIDADO y estado APROBADO.
                IF v_nro_ref_543 IS NOT NULL THEN
                  IT.PAM_FRC.PR_PRO_CTA_MSJ_RECIBIDO(
                    p_cod_msj_swift  => '545',
                    p_nro_referencia => v_nro_referencia,
                    p_ref_543        => v_nro_ref_543
                  );
                  IF IT.PAM_FRC.FU_OBT_COD_ERROR <> 0 THEN
                    pr_set_error_pam_frc(v_cod_mensaje, v_nro_referencia);
                  END IF;
                  --TCE-550 - Se encapsulo el bloque de consulta para los casos de transf. 595
                  begin
                    select m.nro_referencia, m.monto
                      into v_nro_ref_595, v_mto_fli
                      from ge_snp_transferencias m
                     where m.cod_msj_swift = '595'
                       and m.nro_ref_externa = v_nro_ref_543;
                  exception
                    when no_data_found then
                      v_nro_ref_595 := null;
                  end;   

                  IF v_nro_ref_595 IS NOT NULL THEN
                    BEGIN
                      -- Actualizo la Recompra a Liquidado
                      update ge_snp_transferencias s
                         set situacion = 'L', estado = 'A', error = NULL
                       where s.nro_referencia = v_nro_ref_595;
                    END;
                  END IF;
                  --
                  -- Si tengo un 541 actualizo a Recomprado (solo ref numerica del 986).
                  -- TPREPO: nro_ref_externa del 543 es LINK 502 (D...) y no aplica aqui.
                  IF v_cod_msj_swift = '541'
                     AND REGEXP_LIKE(TRIM(v_nro_ref_986), '^\d+$') THEN
                    BEGIN
                      update ge_snp_transferencias s
                         set observacion = 'S'
                       where s.nro_referencia = TO_NUMBER(v_nro_ref_986);
                    END;
                  END IF;
                  --
                  declare cursor mto_fli is
                  select nro_referencia, nro_cuenta, nro_documento, monto
                    from sb_snp_fli t
                   where t.cod_msj_swift = '506'
                     and t.nro_ref_externa = v_nro_ref_543
                     and t.situacion = 'V'  -- vigente; N=cancelado no recomprar
                     FOR UPDATE;
                  -- Actualizo el saldo de la recompra
                  BEGIN
                    FOR REG IN mto_fli LOOP

                        --FSOP-60451 
                        PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Entro en FOR REG IN mto_fli LOOP Mensaje 545 cta: '||reg.nro_cuenta||' monto: '||reg.monto,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

                        BEGIN
                          UPDATE md_cta_documentos m
                             SET m.sal_restringido = nvl(m.sal_restringido,0) +
                                                     reg.monto,
                                 m.estado = 'T'
                           WHERE m.nro_cuenta = reg.nro_cuenta;
                           --FSOP-60451 
                           PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                           P_DET_ERROR    => 'Mensaje 545 Hizo el update',
                           P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
                        END;
                    END LOOP;

                    UPDATE sb_snp_fli t
                       SET t.situacion = 'L'
                     WHERE t.cod_msj_swift = '506'
                       AND t.nro_ref_externa = v_nro_ref_543
                       AND t.situacion = 'V';  -- no tocar N (cancelado) ni L

                    PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                                           P_DET_ERROR    => 'mensaje 545 Hizo el update snp fli situacion L',
                                              P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

                  END;

                  /*declare cursor mto_fli is
                  select to_number(nvl((((length(ref_oid) -
                            length(REPLACE(ref_oid, ',', ''))) /
                            length(',')) - 1),
                            0)) cantidad,
                            substr(ref_oid, 2, length(ref_oid) - 2) ref_oid
                    --into v_nro_doc_ref
                    from ge_snp_transferencias t
                   where t.cod_msj_swift = '986'
                     --and t.fec_valor = pag_cal.fu_obt_fec_actual(1)
                     and t.nro_referencia = v_nro_ref_986;

                  -- Actualizo el saldo de la recompra
                  BEGIN
                    FOR REG IN mto_fli LOOP
                        FOR e IN 1 .. reg.cantidad LOOP
                            v_nro_doc_ref := pae_uti.fu_obt_valor(reg.ref_oid, e);
                            IF v_nro_doc_ref IS NOT NULL THEN
                               -- Actualizo el estado a Disponible si el saldo es cero (0)
                               BEGIN
                                 UPDATE md_cta_documentos m
                                    SET m.sal_restringido = nvl(m.sal_restringido,0) +
                                                            v_mto_fli
                                  WHERE m.nro_cuenta = v_nro_doc_ref;
                               END;
                               -- Actualizo el estado a Disponible si el saldo es cero (0)
                               \*SELECT nvl(m.sal_restringido,0)
                                 INTO v_sal_act_restringido
                                 FROM md_cta_documentos m
                                WHERE m.nro_cuenta = v_nro_doc_ref;  *\
                            END IF;
                        END LOOP;
                    END LOOP;
                  END;*/
                END IF;

                --END LOOP;
                --END IF;
              END IF;

              -- Se realiza el traslado contable por Depo
              /*IF nvl(fug_obt_pardinamico('SIB_SNP_UTI_ASIENTO'), 'N') = 'S' THEN
              prs_gen_asi_depo('N', reg.nro_referencia, reg.cod_moneda, reg.monto, REPLACE(reg.ref_oid, ',', '.'));
                   END IF;*/

              -- Operación de confirmación de documento Mesa de Dinero.
              /*IF nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
                prs_pro_com_doc(v_nro_ref_externa);
              END IF;*/
            END IF;
          END LOOP;
          pas_snp.pr_set_texto(g_det_msj_error,
                               v_error,
                               pas_snp.fu_obt_salto);
        END;
        -- Operación de recompra de documento mesa de dinero.
        /*IF nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
          prs_pro_vta_doc(v_nro_ref_externa);
        END IF;*/

      elsif v_cod_mensaje = '546' then

        -- Solo conversion FLI→REPO O/N. Otros 546 no invocan PAM_FRC.
        IF v_tip_operacion = 'ILF' THEN
          IT.PAM_FRC.PR_PRO_CTA_MSJ_RECIBIDO(
            p_cod_msj_swift  => '546',
            p_nro_referencia => v_nro_referencia,
            p_ref_543        => v_nro_ref_externa,
            p_msj_swift      => NVL(v_msj_swi_original, TO_CLOB(v_msj_swift))
          );
          IF IT.PAM_FRC.FU_OBT_COD_ERROR <> 0 THEN
            pr_set_error_pam_frc(v_cod_mensaje, v_nro_referencia);
          END IF;
        END IF;

        -- Conversión manual FLI→REPO ON: liquida el lote I542 pendiente.
        -- Conversión automática: no aplica este bloque.
        IF v_cod_msj_swift = '542' THEN
          /* Confirmación de Lote.
          * Setea Situación = 'L' y Estado = 'A' al lote.*/
          declare
            cursor cu_msj_tra is
              select ge.nro_referencia
                from ge_snp_transferencias ge
               where ge.nro_referencia = v_nro_ref_externa
                 and ge.cod_msj_swift = '542' --
                 and ge.fec_recepcion is null
                 and ge.estado = 'A'
                 and ge.situacion = 'V';
          begin
            g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
            for reg in cu_msj_tra loop
              pas_snp.pr_ini_variables;

              -- Verifica que no tenga Workflow para liquidar automáticamente.
              if not pas_snp.fu_ver_workflow(to_char(reg.nro_referencia)) then
                v_error := null;
                -- Cambia la situación del MT542 a LIQUIDADO y estado APROBADO.
                -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS
                BEGIN
                  UPDATE ge_snp_transferencias
                     SET situacion = 'L', estado = 'A', error = NULL
                   WHERE nro_referencia = reg.nro_referencia;
                END;

                --Actualizo el FLI inicial
                    BEGIN
                      update ge_snp_transferencias s
                         set observacion = 'S'
                       where s.nro_referencia = (select m543.nro_ref_externa
                                                    from sb_snp_mensajes m542,
                                                         ge_snp_mensajes m543
                                                   where m542.cod_mensaje = 'MT542'
                                                     AND m542.nro_referencia = reg.nro_referencia
                                                     and m542.campo = '20C'
                                                     AND INSTR(m542.VALOR,'PREV')>0
                                                     and m543.cod_msj_swift = '543'
                                                     and m543.nro_refERENCIA = SUBSTR(m542.VALOR,8)
                                                     and m543.fec_valor = pag_cal.fu_obt_fec_actual(1));
                    END;

                -- Se realiza el traslado contable por Depo
                /*IF nvl(fug_obt_pardinamico('SIB_SNP_UTI_ASIENTO'), 'N') = 'S' THEN
                prs_gen_asi_depo('N', reg.nro_referencia, reg.cod_moneda, reg.monto, REPLACE(reg.ref_oid, ',', '.'));
                     END IF;*/

                -- Operación de confirmación de documento Mesa de Dinero.
                /*IF nvl(fug_obt_pardinamico('SIB_SNP_OPE_MESA'), 'N') = 'S' THEN
                  prs_pro_com_doc(v_nro_ref_externa);
                END IF;*/
              END IF;
            END LOOP;
            pas_snp.pr_set_texto(g_det_msj_error,
                                 v_error,
                                 pas_snp.fu_obt_salto);
          END;
        END IF;
      ELSIF v_cod_mensaje = '547' THEN
        NULL;

      ELSIF v_cod_mensaje = '548' then
        for msj in cu_msj_temporal loop
          --Creo la cabecera del mail
          if v_asunto is null then
            v_asunto := 'Mensajería ' || msj.cod_mensaje || ' Recibida';
          end if;
          --Se concatena los datos disponibles para el envío del Mail.
          pas_snp.pr_set_texto(v_txt_mail,
                               msj.descripcion || ': ' || msj.valor,
                               pas_snp.fu_obt_salto);
          --Se concatenan los errores de formato que pudieron ocurrir
          if msj.err_formato is not null then
            pas_snp.pr_set_texto(v_det_msj_error,
                                 msj.err_formato,
                                 pas_snp.fu_obt_salto);
          end if;
          if msj.campo = '70D' then
            v_campo_70D := substr(pao_pmt.fu_obt_val_mt_proceso(msj.cod_mensaje,
                                                                msj.campo),
                                  13,
                                  length(pao_pmt.fu_obt_val_mt_proceso(msj.cod_mensaje,
                                                                       msj.campo)));

          end if;
        end loop;

        IF NVL(v_tip_operacion, 'X') != 'TPREPO' THEN
          -- Validamos que la ref sea numérica y este alineada al nro_referencia de la transferencia origen --		
          IF REGEXP_LIKE(TRIM(v_nro_ref_externa), '^\d+$') THEN
            declare
                cursor cu_msj_tra_error is
                select ge.nro_referencia
                  from ge_snp_transferencias ge
                 where ge.nro_referencia = v_nro_ref_externa
                   and ge.cod_msj_swift = v_cod_msj_swift
                   and ge.fec_recepcion is null
                   and ge.estado = 'A'
                   and ge.situacion = 'V'; -- Ver en que Estado y Situación quedará al generarse el MT541
            begin
                if v_campo_70D <> fug_obt_pardinamico('SIB_SNP_MSJ_CON_REPO') then
                    g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
                    for reg in cu_msj_tra_error loop
                        pas_snp.pr_ini_variables;
                        -- Se reabre el circuito, por error
                        if nvl(fug_obt_pardinamico('SIB_SNP_VER_WORKFLOW'), 'N') = 'S' THEN
                            BEGIN
                                UPDATE wf_circuitos
                                   SET estado = 'E', usu_insercion = USER, fec_fin = NULL
                                 WHERE cod_tip_circuito = '541'
                                   AND referencia = v_nro_ref_externa;
                                --
                                UPDATE wf_cir_tareas
                                   SET estado = 'P',
                                       --cod_usuario = USER,
                                       usu_insercion    = USER,
                                       fec_finalizacion = NULL
                                 WHERE cod_tip_circuito = '541'
                                   AND cod_tarea = 1
                                   AND cod_circuito = (select cod_circuito
                                                         from wf_circuitos
                                                        where cod_tip_circuito = '541'
                                                          and referencia = v_nro_ref_externa);
                            END;
                        end if;
                        -- Cambia la situación del MT548 a ERROR y estado SOLICITADO.
                        -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS
                        BEGIN
                            UPDATE ge_snp_transferencias
                               SET situacion = 'E', estado = 'S', error = v_campo_70D
                             WHERE nro_referencia = reg.nro_referencia;
                        END;
                    end loop;
                    -- Correo de Recepción de MT Respuesta Depo

                    v_txt_mail := 'Detalle del MT548' || v_cod_msj_swift || v_txt_mail;

                    pas_snp.pr_set_texto(v_txt_mail,
                                         'Detalle del mensaje : ' || v_msj_swift,
                                         pas_snp.fu_obt_salto ||
                                         pas_snp.fu_obt_salto || v_campo_70D ||
                                         pas_snp.fu_obt_salto ||
                                         pas_snp.fu_obt_salto);
                    pas_snp.pr_set_texto(v_txt_mail,
                                         'Atentamente.',
                                         pas_snp.fu_obt_salto);
                end if;
            end;
          END IF;
        END IF; --v_tip_operacion != 'TPREPO'
      end if;
    end if; -- Esquematizado
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Finalizado bloque de IF v_cod_mensaje',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'insert into ge_snp_mensajes:'
                                          ||v_cod_mensaje||'|'
                                          ||v_nro_referencia||'|'
                                          ||v_nro_ref_externa||'|'
                                          ||pas_snp.g_fec_actual||'|'
                                          ||v_msj_swift||'|'
                                          ||v_msj_swi_original||'|'
                                          ||v_det_msj_error||'|'
                                          ||case when p_ind_msj_recibido = 'S' then sysdate else NULL end||'|'
                                          ||case when p_ind_msj_recibido = 'S' then 'R' else 'P' end,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

    begin
      insert into ge_snp_mensajes
        (cod_msj_swift,
         nro_referencia,
         nro_ref_externa,
         fec_valor,
         msj_swift,
         msj_swi_original,
         error,
         fec_recepcion,
         situacion)
      values
        (v_cod_mensaje,
         v_nro_referencia,
         v_nro_ref_externa,
         pas_snp.g_fec_actual,
         v_msj_swift,
         v_msj_swi_original,
         v_det_msj_error,
         case when p_ind_msj_recibido = 'S' then sysdate else NULL end,
         case when p_ind_msj_recibido = 'S' then 'R' else 'P' end);

    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'insertado en ge_snp_mensajes',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
    exception
      when dup_val_on_index then
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'insert into ge_snp_mensajes dup_val_on_index',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        NULL;
      when others then
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'insert into ge_snp_mensajes others: '||sqlerrm,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

        pas_dep.g_cod_error := 55;
        pas_dep.g_msj_error := 'Error al insertar el mensaje en GE_SNP_MENSAJES: ' ||
                               sqlerrm;
        raise ex_salir;
    end;


    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'pre_envia_mail g_det_msj_error: '||g_det_msj_error,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
    /*
    || Envía Correo con los detalles de la mensajería recibida
    */
    BEGIN
      v_env_mail_depo := nvl(fug_obt_pardinamico('SNP_ENV_MAIL_DEPO'), 'N');
      if v_env_mail_depo = 'S' then
        if p_env_mail = 'S' and v_dir_correo is not null then
          it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail);
        end if;
      end if;
    EXCEPTION
      when others then
        NULL;
    END;

    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'g_det_msj_error: '||g_det_msj_error,
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));

    if g_det_msj_error is NULL then
    --
    --FSOP-60451 
 PRG_INS_LOG_ERRORES(P_COD_PROGRAMA => 'pas_dep.fu_reg_msj_rec_depo',
                        P_DET_ERROR    => 'Fin OK',
                        P_CAMPO1       => TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF'));
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
    else
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || g_det_msj_error;
    end if;


  EXCEPTION
    when ex_salir then
      return '99' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || fu_obt_msj_error;
    when others then
      return '99' || '|' || v_cod_mensaje || '|' || SQLERRM;

  end fu_reg_msj_rec_depo;

  FUNCTION fu_obt_cod_error return number IS
    /*
    || Obtiene el código de error del registro del paquete.
    */
  BEGIN
    return pas_dep.g_cod_error;
  END fu_obt_cod_error;

  FUNCTION fu_obt_msj_error return varchar2 IS
    /*
    || Obtiene el mensaje de error contenido en el registro del paquete.
    */
  BEGIN
    return pas_dep.g_msj_error;
  END fu_obt_msj_error;

  FUNCTION fu_obt_det_msj_error return varchar2 IS
    /*
    || Obtiene el mensaje de error contenido en el registro del paquete.
    */
  BEGIN
    return pas_dep.g_det_msj_error;
  END fu_obt_det_msj_error;
  /*Obtiene las ctas relacionadas a los instrumentos comunicados por el BCP*/ --TCE-159
  procedure pr_obt_cta_instrumento_bcp(p_instrumento     in varchar2,
                                       p_mto_instrumento in number,
                                       p_cuenta          out varchar2) is

    v_mensaje         varchar2(500);
    v_tot_restringido number := 0;
    v_tot_operacion   number := p_mto_instrumento;
    v_cuentas         ge_snp_transferencias.ref_oid%type;
    e_error_controlado exception;

  begin
    if p_mto_instrumento <> 0 and p_instrumento is not null then
      --Suma y verifica los saldos restringidos por instrumento para podes descontar luego
      begin
        select sum(nvl(c.sal_restringido, 0)) sal_restringido
          into v_tot_restringido
          from md_cta_documentos c
         where c.estado = 'T'
           and nvl(c.sal_restringido, 0) > 0
           and c.nro_documento = p_instrumento
         order by fec_vencimiento asc;
      exception
        when no_data_found then
          v_mensaje := 'No existen documentos restringidos.';
          raise e_error_controlado;
      end;

      for reg in (select nvl(m.sal_restringido, 0) sal_restringido,
                         m.estado,
                         m.nro_cuenta
                    from md_cta_documentos m
                   where m.estado = 'T'
                     and nvl(m.sal_restringido, 0) > 0
                     and m.nro_documento = p_instrumento
                   order by m.fec_vencimiento asc, m.sal_restringido desc) loop

          exit when v_tot_operacion <= 0 or v_tot_restringido <= 0;
          v_tot_operacion := v_tot_operacion - reg.sal_restringido;
          v_tot_restringido := v_tot_restringido - reg.sal_restringido;
          v_cuentas := ltrim(rtrim(nvl(v_cuentas, ',') || reg.nro_cuenta || ','));
      end loop;
    end if;

    p_cuenta := v_cuentas;
  exception
    when e_error_controlado then
      raise_application_error(-20001, v_mensaje);
    when others then
      raise_application_error(-20000,
                              'Error general al actualizar los instrumentos. Detalle: ' ||
                              sqlerrm || '. Linea: ' ||
                              dbms_utility.format_error_backtrace);
  end pr_obt_cta_instrumento_bcp;
  /*Actualiza operaciones de restriccion/liberacion de saldo*/
  PROCEDURE pr_act_sal_restringido(p_nro_cuenta in varchar2,
                                   p_monto      in number,
                                   p_es_restr   in varchar2) is
    v_sal                 number;
    v_monto               number;
    v_new_sal_restringido number;
  begin
    select nvl(m.sal_restringido, 0), nvl(m.monto, 0)
      into v_sal, v_monto
      from md_cta_documentos m
     where m.nro_cuenta = p_nro_cuenta
       for update;
  
    if nvl(p_es_restr, 'N') = 'S' then
      v_new_sal_restringido := v_sal + p_monto;
      if v_new_sal_restringido > v_monto then
        raise_application_error(-20801,
                                'Saldo a restringir mayor al monto. Por favor verifique.');
      end if;
      update md_cta_documentos m
         set m.estado = 'T', m.sal_restringido = v_new_sal_restringido
       where m.nro_cuenta = p_nro_cuenta;
    
    else
      if (v_sal - p_monto) < 0 then
        raise_application_error(-20801,
                                'Saldo menor a cero (0). Por favor verifique.');
      end if;
    
      if (v_sal - p_monto) = 0 then
        update md_cta_documentos m
           set m.sal_restringido = 0, m.estado = 'C'
         where m.nro_cuenta = p_nro_cuenta;
      else
        update md_cta_documentos m
           set m.estado = 'T', m.sal_restringido = v_sal - p_monto
         where m.nro_cuenta = p_nro_cuenta;
      end if;
    end if;
  end pr_act_sal_restringido;
end PAS_DEP;
/

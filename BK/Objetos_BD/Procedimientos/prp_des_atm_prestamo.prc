create or replace procedure it.prp_des_atm_prestamo(p_cod_persona   in varchar2,
                                                 p_monto         in number,
                                                 p_cta_credito   in varchar2,
                                                 p_nro_solicitud in varchar2) is

  v_fecha         date := pag_cal.fu_obt_fec_actual(6);
  v_hora          ge_movimientos.hora%type := to_char(sysdate, 'hh24:mi:ss');
  v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
  v_nro_cuenta    ge_cuentas.nro_cuenta%type;
  v_cotizacion    ge_movimientos.cotizacion%type;
  rg_solicitudes  pr_solicitudes%rowtype;
  v_usuario       ba_usuarios.cod_usuario%type;
  v_nom_cliente   ba_personas.nom_completo%type;
  v_cod_persona   ba_personas.cod_persona%type;
  v_cod_oficina   ba_oficinas.cod_oficina%type;
  v_cod_canal     ge_canales.cod_canal%type;
  v_cod_usu_oficial ge_clientes.cod_usu_oficial%type;
  v_dir_correo    ba_usuarios.dir_correo%type;
  v_mensaje       varchar2(400) := fug_obt_pardinamico('ENV_MEN_PRE_APROBADOS');
  v_texto         varchar2(4000);
  v_membrete      LONG := fug_gen_template('M');
  v_fin           LONG := fug_gen_template('F');
  v_pie           LONG := fug_gen_template('P');
  V_DIR_CORREO_CC varchar2(300) := fug_obt_pardinamico('ENV_MEN_CC_PRE_APR');--'mariaalejandra.gossen@bbva.com';
  v_can_cuotas    pr_cta_prestamos.can_cuotas%type;
  v_cod_modalidad ge_modalidades.cod_modalidad%type;
  -- PCCDEEVO-214 Se obtiene estado del m�dulo 3 para este desarrollo se considera
  -- operaciones que provienen del ATM (m�dulo 3 cabecera de ATM).
  v_est_modulo    ba_modulos.estado%TYPE := pae_cnf.fu_obt_est_modulo(6);
  v_es_nocturno   varchar2(1) default 'N';
  v_horario       varchar2(1) default 'D';
  v_est_doc     number := 0;
  v_est_wf48    number := 0;
  v_cod_causa   ge_movimientos.cod_causa%TYPE;
  v_nro_doc_blo ge_movimientos.nro_documento%TYPE;
  v_cod_moneda  ba_monedas.cod_moneda%type;
  v_dir_mail  ge_par_dinamicos.parametro%type := fug_obt_pardinamico('MAI_BLO_DESEMBOLSO');
  v_tex_mail     varchar2(4000);
  v_remitente ge_par_generales.dir_correo%type := fug_obt_dir_correo;
  v_asunto    varchar2(4000);
  PROCEDURE pr_ins_mov_bloqueo(p_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE,
                               p_cod_transaccion ge_movimientos.cod_transaccion%TYPE,
                               p_imp_transaccion ge_movimientos.monto%TYPE,
                               p_nro_documento   ge_movimientos.nro_documento%TYPE,
                               p_cod_causa       ge_movimientos.cod_causa%TYPE,
                               p_emi_aviso       ge_movimientos.emi_aviso%TYPE) IS
    r_gmovi ge_movimientos%rowtype;
    -------------------------------------------------------
    -- Obj. Graba GE_MOVIMIENTOS de acuerdo a los parametros --
    -------------------------------------------------------
  BEGIN
    --g_lugar         := 'Genera_ge_movimientos';
    v_nro_secuencia := v_nro_secuencia + 1;
    --- Cargar registro de movimientos
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.nro_secuencia   := nvl(v_nro_secuencia, 1);
    r_gmovi.cod_modulo      := pag_Cta.G_CTAS.COD_MODULO;
    r_gmovi.cod_modalidad   := pag_cta.G_CTAS.COD_MODALIDAD;
    r_gmovi.cod_oficina     := pag_cta.G_CTAS.COD_OFICINA;
    r_gmovi.nro_cuenta      := p_cta_credito;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.fec_valor       := v_fecha;
    r_gmovi.fecha           := v_fecha;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.est_cuenta      := pag_cta.g_ctas.ESTADO;
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := TO_NUMBER(nvl(v_cod_oficina,
                                             it.fug_obt_ofi_matriz));
    r_gmovi.reversado       := 'N';
    r_gmovi.emi_aviso       := p_emi_aviso;
    r_gmovi.protegido       := 'N';
    r_gmovi.cod_mod_padre   := nvl(pag_Cta.g_ctas.COD_MODULO, 3);
    r_gmovi.cod_mad_padre   := nvl(pag_cta.g_ctas.COD_MODALIDAD, 31);
    r_gmovi.monto           := p_imp_transaccion;
    r_gmovi.nro_documento   := p_nro_documento;
    r_gmovi.cod_causa       := p_cod_causa;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
    v_nro_secuencia := nvl(v_nro_secuencia, 1) + 1;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,
                            'Error al generar Mov. Bloqueo Saldo -' || sqlerrm);
  END;
begin
  --Verificar Usuario ATM--
  if substr(user,1,3) = 'ATM' then
     v_usuario := fug_obt_pardinamico('COD_USU_ATM_ACTUAL');
     v_est_modulo := pae_cnf.fu_obt_est_modulo(3); -- CORECTRB-2 ABR/2018
  elsif  substr(UPPER(user),1,4) = 'HBAN' then
     v_est_modulo := pae_cnf.fu_obt_est_modulo(3); --21102020-Para igualar a ATM
      v_usuario := user;
  else
     v_usuario := user;
  end if;
  pag_cta.PR_OBT_CUENTA(p_cta_credito);
  begin
    select *
      into rg_solicitudes
      from pr_solicitudes a
     where a.cod_persona = p_cod_persona
       and a.estado = 'S'
       and nvl(fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',a.cod_modulo,a.cod_modalidad),'N') = 'S' -- PCCFPPTC-1 -- Flexibilidad en m�dulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
       and a.monto = p_monto
       and a.nro_solicitud = p_nro_solicitud;
  exception
    when no_data_found then
      Raise_application_error(-20000, 'No se encuentra la Solicitud de Pr�stamo!');
    when too_many_rows then
      Raise_application_error(-20000, 'Se recupera m�s de una Solicitud de Pr�stamo Pendiente!');
  end;
  v_cod_moneda := rg_solicitudes.cod_moneda;

  -- PCCDEEVO-214 Oferta Pre Aprobados en Cierre 06/2017.
  If v_est_modulo = 2 then
     v_es_nocturno := 'N';
     v_horario     := 'D' ;    -- D=Abierto, N=Cerrado
  else
     v_es_nocturno := 'S';
     v_horario     := 'N' ;    -- D=Abierto, N=Cerrado
     v_fecha       := pag_cal.fu_obt_fec_proxima(6);
  end if;
  -------**
  begin
    select count(1)
      into v_est_doc
      from ba_per_ima_documentos
     where cod_persona = p_cod_persona
     and cod_tip_documento = 64
     and est_doc = 'A';
  exception
    when no_data_found then
      v_est_doc := 0;
    when others then
      v_est_doc := 0;
  end;
  begin
    select count(1)
      into v_est_wf48
      from wf_circuitos
     where estado <> 'F'
     and referencia = p_cod_persona
     and cod_tip_circuito = 48;
  exception
    when no_data_found then
      v_est_wf48 := 0;
    when others then
      v_est_wf48 := 0;
  end;

  --obtenermos la hora disponible
  v_hora := fug_obt_hor_disponible(v_fecha,v_hora,v_usuario,v_es_nocturno);
  --valida que este todo ok antes del desembolso, luego genera la cuenta
  pap_pre.PR_DES_PRESTAMOS(rg_solicitudes.nro_solicitud,
                           rg_solicitudes.tot_desembolsar,
                           rg_solicitudes.fec_inicio,
                           rg_solicitudes.tip_documento,
                           1,
                           1,
                           rg_solicitudes.cod_oficina,
                           rg_solicitudes.cod_ori_fondo,
                           v_hora,
                           v_nro_secuencia,
                           v_nro_cuenta); --out
  v_cotizacion := null;
  if rg_solicitudes.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
    v_cotizacion := pag_gen.fu_obt_cotizacion(rg_solicitudes.cod_moneda,
                                              v_fecha);
  end if;
  --DYDMR-5803--Modificado por rpavon 03.01.17--
  --Setear variables para cargar usuario correcto--
  PAG_CTA.PR_SET_VARIABLES(v_usuario,
                           v_fecha,
                           358,
                           'N',-- estado
                           'N',-- reversado
                           v_nro_secuencia,
                           null,
                           rg_solicitudes.cod_oficina,
                           rg_solicitudes.cod_modulo,
                           rg_solicitudes.cod_modalidad);
  -- Actualiza el horario del pag_cta seg�n estado del modulo -- PCCDEEVO-214 06/2017
  pag_cta.g_horario := v_horario;
  --acreditacion a la cuenta
  pag_cta.PR_ACT_OPERACION(p_cta_credito,
                           v_hora,
                           'C', --credito
                           rg_solicitudes.cod_moneda,
                           rg_solicitudes.tot_desembolsar,
                           358,
                           602,
                           rg_solicitudes.nro_solicitud,
                           v_cotizacion,
                           rg_solicitudes.cod_oficina,
                           rg_solicitudes.cod_modulo,
                           rg_solicitudes.cod_modalidad,
                           null,
                           null,
                           'Desembolso de Sol. ' ||
                           rg_solicitudes.nro_solicitud,
                           'S', --emi_aviso
                           v_nro_secuencia,
                           v_fecha);
  if pag_cta.FU_OBT_COD_ERROR() <> 0 then
    raise_application_error(-20000,
                            'Error al desembolsar prestamo -' || pag_cta.FU_OBT_COD_ERROR()||'- '||pag_cta.FU_OBT_MSJ_ERROR()||'-'||sqlerrm);
  else
     --DA-10225 -glopez
    BEGIN
        update ge_clientes a
           set a.cod_seg_cliente = nvl(a.cod_seg_cliente,fug_obt_pardinamico('PRE_PLUS_SEGMENTO'))
         where a.cod_persona = p_cod_persona;
         if sql%notfound then
           raise_application_error(-20000, 'No se encuentra registro para actualizar');
         end if;
      EXCEPTION
        WHEN OTHERS THEN
         raise_application_error(-20000, 'Error al actualizar segmento de cliente ' ||
                         SQLERRM);
      END;
    /*update ge_pro_pre_aprobados a
       set a.estado = 'C'
     where a.cod_persona = p_cod_persona
       and a.estado = 'V'
       and a.cod_modulo = 6
       and a.cod_modalidad = 68
       and a.nro_solicitud = rg_solicitudes.nro_solicitud;*/

     -- PCCFPPTC-1 -- Flexibilidad en m�dulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
     --prg_can_pre_aprobado(p_cod_persona);
     prg_can_pre_aprobado(p_cod_persona, p_nro_solicitud);
     prg_rec_pre_aprobado(p_cod_persona, p_nro_solicitud);
     --PCCDEEVO-103 -- Envio de mail al gestor
     begin
       select distinct(a.cod_modalidad)
         into v_cod_modalidad
         from ge_cta_clientes a
        where a.cod_persona = p_cod_persona
          and a.nro_cuenta = rg_solicitudes.nro_cta_debito;
     exception
       when no_data_found then
         null;
     end;
     if pag_pre.fu_es_cta_nomina(p_cod_persona,rg_solicitudes.nro_cta_debito,v_cod_modalidad) = 'N' then --solo para los NO nominas
       begin
         v_cod_persona := rg_solicitudes.cod_persona;
         v_nom_cliente := fue_obt_nom_persona(v_cod_persona);
         v_cod_oficina := fug_obt_ofi_cliente(v_cod_persona);
         v_cod_canal   := rg_solicitudes.cod_canal;
         begin
           select a.cod_usu_oficial
             into v_cod_usu_oficial
             from ge_clientes a
            where a.cod_persona = v_cod_persona;
           begin
             select a.dir_correo
               into v_dir_correo
               from ba_usuarios a
              where a.cod_usuario = v_cod_usu_oficial;
           exception
             when no_data_found then
               v_dir_correo := '';
           end;
           begin
             select a.can_cuotas
               into v_can_cuotas
               from pr_cta_prestamos a
              where a.nro_solicitud = rg_solicitudes.nro_solicitud;
           exception
             when no_data_found then
               raise_application_error(-20000,'Error al buscar cuota ' || sqlerrm);
           end;
         end;
         v_texto := '<br><br>
                     <br><br>
                     El cliente ha desembolsado un Pr�stamo Pre-aprobado en el Canal '||v_cod_canal||'-'||fug_obt_des_canal(v_cod_canal)||
                     '<br><br>
                     Nombre del cliente: '||v_nom_cliente||
                     '<br><br>
                     Nro de Riesgo: '||v_cod_persona||
                     '<br><br>
                     Oficina: '||v_cod_oficina||
                     '<br><br>
                     Fecha de la contrataci�n del producto: '||v_fecha||
                     '<br><br>
                     Monto: '||trim(to_char(rg_solicitudes.tot_desembolsar,'999G999G999G999','NLS_NUMERIC_CHARACTERS = ".,"'))||' '||rg_solicitudes.cod_moneda||
                     '<br><br>
                     Plazo: '||rg_solicitudes.dia_plazo||' dias. Cantidad cuotas: '||v_can_cuotas||
                     '<br><br>
                     Modalidad: '||rg_solicitudes.cod_modalidad||'-'||fug_obt_des_modal(rg_solicitudes.cod_modulo,rg_solicitudes.cod_modalidad)||
                     '<br><br>'||v_mensaje||
                     '<br><br>
                      <br><br>';
         PRG_SEND_MAIL(p_to        => v_dir_correo,
                       p_from      => fug_obt_pardinamico('CAM_MAR_DIR_MAIL'),--'info@bbva.com.py',
                       p_subject   => 'Aceptaci�n Pre-preaprobado',
                       p_text_msg  => '',
                       p_html_msg  => v_membrete|| v_texto || v_fin || v_pie ,
                       p_smtp_host => fug_obt_pardinamico('DIR_SER_CORREOS'),
                       p_smtp_port => 25,
                       pcc         => V_DIR_CORREO_CC);
       exception
         when others then
         v_texto := substr(v_texto || '-Error: [' || sqlerrm || ']',1,4000);
         insert into tm_mails(env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
         values(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'), v_dir_correo, 'Aceptaci�n Pre-preaprobado', v_texto, sysdate, user);
       end;
     end if;

     ---**
     IF fug_val_con_uni_per(p_cod_persona) = 'N' or (v_est_doc > 0 and v_est_wf48 > 0 ) THEN
        v_cod_causa := fug_obt_pardinamico('PRE_COD_CAU_PRE_APROBADO');
        IF v_nro_doc_blo is null THEN
          BEGIN
            select s_nro_bloqueo.nextval into v_nro_doc_blo from dual;
          EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20000,
                            'Error al buscar sescuencia -' || sqlerrm);
              /*g_cod_error := '005';
              g_lugar     := 'Obtiene la secuencia del bloqueo';
              g_msj_error := 'Error al generar secuencia de bloqueo ' ||
                             SQLERRM;*/
          END;
        END IF;
        --
        --604

        BEGIN
          UPDATE ah_cta_vistas a
             SET a.fec_ult_movimiento = v_fecha,
                 a.hor_ult_movimiento = v_hora,
                 a.sal_bloqueado      = a.sal_bloqueado + p_monto,
                 a.estado = 'S'
           WHERE a.nro_cuenta = p_cta_credito;

          --seteamos el estado de la cuenta por que desde este punto debe figurar como bloqueado
          --para todos los movimientos
          pag_cta.g_ctas.estado := 'S';

        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                            'Error Actualiza Cuenta Ahorro -' || sqlerrm);
            /*g_cod_error := '007';
            g_lugar     := 'Actualiza Cuenta Ahorro';
            g_msj_error := 'Error al actualizar datos de la cuenta de ahorro ' ||
                           SQLERRM;*/
        END;
        --
        v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
        pr_ins_mov_bloqueo(307, 409, null, v_nro_doc_blo, v_cod_causa, 'N');
        --

        BEGIN
          insert into ge_bloqueos
            (nro_cuenta,
             fec_inicio,
             nro_documento,
             cod_causa,
             monto,
             hor_inicio,
             fec_fin,
             tipo,
             observacion)
          values
            (p_cta_credito,
             v_fecha,
             v_nro_doc_blo,
             v_cod_causa,
             p_monto,
             v_hora,
             null,
             'S',
             'BLOQUEO POR FALTA DE FIRMA DE CONTRATO UNICO.');
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al Insertar Bloqueos -' || sqlerrm);
/*            g_cod_error := '006';
            g_lugar     := 'Inserta Bloqueos';
            g_msj_error := 'Error al insertar bloqueos ' || SQLERRM;
*/        END;

        -- Insert ba_tab_dat_adicionales
    BEGIN
        insert into ba_tab_dat_adicionales
          (TAB_RELACION,
           REFERENCIA,
           PARAMETRO,
           VAL_PARAMETRO)
        values
          ('GE_BLOQUEOS',
           v_nro_doc_blo,
           'BLO_PRE_APROBADO',
           p_cta_credito);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, 'Error al Insertar Dat Adicionales -' || sqlerrm);
        /*g_cod_error := '008';
        g_lugar     := 'Inserta Dat Adicionales';
        g_msj_error := 'Error al insertar Dat_Adicionales ' || SQLERRM;*/
    END;

        pr_ins_mov_bloqueo(307,
                           604,
                           p_monto,
                           v_nro_doc_blo,
                           v_cod_causa,
                           'N');
        --notificacion de bloqueo de saldo--
        if nvl(v_dir_mail, 'X') <> 'X' then
          begin
            v_asunto := 'Saldo Bloqueado por Desembolso para persona  ' ||
                        FUE_OBT_NOM_PERSONA(p_cod_persona);
            v_tex_mail  := 'El saldo se encuentra bloqueado y la firma del CU debe ser regularizada.' ||
                        chr(10) || 'Cliente: ' || p_cod_persona || ' - ' ||
                        FUE_OBT_NOM_PERSONA(p_cod_persona) || chr(10) ||
                        'Cuenta Prestamo Desembolsado: ' || v_nro_cuenta ||
                        chr(10) || 'Cuenta Acreditada: ' ||
                        p_cta_credito || chr(10) ||
                        'Monto Desembolsado: ' || p_monto ||
                        chr(10);
            it_mail.mail(v_remitente, -- quien envia
                         v_dir_mail, -- a quien
                         v_asunto, -- asunto
                         v_tex_mail); -- detalle
          exception
            when others then
              null;
          end;
        end if;
        ------------------------------------

  ---**
  end if;

  END IF;
end prp_des_atm_prestamo;
/


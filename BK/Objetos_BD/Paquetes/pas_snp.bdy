create or replace package body it.PAS_SNP is

  /* variables para manejo de snp - se accede mediante funciones de recuperaci�n.. */
  g_cod_tra_padre ge_transacciones.cod_transaccion%type := 303;
  g_cod_mod_padre ge_transacciones.cod_modulo%type      := 4;
  g_cod_mad_padre ge_modalidades.cod_modalidad%type     := 455;
  g_cod_tra_cargo ge_transacciones.cod_transaccion%type := 196;
  g_cod_tra_impuesto      ge_transacciones.cod_transaccion%type := 517;
  g_cod_tra_indemnizacion ge_transacciones.cod_transaccion%type := 4602;
  g_env_alerta    varchar2(1) := 'S';

  /*Datos de conexion al socket*/
  g_servidor   constant varchar2(20):= fug_obt_pardinamico( 'SNP_SCK_DIR' );
  g_puerto     constant number(4)   := fug_obt_pardinamico( 'SNP_SCK_PUERTO' );
  g_tie_espera constant number(4)   := fug_obt_pardinamico( 'SNP_SCK_TIE_ESPERA' );
  g_ok                  varchar2(1) := 'N';

  /*Datos de la Operacion*/
  g_tip_canal           constant ge_par_dinamicos.val_parametro%type := nvl( fug_obt_pardinamico( 'TIP_CANAL' ), 'V' );
  g_dia_duplicacion     constant number := nvl( fug_obt_pardinamico ( 'SNP_DIA_DUPLICACION' ), 0 );
  g_dia_fec_valor       constant number := nvl( fug_obt_pardinamico ( 'SNP_RAN_DIA_FEC_VALOR' ), 0 );
  g_dia_max_reversion   constant number := nvl( fug_obt_pardinamico ( 'SNP_DIA_MAX_REVERSION' ), 0 );

  g_dir_mai_cumplimiento constant ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico( 'SNP_DIR_MAI_CUMPLIMIENTO' );
  g_ope_sup_mon_fuerte   constant number := nvl( fug_obt_pardinamico( 'OPE_SUP_MON_FUERTE' ), 0 );

  g_bic_hacienda         constant ge_snp_transferencias.cod_swi_pte_beneficiario%type := fug_obt_pardinamico('SNP_BIC_HACIENDA');

  g_cab_msj_swift       varchar2(200);

  /*Formato del Mensaje.*/
  --El salto configurado en ITGF es <CR+LF>
  g_salto         constant varchar2(2) := chr(13)||chr(10);

  --El salto configurado en el SOCKET es <*>
  g_sal_socket    constant varchar2(2) := '*';

  /*Formato de la m�scara para importes*/
  g_mascara       varchar2(15):= '999999999990D';
  g_car_013       varchar2(1) := 'N'; --SPI-2

/*Obtiene la ultima fecha del ultimo periodo para intercambios de mensajes con BCP*/
FUNCTION fu_obt_fec_ult_periodo ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                              p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                              p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type
                            ) return date
IS
   /*
   || Obtiene la fecha del ultimo periodo configurado seg�n el MT, Tipo Operaci�n y Sub Tipo Operaci�n
   */

   -- Tipo de dato para el vector
   type t_vector  is table of ge_snp_par_mensajes.cod_periodo%type
                              index by binary_integer;
   v_vector       t_vector;
   v_fecha       ge_snp_horarios.fecha%type;
   c_fec_actual   constant date := g_fec_actual;
   v_per_mayor    ge_snp_par_mensajes.cod_periodo%type:=0;

   PROCEDURE lp_ver_fec_periodo( p_cod_periodo in     ge_snp_horarios.cod_periodo%type,
                                 p_fecha       out    ge_snp_horarios.fecha%type
                               )
   IS
   BEGIN

      SELECT max(sh.fecha)
        INTO p_fecha
        FROM ge_snp_horarios sh
       WHERE sh.cod_periodo = p_cod_periodo;

   EXCEPTION
      when others then
         p_fecha := c_fec_actual;
   END lp_ver_fec_periodo;
BEGIN

  /*Inicializa las variables de error*/
  pas_snp.pr_ini_variables;
  --

  /*Inicializamos el vector*/
  v_vector.delete;

  if not fu_val_par_mensajes( p_cod_msj_swift,
                              p_tip_operacion,
                              p_sub_tip_operacion
                            )
  then
     pas_snp.g_cod_error := 41;
     pas_snp.g_msj_error := 'Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES';
     raise ex_salir;
  end if;

  begin
      select m.cod_periodo, m.cod_periodo2, m.cod_periodo3
        into v_vector(1),v_vector(2), v_vector(3)
        from ge_snp_par_mensajes m
       where m.cod_msj_swift                  = p_cod_msj_swift
         and m.cod_tip_operacion              = p_tip_operacion
         and nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x');
  exception
    when others then
      raise;
  end;

  if v_vector.COUNT > 0 then
     --Recuperamos los periodos del vector para la buscar el mayor periodo
     for i IN v_vector.FIRST..v_vector.LAST loop
        if v_vector.EXISTS(i) THEN
           if v_vector(i) > v_per_mayor then
              lp_ver_fec_periodo(v_vector(i),v_fecha);
           end if;
        end if;
     end loop;
  end if;

  return v_fecha;

EXCEPTION
  when ex_salir then
     return null;
  when others then
     pas_snp.g_cod_error  := 41;
     pas_snp.g_msj_error  := 'Error en PAS_SNP.FU_OBT_FEC_ULT_PERIODO, ' || sqlerrm ;
     return null;
END fu_obt_fec_ult_periodo;

PROCEDURE pr_ini_variables
IS
  /*
  || Inicializa las variables de error.
  */
BEGIN
   pas_snp.g_cod_error := 0;
   pas_snp.g_msj_error := NULL;
END pr_ini_variables;

PROCEDURE pr_ini_registros
IS
  /*
  || Inicializa variables del tipo ROWTYPE.
  */
BEGIN
   pas_snp.g_msj := NULL;
END pr_ini_registros;

FUNCTION fu_ini_hora( p_fecha in date default sysdate,
                      p_formato in varchar2 default 'HH24:MI:SS'
                    ) return varchar2
IS
  /* Retorna la siguiente HORA de GE_MOVIMIENTOS */
  v_hora     varchar2(8) := to_char( nvl( p_fecha, sysdate ), nvl( p_formato, 'HH24:MI:SS' ) );
  v_max_hora varchar2(8);

begin
  select nvl(max(hora),v_hora)
    into v_max_hora
    from ge_movimientos
   where cod_usuario = user;

  if v_max_hora >= v_hora then
     v_hora := pag_gen.fu_obt_sig_segundo(v_max_hora);
  end if;

  if v_hora = '00:00:00' then
     select nvl(max(hora),v_hora)
       into v_max_hora
       from ge_movimientos
      where cod_usuario = user
        and hora < '06:00:00';
     if v_max_hora >= v_hora then
        v_hora := pag_gen.fu_obt_sig_segundo(v_max_hora);
     end if;
  end if;

  RETURN v_hora;
EXCEPTION
  when others then
     RETURN v_hora;
END fu_ini_hora;

PROCEDURE pr_set_texto ( p_texto in out varchar2, p_dato varchar2, p_separador varchar2 default ' ' )
IS
  /*
  || Adiciona datos a un texto.
  */
BEGIN

  if p_texto is null THEN
     p_texto := p_dato;
  else
     p_texto := substr( p_texto || p_separador || p_dato, 1, 4000 );
  end if;

END pr_set_texto;

PROCEDURE pr_obt_mensaje( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                          p_ind_validar    in char default 'S'
                        ) is
  /*
  || Recupera los datos de la mensajer�a.
  || Se agrega este cursor para los mensajes que son por lotes, ya que para
  || los mismos solo debe de tomar algunos datos del primer registro solamente.
  */
  v_nro_referencia ge_snp_transferencias.nro_referencia%type := p_nro_referencia;
  v_ind_validar    varchar2(1)                               := p_ind_validar ;
  cursor cu_msj_tra is
     select t.nro_referencia, t.nro_lote, t.nro_sec_lote, t.cod_modulo, t.cod_modalidad,
            t.cod_oficina, t.cod_msj_swift, t.cod_tip_operacion, t.cod_sub_tip_operacion,
            t.msj_swift, t.fec_ingreso, t.fec_recepcion, t.fec_valor, t.fecha, t.hora,
            t.cod_usuario, t.cod_moneda, t.monto, t.cod_per_solicitante, t.nom_solicitante,
            t.dir_solicitante, t.cod_tip_doc_solicitante, t.nro_doc_solicitante, t.nro_cta_solicitante,
            t.cod_swi_pte_solicitante, t.cod_swi_suc_solicitante, t.nro_cta_pte_solicitante,
            t.nro_cta_suc_pte_solicitante, t.cod_per_beneficiario, t.nom_beneficiario,
            t.dir_beneficiario, t.cod_tip_doc_beneficiario, t.nro_doc_beneficiario, t.nro_cta_beneficiario,
            t.cod_swi_pte_beneficiario, t.cod_swi_suc_beneficiario, t.nro_cta_pte_beneficiario,
            t.nro_cta_suc_pte_beneficiario, t.concepto, t.observacion, t.nro_ref_externa,
            t.tip_cargo, t.mto_cargo, t.ind_valor, t.situacion, t.estado, t.tip_rechazo,
            t.prioridad, t.nro_operacion, t.tip_mensaje, t.cod_usu_transaccion, t.ref_oid,
            t.imp_inf_hacienda, t.error, t.origen, t.plataforma,
            t.indemnizado, t.cod_servicio, t.usu_insercion, t.usu_modificacion,to_char(t.fec_insercion,'dd/mm/yyyy hh24:mi:ss')
       from ge_snp_transferencias t
      where t.nro_referencia  = v_nro_referencia;

  FUNCTION lf_obt_mov_relacionado ( p_fecha   ge_movimientos.fecha%type,
                                    p_hora    ge_movimientos.hora%type,
                                    p_usuario ge_movimientos.cod_usuario%type
                                  ) return boolean

  IS
  BEGIN
     FOR i in ( Select /*+ NO_UNNEST */ distinct '1'
                       from gv_movimientos m
                      where m.fecha       = p_fecha
                        and m.hora        = p_hora
                        and m.cod_usuario = p_usuario
                        and m.reversado   = 'N' ) LOOP
          return TRUE;
     END LOOP;
     return FALSE;
  EXCEPTION
    when others then
       return FALSE;
  END lf_obt_mov_relacionado;

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   /*Inicializa variables del tipo ROWTYPE*/
   pas_snp.pr_ini_registros;

   g_lugar := 'Obteniendo datos de GE_SNP_TRANSFERENCIAS, ';

   if cu_msj_tra%isopen then
      close cu_msj_tra;
   END if;

   open cu_msj_tra;
   fetch cu_msj_tra
    into g_msj.nro_referencia, g_msj.nro_lote, g_msj.nro_sec_lote, g_msj.cod_modulo, g_msj.cod_modalidad,
         g_msj.cod_oficina, g_msj.cod_msj_swift, g_msj.cod_tip_operacion, g_msj.cod_sub_tip_operacion,
         g_msj.msj_swift, g_msj.fec_ingreso, g_msj.fec_recepcion, g_msj.fec_valor, g_msj.fecha, g_msj.hora,
         g_msj.cod_usuario, g_msj.cod_moneda, g_msj.monto, g_msj.cod_per_solicitante, g_msj.nom_solicitante,
         g_msj.dir_solicitante, g_msj.cod_tip_doc_solicitante, g_msj.nro_doc_solicitante, g_msj.nro_cta_solicitante,
         g_msj.cod_swi_pte_solicitante, g_msj.cod_swi_suc_solicitante, g_msj.nro_cta_pte_solicitante,
         g_msj.nro_cta_suc_pte_solicitante, g_msj.cod_per_beneficiario, g_msj.nom_beneficiario,
         g_msj.dir_beneficiario, g_msj.cod_tip_doc_beneficiario, g_msj.nro_doc_beneficiario, g_msj.nro_cta_beneficiario,
         g_msj.cod_swi_pte_beneficiario, g_msj.cod_swi_suc_beneficiario, g_msj.nro_cta_pte_beneficiario,
         g_msj.nro_cta_suc_pte_beneficiario, g_msj.concepto, g_msj.observacion, g_msj.nro_ref_externa,
         g_msj.tip_cargo, g_msj.mto_cargo, g_msj.ind_valor, g_msj.situacion, g_msj.estado, g_msj.tip_rechazo,
         g_msj.prioridad, g_msj.nro_operacion, g_msj.tip_mensaje, g_msj.cod_usu_transaccion, g_msj.ref_oid,
         g_msj.imp_inf_hacienda, g_msj.error, g_msj.origen, g_msj.plataforma,
         g_msj.indemnizado, g_msj.cod_servicio, g_msj.usu_insercion, g_msj.usu_modificacion,g_msj.fec_insercion;
   if cu_msj_tra%notfound then
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MENSAJE, no se encuentran datos para Nro. Referencia: '||v_nro_referencia;
      pas_snp.g_cod_error := 16;
   end if;

   /*Verificar si es fecha futura para no validar movimientos */
   if g_msj.fec_valor <> g_fec_actual then
      v_ind_validar := 'N' ;
   end if ;
   /*
   || No existen movimientos generados al recibir la mensajer�a desde el socket, primeramente,
   || es por ello que se agrega el indicador VALIDAR, para re-utilizar el procedimiento y as�
   || obtener los datos de la mensajer�a, independiente a si tiene o no un movimiento relacionado,
   || esto se verificar� con el INDICADOR de VALIDACION
   ||      (S)= Si valida con los movimientos que gener�
   ||      Cual otra opci�n NO VALIDAR� con movimientos, solo recuperar� los datos de la mensajer�a
   */

   if v_ind_validar = 'S' and not lf_obt_mov_relacionado ( g_msj.fecha, g_msj.hora, g_msj.cod_usuario ) then
      pas_snp.pr_set_texto(pas_snp.g_msj_error, 'Buscando movimientos, no se encuentran movimientos para la Ref.: ' || v_nro_referencia, ' ' );

      if g_msj.fecha is not null then
        pas_snp.pr_set_texto(pas_snp.g_msj_error, 'Fecha ' || to_char( g_msj.fecha,'DD/MM/YYYY' ), ', ' );
      end if;
      if g_msj.hora is not null then
        pas_snp.pr_set_texto(pas_snp.g_msj_error, 'Hora ' || g_msj.hora, ', ' );
      end if;
      if g_msj.cod_usuario is not null then
        pas_snp.pr_set_texto(pas_snp.g_msj_error, 'Usuario ' || g_msj.cod_usuario, ', ' );
      end if;
      pas_snp.g_cod_error := 16;
      pas_snp.pr_ini_registros;
   end if;

   close cu_msj_tra;
EXCEPTION
   When Others then
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MENSAJE '||sqlerrm;
      pas_snp.g_cod_error := 16;
END pr_obt_mensaje;

PROCEDURE pr_val_cod_swi_participante( p_cod_swi_participante in out ge_snp_transferencias.cod_swi_pte_solicitante%type )
IS
BEGIN
  -- Recupera el c�digo swift configurado en ITGF a partir del c�digo SWIFT recibido como par�metro.
  select v.cod_swift
    into p_cod_swi_participante
    from gv_snp_participantes v
   where rpad( v.cod_swift, 11, 'X' ) = rpad( p_cod_swi_participante, 11, 'X' );
EXCEPTION
  when no_data_found then
    --busca en la tabla del patrocinador--
    begin
      select distinct d.cod_swift_sub
        into p_cod_swi_participante
        from ge_snp_patrocinador_cab s , ge_snp_patrocinador_det d
       where s.cod_swift = d.cod_swift_padre
         and d.estado = 'S'
         and d.cod_swift_sub = p_cod_swi_participante;
        exception
          when no_data_found then
            pas_snp.g_cod_error := 84;
            pas_snp.g_msj_error := 'BIC ' || p_cod_swi_participante || ' del Participante no coincide con el registrado en ITGF.!';
          when others then
            pas_snp.g_cod_error := 84;
            pas_snp.g_msj_error := 'Error en PAS_SNP.PR_VAL_COD_SWI_PARTICIPANTE: ' || sqlerrm;
    end;
END pr_val_cod_swi_participante;

PROCEDURE pr_obt_dat_participante( p_cod_swi_participante in     ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                   rg_dat_pte             in out rg_pte
                                 ) is
  /*
  || Recupera los datos del participante.
  */
  cursor cu_dat_pte is
     select v.cod_persona, v.ind_swi_propio,
            v.ind_hab_pte_hb, v.ind_val_fmt_msj_recibido
       from gv_snp_participantes v, ba_personas p
      where v.cod_persona = p.cod_persona
        and v.cod_swift   = p_cod_swi_participante;

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   g_lugar := 'Obteniendo datos del Participante, ';

   if cu_dat_pte%isopen then
      close cu_dat_pte;
   END if;

   open cu_dat_pte;
   fetch cu_dat_pte
    into rg_dat_pte.cod_persona,
         rg_dat_pte.ind_swi_propio,
         rg_dat_pte.ind_hab_pte_hb,
         rg_dat_pte.ind_val_fmt_msj_recibido;

   if cu_dat_pte%notfound then
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_DAT_PARTICIPANTE, no se encuentran datos para el SWIFT: ' || p_cod_swi_participante;
      pas_snp.g_cod_error := 82;
   else
      rg_dat_pte.nom_persona         := fue_obt_nom_persona( rg_dat_pte.cod_persona );
      rg_dat_pte.cod_tip_doc_persona := fue_obt_doc_principal( rg_dat_pte.cod_persona );
      rg_dat_pte.nro_doc_persona     := substr( fue_obt_nro_doc_persona( rg_dat_pte.cod_persona ), 1, 20 );
      rg_dat_pte.dir_persona         := fue_obt_dir_principa( rg_dat_pte.cod_persona );
   end if;

   close cu_dat_pte;
EXCEPTION
   When Others then
      rg_dat_pte := NULL;
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_DAT_PARTICIPANTE '||sqlerrm;
      pas_snp.g_cod_error := 82;
END pr_obt_dat_participante;

PROCEDURE pr_gen_msj_invertido( rg_msj_ent in  pas_snp.rg_msj,
                                rg_msj_sal out pas_snp.rg_msj
                              )
IS
  /*Invierte un mensaje RECIBIDO para operaciones de reversos*/
  v_det_error   pas_snp.g_det_msj_error%type := NULL;
  v_des_rechazo ba_cod_referencias.abreviatura%type := NULL;
  v_nro_cta_pte_beneficiario ge_snp_transferencias.nro_cta_pte_beneficiario%type := NULL;
  v_cod_swi_pte_beneficiario ge_snp_transferencias.cod_swi_pte_beneficiario%type := NULL;
  v_nro_cta_cli_beneficiario ge_par_entes_det.val_parametro%type := NULL;
  v_des_cta_cli_beneficiario ge_par_entes_det.descripcion%type := NULL;
  v_tip_doc_cli_beneficiario ba_tip_documentos.cod_tip_documento%type := NULL;
  v_nro_doc_cli_beneficiario ge_par_entes_det.ref_adicional%type := NULL;
BEGIN

     if pas_snp.fu_val_es_enviado ( rg_msj_ent ) then
        pas_snp.pr_set_texto ( v_det_error, 'El mensaje est� catalogado como ENVIADO. El mensaje debe ser RECIBIDO.!', pas_snp.fu_obt_salto );
     end if;

     if rg_msj_ent.fec_valor is null then
        pas_snp.pr_set_texto ( v_det_error, 'Debe ingresar algun valor para el campo Fec. Valor.!', pas_snp.fu_obt_salto );
     end if;

     if rg_msj_ent.prioridad is null then
        pas_snp.pr_set_texto ( v_det_error, 'El campo Prioridad no puede ser nulo.!', pas_snp.fu_obt_salto );
     end if;

     if rg_msj_ent.nro_cta_suc_pte_solicitante is not null and
        rg_msj_ent.cod_swi_suc_solicitante is null
     then
        pas_snp.pr_set_texto ( v_det_error, 'El BIC de la Sucursal del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
     elsif rg_msj_ent.nro_cta_suc_pte_solicitante is null and
        rg_msj_ent.cod_swi_suc_solicitante is not null
     then
        pas_snp.pr_set_texto ( v_det_error, 'La cuenta de liquidaci�n para la Sucursal del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
     end if;

     if rg_msj_ent.nro_cta_suc_pte_solicitante is not null and
        rg_msj_ent.cod_swi_suc_solicitante is not null
     then
       if pas_snp.fu_obt_mon_cta_participante( rg_msj_ent.nro_cta_suc_pte_solicitante, rg_msj_ent.cod_moneda ) is not null then
          if pas_snp.fu_obt_mon_cta_participante( rg_msj_ent.nro_cta_suc_pte_solicitante, rg_msj_ent.cod_moneda ) <> rg_msj_ent.cod_moneda then
             -- Si la moneda de la cuenta de la sucursal es diferente a la moneda de la transferecia se obtienen
             -- los datos necesarios para retornar el mensaje recibido.
             begin
               select ped.val_parametro, ped.descripcion, fue_obt_tip_documento( 'RUC' ), ped.ref_adicional
                 into v_nro_cta_cli_beneficiario, v_des_cta_cli_beneficiario, v_tip_doc_cli_beneficiario, v_nro_doc_cli_beneficiario
                 from ge_par_entes_det ped
                where ped.parametro  = 'SNP_CTA_CRE_REI_MIH'
                  and ped.cod_moneda = rg_msj_ent.cod_moneda
                  and exists( select 0
                                from ge_par_entes gpe
                               where gpe.parametro     = 'COD_SWIFT'
                                 and gpe.val_parametro = pas_snp.g_bic_hacienda
                                 and gpe.cod_ente      = ped.cod_ente
                            );
               v_cod_swi_pte_beneficiario := pas_snp.g_bic_hacienda;
               v_nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante( v_cod_swi_pte_beneficiario, rg_msj_ent.cod_moneda );
               if pas_snp.fu_obt_cod_error <> 0 then
                  pas_snp.pr_set_texto ( v_det_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               end if;
             exception
               when no_data_found then
                 v_nro_cta_pte_beneficiario := NULL;
                 v_cod_swi_pte_beneficiario := NULL;
                 v_nro_cta_cli_beneficiario := NULL;
                 v_des_cta_cli_beneficiario := NULL;
                 v_tip_doc_cli_beneficiario := NULL;
                 v_nro_doc_cli_beneficiario := NULL;
                 pas_snp.pr_set_texto ( v_det_error, 'Cuenta de reintegro para el Ministerio de Hacienda en la moneda '||rg_msj_ent.cod_moneda||' inexistente.', pas_snp.fu_obt_salto );
               when too_many_rows then
                 v_nro_cta_pte_beneficiario := NULL;
                 v_cod_swi_pte_beneficiario := NULL;
                 v_nro_cta_cli_beneficiario := NULL;
                 v_des_cta_cli_beneficiario := NULL;
                 v_tip_doc_cli_beneficiario := NULL;
                 v_nro_doc_cli_beneficiario := NULL;
                 pas_snp.pr_set_texto ( v_det_error, 'Existes varias cuentas de reintegro para el Ministerio de Hacienda en la moneda '||rg_msj_ent.cod_moneda||'.', pas_snp.fu_obt_salto );
               when others then
                 v_nro_cta_pte_beneficiario := NULL;
                 v_cod_swi_pte_beneficiario := NULL;
                 v_nro_cta_cli_beneficiario := NULL;
                 v_des_cta_cli_beneficiario := NULL;
                 v_tip_doc_cli_beneficiario := NULL;
                 v_nro_doc_cli_beneficiario := NULL;
                 pas_snp.pr_set_texto ( v_det_error, 'Buscando cuenta de reintegro para el Ministerio de Hacienda en la moneda '||rg_msj_ent.cod_moneda||': '||sqlerrm, pas_snp.fu_obt_salto );
             end;
          end if;
       else
          pas_snp.pr_set_texto ( v_det_error, 'No se encuentra la moneda para la cuenta de la sucursal '||rg_msj_ent.nro_cta_suc_pte_solicitante||'.', pas_snp.fu_obt_salto );
       end if;
     end if;

     if v_det_error is null then -- Si no tiene ERRORES se invierte la mensajer�a
        rg_msj_sal.nro_ref_externa              := rg_msj_ent.nro_ref_externa;
        rg_msj_sal.cod_modulo                   := rg_msj_ent.cod_modulo;
        rg_msj_sal.cod_modalidad                := rg_msj_ent.cod_modalidad;
        rg_msj_sal.cod_oficina                  := rg_msj_ent.cod_oficina;
        rg_msj_sal.cod_msj_swift                := rg_msj_ent.cod_msj_swift;
        rg_msj_sal.cod_tip_operacion            := rg_msj_ent.cod_tip_operacion;
        rg_msj_sal.cod_sub_tip_operacion        := rg_msj_ent.cod_sub_tip_operacion;
        rg_msj_sal.fec_ingreso                  := g_fec_actual;
        rg_msj_sal.fec_recepcion                := null;
        rg_msj_sal.fec_valor                    := g_fec_actual;
        rg_msj_sal.fecha                        := rg_msj_ent.fecha;
        rg_msj_sal.hora                         := rg_msj_ent.hora;
        rg_msj_sal.cod_usuario                  := rg_msj_ent.cod_usuario;
        rg_msj_sal.cod_moneda                   := rg_msj_ent.cod_moneda;
        rg_msj_sal.monto                        := rg_msj_ent.monto;
        -----------------------------------------------------------------------------
        rg_msj_sal.cod_per_solicitante          := rg_msj_ent.cod_per_beneficiario;
        rg_msj_sal.nom_solicitante              := rg_msj_ent.nom_beneficiario;
        rg_msj_sal.dir_solicitante              := rg_msj_ent.dir_beneficiario;
        rg_msj_sal.cod_tip_doc_solicitante      := rg_msj_ent.cod_tip_doc_beneficiario;
        rg_msj_sal.nro_doc_solicitante          := rg_msj_ent.nro_doc_beneficiario;
        rg_msj_sal.nro_cta_solicitante          := rg_msj_ent.nro_cta_beneficiario;
        rg_msj_sal.cod_swi_pte_solicitante      := nvl(rg_msj_ent.cod_swi_pte_beneficiario, pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
        rg_msj_sal.cod_swi_suc_solicitante      := rg_msj_ent.cod_swi_suc_beneficiario;
        rg_msj_sal.nro_cta_pte_solicitante      := rg_msj_ent.nro_cta_pte_beneficiario;
        rg_msj_sal.nro_cta_suc_pte_solicitante  := rg_msj_ent.nro_cta_suc_pte_beneficiario;
        -----------------------------------------------------------------------------
        rg_msj_sal.cod_per_beneficiario         := rg_msj_ent.cod_per_solicitante;
        rg_msj_sal.nom_beneficiario             := nvl( v_des_cta_cli_beneficiario, rg_msj_ent.nom_solicitante );
        rg_msj_sal.dir_beneficiario             := rg_msj_ent.dir_solicitante;
        rg_msj_sal.cod_tip_doc_beneficiario     := nvl( v_tip_doc_cli_beneficiario, rg_msj_ent.cod_tip_doc_solicitante );
        rg_msj_sal.nro_doc_beneficiario         := nvl( v_nro_doc_cli_beneficiario, rg_msj_ent.nro_doc_solicitante );
        rg_msj_sal.nro_cta_beneficiario         := nvl( v_nro_cta_cli_beneficiario, rg_msj_ent.nro_cta_solicitante );
        rg_msj_sal.cod_swi_pte_beneficiario     := nvl( v_cod_swi_pte_beneficiario, rg_msj_ent.cod_swi_pte_solicitante );
        rg_msj_sal.cod_swi_suc_beneficiario     := CASE WHEN v_nro_cta_cli_beneficiario IS NULL THEN rg_msj_ent.cod_swi_suc_solicitante ELSE NULL END;
        rg_msj_sal.nro_cta_pte_beneficiario     := nvl( v_nro_cta_pte_beneficiario, rg_msj_ent.nro_cta_pte_solicitante );
        rg_msj_sal.nro_cta_suc_pte_beneficiario := CASE WHEN v_nro_cta_cli_beneficiario IS NULL THEN rg_msj_ent.nro_cta_suc_pte_solicitante ELSE NULL END;
        -----------------------------------------------------------------------------
        rg_msj_sal.concepto                     := rg_msj_ent.concepto;
        rg_msj_sal.observacion                  := rg_msj_ent.observacion;
        rg_msj_sal.ref_oid                      := rg_msj_ent.ref_oid;
        rg_msj_sal.tip_cargo                    := rg_msj_ent.tip_cargo;
        rg_msj_sal.ind_valor                    := rg_msj_ent.ind_valor;
        rg_msj_sal.situacion                    := 'P';
        rg_msj_sal.estado                       := 'R';
        rg_msj_sal.tip_rechazo                  := rg_msj_ent.tip_rechazo;
        rg_msj_sal.prioridad                    := rg_msj_ent.prioridad;
        rg_msj_sal.tip_mensaje                  := rg_msj_ent.tip_mensaje;
        rg_msj_sal.origen                       := rg_msj_ent.origen;
        rg_msj_sal.plataforma                   := rg_msj_ent.plataforma;
        rg_msj_sal.indemnizado                  := 'N';
        rg_msj_sal.cod_servicio                 := rg_msj_ent.cod_servicio;
        -----------------------------------------------------------------------------
        rg_msj_sal.nro_operacion                := rg_msj_ent.nro_referencia;
        rg_msj_sal.nro_referencia               := pas_snp.fu_obt_sig_nro_referencia;
        rg_msj_sal.imp_inf_hacienda             := rg_msj_ent.imp_inf_hacienda;
        -----------------------------------------------------------------------------

        --Sintaxis de reversi�n alto valor : /REV/Referencia del mensaje original a reversar
        --                                   /OID/AAMMDDXXXXXXXXXXXX9999999999
        --                                   //<c�digo de reverso>/[<descripci�n del reverso>]

        --Sintaxis de reversi�n bajo valor : /REV/Referencia del mensaje original a reversar
        --                                   /<c�digo de reverso>/[<descripci�n del reverso>]

        begin
          v_des_rechazo := fue_obt_des_refcodes('TIP_REC_SNP', rg_msj_ent.tip_rechazo );
          if upper( v_des_rechazo ) like '%REF%NO%REG%SISTEMA%' then
             -- No se ha encontrado la descripci�n del valor TIP_RECHAZO en BA_COD_REFERENCIAS,
             -- se env�a el tipo rechazo 999-Otros
             v_des_rechazo := fue_obt_des_refcodes('TIP_REC_SNP', '999' );
             rg_msj_sal.tip_rechazo := 999;
             if upper( v_des_rechazo ) like '%REF%NO%REG%SISTEMA%' then
                -- Si no se vuelve a encontrar la descripci�n para el tipo rechazo 999, enviar fijo 999-Otros
                v_des_rechazo := 'Otros';
             end if;
          end if;
        exception
           when others then
             rg_msj_sal.tip_rechazo := 999;
             v_des_rechazo := 'Otros';
        end;

        if rg_msj_sal.cod_msj_swift in ( 103, 202 ) then
           rg_msj_sal.observacion := '/REV/' || rg_msj_ent.nro_ref_externa || pas_snp.fu_obt_salto;
           if rg_msj_sal.ref_oid is not null then
              /* Anexa /OID/ */
              rg_msj_sal.observacion := rg_msj_sal.observacion || rg_msj_sal.ref_oid || pas_snp.fu_obt_salto;
           end if;
           rg_msj_sal.observacion := rg_msj_sal.observacion ||
                                    '//' || rg_msj_ent.tip_rechazo || '/' || substr( v_des_rechazo, 1, 29 );
        elsif rg_msj_sal.cod_msj_swift = 102 then
           rg_msj_sal.concepto    := '/REV/' || rg_msj_ent.nro_sec_lote || pas_snp.fu_obt_salto ||
                                     '/'     || rg_msj_ent.tip_rechazo  || '/'             ||
                                     substr( v_des_rechazo, 1, 29 );
        end if;
     else
       rg_msj_sal          := null;
       pas_snp.g_cod_error := 68;
       pas_snp.g_msj_error := substr( v_det_error, 1, 1000 );
     end if;
EXCEPTION
   WHEN others THEN
      rg_msj_sal          := null;
      pas_snp.g_cod_error := 68;
      pas_snp.g_msj_error := 'Error al generar el MT de Reverso. Nro. Ref.: ' || rg_msj_ent.nro_ref_externa || ' - ' || sqlerrm;
END pr_gen_msj_invertido;

FUNCTION fu_obt_nro_ref_interna( p_referencia       in ge_snp_transferencias.nro_ref_externa%type,
                                 p_cta_participante in ge_snp_transferencias.nro_cta_pte_solicitante%type,
                                 p_fec_valor        in ge_snp_transferencias.fec_valor%type default null
                               ) return number
IS
  /*Recupera el número de referencia interno de la mensajería ENVIADA o RECIBIDA para un MT900 ó MT910*/
  v_nro_referencia ge_snp_transferencias.nro_ref_externa%type := NULL;
  cursor cu_msj_tra is
     -- MT enviados
     SELECT t.nro_referencia
       FROM ge_snp_transferencias t
      WHERE to_char(t.nro_referencia)    = p_referencia
        AND ( t.nro_cta_pte_solicitante  = p_cta_participante OR  -- Cuando son operaciones de Retiro / Depósito en Efectivo,
              t.nro_cta_pte_beneficiario = p_cta_participante     -- la Cuenta Física de nuestra entidad puede venir en
            )                                                     -- el Pte. Solicitante o en el Pte. Beneficiario */
        AND t.fec_valor                  = p_fec_valor
        AND t.fec_recepcion              IS NULL
        AND t.cod_msj_swift != 202 --TCE-1347
        AND t.situacion != 'L' --TCE-488
        AND t.plataforma                 = 'X'
     UNION ALL
     -- MT103 recibidos
     SELECT r.nro_referencia
       FROM ge_snp_transferencias r
      WHERE r.nro_ref_externa            = p_referencia
        AND ( r.nro_cta_pte_solicitante  = p_cta_participante OR  -- Cuando son operaciones de Débito / Crédito Directo,
              r.nro_cta_pte_beneficiario = p_cta_participante     -- la Cuenta Física de nuestra entidad puede venir en
            )                                                     -- el Pte. Solicitante como en el Pte. Beneficiario */
        AND r.fec_valor                  = p_fec_valor
        AND r.fec_recepcion              IS NOT NULL
        AND r.cod_msj_swift != 202 --TCE-1347
        AND r.situacion != 'L' --TCE-488
        AND NOT ( r.situacion = 'R'
            AND r.estado = 'R')--TCE-1347
        AND r.plataforma                 = 'X'
      UNION ALL   ----TCE-1347 fondeo
     -- MT202 enviados
     SELECT e.nro_referencia
       FROM ge_snp_transferencias e
      WHERE to_char(e.nro_referencia)    = p_referencia
        AND ( e.nro_cta_pte_solicitante  = p_cta_participante OR  -- Cuando son operaciones de Retiro / Depósito en Efectivo,
              e.nro_cta_pte_beneficiario = p_cta_participante     -- la Cuenta Física de nuestra entidad puede venir en
            )                                                     -- el Pte. Solicitante o en el Pte. Beneficiario */
        AND e.fec_valor                  = p_fec_valor
        AND e.fec_recepcion              IS NULL
        AND e.cod_msj_swift = 202
        AND e.plataforma                 = 'X'
     UNION ALL --TCE-1347
     -- MT202 recibidos 
     SELECT s.nro_referencia
       FROM ge_snp_transferencias s
      WHERE s.nro_ref_externa            = p_referencia
        AND ( s.nro_cta_pte_solicitante  = p_cta_participante OR  -- Cuando son operaciones de Débito / Crédito Directo,
              s.nro_cta_pte_beneficiario = p_cta_participante     -- la Cuenta Física de nuestra entidad puede venir en
            )                                                     -- el Pte. Solicitante como en el Pte. Beneficiario */
        AND s.fec_valor                  = p_fec_valor
        AND s.fec_recepcion              IS NOT NULL
        AND s.cod_msj_swift = 202 
        AND s.plataforma                 = 'X';


BEGIN
   FOR c IN cu_msj_tra LOOP
      v_nro_referencia := c.nro_referencia;
   END LOOP;
   RETURN v_nro_referencia;
END fu_obt_nro_ref_interna;

FUNCTION fu_obt_des_tip_operacion( p_cod_swift         in ge_snp_transferencias.cod_msj_swift%type,
                                   p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                   p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type default null
                                 ) return varchar2
IS
   /*Retorna la descripci�n del tipo/subtipo de operaci�n seg�n el MT*/
   v_des_tip_operacion ge_snp_par_mensajes.descripcion%type := null;
BEGIN
  SELECT m.descripcion
    INTO v_des_tip_operacion
    FROM ge_snp_par_mensajes m
   WHERE m.cod_msj_swift                  = p_cod_swift
     AND nvl(m.cod_tip_operacion,'x')     = nvl(p_tip_operacion,'x')
     AND nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x');
  RETURN v_des_tip_operacion;
EXCEPTION
   when others then
     return 'Tipo de Operaci�n no registrado en el Sistema';
END fu_obt_des_tip_operacion;

FUNCTION fu_obt_des_prioridad ( p_tip_prioridad in varchar2 ) return varchar2
IS
   /*Retorna la descripci�n del grupo de prioridades para los mensajes*/
   cursor c_prioridad is
      select substr('(' || cr.val_minimo || ' al ' || cr.val_maximo || ') ' || cr.significado,1,100) des_prioridad
        from ba_cod_referencias cr
       where cr.dominio = 'SNP_MSJ_PRIORIDAD'
         and cr.abreviatura = nvl( p_tip_prioridad, cr.abreviatura )
       order by to_number(nvl(val_minimo,0)), to_number(nvl(val_maximo,0));
   v_des_prioridad varchar2(4000) := NULL;
BEGIN
  for p in c_prioridad loop
    pr_set_texto(v_des_prioridad, p.des_prioridad, pas_snp.fu_obt_salto);
  end loop;
  RETURN v_des_prioridad;
EXCEPTION
   when others then
     return 'Significado de las diferentes prioridades habilitadas.';
END fu_obt_des_prioridad;

PROCEDURE pr_obt_par_mensajes( p_cod_swift         in  ge_snp_transferencias.cod_msj_swift%type,
                               p_tip_operacion     in  ge_snp_transferencias.cod_tip_operacion%type,
                               p_sub_tip_operacion in  ge_snp_transferencias.cod_sub_tip_operacion%type default null,
                               p_ind_transaccion   in  varchar2 default 'E',
                               p_cod_modulo        out ge_transacciones.cod_modulo%type,
                               p_cod_modalidad     out ge_transacciones.cod_modalidad%type,
                               p_cod_transaccion   out ge_transacciones.cod_transaccion%type
                             )
IS
  /*Retorna datos necesarios para la generaci�n de movimientos para los MTs*/
  v_cod_modulo      ge_transacciones.cod_modulo%type;
  v_cod_modalidad   ge_transacciones.cod_modalidad%type;
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
BEGIN
  if not fu_val_par_mensajes( p_cod_swift,
                              p_tip_operacion,
                              p_sub_tip_operacion
                            )
  then
     pas_snp.g_cod_error := 64;
     pas_snp.g_msj_error := 'Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES';
     raise ex_salir;
  end if;

  SELECT distinct m.cod_modulo, m.cod_modalidad,
         decode( p_ind_transaccion, 'E', m.cod_tra_emitido, m.cod_tra_recibido ) cod_transaccion
    INTO v_cod_modulo, v_cod_modalidad,
         v_cod_transaccion
    FROM ge_snp_par_mensajes m
   WHERE m.cod_msj_swift                  = p_cod_swift
     AND m.cod_tip_operacion              = p_tip_operacion
     AND nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x');

  if v_cod_modulo is null or
     v_cod_modalidad is null or
     v_cod_transaccion is null
  then
     pas_snp.g_cod_error := 64;
     pas_snp.g_msj_error := 'M�dulo � Modalidad � Transacci�n no pueden ser nulos en GE_SNP_PAR_MENSAJES';
     raise ex_salir;
  end if;

  p_cod_modulo      := v_cod_modulo;
  p_cod_modalidad   := v_cod_modalidad;
  p_cod_transaccion := v_cod_transaccion;

EXCEPTION
  when ex_salir then
    p_cod_modulo      := NULL;
    p_cod_modalidad   := NULL;
    p_cod_transaccion := NULL;
  when others then
    p_cod_modulo        := NULL;
    p_cod_modalidad     := NULL;
    p_cod_transaccion   := NULL;
    pas_snp.g_cod_error := 64;
    pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_PAR_MENSAJES, ' || sqlerrm ;
END pr_obt_par_mensajes;

/*Retorna la confirmaci�n/rechazo de los MTs recibidos*/
FUNCTION fu_obt_msj_confirmacion( p_cod_swift       in  ge_snp_mensajes.cod_msj_swift%type,
                                  p_nro_ref_externa in  ge_snp_mensajes.nro_ref_externa%type,
                                  p_fec_valor       in  ge_snp_mensajes.fec_valor%type,
                                  p_ref_oid         out ge_snp_transferencias.ref_oid%type
                                ) RETURN varchar2
IS
  v_ref_oid ge_snp_transferencias.ref_oid%type := null;
  v_pos_ini number := 0;
  v_pos_fin number := 0;
  cursor cu_msj_respuesta is
    select m.cod_msj_swift, m.msj_swift,
           pas_snp.fu_pro_val_tag( m.msj_swift, '72', 'N' ) tag_72
      from ge_snp_mensajes m
     where m.nro_ref_externa = p_nro_ref_externa
       and m.fec_valor       = p_fec_valor
     order by m.fec_insercion;
BEGIN
   p_ref_oid := NULL;

   if p_cod_swift is null then
      pas_snp.g_cod_error := 65;
      pas_snp.g_msj_error := 'El c�digo SWIFT no puede ser nulo' ;
      raise ex_salir;
   end if;
   -- La funci�n busca la primera respuesta v�lida de confirmaci�n/rechazo para un MT recibido.
   for c in cu_msj_respuesta loop
      -- Campo :72: Referencia OID, sirve para casos de retorno de operaciones
      if c.tag_72 is not null then
         v_pos_ini := instr(c.tag_72,'/OID/');
         v_pos_fin := instr(c.tag_72,pas_snp.fu_obt_salto,v_pos_ini,1);

         -- Se busca la palabra clave /OID/ dentro del campo 72, recupera el valor hasta el primer salto de l�nea
         v_ref_oid := substr(c.tag_72,v_pos_ini,v_pos_fin - v_pos_ini);
      end if;

      if p_cod_swift = '102' and
         ( c.cod_msj_swift = '196' or
           substr( c.msj_swift, instr( c.msj_swift, '{2:' ) + 4, 3 ) = '196'
         ) and
         nvl( instr( pas_snp.fu_pro_val_tag( c.msj_swift, '76' ), 'NETL' ), 0 ) > 0
      then
         p_ref_oid := v_ref_oid;
         return '196';
      elsif p_cod_swift = '103' and
            ( c.cod_msj_swift = '910' or
              substr( c.msj_swift, instr( c.msj_swift, '{2:' ) + 4, 3 ) = '910'
            )
      then
         p_ref_oid := v_ref_oid;
         return '910';
      elsif p_cod_swift = '202' and
            ( c.cod_msj_swift in ( '900', '910' ) or
              substr( c.msj_swift, instr( c.msj_swift, '{2:') + 4, 3 ) in ( '900', '910' )
            )
      then
         p_ref_oid := v_ref_oid;
         return nvl( c.cod_msj_swift, substr( c.msj_swift, instr( c.msj_swift, '{2:') + 4, 3 ) );
      end if;
   end loop;
   --
   return NULL;
   --
EXCEPTION
  when ex_salir then
    return NULL;
  when others then
    return NULL;
    pas_snp.g_cod_error := 65;
    pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_MSJ_CONFIRMACION, ' || sqlerrm ;
END fu_obt_msj_confirmacion;

FUNCTION fu_obt_tip_mov_transaccion( p_cod_modulo      IN ge_transacciones.cod_modulo%type,
                                     p_cod_modalidad   IN ge_transacciones.cod_modalidad%type,
                                     p_cod_transaccion IN ge_transacciones.cod_transaccion%type
                                   ) RETURN varchar2
IS
   /*Retorna el tipo de movimiento dependiendo de la transacci�n*/
   v_tip_mov ge_transacciones.tipo%type := NULL;
BEGIN
    select tr.tipo
      into v_tip_mov
      from ge_transacciones tr
     where tr.cod_modulo      = p_cod_modulo
       and tr.cod_modalidad   = p_cod_modalidad
       and tr.cod_transaccion = p_cod_transaccion;
    RETURN v_tip_mov;
EXCEPTION
   when no_data_found then
      pas_snp.g_cod_error := 39;
      pas_snp.g_msj_error := 'No se ha encontrado el tipo de movimiento para'||
                             ' ModH.:'||p_cod_modulo||
                             ' MadH.:'||p_cod_modalidad||
                             ' TrxH'||p_cod_transaccion;
      RETURN NULL;
   when others then
      pas_snp.g_cod_error := 39;
      pas_snp.g_msj_error := 'Error al recuperar el tipo de movimiento para el rubro.'||sqlerrm;
      RETURN NULL;
END fu_obt_tip_mov_transaccion;

PROCEDURE pr_obt_cta_interna( p_nro_cuenta            in  ge_snp_transferencias.nro_cta_beneficiario%type,
                              p_tip_documento         in  ba_personas.cod_tip_documento%type,
                              p_nro_documento         in  ba_personas.nro_documento%type,
                              p_nro_cta_interno       out ge_cuentas.nro_cuenta%type,
                              p_cod_persona           out ba_personas.cod_persona%type
                            )
  /*
  || Obtiene la Cuenta registrada en ITGF seg�n el N�mero de Cuenta registrado
  || y formateado en los MTs RECIBIDOS.
  */
IS
   cursor cu_cta_clientes is
   select ct.nro_cuenta, ct.cod_persona, ct.cod_modulo, ct.cod_modalidad,
          b.cod_tip_documento, b.nro_documento, g.estado
     from ba_personas b, ge_cta_clientes ct, ge_cuentas g
    where to_number( ct.nro_cuenta ) = to_number( p_nro_cuenta )
      and ct.cod_persona             = b.cod_persona
      and ct.nro_cuenta              = g.nro_cuenta;

   v_cod_modulo    ge_modalidades.cod_modulo%type := null;
   v_cod_modalidad ge_modalidades.cod_modalidad%type := null;
   v_ind_tip_doc   varchar2(1):= 'N'; -- Existe el Tipo de Documento (S/N).
   v_ind_nro_doc   varchar2(1):= 'N'; -- Existe el N�mero de Documento (S/N).
   v_estado        ge_cuentas.estado%type;

BEGIN
   -- Inicializa variables de error
   pas_snp.pr_ini_variables;
   --
   for c in cu_cta_clientes loop
      p_nro_cta_interno := c.nro_cuenta;
      p_cod_persona     := c.cod_persona;
      v_cod_modulo      := c.cod_modulo;
      v_cod_modalidad   := c.cod_modalidad;
      v_estado          := c.estado;

      -- Si el tipo de documento no est� cargado, no se valida.
      /*if p_tip_documento = c.cod_tip_documento or
         p_tip_documento is null
      then
         v_ind_tip_doc := 'S';
      end if;*/ --TCE-489

      -- Como el pas_snp.fu_val_cadena no limpia los caracteres .:-/?(),+
      -- entonces volvemos a limpiar dichos caracteres del n�mero de documento.
      /*if pas_snp.fu_val_cadena(c.nro_documento, 'A') =
         pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A') or
         instr(pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A'),
               pas_snp.fu_val_cadena(c.nro_documento, 'A'), 1) > 0 then*/
      if (pas_snp.fu_val_cadena(c.nro_documento, 'A') =
        pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A')) or
        (substr( trim(c.nro_documento),1, instr(c.nro_documento, '-')-1))=trim(p_nro_documento) or
        (substr( trim(p_nro_documento),1, instr(p_nro_documento, '-')-1)) =trim(c.nro_documento) then --TCE-489
         v_ind_nro_doc := 'S';
      end if;
      --
      if /*v_ind_tip_doc = 'S' and */ --TCE-489
         v_ind_nro_doc = 'S'
      then
         exit; -- Si encuentra el Tipo y el Nro. de Documento
      end if;
      --
   end loop;

   if p_nro_cta_interno is null then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Cuenta no puede ser nulo', '. ' );
      raise ex_salir;
   end if;

   if not ( ( v_cod_modulo in ( 3, 4 ) and v_cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39, 334 ) ) or
              v_cod_modulo = 5
          ) --Para MT recibido la Cuenta de Cr�dito puede ser la de Tarjetas
   then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Modalidad de la cuenta no permite este tipo de operaci�n', '. ' );
      raise ex_salir;
   end if;

   if  v_cod_modulo in ( 3, 4 ) and v_estado in ( 'C', 'P', 'X', 'T' ) then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Estado de la cuenta no permite este tipo de operaci�n', '. ' );
      raise ex_salir;
   end if;

   /*if v_ind_tip_doc = 'N' then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Tip. Doc. no coincide con el registrado en ITGF para la cuenta '||p_nro_cta_interno, '. ' );
   end if;*/ --TCE-489

   if v_ind_nro_doc = 'N' then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Nro Doc. no coincide con el registrado en ITGF para la cuenta '||p_nro_cta_interno, '. ' );
   end if;
   --
   if pas_snp.fu_obt_cod_error <> 0 then
      p_nro_cta_interno := null;
      p_cod_persona     := null;
   end if;
   --
EXCEPTION
   when ex_salir then
      p_nro_cta_interno   := null;
      p_cod_persona       := null;
   when others then
      p_nro_cta_interno   := null;
      p_cod_persona       := null;
      pas_snp.g_cod_error := 66;
      pas_snp.g_msj_error := 'Error al recuperar la Cuenta Interna en ITGF. Cuenta: ' || p_nro_cuenta || ' ' || SQLERRM;
END pr_obt_cta_interna;

PROCEDURE pr_ver_nro_tarjeta ( p_nro_tarjeta in  ge_snp_transferencias.nro_cta_beneficiario%type,
                               p_nro_cuenta  out ta_tarjetas.nro_cuenta%type
                             )
IS
   /*
   || Verificaci�n del Nro. de Tarjeta,
   || en caso de encontrar la Tarjeta se devuelve el Nro. Cuenta asociado a dicha Tarjeta.
   */
   v_vigente ta_tarjetas.vigente%type := 'N';
BEGIN
   select tar.nro_cuenta, nvl(tar.vigente,'N') vigente
     into p_nro_cuenta, v_vigente
     from ge_cta_clientes cli, ta_tarjetas tar
    where cli.nro_cuenta = tar.nro_cuenta
      and relacion       = 'P'
      and nro_tarjeta    = p_nro_tarjeta;
   if v_vigente <> 'S' then
      p_nro_cuenta := NULL;
      pas_snp.g_cod_error := 63;
      pas_snp.g_msj_error := 'Nro. de Tarjeta ' || p_nro_tarjeta || ' no est� vigente.';
   end if;
EXCEPTION
  when no_data_found then
    p_nro_cuenta        := NULL;
    pas_snp.g_cod_error := 63;
    pas_snp.g_msj_error := 'Nro. de Tarjeta inexistente.';
  when others then
    p_nro_cuenta        := NULL;
    pas_snp.g_cod_error := 63;
    pas_snp.g_msj_error := 'Error en LP_VER_NRO_CUENTA: ' || sqlerrm;
END pr_ver_nro_tarjeta;

PROCEDURE pr_env_alerta(rg_msj_alerta in rg_msj,
                        p_tip_alerta  in varchar2 default 'C') IS
  /*
  || Env�a alertas al Cliente y al Oficial. Tipo de Alertas:
  || (C)onfirmado, (E)rror, (R)eversado y (O)ficial solamente por reversi�n de cargos
  */
  v_nro_cta_origen  ge_snp_transferencias.nro_cta_solicitante%type;
  v_nro_cta_destino ge_snp_transferencias.nro_cta_solicitante%type;
  v_cod_persona     ba_personas.cod_persona%type;
  v_dir_mail        ba_personas.dir_correo%type;
  v_dir_mail_ofi    ba_personas.dir_correo%type;
  v_nro_secuencia   cr_per_notas.nro_secuencia%type;
  v_env_alerta      varchar2(1) := 'N';
  v_msj_titulo      varchar2(200) := NULL;
  v_str_cuenta      varchar2(100) := NULL;
  v_des_monto       varchar2(500) := NULL;
  v_detalle         varchar2(1000) := NULL;
  v_inf_json        long := null;
  v_tip_pro_cliente it.ba_env_correos.tip_producto%type;
  v_tip_pro_oficial it.ba_env_correos.tip_producto%type;
  v_cod_swi_pte_beneficiario ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  v_tem_vigente varchar2(1):='N';
  v_moneda          ba_monedas.cod_mon_iso%type;
  v_fec_recepcion   varchar2(20);
  v_nombre          varchar2(100);
 BEGIN
  g_lugar           := 'Env�ando alerta, ';
  v_nro_cta_origen  := ltrim(rtrim(rg_msj_alerta.nro_cta_solicitante));
  v_nro_cta_destino := ltrim(rtrim(rg_msj_alerta.nro_cta_beneficiario));
  v_fec_recepcion:= to_char(rg_msj_alerta.fec_recepcion, 'dd/mm/yyyy hh24:mi:ss');
 --DA-8974
  v_moneda := rg_msj_alerta.cod_moneda;
  v_des_monto:=trim(to_char(rg_msj_alerta.monto,'9,999,999,999,999,990.00'))||' '||v_moneda||'.';

  if pas_snp.fu_val_es_enviado(rg_msj_alerta) then
     -- MT Enviado
  --DA-6947
     if rg_msj_alerta.cod_tip_operacion = '001' and rg_msj_alerta.cod_sub_tip_operacion = '004' then
       v_nombre := it.fus_obt_nom_sub_participante(rg_msj_alerta.cod_swi_pte_beneficiario, rg_msj_alerta.cod_swi_suc_beneficiario );
     else
       v_nombre := it.fug_obt_nom_snp_participante(rg_msj_alerta.cod_swi_pte_beneficiario);
     end if;
   --
      v_inf_json        := '{' || '"nro_transaccion":' || '"' ||case when rg_msj_alerta.cod_msj_swift=102 then rg_msj_alerta.nro_lote else rg_msj_alerta.nro_referencia end || '"' || ',' || -- Nro. de Operaci�n
                                  '"fec_transferencia":' || '"' || rg_msj_alerta.fec_insercion || '"' || ',' || --Fecha y hora de Operaci�n
                                  '"nom_cue_debito":' || '"' || rg_msj_alerta.nom_solicitante || '"' || ',' || --Cliente Pagador
                                  '"num_cue_debito":' || '"' || rg_msj_alerta.nro_cta_solicitante || '"' || ',' || --Nro. de Cuenta del Pagador
                                  '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                  '"ban_cue_beneficiario":' || '"' || v_nombre || '"' || ',' || --Entidad Beneficiaria
                                  '"nom_beneficiario":' || '"' || rg_msj_alerta.nom_beneficiario || '"' || ',' || --Cliente Beneficiario
                                  '"num_cue_beneficiario":' || '"' || rg_msj_alerta.nro_cta_beneficiario || '"' || ',' || --N�mero de cuenta del Cliente Beneficiario
                                  '"aviso":' || '"' || 'La transferencia ha sido enviada.' || '"' || '}'; --Texto sugerido
    --v_tip_pro_cliente := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVCLISNP');--Envio de transferencia SIPAP (Cliente) --TCE-249
    v_tip_pro_oficial := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVOFISNP');--Envio de transferencia SIPAP (Oficial de Cuentas)
    v_cod_persona     := rg_msj_alerta.cod_per_solicitante;

    if fue_val_es_numerico(v_nro_cta_destino) = 'S' and
       length(ltrim(rtrim(to_number(v_nro_cta_destino)))) >= 16 then
      v_str_cuenta := 'Nro. de Tarjeta de Cr�dito ' ||
                      ltrim(rtrim(v_nro_cta_destino));
    else
      v_str_cuenta := 'Nro. de Cuenta ' || ltrim(rtrim(v_nro_cta_destino));
    end if;

  else
    if rg_msj_alerta.cod_swi_pte_beneficiario is null then
      /*Si es nulo, busca el codigo swift perteneciente a la entidad*/
       v_cod_swi_pte_beneficiario:= pas_snp.fu_obt_cod_swi_participante(FUG_OBT_PER_ENTIDAD);
    else
       v_cod_swi_pte_beneficiario:=rg_msj_alerta.cod_swi_pte_beneficiario;
    end if;
   --DA-6946
    if rg_msj_alerta.cod_tip_operacion = '001' and rg_msj_alerta.cod_sub_tip_operacion = '004' then
      v_nombre := it.fus_obt_nom_sub_participante(rg_msj_alerta.cod_swi_pte_solicitante, rg_msj_alerta.cod_swi_suc_solicitante);
    else
      v_nombre := it.fug_obt_nom_snp_participante(rg_msj_alerta.cod_swi_pte_solicitante);
    end if;

   --MT Recibido
   if p_tip_alerta = 'C' then
     v_inf_json        := '{' || '"fec_transferencia":' || '"' || v_fec_recepcion || '"' || ',' || --Fecha y hora de Operaci�n
                                  '"ban_cue_beneficiario":' || '"' || v_nombre || '"' || ',' ||
                                  '"num_cue_debito":' || '"' || rg_msj_alerta.nro_cta_solicitante || '"' || ',' ||
                                  '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                  '"aviso":' || '"' || 'Transferencia acreditada en cuenta' || '"' || ',' ||
                                  '"notas":' || '"' || rg_msj_alerta.observacion || '"' || '}';
   elsif p_tip_alerta = 'R' then
       v_inf_json        := '{' || '"fec_transferencia":' || '"' || v_fec_recepcion || '"' || ',' || --Fecha y hora de Operaci�n
                                  '"ban_cue_beneficiario":' || '"' || v_nombre || '"' || ',' || --Entidad Beneficiaria
                                  '"nom_beneficiario":' || '"' || rg_msj_alerta.nom_beneficiario || '"' || ',' || --Cliente Beneficiario
                                  '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                  '"aviso":' || '"' || 'La transferencia ha sido rechazada.' || '"' || '}'; --Texto sugerido
   end if;
   /*if p_tip_alerta = 'R' then ---TCE-249 tipo de producto 24
    v_tip_pro_cliente := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTRVLBTR');--Recibo de transferencia SIPAP (Cliente)
    v_tip_pro_oficial := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTRVLBTR');
   els*/if p_tip_alerta = 'C' then
    --v_tip_pro_cliente := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','RECCLISNP');--Recibo de transferencia SIPAP (Cliente) --tipo prod 9
    v_tip_pro_oficial := fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','RECOFISNP');--Recibo de transferencia SIPAP (Oficial de Cuentas)
   end if;
    v_cod_persona     := rg_msj_alerta.cod_per_beneficiario;

    -- Se verifica que tipo de Cuenta es: Cuenta Normal o Cuenta de Tarjeta
    pag_cta.pr_obt_cuenta(ltrim(rtrim(v_nro_cta_destino)));
    if pag_cta.g_ctas.cod_modulo = 5 then
      v_str_cuenta := 'Nro. de Cta. Tarjeta ' ||
                      ltrim(rtrim(v_nro_cta_destino));
    else
      v_str_cuenta := 'Nro. de Cuenta ' || ltrim(rtrim(v_nro_cta_destino));
    end if;

  end if;

  if p_tip_alerta = 'C' then
    /*Alerta de Confirmaci�n*/
    v_msj_titulo := 'Transferencia Realizada correctamente para la Cuenta ' ||
                    CASE pas_snp.fu_val_es_enviado(rg_msj_alerta)
                      WHEN TRUE THEN
                       v_nro_cta_origen
                      ELSE
                       v_nro_cta_destino
                    END;
  elsif p_tip_alerta = 'E' then
    /*Alerta de Error*/
    v_msj_titulo := 'Error durante el Proceso de Transferencia para la Cuenta ' ||
                    CASE pas_snp.fu_val_es_enviado(rg_msj_alerta)
                      WHEN TRUE THEN
                       v_nro_cta_origen
                      ELSE
                       v_nro_cta_destino
                    END;
  elsif p_tip_alerta = 'R' then
    /*Alerta de Reversi�n*/
    v_msj_titulo := 'Reversi�n de Transferencia Realizada correctamente para la Cuenta ' ||
                    CASE pas_snp.fu_val_es_enviado(rg_msj_alerta)
                      WHEN TRUE THEN
                       v_nro_cta_origen
                      ELSE
                       v_nro_cta_destino
                    END;
  elsif p_tip_alerta = 'O' then
    /*Alerta solo al Oficial por reversi�n de cargos*/
    v_msj_titulo := 'Reversi�n de Movimientos Relacionados a la Transferencia ' ||
                    rg_msj_alerta.nro_referencia || ' para la Cuenta ' ||
                    CASE pas_snp.fu_val_es_enviado(rg_msj_alerta)
                      WHEN TRUE THEN
                       v_nro_cta_origen
                      ELSE
                       v_nro_cta_destino
                    END;
  end if;

  BEGIN
    -- Busca la direccion de Correo del Cliente y Oficial
    select b.dir_correo, u.dir_correo
      into v_dir_mail, v_dir_mail_ofi
      from ba_personas b, ge_clientes c, ba_usuarios u
     where b.cod_persona = v_cod_persona
       and b.cod_persona = c.cod_persona
       and c.cod_usu_oficial = u.cod_usuario;

  EXCEPTION
    when others then
      v_dir_mail     := null;
      v_dir_mail_ofi := null;
  END;

  if p_tip_alerta = 'O' and v_dir_mail_ofi is not null then
    -- Se env�a Correo al Oficial por la reversi�n de CARGOS realizado desde el PRG_REV_OPERACION
    it_mail.mail(fug_obt_dir_correo,
                 v_dir_mail_ofi,
                 v_msj_titulo,
                 'Se han reversado movimientos relacionados a la Transferencia ' ||
                 rg_msj_alerta.nro_referencia || ' para la Cuenta ' ||
                 CASE pas_snp.fu_val_es_enviado(rg_msj_alerta)
                   WHEN TRUE THEN
                    v_nro_cta_origen
                   ELSE
                    v_nro_cta_destino
                 END || chr(10) || 'A continuaci�n los datos del SWIFT: ' ||
                 chr(10) || chr(10) || rg_msj_alerta.msj_swift || chr(10) ||
                 chr(10) || 'Atentamente. ');
  else
    -- Alertas al Oficial y al Cliente por transferencias realizadas.
    -- Se recupera la configuraci�n de env�o de alerta asignada en datos adicionales de persona
    v_env_alerta := nvl(fue_per_dat_adicional(v_cod_persona,
                                              'SNP_ENV_ALERTA'),
                        'S');

    if v_env_alerta = 'S' and p_tip_alerta in ('C', 'R') then
      --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
      pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
      --
        v_des_monto:=trim(to_char(rg_msj_alerta.monto,'9,999,999,999,999,990.00'))||' '||rg_msj_alerta.cod_moneda||'.';

      if pas_snp.g_env_alerta = 'S' and v_cod_persona is not null then
        -- Se env�a el Correo al Cliente si esta registrado
        if v_dir_mail is not null then

          insert into it.ba_env_correos
            (cod_persona,
             tip_producto,
             estado,
             fec_registro,
             parametros,
             mai_destinatario)
          values
            (v_cod_persona,
             v_tip_pro_cliente,
             'P',
             sysdate,
             v_inf_json,
             v_dir_mail);
        end if;

        -- Obtiene la secuencia de la tabla cr_per_notas
        BEGIN
          select nvl(max(nro_secuencia), 0)
            into v_nro_secuencia
            from cr_per_notas
           where cod_persona = v_cod_persona;
        EXCEPTION
          when others then
            v_nro_secuencia := 0;
        END;

        -- Se arma del detalle de la nota para el HomeBanking.
        v_detalle := 'Estimado cliente: Le informamos que la operaci�n realizada para el ' ||
                     v_str_cuenta || ' solicitado en fecha ' ||
                     to_char(rg_msj_alerta.fec_ingreso, 'DD/MM/YYYY') ||
                     ' con fecha valor ' ||
                     to_char(rg_msj_alerta.fec_valor, 'DD/MM/YYYY') ||
                     ' por el importe de ' || v_des_monto ||
                     CASE p_tip_alerta
                       WHEN 'C' THEN
                        ' se ha realizado con �xito. '
                       WHEN 'E' THEN
                        ' no ha podido realizarse. '
                       ELSE
                        ' se ha cancelado. '
                     END;

        -- Se inserta el registro de notas para el HomeBanking.
        insert into cr_per_notas
          (cod_persona,
           nro_secuencia,
           tipo,
           fecha,
           descripcion,
           automatico,
           estado,
           medio,
           detalle)
        values
          (v_cod_persona,
           v_nro_secuencia + 1,
           'M',
           g_fec_actual,
           v_msj_titulo,
           'N',
           'P',
           'G',
           v_detalle);

      end if;
      -- Se env�a el Correo al Oficial si esta configurado la direcci�n de correo
       begin
       select 'S'
       into   v_tem_vigente
       from ge_mai_onb_templates
       where trunc(sysdate) between ini_vigencia and fin_vigencia
       and tip_producto=v_tip_pro_oficial;
     exception
       when no_data_found then
         v_tem_vigente:='N';
       when too_many_rows then
          v_tem_vigente:='S';
      when others then
           v_tem_vigente:='N';
     end;
      if v_dir_mail_ofi is not null and nvl(v_tem_vigente,'N')='S' then

        insert into it.ba_env_correos
          (cod_persona,
           tip_producto,
           estado,
           fec_registro,
           parametros,
           mai_destinatario)
        values
          (v_cod_persona,
           v_tip_pro_oficial,
           'P',
           sysdate,
           v_inf_json,
           v_dir_mail_ofi);
      end if;
    end if;
  end if;
  EXCEPTION --DA-7825
  WHEN NO_DATA_FOUND THEN
    NULL;
  WHEN OTHERS THEN
    NULL;
END pr_env_alerta;

PROCEDURE pr_set_env_alerta( p_env_alerta varchar2 ) IS
  /*
  || Setea el indicador de env�o de alertas al Cliente y al Oficial.
  */

BEGIN
   pas_snp.g_env_alerta := p_env_alerta;

END pr_set_env_alerta;

PROCEDURE pr_con_mon_a_moneda( p_cod_mon_original in     ba_monedas.cod_moneda%type,
                               p_cod_mon_destino  in     ba_monedas.cod_moneda%type,
                               p_mto_mon_original in     number,
                               p_mto_mon_destino  out    number,
                               p_cot_mon_original in out number,
                               p_cot_mon_destino  in out number
                             )
IS
   /*
   || Convierte un monto de una moneda a otra
   */
   v_tip_ori varchar(1) := 'C'/*COMPRA*/;
   v_tip_des varchar(1) := 'V'/*VENTA*/;

   FUNCTION lf_obt_cotizacion ( p_cod_moneda in ba_monedas.cod_moneda%type,
                                p_tipo       in varchar2  -- C-COMPRA o V-VENTA
                              ) return number
   IS
      /*
      || Obtiene la Cotizaci�n de Compra y Venta para SNP.
      */

      v_cotizacion ge_cotizaciones.val_conversion%type;
   BEGIN
      /*Inicializa las variables de error*/
      pas_snp.pr_ini_variables;
      --
      select decode( p_tipo,'C',val_com_interbancaria,'V',val_ven_interbancaria,null )
        into v_cotizacion
        from ge_cotizaciones a
       where fecha      = (select max(fecha)
                             from ge_cotizaciones
                            where cod_moneda = a.cod_moneda
                              and fecha     <= g_fec_actual)
         and cod_moneda = p_cod_moneda;

      return v_cotizacion;

   EXCEPTION
      when others then
         return NULL;
   END lf_obt_cotizacion;
BEGIN
    /*Inicializa las variables de error*/
    pas_snp.pr_ini_variables;
    --

    if p_cod_mon_original = p_cod_mon_destino  then

       p_mto_mon_destino := p_mto_mon_original;
       if p_cod_mon_original <> g_cod_mon_local then
          p_cot_mon_destino  := nvl(p_cot_mon_original,pag_gen.fu_obt_cotizacion(p_cod_mon_original));
          p_cot_mon_original := p_cot_mon_destino;
       else
          p_cot_mon_destino  := 1;
          p_cot_mon_original := 1;
       end if;

    else -- La moneda original es distinta a la moneda destino

       if  p_cod_mon_original <> g_cod_mon_local and
           p_cod_mon_destino = g_cod_mon_local
       then
           p_cot_mon_original := nvl( p_cot_mon_original, lf_obt_cotizacion( p_cod_mon_original, v_tip_ori ) );
           p_cot_mon_destino  := 1;
           p_mto_mon_destino  := round( p_mto_mon_original * p_cot_mon_original, 0 );
       elsif p_cod_mon_original = g_cod_mon_local and
             p_cod_mon_destino <> g_cod_mon_local
       then
           p_cot_mon_original := 1;
           p_cot_mon_destino  := nvl( p_cot_mon_destino, lf_obt_cotizacion( p_cod_mon_destino, v_tip_des ) );
           p_mto_mon_destino  := round( p_mto_mon_original / p_cot_mon_destino, 2 );
       elsif p_cod_mon_original <> g_cod_mon_local and
             p_cod_mon_destino <> g_cod_mon_local
       then
           p_cot_mon_original := nvl( p_cot_mon_original, lf_obt_cotizacion( p_cod_mon_original, v_tip_ori ) );
           p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
           p_cot_mon_destino  := nvl( p_cot_mon_destino, lf_obt_cotizacion( p_cod_mon_destino, v_tip_des ) );
           p_mto_mon_destino  := round( p_mto_mon_destino / p_cot_mon_destino, 2 );
       end if;

    end if;
EXCEPTION
  when others then
     pas_snp.g_cod_error := 62;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_CON_MON_A_MONEDA ' || sqlerrm;
END pr_con_mon_a_moneda;

FUNCTION fu_obt_mov_concepto( p_tipo       in varchar2 default 'M',
                              p_origen     in ge_snp_transferencias.origen%type default 'I',
                              p_referencia in ge_snp_transferencias.nro_ref_externa%type
                            ) return varchar2
IS
   /*
   || Obtiene el concepto del movimiento SIPAP a generar
   || Tipo: (R)eversi�n de Movimientos, (M)ovimiento Normal
   || Origen: (I)tgf, (H)omebanking
   */
   v_concepto     varchar2(35);
   v_referencia   varchar2(16) := substr(p_referencia, 1, 16);
   v_mov_concepto ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('SNP_MOV_CONCEPTO'),'Trx.BCP Ref:');
BEGIN

   if p_tipo = 'R' then -- Reversi�n de Movimientos
      if p_origen = 'H' then -- Homebanking
         v_concepto := 'Rev.HB-' || substr(v_mov_concepto, 1, 12) || v_referencia;
      else -- ITGF
         v_concepto := 'Rev.' || substr(v_mov_concepto, 1, 15) || v_referencia;
      end if;
   else -- Movimiento Normal
      if p_origen = 'H' then -- Homebanking
         v_concepto := 'HB-' || substr(v_mov_concepto, 1, 16) || v_referencia;
      else -- ITGF
         v_concepto := substr(v_mov_concepto, 1, 19) || v_referencia;
      end if;
   end if;

   return v_concepto;

END fu_obt_mov_concepto;

FUNCTION fu_obt_des_participante( p_cod_swift ge_bancos.cod_swift%type ) return varchar
IS
   /*
   || Obtiene la denominaci�n del Participante.
   */
   v_descripcion varchar2(60);
BEGIN

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   IF length(p_cod_swift) = 12 THEN --TCE-214 si el codigo tiene 12 char es un subparticipante
     select substr( subparticipante, 1, 60 )
       into v_descripcion
       from ge_snp_patrocinador_det
      where cod_swift_sub = trim(p_cod_swift)
       and estado = 'S';
   ELSE

     select substr( participante, 1, 60 )
       into v_descripcion
       from gv_snp_participantes
      where cod_swift = trim(p_cod_swift);
   END IF;

   return v_descripcion;

EXCEPTION
  when no_data_found then
     pas_snp.g_cod_error := 61;
     pas_snp.g_msj_error := 'Denominaci�n para el Participante inexistente.';
     v_descripcion := substr(pas_snp.fu_obt_msj_error,1,60);
     return v_descripcion;
  when too_many_rows then
     pas_snp.g_cod_error := 61;
     pas_snp.g_msj_error := 'Existe m�s de una denominaci�n para el participante con BIC '||p_cod_swift;
     v_descripcion := substr(pas_snp.fu_obt_msj_error,1,60);
     return v_descripcion;
  when others Then
     pas_snp.g_cod_error := 61;
     pas_snp.g_msj_error := 'Error al Obt. Des. Participante '||' - '|| sqlerrm;
     v_descripcion := substr(pas_snp.fu_obt_msj_error,1,60);
     return v_descripcion;
END fu_obt_des_participante;

FUNCTION fu_obt_ind_swi_propio( p_cod_swift in ge_bancos.cod_swift%type ) return boolean
IS
  /*
  || Obtiene el indicador de BIC proporcionado por SWIFT o bien por el SIPAP,
  || esto es para los cambios de letras en los TAGS, Ej. 50A � 50D
  */
BEGIN

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   for c in ( select CASE v.ind_swi_propio
                     WHEN 'S' THEN 'S' ELSE 'N' END ind_swi_propio
                from gv_snp_participantes v
               where cod_swift = trim(p_cod_swift)
            ) loop
      if c.ind_swi_propio = 'S' then
         return TRUE;
      else
         return FALSE;
      end if;
   end loop;
   return FALSE;
EXCEPTION
   when others then
      return FALSE;
END fu_obt_ind_swi_propio;

FUNCTION fu_obt_cod_swi_participante( p_cod_persona in ba_personas.cod_persona%type ) return varchar
IS
   /*
   || Obtiene el C�digo Swift del Participante.
   */

   v_cod_swi_entidad ge_bancos.cod_swift%type;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   g_lugar := 'Obteniendo BIC del Participante, ';
   select cod_swift
     into v_cod_swi_entidad
     from gv_snp_participantes
    where cod_persona = p_cod_persona;

   return v_cod_swi_entidad;

EXCEPTION
  when no_data_found then
     pas_snp.g_cod_error := 24;
     pas_snp.g_msj_error := 'C�digo Swift no definido para la persona '||p_cod_persona;
     return NULL;
  when too_many_rows then
     pas_snp.g_cod_error := 24;
     pas_snp.g_msj_error := 'Existe m�s de un C�digo Swift para la persona '||p_cod_persona;
     return NULL;
  when others Then
     pas_snp.g_cod_error := 24;
     pas_snp.g_msj_error := 'Error al Obt. Cod. Swift para la persona '||p_cod_persona||' - '||sqlerrm;
     return NULL;
END fu_obt_cod_swi_participante;

FUNCTION fu_obt_cta_ban_participante( p_cod_swift  in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                      p_cod_moneda in ba_monedas.cod_moneda%type
                                    ) return varchar
IS
  /*
  || Obtiene la Cta. F�sica en BCP del participante seg�n la moneda.
  */

  v_nro_cta_pte ge_snp_cta_bancos.nro_cta_bancaria%type;
BEGIN
  /*Inicializa las variables de error*/
  pas_snp.pr_ini_variables;
  --

  --Primero se buscar� la Cta. F�sica en CC_CTA_BANCARIAS
  select nro_cta_bancaria
    into v_nro_cta_pte
    from cc_cta_bancarias cb,
         ge_cta_clientes cc,
         gv_snp_participantes v
  where cb.nro_cuenta    = cc.nro_cuenta
    and cb.cod_moneda    = trim(p_cod_moneda)
    and cc.relacion      = 'P'
    and cb.estado        IN ( 'A', 'N', 'S' ) /*Abierta, Normal, Bloqueo de Saldo*/
    and cb.cod_modulo    = pas_snp.fu_obt_cod_mod_padre
    and cb.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
    and cc.cod_persona   = v.cod_persona
    and v.cod_swift      = trim(p_cod_swift)
    and it.fug_obt_paradicional(cb.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ'
    and NVL(it.fug_obt_paradicional(cb.nro_cuenta, 'SNP_CTA_INTERB_SPI'),'N') = 'N';

  return v_nro_cta_pte;

EXCEPTION
  when no_data_found then
     --Si no se encuentra en CC_CTA_BANCARIAS,
     --se buscar� � en GE_SNP_CTA_BANCOS � en GE_SNP_CTA_ENTES
     BEGIN
         select cb.nro_cta_bancaria
           into v_nro_cta_pte
           from ba_personas p,
                ge_bancos b,
                ge_snp_cta_bancos cb,
                gv_snp_participantes v
          where p.cod_persona = b.cod_persona
            and b.cod_persona = v.cod_persona
            and v.cod_swift   = trim(p_cod_swift)
            and v.cod_banco   = b.cod_banco
            and b.cod_banco   = cb.cod_banco
            and cb.cod_moneda = trim(p_cod_moneda)
            and cb.ind_activo = 'S'
            and cb.principal  = 'S'
            and nvl(cb.ind_spi,'N')='N'
        union all
         select ce.nro_cta_bancaria
           from ba_personas p, ge_entes e,
                ge_snp_cta_entes ce, gv_snp_participantes v
          where p.cod_persona = e.cod_persona
            and e.cod_persona = v.cod_persona
            and v.cod_swift   = trim(p_cod_swift)
            and v.cod_ente    = e.cod_ente
            and e.cod_ente    = ce.cod_ente
            and ce.cod_moneda = trim(p_cod_moneda)
            and ce.ind_activo = 'S'
            and ce.principal  = 'S'
            and nvl(ce.ind_spi,'N')='N';

        return v_nro_cta_pte;

     EXCEPTION
        when no_data_found then
          pas_snp.g_cod_error := 27;
          pas_snp.g_msj_error := 'Cuenta Bancaria inexistente para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
          return NULL;
        when too_many_rows Then
          pas_snp.g_cod_error := 27;
          pas_snp.g_msj_error := 'Existe m�s de una Cta. Bancaria para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
          return NULL;
        when others then
          pas_snp.g_cod_error := 27;
          pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_CTA_BAN_PARTICIPANTE' || ' - ' || sqlerrm;
          return NULL;
     END;
  when too_many_rows Then
     pas_snp.g_cod_error := 27;
     pas_snp.g_msj_error := 'Existe varias Ctas. Bancarias para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
     return NULL;
  when others Then
     pas_snp.g_cod_error := 27;
     pas_snp.g_msj_error := 'Error inesperado en PAS_SNP.FU_OBT_CTA_BAN_PARTICIPANTE' || ' - ' || sqlerrm;
     return NULL;
END fu_obt_cta_ban_participante;

FUNCTION fu_obt_mon_cta_participante( p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type,
                                      p_cod_moneda_cta_participante in ge_snp_patrocinador_cab.cod_moneda%type default null ) return varchar
IS
  v_cod_moneda ba_monedas.cod_moneda%type := null;
BEGIN
  --Primero se buscar� la Cta. F�sica en CC_CTA_BANCARIAS
  select cb.cod_moneda
    into v_cod_moneda
    from cc_cta_bancarias cb,
         ge_cta_clientes cc,
         gv_snp_participantes v
   where cb.nro_cuenta       = cc.nro_cuenta
     and cc.relacion         = 'P'
     and cb.estado           IN ( 'A', 'N', 'S' ) /*Abierta, Normal, Bloqueo de Saldo*/
     and cb.cod_modulo       = pas_snp.fu_obt_cod_mod_padre
     and cb.cod_modalidad    = pas_snp.fu_obt_cod_mad_padre
     and cc.cod_persona      = v.cod_persona
     and cb.nro_cta_bancaria = p_nro_cta_participante
     and fug_obt_paradicional(cb.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ'
     and rownum              = 1;
  return v_cod_moneda;
EXCEPTION
  WHEN no_data_found THEN
    BEGIN
      select cb.cod_moneda
        into v_cod_moneda
        from ba_personas p,
             ge_bancos b,
             ge_snp_cta_bancos cb,
             gv_snp_participantes v
       where p.cod_persona       = b.cod_persona
         and b.cod_persona       = v.cod_persona
         and v.cod_banco         = b.cod_banco
         and b.cod_banco         = cb.cod_banco
         and cb.ind_activo       = 'S'
         and cb.nro_cta_bancaria = p_nro_cta_participante
         and rownum              = 1;
      return v_cod_moneda;
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          select ce.cod_moneda
            into v_cod_moneda
            from ba_personas p,
                 ge_entes e,
                 ge_snp_cta_entes ce,
                 gv_snp_participantes v
           where p.cod_persona       = e.cod_persona
             and e.cod_persona       = v.cod_persona
             and v.cod_ente          = e.cod_ente
             and e.cod_ente          = ce.cod_ente
             and ce.ind_activo       = 'S'
             and ce.nro_cta_bancaria = p_nro_cta_participante
             and rownum              = 1;
          return v_cod_moneda;
        EXCEPTION
          WHEN no_data_found then
            begin
              select s.cod_moneda
                into v_cod_moneda
                from ge_snp_patrocinador_cab s , ge_snp_patrocinador_det d
               where s.cod_swift = d.cod_swift_padre
                 and d.estado = 'S'
                 and trim(d.cta_interna_sub) = trim(p_nro_cta_participante)
                 and (p_cod_moneda_cta_participante is null or s.cod_moneda = p_cod_moneda_cta_participante)
                 and rownum = 1;
            return v_cod_moneda;
            EXCEPTION
          WHEN others THEN
            return NULL;
         end;
        END;
      WHEN others THEN
        return NULL;
    END;
  WHEN others THEN
    return NULL;
END fu_obt_mon_cta_participante;

FUNCTION fu_obt_est_horario ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                              p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                              p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type
                            ) return varchar2
IS
   /*
   || Obtiene el estado actual del periodo configurado seg�n el MT, Tipo Operaci�n y Sub Tipo Operaci�n
   */

   -- Tipo de dato para el vector
   type t_vector  is table of ge_snp_par_mensajes.cod_periodo%type
                              index by binary_integer;
   v_vector       t_vector;
   v_estado       ge_snp_horarios.estado%type := 'N';
   c_fec_actual   constant date := g_fec_actual;

   PROCEDURE lp_ver_est_periodo( p_cod_periodo in     ge_snp_horarios.cod_periodo%type,
                                 p_estado      in out ge_snp_horarios.estado%type
                               )
   IS
     v_hor_inicio ge_snp_horarios.hor_inicio%type := null;
     v_hor_fin    ge_snp_horarios.hor_fin%type    := null;
     v_hor_actual ge_snp_horarios.hor_inicio%type := null;
   BEGIN
     if instr(','||trim(fug_obt_pardinamico('SPI_COD_MSJ_VER_PERIODO'))||',', ','||p_cod_msj_swift||',')>0 then
        p_estado := 'A';
      ELSE
      SELECT nvl(sh.estado,'N'), sh.hor_inicio, sh.hor_fin
        INTO p_estado, v_hor_inicio, v_hor_fin
        FROM ge_snp_horarios sh
       WHERE sh.cod_periodo = p_cod_periodo
         AND sh.fecha       = c_fec_actual;

      v_hor_actual := to_char(sysdate,'hh24mi');

      if to_number(v_hor_inicio) is null or                   -- Si la Hora de Inicio es NULO
         to_number(v_hor_fin) is null or                      -- Si la Hora Fin es NULO
         to_number(v_hor_actual) < to_number(v_hor_inicio) or -- Si la Hora Actual es Menor a la Hora Inicial
         to_number(v_hor_actual) > to_number(v_hor_fin)       -- Si la Hora Actual es Mayor a la Hora Final
      then
         p_estado := 'N';
      end if;

      END IF;
   EXCEPTION
      when others then
         p_estado := 'N';
   END lp_ver_est_periodo;
BEGIN

  /*Inicializa las variables de error*/
  pas_snp.pr_ini_variables;
  --
  /*Inicializamos el vector*/
  v_vector.delete;

  if not fu_val_par_mensajes( p_cod_msj_swift,
                              p_tip_operacion,
                              p_sub_tip_operacion
                            )
  then
     pas_snp.g_cod_error := 33;
     pas_snp.g_msj_error := 'Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES';
     raise ex_salir;
  end if;

  begin
      select m.cod_periodo, m.cod_periodo2, m.cod_periodo3
        into v_vector(1),v_vector(2), v_vector(3)
        from ge_snp_par_mensajes m
       where m.cod_msj_swift                  = p_cod_msj_swift
         and m.cod_tip_operacion              = p_tip_operacion
         and nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x');
  exception
    when others then
      raise;
  end;

  if v_vector.COUNT > 0 then
     --Recuperamos los periodos del vector para la verificaci�n de sus respectivos estados
     for i IN v_vector.FIRST..v_vector.LAST loop
        if v_vector.EXISTS(i) THEN
           lp_ver_est_periodo(v_vector(i),v_estado);
           if v_estado = 'A' then
              return v_estado;
           end if;
        end if;
     end loop;
  end if;
  pas_snp.g_cod_error  := 33;
  pas_snp.g_msj_error  := 'No se encuentra periodo (A)BIERTO para MT ' || p_cod_msj_swift ||
                          ', Tip.Ope.: ' || p_tip_operacion ||
                          ', Sub.Tip.Ope.: ' || p_sub_tip_operacion;
  return v_estado;

EXCEPTION
  when ex_salir then
     return 'N';
  when others then
     pas_snp.g_cod_error  := 33;
     pas_snp.g_msj_error  := 'Error en PAS_SNP.FU_OBT_EST_HORARIO, ' || sqlerrm ;
     return 'N';
END fu_obt_est_horario;

PROCEDURE pr_act_est_horario
IS
/*Cierra los periodos Abiertos*/
BEGIN

   UPDATE ge_snp_horarios h
      SET h.estado = 'C'
    WHERE h.estado != 'C'
      AND h.tip_horario != 'A';

EXCEPTION
  WHEN others THEN
     BEGIN
       if g_err_dir_correo is not null then
          it_mail.mail( fug_obt_dir_correo,
                        g_err_dir_correo,
                        'Error al actualizar el estado en GE_SNP_HORARIOS. ',
                        'Se ha encontrado un error al intentar actualizar el campo ESTADO en GE_SNP_HORARIOS. ' || chr(10) || chr(10) ||
                        'Hora Proceso: ' || to_char(sysdate,'HH24MI') || ' Error : ' || sqlerrm ||
                        chr(10) || chr(10) ||
                        'Atentamente.'
                      );
       end if;
     EXCEPTION
       when others then
          NULL;
     END;
END pr_act_est_horario;

FUNCTION fu_obt_sig_nro_referencia ( p_fecha IN ge_snp_transferencias.fecha%type default NULL ) return number
IS
   /*
   || Se obtiene el siguiente nro. de referencia, como el campo NRO_DOCUMENTO es NUMBER(15)
   || se calcula 6 digitos para la fecha 'RRMMDD' y 6 digitos para la secuencia.
   */

   v_nro_referencia ge_snp_transferencias.nro_referencia%type;
   c_fecha          constant date := nvl( p_fecha, g_fec_actual );
   v_existe         char(1) := 'S';
   v_fecha          date;--TRFS-1353
BEGIN

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   v_fecha:= trunc(sysdate);--TRFS-1353
   select to_number( to_char( v_fecha, 'RRMMDD' ) || s_nro_ref_mensaje.nextval )
     into v_nro_referencia
     from dual;

   /*
   || Se verifica si el n�mero generado no existe a�n.
   */
   BEGIN
     select distinct 'S'
       into v_existe
       from ge_snp_transferencias
      where nro_referencia = v_nro_referencia;
   EXCEPTION
      WHEN no_data_found THEN
         v_existe := 'N';
      WHEN others THEN
         v_existe := 'S';
   END;

   if v_existe = 'S' then
      pas_snp.g_cod_error := 34;
      pas_snp.g_msj_error := 'Error en FU_OBT_SIG_NRO_REFERENCIA: El Nro. Referencia ' || to_char( v_nro_referencia ) ||' generado ya existe.';
   end if;

   -- retorno el sgte nro de referencia
   Return v_nro_referencia;

EXCEPTION
   WHEN OTHERS THEN
      pas_snp.g_cod_error := 34;
      pas_snp.g_msj_error := 'Error en FU_OBT_SIG_NRO_REFERENCIA' || ' - ' || sqlerrm;
      return v_nro_referencia;
END fu_obt_sig_nro_referencia;

FUNCTION fu_obt_sig_nro_lote( p_fecha in ge_snp_transferencias.fecha%type default null ) return number
IS
   /*
   || Obtiene el siguiente n�mero de lote para el MT102.
   */

   v_nro_lote ge_snp_transferencias.nro_lote%type;
   c_fecha    constant date := nvl( p_fecha, g_fec_actual );
BEGIN
   select to_number( to_char( c_fecha, 'RRMMDD' ) || s_nro_sec_lote.nextval )
     into v_nro_lote
     from dual;

   -- retorno el sgte nro de lote
   Return v_nro_lote;

END fu_obt_sig_nro_lote;

FUNCTION fu_ver_mov_duplicados( rg_msj_dup in rg_msj ) return number
IS
  /*
  || Verifica si la operaci�n tiene mensajer�a duplicada.
  */
  v_cantidad number;
  v_fec_ini  rg_msj_dup.fec_valor%type := rg_msj_dup.fec_valor - g_dia_duplicacion;
  v_fec_fin  rg_msj_dup.fec_valor%type := rg_msj_dup.fec_valor;

BEGIN

   SELECT count( nro_referencia )
     INTO v_cantidad
     FROM ( -- Recupera los MT102 y MT103
           SELECT t.nro_referencia
             FROM ge_snp_transferencias t
            WHERE t.nro_cta_solicitante      = rg_msj_dup.nro_cta_solicitante
              AND t.nro_cta_pte_solicitante  = rg_msj_dup.nro_cta_pte_solicitante
              AND t.nro_cta_beneficiario     = rg_msj_dup.nro_cta_beneficiario
              AND t.cod_swi_pte_beneficiario = rg_msj_dup.cod_swi_pte_beneficiario
              AND t.cod_moneda               = rg_msj_dup.cod_moneda
              AND t.monto                    = rg_msj_dup.monto
              AND t.cod_msj_swift            in (103,102)
              AND t.fec_valor BETWEEN v_fec_ini AND v_fec_fin
              AND t.estado                   not in ('C','E','R')
              /*Validaci�n sobre todos los registros o todos menos el que se est� cargando.*/
              AND t.nro_referencia           != nvl(rg_msj_dup.nro_referencia, -1)

           UNION ALL

           -- Recupera el MT202
           SELECT s.nro_referencia
             FROM ge_snp_transferencias s
            WHERE s.nro_cta_pte_solicitante  = rg_msj_dup.nro_cta_pte_solicitante
              AND s.cod_swi_pte_beneficiario = rg_msj_dup.cod_swi_pte_beneficiario
              AND s.cod_moneda               = rg_msj_dup.cod_moneda
              AND s.monto                    = rg_msj_dup.monto
              AND s.cod_msj_swift            = 202
        AND s.cod_tip_operacion        <> '014'
              AND s.cod_sub_tip_operacion not in ('001', '003')
              AND s.fec_valor BETWEEN v_fec_ini AND v_fec_fin
              AND s.estado                   not in ('C','E','R')
              AND s.cod_msj_swift            = rg_msj_dup.cod_msj_swift
              /*Validaci�n sobre todos los registros o todos menos el que se est� cargando.*/
              AND s.nro_referencia           != nvl(rg_msj_dup.nro_referencia, -1)
           ) ;

   return v_cantidad;

EXCEPTION
   when others then
      pas_snp.g_cod_error := '22';
      pas_snp.g_msj_error := 'Error en PAS_SNP.FU_VER_MOV_DUPLICADOS. '|| sqlerrm;
      return null;
END fu_ver_mov_duplicados;

FUNCTION fu_ver_mov_duplicados ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type ) return number
IS
  /*
  || Verifica si la operaci�n tiene mensajer�a duplicada.
  */
BEGIN
   pas_snp.pr_obt_mensaje ( p_nro_referencia, 'N' );
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   end if;
   return pas_snp.fu_ver_mov_duplicados ( pas_snp.g_msj );
EXCEPTION
  when ex_salir then
     return null;
  when others then
     pas_snp.g_cod_error := 59;
     pas_snp.g_msj_error := 'Error en PAS_SNP.FU_VER_MOV_DUPLICADOS '||sqlerrm;
     return null;
END fu_ver_mov_duplicados;

FUNCTION fu_ver_msj_duplicados ( p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type,
                                 p_fec_valor in ge_snp_transferencias.fec_valor%type
                                ) return varchar2
IS
   /*
   || Verifica si la operaci�n RECIBIDA est� duplicada
   */
   cursor cu_msj_dup IS
      SELECT distinct 'S'
        FROM ge_snp_transferencias
       WHERE fec_valor       = p_fec_valor
         AND nro_ref_externa = p_nro_ref_externa
      UNION ALL
      SELECT distinct 'S'
        FROM ge_snp_transferencias
       WHERE fec_valor       = p_fec_valor
         AND nro_ref_externa IS NOT NULL
         AND nro_lote        = p_nro_ref_externa;

   -- Env�a mail notificando la duplicidad de los mensajes.
   PROCEDURE lp_env_cor_duplicacion
   IS
   BEGIN
     if g_gru_dir_correo is not null then
        it_mail.mail( fug_obt_dir_correo,
                      g_gru_dir_correo,
                      'Error al intentar recibir SWIFT desde el BCP.',
                      'Se ha encontrado una mensajer�a RECIBIDA DUPLICADA con Fecha ' || to_char(p_fec_valor,'DD/MM/YYYY') ||
                      ' y Nro.Ref.Externa ' || p_nro_ref_externa || chr(10) || chr(10) || chr(10) ||
                      'Atentamente.'
                     );
     end if;
   EXCEPTION
     when others then
        NULL;
   END lp_env_cor_duplicacion;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --

   for d in cu_msj_dup loop
      pas_snp.g_cod_error := 60;
      pas_snp.g_msj_error := 'Mensajer�a existente para la Ref. Externa ' || p_nro_ref_externa || ' y Fec.Valor ' || to_char(p_fec_valor,'DD/MM/YYYY');
      lp_env_cor_duplicacion;
      return 'S';
   end loop;

   return 'N';
EXCEPTION
   WHEN no_data_found THEN
      return 'N';
   WHEN too_many_rows THEN
      pas_snp.g_cod_error := 60;
      pas_snp.g_msj_error := 'Mensajer�a Duplicada para la Ref.Externa ' || p_nro_ref_externa || ' y Fec.Valor ' || to_char(p_fec_valor,'DD/MM/YYYY');
      lp_env_cor_duplicacion;
      return 'S';
   WHEN others THEN
      pas_snp.g_cod_error := 60;
      pas_snp.g_msj_error := substr('Error inesperado en PAS_SNP.FU_VER_MSJ_DUPLICADOS para la Ref.Externa '||p_nro_ref_externa||' y Fec.Valor '|| to_char(p_fec_valor,'DD/MM/YYYY')||', '||sqlerrm, 1, 200);
      return 'S';
END fu_ver_msj_duplicados;

FUNCTION fu_obt_cab_msj_swift( p_nro_referencia in ge_snp_transferencias.nro_referencia%type ) return varchar
IS
   /*
   || Obtiene la cabecera de la mensajer�a a ENVIAR (Header del MT)
   || Ej:{1:F01RGSAPYPEA0000000000000}{2:O103FINEXPYPXXXX00000}{3:{113:0020}}{4:
   */
   v_bic_entidad   ge_snp_transferencias.cod_swi_pte_solicitante%type := NULL;
BEGIN
   --Recupera el BIC de la entidad solicitante
   v_bic_entidad := pas_snp.fu_obt_cod_swi_participante ( fug_obt_per_entidad );
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   end if;

   --Valida si est� correcto el c�digo de usuario del X-ADAPTER
   if nvl( length( g_usu_xadapter ), 0 ) <> 12 then
      pas_snp.g_cod_error := '30';
      pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER debe tener longitud de 12 caracteres';
      raise ex_salir;
   elsif substr(v_bic_entidad,1,8) <> substr(g_usu_xadapter,1,8) then
      pas_snp.g_cod_error := '30';
      pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER no corresponde a la entidad';
      raise ex_salir;
   end if;

   --Recupera la mensajer�a sin validar si est� o no relacionado a un movimiento.
   pas_snp.pr_obt_mensaje( p_nro_referencia, 'N' );
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   end if;
   g_cab_msj_swift := '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'/*0000000000*/||
                      '{2:I'||substr(to_char(g_msj.cod_msj_swift),1,3)||rpad(fu_obt_bic_sistema/*R=RTSX, D=DEPO*/,12,'X')||'N}'||
                      '{3:{113'||':'||lpad(g_msj.prioridad,4,'0')||'}}{4:';
   return g_cab_msj_swift;
EXCEPTION
  when ex_salir then
    return NULL;
  when others then
    pas_snp.g_cod_error := '30';
    pas_snp.g_msj_error := 'Error en FU_OBT_CAB_MSJ_SWIFT. Ref.: '|| p_nro_referencia || ' - ' || sqlerrm;
    return NULL;
END fu_obt_cab_msj_swift;

PROCEDURE pr_pro_cab_msj_swift( p_mensaje  in  long,
                                rg_msj_rec out pas_snp.rg_msj
                              )
IS
   v_pos_ini number:=0;
BEGIN
   /*
   || Procesa datos de la mensajer�a RECIBIDA (Header del MT)
   */

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   --C�digo de MT, ej: 103,202,etc
   v_pos_ini := instr(p_mensaje,'{2:');
   if v_pos_ini > 0 then
      rg_msj_rec.cod_msj_swift  := substr(p_mensaje,v_pos_ini+4,3);
      v_pos_ini := 0;
   else
      pas_snp.g_cod_error := 16;
      pas_snp.g_msj_error := 'No se encuentra el C�digo del Swift en Bloque 2.';
      raise ex_salir;
   end if;
   --Prioridad
   v_pos_ini := instr(p_mensaje,'{3:');
   if v_pos_ini > 0 then
      v_pos_ini := instr(p_mensaje,':',v_pos_ini,2);
      rg_msj_rec.prioridad := substr(p_mensaje,v_pos_ini+1,4);
   else
      pas_snp.g_cod_error := 16;
      pas_snp.g_msj_error := 'No se encuentra Prioridad en Bloque 3.';
      raise ex_salir;
   end if;
EXCEPTION
  when ex_salir then
     NULL;
  when others then
    pas_snp.g_cod_error := '16';
    pas_snp.g_msj_error := 'Error en PR_PRO_CAB_MSJ_SWIFT. Ref.: '|| sqlerrm;
END pr_pro_cab_msj_swift;

FUNCTION fu_con_mensaje ( p_msj in long ) return long
IS
  /* Antes de enviar al socket se reemplaza G_SALTO por (*)asterisco para que
  || del otro lado se pueda tomar el asterisco y volver a convertirlo en ENTER
  */
BEGIN
     return REPLACE(REPLACE( p_msj, chr(10), pas_snp.fu_obt_sal_socket ),chr(13),'');
END fu_con_mensaje;

PROCEDURE pr_gen_arc_swift( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                            p_val_movimientos in varchar2 default 'S',
                            p_estado ge_snp_transferencias.estado%type default 'A'
                          )
IS
   /*
   || Env�a la mensajer�a al Socket.
   */

   v_resp       varchar2(4000):= null;
   v_ind_enviar varchar2(1):= 'S';
   rg_mensaje   pas_snp.rg_msj;
   ex_error     EXCEPTION;
BEGIN
   /*Inicializa la aplicacion y el modulo*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   --Obtiene el registro de ge_snp_transferencias
   g_lugar := 'Obteniendo el mensaje de la referencia '||p_nro_referencia||', ';
   pas_snp.pr_obt_mensaje ( p_nro_referencia, p_val_movimientos );
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   else
      rg_mensaje := pas_snp.fu_obt_reg_transferencias;
      pas_snp.pr_ini_registros;
   end if;

   /* Solo se env�a si la plataforma es X-Adapter (por defecto) */
   if nvl( rg_mensaje.plataforma, 'X' ) = 'X' then
      /*
      || Si son mensajes de ALTO VALOR y el horario para la fecha actual est� VIGENTE,
      || se env�a el SWIFT al socket.
      */
      if pas_snp.fu_obt_est_horario( rg_mensaje.cod_msj_swift,
                                     rg_mensaje.cod_tip_operacion,
                                     rg_mensaje.cod_sub_tip_operacion
                                   ) = 'A'
      then --Si el horario est� VIGENTE en BCP

         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( rg_mensaje.error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            update ge_snp_transferencias t
               set t.estado = 'C',
                   t.error  = rg_mensaje.error
             where t.nro_referencia = rg_mensaje.nro_referencia;
            raise ex_salir;
         end if;

         g_lugar := 'Verificando datos a enviar, ';
         if rg_mensaje.cod_msj_swift in ( 103,202 ) then

            if rg_mensaje.msj_swift is null then
               pas_snp.g_cod_error := 35;
               pas_snp.g_msj_error := 'No existe SWIFT para la referencia ' || rg_mensaje.nro_referencia || ' creado.!';
               raise ex_salir;
            end if;

            g_lugar := 'Verificando situaci�n de la mensajer�a antes de enviar al socket, Nro. Referencia: ' || rg_mensaje.nro_referencia;
            if rg_mensaje.situacion != 'V' then
               if pas_snp.fu_obt_cod_error <> 0 then
                  raise ex_salir;
               end if;
               begin
                 g_lugar := 'Comprobando Duplicados, ';
                 pr_ins_sb_snp_log_envios(rg_mensaje.nro_referencia, 'I', 'N');
               exception
                  when others then
                    if sqlcode = -20003 then
                       -- Si el error es por duplicaci�n de env�o no volver a enviar la mensajer�a y
                       -- liquidar la operaci�n
                       begin
                          select 'N'
                            into v_ind_enviar
                            from sb_snp_log_envios a
                           where a.nro_referencia = rg_mensaje.nro_referencia
                             and a.situacion      = 'E'
                             and upper(a.error) like '%02%LIM%TIE%';
                       exception
                          when others then
                             v_ind_enviar := 'S';
                       end;
                    else
                       raise;
                    end if;
               end;
               if v_ind_enviar = 'S' then
                  g_lugar := 'Actualizando datos en ge_snp_transferencias, ';
                  -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
                  update ge_snp_transferencias t
                     set t.situacion = 'V',
                         t.estado    = nvl( p_estado, 'A' ),
                         t.error     = null
                   where t.nro_referencia = rg_mensaje.nro_referencia;

                  -- Si tiene problemas al intentar generar movimientos se cargar� el c�digo de error
                  if pas_snp.fu_obt_cod_error <> 0 then
                     raise ex_salir;
                  else
                     --Obtiene el registro de ge_snp_transferencias nuevamente
                     g_lugar := 'Obteniendo el mensaje de la referencia '||rg_mensaje.nro_referencia||', ';
                     pas_snp.pr_obt_mensaje( rg_mensaje.nro_referencia, 'N' );
                     if pas_snp.fu_obt_cod_error <> 0 then
                        raise ex_salir;
                     else
                        rg_mensaje := pas_snp.fu_obt_reg_transferencias;
                        pas_snp.pr_ini_registros;
                     end if;

                     if rg_mensaje.error is not null then
                        pas_snp.g_cod_error := 35;
                        pas_snp.g_msj_error := rg_mensaje.error;
                        raise ex_salir;
                     end if;
                  end if;
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
                      -- TRFS-533-Inserta mensaje para que el OWL/ETL procese

                     if nvl(fug_obt_pardinamico('SNP_HAB_ENV'),'S') = 'S' and rg_mensaje.cod_msj_swift = 103 then
                      g_lugar := 'Insertando en ge_men_env_sipap, ';
                      -- Inserta mensaje para que el OWL/ETL procese
                         begin
                         insert into ge_men_env_sipap
                           (nro_referencia, estado, msj_swift)
                         values
                           (rg_mensaje.nro_referencia,
                            'PENDING',
                            REPLACE(REPLACE(rg_mensaje.msj_swift,
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
                                    pas_snp.pr_ins_sb_snp_log_envios(rg_mensaje.nro_referencia,
                                                                     'A',
                                                                     'E',
                                                                     pas_snp.g_msj_error);
                                    raise ex_error;

                           end;
                           if pas_snp.fu_obt_cod_error = 0 then
                                 g_lugar := 'Actualizando datos en ge_snp_transferencias, ';
                                 -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
                                 update ge_snp_transferencias t
                                    set t.situacion = 'V',
                                        t.estado    = nvl( p_estado, 'A' ),
                                        t.error     = null
                                  where t.nro_referencia = g_msj.nro_referencia;
                           end if;
                      else
                              if rg_mensaje.cod_msj_swift = 103 then
                                g_lugar := 'Actualizando datos en ge_snp_transferencias, ';
                                 -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
                                 update ge_snp_transferencias t
                                    set t.situacion = 'V',
                                        t.estado    = nvl( p_estado, 'A' ),
                                        t.error     = null
                                  where t.nro_referencia = g_msj.nro_referencia;
                              end if;
                            if rg_mensaje.cod_msj_swift <> 103 then
                              g_lugar := 'Conect�ndose al socket, ';
                                -- Envia el mensaje al servidor

                                  -- TRFS-533-Inserta mensaje para que el OWL/ETL procese
                                begin
                                 insert into ge_men_env_sipap
                                   (nro_referencia, estado, msj_swift)
                                 values
                                   (rg_mensaje.nro_referencia,
                                    'PENDING',
                                    REPLACE(REPLACE(rg_mensaje.msj_swift,
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
                                            pas_snp.pr_ins_sb_snp_log_envios(rg_mensaje.nro_referencia,
                                                                             'A',
                                                                             'E',
                                                                             pas_snp.g_msj_error);
                                            raise ex_error;

                                   end;

                               if pas_snp.fu_obt_cod_error = 0 then
                                 g_lugar := 'Actualizando datos en ge_snp_transferencias, ';
                                 -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
                                 update ge_snp_transferencias t
                                    set t.situacion = 'V',
                                        t.estado    = nvl( p_estado, 'A' ),
                                        t.error     = null
                                  where t.nro_referencia = g_msj.nro_referencia;
                              end if;
                            end if;
                  end if;

                else

                  if nvl(fug_obt_pardinamico('SNP_HAB_ENV'),'S') = 'S' and rg_mensaje.cod_msj_swift = 103 then
                      g_lugar := 'Conect�ndose al socket, ';
                      -- Envia el mensaje al servidor
                      g_ok := fue_env_tcp_mensajes( p_servidor   => g_servidor,
                                                    p_puerto     => g_puerto,
                                                    p_tie_espera => g_tie_espera,
                                                    p_mensaje    => pas_snp.fu_con_mensaje( rg_mensaje.msj_swift ),
                                                    p_respuesta  => v_resp
                                                  );
                    if g_ok != 'S' and v_resp not in ('02-Limite de tiempo de espera') THEN  -- DA-4875 -- NGRANCE --
                       -- Hubo problema en el env�o, se actualiza a la situaci�n/estado anterior
                       pas_snp.g_cod_error := 35;
                       pas_snp.g_msj_error := g_lugar || 'Error durante la conexi�n con el socket: ' || substr( v_resp,1,3000 );
                       g_lugar := 'Actualizando Error en el LOG, ';
                       pr_ins_sb_snp_log_envios(rg_mensaje.nro_referencia, 'A', 'E', pas_snp.g_msj_error);
                       if pas_snp.fu_obt_cod_error <> 0 then
                          raise ex_error;
                       end if;
                    else
                       g_lugar := 'Actualizando datos en ge_snp_transferencias, ';
                       -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
                       update ge_snp_transferencias t
                          set t.situacion = 'V',
                              t.estado    = nvl( p_estado, 'A' ),
                              t.error     = null
                        where t.nro_referencia = g_msj.nro_referencia;
                    end if;
                  else
                    if rg_mensaje.cod_msj_swift = 103 then
                      g_lugar := 'Actualizando datos en ge_snp_transferencias, ';
                       -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
                       update ge_snp_transferencias t
                          set t.situacion = 'V',
                              t.estado    = nvl( p_estado, 'A' ),
                              t.error     = null
                        where t.nro_referencia = g_msj.nro_referencia;
                    end if;
                    if rg_mensaje.cod_msj_swift <> 103 then
                      g_lugar := 'Conect�ndose al socket, ';
                        -- Envia el mensaje al servidor
                        g_ok := fue_env_tcp_mensajes( p_servidor   => g_servidor,
                                                      p_puerto     => g_puerto,
                                                      p_tie_espera => g_tie_espera,
                                                      p_mensaje    => pas_snp.fu_con_mensaje( rg_mensaje.msj_swift ),
                                                      p_respuesta  => v_resp
                                                    );
                      if g_ok != 'S' and v_resp not in ('02-Limite de tiempo de espera') THEN  -- DA-4875 -- NGRANCE --
                         -- Hubo problema en el env�o, se actualiza a la situaci�n/estado anterior
                         pas_snp.g_cod_error := 35;
                         pas_snp.g_msj_error := g_lugar || 'Error durante la conexi�n con el socket: ' || substr( v_resp,1,3000 );
                         g_lugar := 'Actualizando Error en el LOG, ';
                         pr_ins_sb_snp_log_envios(rg_mensaje.nro_referencia, 'A', 'E', pas_snp.g_msj_error);
                         if pas_snp.fu_obt_cod_error <> 0 then
                            raise ex_error;
                         end if;
                      else
                         g_lugar := 'Actualizando datos en ge_snp_transferencias, ';
                         -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
                         update ge_snp_transferencias t
                            set t.situacion = 'V',
                                t.estado    = nvl( p_estado, 'A' ),
                                t.error     = null
                          where t.nro_referencia = g_msj.nro_referencia;
                      end if;
                    end if;
                  end if;
                  end if;

               else
                 if (nvl(fug_obt_pardinamico('SNP_HAB_ENV'),'S') = 'S' and rg_mensaje.cod_msj_swift = 103)
                   or rg_mensaje.cod_msj_swift = 202 then
                   -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Liquidada
                   update ge_snp_transferencias t
                      set t.situacion = 'L',
                          t.estado    = 'A'
                    where t.nro_referencia = rg_mensaje.nro_referencia;
                 end if;
               end if;
            end if;
         end if;
     -- else
        --SPI
        --se enviara al BCP con Periodo Cerrado los MT202 de fondeo entre las ctas
        --este escenario solo se dara previo a la recepcion del periodo de intercambio1
        elsif rg_mensaje.cod_msj_swift = 202 and rg_mensaje.cod_tip_operacion = 029 and rg_mensaje.observacion = '/BNF/SPI' then
          --Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Enviado a BCP
          /*update ge_snp_transferencias t
             set t.situacion = 'V', t.estado = nvl(p_estado, 'A'), t.error = null
           where t.nro_referencia = rg_mensaje.nro_referencia;*/

           --Si tiene problemas al intentar generar movimientos se cargar� el c�digo de error
           /* if pas_snp.fu_obt_cod_error <> 0 then
             raise ex_salir;
            else*/
            --Obtiene el registro de ge_snp_transferencias nuevamente
              g_lugar := 'Obteniendo el mensaje de la referencia '||rg_mensaje.nro_referencia||', ';
              pas_snp.pr_obt_mensaje( rg_mensaje.nro_referencia, 'N' );
              if pas_snp.fu_obt_cod_error <> 0 then
               raise ex_salir;
              else
               rg_mensaje := pas_snp.fu_obt_reg_transferencias;
               pas_snp.pr_ini_registros;
              end if;
             if rg_mensaje.error is not null then
                pas_snp.g_cod_error := 35;
                pas_snp.g_msj_error := rg_mensaje.error;
                raise ex_salir;
             end if;
           -- end if;
           -- TRFS-533-Inserta mensaje para que el OWL/ETL procese

            if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
                      g_lugar := 'Insertando en ge_men_env_sipap, ';
                      -- Inserta mensaje para que el OWL/ETL procese
                         begin
                         insert into ge_men_env_sipap
                           (nro_referencia, estado, msj_swift)
                         values
                           (rg_mensaje.nro_referencia,
                            'PENDING',
                            REPLACE(REPLACE(rg_mensaje.msj_swift,
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
                                    pas_snp.pr_ins_sb_snp_log_envios(rg_mensaje.nro_referencia,
                                                                     'A',
                                                                     'E',
                                                                     pas_snp.g_msj_error);
                                    raise ex_error;

                           end;
            else
            g_lugar := 'Conect�ndose al socket, ';
            -- Envia el mensaje al servidor
            g_ok := fue_env_tcp_mensajes( p_servidor   => g_servidor,
                                          p_puerto     => g_puerto,
                                          p_tie_espera => g_tie_espera,
                                          p_mensaje    => pas_snp.fu_con_mensaje( rg_mensaje.msj_swift ),
                                          p_respuesta  => v_resp);
            end if;
      else
          -- Setea la mensajer�a a CANCELADO, registrando el error encontrado.
         pas_snp.pr_set_texto ( rg_mensaje.error, 'Horario NO est� VIGENTE en BCP', pas_snp.fu_obt_salto );
         update ge_snp_transferencias t
            set t.estado = 'C',
                t.error  = rg_mensaje.error
          where t.nro_referencia = rg_mensaje.nro_referencia;
      end if;
   else
     if (nvl(fug_obt_pardinamico('SNP_HAB_ENV'),'S') = 'S' and rg_mensaje.cod_msj_swift = 103)
        or rg_mensaje.cod_msj_swift = 202 then
      -- Actualizar el registro de ge_snp_transferencias, estado Aprobado y situacion Liquidado a BCP para GUI
      update ge_snp_transferencias t
         set t.situacion = 'L',
             t.estado    = 'A'
       where t.nro_referencia = rg_mensaje.nro_referencia;
     end if;
   end if;
EXCEPTION
  when ex_error then
    update ge_snp_transferencias t
       set t.situacion = rg_mensaje.situacion,
           t.estado    = rg_mensaje.estado
     where t.nro_referencia = rg_mensaje.nro_referencia;
    pas_snp.g_msj_error := g_lugar || pas_snp.fu_obt_msj_error;
  when ex_salir then
    if pas_snp.fu_obt_cod_error <> 0 then
       pas_snp.g_cod_error := 35;
       pas_snp.g_msj_error := 'Error al intentar enviar el SWIFT, ' || g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error;
    end if;
  when others then
    pas_snp.g_cod_error := 35;
    pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_ARC_SWIFT: ' || g_lugar || pas_snp.fu_obt_cod_error || ' - ' || sqlerrm;
    update ge_snp_transferencias t
       set t.situacion = rg_mensaje.situacion,
           t.estado    = rg_mensaje.estado
     where t.nro_referencia = rg_mensaje.nro_referencia;
END pr_gen_arc_swift;

PROCEDURE pr_gen_arc_swi_lote( p_msj_lote in long )
IS
   /*
   || Env�a la mensajer�a en LOTE al Socket.
   */

   v_resp varchar2(4000):=null;

BEGIN
   /*
   || Env�a la mensajer�a en batch al socket
   */

   /*Inicializa la aplicacion y el modulo*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   --

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   if nvl(fug_obt_pardinamico('SNP_HAB_ENV'),'S') = 'S' then
       g_lugar := 'Conect�ndose al socket, ';
       -- Envia el mensaje al servidor
       g_ok := fue_env_tcp_mensajes( p_servidor   => g_servidor,
                                     p_puerto     => g_puerto,
                                     p_tie_espera => g_tie_espera,
                                     p_mensaje    => pas_snp.fu_con_mensaje( p_msj_lote ),
                                     p_respuesta  => v_resp
                                   );

       if g_ok != 'S' and v_resp not in ('02-Limite de tiempo de espera') THEN -- DA-4875 -- NGRANCE --
          -- Hubo problema en el envio
          pas_snp.g_cod_error := 36;
          pas_snp.g_msj_error := g_lugar || 'error durante la conexi�n con el socket: ' || substr( v_resp,1,1000 );
          raise_application_error(-20001, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error );
       end if;
   end if;
EXCEPTION
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         pas_snp.g_cod_error := 36;
         pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_ARC_SWI_LOTE: ' || g_lugar || sqlerrm;
         raise_application_error ( -20001, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error );
      end if;
END pr_gen_arc_swi_lote;

PROCEDURE pr_gen_mov_snp ( p_hora            in  ge_movimientos.hora%type,
                           p_fecha           in  ge_movimientos.fecha%type,
                           p_cod_usuario     in  ge_movimientos.cod_usuario%type,
                           p_gen_workflow    in  varchar2 default 'S',
                           p_origen          in  ge_snp_transferencias.origen%type default 'I',
                           p_plataforma      in  ge_snp_transferencias.plataforma%type default 'X',
                           p_nro_ref_externa in  ge_snp_transferencias.nro_ref_externa%type default null,
                           p_ind_enviado     in  varchar2 default 'S',
                           p_cod_programa    out ba_programas.cod_programa%type,
                           p_nro_referencia  out ge_snp_transferencias.nro_referencia%type,
                           p_cod_tra_padre   in  ge_snp_transferencias.cod_tra_padre%type default null
                         )
   /*Genera mensajeria parcial a partir del Movimiento*/
IS

   v_nro_referencia    ge_snp_transferencias.nro_referencia%type := NULL;
   v_fecha             ge_snp_transferencias.fecha%type;
   v_fec_valor         ge_snp_transferencias.fec_valor%type;
   v_cod_msj_swift     ge_snp_transferencias.cod_msj_swift%type;
   v_tip_operacion     ge_snp_transferencias.cod_tip_operacion%type;
   v_sub_tip_operacion ge_snp_transferencias.cod_sub_tip_operacion%type;
   v_ind_valor         ge_snp_transferencias.ind_valor%type := 'N';
   v_nro_cta_benef     ge_snp_transferencias.nro_cta_beneficiario%type;
   v_prioridad         ge_snp_transferencias.prioridad%type := 20;
   v_nro_cta_sol       ge_cuentas.nro_cuenta%type;
   v_cod_modulo        ba_modulos.cod_modulo%type;
   v_cod_modalidad     ge_modalidades.cod_modalidad%type;
   v_cod_oficina       ba_oficinas.cod_oficina%type;
   v_concepto          ge_movimientos.concepto%type;
   v_con_movimiento    ge_movimientos.concepto%type;
   v_monto             ge_movimientos.monto%type;
   v_cod_moneda        ba_monedas.cod_moneda%type;
   v_cod_persona       ba_personas.cod_persona%type;
   v_cod_tra_padre     ge_snp_transferencias.cod_tra_padre%type := nvl(p_cod_tra_padre,pas_snp.fu_obt_cod_tra_padre);

   CURSOR datos IS
      SELECT m.fec_valor,
             m.cod_tra_padre,
             m.cod_mad_padre,
             m.cod_transaccion,
             m.cod_modulo,
             m.cod_modalidad,
             m.monto,
             m.cod_moneda,
             m.nro_cuenta,
             m.cod_oficina,
             m.nro_documento,
             m.nro_documento2,
             m.concepto,
             m.cod_banco,
             m.referencia
        FROM gv_movimientos m
       WHERE m.fecha         = v_fecha
         AND m.hora          = p_hora
         AND m.cod_usuario   = p_cod_usuario
         AND m.cod_tra_padre = v_cod_tra_padre -- pas_snp.fu_obt_cod_tra_padre
         AND m.cod_mod_padre = pas_snp.fu_obt_cod_mod_padre
         AND m.cod_mad_padre = pas_snp.fu_obt_cod_mad_padre
         AND m.nro_documento2 IS NOT NULL
       ORDER by m.nro_secuencia DESC;
BEGIN
   IF p_fecha IS NULL THEN
      v_fecha := pas_snp.g_fec_actual;
   ELSE
      v_fecha := p_fecha;
   END IF;
   p_cod_programa  := NULL ;
   BEGIN
       FOR dt IN datos LOOP
           v_cod_msj_swift     := substr(dt.nro_documento2,1,1);
           if v_cod_msj_swift= 8 then
           v_cod_msj_swift     := substr(dt.nro_documento2,1,1);
           v_tip_operacion     := substr(dt.nro_documento2,2,3);
           v_sub_tip_operacion := substr(dt.nro_documento2,5,3);
           else
           v_cod_msj_swift     := substr(dt.nro_documento2,1,3);
           v_tip_operacion     := substr(dt.nro_documento2,4,3);
           v_sub_tip_operacion := substr(dt.nro_documento2,7,3);
           end if;
           IF v_cod_msj_swift = 104 THEN
              --Si es un MT104 solo debe mostrar la transferencia ya registrada
              p_cod_programa      := 'gmsnp104';
              EXIT;
           ELSIF v_cod_msj_swift IN ( 102, 103, 202 ) AND
              dt.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
           THEN
              --Solo si es un DEBITO a la CTA. INTERBANCARIA en la entidad, entonces es un MT102
              v_fec_valor     := dt.fec_valor;
              v_cod_modulo    := dt.cod_modulo;
              v_cod_modalidad := dt.cod_modalidad;
              v_cod_moneda    := dt.cod_moneda;
              v_monto         := dt.monto;
              v_cod_oficina   := dt.cod_oficina;
              v_concepto      := dt.concepto;
              v_cod_persona   := fug_obt_cli_principal(dt.nro_cuenta) ;
              IF v_cod_msj_swift = 202 THEN
                 p_cod_programa := 'gmsnp202';
                 v_ind_valor    := 'S';
                 IF v_tip_operacion in ( '002', '003' ) THEN
                    -- Solo si es operaci�n de Retiro/Dep�sito en Efectivo levantar el GMSNPDEE
                    p_cod_programa := 'gmsnpdee';
                 END IF;
              END IF ;
           ELSIF v_cod_msj_swift IN ( 102, 103,8 ) AND
              dt.cod_modalidad <> pas_snp.fu_obt_cod_mad_padre
           THEN
              --Si es un DEBITO evaluar si se debita solamente al cliente
              v_nro_cta_sol       := dt.nro_cuenta;
              p_cod_programa      := 'gmsnp103';
              v_cod_persona       := fug_obt_cli_principal(dt.nro_cuenta) ;

              IF pae_cnf.g_programa = 'AMTRCSER' AND dt.cod_transaccion = 4030 THEN
                 -- Se agrega para DNA
                 v_nro_cta_benef     := dt.referencia;
              END IF;

              IF v_cod_msj_swift = 102 THEN
                 v_ind_valor     := 'N';
              ELSE
                 v_ind_valor     := 'S';
              END IF;
           END IF;
       END LOOP;
   END ;
       --
   IF p_cod_programa IS NOT NULL THEN
      --Cargar datos mas importantes en la tabla ge_snp_transferencias
      BEGIN
        SELECT nro_referencia
          INTO v_nro_referencia
          FROM ge_snp_transferencias t
         WHERE t.fecha        = v_fecha
           AND t.hora         = p_hora
           AND t.cod_usuario  = nvl( p_cod_usuario, USER );

      EXCEPTION
         WHEN no_data_found THEN
            IF v_cod_msj_swift = '104' THEN
               raise_application_error(-20001, 'No se han encontrado datos para el movimiento con Fecha: '|| to_char( v_fecha,'DD/MM/YYYY' ) ||                                                                                                                      ' Hora: '|| p_hora ||
                                                                                                     ' Usu : '|| nvl( p_cod_usuario, USER ) );
            ELSE
           BEGIN
              /* Inicializa variables */
              pas_snp.g_msj := NULL;
              --
              BEGIN
                 SELECT m.prioridad
                   INTO v_prioridad
                   FROM ge_snp_par_mensajes m
                  WHERE m.cod_msj_swift                  = v_cod_msj_swift
                    AND m.cod_tip_operacion              = v_tip_operacion
                    AND nvl(m.cod_sub_tip_operacion,'x') = nvl(v_sub_tip_operacion,'x');
              EXCEPTION
                 WHEN others THEN
                   v_prioridad := CASE nvl( v_cod_msj_swift, 102 )
                                    WHEN 102 THEN 100
                                    ELSE 20
                                  END; -- Cualquier error coloca la prioridad por defecto
              END;

              v_nro_referencia := pas_snp.fu_obt_sig_nro_referencia;

              pas_snp.g_msj.nro_referencia          := v_nro_referencia;
              pas_snp.g_msj.cod_modulo              := v_cod_modulo;
              pas_snp.g_msj.cod_modalidad           := v_cod_modalidad;
              pas_snp.g_msj.cod_oficina             := v_cod_oficina;
              pas_snp.g_msj.fec_valor               := v_fec_valor;
              pas_snp.g_msj.fec_ingreso             := v_fecha;
              pas_snp.g_msj.fecha                   := v_fecha;
              pas_snp.g_msj.hora                    := p_hora;
              pas_snp.g_msj.cod_usuario             := nvl( p_cod_usuario, USER );
              pas_snp.g_msj.nro_operacion           := v_nro_referencia;
              pas_snp.g_msj.cod_moneda              := v_cod_moneda;
              pas_snp.g_msj.cod_tip_operacion       := v_tip_operacion;
              pas_snp.g_msj.cod_sub_tip_operacion   := v_sub_tip_operacion;
              pas_snp.g_msj.monto                   := v_monto;

              -- Si el Nro. Cta del Solicitante tiene alg�n valor entonces se recupera los datos de la persona relacionada a ella.
              IF p_ind_enviado = 'S' THEN
                 pas_snp.g_msj.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
                 IF v_nro_cta_sol IS NOT NULL THEN
                    pas_snp.g_msj.cod_per_solicitante     := fug_obt_cli_principal( v_nro_cta_sol );
                    pas_snp.g_msj.nom_solicitante         := fue_obt_nom_persona( pas_snp.g_msj.cod_per_solicitante );
                    pas_snp.g_msj.dir_solicitante         := fue_obt_dir_principa( pas_snp.g_msj.cod_per_solicitante );
                    pas_snp.g_msj.cod_tip_doc_solicitante := fue_obt_doc_principal( pas_snp.g_msj.cod_per_solicitante ) ;
                    pas_snp.g_msj.nro_doc_solicitante     := substr(fue_obt_nro_doc_persona( pas_snp.g_msj.cod_per_solicitante ),1,20);
                    pas_snp.g_msj.nro_cta_solicitante     := v_nro_cta_sol;
                 END IF;
              ELSE
                 pas_snp.g_msj.cod_swi_pte_beneficiario := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
                 pas_snp.g_msj.fec_recepcion            := sysdate;
                 IF v_nro_cta_sol IS NOT NULL THEN
                    pas_snp.g_msj.cod_per_beneficiario     := fug_obt_cli_principal( v_nro_cta_sol );
                    pas_snp.g_msj.nom_beneficiario         := fue_obt_nom_persona( pas_snp.g_msj.cod_per_beneficiario );
                    pas_snp.g_msj.dir_beneficiario         := fue_obt_dir_principa( pas_snp.g_msj.cod_per_beneficiario );
                    pas_snp.g_msj.cod_tip_doc_beneficiario := fue_obt_doc_principal( pas_snp.g_msj.cod_per_beneficiario ) ;
                    pas_snp.g_msj.nro_doc_beneficiario     := substr(fue_obt_nro_doc_persona( pas_snp.g_msj.cod_per_beneficiario ),1,20);
                    pas_snp.g_msj.nro_cta_beneficiario     := v_nro_cta_sol;
                 END IF;
              END IF;
              --
              v_con_movimiento := pas_snp.fu_obt_mov_concepto('M','I',v_nro_referencia);
              --
              pas_snp.g_msj.concepto                 := pas_snp.fu_val_cadena( nvl( v_concepto, v_con_movimiento ) );
              pas_snp.g_msj.cod_msj_swift            := v_cod_msj_swift;
              pas_snp.g_msj.ind_valor                := v_ind_valor;
              pas_snp.g_msj.prioridad                := v_prioridad;
              pas_snp.g_msj.situacion                := 'P';
              pas_snp.g_msj.estado                   := 'S';
              pas_snp.g_msj.origen                   := p_origen;
              pas_snp.g_msj.plataforma               := p_plataforma;
              pas_snp.g_msj.indemnizado              := 'N';
              -- Para GUI
              IF p_plataforma = 'G' THEN
                 pas_snp.g_msj.nro_ref_externa := p_nro_ref_externa;
              END IF;
              -- Para DNA
              IF v_nro_cta_benef IS NOT NULL THEN
                 pas_snp.g_msj.nro_cta_beneficiario     := v_nro_cta_benef ;
              END IF;
              pas_snp.g_msj.cod_tra_padre    := v_cod_tra_padre;
              pas_snp.g_lugar :=  'Insertando Mensajer�a.., ';
              pas_snp.pr_ins_transferencias ( pas_snp.g_msj );
              if pas_snp.fu_obt_cod_error <> 0 then
                 raise_application_error (-20001, pas_snp.fu_obt_msj_error);
              end if;

              --Una vez registrada la mensajer�a, se ACTUALIZA el movimiento con el NRO_REFERENCIA y NRO_SEC_LOTE
              BEGIN
                 UPDATE ge_movimientos m
                    SET m.nro_documento  = to_number( substr( v_nro_referencia,1,15 ) ),
                        m.concepto       = DECODE( m.nro_documento2, NULL, m.concepto, pas_snp.g_msj.concepto )
                  WHERE m.hora           = p_hora
                    AND m.cod_usuario    = nvl( p_cod_usuario, USER )
                    AND m.fecha          = v_fecha
                    AND m.cod_mod_padre  = pas_snp.fu_obt_cod_mod_padre
                    AND m.cod_mad_padre  = pas_snp.fu_obt_cod_mad_padre
                    AND m.cod_tra_padre  = v_cod_tra_padre--pas_snp.fu_obt_cod_tra_padre
                    AND m.monto          > 0;
                 IF sql%notfound THEN
                    raise_application_error(-20002, 'No se ha podido RELACIONAR el movimiento con el SWIFT generado. Fecha: '|| to_char( v_fecha,'DD/MM/YYYY' ) ||
                                                                                                                    ' Hora: '|| p_hora ||
                                                                                                                    ' Usu : '|| nvl( p_cod_usuario, USER ) );
                 END IF;
              END;
              --
              IF p_gen_workflow = 'S' THEN
                pas_snp.pr_ini_workflow( pas_snp.g_msj );
                if pas_snp.fu_obt_cod_error <> 0 then
                   raise_application_error (-20003, pas_snp.fu_obt_msj_error);
                else
                   commit ;-- Con esto se tiene la integridad del circuito de datos para su posterior seguimiento en el WF.
                end if;
              END IF;
              --
           END;
         END IF;
      END;
      -- Devuelve los datos del MT relacionado al movimiento
      p_nro_referencia := v_nro_referencia;
   END IF;
EXCEPTION
   WHEN dup_val_on_index THEN
      raise_application_error( -20004,' Ya existen registros en ge_snp_transferencias para el n�mero de transferencia '||p_nro_referencia||', verifique.!' );
   WHEN others then
      IF sqlcode <= -20000 THEN
         raise;
      ELSE
         raise_application_error( -20005,'Error en PAS_SNP.PR_GEN_MOV_SNP' || '-' || sqlerrm );
      END IF;

END pr_gen_mov_snp;

FUNCTION fu_val_cta_ban_participante ( p_cod_swift            in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                       p_cod_moneda           in ba_monedas.cod_moneda%type,
                                       p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type
                                     ) return varchar
IS
  /*Valida la cuenta bancaria del participante*/
  v_existe varchar2(1) := 'N';
BEGIN
 /*Inicializa las variables de error*/
  pas_snp.pr_ini_variables;
  --

  --Primero se buscar� la Cta. F�sica en CC_CTA_BANCARIAS
  select distinct 'S'
    into v_existe
    from cc_cta_bancarias cb,
         ge_cta_clientes cc,
         gv_snp_participantes v
   where cb.nro_cuenta       = cc.nro_cuenta
     and cb.cod_moneda       = ltrim(rtrim(p_cod_moneda))
     and cc.relacion         = 'P'
     and cb.estado           IN ( 'A', 'N', 'S' ) /*Abierta, Normal, Bloqueo de Saldo*/
     and cb.cod_modulo       = pas_snp.fu_obt_cod_mod_padre
     and cb.cod_modalidad    = pas_snp.fu_obt_cod_mad_padre
     and cc.cod_persona      = v.cod_persona
     and v.cod_swift         = trim(p_cod_swift)
     and cb.nro_cta_bancaria = p_nro_cta_participante
     and fug_obt_paradicional(cb.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ'
  union all
  select distinct 'S'
    from ba_personas p,
         ge_bancos b,
         ge_snp_cta_bancos cb,
         gv_snp_participantes v
   where p.cod_persona       = b.cod_persona
     and b.cod_persona       = v.cod_persona
     and v.cod_swift         = trim(p_cod_swift)
     and v.cod_banco         = b.cod_banco
     and b.cod_banco         = cb.cod_banco
     and cb.cod_moneda       = ltrim(rtrim(p_cod_moneda))
     and cb.ind_activo       = 'S'
     and cb.nro_cta_bancaria = p_nro_cta_participante
  union all
  select distinct 'S'
    from ba_personas p, ge_entes e,
         ge_snp_cta_entes ce, gv_snp_participantes v
   where p.cod_persona       = e.cod_persona
     and e.cod_persona       = v.cod_persona
     and v.cod_swift         = trim(p_cod_swift)
     and v.cod_ente          = e.cod_ente
     and e.cod_ente          = ce.cod_ente
     and ce.cod_moneda       = ltrim(rtrim(p_cod_moneda))
     and ce.ind_activo       = 'S'
     and ce.nro_cta_bancaria = p_nro_cta_participante
  union all
     select distinct 'S'
       from ge_snp_patrocinador_cab s, ge_snp_patrocinador_det d
      where s.cod_swift = d.cod_swift_padre
        and d.estado = 'S'
        and trim(d.cta_interna_sub) = trim(p_nro_cta_participante)
        and s.cod_moneda = ltrim(rtrim(p_cod_moneda))
        and d.cod_swift_sub = trim(p_cod_swift);

  return v_existe;

EXCEPTION
   when no_data_found then
      pas_snp.g_cod_error := 78;
      pas_snp.g_msj_error := 'Cuenta Bancaria ' || p_nro_cta_participante || ' inexistente para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
      return 'N';
   when too_many_rows Then
      pas_snp.g_cod_error := 78;
      pas_snp.g_msj_error := 'Existe m�s de una Cta. Bancaria ' || p_nro_cta_participante || ' para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
      return 'N';
   when others then
      pas_snp.g_cod_error := 78;
      pas_snp.g_msj_error := 'Error en PAS_SNP.FU_VAL_CTA_BAN_PARTICIPANTE' || ' - ' || sqlerrm;
      return 'N';
END fu_val_cta_ban_participante;

FUNCTION fu_val_dat_ingresado ( p_sql varchar2 ) return boolean
IS
  /*
  || Valida el dato ingresado contra ITGF.
  */

  type     t_tipo_cursor IS REF CURSOR;
  cu_datos t_tipo_cursor;
  v_existe varchar2(1):= 'N';
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   open cu_datos for p_sql;
   loop
     fetch cu_datos into v_existe;
     exit when cu_datos%notfound;
   end loop;
   close cu_datos;
   if v_existe = 'N' then
      return FALSE;
   else
      return TRUE;
   end if;
EXCEPTION
  when others then
    pas_snp.g_cod_error := 56;
    pas_snp.g_msj_error := substr(sqlerrm,1,200);
    return FALSE;
END fu_val_dat_ingresado;

FUNCTION fu_val_par_mensajes ( p_cod_swift         in ge_snp_transferencias.cod_msj_swift%type,
                               p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                               p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type default null
                             ) return boolean
IS
   /*
   || Valida datos cargados contra la configuraci�n realizada en la tabla GE_PAR_MENSAJES
   */
  v_existe varchar2(1) := 'N';
BEGIN
   SELECT distinct 'S'
     INTO v_existe
     FROM ge_snp_par_mensajes m
    WHERE m.cod_msj_swift                  = p_cod_swift
      AND m.cod_tip_operacion              = p_tip_operacion
      AND nvl(m.cod_sub_tip_operacion,'x') = nvl(p_sub_tip_operacion,'x');
   return TRUE;
EXCEPTION
  when others then
    return FALSE;
END fu_val_par_mensajes;

FUNCTION fu_val_perfil ( rg_msj_perfil in pas_snp.rg_msj ) return boolean
IS
  /*Valida datos del perfil del cliente*/
  v_nro_cuenta           ge_snp_transferencias.nro_cta_beneficiario%type;
  v_mto_mon_fuerte       ge_snp_transferencias.monto%type;
  v_cot_origen           ge_cotizaciones.val_conversion%type;
  v_cot_destino          ge_cotizaciones.val_conversion%type;

BEGIN
  if rg_msj_perfil.cod_moneda is not null and
     rg_msj_perfil.monto is not null
  then
     if pas_snp.fu_val_es_enviado( rg_msj_perfil ) then
        v_nro_cuenta := rg_msj_perfil.nro_cta_solicitante;
     else
        v_nro_cuenta := rg_msj_perfil.nro_cta_beneficiario;
     end if;
     -- Si la moneda de la transferencia es diferente a la moneda fuerte,
     -- realizar cambio de moneda a fuerte para la validaci�n.
     if rg_msj_perfil.cod_moneda != pag_gen.fu_obt_mon_fuerte then
        pag_gen.pr_con_mon_a_moneda( rg_msj_perfil.cod_moneda,
                                     pag_gen.fu_obt_mon_fuerte,
                                     nvl( rg_msj_perfil.monto, 0 ),
                                     v_mto_mon_fuerte,
                                     v_cot_origen,
                                     v_cot_destino
                                   );
     else
        v_mto_mon_fuerte := nvl( rg_msj_perfil.monto, 0 );
     end if;
     if v_mto_mon_fuerte > g_ope_sup_mon_fuerte then
        if g_dir_mai_cumplimiento is not null then
           BEGIN
              it_mail.mail( fug_obt_dir_correo,
                            g_dir_mai_cumplimiento,
                            'El monto de la transferencia sobrepasa el cumplimiento configurado. ',
                            'A continuaci�n los datos de la mensajer�a: '                                       || chr(10) || chr(10) ||
                            'Nro. Referencia : ' || rg_msj_perfil.nro_referencia                                || chr(10) ||
                            'Fecha Valor     : ' || to_char(rg_msj_perfil.fec_valor,'DD/MM/YYYY')               || chr(10) ||
                            'Nro. Cuenta     : ' || v_nro_cuenta                                                || chr(10) ||
                            'Moneda          : ' || rg_msj_perfil.cod_moneda                                    || chr(10) ||
                            'Monto           : ' || trim(to_char(rg_msj_perfil.monto,'999,999,999,999,999.99')) || chr(10) ||
                            chr(10) || chr(10) ||
                            'Atentamente.'
                          );
           EXCEPTION
             when others then
               NULL;
           END;
        end if;
        return FALSE;
     else
        return TRUE;
     end if;
  else
    return FALSE;
  end if;
END fu_val_perfil;

FUNCTION fu_val_cadena ( p_cadena in varchar2 ) return varchar2
IS
   /*
   || Excluye de la cadena los caracteres no permitidos en la mensajer�a seg�n SWIFT CHARACTER SET del CMA
   */
   v_cadena VARCHAR2(4000); --TCE-260
   --v_str_invalidos varchar2(200)  := '�������������������������������������'||chr(9)/*TAB*/||'"��`��!#'||'&'||'$*~^%�@��|[]<>�{}\=_;';
   --v_reemplazo     varchar2(50)   := 'naeiouaeiouaeioucaNAEIOUYAEIOUAEIOUCA';
   --TCE-260
   v_str_invalidos varchar2(200)  := fug_obt_pardinamico('TRANSL_CHAR_ORI')||chr(9)/*TAB*/||fug_obt_pardinamico('CHAR_ESP_LIMP');
   v_reemplazo     varchar2(50)   := fug_obt_pardinamico('TRANSL_CHAR_DST');
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   v_cadena := p_cadena;
   --TCE-519 verifico si el string tiene caracteres de WE8MSWIN1252
   IF  REGEXP_LIKE(p_cadena,fug_obt_pardinamico('CHK_IF_NLS_STR'),'i') THEN
     --TCE-260 convierto los caracteres incorrectos de WE8MSWIN1252 a UTF8
     BEGIN
       v_cadena := CONVERT(p_cadena, fug_obt_pardinamico('TRF_COD_NLS_API'), fug_obt_pardinamico('TRF_COD_NLS_SWF'));
     exception when others then
       v_cadena := p_cadena;
     end;
   END IF;
   return ltrim(rtrim(translate(v_cadena,v_str_invalidos,v_reemplazo)));

EXCEPTION
  when others then
     pas_snp.g_cod_error := 37;
     pas_snp.g_msj_error := 'Error en PAS_SNP.FU_VAL_CADENA: '||sqlerrm;
     return NULL;
END fu_val_cadena;

FUNCTION fu_val_cadena ( p_cadena in varchar2,
                         p_tipo   in varchar2
                       ) return varchar2
IS
   /* Expone de la cadena solamente los tipos de caracteres permitidos.
   || N=S�lo caracteres num�ricos, L=S�lo caracteres del alfabeto, A=S�lo caracteres alfanum�ricos
   */
   v_letras      varchar2(100) := 'ABCDEFGHIJKLMN�OPQRSTUVWXYZ';
   v_numeros     varchar2(100) := '0123456789';
   v_car_validos varchar2(100) := null;
   v_caracteres  varchar2(4000):= null;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   if p_tipo = 'N' then -- Solo n�meros
      v_car_validos := v_numeros;
   elsif p_tipo = 'L' then -- Solo letras
      v_car_validos := v_letras;
   else -- Alfanum�rico
      v_car_validos := v_letras || v_numeros;
   end if;

   for i in 1..nvl( length( p_cadena ), 0 ) loop
      if instr( v_car_validos, substr( upper( p_cadena ), i, 1 ) ) > 0 then
         pas_snp.pr_set_texto( v_caracteres, substr( p_cadena, i, 1 ), '' );
      end if;
   end loop;
   return v_caracteres;
EXCEPTION
  when others then
     pas_snp.g_cod_error := 80;
     pas_snp.g_msj_error := 'Error en PAS_SNP.FU_VAL_CADENA para el Tipo ' || p_tipo || ': '||sqlerrm;
     return NULL;
END fu_val_cadena;

FUNCTION fu_val_fec_valor ( p_fec_valor   in ge_snp_transferencias.fec_valor%type,
                            p_fec_actual  in ge_snp_transferencias.fecha%type default null
                          ) return number
IS
   /*
   || Valida que la fecha valor ingresada como par�metro no sobrepase
   || los d�as h�biles permitidos en BCP.
   */

   c_fecha constant ge_calendarios.fec_actual%type := nvl( p_fec_actual, g_fec_actual );

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   /*
   ||Verifica :
   || - Fecha sea mayor a la fecha del sistema para el m�dulo general o
   || - Fecha no sea fin de semana.
   */
   if p_fec_valor < c_fecha or
      trim(to_char(p_fec_valor,'DAY')) in ('SATURDAY','SABADO','S�BADO','SUNDAY','DOMINGO')
   then
      return 1;
   end if;

   if p_fec_valor <= pag_cal.fu_obt_fec_fin_ret( c_fecha,        -- Fecha Valor
                                                 NULL,           -- Cod. Oficina
                                                 g_dia_fec_valor -- Dias Habiles
                                               ) then
      return 0; --Fecha V�lida
   end if;
   return 1; --Fecha inv�lida
EXCEPTION
  when others then
    pas_snp.g_cod_error := 38;
    pas_snp.g_msj_error := 'Error en PAS_SNP.FU_VAL_FEC_VALOR: ' || g_lugar || ' - ' || sqlerrm;
    return 1;
END fu_val_fec_valor;

FUNCTION fu_obt_fec_transferencia ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                                    p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                    p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type,
                                    p_fec_valor         in ge_calendarios.fec_actual%type
                                  ) return date
IS
   v_fec_actual ge_calendarios.fec_actual%type := pas_snp.g_fec_actual;

   FUNCTION lf_obt_fec_disponible ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                                    p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                    p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type
                                  ) RETURN date
   IS
     v_fec_actual      ge_calendarios.fec_actual%type := pas_snp.g_fec_actual;
     v_est_mod_abierto ba_cod_referencias.val_minimo%type;
   BEGIN
      -- Se busca el c�digo del estado del proceso (ABIERTO)
      begin
         select b.val_minimo
           into v_est_mod_abierto
           from ba_cod_referencias b
          where b.dominio = 'EST_PROCESO'
            and trim(upper(b.abreviatura)) = 'ABIERTO';
      exception
        when others then
          v_est_mod_abierto := 2;
      end;

      if to_number( pae_cnf.fu_obt_est_modulo( 1 ) ) > v_est_mod_abierto     -- Si el estado del m�dulo es mayor a 2(Abierto) entonces se considera CERRADO
        or ( to_number( pae_cnf.fu_obt_est_modulo( 1 ) ) = v_est_mod_abierto -- Si el estado del m�dulo 2(Abierto), el horario en BCP
          and pas_snp.fu_obt_est_horario( p_cod_msj_swift,                   -- est� deshabilitado y la fecha calendario es menor a la fecha de �ltimo horario en BCP
                                          p_tip_operacion,                   -- entonces se considera CERRADO
                                          p_sub_tip_operacion
                                        ) <> 'A'
        and fu_obt_fec_ult_periodo( p_cod_msj_swift,                   -- est� deshabilitado y la fecha calendario es menor a la fecha de �ltimo horario en BCP
                                          p_tip_operacion,                   -- entonces se considera CERRADO
                                          p_sub_tip_operacion)= v_fec_actual )
      then
         -- Para setear el campo error si no se encontr� abierto
         pas_snp.pr_ini_variables;
         --
         return pag_cal.fu_obt_fec_sig_hab( v_fec_actual, null );
      end if;
      return v_fec_actual;
   EXCEPTION
     when others then
        return v_fec_actual;
   END lf_obt_fec_disponible;
BEGIN
   if p_fec_valor <= v_fec_actual then
      return lf_obt_fec_disponible( p_cod_msj_swift, p_tip_operacion, p_sub_tip_operacion );
   elsif p_fec_valor > v_fec_actual then
      --Se valida la fecha tope para Transferencias Futuras (7 d�as). La variable g_dia_fec_valor de PAS_SNP contiene el tope de d�as Fecha Futura
     if p_fec_valor > pag_cal.fu_obt_fec_sig_hab( v_fec_actual, 1, g_dia_fec_valor ) then
        --Si supera se retorna la fecha tope posible
        return pag_cal.fu_obt_fec_sig_hab( v_fec_actual, 1, g_dia_fec_valor );
     else --Si NO supera se retorna la fecha h�bil (podria ser la misma o una fecha siguiente, ej. S�bado retorna Lunes)
        return pag_cal.fu_obt_fec_habil(p_fec_valor,1,1);
     end if;
   end if;
   return v_fec_actual;
EXCEPTION
   when others then
     return v_fec_actual;
END fu_obt_fec_transferencia;

FUNCTION fu_obt_fec_ult_operacion return date
IS
  /*
  || Obtiene la �ltima fecha de intercambio de mensajes con BCP
  */
  v_tip_horario       ge_snp_horarios.tip_horario%type;
  v_fec_ult_operacion ge_snp_horarios.fecha%type;
BEGIN
  -- Se busca el tipo de horario (TRANSFERENCIA)
  begin
     select b.val_minimo
       into v_tip_horario
       from ba_cod_referencias b
      where b.dominio = 'SNP_TIP_HORARIOS'
        and trim( upper( b.abreviatura ) ) = 'TRANSFERENCIA';
  exception
     when others then
       v_tip_horario := 'T';
  end;

  -- Se busca la �ltima fecha de transferencia de mensajes con el BCP.
  begin
     select nvl( max( h.fecha ), pas_snp.g_fec_actual ) fecha
       into v_fec_ult_operacion
       from ge_snp_horarios h
      where h.tip_horario = v_tip_horario
        and h.fecha <= pas_snp.g_fec_actual;
  exception
    when others then
      v_fec_ult_operacion := pas_snp.g_fec_actual;
  end;
  --
  return v_fec_ult_operacion;
  --
END fu_obt_fec_ult_operacion;

PROCEDURE pr_pro_principal ( rg_msj_mov in out rg_msj )
IS
   /*
   || Genera el movimiento de la operaci�n a partir de la mensajer�a.
   */

   --Manejo de Errores
   v_error ge_snp_transferencias.error%type := null;

BEGIN
     /*Inicializa la aplicacion y el modulo*/
     begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

     /*Inicializa las variables de error*/
     pas_snp.pr_ini_variables;

     /**/--Verificando los datos
     g_lugar :=  'Buscando Errores, ';
     if  rg_msj_mov.error is not null then
         -- Como el campo ERROR ya tiene por lo general un salto entonces no se anexa el g_salto
         pas_snp.pr_set_texto ( v_error, g_lugar || rg_msj_mov.error, pas_snp.fu_obt_salto );
     end if;

     g_lugar :=  'Buscando Errores, ';
     if  rg_msj_mov.situacion = 'E' then
         pas_snp.pr_set_texto( v_error, g_lugar || 'Estado de la mensajer�a es ERROR, verifique el campo ERROR.!' , pas_snp.fu_obt_salto );
     end if;

     g_lugar :=  'Obteniendo el c�digo SWIFT, ';
     if  rg_msj_mov.cod_msj_swift is null then
         pas_snp.pr_set_texto ( v_error, g_lugar || 'Valor para c�digo SWIFT debe contener algun valor.!', pas_snp.fu_obt_salto );
     end if;

     g_lugar :=  'Verificando si existe movimiento relacionado, ';
     if  rg_msj_mov.fecha is not null and
         rg_msj_mov.hora is not null and
         rg_msj_mov.cod_usuario is not null then
         pas_snp.pr_set_texto( v_error, g_lugar || 'Existe movimiento relacionado al SWIFT, por tanto no se procesar� el SWIFT!', pas_snp.fu_obt_salto );
     end if;

     if v_error is not null then
        g_cod_error      := 50;
         g_msj_error     := 'Se han encontrado errores al intentar procesar el MT con Ref.: '||rg_msj_mov.nro_referencia;
        rg_msj_mov.error := substr( v_error,1,4000 );
        raise ex_workflow;
     end if;

    --Si no hubieron errores, se procesa la mensajer�a
    if pas_snp.fu_obt_cod_error = 0 then
       if rg_msj_mov.cod_msj_swift in (103,102,202,8,104,4) then
          pas_snp.pr_pro_transferencia ( rg_msj_mov );
       end if;
    else
       raise ex_workflow;
    end if;

EXCEPTION
   when ex_workflow then
     if pas_snp.fu_obt_cod_error <> 0 then --Debe enviar el error al WORKFLOW
        -- Agrega errores al campo error de GE_SNP_TRANSFERENCIAS
        pas_snp.pr_set_texto( rg_msj_mov.error, trim( pas_snp.fu_obt_msj_error ), pas_snp.fu_obt_salto );
        if not pas_snp.fu_val_es_enviado( rg_msj_mov ) then
           /*
           || Si es un MT RECIBIDO El WORKFLOW se inicia en el TB_GE_SNP_TRANSFERENCIAS
           || ya que la mensajer�a puede o no estar registrada en la tabla GE_SNP_TRASNFERENCIAS.
           */
           rg_msj_mov.situacion := 'E';
           rg_msj_mov.estado    := 'S';
        else
           /*
           || Si es un MT ENVIADO El WORKFLOW se puede iniciar en otra sesi�n ya que la mensajer�a
           || ya se encuentra en la tabla GE_SNP_TRANSFERENCIAS.
           */
           rg_msj_mov.situacion := 'P';
           rg_msj_mov.estado    := 'S';
           pas_snp.pr_reg_msj_workflow ( rg_msj_mov );
        end if;
     end if;
   when others then
     pas_snp.g_cod_error := 39;
     pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
     raise_application_error (-20001, 'Error en PAS_SNP.PR_PRO_PRINCIPAL: ' || pas_snp.fu_obt_msj_error );
END pr_pro_principal;

PROCEDURE pr_pro_transferencia( rg_msj_mov_tra in out rg_msj )
IS
   /*
   || Genera el movimiento de transferencia a partir de la mensajer�a que pueden ser MT102, MT103 y MT202
   */

   rg_movi             ge_movimientos%rowtype       := NULL;
   v_nro_cta_debito    ge_cuentas.nro_cuenta%type   := NULL;
   v_nro_cta_credito   ge_cuentas.nro_cuenta%type   := NULL;
   v_nro_cta_entidad   ge_cuentas.nro_cuenta%type   := NULL;
   v_nro_tarjeta       ta_tarjetas.nro_tarjeta%type := NULL;
   v_swi_participante  ge_snp_transferencias.cod_swi_pte_solicitante%type := NULL;
   v_nro_secuencia     ge_movimientos.nro_secuencia%type   := 0;
   v_hora              ge_movimientos.hora%type            := NULL;
   v_cod_usuario       ba_usuarios.cod_usuario%type        := NULL;
   v_tra_padre         ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_padre;
   v_mod_padre         ge_movimientos.cod_mod_padre%type   := pas_snp.fu_obt_cod_mod_padre;
   v_mad_padre         ge_movimientos.cod_mad_padre%type   := pas_snp.fu_obt_cod_mad_padre;
   v_tra_debito        ge_movimientos.cod_transaccion%type := NULL;
   v_tra_credito       ge_movimientos.cod_transaccion%type := NULL;
   v_mto_debito        ge_movimientos.monto%type           := NULL;
   v_mto_credito       ge_movimientos.monto%type           := NULL;
   v_tra_entidad       ge_movimientos.cod_transaccion%type := NULL;
   v_nro_documento2    ge_movimientos.nro_documento2%type  := NULL;
   v_dir_correo        ge_par_dinamicos.val_parametro%type := nvl(pas_snp.g_gru_dir_correo,pas_snp.g_err_dir_correo);
	 v_asunto            varchar2(2000);
   v_txt_mail          varchar2(5000);
   -- Conversi�n de Monedas
   v_mto_destino       ge_movimientos.monto%type         := NULL;
   v_mon_origen        ge_movimientos.cod_moneda%type    := NULL;
   v_mon_destino       ge_movimientos.cod_moneda%type    := NULL;
   v_cotizacion        ge_movimientos.cotizacion%type    := NULL;
   v_cot_origen        ge_movimientos.cotizacion%type    := NULL;
   v_cot_destino       ge_movimientos.cotizacion%type    := NULL;
   v_mto_equ_local     ge_movimientos.mto_equ_local%type := NULL;
   -- Retorno de verificaci�n de operaciones
   v_est_cuenta        ge_cuentas.estado%type;    -- Estado Cta.
   v_sal_disponible    ge_movimientos.monto%type; -- Sal.Dispon.
   v_procesa           varchar2(1) := 'N';
   -- Operaci�n de Contrato de Cambios (C)ompra, (V)enta, (A)rbitraje
   -- Definici�n de Movimientos a ser realizados en el PAS_SNP
   v_concepto          ge_movimientos.concepto%type := NULL;
   v_tip_mov_debito    varchar2(1) := 'D';
   v_tip_mov_credito   varchar2(1) := 'C';
   v_tip_mov_entidad   varchar2(1) := NULL;
   v_ind_cob_cargos    varchar2(1) := 'S';
   v_sol_swift         ge_spi_solicitudes.cod_msj_swift%type;
   --Tipo registros para almacenar datos de las cuentas
   rg_deb              pag_cta.rg_ctas := NULL;
   rg_cre              pag_cta.rg_ctas := NULL;
   rg_pte              pag_cta.rg_ctas := NULL;

   --Variables para Contratos de Cambios
   v_nro_con_cambio lc_ope_pendientes.nro_operacion%type  := NULL;
   v_secuencia      ge_movimientos.nro_secuencia%type;

   --Desbloquea el Saldo de la Cuenta si corresponde y
   --registra el movimiento de Transferencias.
   PROCEDURE lp_reg_mov_transferencia
   IS
   BEGIN
   v_cod_usuario:=null;
       if pas_snp.fu_obt_cod_error = 0 and rg_msj_mov_tra.monto <> 0 then
          -- Detecta si el MT es RECIBIDO o ENVIADO.
          if pas_snp.fu_val_es_enviado ( rg_msj_mov_tra ) then
             if rg_msj_mov_tra.cod_msj_swift != 104 then
             --Es un MT ENVIADO.
             v_nro_cta_debito   := rg_msj_mov_tra.nro_cta_solicitante;
             v_mon_origen       := fug_obt_mon_cta (v_nro_cta_debito);
             if rg_msj_mov_tra.cod_servicio is not null then
                -- Si la mensajer�a corresponde a un Cobro de Servicios
                -- se debe verificar si se cobrar�n cargos, por defecto no se cobrar�n cargos a los Servicios.
                v_ind_cob_cargos :=  nvl( fug_obt_val_par_ente( 'SNP_COB_CARGOS',
                                                                'SNP_COD_SERVICIO',
                                                                rg_msj_mov_tra.cod_servicio
                                                              ), 'N'
                                        );
             end if;

             v_nro_cta_credito  := pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_solicitante, 'C' );

             v_swi_participante := rg_msj_mov_tra.cod_swi_pte_beneficiario;
             if rg_msj_mov_tra.cod_msj_swift != fug_obt_pardinamico( 'COD_SPI_PCD' ) then--pacs.008
                v_concepto := pas_snp.fu_obt_mov_concepto('M', rg_msj_mov_tra.origen, rg_msj_mov_tra.nro_referencia);
             else
               v_concepto :=rg_msj_mov_tra.nro_ref_externa;
             end if;
             if pas_snp.fu_obt_cod_error <> 0 then
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );

                raise ex_workflow;
             end if;
              else -- MT104
                 /*v_nro_cta_debito   := pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_solicitante, 'C' );

                 v_swi_participante := rg_msj_mov_tra.cod_swi_pte_beneficiario;

                 -- Se limpia la cadena de caracteres invalidos
                 rg_msj_mov_tra.nro_cta_beneficiario := pas_snp.fu_val_cadena( rg_msj_mov_tra.nro_cta_beneficiario );

                 v_nro_cta_credito := rg_msj_mov_tra.nro_cta_solicitante;

                 v_concepto := pas_snp.fu_obt_mov_concepto('M', rg_msj_mov_tra.origen, rg_msj_mov_tra.nro_ref_externa);

                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );

                    raise ex_workflow;
                 end if;*/
                 null;
              end if;
          else --Es un MT RECIBIDO.
             if rg_msj_mov_tra.cod_msj_swift != 104 then
             v_nro_cta_debito   := pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' );

             v_swi_participante := rg_msj_mov_tra.cod_swi_pte_solicitante;

             -- Se limpia la cadena de caracteres inv�lidos
             rg_msj_mov_tra.nro_cta_beneficiario := pas_snp.fu_val_cadena( rg_msj_mov_tra.nro_cta_beneficiario );

             v_nro_cta_credito := rg_msj_mov_tra.nro_cta_beneficiario;
             if rg_msj_mov_tra.cod_msj_swift != fug_obt_pardinamico( 'COD_SPI_PCD' ) and rg_msj_mov_tra.cod_msj_swift != fug_obt_pardinamico('COD_SPI_DEV') then--pacs.008
                v_concepto := pas_snp.fu_obt_mov_concepto('M', rg_msj_mov_tra.origen, rg_msj_mov_tra.nro_ref_externa);
             elsif rg_msj_mov_tra.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV') then
                v_concepto := 'Dev. '||pas_snp.fu_obt_mov_concepto('M', rg_msj_mov_tra.origen, rg_msj_mov_tra.nro_ref_externa);
             else
               v_concepto :=rg_msj_mov_tra.nro_ref_externa;
             end if;


             if pas_snp.fu_obt_cod_error <> 0 then
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );

                raise ex_workflow;
                 end if;
             else -- MT104
                 v_nro_cta_debito   := rg_msj_mov_tra.nro_cta_beneficiario;
                 v_mon_origen       :=rg_msj_mov_tra.cod_moneda;

                 v_nro_cta_credito  := pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' );

                 v_swi_participante := rg_msj_mov_tra.cod_swi_pte_solicitante;

                  v_concepto := 'Orden de d�bito directo: '||rg_msj_mov_tra.ref_oid;

                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );

                    --raise ex_workflow;
                 end if;
             end if;

          end if;

          ------------------------------------------------------------------------------------------------
          /**/-- D A T O S   D E   L A   C U E N T A   D E   D E B I T O
          ------------------------------------------------------------------------------------------------

          if pas_snp.g_cod_error = 0 then
             g_lugar :=  'Verificando los datos de la Cta. ' || v_nro_cta_debito || ' (1), ' ;
             --
             rg_deb := NULL;
             --
             pag_cta.pr_ver_operacion( v_nro_cta_debito,     -- Nro.Cta.
                                       v_tra_padre,          -- Trx. Padre - Transferencia entre cuentas
                                       v_mod_padre,          -- Mod.Padre
                                       v_mad_padre,          -- Mad.Padre
                                       v_tip_mov_debito,     -- Tip.Mov.
                                       v_mon_origen,         -- Cod.Mon.
                                       0,                    -- Monto
                                       rg_deb.cod_oficina,   -- Ofic.Orig.
                                       rg_deb.cod_modulo,    -- Mod.Hijo
                                       rg_deb.cod_modalidad, -- Mad.Hijo
                                       v_est_cuenta,         -- Estado Cta.
                                       v_sal_disponible,     -- Sal.Dispon.
                                       v_procesa             -- Procesa
                                     );

             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;
                if rg_msj_mov_tra.cod_msj_swift != 104 then
                raise ex_workflow;
                end if;
             end if;

             if not ( rg_deb.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39, 334 ) ) then
                pas_snp.g_cod_error := 39;
                pas_snp.g_msj_error := 'Modalidad de la cuenta no permite esta operaci�n';

                raise ex_workflow;
             end if;

             if pas_snp.fu_val_es_enviado ( rg_msj_mov_tra ) then
                if rg_msj_mov_tra.cod_servicio is not null and
                  rg_msj_mov_tra.cod_msj_swift != 104
                then
                   v_tra_debito := nvl( fug_obt_val_par_ente( 'SNP_COD_TRA_DEBITO',
                                                              'SNP_COD_SERVICIO',
                                                              rg_msj_mov_tra.cod_servicio
                                                            ), 4030
                                      );
                else
                   if rg_msj_mov_tra.cod_msj_swift = 104 then-- MT104

                       -- El debito se realiza a la INTERBANCARIA,
                      pas_snp.pr_obt_par_mensajes( rg_msj_mov_tra.cod_msj_swift,
                                                   rg_msj_mov_tra.cod_tip_operacion,
                                                   rg_msj_mov_tra.cod_sub_tip_operacion,
                                                   'E',
                                                   v_mod_padre,
                                                   v_mad_padre,
                                                   v_tra_debito
                                                 );
                      if pag_cta.fu_obt_cod_error <> 0 then
                         raise ex_workflow;
                      end if;
				   end if;
				   -- pago a proveedores
				   if rg_msj_mov_tra.ref_oid ='PPV' then
                     --v_tra_debito := 7503;
                     v_tra_debito := 7504;--TCE-309
                   else
                     -- El debito se realiza al CLIENTE,
                      v_tra_debito := 503;
                   end if;
                end if;
             else
                if rg_msj_mov_tra.cod_msj_swift = 104 then
                   v_tra_debito := 9503;
                else

                -- Dependiendo del C�digo SWIFT, Tip_Operacion, Sub_Tip_Operacion,
                -- se retornar� la transacci�n a ser utilizada para la generaci�n del movimiento.
                pas_snp.pr_obt_par_mensajes( rg_msj_mov_tra.cod_msj_swift,
                                             rg_msj_mov_tra.cod_tip_operacion,
                                             rg_msj_mov_tra.cod_sub_tip_operacion,
                                             'R',
                                             v_mod_padre,
                                             v_mad_padre,
                                             v_tra_debito
                                           );
                if pas_snp.fu_obt_cod_error <> 0 then
                   raise ex_workflow;
                   end if;
                end if;
             end if;

             --Recuperaci�n de los datos de la cuenta de CREDITO cargados en PAG_CTA.G_CTAS
             rg_deb := pag_cta.g_ctas;
             --

          end if;

          ------------------------------------------------------------------------------------------------
          /**/-- D A T O S   D E   L A   C U E N T A   D E   C R E D I T O
          ------------------------------------------------------------------------------------------------

          if pas_snp.g_cod_error = 0 then
             g_lugar :=  'Verificando los datos de la Cta. ' || v_nro_cta_credito || ' (2), ' ;
             --
             rg_cre := NULL;
             --
             pag_cta.pr_ver_operacion( v_nro_cta_credito,   -- Nro.Cta.
                                       v_tra_padre,         -- Trx. Padre - Transferencia entre cuentas
                                       v_mod_padre,         -- Mod.Padre
                                       v_mad_padre,         -- Mad.Padre
                                       v_tip_mov_credito,   -- Tip.Mov.
                                       rg_cre.cod_moneda,   -- Cod.Mon.
                                       0,                   -- Monto
                                       rg_cre.cod_oficina,  -- Ofic.Orig.
                                       rg_cre.cod_modulo,   -- Mod.Hijo
                                       rg_cre.cod_modalidad,-- Mad.Hijo
                                       v_est_cuenta,        -- Estado Cta.
                                       v_sal_disponible,    -- Sal.Dispon.
                                       v_procesa            -- Procesa
                                     );

             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                raise ex_workflow;

             end if;

             if not ( ( rg_cre.cod_modulo in ( 3, 4 ) and rg_cre.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39,334 ) ) or
                        rg_cre.cod_modulo = 5 ) --Para MT recibido la Cuenta de Cr�dito puede ser la de Tarjetas
             then
                pas_snp.g_cod_error := 39;
                pas_snp.g_msj_error := 'Modalidad de la cuenta no permite este tipo de operaci�n';

                raise ex_workflow;
             end if;

             if pas_snp.fu_val_es_enviado ( rg_msj_mov_tra ) then
                if rg_msj_mov_tra.cod_msj_swift = 104 then--MT104
                   v_tra_credito := 9602;
				end if;
				-- pago a proveedores
				if rg_msj_mov_tra.ref_oid ='PPV' then
					v_tra_credito := 7196;
                else
                -- Dependiendo del C�digo SWIFT, Tip_Operacion, Sub_Tip_Operacion,
                -- se retornar� la transacci�n a ser utilizada para la generaci�n del movimiento.
                pas_snp.pr_obt_par_mensajes( rg_msj_mov_tra.cod_msj_swift,
                                             rg_msj_mov_tra.cod_tip_operacion,
                                             rg_msj_mov_tra.cod_sub_tip_operacion,
                                             'E',
                                             v_mod_padre,
                                             v_mad_padre,
                                             v_tra_credito
                                           );

                if pas_snp.fu_obt_cod_error <> 0 then
                   raise ex_workflow;
                   end if;
                end if;

             else
                if rg_msj_mov_tra.cod_msj_swift = 104 then--MT104
                   pas_snp.pr_obt_par_mensajes( rg_msj_mov_tra.cod_msj_swift,
                                                rg_msj_mov_tra.cod_tip_operacion,
                                                rg_msj_mov_tra.cod_sub_tip_operacion,
                                                'R',
                                                v_mod_padre,
                                                v_mad_padre,
                                                v_tra_credito
                                              );

                   if pag_cta.fu_obt_cod_error <> 0 then
                      raise ex_workflow;
                   end if;
                else
                if rg_cre.cod_modulo = 5 then
                   v_tra_credito := 978;
                else
                   v_tra_credito := 602;
                 end if;
                end if;
             end if;

             --Recuperaci�n de los datos de la cuenta de CREDITO cargados en PAG_CTA.G_CTAS
             rg_cre := pag_cta.g_ctas;
             --

          end if;

          if pas_snp.fu_obt_cod_error = 0 then
             g_lugar :=  'Intentando Registrar la Operaci�n para la Cta. (D). ' || v_nro_cta_debito || ', ' ;
             if rg_deb.cod_moneda <> rg_cre.cod_moneda then
                /* PARA MTs ENVIADOS (No implementado en PAS_SNP)
                || Si la Moneda ORIGEN es M.E. y la Moneda DESTINO es LOCAL entonces
                ||   Es una Compra (16). Al cargar Contrato de Cambio a trav�s de LMOPEPEN
                ||   Cuenta de D�bito es del Cliente M.E. y
                ||   la Cuenta de Cr�dito es la Interbancaria en GS.
                || Sino
                ||   Es una Venta (30). Al cargar Contrato de Cambio a trav�s de LMOPEPEN
                ||   Cuenta de D�bito es del Cliente en GS. y
                ||   la Cuenta de Cr�dito es la Interbancaria en M.E.
                || Fin Si
                */
                /* PARA MTs RECIBIDOS (Implementado s�lo en el PAS_SNP
                || Si la Moneda ORIGEN es M.E. y la Moneda DESTINO es LOCAL entonces
                ||   Es una Compra (16). Al cargar Contrato de Cambio a trav�s de LMOPEPEN
                ||   Cuenta de D�bito es la Interbancaria M.E. y
                ||   la Cuenta de Cr�dito es el Cliente en GS.
                || Sino
                ||   Es una Venta (30). Al cargar Contrato de Cambio a trav�s de LMOPEPEN
                ||   Cuenta de D�bito es la Interbancaria en GS. y
                ||   la Cuenta de Cr�dito es el Cliente en M.E.
                || Fin Si
                */
                pas_snp.pr_obt_con_cambio( v_nro_con_cambio,
                                           'S',
                                           rg_deb.nro_cuenta,    -- Cta. de D�bito
                                           rg_cre.nro_cuenta,    -- Cta. de Cr�dito
                                           rg_msj_mov_tra.monto, -- Monto de la Operaci�n.
                                           rg_deb.cod_moneda,
                                           rg_cre.cod_moneda,
                                           v_cot_destino,
                                           v_mto_debito,
                                           v_mto_credito
                                         );
                --
                if pas_snp.fu_obt_cod_error <> 0 then
                   raise ex_workflow;
                end if;
                --
                -- Para conversi�n de monedas. Detectar si el MT es RECIBIDO o ENVIADO.
                if pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) then
                   --Es un MT ENVIADO.
                   v_mon_origen  := rg_cre.cod_moneda;
                   v_mon_destino := rg_deb.cod_moneda;
                else --Es un MT RECIBIDO.
                   v_mon_origen  := rg_deb.cod_moneda;
                   v_mon_destino := rg_cre.cod_moneda;
                end if;
                if v_mto_credito is null then
                   pas_snp.pr_con_mon_a_moneda( v_mon_origen,
                                                v_mon_destino,
                                                nvl( rg_msj_mov_tra.monto, 0 ),
                                                v_mto_destino,
                                                v_cot_origen,
                                                v_cot_destino
                                              );
                end if;
                --
                if pas_snp.fu_obt_cod_error <> 0 then
                   raise ex_workflow;
                end if;
                --
                if pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) then
                   --Es un MT ENVIADO.
                   v_mto_debito  := v_mto_destino;
                   v_mto_credito := nvl( rg_msj_mov_tra.monto, 0 );
                else --Es un MT RECIBIDO.
                   v_mto_debito  := nvl( rg_msj_mov_tra.monto, 0 );
                   v_mto_credito := nvl(v_mto_destino, v_mto_credito);
                end if;
             else
                v_cotizacion  := null;
                v_mto_debito  := nvl( rg_msj_mov_tra.monto, 0 );
                v_mto_credito := nvl( rg_msj_mov_tra.monto, 0 );
             end if;

             if rg_deb.cod_moneda <> g_cod_mon_local then
                if rg_cre.cod_moneda = g_cod_mon_local then
                   v_mto_equ_local := v_mto_credito;
                else
                   v_mto_equ_local := null ;
                end if ;

                if nvl( v_cot_origen,1 ) = 1 then
                   v_cotizacion := v_cot_destino;
                else
                   v_cotizacion := v_cot_origen;
                end if;
             end if;

             -- Si la cuenta es de la modalidad 455, setear valores del campo referencia cod_rubro y tip_mov_rubro
             pag_cta.pr_set_referencia ( NULL );

             -- Para los movimientos de Transferencias se debe colocar en el campo NRO_DOCUMENTO2
             -- El Tipo de Mensajer�a, Tipo de Operaci�n y Sub Tipo de Operaci�n
             -- Esta asignaci�n sirve para recuperar la mensajer�a desde la consulta de movimientos
             v_nro_documento2 := rg_msj_mov_tra.cod_msj_swift ||
                                 rg_msj_mov_tra.cod_tip_operacion ||
                                 rg_msj_mov_tra.cod_sub_tip_operacion;
             pag_cta.pr_set_nro_documento2 ( v_nro_documento2 );

             -- Recupera el tipo de movimiento de la transacci�n
             v_tip_mov_debito := pas_snp.fu_obt_tip_mov_transaccion( rg_deb.cod_modulo,
                                                                     rg_deb.cod_modalidad,
                                                                     v_tra_debito
                                                                   );

             if pas_snp.fu_obt_cod_error <> 0 then
                raise ex_workflow;
             end if;
             --

             if rg_deb.cod_modalidad = pas_snp.fu_obt_cod_mad_padre then
                --Setea las variables de COD_RUBRO, TIP_MOV_RUBRO
                pag_cta.pr_set_cod_rubro( pac_che.fu_obt_rub_cta_ban( rg_deb.nro_cuenta ), v_tip_mov_debito );

                --Setea el campo REFERENCIA del movimiento
                pag_cta.pr_set_referencia ( v_swi_participante );
             end if;
             --
             -- Para evitar que exista el movimiento de d�bito al encontrar el error de Cuenta Bloqueada para el cr�dito,
             -- se llavea la cuenta de cr�dito antes de realizar el movimiento para la cuenta del d�bito
             /*if rg_cre.cod_modulo in ( 3, 4 ) then  -- DA-4875 -- NGRANCE --
                if pag_cta.fu_llavear_cuenta(rg_cre.cod_modalidad, rg_cre.nro_cuenta) = 'N' then
                   pas_snp.g_cod_error := 39;
                   pas_snp.g_msj_error := 'No se pudo Bloquear la Cuenta '||rg_cre.nro_cuenta;

                   raise ex_workflow;
                end if;
             end if;*/  -- DA-4875 -- NGRANCE --
             --
             --v_hora := fug_ini_hora;
               v_hora := fug_obt_mov_hora;

             --
             if pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) or  rg_msj_mov_tra.cod_msj_swift=104  then  -- DA-4875 -- NGRANCE --
         --ENVIADO
             pag_cta.pr_act_operacion( rg_deb.nro_cuenta,              -- Nro.Cta.
                                       v_hora,                         -- Hora
                                       v_tip_mov_debito,               -- Tip.Mov.
                                       rg_deb.cod_moneda,              -- Cod.Mon.
                                       v_mto_debito,                   -- Monto
                                       v_tra_padre,                    -- Trx.Padre
                                       v_tra_debito,                   -- Trx.Hija
                                       rg_msj_mov_tra.nro_referencia,  -- Nro.Doc.
                                       v_cotizacion,                   -- Cotizacion
                                       fug_obt_ofi_usuario (user),     -- Ofic.Orig.
                                       v_mod_padre,                    -- Mod.Pad.Cliente
                                       v_mad_padre,                    -- Mad.Pad.Cliente
                                       NULL,                           -- Cod.Tasa
                                       NULL,                           -- Val.Tasa
                                       v_concepto,                     -- Concepto
                                       'S',                            -- Emit.Aviso
                                       v_nro_secuencia,
                                       rg_msj_mov_tra.fec_valor,
                                       NULL,
                                       NULL,
                                       v_mto_equ_local
                                     );

             else
			    prs_snp_obt_usu_hor_movimiento(user,'N',v_cod_usuario,v_hora);
         -- RECIBIDO
         --Generar el movimiento
          rg_movi.cod_usuario     := v_cod_usuario;
          rg_movi.hora            := v_hora;
          rg_movi.fecha           := pag_cal.fu_obt_fec_actual( rg_cre.cod_modulo );
          -- Aumento la secuencia
          v_nro_secuencia         := v_nro_secuencia + 1;
          rg_movi.nro_secuencia   := v_nro_secuencia;
          rg_movi.cod_tra_padre   := v_tra_padre;
          rg_movi.cod_mod_padre   := v_mod_padre;
          rg_movi.cod_mad_padre   := v_mad_padre;
          rg_movi.cod_transaccion := v_tra_debito;
          rg_movi.cod_modulo      := rg_deb.cod_modulo;
          rg_movi.cod_modalidad   := rg_deb.cod_modalidad;
          rg_movi.cod_oficina     := rg_deb.cod_oficina;
          rg_movi.cod_moneda      := rg_deb.cod_moneda;
          rg_movi.fec_valor       := rg_msj_mov_tra.fec_valor;
          rg_movi.monto           := v_mto_debito;
          rg_movi.nro_documento   := rg_msj_mov_tra.nro_referencia;
          rg_movi.nro_documento2  := v_nro_documento2;
          rg_movi.nro_cuenta      := v_nro_cta_debito;
          rg_movi.cod_ofi_origen  := fug_obt_ofi_usuario (v_cod_usuario);
          rg_movi.concepto        := v_concepto;
          rg_movi.emi_aviso       := 'N';
          rg_movi.estado          := 'N';
          rg_movi.reversado       := 'N';
          rg_movi.cotizacion      := v_cotizacion;
          rg_movi.mto_equ_local   := v_mto_equ_local;
          --
          pag_gen.pr_ins_ge_movimiento( rg_movi );
          --Limpio variables cargadas para que no quede basura
          pag_cta.pr_set_cod_rubro(null, null);
             end if;  -- DA-4875 -- NGRANCE --
             g_lugar :=  'Verificando movimientos registrados para la Cta. (D). ' || v_nro_cta_debito || ', ' ;
             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                raise ex_workflow;
             end if;

          end if;

          if pas_snp.fu_obt_cod_error = 0 then
             g_lugar :=  'Intentando Registrar la Operaci�n para la Cta. (C). ' || v_nro_cta_credito || ', ' ;

             if rg_cre.cod_moneda <> g_cod_mon_local then
                if rg_deb.cod_moneda = g_cod_mon_local then
                   v_mto_equ_local := v_mto_debito;
                else
                   v_mto_equ_local := null ;
                end if ;
                if nvl( v_cot_origen,1 ) = 1 then
                   v_cotizacion := v_cot_destino;
                else
                   v_cotizacion := v_cot_origen;
                end if;
             end if;

             -- Si la cuenta es de la modalidad 455, setear valores del campo referencia cod_rubro y tip_mov_rubro
             pag_cta.pr_set_referencia ( NULL );

             -- Recupera el tipo de movimiento de la transacci�n
             v_tip_mov_credito := pas_snp.fu_obt_tip_mov_transaccion( rg_cre.cod_modulo,
                                                                      rg_cre.cod_modalidad,
                                                                      v_tra_credito
                                                                    );

             if pas_snp.fu_obt_cod_error <> 0 then
                raise ex_workflow;
             end if;
             --

             if rg_cre.cod_modalidad = pas_snp.fu_obt_cod_mad_padre then
                --Setea las variables de COD_RUBRO, TIP_MOV_RUBRO
                pag_cta.pr_set_cod_rubro( pac_che.fu_obt_rub_cta_ban( rg_cre.nro_cuenta ), v_tip_mov_credito );

                --Setea el campo REFERENCIA del movimiento
                pag_cta.pr_set_referencia ( v_swi_participante );
             end if;
             --
             if rg_cre.cod_modulo in ( 3, 4 ) and
                rg_cre.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39,334 )
             then --Para la modalidad 31,41,43,455 el movimiento debe hacerse por el PAG_CTA.PR_ACT_OPERACION
                if pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) or  rg_msj_mov_tra.cod_msj_swift =104 then -- DA-4875 -- NGRANCE --
          --ENVIADO
          --Generar el movimiento
          rg_movi.cod_usuario     := user;
          rg_movi.hora            := v_hora;
          rg_movi.fecha           := pag_cal.fu_obt_fec_actual( rg_cre.cod_modulo );
          -- Aumento la secuencia
          v_nro_secuencia         := v_nro_secuencia + 1;
          rg_movi.nro_secuencia   := v_nro_secuencia;
          rg_movi.cod_tra_padre   := v_tra_padre;
          rg_movi.cod_mod_padre   := v_mod_padre;
          rg_movi.cod_mad_padre   := v_mad_padre;
          rg_movi.cod_transaccion := v_tra_credito;
          rg_movi.cod_modulo      := rg_cre.cod_modulo;
          rg_movi.cod_modalidad   := rg_cre.cod_modalidad;
          rg_movi.cod_oficina     := rg_cre.cod_oficina;
          rg_movi.cod_moneda      := rg_cre.cod_moneda;
          rg_movi.fec_valor       := rg_msj_mov_tra.fec_valor;
          rg_movi.monto           := v_mto_credito;
          rg_movi.nro_documento   := rg_msj_mov_tra.nro_referencia;
          rg_movi.nro_documento2  := v_nro_documento2;
          rg_movi.nro_cuenta      := v_nro_cta_credito;
          rg_movi.cod_ofi_origen  := fug_obt_ofi_usuario (user);
          rg_movi.concepto        := v_concepto;
          rg_movi.emi_aviso       := 'N';
          rg_movi.estado          := 'N';
          rg_movi.reversado       := 'N';
          rg_movi.cotizacion      := v_cotizacion;
          rg_movi.mto_equ_local   := v_mto_equ_local;
          if rg_msj_mov_tra.cod_msj_swift =104 then
            rg_movi.referencia        := v_swi_participante;
          end if;
          --
          pag_gen.pr_ins_ge_movimiento( rg_movi );
          --Limpio variables cargadas para que no quede basura
          pag_cta.pr_set_cod_rubro(null, null);
               else
          --RECIBIDO
		   pag_cta.pr_set_variables(v_cod_usuario,null,null,'N','N',
                                         v_secuencia,null,null,null,null);
                pag_cta.pr_act_operacion( rg_cre.nro_cuenta,             -- Nro.Cta.
                                          v_hora,                        -- Hora
                                          v_tip_mov_credito,             -- Tip.Mov.
                                          rg_cre.cod_moneda,             -- Cod.Mon.
                                          v_mto_credito,                 -- Monto
                                          v_tra_padre,                   -- Trx.Padre
                                          v_tra_credito,                 -- Trx.Hija
                                          rg_msj_mov_tra.nro_referencia, -- Nro.Doc.
                                          v_cotizacion,                  -- Cotizacion
                                          fug_obt_ofi_usuario (v_cod_usuario),    -- Ofic.Orig.
                                          v_mod_padre,                   -- Mod.Padre
                                          v_mad_padre,                   -- Mad.Padre
                                          NULL,                          -- Cod.Tasa
                                          NULL,                          -- Val.Tasa
                                          v_concepto,                    -- Concepto
                                          'S',                           -- Emit.Aviso
                                          v_nro_secuencia,
                                          rg_msj_mov_tra.fec_valor,
                                          NULL,
                                          NULL,
                                          v_mto_equ_local
                                        );
					pag_cta.pr_set_variables(null,null,null,'N','N',
                                            v_secuencia,null,null,null,null);
                end if; -- DA-4875 -- NGRANCE --
                g_lugar :=  'Verificando movimientos registrados para la Cta. (C). ' || v_nro_cta_credito || ', ' ;
                if pag_cta.fu_obt_cod_error <> 0 then
                   --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                   pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                   pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                   raise ex_workflow;
                end if;

                -- Si no hubo errores cargar datos del movimiento para luego actualizarlos en GE_SNP_TRANSFERENCIAS.
                rg_msj_mov_tra.fecha         := pag_cal.fu_obt_fec_actual ( rg_cre.cod_modulo );
                rg_msj_mov_tra.hora          := v_hora;
                rg_msj_mov_tra.cod_usuario   := nvl(v_cod_usuario,user);
                rg_msj_mov_tra.nro_operacion := rg_msj_mov_tra.nro_referencia;

                v_nro_documento2 := NULL;
                pag_cta.pr_set_nro_documento2 ( v_nro_documento2 );

                -- Si no tiene ERRORES se procede al COBRO DE CARGOS cuando la mensajer�a es RECIBIDA.
                g_lugar :=  'Intentando Registrar Movimiento por Cobro de Cargos para la Cta. ' || v_nro_cta_credito || ', ' ;
                begin
                   /*
                   SPI-2: Cobro de cargo por un pain013 enviado
                   */
                   begin
                        select sl.cod_msj_swift
                        into v_sol_swift
                        from ge_spi_solicitudes sl
                        where sl.nro_referencia=rg_msj_mov_tra.nro_referencia
                        and sl.fec_recepcion is null; --enviado
                   exception
                        when others then
                            v_sol_swift:=0;
                   end;
                   --es una pacs008 en respuesta a un pain013 enviado
                    if v_sol_swift=fug_obt_pardinamico('COD_SPI_SOL_PAGO') then

                       if fue_obt_des_refcodes('SPI_CAR_013_ENV','HABILITADO')='S'
                         and v_mto_credito>=to_number(fue_obt_des_refcodes('SPI_CAR_013_ENV','MTO_MIN_'||rg_cre.cod_moneda)) then
                          v_ind_cob_cargos:= 'S';
                          g_car_013       := 'S';
                       else
                          v_ind_cob_cargos:= 'N';
                          g_car_013       := 'N';
                       end if;
                    end if;
                   --
                   if v_ind_cob_cargos = 'S' then
                      pas_snp.pr_gen_mov_cargo( rg_msj_mov_tra,
                                                case when not pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) then rg_cre else rg_deb end,  -- Cta. Cliente.
                                                case when not pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) then rg_deb else rg_cre end,  -- Cta. Interbancaria.
                                                v_mto_credito,                                                                          -- Monto sobre el cual se calcular�n los cargos (Monto Cliente).
                                                v_hora,                                                                                 -- Hora para el Movimiento de Cobro de Cargos.
                                                v_nro_secuencia                                                                         -- Nro. de Secuencia para el Movimiento de Cargos.
                                              );
                      if pas_snp.fu_obt_cod_error <> 0 then
                         raise ex_salir;
                      end if;
                   end if;

                   if not pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) and
                      rg_msj_mov_tra.indemnizado = 'S'
                   then
                      /**/-- Registro de Movimientos para Indemnizar al Cliente si se excede finalizaci�n en el WF
                      g_lugar := 'Intentando registrar Movimientos para Indemnizaci�n al Cliente, ';
                      pas_snp.pr_gen_mov_indemnizacion( rg_cre,          -- Datos de la cta. del cliente
                                                        rg_msj_mov_tra,  -- Datos de la Transferencia
                                                        v_mto_credito,   -- Monto de la Transferencia
                                                        v_hora,          -- Hora
                                                        v_nro_secuencia  -- Nro. Secuencia
                                                      );
                      --
                   end if;

                   if pas_snp.fu_obt_cod_error <> 0 then
                      raise ex_salir;
                   end if;
                exception
                  when ex_salir then
                    null; -- Solo se env�a Mail, no levantar circuito por que ya est�n registrados los movimientos de SNP.
                          -- Notificar simplemente el error encontrado para solucionarlo de forma MANUAL.
                end;

             elsif rg_cre.cod_modulo = 5 then --Movimiento por Cobro de Tarjetas
                g_lugar :=  'Intentando Registrar Pago Tarjetas para la Cta. (C). ' || v_nro_cta_credito || ', ' ;
                --Generar el movimiento por el Cobro de Tarjetas
                rg_movi.cod_usuario     := v_cod_usuario;
                rg_movi.hora            := v_hora;
                rg_movi.fecha           := pag_cal.fu_obt_fec_actual ( rg_cre.cod_modulo );
                -- Aumento la secuencia
                v_nro_secuencia         := v_nro_secuencia + 1;
                rg_movi.nro_secuencia   := v_nro_secuencia;
                rg_movi.cod_tra_padre   := v_tra_padre;
                rg_movi.cod_mod_padre   := v_mod_padre;
                rg_movi.cod_mad_padre   := v_mad_padre;
                rg_movi.cod_transaccion := v_tra_credito;
                rg_movi.cod_modulo      := rg_cre.cod_modulo;
                rg_movi.cod_modalidad   := rg_cre.cod_modalidad;
                rg_movi.cod_oficina     := rg_cre.cod_oficina;
                rg_movi.cod_moneda      := rg_cre.cod_moneda;
                rg_movi.fec_valor       := rg_msj_mov_tra.fec_valor;
                rg_movi.monto           := v_mto_credito;
                rg_movi.nro_documento   := rg_msj_mov_tra.nro_referencia;
                rg_movi.nro_documento2  := v_nro_documento2;
                rg_movi.nro_cuenta      := rg_cre.nro_cuenta;
                rg_movi.cod_ofi_origen  := fug_obt_ofi_usuario (v_cod_usuario);
                rg_movi.concepto        := v_concepto;
                rg_movi.emi_aviso       := 'N';
                rg_movi.estado          := 'N';
                rg_movi.reversado       := 'N';
                --
                pag_gen.pr_ins_ge_movimiento( rg_movi );
                --

                g_lugar :=  'Intentando Obtener Nro.Tarjeta de la Cuenta Principal ' || v_nro_cta_credito || ', ' ;

                v_nro_tarjeta := fut_obt_nro_tarjeta(rg_msj_mov_tra.nro_cta_beneficiario);
                if v_nro_tarjeta is null then

                   pas_snp.g_cod_error := 99;
                   pas_snp.g_msj_error := 'No se encuentra Nro. Tarjeta para la Cuenta Principal ' || v_nro_cta_credito;

                   raise ex_workflow;
                end if;

                insert into ta_cobros( nro_cuenta,
                                       nro_tarjeta,
                                       fec_proceso,
                                       monto,
                                       estado,
                                       fec_valor,
                                       observacion,
                                       hora,
                                       cod_usuario
                                     )
                               values
                                     ( rg_movi.nro_cuenta,
                                       v_nro_tarjeta,
                                       g_fec_actual,
                                       v_mto_credito,
                                       'P',
                                       g_fec_actual,
                                       'Pago de Tarjeta - SNP',
                                       v_hora,
                                       rg_movi.cod_usuario
                                     );

                -- Si no hubo errores cargar datos del movimiento para luego actualizarlos en GE_SNP_TRANSFERENCIAS.
                rg_msj_mov_tra.fecha         := pag_cal.fu_obt_fec_actual ( rg_cre.cod_modulo );
                rg_msj_mov_tra.hora          := v_hora;
                rg_msj_mov_tra.cod_usuario   := nvl(v_cod_usuario,user);
                rg_msj_mov_tra.nro_operacion := rg_msj_mov_tra.nro_referencia;

                v_nro_documento2 := NULL;
                pag_cta.pr_set_nro_documento2 ( v_nro_documento2 );

             end if;
          end if;
       end if;

   EXCEPTION
     when ex_salir then
        raise ex_workflow;
     when ex_workflow then
        raise ex_workflow;
     when others then
        pas_snp.g_cod_error := 39;
        pas_snp.g_msj_error := 'Error en LP_REG_MOV_TRANSFERENCIA: ' || g_lugar || ' - ' || sqlerrm;
        raise ex_workflow;
   END lp_reg_mov_transferencia;

  --Registra el movimiento de Cr�dito/D�bitos Varios.
   PROCEDURE lp_reg_mov_credito
   IS
     v_ind_transaccion varchar2(1) := 'R';
   BEGIN
       if pas_snp.fu_obt_cod_error = 0 and rg_msj_mov_tra.monto <> 0 then
          -- Para acreditar/debitar alguna operaci�n a nuestra entidad se debe verificar la Cuenta
          -- la cual se encuentra o en el Campo del Solicitante ( Transferencia Interbancaria Emitida/D�bito Directo/Retiro en Efectivo )
          -- o en el Campo del Beneficiario ( Transferencia Interbancaria Recibida/Cr�dito Directo/Dep�sito en Efectivo )

          --SPI--
        if rg_msj_mov_tra.nro_cta_pte_solicitante = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
          if pas_spi.fu_obt_cta_lbtr_reserva( rg_msj_mov_tra.nro_cta_pte_solicitante, 'C' ) is not null then
             v_nro_cta_entidad  := pas_spi.fu_obt_cta_lbtr_reserva( rg_msj_mov_tra.nro_cta_pte_solicitante, 'C' );
             v_ind_transaccion  := 'E';
             v_swi_participante := rg_msj_mov_tra.cod_swi_pte_beneficiario;
          elsif  pas_spi.fu_obt_cta_lbtr_reserva ( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' ) is not null then
             v_nro_cta_entidad  := pas_spi.fu_obt_cta_lbtr_reserva( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' );
             v_ind_transaccion  := 'R';
             v_swi_participante := rg_msj_mov_tra.cod_swi_pte_solicitante;
          end if;
        elsif pas_spi.fu_obt_cta_lbtr_reserva( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' ) is not null then
             v_nro_cta_entidad  :=  pas_spi.fu_obt_cta_lbtr_reserva( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' );
             v_ind_transaccion  := 'R';
             v_swi_participante := rg_msj_mov_tra.cod_swi_pte_solicitante;
        else
            if pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_solicitante, 'C' ) is not null then
             v_nro_cta_entidad  := pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_solicitante, 'C' );
             v_ind_transaccion  := 'E';
             v_swi_participante := rg_msj_mov_tra.cod_swi_pte_beneficiario;
          elsif pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' ) is not null then
             v_nro_cta_entidad  := pas_snp.fu_obt_cta_bancaria( rg_msj_mov_tra.nro_cta_pte_beneficiario, 'C' );
             v_ind_transaccion  := 'R';
             v_swi_participante := rg_msj_mov_tra.cod_swi_pte_solicitante;
          end if;
        end if;
          -- Borrar los errores que pudieron haberse generado durante la validaci�n.
          pas_snp.pr_ini_variables;

          -- Detecta si el MT es RECIBIDO.
          if not pas_snp.fu_val_es_enviado ( rg_msj_mov_tra ) then
             v_concepto := pas_snp.fu_obt_mov_concepto('M', rg_msj_mov_tra.origen, rg_msj_mov_tra.nro_ref_externa);
          end if;

          -- Dependiendo del C�digo SWIFT, Tip_Operacion, Sub_Tip_Operacion,
          -- se retornar� la transacci�n a ser utilizada para la generaci�n del movimiento.
          pas_snp.pr_obt_par_mensajes( rg_msj_mov_tra.cod_msj_swift,
                                       rg_msj_mov_tra.cod_tip_operacion,
                                       rg_msj_mov_tra.cod_sub_tip_operacion,
                                       v_ind_transaccion,
                                       v_mod_padre,
                                       v_mad_padre,
                                       v_tra_entidad
                                     );

          if pas_snp.fu_obt_cod_error <> 0 then
             raise ex_workflow;
          end if;

          -- Si no existe transacci�n definida en GE_SNP_TRANSFERENCIAS, tomar la transacci�n de GE_SNP_PAR_MENSAJES
          v_tra_entidad := nvl( rg_msj_mov_tra.cod_usu_transaccion, v_tra_entidad );

          g_lugar :=  'Obteniendo los datos de la Cta. Pte.' || v_nro_cta_entidad || ', ' ;
          -- Recupera los datos de la Cta. del Participante
          pag_cta.pr_obt_cuenta( v_nro_cta_entidad );

          /*
          || Si existe alg�n error se env�a la mensajer�a al WORKFLOW, sino
          || se relaciona el movimiento a la mensajer�a.
          */
          g_lugar :=  'Verificando los datos de la Cta. Pte.' || v_nro_cta_entidad || ', ' ;
          if pag_cta.fu_obt_cod_error <> 0 then
             --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
             pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
             pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

             raise ex_workflow;
          end if;

          if not ( pag_cta.g_ctas.cod_modalidad = pas_snp.fu_obt_cod_mad_padre ) then
             pas_snp.g_cod_error := 39;
             pas_snp.g_msj_error := 'Modalidad de la cuenta no permite esta operaci�n';

             raise ex_workflow;
          end if;

          --Recuperaci�n de los datos de la cuenta de la ENTIDAD cargados en PAG_CTA.G_CTAS
          rg_pte := pag_cta.g_ctas;

          if pag_cta.fu_obt_cod_error = 0 then

             g_lugar :=  'Intentando Registrar la Operaci�n para la la Cta. Pte.' || rg_pte.nro_cuenta || ', ' ;

             -- Si la cuenta es de la modalidad 455, setear valores del campo referencia cod_rubro y tip_mov_rubro
             pag_cta.pr_set_referencia ( NULL );

             -- Para los movimientos de Transferencias se debe colocar en el campo NRO_DOCUMENTO2
             -- El Tipo de Mensajer�a, Tipo de Operaci�n y Sub Tipo de Operaci�n
             -- Esta asignaci�n sirve para recuperar la mensajer�a desde la consulta de movimientos
             v_nro_documento2 := rg_msj_mov_tra.cod_msj_swift ||
                                 rg_msj_mov_tra.cod_tip_operacion ||
                                 rg_msj_mov_tra.cod_sub_tip_operacion;
             pag_cta.pr_set_nro_documento2 ( v_nro_documento2 );

             -- Recupera el tipo de movimiento de la transacci�n
             v_tip_mov_entidad := pas_snp.fu_obt_tip_mov_transaccion( rg_pte.cod_modulo,
                                                                      rg_pte.cod_modalidad,
                                                                      v_tra_entidad
                                                                    );

             if pas_snp.fu_obt_cod_error <> 0 then
                raise ex_workflow;
             end if;
             --

             if rg_pte.cod_modalidad = pas_snp.fu_obt_cod_mad_padre then
                --Setea las variables de COD_RUBRO, TIP_MOV_RUBRO
                pag_cta.pr_set_cod_rubro( pac_che.fu_obt_rub_cta_ban( rg_pte.nro_cuenta ), v_tip_mov_entidad );

                --Setea el campo REFERENCIA del movimiento
                pag_cta.pr_set_referencia ( v_swi_participante );
             end if;
             --

             -- Cuando el MT202 es del tipo Dep�sito/Extracci�n de Efectivo, se toma el concepto de la Transferencia
             if rg_msj_mov_tra.cod_tip_operacion in ('002','003') and
                rg_msj_mov_tra.cod_sub_tip_operacion in ('001','002')
             then
                v_concepto := nvl(rg_msj_mov_tra.concepto, v_concepto);
             end if;

             --
            -- v_hora := fug_ini_hora;
             v_hora:=  fug_obt_mov_hora;

             --
             pag_cta.pr_act_operacion( rg_pte.nro_cuenta,              -- Nro.Cta.
                                       v_hora,                         -- Hora
                                       v_tip_mov_entidad,              -- Tip.Mov.
                                       rg_pte.cod_moneda,              -- Cod.Mon.
                                       rg_msj_mov_tra.monto,           -- Monto
                                       pas_snp.fu_obt_cod_tra_padre,   -- Trx.Padre
                                       v_tra_entidad,                  -- Trx.Hija
                                       rg_msj_mov_tra.nro_referencia,  -- Nro.Doc.
                                       NULL,                           -- Cotizacion
                                       fug_obt_ofi_usuario (user),     -- Ofic.Orig.
                                       rg_pte.cod_modulo,              -- Mod.Padre
                                       rg_pte.cod_modalidad,           -- Mad.Padre
                                       NULL,                           -- Cod.Tasa
                                       NULL,                           -- Val.Tasa
                                       v_concepto,                     -- Concepto
                                       'S',                            -- Emit.Aviso
                                       v_nro_secuencia,
                                       rg_msj_mov_tra.fec_valor
                                     );

             g_lugar :=  'Verificando movimientos registrados para la Cta. Pte.' || v_nro_cta_entidad || ', ' ;
             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                raise ex_workflow;
             end if;

             -- Si no hubo errores cargar datos del movimiento para luego actualizarlos en GE_SNP_TRANSFERENCIAS.
             rg_msj_mov_tra.fecha         := pag_cal.fu_obt_fec_actual ( rg_pte.cod_modulo );
             rg_msj_mov_tra.hora          := v_hora;
             rg_msj_mov_tra.cod_usuario   := user;
             rg_msj_mov_tra.nro_operacion := rg_msj_mov_tra.nro_referencia;

             v_nro_documento2 := NULL;
             pag_cta.pr_set_nro_documento2 ( v_nro_documento2 );
          end if;

          if pas_snp.fu_obt_cod_error = 0 then
             -- Si la operaci�n es de Provisi�n debe realizar reversi�n de asientos.
             -- Esta operaci�n es solamente para MTs RECIBIDOS.
             if not pas_snp.fu_val_es_enviado ( rg_msj_mov_tra )then
                 prs_snp_gen_provision('R', rg_msj_mov_tra);
             end if;
          end if;
       end if;
   EXCEPTION
     when ex_workflow then
        raise ex_workflow;
     when others then
        pas_snp.g_cod_error := 39;
        pas_snp.g_msj_error := 'Error en LP_REG_MOV_CREDITO: ' || g_lugar || ' - ' || sqlerrm;
        raise ex_workflow;
   END lp_reg_mov_credito;

BEGIN
   if pas_snp.fu_obt_cod_error = 0 then
      /**/-- Registro de Movimientos a partir de la mensajer�a
      g_lugar :=  'Seteando estado para el movimiento a generar, ';
      -- Para todas las transferencias recibidas el estado del movimiento quedar� en (N)ormal.
      if not pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) then
         pag_cta.pr_set_est_movimiento('N');
      end if;
      --
      g_lugar :=  'Registrando el movimiento, ';
      if rg_msj_mov_tra.cod_msj_swift in (103,102,8,104,4) then
         lp_reg_mov_transferencia;
         if not pas_snp.fu_val_es_enviado( rg_msj_mov_tra ) then
            if pas_snp.fu_obt_cod_error = 0 then
               /*
               || Env�a alertas al oficial y al cliente (PROCESO-OK) cuando la mensajer�a es solamente para MTs RECIBIDOS.
               || Para los MTs ENVIADOS se envia correo de confirmaci�n con la recepci�n del MT900
               */
               g_lugar :=  'Enviando alertas por el movimiento generado, ';
            if rg_msj_mov_tra.cod_msj_swift = 103 then
               pas_snp.pr_env_alerta( rg_msj_mov_tra, 'C' );
            end if;
               --
            end if;
         end if;
      elsif rg_msj_mov_tra.cod_msj_swift = 202 then
         lp_reg_mov_credito;
      end if;
   end if;
EXCEPTION
   when ex_workflow then
      raise ex_workflow;
   when others then
      pas_snp.g_cod_error := 39;
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_PRO_TRANSFERENCIA: ' || g_lugar || ' - ' || sqlerrm;
      raise ex_workflow;
END pr_pro_transferencia;

/*Genera movimientos por Cobro de Cargos. Utilizado para Obtener datos desde la BD a los Formularios*/
PROCEDURE pr_gen_mov_cargo( rg_msj_tra          in     pas_snp.rg_msj,
                            p_cta_cliente       in     ge_cuentas.nro_cuenta%type,
                            p_cta_interbancaria in     ge_cuentas.nro_cuenta%type,
                            p_mto_cliente       in     ge_movimientos.monto%type,
                            p_hora              in     ge_movimientos.hora%type,
                            p_nro_secuencia     in out ge_movimientos.nro_secuencia%type
                          )
IS
  rg_clie pag_cta.rg_ctas := null;
  rg_intb pag_cta.rg_ctas := null;
BEGIN

  pag_cta.pr_obt_cuenta( p_cta_cliente );
  if pag_cta.fu_obt_cod_error <> 0 then
     --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
     pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
     pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

     raise ex_salir;
  end if;
  rg_clie := pag_cta.g_ctas;

  pag_cta.pr_obt_cuenta( p_cta_interbancaria );
  if pag_cta.fu_obt_cod_error <> 0 then
     --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
     pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
     pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

     raise ex_salir;
  end if;
  rg_intb := pag_cta.g_ctas;

  pr_gen_mov_cargo( rg_msj_tra,
                    rg_clie,         -- Cta. Cliente.
                    rg_intb,         -- Cta. Interbancaria.
                    p_mto_cliente,   -- Monto sobre el cual se calcular�n los Cargos (Monto Cliente).
                    p_hora,          -- Hora para el Movimiento de los Cargos.
                    p_nro_secuencia  -- Nro. Secuencia para el Movimiento de los Cargos.
                  );

  if pas_snp.fu_obt_cod_error <> 0 then
     raise ex_salir;
  end if;

EXCEPTION
  when ex_salir then
     null;
  when others then
     pas_snp.g_cod_error := 73;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_MOV_CARGO(1): ' || g_lugar || ' - ' || sqlerrm;
END pr_gen_mov_cargo;

PROCEDURE pr_gen_mov_cargo( rg_msj_tra           in     pas_snp.rg_msj,
                            rg_cta_cliente       in     pag_cta.rg_ctas,
                            rg_cta_interbancaria in     pag_cta.rg_ctas,
                            p_mto_cliente        in     ge_movimientos.monto%type,
                            p_hora               in     ge_movimientos.hora%type,
                            p_nro_secuencia      in out ge_movimientos.nro_secuencia%type
                          )
IS
   /*Genera movimientos por Cobro de Cargos*/
   v_nro_secuencia     ge_movimientos.nro_secuencia%type   := 0;
   v_hora              ge_movimientos.hora%type            := NULL;
   v_tra_padre         ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_padre;
   v_mod_padre         ge_movimientos.cod_mod_padre%type   := pas_snp.fu_obt_cod_mod_padre;
   v_mad_padre         ge_movimientos.cod_mad_padre%type   := pas_snp.fu_obt_cod_mad_padre;
   v_cod_modulo        ge_movimientos.cod_modulo%type      := NULL;
   v_cod_modalidad     ge_movimientos.cod_modalidad%type   := NULL;
   v_tra_debito        ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_cargo;
   v_tra_impuesto      ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_impuesto;
   -- Conversi�n de Monedas
   v_cot_origen        ge_movimientos.cotizacion%type  := NULL;
   v_cot_destino       ge_movimientos.cotizacion%type  := NULL;
   -- Retorno de verificaci�n de operaciones
   v_est_cuenta        ge_cuentas.estado%type;    -- Estado Cta.
   v_sal_disponible    ge_movimientos.monto%type; -- Sal.Dispon.
   v_procesa           varchar2(1) := 'N';
   -- Definici�n de Movimientos a ser realizados en el PAS_SNP
   v_con_debito        varchar2(50):= 'Comisi�n de Transferencia - BCP';
   v_con_impuesto      varchar2(50):= 'Comisi�n de Transferencia - BCP';
   v_tip_mov_debito    varchar2(1) := 'D';
   -- Tasa Vigente para Indemnizaci�n al Cliente
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type := NULL;
   v_tip_valor         ge_tasas.tip_valor%type         := NULL;
   rg_tasas            ge_tasas%rowtype;
   v_cod_tas_horario   ge_tasas.cod_tasa%type       := NULL;
   v_cod_tas_cargo     ge_tasas.cod_tasa%type       := NULL;
   v_val_tas_cargo     ge_movimientos.val_tasa%type := NULL;
   v_cod_tas_impuesto  ge_tasas.cod_tasa%type       := NULL;
   v_val_tas_impuesto  ge_movimientos.val_tasa%type := NULL;
   v_mto_cargo         ge_movimientos.monto%type    := 0;
   v_mto_tra_cargo     ge_movimientos.monto%type    := 0;
   v_mto_impuesto      ge_movimientos.monto%type    := 0;
   v_tot_mto_cargo     ge_movimientos.monto%type    := 0;
   v_valor             ge_movimientos.monto%type    := 0;

   type                t_tipo_cursor IS REF CURSOR;
   v_dominio           ba_cod_referencias.dominio%type;
   cu_datos            t_tipo_cursor;
   v_sql               varchar2(500) := NULL;
   v_condicion         varchar2(500) := NULL;
   v_referencia        varchar2(20) :=  NULL;
   v_secuencia         ge_movimientos.nro_secuencia%type;
   PROCEDURE lp_obt_cod_tasa( p_dominio    in     ba_cod_referencias.dominio%type
                             ,p_val_minimo in     ba_cod_referencias.val_minimo%type
                            )
   IS
     v_cod_tasa ge_tasas.cod_tasa%type := NULL;
   BEGIN
      if pas_snp.fu_obt_cod_error = 0 then
         if upper( fue_obt_des_refcodes( p_dominio, p_val_minimo ) ) not like '%REF%NO%REG%SISTEMA%' then
            v_cod_tasa := to_number( fue_obt_des_refcodes( p_dominio, p_val_minimo ) );
         end if;

         if v_cod_tasa is not null then
            pas_snp.pr_set_texto( v_condicion, v_cod_tasa, ',' );
            -- Para la Franja Horaria se guarda el c�digo de tasa para luego compararlo mientras
            -- se realiza el c�lculo del monto para la tasa, ya que para esta tasa hay que pasarle
            -- el horario y no el monto del cliente
            if p_val_minimo = 'FHO' then -- Franja Horaria
               v_cod_tas_horario := v_cod_tasa;
            end if;
         end if;

      end if;

   EXCEPTION
      when others then
         pas_snp.g_cod_error := 74;
         pas_snp.g_msj_error := 'Error en LP_OBT_COD_TASA: '|| g_lugar || sqlerrm;
         raise ex_salir;
   END lp_obt_cod_tasa;

   PROCEDURE lp_obt_cargo( p_cod_ofi_cta       in     ge_cuentas.cod_oficina%type
                          ,p_nro_cuenta        in     ge_cuentas.nro_cuenta%type
                          ,p_cod_moneda        in     ge_cuentas.cod_moneda%type
                          ,p_val_transaccion   in     ge_movimientos.monto%type
                          ,p_cod_modulo        in     ge_cuentas.cod_modulo%type
                          ,p_cod_modalidad     in     ge_cuentas.cod_modalidad%type
                          ,p_tas_personalizada in     ge_cuentas.tas_personalizada%type
                          ,p_cod_tra_cargo     in     ge_movimientos.cod_transaccion%type
                          ,p_cod_tas_cargo     in out ge_movimientos.cod_tasa%type
                          ,p_val_tas_cargo        out ge_movimientos.val_tasa%type
                          ,p_val_cargo            out ge_movimientos.val_tasa%type
                         )
   IS
      v_val_transaccion ge_movimientos.monto%type := p_val_transaccion;
      v_fec_vigencia    ge_tas_fechas.fec_vigencia%type;
      v_tip_valor       ge_tasas.tip_valor%type;
      v_tipo            ge_tasas.tipo%type;
      v_redondeo        number(1);
   BEGIN
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', p_cod_modulo, p_cod_modalidad, p_cod_moneda);
       -- busco el valor de la tasa
       pag_gen.pr_obt_val_tasa( p_cod_modulo,
                                p_cod_modalidad,
                                p_cod_ofi_cta,
                                p_nro_cuenta,
                                p_cod_moneda,
                                v_val_transaccion,
                                nvl(p_tas_personalizada,'N'),
                                p_cod_tas_cargo,
                                p_cod_tra_cargo,
                                g_fec_actual,
                                p_val_tas_cargo,
                                v_fec_vigencia,
                                v_tip_valor,
                                v_tipo);
       if v_tip_valor = 'V' then
          -- si es un valor, se toma directamente
          p_val_cargo := round( nvl(p_val_tas_cargo,0), v_redondeo );
       else
          -- es un porcentaje
          p_val_cargo := round( nvl( v_val_transaccion, 0 ) * nvl( p_val_tas_cargo, 0 ) / 100, v_redondeo );
          --verificar si el monto a cobrar esta limitado x el minimo y maximo de la tasa
          p_val_cargo := pag_gen.fu_obt_val_final(p_val_cargo);
       end if;

       if p_val_cargo < 0 then
          pas_snp.g_cod_error := 74;
          pas_snp.g_msj_error := 'Error en LP_OBT_CARGO: Monto del Impuesto m�s alto que el Monto del Cargo';
          raise ex_salir;
       end if;
   EXCEPTION
      when ex_salir then
         raise ex_salir;
      when others then
         pas_snp.g_cod_error := 74;
         pas_snp.g_msj_error := 'Error en LP_OBT_CARGO: '|| sqlerrm;
         raise ex_salir;
   END lp_obt_cargo;
BEGIN
  if pas_snp.fu_obt_cod_error = 0 and p_mto_cliente <> 0 then

     /*
     || Se cobrar�n cargos por las siguientes situaciones:
     || Tipo de Canal (VPN/SWIFT), MT (Alto/Bajo Valor), Sistema Origen (ITGF, WEB), Tipo de Cargo (BEN, SHA, OUR) y Franja Horaria
     || El cargo se unifica bajo la transacci�n de d�bito 503, aparte de esto se cobrar� IVA.
     */
     --SPI-2
     if g_car_013='S' then
        lp_obt_cod_tasa('SPI_CAR_013_ENV','COD_TASA');
        v_tra_debito    :=fue_obt_des_refcodes('SPI_CAR_013_ENV','TRA_CARGO');
        v_tra_impuesto  :=fue_obt_des_refcodes('SPI_CAR_013_ENV','TRA_IVA');
     else
     if pas_snp.fu_val_es_enviado( rg_msj_tra ) then
        v_dominio := 'SNP_TAS_ENVIADA_'||
                      CASE
                        WHEN rg_msj_tra.origen = 'H' THEN 'HB'
                        ELSE 'ITGF'
                      END;
     else
        v_dominio := 'SNP_TAS_RECIBIDA';
     end if;
     BEGIN
        g_lugar := 'Buscando Tasas para el Cobro de Cargos, ';
        -- Tipo de Canal
        if g_tip_canal = 'S' then -- SWIFT
           lp_obt_cod_tasa( v_dominio, 'SWI' );
        else -- VPN
           lp_obt_cod_tasa( v_dominio, 'VPN' );
        end if;

        -- Tipo de Mensaje
        if fue_val_es_numerico( rg_msj_tra.nro_cta_beneficiario ) = 'S'
          and length( trim( rg_msj_tra.nro_cta_beneficiario ) ) >= 16
          and v_dominio = 'SNP_TAS_ENVIADA_HB' then
          --Se validan los datos para ver si es un pago de tarjeta
           lp_obt_cod_tasa( v_dominio, 'PTC' );
        elsif rg_msj_tra.cod_msj_swift in (103,202) then -- Alto Valor
           lp_obt_cod_tasa( v_dominio, 'AVL' );
        else -- Bajo Valor
           lp_obt_cod_tasa( v_dominio, 'BVL' );
        end if;

        -- Tipo de Cargo (BEN,SHA,OUR)
        if rg_msj_tra.cod_msj_swift in (103,102) then -- Transferencias entre Clientes
           lp_obt_cod_tasa( v_dominio, nvl( rg_msj_tra.tip_cargo, 'SHA' ) );
        end if;

        -- Franja Horaria
        if pas_snp.fu_val_es_enviado( rg_msj_tra ) then -- MT Enviado
           lp_obt_cod_tasa( v_dominio, 'FHO' );
        end if;

     EXCEPTION
        when ex_salir then
           raise ex_salir;
        when others then
           raise ex_salir;
     END;
      end if;

     BEGIN
        if v_condicion is not null then
           v_sql := 'select * from ge_tasas where cod_tasa in ( ' || v_condicion || ' )';
           open cu_datos for v_sql;
           loop
             fetch cu_datos into rg_tasas;
             exit when cu_datos%notfound;
             g_lugar := 'Obteniendo valores para la Tasa, ';
             v_cod_tas_cargo := rg_tasas.cod_tasa;

             -- Si la Tasa corresponde a Franja Horaria el valor debe ser la hora del sistema y no el monto
             if v_cod_tas_horario = rg_tasas.cod_tasa then
                v_valor := to_number( to_char( sysdate, 'HH24MI' ) );
             else
                v_valor := p_mto_cliente;
             end if;

             lp_obt_cargo( rg_cta_cliente.cod_oficina,
                           rg_cta_cliente.nro_cuenta,
                           rg_cta_cliente.cod_moneda,
                           v_valor,
                           rg_cta_cliente.cod_modulo,
                           rg_cta_cliente.cod_modalidad,
                           nvl(rg_cta_cliente.tas_personalizada,'N'),
                           v_tra_debito,
                           v_cod_tas_cargo,
                           v_val_tas_cargo,
                           v_mto_cargo
                         );


             If  NVL(v_val_tas_cargo,0) > 0 then
                  v_referencia := v_referencia ||','||rg_tasas.cod_tasa;
             end IF;
             v_tot_mto_cargo := v_tot_mto_cargo + nvl( v_mto_cargo,0 );
           end loop;

           close cu_datos;
        end if;
     EXCEPTION
        when ex_salir then
           raise ex_salir;
        when others then
           pas_snp.g_cod_error := 74;
           pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_MOV_CARGO(2): ' || g_lugar || sqlerrm;
           close cu_datos;
           raise ex_salir;
     END;
     -- Monto Total del D�bito
     g_lugar := 'Buscando Monto Cargo en la Mensajer�a, ';
     if rg_msj_tra.mto_cargo > 0 then
        if rg_msj_tra.cod_moneda <> rg_cta_cliente.cod_moneda then
           pag_gen.pr_con_mon_a_moneda( rg_cta_interbancaria.cod_moneda,
                                        rg_cta_cliente.cod_moneda,
                                        rg_msj_tra.mto_cargo,
                                        v_mto_tra_cargo,
                                        v_cot_origen,
                                        v_cot_destino
                                      );
        else
           v_mto_tra_cargo := nvl( rg_msj_tra.mto_cargo, 0 );
        end if;
     end if;
     --
     v_tot_mto_cargo := nvl( v_tot_mto_cargo,0 ) + nvl( v_mto_tra_cargo, 0 );

     BEGIN
        if v_tot_mto_cargo > 0 then
           BEGIN
              g_lugar := 'Calculando Monto del Impuesto, ';
              --
              -- Se obtiene el IVA por el total del CARGO.
              lp_obt_cargo( rg_cta_cliente.cod_oficina,
                            rg_cta_cliente.nro_cuenta,
                            rg_cta_cliente.cod_moneda,
                            v_tot_mto_cargo,
                            rg_cta_cliente.cod_modulo,
                            rg_cta_cliente.cod_modalidad,
                            nvl(rg_cta_cliente.tas_personalizada,'N'),
                            v_tra_impuesto,
                            v_cod_tas_impuesto,
                            v_val_tas_impuesto,
                            v_mto_impuesto
                           );

              v_mto_impuesto := nvl( v_mto_impuesto, 0 );

           EXCEPTION
              when ex_salir then
                 raise ex_salir;
              when others then
                 raise ex_salir;
           END;

          if pas_snp.fu_obt_cod_error = 0 then
             g_lugar := 'Obteniendo el tipo de movimiento para la transacci�n '||v_tra_debito||', ';
             -- Recupera el tipo de movimiento de la transacci�n
             v_tip_mov_debito := pas_snp.fu_obt_tip_mov_transaccion( rg_cta_cliente.cod_modulo,
                                                                     rg_cta_cliente.cod_modalidad,
                                                                     v_tra_debito
                                                                   );

             if pas_snp.fu_obt_cod_error <> 0 then
                raise ex_salir;
             end if;

             g_lugar :=  'Verificando los datos de la Cta. ' || rg_cta_cliente.nro_cuenta || ' (3), ' ;
             --
             pag_cta.pr_ver_operacion( rg_cta_cliente.nro_cuenta,               -- Nro.Cta.
                                       v_tra_padre,                             -- Trx. Padre - Transferencia entre cuentas
                                       v_mod_padre,                             -- Mod.Padre
                                       v_mad_padre,                             -- Mad.Padre
                                       v_tip_mov_debito,                        -- Tip.Mov.
                                       rg_cta_cliente.cod_moneda,               -- Cod.Mon.
                                       ( v_tot_mto_cargo + v_mto_impuesto ),    -- Monto Total a Debitar
                                       rg_cta_cliente.cod_oficina,              -- Ofic.Orig.
                                       v_cod_modulo,                            -- Mod.Hijo
                                       v_cod_modalidad,                         -- Mad.Hijo
                                       v_est_cuenta,                            -- Estado Cta.
                                       v_sal_disponible,                        -- Sal.Dispon.
                                       v_procesa                                -- Procesa
                                     );

             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                raise ex_salir;
             end if;

             if not ( rg_cta_cliente.cod_modalidad in ( 31, 41, 43, 47, 38, 39, 334 ) ) then
                pas_snp.g_cod_error := 74;
                pas_snp.g_msj_error := 'Modalidad de la cuenta no permite esta operaci�n';

                raise ex_salir;
             end if;

             --Setea el campo REFERENCIA del movimiento
             pag_cta.pr_set_referencia ( substr( ltrim(v_referencia,','), 1, 20 ) );
             --
             v_hora          := nvl( p_hora, fug_ini_hora );
             v_nro_secuencia := nvl( p_nro_secuencia, v_nro_secuencia );
               --spi fase2
             pag_cta.pr_set_variables(rg_msj_tra.cod_usuario,null,null,'N','N',
                                      v_secuencia,null,null,null,null);
             -- Movimiento por el CARGO GRAVADO.
             pag_cta.pr_act_operacion( rg_cta_cliente.nro_cuenta,  -- Nro.Cta.
                                       v_hora,                     -- Hora
                                       v_tip_mov_debito,           -- Tip.Mov.
                                       rg_cta_cliente.cod_moneda,  -- Cod.Mon.
                                       v_tot_mto_cargo,            -- Monto
                                       v_tra_padre,                -- Trx.Padre
                                       v_tra_debito,               -- Trx.Hija
                                       rg_msj_tra.nro_referencia,  -- Nro.Doc.
                                       NULL,                       -- Cotizacion
                                       fug_obt_ofi_usuario (rg_msj_tra.cod_usuario), -- Ofic.Orig.
                                       v_mod_padre,                -- Mod.Pad.Cliente
                                       v_mad_padre,                -- Mad.Pad.Cliente
                                       v_cod_tas_cargo,            -- Cod.Tasa
                                       v_val_tas_cargo,            -- Val.Tasa
                                       v_con_debito,               -- Concepto
                                       'S',                        -- Emit.Aviso
                                       v_nro_secuencia,
                                       g_fec_actual,
                                       NULL,
                                       NULL,
                                       NULL
                                     );
                --spi fase2
              pag_cta.pr_set_variables(null,null,null,'N','N',
                                       v_secuencia,null,null,null,null);
             g_lugar :=  'Verificando movimientos registrados para la Cta. (D). ' || rg_cta_cliente.nro_cuenta || ', ' ;
             if pag_cta.fu_obt_cod_error <> 0 then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                raise ex_salir;
             else -- Movimiento por el IVA del CARGO GRAVADO
                 pag_cta.pr_set_variables(rg_msj_tra.cod_usuario,null,null,'N','N',
                                          v_secuencia,null,null,null,null);
                pag_cta.pr_act_operacion( rg_cta_cliente.nro_cuenta,    -- Nro.Cta.
                                          v_hora,                       -- Hora
                                          v_tip_mov_debito,             -- Tip.Mov.
                                          rg_cta_cliente.cod_moneda,    -- Cod.Mon.
                                          v_mto_impuesto,               -- Monto
                                          v_tra_padre,                  -- Trx.Padre
                                          v_tra_impuesto,               -- Trx.Hija
                                          rg_msj_tra.nro_referencia,    -- Nro.Doc.
                                          NULL,                         -- Cotizacion
                                          fug_obt_ofi_usuario (rg_msj_tra.cod_usuario),   -- Ofic.Orig.
                                          v_mod_padre,                  -- Mod.Pad.Cliente
                                          v_mad_padre,                  -- Mad.Pad.Cliente
                                          v_cod_tas_impuesto,           -- Cod.Tasa
                                          v_val_tas_impuesto,           -- Val.Tasa
                                          v_con_impuesto,               -- Concepto
                                          'S',                          -- Emit.Aviso
                                          v_nro_secuencia,
                                          g_fec_actual,
                                          NULL,
                                          NULL,
                                          NULL
                                        );
                      --spi fase2
                 pag_cta.pr_set_variables(null,null,null,'N','N',
                                         v_secuencia,null,null,null,null);
                if pag_cta.fu_obt_cod_error <> 0 then
                   --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                   pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                   pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                   raise ex_salir;
                end if;
             end if;
             p_nro_secuencia := v_nro_secuencia;
          end if;
       end if;
     END;
  end if;
EXCEPTION
   when ex_salir then
      if g_gru_dir_correo is not null then
         BEGIN
            it_mail.mail( fug_obt_dir_correo,
                          g_gru_dir_correo,
                          'MT'||rg_msj_tra.cod_msj_swift||' - Error al generar movimientos para COBRO DE CARGOS - SNP',
                          'A continuaci�n los datos de la mensajer�a: '                                                                || chr(10) || chr(10) ||
                          'Nro. Referencia        : ' || rg_msj_tra.nro_referencia                                                     || chr(10) ||
                          'Fecha Valor            : ' || to_char(rg_msj_tra.fec_valor,'DD/MM/YYYY')                                    || chr(10) ||
                          'Nro. Cuenta            : ' || rg_cta_cliente.nro_cuenta                                                     || chr(10) ||
                          'Moneda                 : ' || rg_cta_cliente.cod_moneda                                                     || chr(10) ||
                          'Tasa(s) a Cobrar       : ' || substr( v_condicion, 1, 20 )                                                  || chr(10) ||
                          'Mto. Gravado a Debitar : ' || trim(to_char(v_tot_mto_cargo,'999,999,999,999,999.99'))                       || chr(10) ||
                          'Mto. I.V.A. a Debitar  : ' || trim(to_char(v_mto_impuesto,'999,999,999,999,999.99'))                        || chr(10) ||
                          'Error                  : ' || pas_snp.g_lugar || ' ' || pas_snp.g_cod_error || ' - ' || pas_snp.g_msj_error || chr(10) ||
                          chr(10) || chr(10) ||
                          'Atentamente.'
                        );
         EXCEPTION
           when others then
              NULL;
         END;
      end if;
   when others then
      pas_snp.g_cod_error := 74;
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_MOV_CARGO(2): ' || g_lugar || ' - ' || sqlerrm;
END pr_gen_mov_cargo;

PROCEDURE pr_gen_mov_indemnizacion( rg_cta_cliente   in     pag_cta.rg_ctas,
                                    rg_mensaje       in out pas_snp.rg_msj,
                                    p_mto_cliente    in     ge_movimientos.monto%type,
                                    p_hora           in     ge_movimientos.hora%type,
                                    p_nro_secuencia  in out ge_movimientos.nro_secuencia%type
                                  )
IS
   /*Genera movimientos para indemnizar al Cliente por procesos de transferencias recibidos y atrasados*/
   v_nro_secuencia     ge_movimientos.nro_secuencia%type   := 0;
   v_hora              ge_movimientos.hora%type            := NULL;
   v_tra_padre         ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_padre;
   v_mod_padre         ge_movimientos.cod_mod_padre%type   := pas_snp.fu_obt_cod_mod_padre;
   v_mad_padre         ge_movimientos.cod_mad_padre%type   := pas_snp.fu_obt_cod_mad_padre;
   v_tra_hija          ge_movimientos.cod_transaccion%type := pas_snp.fu_obt_cod_tra_indemnizacion;
   v_mto_cliente       ge_movimientos.monto%type           := nvl( p_mto_cliente, 0 );
   -- Retorno de verificaci�n de operaciones
   v_est_cuenta        ge_cuentas.estado%type;    -- Estado Cta.
   v_sal_disponible    ge_movimientos.monto%type; -- Sal.Dispon.
   v_procesa           varchar2(1) := 'N';        -- Procesar Operaci�n (S/N).
   -- Definici�n de Movimientos a ser realizados en el PAS_SNP
   v_con_movimiento    ge_movimientos.concepto%type := substr('(C) Indemnizaci�n al Cliente - BCP',1,35);
   v_tip_movimiento    varchar2(1) := NULL;
   -- Tasa Vigente para Indemnizaci�n al Cliente
   v_tas_vigente       ge_tasas.cod_tasa%type := fue_obt_des_refcodes('SNP_TAS_RECIBIDA','IND');
   v_val_tasa          ge_tas_fechas.val_tasa%type     := NULL;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type := NULL;
   v_tip_valor         ge_tasas.tip_valor%type         := NULL;
   v_tip_tasa          ge_tasas.tipo%type              := NULL;
   -- Tipo registro para almacenar datos de la cuenta del cliente y de la mensajer�a
   rg_dat_cuenta       pag_cta.rg_ctas := NULL;
   rg_transferencia    pas_snp.rg_msj  := NULL;
   -- Calculo de la Indemnizaci�n al Cliente
   v_mto_indemnizacion ge_movimientos.monto%type := 0;
   v_plazo             number(4);
   -- Avisos por mail del proceso de generaci�n de movimientos por Indemnizaci�n
   v_asunto            varchar2(100) := 'Movimiento de Indemnizaci�n a Clientes - SNP';

   v_min_acr_alt_valor constant number := nvl( fug_obt_pardinamico( 'SNP_MIN_ACR_ALT_VALOR' ), 0 );
   v_tie_excedido      number          := 0;
   v_redondeo          ge_par_dinamicos.val_parametro%type := NULL;
BEGIN
   if pas_snp.fu_obt_cod_error = 0 and
      v_mto_cliente <> 0
   then
      -- Recupera los datos de la mensajer�a
      rg_transferencia := rg_mensaje;
      --
      g_lugar  := 'Obteniendo datos del circuito, ' ;
      begin
        select round( paw_cir.fu_tie_excedido( ctar.cod_circuito, ctar.cod_tarea ), 2 ) tie_excedido
          into v_tie_excedido
          from wf_circuitos cir,
               wf_cir_tareas ctar
         where cir.referencia      = rg_transferencia.nro_referencia
           and cir.cod_circuito    = ctar.cod_circuito
           and cir.cod_tar_actual  = ctar.cod_tarea
           and cir.estado          not in ( 'C', 'F' )
           and ctar.estado         = 'P';
      exception
         when no_data_found then
            pas_snp.pr_ini_variables;
            raise ex_salir;
         when too_many_rows then
            pas_snp.g_cod_error := 39;
            pas_snp.g_msj_error := 'Se han encontrado varios circuitos EN EJECUCI�N en el WF con el Nro. Referencia '||rg_transferencia.nro_referencia||
                                   ' para indemnizar al Cliente. '||chr(10)||'Generar Manualmente la Indemnizaci�n.';
            raise ex_salir;
         when others then
            pas_snp.g_cod_error := 39;
            pas_snp.g_msj_error := 'Error al recuperar datos en el WF con el Nro. Referencia '||rg_transferencia.nro_referencia||
                                   ' para indemnizar al Cliente.'||chr(10)||sqlerrm||chr(10)||'Generar Manualmente la Indemnizaci�n.';
            raise ex_salir;
      end;

      -- Si el mensaje es Alto Valor y mayor a lo configurado en MINUTOS.
      if ( rg_transferencia.cod_msj_swift = 103 and
           v_tie_excedido > v_min_acr_alt_valor
         )
      or -- Si el mensaje es Bajo Valor y mayor a 1 D�A.
         ( rg_transferencia.cod_msj_swift = 102 and
           ( ( v_tie_excedido / 24 ) / 60 ) > 1
         )
      then
         rg_dat_cuenta := rg_cta_cliente;

         -- Recupera el tipo de movimiento de la transacci�n
         g_lugar  := 'Obteniendo el tipo de movimiento para la transacci�n '||v_tra_hija||', ';
         v_tip_movimiento := pas_snp.fu_obt_tip_mov_transaccion( rg_dat_cuenta.cod_modulo,
                                                                 rg_dat_cuenta.cod_modalidad,
                                                                 v_tra_hija
                                                               );

         if pas_snp.fu_obt_cod_error <> 0 then
            raise ex_salir;
         end if;
         --

         ------------------------------------------------------------------------------------------------
         /**/-- D A T O S   D E   L A   C U E N T A   D E   C R E D I T O
         ------------------------------------------------------------------------------------------------

         if pas_snp.g_cod_error = 0 then

            g_lugar :=  'Verificando los datos de la Cta. ' || rg_dat_cuenta.nro_cuenta || ', ' ;
            pag_cta.pr_ver_operacion( rg_dat_cuenta.nro_cuenta,    -- Nro.Cta.
                                      v_tra_padre,                 -- Trx. Padre - Transferencia entre cuentas
                                      v_mod_padre,                 -- Mod.Padre
                                      v_mad_padre,                 -- Mad.Padre
                                      v_tip_movimiento,            -- Tip.Mov.
                                      rg_dat_cuenta.cod_moneda,    -- Cod.Mon.
                                      0,                           -- Monto
                                      rg_dat_cuenta.cod_oficina,   -- Ofic.Orig.
                                      rg_dat_cuenta.cod_modulo,    -- Mod.Hijo
                                      rg_dat_cuenta.cod_modalidad, -- Mad.Hijo
                                      v_est_cuenta,                -- Estado Cta.
                                      v_sal_disponible,            -- Sal.Dispon.
                                      v_procesa                    -- Procesa
                                    );

            if pag_cta.fu_obt_cod_error <> 0 then
               --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
               pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
               pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

               raise ex_salir;

            end if;

            if not ( ( rg_dat_cuenta.cod_modulo in ( 3, 4 ) and rg_dat_cuenta.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39, 334 ) ) or
                       rg_dat_cuenta.cod_modulo = 5
                   ) --Para MT recibido la Cuenta de Cr�dito puede ser la de Tarjetas
            then
               pas_snp.g_cod_error := 39;
               pas_snp.g_msj_error := 'Modalidad de la cuenta no permite este tipo de operaci�n';

               raise ex_salir;
            end if;

         end if;

         -- Se obtiene la Tasa para calcular el Monto a Indemnizar al Cliente.
         g_lugar  := 'Calcula el Monto de Indemnizaci�n..' ;
         pag_gen.pr_obt_val_tasa( 3,
                                  31,
                                  rg_dat_cuenta.cod_oficina,
                                  null,
                                  rg_dat_cuenta.cod_moneda,
                                  null,
                                  null,
                                  v_tas_vigente,
                                  null,
                                  g_fec_actual,
                                  v_val_tasa,     -- OUT
                                  v_fec_vigencia, -- OUT
                                  v_tip_valor,    -- OUT
                                  v_tip_tasa,     -- OUT
                                  null
                                ) ;

         -- Se retorna el plazo redondeando hacia arriba.
         v_plazo := ceil( nvl( sysdate - rg_transferencia.fec_recepcion, 1 ) );

         v_redondeo := nvl( fug_obt_pardinamico( p_parametro  => 'VAL_RED_MON_EXTRANJERA',
                                                 p_cod_moneda => rg_dat_cuenta.cod_moneda
                                               ), 0
                          );

         if fue_val_es_numerico ( v_redondeo ) = 'N' then
            v_redondeo := 0;
         end if;

         -- Calculo de la Indemnizaci�n al Cliente (Monto de la Transferencia x Tasa x plazo)/36500)
         v_mto_indemnizacion := round( pag_gen.fu_cal_int_simple( nvl( v_mto_cliente, 0 ),
                                                                  v_plazo,
                                                                  v_val_tasa
                                                                ),
                                       v_redondeo
                                     );

         if v_mto_indemnizacion > 0 then

            if pas_snp.fu_obt_cod_error = 0 then

               if pas_snp.fu_obt_cod_error = 0 then
                  g_lugar :=  'Intentando Registrar la Operaci�n para la Cta. (C). ' || rg_dat_cuenta.nro_cuenta || ', ' ;
                  --
                  if rg_dat_cuenta.cod_modulo in ( 3, 4 ) and
                     rg_dat_cuenta.cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39, 334 )
                  then --Para la modalidad 31,41,455 el movimiento debe hacerse por el PAG_CTA.PR_ACT_OPERACION

                     v_hora          := nvl( p_hora, fug_ini_hora );
                     v_nro_secuencia := nvl( p_nro_secuencia, v_nro_secuencia );

                     pag_cta.pr_act_operacion( rg_dat_cuenta.nro_cuenta,        -- Nro.Cta.
                                               v_hora,                          -- Hora
                                               v_tip_movimiento,                -- Tip.Mov.
                                               rg_dat_cuenta.cod_moneda,        -- Cod.Mon.
                                               v_mto_indemnizacion,             -- Monto
                                               v_tra_padre,                     -- Trx.Padre
                                               v_tra_hija,                      -- Trx.Hija
                                               rg_transferencia.nro_referencia, -- Nro.Doc.
                                               NULL,                            -- Cotizacion
                                               fug_obt_ofi_usuario (user),      -- Ofic.Orig.
                                               v_mod_padre,                     -- Mod.Padre
                                               v_mad_padre,                     -- Mad.Padre
                                               v_tas_vigente,                   -- Cod.Tasa
                                               v_val_tasa,                      -- Val.Tasa
                                               v_con_movimiento,                -- Concepto
                                               'S',                             -- Emit.Aviso
                                               v_nro_secuencia,
                                               pas_snp.g_fec_actual
                                             );

                     g_lugar :=  'Verificando movimientos registrados para la Cta. (C). ' || rg_transferencia.nro_referencia || ', ' ;
                     if pag_cta.fu_obt_cod_error <> 0 then
                        --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                        pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                        pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                        raise ex_salir;
                     end if;
                  end if;
               end if;
            end if;
         end if;
      else --si no exedi� el tiempo, se actualiza el registro con el valor INDEMNIZADO = N
         rg_mensaje.indemnizado := 'N';
      end if;
      if v_mto_indemnizacion = 0 and rg_mensaje.indemnizado = 'S' then
        rg_mensaje.indemnizado := 'N';
      end if;
   end if;
EXCEPTION
   when ex_salir then
        if pas_snp.fu_obt_cod_error <> 0 then
           pas_snp.pr_env_mail( g_gru_dir_correo,
                                v_asunto,
                                rg_transferencia,
                                'Error: '||pas_snp.g_lugar||' '||pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error
                              );
        end if;
   when others then
        pas_snp.pr_env_mail( g_gru_dir_correo,
                             'Error al intentar generar movimiento de Indemnizaci�n a Clientes - SNP',
                             rg_transferencia,
                             'Error:  '||pas_snp.g_lugar||' '||sqlerrm||chr(10)||
                             'Generar Manualmente la Indemnizaci�n.'
                           );
END pr_gen_mov_indemnizacion;

PROCEDURE pr_pro_msj_rechazado( rg_msj in out rg_msj )
IS
  /*Genera y env�a mensajer�a de Reverso para MTs ENVIADOS y RECIBIDOS mediante el mensaje ORIGINAL*/
  v_situacion  ge_snp_transferencias.situacion%type:= null;
  v_msj_swift  ge_snp_transferencias.msj_swift%type;
  rg_msj_rch   pas_snp.rg_msj := null;
BEGIN
     /*Inicializa las variables de error*/
     pas_snp.pr_ini_variables;

     if pas_snp.fu_val_es_enviado( rg_msj ) then
        --Es un MT ENVIADO
        if rg_msj.fecha is not null and
           rg_msj.hora is not null and
           rg_msj.cod_usuario is not null
        then
           -- Para la reversi�n la situaci�n del mensaje enviado debe estar C, E
           -- Luego se reestablece la situacion original
           v_situacion      := rg_msj.situacion;
           rg_msj.situacion := 'C';
           pas_snp.pr_set_transferencias ( rg_msj );
           --REVERSA LA OPERACION RELACIONADA AL MENSAJE
           pas_snp.pr_rev_ope_con_swift( rg_msj.nro_referencia, 'Rev. MT.' || rg_msj.nro_referencia ||' - SNP', 'R' );
           if pas_snp.fu_obt_cod_error <> 0 then
              raise ex_salir;
           end if;
           --
           rg_msj.situacion := v_situacion;
        end if;
        --
        rg_msj.estado := 'R';
        -- Actualiza datos en el MT Original
        update ge_snp_transferencias t
           set t.tip_rechazo    = rg_msj.tip_rechazo,
               t.ref_oid        = rg_msj.ref_oid,
               t.situacion      = rg_msj.situacion,
               t.estado         = rg_msj.estado
         where t.nro_referencia = rg_msj.nro_referencia;
        --
     else --Es un MT RECIBIDO
        -- Se invierte el MT para su posterior env�o.
        -- Se carga el tipo de rechazo gen�rico para reversiones autom�ticas
        rg_msj.tip_rechazo := nvl(rg_msj.tip_rechazo,999);
        --
        pas_snp.pr_gen_msj_invertido ( rg_msj, rg_msj_rch );
        if pas_snp.fu_obt_cod_error <> 0 then
           raise ex_salir;
        end if;
        --
        -- Si el horario est� INACTIVO, preparar el mensaje para enviar al siguiente d�a h�bil y no retornar
        -- el error que genera el pas_snp.fu_obt_est_horario si no est� HABILITADO el horario,
        -- ya que para eso ya se registra la fecha valor el d�a siguiente h�bil
        --
        rg_msj_rch.fec_valor := nvl( pas_snp.fu_obt_fec_transferencia( rg_msj_rch.cod_msj_swift,
                                                                       rg_msj_rch.cod_tip_operacion,
                                                                       rg_msj_rch.cod_sub_tip_operacion,
                                                                       rg_msj_rch.fec_ingreso
                                                                     ),
                                     rg_msj_rch.fec_valor
                                   );

        --
        -- Inserta el mensaje de REVERSI�N
        pas_snp.pr_ins_transferencias ( rg_msj_rch );
        if pas_snp.fu_obt_cod_error <> 0 then
           raise ex_salir;
        end if;
        --
        -- Obtiene el nuevo mensaje de REVERSION
        if rg_msj_rch.cod_msj_swift = 103 then
           v_msj_swift := pas_snp.fu_obt_msj_mt103(rg_msj_rch.nro_referencia, 'N');
        elsif rg_msj_rch.cod_msj_swift = 202 then
           v_msj_swift := pas_snp.fu_obt_msj_mt202(rg_msj_rch.nro_referencia, 'N');
        else
          v_msj_swift := null;
        end if;

        if pas_snp.fu_obt_cod_error <> 0 then
           raise ex_salir;
        end if;
        --
        -- Crea el mensaje SWIFT de REVERSI�N
        update ge_snp_transferencias t
           set t.fec_valor      = rg_msj_rch.fec_valor,
               t.msj_swift      = v_msj_swift
         where t.nro_referencia = rg_msj_rch.nro_referencia;
        --
        -- Actualiza el Tipo de Rechazo del MT Original
        update ge_snp_transferencias t
           set t.tip_rechazo    = rg_msj.tip_rechazo
         where t.nro_referencia = rg_msj.nro_referencia;
        --
        if rg_msj_rch.fec_valor = pas_snp.g_fec_actual
          and  pas_snp.fu_obt_est_horario( rg_msj_rch.cod_msj_swift,
                                       rg_msj_rch.cod_tip_operacion,
                                       rg_msj_rch.cod_sub_tip_operacion
                                     ) = 'A' then
           --Env�a el mensaje SWIFT de REVERSI�N (si corresponde enviar)
           if pas_snp.fu_obt_cod_error = 0 then
              pas_snp.pr_gen_arc_swift ( rg_msj_rch.nro_referencia, 'N', 'R' );
              if pas_snp.fu_obt_cod_error != 0 then
              /*Si hubo problemas con el pr_set_transferencias en el pr_gen_arc_swift
                 se graba el error con un update*/
                 update ge_snp_transferencias a
                    set a.error = a.error||' '||pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error
                  where a.nro_referencia = rg_msj_rch.nro_referencia;
               end if;
           end if;
        elsif rg_msj_rch.fec_valor = pas_snp.g_fec_actual and pas_snp.fu_obt_cod_error = 33 then--si los modulos estan cerrados
                  -- Setear el campo error si no se encontr� abierto
                 pas_snp.pr_ini_variables;
        end if;
     end if;

EXCEPTION
   when ex_salir then
      null;
   when others then
      pas_snp.g_cod_error := 69;
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_PRO_MSJ_RECHAZADO - ' || sqlerrm;
END pr_pro_msj_rechazado;

PROCEDURE pr_env_mail( p_dir_correo in ge_par_dinamicos.val_parametro%type,
                       p_tit_mail   in varchar2,
                       rg_msj_mail  in pas_snp.rg_msj,
                       p_det_error  in varchar2 default null
                     )
IS
BEGIN
   if p_dir_correo is not null then
      if rg_msj_mail.nro_referencia is not null then
         it_mail.mail( fug_obt_dir_correo,
                       p_dir_correo,
                       p_tit_mail,
                       'A continuaci�n los datos de la mensajer�a: '                                        || chr(10) || chr(10) ||
                       'Nro. Referencia    : ' || rg_msj_mail.nro_referencia                                || chr(10) ||
                       'Cta. F�sica Solic. : ' || rg_msj_mail.nro_cta_pte_solicitante                       || chr(10) ||
                       'Fecha Valor        : ' || to_char(rg_msj_mail.fec_valor,'DD/MM/YYYY')               || chr(10) ||
                       'Tipo Operaci�n     : ' || pas_snp.fu_obt_des_tip_operacion( rg_msj_mail.cod_msj_swift,
                                                                                    rg_msj_mail.cod_tip_operacion,
                                                                                    rg_msj_mail.cod_sub_tip_operacion
                                                                                  )                         || chr(10) ||
                       'Moneda             : ' || rg_msj_mail.cod_moneda                                    || chr(10) ||
                       'Monto              : ' || trim(to_char(rg_msj_mail.monto,'999,999,999,999,999.99')) || chr(10) ||
                       CASE nvl( p_det_error, '~' ) WHEN '~' THEN NULL ELSE
                       'Error              : ' || substr( p_det_error,1,4000)
                       END || chr(10) || chr(10) || chr(10) ||
                       'Atentamente.'
                     );
      end if;
   end if;
EXCEPTION
   when others then
      NULL;
END pr_env_mail;

PROCEDURE pr_env_mai_attachment( p_dir_correo  in ge_par_dinamicos.val_parametro%type,
                                 p_tit_mail    in varchar2,
                                 p_det_archivo in long,
                                 p_nom_archivo in varchar2
                               )
IS
  /*Env�a mail con adjunto*/
  conn utl_smtp.connection;
BEGIN
   conn := it_mail.begin_mail( fug_obt_dir_correo,
                               p_dir_correo,
                               p_tit_mail,
                               IT_MAIL.MULTIPART_MIME_TYPE
                             );
   it_mail.attach_text( conn, 'Adjunto archivo conteniendo los datos' || chr(10) || chr(10) || 'Atentamente. ', 'text/plain' );
   it_mail.begin_attachment( conn,'text/plain',false, p_nom_archivo );
   it_mail.write_text( conn, p_det_archivo );
   it_mail.end_mail( conn );
EXCEPTION
  when utl_smtp.transient_error or
       utl_smtp.permanent_error
  then
     begin
        utl_smtp.quit(conn);
     exception
        when utl_smtp.transient_error or
             utl_smtp.permanent_error
        then
           null;
     end;
  when others then
     begin
        utl_smtp.quit(conn);
     exception
        when utl_smtp.transient_error or
             utl_smtp.permanent_error
        then
           null;
     end;
END pr_env_mai_attachment;

PROCEDURE pr_gen_msj_alt_val_workflow( p_fec_valor in ge_snp_transferencias.fec_valor%type )
IS
   c_fec_valor    constant date := nvl( p_fec_valor, g_fec_actual );
   --Variables del corte de control.
   v_tip_cir_ant  wf_tip_circuitos.cod_tip_circuito%type := -999;
   v_tip_tar_ant  wf_tip_cir_tareas.cod_tip_tarea%type   := -999;
   v_det_archivo  long;
   v_ind_env_mail varchar2(1) := 'N';

   /*Env�a mail de alertas para MT's Recibidos Alto Valor que a�n no fueron procesados desde el WF*/
   cursor cu_msj_alt_valor is
     select tcir.cod_tip_circuito, tcir.descripcion des_tip_circuito,
            tct.cod_tip_tarea, tct.descripcion des_tip_tarea, cir.fec_inicio, nvl(tct.tie_estimado,0) tie_estimado,
            CASE nvl(tct.tip_tiempo,'D')
              WHEN 'D' THEN 'Dia(s)'
              WHEN 'H' THEN 'Hora(s)'
              WHEN 'M' THEN 'Minuto(s)'
              WHEN 'S' THEN 'Segundo(s)'
              ELSE tct.tip_tiempo
            END tip_tiempo,
            trim( to_char( ceil( paw_cir.fu_tie_excedido( ctar.cod_circuito, ctar.cod_tarea ) ),'999,999,999,999,999.99' ) ) tie_excedido,
            tra.nro_referencia
       from ge_snp_transferencias tra,
            wf_circuitos cir,
            wf_cir_tareas ctar,
            wf_tip_circuitos tcir,
            wf_tip_cir_tareas tct
      where tra.nro_referencia      = cir.referencia
        and cir.cod_circuito        = ctar.cod_circuito
        and cir.cod_tip_circuito    = tcir.cod_tip_circuito
        and ctar.cod_tip_circuito   = tct.cod_tip_circuito
        and ctar.cod_tip_tarea      = tct.cod_tip_tarea
        and cir.estado              NOT IN ( 'C', 'F' )
        and ctar.estado             = 'P'
        and tra.fec_valor           = c_fec_valor
        and tra.estado              = 'S'                -- Solicitado
        and tra.situacion           IN ( 'R', 'I', 'E' ) -- Recibidos, Pendiente de Autorizaci�n en el WF o con Error
        and tra.cod_msj_swift       IN ( 103, 202 )
        and tra.nro_ref_externa     IS NOT NULL          -- Para MT Recibidos
        and tra.fec_recepcion       IS NOT NULL          -- Para MT Recibidos
        and tra.monto               <> 0
        and tra.fecha               IS NULL              -- Que no tenga movimientos relacionados aun,
        and tra.hora                IS NULL
        and tra.cod_usuario         IS NULL
   order by cod_tip_circuito, tct.cod_tip_tarea, tra.nro_referencia;

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   for c_av in cu_msj_alt_valor loop
     v_ind_env_mail := 'S';
     if nvl(v_tip_cir_ant,'-1') <> nvl(c_av.cod_tip_circuito,'-1') then
        v_tip_cir_ant := c_av.cod_tip_circuito;
        v_tip_tar_ant := -999;
        v_det_archivo := v_det_archivo ||
                         'Tipo Circuito: ' || c_av.cod_tip_circuito || ' ' || c_av.des_tip_circuito || chr(10);
     end if;
     if nvl(v_tip_tar_ant,'-1') <> nvl(c_av.cod_tip_tarea,'-1') then
        v_tip_tar_ant := c_av.cod_tip_tarea;
        v_det_archivo := v_det_archivo ||
                         '    Tipo de Tarea: ' || c_av.cod_tip_tarea || ' ' || c_av.des_tip_tarea || ' Tiempo M�ximo: ' ||
                         c_av.tie_estimado || ' ' ||c_av.tip_tiempo || chr(10);
        v_det_archivo := v_det_archivo ||
                       --
                       --          1         2         3         4         5         6         7         8         9        10        11        12        13        14        15        16
                       -- 1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
                         '        Nro. Referencia   Cliente Beneficiario                                 Mon.                    Monto   Fec. Ini                       Tiempo Excedido' || chr(10) ||
                         '-------------------------------------------------------------------------------------------------------------------------------------------------------------' || chr(10);
     end if;
     pas_snp.pr_ini_registros;
     pas_snp.pr_obt_mensaje( c_av.nro_referencia, 'N' );
     v_det_archivo := v_det_archivo || lpad( g_msj.nro_referencia, 23, ' ' ) || '   ' ||
                                       rpad( nvl( substr( g_msj.nom_beneficiario, 1, 50 ), lpad( ' ', 50, ' ' ) ), 50, ' ' ) || '   ' ||
                                       rpad( nvl( substr( g_msj.cod_moneda, 1, 4 ), lpad( ' ', 4, ' ' ) ), 4, ' ' ) || '   ' ||
                                       lpad( nvl( ltrim( rtrim( to_char( g_msj.monto,'999,999,999,999,999.99' ) ) ), lpad( ' ', 22, ' ' ) ), 22, ' ' ) || '   ' ||
                                       rpad( nvl( to_char( c_av.fec_inicio, 'DD/MM/YYYY HH24:MI:SS' ), lpad( ' ', 21, ' ' ) ), 21, ' ' ) || '   ' ||
                                       lpad( c_av.tie_excedido, 22, ' ' ) || chr(10);
   end loop;
   if v_ind_env_mail = 'S' and
      g_gru_dir_correo is not null
   then
      pas_snp.pr_env_mai_attachment( g_gru_dir_correo,
                                     'MTs Recibidos de Alto Valor - Tareas excedidas correspondientes a SNP en el Workflow',
                                     v_det_archivo,
                                     'MT_AV_'||to_char(sysdate,'DDMMYYYY HH24:MI:SS')||'.txt'
                                   );
   end if;

EXCEPTION
  when others then
    pas_snp.g_cod_error := 71;
    pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_MSJ_ALT_VAL_WORKFLOW: - ' || sqlerrm;
END pr_gen_msj_alt_val_workflow;

PROCEDURE pr_gen_msj_baj_val_workflow( p_fec_valor in ge_snp_transferencias.fec_valor%type )
IS
   /*Env�a mail de alertas para MT's Recibidos Bajo Valor que a�n no fueron procesados desde el WF*/
   c_fec_valor    constant date := nvl( p_fec_valor, g_fec_actual );
   --Variables del corte de control.
   v_tip_cir_ant  wf_tip_circuitos.cod_tip_circuito%type := -999;
   v_tip_tar_ant  wf_tip_cir_tareas.cod_tip_tarea%type   := -999;
   v_det_archivo  long;
   v_ind_env_mail varchar2(1) := 'N';

   cursor cu_msj_baj_valor is
     select tcir.cod_tip_circuito, tcir.descripcion des_tip_circuito,
            tct.cod_tip_tarea, tct.descripcion des_tip_tarea, cir.fec_inicio, nvl(tct.tie_estimado,0) tie_estimado,
            CASE nvl(tct.tip_tiempo,'D')
              WHEN 'D' THEN 'Dia(s)'
              WHEN 'H' THEN 'Hora(s)'
              WHEN 'M' THEN 'Minuto(s)'
              WHEN 'S' THEN 'Segundo(s)'
              ELSE tct.tip_tiempo
            END tip_tiempo,
            trim( to_char( ceil( paw_cir.fu_tie_excedido( ctar.cod_circuito, ctar.cod_tarea ) ),'999,999,999,999,999.99' ) ) tie_excedido,
            tra.nro_referencia
       from ge_snp_transferencias tra,
            wf_circuitos cir,
            wf_cir_tareas ctar,
            wf_tip_circuitos tcir,
            wf_tip_cir_tareas tct
      where tra.nro_referencia      = cir.referencia
        and cir.cod_circuito        = ctar.cod_circuito
        and cir.cod_tip_circuito    = tcir.cod_tip_circuito
        and ctar.cod_tip_circuito   = tct.cod_tip_circuito
        and ctar.cod_tip_tarea      = tct.cod_tip_tarea
        and cir.estado              NOT IN ( 'C', 'F' )
        and ctar.estado             = 'P'
        and tra.fec_valor           = c_fec_valor
        and tra.estado              = 'S'                -- Solicitado
        and tra.situacion           IN ( 'R', 'I', 'E' ) -- Recibidos, Pendiente de Autorizaci�n en el WF o con Error
        and tra.cod_msj_swift       = 102
        and tra.nro_ref_externa     IS NOT NULL          -- Para MT Recibidos
        and tra.fec_recepcion       IS NOT NULL          -- Para MT Recibidos
        and tra.monto               <> 0
        and tra.fecha               IS NULL              -- Que no tenga movimientos relacionados aun,
        and tra.hora                IS NULL
        and tra.cod_usuario         IS NULL
   order by cod_tip_circuito, tct.cod_tip_tarea, tra.nro_referencia;

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   for c_bv in cu_msj_baj_valor loop
     v_ind_env_mail := 'S';
     if nvl(v_tip_cir_ant,'-1') <> nvl(c_bv.cod_tip_circuito,'-1') then
        v_tip_cir_ant := c_bv.cod_tip_circuito;
        v_tip_tar_ant := -999;
        v_det_archivo := v_det_archivo ||
                         'Tipo Circuito: ' || c_bv.cod_tip_circuito || ' ' || c_bv.des_tip_circuito || chr(10);
     end if;
     if nvl(v_tip_tar_ant,'-1') <> nvl(c_bv.cod_tip_tarea,'-1') then
        v_tip_tar_ant := c_bv.cod_tip_tarea;
        v_det_archivo := v_det_archivo ||
                         '    Tipo de Tarea: ' || c_bv.cod_tip_tarea || ' ' || c_bv.des_tip_tarea || ' Tiempo M�ximo: ' ||
                         c_bv.tie_estimado || ' ' ||c_bv.tip_tiempo || chr(10);
        v_det_archivo := v_det_archivo ||
                       --
                       --          1         2         3         4         5         6         7         8         9        10        11        12        13        14        15        16
                       -- 1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
                         '        Nro. Referencia   Cliente Beneficiario                                 Mon.                    Monto   Fec. Ini                       Tiempo Excedido' || chr(10) ||
                         '-------------------------------------------------------------------------------------------------------------------------------------------------------------' || chr(10);
     end if;
     pas_snp.pr_ini_registros;
     pas_snp.pr_obt_mensaje( c_bv.nro_referencia, 'N' );
     v_det_archivo := v_det_archivo || lpad( g_msj.nro_referencia, 23, ' ' ) || '   ' ||
                                       rpad( nvl( substr( g_msj.nom_beneficiario, 1, 50 ), lpad( ' ', 50, ' ' ) ), 50, ' ' ) || '   ' ||
                                       rpad( nvl( substr( g_msj.cod_moneda, 1, 4 ), lpad( ' ', 4, ' ' ) ), 4, ' ' ) || '   ' ||
                                       lpad( nvl( ltrim( rtrim( to_char( g_msj.monto,'999,999,999,999,999.99' ) ) ), lpad( ' ', 22, ' ' ) ), 22, ' ' ) || '   ' ||
                                       rpad( nvl( to_char( c_bv.fec_inicio, 'DD/MM/YYYY HH24:MI:SS' ), lpad( ' ', 21, ' ' ) ), 21, ' ' ) || '   ' ||
                                       lpad( c_bv.tie_excedido, 22, ' ' ) || chr(10);
   end loop;
   if v_ind_env_mail = 'S' and
      g_gru_dir_correo is not null
   then
      pas_snp.pr_env_mai_attachment( g_gru_dir_correo,
                                     'MTs Recibidos de Bajo Valor - Tareas excedidas correspondientes a SNP en el Workflow',
                                     v_det_archivo,
                                     'MT_BV_'||to_char(sysdate,'DDMMYYYY HH24:MI:SS')||'.txt'
                                   );
   end if;

EXCEPTION
  when others then
    pas_snp.g_cod_error := 72;
    pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_MSJ_BAJ_VAL_WORKFLOW: - ' || sqlerrm;
END pr_gen_msj_baj_val_workflow;

function fu_reg_msj_generico( p_mensaje          in clob,
                              p_ind_msj_recibido in varchar2 default 'S',
                              p_env_mail         in varchar2 default 'S'
                            ) return varchar2
is

   v_cod_mensaje      sb_snp_mensajes_tmp.cod_mensaje%type;
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_referencia%type;
   v_dir_correo       ge_par_dinamicos.val_parametro%type := nvl( pas_snp.g_gru_dir_correo, pas_snp.g_err_dir_correo );
   v_det_msj_error    g_det_msj_error%type;
   v_txt_mail         varchar2(4000);
   v_asunto           varchar2(4000);
   v_msj_swift        varchar2(4000);
   v_txt_mas_detalles varchar2(100);
   v_msj_swi_original clob := null;
   v_contador         number;

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
   --
   pas_snp.pr_ini_variables;
   v_det_msj_error := NULL;
   g_det_msj_error:= null;--TRFS-533
   --
   pr_set_texto( v_txt_mas_detalles, '....', pas_snp.fu_obt_salto );
   pr_set_texto( v_txt_mas_detalles, '....', pas_snp.fu_obt_salto );
   pr_set_texto( v_txt_mas_detalles, '....', pas_snp.fu_obt_salto );

   -- Se recupera valores comunes para la inserci�n en GE_SNP_MENSAJES cuando no est� esquematizado.
   v_cod_mensaje := pao_pmt.fu_obt_cod_msj_swift( pao_pmt.fu_obt_linea(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 1) );
   if dbms_lob.getlength( p_mensaje ) > 4000 then
      v_msj_swift := dbms_lob.substr( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), 3800, 1 ) ||
                     v_txt_mas_detalles;
   else
      v_msj_swift := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
   end if;
   v_msj_swi_original := replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );
   --
   select count(*)
     into v_contador
     from sb_snp_mensajes_tmp;
   --
   if v_contador = 0 then -- No est� esquematizado
      v_nro_referencia   := pao_pmt.fu_obt_val_campo( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '20' );
      v_nro_ref_externa  := pao_pmt.fu_obt_val_campo( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '21' );
      --
      pas_snp.pr_set_texto( v_asunto, 'Mensajer�a '|| nvl( v_cod_mensaje, 'sin formato' ) || ' Recibida', NULL );
      pas_snp.pr_set_texto( v_txt_mail, 'Se recibi� un MT con el siguiente detalle:', pas_snp.fu_obt_salto || pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto( v_txt_mail, 'Nro. Referencia     : ' || v_nro_referencia, pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto( v_txt_mail, 'Nro. Ref. Original  : ' || v_nro_ref_externa, pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto( v_txt_mail, 'Fec Valor           : ' || to_char(pas_snp.g_fec_actual, 'DD/MM/YYYY'), pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto( v_txt_mail, 'Detalle del mensaje : ' || v_msj_swift, pas_snp.fu_obt_salto || pas_snp.fu_obt_salto || pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto( v_txt_mail, 'Atentamente.', pas_snp.fu_obt_salto );
      --
   else -- Si est� esquematizado
     for msj in cu_msj_temporal loop
         --Creo la cabecera del mail
         if v_asunto is null then
            v_asunto := 'Mensajer�a '|| msj.cod_mensaje || ' Recibida';
         end if;
         --Se concatena los datos disponibles para el env�o del Mail.
         pas_snp.pr_set_texto( v_txt_mail, msj.descripcion || ': '|| msj.valor, pas_snp.fu_obt_salto );
         --Se concatenan los errores de formato que pudieron ocurrir
         if msj.err_formato is not null then
            pas_snp.pr_set_texto( v_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
         end if;
         --Se obtiene el campo 20 (nro_referencia)
         if msj.campo = '20' then
            v_nro_referencia := substr(msj.valor, 1, 20);
         end if;
         --Se obtiene el campo 21 (nro_ref_externa)
         if msj.campo = '21' then
            v_nro_ref_externa := msj.valor;
         end if;
         if msj.campo = '28C' and v_cod_mensaje in ('940','970') then
            v_nro_ref_externa := msj.valor;
         end if;
     end loop;
     pas_snp.pr_set_texto( v_txt_mail, 'Detalle del mensaje : ' || v_msj_swift, pas_snp.fu_obt_salto || pas_snp.fu_obt_salto || pas_snp.fu_obt_salto );
     pas_snp.pr_set_texto( v_txt_mail, 'Atentamente.', pas_snp.fu_obt_salto );
   end if;

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
                             values( v_cod_mensaje,
                                     v_nro_referencia,
                                     v_nro_ref_externa,
                                     pas_snp.g_fec_actual,
                                     v_msj_swift,
                                     v_msj_swi_original,
                                     v_det_msj_error,
                                     case when p_ind_msj_recibido = 'S' then sysdate else NULL end,
                                     case when p_ind_msj_recibido = 'S' then 'R' else 'P' end
                                   );
   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el n�mero de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Error al insertar el mensaje en GE_SNP_MENSAJES: '||sqlerrm;
         raise ex_salir;
   end;

   /*
   || Env�a Correo con los detalles de la mensajer�a recibida
   */
   BEGIN
      if p_env_mail = 'S' and
         v_dir_correo is not null
      then
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if g_det_msj_error is NULL then
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || g_det_msj_error;
   end if;

EXCEPTION
   when ex_salir then
      return '99' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || fu_obt_msj_error;
   when others then
      return '99' || '|' || v_cod_mensaje || '|' || SQLERRM;

end fu_reg_msj_generico;
FUNCTION fu_pro_msj_recibidos ( p_mensaje in clob )  return varchar2
IS
   /*
   || Carga la mensajer�a recibida desde el Socket.
   */

   v_respuesta varchar2(4000);

BEGIN
   -- Inicializaci�n del sistema.
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;
   g_det_msj_error:=null;--TRFS-533
   if p_mensaje is null then
      raise_application_error(-20001, 'Mensaje nulo');
   end if;

   g_lugar := 'Iniciando verificaci�n del mensaje recibido a trav�s del PAO_PMT, ';
   --Nueva l�gica esquematizada
   v_respuesta := pao_pmt.fu_pro_mt_recibido( replace( p_mensaje, fu_obt_sal_socket, fu_obt_salto ) );
   if substr( v_respuesta, 1, 2 ) not in ( '00', '99' ) or
      upper(v_respuesta) like '%MEN%NO%ENCONT%'
   then
      g_lugar := 'Registrando el mensaje en GE_SNP_MENSAJES, ';
      v_respuesta := pas_snp.fu_reg_msj_generico(p_mensaje);
   end if;

   g_lugar := 'Registrando datos en el LOG, ';
   pas_snp.pr_reg_operacion( replace( dbms_lob.substr(p_mensaje,4000,1), pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '99|' || g_lugar || v_respuesta );

   return v_respuesta;

EXCEPTION
   when others then
      -- Si tiene ERRORES se guarda el mensaje.
      pas_snp.pr_reg_operacion( replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ), '99|' || g_lugar || sqlerrm );

      return '-1|Error durante el proceso del Mensaje '||sqlerrm;

END fu_pro_msj_recibidos;

FUNCTION fu_pro_msj_mt103( p_mensaje in long ) return varchar2
IS
   /*
   || Procesa la mensajer�a RECIBIDA - MT103.
   */

   rg_msj_rec             pas_snp.rg_msj := null;
   rg_dat_pte             pas_snp.rg_pte := null;
   rg_msj_env             pas_snp.rg_msj := null;
   v_nro_reversion        ge_snp_transferencias.nro_ref_externa%type;
   v_nro_cuenta           ge_cuentas.nro_cuenta%type;
   v_tip_doc              ba_tip_documentos.abreviatura%type := null;
   v_ref_oid              ge_snp_transferencias.ref_oid%type := null;
   v_cod_tip_doc_ben      ge_snp_transferencias.cod_tip_doc_beneficiario%type;
   v_texto                varchar2(4000) := null;
   v_sql                  varchar2(4000) := null;
   v_tip_rec_error        varchar2(100)  := null;
   v_linea                varchar2(100)  := null;
   v_campo_72             varchar2(200)  := null;
   v_tag_59a              varchar2(5)    := null;
   v_cod_moneda           varchar2(3)    := null;
   v_ind_reversion        varchar2(1)    := 'N';
   v_ind_rev_manual       varchar2(1)    := 'N';
   v_can_lineas           number         := 0;
   v_pos_ini              number         := 0;
   v_pos_fin              number         := 0;
   v_supera_limite        varchar2(1)    :='N';
   b_es_rev               boolean; --TRFS-1385
   b_es_ueno_ueno         boolean; --TCE-238
   v_doc_ueno             ba_personas.nro_documento%type; --TCE-238

BEGIN
     --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
     pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
     --
     /*Inicializa las variables de error*/
     pas_snp.pr_ini_variables;

     /*Inicializa las variables del tipo ROWTYPE*/
     pas_snp.pr_ini_registros;

     /*
     || En esta variable se almacenar� todos los errores encontrados y
     || se depositar� en el campo error de GE_SNP_TRANSFERENCIAS.
     */
     pas_snp.g_det_msj_error := null;
     --

     if p_mensaje is null then
        pas_snp.g_cod_error := 40;
        pas_snp.g_msj_error := 'Error en PAS_SNP.FU_PRO_MSJ_MT103. Valor para P_MENSAJE debe contener algun valor.!';
        pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     -- ****************************** cabecera del mensaje ********************************************
     g_lugar :=  'Obteniendo cabecera del mensaje, ';
     pas_snp.pr_pro_cab_msj_swift( p_mensaje, rg_msj_rec );
     if pas_snp.fu_obt_cod_error <> 0 then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     -- ****************************** cuerpo del mensaje **********************************************
     /**/-- :20: Referencia del remitente
     g_lugar :=  'Obteniendo campo :20:, ';
     rg_msj_rec.nro_ref_externa := ltrim(rtrim(substr(pas_snp.fu_pro_val_tag(p_mensaje, '20','N'),1,length(pas_snp.fu_pro_val_tag(p_mensaje, '20','N'))-1)));
     rg_msj_rec.nro_lote        := null;
     rg_msj_rec.nro_sec_lote    := null;
     rg_msj_rec.cod_msj_swift   := 103;
     if rg_msj_rec.nro_ref_externa is null then
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Nro. Ref. Externa no puede ser nulo.!', pas_snp.fu_obt_salto );
     end if;

     /**/-- :23B: Tipo de mensaje
     g_lugar :=  'Obteniendo campo :23B:, ';
     rg_msj_rec.tip_mensaje := substr(pas_snp.fu_pro_val_tag(p_mensaje, '23B'),1,4);
     if nvl(rg_msj_rec.tip_mensaje,'x') <> 'CRED' then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tip. Mensaje no est� correcto.!', pas_snp.fu_obt_salto );
     end if;

     /**/-- :26T: C�digo del tipo de transacci�n
     g_lugar :=  'Obteniendo campo :26T:, ';
     rg_msj_rec.cod_tip_operacion := substr(pas_snp.fu_pro_val_tag(p_mensaje,'26T'),1,3);
     v_sql := 'SELECT ''S'' '||
              'FROM   GE_SNP_PAR_MENSAJES '||
              'WHERE  COD_TIP_OPERACION = ' ||rg_msj_rec.cod_tip_operacion||' '||
              'AND    ROWNUM = 1';
     if not fu_val_dat_ingresado(v_sql) then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tip. Operaci�n no est� correcto. ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     /**/-- :32A: Fecha, Moneda y Monto
     g_lugar :=  'Obteniendo campo :32A:, fecha: ';
     rg_msj_rec.fec_recepcion := sysdate;
     rg_msj_rec.fec_valor     := to_date(substr(pas_snp.fu_pro_val_tag(p_mensaje, '32A'),1,6),'RRMMDD');
     rg_msj_rec.fec_ingreso   := g_fec_actual;

     -- Verifica que la fecha valor no sea menor a la fecha calendario del sistema
     if rg_msj_rec.fec_valor <> g_fec_actual then
        g_lugar :=  'Validando fecha valor de la mensajer�a, ';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'fecha valor no puede ser distinto a '||to_char(g_fec_actual,'DD/MM/YYYY'), pas_snp.fu_obt_salto );
     end if;

     -- Verifica que no se haya duplicado la misma mensajer�a RECIBIDA
     if nvl(fug_obt_pardinamico('SNP_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
    if pas_snp.fu_ver_msj_duplicados ( rg_msj_rec.nro_ref_externa, rg_msj_rec.fec_valor ) = 'S' then
       g_lugar :=  'Validando duplicidad de mensajer�a, ';
       pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
    end if;
     end if;

     g_lugar :=  'Obteniendo campo :32A:, cod_moneda: ';

     v_cod_moneda := substr(pas_snp.fu_pro_val_tag(p_mensaje, '32A'),7,3);
     v_cod_moneda := CASE v_cod_moneda WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE v_cod_moneda END;
     rg_msj_rec.cod_moneda := v_cod_moneda;
     v_sql := 'SELECT ''S'' '||
              'FROM   BA_MONEDAS '||
              'WHERE  COD_MONEDA = '||''''||rg_msj_rec.cod_moneda||'''';
     if not fu_val_dat_ingresado(v_sql) then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Cod. Moneda no est� correcto. ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     g_lugar :=  'Obteniendo campo :32A:, monto: ';
     rg_msj_rec.monto := to_number(replace(substr(pas_snp.fu_pro_val_tag(p_mensaje, '32A'),10),'.',','));
     if rg_msj_rec.monto is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Monto no puede ser nulo.!', pas_snp.fu_obt_salto );
     end if;

     /**/-- :52a: Cuenta y BIC del participante sucursal origen
     g_lugar :=  'Obteniendo campo :52a:, Datos del Participante Sucursal Solicitante. ';
     if pas_snp.fu_pro_val_tag(p_mensaje,'52a','N') is not null then
        v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'52a','N');

        g_lugar :=  'Obteniendo campo :52a:, Cta. Participante Sucursal Solicitante. ';
        v_pos_ini := instr(v_texto,'/D/');
        if v_pos_ini = 0 then
           v_pos_ini := instr(v_texto,'/')+1;
        else
           v_pos_ini := instr(v_texto,'/D/')+3;
        end if;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
        rg_msj_rec.nro_cta_suc_pte_solicitante := trim(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)));

        g_lugar :=  'Obteniendo campo :52a:, BIC Participante Sucursal Solicitante. ';
        v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
        rg_msj_rec.cod_swi_suc_solicitante := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Validando BIC del Participante Sucursal Solicitante, ';
        if rg_msj_rec.cod_swi_suc_solicitante is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al BIC del Participante Sucursal Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else --Busca con el BIC recibido el BIC configurado en ITGF
           pr_val_cod_swi_participante( rg_msj_rec.cod_swi_suc_solicitante );
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           end if;
        end if;

        g_lugar :=  'Validando Cta. del Participante Sucursal Solicitante, ';
        if rg_msj_rec.nro_cta_suc_pte_solicitante is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. del Participante Sucursal Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else --Valida que la cuenta y el BIC del PTE. SOLICITANTE existan en ITGF
           if pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante ) is null then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se encuentran datos para la Cta. del Participante Sucursal Solicitante '||rg_msj_rec.nro_cta_suc_pte_solicitante||'.!', pas_snp.fu_obt_salto );
           elsif pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_suc_solicitante,
                                                      CASE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante )
                                                        WHEN g_cod_mon_iso_local THEN
                                                          g_cod_mon_local
                                                        ELSE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante )
                                                      END,
                                                      rg_msj_rec.nro_cta_suc_pte_solicitante
                                                    ) = 'N'
           then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
           end if;
        end if;
     end if;

     /**/-- :53a: Cuenta y BIC del participante origen
     g_lugar :=  'Obteniendo campo :53a:, Datos del Participante Solicitante. ';
     if pas_snp.fu_pro_val_tag(p_mensaje,'53a','N') is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
     else
        v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'53a','N');
     end if;

     g_lugar :=  'Obteniendo campo :53a:, Cta. Participante Solicitante. ';
     v_pos_ini := instr(v_texto,'/D/');
     if v_pos_ini = 0 then
        v_pos_ini := instr(v_texto,'/')+1;
     else
        v_pos_ini := instr(v_texto,'/D/')+3;
     end if;
     v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
     rg_msj_rec.nro_cta_pte_solicitante := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

     g_lugar :=  'Obteniendo campo :53a:, BIC Participante Solicitante. ';
     v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
     v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
     rg_msj_rec.cod_swi_pte_solicitante := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

     g_lugar :=  'Validando BIC del Participante Solicitante, ';
     if rg_msj_rec.cod_swi_pte_solicitante is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al BIC del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
     else --Busca con el BIC recibido el BIC configurado en ITGF
        pr_val_cod_swi_participante( rg_msj_rec.cod_swi_pte_solicitante );
        if pas_snp.fu_obt_cod_error <> 0 then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
        else
           -- Obtiene datos del Participante Solicitante en caso que el BIC no tenga errores
           g_lugar :=  'Obteniendo Datos del Participante Solicitante,  ';
           pas_snp.pr_obt_dat_participante( rg_msj_rec.cod_swi_pte_solicitante,
                                            rg_dat_pte
                                          );
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
           end if;
        end if;
     end if;

     g_lugar :=  'Validando Cta. del Participante Solicitante,  ';
     if rg_msj_rec.nro_cta_pte_solicitante is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
     else --Valida que la cuenta y el BIC del PTE. SOLICITANTE existan en ITGF
        if pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_solicitante,
                                                rg_msj_rec.cod_moneda,
                                                rg_msj_rec.nro_cta_pte_solicitante
                                              ) = 'N'
        then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
        end if;
     end if;

     /**/-- :56a: Cuenta y BIC del participante sucursal destino
     g_lugar :=  'Obteniendo campo :56a:, Datos del Participante Sucursal Beneficiario. ';
     if pas_snp.fu_pro_val_tag(p_mensaje,'56a','N') is not null then
        v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'56a','N');

        g_lugar :=  'Obteniendo campo :56a:, Cta. Participante Sucursal Beneficiario. ';
        v_pos_ini := instr(v_texto,'/C/');
        if v_pos_ini = 0 then
           v_pos_ini := instr(v_texto,'/')+1;
        else
           v_pos_ini := instr(v_texto,'/C/')+3;
        end if;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
        rg_msj_rec.nro_cta_suc_pte_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Obteniendo campo :56a:, BIC Participante Sucursal Beneficiario. ';
        v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
        rg_msj_rec.cod_swi_suc_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Validando BIC del Participante Sucursal Beneficiario, ';
        if rg_msj_rec.cod_swi_suc_beneficiario is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al BIC del Participante Sucursal Beneficiario no puede ser nulo.!', pas_snp.fu_obt_salto );
        else --Busca con el BIC recibido el BIC configurado en ITGF
           pr_val_cod_swi_participante( rg_msj_rec.cod_swi_suc_beneficiario );
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           end if;
        end if;

        g_lugar :=  'Validando Cta. del Participante Sucursal Beneficiario, ';
        if rg_msj_rec.nro_cta_suc_pte_beneficiario is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. del Participante Sucursal Beneficiario no puede ser nulo.!', pas_snp.fu_obt_salto );
        else --Valida que la cuenta y el BIC del PTE. BENEFICIARIO existan en ITGF
           if pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_beneficiario ) is null then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se encuentran datos para la Cta. del Participante Sucursal Beneficiario '||rg_msj_rec.nro_cta_suc_pte_beneficiario||'.!', pas_snp.fu_obt_salto );
           elsif pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_suc_beneficiario,
                                                      CASE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_beneficiario )
                                                        WHEN g_cod_mon_iso_local THEN
                                                          g_cod_mon_local
                                                        ELSE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_beneficiario )
                                                      END,
                                                      rg_msj_rec.nro_cta_suc_pte_beneficiario
                                                    ) = 'N'
           then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
           end if;
        end if;
     end if;

     /**/-- :57a: Cuenta y BIC del participante destino,
     g_lugar :=  'Obteniendo campo :57a:, Datos del Participante Beneficiario. ';
     if pas_snp.fu_pro_val_tag(p_mensaje,'57a','N') is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
     else
        v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'57a','N');
     end if;

     g_lugar :=  'Obteniendo campo :57a:, Cta. Participante Beneficiario. ';
     v_pos_ini := instr(v_texto,'/C/');
     if v_pos_ini = 0 then
        v_pos_ini := instr(v_texto,'/')+1;
     else
        v_pos_ini := instr(v_texto,'/C/')+3;
     end if;
     v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
     rg_msj_rec.nro_cta_pte_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

     g_lugar :=  'Obteniendo campo :57a:, BIC Participante Beneficiario. ';
     v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
     v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
     rg_msj_rec.cod_swi_pte_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

     g_lugar :=  'Validando BIC del Participante Beneficiario, ';
    if instr(p_mensaje,'57C:/') = 0 then
     if rg_msj_rec.cod_swi_pte_beneficiario is null then
      pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al BIC del Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
     else --Valida que el BIC exista en ITGF
      pr_val_cod_swi_participante( rg_msj_rec.cod_swi_pte_beneficiario );
      if pas_snp.fu_obt_cod_error <> 0 then
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
     end if;
     end if;

     g_lugar :=  'Validando Cta. del Participante Beneficiario, ';
     if rg_msj_rec.nro_cta_pte_beneficiario is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
     else --Valida que la cuenta del PTE. BENEFICIARIO exista en ITGF
        if rg_msj_rec.nro_cta_pte_beneficiario <> pas_snp.fu_obt_cta_bancaria( pas_snp.fu_obt_cta_bancaria( rg_msj_rec.nro_cta_pte_beneficiario, 'C' ), 'B' ) then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Participante Beneficiario no est� definido en GE_PAR_DINAMICOS para la moneda ' || rg_msj_rec.cod_moneda , pas_snp.fu_obt_salto );
        end if;
        if pas_snp.fu_obt_cod_error <> 0 then --Envia el error generado por FUG_OBT_PARDINAMICO
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
        end if;
     end if;

     /**/-- :50a: Datos del Ordenante
     g_lugar :=  'Obteniendo campo :50a:, Datos del Cliente Solicitante. ';
     if pas_snp.fu_pro_val_tag(p_mensaje,'50a','N') is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Cliente Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
     else
        v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'50a','N');

        /**/-- 1ra. l�nea (Cuenta Solicitante)
        g_lugar :=  'Obteniendo campo :50a:, Cta. Cli. Solicitante. 1ra. l�nea. ';
        v_pos_ini := instr(v_texto,'/')+1;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1);
        rg_msj_rec.nro_cta_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,35);
        if rg_msj_rec.nro_cta_solicitante is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Cliente Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        end if;

        if nvl( rg_dat_pte.ind_val_fmt_msj_recibido, 'S' ) = 'N' then
           -- Si no se valida sintaxis de la mensajer�a el PAS_SNP debe completar los datos a partir de la 2da. l�nea
           rg_msj_rec.cod_tip_doc_solicitante := rg_dat_pte.cod_tip_doc_persona;
           rg_msj_rec.nro_doc_solicitante     := rg_dat_pte.nro_doc_persona;
           rg_msj_rec.nom_solicitante         := rg_dat_pte.nom_persona;
           rg_msj_rec.dir_solicitante         := rg_dat_pte.dir_persona;
        else -- Se debe validar sintaxis de la mensajer�a.
          /*
          || Se cuenta la cantidad de l�neas que tiene el TAG :50a:
          || (2 l�neas OBLIGATORIAS)
          || (3 l�neas OPCIONALES)
          */
          v_can_lineas := ( length( v_texto ) -
                            length( replace( v_texto, pas_snp.fu_obt_sal_socket ) )
                           ) / nvl( length( pas_snp.fu_obt_sal_socket ), 1 );

          if v_can_lineas < 2 or
             v_can_lineas > 5
          then -- Controla las l�neas permitidas
             pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo :50a: debe contener entre 2 y 5 l�neas OBLIGATORIAS.!', pas_snp.fu_obt_salto );
          else
             /**/-- 2da. l�nea (Tipo y Nro. Doc. Solicitante)
             g_lugar :=  'Obteniendo campo :50a:, Tipo y Nro. Doc. Solicitante. 2da. l�nea. ';
             v_tip_doc := null;
             v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1)+1;
             v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
             v_linea   := ltrim(rtrim(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)));

             v_tip_doc := nvl( substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 4 ), 'RUC' );
             begin -- Recupera el Cod. Tip. Documento, cualquier error retorna el c�digo para RUC
               begin
                 if fue_val_es_numerico( fue_obt_tip_documento( v_tip_doc ) ) = 'S' then
                    rg_msj_rec.cod_tip_doc_solicitante := fue_obt_tip_documento( v_tip_doc );
                    rg_msj_rec.nro_doc_solicitante     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 2, '/' ) ), 1, 20 );
                 else -- Registra el tipo de documento como RUC en caso de no encontrar en ITGF
                    raise ex_salir;
                 end if;
               exception
                 when ex_salir then
                   raise;
                 when others then
                   raise;
               end;
             exception
               when others then
                 rg_msj_rec.cod_tip_doc_solicitante := fue_obt_tip_documento( 'RUC' );
                 rg_msj_rec.nro_doc_solicitante     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 20 );
             end;

             -- Valida la 2da. l�nea, ya que son OBLIGATORIOS
             if rg_msj_rec.cod_tip_doc_solicitante is null then
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Tipo de Documento del Solicitante con el formato <XXX>/.!', pas_snp.fu_obt_salto );
             end if;

             if rg_msj_rec.nro_doc_solicitante is null then
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Nro. Documento del Solicitante.!', pas_snp.fu_obt_salto );
             end if;

             /**/-- 3ra. l�nea (Denominaci�n de la Cuenta)
             g_lugar :=  'Obteniendo campo :50a:, Nom. Cli. Solicitante. 3ra. l�nea. ';
             v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2)+1;
             v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3);
             rg_msj_rec.nom_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,120);

             /**/-- 4ta. l�nea (Direcci�n de la Cuenta)
             g_lugar :=  'Obteniendo campo :50a:, Dir. Solicitante. 5ta. l�nea. ';
             v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3)+1;
             v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,4);
             rg_msj_rec.dir_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,100);
          end if;
       end if;
     end if;
     /**/-- :59a: Datos del Beneficiario
     g_lugar :=  'Obteniendo campo :59a:, Datos del Cliente Beneficiario. ';
     -- Se busca el TAG 59 (BIC no registrado en SWIFT), sino encuentra busca el TAG 59A (BIC registrado en SWIFT)
     if pas_snp.fu_pro_val_tag(p_mensaje,'59','N') is null then
        if pas_snp.fu_pro_val_tag(p_mensaje,'59A','N') is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Cliente Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else
           v_tag_59a := '59A';
        end if;
     else
        v_tag_59a := '59';
     end if;
     if v_tag_59a is not null then
        v_texto := pas_snp.fu_pro_val_tag(p_mensaje,v_tag_59a,'N');
        /*
        || Se cuenta la cantidad de l�neas que tiene el TAG :59a:
        || (2 l�neas OBLIGATORIAS)
        || (3 l�neas OPCIONALES)
        */
        v_can_lineas := ( length( v_texto ) -
                          length( replace( v_texto, pas_snp.fu_obt_sal_socket ) )
                        ) / nvl( length( pas_snp.fu_obt_sal_socket ), 1 );

        if v_can_lineas < 2 or
           v_can_lineas > 5
        then -- Controla las l�neas permitidas
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo :59a: debe contener entre 2 y 5 l�neas OBLIGATORIAS.!', pas_snp.fu_obt_salto );
        else
           /**/-- 1ra. l�nea (Cuenta Beneficiario)
           g_lugar :=  'Obteniendo campo :59a:, Cta. Cli. Beneficiario. 1ra. l�nea. ';
           v_pos_ini := instr(v_texto,'/')+1;
           v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1);
           rg_msj_rec.nro_cta_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,35);
           if rg_msj_rec.nro_cta_beneficiario is null then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Cliente Beneficiario no puede ser nulo.!', pas_snp.fu_obt_salto );
           end if;

           /**/-- 2da. l�nea (Tipo y Nro. Doc. Beneficiario)
           g_lugar :=  'Obteniendo campo :59a:, Tipo y Nro. Doc. Beneficiario. 2da. l�nea. ';
           v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1)+1;
           v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
           v_linea   := ltrim(rtrim(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)));

           v_tip_doc := nvl( substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 4 ), 'RUC' );
           begin -- Recupera el Cod. Tip. Documento, cualquier error retorna el c�digo para RUC
             begin
               if fue_val_es_numerico( fue_obt_tip_documento( v_tip_doc ) ) = 'S' then
                  rg_msj_rec.cod_tip_doc_beneficiario := fue_obt_tip_documento( v_tip_doc );
                  rg_msj_rec.nro_doc_beneficiario := substr( trim( pao_pmt.fu_obt_linea( v_linea, 2, '/' ) ), 1, 20 );
               else -- Registra el tipo de documento como RUC en caso de no encontrar en ITGF
                  raise ex_salir;
               end if;
             exception
               when ex_salir then
                 raise;
               when others then
                 raise;
             end;
           exception
              when others then
                 rg_msj_rec.cod_tip_doc_beneficiario := fue_obt_tip_documento( 'RUC' );
                 rg_msj_rec.nro_doc_beneficiario := substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 20 );
           end;
           --TCE-238
           v_doc_ueno := fug_obt_pardinamico('RUC_CTA_UENO');
           b_es_ueno_ueno := (rg_msj_rec.nro_doc_beneficiario = v_doc_ueno and rg_msj_rec.nro_doc_solicitante = v_doc_ueno);
           IF b_es_ueno_ueno THEN
             IF v_cod_moneda = 'GS' THEN
               rg_msj_rec.nro_cta_beneficiario := fug_obt_pardinamico('CTA_LIQ_PYG');
             ELSIF v_cod_moneda = 'USD' THEN
               rg_msj_rec.nro_cta_beneficiario := fug_obt_pardinamico('CTA_LIQ_USD');
             END IF;
           END IF;
           -- Valida la 2da. l�nea, ya que son OBLIGATORIOS
           if rg_msj_rec.cod_tip_doc_beneficiario is null then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Tipo de Documento del Beneficiario con el formato <XXX>/.!', pas_snp.fu_obt_salto );
           end if;

           if rg_msj_rec.nro_doc_beneficiario is null then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Nro. Documento del Beneficiario.!', pas_snp.fu_obt_salto );
           end if;

           /**/-- 3ra. l�nea (Denominaci�n de la Cuenta)
           g_lugar :=  'Obteniendo campo :59a:, Nom. Cli. Beneficiario. 3ra. l�nea. ';
           v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2)+1;
           v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3);
           rg_msj_rec.nom_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,120);

           /**/-- 4ta. l�nea (Direcci�n de la Cuenta)
           g_lugar :=  'Obteniendo campo :59a:, Dir. Beneficiario. 5ta. l�nea. ';
           v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3)+1;
           v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,4);
           rg_msj_rec.dir_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,100);
        end if;
     end if;

     rg_msj_rec.cod_oficina := fug_obt_ofi_usuario ( user );

     g_lugar :=  'Validando Nro. Cta. del Beneficiario.  ';

     if rg_msj_rec.nro_cta_beneficiario is not null then
        -- Valida que la cuenta del beneficiario sea num�rico, si es num�rico se intenta validar contra ITGF.
        if fue_val_es_numerico( rg_msj_rec.nro_cta_beneficiario ) = 'S' then
           -- Valida que la cuenta o n�mero de tarjeta exista en ITGF.
           -- Se verifica si el dato corresponde a una Cta. o a una Tarjeta.
           if length( to_number( rg_msj_rec.nro_cta_beneficiario ) ) >= 16 then -- Posiblemente sea un Nro. de Tarjeta.
              --
              pas_snp.pr_ver_nro_tarjeta( rg_msj_rec.nro_cta_beneficiario, v_nro_cuenta );
              --
              if pas_snp.fu_obt_cod_error <> 0 then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
              end if;

           else -- Es posiblemente una Cuenta en ITGF.
              -- Si el BIC Solicitante es M. Hacienda no se debe validar el tipo de documento del beneficiario,
              -- ya que MH siempre enviar�a RUC
              if rg_msj_rec.cod_swi_pte_solicitante = g_bic_hacienda then
                 v_cod_tip_doc_ben := NULL;
              else
                 v_cod_tip_doc_ben := rg_msj_rec.cod_tip_doc_beneficiario;
              end if;

              pas_snp.pr_obt_cta_interna( rg_msj_rec.nro_cta_beneficiario,
                                          v_cod_tip_doc_ben,
                                          rg_msj_rec.nro_doc_beneficiario,
                                          v_nro_cuenta,
                                          rg_msj_rec.cod_per_beneficiario
                                        );
              --
              if pas_snp.fu_obt_cod_error <> 0 then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
              end if;
              --
           end if;

           if v_nro_cuenta is not null then
              pag_cta.pr_obt_cuenta( v_nro_cuenta );

              if pag_cta.fu_obt_cod_error <> 0 then
                 --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                 pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                 pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error||pas_snp.fu_obt_salto );
              else
                 rg_msj_rec.nro_cta_beneficiario := pag_cta.g_ctas.nro_cuenta;
                 rg_msj_rec.cod_per_beneficiario := nvl( rg_msj_rec.cod_per_beneficiario, pag_cta.g_ctas.cod_cliente );
                 rg_msj_rec.cod_oficina          := pag_cta.g_ctas.cod_oficina;
              end if;
              --Valido si es REV por medio del tag 72 TRFS-1385
              --  b_es_rev := nvl(instr(pas_snp.fu_pro_val_tag(p_mensaje,'72','N'),'/REV/',1),0) > 0;
			  -- TRFS-1392
              b_es_rev := pas_snp.fu_pro_val_reversion(p_mensaje,'72');
              if pag_cta.g_ctas.cod_moneda != rg_msj_rec.cod_moneda and not b_es_rev then --Modificado por TRFS-1228, verifica que no sea una reversion para validar la moneda PHT
                 pas_snp.g_cod_error := 66;
                 pas_snp.pr_set_texto( pas_snp.g_msj_error, 'No coincide moneda transferencia con moneda de cta', '. ' );
              end if;
                            --
              if pas_snp.fu_obt_cod_error <> 0 then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
              end if;

           end if;
        end if;
     end if;

     /**/-- 70: Concepto
     g_lugar :=  'Obteniendo campo :70:, Concepto. ';
     rg_msj_rec.concepto := substr(pas_snp.fu_pro_val_tag(p_mensaje,'70','N'),1,100);

     if rg_msj_rec.concepto is not null then
        -- Se quita el g_sal_socket en caso que haya duplicados.
        begin
          rg_msj_rec.concepto := pas_snp.fu_val_cadena(replace(fug_ver_cad_multilinea(rg_msj_rec.concepto,
                                                                                      pas_snp.fu_obt_sal_socket,
                                                                                      4,
                                                                                      35
                                                                                     ),
                                                               pas_snp.fu_obt_sal_socket,
                                                               pas_snp.fu_obt_salto
                                                              )
                                                      );
        exception
          when others then
            pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || ' ' || sqlerrm || ' ' , pas_snp.fu_obt_salto );
        end;
     end if;

     /**/-- 71A: Detalle de Cargos
     g_lugar :=  'Obteniendo campo :71A:, ';
     rg_msj_rec.tip_cargo := substr(pas_snp.fu_pro_val_tag(p_mensaje,'71A'),1,3);
     if rg_msj_rec.tip_cargo is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al tipo de cargo no puede ser nulo.!' , pas_snp.fu_obt_salto );
     else --Valida el tipo de cargo
        if not fu_obt_dat_referencias('TIP_CAR_SWIFT',substr(pas_snp.fu_pro_val_tag(p_mensaje,'71A'),1,3)) then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tipo Cargo no est� correcto. ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
        end if;
     end if;

     /**/-- 72: Informaci�n del Remitente al Receptor
     g_lugar :=  'Obteniendo campo :72:, ';
     v_campo_72 := pas_snp.fu_pro_val_tag(p_mensaje,'72','N');
     if v_campo_72 is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || ' El Tag 72 debe contener alg�n valor.! ' , pas_snp.fu_obt_salto );
     else
        if instr(v_campo_72,'/CODTYPTR/',1) > 0 then --Existe Tipo y/o Sub Tipo de Operaci�n
           v_pos_ini := instr(v_campo_72,'/CODTYPTR/',1) + 10;
           v_pos_fin := instr(v_campo_72,pas_snp.fu_obt_sal_socket,v_pos_ini);
           v_texto   := nvl(ltrim(rtrim(substr(v_campo_72,v_pos_ini,v_pos_fin - v_pos_ini))),' ');
           if instr(v_texto,'/',1) > 0 then --Tiene Tipo y Sub Tipo de Operaci�n
              v_pos_ini := instr(v_texto,'/',1) + 1;
              rg_msj_rec.cod_sub_tip_operacion := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini));
              --Verifica si campo 26T es igual a lo definido en el campo 72 (Tipo de Operaci�n)
              if nvl(rg_msj_rec.cod_tip_operacion,'x') <>
                 nvl(pas_snp.fu_val_cadena(substr(v_texto,1,instr(v_texto,'/')-1)),'.')
              then
                 pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, El campo 26T y 72 est�n inconsistentes - (Tipo de Operaci�n)', pas_snp.fu_obt_salto );
              end if;
           else
              --Verifica si campo 26T es igual a lo definido en el campo 72 (Tipo de Operaci�n)
              if nvl(rg_msj_rec.cod_tip_operacion,'x') <>
                 nvl(pas_snp.fu_val_cadena(v_texto),'.')
              then
                 pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, El campo 26T y 72 est�n inconsistentes - Tipo de Operaci�n', pas_snp.fu_obt_salto );
              end if;
           end if;
           --Si el campo 26T y el campo 72 est�n consistentes, se verifica los datos en GE_PAR_MENSAJES
           if not fu_val_par_mensajes( rg_msj_rec.cod_msj_swift,
                                       rg_msj_rec.cod_tip_operacion,
                                       rg_msj_rec.cod_sub_tip_operacion )
           then
              pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES ', pas_snp.fu_obt_salto );
           end if;
        end if;

        if instr(v_campo_72,'/REV/',1) > 0 then --Existe Instrucci�n de REVERSO /REV/, se debe reversar la operaci�n
           rg_msj_rec.observacion := substr(v_campo_72,
                                            instr(v_campo_72,'/REV/',1)
                                           );

           --PHT TTCE-50
           --Si es una reversa, no se consideran los errores anteriores de formato
           g_det_msj_error := NULL;
           --Solo se consideraran los errores de formato del campo de REV

           -- Se quita el g_sal_socket en caso que haya duplicados.
           begin
              rg_msj_rec.observacion := pas_snp.fu_val_cadena(replace(fug_ver_cad_multilinea(rg_msj_rec.observacion,
                                                                                             pas_snp.fu_obt_sal_socket,
                                                                                             6,
                                                                                             35
                                                                                            ),
                                                                      pas_snp.fu_obt_sal_socket,
                                                                      pas_snp.fu_obt_salto
                                                                     )
                                                             );
           exception
             when others then
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || ' ' || sqlerrm || ' ' , pas_snp.fu_obt_salto );
           end;

           v_ind_reversion := 'S'; -- Indicador de reversi�n

           v_pos_ini := instr(v_campo_72,'/REV/',1) + 5;
           v_pos_fin := instr(v_campo_72,pas_snp.fu_obt_sal_socket,v_pos_ini,1);

           if v_pos_fin = 0 then
              pas_snp.pr_set_texto( g_det_msj_error, 'Verificando c�digo de Rechazo. No se encuentra el c�digo de Rechazo //NNN/', pas_snp.fu_obt_salto );
           else
              -- La reversi�n contiene NUESTRO n�mero de referencia, ya que el reverso se realiza en base a un MT ENVIADO
              v_nro_reversion := ltrim( rtrim( pas_snp.fu_val_cadena( substr( v_campo_72, v_pos_ini, v_pos_fin - v_pos_ini ) ) ) );

              -- Se recupera la palabra clave /OID/ dentro del campo 72 hasta el primer salto de l�nea
              -- para actualizarlo en el MT Original
              v_ref_oid := substr( v_campo_72, -- campo 72
                                   instr( v_campo_72, '/OID/' ),       -- pos_ini
                                   instr( v_campo_72,                  -- campo 72
                                          pas_snp.fu_obt_sal_socket,                -- busca el salto del socket para cantidad de caracteres a extraer
                                          instr( v_campo_72, '/OID/' ) -- pos_ini
                                         ) -
                                   instr( v_campo_72, '/OID/' )
                                 );
           end if;

           -- Busca el tipo de rechazo que comience en una nueva l�nea seguido por //
           if instr(v_campo_72,'*//',v_pos_fin,1) > 0 then
              v_pos_ini := instr(v_campo_72,'*//',v_pos_fin,1) + 3;
           end if;
           v_pos_fin := v_pos_ini + 3;
           --

           g_lugar :=  'Obteniendo campo :72:, Tipo Rechazo, ';
           rg_msj_rec.tip_rechazo := substr( v_campo_72, v_pos_ini, v_pos_fin - v_pos_ini );
           -- Verifica si existe el tipo de rechazo en el DOMINIO TIP_REC_SNP
           begin
              select a.val_minimo
                into rg_msj_rec.tip_rechazo
                from ba_cod_referencias a
               where a.dominio = 'TIP_REC_SNP'
                 and a.val_minimo = rg_msj_rec.tip_rechazo;
           exception
              when no_data_found then
                 v_tip_rec_error        := 'C�digo de rechazo ' || rg_msj_rec.tip_rechazo || ' inexistente.';
                 rg_msj_rec.tip_rechazo := 999;
           end;

           if v_nro_reversion is null then
              v_ind_rev_manual := 'S';
              pas_snp.pr_set_texto( g_det_msj_error, 'El Nro. Referencia para la Reversi�n no puede ser nulo.!' , pas_snp.fu_obt_salto );
           elsif fue_val_es_numerico( v_nro_reversion ) <> 'S' then
              v_ind_rev_manual := 'S';
              pas_snp.pr_set_texto( g_det_msj_error, 'El Nro. Referencia no contiene un formato apropiado para la Reversi�n.!' , pas_snp.fu_obt_salto );
           else
              -- Verifica que el MT Reversi�n tenga datos del MT Original ( Nro_cuenta, Monto iguales )
              begin
                 pas_snp.pr_obt_mensaje( v_nro_reversion, 'N' );

                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto ( g_det_msj_error, 'Intentando reversar la operaci�n original, '||pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                 else -- Si no tiene ERRORES
                    -- Descargar pas_snp.g_msj en rg_msg_original para usos futuros
                    rg_msj_env             := pas_snp.fu_obt_reg_transferencias;
                    rg_msj_env.tip_rechazo := rg_msj_rec.tip_rechazo;
                    rg_msj_env.ref_oid     := nvl( v_ref_oid, rg_msj_env.ref_oid );
                    --
                    -- Limpia la variable pas_snp.g_msj
                    pas_snp.pr_ini_registros;
                    --
                    if fue_val_es_numerico( rg_msj_env.nro_cta_solicitante ) = 'S' and
                       fue_val_es_numerico( rg_msj_rec.nro_cta_beneficiario ) = 'S'
                    then
                       if to_number(rg_msj_env.nro_cta_solicitante) <> to_number( nvl( rg_msj_rec.nro_cta_beneficiario, 0 ) ) then
                          v_ind_rev_manual := 'S';
                          pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original. Nro. Cta. Original no concuerda con MT de Reversi�n', pas_snp.fu_obt_salto );
                       end if;
                    else -- Uno de los datos no es num�rico.
                       if rg_msj_env.nro_cta_solicitante <> nvl( rg_msj_rec.nro_cta_beneficiario, 0 ) then
                          v_ind_rev_manual := 'S';
                          pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original. Nro. Cta. MT Original no concuerda con MT de Reversi�n', pas_snp.fu_obt_salto );
                       end if;
                    end if;
                    if rg_msj_env.monto <> nvl( rg_msj_rec.monto, 0 ) then
                       v_ind_rev_manual := 'S';
                       pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original. Monto del MT Original no concuerda con MT de Reversi�n', pas_snp.fu_obt_salto );
                    end if;

                    if ( rg_msj_rec.fec_valor - g_dia_max_reversion ) > rg_msj_env.fec_valor then
                       v_ind_rev_manual := 'S';
                       pas_snp.pr_set_texto ( g_det_msj_error, 'El valor de la fecha de reversi�n es posterior al rango configurado en el par�metro din�mico SNP_DIA_MAX_REVERSION el cual es de (' || g_dia_max_reversion || ') dia(s)', pas_snp.fu_obt_salto );
                    end if;

                    if v_ind_rev_manual = 'N' then
                       begin
                          -- Se env�a el MT Original para ser rechazado
                          prg_cre_savepoint('rechazo');
                          pas_spi.g_reversion:='S';
                          pas_snp.pr_pro_msj_rechazado ( rg_msj_env );
                          pas_spi.g_reversion:='N';
                          if pas_snp.fu_obt_cod_error <> 0 then
                             raise ex_salir;
                          else
                             rg_msj_rec.estado := 'R';
                             --circular 007
                             pas_snp.pr_env_alerta( rg_msj_rec, 'R' );
                          end if;
                       exception
                          when ex_salir then
                             v_ind_rev_manual := 'S';
                             prg_rol_savepoint('rechazo');
                             pas_snp.pr_set_texto ( g_det_msj_error, 'Ejecutando proceso de RECHAZO, '||pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                          when others then
                             v_ind_rev_manual := 'S';
                             prg_rol_savepoint('rechazo');
                             pas_snp.pr_set_texto ( g_det_msj_error, 'Ejecutando proceso de RECHAZO, '||sqlerrm, pas_snp.fu_obt_salto );
                       end;
                    end if;
                 end if;
              exception
                 when others then
                    v_ind_rev_manual := 'S';
                    pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original - '||sqlerrm, pas_snp.fu_obt_salto );
              end;
           end if;

           -- Si la reversi�n tiene alg�n ERROR enviar� un MAIL y
           -- se cancelar� autom�ticamente el mensaje de reversi�n RECIBIDO.
           if g_det_msj_error is not null then
              rg_msj_rec.estado := 'C';
           end if;
        else --Existe valor para el campo 72, se busca el valor a partir de la segunda l�nea si existe
          if instr(v_campo_72,'/CODTYPTR/',1) > 0 then
             rg_msj_rec.observacion := substr(v_campo_72,
                                              instr(v_campo_72,pas_snp.fu_obt_sal_socket,instr(v_campo_72,'/CODTYPTR/',1)+10) + 1
                                             );
          else
             rg_msj_rec.observacion := substr(v_campo_72,
                                              instr(v_campo_72,pas_snp.fu_obt_sal_socket,1)
                                             );
          end if;
          if rg_msj_rec.observacion is not null then
             -- Se quita el g_sal_socket en caso que haya duplicados.
             begin
                rg_msj_rec.observacion := pas_snp.fu_val_cadena(replace(fug_ver_cad_multilinea(rg_msj_rec.observacion,
                                                                                               pas_snp.fu_obt_sal_socket,
                                                                                               6,
                                                                                               35
                                                                                              ),
                                                                        pas_snp.fu_obt_sal_socket,
                                                                        pas_snp.fu_obt_salto
                                                                       )
                                                               );
             exception
               when others then
                  pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || ' ' || sqlerrm || ' ' , pas_snp.fu_obt_salto );
             end;
          end if;
        end if;
     end if;

     -- ********************************* fin del texto ************************************************

     -- Se Inserta en ge_snp_transferencias
     BEGIN

        rg_msj_rec.nro_referencia := fu_obt_sig_nro_referencia;
        rg_msj_rec.cod_modulo     := pas_snp.fu_obt_cod_mod_padre;
        rg_msj_rec.cod_modalidad  := pas_snp.fu_obt_cod_mad_padre;
        rg_msj_rec.msj_swift      := replace(p_mensaje,pas_snp.fu_obt_sal_socket,pas_snp.fu_obt_salto);
        rg_msj_rec.ind_valor      := 'S'; --(S) Alto Valor
        rg_msj_rec.situacion      := 'R';
        rg_msj_rec.estado         := nvl( rg_msj_rec.estado, 'S' );
        rg_msj_rec.origen         := 'I';
        rg_msj_rec.plataforma     := 'X';
        rg_msj_rec.indemnizado    := 'N';

        if v_ind_reversion = 'N' then

           -- Verifica si la Transferencia tiene cumplimiento
           if not pas_snp.fu_val_perfil ( rg_msj_rec ) then
              -- Se comenta la captura del error por incumplimiento, ya que se pide que solo envie mail de aviso y no levantar en WF.
              -- pas_snp.pr_set_texto( g_det_msj_error, 'El monto de la transferencia sobrepasa el cumplimiento configurado.', pas_snp.fu_obt_salto );
              NULL;
           end if;

           -- Verifica que la mensajer�a no est� DUPLICADA
           if nvl(fug_obt_pardinamico('SNP_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
        if pas_snp.fu_ver_mov_duplicados( rg_msj_rec ) > 0 then
         pas_snp.pr_set_texto( g_det_msj_error, 'La mensajer�a tiene movimientos similares.', pas_snp.fu_obt_salto );
        end if;
           end if;
        end if;

        if g_det_msj_error is not null then
           rg_msj_rec.error     := g_det_msj_error;
           rg_msj_rec.situacion := 'E';
        end if;
        --valida credito a modalides especificas( cuenta basica) MGF --BINDESK-254
        BEGIN
          IF v_ind_reversion='N' THEN --BINDESK-1943

             v_supera_limite := NVL(fua_obt_limite_cta_basica(rg_msj_rec.nro_cta_beneficiario,
                                    rg_msj_rec.monto,
                                    rg_msj_rec.fec_valor,
                                    pag_cta.g_ctas.cod_modalidad,
                                    rg_msj_rec.cod_moneda), 'N');

             -- Usamos las variables creadas para realizar la validaci�n.
             IF v_supera_limite = 'S' THEN
                rg_msj_rec.tip_rechazo := '006';
                rg_msj_rec.error       := 'Error: Supera Limite Cta. Basica.';
             END IF;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
          NULL;
        END;

        g_lugar :=  'Insertando MT 103.., ';
        pr_ins_transferencias ( rg_msj_rec );

        if pas_snp.fu_obt_cod_error <> 0 then
           raise ex_salir;
        end if;

        -- Luego de insertar la mensajer�a, env�a mail por la inconsistencia del Tipo de Rechazo (si aplica)
        if v_tip_rec_error is not null then
           pas_snp.pr_env_mail( g_err_dir_correo,
                                'MT103 - Error al buscar el tipo de rechazo para la mensajer�a recibida - SNP',
                                rg_msj_rec,
                                v_tip_rec_error
                              );
        end if;
        --

        if v_ind_reversion = 'N' then -- Si no es REVERSION

           if rg_msj_rec.error is not null then -- Si tiene ERRORES
              if nvl( rg_msj_rec.monto, 0 ) > nvl( fug_obt_pardinamico( p_parametro  => 'SNP_MTO_MAX_REC_AUTOMATICO',
                                                                        p_cod_moneda => rg_msj_rec.cod_moneda
                                                                      ), 0
                                                 )
              then
                 /* Intenta enviar al Workflow si todo esta OK pero con errores,
                 || se asigna un error para la generaci�n del Workflow
                 */
                 rg_msj_rec.indemnizado := 'S';
                 pas_snp.pr_set_transferencias ( rg_msj_rec );
                 pas_snp.pr_ini_workflow( rg_msj_rec );
                 return '00' || '|' || 'MT103' || '|' || rg_msj_rec.nro_referencia || ' - Procesado con errores (WF)';
              else -- Intenta retornar la Mensajer�a si existe un MT de confirmaci�n
                 if pas_snp.fu_obt_msj_confirmacion ( rg_msj_rec.cod_msj_swift,
                                                      rg_msj_rec.nro_ref_externa,
                                                      rg_msj_rec.fec_valor,
                                                      v_ref_oid
                                                    ) = '910'
                 then
                    -- Si existe Msj de Confirmaci�n MT910, Obtengo el OID.
                    rg_msj_rec.ref_oid := nvl( v_ref_oid, rg_msj_rec.ref_oid );

                    -- Y env�o la Transferencia de Rechazo
                    begin
                       prg_cre_savepoint('rechazo');
                       pas_snp.pr_pro_msj_rechazado( rg_msj_rec );
                       if pas_snp.fu_obt_cod_error <> 0 then
                          pas_snp.pr_set_texto( pas_snp.g_msj_error,
                                                'Debe registrar una mensajer�a de REVERSION de forma MANUAL para enviar al SIPAP.',
                                                pas_snp.fu_obt_salto
                                              );
                          pas_snp.pr_env_mail( g_err_dir_correo,
                                               'MT103 - Error al intentar reversar autom�ticamente la mensajer�a recibida - SNP',
                                               rg_msj_rec,
                                               pas_snp.fu_obt_msj_error
                                             );
                          -- Se adjunta el error enviado por mail al mensaje recibido.
                          pas_snp.pr_set_texto( rg_msj_rec.error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                          rg_msj_rec.estado := 'C';
                          raise ex_salir;
                       else
                          rg_msj_rec.estado := 'R';
                       end if;
                    exception
                      when ex_salir then
                        prg_rol_savepoint('rechazo');
                        pas_snp.pr_set_texto ( rg_msj_rec.error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                      when others then
                        prg_rol_savepoint('rechazo');
                        pas_snp.pr_set_texto ( rg_msj_rec.error, sqlerrm, pas_snp.fu_obt_salto );
                    end;
                    --
                    pas_snp.pr_set_transferencias ( rg_msj_rec );
                    --
                    return '00' || '|' || 'MT103' || '|' || rg_msj_rec.nro_referencia || ' - Operaci�n Reversada por error en la Mensajer�a.';
                 else -- Tiene errores pero no se encontr� su MT de confirmaci�n.
                   return '00' || '|' || 'MT103' || '|' || rg_msj_rec.nro_referencia || ' - Procesado con errores';
                 end if;
              end if;
           elsif ( ( nvl( rg_msj_rec.monto, 0 ) > nvl( fug_obt_pardinamico( p_parametro  => 'SNP_MTO_MAX_ACR_AUTOMATICA',
                                                                            p_cod_moneda => rg_msj_rec.cod_moneda
                                                                          ), 0
                                                     )
                   ) or ( nvl( pas_snp.fu_ver_seg_cliente( rg_msj_rec.cod_per_beneficiario ), 'N' ) = 'S' )
                 )
           then
              /*
              || Luego de haber verificado todos los datos posibles, se verifica
              || - Si la mensajer�a ES RECIBIDA dependiendo del monto se procesar� directamente o
              ||   bien se inicializar�a circuito para su verificaci�n.
              || - Si el Cliente est� asociado a un Sector se inicializar�a circuito para su verificaci�n.
              || - Si el Cliente se encuentra en lista de CUMPLIMIENTO se inicializar�a circuito para su verificaci�n.
              || - Si el MT RECIBIDO NO ES de REVERSION.
              */
              -- Debe inicializar circuito para su verificaci�n
              if pas_snp.fu_obt_cod_error <> 0 then
                 -- Si la funci�n pas_snp.FU_VER_SEC_CLIENTE tiene errores se levanta WF por error.
                 rg_msj_rec.situacion := 'E';
                 pas_snp.pr_set_texto ( rg_msj_rec.error, pas_snp.fu_obt_msj_error, ' ' );
              else
                 rg_msj_rec.situacion := 'I';
              end if;
              if pas_snp.fu_obt_msj_confirmacion ( rg_msj_rec.cod_msj_swift,
                                                   rg_msj_rec.nro_ref_externa,
                                                   rg_msj_rec.fec_valor,
                                                   v_ref_oid
                                                 ) = '910'
              then -- Verifica si ya tiene alg�n mensaje de Confirmaci�n previo para as� poder generar movimientos
                 -- Actualiza el campo REF_OID si es que est� nulo, esto es para casos de retorno de operaciones
                 rg_msj_rec.ref_oid := nvl( v_ref_oid, rg_msj_rec.ref_oid );
              end if;
              rg_msj_rec.indemnizado := 'S';
              pas_snp.pr_set_transferencias( rg_msj_rec );
              pas_snp.pr_ini_workflow( rg_msj_rec );
              return '00' || '|' || 'MT103' || '|' || rg_msj_rec.nro_referencia || ' - Procesado OK (WF)';
           elsif pas_snp.fu_obt_msj_confirmacion ( rg_msj_rec.cod_msj_swift,
                                                   rg_msj_rec.nro_ref_externa,
                                                   rg_msj_rec.fec_valor,
                                                   v_ref_oid
                                                 ) = '910'
           then -- Verifica si ya tiene alg�n mensaje de Confirmaci�n previo para as� poder generar movimientos

              -- Actualiza el campo REF_OID si es que est� nulo, esto es para casos de retorno de operaciones
              rg_msj_rec.ref_oid := nvl( v_ref_oid, rg_msj_rec.ref_oid );

              -- Ejecuta el pas_snp.PR_PRO_PRINCIPAL para intentar generar movimientos
              rg_msj_rec.situacion := 'L';
              rg_msj_rec.estado    := 'A';
              pas_snp.pr_set_transferencias ( rg_msj_rec );
              --
              return '00' || '|' || 'MT103' || '|' || rg_msj_rec.nro_referencia || ' - Procesado OK';
           elsif g_det_msj_error is null then -- NO TIENE ERRORES
              return '00' || '|' || 'MT103' || '|' || rg_msj_rec.nro_referencia || ' - Procesado OK';
           end if;
        elsif v_ind_reversion = 'S' then -- Si es REVERSION
           if rg_msj_rec.error is not null then -- Si tiene ERRORES
              /*
              || Si la reversi�n tiene alg�n ERROR:
              || 1. Enviar� correo avisando que el proceso tuvo alg�n error durante la reversi�n de operaciones,
              || 2. Mensaje de Reversi�n RECIBIDA                   : estado = (C) y situaci�n = (E)rror,
              || 3. Mensaje original a ser REVERSADO si encuentra(*): estado = (A)probado y situaci�n = (C)ancelado.
              ||
              || (*)Esto es para que el PRG_REV_OPERACIONES no emita alg�n error durante la REVERSION MANUAL de la mensajer�a.
              */
              -- Si no se pudo reversar el MT por error en la sintaxis, env�a mail.
              if v_ind_rev_manual = 'S' then
                 -- Se adjunta el error al mail a ser enviado.
                 pas_snp.pr_set_texto( rg_msj_rec.error,
                                       'Debe REVERSAR la mensajer�a '||
                                       CASE
                                          when rg_msj_env.nro_referencia is not null then
                                            'EMITIDA'
                                          else
                                            'RECIBIDA'
                                        END ||' de forma MANUAL en ITGF.',
                                        pas_snp.fu_obt_salto
                                     );
              end if;

              if rg_msj_env.nro_referencia is not null then
                 pas_snp.pr_env_mail( g_err_dir_correo,
                                      'MT103 - Error al intentar realizar el proceso de reversi�n de la mensajer�a emitida - SNP',
                                      rg_msj_env,
                                      'Se ha encontrado errores en el MT Recibido : ' || pas_snp.fu_obt_salto || rg_msj_rec.error || pas_snp.fu_obt_salto
                                    );

                 if nvl( rg_msj_env.situacion, '~' ) <> 'C' then
                    rg_msj_env.situacion := 'C';
                    pas_snp.pr_set_transferencias ( rg_msj_env );

                 end if;
              else
                 pas_snp.pr_env_mail( g_err_dir_correo,
                                      'MT103 - Error al intentar reversar la mensajer�a emitida - SNP',
                                      rg_msj_rec,
                                      rg_msj_rec.error
                                    );
              end if;
              return '00' || '|' || 'MT103' || '|' || rg_msj_env.nro_referencia || ' - Reversi�n Procesada con errores';
           else -- Si no tiene ERRORES
              return '00' || '|' || 'MT103' || '|' || rg_msj_rec.nro_referencia || ' - Procesado Reversi�n OK';
           end if;
        end if;

        return 99 || '|' || 'MT103' || '|' || 'Error inesperado';

     EXCEPTION
        when ex_salir then
           raise ex_salir;
        when others then
           raise;
     END;
EXCEPTION
  when ex_salir then
     return 99 || '|' || 'MT103' || '|' || g_lugar || ' - ' || pas_snp.fu_obt_msj_error;
  when others then
     return 99 || '|' || 'MT103' || '|' || g_lugar || ' - ' || SQLERRM;
END fu_pro_msj_mt103;

FUNCTION fu_pro_msj_mt202( p_mensaje in long ) return varchar2
IS
   /*
   || Procesa la mensajer�a RECIBIDA - MT202.
   */
   v_cod_mensaje       sb_snp_tip_mensajes.cod_mensaje%type := 'MT202';

   rg_msj_rec          pas_snp.rg_msj := null;
   rg_msj_env          pas_snp.rg_msj := null;
   v_nro_reversion     ge_snp_transferencias.nro_ref_externa%type;
   v_nro_cuenta        ge_cta_clientes.nro_cuenta%type := NULL;
   v_ref_oid           ge_snp_transferencias.ref_oid%type := null;
   v_tip_rec_error     varchar2(100)  := null;
   v_campo_32a         varchar2(100);
   v_ind_reversion     varchar2(1) := 'N';
   v_ind_rev_manual    varchar2(1) := 'N';


BEGIN
   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --Inicializo rg_msj_rec con la cabecera
   pas_snp.pr_pro_cab_msj_swift( p_mensaje, rg_msj_rec );
   if pas_snp.fu_obt_cod_error <> 0 then
      pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
   end if;

   rg_msj_rec.nro_ref_externa := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20');
   rg_msj_rec.cod_msj_swift   := 202;
   rg_msj_rec.fec_recepcion   := sysdate;
   v_campo_32A                := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '32A');
   rg_msj_rec.fec_valor       := to_date(trim(substr(v_campo_32A,1,6)),'RRMMDD');
   rg_msj_rec.fec_ingreso     := g_fec_actual;
   rg_msj_rec.cod_moneda      := CASE ltrim(rtrim(substr(v_campo_32A,7,3))) WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE substr(v_campo_32A,7,3) END;
   rg_msj_rec.monto           := to_number(replace(substr(v_campo_32A,10),'.',','));
   -- Verifica que no se haya duplicado la misma mensajer�a RECIBIDA
   if nvl(fug_obt_pardinamico('SNP_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
    if pas_snp.fu_ver_msj_duplicados ( rg_msj_rec.nro_ref_externa, rg_msj_rec.fec_valor ) = 'S' then
     pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
    end if;
   end if;
   --Campo :52a: C�digo Swift Sucursal Solicitante
   rg_msj_rec.cod_swi_suc_solicitante := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '52a', 2);
   if rg_msj_rec.cod_swi_suc_solicitante is not null then
      --Busca con el BIC recibido el BIC configurado en ITGF
      pr_val_cod_swi_participante( rg_msj_rec.cod_swi_suc_solicitante );
      if pas_snp.fu_obt_cod_error <> 0 then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
   end if;
   --Campo :52a: Cuenta Sucursal Solicitante
   rg_msj_rec.nro_cta_suc_pte_solicitante := replace(replace(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '52a', 1), '/D/'), '/');
   if rg_msj_rec.nro_cta_suc_pte_solicitante is not null then
      --Valida que la cuenta y el BIC del PTE. SOLICITANTE existan en ITGF
      if pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante ) is null then
         pas_snp.pr_set_texto ( g_det_msj_error, 'No se encuentran datos para la Cta. del Participante Sucursal Solicitante '||rg_msj_rec.nro_cta_suc_pte_solicitante||'.!', pas_snp.fu_obt_salto );
      elsif pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_suc_solicitante,
                                                 CASE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante )
                                                   WHEN g_cod_mon_iso_local THEN
                                                     g_cod_mon_local
                                                   ELSE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante )
                                                  END,
                                                 rg_msj_rec.nro_cta_suc_pte_solicitante
                                               ) = 'N'
      then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
      end if;
   end if;
   --Campo :53a: BIC del participante solicitante
   rg_msj_rec.cod_swi_pte_solicitante := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '53a', 2);
   if rg_msj_rec.cod_swi_pte_solicitante is not null then
      --Busca con el BIC recibido el BIC configurado en ITGF
      pr_val_cod_swi_participante( rg_msj_rec.cod_swi_pte_solicitante );
      if pas_snp.fu_obt_cod_error <> 0 then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
   end if;
   --Campo :53a: Cuenta del participante solicitante
   rg_msj_rec.nro_cta_pte_solicitante := replace(replace(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '53a', 1), '/D/'), '/');
   if rg_msj_rec.nro_cta_pte_solicitante is not null then
   --SPI
      if rg_msj_rec.nro_cta_pte_solicitante = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
        --Valida que la cuenta reserva-LBTR y el BIC del PTE. SOLICITANTE existan en ITGF
        if pas_spi.fu_val_cta_lbtr_reserva( rg_msj_rec.cod_swi_pte_solicitante,
                                                rg_msj_rec.cod_moneda,
                                                rg_msj_rec.nro_cta_pte_solicitante
                                              ) = 'N'
        then
           pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
        end if;
      else
        --Valida que la cuenta y el BIC del PTE. SOLICITANTE existan en ITGF
        if pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_solicitante,
                                                rg_msj_rec.cod_moneda,
                                                rg_msj_rec.nro_cta_pte_solicitante
                                              ) = 'N'
        then
           pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
        end if;
      end if;
   end if;
   --Campo :57a: BIC de la Sucursal del participante beneficiario
   rg_msj_rec.cod_swi_suc_beneficiario := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '57a', 2);
   if rg_msj_rec.cod_swi_suc_beneficiario is not null then
      --Busca con el BIC recibido el BIC configurado en ITGF
      pr_val_cod_swi_participante( rg_msj_rec.cod_swi_suc_beneficiario );
      if pas_snp.fu_obt_cod_error <> 0 then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
   end if;
   --Campo :57a: Cuenta Sucursal participante beneficiario
   rg_msj_rec.nro_cta_suc_pte_beneficiario := replace(replace(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '57a', 1), '/C/'), '/');
   if rg_msj_rec.nro_cta_suc_pte_beneficiario is not null then
      --Valida que la cuenta y el BIC del PTE. BENEFICIARIO existan en ITGF
      if pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_beneficiario ) is null then
         pas_snp.pr_set_texto ( g_det_msj_error, 'No se encuentran datos para la Cta. del Participante Sucursal Beneficiario '||rg_msj_rec.nro_cta_suc_pte_beneficiario||'.!', pas_snp.fu_obt_salto );
      elsif pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_suc_beneficiario,
                                                 CASE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_beneficiario )
                                                 WHEN g_cod_mon_iso_local THEN
                                                      g_cod_mon_local
                                                 ELSE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_beneficiario )
                                                 END,
                                                 rg_msj_rec.nro_cta_suc_pte_beneficiario
                                               ) = 'N'
      then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
      end if;
   end if;
   --Campo :58a: BIC del participante beneficiario
   rg_msj_rec.cod_swi_pte_beneficiario := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '58a', 2);
   if rg_msj_rec.cod_swi_pte_beneficiario is not null then
      --Valida que el BIC exista en ITGF
      pr_val_cod_swi_participante( rg_msj_rec.cod_swi_pte_beneficiario );
      if pas_snp.fu_obt_cod_error <> 0 then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
   end if;
   --Campo :58a: Cuenta del participante beneficiario
   rg_msj_rec.nro_cta_pte_beneficiario := replace(replace(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '58a', 1), '/C/'), '/');
   if rg_msj_rec.nro_cta_pte_beneficiario is not null then
      --SPI
      if rg_msj_rec.nro_cta_pte_beneficiario = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
        --Valida que la cuenta reserva-LBTR y el BIC del PTE. BENEFICIARIO existan en ITGF
        if pas_spi.fu_val_cta_lbtr_reserva( rg_msj_rec.cod_swi_pte_beneficiario,
                                              rg_msj_rec.cod_moneda,
                                              rg_msj_rec.nro_cta_pte_beneficiario
                                            ) = 'N'
        then
           pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
        end if;
      else
      --Valida que la cuenta del PTE. BENEFICIARIO exista en ITGF
      if pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_beneficiario,
                                              rg_msj_rec.cod_moneda,
                                              rg_msj_rec.nro_cta_pte_beneficiario
                                            ) = 'N'
      then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
    end if;
   end if;

   -- Para los tipos de Operaci�n D�bitos/Cr�ditos Directos por Compensaci�n,
   -- la Cuenta de nuestra Entidad pueden venir:
   -- � en el campo :53: (D�bito Directo)
   -- � en el campo :58: (Cr�bito Directo)

   --SPI
  if rg_msj_rec.nro_cta_pte_solicitante = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
     v_nro_cuenta := pas_spi.fu_obt_cta_lbtr_reserva(rg_msj_rec.nro_cta_pte_solicitante, 'C');
     if pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_beneficiario,
                                              rg_msj_rec.cod_moneda,
                                              rg_msj_rec.nro_cta_pte_beneficiario
                                            ) = 'N' then
        pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
 elsif rg_msj_rec.nro_cta_pte_solicitante = pas_snp.fu_obt_cta_bancaria( pas_snp.fu_obt_cta_bancaria( rg_msj_rec.nro_cta_pte_solicitante, 'C' ), 'B' ) then
      v_nro_cuenta := pas_snp.fu_obt_cta_bancaria( rg_msj_rec.nro_cta_pte_solicitante, 'C' );
      if pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_beneficiario,
                                              rg_msj_rec.cod_moneda,
                                              rg_msj_rec.nro_cta_pte_beneficiario
                                            ) = 'N'
      then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;
  --SPI
  elsif rg_msj_rec.nro_cta_pte_beneficiario = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
       v_nro_cuenta := pas_spi.fu_obt_cta_lbtr_reserva(rg_msj_rec.nro_cta_pte_beneficiario, 'C');
       if pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_solicitante,
                                              rg_msj_rec.cod_moneda,
                                              rg_msj_rec.nro_cta_pte_solicitante
                                            ) = 'N' then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
       end if;
  elsif rg_msj_rec.nro_cta_pte_beneficiario = -- Busca la Cta. de nuestra entidad en el campo de Pte. Beneficiario
      pas_snp.fu_obt_cta_bancaria( pas_snp.fu_obt_cta_bancaria( rg_msj_rec.nro_cta_pte_beneficiario, 'C' ), 'B' )
   then
      v_nro_cuenta := pas_snp.fu_obt_cta_bancaria( rg_msj_rec.nro_cta_pte_beneficiario, 'C' );

      if pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_solicitante,
                                              rg_msj_rec.cod_moneda,
                                              rg_msj_rec.nro_cta_pte_solicitante
                                            ) = 'N'
      then
         pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      end if;

   end if;

   -- Seteo las variables de error ya que para los campos de Nro. Cta. Pte. Solicitante y Beneficiario
   -- solamente se necesita validar y no adjuntar los errores encontrados el detalle de error.
   pas_snp.pr_ini_variables;
   --

   if v_nro_cuenta is not null then
      pag_cta.pr_obt_cuenta(v_nro_cuenta);
      rg_msj_rec.cod_oficina := pag_cta.g_ctas.cod_oficina;
   end if;
   --

   rg_msj_rec.cod_tip_operacion := pao_pmt.fu_obt_linea(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72', 1), 2, '/');
   rg_msj_rec.cod_sub_tip_operacion := pao_pmt.fu_obt_linea(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72', 1), 3, '/');
   if not fu_val_par_mensajes( rg_msj_rec.cod_msj_swift,
                               rg_msj_rec.cod_tip_operacion,
                               rg_msj_rec.cod_sub_tip_operacion )
   then
      pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES ', pas_snp.fu_obt_salto );
   end if;


   rg_msj_rec.observacion := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72');

   if pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72', 1) like '%/REV/%' then
      v_nro_reversion := pao_pmt.fu_obt_linea(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72', 1), 2, '/');
      rg_msj_rec.ref_oid := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72', 2);
      rg_msj_rec.tip_rechazo := pao_pmt.fu_obt_linea(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72', 2), 2, '/');
      v_ind_reversion := 'S'; -- Indicador de reversi�n

       if v_nro_reversion is null then
          v_ind_rev_manual := 'S';
          pas_snp.pr_set_texto ( g_det_msj_error, 'El Nro. Referencia para la Reversi�n no puede ser nulo.!' , pas_snp.fu_obt_salto );
       elsif fue_val_es_numerico( v_nro_reversion ) <> 'S' then
            v_ind_rev_manual := 'S';
            pas_snp.pr_set_texto( g_det_msj_error, 'El Nro. Referencia no contiene un formato apropiado para la Reversi�n.!' , pas_snp.fu_obt_salto );
       else
          -- Verifica que el MT Reversi�n tenga datos del MT Original ( Nro_cuenta, Monto iguales )
          begin
             pas_snp.pr_obt_mensaje( v_nro_reversion, 'N' );

             if pas_snp.fu_obt_cod_error <> 0 then
                pas_snp.pr_set_texto ( g_det_msj_error, 'Intentando reversar la operaci�n original, '||pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
             else -- Si no tiene ERRORES
                -- Descargar pas_snp.g_msj en rg_msj_env para usos futuros
                rg_msj_env             := pas_snp.fu_obt_reg_transferencias;
                rg_msj_env.tip_rechazo := rg_msj_rec.tip_rechazo;
                rg_msj_env.ref_oid     := rg_msj_rec.ref_oid;
                --
                -- Limpia la variable pas_snp.g_msj
                pas_snp.pr_ini_registros;
                --

                if to_number(rg_msj_env.nro_cta_solicitante) <> to_number( nvl( rg_msj_rec.nro_cta_beneficiario, 0 ) ) or
                   rg_msj_env.monto <> nvl( rg_msj_rec.monto, 0 )
                then
                   v_ind_rev_manual := 'S';
                   pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original. Nro. Cta. y/o Monto del MT Original no concuerda con MT de Reversi�n', pas_snp.fu_obt_salto );
                end if;

                if ( rg_msj_rec.fec_valor - g_dia_max_reversion ) > rg_msj_env.fec_valor then
                   v_ind_rev_manual := 'S';
                   pas_snp.pr_set_texto ( g_det_msj_error, 'El valor de la fecha de reversi�n es posterior al rango configurado en el par�metro din�mico SNP_DIA_MAX_REVERSION el cual es de (' || g_dia_max_reversion || ') dia(s)', pas_snp.fu_obt_salto );
                end if;

                if v_ind_rev_manual = 'N' then
                   begin
                      -- Se env�a el MT Original para ser rechazado
                      prg_cre_savepoint('rechazo');
                      pas_snp.pr_pro_msj_rechazado ( rg_msj_env );
                      if pas_snp.fu_obt_cod_error <> 0 then
                         raise ex_salir;
                      else
                         rg_msj_rec.estado := 'R';
                      end if;
                   exception
                      when ex_salir then
                         v_ind_rev_manual := 'S';
                         prg_rol_savepoint('rechazo');
                         pas_snp.pr_set_texto ( g_det_msj_error, 'Ejecutando proceso de RECHAZO, '||pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                      when others then
                         v_ind_rev_manual := 'S';
                         prg_rol_savepoint('rechazo');
                         pas_snp.pr_set_texto ( g_det_msj_error, 'Ejecutando proceso de RECHAZO, '||sqlerrm, pas_snp.fu_obt_salto );
                   end;
                end if;
             end if;
          exception
             when no_data_found then
                pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original - '||sqlerrm, pas_snp.fu_obt_salto );
          end;
       end if;
   end if;
   -- Si la reversi�n tiene alg�n ERROR enviar� un MAIL y
   -- se cancelar� autom�ticamente el mensaje de reversi�n RECIBIDO.
   if g_det_msj_error is not null then
      rg_msj_rec.estado := 'C';
   end if;

   -- ********************************* fin del texto ************************************************

   --Se Inserta en ge_snp_transferencias
   BEGIN

      rg_msj_rec.nro_referencia := fu_obt_sig_nro_referencia;
      rg_msj_rec.cod_modulo     := pas_snp.fu_obt_cod_mod_padre;
      rg_msj_rec.cod_modalidad  := pas_snp.fu_obt_cod_mad_padre;
      rg_msj_rec.msj_swift      := replace(p_mensaje,pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto);
      rg_msj_rec.ind_valor      := 'S'; --(S) Alto Valor
      rg_msj_rec.situacion      := 'R';
      rg_msj_rec.estado         := nvl( rg_msj_rec.estado, 'S' );
      rg_msj_rec.origen         := 'I';
      rg_msj_rec.plataforma     := 'X';
      rg_msj_rec.indemnizado    := 'N';

      if v_ind_reversion = 'N' then -- Si no es REVERSION
         -- Verifica que la mensajer�a no est� DUPLICADA
         if nvl(fug_obt_pardinamico('SNP_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
      if pas_snp.fu_ver_mov_duplicados( rg_msj_rec ) > 0 then
         pas_snp.pr_set_texto( g_det_msj_error, 'La mensajer�a tiene movimientos similares.', pas_snp.fu_obt_salto );
       end if;
       end if;
         -- Verifica si ya tiene alg�n mensaje de Confirmaci�n previo para guardar el campo /OID/
         --Si el tag 72 tiene el valor /CODTYPTR/021/001 el mt900 no tiene /OID/
        if  pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '72', 1) not like '%/CODTYPTR/021/001%' then
             if pas_snp.fu_obt_msj_confirmacion ( rg_msj_rec.cod_msj_swift,
                                                  rg_msj_rec.nro_ref_externa,
                                                  rg_msj_rec.fec_valor,
                                                  v_ref_oid
                                                ) in ( '900', '910' )
             then
                -- Actualiza el campo REF_OID si es que est� nulo, esto es para casos de retorno de operaciones
                rg_msj_rec.ref_oid := nvl( v_ref_oid, rg_msj_rec.ref_oid );
             end if;
        else
          -- Actualiza el campo REF_OID si es que esta nulo, esto es para casos de retorno de operaciones
          rg_msj_rec.ref_oid := nvl( v_ref_oid, nvl(rg_msj_rec.ref_oid,'/OID/') );
        end if;
      end if;

      if g_det_msj_error is not null then
         rg_msj_rec.error     := g_det_msj_error;
         rg_msj_rec.situacion := 'E';
      end if;

      pr_ins_transferencias ( rg_msj_rec );

      if pas_snp.fu_obt_cod_error <> 0 then
         raise ex_salir;
      end if;

      -- Luego de insertar la mensajer�a, env�a mail por la inconsistencia del Tipo de Rechazo (si aplica)
      if v_tip_rec_error is not null then
         pas_snp.pr_env_mail( g_err_dir_correo,
                              'MT202 - Error al buscar el tipo de rechazo para la mensajer�a recibida - SNP',
                              rg_msj_rec,
                              v_tip_rec_error
                            );
      end if;
      --

      if v_ind_reversion = 'N' then -- Si no es REVERSION
         if rg_msj_rec.error is not null then -- Si tiene ERRORES
            /* Intenta enviar al Workflow si todo esta OK pero con errores,
            || se asigna un error para la generaci�n del Workflow
            */
            pas_snp.pr_ini_workflow( rg_msj_rec );
            return '00' || '|' || 'MT202' || '|' || rg_msj_rec.nro_referencia || ' - Procesado con errores (WF)';
         elsif /*( rg_msj_rec.cod_tip_operacion = '001' and
                 rg_msj_rec.cod_sub_tip_operacion = '001'
               ) or*/ -- Levantar WF OBLIGATORIO por tip_operacion 001 y sub_tip_operacion 001
               ( nvl( rg_msj_rec.monto, 0 ) > nvl( fug_obt_pardinamico( p_parametro  => 'SNP_MTO_MAX_ACR_AUTOMATICA',
                                                                        p_cod_moneda => rg_msj_rec.cod_moneda
                                                                      ), 0
                                                 ) and
                 rg_msj_rec.cod_tip_operacion not in ( '020','021','022' )
               ) -- No levantar WF por estos tipos de transacci�n
         then
            /*
            || Luego de haber verificado todos los datos posibles, se verifica
            || - Si la mensajer�a ES RECIBIDA dependiendo del monto se procesar� directamente o
            ||   bien se inicializar�a circuito para su verificaci�n.
            || - Si el MT RECIBIDO NO ES de REVERSION.
            */
            rg_msj_rec.situacion := 'I';
            --
            pas_snp.pr_set_transferencias( rg_msj_rec );
            pas_snp.pr_ini_workflow( rg_msj_rec );
            --
            return '00' || '|' || 'MT202' || '|' || rg_msj_rec.nro_referencia || ' - Procesado OK (WF)';
         elsif pas_snp.fu_obt_msj_confirmacion ( rg_msj_rec.cod_msj_swift,
                                                 rg_msj_rec.nro_ref_externa,
                                                 rg_msj_rec.fec_valor,
                                                 v_ref_oid
                                               ) in ( '900', '910' )
         then -- Verifica si ya tiene alg�n mensaje de Confirmaci�n previo para as� poder generar movimientos
            -- Ejecuta el PAS_SNP.PR_PRO_PRINCIPAL para intentar generar movimientos
            rg_msj_rec.situacion := 'L';
            rg_msj_rec.estado    := 'A';
            pas_snp.pr_set_transferencias ( rg_msj_rec );
            --
            return '00' || '|' || 'MT202' || '|' || to_char(rg_msj_rec.nro_referencia) || ' - Procesado OK';
         elsif g_det_msj_error is null then -- NO TIENE ERRORES
            return '00' || '|' || 'MT202' || '|' || to_char(rg_msj_rec.nro_referencia) || ' - Procesado OK';
         end if;
      elsif v_ind_reversion = 'S' then -- Si es REVERSION
         if rg_msj_rec.error is not null then -- Si tiene ERRORES
            /*
            || Si la reversi�n tiene alg�n ERROR:
            || 1. Enviar� correo avisando que el proceso tuvo alg�n error durante la reversi�n de operaciones,
            || 2. Mensaje de Reversi�n RECIBIDA      : estado = (C) y situaci�n = (E)rror,
            || 3. Mensaje original a ser REVERSADO(*): estado = (A)probado y situaci�n = (C)ancelado.
            ||
            || (*)Esto es para que el PRG_REV_OPERACIONES no emita alg�n error durante la REVERSION MANUAL de la mensajer�a.
            */

            -- Si no se pudo reversar el MT por error en la sintaxis, env�a mail.
            if v_ind_rev_manual = 'S' then
               -- Se adjunta el error al mail a ser enviado.
               pas_snp.pr_set_texto( rg_msj_rec.error,
                                     'Debe REVERSAR la mensajer�a '||
                                     CASE
                                        when rg_msj_env.nro_referencia is not null then
                                          'EMITIDA'
                                        else
                                          'RECIBIDA'
                                      END ||' de forma MANUAL en ITGF.',
                                      pas_snp.fu_obt_salto
                                   );
            end if;

            if rg_msj_env.nro_referencia is not null then
               pas_snp.pr_env_mail( g_err_dir_correo,
                                    'MT202 - Error al intentar realizar el proceso de reversi�n de la mensajer�a emitida - SNP',
                                    rg_msj_env,
                                    'Se ha encontrado errores en el MT Recibido : ' || pas_snp.fu_obt_salto || rg_msj_rec.error || pas_snp.fu_obt_salto
                                  );

               if nvl( rg_msj_env.situacion, '~' ) <> 'C' then
                  rg_msj_env.situacion := 'C';
                  pas_snp.pr_set_transferencias ( rg_msj_env );
               end if;
            else
               pas_snp.pr_env_mail( g_err_dir_correo,
                                   'MT202 - Error al intentar reversar la mensajer�a emitida - SNP',
                                   rg_msj_rec,
                                   rg_msj_rec.error
                                  );
            end if;
            return '00' || '|' || 'MT202' || '|' || rg_msj_env.nro_referencia || ' - Reversi�n Procesada con errores';
         else -- Si no tiene ERRORES
            return '00' || '|' || 'MT202' || '|' || rg_msj_rec.nro_referencia || ' - Procesado Reversi�n OK';
         end if;
      end if;

      return 99 || '|' || 'MT202' || '|' || 'Error inesperado';

   EXCEPTION
      when ex_salir then
        raise ex_salir;
      when others then
        raise;
   END;
EXCEPTION
  when ex_salir then
     return '99' || '|' || 'MT202' || '|' || pas_snp.fu_obt_msj_error;
  when others then
     return '99' || '|' || 'MT202' || '|' || SQLERRM;
END fu_pro_msj_mt202;

FUNCTION fu_pro_msj_mt102( p_mensaje in long ) return varchar2
IS
   /*
   || Procesa la mensajer�a RECIBIDA - MT102.
   */
   rg_msj_cab             pas_snp.rg_msj := null;
   rg_msj_det             pas_snp.rg_msj := null;
   rg_msj_env             pas_snp.rg_msj := null;
   rg_dat_pte             pas_snp.rg_pte := null;
   v_nro_reversion        ge_snp_transferencias.nro_ref_externa%type;
   v_nro_sec_lote         ge_snp_transferencias.nro_sec_lote%type;
   v_cta_cliente          ge_snp_transferencias.nro_cta_beneficiario%type;
   v_monto                ge_snp_transferencias.monto%type;
   v_cod_moneda           ge_snp_transferencias.cod_moneda%type := null;
   v_nro_cuenta           ge_cuentas.nro_cuenta%type;
   v_cod_tip_doc_ben      ge_snp_transferencias.cod_tip_doc_beneficiario%type;
   v_cab_msj_error        varchar2(4000) := null;
   v_texto                varchar2(4000) := null;
   v_sql                  varchar2(4000) := null;
   v_campo_70             varchar2(200)  := null;
   v_campo_72             varchar2(200)  := null;
   v_tip_rec_error        varchar2(100)  := null;
   v_linea                varchar2(100)  := null;
   v_tip_doc              varchar2(5)    := null;
   v_ind_reversion        varchar2(1)    := 'N';
   v_ind_rev_manual       varchar2(1)    := 'N';
   v_ban_error            varchar2(1)    := 'N';
   v_can_lineas           number         := 0;
   v_pos_ini              number         := 0;
   v_pos_fin              number         := 0;
   v_pos_reg_ini          number         := 0;
   v_pos_reg_fin          number         := 0;
   v_supera_limite        varchar2(1)    :='N';
   b_es_rev               boolean; --TRFS-1385

BEGIN
     --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
     pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
     --
     /*Inicializa las variables de error*/
     pas_snp.pr_ini_variables;

     /*Inicializa las variables del tipo ROWTYPE*/
     pas_snp.pr_ini_registros;

     /*
     || En esta variable se almacenar� todos los errores encontrados y
     || se depositar� en el campo error de GE_SNP_TRANSFERENCIAS.
     */
     pas_snp.g_det_msj_error := null;

     if p_mensaje is null then
        pas_snp.g_cod_error := 40;
        pas_snp.g_msj_error := 'Error en PAS_SNP.FU_PRO_MSJ_MT102. Valor para P_MENSAJE debe contener algun valor.!';
        pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     -- ****************************** cabecera del mensaje ********************************************
     g_lugar :=  'Obteniendo cabecera del mensaje, ';
     pas_snp.pr_pro_cab_msj_swift( p_mensaje, rg_msj_cab );
     if pas_snp.fu_obt_cod_error <> 0 then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     -- ****************************** cuerpo del mensaje **********************************************
     /**/-- 20: Referencia del remitente
     g_lugar :=  'Obteniendo campo :20:, ';
     rg_msj_cab.nro_lote        := ltrim(rtrim(substr(pas_snp.fu_pro_val_tag(p_mensaje, '20','N'),1,length(pas_snp.fu_pro_val_tag(p_mensaje, '20','N'))-1)));
     rg_msj_cab.nro_sec_lote    := null;
     rg_msj_cab.nro_ref_externa := null;
     rg_msj_cab.cod_msj_swift   := 102;

     if rg_msj_cab.nro_lote is null then
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Nro. Lote no puede ser nulo.!', pas_snp.fu_obt_salto );
     end if;

     /**/-- 23B: Tipo de mensaje
     g_lugar :=  'Obteniendo campo :23:, ';
     rg_msj_cab.tip_mensaje := substr(pas_snp.fu_pro_val_tag(p_mensaje, '23'),1,4);
     if nvl(rg_msj_cab.tip_mensaje,'x') <> 'CRED' then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tip. Mensaje no est� correcto.!', pas_snp.fu_obt_salto );
     end if;

     /**/-- 26T: C�digo del tipo de transacci�n
     g_lugar :=  'Obteniendo campo :26T:, ';
     rg_msj_cab.cod_tip_operacion := substr(pas_snp.fu_pro_val_tag(p_mensaje,'26T'),1,3);
     v_sql := 'SELECT ''S'' '||
              'FROM   GE_SNP_PAR_MENSAJES '||
              'WHERE  COD_TIP_OPERACION = ' ||rg_msj_cab.cod_tip_operacion||' '||
              'AND    ROWNUM = 1';
     if not fu_val_dat_ingresado(v_sql) then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tip. Operaci�n no est� correcto. ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     /**/-- 71A: Detalle de Cargos
     g_lugar :=  'Obteniendo campo :71A:, ';
     rg_msj_cab.tip_cargo := substr(pas_snp.fu_pro_val_tag(p_mensaje,'71A'),1,3);
     if rg_msj_cab.tip_cargo is null then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al tipo de cargo no puede ser nulo.!' , pas_snp.fu_obt_salto );
     else --Valida el tipo de cargo
        if not fu_obt_dat_referencias('TIP_CAR_SWIFT',substr(pas_snp.fu_pro_val_tag(p_mensaje,'71A'),1,3)) then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tipo Cargo no est� correcto. ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
        end if;
     end if;

     /**/-- 32A: Fecha, Moneda y Monto
     g_lugar :=  'Obteniendo campo :32A:, fecha: ';
     rg_msj_cab.fec_recepcion := sysdate;
     rg_msj_cab.fec_valor     := to_date(substr(pas_snp.fu_pro_val_tag(p_mensaje, '32A'),1,6),'RRMMDD');
     rg_msj_cab.fec_ingreso   := g_fec_actual;

     -- Verifica que la fecha valor no sea menor a la fecha calendario del sistema
     if rg_msj_cab.fec_valor <> g_fec_actual then
        g_lugar :=  'Validando fecha valor de la mensajer�a, ';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'fecha valor no puede ser distinto a '||to_char(g_fec_actual,'DD/MM/YYYY'), pas_snp.fu_obt_salto );
     end if;

     -- Verifica que no se haya duplicado la misma mensajer�a RECIBIDA
     if nvl(fug_obt_pardinamico('SNP_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
    if pas_snp.fu_ver_msj_duplicados ( rg_msj_cab.nro_lote, rg_msj_cab.fec_valor ) = 'S' then
       g_lugar :=  'Validando duplicidad de mensajer�a, ';
       pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
    end if;
     end if;

     /**/-- 72: Informaci�n del Remitente al Receptor
     g_lugar :=  'Obteniendo campo :72:, ';
     v_campo_72 := pas_snp.fu_pro_val_tag(p_mensaje,'72','N');
     if v_campo_72 is not null then
        if instr(v_campo_72,'/CODTYPTR/',1) > 0 then --Existe Tipo y/o Sub Tipo de Operaci�n
           v_pos_ini := instr(v_campo_72,'/CODTYPTR/',1) + 10;
           v_pos_fin := instr(v_campo_72,pas_snp.fu_obt_sal_socket,v_pos_ini);
           v_texto   := nvl(ltrim(rtrim(substr(v_campo_72,v_pos_ini,v_pos_fin - v_pos_ini))),' ');
           if instr(v_texto,'/',1) > 0 then --Tiene Tipo y Sub Tipo de Operaci�n
              v_pos_ini := instr(v_texto,'/',1) + 1;
              rg_msj_cab.cod_sub_tip_operacion := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini));
              --Verifica si campo 26T es igual a lo definido en el campo 72 (Tipo de Operaci�n)
              if nvl(rg_msj_cab.cod_tip_operacion,'x') <>
                 nvl(pas_snp.fu_val_cadena(substr(v_texto,1,instr(v_texto,'/')-1)),'.')
              then
                 pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, El campo 26T y 72 est�n inconsistentes - (Tipo de Operaci�n)', pas_snp.fu_obt_salto );
              end if;
           else
              --Verifica si campo 26T es igual a lo definido en el campo 72 (Tipo de Operaci�n)
              if nvl(rg_msj_cab.cod_tip_operacion,'x') <>
                 nvl(pas_snp.fu_val_cadena(v_texto),'.')
              then
                 pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, El campo 26T y 72 est�n inconsistentes - Tipo de Operaci�n', pas_snp.fu_obt_salto );
              end if;
           end if;
           --Si el campo 26T y el campo 72 est�n consistentes, se verifica los datos en GE_PAR_MENSAJES
           if not fu_val_par_mensajes( rg_msj_cab.cod_msj_swift,
                                       rg_msj_cab.cod_tip_operacion,
                                       rg_msj_cab.cod_sub_tip_operacion )
           then
              pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES ', pas_snp.fu_obt_salto );
           end if;
        end if;

        --Si existe valor para el campo 72, se busca el valor a partir de la segunda l�nea
        if instr(v_campo_72,'/CODTYPTR/',1) > 0 then
           rg_msj_cab.observacion := substr(v_campo_72,
                                            instr(v_campo_72,pas_snp.fu_obt_sal_socket,instr(v_campo_72,'/CODTYPTR/',1)+10) + 1
                                           );
        else
           rg_msj_cab.observacion := substr(v_campo_72,
                                            instr(v_campo_72,pas_snp.fu_obt_sal_socket,1)
                                           );
        end if;
        if rg_msj_cab.observacion is not null then
           -- Se quita el g_sal_socket en caso que haya duplicados.
           begin
              rg_msj_cab.observacion := pas_snp.fu_val_cadena(replace(fug_ver_cad_multilinea(rg_msj_cab.observacion,
                                                                                             pas_snp.fu_obt_sal_socket,
                                                                                             5,
                                                                                             35
                                                                                            ),
                                                                      pas_snp.fu_obt_sal_socket,
                                                                      pas_snp.fu_obt_salto
                                                                     )
                                                             );
           exception
              when others then
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || ' ' || sqlerrm || ' ' , pas_snp.fu_obt_salto );
           end;
        end if;
     end if;

     pas_snp.pr_set_texto ( v_cab_msj_error, g_det_msj_error, pas_snp.fu_obt_salto );
     if v_cab_msj_error is not null then
        v_ban_error := 'S';
     end if;

     /**/-- Obtiene los datos del detalle de la operaci�n.
     FOR i IN 1..999999 LOOP
        rg_msj_det             := null;
        rg_msj_env             := null;
        rg_dat_pte             := null;
        rg_msj_det             := rg_msj_cab;
        g_det_msj_error        := null;
        v_tip_rec_error        := null;
        v_pos_reg_fin          := 0;
        v_ind_reversion        := 'N';
        v_ind_rev_manual       := 'N';
        v_cta_cliente          := null;
        v_monto           := 0;
        pas_snp.pr_ini_registros;

        --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
        pre_cam_for_numerico(',.');
        --

        /*
        || Si encuentra la posici�n :21:, busca la siguiente posici�n :21: o
        || si es fin de archivo busca la posici�n del :32A:
        */
        v_pos_reg_ini := instr(p_mensaje,':21:', 1, i);

        if v_pos_reg_ini = 0 then
           exit;
        else
           v_pos_reg_fin := instr(p_mensaje,':21:', 1, i+1);

           if v_pos_reg_fin = 0 then
              v_pos_reg_fin := instr(p_mensaje,':32A:', 1, 1);
           end if;
        end if;

        g_lugar := 'Obteniendo el mensaje parcial, ';
        rg_msj_det.msj_swift := replace( ltrim( rtrim( substr( p_mensaje, v_pos_reg_ini, v_pos_reg_fin - v_pos_reg_ini ) ) ),pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );

        /**/-- 20: Referencia del remitente
        g_lugar :=  'Obteniendo campo :21:, ';
        rg_msj_det.nro_ref_externa := trim(substr(pas_snp.fu_pro_val_tag(p_mensaje, '21','N',1,i),1,length(pas_snp.fu_pro_val_tag(p_mensaje, '21','N',1,i))-1));
        rg_msj_det.nro_sec_lote    := rg_msj_det.nro_ref_externa;
        if rg_msj_det.nro_ref_externa is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Nro. Ref. Externa no puede ser nulo.!', pas_snp.fu_obt_salto );
        end if;

        g_lugar :=  'Obteniendo campo :32B:, cod_moneda: ';
        v_cod_moneda := substr(pas_snp.fu_pro_val_tag(p_mensaje, '32B','N',1,i),1,3);
        v_cod_moneda := CASE v_cod_moneda WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE v_cod_moneda END;
        rg_msj_det.cod_moneda := v_cod_moneda;
        v_sql := 'SELECT ''S'' '||
                 'FROM   BA_MONEDAS '||
                 'WHERE  COD_MONEDA = '||''''||rg_msj_det.cod_moneda||'''';
        if not fu_val_dat_ingresado(v_sql) then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Cod. Moneda no est� correcto. ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
        end if;

        g_lugar :=  'Obteniendo campo :32B:, monto: ';
        rg_msj_det.monto := to_number(replace(replace(substr(pas_snp.fu_pro_val_tag(p_mensaje, '32B','N',1,i),4),'.',','),pas_snp.fu_obt_sal_socket));
        if rg_msj_det.monto is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Monto no puede ser nulo.!', pas_snp.fu_obt_salto );
        end if;

        /**/-- :52a: Cuenta y BIC del participante origen
        g_lugar :=  'Obteniendo campo :52a:, Datos del Participante Solicitante. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'52a','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'52a','N',1,i);
        end if;

        g_lugar :=  'Obteniendo campo :52a:, Cta. Participante Solicitante. ';
        v_pos_ini := instr(v_texto,'/D/');
        if v_pos_ini = 0 then
           v_pos_ini := instr(v_texto,'/')+1;
        else
           v_pos_ini := instr(v_texto,'/D/')+3;
        end if;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
        rg_msj_det.nro_cta_pte_solicitante := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Obteniendo campo :52a:, BIC Participante Solicitante. ';
        v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
        rg_msj_det.cod_swi_pte_solicitante := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Validando BIC del Participante Solicitante,  ';

        if rg_msj_det.cod_swi_pte_solicitante is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al BIC del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else --Busca con el BIC recibido el BIC configurado en ITGF
           pr_val_cod_swi_participante( rg_msj_det.cod_swi_pte_solicitante );
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           else
              -- Obtiene datos del Participante Solicitante en caso que el BIC no tenga errores
              g_lugar :=  'Obteniendo Datos del Participante Solicitante,  ';
              pas_snp.pr_obt_dat_participante( rg_msj_det.cod_swi_pte_solicitante,
                                               rg_dat_pte
                                             );
              if pas_snp.fu_obt_cod_error <> 0 then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
              end if;
           end if;
        end if;


        g_lugar :=  'Validando Cta. del Participante Solicitante,  ';
        if rg_msj_det.nro_cta_pte_solicitante is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else --Valida que la cuenta del PTE. SOLICITANTE exista en ITGF
           if pas_snp.fu_val_cta_ban_participante( rg_msj_det.cod_swi_pte_solicitante,
                                                   rg_msj_det.cod_moneda,
                                                   rg_msj_det.nro_cta_pte_solicitante
                                                 ) = 'N'
           then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
           end if;
        end if;

        /**/-- :57a: Cuenta y BIC del participante destino,
        g_lugar :=  'Obteniendo campo :57a:, Datos del Participante Beneficiario. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'57a','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'57a','N',1,i);
        end if;

        g_lugar :=  'Obteniendo campo :57a:, Cta. Participante Beneficiario. ';
        v_pos_ini := instr(v_texto,'/C/');
        if v_pos_ini = 0 then
           v_pos_ini := instr(v_texto,'/')+1;
        else
           v_pos_ini := instr(v_texto,'/C/')+3;
        end if;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
        rg_msj_det.nro_cta_pte_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Obteniendo campo :57a:, BIC Participante Beneficiario. ';
        v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
        rg_msj_det.cod_swi_pte_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Validando BIC del Participante Beneficiario, ';
        if instr(p_mensaje,'57C:/') = 0 then
        if rg_msj_det.cod_swi_pte_beneficiario is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al BIC del Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else  --Valida que el BIC exista en ITGF
           pr_val_cod_swi_participante( rg_msj_det.cod_swi_pte_beneficiario );
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           end if;
        end if;
        end if;
        g_lugar :=  'Validando Cta. del Participante Beneficiario, ';
        if rg_msj_det.nro_cta_pte_beneficiario is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else --Valida que la cuenta del PTE. BENEFICIARIO exista en ITGF
           if rg_msj_det.nro_cta_pte_beneficiario <> pas_snp.fu_obt_cta_bancaria( pas_snp.fu_obt_cta_bancaria( rg_msj_det.nro_cta_pte_beneficiario, 'C' ), 'B' ) then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Participante Beneficiario no est� definido en GE_PAR_DINAMICOS para la moneda ' || rg_msj_det.cod_moneda , pas_snp.fu_obt_salto );
           end if;
           if pas_snp.fu_obt_cod_error <> 0 then --Envia el error generado por FUG_OBT_PARDINAMICO
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           end if;
        end if;

        /**/-- :50a: Datos del Ordenante
        g_lugar :=  'Obteniendo campo :50K:, Datos del Cliente Solicitante. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'50K','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Cliente Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'50K','N',1,i);

           -- 1ra. l�nea (Cuenta Solicitante)
           g_lugar :=  'Obteniendo campo :50K:, Cta. Cli. Solicitante. ';
           v_pos_ini := instr(v_texto,'/')+1;
           v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1);
           rg_msj_det.nro_cta_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,35);
           if rg_msj_det.nro_cta_solicitante is null then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Cliente Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
           end if;

           if nvl( rg_dat_pte.ind_val_fmt_msj_recibido, 'S' ) = 'N' then
              -- Si no se valida sintaxis de la mensajer�a el PAS_SNP debe completar los datos a partir de la 2da. l�nea
              rg_msj_det.cod_tip_doc_solicitante := rg_dat_pte.cod_tip_doc_persona;
              rg_msj_det.nro_doc_solicitante     := rg_dat_pte.nro_doc_persona;
              rg_msj_det.nom_solicitante         := rg_dat_pte.nom_persona;
              rg_msj_det.dir_solicitante         := rg_dat_pte.dir_persona;
           else -- Se debe validar sintaxis de la mensajer�a.
             /*
             || Se cuenta la cantidad de l�neas que tiene el TAG :50K:
             || (2 l�neas OBLIGATORIAS)
             || (3 l�neas OPCIONALES)
             */
             v_can_lineas := ( length( v_texto ) -
                               length( replace( v_texto, pas_snp.fu_obt_sal_socket ) )
                             ) / nvl( length( pas_snp.fu_obt_sal_socket ), 1 );

             if v_can_lineas < 2 or
                v_can_lineas > 5
             then -- Controla las l�neas permitidas
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo :50K: debe contener entre 2 y 5 l�neas OBLIGATORIAS.!', pas_snp.fu_obt_salto );
             else
                -- 2da. l�nea (Tipo y Nro. Doc. Solicitante)
                g_lugar :=  'Obteniendo campo :50K:, Tipo y Nro. Doc. Solicitante.. ';
                v_tip_doc := null;
                v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1)+1;
                v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
                v_linea   := ltrim(rtrim(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)));

                v_tip_doc := nvl( substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 4 ), 'RUC' );
                begin -- Recupera el Cod. Tip. Documento, cualquier error retorna el c�digo para RUC
                  begin
                    if fue_val_es_numerico( fue_obt_tip_documento( v_tip_doc ) ) = 'S' then
                       rg_msj_det.cod_tip_doc_solicitante := fue_obt_tip_documento( v_tip_doc );
                       rg_msj_det.nro_doc_solicitante     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 2, '/' ) ), 1, 20 );
                    else -- Registra el tipo de documento como RUC en caso de no encontrar en ITGF
                       raise ex_salir;
                    end if;
                  exception
                    when ex_salir then
                      raise;
                    when others then
                      raise;
                  end;
                exception
                  when others then
                    rg_msj_det.cod_tip_doc_solicitante := fue_obt_tip_documento( 'RUC' );
                    rg_msj_det.nro_doc_solicitante     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 20 );
                end;

                -- Valida la 2da. l�nea, ya que son OBLIGATORIOS
                if rg_msj_det.cod_tip_doc_solicitante is null then
                   pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Tipo de Documento del Solicitante con el formato <XXX>/.!', pas_snp.fu_obt_salto );
                end if;

                if rg_msj_det.nro_doc_solicitante is null then
                   pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Nro. Documento del Solicitante.!', pas_snp.fu_obt_salto );
                end if;

                -- 3ra. l�nea (Denominaci�n de la Cuenta)
                g_lugar :=  'Obteniendo campo :50K:, Nom. Cli. Solicitante. 1ra. l�nea';
                v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2)+1;
                v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3);
                rg_msj_det.nom_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,120);

                -- 4ta. l�nea (Direcci�n de la Cuenta)
                g_lugar :=  'Obteniendo campo :50K:, Dir. Solicitante. ';
                v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3)+1;
                v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,4);
                rg_msj_det.dir_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,100);

             end if;
           end if;
        end if;

        rg_msj_det.cod_oficina := fug_obt_ofi_usuario (user);

        /**/-- :59: Datos del Beneficiario
        g_lugar :=  'Obteniendo campo :59:, Datos del Cliente Beneficiario. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'59','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Cliente Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'59','N',1,i);
           /*
           || Se cuenta la cantidad de l�neas que tiene el TAG :59:
           || (2 l�neas OBLIGATORIAS)
           || (3 l�neas OPCIONALES)
           */
           v_can_lineas := ( length( v_texto ) -
                             length( replace( v_texto, pas_snp.fu_obt_sal_socket ) )
                           ) / nvl( length( pas_snp.fu_obt_sal_socket ), 1 );

           if v_can_lineas < 2 or
              v_can_lineas > 5
           then -- Controla las l�neas permitidas
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo :59: debe contener entre 2 y 5 l�neas OBLIGATORIAS.!', pas_snp.fu_obt_salto );
           else
              /**/-- 1ra. l�nea (Cuenta Beneficiario)
              g_lugar :=  'Obteniendo campo :59:, Cta. Cli. Beneficiario. 1ra. l�nea. ';
              v_pos_ini := instr(v_texto,'/')+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1);
              rg_msj_det.nro_cta_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,35);
              if rg_msj_det.nro_cta_beneficiario is null then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Cliente Beneficiario no puede ser nulo.!', pas_snp.fu_obt_salto );
              end if;

              /**/-- 2da. l�nea (Tipo y Nro. Doc. Beneficiario)
              g_lugar :=  'Obteniendo campo :59:, Tipo y Nro. Doc. Beneficiario. 2da. l�nea. ';
              v_tip_doc := null;
              v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1)+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
              v_linea   := ltrim(rtrim(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)));

              v_tip_doc := nvl( substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 4 ), 'RUC' );
              begin -- Recupera el Cod. Tip. Documento, cualquier error retorna el c�digo para RUC
                begin
                   if fue_val_es_numerico( fue_obt_tip_documento( v_tip_doc ) ) = 'S' then
                      rg_msj_det.cod_tip_doc_beneficiario := fue_obt_tip_documento( v_tip_doc );
                      rg_msj_det.nro_doc_beneficiario     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 2, '/' ) ), 1, 20 );
                   else -- Registra el tipo de documento como RUC en caso de no encontrar en ITGF
                      raise ex_salir;
                   end if;
                exception
                   when ex_salir then
                     raise;
                   when others then
                     raise;
                end;
              exception
                when others then
                  rg_msj_det.cod_tip_doc_beneficiario := fue_obt_tip_documento( 'RUC' );
                  rg_msj_det.nro_doc_beneficiario     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 20 );
              end;

              -- Valida la 2da. l�nea, ya que son OBLIGATORIOS
              if rg_msj_det.cod_tip_doc_beneficiario is null then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Tipo de Documento del Beneficiario con el formato <XXX>/.!', pas_snp.fu_obt_salto );
              end if;

              if rg_msj_det.nro_doc_beneficiario is null then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Nro. Documento del Beneficiario.!', pas_snp.fu_obt_salto );
              end if;

              /**/-- 3ra. l�nea (Denominaci�n de la Cuenta)
              g_lugar :=  'Obteniendo campo :59:, Nom. Cli. Beneficiario. 3ra. l�nea. ';
              v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2)+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3);
              rg_msj_det.nom_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,120);

              /**/-- 4ta. l�nea (Direcci�n de la Cuenta)
              g_lugar :=  'Obteniendo campo :59:, Dir. Beneficiario. 5ta. l�nea. ';
              v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3)+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,4);
              rg_msj_det.dir_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,100);

           end if;
        end if;

        rg_msj_det.cod_oficina := fug_obt_ofi_usuario ( user );

        g_lugar :=  'Validando Nro. Cta. del Beneficiario,  ';

        if rg_msj_det.nro_cta_beneficiario is not null then
           -- Valida que la cuenta del beneficiario sea num�rico, si es num�rico se intenta validar contra ITGF.
           if fue_val_es_numerico( rg_msj_det.nro_cta_beneficiario ) = 'S' then

              --Valida que la cuenta o n�mero de tarjeta exista en ITGF.
              -- Se verifica si el dato corresponde a una Cta. o a una Tarjeta.
              if length( to_number( rg_msj_det.nro_cta_beneficiario ) ) >= 16 then -- Posiblemente sea un Nro. de Tarjeta.
                 --
                 pas_snp.pr_ver_nro_tarjeta( rg_msj_det.nro_cta_beneficiario, v_nro_cuenta );
                 --
                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
                 end if;

              else -- Es posiblemente una Cuenta en ITGF.
                 -- Si el BIC Solicitante es M. Hacienda no se debe validar el tipo de documento del beneficiario,
                 -- ya que MH siempre enviar�a RUC
                 if rg_msj_det.cod_swi_pte_solicitante = g_bic_hacienda then
                    v_cod_tip_doc_ben := NULL;
                 else
                    v_cod_tip_doc_ben := rg_msj_det.cod_tip_doc_beneficiario;
                 end if;

                 pas_snp.pr_obt_cta_interna( rg_msj_det.nro_cta_beneficiario,
                                             v_cod_tip_doc_ben,
                                             rg_msj_det.nro_doc_beneficiario,
                                             v_nro_cuenta,
                                             rg_msj_det.cod_per_beneficiario
                                           );
                 --
                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
                 end if;
                 --
              end if;

              if v_nro_cuenta is not null then
                 pag_cta.pr_obt_cuenta( v_nro_cuenta );

                 if pag_cta.fu_obt_cod_error <> 0 then
                    --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                    pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                    pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error||pas_snp.fu_obt_salto );
                 else
                    rg_msj_det.nro_cta_beneficiario := pag_cta.g_ctas.nro_cuenta;
                    rg_msj_det.cod_per_beneficiario := nvl( rg_msj_det.cod_per_beneficiario, pag_cta.g_ctas.cod_cliente );
                    rg_msj_det.cod_oficina          := pag_cta.g_ctas.cod_oficina;
                 end if;

                  --Valido si es REV por medio del tag 70 TRFS-1385
                  --b_es_rev := nvl(instr(substr(substr(pas_snp.fu_pro_val_tag(p_mensaje,'70','N',1,i),1),1,100),'/REV/',1),0) > 0;
                  --TRFS-1392
                  b_es_rev := pas_snp.fu_pro_val_reversion(p_mensaje,'70',1,i);
                  if pag_cta.g_ctas.cod_moneda != rg_msj_det.cod_moneda and not b_es_rev then --Modificado por TRFS-1228, verifica que no sea una reversion para validar la moneda PHT
                     pas_snp.g_cod_error := 66;
                     pas_snp.pr_set_texto( pas_snp.g_msj_error, 'No coincide moneda transferencia con moneda de cta', '. ' );
                  end if;
                                --
                  if pas_snp.fu_obt_cod_error <> 0 then
                     pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
                  end if;

              end if;
           end if;
        end if;

        /**/-- 70: Concepto
        g_lugar :=  'Obteniendo campo :70:, Concepto. ';
        v_campo_70 := substr(substr(pas_snp.fu_pro_val_tag(p_mensaje,'70','N',1,i),1),1,100);
        if v_campo_70 is not null then
           if instr(v_campo_70,'/REV/',1) > 0 then --Existe Instrucci�n de REVERSO /REV/, se debe reversar la operaci�n

              v_ind_reversion := 'S'; -- Indicador de reversi�n

              v_pos_ini := instr(v_campo_70,'/REV/',1) + 5;
              v_pos_fin := instr(v_campo_70,pas_snp.fu_obt_sal_socket,v_pos_ini,1);

              if v_pos_fin = 0 then
                 pas_snp.pr_set_texto( g_det_msj_error, 'Verificando c�digo de Rechazo. No se encuentra el c�digo de Rechazo /NNN/', pas_snp.fu_obt_salto );
              else
                 -- La reversi�n contiene NUESTRO n�mero de referencia, ya que el reverso se realiza en base a un MT enviado
                 v_nro_sec_lote := ltrim( rtrim( substr( v_campo_70, v_pos_ini, v_pos_fin - v_pos_ini ) ) );
                 rg_msj_det.concepto := 'Reversi�n Nro. Sec. Lote ' || v_nro_sec_lote;
              end if;

              v_pos_ini := v_pos_fin + 2;
              v_pos_fin := v_pos_ini + 3;

              g_lugar :=  'Obteniendo campo :70:, Tipo Rechazo, ';
              rg_msj_det.tip_rechazo := substr( v_campo_70, v_pos_ini, v_pos_fin - v_pos_ini );
              -- Verifica si existe el tipo de rechazo en el DOMINIO TIP_REC_SNP
              begin
                 select a.val_minimo
                   into rg_msj_det.tip_rechazo
                   from ba_cod_referencias a
                  where a.dominio = 'TIP_REC_SNP'
                    and a.val_minimo = rg_msj_det.tip_rechazo;
              exception
                when no_data_found then
                   v_tip_rec_error        := 'C�digo de rechazo ' || rg_msj_det.tip_rechazo || ' inexistente.';
                   rg_msj_det.tip_rechazo := 999;
              end;

              if v_nro_sec_lote is null then
                 v_ind_rev_manual := 'S';
                 pas_snp.pr_set_texto ( g_det_msj_error, 'El Nro. Sec. Lote para la Reversi�n no puede ser nulo.!' , pas_snp.fu_obt_salto );
              else
                 -- Verifica que el MT Reversi�n tenga datos del MT Original ( Nro_cuenta, Monto iguales )
                 begin
                    select tr.nro_referencia
                      into v_nro_reversion
                      from ge_snp_transferencias tr
                     where tr.nro_sec_lote            = v_nro_sec_lote
                       and tr.nro_cta_pte_solicitante = rg_msj_det.nro_cta_pte_beneficiario;

                    pas_snp.pr_obt_mensaje ( v_nro_reversion, 'N' );

                    rg_msj_env             := pas_snp.fu_obt_reg_transferencias;
                    rg_msj_env.tip_rechazo := rg_msj_det.tip_rechazo;

                    pas_snp.pr_ini_registros;

                    if fue_val_es_numerico( rg_msj_env.nro_cta_solicitante ) = 'S' and
                       fue_val_es_numerico( rg_msj_det.nro_cta_beneficiario ) = 'S'
                    then
                       if to_number(rg_msj_env.nro_cta_solicitante) <> to_number( nvl( rg_msj_det.nro_cta_beneficiario, 0 ) ) then
                          v_ind_rev_manual := 'S';
                          pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original. Nro. Cta. Original no concuerda con MT de Reversi�n', pas_snp.fu_obt_salto );
                       end if;
                    else -- Uno de los datos no es num�rico.
                       if rg_msj_env.nro_cta_solicitante <> nvl( rg_msj_det.nro_cta_beneficiario, 0 ) then
                          v_ind_rev_manual := 'S';
                          pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original. Nro. Cta. MT Original no concuerda con MT de Reversi�n', pas_snp.fu_obt_salto );
                       end if;
                    end if;

                    if rg_msj_env.monto <> nvl( rg_msj_det.monto, 0 ) then
                       v_ind_rev_manual := 'S';
                       pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original. Nro. Cta. y/o Monto del MT Original no concuerda con MT de Reversi�n', pas_snp.fu_obt_salto );
                    end if;

                    if ( rg_msj_det.fec_valor - g_dia_max_reversion ) > rg_msj_env.fec_valor then
                       v_ind_rev_manual := 'S';
                       pas_snp.pr_set_texto ( g_det_msj_error, 'El valor de la fecha de reversi�n es posterior al rango configurado en el par�metro din�mico SNP_DIA_MAX_REVERSION el cual es de (' || g_dia_max_reversion || ') dia(s)', pas_snp.fu_obt_salto );
                    end if;

                    if v_ind_rev_manual = 'N' then
                       begin
                          -- Se env�a el MT Original para ser rechazado
                          prg_cre_savepoint('rechazo');
                          pas_spi.g_reversion:='S';
                          pas_snp.pr_pro_msj_rechazado ( rg_msj_env );
                          pas_spi.g_reversion:='N';
                          if pas_snp.fu_obt_cod_error <> 0 then
                             raise ex_salir;
                          else
                            --HA-2637
                             rg_msj_det.estado := 'R';
                             pas_snp.pr_env_alerta( rg_msj_det, 'R' );
                          end if;
                       exception
                          when ex_salir then
                             v_ind_rev_manual := 'S';
                             prg_rol_savepoint('rechazo');
                             pas_snp.pr_set_texto ( g_det_msj_error, 'Ejecutando proceso de RECHAZO, '||pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                          when others then
                             v_ind_rev_manual := 'S';
                             prg_rol_savepoint('rechazo');
                             pas_snp.pr_set_texto ( g_det_msj_error, 'Ejecutando proceso de RECHAZO, '||sqlerrm, pas_snp.fu_obt_salto );
                       end;
                    end if;
                 exception
                    when others then
                       v_ind_rev_manual := 'S';
                       pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando datos del MT Original - '||sqlerrm, pas_snp.fu_obt_salto );
                 end;
              end if;

              -- Si la reversi�n tiene alg�n ERROR enviar� un MAIL y
              -- se cancelar� autom�ticamente el mensaje de reversi�n RECIBIDO.
              if g_det_msj_error is not null then
                 rg_msj_det.estado := 'C';
              end if;
           else
             -- Se quita el g_sal_socket en caso que haya duplicados.
             begin
                rg_msj_det.concepto := pas_snp.fu_val_cadena(replace(fug_ver_cad_multilinea(v_campo_70,
                                                                                            pas_snp.fu_obt_sal_socket,
                                                                                            4,
                                                                                            35
                                                                                           ),
                                                                     pas_snp.fu_obt_sal_socket,
                                                                     pas_snp.fu_obt_salto
                                                                    )
                                                            );
             exception
                when others then
                  pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || ' ' || sqlerrm || ' ' , pas_snp.fu_obt_salto );
             end;
           end if;
        end if;

        -- ********************************* fin del texto ************************************************

        -- Concatena los errores de la cabecera de la mensajer�a.
        if v_ban_error = 'S' then
           pas_snp.pr_set_texto ( rg_msj_det.error, v_cab_msj_error, pas_snp.fu_obt_salto );
        end if;

        -- Concatena los errores del detalle de la operaci�n.
        if g_det_msj_error is not null then
           pas_snp.pr_set_texto ( rg_msj_det.error, g_det_msj_error, pas_snp.fu_obt_salto );
        end if;

        -- Se Inserta en ge_snp_transferencias
        BEGIN

           rg_msj_det.nro_referencia := fu_obt_sig_nro_referencia;
           rg_msj_det.cod_modulo     := pas_snp.fu_obt_cod_mod_padre;
           rg_msj_det.cod_modalidad  := pas_snp.fu_obt_cod_mad_padre;
           rg_msj_det.ind_valor      := 'N'; --(N) Bajo Valor
           rg_msj_det.situacion      := 'R';
           rg_msj_det.estado         := nvl( rg_msj_det.estado, 'S' );
           rg_msj_det.origen         := 'I';
           rg_msj_det.plataforma     := 'X';
           rg_msj_det.indemnizado    := 'N';

           if v_ind_reversion = 'N' then

              -- Verifica si la Transferencia tiene cumplimiento
              if not pas_snp.fu_val_perfil ( rg_msj_det ) then
                 -- Se comenta la captura del error por incumplimiento, ya que se pide que solo envie mail de aviso y no levantar en WF.
                 -- pas_snp.pr_set_texto( rg_msj_det.error, 'El monto de la transferencia sobrepasa el cumplimiento configurado.', pas_snp.fu_obt_salto );
                 NULL;
              end if;

              -- Verifica que la mensajer�a no est� DUPLICADA
              if nvl(fug_obt_pardinamico('SNP_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
         if pas_snp.fu_ver_mov_duplicados( rg_msj_det ) > 0 then
          pas_snp.pr_set_texto( rg_msj_det.error, 'La mensajer�a tiene movimientos similares.', pas_snp.fu_obt_salto );
         end if;
              end if;
           end if;

           if rg_msj_det.error is not null then
              rg_msj_det.situacion := 'E';
              v_ban_error          := 'S';
           end if;
           --valida credito a modalides especificas( cuenta basica) MGF --BINDESK-254
            BEGIN
               IF v_ind_reversion='N' THEN --BINDESK-1943

                  v_supera_limite := NVL(fua_obt_limite_cta_basica(rg_msj_det.nro_cta_beneficiario,
                                        rg_msj_det.monto,
                                        rg_msj_det.fec_valor,
                                        pag_cta.g_ctas.cod_modalidad,
                                        rg_msj_det.cod_moneda), 'N');
                  -- Usamos las variables creadas para realizar la validaci�n.
                 IF  v_supera_limite = 'S' THEN
                    rg_msj_det.tip_rechazo := '006';
                    rg_msj_det.error       := 'Error: Supera Limite Cta. Basica.';
                 END IF;
               END IF;
            EXCEPTION
              WHEN OTHERS THEN
              NULL;
            END;

           g_lugar :=  'Insertando MT 102.., ';
           pr_ins_transferencias ( rg_msj_det );

           if pas_snp.fu_obt_cod_error <> 0 then
              raise ex_salir;
           end if;

           -- Luego de insertar la mensajer�a, env�a mail por la inconsistencia del Tipo de Rechazo (si aplica)
           if v_tip_rec_error is not null then
              pas_snp.pr_env_mail( g_err_dir_correo,
                                   'MT102 - Error al buscar el tipo de rechazo para la mensajer�a recibida - SNP',
                                   rg_msj_det,
                                   v_tip_rec_error
                                 );
           end if;
           --
           if v_ind_reversion = 'N' then -- Si no es REVERSION
              if rg_msj_det.error is not null then -- Si tiene ERRORES
                 if nvl( rg_msj_det.monto, 0 ) > nvl( fug_obt_pardinamico( p_parametro  => 'SNP_MTO_MAX_REC_AUTOMATICO',
                                                                           p_cod_moneda => rg_msj_det.cod_moneda
                                                                         ), 0
                                                    )
                 then
                    /* Intenta enviar al Workflow si todo esta OK pero con errores,
                    || se asigna un error para la generaci�n del Workflow
                    */
                    rg_msj_det.indemnizado := 'S';
                    pas_snp.pr_set_transferencias ( rg_msj_det );
                    pas_snp.pr_ini_workflow( rg_msj_det );
                 else
                    begin
                       prg_cre_savepoint('rechazo');
                       pas_snp.pr_pro_msj_rechazado( rg_msj_det );
                       if pas_snp.fu_obt_cod_error <> 0 then
                          pas_snp.pr_set_texto( pas_snp.g_msj_error,
                                                'Debe registrar una mensajer�a de REVERSION de forma MANUAL para enviar al SIPAP.',
                                                pas_snp.fu_obt_salto
                                              );
                          pas_snp.pr_env_mail( g_err_dir_correo,
                                               'MT102 - Error al intentar reversar autom�ticamente la mensajer�a recibida - SNP',
                                               rg_msj_det,
                                               pas_snp.fu_obt_msj_error
                                             );
                          rg_msj_det.estado := 'C';
                          raise ex_salir;
                       else
                          rg_msj_det.estado := 'R';
                       end if;
                    exception
                      when ex_salir then
                         prg_rol_savepoint('rechazo');
                         pas_snp.pr_set_texto ( rg_msj_det.error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                      when others then
                         prg_rol_savepoint('rechazo');
                         pas_snp.pr_set_texto ( rg_msj_det.error, sqlerrm, pas_snp.fu_obt_salto );
                    end;
                    --
                    pas_snp.pr_set_transferencias ( rg_msj_det );
                    --
                 end if;
              elsif ( nvl( rg_msj_det.monto, 0 ) > nvl( fug_obt_pardinamico( p_parametro  => 'SNP_MTO_MAX_ACR_AUTOMATICA',
                                                                             p_cod_moneda => rg_msj_det.cod_moneda
                                                                           ), 0
                                                      )
                    ) or ( nvl( pas_snp.fu_ver_seg_cliente( rg_msj_det.cod_per_beneficiario ), 'N' ) = 'S' )
                    -- Se verifica el Sector del Cliente para ingreso al WF
              then
                 -- No tiene ERRORES
                 /*
                 || Luego de haber verificado todos los datos posibles, se verifica
                 || si la mensajer�a RECIBIDA se procesar� directamente o bien se inicializar�a
                 || circuito para su verificaci�n.
                 */
                 -- Debe inicializar circuito para su verificaci�n
                 if pas_snp.fu_obt_cod_error <> 0 then
                    -- Si la funci�n pas_snp.FU_VER_SEC_CLIENTE tiene errores se levanta WF por error.
                    rg_msj_det.situacion := 'E';
                    pas_snp.pr_set_texto ( rg_msj_det.error, pas_snp.fu_obt_msj_error, ' ' );
                 else
                    rg_msj_det.situacion := 'I';
                 end if;
                 rg_msj_det.indemnizado := 'S';
                 pas_snp.pr_set_transferencias( rg_msj_det );
                 pas_snp.pr_ini_workflow( rg_msj_det );
                 --
              else -- Ejecuta el pas_snp.PR_PRO_PRINCIPAL para intentar generar movimientos
                 rg_msj_det.situacion := 'L';
                 rg_msj_det.estado    := 'A';
                 pas_snp.pr_set_transferencias ( rg_msj_det );
                 --HA-2637
                 if pas_snp.fu_obt_cod_error=0 then
                    pas_snp.pr_env_alerta( rg_msj_det, 'C' );
                 end if;
                 --
              end if;
           elsif v_ind_reversion = 'S' then -- Si es REVERSION
              if rg_msj_det.error is not null then -- Si tiene ERRORES
                 /*
                 || Si la reversi�n tiene alg�n ERROR:
                 || 1. Enviar� correo avisando que el proceso tuvo alg�n error durante la reversi�n de operaciones,
                 || 2. Mensaje de Reversi�n RECIBIDA                   : estado = (C) y situaci�n = (E)rror,
                 || 3. Mensaje original a ser REVERSADO si encuentra(*): estado = (A)probado y situaci�n = (C)ancelado.
                 ||
                 || (*)Esto es para que el PRG_REV_OPERACIONES no emita alg�n error durante la REVERSION MANUAL de la mensajer�a.
                 */
                 -- Si no se pudo reversar el MT por error en la sintaxis, env�a mail.
                 if v_ind_rev_manual = 'S' then
                    -- Se adjunta el error al mail a ser enviado.
                    pas_snp.pr_set_texto( rg_msj_det.error,
                                          'Debe REVERSAR la mensajer�a '||
                                          CASE
                                             when rg_msj_env.nro_referencia is not null then
                                               'EMITIDA'
                                             else
                                               'RECIBIDA'
                                          END ||' de forma MANUAL en ITGF.',
                                          pas_snp.fu_obt_salto
                                        );
                 end if;

                 if rg_msj_env.nro_referencia is not null then
                    pas_snp.pr_env_mail( g_err_dir_correo,
                                         'MT102 - Error al intentar realizar el proceso de reversi�n de la mensajer�a emitida - SNP',
                                         rg_msj_env,
                                         'Se ha encontrado errores en el MT Recibido : ' || pas_snp.fu_obt_salto || rg_msj_det.error || pas_snp.fu_obt_salto
                                       );

                    if nvl( rg_msj_env.situacion, '~' ) <> 'C' then
                       rg_msj_env.situacion := 'C';
                       pas_snp.pr_set_transferencias ( rg_msj_env );
                    end if;
                 else
                    pas_snp.pr_env_mail( g_err_dir_correo,
                                         'MT102 - Error al intentar reversar la mensajer�a emitida - SNP',
                                         rg_msj_det,
                                         rg_msj_det.error
                                       );
                 end if;
              end if;
           end if;
        EXCEPTION
           when ex_salir then
             BEGIN
                if g_err_dir_correo is not null then
                   it_mail.mail( fug_obt_dir_correo,
                                 g_err_dir_correo,
                                 'Error al insertar la mensajer�a EN LOTE en GE_SNP_TRANSFERENCIAS. ',
                                 'Se ha encontrado una mensajer�a en el LOTE, el cual no pudo registrarse en ITGF. ' || chr(10) || chr(10) ||
                                 'Fecha Valor    : ' || to_char(rg_msj_det.fec_valor,'DD/MM/YYYY')                   || chr(10) ||
                                 'Lote           : ' || to_char(rg_msj_det.nro_lote)                                 || chr(10) ||
                                 'Nro.Ref.Externa: ' || rg_msj_det.nro_ref_externa                                   || chr(10) ||
                                 chr(10) || chr(10) ||
                                 'Atentamente.'
                               );
                end if;
             EXCEPTION
               when others then
                 NULL;
             END;
        END;
     END LOOP;

     if v_ban_error = 'N' then
        return '00' || '|' || 'MT102' || '|' || rg_msj_det.nro_lote || ' - Procesado OK';
     else
        return '00' || '|' || 'MT102' || '|' || rg_msj_det.nro_lote || ' - Procesado con errores';
     end if;

EXCEPTION
  when ex_salir then
     return 99 || '|' || 'MT102' || '|' || g_lugar || ' - ' || SQLERRM;
  when others then
     return 99 || '|' || 'MT102' || '|' || g_lugar || ' - ' || SQLERRM;
END fu_pro_msj_mt102;

FUNCTION fu_pro_msj_confirmacion( p_mensaje in long ) return varchar2
IS
  /*
  || Procesa los MT900 y MT910 (Confirmaci�n de D�bito y Cr�dito).
  */

   rg_snp_msj          ge_snp_mensajes%rowtype := NULL;
   rg_snp_tra          pas_snp.rg_msj := NULL;
   v_cod_mensaje       sb_snp_mensajes_tmp.cod_mensaje%type := NULL;
   v_nro_ref_interna   ge_snp_transferencias.nro_referencia%type;
   v_tag_72            ge_snp_transferencias.observacion%type;
   v_tag_25            varchar2(100); --Cta. F�sica D�bito en BCP
   v_monto_envio       ge_snp_transferencias.monto%type;
   v_cta_pte_sol       ge_snp_transferencias.nro_cta_pte_solicitante%type;
   v_err_campo         varchar2(4000) := NULL;
   v_sql               varchar2(4000) := NULL;
   v_det_log           varchar2(4000) := NULL;
   v_retorno           varchar2(4000) := NULL;
   v_cantidad          number;
   v_nro_cta_pte_sol   cc_cta_bancarias.nro_cuenta%type;
   v_cod_ofi_ente      ge_cta_clientes.cod_oficina%type;
   v_cod_mod_ente      ge_cta_clientes.cod_modulo%type;
   v_cod_mad_ente      ge_cta_clientes.cod_modalidad%type;
   v_nro_secuencia     ge_movimientos.nro_secuencia%type := 0;
   v_estado            ge_movimientos.estado%type := 'N';
   v_hora              ge_movimientos.hora%type := fug_obt_mov_hora;
   v_cod_tra_padre     ge_transacciones.cod_transaccion%type := 303;
   v_existe             varchar2(1):='N';
   cursor cu_msj_temporal is
      select a.rowid fila,
             a.cod_mensaje,
             a.campo,
             a.valor,
             a.descripcion,
             a.err_formato,
             a.orden
        from sb_snp_mensajes_tmp a
       where a.cod_mensaje = pao_pmt.fu_obt_cod_mensaje(p_mensaje)
         and a.campo not in ('CAB', 'PIE')
           and a.descripcion is not null
       order by orden;

   PROCEDURE lp_act_err_campo( p_det_error in sb_snp_mensajes_tmp.err_formato%type,
                               p_fila      in rowid
                             )
   IS
   BEGIN
      --
      update sb_snp_mensajes_tmp t
         set t.err_formato = p_det_error
       where t.rowid = p_fila;
      --
   EXCEPTION
     WHEN others THEN
       NULL;
   END lp_act_err_campo;

   PROCEDURE lp_reg_log_transferencia( p_respuesta in varchar2 )
   IS
   BEGIN
      --
      pas_snp.pr_set_texto(v_det_log, p_respuesta, pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto(v_det_log, 'Nro. Ref. Original: '|| '~' || rg_snp_tra.nro_referencia || '~', pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Nro. Lote:          '|| '~' || rg_snp_tra.nro_lote || '~', pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Nro. Ref. Externa:  '|| '~' || rg_snp_tra.nro_ref_externa || '~', pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Fec. Valor:         '|| to_char(rg_snp_tra.fec_valor,'DD/MM/YYYY'), pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Situaci�n:          '|| rg_snp_tra.situacion, pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Estado:             '|| rg_snp_tra.estado, pas_snp.fu_obt_salto);
      pas_snp.pr_reg_operacion( NULL, v_det_log );
      --
   EXCEPTION
     WHEN others THEN
       NULL;
   END lp_reg_log_transferencia;

   PROCEDURE lp_obt_dat_env_202_automatico(p_tipo_mensaje in varchar2,
                                        p_monto out sb_snp_lim_depo.monto%type,
                                        p_cta_sol out cc_cta_bancarias.nro_cta_bancaria%type

                                      )is


  v_mto_bcp_disponible    sb_snp_lim_depo.monto%type := 0;
  v_cod_moneda            sb_snp_lim_depo.cod_moneda%type := 'PYG';
  v_cta                   cc_cta_bancarias.nro_cta_bancaria%type;
begin
 --buscamos la cta del pte sol del ultimo deposito enviado
   select  s.nro_cta_pte_solicitante
     into  v_cta
     from ge_snp_transferencias s
    where s.cod_msj_swift = p_tipo_mensaje
      and s.cod_swi_pte_beneficiario = fug_obt_pardinamico('SNP_BIC_BCP')
      and s.cod_swi_pte_solicitante = trim(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad))
      and s.fec_insercion in (select max(g.fec_insercion)
                                from ge_snp_transferencias g
                               where g.cod_msj_swift = s.cod_msj_swift
                                 and g.cod_swi_pte_beneficiario = s.cod_swi_pte_beneficiario
                                 and g.cod_swi_pte_solicitante = s.cod_swi_pte_solicitante
                                /* and g.situacion = 'L'
                                 and g.estado = 'A'*/) --preguntar como pasa a situacion L y estado A
      and exists
    (select 1
             from ge_snp_mensajes f
            where f.cod_msj_swift = 545
              and f.nro_ref_externa = to_char(s.nro_referencia));

  --consultamos el ultimo saldo generado para el fondeo de la cta liq
    BEGIN
         select replace(substr(x.valor, 11, length(x.valor)), ',', NULL) monto
           into v_mto_bcp_disponible
           from sb_snp_mensajes x
          where x.campo = '64'
            and x.cod_mensaje = 'MT941'
            and to_char(substr(x.valor, 8, 3)) = v_cod_moneda
            and x.fec_insercion =
                (select max(t.fec_insercion)
                   from sb_snp_mensajes t
                  where t.cod_mensaje = 'MT941'
                    and t.campo = '21'
                    and t.valor like '%F%');
       EXCEPTION
         when no_data_found then
           v_mto_bcp_disponible := 0;
       END;

   p_monto := v_mto_bcp_disponible;
   p_cta_sol := v_cta;
exception
 when no_data_found then
      PAS_SNP.g_cod_error := 123;
      PAS_SNP.g_msj_error := 'No se encontro el monto y participante solicitante del ultimo deposito realizado';
      v_mto_bcp_disponible :=0;
   when too_many_rows Then
      PAS_SNP.g_cod_error := 124;
      PAS_SNP.g_msj_error := 'Existe mas de un monto y cuenta del participante solicitante para el ultimo deposito realizado';
      v_mto_bcp_disponible :=0;
   when others then
      PAS_SNP.g_cod_error := 125;
      PAS_SNP.g_msj_error := 'Error en PAS_SNP.lp_obt_dat_env_202_automatico' || ' - ' || sqlerrm;
      v_mto_bcp_disponible :=0;
end lp_obt_dat_env_202_automatico;

BEGIN
   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   /*
   || En esta variable se almacenar� todos los errores encontrados y
   || se depositar� en el campo error de GE_SNP_MENSAJES.
   */
   pas_snp.g_det_msj_error := null;

   for msj in cu_msj_temporal loop
      v_err_campo := msj.err_formato;

      -- Registra el tipo de mensaje para usos futuros.
      if v_cod_mensaje is null then
         v_cod_mensaje := msj.cod_mensaje;
      end if;

      if msj.campo = '20' then     /**/-- Campo :20: Nro. Referencia
         rg_snp_msj.nro_referencia := msj.valor;
      elsif msj.campo = '21' then  /**/-- Campo :21: Nro. Referencia Externa
         rg_snp_msj.nro_ref_externa := msj.valor;
      elsif msj.campo = '25' then  /**/-- Campo :25: Cuenta de liquidaci�n afectada por la operaci�n de d�bito o cr�dito
         v_tag_25 := msj.valor;
      elsif msj.campo = '32A' then /**/-- Campo 32A: Fecha, Moneda y Monto
         rg_snp_msj.fec_valor  := to_date(trim(substr(msj.valor,1,6)),'RRMMDD');
         rg_snp_msj.cod_moneda := CASE trim(substr(msj.valor,7,3)) WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE substr(msj.valor,7,3) END;
         v_sql := 'SELECT ''S'' FROM BA_MONEDAS WHERE COD_MONEDA = '||''''||rg_snp_msj.cod_moneda||'''';
         if not fu_val_dat_ingresado(v_sql) then
            pas_snp.pr_set_texto( v_err_campo, 'El campo Cod. Moneda no est� correcto, '||pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
         end if;
         rg_snp_msj.monto := to_number(replace(substr(msj.valor,10),'.',','));
         if rg_snp_msj.monto is null then
            pas_snp.pr_set_texto( v_err_campo, 'El campo Importe no puede ser nulo.' , pas_snp.fu_obt_salto );
         end if;
         lp_act_err_campo( v_err_campo, msj.fila );
      elsif msj.campo = '72' then  /**/-- Campo :72: Referencia OID, sirve para casos de retorno de operaciones
         v_tag_72 := msj.valor;
      end if;
   end loop;

   --Verifica si existe un registro con el Nro. de Referencia relacionado en ge_snp_transferencias
   g_lugar :=  'Verificando referencia relacionada en GE_SNP_TRANSFERENCIAS, ';
   v_nro_ref_interna := to_number( pas_snp.fu_obt_nro_ref_interna( rg_snp_msj.nro_ref_externa,
                                                                   v_tag_25,
                                                                   rg_snp_msj.fec_valor
                                                                 )
                                 );
   -- Si encuentra la mensajer�a, realiza algunas validaciones
   if v_nro_ref_interna is not null then
      pas_snp.pr_obt_mensaje ( ( ltrim( rtrim( v_nro_ref_interna ) ) ), 'N' );
      if pas_snp.fu_obt_cod_error <> 0 then
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
      else -- No tuvo ERRORES
         rg_snp_tra := pas_snp.fu_obt_reg_transferencias;
      end if;
      pas_snp.pr_ini_registros;
   else -- No se ha encontrado la referencia interna para la mensajer�a recibida.
      pas_snp.pr_set_texto ( g_det_msj_error,
                             g_lugar || 'No se ha encontrado el Nro. Ref. Interna en GE_SNP_TRANSFERENCIAS.'||chr(10)||
                             'A continuaci�n datos para la b�squeda de la Referencia Original:'||chr(10)||
                             'Nro. Ref. Externa: '||'~'||rg_snp_msj.nro_ref_externa||'~'||chr(10)||
                             'Cta. Liquidaci�n:  '||'~'||v_tag_25||'~'||chr(10)||
                             'Fecha Valor:       '||'~'||rg_snp_msj.fec_valor||'~',
                             pas_snp.fu_obt_salto
                           );
   end if;

   --Se inserta en GE_SNP_MENSAJES el swift.
   BEGIN
      --
      g_lugar := 'Verificando datos antes de insertar en GE_SNP_MENSAJES, ';
      if rg_snp_tra.nro_referencia is not null then
         -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS
         -- Si es ENVIADO actualiza solamente la situaci�n,
         -- si es RECIBIDO y no tiene WF actualiza la situaci�n y el estado
         -- Tanto para ENVIADO como RECIBIDO actualiza el campo REF_OID del MT Original
         if g_det_msj_error is null then
            -- Se vuelve a obtener los datos del MT para actualizarlos.
            pas_snp.pr_obt_mensaje ( rg_snp_tra.nro_referencia, 'N' );
            if pas_snp.fu_obt_cod_error <> 0 then
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
            end if;
          if rg_snp_tra.ref_oid Is Not Null then
              if rg_snp_tra.ref_oid <> 'PPV' then
            --
            -- Actualiza el campo REF_OID del MT Original
            rg_snp_tra.ref_oid := nvl( v_tag_72, rg_snp_tra.ref_oid );
            end if;
          Else
            rg_snp_tra.ref_oid := nvl( v_tag_72, rg_snp_tra.ref_oid );
          End If;
            if not pas_snp.fu_val_es_enviado( rg_snp_tra ) -- Si la Mensajer�a ORIGEN es una Recibida
              and rg_snp_tra.error is not null             -- Y si la Mensajer�a ORIGEN tiene Errores
              and rg_snp_tra.cod_msj_swift in ( 102, 103 )
              and not pas_snp.fu_ver_workflow( to_char( rg_snp_tra.nro_referencia ) ) --Y la Mensajer�a ORIGEN no se encuentra en el WORKFLOW
              and (   instr( nvl( rg_snp_tra.concepto, '~' ), '/REV/', 1 ) = 0        -- Si la Mensajer�a ORIGEN es un RETORNO RECIBIDO no se hace nada
                   or instr( nvl( rg_snp_tra.observacion, '~' ), '/REV/', 1 ) = 0
                  )
              and nvl( rg_snp_tra.monto, 0 ) <= nvl( fug_obt_pardinamico( p_parametro => 'SNP_MTO_MAX_REC_AUTOMATICO',
                                                                          p_cod_moneda => rg_snp_tra.cod_moneda
                                                                        ), 0
                                                   )
            then
               begin
                  g_lugar := 'Intentando realizar el RETORNO autom�tico, ';
                  prg_cre_savepoint('rechazo');
                  pas_snp.pr_pro_msj_rechazado( rg_snp_tra );
                  if pas_snp.fu_obt_cod_error <> 0 then
                     pas_snp.pr_set_texto( pas_snp.g_msj_error,
                                           'Debe registrar una mensajer�a de REVERSION de forma MANUAL para enviar al SIPAP.',
                                           pas_snp.fu_obt_salto
                                         );
                     pas_snp.pr_env_mail( g_err_dir_correo,
                                          'MT'||rg_snp_tra.cod_msj_swift||
                                          ' - Error al intentar reversar autom�ticamente la mensajer�a recibida - SNP',
                                          rg_snp_tra,
                                          pas_snp.fu_obt_msj_error
                                        );
                     rg_snp_tra.estado := 'C';
                     raise ex_salir;
                  else
                     rg_snp_tra.estado := 'R';
                  end if;
               exception
                  when ex_salir then
                     prg_rol_savepoint('rechazo');
                  when others then
                     prg_rol_savepoint('rechazo');
               end;
               --
               g_lugar := 'Actualizando datos en el mensaje original debido a proceso de RETORNO autom�tico, ';
               pas_snp.pr_set_transferencias ( rg_snp_tra );
               if pas_snp.fu_obt_cod_error <> 0 then
                  pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
               end if;
            elsif pas_snp.fu_val_es_enviado( rg_snp_tra ) -- Es MT ENVIADO o
              or ( not pas_snp.fu_val_es_enviado( rg_snp_tra ) -- Es MT RECIBIDO y no tiene WF pendiente
                   and not pas_snp.fu_ver_workflow( to_char( rg_snp_tra.nro_referencia ) )
                 )
            then
               rg_snp_tra.indemnizado := 'N';
               rg_snp_tra.situacion   := 'L';
               if (    instr( nvl( rg_snp_tra.concepto, '~' ), '/REV/', 1 ) = 0        -- Si la Mensajer�a ORIGEN es un RETORNO RECIBIDO no se hace nada
                   and instr( nvl( rg_snp_tra.observacion, '~' ), '/REV/', 1 ) = 0
                  )
               then
                  rg_snp_tra.estado := 'A';
               end if;
            end if;
         end if;
        if rg_snp_tra.ref_oid Is Not Null then
         if rg_snp_tra.ref_oid <> 'PPV' then
         -- Actualiza el campo REF_OID del MT Original
         rg_snp_tra.ref_oid := nvl( v_tag_72, rg_snp_tra.ref_oid );
         end if;
        Else
            rg_snp_tra.ref_oid := nvl( v_tag_72, rg_snp_tra.ref_oid );
        end if;
         g_lugar := 'Actualizando datos en GE_SNP_TRANSFERENCIAS, ';
         -- Actualiza la mensajer�a en GE_SNP_TRANSFERENCIAS
         pas_snp.pr_set_transferencias( rg_snp_tra );
         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
         end if;
         --
      elsif rg_snp_tra.nro_referencia is null
            and upper( g_det_msj_error ) not like '%NO%ENCONT%REF%INT%TRANSF%'
            and not (rg_snp_tra.cod_msj_swift = 202
            and rg_snp_tra.cod_tip_operacion = '014'
            and rg_snp_tra.cod_sub_tip_operacion in ('001', '003')) then
         -- No se ha encontrado la referencia interna para la mensajer�a recibida.
         pas_snp.pr_set_texto ( g_det_msj_error,
                                g_lugar || 'No se ha encontrado el Nro. Ref. Interna en GE_SNP_TRANSFERENCIAS.'||chr(10)||
                                'A continuaci�n los datos para la b�squeda de la Referencia Original:'||chr(10)||
                                'Nro. Ref. Externa: '||'~'||rg_snp_msj.nro_ref_externa||'~'||chr(10)||
                                'Cta. Liquidaci�n:  '||'~'||v_tag_25||'~'||chr(10)||
                                'Fecha Valor:       '||'~'||rg_snp_msj.fec_valor||'~',
                                pas_snp.fu_obt_salto
                              );
      end if;

      g_lugar :=  'Insertando en GE_SNP_MENSAJES, ';

      INSERT INTO ge_snp_mensajes ( nro_referencia,
                                    nro_ref_externa,
                                    cod_msj_swift,
                                    fec_valor,
                                    msj_swift,
                                    cod_moneda,
                                    monto,
                                    error,
                                    fec_recepcion
                                  )
                           VALUES ( ltrim( rtrim( rg_snp_msj.nro_referencia ) ),
                                    ltrim( rtrim( rg_snp_msj.nro_ref_externa ) ),
                                    substr( p_mensaje, instr( p_mensaje, '{2:' ) + 4, 3 ),
                                    rg_snp_msj.fec_valor,
                                    replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),
                                    rg_snp_msj.cod_moneda,
                                    rg_snp_msj.monto,
                                    g_det_msj_error,
                                    sysdate
                                  );

      if g_det_msj_error is null then
         if v_cod_mensaje = 'MT900' and
            rg_snp_tra.cod_msj_swift in (102,103)
         then
            pas_snp.pr_env_alerta( rg_snp_tra, 'C' );
         end if;
         v_retorno := '00' || '|' || v_cod_mensaje || '|' || ltrim(rtrim(rg_snp_msj.nro_ref_externa)) || ' - Procesado OK';
      else
         v_retorno := '00' || '|' || v_cod_mensaje || '|' || ltrim(rtrim(rg_snp_msj.nro_ref_externa)) || ' - Procesado con errores';
      end if;
      --
      --SPI
      --apartado donde se controlara el envio automatico del MT202 de fondeo a la ctaLiq desde la ctaReserva
      --este proceso debe activarse a partir de un MT900 o MT910 realcionado a un MT202 de tipo 012 subTipo 003
       begin
         select count(*)
           into v_cantidad
           from ge_snp_transferencias s
          where s.cod_tip_operacion = 029
            and s.cod_sub_tip_operacion in (001,002)
            and s.observacion = '/BNF/SPI'
            and s.fec_valor = trunc(sysdate);--TRFS-670
       end;
     if v_cantidad = 0 then --control solo para enviar a la ma�ana
      if v_nro_ref_interna is not null and rg_snp_tra.cod_msj_swift = 202 and rg_snp_tra.cod_tip_operacion = 012 and rg_snp_tra.cod_sub_tip_operacion = 003 then
        if fug_obt_pardinamico('SPI_IND_GEN_202_AUT') = 'S' then
           lp_obt_dat_env_202_automatico('541' , v_monto_envio , v_cta_pte_sol);
           if pas_spi.fu_obt_cod_error <> 0 then
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           else
              --TCE-91
              if v_cta_pte_sol = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then --COMASPI1PYG
                --valida Fondeo de reserva con confirmacion
                begin
                               select 'S'
                                 INTO v_existe
                                 from ge_snp_transferencias t,
                                      ge_snp_mensajes       m,
                                      ge_snp_mensajes       c
                                where t.fec_valor =
                                      pag_cal.fu_obt_fec_ant_hab( pag_cal.fu_obt_fec_actual(1),
                                                                 61,
                                                                 1)
                                  and t.cod_msj_swift = 202
                                  and t.cod_tip_operacion = 029
                                  and t.cod_sub_tip_operacion = 001
                                  and t.observacion = '/BNF/SPI'
                                  and m.nro_ref_externa =
                                      to_char(t.nro_referencia)
                                  and m.cod_msj_swift in (900)
                                  and c.nro_ref_externa =
                                      to_char(t.nro_referencia)
                                  and c.cod_msj_swift in (910);
                 exception
                   when no_data_found then
                     v_existe:='N';
                   when others then
                     v_existe:='N';
                 end;
              if v_existe ='S'THEN
                 pas_snp.pr_gen_MT202_automatico(v_monto_envio,v_cta_pte_sol);
              end if;
              else
                pas_snp.pr_gen_MT202_automatico(v_monto_envio,v_cta_pte_sol);
              end if;
            end if;
        end if;
      end if;
     end if;
     --
     --apartado que genera el movimiento de credito para la cta Beneficiaria del fondeo
     --solo par los MT202 del tipo 029 para cualquiera de los subTipos su respuesta de creditoMT910--
     if v_cod_mensaje = 'MT910' then
      if v_nro_ref_interna is not null and rg_snp_tra.cod_msj_swift = 202 and rg_snp_tra.cod_tip_operacion = 029 then
        --obtenemos el nro de cta de la cta_bancaria del PTE.SOLICITANTE--
        if v_tag_25 = fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ') then
          v_nro_cta_pte_sol := fug_obt_pardinamico('CTA_LBTR_LIQ');
        elsif v_tag_25 = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
          v_nro_cta_pte_sol := fug_obt_pardinamico('CTA_SPI_RESERVA');
        end if;
       /* begin
          SELECT c.nro_cuenta
            INTO v_nro_cta_pte_sol
            FROM cc_cta_bancarias c
           WHERE c.cod_modalidad = 455
             AND c.nro_cta_bancaria = v_tag_25 ;
        end; */

        --obtiene datos de la cuenta
        pag_cta.PR_OBT_CUENTA(v_nro_cta_pte_sol);
        if pag_cta.G_COD_ERROR = 0 then
          v_cod_ofi_ente := pag_cta.G_CTAS.cod_oficina;
          v_cod_mod_ente := pag_cta.G_CTAS.cod_modulo;
          v_cod_mad_ente := pag_cta.G_CTAS.cod_modalidad;
        end if;
    --se valida que todo este correcto para el movimiento--
   if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
     pas_snp.g_cod_error := 103;
     pas_snp.g_msj_error := 'Error para generar el movimiento: '|| pas_snp.g_lugar||'-'||pas_snp.g_msj_error ||' '|| sqlerrm;
   else
     begin
   --se utiliza funci�n para evaluar el estado a imputar en las operaciones
       v_estado := fug_obt_est_mov_confirmado(rg_snp_msj.monto,
                                              pag_gen.fu_obt_mon_local,
                                              v_cod_mod_ente,
                                              v_cod_mad_ente,
                                              v_cod_tra_padre,
                                              'X',
                                              v_nro_cta_pte_sol,
                                              fug_obt_per_entidad
                                             );
        --llama al pag_cta para generar los registros del movimiento por el debito
         pas_snp.g_lugar := 'Inserta registro del movimiento en la tabla ge_movimiento';
         pag_cta.pr_set_referencia(v_estado);
         pag_cta.pr_act_operacion(v_nro_cta_pte_sol,
                                  v_hora, --HORA
                                  'C',
                                  pag_gen.fu_obt_mon_local,
                                  rg_snp_msj.monto,
                                  v_cod_tra_padre,
                                  fug_obt_pardinamico('TRA_SPI_DBSNP'),--4712, --transaccion de credito MT202
                                  rg_snp_tra.nro_referencia,
                                  NULL, --cotizacion
                                  v_cod_ofi_ente, --cod_ofi_origen
                                  v_cod_mod_ente, --cod_mod_padre
                                  v_cod_mad_ente, --cod_mad_padre
                                  null, --cod_tasa
                                  null, --val_tasa
                                  rg_snp_tra.concepto,
                                  'S', --emi_aviso
                                  v_nro_secuencia,
                                  pag_cal.fu_obt_fec_actual(9));
       if pag_cta.G_COD_ERROR != 00 then
          pas_snp.g_cod_error := 104;
          pas_snp.g_msj_error := pag_cta.G_COD_ERROR || '-' || pag_cta.G_MSJ_ERROR||'-'|| pas_snp.g_cod_error||sqlerrm;
          rollback to transferencia;
       end if;
   exception
       when others then
          pas_snp.g_cod_error := 105;
          pas_snp.g_msj_error := pag_cta.G_COD_ERROR || '-' || pag_cta.G_MSJ_ERROR||'-'||pas_snp.g_cod_error||sqlerrm;
          rollback to transferencia;
   end;
  end if;
      end if;
     end if;
     --
      g_lugar := 'Insertando LOG en BA_LOG_MENSAJERIAS, ';
      lp_reg_log_transferencia( '00' || '|' || v_cod_mensaje || '|LOG DEL MT ' || trim(rg_snp_msj.nro_ref_externa) );
      --
      return v_retorno;
   EXCEPTION
     when others then
        --
        g_lugar := 'Insertando LOG en BA_LOG_MENSAJERIAS (when others), ';
        lp_reg_log_transferencia( '99' || '|' || v_cod_mensaje || '|LOG DEL MT ' || trim(rg_snp_msj.nro_ref_externa) || chr(10) || g_lugar || ' - ' || SQLERRM );
        --
        return 99 || '|' || v_cod_mensaje || '|' || g_lugar || ' - ' || SQLERRM;
   END;
EXCEPTION
  when ex_salir then
    --
    g_lugar := 'Insertando LOG en BA_LOG_MENSAJERIAS (ex_salir), ';
    lp_reg_log_transferencia( '99' || '|' || v_cod_mensaje || '|LOG DEL MT ' || trim(rg_snp_msj.nro_ref_externa) || chr(10) || g_lugar || ' - ' || SQLERRM );
    --
    return 99 || '|' || v_cod_mensaje || '|' || g_lugar || ' - ' || SQLERRM;
END fu_pro_msj_confirmacion;

function fu_obt_mto_formato( p_monto          in ge_snp_transferencias.monto%type,
                             p_cod_moneda     in ge_snp_transferencias.cod_moneda%type,
                             p_ind_agr_moneda in varchar2 default 'S'
                           )
/*Retorna el monto formateado para SNP*/
return varchar2 is
   v_cadena varchar2(35);
begin
   --Moneda
   if p_ind_agr_moneda = 'S' then
      -- Se agregar� al monto el c�digo ISO de la moneda.
      pas_snp.pr_set_texto( v_cadena, CASE p_cod_moneda WHEN g_cod_mon_local THEN g_cod_mon_iso_local ELSE p_cod_moneda END, '');
   end if;

   pas_snp.pr_set_texto( v_cadena, trim( to_char( p_monto, pas_snp.fu_obt_mascara || rpad( '9', nvl( fug_obt_pardinamico( p_parametro => 'VAL_RED_MON_EXTRANJERA',
                                                                                                                          p_cod_moneda => p_cod_moneda
                                                                                                                        )
                                                                                                    ,2
                                                                                                   )
                                                                                          ,'9'
                                                                                         )
                                                 ,'NLS_NUMERIC_CHARACTERS='',.'''
                                                )
                                       )
                        , ''
                       );

   return v_cadena;

end fu_obt_mto_formato;

FUNCTION fu_pro_msj_mtn99( p_mensaje in long ) return varchar2
IS
   v_campo_20         ge_snp_mensajes.nro_ref_externa%type;       -- Nro. Referencia Externa
   v_campo_21         ge_snp_mensajes.nro_ref_externa%type;       -- Nro. Referencia del MT Original
   v_campo_79         ge_snp_mensajes.msj_swift%type;             -- Mensaje Swift
   v_fecha            ge_snp_horarios.fecha%type;                 -- Fecha de apertura para operaciones con BCP
   v_periodo          ge_snp_horarios.descripcion%type := null;   -- Descripci�n del Periodo
   v_per_anterior     ge_snp_horarios.descripcion%type := null;   -- Descripci�n del Periodo a cerrar
   v_nvo_cod_periodo  ge_snp_horarios.cod_periodo%type;           -- Si se ingres� un nuevo periodo
   v_mai_titulo       varchar2(100) := null;
   v_pos_ini          number        := 0;
   v_pos_fin          number        := 0;
   v_nro_ref_ext_cat  ge_snp_mensajes.nro_ref_externa%type;
   v_estado           sb_snp_catastros.estado%type;

   PROCEDURE lp_act_horario (p_des_periodo in ge_snp_horarios.descripcion%type,
                             p_tip_accion  in varchar2)
   IS
     v_cod_periodo ge_snp_horarios.cod_periodo%type;
     v_plsql       ge_snp_horarios.det_sql%type;
     v_msj_error   varchar2(1000);
   BEGIN
     select cod_periodo,
            det_sql
       into v_cod_periodo,
            v_plsql
       from ge_snp_horarios
    where pas_snp.fu_val_cadena(upper(replace(p_des_periodo, ' ', ''))) =
          pas_snp.fu_val_cadena(upper(replace(descripcion, ' ', '')))
        and tip_horario != 'A';

     -- Si no existen errores se actualiza la apertura y cierre de operaciones con BCP
     g_lugar := 'Actualizando datos de apertura y cierre de operaciones con BCP, ';
     if p_tip_accion = 'A' then
        update ge_snp_horarios
           set fecha      = v_fecha,
               estado     = p_tip_accion,
               hor_inicio = to_char(sysdate,'hh24mi')
         where cod_periodo = v_cod_periodo;
     else
       update ge_snp_horarios
          set estado     = p_tip_accion,
              hor_fin    = to_char(sysdate,'hh24mi')
        where cod_periodo = v_cod_periodo
          and tip_horario != 'T'
          and fecha = v_fecha;
     end if;

     -- hay algo para ejecutar
     if v_plsql is not null then
        g_lugar := 'Ejecutando Script Configurado, ';
        v_plsql := replace(v_plsql,''||'&'||'TIP_ACCION',chr(39)||p_tip_accion||chr(39));
        sql_util.ejecute_dml(v_plsql,v_msj_error);
        if v_msj_error is not null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || v_msj_error , pas_snp.fu_obt_salto );
        end if;
     end if;

   EXCEPTION
     when no_data_found then
       Select nvl(max(cod_periodo),0)+1
         into v_nvo_cod_periodo
         from ge_snp_horarios ;
       g_lugar := 'Registrando datos de apertura de operaciones con BCP, ';
       insert into ge_snp_horarios (cod_periodo, descripcion, estado, fecha, hor_inicio, hor_fin, tip_horario)
            values (v_nvo_cod_periodo, trim(upper(p_des_periodo)), p_tip_accion, v_fecha,
                    to_char(sysdate,'hh24mi'), to_char(sysdate,'hh24mi'), 'O');
     when others then
       -- Si tiene errores a nivel de BD, guarda el error para luego enviar por correo.
       pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || SQLERRM , pas_snp.fu_obt_salto );
   END lp_act_horario;

BEGIN

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   /*
   || En esta variable se almacenar� todos los errores encontrados y
   || se depositar� en el campo error de GE_SNP_TRANSFERENCIAS.
   */
   pas_snp.g_det_msj_error := null;

   if p_mensaje is null then
      pas_snp.g_cod_error := 52;
      pas_snp.g_msj_error := 'Error en PAS_SNP.FU_PRO_MSJ_MTn99. Valor para P_MENSAJE debe contener algun valor.!';
      pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
   end if;

   --Campos Mandatorios para el MTn99
   /**/-- Campo :20:
   g_lugar :=  'Obteniendo campo :20:, ';
   v_campo_20 := replace( pas_snp.fu_pro_val_tag( p_mensaje, '20', 'N' ), pas_snp.fu_obt_sal_socket );
   if v_campo_20 is null then
      pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'Nro. Ref. Externa no puede ser nulo.! ' , pas_snp.fu_obt_salto );
   end if;
   g_nro_referencia := v_campo_20; --DA-9195
   /**/-- Campo :21: No es obligatorio, por eso no se valida
   g_lugar :=  'Obteniendo campo :21:, ';
   v_campo_21 := replace( pas_snp.fu_pro_val_tag( p_mensaje, '21', 'N' ), pas_snp.fu_obt_sal_socket );

   /**/-- Campo :79:
   g_lugar :=  'Obteniendo campo :79:, ';
   v_campo_79 := pas_snp.fu_pro_val_tag( p_mensaje, '79', 'N' );
   if v_campo_79 is null then
      pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'Acci�n a realizar (QUERY) no puede ser nulo.! ' , pas_snp.fu_obt_salto );
   elsif instr ( v_campo_79, 'BUSINESSDAYPERIOD/' ) > 0 then -- Apertura de Periodos
      g_lugar := 'Obteniendo datos de apertura de operaciones con BCP - /BUSINESSDAY/YYMMDD, ';
      if instr ( v_campo_79, '/BUSINESSDAY/' ) > 0 then
         v_pos_ini := instr(v_campo_79,'/BUSINESSDAY/') + 13;
         --v_pos_fin := v_pos_ini + 6;
         v_pos_fin := instr(v_campo_79,
                           pas_snp.fu_obt_sal_socket,
                           v_pos_ini,
                           1);
         v_fecha   := to_date( substr ( v_campo_79, v_pos_ini, v_pos_fin - v_pos_ini ), 'RRMMDD' );
      end if;
      if instr ( v_campo_79, '/PERIOD/' ) > 0 then
         v_pos_ini := instr(v_campo_79,'/PERIOD/') + 8;
         v_pos_fin := instr(v_campo_79,pas_snp.fu_obt_sal_socket,v_pos_ini,1);
         v_periodo := ( substr ( v_campo_79, v_pos_ini, v_pos_fin - v_pos_ini ) ) ;
      end if;
      if instr ( v_campo_79, '/PREVIOUSPERIOD/' ) > 0 then
         v_pos_ini := instr(v_campo_79,'/PREVIOUSPERIOD/') + 16;
         v_pos_fin := instr(v_campo_79,pas_snp.fu_obt_sal_socket,v_pos_ini,1);
         v_per_anterior := ( substr ( v_campo_79, v_pos_ini, v_pos_fin - v_pos_ini ) ) ;
      end if;
      if v_fecha is null then
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha recuperado la fecha de la palabra reservada /BUSINESSDAY/.! ' , pas_snp.fu_obt_salto );
      end if;
      if v_periodo is null and v_per_anterior is null then
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha recuperado el concepto del periodo mediante la palabra reservada /PERIOD/. o ! /PREVIOUSPERIOD/' , pas_snp.fu_obt_salto );
      else -- Se recuper� la descripci�n del periodo
         if v_periodo is not null then
            lp_act_horario(v_periodo, 'A');
         end if;
         if v_per_anterior is not null then
            lp_act_horario(v_per_anterior, 'C');
         end if;
      end if;
   end if;

   --Se inserta en GE_SNP_MENSAJES el swift.
   BEGIN
      g_lugar :=  'Insertando en GE_SNP_MENSAJES, ';
      BEGIN
         INSERT INTO ge_snp_mensajes ( nro_referencia,
                                       nro_ref_externa,
                                       cod_msj_swift,
                                       fec_valor,
                                       msj_swift,
                                       error,
                                       fec_recepcion
                                     )
                              VALUES ( v_campo_20,
                                       v_campo_21,
                                       substr( p_mensaje, instr( p_mensaje, '{2:' ) + 4, 3 ),
                                       pas_snp.g_fec_actual,
                                       replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),
                                       g_det_msj_error,
                                       sysdate
                                     );
      EXCEPTION
        when others then
          -- Si tiene errores a nivel de BD, guarda el error para luego enviar por correo.
          pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || SQLERRM , pas_snp.fu_obt_salto );
      END;
      if instr ( v_campo_79, '/INSTRU/CATASTRO DEBITO DIRECTO' ) > 0 then

     g_lugar :=  'Procesando catastro debito directo recepcion, ';
     BEGIN
           /**/-- Insercion del catastro
           pas_snp.pr_pro_msj_catastro(replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),v_campo_20,v_campo_21);
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           end if;
      EXCEPTION
        when others then
          -- Si tiene errores a nivel de BD, guarda el error para luego enviar por correo.
          pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || SQLERRM , pas_snp.fu_obt_salto );
      END;

    end if;
      if g_det_msj_error is null then
         if g_gru_dir_correo is not null then
            if instr ( v_campo_79, 'TEXTMESSAGE/' ) > 0 then -- Mensajer�a de formato libre
               v_mai_titulo := 'MTn99 - Se recibi� un Mensaje con formato libre';
            elsif instr ( v_campo_79, 'BUSINESSDAYPERIOD/' ) > 0 then -- MTn99: Solicitud de Propiedad (Proprietary requests)
               v_mai_titulo := 'MTn99 - Se recibi� una solicitud de activaci�n/cierre de periodo con BCP';
            else
               v_mai_titulo := 'MTn99 - Se recibi� un Mensaje propio de BCP';
            end if;

            DECLARE
               v_mensaje varchar2(1000) := 'Se recibi� un MTn99 con el siguiente detalle:' || chr(10) || chr(10) ||
                                           'Nro. Referencia     : ' || v_campo_20                                       || chr(10) ||
                                           'Nro. Ref. Original  : ' || v_campo_21                                       || chr(10) ||
                                           'Detalle del mensaje : ' || replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) ||
                                           chr(10) || chr(10) ||
                                           'Atentamente.';
               -- Envia mail al grupo de notificaci�n si se recibe un MT de Informaci�n.
            BEGIN
               --Si se grab� un nuevo periodo cambia el texto a enviar.
               if nvl(v_nvo_cod_periodo, 0) != 0 then
                  v_mensaje := 'Se recibi� un MTn99 con el siguiente detalle:' || chr(10) || chr(10) ||
                                           'Nro. Referencia     : ' || v_campo_20                                       || chr(10) ||
                                           'Nro. Ref. Original  : ' || v_campo_21                                       || chr(10) ||
                                           'Detalle del mensaje : ' || replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) ||
                                           'Se gener� un Nuevo Periodo con el C�digo: ' || v_nvo_cod_periodo ||'. Favor realizar las configuraciones necesarias en Horarios de Periodos SNP' || chr(10) ||
                                           chr(10) || chr(10) ||
                                           'Atentamente.';
               end if;
               it_mail.mail( fug_obt_dir_correo,
                             g_gru_dir_correo,
                             v_mai_titulo,
                             v_mensaje
                            );
            EXCEPTION
               when others then
                  NULL;
            END;
         end if;
         return '00' || '|' || 'MTn99' || '|' || ltrim(rtrim(v_campo_20)) || ' - Procesado OK';
      else -- Tiene errores
         if g_err_dir_correo is not null then
            it_mail.mail( fug_obt_dir_correo,
                          g_err_dir_correo,
                          'MTn99 - Error durante el proceso ',
                          'No se pudo procesar el MTn99 con los siguientes datos:' || chr(10) || chr(10) ||
                          'Nro. Referencia     : ' || v_campo_20                              || chr(10) ||
                          'Detalle del mensaje : ' || replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ) || chr(10) ||
                          'Error               : ' || g_det_msj_error                         || chr(10) ||
                          chr(10) || chr(10) ||
                          'Atentamente.'
                        );
         end if;
         return '00' || '|' || 'MTn99' || '|' || ltrim(rtrim(v_campo_20)) || ' - Procesado con errores';
      end if;
   EXCEPTION
     when others then
        raise;
   END;

EXCEPTION
  when others then
    return 99 || '|' || 'MTn99' || '|' || g_lugar || ' - ' || SQLERRM;
END fu_pro_msj_mtn99;

FUNCTION fu_pro_msj_mtn96( p_mensaje in long ) return varchar2
IS
/*
||   Procesa la mensajeria RECIBIDA MTn96
*/
   v_nro_referencia  ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa ge_snp_mensajes.nro_ref_externa%type;
   v_cod_mensaje     sb_snp_mensajes_tmp.cod_mensaje%type;
   v_cod_msj_swift   ge_snp_transferencias.cod_msj_swift%type;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl( pas_snp.g_gru_dir_correo, pas_snp.g_err_dir_correo );
   v_sub_tip_mt      varchar2(30);
   v_error           varchar2(100) := 'No se han encontrado transacciones para procesar ';
   v_txt_mail        varchar2(4000);
   v_asunto          varchar2(4000);
   v_inf_json        long:=null;
   v_moneda          ba_monedas.cod_mon_iso%type;
   v_des_monto       varchar2(500) := null;
   v_nro_lote        ge_snp_transferencias.nro_lote%type;
   rg_cir            wf_circuitos%rowtype;
   rg_snp_tra        rg_msj;
   v_cod_cancel      varchar2(100); --Se incrementa el valor de 30 a 100 por TRFS-1308 PHT
   v_fec_rec        date;
   cursor cu_msj_temporal is
      select a.cod_mensaje,
             a.campo,
             a.valor,
             a.descripcion,
             a.err_formato,
             a.orden
        from sb_snp_mensajes_tmp a
       where a.cod_mensaje =
                           pao_pmt.fu_obt_cod_mensaje(replace(p_mensaje,
                                                              pas_snp.fu_obt_sal_socket,
                                                              pas_snp.fu_obt_salto))
         and a.campo not in ('CAB', 'PIE')
           and a.descripcion is not null
       order by orden;
BEGIN

   for msj in cu_msj_temporal loop
     --Creo la cabecera del mail
      v_asunto := 'Mensajer�a '|| msj.cod_mensaje || ' Recibida' ||chr(10);
      v_cod_mensaje := msj.cod_mensaje;
      --Se concatena los datos disponibles para el env�o del Mail.
      v_txt_mail := v_txt_mail || chr(10) ||
                    msj.descripcion || ': '||
                    case when msj.campo = '76'
                          and msj.descripcion = 'Sub Tipo Respuesta'
                          and msj.cod_mensaje = 'MTn96/STAT' then --Cuando es campo "Respuesta" se traduce
                            fue_obt_des_refcodes('SNP_TIP_RTA_N96_STAT',substr(msj.valor, 0, 4))||' ('||substr(msj.valor, 0, 4)||')'
                         else msj.valor end;
      --Se concatenan los errores de formato que pudieron ocurrir
      if msj.err_formato is not null then
         pas_snp.pr_set_texto( g_det_msj_error, msj.err_formato, pas_snp.fu_obt_salto );
      end if;
      --Se obtiene el campo 20 (nro_referencia)
      if msj.campo = '20' and msj.descripcion ='Nro. Referencia de la Transacci�n'then
         v_nro_referencia := substr(msj.valor, 1, 20);
      end if;
      --Se obtiene el campo 21 (nro_ref_externa)
      if msj.campo = '21' then
         v_nro_ref_externa := msj.valor;
      end if;
      --Se obtiene el campo 76 (Sub Tipo Respuesta)
      if msj.campo = '76' and msj.descripcion = 'Sub Tipo Respuesta' then
         v_sub_tip_mt := substr(msj.valor, 0, 4);
      end if;
      --Se obtiene el campo 76 (C�digo de MT solicitado)
      if msj.campo = '11R' and msj.descripcion = 'C�digo de MT solicitado' then
         v_cod_msj_swift := msj.valor;
      end if;
       if msj.campo = '20' and msj.descripcion = 'Nro. lote' then
         v_nro_lote:= msj.valor;
      end if;
      --Se obtiene el campo 77A (C�digo de Cancelacion)
      if msj.campo = '77A' and msj.descripcion = 'Texto Narrativo' then
         v_cod_cancel:= msj.valor;
      end if;

   end loop;
   if v_cod_msj_swift !=104 then
       if v_cod_msj_swift is null then
         begin
           select t.cod_msj_swift
             into v_cod_msj_swift
             from ge_snp_transferencias t
            where t.nro_referencia = v_nro_ref_externa;
         exception
           when no_data_found then
              g_det_msj_error := g_lugar||' No se ha encontrado datos del MT Original';
           when others then
              g_det_msj_error := g_lugar||sqlerrm;
         end;
       end if;
    end if;
   if v_cod_mensaje = 'MTn96/STAT' and
      v_sub_tip_mt in ('NETS','NETR','WAIT','NETA')
   then
      if v_sub_tip_mt = 'NETS' then
        /*
         * MTn96/STAT NETS Confirmaci�n de Lote.
         * Setea Situaci�n = 'L' y Estado = 'A' al lote.
         */
        declare
          cursor cu_msj_tra is
           select ge.nro_referencia,ge.estado --TRFS-1169
             from ge_snp_transferencias ge
            where ge.nro_lote = v_nro_ref_externa
              and ge.cod_msj_swift = v_cod_msj_swift
              and ge.fec_recepcion is null
              and ge.estado in ('A','R') --TRFS-1169
              and ge.situacion = 'O';
          cursor cu_msj_tra_mt104 is
           select ge.nro_referencia,
                  ge.nro_lote,
                  ge.cod_moneda,
                  ge.fec_insercion,
                  ge.cod_per_beneficiario,
                  ge.monto,
                  ge.nom_solicitante,
                  ge.ref_oid,
                  ge.cod_servicio,
                  ge.nro_sec_lote,
                  ge.fec_recepcion,
                  ge.nom_beneficiario,
                  ge.cod_per_solicitante,
				  ge.estado --TRFS-1169
             from ge_snp_transferencias ge
            where ge.nro_lote = v_nro_ref_externa
              and ge.cod_msj_swift = v_cod_msj_swift
              and ge.estado in ('A','R') --TRFS-1169
              and ge.situacion = 'O';
        begin
          if v_cod_msj_swift =104 then
            --DA-8126-Recepcion y procesamiento MT196 NETS relacionado a un MT104 recibido
           g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
            for reg in cu_msj_tra_mt104 loop
               pas_snp.pr_ini_variables;
                  v_error := null;
                  -- Cambia la situacion del MT104 a LIQUIDADO y estado APROBADO.
                  IF reg.estado = 'R' THEN --TRFS-1169
                    update ge_snp_transferencias
                       SET situacion = 'L',
                           estado    = 'R'
                     where nro_referencia = reg.nro_referencia;
                  ELSE

                    update ge_snp_transferencias
                       SET situacion = 'L',
                           estado    = 'A'
                     where nro_referencia = reg.nro_referencia;
                   END IF;
                   if sql%found then
                     --DA-8539-Actualizacion de sb_snp_catastros_det por recepcion del MT196 NETS
                         update sb_snp_catastros_det
                            set estado = 'L'
                          where nro_referencia = reg.nro_sec_lote;
                     if reg.cod_per_beneficiario is not null then
                     --DA-8255-Envio de notificacion al cliente por Orden de debito realizada
                     begin
                        if reg.cod_moneda = g_cod_mon_local then
                       v_moneda := g_cod_mon_iso_local;
                     else
                       v_moneda := reg.cod_moneda;
                    end if;
                    v_des_monto       := TRIM(v_moneda)||' '||ltrim(rtrim(to_char(reg.monto, '999999999999999')));
                    v_inf_json        := '{' || '"nro_lote":' || '"' || reg.nro_lote|| ',' || -- Nro. Transaccion
                                                '"fec_transferencia":' || '"' || to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || --Fecha y hora de la transaccion
                                                '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y monto
                                                '"solicitante":' || '"' || reg.nom_solicitante || '"' || ',' || --Solicitante
                                                '"servicio":' || '"' || reg.ref_oid || '"' || '}'; --Servicio
                         --Insertar correo para el cliente  por debito directo
                         pas_spi.pr_env_alerta(reg.cod_per_beneficiario,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTORDDEB'),v_inf_json);
                     exception
                        when others then
                          null;--no realiza accion si da error envio de correo
                     end;
                     end if;
                   end if;
                   --Verificar que si alguna instruccion recibida est� relacionada a un circuito de aprobacion de cancelacion de instruccion
                   --Se cancela el circuito
                        /*Se recupera el circuito generado para la cancelaci�n*/
                        begin
                            select *
                              into rg_cir
                              from wf_circuitos
                             where referencia = reg.nro_referencia
                               and estado not in ('C', 'F');
                        exception
                          when no_data_found then
                                  null;
                          when others then
                                  null;
                        end;
                  if rg_cir.cod_circuito is not null then
                      begin
                        --Se actualiza a cancelada las tareas para las tablas
                        --wf_cir_tareas y wf_circuitos
                        update wf_cir_tareas
                           set estado = 'C'
                         where cod_circuito = rg_cir.cod_circuito
                           and estado = 'P';
                        --
                        update wf_circuitos
                           set estado = 'C'
                         where cod_circuito = rg_cir.cod_circuito;

                      exception
                        when others then
                          raise_application_error(-20007,
                                                  'Error al cancelar circuito: ' ||
                                                  nvl(paw_cir.fu_obt_cod_error, SQLERRM));
                      end;
                  end if;


            end loop;
            pas_snp.pr_set_texto( g_det_msj_error, v_error, pas_snp.fu_obt_salto );
          else
             g_lugar := 'Recorre las Operaciones en Cursor cu_msj_tra, ';
            for reg in cu_msj_tra loop
               pas_snp.pr_ini_variables;

               -- Verifica que no tenga Workflow para liquidar autom�ticamente.
               if not pas_snp.fu_ver_workflow( to_char( reg.nro_referencia ) ) then
                  v_error := null;
                  -- Cambia la situaci�n del MT102 a LIQUIDADO y estado APROBADO.
                  -- Si no existen errores se actualiza el Estado del Mensaje Origen en GE_SNP_TRANSFERENCIAS
                  IF reg.estado = 'R' THEN --TRFS-1169
                    update ge_snp_transferencias
                       SET situacion = 'L',
                           estado    = 'R'
                     where nro_referencia = reg.nro_referencia;
                  ELSE
                    UPDATE ge_snp_transferencias
                       SET situacion = 'L',
                           estado    = 'A'
                     WHERE nro_referencia = reg.nro_referencia;
                   END IF;
                   --HA-2637
                   if pas_snp.fu_obt_cod_error=0 then
                       pas_snp.pr_ini_variables;
                       pas_snp.pr_obt_mensaje(reg.nro_referencia);
                       if pas_snp.fu_obt_cod_error = 0 then
                          rg_snp_tra := pas_snp.fu_obt_reg_transferencias;
                          pas_snp.pr_env_alerta( rg_snp_tra, 'C' );
                       end if;
                   end if;
               end if ;
            end loop;
            pas_snp.pr_set_texto( g_det_msj_error, v_error, pas_snp.fu_obt_salto );
          end if;
        end;
        v_txt_mail := 'Confirmaci�n de Lote MT' || v_cod_msj_swift || v_txt_mail;
      elsif v_sub_tip_mt = 'WAIT' then
         /*
         * MTn96/STAT WAIT Transferencia en Demora.
         * Setea Situaci�n = 'D'.
         */
         v_nro_ref_externa := pas_snp.fu_obt_nro_ref_relacionada(v_nro_ref_externa);
         pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
         if pas_snp.fu_obt_cod_error = 0 then
            g_msj.situacion := 'D';
            pas_snp.pr_set_transferencias ( g_msj );
            v_asunto := 'Mensajer�a en Demora - SNP.';
            v_txt_mail := 'Transferencia en Demora' || v_txt_mail;
            v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
            'Nro. Cuenta    : ' || g_msj.nro_cta_pte_solicitante || chr(10) ||
            'Nro. Referencia: ' || g_msj.nro_referencia || chr(10) ||
            'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
            'Tipo Operaci�n : ' || pas_snp.fu_obt_des_tip_operacion( g_msj.cod_msj_swift,
                                                                     g_msj.cod_tip_operacion,
                                                                     g_msj.cod_sub_tip_operacion) || chr(10) ||
            'Moneda         : ' || g_msj.cod_moneda || chr(10) ||
            'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99'));
         else -- Tiene Errores
            pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
            pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         end if;
      elsif v_sub_tip_mt in ('NETR', 'NETA') then
         /*
         * MTn96/STAT NETR Precompensacion OK.
         * Mensaje aceptado para el Neteo de hoy. Puede ser cancelado por el participante.
         * Setea Situaci�n = 'O' para los MT102 Enviados.
         */
         begin
           select distinct(ge.fec_recepcion)
             into v_fec_rec
             from ge_snp_transferencias ge
            where ge.nro_lote = v_nro_ref_externa
              and ge.cod_msj_swift = v_cod_msj_swift
              and trunc(ge.fec_insercion) < g_fec_actual;
          exception
           when no_data_found then
             v_fec_rec := null;
         end;

         g_lugar := 'Condiciona cod_msj_swift para validar mt104, ';
         if v_cod_msj_swift !=104 then
           g_lugar := 'Actualizando Situaci�n a Pre-Proceso OK, ';
               UPDATE ge_snp_transferencias
                  SET situacion = 'O'
               WHERE nro_lote = v_nro_ref_externa;
               if sql%rowcount > 0 then
                  v_txt_mail := 'Precompensacion OK '|| v_txt_mail;
               else
              v_txt_mail := 'Error: No se encontr� lote '||v_nro_ref_externa;
               end if;
          else
            --DA-7725- Recepcion y procesamiento MT196 NETR relacionado a un MT104 recibido
                if v_sub_tip_mt='NETR' then
                  -- SI ES UN RECIBIDO
                  if v_fec_rec is not null then
                    begin
                           g_lugar := 'Invoca a pr_pro_rec_mt104,para proceso del mt104 ';
                           pas_snp.pr_ini_variables;
                           v_error := null;
                           pr_pro_rec_mt104(v_nro_ref_externa);
                           pas_snp.pr_set_texto( g_det_msj_error, v_error, pas_snp.fu_obt_salto );
                    end;
                  else -- SI ES UN ENVIADO
                     begin
                       g_lugar := 'Actualizando Situaci�n a Pre-Proceso OK, ';
                           UPDATE ge_snp_transferencias
                              SET situacion = 'O'
                           WHERE nro_lote = v_nro_ref_externa
                           and  situacion= 'V'
                           and estado ='A';
                           if sql%rowcount > 0 then
                              v_txt_mail := 'Precompensacion OK '|| v_txt_mail;
                           else
                          v_txt_mail := 'Error: No se encontr� lote '||v_nro_ref_externa;
                           end if;
                          -- Actualizamos tambi�n el detalle del catastro
                          update sb_snp_catastros_det
                             set estado = 'O'
                           where estado = 'P'
                           and nro_referencia in (select t.nro_sec_lote
                                                      from ge_snp_transferencias t
                                                     where t.nro_lote = v_nro_ref_externa);

                     end;
                   end if;
                end if;
         end if;
      end if;
   elsif v_cod_mensaje = 'MTn96/AUTH' then
      /*
      * MTn96/AUTH Mensaje de autorizaci�n.
      * Setea Situaci�n = 'A'.
      */
      if v_sub_tip_mt != 'ERRC' then
         pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
         if pas_snp.fu_obt_cod_error = 0 then
            g_msj.situacion := 'A';
            pas_snp.pr_set_transferencias ( g_msj );
            if g_msj.cod_msj_swift = 202
             and g_msj.cod_tip_operacion in ('002','003') then
               v_dir_correo := g_err_dir_tesoreria;
               v_asunto := 'Aprobaci�n Tesorer�a BCP - RETIRO/DEPOSITO en EFECTIVO.';
            end if;
            v_txt_mail := 'Mensaje de Autorizaci�n del BCP (AUTH) ' || v_txt_mail;
            v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
            'Nro. Cuenta    : ' || g_msj.nro_cta_pte_solicitante || chr(10) ||
            'Nro. Referencia: ' || g_msj.nro_referencia || chr(10) ||
            'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
            'Tipo Operaci�n : ' || pas_snp.fu_obt_des_tip_operacion( g_msj.cod_msj_swift,
                                                                     g_msj.cod_tip_operacion,
                                                                     g_msj.cod_sub_tip_operacion) || chr(10) ||
            'Moneda         : ' || g_msj.cod_moneda || chr(10) ||
            'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99'));
         else -- Tiene Errores
            pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
            pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         end if;
      end if;
   elsif v_cod_mensaje = 'MTn96/NAUT' then
      /*
       * MTn96/NAUT Transferencia rechazada
       * Marca como cancelado (estado = 'C'), Reversa el Movimiento.
       */
      if v_sub_tip_mt != 'ERRC' then
         begin
            --Obtiene los datos del mensaje.
            pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
            if pas_snp.fu_obt_cod_error = 0 then
               --CANCELA SWIFT POR MTn96.
               g_lugar := 'MTn96: Rechazo de SWIFT por BCP.';
               if g_msj.cod_msj_swift = 202
                 and g_msj.cod_tip_operacion in ('002','003') then
                  --Si es MT202 RETIRO/DEPOSITO en EFECTIVO actualizar situaci�n a X=Rechazo de Tesorer�a BCP
               g_msj.situacion := 'X';
               v_dir_correo := g_err_dir_tesoreria;
               end if;
               --CANCELA EL SWIFT
               g_lugar := 'MTn96: Cancelaci�n de SWIFT .';
               g_msj.estado := 'C';
               pas_snp.pr_set_transferencias ( g_msj );
               --Si es del d�a Cancela el Movimiento
               if g_msj.fec_valor = g_fec_actual then
                  if g_msj.fecha is not null
                    and g_msj.hora is not null
                    and g_msj.cod_usuario is not null then
                     --REVERSA LA OPERACION RELACIONADA AL MENSAJE
                     pas_snp.pr_rev_ope_con_swift( v_nro_ref_externa, 'Rev. Autom�t. CANC. - SNP' );
                     -- Si la reversi�n tiene ERRORES se adjunta el error en la mensajer�a.
                     if pas_snp.fu_obt_cod_error <> 0 then
                        raise ex_salir;
                     end if;
                  end if;
               end if ;
               v_txt_mail := 'Mensaje de Rechazo (NAUT) ' || v_txt_mail;
               v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
               'Nro. Cuenta    : ' || g_msj.nro_cta_pte_solicitante || chr(10) ||
               'Nro. Referencia: ' || g_msj.nro_referencia || chr(10) ||
               'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
               'Tipo Operaci�n : ' || pas_snp.fu_obt_des_tip_operacion( g_msj.cod_msj_swift,
                                                                        g_msj.cod_tip_operacion,
                                                                        g_msj.cod_sub_tip_operacion) || chr(10) ||
               'Moneda         : ' || g_msj.cod_moneda || chr(10) ||
               'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99'));
            else -- Tiene Errores
               pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
               pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
            end if;
         exception
            when ex_salir then
               pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
            when others then
               pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
         end;
      end if;
   elsif v_cod_mensaje = 'MTn96/PRTY' then
     /*
      * MTn96/PRTY Cambio de prioridad.
      * Actualiza prioridad.
      */
      BEGIN
        if v_sub_tip_mt != 'ERRC' then
           --
           g_lugar  := 'Obteniendo datos del Nro. Ref.: ' || v_nro_referencia || ', ';
           v_nro_ref_externa := pas_snp.fu_obt_nro_ref_relacionada(v_nro_ref_externa);
           pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
           if pas_snp.fu_obt_cod_error = 0 then
              -- Si no existen errores se actualiza la prioridad en GE_SNP_TRANSFERENCIAS
              UPDATE ge_snp_transferencias
                 SET prioridad       = v_sub_tip_mt
               WHERE nro_referencia  = v_nro_ref_externa;
              --
              if sql%found then
                 v_txt_mail := 'Mensaje de Cambio de Prioridad ' || v_txt_mail;
                 v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
                 'Nro. Cuenta    : ' || g_msj.nro_cta_pte_solicitante || chr(10) ||
                 'Nro. Referencia: ' || g_msj.nro_referencia || chr(10) ||
                 'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
                 'Tipo Operaci�n : ' || pas_snp.fu_obt_des_tip_operacion( g_msj.cod_msj_swift,
                                                                          g_msj.cod_tip_operacion,
                                                                          g_msj.cod_sub_tip_operacion) || chr(10) ||
                 'Moneda         : ' || g_msj.cod_moneda || chr(10) ||
                 'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99'));
              end if;
           else -- Tiene Errores
              pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
              pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
              pas_snp.pr_ini_variables;
           end if;
        end if;
      EXCEPTION
         when no_data_found then
            g_det_msj_error := g_lugar||' No se ha encontrado datos del MT Original';
         when others then
            g_det_msj_error := g_lugar||sqlerrm;
      END;
   elsif v_cod_mensaje = 'MTn96/ERRC'
     or (v_cod_mensaje = 'MTn96/STAT' and v_sub_tip_mt in('ERRC','ERRP')) then
      BEGIN
        /*
         * MTn96/STAT ERRC ERRP o MTn96/ERRC
         * Marca con estado 'E', reversa operaci�n.
         * Alto y Bajo Valor
         */
         --if v_cod_msj_swift in (103, 202, 541) then agregamos faltante para casos de FLI MGF 16/10/2024 --FIELDESK-113732 --FIELDESK-92937
	       if v_cod_msj_swift in (103, 202, 541, 986) then
            --ALTO VALOR
            g_lugar  := 'Obteniendo datos de la mensajer�a. Nro. Ref.:'||v_nro_ref_externa||', ';
            pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
            if pas_snp.fu_obt_cod_error = 0 then
               g_lugar := 'MTn96: Intentando cancelar el SWIFT por error, ';
               if not ( g_msj.estado = 'A' and g_msj.situacion = 'L' )
                 and ( g_fec_actual - g_dia_max_reversion ) <= g_msj.fec_valor then
                  --CANCELA EL SWIFT SI NO EST� LIQUIDADO Y SI LA FECHA VALOR DEL MENSAJE
                  --SE ENCUENTRA DENTRO DE LO PERMITIDO SEG�N PAR�METRO DE CANTIDAD DE DIAS M�XIMO PARA REVERSI�N
                  if v_cod_msj_swift = 986 then--Actualiza estado y situacion MGF 16/10/2024 --FIELDESK-113732 --FIELDESK-92937
                    g_msj.estado := 'E';
                    g_msj.situacion := 'C';
                  else
                   -- g_msj.estado := 'E';
                   g_msj.situacion := 'C';--TCE-155
                  end if;
                  pas_snp.pr_set_transferencias ( g_msj );
                  --Si tuvo Movimiento Reversa la operaci�n
                  if g_msj.fecha is not null
                    and g_msj.hora is not null
                    and g_msj.cod_usuario is not null
                    --and g_msj.cod_msj_swift <>'541' then
		    and g_msj.cod_msj_swift not in ('541','986') then --MGF 16/10/2024 --FIELDESK-113732 --FIELDESK-92937
                     pas_snp.pr_rev_ope_con_swift( v_nro_ref_externa, 'Rev. Autom�t. ERROR - SNP' );
                     -- Si la reversi�n tiene ERRORES se adjunta el error en la mensajer�a.
                     if pas_snp.fu_obt_cod_error <> 0 then
                        raise ex_salir;
                     end if;
                  end if;
                  if g_msj.cod_msj_swift = 202
                    and g_msj.cod_tip_operacion in ( '002', '003' )then
                     v_asunto := 'Rechazo por Error - RETIRO/DEPOSITO en EFECTIVO.';
                     v_dir_correo := g_err_dir_tesoreria;
                  elsif g_msj.cod_msj_swift = 541 then
                     v_asunto     := 'Rechazo por Error - Operaci�n DEPO.';
                     v_dir_correo := g_err_dir_tesoreria;
                  elsif g_msj.cod_msj_swift = 986 then --Agregamos faltante para operaciones FLI MGF 16/10/2024 --FIELDESK-113732 --FIELDESK-92937
                     v_asunto     := 'Rechazo por Error - Operaci�n FLI.';
                     v_dir_correo := g_err_dir_tesoreria;
                  else
                     v_asunto := 'Cancelaci�n por Error.';
                  end if;
               end if;
               v_txt_mail := 'Mensajer�a Alto Valor con error ('|| v_sub_tip_mt || ') ' || v_txt_mail;
               v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
               'Nro. Cuenta    : ' || g_msj.nro_cta_pte_solicitante || chr(10) ||
               'Nro. Referencia: ' || g_msj.nro_referencia || chr(10) ||
               'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
               'Tipo Operaci�n : ' || pas_snp.fu_obt_des_tip_operacion( g_msj.cod_msj_swift,
                                                                        g_msj.cod_tip_operacion,
                                                                        g_msj.cod_sub_tip_operacion) || chr(10) ||
               'Moneda         : ' || g_msj.cod_moneda || chr(10) ||
               'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99'));
            else -- Tiene Errores
               pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
               pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_ini_variables;
            end if;
         elsif v_cod_msj_swift in (102, 104) then
            --BAJO VALOR
           -- Enviados
            declare
               cursor cu_nro_referencias is
                  select ge.nro_referencia,
                         ge.fecha,
                         ge.hora,
                         ge.cod_usuario
                    from ge_snp_transferencias ge
                   where ge.cod_msj_swift = v_cod_msj_swift
                     --and ge.fec_recepcion is null
                     and ge.nro_lote = v_nro_ref_externa;
                -- Recibidos
                /*cursor cu_msj_tra_mt104 is
                  select ge.nro_referencia,
                         ge.fecha,
                         ge.hora,
                         ge.cod_usuario
                    from ge_snp_transferencias ge
                   where ge.cod_msj_swift = v_cod_msj_swift
                     and ge.fec_recepcion is not null
                     and ge.nro_lote = v_nro_ref_externa;   */

           -- DA-9123 -- MT196 ERRP enviado por la entidad emisora del MT104, no procesa, solo graba en ge_snp_mensajes --
           begin
            if instr(fug_obt_pardinamico('TIP_REC_TOT_INS_196',null, null, null, null),v_cod_cancel) > 0 then
                for reg in cu_nro_referencias loop
                  --DA-7964
                 g_lugar  := 'Obteniendo datos de la mensajer�a. Nro. Ref.:'||reg.nro_referencia||', ';
                 pas_snp.pr_obt_mensaje( reg.nro_referencia, 'N' );
                 if pas_snp.fu_obt_cod_error = 0 then

                  if reg.fecha is not null and
                     reg.hora is not null and
                     reg.cod_usuario is not null
                  then
                     -- REVERSA LA OPERACION RELACIONADA AL MENSAJE
                     pas_snp.pr_rev_ope_con_swift( reg.nro_referencia, 'Rev Autom�t. ERR MT '||v_cod_msj_swift|| ' - SNP' );
                     if pas_snp.fu_obt_cod_error <> 0 then
                        pas_snp.pr_ini_variables;
                     elsif pas_snp.fu_obt_cod_error = 0 then
                        g_msj.estado := 'R';
                        g_msj.situacion := 'C';
                        g_msj.tip_rechazo := v_cod_cancel;
                        pas_snp.pr_set_transferencias ( g_msj );
                        update sb_snp_catastros_det
                         set estado = 'C'
                        where nro_referencia = to_char(reg.nro_referencia);--v_nro_ref_externa;

                     end if;
                  else
                        g_msj.estado := 'R';
                        g_msj.situacion := 'C';
                        g_msj.tip_rechazo := v_cod_cancel;
                        pas_snp.pr_set_transferencias ( g_msj );
                         update sb_snp_catastros_det
                         set estado = 'C'
                         where nro_referencia in (select t.nro_sec_lote
                                                   from ge_snp_transferencias t
                                                   where t.nro_lote=v_nro_ref_externa);

                  end if;
                  v_error := null;
                end if;
               end loop;
          else
             begin
               for reg in cu_nro_referencias loop
                  -- ACTUALIZA EL SWIFT POR ERROR
                  g_lugar := 'MTn96: Cancelaci�n de SWIFT por Error.';
                  update ge_snp_transferencias
                     set estado = 'E',
                         situacion = 'C',
                         error = 'Error '||v_cod_cancel||' al procesar '||v_cod_mensaje||' Lote '||v_nro_ref_externa||'.'
                   where nro_referencia = reg.nro_referencia;
                   update sb_snp_catastros_det
                     set estado = 'C'
                   where nro_referencia = to_char(reg.nro_referencia);
                  if reg.fecha is not null and
                     reg.hora is not null and
                     reg.cod_usuario is not null
                  then
                     -- REVERSA LA OPERACION RELACIONADA AL MENSAJE
                     pas_snp.pr_rev_ope_con_swift( reg.nro_referencia, 'Rev Autom�t. ERR MT '||v_cod_msj_swift|| ' - SNP' );
                     if pas_snp.fu_obt_cod_error <> 0 then
                        pas_snp.pr_ini_variables;
                     end if;
                  end if;
                  v_error := null;
               end loop;
              --end if;
               v_asunto := 'Cancelaci�n de la Mensajer�a MT '||v_cod_msj_swift|| ' por Error - SNP.';
               v_txt_mail := v_error||chr(10)||'Mensajer�a Bajo Valor Enviado con Error ' || v_txt_mail;
            exception
               when others then
                  raise;
             end;
          end if;
        end;
       end if;
      EXCEPTION
         when ex_salir then
            pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         when others then
            pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
      END;
   elsif v_cod_mensaje = 'MTn96/CANC'
     or (v_cod_mensaje = 'MTn96/STAT' and v_sub_tip_mt = 'CANC') then
     /*
      * MTn96/STAT CANC o MTn96/CANC
      * Marca como cancelado (estado = 'C'), Reversa el Movimiento.
      */
      BEGIN
        v_asunto := 'Respuesta por Solicitud de Cancelaci�n';
        if v_sub_tip_mt != 'ERRC' then
           v_txt_mail := 'Se ha Procesado la Petici�n de Cancelaci�n' || v_txt_mail;
           if v_cod_msj_swift in (103,202) then -- Alto Valor
              --Obtiene los datos del mensaje.
              pas_snp.pr_obt_mensaje( v_nro_ref_externa, 'N' );
              if pas_snp.fu_obt_cod_error = 0 then
                 g_lugar := 'MTn96: Intentando cancelar el SWIFT, ';
                 if not ( g_msj.estado = 'A' and g_msj.situacion = 'L' )
                   and ( g_fec_actual - g_dia_max_reversion ) <= g_msj.fec_valor
                 then
                    --CANCELA EL SWIFT SI NO EST� LIQUIDADO Y SI LA FECHA VALOR DEL MENSAJE
                    --SE ENCUENTRA DENTRO DE LO PERMITIDO SEG�N PAR�METRO DE CANTIDAD DE DIAS M�XIMO PARA REVERSI�N
                    g_msj.estado := 'C';
                    g_msj.situacion := 'E';
                    pas_snp.pr_set_transferencias ( g_msj );
                    if g_msj.fecha is not null and
                       g_msj.hora is not null and
                       g_msj.cod_usuario is not null
                    then
                       --REVERSA LA OPERACION RELACIONADA AL MENSAJE
                       pas_snp.pr_rev_ope_con_swift( v_nro_ref_externa, 'Rev. Autom�t. CANC. - SNP' );
                       -- Si la reversi�n tiene ERRORES se adjunta el error en la mensajer�a.
                       if pas_snp.fu_obt_cod_error <> 0 then
                          raise ex_salir;
                       end if;
                    end if;
                 else
                   pas_snp.g_cod_error:= 55;
                   pas_snp.g_msj_error:= g_lugar || 'Se intent� reversar una transferencia ya liquidada o bien la fecha de la misma no permite su reversi�n';
                 end if;
                 v_txt_mail := v_txt_mail || chr(10) || chr(10) || 'Datos de la Transferencia Original: ' || chr(10) ||
                 'Nro. Cuenta    : ' || g_msj.nro_cta_pte_solicitante || chr(10) ||
                 'Nro. Referencia: ' || g_msj.nro_referencia || chr(10) ||
                 'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY') || chr(10) ||
                 'Tipo Operaci�n : ' || pas_snp.fu_obt_des_tip_operacion( g_msj.cod_msj_swift,
                                                                          g_msj.cod_tip_operacion,
                                                                          g_msj.cod_sub_tip_operacion) || chr(10) ||
                 'Moneda         : ' || g_msj.cod_moneda || chr(10) ||
                 'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99'));
              else -- Tiene Errores
                 --pas_snp.g_msj_error := v_error || ', ' || pas_snp.fu_obt_msj_error;
                 --pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                 pas_snp.pr_ini_variables;
                 --TCE-169
                 --No asignar error, ya que la seccion de arriba busca de manera incorrecta el mensaje por el campo 21, dicho valor corresponde
                 -- al nro_referencia del 292 enviado, no asi del 202 original
              end if;
           elsif v_cod_msj_swift in (102, 104) then -- Bajo Valor
             declare
               cursor cu_msj_tra(p_nro_lote ge_snp_transferencias.nro_lote%type) is
                  select ge.nro_referencia
                    from ge_snp_transferencias ge
                   where ge.nro_lote = p_nro_lote;
             begin
               g_lugar := 'Intentando reversar operaciones en LP_PRO_CAN_MT102, ';
               if v_cod_msj_swift in (104) then
                 v_nro_ref_externa:=v_nro_lote;
               end if;
               for reg in cu_msj_tra(v_nro_ref_externa) loop
                  -- Obtiene los datos del mensaje.
                  pas_snp.pr_obt_mensaje( reg.nro_referencia, 'N' );
                  if pas_snp.fu_obt_cod_error = 0 then
                     g_lugar := 'MTn96: Intentando cancelar la transferencia '||reg.nro_referencia||', ';
                     if not ( g_msj.estado = 'A' and g_msj.situacion = 'L' )
                       and ( g_fec_actual - g_dia_max_reversion ) <= g_msj.fec_valor then
                        --CANCELA EL SWIFT SI NO EST� LIQUIDADO Y SI LA FECHA VALOR DEL MENSAJE
                        --SE ENCUENTRA DENTRO DE LO PERMITIDO SEG�N PAR�METRO DE CANTIDAD DE DIAS M�XIMO PARA REVERSI�N
                         if v_cod_msj_swift in (104) then
                             v_nro_ref_externa:=v_nro_lote;
                             g_msj.situacion :='C';
                             g_msj.estado := 'R';
                         else
                             g_msj.estado := 'C';
                         end if;
                        pas_snp.pr_set_transferencias ( g_msj );
                        if g_msj.fecha is not null
                          and g_msj.hora is not null
                          and g_msj.cod_usuario is not null then
                            -- REVERSA LA OPERACION RELACIONADA AL MENSAJE
                            pas_snp.pr_rev_ope_con_swift( reg.nro_referencia, 'Rev. Autom�t. CANC MT'||v_cod_msj_swift||' - SNP' );
                            if pas_snp.fu_obt_cod_error <> 0 then
                               pas_snp.pr_ini_variables;
                            end if;
                        end if;
                     else
                       g_det_msj_error := 'La transferencia '||reg.nro_referencia||' se encuentra liquidada o bien la Fecha Valor no permite su reversi�n';
                     end if;
                  end if;
               end loop;
             exception
                when others then
                  raise;
             end;
           end if;
        end if;
      EXCEPTION
         when ex_salir then
            pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
         when others then
            pas_snp.pr_set_texto( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_ini_variables;
      END;
   end if;

   begin
      g_lugar :=  'Insertando MTn96, ';
      insert into ge_snp_mensajes ( nro_referencia,
                                    nro_ref_externa,
                                    cod_msj_swift,
                                    fec_valor,
                                    msj_swift,
                                    error,
                                    fec_recepcion )
                           values ( v_nro_referencia,
                                    v_nro_ref_externa,
                                    substr( p_mensaje, instr( p_mensaje, '{2:' ) + 4, 3 ),
                                    pas_snp.g_fec_actual,
                                    replace( p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto ),
                                    g_det_msj_error,
                                    sysdate );

   exception
      when dup_val_on_index then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el n�mero de Ref.Externa '|| v_nro_ref_externa ||'!';
         raise ex_salir;
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := SQLERRM;
         raise ex_salir;
   end;

   /*
   || Env�a Correo con los detalles de la mensajer�a recibida
   */
   BEGIN
      if v_dir_correo is not null then
         it_mail.mail( fug_obt_dir_correo,
                       v_dir_correo,
                       v_asunto,
                       v_txt_mail || chr(10) || chr(10) ||
                        'MT Recibido: ' || chr(10) ||
                       p_mensaje || chr(10) || chr(10) || 'Atentamente.'
                     );
      end if;
   EXCEPTION
     when others then
        NULL;
   END;

   if g_det_msj_error is NULL then
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Procesado OK';
   else
      return '00' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || g_det_msj_error;
   end if;

EXCEPTION
   when ex_salir then
      return '99' || '|' || v_cod_mensaje || '|' || v_nro_ref_externa || ' - Error ' || fu_obt_msj_error;
   when others then
      return '99' || '|' || v_cod_mensaje || '|' || SQLERRM;
END fu_pro_msj_mtn96;

FUNCTION fu_pro_msj_mt986( p_mensaje in long ) return varchar2
  /*Procesa la recepci�n del MT986/PCLT, y env�a el MTn99/SETACCOUNTLIMIT en Respuesta
    Procesa la recepci�n del MT986/STAT, y genera movimientos entre las cuentas interbancarias*/
IS
   v_nro_referencia         ge_snp_mensajes.nro_referencia%type;
   v_cod_msj_recepcion      sb_snp_tip_mensajes.cod_mensaje%type := 'MT986';
   v_cod_msj_envio          sb_snp_tip_mensajes.cod_mensaje%type := 'MTn99/SETACCOUNTLIMIT';
   v_cod_moneda             ge_snp_transferencias.cod_moneda%type;
   v_monto                  number;
   v_tipo                   varchar2(1);
   v_msj_retorno            varchar2(4000);
   v_tip_mov_debito         varchar2(1) := 'D';
   v_tip_mov_credito        varchar2(1) := 'C';
   --MT986/STAT
   r_cc_cta_ban_encaje      cc_cta_bancarias%rowtype;
   r_cc_cta_ban_liquidacion cc_cta_bancarias%rowtype;
   v_secuencia              number := 0;
   v_hora                   ge_movimientos.hora%type;
   v_nro_documento          ge_movimientos.nro_documento%type;
   v_nro_cta_bancaria       cc_cta_bancarias.nro_cta_bancaria%type;

BEGIN
   BEGIN
      g_det_msj_error := null;
      pre_cam_for_numerico(',.');

      /*Obtenemos el tipo de MT986 recibido*/
      v_cod_msj_recepcion := v_cod_msj_recepcion||'/'||substr(pao_pmt.fu_obt_val_campo(p_mensaje, '79'), 1, 4);

      if v_cod_msj_recepcion = 'MT986/PCLT' then
         /*So obtiene el Monto y Moneda, Dato esperado: D120319PYG2030000,*/
         g_lugar := 'Obteniendo Monto, Moneda, Tipo y Fecha, ';
         v_tipo   := pao_pmt.fu_obt_tip_valor(pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '79', 5), 'TIP');
         v_cod_moneda := pao_pmt.fu_obt_tip_valor(pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '79', 5), 'MON');
         v_cod_moneda := CASE v_cod_moneda WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE v_cod_moneda END;
         v_monto := fug_obt_pardinamico(p_parametro => 'SNP_MTO_MIN_RESERVA', p_cod_moneda => v_cod_moneda);
         --Si no hay Monto Min�mo configurado para la Moneda.
         if v_monto is not null then
            /*Enviar un MT999 Set Account Limit por el mismo Importe que viene en el MT986 (Campo D)*/
            -- Cabecera y Nro. Referencia
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio,
                                               'CAB',
                                               '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                               '{2:I999'||rpad(fu_obt_bic_sistema,12,'X')||'N}'||
                                               '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '20', fu_obt_sig_nro_referencia);
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/SETACCOUNTLIMIT/CLEARING');
            -- Consulta
            if v_tipo = 'D' then -- Deudor
               v_monto := pao_pmt.fu_obt_tip_valor(pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '79', 5), 'MTO');
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/DIRECTION/I');
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/ACCOUNT'||pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '79', 2));
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/AMOUNT/'||fu_obt_mto_formato(v_monto, v_cod_moneda, 'N'));
            elsif v_tipo = 'C' then -- Acreedor
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/DIRECTION/D');
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/ACCOUNT'||pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '79', 2));
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, '79', '/AMOUNT/'||fu_obt_mto_formato(v_monto, v_cod_moneda, 'N'));
            end if;

            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_envio, 'PIE', '-}');

            -- Obtengo el mensaje envio
            g_lugar := 'Procesando y Enviando '||v_cod_msj_envio||', ';
            pao_pmt.pr_pro_mt_enviado(v_cod_msj_envio, v_msj_retorno);
            if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
              -- TRFS-533-Inserta mensaje para que el OWL/ETL procese



            begin
                         insert into ge_men_env_sipap
                           (nro_referencia, estado, msj_swift)
                         values
                           (pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_envio, '20'),
                            'PENDING',
                            REPLACE(REPLACE(v_msj_retorno,
                                            chr(10),
                                            pas_snp.fu_obt_sal_socket),
                                    chr(13),
                                    ''));
                          exception
                              when others then
                                   -- Hubo problema en la insercion

                                    pas_snp.g_cod_error := 49;
                                    pas_snp.g_msj_error := SQLERRM;
                                    g_det_msj_error := 'Error en la insercion  ' ||
                                    v_cod_msj_recepcion || ' Error: ' || sqlerrm;
                           end;
            else
            pas_snp.pr_gen_arc_swi_lote(v_msj_retorno);
            end if;
            g_lugar := 'Grabando el mensaje Enviado en GE_SNP_MENSAJES, ';
            INSERT INTO ge_snp_mensajes
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
            VALUES
              (pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_envio, '20'),
               null,
               999,
               g_fec_actual,
               v_msj_retorno,
               v_cod_moneda,
               v_monto,
               'V',
               g_det_msj_error,
               v_msj_retorno);
         end if;
      elsif v_cod_msj_recepcion = 'MT986/STAT' then
        begin
           prg_cre_savepoint('TRA_ENC');
           begin
             --Obtengo el monto
             select to_number(pao_pmt.fu_obt_val_delimitador(a.valor, 3))
               into v_monto
               from sb_snp_mensajes_tmp a
              where a.cod_mensaje = v_cod_msj_recepcion
                and a.campo = '79'
                and a.valor like '/L/MANDATORY/%';
             if nvl(v_monto, 0) = 0 then
                g_det_msj_error := 'Error, Monto no encontrado en el ' ||
                                   v_cod_msj_recepcion;
             end if;
           exception
             when others then
               g_det_msj_error := 'Error al hallar el Monto de Encaje en el  ' ||
                                  v_cod_msj_recepcion || ' Error: ' || sqlerrm;
           end;

           --Si no tuvo errores al hallar el monto
           if g_det_msj_error is null then
              g_det_msj_error := '|No existen cuentas de encaje configuradas para.'||pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '59', 1);

              --Obtenemos la moneda
              v_nro_cta_bancaria := pao_pmt.fu_obt_val_delimitador(pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '59', 1) ,1);

              if v_nro_cta_bancaria = pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) then
                 v_nro_cta_bancaria := pao_pmt.fu_obt_val_delimitador(pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '59', 2) ,1);
              end if;
              v_cod_moneda := fu_obt_mon_cta_participante(v_nro_cta_bancaria);

              g_det_msj_error := null;
              begin --Obtengo la cuenta interbancaria de Encaje Legal
                 select c.*
                   into r_cc_cta_ban_encaje
                   from cc_cta_bancarias c, gv_snp_participantes d
                  where c.cod_banco = d.cod_banco --Solo de la entidad
                    and d.cod_persona = fug_obt_per_entidad
                    and c.cod_modulo = pas_snp.fu_obt_cod_mod_padre
                    and c.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
                    and c.cod_moneda = v_cod_moneda
                    and fug_obt_paradicional(c.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'ENC';
              exception
                when others then
                   g_det_msj_error := 'Error al Hallar Cuenta Interbancaria de Encaje Legal: ' ||
                                       sqlerrm;
              end;

              g_det_msj_error := null;
              begin --Obtengo la cuenta interbancaria de Liquidaci�n
                select c.*
                  into r_cc_cta_ban_liquidacion
                  from cc_cta_bancarias c,
                       gv_snp_participantes d
                 where c.cod_banco = d.cod_banco --Solo de la entidad
                   and d.cod_persona = fug_obt_per_entidad
                   and c.cod_modulo = pas_snp.fu_obt_cod_mod_padre
                   and c.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
                   and c.cod_moneda = v_cod_moneda
                   and fug_obt_paradicional(c.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ';
              exception
                 when others then
                    g_det_msj_error := 'Error al Hallar Cuenta Interbancaria: '||sqlerrm;
              end;

              if g_det_msj_error is null then --Si no hay errores en la obtenci�n continuo
                 pag_cta.pr_obt_cuenta(r_cc_cta_ban_encaje.nro_cuenta); --Obtengo la cuenta
                 v_hora := fug_ini_hora; --Inicializo la hora de transacci�n
                 --Definimos el nro_documento a registrar en GE_MOVIMIENTOS
                 v_nro_referencia := pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '20');
                 v_nro_documento  := to_number(substr(v_nro_referencia, 2, instr(v_nro_referencia, '/', 1)-2));
                 if abs(pag_cta.FU_SAL_DISPONIBLE) > v_monto then --Desafectar encaje legal
                    --Hallo la diferencia
                    v_monto := abs(pag_cta.FU_SAL_DISPONIBLE) - v_monto;
                    --Debito interbancaria
                    pag_cta.pr_act_operacion( r_cc_cta_ban_liquidacion.nro_cuenta,-- Nro.Cta.
                                              v_hora,                                              -- Hora
                                              v_tip_mov_debito,                                    -- Tip.Mov.
                                              r_cc_cta_ban_liquidacion.cod_moneda,                 -- Cod.Mon.
                                              v_monto,                                             -- Monto
                                              pas_snp.fu_obt_cod_tra_padre,                        -- Trx.Padre
                                              503,                                                 -- Trx.Hija
                                              v_nro_documento,                                     -- Nro.Doc.
                                              NULL,                                                -- Cotizacion
                                              fug_obt_ofi_usuario (user),                          -- Ofic.Orig.
                                              r_cc_cta_ban_liquidacion.cod_modulo,                 -- Mod.Padre
                                              r_cc_cta_ban_liquidacion.cod_modalidad,              -- Mad.Padre
                                              null,                                                -- Cod.Tasa
                                              null,                                                -- Val.Tasa
                                              'Desafectaci�n Enc.Legal',                           -- Concepto
                                              'N',                                                 -- Emit.Aviso
                                              v_secuencia,
                                              pas_snp.g_fec_actual
                                           );

                    if pag_cta.fu_obt_cod_error <> 0 then
                       g_det_msj_error := '00|' || v_cod_msj_recepcion || '|' ||
                                          v_nro_documento ||
                                          '|Error al Generar Movimiento: ' ||
                                          pag_cta.FU_OBT_MSJ_ERROR;
                    end if;

                    --Credito Interbancaria Enc. Legal
                    pag_cta.pr_act_operacion( r_cc_cta_ban_encaje.nro_cuenta,                      -- Nro.Cta.
                                              v_hora,                                              -- Hora
                                              v_tip_mov_credito,                                   -- Tip.Mov.
                                              r_cc_cta_ban_encaje.cod_moneda,                      -- Cod.Mon.
                                              v_monto,                                             -- Monto
                                              pas_snp.fu_obt_cod_tra_padre,                        -- Trx.Padre
                                              602,                                                 -- Trx.Hija
                                              v_nro_documento,                                     -- Nro.Doc.
                                              NULL,                                                -- Cotizacion
                                              fug_obt_ofi_usuario (user),                          -- Ofic.Orig.
                                              r_cc_cta_ban_encaje.cod_modulo,                      -- Mod.Padre
                                              r_cc_cta_ban_encaje.cod_modalidad,                   -- Mad.Padre
                                              null,                                                -- Cod.Tasa
                                              null,                                                -- Val.Tasa
                                              'Desafectaci�n Enc.Legal',                           -- Concepto
                                              'N',                                                 -- Emit.Aviso
                                              v_secuencia,
                                              pas_snp.g_fec_actual
                                            );

                    if pag_cta.fu_obt_cod_error <> 0 then
                       g_det_msj_error := '00|' || v_cod_msj_recepcion || '|' ||
                                          v_nro_documento ||
                                          '|Error al Generar Movimiento: ' ||
                                          pag_cta.FU_OBT_MSJ_ERROR;
                    end if;

                 elsif abs(pag_cta.FU_SAL_DISPONIBLE) < v_monto then
                    --Constituir encaje legal
                    v_monto := v_monto - abs(pag_cta.FU_SAL_DISPONIBLE);
                    pag_cta.pr_act_operacion( r_cc_cta_ban_encaje.nro_cuenta,                      -- Nro.Cta.
                                              v_hora,                                              -- Hora
                                              v_tip_mov_debito,                                    -- Tip.Mov.
                                              r_cc_cta_ban_encaje.cod_moneda,                      -- Cod.Mon.
                                              v_monto,                                             -- Monto
                                              pas_snp.fu_obt_cod_tra_padre,                        -- Trx.Padre OJO
                                              503,                                                 -- Trx.Hija OJO
                                              v_nro_documento,                                     -- Nro.Doc.
                                              NULL,                                                -- Cotizacion
                                              fug_obt_ofi_usuario (user),                          -- Ofic.Orig.
                                              r_cc_cta_ban_encaje.cod_modulo,                      -- Mod.Padre
                                              r_cc_cta_ban_encaje.cod_modalidad,                   -- Mad.Padre
                                              null,                                                -- Cod.Tasa
                                              null,                                                -- Val.Tasa
                                              'Constituci�n Enc.Legal',                            -- Concepto
                                              'N',                                                 -- Emit.Aviso
                                              v_secuencia,
                                              pas_snp.g_fec_actual
                                            );

                    if pag_cta.fu_obt_cod_error <> 0 then
                       g_det_msj_error := '00|' || v_cod_msj_recepcion || '|' ||
                                          v_nro_documento ||
                                          '|Error al Generar Movimiento: ' ||
                                          pag_cta.FU_OBT_MSJ_ERROR;
                    end if;

                    pag_cta.pr_act_operacion( r_cc_cta_ban_liquidacion.nro_cuenta,                 -- Nro.Cta.
                                              v_hora,                                              -- Hora
                                              v_tip_mov_credito,                                   -- Tip.Mov.
                                              r_cc_cta_ban_liquidacion.cod_moneda,                 -- Cod.Mon.
                                              v_monto,                                             -- Monto
                                              pas_snp.fu_obt_cod_tra_padre,                        -- Trx.Padre OJO
                                              602,                                                 -- Trx.Hija OJO
                                              v_nro_documento,                                     -- Nro.Doc.
                                              NULL,                                                -- Cotizacion
                                              fug_obt_ofi_usuario (user),                          -- Ofic.Orig.
                                              r_cc_cta_ban_encaje.cod_modulo,                      -- Mod.Padre
                                              r_cc_cta_ban_encaje.cod_modalidad,                   -- Mad.Padre
                                              null,                                                -- Cod.Tasa
                                              null,                                                -- Val.Tasa
                                              'Constituci�n Enc.Legal',                            -- Concepto
                                              'N',                                                 -- Emit.Aviso
                                              v_secuencia,
                                              pas_snp.g_fec_actual
                                            );

                    if pag_cta.fu_obt_cod_error <> 0 then
                       g_det_msj_error := '00|' || v_cod_msj_recepcion || '|' ||
                                          v_nro_documento ||
                                          '|Error al Generar Movimiento: ' ||
                                          pag_cta.FU_OBT_MSJ_ERROR;
                    end if;
                 end if;
              end if;
           end if;
        exception
           when others then
             prg_rol_savepoint('TRA_ENC');
        end;
      end if;
      --
      g_lugar := 'Grabando el mensaje Recibido en GE_SNP_MENSAJES, ';
      INSERT INTO ge_snp_mensajes
        (nro_referencia,
         nro_ref_externa,
         cod_msj_swift,
         fec_valor,
         msj_swift,
         cod_moneda,
         monto,
         error,
         fec_recepcion,
         msj_swi_original)
      VALUES
        (fu_obt_sig_nro_referencia,
         pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '20'),
         pao_pmt.fu_obt_cod_msj_swift(pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, 'CAB')),
         g_fec_actual,
         replace(p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto),
         v_cod_moneda,
         v_monto,
         g_det_msj_error,
         sysdate,
         replace(p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto));

      -- Envio Mail
      BEGIN
        it_mail.mail( fug_obt_dir_correo,
                      g_err_dir_correo,
                      'Recepci�n de '||v_cod_msj_recepcion,
                      'Se recibi� un '||v_cod_msj_recepcion||' para la cuenta '||
                      replace(pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '59', 1), '/')||chr(10)||
                      'Monto: '||v_monto||chr(10)||
                      'Errores de Proceso: '||nvl(g_det_msj_error,'Ninguno')||chr(10)||
                      'Mensaje Original: '||chr(10)||
                      p_mensaje
                     );
      EXCEPTION
        when others then
          null;
      END;
   end;

   if g_det_msj_error is NULL then
      return '00|'||v_cod_msj_recepcion||'|' || pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '20') || '|Procesado OK';
   else
      -- Si ocurrieron errores envio alerta.
      BEGIN
         it_mail.mail( fug_obt_dir_correo,
                       g_err_dir_correo,
                       'Error al procesar la recepci�n del '||v_cod_msj_recepcion,
                       'Error: '||g_det_msj_error||
                       chr(10) || chr(10) ||
                       'Atentamente.'
                     );
      EXCEPTION
         when others then
            null;
      END;

      return '00|'||v_cod_msj_recepcion||'|'||pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '20')||g_det_msj_error;

   end if;

exception
   when others then
      -- Si ocurrieron errores envio alerta.
      BEGIN
         it_mail.mail( fug_obt_dir_correo,
                       g_err_dir_correo,
                       'Error al procesar la recepci�n del '||v_cod_msj_recepcion,
                       'Error: '||sqlerrm||
                       chr(10) || chr(10) ||
                       'Atentamente.'
                     );
      EXCEPTION
         when others then
            null;
      END;
      return '99|'||v_cod_msj_recepcion||'|'|| pao_pmt.fu_obt_val_mt_proceso(v_cod_msj_recepcion, '20') || '|Error: ' || sqlerrm;

END fu_pro_msj_mt986;

PROCEDURE pr_ins_transferencias ( rg_msj_ins_tra in rg_msj )
IS
   /*
   || Registra datos de la mensajer�a en la tabla GE_SNP_TRANSFERENCIAS.
   */

BEGIN

    INSERT INTO ge_snp_transferencias ( nro_referencia,
                                        nro_lote,
                                        nro_sec_lote,
                                        cod_modulo,
                                        cod_modalidad,
                                        cod_oficina,
                                        cod_msj_swift,
                                        cod_tip_operacion,
                                        cod_sub_tip_operacion,
                                        msj_swift,
                                        fec_ingreso,
                                        fec_recepcion,
                                        fec_valor,
                                        fecha,
                                        hora,
                                        cod_usuario,
                                        cod_moneda,
                                        monto,
                                        cod_per_solicitante,
                                        nom_solicitante,
                                        dir_solicitante,
                                        cod_tip_doc_solicitante,
                                        nro_doc_solicitante,
                                        nro_cta_solicitante,
                                        cod_swi_pte_solicitante,
                                        cod_swi_suc_solicitante,
                                        nro_cta_pte_solicitante,
                                        nro_cta_suc_pte_solicitante,
                                        cod_per_beneficiario,
                                        nom_beneficiario,
                                        dir_beneficiario,
                                        cod_tip_doc_beneficiario,
                                        nro_doc_beneficiario,
                                        nro_cta_beneficiario,
                                        cod_swi_pte_beneficiario,
                                        cod_swi_suc_beneficiario,
                                        nro_cta_pte_beneficiario,
                                        nro_cta_suc_pte_beneficiario,
                                        concepto,
                                        observacion,
                                        nro_ref_externa,
                                        tip_cargo,
                                        ind_valor,
                                        situacion,
                                        estado,
                                        tip_rechazo,
                                        prioridad,
                                        nro_operacion,
                                        tip_mensaje,
                                        ref_oid,
                                        error,
                                        origen,
                                        plataforma,
                                        indemnizado,
                                        cod_servicio )
                               VALUES ( rg_msj_ins_tra.nro_referencia,
                                        rg_msj_ins_tra.nro_lote,
                                        rg_msj_ins_tra.nro_sec_lote,
                                        rg_msj_ins_tra.cod_modulo,
                                        rg_msj_ins_tra.cod_modalidad,
                                        rg_msj_ins_tra.cod_oficina,
                                        rg_msj_ins_tra.cod_msj_swift,
                                        rg_msj_ins_tra.cod_tip_operacion,
                                        rg_msj_ins_tra.cod_sub_tip_operacion,
                                        rg_msj_ins_tra.msj_swift,
                                        rg_msj_ins_tra.fec_ingreso,
                                        rg_msj_ins_tra.fec_recepcion,
                                        rg_msj_ins_tra.fec_valor,
                                        rg_msj_ins_tra.fecha,
                                        rg_msj_ins_tra.hora,
                                        rg_msj_ins_tra.cod_usuario,
                                        rg_msj_ins_tra.cod_moneda,
                                        rg_msj_ins_tra.monto,
                                        rg_msj_ins_tra.cod_per_solicitante,
                                        rg_msj_ins_tra.nom_solicitante,
                                        rg_msj_ins_tra.dir_solicitante,
                                        rg_msj_ins_tra.cod_tip_doc_solicitante,
                                        rg_msj_ins_tra.nro_doc_solicitante,
                                        rg_msj_ins_tra.nro_cta_solicitante,
                                        rg_msj_ins_tra.cod_swi_pte_solicitante,
                                        rg_msj_ins_tra.cod_swi_suc_solicitante,
                                        rg_msj_ins_tra.nro_cta_pte_solicitante,
                                        rg_msj_ins_tra.nro_cta_suc_pte_solicitante,
                                        rg_msj_ins_tra.cod_per_beneficiario,
                                        rg_msj_ins_tra.nom_beneficiario,
                                        rg_msj_ins_tra.dir_beneficiario,
                                        rg_msj_ins_tra.cod_tip_doc_beneficiario,
                                        rg_msj_ins_tra.nro_doc_beneficiario,
                                        rg_msj_ins_tra.nro_cta_beneficiario,
                                        rg_msj_ins_tra.cod_swi_pte_beneficiario,
                                        rg_msj_ins_tra.cod_swi_suc_beneficiario,
                                        rg_msj_ins_tra.nro_cta_pte_beneficiario,
                                        rg_msj_ins_tra.nro_cta_suc_pte_beneficiario,
                                        rg_msj_ins_tra.concepto,
                                        rg_msj_ins_tra.observacion,
                                        rg_msj_ins_tra.nro_ref_externa,
                                        rg_msj_ins_tra.tip_cargo,
                                        rg_msj_ins_tra.ind_valor,
                                        rg_msj_ins_tra.situacion,
                                        rg_msj_ins_tra.estado,
                                        rg_msj_ins_tra.tip_rechazo,
                                        rg_msj_ins_tra.prioridad,
                                        rg_msj_ins_tra.nro_operacion,
                                        rg_msj_ins_tra.tip_mensaje,
                                        rg_msj_ins_tra.ref_oid,
                                        rg_msj_ins_tra.error,
                                        rg_msj_ins_tra.origen,
                                        rg_msj_ins_tra.plataforma,
                                        rg_msj_ins_tra.indemnizado,
                                        rg_msj_ins_tra.cod_servicio );
EXCEPTION
  WHEN others THEN
    pas_snp.g_cod_error := 45;
    pas_snp.g_msj_error := 'Error al insertar en GE_SNP_TRANSFERENCIAS. Nro. Ref.: ' || rg_msj_ins_tra.nro_referencia || ' - ' || sqlerrm;
END pr_ins_transferencias;

FUNCTION fu_obt_msj_mt103 ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                            p_val_movimientos varchar2 default null
                          ) return varchar2
IS
   /*
   || Generaci�n de la mensajer�a a ser ENVIADA - MT103.
   */
   v_texto       varchar2(4000) := null;
   v_cod_moneda  varchar2(3)    := null;
   v_tag_50a     varchar2(5)    := null;
   v_tag_53a     varchar2(5)    := null;
   v_tag_57a     varchar2(5)    := null;
   v_tag_59a     varchar2(5)    := null;
   v_tag_56a     varchar2(5)    := null; --patrocinador
   v_tag_57d     varchar2(5)    := null; --patrocinador
   v_nro_cta_beneficiario ge_snp_transferencias.nro_cta_beneficiario%type := null;
   v_tax         varchar2(240)    := null;

BEGIN
     --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
     pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
     --

     /*Inicializa las variables de error*/
     pas_snp.pr_ini_variables;

     /*
     || En esta variable se almacenar� todos los errores encontrados y
     || se depositar� en el campo error de GE_SNP_TRANSFERENCIAS.
     */
     pas_snp.g_det_msj_error := null;

     if p_nro_referencia is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_MSJ_MT103. Valor para P_NRO_REFENCIA debe contener algun valor.!';
        raise ex_salir;
     end if;

     --Obtiene el registro de ge_snp_transferencias
     g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
     pas_snp.pr_obt_mensaje ( p_nro_referencia, p_val_movimientos );
     if pas_snp.fu_obt_cod_error <> 0 then
        raise ex_salir;
     end if;

     g_lugar :=  'Validando Datos, ';
     if  g_msj.error is not null then
         pas_snp.g_cod_error := 46;
         pas_snp.g_msj_error := 'Se ha encontrado errores en el registro, valor verifique el campo ERROR.!';
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     if nvl(g_msj.cod_msj_swift,0) <> 103 then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'Valor err�neo para el campo Cod. Mensaje Swift. Debe ser 103.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     if nvl(g_msj.ind_valor,'x') <> 'S' then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El MT103 debe ser considerado como Alto Valor.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     -- ****************************** cabecera del mensaje ********************************************
     g_lugar :=  'Generando cabecera del mensaje, ';
     if g_msj.fec_valor is null and g_msj.fecha is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'Debe ingresar algun valor para el campo Fec. Valor o Fecha.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     if g_msj.prioridad is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Prioridad no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     v_texto := v_texto||pas_snp.fu_obt_cab_msj_swift( p_nro_referencia )||pas_snp.fu_obt_salto;
     if pas_snp.fu_obt_cod_error <> 0 then
        raise ex_salir;
     end if;

     -- ****************************** cuerpo del mensaje **********************************************
     /**/-- :20: Referencia del remitente
     g_lugar :=  'Generando campo :20:, ';
     if g_msj.nro_referencia is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Nro. Referencia no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     v_texto := v_texto||':20:'||g_msj.nro_referencia||pas_snp.fu_obt_salto;

     /**/-- :23B: Tipo de mensaje
     g_lugar :=  'Generando campo :23B:, ';
     if g_msj.tip_mensaje is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Tip. Mensaje no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     v_texto := v_texto||':23B:'||pas_snp.fu_val_cadena(g_msj.tip_mensaje)||pas_snp.fu_obt_salto;

     /**/-- :23E: C�digo de instrucci�n
     v_texto := v_texto||':23E:'||'SDVA'||pas_snp.fu_obt_salto;

     /**/-- :26T: C�digo del tipo de transacci�n
     g_lugar :=  'Generando campo :26T:, ';
     if g_msj.cod_tip_operacion is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Tip. Operaci�n no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     v_texto := v_texto||':26T:'||g_msj.cod_tip_operacion||pas_snp.fu_obt_salto;

     /**/-- :32A: Fecha, Moneda y Monto
     g_lugar :=  'Generando campo :32A:, ';
     if g_msj.cod_moneda is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Cod. Moneda no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.monto is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Monto no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     if g_msj.cod_moneda = g_cod_mon_local then
        v_cod_moneda := g_cod_mon_iso_local;
     else
        v_cod_moneda := g_msj.cod_moneda;
     end if;

     v_texto := v_texto||':32A:'||to_char(g_msj.fec_valor,'RRMMDD')||
                         v_cod_moneda||
                         ltrim(rtrim(to_char(g_msj.monto,pas_snp.fu_obt_mascara||rpad('9',nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => g_msj.cod_moneda),2),'9'))))||
                         pas_snp.fu_obt_salto;

     /**/-- :50a: Ordenante, :53a: Cuenta y BIC del participante origen, :57a: Cuenta y BIC del participante destino, :59: Beneficiario
     g_lugar :=  'Generando campos :50a:,:53a:,:57a:,:59a:, ';
     /**/-- :50a: Ordenante
     if g_msj.nro_cta_solicitante is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Cta. Solicitante no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.nom_solicitante is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Nom. Solicitante no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.cod_tip_doc_solicitante is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Tip. Doc. Solicitante no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.nro_doc_solicitante is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Nro. Doc. Solicitante no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     /**/-- :53a: Cuenta y BIC del participante origen
     if g_msj.nro_cta_pte_solicitante is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Cta. Participante del Solicitante no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.cod_swi_pte_solicitante is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Swift del Participante Solicitante no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     /**/--:59: Beneficiario
     if g_msj.nro_cta_beneficiario is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Cta. Beneficiario no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.nom_beneficiario is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Nom. Beneficiario no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.cod_tip_doc_beneficiario is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Tip. Doc. Beneficiario no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     if g_msj.nro_doc_beneficiario is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Nro. Doc. Beneficiario no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     /**/-- :57a: Cuenta y BIC del participante destino
     if g_msj.nro_cta_pte_beneficiario is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Cta. del Participante Beneficiario no puede ser nulo.!';
        raise ex_salir;
     end if;
     if g_msj.cod_swi_pte_beneficiario is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Swift del Participante Beneficiario no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     g_lugar :=  'Generando tag :50a:, :53a:, :57a:, :59a: ';
     if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_solicitante )then
        v_tag_53a := ':53A:';
     else
        v_tag_53a := ':53D:';
     end if;

     if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_beneficiario )then
        v_tag_57a := ':57A:';
     else
        v_tag_57a := ':57D:';
     end if;
     --patrocinador--
     if g_msj.cod_tip_operacion = '001' and g_msj.cod_sub_tip_operacion = '004' then
       --v_tag_56a := ':56A:'; Modificamos la forma en que carga el tag del 56 MGF 16/02/2022
       if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_beneficiario )then
          v_tag_56a := ':56A:';
       else
          v_tag_56a := ':56D:';
       end if;
       v_tag_57d := ':57D:';
     end if;
     v_tag_50a := ':50K:';
     v_tag_59a := ':59:';
     g_lugar :=  'Generando campo :50a:, ';
     v_texto := v_texto||v_tag_50a||'/'||lpad(pas_snp.fu_val_cadena(g_msj.nro_cta_solicitante),16,'0')||pas_snp.fu_obt_salto
                ||/*'/'||*/fue_obt_tip_doc_abreviatura(g_msj.cod_tip_doc_solicitante)
                ||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nro_doc_solicitante),1,20),'CIN')||pas_snp.fu_obt_salto
                ||/*'/'||*/nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_solicitante),1,34),'NOM')||pas_snp.fu_obt_salto;
              --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_solicitante),35,69),':')||pas_snp.fu_obt_salto
              --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.dir_solicitante),1,34),'DIR')||pas_snp.fu_obt_salto;

     g_lugar :=  'Generando campo :53a:, ';

     v_texto := v_texto||v_tag_53a||'/D/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_solicitante)||pas_snp.fu_obt_salto||
                pas_snp.fu_val_cadena(g_msj.cod_swi_pte_solicitante)||pas_snp.fu_obt_salto;
    if g_msj.cod_tip_operacion = '001' and  g_msj.cod_sub_tip_operacion='004' then
    -- generar cuando es patrocinador
      g_lugar :=  'Generando campo :56a:, ';
      v_texto := v_texto||v_tag_56a||'/C/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_beneficiario)||pas_snp.fu_obt_salto||
                  pas_snp.fu_val_cadena(g_msj.cod_swi_pte_beneficiario)||pas_snp.fu_obt_salto;
    else
      g_lugar :=  'Generando campo :57a:, ';
      --TRFS-840
       if g_bic_hacienda = g_msj.cod_swi_pte_beneficiario then
         v_texto := v_texto||v_tag_57a||'/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_beneficiario)||pas_snp.fu_obt_salto||
         pas_snp.fu_val_cadena(g_msj.cod_swi_pte_beneficiario)||pas_snp.fu_obt_salto;

       else
      v_texto := v_texto||v_tag_57a||'/C/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_beneficiario)||pas_snp.fu_obt_salto||
                  pas_snp.fu_val_cadena(g_msj.cod_swi_pte_beneficiario)||pas_snp.fu_obt_salto;
      end if;
    end if;
     if g_msj.cod_tip_operacion = '001' and  g_msj.cod_sub_tip_operacion='004' then
       g_lugar :=  'Generando campo :57d:, ';
       v_texto := v_texto||v_tag_57d||'/'||pas_snp.fu_val_cadena(g_msj.nro_cta_suc_pte_beneficiario)||pas_snp.fu_obt_salto||
                pas_snp.fu_val_cadena(g_msj.cod_swi_suc_beneficiario)||pas_snp.fu_obt_salto;
    end if;


     g_lugar :=  'Generando campo :59a:, ';
     if fue_val_es_numerico( pas_snp.fu_val_cadena( g_msj.nro_cta_beneficiario ) ) <> 'S' then
        v_nro_cta_beneficiario := g_msj.nro_cta_beneficiario;
     else
        v_nro_cta_beneficiario := lpad(pas_snp.fu_val_cadena(g_msj.nro_cta_beneficiario),16,'0');
     end if;

     v_texto := v_texto||v_tag_59a||'/'||v_nro_cta_beneficiario||pas_snp.fu_obt_salto
                ||/*'/'||*/fue_obt_tip_doc_abreviatura(g_msj.cod_tip_doc_beneficiario)
                ||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nro_doc_beneficiario),1,20),'CIN')||pas_snp.fu_obt_salto
                ||/*'/'||*/nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_beneficiario),1,34),'NOM')||pas_snp.fu_obt_salto;
              --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_beneficiario),35,69),':')||pas_snp.fu_obt_salto
              --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.dir_beneficiario),1,34),'DIR')||pas_snp.fu_obt_salto;

     /**/-- :70: Concepto
     g_lugar :=  'Generando campo :70:, ';
     if nvl(trim(g_msj.concepto),'X') <> 'X' then
        v_texto := v_texto||':70:'||substr(pas_snp.fu_val_cadena(g_msj.concepto),1,100)||pas_snp.fu_obt_salto;
     end if;

     /**/-- :71A: Detalle de Cargos
     g_lugar :=  'Generando campo :71A:, ';
     if g_msj.tip_cargo is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo :71A: no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     v_texto := v_texto||':71A:'||ltrim(rtrim(g_msj.tip_cargo))||pas_snp.fu_obt_salto;

     /**/-- :72: Informaci�n del Remitente al Receptor
     g_lugar :=  'Generando campo :72:, ';
     if g_msj.cod_tip_operacion is null then
        pas_snp.g_cod_error := 46;
        pas_snp.g_msj_error := 'El campo Tip. Operaci�n no puede ser nulo.!';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     else
        v_texto := v_texto||':72:'||'/CODTYPTR/'||g_msj.cod_tip_operacion;
        if g_msj.cod_sub_tip_operacion is not null then
           v_texto := v_texto||'/'||g_msj.cod_sub_tip_operacion;
        end if;

        -- Se anexa palabra clave /TAX/ si el BIC Beneficiario corresponde al Ministerio de Hacienda.
        if g_bic_hacienda = g_msj.cod_swi_pte_beneficiario and
           g_msj.imp_inf_hacienda is not null
        then
		       --TRFS-840
          v_tax:=fue_obt_val_max_refcodes('TAX_IMP_HACIENDA',substr(g_msj.imp_inf_hacienda,2,210));
          v_texto := v_texto||pas_snp.fu_obt_salto||'/BNF/TAX/'||v_tax;
        end if;

        if nvl(trim(g_msj.observacion),'X') <> 'X' then
           -- Si es un mensaje de REVERSION se anexa la sintaxis de reversi�n
           if instr(g_msj.observacion,'/REV/',1,1) > 0 then
              v_texto := v_texto||pas_snp.fu_obt_salto||g_msj.observacion;
           else -- Se anexa como informaci�n del remitente al receptor
              v_texto := v_texto||pas_snp.fu_obt_salto||substr(pas_snp.fu_val_cadena(g_msj.observacion),1,183);
           end if;
        end if;
        v_texto := v_texto||pas_snp.fu_obt_salto;
     end if;

     --Fin de la funci�n
     if v_texto is null then
        raise ex_salir;
     end if;
     -- ********************************* fin del texto ************************************************
     v_texto := v_texto||'-}';

     RETURN v_texto;

EXCEPTION
  when ex_salir then
     RETURN null;
  when others then
     pas_snp.g_cod_error := 46;
     pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_MSJ_MT103: ' || g_lugar || ' - ' || sqlerrm;
     RETURN null;
END fu_obt_msj_mt103;

--
FUNCTION  fu_formato_tag72(p_tag_72 varchar2)
RETURN VARCHAR2
IS
 L_MD t_tag72_md;
 l_md_order t_tag72_md;
 L_INDEX PLS_INTEGER:=1;
 L_SEPARATOR PLS_INTEGER;
 v_tag_72 VARCHAR2(1000);
 V_MD VARCHAR2(1000);
 v_tcp VARCHAR2(1000);

 v_resultado varchar2(1000);


BEGIN

-- TRFS-1187 PHT
--Esta funcion formatea el Tag72 de TCP y MD para mensajes 202
--Dado que las lineas de billetes de MD puede ser mayor a 35 caracteres, y los billetes desordenados
--La funcion asegura que cada linea del MD no sea mayor a 35 caracteres y ordena los billetes

--Quitamos los saltos de linea
  --Corregido por TRFS-1366
  v_tag_72 := REPLACE(REPLACE(REPLACE(p_tag_72,CHR(10),'') ,CHR(13),'') ,'','');

--Guardamos el valor de la linea TCP y el valor de la linea MD
  v_tcp := SUBSTR(v_tag_72,1,instr(v_tag_72,'/MD/') );
  V_MD :=SUBSTR(v_tag_72,instr(v_tag_72,'/MD/')+4,LENGTH(v_tag_72) );

  --Los billetes y sus montos estan separados por el caracter "/" (billete/monto)
  --Se comienza a parsear la linea MD por cada encuentro de ese caracter especial
  L_SEPARATOR := INSTR(V_MD,'/');

  --Busco los pares de billetes y montos y los guardo en un array
  WHILE L_SEPARATOR > 0
  LOOP

    --Se obtiene el valor del billete
    L_MD(L_INDEX).BILLETE := SUBSTR(V_MD,1,L_SEPARATOR-1);


    IF  INSTR(V_MD,'/',L_SEPARATOR+1) > 0 then --Verifico si es el ultimo par billete/monto
      --Si no es el ultimo par de billete/monto, obtengo el monto y busco la siguiente posicion del separador para el siguiente par
      L_MD(L_INDEX).MONTO := SUBSTR(V_MD,L_SEPARATOR+1,INSTR(V_MD,'/',L_SEPARATOR+1) - L_SEPARATOR - 1);
      v_md := SUBSTR(V_MD,INSTR(V_MD,'/',L_SEPARATOR+1)+1,length(v_md));
      L_SEPARATOR := INSTR(V_MD,'/');
    else
      --Si es el ultimo par de billete/monto, obtengo el monto y corto el parseo
      L_MD(L_INDEX).MONTO := SUBSTR(V_MD,L_SEPARATOR+1,length(V_MD));
      L_SEPARATOR := 0;
    end if;

    --La linea MD puede tener saltos de linea, en donde la siguiente linea comenzara con //
    --En esos casos, la posicion del separador / sera 1, asi que corrijo la posicion del separador
    if L_SEPARATOR = 1 then
      v_md := SUBSTR(V_MD,L_SEPARATOR + 1,length(v_md));
      L_SEPARATOR := INSTR(V_MD,'/');
    end if;

     L_INDEX := L_INDEX + 1;


  END LOOP;

   --Ordeno el array por billete
   select billete,monto
   bulk collect into l_md_order
   from table(l_md)
   order by billete desc
   ;


   --Se comienza rearmar la estructura del tag, se agrega primero el valor del TCP
   v_resultado := v_tcp||chr(10);

   --Se agrega ahora el valor del MD (billetes y montos)
   v_md := '/MD';
   if l_md_order.exists(1) then
     for idx in l_md_order.first .. l_md_order.last loop
       --Si la linea es mayor a 35 caracteres, se pasa el par de billete monto a la siguiente linea
       if length(v_md || '/' ||l_md_order(idx).billete || '/' || l_md_order(idx).monto ) <= 35 then
        v_md := v_md || '/' ||l_md_order(idx).billete || '/' || l_md_order(idx).monto;
       else
         v_md   := v_md || chr(10);
         v_resultado := v_resultado || v_md;
         v_md := '//'||l_md_order(idx).billete || '/' || l_md_order(idx).monto;
       end if;
     end loop;
     v_resultado := v_resultado || v_md;
   end if;

   return v_resultado;

END fu_formato_tag72;
--

FUNCTION fu_obt_msj_mt202( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                           p_val_movimientos varchar2 default 'S'
                         ) return varchar2
IS
   /*
   || Generaci�n de la mensajer�a a ser ENVIADA - MT202.
   */

   v_texto      varchar2(4000) := null;
   v_cod_moneda varchar2(3) := null;
   v_tag_53a    varchar2(5) := null;
   v_tag_58a    varchar2(5) := null;
   v_tag_56a    varchar2(5) := null;
   v_tag_57a    varchar2(5) := null;


BEGIN
   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   /*
   || En esta variable se almacenar� todos los errores encontrados y
   || se depositar� en el campo error de GE_SNP_TRANSFERENCIAS.
   */
   pas_snp.g_det_msj_error := null;

   if p_nro_referencia is null then
        pas_snp.g_cod_error := 47;
        pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_MSJ_MT202. Valor para P_NRO_REFENCIA debe contener algun valor.!';
        pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
   end if;

   --Invoco al procedimiento que arma el registro de la transferencia
   g_lugar :=  'Obteniendo los datos del mensaje, ';
   pas_snp.pr_obt_mensaje( p_nro_referencia, p_val_movimientos );
   if pas_snp.fu_obt_cod_error <> 0 then
      pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
      raise ex_salir;
   end if;

   g_lugar :=  'Validando Datos, ';
   if  g_msj.error is not null then
       pas_snp.g_cod_error := 47;
       pas_snp.g_msj_error := 'Se ha encontrado errores en el registro, valor verifique el campo ERROR.!';
       pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
   end if;

   if nvl(g_msj.cod_msj_swift,0) <> 202 then
      pas_snp.g_cod_error := 47;
      pas_snp.g_msj_error := 'Valor err�neo para el campo Cod. Mensaje Swift. Debe ser 202.!';
      pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
   end if;

   -- ****************************** cabecera del mensaje ********************************************
   g_lugar := 'Obteniendo la cabecera del mensaje, ';
   v_texto := v_texto||pas_snp.fu_obt_cab_msj_swift( p_nro_referencia )||pas_snp.fu_obt_salto;
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   end if;

   -- ****************************** cuerpo del mensaje **********************************************
   /**/-- :20: Numero de referencia

   if g_msj.cod_moneda = g_cod_mon_local then
      v_cod_moneda := g_cod_mon_iso_local;
   else
      v_cod_moneda := g_msj.cod_moneda;
   end if;

   v_texto := v_texto||substr(':20:'||trim(g_msj.nro_referencia),1,35)||pas_snp.fu_obt_salto;
   v_texto := v_texto||(':21:'||'NONREF')||pas_snp.fu_obt_salto;
   v_texto := v_texto||substr(':32A:'||to_char(g_msj.fec_valor,'YYMMDD')||
              v_cod_moneda||
              ltrim(rtrim(to_char(g_msj.monto,pas_snp.fu_obt_mascara||rpad('9',nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => g_msj.cod_moneda),2),'9')))),1,35)||
              pas_snp.fu_obt_salto;

   /**/-- :53a: Cuenta y BIC del participante origen, :58a: Cuenta y BIC del participante destino
   g_lugar :=  'Generando campos :53a:,:58a:, ';
   /**/-- :53a: Cuenta y BIC del participante origen
   if g_msj.nro_cta_pte_solicitante is null then
      pas_snp.g_cod_error := 47;
      pas_snp.g_msj_error := 'El campo Cta. Participante del Solicitante no puede ser nulo.!';
      pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
   end if;
   if g_msj.cod_swi_pte_solicitante is null then
      pas_snp.g_cod_error := 47;
      pas_snp.g_msj_error := 'El campo Swift del Participante Solicitante no puede ser nulo.!';
      raise ex_salir;
   end if;
   /**/-- :58a: Cuenta y BIC del participante destino
   if g_msj.nro_cta_pte_beneficiario is null then
      pas_snp.g_cod_error := 47;
      pas_snp.g_msj_error := 'El campo Cta. del Participante Beneficiario no puede ser nulo.!';
      raise ex_salir;
   end if;
   if g_msj.cod_swi_pte_beneficiario is null then
      pas_snp.g_cod_error := 47;
      pas_snp.g_msj_error := 'El campo Swift del Participante Beneficiario no puede ser nulo.!';
      raise ex_salir;
   end if;

   g_lugar :=  'Generando tag :53a:, :58a:, ';
   if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_solicitante )then
      v_tag_53a := ':53A:';
   else
      v_tag_53a := ':53D:';
   end if;

   if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_beneficiario )then
      v_tag_58a := ':58A:';
   else
      v_tag_58a := ':58D:';
   end if;

   g_lugar :=  'Generando campo :53a:, ';
   v_texto := v_texto||v_tag_53a||'/D/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_solicitante)||pas_snp.fu_obt_salto||
              pas_snp.fu_val_cadena(g_msj.cod_swi_pte_solicitante)||pas_snp.fu_obt_salto;
    --TRFS-1043
    if g_msj.cod_tip_operacion='004' and  g_msj.cod_sub_tip_operacion='001' then

    g_lugar :=  'Generando campo :56a:, ';
    if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_beneficiario )then
      v_tag_56a := ':56A:';
   else
      v_tag_56a := ':56D:';
   end if;
    v_texto := v_texto||v_tag_56a||'/C/'||fug_obt_pardinamico( 'SNP_FON_CTA_TRAN_BCP' )||pas_snp.fu_obt_salto||
              pas_snp.fu_val_cadena( fug_obt_pardinamico( 'SNP_BIC_BCP' ))||pas_snp.fu_obt_salto;
    g_lugar :=  'Generando campo :57a:, ';
    if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_beneficiario )then
      v_tag_57a := ':57A:';
   else
      v_tag_57a := ':57D:';
   end if;
    v_texto := v_texto||v_tag_57a||'/'||fug_obt_pardinamico( 'SNP_FON_NRO_ABA_IBAN' )||pas_snp.fu_obt_salto||
              pas_snp.fu_val_cadena(fug_obt_pardinamico( 'SNP_FON_BIC_CORRESPONSAL' ))||pas_snp.fu_obt_salto;

    g_lugar :=  'Generando campo :58a:, ';
    v_texto := v_texto||v_tag_58a||'/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_beneficiario)||pas_snp.fu_obt_salto||
              pas_snp.fu_val_cadena(g_msj.cod_swi_pte_beneficiario)||pas_snp.fu_obt_salto;


  else
   g_lugar :=  'Generando campo :58a:, ';
   v_texto := v_texto||v_tag_58a||'/C/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_beneficiario)||pas_snp.fu_obt_salto||
              pas_snp.fu_val_cadena(g_msj.cod_swi_pte_beneficiario)||pas_snp.fu_obt_salto;

  end if;
   /**/--:72:
   if g_msj.cod_tip_operacion is null then
      pas_snp.g_cod_error := 47;
      pas_snp.g_msj_error := 'Valor para Tipo de Operaci�n debe contener algun valor.!';
      pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
   else
      v_texto := v_texto||':72:'||'/CODTYPTR/'||g_msj.cod_tip_operacion;
      if g_msj.cod_sub_tip_operacion is not null then
         v_texto := v_texto||'/'||g_msj.cod_sub_tip_operacion;
      end if;

      -- Si es un mensaje de REVERSION se anexa la sintaxis de reversi�n
      if instr(g_msj.observacion,'/REV/',1,1) > 0 then
         v_texto := v_texto||pas_snp.fu_obt_salto||g_msj.observacion;
      else -- Se anexa el campo observaci�n dependiendo del caso
         if g_msj.cod_tip_operacion = '002' or
            g_msj.cod_tip_operacion = '003'
         then
            -- Si tipo de Operaci�n es RETIRO/DEPOSITO en EFECTIVO,
            -- el campo 72 debe detallar el C�digo de la Compa��a de Transporte /TPC/ y
            -- la Denominaci�n de Billetes /MD/.';

            if nvl(trim(g_msj.observacion),'X') = 'X' then
               pas_snp.g_cod_error := 47;
               pas_snp.g_msj_error := 'Campo 72 debe contener el detalle del Retiro/Dep�sito en Efectivo.';
               raise ex_salir;
            else
               --Se buscan las palabras claves /TPC/ y /MD/
               if nvl( instr ( g_msj.observacion, '/TPC/', 1 ), 0 ) > 0 and
                  nvl( instr ( g_msj.observacion, '/MD/', 1 ), 0 ) > 0
               then
                  --v_texto := v_texto||pas_snp.fu_obt_salto||g_msj.observacion;
                  -- TRFS-1187 PHT
                  v_texto := v_texto||pas_snp.fu_obt_salto||fu_formato_tag72(p_tag_72 =>  g_msj.observacion);
               else
                  pas_snp.g_cod_error := 47;
                  pas_snp.g_msj_error := 'Campo 72 debe contener C�digo de la Compa��a de Transporte /TPC/ y Denominaci�n de Billetes /MD/.';
                  raise ex_salir;
               end if;
            end if;
         else -- Informaci�n del Remitente al Receptor
            if nvl(trim(g_msj.observacion),'X') <> 'X' then
               v_texto := v_texto||pas_snp.fu_obt_salto||substr(pas_snp.fu_val_cadena(g_msj.observacion),1,183);
            end if;
         end if;
      end if;
   end if;
   v_texto := v_texto||pas_snp.fu_obt_salto;

   -- Si la mensajer�a no se cre� no retorna NADA.
   if v_texto is null then
      raise ex_salir;
   end if;

   -- ********************************* fin del texto ************************************************

   v_texto := v_texto||'-}';

   RETURN  v_texto;

EXCEPTION
  when ex_salir then
     RETURN null;
  when others then
     pas_snp.g_cod_error := 47;
     pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_MSJ_MT202: ' || g_lugar || ' - ' || sqlerrm;
     RETURN null;
END fu_obt_msj_mt202;

PROCEDURE pr_obt_msj_mt102( p_fecha          in ge_snp_transferencias.fecha%type default null,
                            p_ver_cuenta     in varchar2 default 'N', --Verifica o no la Cta. D�bito antes de generar el MT
                            p_val_movimiento in varchar2 default 'S'  --Valida si el SWIFT tiene movimiento o no.
                          )
IS
   /*
   || Generaci�n de la mensajer�a (en batch) a ser ENVIADA - MT102.
   */
   v_est_cuenta     ge_cuentas.estado%type;
   v_sal_disponible ge_cuentas.sal_contable%type;
   v_nro_lote       ge_snp_transferencias.nro_lote%type:= null;
   v_texto          varchar2(4000)       := null;
   v_tag_52a        varchar2(5)          := null;
   v_cod_moneda     varchar2(3)          := null;
   v_cnt_msj        number(4)            := 0;  -- Contador de mensajes.
   v_tot_monto      number               := 0;  --Totalizador de montos para el pie del archivo en lotes.
   c_fec_valor      constant date        := nvl( p_fecha, g_fec_actual );
   v_pos_ini        number               := 0;
   v_procesa        char(1)              := 'N';

   --Vector
   type t_vector is table of ge_snp_transferencias.nro_lote%type
                             index by binary_integer;
   v_vector t_vector;

   cursor cu_msj_baj_valor( p_nro_lote in ge_snp_transferencias.nro_lote%type ) is
         select t.nro_referencia, t.nro_lote, t.nro_sec_lote, t.fec_valor
           from ge_snp_transferencias t
          where t.fec_valor                   <= c_fec_valor
            and t.nro_lote                     = p_nro_lote
            and nvl(t.ind_valor,'N')           = 'N'           -- Bajo Valor
            and t.estado                       IN ( 'A', 'R' ) -- Aprobado y Reversado en ITGF
            and t.situacion                    = 'P'           -- Pendiente de env�o a BCP
            and t.cod_msj_swift                = 102
            and t.tip_cargo                    IS NOT NULL
            and t.prioridad                    IS NOT NULL
            and t.cod_swi_pte_beneficiario     IS NOT NULL
            and t.cod_moneda                   IS NOT NULL
            and t.fec_recepcion                IS NULL
            and t.error                        IS NULL
            and t.monto                        <> 0
          order by t.msj_swift;

   cursor cu_msj_102 is --Cursor que retorna los MT102 a ser enviados
        select t.rowid fila, t.*,
          rank() over ( partition by t.estado, t.cod_swi_pte_beneficiario, t.cod_moneda,
                                     t.cod_tip_operacion, t.cod_sub_tip_operacion,
                                     t.tip_cargo, t.prioridad, t.imp_inf_hacienda
                            order by monto desc
                      ) ord_registro
          from ge_snp_transferencias t
         where fec_valor                 <=  c_fec_valor
           and nvl(t.ind_valor,'N')       = 'N'           -- Bajo Valor
           and t.estado                   IN ( 'A', 'R' ) -- Aprobado y Reversado en ITGF
           and t.situacion                = 'P'           -- Pendiente de env�o a BCP
           and t.cod_msj_swift            = 102
           and t.tip_cargo                IS NOT NULL
           and t.prioridad                IS NOT NULL
           and t.cod_swi_pte_beneficiario IS NOT NULL
           and t.cod_moneda               IS NOT NULL
           and t.fec_recepcion            IS NULL
           and t.error                    IS NULL
           and t.monto                    <> 0
           order by t.nro_cta_solicitante
           for update of t.nro_referencia, t.nro_lote nowait;

   --Registrar error encontrado al intentar procesar mensajer�a de BAJO VALOR y env�a mail.
   PROCEDURE lp_reg_err_transferencia ( rg_reg rg_msj )
   IS
   BEGIN
      /*
      || Si existe alg�n error se actualiza a CANCELADO la mensajer�a y
      || Se env�a un mail a donde corresponda ( si aplica ).
      */
      -- Cancela la mensajer�a.
      g_lugar := 'Cancelando el mensaje, ';
      g_msj.estado := 'C';
      pas_snp.pr_set_transferencias ( rg_reg );
      --

      -- Env�a el mail notificando el error.
      BEGIN
          if g_gru_dir_correo is not null then
             it_mail.mail( fug_obt_dir_correo,
                           g_gru_dir_correo,
                           'Error al intentar env�ar el SWIFT a BCP.',
                           'Se ha encontrado un error al intentar enviar el SWIFT a BCP.' ||
                           ' A continuaci�n los datos de la mensajer�a: '                                   || chr(10) || chr(10) ||
                           'Cliente        : ' || rg_reg.nom_solicitante                                    || chr(10) ||
                           'Nro. Cuenta    : ' || rg_reg.nro_cta_solicitante                                || chr(10) ||
                           'Nro. Operaci�n : ' || rg_reg.nro_operacion                                      || chr(10) ||
                           'Fecha Valor    : ' || to_char( rg_reg.fec_valor, 'DD/MM/YYYY' )                 || chr(10) ||
                           'Moneda         : ' || rg_reg.cod_moneda                                         || chr(10) ||
                           'Monto          : ' || trim( to_char( rg_reg.monto, '999,999,999,999,999.99' ) ) || chr(10) ||
                           'Motivo         : ' || rg_reg.error                                              || chr(10) ||
                           chr(10) || chr(10) ||
                           'Atentamente.'
                         );
          end if;

          -- Env�a alertas al oficial y al cliente.
             pas_snp.pr_env_alerta( g_msj, 'E' );
          --
      EXCEPTION
         when others then
            NULL;
      END;
      --
   EXCEPTION
     when others then
        pas_snp.g_cod_error := 48;
        pas_snp.g_msj_error := 'Error en LP_REG_ERR_TRANSFERENCIA: ' || g_lugar || ' - ' || sqlerrm;
        raise;
   END lp_reg_err_transferencia;

   --Agrupador de mensajes a ser enviado.
   PROCEDURE lp_agr_msj_lote
   IS
      v_mto_destino     ge_movimientos.monto%type := NULL;
      v_cot_origen      ge_movimientos.cotizacion%type := NULL;
      v_cot_destino     ge_movimientos.cotizacion%type := NULL;
      v_nro_lote        ge_snp_transferencias.nro_lote%type;
      v_nro_sec_lote    ge_snp_transferencias.nro_sec_lote%type;

      --Variables del corte de control.
      v_est_msj_ant     ge_snp_transferencias.estado%type;                   -- Estado de la Mensajer�a
      v_swi_pte_ant     ge_snp_transferencias.cod_swi_pte_beneficiario%type; -- BIC Beneficiario
      v_cod_mon_ant     ge_snp_transferencias.cod_moneda%type;               -- C�digo Moneda
      v_tip_ope_ant     ge_snp_transferencias.cod_tip_operacion%type;        -- Tipo Operaci�n
      v_sub_tip_ope_ant ge_snp_transferencias.cod_sub_tip_operacion%type;    -- Sub Tipo Operaci�n
      v_tip_car_ant     ge_snp_transferencias.tip_cargo%type;                -- Tipo Cargo
      v_pri_msj_ant     ge_snp_transferencias.prioridad%type;                -- Prioridad
      v_imp_inf_hac_ant ge_snp_transferencias.imp_inf_hacienda%type;         -- Impuestos para M. Hacienda
      g_nro_cta_solicitante ge_snp_transferencias.nro_cta_solicitante%type;
      v_tot_cuenta         ah_cta_vistas.sal_total%type;

      procedure lp_reg_movimiento(rg_msj_mov in out rg_msj) is --HA-3690

      begin
             pas_snp.pr_ini_registros;
             pas_snp.pr_pro_principal (rg_msj_mov);

             update ge_snp_transferencias tr
             set tr.situacion=rg_msj_mov.situacion,
             tr.estado=rg_msj_mov.estado,
             tr.indemnizado=rg_msj_mov.indemnizado,
             tr.fecha=rg_msj_mov.fecha,
             tr.hora=rg_msj_mov.hora,
             tr.cod_usuario=rg_msj_mov.cod_usuario,
             tr.nro_operacion=rg_msj_mov.nro_operacion,
             tr.error=rg_msj_mov.error
             where tr.nro_referencia=rg_msj_mov.nro_referencia;
       exception
             when others then
                --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                 pas_snp.g_cod_error := 39;
                 pas_snp.g_msj_error :='lp_reg_movimiento ' || ' - ' || sqlerrm;
                 pas_snp.pr_set_texto( rg_msj_mov.error, trim( pas_snp.fu_obt_msj_error ), pas_snp.fu_obt_salto );
       end;
      --Procedimiento que valida el registro que est� siendo procesado.
      PROCEDURE lp_val_registro(rg_reg rg_msj, p_tot_cuenta ah_cta_vistas.sal_total%type)
      IS
      BEGIN
         if rg_reg.estado = 'A' then -- La mensajer�a con estado (R)eversado no debe validar.
            g_lugar :=  'Validando C�d. Mensaje Swift, ';
            if nvl(rg_reg.cod_msj_swift,0) <> 102 then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'Valor err�neo para el campo Cod. Mensaje Swift. Debe ser 102. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando Moneda, ';
            if rg_reg.cod_moneda is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'La Moneda no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando Monto, ';
            if nvl(rg_reg.monto,0) = 0 then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'El Monto debe ser mayor a cero. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando Cta. del Solicitante, ';
            if rg_reg.nro_cta_solicitante is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'La Cta. del Solicitante no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando Nom. Solicitante, ';
            if rg_reg.nom_solicitante is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'El Nom. del Solicitante no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando Cta. del Participante Solicitante, ';
            if rg_reg.nro_cta_pte_solicitante is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'La Cta. del Participante Solicitante no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando BIC del Participante Solicitante, ';
            if rg_reg.cod_swi_pte_solicitante is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'El BIC del Participante Solicitante no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando Cta. del Beneficiario, ';
            if rg_reg.nro_cta_beneficiario is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'La Cta. del Beneficiario no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando Nom. Beneficiario, ';
            if rg_reg.nom_beneficiario is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'El Nom. del Beneficiario no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;
            g_lugar :=  'Validando BIC del Participante Beneficiario, ';
            if rg_reg.cod_swi_pte_beneficiario is null then
               pas_snp.g_cod_error := 48;
               pas_snp.g_msj_error := 'El BIC del Participante Beneficiario no puede ser nulo. Ref.: '||rg_reg.nro_referencia;
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            end if;

            if rg_reg.fecha is null and
               rg_reg.hora is null and
               rg_reg.cod_usuario is null and
               p_ver_cuenta = 'S'
            then-- Si todavia no gener� movimientos se debe verificar la Cuenta.

               g_lugar :=  'Obteniendo los datos de la Cta. ' || rg_reg.nro_cta_solicitante || ', ' ;
               -- Recupera los datos de la Cta. de D�bito
               pag_cta.pr_obt_cuenta( rg_reg.nro_cta_solicitante );

               if pag_cta.fu_obt_cod_error <> 0 then
                  --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                  pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                  pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;
                  pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               end if;

               if pag_cta.fu_obt_cod_error = 0 then

                  if pag_cta.g_ctas.cod_moneda <> g_msj.cod_moneda then
                     g_lugar :=  'Realizando conversi�n de moneda, ';
                     pas_snp.pr_con_mon_a_moneda( g_msj.cod_moneda,
                                                  pag_cta.g_ctas.cod_moneda,
                                                  nvl( g_msj.monto, 0 ),
                                                  v_mto_destino,
                                                  v_cot_origen,
                                                  v_cot_destino
                                                );

                     if pas_snp.fu_obt_cod_error <> 0 then
                        --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error );
                     end if;
                  else
                    v_mto_destino := g_msj.monto;
                  end if;

                  g_lugar :=  'Verificando los datos de la Cta. ' || rg_reg.nro_cta_solicitante || ' (4), ' ;
                  pag_cta.pr_ver_operacion( pag_cta.g_ctas.nro_cuenta,          -- Nro.Cta.
                                            pas_snp.fu_obt_cod_tra_padre,       -- Trx. Padre - Transferencia entre cuentas
                                            pas_snp.fu_obt_cod_mod_padre,       -- Mod.Padre
                                            pas_snp.fu_obt_cod_mad_padre,       -- Mad.Padre
                                            'D',
                                            pag_cta.g_ctas.cod_moneda,          -- Cod.Mon.
                                            --v_mto_destino,                      -- Monto
                                            p_tot_cuenta,
                                            pag_cta.g_ctas.cod_oficina,         -- Ofic.Orig.
                                            pag_cta.g_ctas.cod_modulo,          -- Mod.Padre
                                            pag_cta.g_ctas.cod_modalidad,       -- Mad.Padre
                                            v_est_cuenta,                       -- Estado Cta.
                                            v_sal_disponible,                   -- Sal.Dispon.
                                            v_procesa                           -- Procesa
                                          );

                  if pag_cta.fu_obt_cod_error <> 0 then
                     --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                     pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                     pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                     pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                  else
                      lp_reg_movimiento(g_msj); --HA-3690
				  end if;
               end if;
            end if;
         end if;
      EXCEPTION
         when others then
            pas_snp.g_cod_error := 48;
            pas_snp.g_msj_error := 'Error en LP_VAL_REGISTRO. ' || g_lugar || ' - ' || sqlerrm;
            raise;
      END lp_val_registro;

      --Recupera el mensaje parcial del SWIFT.
      FUNCTION lf_obt_msj_parcial ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                    p_nro_lote       in ge_snp_transferencias.nro_lote%type,
                                    p_nro_sec_lote   out ge_snp_transferencias.nro_sec_lote%type
                                  ) return varchar2
      IS
         /* Para los mensajes que iran en un lote (el campo msj_swift contendr�
         || la porci�n que le corresponder� a dicho mensaje dentro del lote.
         || Para ello el procedimiento recorrer� un VECTOR e ir� generando de
         || forma parcial el swift.
         */
         v_nro_cta_beneficiario ge_snp_transferencias.nro_cta_beneficiario%type := null;
      BEGIN
         /*Inicializa las variables de error*/
         pas_snp.pr_ini_variables;
         --
         v_texto := NULL;

         --Obtiene el registro de ge_snp_transferencias
         g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
         pas_snp.pr_obt_mensaje ( p_nro_referencia, p_val_movimiento );
         if pas_snp.fu_obt_cod_error <> 0 then
            raise ex_salir;
         end if;

         -- ****************************** cuerpo del mensaje **********************************************
         /**/-- 21: Referencia del mensaje
         g_lugar :=  'Generando campo :21:, ';
         p_nro_sec_lote := p_nro_referencia;
         v_texto := v_texto||':21:'||p_nro_sec_lote||pas_snp.fu_obt_salto;

         /**/-- 32B: Moneda y Monto
         g_lugar :=  'Generando campo :32B:, cod_moneda: ';
         if g_msj.cod_moneda = g_cod_mon_local then
            v_cod_moneda := g_cod_mon_iso_local;
         else
            v_cod_moneda := g_msj.cod_moneda;
         end if;
         v_texto := v_texto||':32B:'||
                    v_cod_moneda||
                    replace(ltrim(rtrim(to_char(g_msj.monto,pas_snp.fu_obt_mascara||rpad('9',nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => g_msj.cod_moneda),2),'9')))),'.',',')||
					--ltrim(rtrim(to_char(g_msj.monto,pas_snp.fu_obt_mascara||rpad('9',nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => g_msj.cod_moneda),2),'9'))))||
                    pas_snp.fu_obt_salto;

         g_lugar :=  'Generando campo :50K:, ';
         v_texto := v_texto||':50K:'||'/'||lpad(pas_snp.fu_val_cadena(g_msj.nro_cta_solicitante),16,'0')||pas_snp.fu_obt_salto
                    ||/*'/'||*/fue_obt_tip_doc_abreviatura(g_msj.cod_tip_doc_solicitante)
                    ||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nro_doc_solicitante),1,20),'CIN')||pas_snp.fu_obt_salto
                    ||/*'/'||*/nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_solicitante),1,34),'NOM')||pas_snp.fu_obt_salto;
                  --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_solicitante),35,69),':')||pas_snp.fu_obt_salto
                  --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.dir_solicitante),1,34),'DIR')||pas_snp.fu_obt_salto;

         g_lugar :=  'Generando campo :52a:, ';
         if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_solicitante )then
            v_tag_52a := ':52A:';
         else
            v_tag_52a := ':52B:';
         end if;
         v_texto := v_texto||v_tag_52a||'/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_solicitante)||pas_snp.fu_obt_salto||
                    pas_snp.fu_val_cadena(g_msj.cod_swi_pte_solicitante)||pas_snp.fu_obt_salto;

         g_lugar :=  'Generando campo :57a: ';
         if pas_snp.fu_obt_ind_swi_propio( g_msj.cod_swi_pte_beneficiario )then
            v_texto := v_texto||':57A:'||'/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_beneficiario)||pas_snp.g_salto||
            pas_snp.fu_val_cadena(g_msj.cod_swi_pte_beneficiario)||pas_snp.g_salto;
         else
            v_texto := v_texto||':57C:'||'/'||pas_snp.fu_val_cadena(g_msj.nro_cta_pte_beneficiario)||pas_snp.g_salto;
         end if;

         g_lugar :=  'Generando campo :59:, ';
         if fue_val_es_numerico( pas_snp.fu_val_cadena( g_msj.nro_cta_beneficiario ) ) <> 'S' then
            v_nro_cta_beneficiario := g_msj.nro_cta_beneficiario;
         else
            v_nro_cta_beneficiario := lpad(pas_snp.fu_val_cadena(g_msj.nro_cta_beneficiario),16,'0');
         end if;

         v_texto := v_texto||':59:'||'/'||v_nro_cta_beneficiario||pas_snp.fu_obt_salto
                    ||/*'/'||*/fue_obt_tip_doc_abreviatura(g_msj.cod_tip_doc_beneficiario)
                    ||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nro_doc_beneficiario),1,20),'CIN')||pas_snp.fu_obt_salto
                    ||/*'/'||*/nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_beneficiario),1,34),'NOM')||pas_snp.fu_obt_salto;
                  --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.nom_beneficiario),35,69),':')||pas_snp.fu_obt_salto
                  --||'/'||nvl(substr(pas_snp.fu_val_cadena(g_msj.dir_beneficiario),1,34),'DIR')||pas_snp.fu_obt_salto;

         /**/-- 70: Informaci�n del Remitente
         g_lugar :=  'Generando campo :70:, ';
         if nvl(trim(g_msj.concepto),'X') <> 'X' then
            v_texto := v_texto||':70:';
            if instr(g_msj.concepto,'/REV/',1,1) > 0 then
               v_texto := v_texto||g_msj.concepto||pas_snp.fu_obt_salto;
            else
               v_texto := v_texto||substr(pas_snp.fu_val_cadena(g_msj.concepto),1,100)||pas_snp.fu_obt_salto;
            end if;
         end if;

         --Fin de la funci�n
         if v_texto is not null then
            RETURN v_texto;
         else
            RETURN null;
         end if;
      EXCEPTION
         when ex_salir then
            RETURN null;
         when others then
            pas_snp.g_cod_error := 48;
            pas_snp.g_msj_error := 'Error en LF_OBT_MSJ_PARCIAL: '||g_lugar||' - '||sqlerrm;
            RETURN null;
      END lf_obt_msj_parcial;

   BEGIN -- B L O Q U E   P R I N C I P A L   D E L   P R O C E D I M I E N T O   L O C A L

      v_est_msj_ant     := '.';
      v_swi_pte_ant     := '.';
      v_cod_mon_ant     := '.';
      v_tip_ope_ant     := '.';
      v_sub_tip_ope_ant := '.';
      v_tip_car_ant     := '.';
      v_pri_msj_ant     :=  -1;
      v_imp_inf_hac_ant := '.';

      --Inicializamos el vector
      v_vector.delete;
      g_nro_cta_solicitante := '';
      v_tot_cuenta := 0;

      for reg in cu_msj_102 loop

         pas_snp.g_det_msj_error := NULL;

         if reg.nro_cta_solicitante != nvl(g_nro_cta_solicitante,'X') then
            v_tot_cuenta := 0;
            g_nro_cta_solicitante := reg.nro_cta_solicitante;
         end if;

         v_tot_cuenta := v_tot_cuenta + nvl(reg.monto,0);
         --Obtiene el registro actual
         g_lugar :=  'Procesando datos de la Referencia '||reg.nro_referencia||', ';
         pas_snp.pr_obt_mensaje( reg.nro_referencia, p_val_movimiento );
         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_set_texto ( g_msj.error, pas_snp.fu_obt_det_msj_error, pas_snp.fu_obt_salto );
            lp_reg_err_transferencia ( g_msj );
            GOTO siguiente_registro;
         end if;

         --Verificando Horario del Vigente para el per�odo configurado en GE_SNP_PAR_MENSAJES
         g_lugar :=  'Verificando Horario Vigente en BCP para Nro.Referencia '||reg.nro_referencia||', ';
         if pas_snp.fu_obt_est_horario ( g_msj.cod_msj_swift,
                                         g_msj.cod_tip_operacion,
                                         g_msj.cod_sub_tip_operacion
                                       ) <> 'A' then --Si el horario NO est� VIGENTE en BCP
            if pas_snp.fu_obt_cod_error <> 0 then
               pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
               pas_snp.pr_set_texto ( g_msj.error, pas_snp.fu_obt_det_msj_error, pas_snp.fu_obt_salto );
               lp_reg_err_transferencia ( g_msj );
               GOTO siguiente_registro;
            end if;
         end if;

         --Validando los campos del registro
         g_lugar :=  'Validando datos de la Referencia '||reg.nro_referencia||', ';
         lp_val_registro(g_msj, v_tot_cuenta);
         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            pas_snp.pr_set_texto ( g_msj.error, pas_snp.fu_obt_det_msj_error, pas_snp.fu_obt_salto );
            lp_reg_err_transferencia ( g_msj );
            GOTO siguiente_registro;
         else
         --end if;

         g_lugar :=  'Agrupando registros, ';
         --Realiza la agrupaci�n si todo est� OK.
         if nvl(v_est_msj_ant,'-1')     <> nvl(reg.estado,'-1') or
            nvl(v_swi_pte_ant,'-1')     <> nvl(reg.cod_swi_pte_beneficiario,'-1') or
            nvl(v_cod_mon_ant,'-1')     <> nvl(reg.cod_moneda,'-1') or
            nvl(v_tip_ope_ant,'-1')     <> nvl(reg.cod_tip_operacion,'-1') or
            nvl(v_sub_tip_ope_ant,'-1') <> nvl(reg.cod_sub_tip_operacion,'-1') or
            nvl(v_tip_car_ant,'-1')     <> nvl(reg.tip_cargo,'-1') or
            nvl(v_pri_msj_ant,-1)       <> nvl(reg.prioridad,-1) or
            nvl(v_imp_inf_hac_ant,'-1') <> nvl(reg.imp_inf_hacienda,'-1')
         then
            v_cnt_msj         := 1;
            v_est_msj_ant     := reg.estado;
            v_swi_pte_ant     := reg.cod_swi_pte_beneficiario;
            v_cod_mon_ant     := reg.cod_moneda;
            v_tip_ope_ant     := reg.cod_tip_operacion;
            v_sub_tip_ope_ant := reg.cod_sub_tip_operacion;
            v_tip_car_ant     := reg.tip_cargo;
            v_pri_msj_ant     := reg.prioridad;
            v_imp_inf_hac_ant := reg.imp_inf_hacienda;
            v_nro_lote        := pas_snp.fu_obt_sig_nro_lote;
            --Guardar el Nro. Lote y Sub. Lote en el vector para luego recuperarlo.
            v_vector((v_vector.count)+1) := v_nro_lote;
         else
            v_cnt_msj := v_cnt_msj + 1 ;
         end if;

         g_lugar :=  'Generando SWIFT parcial Nro. Ref.: '|| reg.nro_referencia;
         v_texto := lf_obt_msj_parcial( reg.nro_referencia, v_nro_lote, v_nro_sec_lote );
         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( g_msj.error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
            lp_reg_err_transferencia ( g_msj );
            GOTO siguiente_registro;
         end if;

         --Si se ha llegado a la m�xima cantidad de mensajes en un archivo,
         --hay que lotear hasta esos mensajes y generar un nuevo lote para los registros siguientes.
         g_lugar :=  'Verificando Tipo de Canal, ';
         if v_cnt_msj = g_max_msj_lote then
            v_est_msj_ant     := '.';
            v_swi_pte_ant     := '.';
            v_cod_mon_ant     := '.';
            v_tip_ope_ant     := '.';
            v_sub_tip_ope_ant := '.';
            v_tip_car_ant     := '.';
            v_pri_msj_ant     :=  -1;
            v_imp_inf_hac_ant := '.';
         end if;

         /*
         || Actualizar el NRO.SEC.LOTE y MSJ.SWIFT PARCIAL
         */
         g_lugar :=  'Actualizando datos de Referencia '||reg.nro_referencia||', ';
         update ge_snp_transferencias s
            set s.msj_swift    = v_texto,
                s.nro_lote     = v_nro_lote,
                s.nro_sec_lote = v_nro_sec_lote
          where s.rowid        = reg.fila;

        end if;

         << siguiente_registro >>
            NULL;

      end loop;
   EXCEPTION
     when others then
        pas_snp.g_cod_error := 48;
        pas_snp.g_msj_error := 'Error en LP_AGR_MSJ_LOTE: ' || g_lugar || ' - ' || sqlerrm;
        raise;
   END lp_agr_msj_lote;

   --Generador de archivo SWIFT para enviar al socket.
   PROCEDURE lp_gen_arc_swift
   IS
      v_txt_lote long := NULL;

      --Funcion que recupera la cabecera para el mensaje SWIFT por lotes.
      FUNCTION lf_gen_cab_arc_lote( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                    p_nro_lote       in ge_snp_transferencias.nro_lote%type
                                   ) return VARCHAR2 IS
         v_txt_cab VARCHAR2(500):=NULL;
      BEGIN
         --
         v_txt_cab := pas_snp.fu_obt_cab_msj_swift( p_nro_referencia );
         if pas_snp.fu_obt_cod_error <> 0 then
            return v_txt_cab;
         end if;
         --
         v_pos_ini := instr(v_txt_cab,'{3:')+7;
         v_txt_cab := substr(v_txt_cab,1,v_pos_ini)||'0100'||'}}{4:'||pas_snp.fu_obt_salto;

         g_lugar   := 'Generando campo :20:, ';
         v_txt_cab := v_txt_cab||':20:'||p_nro_lote||pas_snp.fu_obt_salto;

         g_lugar   := 'Generando campo :23:, ';
         v_txt_cab := v_txt_cab||':23:'||'CREDIT'||pas_snp.fu_obt_salto;

         g_lugar   := 'Generando campo :26T:, ';
         v_txt_cab := v_txt_cab||':26T:'||g_msj.cod_tip_operacion||pas_snp.fu_obt_salto;

         g_lugar   := 'Generando campo :71A:, ';
         v_txt_cab := v_txt_cab||':71A:'||g_msj.tip_cargo||pas_snp.fu_obt_salto;

         return v_txt_cab;
      EXCEPTION
         when others then
           pas_snp.g_cod_error := 48;
           pas_snp.g_msj_error := 'Error en LP_GEN_ARC_SWIFT: ' || g_lugar || ' - ' || sqlerrm;
      END lf_gen_cab_arc_lote;

      --Funcion que recupera el pie (fin de archivo) del mensaje SWIFT por lotes.
      FUNCTION lf_gen_pie_arc_lote(rg_mensaje in rg_msj, p_tot_monto in ge_snp_transferencias.monto%type) return VARCHAR2 IS
         v_txt_pie VARCHAR2(500):=NULL;
      BEGIN
         g_lugar :=  'Generando pie del mensaje (:32A:) en archivo por lotes. Nro. Ref.: '||rg_mensaje.nro_referencia||' Lote: '||rg_mensaje.nro_lote||', ';
         --Generar el pie del mensaje y enviar al socket, luego crear un nuevo archivo por lotes.
         if rg_mensaje.cod_moneda = g_cod_mon_local then
            v_cod_moneda := g_cod_mon_iso_local;
         else
            v_cod_moneda := rg_mensaje.cod_moneda;
         end if;

         v_txt_pie := v_txt_pie||':32A:'||to_char(rg_mensaje.fec_valor,'YYMMDD')||
                      v_cod_moneda||
                      replace(ltrim(rtrim(to_char(p_tot_monto,pas_snp.fu_obt_mascara||rpad('9',nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => g_msj.cod_moneda),2),'9')))),'.',',')||
					  --ltrim(rtrim(to_char(p_tot_monto,pas_snp.fu_obt_mascara||rpad('9',nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => g_msj.cod_moneda),2),'9'))))||
                      pas_snp.fu_obt_salto;

         v_txt_pie := v_txt_pie||':72:/CODTYPTR/'||rg_mensaje.cod_tip_operacion;
         if rg_mensaje.cod_sub_tip_operacion is not null then
           v_txt_pie := v_txt_pie||'/'||rg_mensaje.cod_sub_tip_operacion;
         end if;

         -- Se anexa palabra clave /TAX/ si el BIC Beneficiario corresponde al Ministerio de Hacienda.
         if g_bic_hacienda = rg_mensaje.cod_swi_pte_beneficiario and
            rg_mensaje.imp_inf_hacienda is not null
         then
            v_txt_pie := v_txt_pie||pas_snp.fu_obt_salto||'/TAX'||substr(rg_mensaje.imp_inf_hacienda,1,210);
         end if;

         v_txt_pie := v_txt_pie||pas_snp.fu_obt_salto||'-}';
         -- ********************************* fin del texto ************************************************
         return v_txt_pie;
      END lf_gen_pie_arc_lote;

   BEGIN -- B L O Q U E   P R I N C I P A L   D E L   P R O C E D I M I E N T O   L O C A L

      /*Inicializa las variables de error*/
      pas_snp.pr_ini_variables;
      --
      if v_vector.COUNT > 0 then
         --Recuperamos del vector los Nro. Ref.: para la generaci�n
         for i IN v_vector.FIRST..v_vector.LAST loop
             v_nro_lote := NULL;
             if v_vector.EXISTS(i) THEN
                --Se crea el cuerpo del archivo por lotes.
                v_cnt_msj   := 0;
                v_tot_monto := 0;
                v_txt_lote  := NULL;
                for m in cu_msj_baj_valor(v_vector(i)) loop
                   v_nro_lote := m.nro_lote;
                   if v_cnt_msj = 0 then
                      --Se crea la cabecera del archivo por lotes.
                      g_lugar :=  'Generando cabecera para el archivo por lotes, Nro. Ref.: '||g_msj.nro_referencia||', ';
                      v_txt_lote := lf_gen_cab_arc_lote( m.nro_referencia, v_nro_lote );
                      if pas_snp.fu_obt_cod_error <> 0 then
                         raise ex_salir;
                      end if;
                   end if;

                   g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
                   pas_snp.pr_obt_mensaje( m.nro_referencia, p_val_movimiento );
                   if pas_snp.fu_obt_cod_error <> 0 then
                      raise ex_salir;
                   end if;

                   g_lugar :=  'Cargando cuerpo del mensaje en archivo por lotes. Nro. Ref.: '||g_msj.nro_referencia||' Lote: '||g_msj.nro_lote||', ';
                   if g_msj.msj_swift is not null then
                      v_txt_lote  := v_txt_lote||substr(g_msj.msj_swift,1,4000);
                      v_cnt_msj   := v_cnt_msj + 1;
                      v_tot_monto := v_tot_monto + nvl(g_msj.monto,0);
                   end if;
                end loop;
                --Si NO ES FIN DE ARCHIVO, genera pie del mensaje
                if v_cnt_msj > 0 and v_tot_monto > 0 then
                   v_txt_lote := v_txt_lote||lf_gen_pie_arc_lote(g_msj, v_tot_monto);

                    --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
                                 begin
                                     insert into ge_men_env_sipap
                                       (nro_referencia, estado, msj_swift)
                                     values
                                       (v_nro_lote,
                                        'PENDING',
                                        REPLACE(REPLACE(v_txt_lote,
                                                        chr(10),
                                                        pas_snp.fu_obt_sal_socket),
                                                chr(13),
                                                ''));
                                exception
                                when others then
                                     -- Hubo problema en la insercion
                                      pas_snp.g_cod_error := 49;
                                      pas_snp.g_msj_error := SQLERRM;
                                      pas_snp.pr_ins_sb_snp_log_envios(v_nro_lote,
                                                                       'A',
                                                                       'E',
                                                                       pas_snp.g_msj_error);
                                      raise ex_salir;

                               end;
                    else
                    --Se env�a al socket el archivo por lotes.
                    pas_snp.pr_gen_arc_swi_lote(v_txt_lote);
                    end if;
                   g_lugar := 'Actualizando datos en GE_SNP_TRANSFERENCIAS(02)';
                   -- Actualizar el registro de ge_snp_transferencias, situacion Enviado a BCP
                   UPDATE ge_snp_transferencias
                      SET situacion = 'V'
                    WHERE nro_lote  = v_nro_lote;
                   commit; --HA-3690
               end if;
             end if;
         end loop;
      end if;
   EXCEPTION
      when ex_salir then
        raise ex_salir;
      when others then
        pas_snp.g_cod_error := 48;
        pas_snp.g_msj_error := 'Error en LP_GEN_ARC_SWIFT: ' || g_lugar || ' - ' || sqlerrm;
        raise;
   END lp_gen_arc_swift;

BEGIN -- B L O Q U E   D E L   P R O C E D I M I E N T O   P R I N C I P A L

   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --

   /* Inicializa la aplicacion*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   --

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --

   --Si est� vigente el horario
   g_lugar :=  'Agrupando SWIFT 102, ';
   -- Se valida cada registro y luego se agrupan los mensajes que deben ser enviados en lote
   lp_agr_msj_lote;
   commit;
/*   if pas_snp.fu_obt_cod_error <> 0 and g_procesado = 0 then
      raise ex_salir;
   end if;*/
   /* Luego de la generaci�n correcta de los mensajes parciales, se toma
   || del vector todas las referencias y se va enviando por NRO_REFERENCIA,
   || n-archivos dependiendo del n�mero de operaciones m�ximas definido en g_max_msj_lote
   */
   g_lugar :=  'Enviando SWIFT 102 al socket, ';
   lp_gen_arc_swift;

EXCEPTION
  when ex_horario then
     pas_snp.g_cod_error := 48;
     pas_snp.g_msj_error := g_lugar || ' ' || pas_snp.fu_obt_msj_error;
  when ex_salir then
     pas_snp.g_cod_error := 48;
     pas_snp.g_msj_error := g_lugar || ' - ' || pas_snp.fu_obt_msj_error;
  when others then
     pas_snp.g_cod_error := 48;
     pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
END pr_obt_msj_mt102;

PROCEDURE pr_obt_msj_mtn92 ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type )
IS
   v_nro_referencia         ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa         ge_snp_transferencias.nro_lote%type;
   v_tip_msj_swift           ge_snp_transferencias.cod_msj_swift%type;
   v_bic_entidad             ge_snp_transferencias.cod_swi_pte_solicitante%type := NULL;
   v_valor_canc              number := fug_obt_pardinamico('SNP_DIA_DEB_CONFIRMACION');
   v_fec_liq                 ge_calendarios.fec_proxima%type;
   v_texto                   varchar2(4000) := null;
   v_resp                    varchar2(4000) :=null;
   v_cod_causa               wf_cir_tareas.cod_causa%type;
   v_mot_rch                 ge_snp_transferencias.tip_rechazo%type;
   v_desc_rch                varchar2(4000);
   PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN
    --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
    pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
    --
    /*Inicializa las variables de error*/
    pas_snp.pr_ini_variables;

    if p_nro_referencia is null then
       pas_snp.g_cod_error := 49;
       pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn92. Valor para P_NRO_REFENCIA debe contener algun valor.!';
       raise ex_salir;
    end if;

    --Obtiene el registro de ge_snp_transferencias
    g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
    pas_snp.pr_obt_mensaje ( p_nro_referencia, 'N' );
    if pas_snp.fu_obt_cod_error <> 0 then
       raise ex_salir;
    end if;

    g_lugar :=  'Averiguando Horario Vigente en BCP, ';
    if pas_snp.fu_obt_est_horario( g_msj.cod_msj_swift,
                                   g_msj.cod_tip_operacion,
                                   g_msj.cod_sub_tip_operacion
                                 ) = 'A' then--Si el horario est� VIGENTE en BCP

       if pas_snp.fu_obt_cod_error <> 0 then
          raise ex_salir;
       end if;

       if g_msj.cod_msj_swift is null then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'El C�d.Swift no puede ser nulo.!';
          raise ex_salir;
       elsif nvl(g_msj.cod_msj_swift,0) not in (103,102,104,110,202) then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'El C�d.Swift debe tener alg�n valor permitido.!';
          raise ex_salir;
       elsif nvl(g_msj.cod_msj_swift,0) in (103,102,104,110) then
          v_tip_msj_swift := 192;
       else
          v_tip_msj_swift := 292;
       end if;

       if g_msj.fec_valor is null then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'El campo Fecha Valor no puede ser nulo.!';
          raise ex_salir;
       end if;

       -- ****************************** cabecera del mensaje ********************************************

       g_lugar :=  'Generando cabecera del mensaje, ';
       if g_msj.fec_valor is null and g_msj.fecha is null then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'Debe ingresar algun valor para el campo Fec. Valor o Fecha.!';
          raise ex_salir;
       end if;

       if g_msj.prioridad is null then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'El campo Prioridad no puede ser nulo.!';
          raise ex_salir;
       end if;

       --Valida si est� correcto el c�digo de usuario del X-ADAPTER
       if nvl( length( g_usu_xadapter ), 0 ) <> 12 then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER debe tener longitud de 12 caracteres';
          raise ex_salir;
       elsif v_bic_entidad <> substr(g_usu_xadapter,1,8) then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER no corresponde a la entidad';
          raise ex_salir;
       end if;

       v_texto := v_texto||
                  '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'/*0000000000*/||
                  '{2:I'||v_tip_msj_swift||rpad(fu_obt_bic_sistema/*R=RTSX, D=DEPO*/,12,'X')||'N}'||
                  '{3:{113'||':'||lpad(g_msj.prioridad,4,'0')||'}}{4:'||pas_snp.fu_obt_salto;

       -- ****************************** cuerpo del mensaje **********************************************
       v_nro_referencia := fu_obt_sig_nro_referencia;
       if pas_snp.fu_obt_cod_error <> 0 then
          raise ex_salir;
       end if;
       /**/-- 20: Referencia del mensaje
       g_lugar :=  'Generando campo :20:, ';
       v_texto := v_texto||':20:'||v_nro_referencia||pas_snp.fu_obt_salto;

       /**/-- 21: Referencia del remitente
       g_lugar :=  'Generando campo :21:, ';
        if nvl(g_msj.cod_msj_swift,0) not in (104) then
           v_nro_ref_externa := CASE g_msj.cod_msj_swift
                                  WHEN 103 THEN
                                    g_msj.nro_referencia
                                  WHEN 202 THEN
                                    g_msj.nro_referencia
                                  ELSE
                                    g_msj.nro_lote
                                END;
       else

                                v_nro_ref_externa :=g_msj.nro_lote;
      end if;
       if v_nro_ref_externa is null then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'El campo Nro. Referencia externa no puede ser nulo.!';
          raise ex_salir;
       end if;

       v_texto := v_texto||':21:'||v_nro_ref_externa||pas_snp.fu_obt_salto;

       /**/-- 11S: Codigo de MT, Fecha
       g_lugar :=  'Generando campo :11S:, ';
       v_texto := v_texto||':11S:'||to_char(g_msj.cod_msj_swift)||pas_snp.fu_obt_salto||
                  to_char(g_msj.fec_valor,'RRMMDD')||pas_snp.fu_obt_salto;--TCE-190

       /**/-- 79: BIC del participante origen, Fecha Valor
       g_lugar :=  'Generando campo 79, ';
       if g_msj.cod_swi_pte_solicitante is null then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'El campo Swift del Participante Solicitante no puede ser nulo.!';
          raise ex_salir;
       end if;
	  -- Calcular fecha de liquidaci�n --
      if nvl(g_msj.cod_msj_swift,0) not in (104) then
         v_fec_liq:= g_fec_actual;
      else
          v_fec_liq:= pag_cal.fu_obt_fec_sig_hab(g_msj.fec_ingreso,fug_obt_ofi_usuario(user),1);
      end if;
       v_texto := v_texto||':79:'||fu_val_cadena(g_msj.cod_swi_pte_solicitante)||pas_snp.fu_obt_salto||
                  to_char(nvl(v_fec_liq,g_msj.fec_valor),'RRMMDD'||pas_snp.fu_obt_salto);

       if nvl(g_msj.cod_msj_swift,0) in (104) then
           v_mot_rch :=g_msj.tip_rechazo;--TCE-87
           v_desc_rch:=fue_obt_des_refcodes('TIP_REC_SNP',v_mot_rch);
           v_texto := v_texto||'/DESC/'||v_mot_rch||pas_snp.fu_obt_salto; -- DA-9301 --
           v_texto := v_texto||v_desc_rch||pas_snp.fu_obt_salto;

      elsif  nvl(g_msj.cod_msj_swift,0) in ('102','103','202') then--TCE-88

           v_mot_rch :=g_msj.tip_rechazo;
           v_desc_rch:=fue_obt_des_refcodes('TIP_REC_SNP',v_mot_rch);
           v_texto := v_texto||'/DESC/'||v_mot_rch||pas_snp.fu_obt_salto; -- DA-9301 --
           v_texto := v_texto||v_desc_rch||pas_snp.fu_obt_salto;
      end if;
       if v_texto is null then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := 'No se ha generado el MTn92, no se puede continuar.!';
          raise ex_salir;
       end if;

       -- ********************************* fin del texto ************************************************

       v_texto := v_texto||'-}';
       g_lugar := 'Comprobando Duplicados, ';
       pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
       if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then--TCE-59
          begin
            insert into ge_men_env_sipap
              (nro_referencia, estado, msj_swift)
            values
              (v_nro_referencia,
               'PENDING',
               REPLACE(REPLACE(v_texto,
                               chr(10),
                               pas_snp.fu_obt_sal_socket),
                       chr(13),
                       ''));
          exception
            when others then
              -- Hubo problema en la insercion
              v_resp              := SQLERRM;
              pas_snp.g_ok :='N';
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'E',
                                               pas_snp.g_msj_error);
              raise ex_salir;

          end;
           pas_snp.g_ok :='S';
           v_resp:='00';
       else

       g_lugar := 'Conect�ndose al socket';
       -- Envia el mensaje al servidor
       pas_snp.g_ok := fue_env_tcp_mensajes( p_servidor   => pas_snp.g_servidor,
                                             p_puerto     => pas_snp.g_puerto,
                                             p_tie_espera => pas_snp.g_tie_espera,
                                             p_mensaje    => pas_snp.fu_con_mensaje(v_texto),
                                             p_respuesta  => v_resp
                                           );
       end if;
       if pas_snp.g_ok != 'S' THEN
          -- Hubo problema en el envio
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := v_resp;
          g_lugar := 'Actualizando Error en el LOG, ';
          pr_ins_sb_snp_log_envios(v_nro_referencia, 'A', 'N', pas_snp.g_msj_error);
          if nvl(g_msj.cod_msj_swift,0) =104 then
             IF pas_snp.fu_obt_cod_error <> 0 THEN
                raise_application_error(-20206, pas_snp.fu_obt_msj_error);--arroja error al circuito
             END IF;
          end if;
          raise ex_salir;
       else
         if substr(v_resp,1,2) = '00' then
            g_lugar := 'Actualizando datos en ge_snp_transferencias';
            --Se inserta en GE_SNP_MENSAJES
            BEGIN
                /*Inicializa la aplicacion*/
                begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
                --
                g_lugar :=  'Insertando en GE_SNP_MENSAJES, ';
                INSERT INTO ge_snp_mensajes ( nro_referencia,
                                              nro_ref_externa,
                                              cod_msj_swift,
                                              fec_valor,
                                              situacion,
                                              msj_swift )
                                     VALUES ( v_nro_referencia,
                                              v_nro_ref_externa,
                                              v_tip_msj_swift,
                                              g_fec_actual,
                                              'V',
                                              v_texto );
            EXCEPTION
               when others then
                  pas_snp.g_cod_error := 49;
                  pas_snp.g_msj_error := g_lugar ||' - '|| sqlerrm;
                  raise ex_salir;
            END;
         else
            pas_snp.g_cod_error := 49;
            pas_snp.g_msj_error := substr('Archivo no generado ' || v_resp,1,1000);
            raise ex_salir;
         end if;
       end if;
     --Fin de la funci�n
    else
       if nvl(g_msj.cod_msj_swift,0)=104 then
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := substr('Archivo no generado, horario Inactivo ' ,1,1000);
             IF pas_snp.fu_obt_cod_error <> 0 THEN
                raise_application_error(-20206, pas_snp.fu_obt_msj_error);--arroja error al circuito
             END IF;
       else
       raise ex_salir;
       end if;
    end if;
    commit;
EXCEPTION
  when ex_salir then
     pas_snp.g_cod_error := 49;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn92: '||g_lugar||' - '||fu_obt_msj_error;
  when others then
     pas_snp.g_cod_error := 49;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn92: '||g_lugar||' - '||sqlerrm;
END pr_obt_msj_mtn92;

PROCEDURE pr_obt_msj_mtn95 ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                             p_tip_mensaje    in varchar2,
                             p_prioridad      in ge_snp_transferencias.prioridad%type default null
                           )
IS
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_ref_externa%type;
   v_tip_msj_swift    ge_snp_transferencias.cod_msj_swift%type;
   v_bic_entidad      ge_snp_transferencias.cod_swi_pte_solicitante%type := NULL;
   v_texto            varchar2(4000) := null;
   v_resp             varchar2(4000) :=null;

   PRAGMA AUTONOMOUS_TRANSACTION;

   procedure lp_obt_n95_stat is
      v_cod_mensaje sb_snp_mensajes_tmp.cod_mensaje%type := 'MTn95/STAT';
   begin
      delete sb_snp_mensajes_tmp;
      --Obtengo el mensaje a consultar
      g_lugar := 'Obteniendo Datos de la Transferencia';
      pas_snp.pr_obt_mensaje ( p_nro_referencia, 'N' );
      if pas_snp.fu_obt_cod_error <> 0 then
         raise ex_salir;
      end if;
      --Obtengo el msj swift
      v_tip_msj_swift := substr(g_msj.cod_msj_swift, 1, 1) || '95';
      --Inserto la Cabecera del MTn95/STAT
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          'CAB',
                                          '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                          '{2:I'||v_tip_msj_swift||rpad(fu_obt_bic_sistema,12,'X')||'N}'||
                                          '{3:{113'||':'||lpad(g_msj.prioridad,4,'0')||'}}{4:'
                                        );

      --Inserto el campo 20 Nro. Referencia de la Transaccion
      v_nro_referencia := fu_obt_sig_nro_referencia;
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          '20',
                                          v_nro_referencia
                                        );

      --Inserto el campo 21 Referencia Relacionada
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          '21',
                                          nvl(g_msj.nro_lote, g_msj.nro_referencia)
                                        );

      --Inserto el campo 75 Tipo de Consulta
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          '75',
                                          p_tip_mensaje
                                        );

      --Inserto el campo 11S C�digo del MT solicitado
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          '11S',
                                          g_msj.cod_msj_swift
                                        );

      --Inserto el campo 11S Fecha del MT solicitado
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          '11S',
                                          to_char(g_msj.fec_valor,'RRMMDD')
                                        );

      --Inserto el campo 79
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          '79',
                                          g_msj.cod_swi_pte_solicitante
                                        );

      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          '79',
                                          to_char(g_msj.fec_valor,'RRMMDD')
                                        );

      --Inserto el PIE
      pao_pmt.pr_ins_sb_snp_mensajes_tmp( v_cod_mensaje,
                                          'PIE',
                                          '-}'
                                        );
      g_lugar := 'Procesando Esquema';
      pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_texto);
      g_lugar := 'Comprobando Duplicados, ';
      pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
      if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then--TCE-191
          begin
            insert into ge_men_env_sipap
              (nro_referencia, estado, msj_swift)
            values
              (v_nro_referencia,
               'PENDING',
               REPLACE(REPLACE(v_texto,
                               chr(10),
                               pas_snp.fu_obt_sal_socket),
                       chr(13),
                       ''));
          exception
            when others then
              -- Hubo problema en la insercion
              v_resp              := SQLERRM;
              pas_snp.g_ok :='N';
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'E',
                                               pas_snp.g_msj_error);
              raise ex_salir;

          end;
           pas_snp.g_ok :='S';
           v_resp:='00';
       else

      -- Envia el mensaje al servidor
      g_lugar := 'Env�o al Socket';
       pas_snp.g_ok := fue_env_tcp_mensajes( p_servidor   => pas_snp.g_servidor,
                                             p_puerto     => pas_snp.g_puerto,
                                             p_tie_espera => pas_snp.g_tie_espera,
                                             p_mensaje    => pas_snp.fu_con_mensaje(v_texto),
                                             p_respuesta  => v_resp
                                           );
       end if;
       if pas_snp.g_ok != 'S' THEN

         -- Hubo problema en el envio
         pas_snp.g_cod_error := 75;
         pas_snp.g_msj_error := v_resp;
         g_lugar := 'Actualizando Errror en el LOG, ';
         pr_ins_sb_snp_log_envios(v_nro_referencia, 'A', 'N', pas_snp.g_msj_error);
         raise ex_salir;
      else
         --Se inserta en GE_SNP_MENSAJES
         BEGIN
            /*Inicializa la aplicacion*/
            begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
            g_lugar := 'Inserta registro en GE_SNP_MENSAJES';
            INSERT INTO ge_snp_mensajes ( nro_referencia,
                                          nro_ref_externa,
                                          cod_msj_swift,
                                          fec_valor,
                                          msj_swift,
                                          situacion )
                                 VALUES ( v_nro_referencia,
                                          p_nro_referencia,
                                          v_tip_msj_swift,
                                          g_fec_actual,
                                          v_texto,
                                          'V');
         EXCEPTION
            when others then
               -- Error al insertar en GE_SNP_MENSAJES
               pas_snp.g_cod_error := 75;
               pas_snp.g_msj_error := 'Error al insertar en GE_SNP_MENSAJES: '||sqlerrm;
               raise ex_salir;
         END;
      end if;
   end lp_obt_n95_stat;
BEGIN

   if p_tip_mensaje = 'STAT' then
     lp_obt_n95_stat;
   else
      --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
      pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
      --
      /*Inicializa las variables de error*/
      pas_snp.pr_ini_variables;

      if p_nro_referencia is null then
         pas_snp.g_cod_error := 75;
         pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn95. Valor para P_NRO_REFENCIA debe contener algun valor.!';
         raise ex_salir;
      end if;

      if p_prioridad is null then
         pas_snp.g_cod_error := 75;
         pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn95. Valor para P_PRIORIDAD debe contener algun valor.!';
         raise ex_salir;
      end if;

      --Obtiene el registro de ge_snp_transferencias
      g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
      pas_snp.pr_obt_mensaje ( p_nro_referencia, 'S' );
      if pas_snp.fu_obt_cod_error <> 0 then
         raise ex_salir;
      end if;

      g_lugar :=  'Averiguando Horario Vigente en BCP, ';
      if pas_snp.fu_obt_est_horario( g_msj.cod_msj_swift,
                                     g_msj.cod_tip_operacion,
                                     g_msj.cod_sub_tip_operacion
                                   ) = 'A' then--Si el horario est� VIGENTE en BCP

         if pas_snp.fu_obt_cod_error <> 0 then
            raise ex_salir;
         end if;

         -- ****************************** cabecera del mensaje ********************************************
         if g_msj.cod_msj_swift is null then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'El C�d.Swift no puede ser nulo.!';
            raise ex_salir;
         elsif g_msj.cod_msj_swift not in (103,102,104,110,202) then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'El C�d.Swift debe tener alg�n valor permitido.!';
            raise ex_salir;
         elsif nvl(g_msj.cod_msj_swift,0) in (103,102,104,110) then
            v_tip_msj_swift := 195;
         else
            v_tip_msj_swift := 295;
         end if;

         if g_msj.fec_valor is null then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'El campo Fecha Valor no puede ser nulo.!';
            raise ex_salir;
         end if;

         g_lugar :=  'Generando cabecera del mensaje, ';
         if g_msj.fec_valor is null and g_msj.fecha is null then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'Debe ingresar algun valor para el campo Fec. Valor o Fecha.!';
            raise ex_salir;
         end if;

         --Valida si est� correcto el c�digo de usuario del X-ADAPTER
         if nvl( length( g_usu_xadapter ), 0 ) <> 12 then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER debe tener longitud de 12 caracteres';
            raise ex_salir;
         elsif v_bic_entidad <> substr(g_usu_xadapter,1,8) then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER no corresponde a la entidad';
            raise ex_salir;
         end if;

         v_texto := v_texto||
                    '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'/*0000000000*/||
                    '{2:I'||v_tip_msj_swift||rpad(fu_obt_bic_sistema/*R=RTSX, D=DEPO*/,12,'X')||'N}'||
                    '{3:{113'||':'||lpad(g_msj.prioridad,4,'0')||'}}{4:'||pas_snp.fu_obt_salto;

         -- ****************************** cuerpo del mensaje **********************************************
         v_nro_referencia := fu_obt_sig_nro_referencia;
         if pas_snp.fu_obt_cod_error <> 0 then
            raise ex_salir;
         end if;
         /**/-- 20: Referencia del mensaje
         g_lugar :=  'Generando campo :20:, ';
         v_texto := v_texto||':20:'||v_nro_referencia||pas_snp.fu_obt_salto;

         /**/-- 21: Referencia del remitente
         g_lugar :=  'Generando campo :21:, ';
         v_nro_ref_externa := CASE g_msj.cod_msj_swift
                                WHEN 103 THEN
                                  g_msj.nro_referencia
                                WHEN 202 THEN
                                  g_msj.nro_referencia
                                ELSE
                                  g_msj.nro_lote
                              END;

         if v_nro_ref_externa is null then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'El campo Nro. Referencia externa no puede ser nulo.!';
            raise ex_salir;
         end if;

         v_texto := v_texto||':21:'||v_nro_ref_externa||pas_snp.fu_obt_salto;

         /**/-- 75: Consulta
         g_lugar :=  'Generando campo :75:, ';
         v_texto := v_texto||':75:'||'PRTY'||pas_snp.fu_obt_salto;

         /**/-- 77A: Valor para la nueva Prioridad
         g_lugar :=  'Generando campo :77A:, ';
         v_texto := v_texto||':77A:'||lpad(p_prioridad,4,'0')||pas_snp.fu_obt_salto;

         /**/-- 11S: Codigo de MT, Fecha
         g_lugar :=  'Generando campo :11S:, ';
         v_texto := v_texto||':11S:'||to_char(g_msj.cod_msj_swift)||pas_snp.fu_obt_salto||
                    to_char(g_fec_actual,'RRMMDD')||pas_snp.fu_obt_salto;

         /**/-- 79: BIC del participante origen, Fecha Valor
         g_lugar :=  'Generando campo 79, ';
         if g_msj.cod_swi_pte_solicitante is null then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'El campo Swift del Participante Solicitante no puede ser nulo.!';
            raise ex_salir;
         end if;

         v_texto := v_texto||':79:'||fu_val_cadena(g_msj.cod_swi_pte_solicitante)||pas_snp.fu_obt_salto||
                    to_char(nvl(g_msj.fec_valor,g_msj.fecha),'RRMMDD'||pas_snp.fu_obt_salto);

         if v_texto is null then
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := 'No se ha generado el MTn92, no se puede continuar.!';
            raise ex_salir;
         end if;

         -- ********************************* fin del texto ************************************************

         v_texto := v_texto||'-}';
         g_lugar := 'Comprobando Duplicados, ';
         pr_ins_sb_snp_log_envios(v_nro_referencia, 'I', 'N');
         if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then--TCE-59
          begin
            insert into ge_men_env_sipap
              (nro_referencia, estado, msj_swift)
            values
              (v_nro_referencia,
               'PENDING',
               REPLACE(REPLACE(v_texto,
                               chr(10),
                               pas_snp.fu_obt_sal_socket),
                       chr(13),
                       ''));
          exception
            when others then
              -- Hubo problema en la insercion
              v_resp              := SQLERRM;
              pas_snp.g_ok :='N';
              pas_snp.g_cod_error := 49;
              pas_snp.g_msj_error := v_resp;
              g_lugar             := 'Actualizando Error en el LOG, ';
              pas_snp.pr_ins_sb_snp_log_envios(v_nro_referencia,
                                               'A',
                                               'E',
                                               pas_snp.g_msj_error);
              raise ex_salir;

          end;
           pas_snp.g_ok :='S';
           v_resp:='00';
       else

         g_lugar := 'Conect�ndose al socket';
         -- Envia el mensaje al servidor
         pas_snp.g_ok := fue_env_tcp_mensajes( p_servidor   => pas_snp.g_servidor,
                                               p_puerto     => pas_snp.g_puerto,
                                               p_tie_espera => pas_snp.g_tie_espera,
                                               p_mensaje    => pas_snp.fu_con_mensaje(v_texto),
                                               p_respuesta  => v_resp
                                             );
         if pas_snp.g_ok != 'S' THEN
            -- Hubo problema en el envio
            pas_snp.g_cod_error := 75;
            pas_snp.g_msj_error := v_resp;
            g_lugar := 'Actualizando Errror en el LOG, ';
            pr_ins_sb_snp_log_envios(v_nro_referencia, 'A', 'N', pas_snp.g_msj_error);
            raise ex_salir;
         end if;
       end if;
           if substr(v_resp,1,2) = '00' then
              g_lugar := 'Actualizando datos en ge_snp_transferencias';
              --Se inserta en GE_SNP_MENSAJES
              BEGIN
                  /*Inicializa la aplicacion*/
                  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
                  --
                  g_lugar :=  'Insertando en GE_SNP_MENSAJES, ';
                  INSERT INTO ge_snp_mensajes ( nro_referencia,
                                                nro_ref_externa,
                                                cod_msj_swift,
                                                fec_valor,
                                                msj_swift,
                                                situacion )
                                       VALUES ( v_nro_referencia,
                                                v_nro_ref_externa,
                                                v_tip_msj_swift,
                                                g_fec_actual,
                                                v_texto,
                                                'V');
              EXCEPTION
                 when others then
                    pas_snp.g_cod_error := 75;
                    pas_snp.g_msj_error := g_lugar ||' - '|| sqlerrm;
                    raise ex_salir;
              END;
           else
              pas_snp.g_cod_error := 75;
              pas_snp.g_msj_error := substr('Archivo no generado ' || v_resp,1,1000);
              raise ex_salir;
           end if;

       --Fin de la funci�n
      else
         raise ex_salir;
      end if;
   end if;
   commit;
EXCEPTION
  when ex_salir then
     pas_snp.g_cod_error := 75;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn95: '||g_lugar||' - '||PAS_SNP.fu_obt_msj_error;
  when others then
     pas_snp.g_cod_error := 75;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn95: '||g_lugar||' - '||sqlerrm;
END pr_obt_msj_mtn95;

PROCEDURE pr_obt_msj_mtn99 ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                             p_observacion  in varchar2 )
IS
   /*
   || Envia MT199 de Solicitud de Informaci�n por MT Recibido con Error.
   */
   v_tip_msj_swift    ge_snp_transferencias.cod_msj_swift%type;
   v_bic_entidad      ge_snp_transferencias.cod_swi_pte_solicitante%type := NULL;
   v_mto_cargo        ge_snp_transferencias.mto_cargo%type := 0;
   v_texto            varchar2(4000) := null;
   v_resp             varchar2(4000) := null;

   PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   --Recupera el BIC de la entidad solicitante
   v_bic_entidad := pas_snp.fu_obt_cod_swi_participante ( fug_obt_per_entidad );
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   end if;

   --Valida si est� correcto el c�digo de usuario del X-ADAPTER
   if nvl( length( g_usu_xadapter ), 0 ) <> 12 then
      pas_snp.g_cod_error := '70';
      pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER debe tener longitud de 12 caracteres';
      raise ex_salir;
   elsif v_bic_entidad <> substr(g_usu_xadapter,1,8) then
      pas_snp.g_cod_error := '70';
      pas_snp.g_msj_error := 'C�digo de usuario X-ADAPTER no corresponde a la entidad';
      raise ex_salir;
   end if;

   if p_nro_referencia is null then
      pas_snp.g_cod_error := 70;
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn99. Valor para P_NRO_REF_EXTERNA debe contener algun valor.!';
      raise ex_salir;
   end if;

   --Obtiene el registro de ge_snp_transferencias
   g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
   pas_snp.pr_obt_mensaje ( p_nro_referencia, 'N' );
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   end if;

   g_lugar :=  'Averiguando Horario Vigente en BCP, ';
   if pas_snp.fu_obt_est_horario( g_msj.cod_msj_swift,
                                  g_msj.cod_tip_operacion,
                                  g_msj.cod_sub_tip_operacion
                                ) = 'A' then   --Si el horario est� VIGENTE en BCP

      if pas_snp.fu_obt_cod_error <> 0 then
         raise ex_salir;
      end if;

      -- Se asigna 199 por ser el �nico mensaje a enviar por ahora.
      if g_msj.cod_msj_swift is null then
         pas_snp.g_cod_error := 70;
         pas_snp.g_msj_error := 'El C�d.Swift debe tener alg�n valor .!';
         raise ex_salir;
      elsif nvl(g_msj.cod_msj_swift,0) in (103,102,104) then
          v_tip_msj_swift:=199;
      end if;

      g_lugar :=  'Generando cabecera del mensaje, ';
      v_texto := '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'/*0000000000*/||
                 '{2:I'||v_tip_msj_swift||rpad(fu_obt_bic_sistema/*R=RTSX, D=DEPO*/,12,'X')||'N}'||
                 '{3:{113'||':'||lpad(99,'0')||'}}{4:'||pas_snp.fu_obt_salto;

      -- ****************************** cuerpo del mensaje **********************************************
      /**/-- 20: Referencia del mensaje
      g_lugar :=  'Generando campo :20:, ';
      v_texto := v_texto||':20:'||p_nro_referencia||pas_snp.fu_obt_salto;

      /**/-- 21: Referencia del remitente
      g_lugar :=  'Generando campo :21:, ';
      v_texto := v_texto||':21:'||g_msj.nro_ref_externa||pas_snp.fu_obt_salto;

      /**/-- 79: BIC del participante origen, Fecha Valor
      g_lugar :=  'Generando campo 79, ';
      v_texto := v_texto||':79:/TEXTMESSAGE/'||g_msj.cod_swi_pte_solicitante||pas_snp.fu_obt_salto||
                 ful_for_dat_swift(p_observacion,49);

      if v_texto is null then
          pas_snp.g_cod_error := 70;
          pas_snp.g_msj_error := 'No se ha generado el MTn99, no se puede continuar.!';
          raise ex_salir;
      end if;

      -- ********************************* fin del texto ************************************************

      v_texto := v_texto||'-}';

      g_lugar := 'Conect�ndose al socket';
      -- Envia el mensaje al servidor
      pas_snp.g_ok := fue_env_tcp_mensajes( p_servidor   => pas_snp.g_servidor,
                                            p_puerto     => pas_snp.g_puerto,
                                            p_tie_espera => pas_snp.g_tie_espera,
                                            p_mensaje    => pas_snp.fu_con_mensaje(v_texto),
                                            p_respuesta  => v_resp
                                          );
      if pas_snp.g_ok != 'S' THEN
         -- Hubo problema en el envio
         pas_snp.g_cod_error := 70;
         pas_snp.g_msj_error := substr(v_resp,1,1000);
         raise ex_salir;
      else
         if substr(v_resp,1,2) = '00' then
            g_lugar := 'Actualizando datos en ge_snp_mensajes';
            BEGIN
                --
                g_lugar :=  'Insertando en GE_SNP_MENSAJES, ';
                INSERT INTO ge_snp_mensajes ( nro_referencia,
                                              nro_ref_externa,
                                              cod_msj_swift,
                                              fec_valor,
                                              msj_swift )
                                     VALUES ( p_nro_referencia,
                                              g_msj.nro_ref_externa,
                                              v_tip_msj_swift,
                                              g_fec_actual,
                                              v_texto );

                g_lugar :=  'Actualizando el registro en GE_SNP_TRANSFERENCIAS, ';
                v_mto_cargo := nvl( fug_obt_pardinamico( p_parametro  => 'SNP_MTO_CAR_MTN99',
                                                         p_cod_moneda => g_msj.cod_moneda
                                                       ), 0 );
                update ge_snp_transferencias gt
                   set gt.mto_cargo = v_mto_cargo
                where gt.nro_referencia = p_nro_referencia ;

                if sql%notfound then
                   pas_snp.g_cod_error := 70;
                   pas_snp.g_msj_error := 'MT'||v_tip_msj_swift || ' | ' || 'Al actualizar en GE_SNP_TRANSFERENCIAS - Ope: '||p_nro_referencia;
                   raise ex_salir;
                else
                   commit;
                end if;

            EXCEPTION
               when ex_salir then
                  raise ex_salir;
               when others then
                  pas_snp.g_cod_error := 70;
                  pas_snp.g_msj_error := 'MT' || v_tip_msj_swift || ' | ' || 'Al intentar insertar en GE_SNP_TRANSFERENCIAS - Ope: '||p_nro_referencia;
                  raise ex_salir;
            END ;
         else
            pas_snp.g_cod_error := 70;
            pas_snp.g_msj_error := substr('Archivo no generado ' || v_resp,1,1000);
            raise ex_salir;
         end if;
      end if;
      --Fin de la funci�n
   else
      raise ex_salir;
   end if;
EXCEPTION
  when ex_salir then
     pas_snp.g_cod_error := 70;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn99: '||g_lugar||' - '||fu_obt_msj_error;
  when others then
     pas_snp.g_cod_error := 70;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_MTn99: '||g_lugar||' - '||sqlerrm;
END pr_obt_msj_mtn99;

FUNCTION fu_obt_reg_transferencias return rg_msj
IS
   /*
   || Obtiene el registro G_MSJ que contiene los datos de GE_SNP_TRANSFERENCIAS
   */
BEGIN
  return pas_snp.g_msj;
END;


FUNCTION fu_obt_cod_error return number
IS
   /*
   || Obtiene el c�digo de error del registro del paquete.
   */
BEGIN
   return pas_snp.g_cod_error;
END fu_obt_cod_error;

FUNCTION fu_obt_msj_error return varchar2
IS
   /*
   || Obtiene el mensaje de error contenido en el registro del paquete.
   */
BEGIN
   return pas_snp.g_msj_error;
END fu_obt_msj_error;

FUNCTION fu_obt_det_msj_error return varchar2
IS
   /*
   || Obtiene el mensaje de error contenido en el registro del paquete.
   */
BEGIN
   return pas_snp.g_det_msj_error;
END fu_obt_det_msj_error;

PROCEDURE pr_ini_workflow ( rg_msj_ini_wfl in rg_msj )
IS
   /*
   || Registra errores en el WORKFLOW.
   */

   v_nro_cta       ge_snp_transferencias.nro_cta_pte_solicitante%type;
   v_cod_persona   ba_personas.cod_persona%type := NULL;
   v_tip_circuito  wf_tip_circuitos.cod_tip_circuito%type:= NULL;
   v_tit_mai_error varchar2(100) := 'Error de parametrizaci�n del Circuito - SNP';
   v_ind_enviado   varchar2(1):= 'E';

BEGIN
  -- Si no encuentra ning�n circuito abierto, genera uno nuevo
  if not pas_snp.fu_ver_workflow( to_char( rg_msj_ini_wfl.nro_referencia ) ) then
         begin
            --Intenta crear el circuito en el WORKFLOW
            if pas_snp.fu_val_es_enviado( rg_msj_ini_wfl ) then --MT Enviado
               v_ind_enviado := 'E';
               if rg_msj_ini_wfl.cod_msj_swift = 202 then
                  v_nro_cta     := rg_msj_ini_wfl.nro_cta_pte_solicitante;
                  v_cod_persona := fug_obt_per_entidad;
               else
                  v_nro_cta     := rg_msj_ini_wfl.nro_cta_solicitante;
                  v_cod_persona := pas_snp.fu_obt_cli_principal( v_nro_cta );
               end if;
            else --MT Recibido
               v_ind_enviado := 'R';
               if rg_msj_ini_wfl.cod_msj_swift = 202 then
                  v_nro_cta     := rg_msj_ini_wfl.nro_cta_pte_beneficiario;
                  v_cod_persona := fug_obt_per_entidad;
               else
                  if length( rg_msj_ini_wfl.nro_cta_beneficiario ) >= 16 then -- Posiblemente sea un Nro. de Tarjeta.
                     --
                     pas_snp.pr_ver_nro_tarjeta( rg_msj_ini_wfl.nro_cta_beneficiario, v_nro_cta );
                     v_nro_cta := nvl( v_nro_cta, rg_msj_ini_wfl.nro_cta_beneficiario );
                     --
                  else -- Es una Cuenta en ITGF.
                     --
                     v_nro_cta := rg_msj_ini_wfl.nro_cta_beneficiario;
                     --
                  end if;

                  v_cod_persona := pas_snp.fu_obt_cli_principal( v_nro_cta );

               end if;

               -- Si no se recupera el c�digo de persona de la cuenta, se colocar� el c�digo de persona de la entidad.
               if v_cod_persona is null then
                  v_cod_persona := fug_obt_per_entidad;
               end if;
               --
            end if;

            -- Luego se valida la C�digo Swift, Tipo de Operaci�n y Sub Tipo de Operaci�n para buscar valores en la tabla GE_SNP_PAR_MENSAJES
            if not fu_val_par_mensajes( rg_msj_ini_wfl.cod_msj_swift,
                                        rg_msj_ini_wfl.cod_tip_operacion,
                                        rg_msj_ini_wfl.cod_sub_tip_operacion
                                      )
            then
               pas_snp.g_cod_error := 50;
               pas_snp.g_msj_error := 'Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES';
               raise ex_salir;
            end if;
            -- Busca el tipo de circuito a levantar, definido en la tabla GE_SNP_PAR_MENSAJES.
            v_tip_circuito := pas_snp.fu_obt_cod_tip_cir_workflow( rg_msj_ini_wfl.cod_msj_swift,
                                                                   v_ind_enviado,
                                                                   rg_msj_ini_wfl.cod_tip_operacion,
                                                                   rg_msj_ini_wfl.cod_sub_tip_operacion
                                                                  );
            if pas_snp.fu_obt_cod_error <> 0 then
               raise ex_salir;
            end if;

            if v_tip_circuito is not null then
               /**/-- Inicializa el circuito. Si tiene ERRORES env�a mail sino inicia el circuito.
               if paw_cir.fu_ini_circuito( v_tip_circuito,
                                           rg_msj_ini_wfl.nro_referencia,
                                           v_cod_persona
                                         ) <> 0
               then
                  v_tit_mai_error     := 'Error al intentar iniciar el circuito - SNP';
                  pas_snp.g_cod_error := 50;
                  pas_snp.g_msj_error := 'No se ha podido iniciar el circuito ' || v_tip_circuito ||'. '|| nvl( paw_cir.fu_obt_msj_error, sqlerrm );
                  raise ex_salir;
               end if;
            else
               pas_snp.g_cod_error := 50;
               pas_snp.g_msj_error := 'No se encuentra tipo de circuito para inicializar proceso de seguimiento de tareas (WORKFLOW).';
               raise ex_salir;
            end if;
         exception
            when ex_salir then
               raise ex_salir;
            when others then
               pas_snp.g_cod_error := 50;
               pas_snp.g_msj_error := sqlerrm;
               raise ex_salir;
         end;
  end if;
EXCEPTION
  when ex_salir then
     begin
       if g_err_dir_correo is not null then
          it_mail.mail( fug_obt_dir_correo,
                        g_err_dir_correo,
                        v_tit_mai_error,
                        'Favor verificar las siguientes configuraciones para la mensajer�a '||rg_msj_ini_wfl.nro_referencia                             || chr(10) || chr(10) ||
                        'Configuraci�n del tipo de circuito para el MT '||rg_msj_ini_wfl.cod_msj_swift||' que est� siendo procesado (WF_TIP_CIRCUITOS)' || chr(10) ||
                        'Configuraci�n de los circuitos seg�n c�digo swift, c�digo tipo de operaci�n y c�digo sub tipo de operaci�n para el mensaje que est� siendo procesado (GE_SNP_PAR_MENSAJES)' || chr(10) ||
                        'A continuaci�n los datos de la mensajer�a que caus� el error: '                                                                || chr(10) ||
                        'Nro. Referencia: ' || rg_msj_ini_wfl.nro_referencia                                                                            || chr(10) ||
                        'Nro. Cuenta    : ' || v_nro_cta                                                                                                || chr(10) ||
                        'Tipo Mensaje   : ' || rg_msj_ini_wfl.cod_msj_swift                                                                             || chr(10) ||
                        'Tipo Operaci�n : ' || pas_snp.fu_obt_des_tip_operacion( rg_msj_ini_wfl.cod_msj_swift,
                                                                                 rg_msj_ini_wfl.cod_tip_operacion,
                                                                                 rg_msj_ini_wfl.cod_sub_tip_operacion
                                                                               )                                                                        || chr(10) ||
                        'Fecha Valor    : ' || to_char(rg_msj_ini_wfl.fec_valor,'DD/MM/YYYY')                                                           || chr(10) ||
                        'Moneda         : ' || rg_msj_ini_wfl.cod_moneda                                                                                || chr(10) ||
                        'Monto          : ' || trim(to_char(rg_msj_ini_wfl.monto,'999,999,999,999,999.99'))                                             || chr(10) ||
                        'Detalle Error  : ' || pas_snp.fu_obt_msj_error                                                                                 || chr(10) ||
                        chr(10) || chr(10) ||
                        'Atentamente.'
                      );
       end if;
     exception
        when others then
           NULL;
     end;
  when others then
     pas_snp.g_cod_error := 50;
     pas_snp.g_msj_error := sqlerrm;
END pr_ini_workflow;

PROCEDURE pr_can_workflow ( p_referencia in wf_circuitos.referencia%type )
IS
   /* Cancela WORKFLOW abierto con relaci�n a la transferencia */
   cursor cur_cir_pend is
      select cod_circuito
        from wf_circuitos
       where referencia = p_referencia
         and estado not in ('C','F');
BEGIN
   --Se cancela el circuito
   for cp in cur_cir_pend loop
      --Se actualiza a cancelada las tareas para las tablas
      --wf_cir_tareas y wf_circuitos
      update wf_cir_tareas ct
         set ct.estado = 'C'
       where ct.cod_circuito = cp.cod_circuito
         and ct.estado = 'P';
      --
      update wf_circuitos c
         set c.estado = 'C'
       where c.cod_circuito = cp.cod_circuito;
   end loop;
EXCEPTION
   when others then
      pas_snp.g_cod_error := 81;
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_CAN_WORKFLOW: ' || sqlerrm;
END pr_can_workflow;

FUNCTION fu_ver_workflow ( p_referencia in wf_circuitos.referencia%type ) return boolean
IS
   /* Verifica si existe WORKFLOW abierto */
BEGIN
   FOR c IN ( select 'S'
                from wf_circuitos c
               where c.referencia = p_referencia
                 and c.estado not in ('C','F')
                 and rownum = 1 ) LOOP
       RETURN TRUE;
   END LOOP;
   RETURN FALSE;
EXCEPTION
   when others then
      RETURN FALSE;
END fu_ver_workflow;

FUNCTION fu_obt_cod_tip_cir_workflow( p_cod_swift         in ge_snp_transferencias.cod_msj_swift%type,
                                      p_tip_circuito      in varchar2,
                                      p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                                      p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type default null,
                                      p_cod_tra_padre     in ge_snp_par_mensajes.cod_tra_padre%type default null
                                    ) return number
IS
  /* Recupera el c�digo de circuito de workflow dependiendo del origen E=Enviado, R=Recibido, C=Reversado */
  v_tip_circuito wf_tip_circuitos.cod_tip_circuito%type := null;
BEGIN
    /*Inicializa las variables de error*/
    pas_snp.pr_ini_variables;

    -- Busca el tipo de circuito a levantar, definido en la tabla GE_SNP_PAR_MENSAJES.
    select w.cod_tip_circuito
      into v_tip_circuito
      from wf_tip_circuitos w
     where exists ( select 1
                      from ge_snp_par_mensajes r
                     where r.cod_msj_swift         = p_cod_swift
                       and r.cod_tip_operacion     = p_tip_operacion
                       and r.cod_sub_tip_operacion = p_sub_tip_operacion
                       and case p_tip_circuito
                             when 'E' then -- E = Tipo de Circuito para MT Enviados.
                                r.cod_tip_cir_emitido
                             when 'R' then -- R = Tipo de Circuito para MT Recibidos.
                                r.cod_tip_cir_recibido
                             else          -- C = Tipo de Circuito para MT Reversados.
                                r.cod_tip_cir_rec_reversado
                             end                   = w.cod_tip_circuito
                  );
    --
    if v_tip_circuito is null then
       raise no_data_found;
    end if;
    --
    return v_tip_circuito;
EXCEPTION
  WHEN no_data_found THEN
    pas_snp.g_cod_error := 79;
    pas_snp.g_msj_error := 'Tipo de circuito inexistente para MT ' || p_cod_swift || ', Tip.Operaci�n y/o Sub Tip.Operaci�n ' || p_tip_operacion || '/' || p_sub_tip_operacion;
    return null;
  WHEN others THEN
    pas_snp.g_cod_error := 79;
    pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_COD_TIP_CIR_WORKFLOW: ' || sqlerrm;
    return null;
END fu_obt_cod_tip_cir_workflow;

PROCEDURE pr_reg_msj_workflow ( rg_msj_reg_wfl in rg_msj )
IS
   /*Env�o de mensajer�a al WorkFlow*/
   PRAGMA AUTONOMOUS_TRANSACTION;
   v_cod_error pas_snp.g_cod_error%type := NULL;
   v_msj_error pas_snp.g_msj_error%type := NULL;
BEGIN
   --
   pas_snp.pr_set_transferencias ( rg_msj_reg_wfl );
   --
   if pas_snp.fu_obt_cod_error <> 0 then
      --Guarda los errores encontrados para que otro objeto no los borre
      v_cod_error := pas_snp.fu_obt_cod_error;
      v_msj_error := pas_snp.fu_obt_msj_error;
   end if;
   pas_snp.pr_ini_workflow ( rg_msj_reg_wfl );
   commit;
   -- Si al entrar al procedimiento hubieron errores, debe permanecer dicho error,
   -- en caso que algun objeto haya borrado el error, se vuelve a cargar las variables.
      pas_snp.g_cod_error := v_cod_error;
      pas_snp.g_msj_error := v_msj_error;
   --
END pr_reg_msj_workflow;

PROCEDURE pr_set_transferencias ( rg_msj_set_tra in rg_msj )
IS
   /*
   || Setea valores en GE_SNP_TRANSFERENCIAS
   */
BEGIN

   UPDATE ge_snp_transferencias
      SET nro_lote = rg_msj_set_tra.nro_lote,
          nro_sec_lote = rg_msj_set_tra.nro_sec_lote,
          cod_modulo = rg_msj_set_tra.cod_modulo,
          cod_modalidad = rg_msj_set_tra.cod_modalidad,
          cod_oficina = rg_msj_set_tra.cod_oficina,
          cod_msj_swift = rg_msj_set_tra.cod_msj_swift,
          cod_tip_operacion = rg_msj_set_tra.cod_tip_operacion,
          cod_sub_tip_operacion = rg_msj_set_tra.cod_sub_tip_operacion,
          msj_swift = rg_msj_set_tra.msj_swift,
          fec_valor = rg_msj_set_tra.fec_valor,
          fec_ingreso = rg_msj_set_tra.fec_ingreso,
          fec_recepcion = rg_msj_set_tra.fec_recepcion,
          fecha = rg_msj_set_tra.fecha,
          hora = rg_msj_set_tra.hora,
          cod_usuario = rg_msj_set_tra.cod_usuario,
          cod_moneda = rg_msj_set_tra.cod_moneda,
          monto = rg_msj_set_tra.monto,
          cod_per_solicitante = rg_msj_set_tra.cod_per_solicitante,
          nom_solicitante = rg_msj_set_tra.nom_solicitante,
          dir_solicitante = rg_msj_set_tra.dir_solicitante,
          cod_tip_doc_solicitante = rg_msj_set_tra.cod_tip_doc_solicitante,
          nro_doc_solicitante = rg_msj_set_tra.nro_doc_solicitante,
          nro_cta_solicitante = rg_msj_set_tra.nro_cta_solicitante,
          cod_swi_pte_solicitante = rg_msj_set_tra.cod_swi_pte_solicitante,
          cod_swi_suc_solicitante = rg_msj_set_tra.cod_swi_suc_solicitante,
          nro_cta_pte_solicitante = rg_msj_set_tra.nro_cta_pte_solicitante,
          nro_cta_suc_pte_solicitante = rg_msj_set_tra.nro_cta_suc_pte_solicitante,
          cod_per_beneficiario = rg_msj_set_tra.cod_per_beneficiario,
          nom_beneficiario = rg_msj_set_tra.nom_beneficiario,
          dir_beneficiario = rg_msj_set_tra.dir_beneficiario,
          cod_tip_doc_beneficiario = rg_msj_set_tra.cod_tip_doc_beneficiario,
          nro_doc_beneficiario = rg_msj_set_tra.nro_doc_beneficiario,
          nro_cta_beneficiario = rg_msj_set_tra.nro_cta_beneficiario,
          cod_swi_pte_beneficiario = rg_msj_set_tra.cod_swi_pte_beneficiario,
          cod_swi_suc_beneficiario = rg_msj_set_tra.cod_swi_suc_beneficiario,
          nro_cta_pte_beneficiario = rg_msj_set_tra.nro_cta_pte_beneficiario,
          nro_cta_suc_pte_beneficiario = rg_msj_set_tra.nro_cta_suc_pte_beneficiario,
          concepto = rg_msj_set_tra.concepto,
          observacion = rg_msj_set_tra.observacion,
          nro_ref_externa = rg_msj_set_tra.nro_ref_externa,
          tip_cargo = rg_msj_set_tra.tip_cargo,
          ind_valor = rg_msj_set_tra.ind_valor,
          situacion = rg_msj_set_tra.situacion,
          estado = rg_msj_set_tra.estado,
          tip_rechazo = rg_msj_set_tra.tip_rechazo,
          mto_cargo = rg_msj_set_tra.mto_cargo,
          prioridad = rg_msj_set_tra.prioridad,
          nro_operacion = rg_msj_set_tra.nro_operacion,
          tip_mensaje = rg_msj_set_tra.tip_mensaje,
          error = rg_msj_set_tra.error,
          cod_usu_transaccion = rg_msj_set_tra.cod_usu_transaccion,
          ref_oid = rg_msj_set_tra.ref_oid,
          indemnizado = rg_msj_set_tra.indemnizado,
          cod_servicio = rg_msj_set_tra.cod_servicio
    WHERE nro_referencia = rg_msj_set_tra.nro_referencia;

EXCEPTION
  WHEN others THEN
    pas_snp.g_cod_error := 45;
    pas_snp.g_msj_error := 'Error al actualizar en GE_SNP_TRANSFERENCIAS. Nro. Ref.: ' || rg_msj_set_tra.nro_referencia || ' - ' || sqlerrm;
END pr_set_transferencias;

PROCEDURE pr_reg_operacion( p_mensaje   in long,
                            p_respuesta in varchar2 )
IS
   /*
   || Registra LOG de la mensajer�a
   */

   PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
BEGIN
   insert into ba_log_mensajerias
       (mensaje, respuesta)
     values
       (p_mensaje, substr(p_respuesta,1,4000));
   commit;
EXCEPTION
  when others then
     pas_snp.g_cod_error := 50;
     pas_snp.g_msj_error := sqlerrm;
     raise_application_error(-20000, pas_snp.fu_obt_msj_error);
END;

FUNCTION fu_pro_val_tag( p_mensaje   in long,
                         p_tag       in varchar2,
                         p_limpia    in varchar2 default NULL,
                         p_posicion  in number default 1,
                         p_ubicacion in number default 1
                       ) return varchar2
IS
   /*
   || Retorna el valor del TAG recibido del mensaje swift parseado.
   || El tag en el swift son las ETIQUETAS que se anteponen al valor del mismo
   || Ej. 23E es un TAG/Etiqueta del swift que corresponde al Tipo de Operaci�n en el MT103.
   */

   v_tag          varchar2(10);
   v_tag_mensaje  varchar2(10);
   v_valor_tag    varchar(500);
   v_par_tag      varchar2(10);
   v_tag_distinto varchar2(1):= 'N';
   v_lon_par_tag  number := 0;
   v_pos_ini      number := 0;
   v_pos_fin      number := 0;
   i              number := 0;
   v_pos_startime NUMBER := 0;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   g_lugar :=  'Obteniendo el valor del TAG '||p_tag||', ';
   --Controla los par�metros ingresados.
   if p_mensaje is null then
      pas_snp.g_cod_error := 16;
      pas_snp.g_msj_error :='No se ha encontrado el parameto P_MENSAJE en PAS_SNP.FU_PRO_VAL_TAG.!';
      raise ex_salir;
   end if;
   if p_tag is null then
      pas_snp.g_cod_error := 16;
      pas_snp.g_msj_error :='No se ha encontrado el parameto P_TAG en PAS_SNP.FU_PRO_VAL_TAG.!';
      raise ex_salir;
   end if;

   v_tag := substr( ':' || p_tag || ':', 1, 10 );

   g_lugar := 'Obteniendo longitud del TAG. '||p_tag||', ';
   -- Si el TAG posee la letra "a" significa que dicha letra puede ser reemplazada din�micamente por A, D, K, etc
   if nvl( instr( p_tag, 'a', 3 ), 0 ) > 0 then
      v_par_tag := regexp_substr(p_mensaje, ':(' || substr( p_tag, 1, instr( p_tag, 'a' ) - 1 ) || '.):');
   else -- El TAG se debe buscar tal cual
      v_par_tag    := ':' || p_tag || ':';
   end if;

   g_lugar := 'Seteando posici�n inicial para la b�squeda del TAG '||p_tag||' en el mensaje, ';
   -- Guarda la posici�n inicial del bloque 4 (Detalle del mensaje)
   v_pos_ini := nvl( instr( p_mensaje, '{4:', 1 ) + 3, 0 );

   -- Si el valor de la posici�n que se recibe como par�metro es mayor a la posici�n inicial del bloque 4,
   -- se setea la posici�n inicial de b�squeda con el valor recibido en P_POSICION, sino se setea como posici�n inicial el bloque 4
   if p_posicion > v_pos_ini then
      v_pos_ini := p_posicion;
   end if;

   g_lugar := 'Buscando el TAG '||p_tag||' en el mensaje, ';
   --Controla si el valor pasado del TAB existe dentro del mensaje
   v_pos_ini := instr( p_mensaje, v_par_tag, v_pos_ini, p_ubicacion );
   --Controla que no exista la linea STARTIME, la cual indica fecha y hora TRFS-1309 PHT
   v_pos_startime := instr( p_mensaje, '/STARTTIME/', 1, p_ubicacion );

   --El formato de fecha y hora es /STARTTIME/YYYY.MM.DD HH:MI:SS
   --La diferencia de posicion entre los MI y /STARTIME/ es 24 posiciones
   --Por lo tanto si la diferencia entre la posicion del tag y de la linea STARTIME es 24, significa que lo que encontro fueron los minutos
   --En ese caso vuelve a buscar el Tag mas adelante
   IF v_pos_ini - v_pos_startime = 24 THEN
     v_pos_ini := instr( p_mensaje, v_par_tag, v_pos_ini+1, p_ubicacion );
   END IF;
     v_pos_fin := instr( p_mensaje, ':', v_pos_ini, 2 );


   if v_pos_ini = 0 or v_pos_fin = 0 then
      pas_snp.g_cod_error := 20;
      pas_snp.g_msj_error := 'No se encuentra el TAG '||p_tag||' dentro del mensaje.';
      raise ex_salir;
   end if;

   v_tag_mensaje:= substr( p_mensaje, v_pos_ini, v_pos_fin - ( v_pos_ini - 1 ) );

   g_lugar := 'Validando contenido del TAG '||p_tag||' en el mensaje, ';
   if length( v_tag_mensaje ) <> length( v_tag ) then
      pas_snp.g_cod_error := 20;
      pas_snp.g_msj_error := 'Longitud del TAG '||p_tag||' no coincide con el TAG del mensaje.';
      raise ex_salir;
   elsif length( v_tag_mensaje ) = length( v_tag ) then
      -- Valida caracter por caracter para detectar diferencias entre el TAG enviado y
      -- el TAG recuperado del mensaje
      for i in 1..nvl( length( v_tag ), 0 ) loop
         if substr( v_tag, i, 1 ) <> substr( v_tag_mensaje, i, 1 ) and
            substr( v_tag, i, 1 ) <> 'a'
         then
            v_tag_distinto := 'S';
            exit;
         end if;
      end loop;
      if v_tag_distinto = 'S' then
         pas_snp.g_cod_error := 20;
         pas_snp.g_msj_error := 'TAG '||v_tag_mensaje||' recuperado del mensaje no coincide con el '||
                                'TAG '||p_tag||' enviado como par�metro.';
         raise ex_salir;
      end if;
   end if;
   if pas_snp.fu_obt_cod_error = 0 then
      -- Si no tuvo ERRORES
      v_lon_par_tag := length( v_tag_mensaje );
      g_lugar := 'Obteniendo detalle del TAG '||v_tag_mensaje||', ';
      -- Obtiene el detalle del TAG encontrado en el mensaje
      v_pos_ini := instr( p_mensaje, v_tag_mensaje, p_posicion, p_ubicacion ) + v_lon_par_tag;
      v_pos_fin := CASE instr( p_mensaje, pas_snp.fu_obt_sal_socket || ':', v_pos_ini, 1 )
                   WHEN 0 THEN 0
                   ELSE instr( p_mensaje, pas_snp.fu_obt_sal_socket || ':', v_pos_ini, 1 )+ 1
                   END;
      if v_pos_fin = 0 then
         v_pos_fin := instr( p_mensaje, '-}', p_posicion + v_lon_par_tag, p_ubicacion );
         if v_pos_fin = 0 then
            pas_snp.g_cod_error := 20;
            pas_snp.g_msj_error := 'No se puede recuperar detalle del TAG '||v_tag_mensaje||'.No se encuentra caracter final del detalle.';
            raise ex_salir;
         end if;
      end if;

      v_valor_tag :=  substr( p_mensaje, v_pos_ini, v_pos_fin - v_pos_ini );

      g_lugar := 'Limpiando texto del TAG '||p_tag||', ';
      if p_limpia = 'N' then
         return ltrim(rtrim(v_valor_tag));
      else
         return pas_snp.fu_val_cadena(v_valor_tag);
      end if;
   else
      raise ex_salir;
   end if;

EXCEPTION
  when ex_salir then
     return NULL;
  when others then
     pas_snp.g_cod_error := 20;
     pas_snp.g_msj_error := 'Error en PAS_SNP.FU_PRO_VAL_TAG: '||g_lugar||' - '||sqlerrm;
     return NULL;
END fu_pro_val_tag;


FUNCTION fu_pro_val_reversion( p_mensaje   in long,
                               p_tag       in varchar2,
                               p_posicion  in number default 1,
                               p_ubicacion in number default 1
                              ) return BOOLEAN
IS
   /*
   || TRFS-1392
   || A partir del TAG dado por parametro, revise si el mismo tiene el codigo REV indicando que es una reversion
   || El tag en el swift son las ETIQUETAS que se anteponen al valor del mismo
   || Basado en fu_pro_val_tag, no se usa este para no setear un codigo de error en caso de no encontrar el tag
   */

   v_tag          varchar2(10);
   v_tag_mensaje  varchar2(10);
   v_valor_tag    varchar(500);
   v_par_tag      varchar2(10);
   v_tag_distinto varchar2(1):= 'N';
   v_lon_par_tag  number := 0;
   v_pos_ini      number := 0;
   v_pos_fin      number := 0;
   i              number := 0;
BEGIN


   --Controla los par�metros ingresados.
   if p_mensaje is null or p_tag is null then
      raise ex_salir;
   end if;

   v_tag := substr( ':' || p_tag || ':', 1, 10 );

   -- Si el TAG posee la letra "a" significa que dicha letra puede ser reemplazada din�micamente por A, D, K, etc
   if nvl( instr( p_tag, 'a', 3 ), 0 ) > 0 then
      v_par_tag := regexp_substr(p_mensaje, ':(' || substr( p_tag, 1, instr( p_tag, 'a' ) - 1 ) || '.):');
   else -- El TAG se debe buscar tal cual
      v_par_tag    := ':' || p_tag || ':';
   end if;

   -- Guarda la posici�n inicial del bloque 4 (Detalle del mensaje)
   v_pos_ini := nvl( instr( p_mensaje, '{4:', 1 ) + 3, 0 );

   -- Si el valor de la posici�n que se recibe como par�metro es mayor a la posici�n inicial del bloque 4,
   -- se setea la posici�n inicial de b�squeda con el valor recibido en P_POSICION, sino se setea como posici�n inicial el bloque 4
   if p_posicion > v_pos_ini then
      v_pos_ini := p_posicion;
   end if;

   --Controla si el valor pasado del TAB existe dentro del mensaje
   v_pos_ini := instr( p_mensaje, v_par_tag, v_pos_ini, p_ubicacion );
   v_pos_fin := instr( p_mensaje, ':', v_pos_ini, 2 );

   if v_pos_ini = 0 or v_pos_fin = 0 then
      raise ex_salir;
   end if;

   v_tag_mensaje:= substr( p_mensaje, v_pos_ini, v_pos_fin - ( v_pos_ini - 1 ) );

   if length( v_tag_mensaje ) <> length( v_tag ) then
      raise ex_salir;
   elsif length( v_tag_mensaje ) = length( v_tag ) then
      -- Valida caracter por caracter para detectar diferencias entre el TAG enviado y
      -- el TAG recuperado del mensaje
      for i in 1..nvl( length( v_tag ), 0 ) loop
         if substr( v_tag, i, 1 ) <> substr( v_tag_mensaje, i, 1 ) and
            substr( v_tag, i, 1 ) <> 'a'
         then
            v_tag_distinto := 'S';
            exit;
         end if;
      end loop;
      if v_tag_distinto = 'S' then
         raise ex_salir;
      end if;
   end if;

      -- Si no tuvo ERRORES
      v_lon_par_tag := length( v_tag_mensaje );
      -- Obtiene el detalle del TAG encontrado en el mensaje
      v_pos_ini := instr( p_mensaje, v_tag_mensaje, p_posicion, p_ubicacion ) + v_lon_par_tag;
      v_pos_fin := CASE instr( p_mensaje, pas_snp.fu_obt_sal_socket || ':', v_pos_ini, 1 )
                   WHEN 0 THEN 0
                   ELSE instr( p_mensaje, pas_snp.fu_obt_sal_socket || ':', v_pos_ini, 1 )+ 1
                   END;
      if v_pos_fin = 0 then
         v_pos_fin := instr( p_mensaje, '-}', p_posicion + v_lon_par_tag, p_ubicacion );
         if v_pos_fin = 0 then
            raise ex_salir;
         end if;
      end if;

      v_valor_tag :=  substr( p_mensaje, v_pos_ini, v_pos_fin - v_pos_ini );

      RETURN nvl(instr(substr(substr(v_valor_tag,1),1,100),'/REV/',1),0) > 0;


EXCEPTION
   when ex_salir then
      return FALSE;
  when others then
     return FALSE;
END fu_pro_val_reversion;


PROCEDURE pr_rev_automatica ( p_fec_actual in ge_snp_transferencias.fecha%type default null )
IS
   /*
   || Proceso que reversara los movimientos de la modalidad 455 que no registren Mensajes del SNP
   */

   v_hor_reversion ge_movimientos.hor_reversion%type := to_char(sysdate,'hh24:mi:ss');

   cursor cu_rev_mov is
     select distinct fecha,  hora, cod_usuario,
            cod_mod_padre, cod_mad_padre, cod_tra_padre
       from ge_movimientos m
      where fecha         = nvl( p_fec_actual, g_fec_actual )
        and cod_modalidad = pas_snp.fu_obt_cod_mad_padre
        and reversado     = 'N'
        and not exists ( select distinct 1
                           from ge_snp_transferencias t
                          where t.fecha = m.fecha
                            and t.hora = m.hora
                            and m.cod_usuario = t.cod_usuario
                       );
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

    for c in cu_rev_mov loop
       v_hor_reversion := pag_gen.fu_obt_sig_segundo(v_hor_reversion);
       g_lugar := 'Intentando reversar la operacion. Fec.: ' || to_char(c.fecha,'DD/MM/YYYY') || ' '||
                                                    'Hor.: ' || c.hora || ' '||
                                                    'Usu.: ' || c.cod_usuario || ' ' ||
                                                    'Mod.Padre '||c.cod_mod_padre || ' ' ||
                                                    'Mad.Padre '||c.cod_mad_padre || ' ' ||
                                                    'Trx.Padre '||c.cod_tra_padre || ', ';
       prg_rev_operacion(c.fecha,c.hora,c.cod_usuario,c.cod_mod_padre,c.cod_mad_padre,c.cod_tra_padre,user,v_hor_reversion,'N','Cancelado en forma Autom�tica');
    end loop;
EXCEPTION
   when others then
      pas_snp.g_cod_error := 50;
      pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
      raise_application_error(-20000,'Error en PAS_SNP.PR_REV_AUTOMATICA, ' || pas_snp.fu_obt_msj_error);
END pr_rev_automatica;

PROCEDURE pr_gen_men_automaticos( p_fec_valor     in ge_snp_transferencias.fec_valor%type default null,
                                  p_can_sin_fondo in varchar2 default 'N'
                                )
IS
   /*
   || Proceso diario de env�o de SWIFTS a BCP,
   || previa apertura de la fecha actual para el intercambio de informaci�n
   */

   v_cta_debito      ge_cuentas.nro_cuenta%type;
   v_tra_debito      ge_movimientos.cod_transaccion%type := 503;
   v_est_cuenta      ge_cuentas.estado%type;
   v_sal_disponible  ge_cuentas.sal_contable%type;
   v_tra_padre       ge_transacciones.cod_transaccion%type := NULL;
   v_cod_modulo      ge_transacciones.cod_modulo%type := NULL;
   v_cod_modalidad   ge_transacciones.cod_modalidad%type := NULL;
   v_cod_transaccion ge_transacciones.cod_transaccion%type := NULL;
   v_mto_destino     ge_movimientos.monto%type := NULL;
   v_cot_origen      ge_movimientos.cotizacion%type := NULL;
   v_cot_destino     ge_movimientos.cotizacion%type := NULL;
   c_fec_valor       constant date := nvl( p_fec_valor, g_fec_actual );
   v_tip_mov         varchar2(1)   := NULL;
   v_procesa         varchar2(1)   := 'N';
   v_can_sin_fondo   varchar2(1)   := p_can_sin_fondo;
   v_env_alerta      varchar2(1)   := 'S';

   cursor cu_msj_av is --Cursor de alto valor para aquellos registrados por ITGF y por HB
     select t.nro_referencia, t.cod_msj_swift, t.cod_tip_operacion, t.cod_sub_tip_operacion
       from ge_snp_transferencias t
      where t.fec_valor                =  c_fec_valor
        and nvl( t.ind_valor,'N' )     = 'S'          -- Alto Valor
        and t.estado                   = 'A'          -- Aprobado en ITGF
        and t.situacion                = 'P'          -- Pendiente de env�o a BCP
        and t.cod_msj_swift            IN ( 103,202 )
        and t.nro_lote                 IS NULL        -- Si nro_lote es NULO significa que todavia no se proces�.
        and t.nro_ref_externa          IS NULL        -- Para MT enviados
        and t.fec_recepcion            IS NULL        -- Para MT enviados
        and ( t.error IS NULL or
              upper( t.error ) LIKE ( '%SOCKET%' ) or -- Errores por conexi�n al Socket, debe intentar otra vez
              upper( t.error ) LIKE ( '%SAL%INSUF%' ) -- Errores por Saldo Insuficiente, debe intentar otra vez
            )
        and t.monto                    <> 0
        and t.nro_cta_pte_solicitante  IS NOT NULL
        -- Para que se puedan procesar primero los de la WEB y luego los de ITGF, por moneda, prioridad y monto
        order by t.origen asc, t.cod_moneda asc, t.prioridad asc, monto desc;

        --for update of t.nro_referencia nowait; -- HA-3690

   cursor cu_msj_rev is --Cursor de REVERSADOS
     select t.nro_referencia, t.cod_msj_swift, t.cod_tip_operacion, t.cod_sub_tip_operacion
       from ge_snp_transferencias t
      where t.fec_valor                = c_fec_valor
        and nvl( t.ind_valor,'N' )     = 'S'          -- Alto Valor
        and t.estado                   = 'R'          -- Reversado en ITGF
        and t.situacion                = 'P'          -- Pendiente de env�o a BCP
        and t.cod_msj_swift            IN ( 103,202 )
        and t.fec_recepcion            IS NULL        -- Para MT enviados
        and t.error                    IS NULL
        and t.monto                    <> 0

        for update of t.nro_referencia nowait;

   PROCEDURE lp_pro_swi_alt_valor
   IS
   BEGIN
      for c in cu_msj_av loop
         pas_snp.g_det_msj_error := NULL;

         --Obtiene el registro de ge_snp_transferencias
         g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
         pas_snp.pr_obt_mensaje ( c.nro_referencia, 'N' );
         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error );
         end if;

         g_lugar :=  'AV - Averiguando Horario Vigente en BCP para Nro. Ref.: ' || c.nro_referencia;
         if pas_snp.fu_obt_est_horario( c.cod_msj_swift,
                                        c.cod_tip_operacion,
                                        c.cod_sub_tip_operacion
                                      ) = 'A'
         then --Si el horario est� VIGENTE en BCP
            if pas_snp.fu_obt_cod_error = 0 then
               if g_msj.fecha is null and
                  g_msj.hora is null and
                  g_msj.cod_usuario is null
               then
                  g_lugar :=  'Obteniendo los datos de la Cta. ' || v_cta_debito || ', ' ;
                  -- Antes de enviar la mensajer�a al socket, se verifica si existe saldo disponible
                  -- en la cuenta de DEBITO.

                  v_tra_padre       := pas_snp.fu_obt_cod_tra_padre;
                  v_cod_modulo      := NULL;
                  v_cod_modalidad   := NULL;
                  v_cod_transaccion := NULL;
                  v_mto_destino     := NULL;
                  v_cot_origen      := NULL;
                  v_cot_destino     := NULL;
                  v_env_alerta      := 'S';

                  if g_msj.cod_msj_swift = 103 then
                     v_cta_debito      := g_msj.nro_cta_solicitante;
                     v_cod_transaccion := v_tra_debito;
                      if g_msj.ref_oid ='PPV' then
                         v_cod_transaccion := 7503;
                      end if;
                  elsif g_msj.cod_msj_swift = 202 then
                     v_cta_debito := pas_snp.fu_obt_cta_bancaria( g_msj.nro_cta_pte_solicitante, 'C' );
                     -- Obtiene la transacci�n hija de la Cta. Interbancaria seg�n el tipo/subtipo de operaci�n de GE_PAR_MENSAJES.
                     g_lugar :=  'Buscando Transacci�n de GE_PAR_MENSAJES, ';
                     pas_snp.pr_obt_par_mensajes( g_msj.cod_msj_swift,
                                                  g_msj.cod_tip_operacion,
                                                  g_msj.cod_sub_tip_operacion,
                                                  'E',
                                                  v_cod_modulo,
                                                  v_cod_modalidad,
                                                  v_cod_transaccion
                                                );

                     if pas_snp.fu_obt_cod_error <> 0 then
                        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error );
                     end if;
                  else
                     v_cta_debito := 0;
                     v_tra_padre  := NULL;
                     v_tip_mov    := NULL;
                  end if;

                  -- Recupera los datos de la Cta. de D�bito
                  pag_cta.pr_obt_cuenta( v_cta_debito );
                  if pag_cta.fu_obt_cod_error <> 0 then
                     --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                     pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                     pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                     pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error );

                  end if;

                  -- Para el MT103 el m�dulo y la modalidad se carga con el PAG_CTA.PR_OBT_CUENTA
                  v_cod_modulo    := nvl( v_cod_modulo, pag_cta.g_ctas.cod_modulo );
                  v_cod_modalidad := nvl( v_cod_modalidad, pag_cta.g_ctas.cod_modalidad );

                  -- Obtiene el tipo de movimiento seg�n el modulo, modalidad y transaccion de GE_TRANSACCION.
                  g_lugar :=  'Buscando Tipo de Movimiento de GE_TRANSACCION, ';
                  v_tip_mov := pas_snp.fu_obt_tip_mov_transaccion( v_cod_modulo,
                                                                   v_cod_modalidad,
                                                                   v_cod_transaccion
                                                                 );
                  if pas_snp.fu_obt_cod_error <> 0 then
                     pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error );
                  end if;

                  -- Si no hubo ning�n error
                  if pas_snp.fu_obt_cod_error = 0 then

                     if pag_cta.g_ctas.cod_moneda <> g_msj.cod_moneda then
                        g_lugar :=  'Realizando conversi�n de moneda, ';
                        pas_snp.pr_con_mon_a_moneda( g_msj.cod_moneda,
                                                     pag_cta.g_ctas.cod_moneda,
                                                     nvl( g_msj.monto, 0 ),
                                                     v_mto_destino,
                                                     v_cot_origen,
                                                     v_cot_destino
                                                   );

                        if pas_snp.fu_obt_cod_error <> 0 then
                           --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error );
                        end if;
                     else
                        v_mto_destino := g_msj.monto;
                     end if;

                     if pas_snp.fu_obt_cod_error = 0 then
                        g_lugar :=  'Verificando los datos de la Cta. ' || v_cta_debito || ' (5), ' ;
                        pag_cta.pr_ver_operacion( pag_cta.g_ctas.nro_cuenta,   -- Nro.Cta.
                                                  v_tra_padre,                 -- Trx.Padre
                                                  pas_snp.fu_obt_cod_mod_padre,-- Mod.Padre
                                                  pas_snp.fu_obt_cod_mad_padre,-- Mad.Padre
                                                  v_tip_mov,                   -- Tip.Mov.
                                                  pag_cta.g_ctas.cod_moneda,   -- Cod.Mon.
                                                  v_mto_destino,               -- Monto
                                                  pag_cta.g_ctas.cod_oficina,  -- Ofic.Orig.
                                                  pag_cta.g_ctas.cod_modulo,   -- Mod.Padre
                                                  pag_cta.g_ctas.cod_modalidad,-- Mad.Padre
                                                  v_est_cuenta,                -- Estado Cta.
                                                  v_sal_disponible,            -- Sal.Dispon.
                                                  v_procesa                    -- Procesa
                                                );

                        if pag_cta.fu_obt_cod_error <> 0 then
                           --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                           pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                           pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error );

                        end if;
                     end if;
                  end if;

                  /*
                  || Si existe alg�n error se actualiza a CANCELADO la mensajer�a y
                  || Se env�a un mail a donde corresponda ( si aplica ).
                  || Si no tiene ning�n error entonces env�a el SWIFT al socket.
                  */

                  if g_det_msj_error is not null then
                     g_lugar :=  'Registrando error encontrado para la Cta. ' || v_cta_debito || ', ' ;
                     g_msj.error :=null; ---ha-3690-- limipia el campo para cargar el nuevo mensaje de error
					 g_msj.error := g_det_msj_error;

                     /*
                     || Setea la mensajer�a a CANCELADO, registrando el error encontrado.
                     || Si la cuenta tiene saldo insuficiente, no se cancela hasta que el
                     || indicador de cancelaci�n por insuficiencia de fondo tenga valor S.
                     || En caso de existir m�s errores junto al error de insuficiencia de
                     || saldo ser�n, �stos ser�n notificados por mail al grupo g_gru_dir_correo.
                     */

                     if upper( g_msj.error ) like '%SAL%INSUF%' then
                        if v_can_sin_fondo = 'S' then
                           g_msj.estado := 'C';
                        else -- Si existe errores de Saldo Insuficiente no se le notifica al cliente.
                           v_env_alerta := 'N';
                        end if;
                     else -- Son otros errores
                        g_msj.estado := 'C';
                     end if;

                     pas_snp.pr_set_transferencias ( g_msj );
                     --
                     -- Env�a el mail notificando el error.
                     BEGIN
                        if g_gru_dir_correo is not null then
                           it_mail.mail( fug_obt_dir_correo,
                                         g_gru_dir_correo,
                                         'Error antes de intentar env�ar el SWIFT a BCP.',
                                         'Se ha encontrado un error antes de intentar enviar el SWIFT a BCP.'||
                                         ' A continuaci�n los datos de la mensajer�a: '                             || chr(10) || chr(10) ||
                                         'Cliente        : ' || g_msj.nom_solicitante                               || chr(10) ||
                                         'Nro. Cuenta    : ' || g_msj.nro_cta_solicitante                           || chr(10) ||
                                         'Nro. Operaci�n : ' || g_msj.nro_operacion                                 || chr(10) ||
                                         'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY')               || chr(10) ||
                                         'Moneda         : ' || g_msj.cod_moneda                                    || chr(10) ||
                                         'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99')) || chr(10) ||
                                         'Motivo         : ' || g_msj.error                                         || chr(10) ||
                                         chr(10) || chr(10) ||
                                         'Atentamente.'
                                       );
                        end if;
                        if v_env_alerta = 'S' then
                           -- Env�a alertas al oficial y al cliente.
                           pas_snp.pr_set_env_alerta(v_env_alerta);
                           pas_snp.pr_env_alerta( g_msj, 'E' );
                        end if;

                     EXCEPTION
                        when others then
                           NULL;
                     END;
                  end if;
               end if;
               -- Si ya tiene movimientos asociados a la mensajer�a con situaci�n P y estado A �
               -- sino tiene errores intentar enviar al socket.
               if g_det_msj_error is null and
                  g_msj.situacion = 'P' and
                  g_msj.estado = 'A'
               then
                 --HA-3690 -- limipia el  mensaje de error del intento anterior
                  if upper( g_msj.error ) like '%SAL%INSUF%' then
                     update ge_snp_transferencias a
                     set a.error =null
                     where a.nro_referencia = c.nro_referencia;
                  end if;
                  pas_snp.pr_gen_arc_swift (g_msj.nro_referencia, 'N', g_msj.estado);
                  -- Si hubo problemas con el pr_set_transferencias en el pr_gen_arc_swift
                  -- se graba el error con un update
                  if pas_snp.fu_obt_cod_error != 0 then
                     update ge_snp_transferencias a
                        set a.error = error||' '||pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error
                      where a.nro_referencia = c.nro_referencia;
                  end if;
                   commit; --HA-3690
               end if;
            end if;
         end if;
      end loop;

      -- Env�o de mensajes REVERSADOS.
      for mt in cu_msj_rev loop
         g_lugar :=  'REV - Averiguando Horario Vigente en BCP para Nro. Ref.: ' || mt.nro_referencia;
         if pas_snp.fu_obt_est_horario( mt.cod_msj_swift,
                                        mt.cod_tip_operacion,
                                        mt.cod_sub_tip_operacion
                                      ) = 'A' then --Si el horario est� VIGENTE en BCP
            if pas_snp.fu_obt_cod_error = 0 then
               pas_snp.pr_gen_arc_swift ( mt.nro_referencia, 'N', 'R' );
               /*
               || Si hubo problemas con el pr_set_transferencias en el pr_gen_arc_swift
               || se graba el error con un update
               */
               if pas_snp.fu_obt_cod_error != 0 then
                  update ge_snp_transferencias a
                     set a.error = pas_snp.fu_obt_msj_error
                   where a.nro_referencia = mt.nro_referencia;
               end if;
            end if;
         end if;
      end loop;

   EXCEPTION
     when ex_horario then
        raise ex_horario;
     when ex_salir then
        raise ex_salir;
     when others then
        pas_snp.g_cod_error := 54;
        pas_snp.g_msj_error := 'Error en LP_PRO_SWI_ALT_VALOR, ' || ' - ' || sqlerrm;
        raise ex_salir;
   END lp_pro_swi_alt_valor;

   PROCEDURE lp_pro_swi_baj_valor
   IS
   BEGIN
      pas_snp.pr_obt_msj_mt102 ( c_fec_valor, 'S', 'N' );
   EXCEPTION
     when others then
        pas_snp.g_cod_error := 54;
        pas_snp.g_msj_error := 'Error en LP_PRO_SWI_BAJ_VALOR, ' || ' - ' || sqlerrm;
        raise ex_salir;
   END lp_pro_swi_baj_valor;

BEGIN
   /* Inicializa la aplicacion*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   --

   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --

   -- Se procesa los mensajes MT103, MT202
   lp_pro_swi_alt_valor;

   -- Luego se debe procesar los MTs 102
   lp_pro_swi_baj_valor;

EXCEPTION
   when ex_horario then
      pas_snp.g_cod_error := 54;
      pas_snp.g_msj_error := g_lugar || ' ' || pas_snp.fu_obt_msj_error;
   when ex_salir then
      pas_snp.g_cod_error := 54;
      pas_snp.g_msj_error := g_lugar || ' - ' || pas_snp.fu_obt_msj_error;
   when others then
      pas_snp.g_cod_error := 54;
      pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
END pr_gen_men_automaticos;

PROCEDURE pr_gen_rev_snp( p_fec_valor in ge_snp_transferencias.fec_valor%type default null )
IS
  /*
  || Proceso diario de reversi�n de todas las operaciones referentes a SNP y
  || cancelaci�n de la mensajer�a.
  */

  c_fec_valor constant date := nvl( p_fec_valor, g_fec_actual );
  v_existe varchar2(1):='N';
  v_can    number;
  cursor cu_msj_pend is
     select t.nro_referencia, t.fec_insercion
       from ge_snp_transferencias t
      where t.cod_msj_swift  IN ( 102, 103, 202 )
        and ( case
                when t.fec_recepcion is null then
                  /*
                  || Si es ENVIADO reversar los que est�n con las siguientes SITUACIONES / ESTADOS:
                  || - SITUACI�N Pendiente de Env�o a BCP � Enviando al Socket y con ESTADO distinto a Cancelado, Error y Reversado.
                  */
                  case
                    when t.situacion in ('P', 'N', 'V') and  -- DA-4875 -- NGRANCE --
                         t.estado not in ('C', 'E', 'R') then 'S'
                    else 'N'
                  end
                else
                   /*
                   || Si es RECIBIDO reversar los que est�n con las siguientes SITUACIONES / ESTADOS:
                   || - SITUACI�N Recibido � Error y con ESTADO Solicitado.
                   */
                   case
                     when t.situacion in ('R', 'E') and
                          t.estado = 'S' then 'S'
                     else 'N'
                   end
                end
            ) = 'S'
        and (   t.fec_valor  =  c_fec_valor               -- Mensajes con fecha valor igual a calendario que no fueron finiquitadas
             or exists ( select 1                          -- � Mensajes (Futuras o del d�a) que no fueron aprobadas desde el HB (Movimientos Pendientes de Autorizaci�n)
                           from bw_mov_pendientes mp
                          where mp.referencia = t.nro_referencia
                            and mp.nro_cuenta = t.nro_cta_solicitante
                            and trunc( mp.fec_hora ) = trunc( t.fec_insercion )
                            and instr( fug_obt_pardinamico( 'SNP_COD_TIP_MSJ_HB' ), mp.cod_tip_mensaje ) > 0
                            and mp.estado = 'P'
                        )
            )
        for update of t.nro_referencia nowait;

BEGIN
    /*Inicializa la aplicacion y el modulo*/
     begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

    /*Inicializa las variables de error*/
    pas_snp.pr_ini_variables;

    for c in cu_msj_pend loop

        --Obtiene el registro de ge_snp_transferencias
        g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
        pas_snp.pr_obt_mensaje ( c.nro_referencia, 'N' );

        if pas_snp.fu_obt_cod_error = 0 then
           if g_msj.fec_recepcion is null then
              -- Si es un MT Enviado
              --TRFS-383
             if g_msj.cod_msj_swift=103 then
               --Busca si tiene confirmacion MT900
               begin
               select 'S' INTO v_existe from ge_snp_mensajes
               where nro_ref_externa=to_char(g_msj.nro_referencia);
               exception
                 when no_data_found then
                   v_existe:='N';
                 when others then
                   v_existe:='N';

               end;
             end if;
             if g_msj.cod_msj_swift=102 then
                --Busca si tiene NETL,NETR o NETS
               begin
               select count(*) INTO v_can from ge_snp_mensajes
               where nro_ref_externa=g_msj.nro_lote;
               exception
                 when no_data_found then
                   v_can:=0;
                 when others then
                   v_can:=0;

               end;
               if v_can >=1 then
                  v_existe:='S';
               else
                  v_existe:='N';
               end if;
             end if;
             if v_existe ='N' then
              if g_msj.fecha is not null and   -- Si tiene un movimiento asociado lo reversa,
                 g_msj.hora is not null and    -- la reversion ya cancela el SWIFT y elimina del WF (si aplica)
                 g_msj.cod_usuario is not null
              then
                --TRFS-628
                pas_spi.g_reversion:='S';
                 pas_snp.pr_rev_ope_con_swift( g_msj.nro_referencia, 'Rev. autom�tica del mensaje con mov. relacionados - SNP', 'C' );
                pas_spi.g_reversion:='N';
                 -- Si la reversi�n tiene ERRORES se adjunta el error en la mensajer�a.
                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto( g_msj.error, pas_snp.fu_obt_msj_error, ' ' );
                 end if;
              else
                 g_msj.estado := 'C';
                 pas_snp.pr_set_transferencias ( g_msj );

                 -- Cancela circuito relacionado al mismo (Si aplica).
                 pas_snp.pr_can_workflow( g_msj.nro_referencia );

                 -- Si la cancelaci�n del circuito tiene ERRORES se adjunta el error en la mensajer�a.
                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto( g_msj.error, pas_snp.fu_obt_msj_error, ' ' );
                 end if;
              end if;

              -- Si la mensajer�a de la fecha valor no tiene movimientos y no se env�o al BCP se debe cancelar
              -- Se debe eliminar tambien si la menjajer�a es del RW y tiene movimientos pendientes de autorizaci�n.
              if g_msj.origen = 'H' then
                 delete bw_mov_pendientes mp
                  where mp.referencia = c.nro_referencia
                    and mp.nro_cuenta = g_msj.nro_cta_solicitante
                    and trunc( mp.fec_hora ) = trunc( c.fec_insercion )
                    and instr( fug_obt_pardinamico( 'SNP_COD_TIP_MSJ_HB' ), mp.cod_tip_mensaje ) > 0
                    and mp.estado = 'P'; -- Movimientos Pendientes de Autorizaci�n
                 if sql%found then
                    pas_snp.pr_set_texto( g_msj.error, 'Rev. autom�tica del mensaje. Movimientos pendientes de autorizaci�n en el HB - SNP.', ' ' );
                 end if;
              else -- Origen es ITGF
                 pas_snp.pr_set_texto( g_msj.error, 'Rev. autom�tica del mensaje. Situaci�n y Estado del mensaje inapropiados - SNP.', ' ' );
              end if;

              -- Actualizo la situaci�n de la operaci�n.
              g_lugar :=  'Actualizando la Situaci�n de la Operaci�n, ';
              g_msj.situacion := 'T';
              pas_snp.pr_set_transferencias ( g_msj );
              --
              end if;
           elsif g_msj.fec_recepcion is not null and
             not pas_snp.fu_ver_workflow( g_msj.nro_referencia )
           then
             -- Si es un MT Recibido y no tiene Circuito Pendiente, darle seguimiento.
             g_lugar :=  'Actualizando la Situaci�n de la Operaci�n, ';
             if g_msj.estado = 'S' and g_msj.situacion in ( 'R', 'E' ) then
                pas_snp.pr_ini_workflow( g_msj );
                if pas_snp.fu_ver_workflow( g_msj.nro_referencia ) then
                   g_msj.situacion := 'I';
                   pas_snp.pr_set_transferencias ( g_msj );
                end if;
             else
                g_msj.situacion := 'T';
                g_msj.estado := 'C';
                pas_snp.pr_set_texto( g_msj.error, 'Rev. autom�tica del mensaje. Situaci�n y Estado del mensaje inapropiados para iniciar Circuito - SNP.', ' ' );
                pas_snp.pr_set_transferencias ( g_msj );
             end if;
             --
           end if;
        end if;
    end loop;
EXCEPTION
  when ex_salir then
     pas_snp.g_cod_error := 57;
     pas_snp.g_msj_error := g_lugar || ' - ' || pas_snp.fu_obt_msj_error;
     raise_application_error(-20001,'Error en PAS_SNP.PR_GEN_REV_SNP: ' || pas_snp.fu_obt_msj_error);
  when others then
     pas_snp.g_cod_error := 57;
     pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
     raise_application_error(-20001,'Error en PAS_SNP.PR_GEN_REV_SNP: ' || pas_snp.fu_obt_msj_error);
END pr_gen_rev_snp;

PROCEDURE pr_rev_ope_con_swift( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                p_concepto       in ge_movimientos.concepto%type default null,
                                p_estado         in ge_snp_transferencias.estado%type default 'C'
                              )
IS
   /*
   || Reversi�n de operaci�n con un SWIFT relacionado.
   */

   v_hor_reversion ge_movimientos.hor_reversion%type := fug_obt_mov_hora;--fug_ini_hora;
   v_concepto      ge_movimientos.concepto%type;
   v_usu_reversion ba_usuarios.cod_usuario%type;

   cursor cur_snp ( p_fecha         ge_movimientos.fecha%type,
                    p_hora          ge_movimientos.hora%type,
                    p_cod_usuario   ge_movimientos.cod_usuario%type,
                    p_nro_documento ge_movimientos.nro_documento%type
                  ) is
      select /*+ NO_UNNEST */
             distinct fecha,
             hora,
             cod_usuario,
             cod_mod_padre,
             cod_mad_padre,
             cod_tra_padre,
             nro_documento,
             nro_documento2,
             concepto
        from gv_movimientos
       where fecha         = p_fecha
         and hora          = p_hora
         and cod_usuario   = p_cod_usuario
         and nro_documento = p_nro_documento
         and reversado = 'N';

BEGIN

   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   pas_snp.pr_obt_mensaje( p_nro_referencia, 'S' );
   if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
   end if;

   /* Se incluye a los campos fecha, hora, cod_usuario, nro_secuencia
   || para que levante el orden antes de realizar el rownum
   */
   g_lugar := 'Buscando movimientos para el proceso de reversi�n ';
   for rg in cur_snp (g_msj.fecha, g_msj.hora, g_msj.cod_usuario, g_msj.nro_referencia ) loop

      --Reversi�n de la operaci�n
      g_lugar := 'Intentando reversar la operaci�n ';
      if rg.nro_documento2 is null then
         v_concepto := 'Rev.'||rg.concepto;
      else
         v_concepto := pas_snp.fu_obt_mov_concepto('R', g_msj.origen, nvl(g_msj.nro_ref_externa, g_msj.nro_referencia));
      end if;
      if g_msj.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_PCD' ) then
        v_concepto:='RV'||g_msj.nro_ref_externa;
      end if;
	  prs_snp_obt_usu_hor_movimiento(user,'S',v_usu_reversion,v_hor_reversion);
      prg_rev_operacion( rg.fecha,
                         rg.hora,
                         rg.cod_usuario,
                         rg.cod_mod_padre,
                         rg.cod_mad_padre,
                         rg.cod_tra_padre,
                         v_usu_reversion,
                         v_hor_reversion,
                         'N',
                         v_concepto,
                         null,
                         null,
                         rg.nro_documento
                       );
      --
   end loop;

   --Actualiza el estado seg�n par�metro ingresado
   g_msj.estado := nvl( p_estado, 'C' );
   g_msj.error  := p_concepto;
   pas_snp.pr_set_transferencias ( g_msj );
   --
EXCEPTION
  when ex_salir then
     pas_snp.g_cod_error := 51;
     pas_snp.g_msj_error := g_lugar || ' - ' || pas_snp.fu_obt_msj_error;
     raise_application_error(-20000, 'Error en PAS_SNP.PR_REV_OPE_CON_SWIFT, '||'referencia: '|| g_msj.nro_referencia || pas_snp.fu_obt_msj_error);
  when no_data_found then
     pas_snp.g_cod_error := 51;
     pas_snp.g_msj_error := g_lugar || ' - ' || 'No se han encontrados datos para la Reversi�n';
     raise_application_error(-20001, 'Error en PAS_SNP.PR_REV_OPE_CON_SWIFT, '||'referencia: '|| g_msj.nro_referencia  || pas_snp.fu_obt_msj_error);
  when others then
     pas_snp.g_cod_error := 51;
     pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
     raise_application_error(-20002, 'Error en PAS_SNP.PR_REV_OPE_CON_SWIFT, '||'referencia: '|| g_msj.nro_referencia  || pas_snp.fu_obt_msj_error);
END pr_rev_ope_con_swift;

FUNCTION fu_obt_cli_principal( p_nro_cuenta  ge_cuentas.nro_cuenta%type ) return varchar2
IS
   /*
   || Verifica que exista la relaci�n  de la cuenta con el cliente.
   */

   v_cod_cliente ge_cta_clientes.cod_persona%type;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   g_lugar :=  'Obteniendo Cliente principal de la Persona, ';
   SELECT cod_persona
     INTO v_cod_cliente
     FROM ge_cta_clientes
    WHERE nro_cuenta = p_nro_cuenta
      AND relacion = 'P';
   RETURN v_cod_cliente;
EXCEPTION
   when no_data_found then
      pas_snp.g_cod_error := '25';
      pas_snp.g_msj_error := 'Cuenta sin cliente principal';
      return NULL;
   when too_many_rows then
      pas_snp.g_cod_error := '25';
      pas_snp.g_msj_error := 'M�s de un Principal definido para la Cuenta';
      return NULL;
   when others then
      pas_snp.g_cod_error := '25';
      pas_snp.g_msj_error :='Obt.Principal de Cta. '||sqlerrm;
      return NULL;
END fu_obt_cli_principal;

FUNCTION fu_obt_mon_cta( p_nro_cuenta in varchar2 ) return varchar2
IS
   /*
   || Obtiene la moneda de la Cta.
   */

   v_cod_moneda ba_monedas.cod_moneda%type;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   g_lugar :=  'Obteniendo moneda de la Cuenta, ';
   select a.cod_moneda
     into v_cod_moneda
     from ge_cuentas a
    where a.nro_cuenta = p_nro_cuenta;
   return v_cod_moneda;
EXCEPTION
  when no_data_found then
     pas_snp.g_cod_error := '26';
     pas_snp.g_msj_error := 'No se encuentra la moneda para la Cta. '||p_nro_cuenta;
     return NULL;
  when others then
     pas_snp.g_cod_error := '26';
     pas_snp.g_msj_error := 'Error en PAS_SNP.FU_OBT_MON_CTA '||' - '||sqlerrm;
     return NULL;
END fu_obt_mon_cta;

FUNCTION fu_obt_dir_principal( p_cod_persona in ba_personas.cod_persona%type ) return varchar2
IS
   /*
   || Busqueda de la direccion de la persona principal.
   */
   v_direccion ba_direcciones.direccion%TYPE;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   g_lugar :=  'Obteniendo direcci�n principal de la de la Persona, ';
   select direccion
     into v_direccion
     from ba_direcciones
    where cod_persona = p_cod_persona
      and principal = 'S';
   return v_direccion;
EXCEPTION
  when no_data_found then
     pas_snp.g_cod_error := '58';
     pas_snp.g_msj_error := 'Cliente sin direccion registrada';
     return NULL;
  when others then
     pas_snp.g_cod_error := '58';
     pas_snp.g_msj_error := 'Error al obt.direccion '||' - '||sqlerrm;
     return NULL;
END fu_obt_dir_principal;

FUNCTION fu_obt_nro_doc_persona( p_cod_persona in ba_personas.cod_persona%type ) return varchar2
IS
   /*
   || Busqueda del n�mero de documento de la persona principal.
   */
   v_nro_documento ba_personas.nro_documento%type;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   g_lugar :=  'Buscando Nro. Doc. de la Persona, ';
   select nro_documento
     into v_nro_documento
     from ba_personas
    where cod_persona = p_cod_persona;
    return v_nro_documento;
EXCEPTION
  when no_data_found then
     pas_snp.g_cod_error := '28';
     pas_snp.g_msj_error := 'Persona no registrada en el Sistema';
     return NULL;
  when others then
     pas_snp.g_cod_error := '28';
     pas_snp.g_msj_error := 'Error al obt. n� de documento '||' - '||sqlerrm;
     return NULL;
END fu_obt_nro_doc_persona;

FUNCTION fu_obt_dat_referencias( p_dominio IN ba_cod_referencias.dominio%type,
                                 p_valor IN ba_cod_referencias.val_minimo%type ) return boolean
IS
   /*
   || Validaci�n del dominio y el val_minimo en BA_COD_REFERENCIAS.
   */
   v_existe varchar2(1):= 'N';
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   g_lugar :=  'Buscando datos en BA_COD_REFERENCIAS, ';
   select distinct 'S'
     into v_existe
     from ba_cod_referencias
    where dominio    = p_dominio
      and val_minimo = p_valor;
    return TRUE;
EXCEPTION
  when no_data_found then
     pas_snp.g_cod_error := '29';
     pas_snp.g_msj_error := 'Referencia  no registrada en el Sistema';
     RETURN FALSE;
  when others then
     pas_snp.g_cod_error := '29';
     pas_snp.g_msj_error := 'Error al obt. datos de ba_cod_referencias '||' - '||sqlerrm;
     RETURN FALSE;
END fu_obt_dat_referencias;

FUNCTION fu_obt_cta_bancaria( p_nro_cuenta in cc_cta_bancarias.nro_cta_bancaria%type,
                              p_tip_cuenta in varchar2 ) return varchar2
IS
   /*
   || Obtiene la Cta. Bancaria.
   */

   v_nro_cta_bancaria cc_cta_bancarias.nro_cta_bancaria%type;
   v_nro_cuenta       cc_cta_bancarias.nro_cuenta%type;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   g_lugar :=  'Obteniendo Cta. Bancaria, '||p_nro_cuenta||'-'||p_tip_cuenta;
   if p_tip_cuenta = 'B' then
      select nro_cta_bancaria
        into v_nro_cta_bancaria
        from cc_cta_bancarias
       where nro_cuenta    = p_nro_cuenta
         and cod_modulo    = pas_snp.fu_obt_cod_mod_padre
         and cod_modalidad = pas_snp.fu_obt_cod_mad_padre
         and estado        IN ( 'A', 'N', 'S' ) /*Abierta, Normal, Bloqueo de Saldo*/
         and fug_obt_paradicional(nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ';
      return v_nro_cta_bancaria;
   elsif p_tip_cuenta = 'C' then
     select nro_cuenta
       into v_nro_cuenta
       from cc_cta_bancarias
      where nro_cta_bancaria = p_nro_cuenta
        and cod_modulo       = pas_snp.fu_obt_cod_mod_padre
        and cod_modalidad    = pas_snp.fu_obt_cod_mad_padre
        and estado           IN ( 'A', 'N', 'S' ) /*Abierta, Normal, Bloqueo de Saldo*/
        and fug_obt_paradicional(nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ';
     return v_nro_cuenta;
   end if;
  return NULL;
EXCEPTION
   when no_data_found then
       pas_snp.g_cod_error := '30';
       pas_snp.g_msj_error := 'Sin Cta. Bancaria asignada';
       return NULL;
    when too_many_rows then
       pas_snp.g_cod_error := '30';
       pas_snp.g_msj_error := 'Nro. Cta. Bancaria '||p_nro_cuenta||' existe para m�s de una cuenta.!';
       return NULL;
    when others then
       pas_snp.g_cod_error := '30';
       pas_snp.g_msj_error := 'Error al Obt.Cta.Bancaria '||' - '||sqlerrm;
       return NULL;
END fu_obt_cta_bancaria;



FUNCTION fu_ver_cta_interbancaria ( p_nro_cuenta in ge_cuentas.nro_cuenta%type ) return BOOLEAN
IS
  /*
  ||Funci�n que verifica si una cuenta es o no una Cta. Interbancaria (Cta. con modalidad 455)
  */
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   pag_cta.pr_obt_cuenta ( p_nro_cuenta ) ;
   if pag_cta.fu_obt_cod_error <> 0 or
      pag_cta.g_ctas.cod_modalidad <> pas_snp.fu_obt_cod_mad_padre
   then
      return FALSE;
   end if;

   return TRUE;

EXCEPTION
  when others then
    return FALSE;
END fu_ver_cta_interbancaria;

FUNCTION fu_ver_mt_env_bcp ( p_nro_referencia in ge_snp_transferencias.nro_referencia%type ) return varchar2
IS
/*
|| Funci�n que verifica si un MT fue enviado o no al BCP.
|| Evalua la situaci�n y el estado del mt seg�n los par�metros recibidos para la consulta
*/
  v_enviado varchar2(1) := 'N';

BEGIN
/* La transferencia fu� enviada al BCP Si la SITUACION se encuentra en:
A Aprobaci�n de Tesorer�a BCP, D En Demora, L Operaci�n Liquidada, O Pre-Proceso OK
R Recibido, S Pre-Proceso Pendiente, V Enviado al BCP, X Rechazo de Tesorer�a BCP*/

   select 'S'
     into v_enviado
     from ge_snp_transferencias t
    where t.situacion in ('S', 'A', 'X', 'V', 'D', 'L', 'R', 'O')
      and t.nro_referencia = p_nro_referencia;

   return v_enviado;

EXCEPTION
   WHEN OTHERS THEN
      return 'N';

END fu_ver_mt_env_bcp;

FUNCTION fu_val_es_enviado ( rg_msj_ver_env in pas_snp.rg_msj ) return BOOLEAN
IS
  /*
  ||Funci�n que valida si la mensajer�a es ENVIADA o RECIBIDA
  */
BEGIN
   if rg_msj_ver_env.fec_recepcion is not null and
      rg_msj_ver_env.nro_ref_externa is not null
   then --Es mensaje RECIBIDO
      return FALSE;
   end if;
   return TRUE; --Es mensaje ENVIADO

END fu_val_es_enviado;

FUNCTION fu_ver_seg_cliente ( p_cod_cliente in ge_clientes.cod_persona%type ) return varchar2
IS
   /*
   || Funci�n que verifica si el segmento del cliente debe levantar o no Workflow.
   || Retorna los valores 'S' o 'N' (Si levanta workflow o No).
   */
   c_seg_clientes    ge_par_dinamicos.val_parametro%type := nvl( fug_obt_pardinamico ( 'SNP_SEG_CLIENTES'),-999 );
   TYPE              t_tipo_cursor IS REF CURSOR;
   cu_cursor         t_tipo_cursor;
   v_existe          varchar2(1) := 'N';
   v_sql             varchar2(2000) := null;
BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --

   v_sql := 'select distinct ''S''
               from ge_clientes
              where cod_persona = :p_cod_cli
                and cod_seg_cliente in ('||c_seg_clientes||')';
   open cu_cursor for v_sql using p_cod_cliente;
   loop
      fetch cu_cursor into v_existe;
      exit when cu_cursor%notfound;
      return v_existe;
   end loop;
   close cu_cursor;
   return v_existe;

EXCEPTION
   WHEN others THEN
      pas_snp.g_cod_error := 57;
      pas_snp.g_msj_error := substr('Error inesperado en PAS_SNP.FU_VER_SEG_CLIENTE. Verificar valor para el par�metro din�mico SNP_SEG_CLIENTES '||', '||sqlerrm, 1, 200);
      return 'S';
END fu_ver_seg_cliente;

-- Procedimiento que valida el contrato de cotizacion para MT Recibidos
PROCEDURE pr_obt_con_cambio ( p_nro_con_cambio  in out lc_ope_pendientes.nro_operacion%type, --Nro Contrato de Cambios (opcional)
                              p_con_confirma    in     varchar2 default 'N',                 --Confirma o v�lida contrato (S/N)
                              p_cta_debito      in     lc_ope_pendientes.cta_referencia%type,
                              p_cta_credito     in     lc_ope_pendientes.cta_referencia%type,
                              p_mto_operacion   in     lc_ope_pendientes.monto%type,
                              p_cod_mon_origen  in     lc_ope_pendientes.cod_moneda%type,    --Moneda Origen
                              p_cod_mon_destino in     lc_ope_pendientes.cod_moneda%type,    --Moneda Destino
                              p_cotizacion      in out lc_ope_pendientes.cotizacion%type,    --Cotizaci�n de Cambio
                              p_mto_debito      in out lc_ope_pendientes.monto%type,         --Monto del Contrato de Cambio
                              p_mto_credito     in out lc_ope_pendientes.monto%type          --Monto del Contrato de Cambio
                            )
IS
  v_nro_contrato    lc_ope_pendientes.nro_operacion%type := null;
  v_cotizacion      lc_ope_pendientes.cotizacion%type    := null;
  v_mto_debito      lc_ope_pendientes.monto%type         := null;
  v_mto_credito     lc_ope_pendientes.monto%type         := null;
  v_cta_referencia  lc_ope_pendientes.cta_referencia%type:= null;
  v_cta_ref_contra3 lc_ope_pendientes.cta_referencia%type:= null;
  v_tip_operacion   varchar2(3);

BEGIN
   if p_cod_mon_origen <> p_cod_mon_destino then
      if p_cod_mon_destino <> g_cod_mon_local and
         p_cod_mon_origen <> g_cod_mon_local
      then
         pas_snp.g_cod_error := 59;
         pas_snp.g_msj_error := 'No se puede realizar Cambio por Arbitraje.!';
         raise ex_salir;
      end if;
      if p_cod_mon_origen <> g_cod_mon_local and
         p_cod_mon_destino = g_cod_mon_local
      then
         v_tip_operacion := 16; -- compra
         v_cta_referencia  := p_cta_debito;
         v_cta_ref_contra3 := p_cta_credito;
      else
         v_tip_operacion := 30; -- venta
         v_cta_referencia  := p_cta_credito;
         v_cta_ref_contra3 := p_cta_debito;
      end if;

      Begin
         select l.cotizacion,
                decode(l.cod_moneda, p_cod_mon_origen, l.monto, l.mto_equ_local) mto_debito,
                decode(l.cod_moneda, p_cod_mon_origen, l.mto_equ_local, l.monto) mto_credito,
                l.nro_operacion
           into v_cotizacion, v_mto_debito, v_mto_credito, v_nro_contrato
         from lc_ope_pendientes l
         where l.liquidado         = 'N'
           and l.cod_tip_operacion = v_tip_operacion
           and l.nro_operacion     = nvl(p_nro_con_cambio,l.nro_operacion)
           and l.cta_referencia    = v_cta_referencia
           and l.cta_ref_contra3   = v_cta_ref_contra3
           and (   ( l.monto * l.cotizacion ) = p_mto_operacion
                or l.monto = p_mto_operacion
               )
           and l.fec_operacion     = g_fec_actual;
      exception
         when no_data_found then
           null; -- Si no encuentra Contrato de Cambio, se recupera la cotizaci�n de Pizarra.
         when others then
           pas_snp.g_cod_error := 59;
           pas_snp.g_msj_error := 'Error al buscar Contato de Cambio '||sqlerrm;
           raise ex_salir;
      end ;

      p_cotizacion  := v_cotizacion;
      p_mto_debito  := v_mto_debito;
      p_mto_credito := v_mto_credito;

      if p_con_confirma = 'S' and
         v_nro_contrato is not null
      then
         update lc_ope_pendientes
            set liquidado           = 'S',
                cod_usu_liquidacion = user,
                fec_liquidacion     = g_fec_actual
          where nro_operacion       = v_nro_contrato;
      end if;

   end if;
EXCEPTION
  when ex_salir then
    null;
  when others then
    pas_snp.g_cod_error := 59;
    pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_CON_CAMBIO '||sqlerrm;
END pr_obt_con_cambio;

PROCEDURE pr_gen_mov_tesoreria( p_fec_valor in ge_snp_transferencias.fec_valor%type default null )
IS
   /*
   || Proceso diario de generaci�n de movimientos para Dep�sito y Extracci�n en Fecha Futura.
   || Solo genera movimientos a MT202 Enviado que fueron aprobados por WF
   */
   v_fec_valor    date := nvl( p_fec_valor, g_fec_actual );

   cursor cur_mt_202 is
     select t.nro_referencia, t.situacion
       from ge_snp_transferencias t
      where t.fec_valor                =  v_fec_valor
        and t.estado                   = 'A'          -- Aprobado en ITGF
        and t.situacion                = 'V'          -- Enviado a BCP
        and t.cod_msj_swift            = 202
        and t.nro_ref_externa          IS NULL        -- Para MT enviados
        and t.fec_recepcion            IS NULL        -- Para MT enviados
        and t.error                    IS NULL
        and t.monto                    > 0
        and t.fecha                    IS NULL        -- Que no tenga movimientos relacionados aun,
        and t.hora                     IS NULL        -- ya que el MT de confirmacion crear� el movimiento
        and t.cod_usuario              IS NULL        -- relacionado a la operaci�n enviada
        and t.nro_cta_pte_solicitante  IS NOT NULL
        and t.fec_valor                > t.fec_ingreso
        and t.cod_tip_operacion        IN ('002','003') ; -- Solo Dep�sito y Extracci�n de Efectivo.
BEGIN
   -- Inicializa las variables
   pas_snp.pr_ini_variables;
   for n in cur_mt_202 loop
      pas_snp.pr_ini_registros;
      --Obtiene el registro de ge_snp_transferencias
      g_lugar :=  'Obteniendo datos del MT Nro. , ' ||n.nro_referencia || ', ' ;
      pas_snp.pr_obt_mensaje ( n.nro_referencia, 'N' );

      if pas_snp.fu_obt_cod_error = 0 then
         g_lugar :=  'Al Generar movimiento del MT Nro. , ' ||n.nro_referencia|| ', ' ;
         -- Setea la Situaci�n a Liquidado para la Generaci�n de movimientos via Trigger.
         g_msj.situacion := 'L';
      else
         pas_snp.pr_set_texto ( g_msj.error, pas_snp.fu_obt_msj_error, ' ' );

         -- Env�a el mail notificando el Error al tratar de Generar movimiento.
         BEGIN
            if g_err_dir_tesoreria is not null then
               it_mail.mail( fug_obt_dir_correo,
                             g_err_dir_tesoreria,
                             'Error al Tratar de Generar Movimiento por Dep�sito/Extracci�n Futura.',
                             'Se ha producido un error al tratar de generar movimiento por una operaci�n de Dep�sito/Extracci�n en Efectivo Futura.' ||
                             ' A continuaci�n los datos del MT: '                                       || chr(10) || chr(10) ||
                             'Nro. Cuenta    : ' || g_msj.nro_cta_pte_solicitante                       || chr(10) ||
                             'Nro. Referencia: ' || g_msj.nro_referencia                                || chr(10) ||
                             'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY')               || chr(10) ||
                             'Fecha Registro : ' || to_char(g_msj.fec_ingreso,'DD/MM/YYYY')             || chr(10) ||
                             'Moneda         : ' || g_msj.cod_moneda                                    || chr(10) ||
                             'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99')) || chr(10) ||
                             chr(10) || chr(10) ||
                             'Atentamente.'
                           );
            end if;
         EXCEPTION
           when others then
              NULL;
         END;
      end if ;
      pas_snp.pr_set_transferencias ( g_msj );
      pas_snp.pr_obt_mensaje ( n.nro_referencia, 'N' );
      g_msj.situacion := n.situacion ;
      pas_snp.pr_set_transferencias ( g_msj );
   end loop ;
EXCEPTION
   when others then
      pas_snp.g_cod_error := 67;
      pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
END pr_gen_mov_tesoreria ;

PROCEDURE pr_gen_tra_servicio ( p_cod_servicio in ge_cob_servicios.cod_servicio%type )
IS
   /*
   || Procedimiento de generaci�n de mensajer�a de cobro de servicios
   */
   rg_mensaje             pas_snp.rg_msj;
   v_tab_cob_servicio     pas_snp.t_tab_cob_servicio;
   v_cod_per_servicio     ba_personas.cod_persona%type;
   v_cod_ente             ge_entes.cod_ente%type;
   v_nro_cta_origen       ge_cuentas.nro_cuenta%type;
   v_cod_mon_origen       ge_cuentas.cod_moneda%type;
   v_nro_cta_destino      ge_cuentas.nro_cuenta%type;
   v_tot_monto            ge_movimientos.monto%type;
   v_mai_alerta           ge_par_entes.val_parametro%type;
   v_mai_ente             ge_par_entes.val_parametro%type;
   v_dia_env_mensaje      ge_par_entes.val_parametro%type;
   v_abr_servicio         ge_par_entes.val_parametro%type;
   v_cob_ser_automatico   ge_par_entes.val_parametro%type;
   v_tra_debito           ge_transacciones.cod_transaccion%type;
   v_tip_mov_debito       ge_transacciones.afecta%type := 'D';
   v_cod_msj_swift        ge_par_entes.val_parametro%type;
   v_con_transferencia    ge_par_entes.val_parametro%type;
   v_per_pte_beneficiario ge_snp_transferencias.cod_per_beneficiario%type;
   v_nro_cta_beneficiario ge_snp_transferencias.nro_cta_beneficiario%type;
   v_tip_operacion        ge_par_entes.val_parametro%type;
   v_sub_tip_operacion    ge_par_entes.val_parametro%type;
   v_cod_oficina          ge_snp_transferencias.cod_oficina%type;
   v_prioridad            ge_snp_transferencias.prioridad%type;
   v_cod_ser_parametro    ge_snp_transferencias.cod_servicio%type;
   v_cod_servicio         ge_snp_transferencias.cod_servicio%type;
   v_dir_correo           ge_par_dinamicos.val_parametro%type;
   v_asunto               varchar2(100);
   v_mensaje              varchar2(1000);
   -- Retorno de verificaci�n de operaciones
   v_est_cuenta           ge_cuentas.estado%type;    -- Estado Cta.
   v_sal_disponible       ge_movimientos.monto%type; -- Sal.Dispon.
   v_procesa              varchar2(1) := 'N';

   PROCEDURE lp_obt_dat_cob_servicio ( p_cod_servicio IN ge_cob_ser_parametros.cod_servicio%type )
   IS
   -- Busca los datos del servicio
   BEGIN
      pas_snp.g_lugar := 'Obteniendo datos para el Cobro de Servicios ' || p_cod_servicio || ', ';
      BEGIN
        select cs.cod_persona
          into v_cod_per_servicio
          from ge_cob_ser_parametros cs
         where cs.cod_servicio = p_cod_servicio;

        -- Si no encuentra la persona, cancelar el proceso
        if v_cod_per_servicio is null then
           raise no_data_found;
        end if;

      EXCEPTION
         when no_data_found then
            pas_snp.g_cod_error := 76;
            pas_snp.pr_set_texto ( pas_snp.g_msj_error, g_lugar ||
                                   'Persona inexistente para el servicio ' || p_cod_servicio,
                                   pas_snp.fu_obt_salto
                                 );
            raise pas_snp.ex_salir;
         when others then
            pas_snp.g_cod_error := 76;
            pas_snp.pr_set_texto ( pas_snp.g_msj_error,
                                   g_lugar || 'Error al buscar la persona para el servicio ' || p_cod_servicio || ': ' || sqlerrm,
                                   pas_snp.fu_obt_salto
                                 );
            raise pas_snp.ex_salir;
      END;

      BEGIN
         select pe.cod_ente
           into v_cod_ente
           from ge_entes pe
          where tipo = 'TH'
            and exists ( select 0
                           from ge_par_entes p
                          where p.parametro     = 'SNP_COD_SERVICIO'
                            and p.val_parametro = p_cod_servicio
                            and p.cod_ente      = pe.cod_ente
                       )
            and cod_persona = v_cod_per_servicio;

         -- Si no encuentra el ente, cancelar el proceso
         if v_cod_ente is null then
            raise no_data_found;
         end if;

      EXCEPTION
         when no_data_found then
            pas_snp.g_cod_error := 76;
            pas_snp.pr_set_texto ( pas_snp.g_msj_error,
                                   g_lugar || 'Ente inexistente para la persona ' || nvl( v_cod_per_servicio, -99 ) || ' y c�d. servicio ' || p_cod_servicio,
                                   pas_snp.fu_obt_salto
                                 );
            raise pas_snp.ex_salir;
         when others then
            pas_snp.g_cod_error := 76;
            pas_snp.pr_set_texto ( pas_snp.g_msj_error,
                                   g_lugar || 'Error al buscar el ente para la persona ' || nvl( v_cod_per_servicio, -99 ) || ' y c�d. servicio ' || p_cod_servicio || ': ' ||sqlerrm,
                                   pas_snp.fu_obt_salto
                                 );
            raise pas_snp.ex_salir;
      END;

      pas_snp.g_lugar := 'Obteniendo Par�metros del ente ' || v_cod_ente || ', ';
      v_nro_cta_origen       := fug_obt_parentes( v_cod_ente, 'SNP_CTA_ORIGEN' );
      v_nro_cta_destino      := fug_obt_parentes( v_cod_ente, 'SNP_CTA_DESTINO' );
      v_cob_ser_automatico   := fug_obt_parentes( v_cod_ente, 'SNP_COB_SER_AUTOMATICO' );
      v_tra_debito           := fug_obt_parentes( v_cod_ente, 'SNP_COD_TRA_DEBITO' );
      v_abr_servicio         := fug_obt_parentes( v_cod_ente, 'SNP_ABR_SERVICIO' );
      v_mai_alerta           := fug_obt_parentes( v_cod_ente, 'SNP_EMA_ALERTA' );
      v_mai_ente             := fug_obt_parentes( v_cod_ente, 'SNP_EMA_CON_MT' );
      v_cod_msj_swift        := fug_obt_parentes( v_cod_ente, 'SNP_COD_MT' );
      v_con_transferencia    := fug_obt_parentes( v_cod_ente, 'SNP_MT_CONCEPTO' );
      v_per_pte_beneficiario := fug_obt_parentes( v_cod_ente, 'SNP_PER_PTE_BENEFICIARIO' );
      v_nro_cta_beneficiario := fug_obt_parentes( v_cod_ente, 'SNP_CTA_BENEFICIARIO' );
      v_tip_operacion        := fug_obt_parentes( v_cod_ente, 'SNP_MT_TIPO' );
      v_sub_tip_operacion    := fug_obt_parentes( v_cod_ente, 'SNP_MT_SUB_TIPO' );
      v_cod_servicio         := fug_obt_parentes( v_cod_ente, 'SNP_COD_SERVICIO' );
      v_dia_env_mensaje      := fug_obt_parentes( v_cod_ente, 'SNP_DIA_ENV_MENSAJE' );

      -- Si tuvo errores cancelar el proceso
      if pas_snp.fu_obt_cod_error <> 0 then
         raise pas_snp.ex_salir;
      end if;

      pas_snp.g_lugar := 'Verificando Par�metros del ente ' || v_cod_ente || ', ';
      if v_nro_cta_origen is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_CTA_ORIGEN', pas_snp.fu_obt_salto );
      else
         pag_cta.pr_obt_cuenta( v_nro_cta_origen );
         if pag_cta.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Validando Cta. origen, ' || pag_cta.fu_obt_msj_error, pas_snp.fu_obt_salto );
         else -- Se encontr� la Cuenta Origen, se verifica la moneda de la cuenta
            v_cod_mon_origen := pag_cta.g_ctas.cod_moneda;
            v_cod_oficina    := pag_cta.g_ctas.cod_oficina;
            if v_cod_mon_origen is null then
               pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'No se encuentra la moneda de la cuenta origen', pas_snp.fu_obt_salto );
            end if;
         end if;
      end if;
      if v_nro_cta_destino is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_CTA_DESTINO', pas_snp.fu_obt_salto );
      else
         pag_cta.pr_obt_cuenta( v_nro_cta_destino );
         if pag_cta.fu_obt_cod_error <> 0 then
            pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Validando Cta. destino, ' || pag_cta.fu_obt_msj_error, pas_snp.fu_obt_salto );
         end if;
      end if;
      if nvl( v_cob_ser_automatico, 'N' ) <> 'S' then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar el valor S al par�metro SNP_COB_SER_AUTOMATICO', pas_snp.fu_obt_salto );
      end if;
      if v_tra_debito is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_COD_TRA_DEBITO', pas_snp.fu_obt_salto );
      end if;
      if v_mai_alerta is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_EMA_ALERTA', pas_snp.fu_obt_salto );
      end if;
      if nvl( v_cod_msj_swift, '-99' ) not in ( 102, 103 ) then
        pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Valor para el tipo de MT debe ser � 102 � 103', pas_snp.fu_obt_salto );
      end if;
      if v_con_transferencia is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_MT_CONCEPTO', pas_snp.fu_obt_salto );
      end if;
      if v_per_pte_beneficiario is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_PER_PTE_BENEFICIARIO', pas_snp.fu_obt_salto );
      end if;
      if v_nro_cta_beneficiario is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_CTA_BENEFICIARIO', pas_snp.fu_obt_salto );
      end if;
      if v_cod_servicio is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_COD_SERVICIO', pas_snp.fu_obt_salto );
      end if;
      if v_tip_operacion is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_MT_TIPO', pas_snp.fu_obt_salto );
      end if;
      if v_sub_tip_operacion is null then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Debe asignar un valor al par�metro SNP_MT_SUB_TIPO', pas_snp.fu_obt_salto );
      end if;
      if not pas_snp.fu_val_par_mensajes( v_cod_msj_swift,
                                          v_tip_operacion,
                                          v_sub_tip_operacion
                                        )
      then
         pas_snp.pr_set_texto ( pas_snp.g_msj_error, 'Campo(s) Tip.Operaci�n y/o Sub Tip.Operaci�n no se encuentra(n) en GE_SNP_PAR_MENSAJES', pas_snp.fu_obt_salto );
      else
         begin
           select m.prioridad
             into v_prioridad
             from ge_snp_par_mensajes m
            where m.cod_msj_swift                  = v_cod_msj_swift
              and m.cod_tip_operacion              = v_tip_operacion
              and nvl(m.cod_sub_tip_operacion,'~') = nvl(v_sub_tip_operacion,'~');
         exception
           when others then
              -- Cualquier error coloca la prioridad por defecto
              v_prioridad := case when nvl( v_cod_msj_swift, 102 ) = 102 then 100 else 20 end;
         end;
      end if;

      begin
        select nvl( max( t.val_minimo ), 'SHA' )
          into rg_mensaje.tip_cargo
          from ba_cod_referencias t
         where t.dominio = 'TIP_CAR_SWIFT'
           and t.val_maximo = 'DEFAULT';
      exception
        when others then
          rg_mensaje.tip_cargo := 'SHA';
      end;

      if pas_snp.fu_obt_msj_error is not null then
         pas_snp.g_cod_error := 76;
         pas_snp.g_msj_error := g_lugar || pas_snp.g_msj_error;
         raise pas_snp.ex_salir;
      end if;

   EXCEPTION
     when pas_snp.ex_salir then
        raise pas_snp.ex_salir;
     when others then
         pas_snp.g_cod_error := 76;
         pas_snp.pr_set_texto ( pas_snp.g_msj_error,
                                g_lugar || 'Error al buscar los datos para el c�digo de servicio ' || p_cod_servicio || ': ' ||sqlerrm,
                                pas_snp.fu_obt_salto
                              );
         raise pas_snp.ex_salir;
   END lp_obt_dat_cob_servicio;

   PROCEDURE lp_obt_mto_cob_servicio ( p_cod_servicio     in     ge_cob_servicios.cod_servicio%type,
                                       p_cod_moneda       in     ge_movimientos.cod_moneda%type,
                                       p_tot_monto           out ge_movimientos.monto%type,
                                       p_cur_cob_servicio    out pas_snp.t_tab_cob_servicio
                                     )
   IS
   BEGIN
      pas_snp.g_lugar := 'Obteniendo el monto de recaudaci�n para el cobro de servicios ' || p_cod_servicio ||
                         ' en la moneda '|| p_cod_moneda || ', ';
      prs_snp_obt_tra_servicio( p_cod_servicio,
                                p_cod_moneda,
                                p_tot_monto,
                                p_cur_cob_servicio
                              );

     if nvl( p_tot_monto, 0 ) <= 0 then
        pas_snp.g_cod_error := 76;
        pas_snp.g_msj_error :=  pas_snp.g_lugar || 'No se encuentra recaudaci�n para el c�digo de servicio';
        raise pas_snp.ex_salir;
     end if;

   EXCEPTION
      when pas_snp.ex_salir then
        raise pas_snp.ex_salir;
      when others then
        pas_snp.g_cod_error := 76;
        pas_snp.pr_set_texto ( pas_snp.g_msj_error,
                               g_lugar || 'Error al buscar el monto de la recaudaci�n para el c�digo de servicio ' || p_cod_servicio || ' en la moneda '|| p_cod_moneda || ': ' || sqlerrm,
                               pas_snp.fu_obt_salto
                             );
        raise pas_snp.ex_salir;
   END lp_obt_mto_cob_servicio;

   PROCEDURE lp_env_mai_alerta
   IS
     v_dir_cor_alerta ge_par_dinamicos.val_parametro%type;
   BEGIN
     if pas_snp.fu_obt_cod_error <> 0 then
        v_dir_cor_alerta := nvl( v_mai_alerta, pas_snp.g_err_dir_correo );
        if v_dir_cor_alerta is not null then
           it_mail.mail( fug_obt_dir_correo,
                         v_dir_correo,
                         'Error en la Remisi�n de Cobros Realizados '||
                         case
                            when v_abr_servicio is null then
                              'para el c�digo '||v_cod_ser_parametro
                            else
                              'a '||v_abr_servicio
                         end,
                         'Se han encontrado errores durante el proceso. A continuaci�n el detalle de los mismos:' || chr(10) || chr(10) ||
                         pas_snp.fu_obt_msj_error || chr(10) ||
                         chr(10) || chr(10) ||
                         'Atentamente.'
                       );
        end if;
     else -- No tiene ERRORES
        v_dir_correo := nvl( v_mai_alerta, pas_snp.g_gru_dir_correo );
        if v_mai_ente is not null then
           v_dir_correo := v_dir_correo || ',' || v_mai_ente;
        end if;

        pas_snp.pr_set_texto( v_mensaje,
                              'Cuenta Origen    : '||v_nro_cta_origen ||chr(10)||
                              'Cuenta Destino   : '||v_nro_cta_destino ||chr(10)||
                              'Fecha de Ingreso : '||to_char(rg_mensaje.fec_ingreso,'DD/MM/YYYY') ||chr(10)||
                              'Fecha de Remisi�n: '||to_char(rg_mensaje.fec_valor,'DD/MM/YYYY') ||chr(10)||
                              'Nro. Operaci�n   : '||to_char(rg_mensaje.nro_referencia) ||chr(10)||
                              'Total a Remitir  : '||trim(to_char(v_tot_monto,'999,999,999,999,999.99')) ||chr(10)||chr(10)||
                              'Atentamente.', ''
                            );

        if v_dir_correo is not null and
              v_asunto is not null and
              v_mensaje is not null
        then
           it_mail.mail( fug_obt_dir_correo,
                         v_dir_correo,
                         v_asunto,
                         v_mensaje
                       );
        end if;
     end if;
   EXCEPTION
    when others then
      NULL;
   END lp_env_mai_alerta;

   PROCEDURE lp_gen_msj_transferencia IS
   BEGIN
     -- Verifico los datos necesarios para la generaci�n de la transferencia para el Cobro del Servicio
     pas_snp.g_lugar := 'Intentando generar la mensajer�a para el Cobro de Servicio ' || v_cod_servicio || ', ';
     -- Verifica si se puede realizar el movimiento de d�bito a la Cta. de Origen.
     pag_cta.pr_ver_operacion( v_nro_cta_origen,             -- Nro.Cta.
                               pas_snp.fu_obt_cod_tra_padre, -- Trx. Padre
                               pas_snp.fu_obt_cod_mod_padre, -- Mod. Padre
                               pas_snp.fu_obt_cod_mad_padre, -- Mad. Padre
                               v_tip_mov_debito,             -- Tip.Mov.
                               v_cod_mon_origen,             -- Cod.Mon.
                               v_tot_monto,                  -- Monto
                               v_cod_oficina,                -- Ofic.Orig.
                               pag_cta.g_ctas.cod_modulo,    -- Mod.Hijo
                               pag_cta.g_ctas.cod_modalidad, -- Mad.Hijo
                               v_est_cuenta,                 -- Estado Cta.
                               v_sal_disponible,             -- Sal.Dispon.
                               v_procesa,                    -- Procesa
                               v_tra_debito                  -- Trx. Hija
                             );

     if pag_cta.fu_obt_cod_error <> 0 then
        --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
        pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
        pas_snp.g_msj_error := pas_snp.g_lugar || pag_cta.fu_obt_msj_error;
        raise pas_snp.ex_salir;
     end if;

     pas_snp.g_lugar := 'Obteniendo Datos para la mensajer�a, ';
     rg_mensaje.cod_modulo            := pas_snp.fu_obt_cod_mod_padre;
     rg_mensaje.cod_modalidad         := pas_snp.fu_obt_cod_mad_padre;
     rg_mensaje.cod_oficina           := v_cod_oficina;
     rg_mensaje.fec_ingreso           := pas_snp.g_fec_actual;
     rg_mensaje.cod_moneda            := v_cod_mon_origen;
     rg_mensaje.cod_tip_operacion     := v_tip_operacion;
     rg_mensaje.cod_sub_tip_operacion := v_sub_tip_operacion;
     rg_mensaje.tip_mensaje           := 'CRED';
     rg_mensaje.cod_msj_swift         := v_cod_msj_swift;
     rg_mensaje.ind_valor             := case when v_cod_msj_swift = 102 then 'N' else 'S' end;
     rg_mensaje.prioridad             := v_prioridad;
     rg_mensaje.monto                 := v_tot_monto;
     rg_mensaje.situacion             := 'P';
     rg_mensaje.estado                := 'A';
     rg_mensaje.origen                := 'I';
     rg_mensaje.plataforma            := 'X';
     rg_mensaje.indemnizado           := 'N';
     rg_mensaje.cod_servicio          := v_cod_servicio;

     pas_snp.g_lugar := 'Obteniendo Datos del Cliente Beneficiario, ';
     rg_mensaje.cod_per_beneficiario     := v_cod_per_servicio;
     rg_mensaje.nom_beneficiario         := fue_obt_nom_persona( rg_mensaje.cod_per_beneficiario );
     rg_mensaje.dir_beneficiario         := pas_snp.fu_obt_dir_principal( rg_mensaje.cod_per_beneficiario );
     rg_mensaje.cod_tip_doc_beneficiario := fue_obt_doc_principal( rg_mensaje.cod_per_beneficiario );
     rg_mensaje.nro_doc_beneficiario     := substr( fue_obt_nro_doc_persona( rg_mensaje.cod_per_beneficiario ), 1, 20 );
     rg_mensaje.nro_cta_beneficiario     := v_nro_cta_beneficiario;

     if pas_snp.fu_obt_msj_error is not null then
        pas_snp.g_cod_error := 76;
        pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
        raise pas_snp.ex_salir;
     end if;

     pas_snp.g_lugar := 'Obteniendo Datos del Cliente Solicitante, ';
     rg_mensaje.cod_per_solicitante     := fug_obt_cli_principal( v_nro_cta_origen );
     rg_mensaje.nom_solicitante         := fue_obt_nom_persona( rg_mensaje.cod_per_solicitante );
     rg_mensaje.dir_solicitante         := fue_obt_dir_principa( rg_mensaje.cod_per_solicitante );
     rg_mensaje.cod_tip_doc_solicitante := fue_obt_doc_principal( rg_mensaje.cod_per_solicitante ) ;
     rg_mensaje.nro_doc_solicitante     := substr(fue_obt_nro_doc_persona( rg_mensaje.cod_per_solicitante ),1,20);
     rg_mensaje.nro_cta_solicitante     := v_nro_cta_origen;
     rg_mensaje.cod_swi_pte_solicitante := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);

     if pas_snp.fu_obt_msj_error is not null then
        pas_snp.g_cod_error := 76;
        pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
        raise pas_snp.ex_salir;
     end if;

     if v_cod_mon_origen is not null then
        pas_snp.g_lugar := 'Obteniendo Cta Participante Solicitante, ';
        rg_mensaje.nro_cta_pte_solicitante := pas_snp.fu_obt_cta_ban_participante( pas_snp.fu_obt_cod_swi_participante( fug_obt_per_entidad ),
                                                                                   v_cod_mon_origen
                                                                                 );
        if pas_snp.fu_obt_msj_error is not null then
           pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
           raise pas_snp.ex_salir;
        end if;

        pas_snp.g_lugar := 'Obteniendo el BIC del Participante Beneficiario, ';
        rg_mensaje.cod_swi_pte_beneficiario := pas_snp.fu_obt_cod_swi_participante( v_per_pte_beneficiario );
        if pas_snp.fu_obt_msj_error is not null then
           pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
           raise pas_snp.ex_salir;
        end if;

        pas_snp.g_lugar := 'Obteniendo Cta del Participante Beneficiario, ';
        rg_mensaje.nro_cta_pte_beneficiario := pas_snp.fu_obt_cta_ban_participante( rg_mensaje.cod_swi_pte_beneficiario,
                                                                                    v_cod_mon_origen
                                                                                  );
        if pas_snp.fu_obt_msj_error is not null then
           pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
           raise pas_snp.ex_salir;
        end if;
     end if;
     --

     if nvl( v_dia_env_mensaje, 0 ) <= 0 then
        -- Se toma como si fuese a enviarse en el d�a, sino puede obtendr� fecha valor h�bil siguiente
        rg_mensaje.fec_valor := pas_snp.fu_obt_fec_transferencia( v_cod_msj_swift,
                                                                  v_tip_operacion,
                                                                  v_sub_tip_operacion,
                                                                  rg_mensaje.fec_ingreso
                                                                );
     else
        rg_mensaje.fec_valor := pag_cal.fu_obt_fec_fin_ret( pas_snp.g_fec_actual,
                                                            v_cod_oficina,
                                                            v_dia_env_mensaje
                                                          );
     end if;
     --
     rg_mensaje.nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
     rg_mensaje.concepto := pas_snp.fu_obt_mov_concepto('M', 'I', rg_mensaje.nro_referencia);
     --
     pas_snp.g_lugar :=  'Insertando Mensajer�a ' || rg_mensaje.cod_msj_swift || ', ';
     pas_snp.pr_ins_transferencias ( rg_mensaje );
     if pas_snp.fu_obt_cod_error <> 0 then
        pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
        raise pas_snp.ex_salir;
     end if;

     -- Luego del registro de la mensajer�a se vuelve a recuperar los datos de la misma
     pas_snp.g_lugar :=  'Obteniendo datos de la Mensajer�a ' || rg_mensaje.cod_msj_swift || ', ';
     pas_snp.pr_obt_mensaje( rg_mensaje.nro_referencia, 'N' );
     if pas_snp.fu_obt_cod_error <> 0 then
        pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
        raise pas_snp.ex_salir;
     else
        rg_mensaje:= pas_snp.fu_obt_reg_transferencias;
        pas_snp.pr_ini_registros;
     end if;

     if rg_mensaje.cod_msj_swift = 103 then
        pas_snp.g_lugar := 'Generando la mensajer�a ' || rg_mensaje.cod_msj_swift || ', ';
        rg_mensaje.msj_swift := pas_snp.fu_obt_msj_mt103( rg_mensaje.nro_referencia, 'N' );

        if pas_snp.fu_obt_cod_error <> 0 then
           pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
           raise pas_snp.ex_salir;
        end if;

        /*Actualizar datos de la transferencia*/
        pas_snp.g_lugar := 'Actualizando la mensajer�a Nro. Referencia: ' || rg_mensaje.nro_referencia || ', ';
        pas_snp.pr_set_transferencias( rg_mensaje );
        if pas_snp.fu_obt_cod_error <> 0 then
           pas_snp.g_msj_error := pas_snp.g_lugar || pas_snp.g_msj_error;
           raise pas_snp.ex_salir;
        end if;
     end if;

     pas_snp.g_lugar := 'Intentando actualizar el detalle de la recaudaci�n con el servicio ' || rg_mensaje.cod_servicio || ', ';
     if rg_mensaje.cod_servicio is not null then
        begin
           prs_snp_act_tra_servicio( v_tab_cob_servicio,
                                     rg_mensaje.nro_referencia
                                   );
        exception
           when others then
              pas_snp.g_cod_error := 76;
              pas_snp.g_msj_error := pas_snp.g_lugar || sqlerrm;
              raise pas_snp.ex_salir;
        end;

        if pas_snp.fu_obt_cod_error <> 0 then
           raise pas_snp.ex_salir;
        end if;

        if g_msj.fec_valor > pas_snp.g_fec_actual or
        ( g_msj.fec_valor = pas_snp.g_fec_actual and
          pas_snp.fu_obt_fec_ult_operacion < pas_snp.g_fec_actual
        )
        then -- La mensajer�a est� registrada con fecha futura o
           -- bien a�n no se habilit� la fecha actual para operar con BCP.
           pas_snp.pr_set_texto( v_asunto, 'Remisi�n a realizarse por Pagos de '||v_abr_servicio, '' );
           pas_snp.pr_set_texto( v_mensaje, 'A continuaci�n se detallan los datos de la Remisi�n a realizarse por Cobro de '||v_abr_servicio||': '||chr(10)||chr(10), ' ' );
        else -- Se env�a la mensajer�a al BCP, una vez que el socket responda se generar�n los movimientos*/
           if pas_snp.fu_obt_fec_ult_operacion = pas_snp.g_fec_actual then
              pas_snp.g_lugar := 'Intentando enviar la mensajer�a al SOCKET, ';
              pas_snp.pr_gen_arc_swift( rg_mensaje.nro_referencia, 'N', 'A' );
              if pas_snp.fu_obt_cod_error <> 0 then
                 raise pas_snp.ex_salir;
              end if;
              pas_snp.pr_set_texto( v_asunto, 'Remisi�n por Pagos de '||v_abr_servicio||' realizado', '' );
              pas_snp.pr_set_texto( v_mensaje, 'A continuaci�n se detallan los datos de la Remisi�n realizada por Cobro de '||v_abr_servicio||': '||chr(10)||chr(10), ' ' );
           end if;
        end if;

        if pas_snp.fu_obt_cod_error <> 0 then
           raise pas_snp.ex_salir;
        end if;
     else
       pas_snp.g_cod_error := 76;
       pas_snp.g_msj_error := pas_snp.g_lugar || 'No se ha encontrado el c�digo de servicio para relacionarlo con el detalle de la recaudaci�n';
       raise pas_snp.ex_salir;
     end if;
  EXCEPTION
     when pas_snp.ex_salir then
        raise pas_snp.ex_salir;
     when others then
        pas_snp.g_cod_error := 76;
        pas_snp.pr_set_texto ( pas_snp.g_msj_error, g_lugar || sqlerrm, pas_snp.fu_obt_salto );
        raise pas_snp.ex_salir;
  END lp_gen_msj_transferencia;

  PROCEDURE lp_rol_operacion
  IS
  BEGIN
      prg_rol_savepoint( 'COB_SER' );
      if pas_snp.fu_obt_cod_error = 0 then -- Tiene Errores
         pas_snp.g_cod_error := 76;
      end if;
      lp_env_mai_alerta;
  END lp_rol_operacion;

BEGIN
   -- Inicializa variables de error
   pas_snp.pr_ini_variables;
   --
   /*Inicializa la aplicacion*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   prg_cre_savepoint( 'COB_SER' );
   --
   v_cod_ser_parametro := nvl( p_cod_servicio, -88 );
   -- Obtiene los datos del servicio y del ente relacionado al servicio
   lp_obt_dat_cob_servicio( v_cod_ser_parametro );
   -- Se abre el cursor con el monto de la recaudaci�n, si no existen datos se recupera monto 0
   lp_obt_mto_cob_servicio( v_cod_servicio,
                            v_cod_mon_origen,
                            v_tot_monto,       -- OUT monto total de la recaudaci�n
                            v_tab_cob_servicio -- OUT collection
                          );
   -- Intenta generar mensajer�a a partir del monto de recaudaci�n recuperado
   lp_gen_msj_transferencia;
   --
   -- Si no tiene ERRORES env�a correo
   lp_env_mai_alerta;
   --
EXCEPTION
    when pas_snp.ex_salir then
      -- Se deshace toda la operaci�n
      lp_rol_operacion;
    when others then
      pas_snp.g_cod_error := 76;
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_GEN_TRA_SERVICIO: ' || pas_snp.g_lugar || sqlerrm;
      -- Se deshace toda la operaci�n
      lp_rol_operacion;
END pr_gen_tra_servicio;

FUNCTION fu_obt_salto return varchar2
IS
   /*
   || Obtiene el salto configurado en ITGF es <CR+LF>
   */
BEGIN
   return pas_snp.g_salto;
END fu_obt_salto;

FUNCTION fu_obt_sal_socket return varchar2
IS
   /*
   || Obtiene el salto configurado en el SOCKET es <*>
   */
BEGIN
   return pas_snp.g_sal_socket;
END fu_obt_sal_socket;

FUNCTION fu_obt_mascara return varchar2
IS
   /*
   || Formato de la m�scara para importes
   */
BEGIN
   return pas_snp.g_mascara;
END fu_obt_mascara;

FUNCTION fu_obt_cod_tra_padre return number
IS
   /*
   || Obtiene el c�digo de transacci�n padre para identificar movimientos de snp
   */
BEGIN
   return pas_snp.g_cod_tra_padre;
END fu_obt_cod_tra_padre;

FUNCTION fu_obt_cod_mod_padre return number
IS
   /*
   || Obtiene el c�digo de m�dulo padre para identificar movimientos de snp
   */
BEGIN
   return pas_snp.g_cod_mod_padre;
END fu_obt_cod_mod_padre;

FUNCTION fu_obt_cod_mad_padre return number
IS
   /*
   || Obtiene el c�digo de modalidad padre para identificar movimientos de snp
   */
BEGIN
   return pas_snp.g_cod_mad_padre;
END fu_obt_cod_mad_padre;

FUNCTION fu_obt_cod_tra_cargo return number
IS
   /*
   || Obtiene el c�digo de transacci�n hija para la generaci�n de movimientos de cobro de cargos - SNP
   */
BEGIN
   return pas_snp.g_cod_tra_cargo;
END fu_obt_cod_tra_cargo;

FUNCTION fu_obt_cod_tra_indemnizacion return number
IS
   /*
   || Obtiene el c�digo de transacci�n hija para identificar movimientos de indemnizacion de SNP
   */
BEGIN
   return pas_snp.g_cod_tra_indemnizacion;
END fu_obt_cod_tra_indemnizacion;

PROCEDURE pr_gen_mov_tar_conciliacion
(  p_hora            ge_movimientos.hora%type,
   p_nro_secuencia   ge_movimientos.nro_secuencia%type,
   p_cod_ent_debito  ge_entes.cod_ente%type,
   p_monto           ge_movimientos.monto%type,
   p_cod_moneda      ba_monedas.cod_moneda%type,
   p_tip_gru_servicio number
) IS

    r_gmovi               ge_movimientos%ROWTYPE;
    v_cot_mon_local       ge_movimientos.cotizacion%TYPE;
    v_con_debito          ge_movimientos.concepto%TYPE := 'Saldos BANCARD - BCO. PAIS';
    v_cod_ent_procesadora ge_par_entes.cod_ente%type;
    v_nro_secuencia       ge_movimientos.nro_secuencia%TYPE := p_nro_secuencia;
  BEGIN
    r_gmovi.mto_equ_local := 0;
    r_gmovi.monto         := abs(p_monto);

    g_lugar := 'Recuperando el C�digo de la Entidad en la Procesadora: ';
    Begin
      /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
      En la Procesadora Parametrizado.*/
      Select cod_ente
        into v_cod_ent_procesadora
        from ge_par_entes a
       where a.parametro = 'COD_ENT_FINANCIERA'
         and to_number(a.val_parametro) = to_number(p_cod_ent_debito);
    Exception
      When NO_DATA_FOUND then
        v_cod_ent_procesadora := NULL;
    End;

    /*se carga el codigo de transaccion segun el monto (si es negativo es debito y positivo credito*/
    IF p_monto < 0 THEN
      r_gmovi.cod_transaccion := 4712;
    ELSE
      r_gmovi.cod_transaccion := 4711;
    END IF;

    /*se define el tra padre segun la transaccion*/
    r_gmovi.cod_tra_padre := r_gmovi.cod_transaccion;

    /* condicion para mto_equ_local ,cdo es moneda extranjera por la cotizacion */
    r_gmovi.cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda);

    g_lugar := 'Realizando conversi�n de moneda: ';
    IF p_cod_moneda != pag_gen.fu_obt_mon_local THEN
      pas_snp.pr_con_mon_a_moneda(p_cod_moneda,
                                  pag_gen.fu_obt_mon_local,
                                  r_gmovi.monto,
                                  r_gmovi.mto_equ_local,
                                  r_gmovi.cotizacion,
                                  v_cot_mon_local);
    END IF;

    if pas_snp.fu_obt_cod_error <> 0 then
      raise ex_salir;
    end if;

    --Es entidad bancaria o Sponsor Bancard
    if p_tip_gru_servicio = 0 then
      --Se setea para ENTIDADES FINANCIERAS DEL PA�S
      r_gmovi.cod_modulo    := 4;
      r_gmovi.cod_modalidad := 42;
      g_lugar         := 'Recuperando n�mero de Cuenta y Moneda de la Entidad: ';
      /*se recupera el nro de cuenta y moneda de la Entidad*/
      BEGIN
        SELECT c.nro_cuenta
          INTO r_gmovi.nro_cuenta
          FROM cc_cta_bancarias c
         WHERE c.estado = 'N'
           AND c.cod_modulo = r_gmovi.cod_modulo
           AND c.cod_modalidad = r_gmovi.cod_modalidad --- Solo cuentas Entidades del Pais
           AND (c.cod_banco = p_cod_ent_debito --Banco
               OR cod_ente = v_cod_ent_procesadora) --Entidad Financiera
           AND c.cod_moneda = p_cod_moneda;
      EXCEPTION
        when no_data_found then
          pas_snp.g_cod_error := 84;
          pas_snp.g_msj_error := 'Al buscar Cuenta Bancaria ' || 'Banco : ' ||
                                 p_cod_ent_debito || ' - ' || 'Ente: ' ||
                                 v_cod_ent_procesadora;
        when too_many_rows then
          pas_snp.g_cod_error := 84;
          pas_snp.g_msj_error := 'Existe mas de una Cuenta Bancaria para la Entidad: ' ||
                                 p_cod_ent_debito;
        when others then
          pas_snp.g_cod_error := 84;
          pas_snp.g_msj_error := 'Error recuperando Cuenta Bancaria ' ||
                                 'Banco : ' || p_cod_ent_debito || ' - ' ||
                                 'Ente: ' || v_cod_ent_procesadora || ' ' ||
                                 sqlerrm;
      END;

      if pas_snp.fu_obt_cod_error <> 0 then
        raise ex_salir;
      end if;

      /*Recupera el tipo de Transaccion*/
      g_lugar         := 'Obteniendo el tipo de transacci�n: ';
      r_gmovi.tip_mov_rubro := pas_snp.fu_obt_tip_mov_transaccion(r_gmovi.cod_modulo,
                                                                  r_gmovi.cod_modalidad,
                                                                  r_gmovi.cod_transaccion);

      if pas_snp.fu_obt_cod_error <> 0 then
        raise ex_salir;
      end if;

      g_lugar := 'Obteniendo el rubro de la cuenta: ';
      /*Carga el Rubro*/
      pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(r_gmovi.nro_cuenta),
                               r_gmovi.tip_mov_rubro);

      if pag_cta.fu_obt_cod_error <> 0 then
        --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
        pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
        pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;
        raise ex_salir;
      end if;

      g_lugar := 'Generando los movimientos de modalidad 42: ';
      /*Genera movimientos*/
      pag_cta.pr_act_operacion(r_gmovi.nro_cuenta,
                               p_hora,
                               r_gmovi.tip_mov_rubro,
                               p_cod_moneda,
                               r_gmovi.monto,
                               r_gmovi.cod_tra_padre,
                               r_gmovi.cod_transaccion,
                               NULL,
                               r_gmovi.cotizacion,
                               fug_obt_ofi_usuario(USER),
                               r_gmovi.cod_modulo,
                               r_gmovi.cod_modalidad,
                               NULL,
                               NULL,
                               v_con_debito,
                               'S',
                               v_nro_secuencia,
                               g_fec_actual,
                               NULL,
                               NULL,
                               r_gmovi.mto_equ_local);

      if pag_cta.fu_obt_cod_error <> 0 then
         --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
         pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
         pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;
         raise ex_salir;
      end if;

    else
      --Se setea para Cuentas Gerencia
      r_gmovi.cod_modulo    := 4;
      r_gmovi.cod_modalidad := 43;

      /*Recupera el tipo de Transaccion*/
      g_lugar := 'Obteniendo el tipo de transacci�n: ';
      if pas_snp.fu_obt_tip_mov_transaccion(r_gmovi.cod_modulo,
                                            r_gmovi.cod_modalidad,
                                            r_gmovi.cod_transaccion) = 'D' then
        r_gmovi.tip_mov_rubro := 'C';
      else
        r_gmovi.tip_mov_rubro := 'D';
      end if;

      if pas_snp.fu_obt_cod_error <> 0 then
        raise ex_salir;
      end if;

      g_lugar := 'Generando los movimientos de modalidad 43: ';
      /*Genera movimientos*/
      r_gmovi.cod_usuario         := USER;
      r_gmovi.hora                := p_hora;
      r_gmovi.fecha               := g_fec_actual;
      v_nro_secuencia             := p_nro_secuencia + 1;
      r_gmovi.nro_secuencia       := v_nro_secuencia;
      r_gmovi.cod_oficina         := fug_obt_ofi_usuario(USER);
      r_gmovi.cod_moneda          := p_cod_moneda;
      r_gmovi.fec_valor           := g_fec_actual;
      r_gmovi.cod_mod_padre       := 4;
      r_gmovi.cod_mad_padre       := 43;
      r_gmovi.nro_documento       := NULL;
      r_gmovi.cod_ofi_origen      := fug_obt_ofi_usuario(USER);
      r_gmovi.emi_aviso           := 'S';
      r_gmovi.concepto            := v_con_debito;
      r_gmovi.estado              := 'N';
      r_gmovi.reversado           := 'N';

      pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
  EXCEPTION
    when pas_snp.ex_salir then
      raise_application_error(-20001, pas_snp.fu_obt_msj_error);
    when others then
      raise_application_error(-20002,
                              'Error en PR_GEN_MOV_TAR_CONCILIACION ' ||
                              g_lugar || sqlerrm);

end pr_gen_mov_tar_conciliacion;

FUNCTION fu_obt_cod_tra_impuesto return number
IS
   /*
   || Obtiene el c�digo de transacci�n hija para identificar movimientos de IVA de SNP
   */
BEGIN
   return pas_snp.g_cod_tra_impuesto;
END fu_obt_cod_tra_impuesto;

/* Controla las transferencias duplicadas SNP e inserta en la tabla de logs*/
PROCEDURE pr_ins_sb_snp_log_envios (p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                    p_accion         in varchar2,
                                    p_situacion      in ge_snp_transferencias.situacion%type default null,
                                    p_error          in ge_snp_transferencias.error%type default null)
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   v_secuencia number := 0;
BEGIN
   if p_accion = 'I' then
      if p_situacion != 'N' then --hallar la �ltima secuencia del estado
         begin
            select secuencia + 1
              into v_secuencia
              from sb_snp_log_envios
             where nro_referencia = p_nro_referencia
               and situacion = p_situacion;
         exception
            when others then
               v_secuencia := 0;
         end;
      end if;

      insert into sb_snp_log_envios
         (nro_referencia, situacion, secuencia, error)
      values
         (p_nro_referencia, p_situacion, v_secuencia, p_error);
      commit;

   elsif p_accion = 'A' then
      select nvl(max(secuencia), 0) + 1
        into v_secuencia
        from sb_snp_log_envios
       where nro_referencia = p_nro_referencia
         and situacion = 'E';

      update sb_snp_log_envios
         set situacion = p_situacion,
             secuencia = v_secuencia,
             error = p_error
       where nro_referencia = p_nro_referencia
         and situacion = 'N';
      commit;
  end if;
EXCEPTION
    when DUP_VAL_ON_INDEX then
       select NVL(MAX(secuencia), 0) + 1
         into v_secuencia
         from sb_snp_log_envios
         where nro_referencia = p_nro_referencia
           and situacion = 'E';

       insert into sb_snp_log_envios
          (nro_referencia, situacion, secuencia, error)
       values
          (p_nro_referencia, 'E', v_secuencia, 'Transferencia en estado de env�o al Socket');
       commit;

       raise_application_error(-20003, 'Transferencia en estado de env�o al Socket');
END pr_ins_sb_snp_log_envios;

FUNCTION fu_obt_nro_ref_relacionada( p_nro_referencia in ge_snp_mensajes.nro_referencia%type )
   return number
 /*
 || Obbtiene el Nro. de refencia relacionada para los casos en que la referencia
 || corresponde a un MTn95/STAT enviado.
 */
IS
   v_nro_referencia  ge_snp_transferencias.nro_referencia%type;
BEGIN

   BEGIN
      v_nro_referencia := to_number(p_nro_referencia);
      select nro_referencia
        into v_nro_referencia
        from ge_snp_transferencias
       where nro_referencia = v_nro_referencia;
   EXCEPTION
      when others then
         select t.nro_referencia
           into v_nro_referencia
           from ge_snp_transferencias t
          where exists ( select 0
                           from ge_snp_mensajes m
                          where m.nro_ref_externa = to_char( t.nro_referencia )
                            and m.nro_referencia  = p_nro_referencia
                            and m.fec_recepcion is null
                            and m.cod_msj_swift = substr(t.cod_msj_swift, 0, 1)||'95' );
   END;

   return v_nro_referencia;

EXCEPTION
    when others then
        return null;
END fu_obt_nro_ref_relacionada;

FUNCTION fu_obt_bic_sistema return varchar2 is
   /*
   || Halla el BIC del Sistema X-ADAPTER
   */
   v_valor ba_cod_referencias.abreviatura%type := fue_obt_des_refcodes('SNP_BIC_SISTEMA', fug_es_produccion);
begin
   if upper(v_valor) like 'REF%NO%REG%SIS%' then
      raise_application_error(-20801, 'BIC del Sistema no est� parametrizado.');
   end if;
   return v_valor;
end fu_obt_bic_sistema;

PROCEDURE pr_obt_msj_MT985( p_cod_tip_mensaje  in sb_snp_tip_mensajes.cod_mensaje%type,
                            p_nro_cta_bancaria in ge_snp_cta_bancos.nro_cta_bancaria%type,
                            p_cod_persona      in ba_personas.cod_persona%type
                          )
is
  v_nro_referencia          ge_snp_mensajes.nro_referencia%type := fu_obt_sig_nro_referencia;
  v_cod_swi_pte_solicitante ge_snp_transferencias.cod_swi_pte_solicitante%type := fu_obt_cod_swi_participante(p_cod_persona);
  v_mensaje                 ge_snp_mensajes.msj_swift%type;
begin
   --
   pr_ini_registros;
   -- Cabecera
   pas_snp.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
   pao_pmt.pr_ins_sb_snp_mensajes_tmp( p_cod_tip_mensaje,
                                       'CAB',
                                       '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                       '{2:I985'||rpad(fu_obt_bic_sistema,12,'X')||'N}'||
                                       '{3:{113'||':'||lpad('30',4,'0')||'}}{4:'
                                     );
   -- Detalle
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '20', v_nro_referencia);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '57A', fu_obt_bic_sistema);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '59', '/'||p_nro_cta_bancaria);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '59', v_cod_swi_pte_solicitante);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '75', substr(p_cod_tip_mensaje, instr(p_cod_tip_mensaje, '/')+1, 4));
   if substr(p_cod_tip_mensaje, instr(p_cod_tip_mensaje, '/') + 1, 4) in ('TTLS', 'PCLT') then
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '75', to_char(pas_snp.g_fec_actual,'RRMMDD')||'/'||'FIRST');
   end if;
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');
   begin
      --
      pas_snp.g_lugar := 'Creando la mensajer�a, ';
      pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);
      --
      pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
      insert into ge_snp_mensajes( nro_referencia,
                                   nro_ref_externa,
                                   cod_msj_swift,
                                   fec_valor,
                                   msj_swift,
                                   cod_moneda,
                                   monto,
                                   situacion,
                                   error,
                                   msj_swi_original
                                 )
                           values( v_nro_referencia,
                                   null,
                                   985,
                                   pas_snp.g_fec_actual,
                                   v_mensaje,
                                   null,
                                   null,
                                   'V',
                                   null,
                                   v_mensaje
                                 );
      --
      if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
              -- TRFS-533-Inserta mensaje para que el OWL/ETL procese

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
                                      pas_snp.g_cod_error := 49;
                                      pas_snp.g_msj_error := SQLERRM;
                                      raise;

                          end;
      else
            pas_snp.g_lugar := 'Enviando mensaje swift al socket, ';
            pr_gen_arc_swi_lote(v_mensaje);
      end if;

   exception
      when others then
         raise;
   end;
exception
   when others then
      pas_snp.g_cod_error := 89;
      pas_snp.g_msj_error := 'Error al Generar MT: '|| pas_snp.g_lugar ||' '|| sqlerrm;
end pr_obt_msj_mt985;

/*Genera MT920*/
PROCEDURE pr_obt_msj_MT920(p_cod_tip_mensaje    in sb_snp_tip_mensajes.cod_mensaje%type,
                           p_nro_cta_bancaria   in ge_snp_cta_bancos.nro_cta_bancaria%type,
                           p_tip_rep_solicitado in number default null,
                           p_ind_debito         in varchar2 default null,
                           p_ind_credito        in varchar2 default null,
                           p_mto_debito         in ge_snp_transferencias.monto%type default 0,
                           p_mto_credito        in ge_snp_transferencias.monto%type default 0,
                           p_cod_moneda         in ge_snp_transferencias.cod_moneda%type
                          )
is
   v_nro_referencia ge_snp_mensajes.nro_referencia%type  := fu_obt_sig_nro_referencia;
   v_mensaje        ge_snp_mensajes.msj_swift%type;
begin
   pr_ini_registros;

   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
     pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --
   pas_snp.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje,
                                      'CAB',
                                      '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                      '{2:I920'||rpad(fu_obt_bic_sistema,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
   -- Detalle
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '20', v_nro_referencia);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '12', p_tip_rep_solicitado);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '25', p_nro_cta_bancaria);
   if p_tip_rep_solicitado = 942 then
      if p_mto_debito >= 0 and p_mto_credito = 0 then
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '34F', substr(p_nro_cta_bancaria, -3, 3)||trim(to_char(p_mto_debito, pas_snp.fu_obt_mascara || rpad('9', nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => p_cod_moneda), 2), '9'))));
      elsif p_mto_debito > 0 and p_mto_credito > 0 then
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '34F', substr(p_nro_cta_bancaria, -3, 3)||p_ind_debito||trim(to_char(p_mto_debito, pas_snp.fu_obt_mascara || rpad('9', nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => p_cod_moneda), 2), '9'))));
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '34F', ':34F:'||substr(p_nro_cta_bancaria, -3, 3)||p_ind_credito||trim(to_char(p_mto_credito, pas_snp.fu_obt_mascara || rpad('9', nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => p_cod_moneda), 2), '9'))));
      else
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '34F', substr(p_nro_cta_bancaria, -3, 3)||p_ind_debito||trim(to_char(p_mto_debito, pas_snp.fu_obt_mascara || rpad('9', nvl(fug_obt_pardinamico(p_parametro  => 'VAL_RED_MON_EXTRANJERA', p_cod_moneda => p_cod_moneda), 2), '9'))));
      end if;
   end if;
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');
   begin
      pas_snp.g_lugar := 'Creando la mensajer�a, ';
      pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);
      pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
      insert into ge_snp_mensajes( nro_referencia,
                                   nro_ref_externa,
                                   cod_msj_swift,
                                   fec_valor,
                                   msj_swift,
                                   cod_moneda,
                                   monto,
                                   situacion,
                                   error,
                                   msj_swi_original
                                 )
                           values( v_nro_referencia,
                                   null,
                                   920,
                                   pas_snp.g_fec_actual,
                                   v_mensaje,
                                   null,
                                   null,
                                   'V',
                                   null,
                                   v_mensaje
                                 );
      --
          if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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

     else
        pas_snp.g_lugar := 'Enviando mensaje swift al socket, ';
        pr_gen_arc_swi_lote(v_mensaje);
     end if;
      --

   exception
     when others then
        raise;
   end;
exception
   when others then
      pas_snp.g_cod_error := 90;
      pas_snp.g_msj_error := 'Error al Generar MT: '|| pas_snp.g_lugar ||' '|| sqlerrm;
end pr_obt_msj_mt920;

/*Genera MT202 automatico*/
--SPI
procedure pr_gen_MT202_automatico(p_monto           in sb_snp_lim_depo.monto%type,
                                  p_cta_pte_solicitante in ge_snp_transferencias.nro_cta_pte_solicitante%type) is
  r_gtran             pas_snp.rg_msj;
  v_cod_mod_padre     ge_transacciones.cod_modulo%type := 4;
  v_cod_mad_padre     ge_modalidades.cod_modalidad%type := 455;
  v_tip_transf        ge_snp_transferencias.cod_msj_swift%type := 202;
  v_cod_tip_ope       ge_snp_transferencias.cod_tip_operacion%type := '029';
  v_cod_sub_tip_ope   ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_fec_operacion     date := trunc(sysdate);
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(9);
  v_hora              ge_movimientos.hora%type := fug_obt_mov_hora;
  v_participante      gv_snp_participantes.participante%type;
  v_cod_swif          gv_snp_participantes.cod_swift%type;
  v_cod_persona       gv_snp_participantes.cod_persona%type;
  v_direccion         ba_direcciones.direccion%type;
  v_cta_beneficiario  cc_cta_bancarias.nro_cta_bancaria%type;
  v_cta_solicitante   cc_cta_bancarias.nro_cta_bancaria%type;
  v_prioridad         ge_snp_par_mensajes.prioridad%type;
  v_origen            ge_snp_transferencias.origen%type default 'I'; --I = ITGF
  v_plataforma        ge_snp_transferencias.plataforma%type default 'X'; -- X = Xadapter
  v_cod_moneda        ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
  v_nro_cta_pte_sol   cc_cta_bancarias.nro_cuenta%type;
  v_cod_tra_padre     ge_transacciones.cod_transaccion%type := null ;
  v_cod_ofi_ente      ge_cta_clientes.cod_oficina%type;
  v_cod_mod_ente      ge_cta_clientes.cod_modulo%type;
  v_cod_mad_ente      ge_cta_clientes.cod_modalidad%type;
  v_nro_secuencia     ge_movimientos.nro_secuencia%type := 0;
  v_estado            ge_movimientos.estado%type := 'N';
  v_monto             ge_snp_transferencias.monto%type;
begin
  pr_ini_registros;

  --validamos los montos segun lo recibido como parametro--
  if p_monto = 0 then
     pas_dep.pr_obt_dat_fondeo('PYG', v_monto);
  else
    v_monto := p_monto;
  end if;

  --validamos el subTipo de la operacion que cargara segun la ctaPteSolicitante
  --si el solicitante es la cta de reserva se fondeara la cta de liq.
  if p_cta_pte_solicitante = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then --COMASPI1PYG
    v_cod_sub_tip_ope    := '002';
    v_cta_solicitante    := p_cta_pte_solicitante;--fug_obt_pardinamico('TRANSF_CTA_RES_LBTR');
    v_cta_beneficiario   := fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ');
  else
    v_cod_sub_tip_ope  := '001';
    v_cta_solicitante  := p_cta_pte_solicitante;--fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ'); --COMA1001PYG
    v_cta_beneficiario := fug_obt_pardinamico('TRANSF_CTA_RES_LBTR');
  end if;

  --buscamos los datos del la cta solicitante y beneficiario
  begin
    select s.participante,
           s.cod_swift,
           s.cod_persona,
           fue_obt_dir_principa(s.cod_persona)
      into v_participante, v_cod_swif, v_cod_persona, v_direccion
      from gv_snp_participantes s
     where cod_persona = fug_obt_per_entidad;
  end;

  --obtenemos la prioridad
    v_prioridad := fus_snp_obt_prioridad(v_tip_transf, v_cod_tip_ope, v_cod_sub_tip_ope);

  --obtenemos el nro de cta de la cta_bancaria del PTE.SOLICITANTE--
  if p_cta_pte_solicitante = fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ') then
     v_nro_cta_pte_sol := fug_obt_pardinamico('CTA_LBTR_LIQ');
  elsif p_cta_pte_solicitante = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
      v_nro_cta_pte_sol := fug_obt_pardinamico('CTA_SPI_RESERVA');
  end if;
  /*  begin
      SELECT c.nro_cuenta
        INTO v_nro_cta_pte_sol
        FROM cc_cta_bancarias c
       WHERE c.cod_modalidad = v_cod_mad_padre
         AND c.nro_cta_bancaria = v_cta_solicitante;
    end;*/
  --insertamos el registro MT202 en ge_snp_transferencia
  pas_snp.g_lugar := 'Insertando registro en ge_snp_transferencias';
  begin
    r_gtran.nro_referencia           := pas_snp.fu_obt_sig_nro_referencia;
    r_gtran.nro_lote                 := null;
    r_gtran.nro_sec_lote             := null;
    r_gtran.cod_modulo               := v_cod_mod_padre;
    r_gtran.cod_modalidad            := v_cod_mad_padre;
    r_gtran.cod_oficina              := fug_obt_ofi_matriz;
    r_gtran.cod_msj_swift            := v_tip_transf;
    r_gtran.cod_tip_operacion        := v_cod_tip_ope;
    r_gtran.cod_sub_tip_operacion    := v_cod_sub_tip_ope;
    r_gtran.fec_valor                := v_fec_operacion;
    r_gtran.fec_ingreso              := v_fec_actual;
    r_gtran.fec_recepcion            := null;
    r_gtran.fecha                    := v_fec_actual;
    r_gtran.hora                     := v_hora;
    r_gtran.situacion                := 'P';
    r_gtran.estado                   := 'A';
    r_gtran.cod_usuario              := user;
    r_gtran.cod_moneda               := v_cod_moneda;
    r_gtran.monto                    := v_monto;
    --solicitante
    r_gtran.cod_per_solicitante      := v_cod_persona;
    r_gtran.nom_solicitante          := v_participante;
    r_gtran.dir_solicitante          := v_direccion;
    r_gtran.cod_swi_pte_solicitante  := v_cod_swif;
    r_gtran.nro_cta_pte_solicitante  := v_cta_solicitante;
    --beneficiario
    r_gtran.cod_per_beneficiario     := v_cod_persona;
    r_gtran.nom_beneficiario         := v_participante;
    r_gtran.dir_beneficiario         := v_direccion;
    r_gtran.cod_swi_pte_beneficiario := v_cod_swif;
    r_gtran.nro_cta_pte_beneficiario := v_cta_beneficiario;
    --
    r_gtran.concepto                 := 'Trx. via BCP Nro Re'||r_gtran.nro_referencia;
    r_gtran.observacion              := '/BNF/SPI';
    r_gtran.ind_valor                := 'S';
    r_gtran.prioridad                := v_prioridad;
    r_gtran.nro_operacion            := r_gtran.nro_referencia;
    r_gtran.origen                   := v_origen;
    r_gtran.plataforma               := v_plataforma;
    r_gtran.indemnizado              := 'N';
    r_gtran.usu_insercion            := user;
    r_gtran.usu_modificacion         := user;
    pas_snp.pr_ins_transferencias(r_gtran);
   exception
     when others then
        pas_snp.g_cod_error := 100;
        pas_snp.g_msj_error := 'Error al Generar MT: '|| pas_snp.g_lugar||'-'||pas_snp.g_msj_error ||' '|| sqlerrm;
    end;

    --validamos que se haya insertado bien el registro para generar la estructura swift
    if pas_snp.g_cod_error != 00 then
       pas_snp.g_cod_error := 101;
       pas_snp.g_msj_error := 'Error al Generar MT202 de Fondeo Automatico: '|| pas_snp.g_lugar||'-'||pas_snp.g_msj_error ||' '|| sqlerrm;
    else
       if r_gtran.cod_msj_swift = 202 then
          pas_snp.g_lugar := 'Genera el la estructura swift del registro';
          r_gtran.msj_swift := pas_snp.fu_obt_msj_mt202(r_gtran.nro_referencia,'N');
       end if;
       --se actualiza el campo msj_swift de la tabla ge_snp_transferncia si no hubo errores
       if pas_snp.g_cod_error != 00 then
          pas_snp.g_cod_error := 102;
          pas_snp.g_msj_error := 'Error: '|| pas_snp.g_lugar||'-'||pas_snp.g_msj_error ||' '|| sqlerrm;
       else
        --actualiza el set de datos--
          pas_snp.g_lugar := 'Actualiza el set de datos';
          pas_snp.pr_set_transferencias(r_gtran);
       end if;
        --se inserta el registros en datos adicionales--
        pas_snp.g_lugar := 'inserta el registro en la tabla ba_tab_dat_adicionales';
        begin
          insert into ba_tab_dat_adicionales
            (tab_relacion, referencia, parametro, val_parametro)
          values
            ('GE_SNP_TRANSFERENCIAS',
             r_gtran.nro_referencia,
             'SIB_TRA_MOTIVO',
             1);
        end;
    end if;

    --se genera el movimiento por el debito de la cta del participante solicitante--
    --obtiene datos de la cuenta
    pag_cta.PR_OBT_CUENTA(v_nro_cta_pte_sol);
    if pag_cta.G_COD_ERROR = 0 then
      v_cod_ofi_ente := pag_cta.G_CTAS.cod_oficina;
      v_cod_mod_ente := pag_cta.G_CTAS.cod_modulo;
      v_cod_mad_ente := pag_cta.G_CTAS.cod_modalidad;
    end if;

    --asigna la Transaccion Padre si es SNP
    if v_cod_mod_ente = 4 then
      if pas_snp.fu_ver_cta_interbancaria(v_nro_cta_pte_sol) then
         v_cod_tra_padre := 303;
    --Setea las variables de COD_RUBRO, TIP_MOV_RUBRO
         pag_cta.pr_set_nro_documento2(202||v_cod_tip_ope||v_cod_sub_tip_ope);
      end if;
      pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_nro_cta_pte_sol), 'C');
    end if ;

   --Generacion del movimiento--
   --se valida que todo este correcto para el movimiento--
   if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
     pas_snp.g_cod_error := 103;
     pas_snp.g_msj_error := 'Error para generar el movimiento: '|| pas_snp.g_lugar||'-'||pas_snp.g_msj_error ||' '|| sqlerrm;
   else
     begin
   --se utiliza funci�n para evaluar el estado a imputar en las operaciones
       v_estado := fug_obt_est_mov_confirmado(p_monto,
                                              v_cod_moneda,
                                              v_cod_mod_ente,
                                              v_cod_mad_ente,
                                              v_cod_tra_padre,
                                              'X',
                                              v_nro_cta_pte_sol,
                                              v_cod_persona
                                             );

   --llama al pag_cta para generar los registros del movimiento por el debito
        pas_snp.g_lugar := 'Inserta registro del movimiento en la tabla ge_movimiento';
       pag_cta.pr_set_referencia(v_estado);
       pag_cta.pr_act_operacion(v_nro_cta_pte_sol,
                                v_hora, --HORA
                                'C',
                                v_cod_moneda,
                                v_monto,
                                v_cod_tra_padre,
                                fug_obt_pardinamico('TRA_SPI_CRSNP'),--4711, --transaccion de envio MT202
                                r_gtran.nro_referencia,
                                NULL, --cotizacion
                                v_cod_ofi_ente, --cod_ofi_origen
                                v_cod_mod_ente, --cod_mod_padre
                                v_cod_mad_ente, --cod_mad_padre
                                null, --cod_tasa
                                null, --val_tasa
                                r_gtran.concepto,
                                'S', --emi_aviso
                                v_nro_secuencia,
                                v_fec_actual);
       if pag_cta.G_COD_ERROR != 00 then
          pas_snp.g_cod_error := 104;
          pas_snp.g_msj_error := pag_cta.G_COD_ERROR || '-' || pag_cta.G_MSJ_ERROR||'-'|| pas_snp.g_cod_error||sqlerrm;
          rollback to transferencia;
       end if;
   exception
       when others then
          pas_snp.g_cod_error := 105;
          pas_snp.g_msj_error := pag_cta.G_COD_ERROR || '-' || pag_cta.G_MSJ_ERROR||'-'||pas_snp.g_cod_error||sqlerrm;
          rollback to transferencia;
   end;
  end if;

    --verificamos que todo este correcto para enviar el swift al socket--
    --ver de agregar el control del periodo--
     pas_snp.g_lugar := 'Envia al socket';
    if pas_snp.g_cod_error = 00 then
      pas_snp.pr_gen_arc_swift(r_gtran.nro_referencia, 'N', 'A');
    end if;
 exception
    when others then
    ROLLBACK;
    /*PRG_INS_LOG_PROGRAMAS('pas_snp.pr_gen_MT202_automatico',
                          pas_snp.g_msj_error,
                          null,
                          v_nro_cta_pte_sol);*/
end pr_gen_MT202_automatico;

/*Procesa la mensajeria del Catastro - MT104.*/
PROCEDURE pr_pro_msj_catastro( p_mensaje in long,p_referencia in varchar2,p_ref_externa in varchar2)
IS
   r_sb_snp_mensajes         sb_snp_mensajes%rowtype := null;
   v_cod_mensaje             sb_snp_tip_mensajes.cod_mensaje%type;
   v_nro_orden               sb_snp_catastros.nro_orden%type;
   v_cod_swi_pte_receptor    sb_snp_catastros.cod_swi_pte_receptor%type :=pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
   v_cod_tip_doc_solicitante ba_tip_documentos.abreviatura%type;
   v_cod_tip_doc_receptor    ba_tip_documentos.abreviatura%type;
   v_tip_circuito            wf_tip_circuitos.cod_tip_circuito%type;
   v_dir_correo              ge_par_dinamicos.val_parametro%type := nvl(pas_snp.g_gru_dir_correo,pas_snp.g_err_dir_correo);
   v_tip_operacion           varchar2(4000);
   v_asunto                  varchar2(1000);
   v_can_lineas              number;
   v_valor                   varchar2(1000);
   v_cod_moneda              varchar2(3):= g_cod_mon_local;
   v_txt_mail                varchar2(4000);
   v_observacion             sb_snp_catastros.error%type;
   v_can_aut                 varchar2(1):='N';
   v_existe                  varchar2(1):='N';
   v_exi_cod_servicio        varchar2(1) := 'N';
   v_mto_fijo                varchar2(1);
   v_nro_cuenta              ge_cta_clientes.nro_cuenta%type;
   v_mot_rch_dup             constant varchar2(03) := '015';
   v_mot_rch_for             constant varchar2(03) := '014';
   v_mot_rch_cru             constant varchar2(03) := '011';
   v_mot_rch_nau             constant varchar2(03) := '008'; -- D�bito no autorizado
   v_mot_rch_lim             constant varchar2(03) := '010'; -- Monto superior al limite
   v_cod_rechazo            varchar2(3);
   v_can_ser                 number;
   v_can_mon                 number;
   ex_rechazo                exception;
   v_dir_receptor            ba_direcciones.direccion%type;
   v_cod_validacion          varchar2(20);
   v_cant_ejecucion          number(5):=0;
   v_error                   sb_snp_catastros.error%type;


PROCEDURE lp_act_catastro ( p_nro_orden IN sb_snp_catastros.nro_orden%type,p_motivo IN sb_snp_catastros.tip_rechazo%type,p_error IN sb_snp_catastros.error%type )
   IS
   BEGIN
     pas_snp.g_lugar := 'Actualizando catastro ';
     update sb_snp_catastros
        set  tip_rechazo = p_motivo, error = p_error
      where nro_orden = p_nro_orden;
      if sql%found then
          v_error:=p_error;
      end if;
   EXCEPTION
     when others then
       null;
END lp_act_catastro;
FUNCTION lf_obt_val_campo(p_valor sb_snp_mensajes_tmp.valor%type,p_longitud in number)
      return varchar2
     IS
    BEGIN
      select substr(a.valor, instr(a.valor, p_valor) + p_longitud, length(a.valor))
        into v_valor
         from sb_snp_mensajes_tmp a
        where a.campo = '79'
          and a.cod_mensaje = 'MTn99/TEXTMESSAGE'
          and instr(a.valor, p_valor) > 0;
      return v_valor;
    EXCEPTION
      when no_data_found then
        return NULL;
      when others then
        raise_application_error( -20101, 'Error obteniendo el valor del campo '||p_valor||'. - '||SQLERRM);
END lf_obt_val_campo;

BEGIN

   /*Inicializa las variables*/
   pas_snp.pr_ini_variables;
   pas_snp.g_det_msj_error := null;
   v_can_aut:='N';
   g_ref_invalida:=false;
   r_sb_snp_catastros:=null;
   /*Se cuentan la cantidad de lineas para el recorrido*/
   select count(*)
   into v_can_lineas
   from table(fug_obt_tab_registro(replace(p_mensaje, chr(13)), chr(10)));
   v_cod_mensaje := pao_pmt.fu_obt_cod_mensaje(p_mensaje);
   g_lugar :=  'Insertar sb_snp_mensajes, ';
   --Grabo linea por linea
   for i in 1..v_can_lineas loop
       r_sb_snp_mensajes.cod_mensaje := v_cod_mensaje;
       r_sb_snp_mensajes.Ind_Requerido := 'N';
       r_sb_snp_mensajes.Nro_Detalle := 0;
       r_sb_snp_mensajes.orden := i;
       r_sb_snp_mensajes.valor := trim(pao_pmt.fu_obt_linea(p_mensaje, r_sb_snp_mensajes.orden));
       r_sb_snp_mensajes.campo := nvl(pao_pmt.fu_obt_campo(r_sb_snp_mensajes.valor), r_sb_snp_mensajes.campo);
       if r_sb_snp_mensajes.campo = pao_pmt.fu_obt_campo(r_sb_snp_mensajes.valor) then
          r_sb_snp_mensajes.nro_linea := 1;

       else
          r_sb_snp_mensajes.nro_linea := r_sb_snp_mensajes.nro_linea + 1;
       end if;
       r_sb_snp_mensajes.valor := trim(replace(r_sb_snp_mensajes.valor, ':'||r_sb_snp_mensajes.campo||':'));
       g_lugar :=  'Obtener valores campo 79:, ';

       case
                WHEN  instr ( r_sb_snp_mensajes.valor, '/TIPOPE/' )>0 THEN
                         g_lugar :=  '/TIPOPE/ '||r_sb_snp_mensajes.valor;
                        v_tip_operacion:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/TIPOPE/'));

                 WHEN  instr ( r_sb_snp_mensajes.valor, '/TEXTMESSAGE/' )>0 THEN
                         g_lugar :=  '/TEXTMESSAGE/ '||r_sb_snp_mensajes.valor;
                        r_sb_snp_catastros.cod_swi_pte_solicitante:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/TEXTMESSAGE/'));

                 WHEN  instr ( r_sb_snp_mensajes.valor, '/FECREG/' )>0 THEN
                       g_lugar :=  '/FECREG/ '||r_sb_snp_mensajes.valor;
                       if ltrim( rtrim(substr(r_sb_snp_mensajes.valor,9,1000))) like '%/%' then
                         r_sb_snp_catastros.fec_registro:=ltrim( rtrim(substr(r_sb_snp_mensajes.valor,9,1000)));
                       else
                         r_sb_snp_catastros.fec_registro:=to_date(ltrim( rtrim(substr(r_sb_snp_mensajes.valor,9,1000))),'DD/MM/YYYY');
                       end if;
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/REFCAT/' )>0 THEN
                       g_lugar :=  '/REFCAT/ '||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.nro_referencia:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/REFCAT/'));

                 WHEN  instr ( r_sb_snp_mensajes.valor, '/NOMCRE/' )>0 THEN
                       g_lugar :=  '/NOMCRE/ '||r_sb_snp_mensajes.valor;
                        r_sb_snp_catastros.nom_solicitante:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/NOMCRE/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/TDOCRE/' )>0 THEN
                       g_lugar :=  '/TDOCRE/ '||r_sb_snp_mensajes.valor;
                       v_cod_tip_doc_solicitante:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/TDOCRE/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/NDOCRE/' )>0 THEN
                       g_lugar :=  '/NDOCRE/ '||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.nro_doc_solicitante:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/NDOCRE/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/CODSER/' )>0 THEN
                       g_lugar :=  '/CODSER/ '||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.cod_servicio:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/CODSER/'));
                        select length(r_sb_snp_catastros.cod_servicio) into v_can_ser from dual;
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/TITSER/' )>0 THEN
                       g_lugar :=  '/TITSER/ '||r_sb_snp_mensajes.valor;
                        r_sb_snp_catastros.titular_servicio:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/TITSER/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/TIPMTO/' )>0 THEN
                       g_lugar :=  '/TIPMTO/ '||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.ind_mto_fijo:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/TIPMTO/'));
                       v_mto_fijo:= r_sb_snp_catastros.ind_mto_fijo;
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/CODMON/' )>0 THEN
                       g_lugar :=  '/CODMON/ '||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.cod_moneda:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/CODMON/'));
                       r_sb_snp_catastros.cod_moneda := case when r_sb_snp_catastros.cod_moneda = pas_snp.g_cod_mon_iso_local THEN
                                                                  pas_snp.g_cod_mon_local
                                                        else
                                                                  r_sb_snp_catastros.cod_moneda
                                                       end;

                 WHEN  instr ( r_sb_snp_mensajes.valor, '/MTODEB/' )>0 THEN
                    g_lugar :=  '/MTODEB/'||r_sb_snp_mensajes.valor;
                    pre_cam_for_numerico(',.');
                    r_sb_snp_catastros.monto :=to_number(to_char(lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/MTODEB/'))));
                    select length(r_sb_snp_catastros.monto) into v_can_mon from dual;

                 WHEN  instr ( r_sb_snp_mensajes.valor, '/FECVTO/' )>0 THEN
                        g_lugar :=  '/FECVTO/'||r_sb_snp_mensajes.valor;
                       if ltrim( rtrim(substr(r_sb_snp_mensajes.valor,9,1000))) like '%/%' then
                         r_sb_snp_catastros.fec_vencimiento:=ltrim( rtrim(substr(r_sb_snp_mensajes.valor,9,1000)));
                       else
                         r_sb_snp_catastros.fec_vencimiento:=to_date(ltrim( rtrim(substr(r_sb_snp_mensajes.valor,9,1000))),'DD/MM/YYYY');
                       end if;
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/CUOSER/' )>0 THEN
                     g_lugar :=  '/CUOSER/'||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.can_cuotas:=to_number(lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/CUOSER/')));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/BICDEB/' )>0 THEN
                     g_lugar :=  '/BICDEB/'||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.cod_swi_pte_receptor:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/BICDEB/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/NOMDEB/' )>0 THEN
                       g_lugar :=  '/NOMDEB/'||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.nom_receptor:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/NOMDEB/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/TDODEB/' )>0 THEN
                       g_lugar :=  '/TDODEB/'||r_sb_snp_mensajes.valor;
                       v_cod_tip_doc_receptor:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/TDODEB/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/NDODEB/' )>0 THEN
                        g_lugar :=  '/NDODEB/'||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.nro_doc_receptor:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/NDODEB/'));
                 WHEN  instr ( r_sb_snp_mensajes.valor, '/CTADEB/' )>0 THEN
                      g_lugar :=  '/CTADEB'||r_sb_snp_mensajes.valor;
                       r_sb_snp_catastros.nro_cta_receptor:=lf_obt_val_campo(r_sb_snp_mensajes.valor,length('/CTADEB/'));
                 ELSE
                   NULL;
      END CASE;
  end loop;
  /* Registrar el Pedido de Catastro Recibido */
      if v_tip_operacion = 'INS' then
           /*Inicializa valores para sb_snp_catastros*/
           select s_snp_nro_orden.nextval into v_nro_orden from dual;
           r_sb_snp_catastros.nro_referencia:=p_referencia;
           r_sb_snp_mensajes.nro_referencia:=r_sb_snp_catastros.nro_referencia;
           r_sb_snp_catastros.nro_ref_externa:=p_ref_externa;
           r_sb_snp_catastros.usu_insercion:=user;
           r_sb_snp_catastros.usu_modificacion:=user;
           r_sb_snp_catastros.fec_insercion:=sysdate;
           r_sb_snp_catastros.fec_modificacion:=sysdate;
           r_sb_snp_catastros.estado:='P';--Pendiente de aprobacion
           r_sb_snp_catastros.origen:='I';
           r_sb_snp_catastros.nro_orden:=v_nro_orden;
           r_sb_snp_catastros.cod_mensaje:='MT104';
           r_sb_snp_catastros.cod_per_receptor:=null;
           r_sb_snp_catastros.cod_tip_per_receptor:=null;
           r_sb_snp_catastros.dir_solicitante :=null;
           r_sb_snp_catastros.dir_receptor:=null;
           r_sb_snp_catastros.fec_recepcion:=pag_cal.fu_obt_fec_actual(1);
           if v_cod_tip_doc_solicitante is not null then
           r_sb_snp_catastros.cod_tip_doc_solicitante := fue_obt_tip_documento(v_cod_tip_doc_solicitante);
           end if;
           if v_cod_tip_doc_receptor is not null then
           r_sb_snp_catastros.cod_tip_doc_receptor := fue_obt_tip_documento(v_cod_tip_doc_receptor);
           end if;
           g_lugar :=  'Obtener datos de Tipo de Monto, ';
           r_sb_snp_catastros.ind_mto_fijo := case when r_sb_snp_catastros.ind_mto_fijo = 'F' then
                                                  'S'
                                                else
                                                  'N'
                                              end;

            r_sb_snp_catastros.cod_per_solicitante:=null;
            r_sb_snp_catastros.cod_tip_per_solicitante:=null;
            r_sb_snp_catastros.motivo:=  'O';
            g_lugar :=  'Actualiza ge_snp_mensajes, ';
            /* Actualiza ge_snp_mensajes con los valores de moneda y monto*/
            begin
              update ge_snp_mensajes
                 set monto = r_sb_snp_catastros.monto,
                     cod_moneda = r_sb_snp_catastros.cod_moneda
               where nro_referencia = p_referencia;
            if sql%rowcount = 0 then
              raise_application_error ( -20001, 100 || ' - ' || g_lugar||p_referencia);
              end if;
            end;
            /* Seccion validaciones para rechazo automatico*/
             g_lugar :=  'Validacion de formato, ';
            if v_can_aut='N' then
              if  r_sb_snp_catastros.cod_servicio is null
                                or v_mto_fijo is null
                                or v_mto_fijo NOT IN('F','V')
                                or r_sb_snp_catastros.monto is null
                                or r_sb_snp_catastros.monto <=0
                                or r_sb_snp_catastros.cod_swi_pte_solicitante is null
                                or r_sb_snp_catastros.fec_registro is null
                                or r_sb_snp_catastros.nom_solicitante is null
                               or v_cod_tip_doc_solicitante is null
                                or r_sb_snp_catastros.nro_doc_solicitante is null
                                or r_sb_snp_catastros.cod_moneda is null
                                or r_sb_snp_catastros.cod_swi_pte_receptor is null
                                or r_sb_snp_catastros.nom_receptor is null
                                or v_cod_tip_doc_receptor is null
                                or r_sb_snp_catastros.nro_doc_receptor is null
                                or r_sb_snp_catastros.nro_cta_receptor is null
                                or v_can_ser >19
                                or v_can_mon >11  then
                  pas_snp.pr_set_texto ( v_observacion, 'Formato no estandar', pas_snp.fu_obt_salto );

                  v_can_aut:='S';
              end if;
            end if;
            if r_sb_snp_catastros.cod_moneda is not null then
              if r_sb_snp_catastros.cod_swi_pte_receptor is not null then
                 g_lugar :=  'Obtener cuenta participante Receptor';
                 r_sb_snp_catastros.nro_cta_pte_receptor := pas_snp.fu_obt_cta_ban_participante(r_sb_snp_catastros.cod_swi_pte_receptor,r_sb_snp_catastros.cod_moneda);
                 if pas_snp.fu_obt_cod_error <> 0 then
                  raise ex_salir;
                 end if;
              end if;
              if r_sb_snp_catastros.cod_swi_pte_solicitante is not null then
                 g_lugar :=  'Obtener cuenta participante solicitante, ';
                 r_sb_snp_catastros.nro_cta_pte_solicitante := it.pas_snp.fu_obt_cta_ban_participante(r_sb_snp_catastros.cod_swi_pte_solicitante,r_sb_snp_catastros.cod_moneda);
                 if pas_snp.fu_obt_cod_error <> 0 then
                  raise ex_salir;
                 end if;
              end if;
           end if;
              g_lugar :=  'Inserta datos del catastro, ';
            insert into sb_snp_catastros values r_sb_snp_catastros;
            if pas_snp.fu_obt_cod_error <> 0 then
              raise ex_rechazo;
            end if;
            if v_can_aut='S' then
             lp_act_catastro ( v_nro_orden,v_mot_rch_for,v_observacion);
             pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
            end if;
            g_lugar :=  'Validacion de duplicacion de catastros, ';
            declare

             begin
               SELECT distinct 'S'
                 INTO v_exi_cod_servicio
                 FROM sb_snp_catastros
                WHERE cod_servicio = r_sb_snp_catastros.cod_servicio
                  AND estado in( 'A','P','O','N')--A - Aprobado ,P-Pendiente Aprobacion,O-Pendiente de Autoriz.-Entidad Debitante, N-Pendiente de Cancelacion
                  AND nro_orden!=v_nro_orden
                  AND nro_doc_solicitante = r_sb_snp_catastros.nro_doc_solicitante
                  AND nro_doc_receptor =  r_sb_snp_catastros.nro_doc_receptor
                  AND nro_cta_receptor = r_sb_snp_catastros.nro_cta_receptor;

             exception
               when no_data_found then
                 null;
               when too_many_rows then
                 v_existe:='S';
               when others THEN
                  v_existe:='S';
             end;
            if v_can_aut='N' then
             if v_existe = 'S' or v_exi_cod_servicio='S' then
                  pas_snp.pr_set_texto ( v_observacion, 'Codigo de Servicio ya existe o se encuentra en otro estado', pas_snp.fu_obt_salto );
                  lp_act_catastro ( v_nro_orden,v_mot_rch_dup,v_observacion);
                  pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
                  v_can_aut:='S';
               end if;
            end if;
            g_lugar :=  'Validacion de Monto del catastro, ';
            if v_can_aut='N' and  r_sb_snp_catastros.cod_moneda = pag_gen.fu_obt_mon_local and (abs(r_sb_snp_catastros.monto) - floor(abs(r_sb_snp_catastros.monto))) > 0 then
                pas_snp.pr_set_texto ( v_observacion, 'El Monto de la orden de domiciliacion no puede contener decimales, ya que la moneda del catastro es GS.', pas_snp.fu_obt_salto );
                lp_act_catastro ( v_nro_orden,v_mot_rch_for,v_observacion);
                pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden, 'X','INS');
                 v_can_aut:='S';
            end if;
            g_lugar :=  'Validacion de Moneda del catastro, ';
            if v_can_aut='N' and r_sb_snp_catastros.cod_moneda!= v_cod_moneda then
                   pas_snp.pr_set_texto ( v_observacion, 'Moneda del catastro incorrecto', pas_snp.fu_obt_salto );
                   lp_act_catastro ( v_nro_orden,v_mot_rch_cru,v_observacion);
                   pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
                   v_can_aut:='S';
             end if;
              g_lugar :=  'Validacion de supera monto maximo de catastro, ';
            if v_can_aut='N' and r_sb_snp_catastros.monto > fug_obt_pardinamico('MTO_MAX_SOL_CATASTRO') then
                   pas_snp.pr_set_texto ( v_observacion, 'Monto del catastro supera monto maximo', pas_snp.fu_obt_salto );
                   lp_act_catastro ( v_nro_orden,v_mot_rch_lim,v_observacion);
                   pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
                   v_can_aut:='S';
            end if;
             g_lugar :=  'Validacion de Fecha de vencimiento del catastro, ';
            if v_can_aut='N' and r_sb_snp_catastros.fec_vencimiento is not null  then
              if r_sb_snp_catastros.fec_vencimiento < g_fec_actual then
                   pas_snp.pr_set_texto ( v_observacion, 'Fecha de vencimiento del catastro menor a fecha actual', pas_snp.fu_obt_salto );
                   lp_act_catastro ( v_nro_orden,v_mot_rch_for,v_observacion);
                   pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
                   v_can_aut:='S';
                   end if;
            end if;
            if v_can_aut='N' then
              g_lugar :=  'Validacion de Cuenta Debito-Receptor, ';
              pas_snp.pr_obt_cta_catastro( r_sb_snp_catastros.nro_cta_receptor,
                                          r_sb_snp_catastros.cod_tip_doc_receptor,
                                          r_sb_snp_catastros.nro_doc_receptor,
                                          v_nro_cuenta,
                                          r_sb_snp_catastros.cod_per_receptor,
                                          v_cod_rechazo
                                        );
              --
              if pas_snp.fu_obt_cod_error <> 0 then
                 pas_snp.pr_set_texto ( v_observacion, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                 v_can_aut:='S';
              end if;
                  if v_nro_cuenta is not null then
                      pag_cta.pr_obt_cuenta( v_nro_cuenta );

                      if pag_cta.fu_obt_cod_error <> 0 then
                         pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                         pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;
                         pas_snp.pr_set_texto ( v_observacion, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                         v_can_aut:='S';

                      end if;

                      if pag_cta.g_ctas.cod_moneda !=  r_sb_snp_catastros.cod_moneda then
                          pas_snp.pr_set_texto ( v_observacion, 'No coincide moneda transferencia con moneda de cta', pas_snp.fu_obt_salto );
                          v_can_aut:='S';
                      end if;
                      if pas_snp.fu_obt_cod_error <> 0 then
                         pas_snp.pr_set_texto ( v_observacion, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
                         v_can_aut:='S';
                      end if;
                  end if;
                      if  v_can_aut='S' then
                        lp_act_catastro ( v_nro_orden,nvl(v_cod_rechazo,v_mot_rch_nau),v_observacion);
                        pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
                        v_can_aut:='S';
                      end if;
                        if r_sb_snp_catastros.cod_per_receptor is not null then
                          v_dir_receptor := fue_obt_dir_principa(r_sb_snp_catastros.cod_per_receptor );
                          update sb_snp_catastros
                          set cod_per_receptor=r_sb_snp_catastros.cod_per_receptor,
                              dir_receptor= v_dir_receptor
                          where nro_orden=v_nro_orden;
                        end if;
                  end if;

            if v_can_aut='N' and  r_sb_snp_catastros.cod_swi_pte_receptor != v_cod_swi_pte_receptor then
                   pas_snp.pr_set_texto ( v_observacion, 'BIC debito no corresponde a la entidad', pas_snp.fu_obt_salto );
                   lp_act_catastro ( v_nro_orden,v_mot_rch_nau,v_observacion);
                   pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
                   v_can_aut:='S';
            end if;
           -- Condiciona ,solo si NO hubo un rechazo automatico, generar circuito y registra datos del recaudador
           if v_can_aut!='S' then

           g_lugar :=  'Registra Datos del recaudador, ';
            pas_snp.pr_reg_persona(r_sb_snp_catastros.nom_solicitante,
                                   r_sb_snp_catastros.nro_doc_solicitante,
                                   v_cod_tip_doc_solicitante);
           g_lugar :=  'Inicia Circuito de Solicitud de Catastro Recibido, ';
           -- Iniciar Circuito de Solicitud de Catastro Recibido

               v_tip_circuito := fug_obt_pardinamico('SNP_CIR_APR_SOL_CAT_REC');

               if paw_cir.fu_ini_circuito( v_tip_circuito,
                                           v_nro_orden,
                                           1
                                         ) <> 0 then
                              raise_application_error( -20001, 'No se ha podido iniciar el circuito ' || v_tip_circuito ||'. - Orden N� '||v_nro_orden||' - '|| paw_cir.fu_obt_msj_error );
               end if;
               if v_dir_correo is not null then
                  BEGIN
                    /*Envio notificacion*/
                    v_asunto   := 'Notificacion de Inicio de Circuito de Workflow, por la Recepcion de una Solicitud de Alta de Catastro - Orden N� '||v_nro_orden;
                    v_txt_mail := 'Se ha iniciado un Circuito de Workflow ' || v_tip_circuito || ', por la Recepcion de una Solicitud de Alta de Catastro - Orden N� '||v_nro_orden ||
                                  chr(10) || 'Codigo de Servicio Nro. ' || r_sb_snp_catastros.cod_servicio ||
                                  chr(10) || 'Referencia Nro. ' || r_sb_snp_catastros.nro_referencia ||
                                  chr(10) ||
                                  'Por favor verifique su bandeja de Workflow.'  ||
                                  chr(10) || chr(10) || 'Atentamente.';

                    it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                  EXCEPTION
                    when others then
                      NULL;
                  END;
                end if;
            elsif v_can_aut='S' then
              if v_dir_correo is not null then
                  BEGIN
                    /*Envio notificacion por rechazo automatico*/
                    v_asunto   := 'Notificacion de Rechazo de Solicitud de Alta de Catastro - Orden Nro: '||v_nro_orden;
                    v_txt_mail := 'Se ha realizado un Rechazo automatico por errores en el proceso de validacion de la Solicitud de Alta de Catastro Recibida - Orden Nro: '||v_nro_orden ||
                                  chr(10) || 'Codigo de Servicio Nro. ' || r_sb_snp_catastros.cod_servicio ||
                                  chr(10) || 'Referencia Nro. ' || r_sb_snp_catastros.nro_referencia ||
                                  chr(10) || 'Referencia Externa Nro. ' || r_sb_snp_catastros.nro_ref_externa ||
                                  chr(10) || 'El motivo de rechazo es: '||v_error ||
                                  chr(10) || chr(10) || 'Atentamente.';

                    it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                  EXCEPTION
                    when others then
                      NULL;
                  END;
                end if;
          -- Registrar el error la descripci�n de la validaci�n que no se cumple
                update ge_snp_mensajes mm
                set mm.error=substr(v_error,1,4000)
                where mm.nro_referencia = p_referencia
                and mm.nro_ref_externa=p_ref_externa;
            end if;
    elsif v_tip_operacion = 'CANC' then
       -- Recepcion de cancelacion de catastro -- Genera WF
        begin
            select ct.nro_referencia
            into r_sb_snp_catastros.nro_referencia
            from sb_snp_catastros ct
            where ct.cod_servicio = r_sb_snp_catastros.cod_servicio
            and ct.nro_doc_solicitante = r_sb_snp_catastros.nro_doc_solicitante
            and ct.cod_tip_doc_solicitante=fue_obt_tip_documento(v_cod_tip_doc_solicitante)
            and ct.fec_registro=r_sb_snp_catastros.fec_registro;
        exception
            when others then
               r_sb_snp_catastros.nro_referencia:=null;
        end;

         pr_obt_dat_catastro(r_sb_snp_catastros.nro_referencia,'R');
         v_tip_circuito := fug_obt_pardinamico('SNP_CIR_SOL_CAN_CAT');

         if g_cat.estado='C' then  --catastro cancelado
            pas_snp.pr_set_texto ( v_observacion, 'La orden de catastro ya se encuentra cancelada', pas_snp.fu_obt_salto );
            v_cod_validacion:='012';
         elsif pas_snp.g_cod_error!=0 or
               g_cat.estado!='A' or g_cat.fec_registro!=r_sb_snp_catastros.fec_registro then

               g_tip_doc         := fue_obt_tip_documento(v_cod_tip_doc_solicitante);
               g_documento       := r_sb_snp_catastros.nro_doc_solicitante;
               g_cod_ser         := r_sb_snp_catastros.cod_servicio;

               v_cod_validacion:='999';

               if pas_snp.g_cod_error=17 then  --ref. de catastro no encontrada
                  g_ref_invalida:=true;
                  pas_snp.pr_set_texto ( v_observacion, 'Orden de catastro no encontrada', pas_snp.fu_obt_salto );
               elsif g_cat.estado!='A' then
                  pas_snp.pr_set_texto ( v_observacion, 'Orden de catastro no aprobada', pas_snp.fu_obt_salto );
               else
                  pas_snp.pr_set_texto ( v_observacion, 'La fecha del registro no coincide con lo especificado en el catastro', pas_snp.fu_obt_salto );
               end if;
         elsif g_cat.cod_swi_pte_solicitante!=r_sb_snp_catastros.cod_swi_pte_solicitante or
               g_cat.cod_swi_pte_receptor!=r_sb_snp_catastros.cod_swi_pte_receptor then
               pas_snp.pr_set_texto ( v_observacion, 'Codigo swfit del solicitante o receptor no coincide con lo registrado en el catastro', pas_snp.fu_obt_salto );
               v_cod_validacion:='014';
         else
            --cancelaci?n pendiente de aprobacion o rechazo
               select count(*)
               into v_cant_ejecucion
               from wf_circuitos w
               where w.referencia=g_cat.nro_orden
               and w.cod_tip_circuito=v_tip_circuito
               and w.estado in ('E');

               if v_cant_ejecucion>0 then
                   v_cod_validacion:='015';
                    pas_snp.pr_set_texto ( v_observacion, 'Ya existe una orden de cancelaci�n pendiente de aprobacion o rechazo', pas_snp.fu_obt_salto );
               end if;
         end if;

         if v_cod_validacion is not null then --alguna validacion no se cumple, se procede al rechazo automatico
           -- Registrar el error la descripci�n de la validaci�n que no se cumple
            update ge_snp_mensajes mm
            set mm.error=substr(v_observacion,1,4000)
            where mm.nro_referencia = p_referencia
            and mm.nro_ref_externa=p_ref_externa;

            pas_snp.pr_obt_msj_catastro(g_cat.nro_orden,'X',v_tip_operacion,v_cod_validacion);
            if  pas_snp.fu_obt_cod_error!=0 then
                raise ex_salir;
            end if;
         else --se aprueban las validaciones iniicales y se debe generar WF
              if paw_cir.fu_ini_circuito(v_tip_circuito,g_cat.nro_orden,1) <> 0 then
                 raise_application_error( -20002, 'No se ha podido iniciar el circuito ' || v_tip_circuito ||'. - Orden N� '||g_cat.nro_orden||' - '|| paw_cir.fu_obt_msj_error );
              end if;

              if v_dir_correo is not null then
                 begin
                      /*Envio notificacion*/
                      v_asunto   := 'Notificacion de Inicio de Circuito de Workflow, por la Recepcion de una Solicitud de Cancelacion de Catastro - Orden N� '||g_cat.nro_orden;
                      v_txt_mail := 'Se ha iniciado un Circuito de Workflow ' || v_tip_circuito || ', por la Recepcion de una Solicitud de Cancelacion de Catastro - Orden N� '||g_cat.nro_orden ||
                                    chr(10) || 'Codigo de Servicio Nro. ' ||g_cat.cod_servicio ||
                                    chr(10) || 'Referencia Nro. ' ||g_cat.nro_referencia ||
                                    chr(10) ||
                                    'Por favor verifique su bandeja de Workflow.'  ||
                                    chr(10) || chr(10) || 'Atentamente.';

                       it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                  exception
                      when others then
                          NULL;
                  end;
              end if;
         end if;
     elsif v_tip_operacion = 'AUT-INS' then
        -- Recepcion y Confirmacion de alta catastro --
        begin
            select ce.nro_orden
            into r_sb_snp_catastros.nro_orden
            from sb_snp_catastros ce
            where ce.cod_servicio = r_sb_snp_catastros.cod_servicio
            and ce.nro_doc_solicitante = r_sb_snp_catastros.nro_doc_solicitante
            and ce.cod_tip_doc_solicitante=fue_obt_tip_documento(v_cod_tip_doc_solicitante)
            and ce.fec_registro=r_sb_snp_catastros.fec_registro;
        exception
            when others then
               r_sb_snp_catastros.nro_orden:=null;
        end;


         -- Actualizar la Solicitud de Catastro Recibida y Aprobada -- DA-9231 --
                 begin
                   update sb_snp_catastros c
                      set c.estado = 'A',
                          c.situacion = 'EA',
                          c.fec_autorizacion =sysdate
                    where c.nro_orden = r_sb_snp_catastros.nro_orden;

                    if SQL%ROWCOUNT = 0 then
                       raise_application_error( -20101, 'No se han encontrado datos de la Solicitud de Catastro a actualizar - Orden N� '||r_sb_snp_catastros.nro_orden);
                   end if;
                 end;

                 if v_dir_correo is not null then
                    BEGIN
                      /*Envio notificacion*/
                      v_asunto   := 'Notificaci�n de Aprobaci�n de Solicitud de Alta de Catastro Recibida - Orden N� '||r_sb_snp_catastros.nro_orden;
                      v_txt_mail := 'Se ha realizado una Aprobaci�n por parte de la Entidad Receptora de la Solicitud de Alta de Catastro Recibida - Orden N� '||r_sb_snp_catastros.nro_orden ||
                                    chr(10) || 'C�digo de Servicio Nro.' || r_sb_snp_catastros.cod_servicio ||
                                    chr(10) || 'El mensaje de Aprobaci�n fue enviado a la entidad: '|| r_sb_snp_catastros.cod_swi_pte_receptor ||
                                    chr(10) || chr(10) || 'Atentamente.';

                      it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                    EXCEPTION
                      when others then
                        NULL;
                    END;
                  end if;
     elsif v_tip_operacion = 'RCH-INS' then
        -- Recepcion y Rechazo de alta catastro --
        begin
            select ce.nro_orden
            into r_sb_snp_catastros.nro_orden
            from sb_snp_catastros ce
            where ce.cod_servicio = r_sb_snp_catastros.cod_servicio
            and ce.nro_doc_solicitante = r_sb_snp_catastros.nro_doc_solicitante
            and ce.cod_tip_doc_solicitante=fue_obt_tip_documento(v_cod_tip_doc_solicitante)
            and ce.fec_registro=r_sb_snp_catastros.fec_registro;
        exception
            when others then
               r_sb_snp_catastros.nro_orden:=null;
        end;
                -- Actualizar la Solicitud de Catastro Catastro Recibida y Rechazada
                begin
                  update sb_snp_catastros c
                     set c.estado = 'R',
                         c.situacion = 'ER',
                         c.fec_rechazo =sysdate
                   where c.nro_orden = r_sb_snp_catastros.nro_orden;

                   if SQL%ROWCOUNT = 0 then
                      raise_application_error( -20101, 'No se han encontrado datos de la Solicitud de Catastro a actualizar - Orden N� '||r_sb_snp_catastros.nro_orden);
                   end if;
                end;

                if v_dir_correo is not null then
                    BEGIN
                      /*Envio notificacion*/
                      v_asunto   := 'Notificaci�n de Rechazo de Solicitud de Alta de Catastro Recibida - Orden N� '||r_sb_snp_catastros.nro_orden;
                      v_txt_mail := 'Se ha realizado un Rechazo por parte de la entidad receptora de la Solicitud de Alta de Catastro Recibida - Orden N� '||r_sb_snp_catastros.nro_orden ||
                                    chr(10) || 'C�digo de Servicio Nro.' || r_sb_snp_catastros.cod_servicio ||
                                    chr(10) || 'El mensaje de Rechazo fue enviado a la entidad: '|| r_sb_snp_catastros.cod_swi_pte_receptor  ||
                                    chr(10) || chr(10) || 'Atentamente.';

                      it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                    EXCEPTION
                      when others then
                        NULL;
                    END;
                  end if;
  -- DA-9544 --
     elsif v_tip_operacion = 'AUT-CANC' then
        -- Recepcion Autorizacion de Cancelaci�n de catastro --
        begin
            select ct.nro_referencia
            into r_sb_snp_catastros.nro_referencia
            from sb_snp_catastros ct
            where ct.cod_servicio = r_sb_snp_catastros.cod_servicio
            and ct.nro_doc_solicitante = r_sb_snp_catastros.nro_doc_solicitante
            and ct.cod_tip_doc_solicitante=fue_obt_tip_documento(v_cod_tip_doc_solicitante)
            and ct.fec_registro=r_sb_snp_catastros.fec_registro;
        exception
            when others then
               r_sb_snp_catastros.nro_referencia:=null;
        end;

         pr_obt_dat_catastro(r_sb_snp_catastros.nro_referencia,'R');

                -- Actualizar la Solicitud de Catastro Catastro Recibida y Rechazada
                begin
                  update sb_snp_catastros c
                     set c.situacion = 'EC',
                         c.estado='C'
                   where c.nro_orden = g_cat.nro_orden;

                   if SQL%ROWCOUNT = 0 then
                      raise_application_error( -20101, 'No se han encontrado datos de la Solicitud de Catastro a actualizar - Orden N� '||r_sb_snp_catastros.nro_orden);
                   end if;
                end;

                if v_dir_correo is not null then
                    BEGIN
                      /*Envio notificacion*/
                      v_asunto   := 'Notificaci�n de Aprobaci�n de Solicitud de Cancelaci�n de Catastro Recibida - Orden N� '||r_sb_snp_catastros.nro_orden;
                      v_txt_mail := 'Se ha realizado una Aprobaci�n por parte de la Entidad Receptora de la Solicitud de Cancelaci�n de Catastro Recibida - Orden N� '||r_sb_snp_catastros.nro_orden ||
                                    chr(10) || 'El mensaje de Aprobaci�n fue enviado a la entidad: '|| r_sb_snp_catastros.cod_swi_pte_receptor  ||
                                    chr(10) || chr(10) || 'Atentamente.';

                      it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                    EXCEPTION
                      when others then
                        NULL;
                    END;
                  end if;
     elsif v_tip_operacion = 'RCH-CANC' then
        -- Recepcion del Rechazo de Cancelaci�n de catastro --
        null;
     else
          raise_application_error( -20003, 'Solo se permiten las operaciones INS-CANC' );
    end if;

EXCEPTION
   when ex_rechazo then
    lp_act_catastro ( v_nro_orden,v_mot_rch_for,v_observacion);
    pas_snp.pr_obt_msj_catastro(r_sb_snp_catastros.nro_orden,'X','INS');
   when ex_salir then
     pas_snp.g_cod_error := 70;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_PRO_MSJ_CATASTRO: '||g_lugar||' - '||fu_obt_msj_error;
  when others then
     pas_snp.g_cod_error := 80;
     pas_snp.g_msj_error := 'Error al procesar PAS_SNP.PR_PRO_MSJ_CATASTRO: '|| pas_snp.g_lugar ||' '|| sqlerrm;
end pr_pro_msj_catastro;
/*Registro de persona*/
PROCEDURE pr_reg_persona(p_nombre        in varchar2,
                         p_nro_documento in varchar2,
                         p_tipo          in varchar2) is
  PRAGMA AUTONOMOUS_TRANSACTION;

  l_nombre        ba_personas.nom_completo%type := p_nombre;
  v_cod_per_cli   ba_personas.cod_persona%type;
  l_tip_documento ba_tip_documentos.cod_tip_documento%type := 6;
BEGIN

  select t.cod_persona
    into v_cod_per_cli
    from ba_personas t
   where t.nro_documento = p_nro_documento;
exception
  when no_data_found then
    -- DA-9078 --
     if fue_obt_tip_documento(p_tipo) = l_tip_documento then
        prl_ins_persona(p_nro_documento,
                        l_tip_documento,
                        1,
                        l_nombre,
                        null,
                        'J',
                        trunc(sysdate),
                        v_cod_per_cli);
          commit;
     else
       null;
     end if;
  when others then
    pas_snp.g_cod_error := 90;
    pas_snp.g_msj_error := 'Error al registrar solicitante catastro: ' ||
                           pas_snp.g_lugar || ' ' || sqlerrm;
end pr_reg_persona;
/*Controla cuenta interna para catastro*/
PROCEDURE pr_obt_cta_catastro( p_nro_cuenta            in  ge_snp_transferencias.nro_cta_beneficiario%type,
                              p_tip_documento         in  ba_personas.cod_tip_documento%type,
                              p_nro_documento         in  ba_personas.nro_documento%type,
                              p_nro_cta_interno       out ge_cuentas.nro_cuenta%type,
                              p_cod_persona           out ba_personas.cod_persona%type,
                              p_cod_rechazo           out varchar2
                            )
  /*Obtiene la Cuenta registrada en ITGF segun el Numero de Cuenta registrado*/
IS
   cursor cu_cta_clientes is
   select ct.nro_cuenta, ct.cod_persona, ct.cod_modulo, ct.cod_modalidad,
          b.cod_tip_documento, b.nro_documento, g.estado
     from ba_personas b, ge_cta_clientes ct, ge_cuentas g
    where to_number( ct.nro_cuenta ) = to_number( p_nro_cuenta )
      and ct.cod_persona             = b.cod_persona
      and ct.nro_cuenta              = g.nro_cuenta;

   v_cod_modulo    ge_modalidades.cod_modulo%type := null;
   v_cod_modalidad ge_modalidades.cod_modalidad%type := null;
   v_ind_tip_doc   varchar2(1):= 'N'; -- Existe el Tipo de Documento (S/N).
   v_ind_nro_doc   varchar2(1):= 'N'; -- Existe el Numero de Documento (S/N).
   v_estado        ge_cuentas.estado%type;

BEGIN
   -- Inicializa variables de error
   pas_snp.pr_ini_variables;
   --
   for c in cu_cta_clientes loop
      p_nro_cta_interno := c.nro_cuenta;
      p_cod_persona     := c.cod_persona;
      v_cod_modulo      := c.cod_modulo;
      v_cod_modalidad   := c.cod_modalidad;
      v_estado          := c.estado;

      -- Si el tipo de documento no esta cargado, no se valida.
      /*if p_tip_documento = c.cod_tip_documento or
         p_tip_documento is null
      then
         v_ind_tip_doc := 'S';
      end if;*/ --TC-489

      -- Como el pas_snp.fu_val_cadena no limpia los caracteres .:-/?(),+
      -- entonces volvemos a limpiar dichos caracteres del numero de documento.
      /*if pas_snp.fu_val_cadena(c.nro_documento, 'A') =
         pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A') or
         instr(pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A'),
               pas_snp.fu_val_cadena(c.nro_documento, 'A'), 1) > 0 then*/--TCE-489
      if (pas_snp.fu_val_cadena(c.nro_documento, 'A') =
        pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A')) or
        (substr( trim(c.nro_documento),1, instr(c.nro_documento, '-')-1))=trim(p_nro_documento) or
        (substr( trim(p_nro_documento),1, instr(p_nro_documento, '-')-1)) =trim(c.nro_documento) then --TCE-489
         v_ind_nro_doc := 'S';
      end if;
      --
      if --v_ind_tip_doc = 'S' and --TC-489
         v_ind_nro_doc = 'S'
      then
         exit; -- Si encuentra el Tipo y el Nro. de Documento
      end if;
      --
   end loop;

   if p_nro_cta_interno is null then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Cuenta existente o no corresponde al cliente', '. ' );
      p_cod_rechazo :='002'; -- cuenta no existe --
      raise ex_salir;
   end if;

   if not  ( v_cod_modulo in ( 3, 4 ) and v_cod_modalidad in ( 31, 38, 39, 41, 43, 47, 455, 38, 39, 334 ) )
   then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Modalidad de la cuenta no permite este tipo de operacion', '. ' );
      p_cod_rechazo :='008'; -- d�bito no autorizado --
      raise ex_salir;
   end if;

   if  v_cod_modulo in ( 3, 4 ) and v_estado in ( 'C', 'P', 'X', 'T' ) then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Estado de la cuenta no permite este tipo de operacion', '. ' );
      p_cod_rechazo :='001'; -- cuenta cancelada --
      raise ex_salir;
   end if;

   /*if v_ind_tip_doc = 'N' then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Tip. Doc. no coincide con el registrado en ITGF para la cuenta '||p_nro_cta_interno, '. ' );
      p_cod_rechazo :='003'; -- datos no corresponden a la cta.
   end if;*/ --TC-489

   if v_ind_nro_doc = 'N' then
      pas_snp.g_cod_error := 66;
      pas_snp.pr_set_texto( pas_snp.g_msj_error, 'Nro Doc. no coincide con el registrado en ITGF para la cuenta '||p_nro_cta_interno, '. ' );
      p_cod_rechazo :='003'; -- datos no corresponden a la cta.
   end if;
   --
   if pas_snp.fu_obt_cod_error <> 0 then
      p_nro_cta_interno := null;
      p_cod_persona     := null;
   end if;
   --
EXCEPTION
   when ex_salir then
      p_nro_cta_interno   := null;
      p_cod_persona       := null;
   when others then
      p_nro_cta_interno   := null;
      p_cod_persona       := null;
      pas_snp.g_cod_error := 66;
      pas_snp.g_msj_error := 'Error al recuperar la Cuenta Interna en ITGF. Cuenta: ' || p_nro_cuenta || ' ' || SQLERRM;
END pr_obt_cta_catastro;
/*Genera MT999 a enviar -Catastro.*/
PROCEDURE pr_obt_msj_catastro ( p_nro_orden in sb_snp_catastros.nro_orden%type,
                                p_tip_accion     in varchar2,
                                p_tip_operacion  in varchar2,
                                p_cod_rechazo    in varchar2 default null)
IS
   /*
   || Envia MT999 de Catastro,envia el mensaje al servidor e inserta en ge_snp_mensajes.
   */
   v_tip_msj_swift    ge_snp_transferencias.cod_msj_swift%type:='999';
   v_cod_msj_swift   sb_snp_mensajes.cod_mensaje%type:='MT999';
   v_bic_entidad      ge_bancos.cod_swift%type;
   v_mensaje          ge_snp_mensajes.msj_swift%type;
   v_resp             varchar2(4000) := null;
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_estado           varchar2(1);
   v_dir_correo       ge_par_dinamicos.val_parametro%type := nvl(pas_snp.g_gru_dir_correo, pas_snp.g_err_dir_correo);
   v_asunto          varchar2(1000);
   v_txt_mail        varchar2(4000);
   v_tip_can         varchar2(1000);
   v_fec_ref_catastro varchar2(10);
   v_rechazo         varchar2(2000);
   v_ref_rechazo     ba_cod_referencias.val_maximo%type;
   v_tip_operacion   varchar2(2000);
BEGIN
         /*Inicializa las variables de error*/
         pas_snp.pr_ini_variables;
         begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
         --Recupera el BIC de la entidad solicitante
         v_bic_entidad := pas_snp.fu_obt_cod_swi_participante ( fug_obt_per_entidad );
         if pas_snp.fu_obt_cod_error <> 0 then
            raise ex_salir;
         end if;

         --Valida si esta correcto el codigo de usuario del X-ADAPTER
         if nvl( length( g_usu_xadapter ), 0 ) <> 12 then
            pas_snp.g_cod_error := '70';
            pas_snp.g_msj_error := 'Codigo de usuario X-ADAPTER debe tener longitud de 12 caracteres';
            raise ex_salir;
         elsif v_bic_entidad <> substr(g_usu_xadapter,1,8) then
            pas_snp.g_cod_error := '70';
            pas_snp.g_msj_error := 'Codigo de usuario X-ADAPTER no corresponde a la entidad';
            raise ex_salir;
         end if;

         if p_nro_orden is null and not g_ref_invalida then
            pas_snp.g_cod_error := 70;
            pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_CATASTRO. Valor para P_NRO_REFERENCIA debe contener algun valor.!';
            raise ex_salir;
         end if;

         --Obtiene el registro de ge_snp_transferencias
         g_lugar :=  'Levantando registros desde SB_SNP_CATASTROS, ';
         pas_snp.pr_obt_dat_catastro( p_nro_orden,'O');
         if pas_snp.fu_obt_cod_error <> 0 and not g_ref_invalida then
            raise ex_salir;
         end if;
       -- ****************************** Cabecera del mensaje **********************************************
        v_nro_referencia:=pas_snp.fu_obt_sig_nro_referencia;
        v_fec_ref_catastro := replace(to_char(pag_cal.fu_obt_fec_actual(1), 'DDMMRRRR'), '/','');
        pas_snp.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_swift,
                                               'CAB',
                                               '{1:F01' ||rpad(pas_snp.g_usu_xadapter, 12, 'X') || '}' ||
                                               '{2:I'||v_tip_msj_swift ||rpad(fu_obt_bic_sistema, 12, 'X') || 'N}' ||
                                               '{3:{113'||':'||lpad('30', 4, '0') || '}}{4:');

          -- 20: Referencia del mensaje
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_swift,
                                               '20',
                                               v_nro_referencia);
            case p_tip_operacion
              when 'INS' then
                  v_fec_ref_catastro:=replace(to_char(g_cat.fec_registro, 'DDMMRRRR'), '/','');
                   if p_tip_accion='A' then
                      v_tip_operacion :='AUT'||'-'||p_tip_operacion;
                   elsif p_tip_accion in ('C','X') then
                      v_tip_operacion :='RCH'||'-'||p_tip_operacion;
                      v_rechazo       :=g_cat.tip_rechazo || '/' || fue_obt_des_refcodes('TIP_REC_SNP', g_cat.tip_rechazo);
                   end if;
               when  'CANC' then
                     v_fec_ref_catastro:=replace(to_char(g_cat.fec_registro, 'DDMMRRRR'), '/','');
                     if p_tip_accion='A' then
                         v_tip_operacion  :='AUT'||'-'||p_tip_operacion;
                     elsif p_tip_accion in ('C','X') then

                       v_tip_operacion  :='RCH'||'-'||p_tip_operacion;

                       if p_tip_accion='X' then --corresponde a una causa de rechazo autom?tico
                          v_rechazo :=p_cod_rechazo|| '/' ||fue_obt_des_refcodes('TIP_REC_SNP',p_cod_rechazo);
                       else --corresponde a una causa de rechazo cargada por WF
                          v_ref_rechazo :=fue_obt_val_max_referencia('SNP_CAU_REC_CAN_CAT',p_cod_rechazo);
                          v_rechazo     :=v_ref_rechazo|| '/' ||fue_obt_des_refcodes('TIP_REC_SNP',v_ref_rechazo);
                       end if;
                     end if;
              end case;
        /*Desde aqui valida las condiciones segun el tipo de accion*/

        -- ****************************** cuerpo del mensaje **********************************************
          -- 79: Generando datos del campo 79
           if g_ref_invalida then
              g_cat.cod_swi_pte_solicitante:=r_sb_snp_catastros.cod_swi_pte_solicitante;
              g_cat.nro_referencia         :=r_sb_snp_catastros.nro_referencia;
              g_cat.cod_swi_pte_receptor   :=r_sb_snp_catastros.cod_swi_pte_receptor;
              v_fec_ref_catastro           :=replace(to_char(r_sb_snp_catastros.fec_registro, 'DDMMRRRR'), '/','');
              g_cat.fec_recepcion          :=sysdate;
           end if;
           if p_tip_accion='A' and g_cat.fec_recepcion is not null then
                pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_swift,
                                                   '79',
                                                   '/TEXTMESSAGE/' ||g_cat.cod_swi_pte_solicitante || pas_snp.fu_obt_salto ||
                                                   '/INSTRU/CATASTRO DEBITO DIRECTO' || pas_snp.fu_obt_salto ||
                                                   '/TIPOPE/' || v_tip_operacion||pas_snp.fu_obt_salto ||
                                                   '/TDOCRE/'||fue_obt_tip_doc_abreviatura(g_cat.cod_tip_doc_solicitante)||pas_snp.fu_obt_salto || --DA-8861
                                                   '/NDOCRE/'||g_cat.nro_doc_solicitante||pas_snp.fu_obt_salto ||
                                                   '/CODSER/'||g_cat.cod_servicio||pas_snp.fu_obt_salto ||
                                                   '/FECREG/' || v_fec_ref_catastro|| pas_snp.fu_obt_salto ||
                                                   '/BICDEB/' || g_cat.cod_swi_pte_receptor
                                                   );

           elsif g_cat.fec_recepcion is not NULL and p_tip_accion in ('C','X') then--rechazada desde el WF y rechazada automaticamente
        -- ****************************** cuerpo del mensaje **********************************************
          -- 79: Generando datos del campo 79
                pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_swift,
                                                   '79',
                                                   '/TEXTMESSAGE/' ||g_cat.cod_swi_pte_solicitante || pas_snp.fu_obt_salto ||
                                                   '/INSTRU/CATASTRO DEBITO DIRECTO' || pas_snp.fu_obt_salto ||
                                                   '/TIPOPE/' || v_tip_operacion||pas_snp.fu_obt_salto ||
                                                   '/TDOCRE/'|| fue_obt_tip_doc_abreviatura(nvl(g_cat.cod_tip_doc_solicitante,g_tip_doc))||pas_snp.fu_obt_salto || --DA-8861
                                                   '/NDOCRE/'|| nvl(g_cat.nro_doc_solicitante,g_documento)||pas_snp.fu_obt_salto ||
                                                   '/CODSER/'|| nvl(g_cat.cod_servicio,g_cod_ser)||pas_snp.fu_obt_salto ||
                                                   '/FECREG/' || v_fec_ref_catastro|| pas_snp.fu_obt_salto ||
                                                   '/BICDEB/' || g_cat.cod_swi_pte_receptor|| pas_snp.fu_obt_salto ||
                                                   '/MOTREC/' || v_rechazo
                                                   );
          end if;
        pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_swift, 'PIE', '-}');
        BEGIN

              pas_snp.g_lugar := 'Creando la mensajeria de Catastro, ';
              pao_pmt.pr_pro_mt_enviado(v_cod_msj_swift, v_mensaje);

              pas_snp.g_lugar:=  'Insertando en GE_SNP_MENSAJES, ';
              INSERT INTO ge_snp_mensajes ( nro_referencia,
                                            nro_ref_externa,
                                            cod_msj_swift,
                                            fec_valor,
                                            msj_swift,
                                            situacion )
                                   VALUES (v_nro_referencia,
                                           nvl(g_cat.nro_referencia,g_nro_referencia),--p_nro_referencia,
                                           '999',
                                           g_fec_actual,
                                           v_mensaje,
                                           'V' );
                   --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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
                                      pas_snp.g_cod_error := 70;
                                      pas_snp.g_msj_error := 'MT' || v_tip_msj_swift || ' | ' || 'Al intentar insertar en GE_MEN_ENV_SIPAP - Ope: '||p_nro_orden;
                                      raise ex_salir;

                               end;
                    else
                       pas_snp.g_lugar := 'Enviando mensaje swift al socket, ';
                       pas_snp.pr_gen_arc_swi_lote(v_mensaje);
           end if;
            EXCEPTION
               when ex_salir then
                    raise ex_salir;

               when others then
                     pas_snp.g_cod_error := 70;
                     pas_snp.g_msj_error := 'MT' || v_tip_msj_swift || ' | ' || 'Al intentar insertar en GE_SNP_MENSAJES - Ope: '||p_nro_orden;
                  raise ex_salir;
                      raise_application_error(-20000,'Error'||sqlerrm);

            END ;
       if pas_snp.g_cod_error = 0 then
        if p_tip_operacion='INS' then
              if g_cat.fec_recepcion is NOT NULL and p_tip_accion = 'A' then
                -- Actualizar la Solicitud de Catastro Recibida y Aprobada
                begin
                   update sb_snp_catastros c
                      set c.estado = 'A',
                          c.situacion = 'RA',
                          c.fec_autorizacion = pag_cal.fu_obt_fec_actual(1)
                    where c.nro_orden = g_cat.nro_orden;

                    if SQL%ROWCOUNT = 0 then
                       raise_application_error( -20101, 'No se han encontrado datos de la Solicitud de Catastro a actualizar - Orden N� '||g_cat.nro_orden);
                   end if;
                 end;
                 if v_dir_correo is not null then
                    BEGIN
                      /*Envio notificacion*/
                      v_asunto   := 'Notificacion de Aprobacion de Solicitud de Alta de Catastro Recibida - Orden N� '||g_cat.nro_orden;
                      v_txt_mail := 'Se ha realizado una Aprobacion por Workflow, de la Solicitud de Alta de Catastro Recibida - Orden N� '||g_cat.nro_orden ||
                                    chr(10) || 'Codigo de Servicio Nro.' || g_cat.cod_servicio ||
                                    chr(10) ||
                                    'El mensaje de Aprobacion fue enviado a la entidad: '||g_cat.cod_swi_pte_solicitante  ||
                                     chr(10) || chr(10) || 'Atentamente.';

                      it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                    EXCEPTION
                      when others then
                        NULL;
                    END;
                  end if;
                  elsif g_cat.fec_recepcion is not NULL and p_tip_accion in ('C','X') then --rechazada desde el WF y rechazada automaticamente
                      -- Actualizar la Solicitud de Catastro Catastro Recibida y Rechazada
                      begin
                        update sb_snp_catastros c
                           set c.estado = 'R',
                               c.situacion = 'RR',
                               c.fec_rechazo = sysdate --pag_cal.fu_obt_fec_actual(1)
                         where c.nro_orden = g_cat.nro_orden;

                         if SQL%ROWCOUNT = 0 then
                            raise_application_error( -20101, 'No se han encontrado datos de la Solicitud de Catastro a actualizar - Orden N� '||g_cat.nro_orden);
                         end if;
                      end;

                       /* if v_dir_correo is not null then
                            BEGIN
                              --Envio notificacion
                              v_tip_can:=CASE WHEN p_tip_accion='C'  THEN 'por Workflow ' WHEN p_tip_accion='X' THEN 'automatico ' END;

                              v_asunto   := 'Notificacion de Rechazo de Solicitud de Alta de Catastro Recibida - Orden N� '||g_cat.nro_orden;
                              v_txt_mail := 'Se ha realizado un Rechazo '|| v_tip_can|| 'de la Solicitud de Alta de Catastro Recibida - Orden N� '||g_cat.nro_orden ||
                                            chr(10) || 'Codigo de Servicio Nro.' || g_cat.cod_servicio ||
                                            chr(10) ||
                                             'El motivo de rechazo es: '||g_cat.error;

                              it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                            EXCEPTION
                              when others then
                                NULL;
                            END;
                          end if;*/
                   end if;
        else --
              if g_cat.fec_recepcion is not null and p_tip_accion = 'A' then
                -- Actualizar la Solicitud de Catastro Recibida y Aprobada
                   update sb_snp_catastros c
                      set c.estado = 'C',
                          c.situacion = 'RC',
                          c.fec_autorizacion = trunc(sysdate),
                          c.fec_cancelacion = sysdate
                    where c.nro_orden = g_cat.nro_orden;
                   if v_dir_correo is not null then
                      begin
                            /*Envio notificacion*/
                            v_asunto   := 'Notificacion de Aprobacion de Solicitud de Cancelacion de Catastro - Orden N� '||g_cat.nro_orden;
                            v_txt_mail := 'Se ha realizado una Aprobacion por Workflow, de la Solicitud de Cancelaci?n de Catastro Recibida - Orden N� '||g_cat.nro_orden ||
                                       chr(10) || 'Codigo de Servicio Nro.' || g_cat.cod_servicio ||
                                       chr(10) ||
                                       'El mensaje de Aprobacion fue enviado a la entidad: '||g_cat.cod_swi_pte_solicitante  ||
                                       chr(10) || chr(10) || 'Atentamente.';

                           it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                       exception
                          when others then
                              NULL;
                       end;
                  end if;
               elsif  g_cat.fec_recepcion is NOT NULL and p_tip_accion in ('C','X') then
                      if v_dir_correo is not null then
                         begin
                              /*Envio notificacion*/
                              v_tip_can:=CASE WHEN p_tip_accion='C'  THEN 'por Workflow ' WHEN p_tip_accion='X' THEN 'automatico ' END;

                              if g_ref_invalida then
                                 v_asunto   := 'Notificacion de Rechazo de Solicitud de Cancelacion de Catastro - Ref. Nro. '||g_cat.nro_referencia;
                                 v_txt_mail := 'Se ha realizado un Rechazo '|| v_tip_can|| 'de la Solicitud de Cancelaci?n de Catastro Recibida -Referencia Nro. '||g_cat.nro_referencia||
                                               chr(10) || 'La referencia mencionada no se encuentra registada en la entidad' ||chr(10) ||
                                               'El mensaje de Rechazo fue enviado a la entidad: '||g_cat.cod_swi_pte_solicitante  ||
                                               chr(10) || chr(10) || 'Atentamente.';
                              else

                                  v_asunto   := 'Notificacion de Rechazo de Solicitud de Cancelacion de Catastro - Orden N� '||g_cat.nro_orden;
                                  v_txt_mail := 'Se ha realizado un Rechazo '|| v_tip_can|| 'de la Solicitud de Cancelaci?n de Catastro Recibida - Orden N� '||g_cat.nro_orden ||
                                             chr(10) || 'Codigo de Servicio Nro.' || g_cat.cod_servicio ||
                                             chr(10) ||
                                             'El mensaje de Rechazo fue enviado a la entidad: '||g_cat.cod_swi_pte_solicitante  ||
                                             chr(10) || chr(10) || 'Atentamente.';
                              end if;
                              it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);

                          exception
                              when others then
                                NULL;
                          end;
                       end if;
               end if;
            end if;
        end if;
EXCEPTION
  when ex_salir then
     pas_snp.g_cod_error := 70;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_CATASTRO: '||g_lugar||' - '||fu_obt_msj_error;

  when others then
     pas_snp.g_cod_error := 70;
     pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_MSJ_CATASTRO: '||g_lugar||' - '||sqlerrm;
END pr_obt_msj_catastro;
PROCEDURE pr_obt_dat_catastro(p_valor in varchar2, p_filtro in varchar2) is
  /*
  || Recupera los datos del catastro.

  */
  v_sentencia varchar2(10000);
  type t_cur is ref cursor;
  cu_msj_cat t_cur;
  v_mensaje  varchar2(200);

BEGIN
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;

   /*Inicializa variables del tipo ROWTYPE*/
   pas_snp.pr_ini_registros;

   g_lugar := 'Obteniendo datos de SB_SNP_CATASTROS, ';

   v_sentencia:='
                select  t.nro_orden,
                t.estado,
                t.origen,
                t.cod_mensaje,
                t.cod_moneda,
                t.monto,
                t.ind_mto_fijo,
                t.fec_vencimiento,
                t.tip_rechazo,
                t.dia_envio,
                t.cod_per_solicitante,
                t.cod_tip_doc_solicitante,
                t.nro_doc_solicitante,
                t.cod_tip_per_solicitante,
                t.nom_solicitante,
                t.dir_solicitante,
                t.cod_swi_pte_solicitante,
                t.nro_cta_pte_solicitante,
                t.nro_cta_solicitante,
                t.cod_per_receptor,
                t.cod_tip_doc_receptor,
                t.nro_doc_receptor,
                t.cod_tip_per_receptor,
                t.nom_receptor,
                t.dir_receptor,
                t.cod_swi_pte_receptor,
                t.nro_cta_pte_receptor,
                t.nro_cta_receptor,
                t.usu_insercion,
                t.fec_insercion,
                t.usu_modificacion,
                t.fec_modificacion,
                t.nro_referencia,
                t.nro_ref_externa,
                t.fec_registro,
                t.titular_servicio,
                t.cod_servicio,
                t.can_cuotas,
                t.fec_recepcion
                from sb_snp_catastros t where';

   case p_filtro
        when 'O' then
             v_sentencia:=v_sentencia||' '||'t.nro_orden='||p_valor;
             v_mensaje  :='Nro. Orden: '||p_valor;
        when 'R' then
             v_sentencia:=v_sentencia||' '||'t.nro_referencia='||''''||p_valor||'''';
             v_mensaje  :='Nro. Referencia: '||p_valor;
        else
             pas_snp.g_msj_error := 'Los filtros habilitados son O-Nro. Orden y R-Referencia';
             pas_snp.g_cod_error := 16;
        end case;

   if cu_msj_cat%isopen then
      close cu_msj_cat;
   END if;

   open cu_msj_cat for v_sentencia;

   fetch cu_msj_cat into
       g_cat.nro_orden,
       g_cat.estado,
       g_cat.origen,
       g_cat.cod_mensaje,
       g_cat.cod_moneda,
       g_cat.monto,
       g_cat.ind_mto_fijo,
       g_cat.fec_vencimiento,
       g_cat.tip_rechazo,
       g_cat.dia_envio,
       g_cat.cod_per_solicitante,
       g_cat.cod_tip_doc_solicitante,
       g_cat.nro_doc_solicitante,
       g_cat.cod_tip_per_solicitante,
       g_cat.nom_solicitante,
       g_cat.dir_solicitante,
       g_cat.cod_swi_pte_solicitante,
       g_cat.nro_cta_pte_solicitante,
       g_cat.nro_cta_solicitante,
       g_cat.cod_per_receptor,
       g_cat.cod_tip_doc_receptor,
       g_cat.nro_doc_receptor,
       g_cat.cod_tip_per_receptor,
       g_cat.nom_receptor,
       g_cat.dir_receptor,
       g_cat.cod_swi_pte_receptor,
       g_cat.nro_cta_pte_receptor,
       g_cat.nro_cta_receptor,
       g_cat.usu_insercion,
       g_cat.fec_insercion,
       g_cat.usu_modificacion,
       g_cat.fec_modificacion,
       g_cat.nro_referencia,
       g_cat.nro_ref_externa,
       g_cat.fec_registro,
       g_cat.titular_servicio,
       g_cat.cod_servicio,
       g_cat.can_cuotas,
       g_cat.fec_recepcion;

   if cu_msj_cat%notfound then
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_DAT_CATASTRO, no se encuentran datos para '||v_mensaje;
      pas_snp.g_cod_error := 17;
   end if;
   close cu_msj_cat;
EXCEPTION
   When Others then
      pas_snp.g_msj_error := 'Error en PAS_SNP.PR_OBT_DAT_CATASTRO '||sqlerrm;
      pas_snp.g_cod_error := 16;
END pr_obt_dat_catastro;
FUNCTION fu_obt_reg_catastros return rg_cat
IS
   /*
   || Obtiene el registro G_CAT que contiene los datos de SB_SNP_CATASTROS
   */
BEGIN
  return pas_snp.g_cat;
END;
 /* Procesa la mensajeria RECIBIDA - MT104.*/
FUNCTION fu_pro_msj_mt104( p_mensaje in long ) return varchar2
IS
   /*
   || Procesa la mensajeria MT104 recibida, realiza validaciones, verifica si existe en los catastros
   || Se Inserta en ge_snp_transferencias y en sb_snp_catastros_det
   || Si corresponde Genera MT-192 de rechazo total o Genera MT-198 de rechazo parcial( inserta en ge_snp_mensajes)
   */
   rg_msj_cab             pas_snp.rg_msj := null;
   rg_msj_det             pas_snp.rg_msj := null;
   rg_msj_env             pas_snp.rg_msj := null;
   rg_dat_pte             pas_snp.rg_pte := null;
   --v_nro_reversion        ge_snp_transferencias.nro_ref_externa%type;
   --v_nro_sec_lote         ge_snp_transferencias.nro_sec_lote%type;
   v_cta_cliente          ge_snp_transferencias.nro_cta_beneficiario%type;
   v_monto                ge_snp_transferencias.monto%type;
   v_cod_moneda           ge_snp_transferencias.cod_moneda%type := null;
   v_nro_cuenta           ge_cuentas.nro_cuenta%type;
   v_cod_tip_doc_ben      ge_snp_transferencias.cod_tip_doc_beneficiario%type;
   v_cab_msj_error        varchar2(4000) := null;
   v_texto                varchar2(4000) := null;
   v_sql                  varchar2(4000) := null;
   v_campo_70             varchar2(4000)  := null;
   v_cod_ser              varchar2(200)  := null;
   v_campo_77             varchar2(200)  := null;
   v_campo_72             varchar2(200)  := null;
   v_tip_rec_error        varchar2(100)  := null;
   v_linea                varchar2(100)  := null;
   v_tip_doc              varchar2(5)    := null;
   v_ind_reversion        varchar2(1)    := 'N';
   v_ind_rev_manual       varchar2(1)    := 'N';
   v_ban_error            varchar2(1)    := 'N';
   v_can_lineas           number         := 0;
   v_pos_ini              number         := 0;
   v_pos_fin              number         := 0;
   v_pos_reg_ini          number         := 0;
   v_pos_reg_fin          number         := 0;
   v_dia_deb_confirmacion     number := fug_obt_pardinamico('SNP_DIA_DEB_CONFIRMACION');
   v_est_cuenta               ge_cuentas.estado%type;    -- Estado Cta.
   v_sal_disponible           ge_movimientos.monto%type; -- Sal.Dispon.
   v_procesa                  varchar2(1);        -- Procesar Operacion (S/N).
   v_mto_maximo               sb_snp_catastros.monto%type;
   v_mto_mt_limite            number := nvl(fug_obt_pardinamico('MTO_MAX_ACH'), 0);
   v_can_transferencias       number := 0;
   v_can_tra_errores          number := 0;
   v_msj_retorno              varchar2(300);
   v_mto_total                ge_snp_transferencias.monto%type;
   v_cod_swi_pte_solicitante  ge_snp_transferencias.cod_swi_pte_solicitante%type;
   v_nro_orden                sb_snp_catastros.nro_orden%type;
   v_mot_rch                  varchar2(4000):= null;
   v_mot_rechazo              sb_snp_catastros.tip_rechazo%type;
   v_fec_liq                  ge_calendarios.fec_proxima%type;
   v_pri_dia_mes              date;
   v_ult_dia_mes              date;
   v_cant_debitos             number(2);
   v_cant_deb_mes             number(2);
   v_can_cuotas               sb_snp_catastros.can_cuotas%type;
   v_est_periodo              ge_snp_horarios.estado%type;
   v_err_est                   number(2):=24;
   v_mot_rch_for              constant varchar2(03) := '014';
   v_mot_rch_sal              constant varchar2(03) := '007';
   v_mot_deb_aut              constant varchar2(03) := '008';
   v_mot_hor_ina              constant varchar2(03) := '013';
    cursor c_errores is
      select b.nro_ref_externa,
             b.nro_referencia,
             b.monto,
             b.nro_sec_lote,
             b.tip_rechazo
        from ge_snp_transferencias b
       where b.nro_lote = rg_msj_cab.nro_lote
         and b.cod_msj_swift = rg_msj_cab.cod_msj_swift
         and b.situacion = 'E'
         and b.fec_ingreso = g_fec_actual;
       cursor c_transferencias is
      select b.nro_ref_externa,
             b.nro_referencia,
             b.monto
        from ge_snp_transferencias b
       where b.nro_lote = rg_msj_cab.nro_lote
         and b.cod_msj_swift = rg_msj_cab.cod_msj_swift
         and b.fec_ingreso = g_fec_actual;
BEGIN
     --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
     pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
     --
     /*Inicializa las variables de error*/
     pas_snp.pr_ini_variables;

     /*Inicializa las variables del tipo ROWTYPE*/
     pas_snp.pr_ini_registros;

     /*
     || En esta variable se almacenara todos los errores encontrados y
     || se depositara en el campo error de GE_SNP_TRANSFERENCIAS.
     */
     pas_snp.g_det_msj_error := null;

	 if v_dia_deb_confirmacion=0 then
       v_fec_liq:= g_fec_actual;
     else
       v_fec_liq:= pag_cal.fu_obt_fec_proxima(1);
     end if;
     if p_mensaje is null then
        pas_snp.g_cod_error := 40;
        pas_snp.g_msj_error := 'Error en PAS_SNP.FU_PRO_MSJ_MT104. Valor para P_MENSAJE debe contener algun valor.!';
        pas_snp.pr_set_texto ( g_det_msj_error, pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     -- ****************************** cabecera del mensaje ********************************************
     g_lugar :=  'Obteniendo cabecera del mensaje, ';
     pas_snp.pr_pro_cab_msj_swift( p_mensaje, rg_msj_cab );
     if pas_snp.fu_obt_cod_error <> 0 then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;

     -- ****************************** cuerpo del mensaje **********************************************
     /**/-- 20: Referencia del remitente
     g_lugar :=  'Obteniendo campo :20:, ';
     rg_msj_cab.nro_lote        := ltrim(rtrim(substr(pas_snp.fu_pro_val_tag(p_mensaje, '20','N'),1,length(pas_snp.fu_pro_val_tag(p_mensaje, '20','N'))-1)));
     rg_msj_cab.nro_sec_lote    := null;
     rg_msj_cab.nro_ref_externa := null;
     rg_msj_cab.cod_msj_swift   := 104;

     if rg_msj_cab.nro_lote is null then
         pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Nro. Lote no puede ser nulo.!', pas_snp.fu_obt_salto );
     end if;

     /**/-- 23E: Tipo de mensaje
     g_lugar :=  'Obteniendo campo :23:, ';
     rg_msj_cab.tip_mensaje := substr(pas_snp.fu_pro_val_tag(p_mensaje, '23E'),1,4);
     if nvl(rg_msj_cab.tip_mensaje,'x') <> 'NAUT' then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tip. Mensaje no esta correcto.!', pas_snp.fu_obt_salto );
     end if;

     /**/-- 32: Fecha en que se recibe el lote, en formato YYMMDD.
     g_lugar :=  'Obteniendo campo :30:, fecha: ';
     rg_msj_cab.fec_recepcion := sysdate;
     rg_msj_cab.fec_valor     := to_date(substr(pas_snp.fu_pro_val_tag(p_mensaje, '30'),1,6),'RRMMDD');
     rg_msj_cab.fec_ingreso   := g_fec_actual;

     -- Verifica que la fecha valor no sea menor a la fecha calendario del sistema
     if rg_msj_cab.fec_valor <> g_fec_actual then
        g_lugar :=  'Validando fecha valor de la mensajeria, ';
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'fecha valor no puede ser distinto a '||to_char(g_fec_actual,'DD/MM/YYYY'), pas_snp.fu_obt_salto );
     end if;

     /**/-- 26T: Codigo del tipo de transaccion
     g_lugar :=  'Obteniendo campo :26T:, ';
     rg_msj_cab.cod_tip_operacion := substr(pas_snp.fu_pro_val_tag(p_mensaje,'26T'),1,3);
     v_sql := 'SELECT ''S'' '||
              'FROM   GE_SNP_PAR_MENSAJES '||
              'WHERE  COD_TIP_OPERACION = ' ||rg_msj_cab.cod_tip_operacion||' '||
              'AND    ROWNUM = 1';
     if not fu_val_dat_ingresado(v_sql) then
        pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Tip. Operacion no esta correcto. ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
     end if;
     /**/-- 72: Informacion del Remitente al Receptor
     g_lugar :=  'Obteniendo campo :72:, ';
     v_campo_72 := pas_snp.fu_pro_val_tag(p_mensaje,'72','N');
     if v_campo_72 is not null then
        if instr(v_campo_72,'/CODTYPTR/',1) > 0 then --Existe Tipo y/o Sub Tipo de Operacion
           v_pos_ini := instr(v_campo_72,'/CODTYPTR/',1) + 10;
           v_pos_fin := instr(v_campo_72,pas_snp.fu_obt_sal_socket,v_pos_ini);
           v_texto   := nvl(ltrim(rtrim(substr(v_campo_72,v_pos_ini,v_pos_fin - v_pos_ini))),' ');
           if instr(v_texto,'/',1) > 0 then --Tiene Tipo y Sub Tipo de Operacion
              v_pos_ini := instr(v_texto,'/',1) + 1;
              rg_msj_cab.cod_sub_tip_operacion := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini));
              --Verifica si campo 26T es igual a lo definido en el campo 72 (Tipo de Operacion)
              if nvl(rg_msj_cab.cod_tip_operacion,'x') <>
                 nvl(pas_snp.fu_val_cadena(substr(v_texto,1,instr(v_texto,'/')-1)),'.')
              then
                 pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, El campo 26T y 72 estan inconsistentes - (Tipo de Operacion)', pas_snp.fu_obt_salto );
              end if;
           else
              --Verifica si campo 26T es igual a lo definido en el campo 72 (Tipo de Operacion)
              if nvl(rg_msj_cab.cod_tip_operacion,'x') <>
                 nvl(pas_snp.fu_val_cadena(v_texto),'.')
              then
                 pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, El campo 26T y 72 estan inconsistentes - Tipo de Operacion', pas_snp.fu_obt_salto );
              end if;
           end if;
           --Si el campo 26T y el campo 72 estan consistentes, se verifica los datos en GE_PAR_MENSAJES
           if not fu_val_par_mensajes( rg_msj_cab.cod_msj_swift,
                                       rg_msj_cab.cod_tip_operacion,
                                       rg_msj_cab.cod_sub_tip_operacion )
           then
              pas_snp.pr_set_texto ( g_det_msj_error, 'Verificando consistencia, Campo(s) Tip.Operacion y/o Sub Tip.Operacion no se encuentra(n) en GE_SNP_PAR_MENSAJES ', pas_snp.fu_obt_salto );
           end if;
        end if;

        --Si existe valor para el campo 72, se busca el valor a partir de la segunda linea
        if instr(v_campo_72,'/CODTYPTR/',1) > 0 then
           rg_msj_cab.observacion := substr(v_campo_72,
                                            instr(v_campo_72,pas_snp.fu_obt_sal_socket,instr(v_campo_72,'/CODTYPTR/',1)+10) + 1
                                           );
        else
           rg_msj_cab.observacion := substr(v_campo_72,
                                            instr(v_campo_72,pas_snp.fu_obt_sal_socket,1)
                                           );
        end if;
        if rg_msj_cab.observacion is not null then
           -- Se quita el g_sal_socket en caso que haya duplicados.
           begin
              rg_msj_cab.observacion := pas_snp.fu_val_cadena(replace(fug_ver_cad_multilinea(rg_msj_cab.observacion,
                                                                                             pas_snp.fu_obt_sal_socket,
                                                                                             5,
                                                                                             35
                                                                                            ),
                                                                      pas_snp.fu_obt_sal_socket,
                                                                      pas_snp.fu_obt_salto
                                                                     )
                                                             );
           exception
              when others then
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || ' ' || sqlerrm || ' ' , pas_snp.fu_obt_salto );
           end;
        end if;
     end if;

     pas_snp.pr_set_texto ( v_cab_msj_error, g_det_msj_error, pas_snp.fu_obt_salto );
     if v_cab_msj_error is not null then
        v_ban_error := 'S';
     end if;

     /**/-- Obtiene los datos del detalle de la operacion.
    FOR i IN 1..999999 LOOP
        rg_msj_det             := null;
        rg_msj_env             := null;
        rg_dat_pte             := null;
        rg_msj_det             := rg_msj_cab;
        g_det_msj_error        := null;
        v_tip_rec_error        := null;
        v_pos_reg_fin          := 0;
        v_ind_reversion        := 'N';
        v_ind_rev_manual       := 'N';
        v_cta_cliente          := null;
        v_monto           := 0;
        pas_snp.pr_ini_registros;
        --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
        pre_cam_for_numerico(',.');
        --

      /*
        || Si encuentra la posicion :21:, busca la siguiente posicion :21: o
        || si es fin de archivo busca la posicion del :32A:
        */
        v_pos_reg_ini := instr(p_mensaje,':21:', 1, i);

        if v_pos_reg_ini = 0 then
           exit;
        else
           v_pos_reg_fin := instr(p_mensaje,':21:', 1, i+1);

           if v_pos_reg_fin = 0 then
              v_pos_reg_fin := instr(p_mensaje,'-}', i, 1);
           end if;
        end if;

        g_lugar := 'Obteniendo el mensaje parcial, ';
        rg_msj_det.msj_swift := replace( ltrim( rtrim( substr( p_mensaje, v_pos_reg_ini, v_pos_reg_fin - v_pos_reg_ini ) ) ),pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );

         /**/-- 20: Referencia del remitente
        g_lugar :=  'Obteniendo campo :21:, ';
        rg_msj_det.nro_ref_externa := trim(substr(pas_snp.fu_pro_val_tag(p_mensaje, '21','N',1,i),1,length(pas_snp.fu_pro_val_tag(p_mensaje, '21','N',1,i))-1));
        rg_msj_det.nro_sec_lote    := rg_msj_det.nro_ref_externa;
        if rg_msj_det.nro_ref_externa is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Nro. Ref. Externa no puede ser nulo.!', pas_snp.fu_obt_salto );
        end if;

        g_lugar :=  'Obteniendo campo :32B:, cod_moneda: ';
        v_cod_moneda := substr(pas_snp.fu_pro_val_tag(p_mensaje, '32B','N',1,i),1,3);
        v_cod_moneda := CASE v_cod_moneda WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE v_cod_moneda END;
        rg_msj_det.cod_moneda := v_cod_moneda;
        v_sql := 'SELECT ''S'' '||
                 'FROM   BA_MONEDAS '||
                 'WHERE  COD_MONEDA = '||''''||rg_msj_det.cod_moneda||'''';
        if not fu_val_dat_ingresado(v_sql) then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Cod. Moneda no esta correcto. ' || pas_snp.fu_obt_msj_error, pas_snp.fu_obt_salto );
        end if;

        g_lugar :=  'Obteniendo campo :32B:, monto: ';
        rg_msj_det.monto := to_number(replace(replace(substr(pas_snp.fu_pro_val_tag(p_mensaje, '32B','N',1,i),4),'.',','),pas_snp.fu_obt_sal_socket));
        if rg_msj_det.monto is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo Monto no puede ser nulo.!', pas_snp.fu_obt_salto );
        end if;

         /**/--:52a: Cuenta y BIC del participante origen
        g_lugar :=  'Obteniendo campo :52a:, Datos del Participante Solicitante. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'52a','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Participante Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'52a','N',1,i);
        end if;

        g_lugar :=  'Obteniendo campo :52a:, Cta. Participante Solicitante. ';
        v_pos_ini := instr(v_texto,'/D/');
        if v_pos_ini = 0 then
           v_pos_ini := instr(v_texto,'/')+1;
        else
           v_pos_ini := instr(v_texto,'/D/')+3;
        end if;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
        rg_msj_det.nro_cta_pte_solicitante := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Obteniendo campo :52a:, BIC Participante Solicitante. ';
        v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
        rg_msj_det.cod_swi_pte_solicitante := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));
         g_lugar :=  'Obteniendo Datos del Participante Solicitante,  ';
              pas_snp.pr_obt_dat_participante( rg_msj_det.cod_swi_pte_solicitante,
                                               rg_dat_pte
                                             );
         /**/-- :57a: Cuenta y BIC del participante destino,
        g_lugar :=  'Obteniendo campo :57a:, Datos del Participante Beneficiario. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'57a','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'57a','N',1,i);
        end if;

        g_lugar :=  'Obteniendo campo :57a:, Cta. Participante Beneficiario. ';
        v_pos_ini := instr(v_texto,'/C/');
        if v_pos_ini = 0 then
           v_pos_ini := instr(v_texto,'/')+1;
        else
           v_pos_ini := instr(v_texto,'/C/')+3;
        end if;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket);
        rg_msj_det.nro_cta_pte_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Obteniendo campo :57a:, BIC Participante Beneficiario. ';
        v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket)+1;
        v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
        rg_msj_det.cod_swi_pte_beneficiario := pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini));

        g_lugar :=  'Validando BIC del Participante Beneficiario, ';
        if instr(p_mensaje,'57C:/') = 0 then
        if rg_msj_det.cod_swi_pte_beneficiario is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado al BIC del Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else  --Valida que el BIC exista en ITGF
           pr_val_cod_swi_participante( rg_msj_det.cod_swi_pte_beneficiario );
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           end if;
        end if;
        end if;
        g_lugar :=  'Validando Cta. del Participante Beneficiario, ';
        if rg_msj_det.nro_cta_pte_beneficiario is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Participante Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else --Valida que la cuenta del PTE. BENEFICIARIO exista en ITGF
           if rg_msj_det.nro_cta_pte_beneficiario <> pas_snp.fu_obt_cta_bancaria( pas_snp.fu_obt_cta_bancaria( rg_msj_det.nro_cta_pte_beneficiario, 'C' ), 'B' ) then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Participante Beneficiario no esta definido en GE_PAR_DINAMICOS para la moneda ' || rg_msj_det.cod_moneda , pas_snp.fu_obt_salto );
           end if;
           if pas_snp.fu_obt_cod_error <> 0 then --Envia el error generado por FUG_OBT_PARDINAMICO
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
           end if;
        end if;

        /**/-- :50a: Datos del Ordenante
        g_lugar :=  'Obteniendo campo :50K:, Datos del Cliente Solicitante. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'50K','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Cliente Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'50K','N',1,i);

           -- 1ra. linea (Cuenta Solicitante)
           g_lugar :=  'Obteniendo campo :50K:, Cta. Cli. Solicitante. ';
           v_pos_ini := instr(v_texto,'/')+1;
           v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1);
           rg_msj_det.nro_cta_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,35);
           if rg_msj_det.nro_cta_solicitante is null then
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Cliente Solicitante no puede ser nulo.!', pas_snp.fu_obt_salto );
           end if;

           if nvl( rg_dat_pte.ind_val_fmt_msj_recibido, 'S' ) = 'N' then
              -- Si no se valida sintaxis de la mensajeria el PAS_SNP debe completar los datos a partir de la 2da. linea
              rg_msj_det.cod_tip_doc_solicitante := rg_dat_pte.cod_tip_doc_persona;
              rg_msj_det.nro_doc_solicitante     := rg_dat_pte.nro_doc_persona;
              rg_msj_det.nom_solicitante         := rg_dat_pte.nom_persona;
              rg_msj_det.dir_solicitante         := rg_dat_pte.dir_persona;
           else -- Se debe validar sintaxis de la mensajeria.
            /*
             || Se cuenta la cantidad de lineas que tiene el TAG :50K:
             || (2 lineas OBLIGATORIAS)
             || (3 lineas OPCIONALES)
             */
             v_can_lineas := ( length( v_texto ) -
                               length( replace( v_texto, pas_snp.fu_obt_sal_socket ) )
                             ) / nvl( length( pas_snp.fu_obt_sal_socket ), 1 );

             if v_can_lineas < 2 or
                v_can_lineas > 5
             then -- Controla las lineas permitidas
                pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo :50K: debe contener entre 2 y 5 lineas OBLIGATORIAS.!', pas_snp.fu_obt_salto );
             else
                -- 2da. linea (Tipo y Nro. Doc. Solicitante)
                g_lugar :=  'Obteniendo campo :50K:, Tipo y Nro. Doc. Solicitante.. ';
                v_tip_doc := null;
                v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1)+1;
                v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
                v_linea   := ltrim(rtrim(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)));

                v_tip_doc := nvl( substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 4 ), 'RUC' );
                begin -- Recupera el Cod. Tip. Documento, cualquier error retorna el codigo para RUC
                  begin
                    if fue_val_es_numerico( fue_obt_tip_documento( v_tip_doc ) ) = 'S' then
                       rg_msj_det.cod_tip_doc_solicitante := fue_obt_tip_documento( v_tip_doc );
                       rg_msj_det.nro_doc_solicitante     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 2, '/' ) ), 1, 20 );
                       ---rg_msj_det.cod_per_solicitante    := rg_dat_pte.cod_persona;
                    else -- Registra el tipo de documento como RUC en caso de no encontrar en ITGF
                       raise ex_salir;
                    end if;
                  exception
                    when ex_salir then
                      raise;
                    when others then
                      raise;
                  end;
                exception
                  when others then
                    rg_msj_det.cod_tip_doc_solicitante := fue_obt_tip_documento( 'RUC' );
                    rg_msj_det.nro_doc_solicitante     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 20 );
                end;

                -- Valida la 2da. linea, ya que son OBLIGATORIOS
                if rg_msj_det.cod_tip_doc_solicitante is null then
                   pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Tipo de Documento del Solicitante con el formato <XXX>/.!', pas_snp.fu_obt_salto );
                end if;

                if rg_msj_det.nro_doc_solicitante is null then
                   pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Nro. Documento del Solicitante.!', pas_snp.fu_obt_salto );
                end if;

                -- 3ra. linea (Denominacion de la Cuenta)
                g_lugar :=  'Obteniendo campo :50K:, Nom. Cli. Solicitante. 1ra. linea';
                v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2)+1;
                v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3);
                rg_msj_det.nom_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,120);

                -- 4ta. linea (Direccion de la Cuenta)
                g_lugar :=  'Obteniendo campo :50K:, Dir. Solicitante. ';
                v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3)+1;
                v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,4);
                rg_msj_det.dir_solicitante := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,100);

             end if;
           end if;
        end if;

        rg_msj_det.cod_oficina := fug_obt_ofi_usuario (user);

         /**/-- :59: Datos del Beneficiario
        g_lugar :=  'Obteniendo campo :59:, Datos del Cliente Beneficiario. ';
        if pas_snp.fu_pro_val_tag(p_mensaje,'59','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del Cliente Beneficiario no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else
           v_texto := pas_snp.fu_pro_val_tag(p_mensaje,'59','N',1,i);
           /*
           || Se cuenta la cantidad de lineas que tiene el TAG :59:
           || (2 lineas OBLIGATORIAS)
           || (3 lineas OPCIONALES)
           */
           v_can_lineas := ( length( v_texto ) -
                             length( replace( v_texto, pas_snp.fu_obt_sal_socket ) )
                           ) / nvl( length( pas_snp.fu_obt_sal_socket ), 1 );

           if v_can_lineas < 2 or
              v_can_lineas > 5
           then -- Controla las lineas permitidas
              pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo :59: debe contener entre 2 y 5 lineas OBLIGATORIAS.!', pas_snp.fu_obt_salto );
           else
               /**/-- 1ra. linea (Cuenta Beneficiario)
              g_lugar :=  'Obteniendo campo :59:, Cta. Cli. Beneficiario. 1ra. linea. ';
              v_pos_ini := instr(v_texto,'/')+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1);
              rg_msj_det.nro_cta_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,35);
              if rg_msj_det.nro_cta_beneficiario is null then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a la Cta. Cliente Beneficiario no puede ser nulo.!', pas_snp.fu_obt_salto );
              end if;

               /**/-- 2da. linea (Tipo y Nro. Doc. Beneficiario)
              g_lugar :=  'Obteniendo campo :59:, Tipo y Nro. Doc. Beneficiario. 2da. linea. ';
              --v_tip_doc := null;
              v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,1)+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2);
              v_linea   := ltrim(rtrim(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)));

              v_tip_doc := nvl( substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 4 ), 'RUC' );
              begin -- Recupera el Cod. Tip. Documento, cualquier error retorna el codigo para RUC
                begin
                   if fue_val_es_numerico( fue_obt_tip_documento( v_tip_doc ) ) = 'S' then
                      rg_msj_det.cod_tip_doc_beneficiario := fue_obt_tip_documento( v_tip_doc );
                      rg_msj_det.nro_doc_beneficiario     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 2, '/' ) ), 1, 20 );
                   else -- Registra el tipo de documento como RUC en caso de no encontrar en ITGF
                      raise ex_salir;
                   end if;
                exception
                   when ex_salir then
                     raise;
                   when others then
                     raise;
                end;
              exception
                when others then
                  rg_msj_det.cod_tip_doc_beneficiario := fue_obt_tip_documento( 'RUC' );
                  rg_msj_det.nro_doc_beneficiario     := substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 20 );
              end;

              -- Valida la 2da. linea, ya que son OBLIGATORIOS
              if rg_msj_det.cod_tip_doc_beneficiario is null then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Tipo de Documento del Beneficiario con el formato <XXX>/.!', pas_snp.fu_obt_salto );
              end if;

              if rg_msj_det.nro_doc_beneficiario is null then
                 pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'No se ha encontrado el Nro. Documento del Beneficiario.!', pas_snp.fu_obt_salto );
              end if;

               /**/-- 3ra. linea (Denominacion de la Cuenta)
              g_lugar :=  'Obteniendo campo :59:, Nom. Cli. Beneficiario. 3ra. linea. ';
              v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,2)+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3);
              rg_msj_det.nom_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,120);

               /**/--4ta. linea (Direccion de la Cuenta)
              g_lugar :=  'Obteniendo campo :59:, Dir. Beneficiario. 5ta. linea. ';
              v_pos_ini := instr(v_texto,pas_snp.fu_obt_sal_socket,1,3)+1;
              v_pos_fin := instr(v_texto,pas_snp.fu_obt_sal_socket,1,4);
              rg_msj_det.dir_beneficiario := substr(pas_snp.fu_val_cadena(substr(v_texto,v_pos_ini,v_pos_fin - v_pos_ini)),1,100);

           end if;
        end if;

        rg_msj_det.cod_oficina := fug_obt_ofi_usuario ( user );

        g_lugar :=  'Validando Nro. Cta. del Beneficiario,  ';

        if rg_msj_det.nro_cta_beneficiario is not null then
           -- Valida que la cuenta del beneficiario sea numerico, si es numerico se intenta validar contra ITGF.
           if fue_val_es_numerico( rg_msj_det.nro_cta_beneficiario ) = 'S' then

              --Valida que la cuenta o numero de tarjeta exista en ITGF.
              -- Se verifica si el dato corresponde a una Cta. o a una Tarjeta.
              if length( to_number( rg_msj_det.nro_cta_beneficiario ) ) >= 16 then -- Posiblemente sea un Nro. de Tarjeta.
                 --
                 pas_snp.pr_ver_nro_tarjeta( rg_msj_det.nro_cta_beneficiario, v_nro_cuenta );
                 --
                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
                 end if;

              else -- Es posiblemente una Cuenta en ITGF.
                 -- Si el BIC Solicitante es M. Hacienda no se debe validar el tipo de documento del beneficiario,
                 -- ya que MH siempre enviaria RUC
                 if rg_msj_det.cod_swi_pte_solicitante = g_bic_hacienda then
                    v_cod_tip_doc_ben := NULL;
                 else
                    v_cod_tip_doc_ben := rg_msj_det.cod_tip_doc_beneficiario;
                 end if;

                 pas_snp.pr_obt_cta_interna( rg_msj_det.nro_cta_beneficiario,
                                             v_cod_tip_doc_ben,
                                             rg_msj_det.nro_doc_beneficiario,
                                             v_nro_cuenta,
                                             rg_msj_det.cod_per_beneficiario
                                           );
                 --
                 if pas_snp.fu_obt_cod_error <> 0 then
                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
                 end if;
                 --
              end if;

              if v_nro_cuenta is not null then
                 pag_cta.pr_obt_cuenta( v_nro_cuenta );

                 if pag_cta.fu_obt_cod_error <> 0 then
                    --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                    pas_snp.g_cod_error := pag_cta.fu_obt_cod_error;
                    pas_snp.g_msj_error := pag_cta.fu_obt_msj_error;

                    pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error||pas_snp.fu_obt_salto );
                 else
                    rg_msj_det.nro_cta_beneficiario := pag_cta.g_ctas.nro_cuenta;
                    rg_msj_det.cod_per_beneficiario := nvl( rg_msj_det.cod_per_beneficiario, pag_cta.g_ctas.cod_cliente );
                    rg_msj_det.cod_oficina          := pag_cta.g_ctas.cod_oficina;
                 end if;

                  if pag_cta.g_ctas.cod_moneda != rg_msj_det.cod_moneda then
                     pas_snp.g_cod_error := 66;
                     pas_snp.pr_set_texto( pas_snp.g_msj_error, 'No coincide moneda transferencia con moneda de cta', '. ' );
                  end if;
                                --
                  if pas_snp.fu_obt_cod_error <> 0 then
                     pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || pas_snp.fu_obt_cod_error || ' - ' || pas_snp.fu_obt_msj_error , pas_snp.fu_obt_salto );
                  end if;

              end if;
           end if;
        end if;

        /**/-- :70: Codigo de servicio--DA-7712
        g_lugar :=  'Obteniendo campo :70:, Codigo de servicio';
        if pas_snp.fu_pro_val_tag(p_mensaje,'70','N',1,i) is null then
           pas_snp.pr_set_texto ( g_det_msj_error, g_lugar || 'El campo relacionado a los Datos del servicio no puede ser nulo.!' , pas_snp.fu_obt_salto );
        else
           v_campo_70 := pas_snp.fu_pro_val_tag(p_mensaje,'70','N',1,i);
           /*
           || Se cuenta la cantidad de lineas que tiene el TAG :70:
           */
           v_can_lineas := ( length( v_campo_70 ) -
                             length( replace( v_campo_70, pas_snp.fu_obt_sal_socket ) )
                           ) / nvl( length( pas_snp.fu_obt_sal_socket ), 1 );

           --if v_can_lineas <= 1 then
               v_pos_ini := instr(v_campo_70,'/')+1;
               v_pos_fin := instr(v_campo_70,pas_snp.fu_obt_sal_socket,1,1);
               v_linea   := ltrim(rtrim(substr(v_campo_70,v_pos_ini,v_pos_fin - v_pos_ini)));
              begin
               select substr(v_linea,8,v_pos_fin) into rg_msj_det.ref_oid  from dual where  v_linea like 'CODSER/%';
               exception
                  when no_data_found then
                   rg_msj_det.ref_oid      := substr( trim( pao_pmt.fu_obt_linea( v_linea, 1, '/' ) ), 1, 20 );
                  when others then
                    null;
              end;

        end if;
         /**/-- 77: Informacion adicional
        g_lugar :=  'Obteniendo campo :77B:, Observacion. ';
        v_campo_77 := substr(substr(pas_snp.fu_pro_val_tag(p_mensaje,'77B','N',1,i),1),1,100);
        rg_msj_det.observacion :=v_campo_77;


        -- ********************************* fin del texto ************************************************

        -- Concatena los errores de la cabecera de la mensajeria.
        if v_ban_error = 'S' then
           pas_snp.pr_set_texto ( rg_msj_det.error, v_cab_msj_error, pas_snp.fu_obt_salto );
        end if;

        -- Concatena los errores del detalle de la operacion.
        if g_det_msj_error is not null then
           pas_snp.pr_set_texto ( rg_msj_det.error, g_det_msj_error, pas_snp.fu_obt_salto );
        end if;
        if rg_msj_det.error is null  --Si no tiene errores de validacion y el dia de confirmacion es 0
         /*and v_dia_deb_confirmacion = 0*/ then --Verifico Saldo
         pag_cta.pr_ver_operacion( rg_msj_det.nro_cta_beneficiario,  -- Nro.Cta.
                                   fu_obt_cod_tra_padre,      -- Trx. Padre - Transferencia entre cuentas
                                   fu_obt_cod_mod_padre,      -- Mod.Padre
                                   fu_obt_cod_mad_padre,      -- Mad.Padre
                                   'D',                       -- Tip.Mov.
                                   rg_msj_det.cod_moneda,         -- Cod.Mon.
                                   rg_msj_det.monto,              -- Monto
                                   rg_msj_det.cod_oficina,        -- Ofic.Orig.
                                   rg_msj_det.cod_modulo,         -- Mod.Hijo
                                   rg_msj_det.cod_modalidad,      -- Mad.Hijo
                                   v_est_cuenta,              -- Estado Cta.
                                   v_sal_disponible,          -- Sal.Dispon.
                                   v_procesa                  -- Procesa
                                 );
          if pag_cta.fu_obt_cod_error <> 0 then
            if pag_cta.fu_obt_cod_error=v_err_est then
               pas_snp.pr_set_texto( rg_msj_det.error, pag_cta.fu_obt_msj_error, pas_snp.fu_obt_salto );
             v_mot_rechazo:=v_mot_deb_aut;
            end if;
          end if;
      end if;
      --Valido si existe en los catastros
      declare

         v_ind_mto_fijo   sb_snp_catastros.ind_mto_fijo%type;
      begin
         select c.nro_orden,
                c.monto,
                c.ind_mto_fijo,
                c.can_cuotas
           into v_nro_orden,
                v_mto_maximo,
                v_ind_mto_fijo,
                v_can_cuotas
           from sb_snp_catastros c
          where c.cod_tip_doc_receptor = rg_msj_det.cod_tip_doc_beneficiario
            and to_number(ltrim(replace(replace(trim(c.nro_doc_receptor), '-', ''), '/',''))) = to_number(ltrim(replace(replace(trim(rg_msj_det.nro_doc_beneficiario), '-', ''), '/','')))
            and c.nro_cta_pte_receptor = rg_msj_det.nro_cta_pte_beneficiario
            and to_number(ltrim(replace(replace(trim(c.nro_cta_receptor), '-', ''), '/',''))) = to_number(ltrim(replace(replace(trim(rg_msj_det.nro_cta_beneficiario), '-', ''), '/','')))
            and c.cod_tip_doc_solicitante = rg_msj_det.cod_tip_doc_solicitante
            and to_number(ltrim(replace(replace(trim(c.nro_doc_solicitante), '-', ''), '/',''))) = to_number(ltrim(replace(replace(trim(rg_msj_det.nro_doc_solicitante), '-', ''), '/','')))
            and c.nro_cta_pte_solicitante= rg_msj_det.nro_cta_pte_solicitante
            and c.estado = 'A' --Aprobado
            and c.cod_servicio=rg_msj_det.ref_oid;

         -- Validaciones monto fijo variable DA-7712
         if v_ind_mto_fijo = 'N'
           and rg_msj_det.monto > v_mto_maximo then
            pas_snp.pr_set_texto( rg_msj_det.error, 'Monto de la Transferencia es superior al Monto Maximo Catastrado.', pas_snp.fu_obt_salto );
         elsif v_ind_mto_fijo = 'S'  then

           if  rg_msj_det.monto != v_mto_maximo then
            pas_snp.pr_set_texto( rg_msj_det.error, 'Monto de la Transferencia es Diferente al Monto Fijo Catastrado.', pas_snp.fu_obt_salto );
           else
              --Valida que la solicitud de debito se encuentre dentro de la cantidad de cuotas solicitado
            begin
              select count(*)
                into v_cant_debitos
                from sb_snp_catastros_det d, sb_snp_catastros c
               where d.nro_orden = c.nro_orden
                 and c.cod_servicio = rg_msj_det.ref_oid
                 and d.estado in ('P', 'L', 'O');
            exception
              when no_data_found then
                v_cant_debitos := 0;
              when others then
                 v_cant_debitos := 0;
            end;
            if v_cant_debitos > v_can_cuotas then
              pas_snp.pr_set_texto( rg_msj_det.error, 'Cantidad de solicitudes MT104 recibidas superan cantidad de cuotas del catastro.', pas_snp.fu_obt_salto );
              v_mot_rechazo:=v_mot_deb_aut;
           end if;
         end if;
         end if;

         -- Control del monto contra el monto maximo definido para ACH
         if rg_msj_det.monto > v_mto_mt_limite then
            pas_snp.pr_set_texto( rg_msj_det.error, 'Monto de la Transferencia es superior al Monto Maximo ACH definido.', pas_snp.fu_obt_salto );
         end if;

      exception
         when dup_val_on_index then
            pas_snp.pr_set_texto( rg_msj_det.error, 'Domiciliacion duplicada. ', pas_snp.fu_obt_salto );
            v_mot_rechazo:=v_mot_rch_for;
         when no_data_found then
            pas_snp.pr_set_texto(rg_msj_det.error ,'No existe Orden de Domiciliacion Asociada.' ||rg_msj_det.ref_oid, pas_snp.fu_obt_salto );
            v_mot_rechazo:=v_mot_rch_for;
         when others then
            pas_snp.pr_set_texto( rg_msj_det.error, 'Error al recuperar catastro.', pas_snp.fu_obt_salto );
            v_mot_rechazo:=v_mot_rch_for;
      end;
      --controla la cantidad de debito en el mes DA-7712
      begin
        pag_cal.pr_obt_dat_calendar(1);
        v_pri_dia_mes:=pag_cal.g_pri_dia_mes;
        v_ult_dia_mes:=pag_cal.g_ult_dia_mes;
      select count(*)
        into v_cant_deb_mes
        from sb_snp_catastros_det d, sb_snp_catastros c
       where d.nro_orden = c.nro_orden
         and c.cod_servicio = rg_msj_det.ref_oid
         and d.estado in('P', 'L','O')
         and d.fec_cobro between  v_pri_dia_mes and v_ult_dia_mes;

      exception
         when no_data_found then
           v_cant_deb_mes:=0;
         when others then
           v_cant_deb_mes:=0;
       end;
      if v_cant_deb_mes >= fug_obt_pardinamico( 'SNP_CAN_DEB_MES' ) then
        pas_snp.pr_set_texto( rg_msj_det.error, 'Supera cantidad de solicitud de debito posibles en el mes', pas_snp.fu_obt_salto );
            v_mot_rechazo:=v_mot_deb_aut;
     end if;
      -- Controla en que periodo es recibido.
     begin
        select estado
          into v_est_periodo
          from ge_snp_horarios
         where cod_periodo =
               (select a.cod_periodo3
                  from ge_snp_par_mensajes a
                 where a.cod_msj_swift = rg_msj_cab.cod_msj_swift
                   and a.cod_tip_operacion = rg_msj_cab.cod_tip_operacion
                   and a.cod_sub_tip_operacion =
                       rg_msj_cab.cod_sub_tip_operacion);
         exception
           when no_data_found then
             v_est_periodo:=null;
           when others then
              v_est_periodo:=null;
      end;
      if v_est_periodo is not null and v_est_periodo= 'A' then
         pas_snp.pr_set_texto( rg_msj_det.error, 'Horario del servicio inactivo', pas_snp.fu_obt_salto );
         v_mot_rechazo:=v_mot_hor_ina;
      end if;

       -- Se Inserta en ge_snp_transferencias DA-7732
        BEGIN

           rg_msj_det.nro_referencia := fu_obt_sig_nro_referencia;
           rg_msj_det.cod_modulo     := pas_snp.fu_obt_cod_mod_padre;
           rg_msj_det.cod_modalidad  := pas_snp.fu_obt_cod_mad_padre;
           rg_msj_det.ind_valor      := 'N'; --(N) Bajo Valor
           rg_msj_det.situacion      := 'R';
           rg_msj_det.estado         :=  nvl( rg_msj_det.estado, 'A' ); --nvl( rg_msj_det.estado, 'S' );
           rg_msj_det.origen         := 'I';
           rg_msj_det.plataforma     := 'X';
           rg_msj_det.indemnizado    := 'N';

           if rg_msj_det.error is not null then
              rg_msj_det.situacion := 'E';
              v_ban_error          := 'S';
              v_can_tra_errores := v_can_tra_errores + 1;
              rg_msj_det.tip_rechazo:=v_mot_deb_aut;
           end if;

           g_lugar :=  'Insertando MT 104.., ';
           pr_ins_transferencias ( rg_msj_det );

           if pas_snp.fu_obt_cod_error <> 0 then
              raise ex_salir;
           end if;

        EXCEPTION
           when ex_salir then
             BEGIN
                if g_err_dir_correo is not null then
                   it_mail.mail( fug_obt_dir_correo,
                                 g_err_dir_correo,
                                 'Error al insertar la mensajeria EN LOTE en GE_SNP_TRANSFERENCIAS. ',
                                 'Se ha encontrado una mensajeria en el LOTE, el cual no pudo registrarse en ITGF. ' || chr(10) || chr(10) ||
                                 'Fecha Valor    : ' || to_char(rg_msj_det.fec_valor,'DD/MM/YYYY')                   || chr(10) ||
                                 'Lote           : ' || to_char(rg_msj_det.nro_lote)                                 || chr(10) ||
                                 'Nro.Ref.Externa: ' || rg_msj_det.nro_ref_externa                                   || chr(10) ||
                                 chr(10) || chr(10) ||
                                 'Atentamente.'
                               );
                end if;
             EXCEPTION
               when others then
                 NULL;
             END;
        END;
         begin
           insert into it.sb_snp_catastros_det
              (nro_orden, estado, fec_cobro, monto, nro_referencia)
           values
              (v_nro_orden,decode(rg_msj_det.situacion,'R','P','E','C'), rg_msj_det.fec_valor, rg_msj_det.monto, rg_msj_det.nro_sec_lote);
         exception
           when others then
             null;
         end;
        v_cod_swi_pte_solicitante:=rg_msj_det.cod_swi_pte_solicitante;
        v_cod_moneda:=rg_msj_det.cod_moneda;
     END LOOP;

      for err in c_transferencias loop
           v_can_transferencias:=v_can_transferencias+1;
       end loop;

/*Rechazo total de intrucciones recibidas dentro del lote MT104-DA-7764
   Si todas las transferencias tuvieron error,genera 192*/
  if v_can_tra_errores = v_can_transferencias then

    /*Generar 192 de rechazo total- MT192*/
    declare
         v_cod_msj_rechazo    sb_snp_tip_mensajes.cod_mensaje%type := 'MTn92';
         v_cod_msj            ge_snp_mensajes.cod_msj_swift%type:=192;
         v_tip_msj            ge_snp_par_mensajes.cod_tip_operacion%type:='001';
         v_sub_tip_msj        ge_snp_par_mensajes.cod_sub_tip_operacion%type:='001';
         v_nro_referencia     ge_snp_mensajes.nro_referencia%type  := fu_obt_sig_nro_referencia;
         v_mensaje            ge_snp_mensajes.msj_swift%type;
         v_cod_cau_defecto         wf_cir_tareas.cod_causa%type :=197;
         --v_nro_detalle        sb_snp_mensajes_tmp.nro_detalle%type;
         --v_Error              ge_snp_transferencias.error%type;
         v_fecha              ge_snp_transferencias.fec_valor%type;
      begin
         select decode(v_dia_deb_confirmacion,0,to_char(rg_msj_det.fec_valor,'RRMMDD'),1,to_char(pag_cal.FU_OBT_FEC_SIG_HAB(g_msj.fec_valor,null,1))) into v_fecha from dual;
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo,
                                            'CAB',
                                            '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                            '{2:I192'||rpad('ZYAGPYP0',12,'X')||'N}'||
                                            '{3:{113'||':'||lpad(fus_snp_obt_prioridad(v_cod_msj,v_tip_msj,v_sub_tip_msj),4,'0')||'}}{4:');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '20', v_nro_referencia);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '21', rg_msj_det.nro_lote);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', rg_msj_det.cod_msj_swift);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', to_char(rg_msj_det.fec_ingreso,'RRMMDD'));
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_cod_swi_pte_solicitante);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79',to_char(v_fec_liq,'RRMMDD'));
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79','/DESC/'||fue_obt_val_max_referencia('SNP_CAU_REC_CAN_INS',v_cod_cau_defecto)||pas_snp.fu_obt_salto||(fue_obt_des_refcodes('TIP_REC_SNP',fue_obt_val_max_referencia('SNP_CAU_REC_CAN_INS',v_cod_cau_defecto))));
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, 'PIE', '-}');

         pao_pmt.pr_pro_mt_enviado(v_cod_msj_rechazo, v_mensaje);
                    --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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
                                      pas_snp.g_cod_error := 70;
                                      pas_snp.g_msj_error := 'Error al intentar insertar en GE_MEN_ENV_SIPAP -referencia:'||v_nro_referencia;


                               end;
                    else
                               pr_gen_arc_swi_lote(v_mensaje);
                    end if;
         v_msj_retorno := '00|MT104|Error Lote '||rg_msj_det.nro_lote||' Rechazado';

         insert into ge_snp_mensajes
            (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift, cod_moneda, monto, error, situacion)
         values
            (v_nro_referencia, rg_msj_det.nro_lote, v_cod_msj, rg_msj_det.fec_valor, v_mensaje, v_cod_moneda, v_mto_total, v_msj_retorno,'V');

      exception
         when others then
           -- v_msj_retorno := '99|MT104|'||rg_msj_det.nro_lote||'|Error al enviar rechazo '||v_cod_msj_rechazo||': ' || sqlerrm;
                 raise_application_error(-20001, 'Error al enviar rechazo  - ' || sqlerrm );
      end;
      if pas_snp.fu_obt_cod_error = 0 then
            --DA-8321
            for reg in c_errores loop
                  g_lugar := 'Cancelacion de SWIFT';
                  update ge_snp_transferencias
                     set situacion = 'C'
                   where nro_referencia = reg.nro_referencia;
                   --DA-7824
                   if sql%rowcount > 0 then
                     --- Notificacion interna a operaciones
                                begin
                                  if g_gru_dir_correo is not null then

                                    it_mail.mail(fug_obt_dir_correo,
                                                 g_gru_dir_correo,
                                                 'Notificacion de Rechazo de Solicitud de d�bito Directo - Ref. Nro: ' ||
                                                 reg.nro_referencia,
                                                 'Rechazo autom�tico por validaci�n de datos para Solicitud de d�bito' ||
                                                 chr(10) ||
                                                 'Se ha realizado un Rechazo automatico por errores en el proceso de validacion de la Solicitud de d�bito directo Recibida - Ref. Nro:' ||
                                                 reg.nro_referencia);

                                  end if;
                                exception
                                  when others then
                                    null;
                                end;
                   end if;
                  update sb_snp_catastros_det
                     set estado = 'C'
                   where nro_referencia = reg.nro_sec_lote;
             end loop;
      end if;

  elsif v_can_tra_errores > 0 then
  /*  Rechazo parcial de instrucciones recibidas dentro del lote MT104-DA-7764
     Generar 198 de rechazo parcial, todas las que esten con error*/
     declare
         v_cod_msj_rechazo    sb_snp_tip_mensajes.cod_mensaje%type := 'MT198/196';
         v_nro_referencia     ge_snp_mensajes.nro_referencia%type;
         v_mensaje            ge_snp_mensajes.msj_swift%type;
         v_cod_msj            ge_snp_mensajes.cod_msj_swift%type:=198;
         v_tip_msj            ge_snp_par_mensajes.cod_tip_operacion%type:='001';
         v_sub_tip_msj        ge_snp_par_mensajes.cod_sub_tip_operacion%type:='001';
      begin
         v_can_tra_errores := 0;
         v_mto_total       := 0;
         for err in c_errores loop
               v_nro_referencia:= fu_obt_sig_nro_referencia;
               v_can_tra_errores := v_can_tra_errores + 1;
               v_mto_total := err.monto;
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo,
                                                'CAB',
                                                 '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                                '{2:I198'||rpad(fu_obt_bic_sistema,12,'X')||'N}'||
                                                '{3:{113'||':'||lpad(fus_snp_obt_prioridad(v_cod_msj,v_tip_msj,v_sub_tip_msj),4,'0')||'}}{4:');
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '20', v_nro_referencia);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '12', '192');
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '77E', NULL);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '21', err.nro_sec_lote);
               v_mot_rch:=fue_obt_des_refcodes('TIP_REC_SNP',err.tip_rechazo,null);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', rg_msj_det.cod_msj_swift);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', to_char(rg_msj_det.fec_ingreso,'RRMMDD'));
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/INSTR/');
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/BATCH/'||rg_msj_det.nro_lote);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_cod_swi_pte_solicitante);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', to_char(v_fec_liq,'RRMMDD'));
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/DESC/'||err.tip_rechazo);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_mot_rch);
               pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, 'PIE', '-}');
               pao_pmt.pr_pro_mt_enviado(v_cod_msj_rechazo, v_mensaje);
                --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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
                                      pas_snp.g_cod_error := 70;
                                      pas_snp.g_msj_error := 'Error al intentar insertar en GE_MEN_ENV_SIPAP -referencia:'||v_nro_referencia;


                               end;
                    else
                        pr_gen_arc_swi_lote(v_mensaje);
                    end if;
                insert into ge_snp_mensajes
               (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift, cod_moneda, monto, error,situacion)
            values
               (v_nro_referencia, rg_msj_det.nro_lote, v_cod_msj, rg_msj_det.fec_valor, v_mensaje, v_cod_moneda, v_mto_total, v_msj_retorno,'V');


         end loop;
         --DA-8321
         if pas_snp.fu_obt_cod_error = 0 then
            for reg in c_errores loop
              g_lugar := 'Cancelacion de SWIFT';
              update ge_snp_transferencias
                 set situacion = 'C'
               where nro_referencia = reg.nro_referencia;
               --DA-7824
               if sql%rowcount > 0 then
                     --- Notificacion interna a operaciones
                                begin
                                  if g_gru_dir_correo is not null then

                                    it_mail.mail(fug_obt_dir_correo,
                                                 g_gru_dir_correo,
                                                 'Notificacion de Rechazo de Solicitud de d�bito Directo - Ref. Nro: ' ||reg.nro_referencia,
                                                 'Rechazo autom�tico por validaci�n de datos para Solicitud de d�bito' ||
                                                 chr(10) ||
                                                 'Se ha realizado un rechazo autom�tico por errores en el proceso de validaci�n de la Solicitud de d�bito directo Recibida - Ref. Nro: '||reg.nro_referencia);

                                  end if;
                                exception
                                  when others then
                                    null;
                                end;
              end if;
              update sb_snp_catastros_det
                 set estado = 'C'
               where nro_referencia = reg.nro_sec_lote;
            end loop;
           end if;
      exception
         when others then
            return '00' || '|' || '99|MT104|'||rg_msj_det.nro_lote||'|Error al enviar rechazo '||v_cod_msj_rechazo||': ' || sqlerrm;
      end;
   end if;


     if v_ban_error = 'N' then
        return '00' || '|' || 'MT104' || '|' || rg_msj_det.nro_lote || ' - Procesado OK';
     else
        return '00' || '|' || 'MT104' || '|' || rg_msj_det.nro_lote || ' - Procesado con errores';
     end if;

EXCEPTION
  when ex_salir then
     return 99 || '|' || 'MT104' || '|' || g_lugar || ' - ' || SQLERRM;
  when others then
     return 99 || '|' || 'MT104' || '|' || g_lugar || ' - ' || SQLERRM;
END fu_pro_msj_mt104;
/*Procesa Liquidacion de transferencias recibidas(MT104)*/
--DA-7725 - Recepcion y procesamiento MT196 NETR relacionado a un MT104 recibido
PROCEDURE pr_pro_rec_mt104 (p_nro_lote in ge_snp_transferencias.nro_lote%type default null)
IS

   v_dia_deb_confirmacion     number := nvl(fug_obt_pardinamico('SNP_DIA_DEB_CONFIRMACION'), 0);
   v_nro_lote                 ge_snp_transferencias.nro_lote%type;
   v_can_error                number := 0;
   v_dir_correo               ge_par_dinamicos.val_parametro%type := nvl( pas_snp.g_gru_dir_correo, pas_snp.g_err_dir_correo );
   v_txt_mail                 varchar2(4000);
   v_asunto                   varchar2(1000);
   v_mensaje                  varchar2(4000);
   v_mto_total                number;
   -- Retorno de verificacion de operaciones
   v_est_cuenta               ge_cuentas.estado%type;    -- Estado Cta.
   v_sal_disponible           ge_movimientos.monto%type; -- Sal.Dispon.
   v_procesa                  varchar2(1) := 'N';        -- Procesar Operacion (S/N).
   v_cod_msj_rechazo          sb_snp_tip_mensajes.cod_mensaje%type := 'MT198/192';
   v_nro_referencia           ge_snp_mensajes.nro_referencia%type;
   v_cod_swi_pte_solicitante  ge_snp_transferencias.cod_swi_pte_solicitante%type;
   v_fec_ingreso              ge_snp_transferencias.fec_ingreso%type;
   v_fec_valor                 ge_snp_transferencias.fec_valor%type;
   v_cod_msj_swift            ge_snp_transferencias.cod_msj_swift%type := '104';
   v_cod_moneda               ge_snp_transferencias.cod_moneda%type;
   v_fec_liq                  ge_calendarios.fec_proxima%type;
   v_error  varchar2(4000);
   v_can_ins_error           number := 0;
   v_can_ins_ok              number := 0;
   v_can_tot_transferencias  number := 0;
   v_mot_rch           varchar2(4000):= null;
   v_mot_rechazo sb_snp_catastros.tip_rechazo%type;
   v_msj_retorno              varchar2(300);
   v_mot_rch_sal              constant varchar2(03) := '007';
   v_mot_deb_aut              constant varchar2(03) := '008';
   cursor c_pendientes is
      select a.nro_referencia,
             a.nro_cta_beneficiario,
             a.cod_oficina,
             a.cod_modulo,
             a.cod_modalidad,
             a.cod_moneda,
             a.nro_lote,
             a.monto,
             a.fec_ingreso,
             a.fec_valor,
             a.cod_swi_pte_solicitante,
             a.nro_sec_lote
        from ge_snp_transferencias a
       where a.cod_msj_swift = v_cod_msj_swift
         and a.estado = 'A' -- 'S'
         and a.situacion = 'R'
         and a.fecha is null
         and a.hora is null
         and a.cod_usuario is null
         and a.fec_recepcion is not null
         and a.fec_ingreso <= g_fec_actual - v_dia_deb_confirmacion
         and a.nro_lote=p_nro_lote
       order by a.nro_lote
         for update of a.estado, a.situacion;
    cursor c_errores is
      select b.nro_ref_externa,
             b.nro_referencia,
             b.nro_sec_lote,
             b.monto,
             b.tip_rechazo
        from ge_snp_transferencias b
       where b.cod_msj_swift = v_cod_msj_swift
         --and b.situacion = 'C'
         and (b.tip_rechazo is null and b.error is not null)
         and b.fec_ingreso <= g_fec_actual - v_dia_deb_confirmacion
         and b.nro_lote=p_nro_lote;


BEGIN
   /*
   || Procesa datos de la mensajeria RECIBIDA (Header del MT)
   */
   pas_snp.pr_ini_variables;
   v_fec_liq:= g_fec_actual;-- se considera fecha actual ya que la recepcion del NETR, se realiza en T+1

   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   for tra in c_pendientes loop
      if nvl(to_char(v_nro_lote), '*') != to_char(tra.nro_lote) then
         if v_can_error > 0 then
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', v_cod_msj_swift);
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', to_char(v_fec_ingreso,'RRMMDD'));
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/INSTR/');
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/BATCH/'||v_nro_lote);
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_cod_swi_pte_solicitante);
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', to_char(v_fec_liq,'RRMMDD'));
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, 'PIE', '-}');
            pao_pmt.pr_pro_mt_enviado(v_cod_msj_rechazo, v_mensaje);
            --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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
                                      pas_snp.g_cod_error := 55;
                                      pas_snp.g_msj_error := 'Error al insertar en GE_MEN_ENV_SIPAP: '||sqlerrm;


                               end;
                    else
                       pr_gen_arc_swi_lote(v_mensaje);
                    end if;
            insert into ge_snp_mensajes
               (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift, cod_moneda, monto)
            values
               (v_nro_referencia, v_nro_lote, 198, g_fec_actual, v_mensaje, v_cod_moneda, v_mto_total);

         end if;

         v_can_error := 0;
         v_mto_total := 0;
         v_nro_lote := tra.nro_lote;
         v_fec_ingreso := tra.fec_ingreso;
         v_fec_valor:= tra.fec_valor;
         v_cod_swi_pte_solicitante := tra.cod_swi_pte_solicitante;
         v_nro_referencia := fu_obt_sig_nro_referencia;
         v_cod_moneda := tra.cod_moneda;

         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo,
                                            'CAB',
                                            '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                            '{2:I198'||rpad(fu_obt_bic_sistema,12,'X')||'N}'||
                                            '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '20', v_nro_referencia);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '12', '192');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '77E', NULL);

      end if;
      --DA-7768
      pag_cta.pr_ver_operacion( tra.nro_cta_beneficiario,  -- Nro.Cta.
                                fu_obt_cod_tra_padre,      -- Trx. Padre - Transferencia entre cuentas
                                fu_obt_cod_mod_padre,      -- Mod.Padre
                                fu_obt_cod_mad_padre,      -- Mad.Padre
                                'D',                       -- Tip.Mov.
                                tra.cod_moneda,            -- Cod.Mon.
                                tra.monto,                 -- Monto
                                tra.cod_oficina,           -- Ofic.Orig.
                                tra.cod_modulo,            -- Mod.Hijo
                                tra.cod_modalidad,         -- Mad.Hijo
                                v_est_cuenta,              -- Estado Cta.
                                v_sal_disponible,          -- Sal.Dispon.
                                v_procesa                  -- Procesa
                              );

      if pag_cta.fu_obt_cod_error <> 0 then
         v_can_error := v_can_error + 1;
         v_mto_total := v_mto_total + tra.monto;
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '21', tra.nro_referencia, v_can_error);
         --Actualiza mt104
         update ge_snp_transferencias
            set estado = 'R',
                situacion = 'C',
                error = pag_cta.fu_obt_msj_error,
                tip_rechazo=decode(pag_cta.fu_obt_cod_error,24,v_mot_deb_aut,31,v_mot_rch_sal,v_mot_rch_sal)
          where current of c_pendientes;
          --DA-8446
               if sql%rowcount > 0 then
                     --- Notificacion interna a operaciones
                                begin
                                  if g_gru_dir_correo is not null then

                                    it_mail.mail(fug_obt_dir_correo,
                                                 g_gru_dir_correo,
                                                 'Notificacion de Rechazo de Solicitud de d�bito Directo - Ref. Nro: ' ||tra.nro_referencia,
                                                 'Rechazo autom�tico por validaci�n de datos para Solicitud de d�bito' ||
                                                 chr(10) ||
                                                 'Se ha realizado un rechazo autom�tico por errores en el proceso de validaci�n de la Solicitud de d�bito directo Recibida - Ref. Nro:' ||tra.nro_referencia);

                                  end if;
                                exception
                                  when others then
                                    null;
                                end;
              end if;
        -- Actualiza detalle de catastro
         update sb_snp_catastros_det h
            set h.estado = 'C'
          where h.nro_referencia = tra.nro_sec_lote;
      else
        --DA-7777 Actualiza mt104- para generar movimiento
        begin
          update ge_snp_transferencias a
             set a.situacion = 'V'
           where a.nro_referencia = tra.nro_referencia;
        exception
          when others then
            v_error := sqlerrm;
        end;
        if pas_snp.fu_obt_cod_error <> 0 then
           v_can_error := v_can_error + 1;
           v_mto_total := v_mto_total + tra.monto;
           pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '21', tra.nro_referencia, v_can_error);
            --Error al procesar el debito,  debe enviar MT198 de solicitud de cancelacion
                     update sb_snp_catastros_det d
                        set d.estado = 'C'
                      where d.nro_referencia = tra.nro_sec_lote;

                     update ge_snp_transferencias a
                        set a.situacion = 'C',
                            a.estado    = 'C',
                            error       = error || v_error
                      where a.nro_referencia = tra.nro_referencia;
                      --DA-8446
                      if sql%rowcount > 0 then
                         --- Notificacion interna a operaciones
                                begin
                                  if g_gru_dir_correo is not null then

                                    it_mail.mail(fug_obt_dir_correo,
                                                 g_gru_dir_correo,
                                                 'Notificacion de Rechazo de Solicitud de d�bito Directo - Ref. Nro: ' ||
                                                 tra.nro_referencia,
                                                 'Rechazo autom�tico por validaci�n de datos para Solicitud de d�bito' ||
                                                 chr(10) ||
                                                 'Se ha realizado un Rechazo automatico por errores en el
                                                    proceso de validacion de la Solicitud de d�bito directo Recibida - Ref. Nro:' ||
                                                 tra.nro_referencia);

                                  end if;
                                exception
                                  when others then
                                    null;
                                end;
                       end if;
        else
          update sb_snp_catastros_det d
                        set d.estado = 'O',
                            d.fec_cobro=pas_snp.g_fec_actual
                      where d.nro_referencia = tra.nro_sec_lote;
          update ge_snp_transferencias a
             set a.situacion = 'O', a.estado = 'A'
           where a.nro_referencia = tra.nro_referencia;
        end if;
      end if;
        v_can_ins_ok:=v_can_ins_ok+1;
   end loop;

   begin
     select count(a.nro_lote)
     into v_can_tot_transferencias
        from ge_snp_transferencias a
       where a.cod_msj_swift = v_cod_msj_swift
         and a.fec_ingreso <= g_fec_actual - v_dia_deb_confirmacion
         and a.nro_lote=p_nro_lote;
       exception
         when no_data_found then
             v_error := sqlerrm;
         when others then
            v_error := sqlerrm;
   end;
   --controla la cantidad de transferencias
   for err in c_errores loop
      v_can_ins_error  := v_can_ins_error  + 1;
   end loop;
   --Verifica que se realizara rechazo parcial o total--DA-7764
   if v_can_ins_error  = v_can_tot_transferencias  then -- v_can_transferencias

      /*Generar 192 de rechazo total- MT192*/
    declare
         v_cod_msj_rechazo    sb_snp_tip_mensajes.cod_mensaje%type := 'MTn92';
         v_cod_msj            ge_snp_mensajes.cod_msj_swift%type:=192;
         v_tip_msj            ge_snp_par_mensajes.cod_tip_operacion%type:='001';
         v_sub_tip_msj        ge_snp_par_mensajes.cod_sub_tip_operacion%type:='001';
         v_nro_referencia     ge_snp_mensajes.nro_referencia%type  := fu_obt_sig_nro_referencia;
         v_mensaje            ge_snp_mensajes.msj_swift%type;
         v_fecha              ge_snp_transferencias.fec_valor%type;
      begin
         select decode(v_dia_deb_confirmacion,0,to_char(v_fec_valor,'RRMMDD'),1,to_char(pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_valor,null,1))) into v_fecha from dual;
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo,
                                            'CAB',
                                            '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                            '{2:I192'||rpad('ZYAGPYP0',12,'X')||'N}'||
                                            '{3:{113'||':'||lpad(fus_snp_obt_prioridad(v_cod_msj,v_tip_msj,v_sub_tip_msj),4,'0')||'}}{4:');
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '20', v_nro_referencia);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '21', v_nro_lote);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', v_cod_msj_swift);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', to_char(v_fec_ingreso,'RRMMDD'));
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_cod_swi_pte_solicitante);
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', to_char(v_fec_liq,'RRMMDD'));
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, 'PIE', '-}');

         pao_pmt.pr_pro_mt_enviado(v_cod_msj_rechazo, v_mensaje);
         --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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
                                      pas_snp.g_cod_error := 70;
                                      pas_snp.g_msj_error := 'Error al intentar insertar en GE_MEN_ENV_SIPAP -referencia:'||v_nro_referencia;


                               end;
                    else
                               pr_gen_arc_swi_lote(v_mensaje);
                    end if;
         v_msj_retorno := '00|MT104|Error Lote '||v_nro_lote||' Rechazado';

         insert into ge_snp_mensajes
            (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift, cod_moneda, monto, error,situacion)
         values
            (v_nro_referencia, v_nro_lote, 192, g_fec_actual, v_mensaje,v_cod_moneda, v_mto_total, v_msj_retorno,'V');

      exception
         when others then
           -- v_msj_retorno := '99|MT104|'||rg_msj_det.nro_lote||'|Error al enviar rechazo '||v_cod_msj_rechazo||': ' || sqlerrm;
                 raise_application_error(-20001, 'Error al enviar rechazo  - ' || sqlerrm );
      end;
      if pas_snp.fu_obt_cod_error = 0 then
        --DA-8321
          for reg in c_errores loop
            g_lugar := 'Cancelacion de SWIFT';
            --Actualiza mt104
            update ge_snp_transferencias
               set situacion = 'C'
            where nro_referencia = reg.nro_referencia;
              -- Actualiza detalle de catastro
           update sb_snp_catastros_det
            set estado = 'C'
            where nro_referencia = reg.nro_sec_lote;
       end loop;
      end if;
     null;
  elsif v_can_ins_error >0 and  v_can_ins_error < v_can_tot_transferencias then
   /*DA-7764-generar 198 de rechazo parcial, todas las que esten con error*/
      declare
         v_cod_msj_rechazo    sb_snp_tip_mensajes.cod_mensaje%type := 'MT198/196';
         v_mensaje            ge_snp_mensajes.msj_swift%type;
          v_nro_referencia     ge_snp_mensajes.nro_referencia%type;
      begin
         v_can_ins_error := 0;
         for err in c_errores loop
            v_nro_referencia:= fu_obt_sig_nro_referencia;
            v_can_ins_error := v_can_ins_error + 1;
            v_mto_total := err.monto;
            pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo,
                                            'CAB',
                                            '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                            '{2:I198'||rpad(fu_obt_bic_sistema,12,'X')||'N}'||
                                            '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '20', v_nro_referencia);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '12', '192');
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '77E', NULL);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '21', err.nro_sec_lote);
             v_mot_rch:=fue_obt_des_refcodes('TIP_REC_SNP',err.tip_rechazo,null);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', v_cod_msj_swift);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', to_char(v_fec_ingreso,'RRMMDD'));
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/INSTR/');
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/BATCH/'||v_nro_lote);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_cod_swi_pte_solicitante);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79',  to_char(v_fec_liq,'RRMMDD'));
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/DESC/'||err.tip_rechazo);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_mot_rch);
             pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, 'PIE', '-}');
             pao_pmt.pr_pro_mt_enviado(v_cod_msj_rechazo, v_mensaje);
             --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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
                                      pas_snp.g_cod_error := 70;
                                      pas_snp.g_msj_error := 'Error al intentar insertar en GE_MEN_ENV_SIPAP -referencia:'||v_nro_referencia;


                               end;
                    else
                               pr_gen_arc_swi_lote(v_mensaje);
                    end if;

            insert into ge_snp_mensajes
               (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift, cod_moneda, monto,situacion)
            values
               (v_nro_referencia, v_nro_lote, 198, g_fec_actual, v_mensaje, v_cod_moneda, v_mto_total,'V');
         end loop;
      exception
         when others then
          /*Envio notificacion*/
          v_asunto   := 'Error en proceso de Liquidacion de MT104 Pendientes - SNP.';
          v_txt_mail := 'Ocurrio un error al procesar los MT104 Pendientes de Liquidacion'||chr(10)||
                     'Error: '||sqlerrm||chr(10)||'Atentamente.';
          it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);
      end;
      if pas_snp.fu_obt_cod_error = 0 then
             --DA-8321
             for reg in c_errores loop
                  g_lugar := 'Cancelacion de SWIFT';
                 --Actualiza mt104
                 update ge_snp_transferencias
                    set situacion = 'C'
                  where nro_referencia = reg.nro_referencia;
                 -- Actualiza detalle de catastro
                 update sb_snp_catastros_det
                    set estado = 'C'
                  where nro_referencia = reg.nro_sec_lote;
             end loop;
      end if;
   end if;
exception
    when others then
       /*Envio notificacion*/
      v_asunto   := 'Error en proceso de Liquidacion de MT104 Pendientes - SNP.';
       v_txt_mail := 'Ocurrio un error al procesar los MT104 Pendientes de Liquidacion'||chr(10)||
                     'Error: '||sqlerrm||chr(10)||'Atentamente.';

       it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);


END pr_pro_rec_mt104;
function fu_pro_msj_mt198( p_mensaje in long ) return varchar2
is
   v_msj_retorno             varchar2(100);
   v_txt_mail                varchar2(4000);
   v_asunto                  varchar2(1000);
   v_error                   varchar2(200);
   v_can_errores             number := 0;
   v_transferencias          varchar2(3000);
   v_cod_mensaje             sb_snp_tip_mensajes.cod_mensaje%type := 'MT198/192';
   v_dir_correo              ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_RECHAZO_LIM');
   v_nro_referencia          ge_snp_transferencias.nro_referencia%type;
   v_nro_ref_externa         ge_snp_transferencias.nro_sec_lote%type;
   v_nro_lote                ge_snp_transferencias.nro_lote%type;
   v_nro_lot_varias          ge_snp_transferencias.nro_lote%type;
   v_ind                     varchar2(1)  :='N';
   v_tipo                    varchar2(50);
   v_nro_sec_ins             ge_snp_transferencias.nro_sec_lote%type;
   v_nro_lot_ins             ge_snp_transferencias.nro_lote%type;
   v_cod_msj                 ge_snp_transferencias.cod_msj_swift%type :=104;
   v_rch_ins                 ge_snp_transferencias.error%type;
   v_tip_rec_ins             ge_snp_transferencias.tip_rechazo%type;
   v_nro_lot_varios          ge_snp_transferencias.nro_lote%type;
   no_procesa                exception;
   v_pos_reg_ini             number         := 0;
   v_pos_reg_fin             number         := 0;
   rg_msj_cab             pas_snp.rg_msj := null;
   rg_msj_det             pas_snp.rg_msj := null;
   rg_msj_env             pas_snp.rg_msj := null;
   rg_dat_pte             pas_snp.rg_pte := null;
   v_tip_rec_error        varchar2(100)  := null;
   v_ind_reversion        varchar2(1)    := 'N';
   v_ind_rev_manual       varchar2(1)    := 'N';
   v_cta_cliente          ge_snp_transferencias.nro_cta_beneficiario%type;
   v_monto                ge_snp_transferencias.monto%type;
    v_pos_ini              number;
    v_pos_fin              number ;
    v_texto                ge_snp_transferencias.nro_sec_lote%type;
   cursor c_detalle is
      select a.cod_mensaje,
             a.campo,
             a.valor,
             a.descripcion,
             a.err_formato,
             a.orden,
             a.nro_detalle
        from sb_snp_mensajes_tmp a
       where a.cod_mensaje = v_cod_mensaje
        -- and a.nro_detalle != 0
       order by nro_detalle asc;

begin

   v_msj_retorno := '00|'||v_cod_mensaje||'|Procesado OK.';
   for tra in c_detalle loop
      begin
       v_error           := pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '77A', 1, tra.nro_detalle)||'-'||pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '77A', 2, tra.nro_detalle);
       v_nro_ref_externa := pao_pmt.fu_obt_val_delimitador(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '79', 1, tra.nro_detalle), 2);
       v_tipo            := substr(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '76', 1, tra.nro_detalle),1,4)||substr(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '76', 2, tra.nro_detalle),1,2);
       v_nro_lote        :=  substr(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '79', 1, tra.nro_detalle),8,20);
       v_nro_sec_ins     :=  substr(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '21', 1, tra.nro_detalle),1,20);
       v_nro_lot_ins     :=  pao_pmt.fu_obt_val_delimitador(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '79', 2, tra.nro_detalle), 2);
       v_tip_rec_ins     :=  pao_pmt.fu_obt_val_delimitador(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '79', 5, tra.nro_detalle), 2);
       if tra.campo = '79' and tra.descripcion ='Referencia BATCH' then
           v_nro_lot_varios    :=  pao_pmt.fu_obt_val_delimitador(pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '79',2, tra.nro_detalle), 2);
       end if;
      exception
         when others then
            pas_snp.g_cod_error := 55;
            pas_snp.g_msj_error := 'Error al procesar MT198: '||sqlerrm;
            raise ex_salir;
      end;
   end loop;
   begin
     insert into ge_snp_mensajes
        (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift,
         cod_moneda, monto, error, fec_recepcion)
     values
        (pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20'), null, 198, g_fec_actual,
         replace(p_mensaje, pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto),
         null, null, v_msj_retorno, sysdate);
    exception
       when others then
          v_msj_retorno := '99|'||v_cod_mensaje||'|Error al Insertar Mensajeria Recibida. '||sqlerrm;
    end;

      if v_tipo=fug_obt_pardinamico('SNP_CON_CAN_OK') then
          v_ind:='S';
      end if;

      if v_ind = 'S' then -- DA-8339 -- MT198 del tipo OK CANC en respuesta a un MT198 enviado
       --se obtiene nro de referencia
           begin
             select nro_referencia
               into v_nro_referencia
               from ge_snp_transferencias
              where nro_lote = v_nro_lot_varios --v_nro_ref_externa
              and nro_sec_lote=v_nro_lote;
           exception
             when no_data_found then
               v_nro_referencia := null;
             when others then
               v_nro_referencia := null;
           end;
      if v_nro_referencia is not null then
           pas_snp.pr_obt_mensaje ( v_nro_referencia, 'S' );
           if pas_snp.fu_obt_cod_error=0 and pas_snp.fu_obt_cod_error <> 16 and pas_snp.fu_obt_cod_error not like  '%no se encuentran movimientos%' then
            --reversa la operacion relacionada al mensaje
               pas_snp.pr_rev_ope_con_swift( g_msj.nro_referencia, 'Rev. MT.' || g_msj.nro_referencia ||' - SNP', 'R' );
               if pas_snp.fu_obt_cod_error <> 0 then
                  raise no_procesa;
               else
                   update sb_snp_catastros_det
                    set estado = 'C'
                where nro_referencia = v_nro_lote;
                update ge_snp_transferencias t
                  set t.situacion = 'C',
                      t.error     = v_error --substr(error || v_error, 1, 4000)
                where t.nro_sec_lote = v_nro_lote
                  and t.cod_msj_swift =
                      pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '11R', 1, 0);
               end if;
           else
               update ge_snp_transferencias t
                  set t.estado    = 'R',
                      t.situacion = 'C',
                      t.error     = v_error-- substr(error || v_error, 1, 4000)
                where t.nro_sec_lote = v_nro_lote
                  and t.cod_msj_swift =
                      pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '11R', 1, 0);

               update sb_snp_catastros_det
                  set estado = 'C'
                where nro_referencia = v_nro_lote;

            end if;
        end if;
     elsif v_tipo is null then -- CANCELA UNA SOLA INSTRUCCION
      -- DA-8439 --
         --se obtiene nro de referencia
           begin
             select nro_referencia
               into v_nro_referencia
               from ge_snp_transferencias
              where nro_lote = v_nro_lot_ins
              and nro_sec_lote=v_nro_sec_ins;
           exception
             when no_data_found then
               v_nro_referencia := null;
             when others then
               v_nro_referencia := null;
           end;
      if v_nro_referencia is not null then
          --v_rch_ins :=fue_obt_des_refcodes('TIP_REC_SNP',v_tip_rec_ins);
        if instr(fug_obt_pardinamico('TIP_REC_TOT_INS_196',null, null, null, null),v_tip_rec_ins) > 0 then
           v_rch_ins :='La instruccion es cancelada.'; --fue_obt_des_refcodes('TIP_REC_198',v_tip_rec_ins);
        else
           v_rch_ins :=v_error;
        end if;
           pas_snp.pr_obt_mensaje ( v_nro_referencia, 'N' );

           if pas_snp.fu_obt_cod_error=0 and pas_snp.fu_obt_cod_error <> 16 and pas_snp.fu_obt_cod_error not like  '%no se encuentran movimientos%' then
            --reversa la operacion relacionada al mensaje
             --if (g_msj.situacion='R' and g_msj.estado='S') or (g_msj.situacion='O' and g_msj.estado='A') then
             if (g_msj.fecha is not null and g_msj.hora is not null and g_msj.cod_usuario is not null) then
               pas_snp.pr_rev_ope_con_swift( g_msj.nro_referencia, 'Rev. Aut. MT.198 Recibido ' || v_nro_sec_ins ||' - SNP', 'R' );
               if pas_snp.fu_obt_cod_error <> 0 then
                  raise no_procesa;
               else
                     update sb_snp_catastros_det
                      set estado = 'C'
                  where nro_referencia = v_nro_sec_ins;
                  update ge_snp_transferencias t
                    set t.situacion = 'C',
                        t.error       = substr(error || v_tip_rec_ins || '-' ||v_rch_ins,1,4000),
                        t.tip_rechazo = v_tip_rec_ins
                  where t.nro_sec_lote =  v_nro_sec_ins
                  and t.nro_lote = v_nro_lot_ins
                    and t.cod_msj_swift = v_cod_msj;
                end if;
           else
                /*update ge_snp_mensajes g
                   set g.error = v_cod_mensaje || ' ' ||
                                 'Recibido. No se ha podido cancelar la instrucci�n ' ||
                                 v_nro_sec_ins
                 where g.nro_referencia =
                       pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20');
               end if;*/
                  update sb_snp_catastros_det
                      set estado = 'C'
                  where nro_referencia = v_nro_sec_ins;
                  update ge_snp_transferencias t
                    set t.situacion = 'C',
                        t.error       = substr(error || v_tip_rec_ins || '-' ||v_rch_ins,1,4000),
                        t.tip_rechazo = v_tip_rec_ins
                  where t.nro_sec_lote =  v_nro_sec_ins
                  and t.nro_lote = v_nro_lot_ins
                    and t.cod_msj_swift = v_cod_msj;
             end if;
           else
               update ge_snp_transferencias t
                  set t.estado    = 'R',
                      t.situacion = 'C',
                      t.error     = substr(error || v_tip_rec_ins||'-'|| v_rch_ins, 1, 4000),
                      t.tip_rechazo = v_tip_rec_ins
                where t.nro_sec_lote = v_nro_sec_ins
                  and t.cod_msj_swift = v_cod_msj;
               update sb_snp_catastros_det
                  set estado = 'C'
                where nro_referencia = v_nro_sec_ins;
            end if;

        end if;
     else -- MT198 CANCELA VARIAS INSTRUCCIONES -- DA-9114 --
         -- Obtiene los datos del detalle de la operacion.
     for i in 1..999999 loop
        rg_msj_det             := null;
        rg_msj_env             := null;
        rg_dat_pte             := null;
        rg_msj_det             := rg_msj_cab;
        g_det_msj_error        := null;
        v_tip_rec_error        := null;
        v_pos_reg_fin          := 0;
        v_ind_reversion        := 'N';
        v_ind_rev_manual       := 'N';
        v_cta_cliente          := null;
        v_monto                := 0;
        v_pos_ini              := 0;
        v_pos_fin              := 0;
        v_nro_sec_ins          := null;

        pas_snp.pr_ini_registros;
        --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
        pre_cam_for_numerico(',.');
      /*
        || Si encuentra la posicion :76:, busca la siguiente posicion :76: o
        || si es fin de archivo busca la posicion del :79:
        */
        v_pos_reg_ini := instr(p_mensaje,':76:', 1, i);

        if v_pos_reg_ini = 0 then
           exit;
        else
           v_pos_reg_fin := instr(p_mensaje,':76:', 1, i+1);

           if v_pos_reg_fin = 0 then
              v_pos_reg_fin := instr(p_mensaje,'-}', i, 1);
           end if;
        end if;

       rg_msj_det.msj_swift := replace( ltrim( rtrim( substr( p_mensaje, v_pos_reg_ini, v_pos_reg_fin - v_pos_reg_ini ) ) ),pas_snp.fu_obt_sal_socket, pas_snp.fu_obt_salto );

     /**/-- 77A: Informacion
           g_lugar :=  'Obteniendo campo :77A:, ';
           v_pos_ini := instr(rg_msj_det.msj_swift,':77A:',1) + 5;
           v_pos_fin := instr(rg_msj_det.msj_swift,pas_snp.fu_obt_salto,v_pos_ini);
           v_tip_rec_ins   := nvl(ltrim(rtrim(substr(rg_msj_det.msj_swift,v_pos_ini,v_pos_fin - v_pos_ini))),' ');

     /**/-- 79: Informacion
           g_lugar :=  'Obteniendo campo :79:, ';
           v_pos_ini := instr(rg_msj_det.msj_swift,'/INSTR/',1) + 7;
           v_pos_fin := instr(rg_msj_det.msj_swift,pas_snp.fu_obt_salto,v_pos_ini);
           v_nro_sec_ins   := nvl(ltrim(rtrim(substr(rg_msj_det.msj_swift,v_pos_ini,v_pos_fin - v_pos_ini))),' ');

     --se obtiene nro de referencia
         begin
             select nro_referencia
               into v_nro_referencia
               from ge_snp_transferencias
              where nro_lote = v_nro_lot_varios
              and nro_sec_lote=nvl(v_nro_sec_ins,v_nro_ref_externa);
           exception
             when no_data_found then
               v_nro_referencia := null;
             when others then
               v_nro_referencia := null;
           end;
      if v_nro_referencia is not null then
        if instr(fug_obt_pardinamico('TIP_REC_TOT_INS_196',null, null, null, null),v_tip_rec_ins) > 0 then
           v_rch_ins :='La instruccion es cancelada.'; --fue_obt_des_refcodes('TIP_REC_198',v_tip_rec_ins);
        else
           v_rch_ins :=v_error;
        end if;
           pas_snp.pr_obt_mensaje ( v_nro_referencia, 'N' );
           if pas_snp.fu_obt_cod_error=0 and pas_snp.fu_obt_cod_error <> 16 and pas_snp.fu_obt_cod_error not like  '%no se encuentran movimientos%' then
                --reversa la operacion relacionada al mensaje
                if (g_msj.fecha is not null and g_msj.hora is not null and g_msj.cod_usuario is not null) then
                --if (g_msj.situacion='R' and g_msj.estado='S') or (g_msj.situacion in ('O') and g_msj.estado='A') then
                   pas_snp.pr_rev_ope_con_swift( g_msj.nro_referencia, 'Rev. Aut. MT.198 Recibido ' || v_nro_sec_ins ||' - SNP - ', 'R' );
                   --pas_snp.pr_rev_ope_con_swift( g_msj.nro_referencia, 'Rev. Aut. MT.198 Recibido ' || v_nro_sec_ins ||' - SNP - ');
                   if pas_snp.fu_obt_cod_error <> 0 then
                      raise no_procesa;
                   else
                       update sb_snp_catastros_det
                        set estado = 'C'
                    where nro_referencia = v_nro_sec_ins;
                    update ge_snp_transferencias t
                      set t.situacion = 'C',
                          t.error     = substr(error || v_tip_rec_ins||'-'|| v_rch_ins, 1, 4000),
                          t.tip_rechazo = v_tip_rec_ins
                    where t.nro_sec_lote =  v_nro_sec_ins
                    and t.nro_lote = v_nro_lot_varios
                      and t.cod_msj_swift = v_cod_msj;
                   end if;
             else -- En caso que no tenga movimientos
            /*update ge_snp_mensajes g
               set g.error = v_cod_mensaje || ' ' ||
                                         'Recibido. No se ha podido cancelar del lote ' ||
                                         v_nro_lot_varios
             where g.nro_referencia =
                   pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20');*/
                   update sb_snp_catastros_det
                        set estado = 'C'
                    where nro_referencia = v_nro_sec_ins;
                    update ge_snp_transferencias t
                      set t.situacion = 'C',
                          t.error     = substr(error || v_tip_rec_ins||'-'|| v_rch_ins, 1, 4000),
                          t.tip_rechazo = v_tip_rec_ins
                    where t.nro_sec_lote =  v_nro_sec_ins
                    and t.nro_lote = v_nro_lot_varios
                      and t.cod_msj_swift = v_cod_msj;
          end if;
           else
               update ge_snp_transferencias t
                  set t.estado    = 'R',
                      t.situacion = 'C',
                      t.error     = substr(error || v_tip_rec_ins||'-'|| v_rch_ins, 1, 4000),
                      t.tip_rechazo = v_tip_rec_ins
                where t.nro_sec_lote = v_nro_sec_ins
                  and t.nro_lote=v_nro_lot_varios
                  and t.cod_msj_swift = v_cod_msj;
               update sb_snp_catastros_det
                  set estado = 'C'
                where nro_referencia = v_nro_sec_ins;
            end if;
        end if;
       end loop;
    end if;
  return v_msj_retorno;

exception
  -- DA-8439 --
   when no_procesa then
    begin
      if v_dir_correo is not null then
         it_mail.mail( fug_obt_dir_correo,
             v_dir_correo,
             'Inconveniente en reversion '|| v_cod_mensaje ||' Recibido.',
             'Hubo un error en la reversion de la operacion'
             || chr(10) ||'Nro. de referencia lote: '||nvl(v_nro_lot_ins,v_nro_lote)
             || chr(10) ||'Detalle Error: '|| pas_snp.fu_obt_msj_error
            );
       end if;
      exception
        when others then
           null;
      end;
      return '99|'||v_cod_mensaje||'|Error al Procesar Reverso Recibido. '||sqlerrm;
   when ex_salir then
      return '99|'||v_cod_mensaje||'|Error al Procesar Mensajeria Recibida. '||sqlerrm;
   when others then
      return '99|'||v_cod_mensaje||'|Error al Procesar Mensajeria Recibida. '||sqlerrm;

end fu_pro_msj_mt198;
/*Genera MT de rechazo de instruccion dentro de un Batch*/
PROCEDURE pr_obt_msj_mt198( p_nro_referencia in ge_snp_transferencias.nro_referencia%type) is
   v_cod_msj_rechazo         sb_snp_tip_mensajes.cod_mensaje%type := 'MT198/196';
   v_nro_referencia          ge_snp_mensajes.nro_referencia%type  := fu_obt_sig_nro_referencia;
   v_mensaje                 ge_snp_mensajes.msj_swift%type;
   v_cod_causa                wf_cir_tareas.cod_causa%type;
   v_mot_rch                 ge_snp_transferencias.tip_rechazo%type;
   v_desc_rch                varchar2(4000);
   v_dia_deb_confirmacion    number := fug_obt_pardinamico('SNP_DIA_DEB_CONFIRMACION');
   v_fec_liq                 ge_calendarios.fec_proxima%type;
   v_cod_msj            ge_snp_mensajes.cod_msj_swift%type:=198;
begin
   pr_ini_registros;

   pr_obt_mensaje(p_nro_referencia, 'N');
   begin
     select t.cod_causa
           into v_cod_causa
           from wf_cir_tareas t,wf_circuitos c
           where t.cod_tip_circuito=fug_obt_pardinamico('SNP_CIR_APR_REC_CAN_INS')
           and t.cod_tarea=1
           and t.cod_circuito= c.cod_circuito
           and c.referencia=g_msj.nro_referencia;
      exception
        when others then
          null;
   end;
  --TCE-175
  v_mot_rch :=g_msj.tip_rechazo;
   v_desc_rch:=fue_obt_des_refcodes('TIP_REC_SNP',v_mot_rch);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo,
                                      'CAB',
                                      '{1:F01'||rpad(g_usu_xadapter,12,'X')||'}'||
                                      '{2:I198'||rpad(pas_snp.fu_obt_bic_sistema,12,'X')||'N}'||
                                      '{3:{113'||':'||lpad('30',4,'0')||'}}{4:');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '20', v_nro_referencia);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '12', '192');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '77E', NULL);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '21',g_msj.nro_sec_lote, 1);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', g_msj.cod_msj_swift);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '11S', to_char(g_msj.fec_ingreso,'RRMMDD'));
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/INSTR/');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/BATCH/'||g_msj.nro_lote);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', g_msj.cod_swi_pte_solicitante);
   -- Calcular fecha de liquidaci�n --
      if g_msj.cod_msj_swift != 104 then
         v_fec_liq:= g_fec_actual;
      else
         v_fec_liq:= pag_cal.fu_obt_fec_sig_hab(g_msj.fec_ingreso,fug_obt_ofi_usuario(user),1);
      end if;
   --
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', to_char(v_fec_liq,'RRMMDD'));
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', '/DESC/'||v_mot_rch);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, '79', v_desc_rch);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_msj_rechazo, 'PIE', '-}');
   begin
      pao_pmt.pr_pro_mt_enviado(v_cod_msj_rechazo, v_mensaje);
                   --TRFS-533
                   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
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
                                      pas_snp.g_cod_error := 55;
                                      pas_snp.g_msj_error := 'Error al insertar en GE_MEN_ENV_SIPAP: '||sqlerrm;


                               end;
                    else
                               pr_gen_arc_swi_lote(v_mensaje);
                    end if;
   exception
      when others then
         pas_snp.g_cod_error := 55;
         pas_snp.g_msj_error := 'Error al Generar MT: '||sqlerrm;
   end;

   insert into ge_snp_mensajes
      (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift, cod_moneda, monto, error,situacion)
   values
      (v_nro_referencia, g_msj.nro_lote, v_cod_msj, g_fec_actual, v_mensaje, g_msj.cod_moneda, g_msj.monto, pas_snp.g_msj_error,'V');
   commit;

exception
   when others then
      pas_snp.g_cod_error := 55;
      pas_snp.g_msj_error := 'Error al Generar MT: '||sqlerrm;

end pr_obt_msj_mt198;
/*
Cancelacion automatica de solicitudes de alta y cancelacion de catastro
*/
procedure pr_can_aut_catastro is
v_cir_alta        wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SNP_CIR_APR_SOL_CAT_REC');
v_cir_cancel      wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SNP_CIR_SOL_CAN_CAT');
v_can_dias        number(8):=fug_obt_pardinamico('SNP_CAN_DIA_CANCELACION');
v_causal          ba_cod_referencias.val_maximo%type;
v_comentario      wf_cir_tareas.comentario%type;
v_asunto          varchar2(2000);
v_txt_mail        varchar2(5000);
v_dir_correo      ge_par_dinamicos.val_parametro%type := nvl(pas_snp.g_gru_dir_correo, pas_snp.g_err_dir_correo);
v_causa           ge_par_dinamicos.val_parametro%type;
cursor c_solicitudes is
       select *
       from wf_circuitos w
       where w.cod_tip_circuito in (v_cir_alta,v_cir_cancel)
       and w.estado='E' --ejecucion
       and trunc(sysdate)>=it.fug_cal_fec_habil(trunc(w.fec_inicio),v_can_dias)
       and exists (select 1 from sb_snp_catastros tr
                   where tr.nro_orden=w.referencia);
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   v_causa:=fug_obt_pardinamico('SNP_MOT_REC_AUTOMATICO');
   v_causal:=fue_obt_val_max_referencia('SNP_CAU_REC_CAN_CAT',v_causa);
   for reg in c_solicitudes loop
     begin
           pr_obt_dat_catastro(reg.referencia,'O');
           if reg.cod_tip_circuito=v_cir_alta then

              update sb_snp_catastros ca
              set ca.tip_rechazo=v_causal,
              ca.fec_rechazo=sysdate,
              ca.estado = 'R',
              ca.situacion = 'RR'
              where ca.nro_orden=reg.referencia;

              v_comentario:='Rechazo automatico por falta de Autorizacion de Alta de catastro';
              v_asunto    := 'Notificacion de Rechazo de Solicitud de Alta de Catastro - Orden Nro. '||reg.referencia;
              v_txt_mail  := 'Se ha realizado un Rechazo automatico por falta de respuesta de la Solicitud de Alta de Catastro Recibida - Orden Nro. '||reg.referencia ||
                            chr(10) || 'Codigo de Servicio Nro. ' || g_cat.cod_servicio ||
                            chr(10) || 'Referencia Nro. ' || g_cat.nro_referencia ||
                            chr(10) || 'Referencia Externa Nro. ' || g_cat.nro_ref_externa;

           else
              v_comentario :='Rechazo automatico por falta de autorizacion de Cancelacion de catastro';
              v_asunto     := 'Notificacion de Rechazo de Solicitud de Cancelacion de Catastro - Orden Nro. '||reg.referencia;
              v_txt_mail   := 'Se ha realizado un Rechazo automatico por falta de respuesta de la Solicitud de Cancelacion de Catastro Recibida - Orden Nro. '||reg.referencia ||
                              chr(10) || 'Circuito WorkFlow Nro.' || reg.cod_circuito ||
                              chr(10) || 'Codigo de Servicio Nro.' || g_cat.cod_servicio ||
                              chr(10) || 'Atentamente.';
           end if;

      update wf_circuitos cr
      set cr.estado='C',
      cr.fec_fin=trunc(sysdate)
      where cr.cod_circuito=reg.cod_circuito;

      update wf_cir_tareas ta
      set ta.fec_finalizacion=trunc(sysdate),
      ta.estado='C',
      ta.comentario=v_comentario,
      ta.cod_usuario=user,
      ta.cod_causa=v_causa
      where ta.cod_circuito=reg.cod_circuito
      and ta.cod_tarea=reg.cod_tar_actual;

      if v_dir_correo is not null then
          begin
                 it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);
          exception
             when others then
                  NULL;
          end;
       end if;
      exception
          when others then
              v_asunto    := 'Error en la cancelacion automatica del siguiente circuito '||reg.cod_circuito;
              v_txt_mail  := 'Se ha producido el siguiente error: '||sqlerrm ||' al intentar rechazar automaticamente el: '||
                            chr(10) || 'Circuito WorkFlow Nro.' || reg.cod_circuito ||
                            chr(10) || 'Catastro Nro. ' || reg.referencia ||
                            chr(10) || 'Codigo de Servicio Nro.' || g_cat.cod_servicio ||
                            chr(10) || 'Atentamente.';
             if v_dir_correo is not null then
                begin
                 it_mail.mail(fug_obt_dir_correo, v_dir_correo, v_asunto, v_txt_mail);
                exception
                   when others then
                        NULL;
                end;
             end if;
       end;
   end loop;
end pr_can_aut_catastro;

PROCEDURE pr_gen_mov_bancard
(  p_hora            ge_movimientos.hora%type,
   p_nro_secuencia   ge_movimientos.nro_secuencia%type,
   p_cod_ent_debito  ge_bancos.cod_banco%type,
   p_monto           ge_movimientos.monto%type,
   p_cod_moneda      ba_monedas.cod_moneda%type
) IS

   v_nro_cuenta      ge_movimientos.nro_cuenta%TYPE;
   v_tip_mov_rubro   ge_movimientos.tip_mov_rubro%TYPE;
   v_cod_moneda      ge_movimientos.cod_moneda%TYPE;
   v_cod_modulo      ge_movimientos.cod_modulo%TYPE := 4;
   v_cod_modalidad   ge_movimientos.cod_modalidad%TYPE := 42;
   v_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
   --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del Pa�s sin Banco Sponsor
   v_cod_ent_procesadora ge_entes.cod_ente%TYPE;
   v_mad_ent_pais    ge_movimientos.cod_modalidad%TYPE := 49;
   v_cotizacion      ge_movimientos.cotizacion%TYPE;
   v_cot_mon_local   ge_movimientos.cotizacion%TYPE;
   v_con_debito      ge_movimientos.concepto%TYPE := 'Saldos BANCARD - BCO. PAIS';
   v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE := p_nro_secuencia;
   v_mto_equ_local   ge_movimientos.mto_equ_local%TYPE := 0;
   v_cod_tra_padre   ge_movimientos.cod_transaccion%TYPE;
   v_cod_mod_padre   ge_movimientos.cod_mod_padre%TYPE := 4;
   v_cod_mad_padre   ge_movimientos.cod_mad_padre%TYPE := 42;
   v_monto           ge_movimientos.monto%type := abs(p_monto);
BEGIN
   --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del Pa�s sin Banco Sponsor
   BEGIN
     /*Halla el Cod. de Ente por el Cod. de la Entidad Financiera
       En la Procesadora Parametrizada.*/
     SELECT cod_ente
       INTO v_cod_ent_procesadora
       FROM ge_par_entes a
      WHERE a.parametro = 'COD_ENT_FINANCIERA'
        AND to_number(a.val_parametro) = p_cod_ent_debito;
   EXCEPTION
       WHEN NO_DATA_FOUND THEN
          v_cod_ent_procesadora := NULL;
   END;
   /*se recupera el nro de cuenta y moneda de la cuenta*/
   BEGIN
      SELECT nro_cuenta, cod_moneda
        INTO v_nro_cuenta, v_cod_moneda
        FROM cc_cta_bancarias
       WHERE (cod_banco     = p_cod_ent_debito
         AND cod_modalidad = v_cod_modalidad) -- Modalidad de ATM'S Bancos.
          OR (cod_ente = v_cod_ent_procesadora
         AND cod_modalidad = v_mad_ent_pais) -- Modalidad de ATM'S Financieras.
         AND cod_moneda    = p_cod_moneda;

   EXCEPTION
      when no_data_found then
         pas_snp.g_cod_error := 99;
         pas_snp.g_msj_error := 'No se encuentra Cuenta Bancaria ' ||'Banco : '||p_cod_ent_debito;
      WHEN OTHERS THEN
         pas_snp.g_cod_error := 100;
         pas_snp.g_msj_error := 'Error recuperando Cuenta Bancaria ' || sqlerrm;
   END;

   /*se carga el codigo de transaccion segun el monto (si es negativo es debito y positivo credito*/
   IF p_monto < 0 THEN
      v_cod_transaccion := 4712;
   ELSE
      v_cod_transaccion := 4711;
   END IF;

   /*se define el tra padre segun la transaccion*/
   v_cod_tra_padre := v_cod_transaccion;

   /* condicion para mto_equ_local ,cdo es moneda extranjera por la cotizacion */
   v_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda, trunc(SYSDATE));
   IF p_cod_moneda != pag_gen.fu_obt_mon_local THEN
      pas_snp.pr_con_mon_a_moneda(p_cod_moneda,
                                  pag_gen.FU_OBT_MON_LOCAL,
                                  abs(p_monto),
                                  v_mto_equ_local,
                                  v_cotizacion,
                                  v_cot_mon_local);
   END IF;

   /*Recupera el tipo de Transaccion*/
   v_tip_mov_rubro := pas_snp.fu_obt_tip_mov_transaccion(v_cod_modulo, v_cod_modalidad, v_cod_transaccion);

   /*Carga el Rubro*/
   pag_cta.pr_set_cod_rubro(pac_che.fu_obt_rub_cta_ban(v_nro_cuenta), v_tip_mov_rubro);

   /*Genera movimientos*/
   prg_ver_mod_horario;
   pag_cta.pr_act_operacion(v_nro_cuenta,
                            p_hora,
                            v_tip_mov_rubro,
                            v_cod_moneda,
                            abs(v_monto),
                            v_cod_tra_padre,
                            v_cod_transaccion,
                            NULL,
                            v_cotizacion,
                            fug_obt_ofi_usuario(USER),
                            v_cod_mod_padre,
                            v_cod_mad_padre,
                            NULL,
                            NULL,
                            v_con_debito,
                            'S',
                            v_nro_secuencia,
                            g_fec_actual,
                            NULL,
                            NULL,
                            v_mto_equ_local);
END pr_gen_mov_bancard;

PROCEDURE pr_gen_men_pag_proveedor( p_cod_ente in ge_entes.cod_ente%type,
                                    p_usuario  in ba_usuarios.cod_usuario%type,
                                    p_fec_pago date,
                                    p_nro_archivo ge_pag_proveedores.nro_archivo%type )
IS
   /*
   || Proceso de env�o de SWIFTS a BCP de Pagos a Proveedores
   */
  --PRAGMA AUTONOMOUS_TRANSACTION;
  c_fec_valor           constant date := nvl( p_fec_pago, pag_cal.fu_obt_fec_actual(1));
  v_est_periodo         varchar2(1);
  rg_gle                ge_log_envios%rowtype;
  cursor cu_msj_av is --Cursor de alto valor
     select t.nro_referencia, t.cod_msj_swift, t.cod_tip_operacion, t.cod_sub_tip_operacion
       from ge_snp_transferencias t, ge_pag_proveedores p
      where t.nro_referencia           = p.nro_referencia
        and t.fec_valor                =  c_fec_valor
        and nvl( t.ind_valor,'N' )     = 'S'          -- Alto Valor
        and t.estado                   = 'A'          -- Aprobado en ITGF
        and t.situacion                = 'P'          -- Pendiente de env�o a BCP
        and t.cod_msj_swift            IN ( 103/*,202*/ )
        and t.nro_lote                 IS NULL        -- Si nro_lote es NULO significa que todavia no se proces�.
        and t.nro_ref_externa          IS NULL        -- Para MT enviados
        and t.fec_recepcion            IS NULL        -- Para MT enviados
        and t.error                    IS NULL
        and t.monto                    <> 0
        and t.fecha                    IS NOT NULL
        and t.hora                     IS NOT NULL
        and t.cod_usuario              IS NOT NULL
        and t.nro_cta_pte_solicitante  IS NOT NULL
        and p.cod_ente                 = p_cod_ente
        and p.estado                   = 'N'
        and p.usu_insercion            = p_usuario
        and p.for_pago                 = 'I'
        and trunc(p.fec_pago)          = trunc(p_fec_pago)
        and p.nro_archivo              = p_nro_archivo
        --25/05 Pago a Proveedores (302)
        and t.cod_tra_padre= 302
        order by p.nro_cta_debito, t.nro_referencia;
  -- Procedimiento de insercion de LOG --
  procedure pr_ins_log_envios(rp_gle ge_log_envios%rowtype) is
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_nro_intento ge_log_envios.nro_intento%type;
  begin
    begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; end;
    insert into ge_log_envios(nro_referencia,nro_intento,error)
    values(rp_gle.nro_referencia,rp_gle.nro_intento,rp_gle.error);
    commit;
  exception
    when dup_val_on_index then
      begin
        select max(nvl(nro_intento,0))+1
          into v_nro_intento
          from ge_log_envios
         where nro_referencia = rp_gle.nro_referencia;
        insert into ge_log_envios(nro_referencia,nro_intento,error)
        values(rp_gle.nro_referencia,v_nro_intento,rp_gle.error);
        commit;
      exception
        when others then
          null;
      end;
     when others then
       null;
  end pr_ins_log_envios;
BEGIN
   --DYDMR-1626--
   g_lugar := 'PAS_SNP.PR_GEN_MEN_AUTOMATICOS';
   /* Inicializa la aplicacion*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   --
   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   --
   /*Inicializa las variables de error*/
   pas_snp.pr_ini_variables;
   --
   -- Se procesa los mensajes MT103 --
   for reg in cu_msj_av loop
     begin
         pas_snp.pr_obt_mensaje ( reg.nro_referencia, 'N' );
         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.g_msj_error := 'OBTENER MENSAJERIA: '||g_msj.nro_referencia || ' - ' || pas_snp.g_msj_error ;
            rg_gle.nro_referencia := g_msj.nro_referencia;
            rg_gle.nro_intento := 1;
            rg_gle.error := pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error;
            pr_ins_log_envios(rg_gle);
            GOTO siguiente_registro;
         end if;
      exception
         when others then
            pas_snp.g_cod_error := 99;
            pas_snp.g_msj_error := 'OBTENER MENSAJERIA: '||g_msj.nro_referencia || ' - ' || sqlerrm;
            rg_gle.nro_referencia := g_msj.nro_referencia;
            rg_gle.nro_intento := 1;
            rg_gle.error := pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error;
            pr_ins_log_envios(rg_gle);
            GOTO siguiente_registro;
      end;
      if pas_snp.fu_ver_mov_duplicados(g_msj) > 0 then
         pas_snp.pr_ini_workflow(g_msj);
         g_msj.estado := 'S';
         pas_snp.pr_set_transferencias(g_msj);
         if pas_snp.fu_obt_cod_error <> 0 then
            pas_snp.g_msj_error := 'MOVIMIENTOS DUPLICADOS: '||g_msj.nro_referencia || ' - ' || pas_snp.g_msj_error ;
            rg_gle.nro_referencia := g_msj.nro_referencia;
            rg_gle.nro_intento := 1;
            rg_gle.error := pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error;
            pr_ins_log_envios(rg_gle);
            GOTO siguiente_registro;
         end if;
      else
         --Si es para hoy hago movimiento y envio--
         v_est_periodo:= nvl(pas_snp.fu_obt_est_horario(g_msj.cod_msj_swift, g_msj.cod_tip_operacion, g_msj.cod_sub_tip_operacion),'C');
         if g_msj.fec_valor = pag_cal.FU_OBT_FEC_ACTUAL(1)
            and v_est_periodo='A' then
            begin
               --Se llama para que pueda reversar si hay errores en Socket
               pas_snp.pr_gen_pro_swift(g_msj.nro_referencia, 'S');
               if pas_snp.g_cod_error != 0 then
                  pas_snp.g_msj_error := 'ERROR AL ENVIAR MENSAJERIA: '||g_msj.nro_referencia || ' - ' || pas_snp.g_msj_error ;
                  rg_gle.nro_referencia := g_msj.nro_referencia;
                  rg_gle.nro_intento := 1;
                  rg_gle.error := pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error;
                  pr_ins_log_envios(rg_gle);
                  GOTO siguiente_registro;
               end if;
            exception
               when others then
                   pas_snp.g_cod_error := 99;
                   pas_snp.g_msj_error := 'ERROR AL ENVIAR MENSAJERIA: '||g_msj.nro_referencia || ' - ' || sqlerrm ;
                   rg_gle.nro_referencia := g_msj.nro_referencia;
                   rg_gle.nro_intento := 1;
                   rg_gle.error := pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error;
                   pr_ins_log_envios(rg_gle);
                   GOTO siguiente_registro;
            end;
         end if;
      end if;
        <<siguiente_registro>> NULL;
   end loop;
   commit;
EXCEPTION
   when others then
      pas_snp.g_cod_error := 99;
      pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
      rg_gle.nro_referencia := pas_snp.fu_obt_cod_error;
      rg_gle.nro_intento := 1;
      rg_gle.error := pas_snp.fu_obt_cod_error||' - '||pas_snp.fu_obt_msj_error;
      pr_ins_log_envios(rg_gle);
END pr_gen_men_pag_proveedor;

FUNCTION fu_ver_cuenta
  (p_cta in varchar2)
  return varchar2 is
    existe number;
    v_cta_as400 varchar2(40);
  Begin
    -- Primero verificar si la cuenta existe en ge_cuentas si no
    -- convertir al formato IT
    Select count(*) into existe
      from ge_cuentas
     where nro_cuenta = p_cta;
     --Cortamos 14 Digitos para verificar si es de AS400
     --Las cuentas de SIPAP
     IF length(p_cta)= 16 then
        v_cta_as400:= trim(substr(p_cta,3,14));
     else
        v_cta_as400:= p_cta;
     end if;

    if  existe = 0 then
      if  substr(v_cta_as400,3,6) in('210100','215000') then
         Select count(*) into existe
           from ge_cuentas
          where nro_cuenta = substr(v_cta_as400,1,2)||'01'||substr(v_cta_as400,9,6);
         if  existe = 0 then
            return  (substr(v_cta_as400,1,2)||'07'||substr(v_cta_as400,9,6));
         else
            return  (substr(v_cta_as400,1,2)||'01'||substr(v_cta_as400,9,6));
         end if;
      elsif substr(v_cta_as400,3,6) in('210500','215500') then
         Select count(*) into existe
           from ge_cuentas
          where nro_cuenta = substr(v_cta_as400,1,2)||'02'||substr(v_cta_as400,9,6);
         if  existe = 0 then
           return  (substr(v_cta_as400,1,2)||'08'||substr(v_cta_as400,9,6));
         else
           return  (substr(v_cta_as400,1,2)||'02'||substr(v_cta_as400,9,6));
         end if;
      elsif substr(v_cta_as400,3,6) = '999999' then
        return  '999999999999999';
      else
        --Sino encuentra, retorna la misma Cta Ingresada
        v_cta_as400:=p_cta;
        return v_cta_as400;
      End if;
    else
      return v_cta_as400;
    end if;
End fu_ver_cuenta;

PROCEDURE pr_gen_pro_swift( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                            p_val_movimientos in varchar2 default 'S',
                            p_estado ge_snp_transferencias.estado%type default 'A'
                          )
IS
BEGIN
  --Se llama la gen_arc_swift para mensajeria de Pago a Proveedores
   --DYDMR-1626--
    g_lugar := 'PAS_SNP.PR_GEN_MEN_AUTOMATICOS';
    pas_snp.pr_gen_arc_swift(p_nro_referencia, p_val_movimientos);

EXCEPTION
   when ex_horario then
      pas_snp.g_cod_error := 54;
      pas_snp.g_msj_error := g_lugar || ' ' || pas_snp.fu_obt_msj_error;
   when ex_salir then
      pas_snp.g_cod_error := 54;
      pas_snp.g_msj_error := g_lugar || ' - ' || pas_snp.fu_obt_msj_error;
   when others then
      pas_snp.g_cod_error := 54;
      pas_snp.g_msj_error := g_lugar || ' - ' || sqlerrm;
END pr_gen_pro_swift;

----------------------------------------------------------
PROCEDURE pr_get_val_tags_MTN96 (p_texto in clob,
                           p_nro_ref_externa out ge_snp_transferencias.nro_referencia%TYPE,
                           p_cod_swift       out ge_snp_transferencias.cod_msj_swift%TYPE,
                           p_sub_tipo_mt     out varchar2)
IS

   r_sb_snp_tmp_mensajes sb_snp_mensajes_tmp%rowtype := null;
   v_cod_mensaje         sb_snp_tip_mensajes.cod_mensaje%type;
   v_can_lineas          number;
   v_det_campo           sb_snp_campos.campo%type;

begin

/* Proceso para obtener los tags de referencia externa, codigo swift y subtipo MT para un MTN96
     Creado por TRFS-1088 PHT
*/
   begin
     --obtengo el mensaje, si no encuentra esquematizado igual se debe registrar en GE_SNP_MENSAJES
     v_cod_mensaje := pao_pmt.fu_obt_cod_mensaje(p_texto);
   exception  when others then
     raise;
   end;
   --Obtengo el campo PK del Detalle
   select max(d.campo)
     into v_det_campo
     from sb_snp_campos d
    where d.cod_mensaje = v_cod_mensaje
      and d.orden = (select min(orden)
                       from sb_snp_campos
                      where cod_mensaje = d.cod_mensaje
                        and ind_detalle = d.ind_detalle)
      and d.ind_detalle = 'S';
   --Se cuentan la cantidad de l�neas para el recorrido
   select count(*)
     into v_can_lineas
     from table(fug_obt_tab_registro(replace(p_texto, chr(13)), chr(10)));

   -- Recorro las lineas del swift
   for i in 1..v_can_lineas loop
      r_sb_snp_tmp_mensajes.cod_mensaje := v_cod_mensaje;
      r_sb_snp_tmp_mensajes.orden := i;
      r_sb_snp_tmp_mensajes.valor := trim(pao_pmt.fu_obt_linea(p_texto, r_sb_snp_tmp_mensajes.orden));
      r_sb_snp_tmp_mensajes.campo := nvl(pao_pmt.fu_obt_campo(r_sb_snp_tmp_mensajes.valor), r_sb_snp_tmp_mensajes.campo);
      if r_sb_snp_tmp_mensajes.campo = pao_pmt.fu_obt_campo(r_sb_snp_tmp_mensajes.valor) then
         r_sb_snp_tmp_mensajes.nro_linea := 1;
         if nvl(v_det_campo, '*') = r_sb_snp_tmp_mensajes.campo then
            r_sb_snp_tmp_mensajes.nro_detalle := nvl(r_sb_snp_tmp_mensajes.nro_detalle, 0) + 1;
         end if;
      else
         r_sb_snp_tmp_mensajes.nro_linea := r_sb_snp_tmp_mensajes.nro_linea + 1;
      end if;
      r_sb_snp_tmp_mensajes.valor := trim(replace(r_sb_snp_tmp_mensajes.valor, ':'||r_sb_snp_tmp_mensajes.campo||':'));

      -- Si la linea es uno de los Tags deseados, se setea la variable de salida
      if  r_sb_snp_tmp_mensajes.campo = '21' then
        p_nro_ref_externa := r_sb_snp_tmp_mensajes.valor;
      elsif r_sb_snp_tmp_mensajes.campo = '11R'  and r_sb_snp_tmp_mensajes.nro_linea = 1 then
        p_cod_swift := r_sb_snp_tmp_mensajes.valor;
      elsif r_sb_snp_tmp_mensajes.campo = '76' and r_sb_snp_tmp_mensajes.orden =  5 then
        p_sub_tipo_mt := substr(r_sb_snp_tmp_mensajes.valor,1,4);
      end if;
   end loop;


END pr_get_val_tags_MTN96;

----------------------------------------------------------
FUNCTION fu_val_MTN96(p_texto in clob)
RETURN NUMBER
IS
  v_return NUMBER:=0;

  v_nro_ref_externa ge_snp_transferencias.nro_referencia%TYPE;
  v_cod_swift       ge_snp_transferencias.cod_msj_swift%TYPE;
  v_sub_tipo_mt     varchar2(40);
BEGIN

  /* Proceso para validar existencia de la referencia de un 196 antes de intentar procesar el archivo
     Creado por TRFS-1088 PHT
     Return:
       Mayor a 0 - Existe la referencia del MTN96
       Igual a 0 - No existe la referencia
       Menor a 0 - Se detecto algun error durante la validacion
  */

  --Obtengo los valores del MTN96
  pr_get_val_tags_MTN96 (p_texto => replace(p_texto,pas_snp.fu_obt_sal_socket,pas_snp.fu_obt_salto),
                   p_nro_ref_externa => v_nro_ref_externa,
                   p_cod_swift => v_cod_swift,
                   p_sub_tipo_mt  => v_sub_tipo_mt);


  --Dependiendo el subtipo del 196, busco que exista su referencia en el Core
  IF v_sub_tipo_mt = 'NETS' THEN
    select count(*)
    INTO v_return
    from ge_snp_transferencias ge
    where ge.nro_lote = to_char(v_nro_ref_externa)
      and ge.cod_msj_swift = v_cod_swift
      and ge.fec_recepcion is null
      and ge.estado = 'A'
      and ge.situacion = 'O';
  ELSIF v_sub_tipo_mt in ('NETR', 'NETA', 'NETL') THEN
    select count(*)
    INTO v_return
    from ge_snp_transferencias ge
    where ge.nro_lote = to_char(v_nro_ref_externa)
      and ge.cod_msj_swift = v_cod_swift
      and ge.fec_valor <= g_fec_actual;
  ElSIF v_sub_tipo_mt in ('ERRC','ERRP') AND v_cod_swift in (102, 104) THEN
    select count(*)
    INTO v_return
    from ge_snp_transferencias ge
    where ge.nro_lote = to_char(v_nro_ref_externa)
      and ge.cod_msj_swift = v_cod_swift;
  ELSE
    select count(*)
    INTO v_return
    from ge_snp_transferencias t
    where t.nro_referencia  = v_nro_ref_externa;
  END IF;

  --Si la referencia existe, se retornara un valor mayor a 0
  RETURN v_return;

EXCEPTION WHEN OTHERS THEN
    RETURN -1;
END fu_val_MTN96;

end PAS_SNP;
/

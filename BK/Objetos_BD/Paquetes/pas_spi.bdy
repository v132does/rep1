create or replace package body it.PAS_SPI is
function fu_obt_cod_error return number
IS
--https://itti-digital.atlassian.net/browse/NVB-3811
   /*
   || Obtiene el código de error del registro del paquete.
   */
BEGIN
   return PAS_SPI.g_cod_error;
END fu_obt_cod_error;
FUNCTION fu_obt_msj_error return varchar2
IS
   /*
   || Obtiene el mensaje de error contenido en el registro del paquete.
   */
BEGIN
   return PAS_SPI.g_msj_error;
END fu_obt_msj_error;
function fu_tip_msj_spi(p_cod_msj_swift  ge_snp_par_mensajes.cod_msj_swift%type) return varchar2 is
      v_tipo_msj ge_snp_par_mensajes.tipo%type;
begin
  g_lugar:='Busca el tipo de mensaje en base al codigo swift en ge_snp_par_mensajes ';
   begin
      select tipo
        into v_tipo_msj
        from ge_snp_par_mensajes
       where cod_msj_swift = p_cod_msj_swift
       fetch first 1 rows only; --SPI Fase 2
      return v_tipo_msj;
   end;
exception
when others then
      PAS_SPI.g_cod_error := 150;
      PAS_SPI.g_msj_error := 'Error en PAS_SPI.fu_tip_msj_spi' || ' - ' ||g_lugar || ' - ' || sqlerrm;
      pas_snp.pr_reg_operacion( 'Error al Obtener tipo de mensaje:'||p_cod_msj_swift, g_lugar|| '|' ||PAS_SPI.g_msj_error );  
      return 'N';
end fu_tip_msj_spi;
function fu_tip_msj_ver(p_cod_msj_mx  ge_spi_cab_versiones.version%type) return varchar2 is
  /*
   || Obtiene el Tipo de mensaje en base a la versión del mensaje.
   */
    v_tipo_msj ge_spi_cab_versiones.tipo_msj%type;
    v_aux_mx  ge_spi_cab_versiones.version%type;
begin
  if instr(p_cod_msj_mx,'/') <> 0 then
     v_aux_mx :=trim(substr(p_cod_msj_mx,1, instr(p_cod_msj_mx,'/')-1));
  else    
     v_aux_mx := p_cod_msj_mx ;
  end if;
  begin
      select tipo_msj
        into v_tipo_msj
        from ge_spi_cab_versiones
       where version = v_aux_mx; --p_cod_msj_mx; 
      return v_tipo_msj;
   end;
exception
when others then
      PAS_SPI.g_cod_error := 140;
      PAS_SPI.g_msj_error := 'Error en PAS_SPI.fu_tip_msj_ver' || ' - ' || sqlerrm;
       pas_snp.pr_reg_operacion( 'Error al Obtener el Tipo de mensaje en base a la versión'||p_cod_msj_mx, g_lugar|| '|' ||PAS_SPI.g_msj_error );  
      return 'N';
end fu_tip_msj_ver;
procedure pr_gen_mov_snp ( p_hora            in  ge_movimientos.hora%type,
                           p_fecha           in  ge_movimientos.fecha%type,
                           p_cod_usuario     in  ge_movimientos.cod_usuario%type,
                           p_gen_workflow    in  varchar2 default 'S',
                           p_origen          in  ge_snp_transferencias.origen%type default 'I',
                           p_plataforma      in  ge_snp_transferencias.plataforma%type default 'S',
                           p_nro_ref_externa in  ge_snp_transferencias.nro_ref_externa%type default null,
                           p_ind_enviado     in  varchar2 default 'S',
                           p_cod_programa    out ba_programas.cod_programa%type,
                           p_nro_referencia  out ge_snp_transferencias.nro_referencia%type
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
         AND m.cod_tra_padre = pas_snp.fu_obt_cod_tra_padre
         AND m.cod_mod_padre = pas_snp.fu_obt_cod_mod_padre
         AND m.cod_mad_padre = pas_snp.fu_obt_cod_mad_padre
         AND m.nro_documento2 IS NOT NULL
       ORDER by m.nro_secuencia DESC;
BEGIN
  /*Inicializa la aplicacion y el modulo*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   IF p_fecha IS NULL THEN
      v_fecha := pas_snp.g_fec_actual;
   ELSE
      v_fecha := p_fecha;
   END IF;
   p_cod_programa  := NULL ;
   BEGIN
       FOR dt IN datos LOOP
           v_cod_msj_swift     := substr(dt.nro_documento2,1,1);
           v_tip_operacion     := substr(dt.nro_documento2,2,3);
           v_sub_tip_operacion := substr(dt.nro_documento2,5,3);
           IF v_cod_msj_swift IN ( 102, 103, 202,8 ) AND
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
                    -- Solo si es operación de Retiro/Depósito en Efectivo levantar el GMSNPDEE
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
   IF p_cod_programa is not null then
      --Cargar datos mas importantes en la tabla ge_snp_transferencias
      begin
        select nro_referencia
          into v_nro_referencia
          from ge_snp_transferencias t
         where t.fecha        = v_fecha
           and t.hora         = p_hora
           and t.cod_usuario  = nvl( p_cod_usuario, user );

      exception
         when no_data_found then
           begin
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
              exception
                 when others then
                   v_prioridad := case nvl( v_cod_msj_swift, 102 )
                                    when 102 then 100
                                    else 20
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

              -- Si el Nro. Cta del Solicitante tiene algún valor entonces se recupera los datos de la persona relacionada a ella.
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
              pas_snp.g_lugar :=  'Insertando Mensajería.., ';
              pas_snp.pr_ins_transferencias ( pas_snp.g_msj );
              if pas_snp.fu_obt_cod_error <> 0 then
                 raise_application_error (-20001, pas_snp.fu_obt_msj_error);
              end if;

              BEGIN
                 UPDATE ge_movimientos m
                    SET m.nro_documento  = to_number( substr( v_nro_referencia,1,15 ) ),
                        m.concepto       = DECODE( m.nro_documento2, NULL, m.concepto, pas_snp.g_msj.concepto )
                  WHERE m.hora           = p_hora
                    AND m.cod_usuario    = nvl( p_cod_usuario, USER )
                    AND m.fecha          = v_fecha
                    AND m.cod_mod_padre  = pas_snp.fu_obt_cod_mod_padre
                    AND m.cod_mad_padre  = pas_snp.fu_obt_cod_mad_padre
                    AND m.cod_tra_padre  = pas_snp.fu_obt_cod_tra_padre
                    AND m.monto          > 0;
                 IF sql%notfound THEN
                    raise_application_error(-20002, 'No se ha podido RELACIONAR el movimiento con el SWIFT generado. Fecha: '|| to_char( v_fecha,'DD/MM/YYYY' ) ||
                                                                                                                    ' Hora: '|| p_hora ||
                                                                                                                    ' Usu : '|| nvl( p_cod_usuario, USER ) );
                 END IF;
              END;
              --
             IF p_gen_workflow = 'S' THEN
               pas_snp.g_msj.cod_msj_swift :=8;
                pas_snp.pr_ini_workflow( pas_snp.g_msj );
                if pas_snp.fu_obt_cod_error <> 0 then
                   raise_application_error (-20003, pas_snp.fu_obt_msj_error);
                else
                   commit ;
                end if;
              END IF;
              --
           END;
      END;
      p_nro_referencia := v_nro_referencia;
   END IF;
EXCEPTION
   WHEN dup_val_on_index THEN
      raise_application_error( -20004,' Ya existen registros en ge_snp_transferencias para el número de transferencia '||p_nro_referencia||', verifique.!' );
   WHEN others then
      IF sqlcode <= -20000 THEN
         raise;
      ELSE
         raise_application_error( -20005,'Error en PAS_SPI.PR_GEN_MOV_SNP' || '-' || sqlerrm );
      END IF;

END pr_gen_mov_snp;
PROCEDURE pr_gen_inf_spi(p_nro_cuenta  in ge_spi_informes.nro_cta_solicitante%type,
                                                   p_cod_moneda  in ge_spi_informes.cod_moneda%type,
                                                   p_monto       in ge_spi_informes.monto%type,
                                                   p_cod_informe in varchar2,
                                                   p_nro_ref_original in ge_snp_transferencias.nro_ref_externa%type)
 /*Genera la solicitud del reporte insertando datos en la tabla ge_spi_reportes*/
IS
  no_procesa exception;
  verror     exception;
  v_nro_referencia ge_spi_informes.nro_referencia%type;
  v_fecha constant date := pag_cal.fu_obt_fec_actual(1);
  r_infspi ge_spi_informes%rowtype;
  v_cod_moneda           varchar2(3)    := null;
  v_fec_tra_ori ge_snp_transferencias.fecha%type;
  v_hor_tra_ori  ge_snp_transferencias.hora%type;
  v_cod_swi_pte_solicitante ge_snp_transferencias.cod_swi_pte_solicitante%type;
  v_fec_valor               ge_snp_transferencias.fec_valor%type;
  v_version                 ge_spi_cab_versiones.version%type;
 
  /* Insertar datos en ge_spi_informes */
  PROCEDURE pr_ins_spi_informes(r_infspi IN ge_spi_informes%ROWTYPE

                                ) IS
  BEGIN
    g_lugar:='Inserta en ge_spi_informes';
    INSERT INTO ge_spi_informes
      (nro_referencia,
       nro_ref_externa,
       cod_msj_mx,
       fecha,
       hora,
       tipo_limite,
       tipo_informe,
       nro_cta_solicitante,
       cod_swi_solicitante,
       cod_moneda,
       monto,
       msj_mx,
       fec_recepcion,
       situacion,
       estado,
       error,
       par_rec_consulta,
       inf_suplementaria,
       nro_ref_msj_original,
       tip_msj_original,
       fec_ins_msj_original,
       hor_ins_msj_original,
       cod_swi_sol_original,
       fec_valor_msj_original,
       usu_insercion,
       fec_insercion,
       usu_modificacion,
       fec_modificacion)
    VALUES
      (r_infspi.nro_referencia,
       r_infspi.nro_ref_externa,
       r_infspi.cod_msj_mx,
       r_infspi.fecha,
       r_infspi.hora,
       r_infspi.tipo_limite,
       r_infspi.tipo_informe,
       r_infspi.nro_cta_solicitante,
       r_infspi.cod_swi_solicitante,
       r_infspi.cod_moneda,
       r_infspi.monto,
       r_infspi.msj_mx,
       r_infspi.fec_recepcion,
       r_infspi.situacion,
       r_infspi.estado,
       r_infspi.error,
       r_infspi.par_rec_consulta,
       r_infspi.inf_suplementaria,
       r_infspi.nro_ref_msj_original,
       r_infspi.tip_msj_original,
       r_infspi.fec_ins_msj_original,
       r_infspi.hor_ins_msj_original,
       r_infspi.cod_swi_sol_original,
       r_infspi.fec_valor_msj_original,
       r_infspi.usu_insercion,
       r_infspi.fec_insercion,
       r_infspi.usu_modificacion,
       r_infspi.fec_modificacion);
  END;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  pas_snp.g_cod_error := 0;
  pas_snp.g_msj_error := NULL;
  g_lugar:='Asigna datos varios para generacion de informe';
  select to_number(to_char(v_fecha, 'RRMMDD') ||
                   s_nro_ref_spi_inf.nextval)
    into v_nro_referencia
    from dual;
  r_infspi.nro_referencia  := v_nro_referencia;
  r_infspi.nro_ref_externa := PAS_SPI.fu_obt_sig_nro_ref_externa;
  r_infspi.msj_mx          := null; --Se inserta despues
  r_infspi.cod_msj_mx      := p_cod_informe;
  r_infspi.fecha           := trunc(sysdate);
  r_infspi.hora            := to_char(sysdate, 'HH24:MI:SS');
  r_infspi.situacion       := 'P';
  r_infspi.estado          := 'U';--ya se inserta autorizado
  r_infspi.error           := null;
  r_infspi.usu_insercion   := user;
  r_infspi.fec_insercion   := sysdate;
  r_infspi.nro_cta_solicitante := p_nro_cuenta;
  g_lugar:='Obtiene swift participante solicitante';
  r_infspi.cod_swi_solicitante :=pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
  if p_cod_informe = g_cam_009 then
    g_lugar:='Asigna datos varios para camt.009';
    r_infspi.tipo_limite   := null;
    r_infspi.tipo_informe  := null;
    r_infspi.monto         := null;
    r_infspi.fec_recepcion := null;
    v_cod_moneda:= CASE p_cod_moneda WHEN g_cod_mon_local THEN g_cod_mon_iso_local ELSE p_cod_moneda END;
    r_infspi.Cod_Moneda          := v_cod_moneda;
  end if;
  if p_cod_informe = g_cam_011 then
    g_lugar:='Asigna datos varios para camt.011';
    r_infspi.monto         := p_monto;
    r_infspi.tipo_limite   := fug_obt_pardinamico( 'SPI_TIP_LIMITE' );
    r_infspi.tipo_informe  := null;
    r_infspi.fec_recepcion := null;
    v_cod_moneda:= CASE p_cod_moneda WHEN g_cod_mon_local THEN g_cod_mon_iso_local ELSE p_cod_moneda END;
    r_infspi.Cod_Moneda          := v_cod_moneda;
  end if;
   if p_cod_informe = g_cam_060 then
    g_lugar:='Asigna datos varios para camt.060';
    r_infspi.monto         := null;
    r_infspi.tipo_limite   := null;
    r_infspi.tipo_informe  := fug_obt_pardinamico( 'SPI_TIP_INFORME' );
    r_infspi.fec_recepcion := null;
    r_infspi.Cod_Moneda    := null;
  end if;
  if p_cod_informe = g_pac_028 then
    g_lugar:='Asigna datos varios para pacs.028';
    select nvl(a.fecha,trunc(a.fec_recepcion)), nvl(a.hora,to_char(a.fec_recepcion,'HH24:MI:SS')), a.cod_swi_pte_solicitante, a.fec_valor
      into v_fec_tra_ori,
           v_hor_tra_ori,
           v_cod_swi_pte_solicitante,
           v_fec_valor
      from ge_snp_transferencias a
     where a.nro_ref_externa = p_nro_ref_original;
    g_lugar:='Obtiene version para del pacs.008';
    select version
      into v_version
      from ge_spi_cab_versiones
     where tipo_msj = g_pac_008;
   g_lugar:='Asigna otros datos para pacs.028';
    r_infspi.monto         := null;
    r_infspi.tipo_limite   := null;
    r_infspi.tipo_informe  := null;
    r_infspi.fec_recepcion := null;
    r_infspi.Cod_Moneda    := null;
    r_infspi.msj_mx    := null;
    r_infspi.par_rec_consulta   :=fug_obt_pardinamico( 'SPI_BIC_RECEPTOR' );
    r_infspi.inf_suplementaria:= null;
    r_infspi.nro_ref_msj_original:=p_nro_ref_original;--nro_ref_externa del pacs.008 consultado
    r_infspi.tip_msj_original:=v_version;
    r_infspi.fec_ins_msj_original:=v_fec_tra_ori;
    r_infspi.hor_ins_msj_original:=v_hor_tra_ori;
    r_infspi.cod_swi_sol_original:=v_cod_swi_pte_solicitante;
    r_infspi.fec_valor_msj_original:=v_fec_valor;
  end if;
  if p_cod_informe = g_cam_033 then
      g_lugar:='Asigna datos varios para camt.033';
      select a.fecha, a.hora, a.cod_swi_pte_solicitante, a.fec_valor
        into v_fec_tra_ori,
             v_hor_tra_ori,
             v_cod_swi_pte_solicitante,
             v_fec_valor
        from ge_snp_transferencias a
       where a.nro_ref_externa = p_nro_ref_original;
      g_lugar:='Obtiene version para del camt.033';
      select version
        into v_version
        from ge_spi_cab_versiones
       where tipo_msj = g_pac_008;
     g_lugar:='Asigna otros datos para camt.033';
      r_infspi.monto         := null;
      r_infspi.tipo_limite   := null;
      r_infspi.tipo_informe  := null;
      r_infspi.fec_recepcion := null;
      r_infspi.Cod_Moneda    := null;
      r_infspi.msj_mx    := null;
      r_infspi.par_rec_consulta   :=fug_obt_pardinamico( 'SPI_BIC_RECEPTOR' );
      r_infspi.inf_suplementaria   :=fug_obt_pardinamico( 'SPI_INF_SUPLEMENTARIA' );
      r_infspi.nro_ref_msj_original:=p_nro_ref_original;--nro_ref_externa del pacs.008 consultado
      r_infspi.tip_msj_original:=v_version;
      r_infspi.fec_ins_msj_original:=v_fec_tra_ori;
      r_infspi.hor_ins_msj_original:=v_hor_tra_ori;
      r_infspi.cod_swi_sol_original:=v_cod_swi_pte_solicitante;
      r_infspi.fec_valor_msj_original:=v_fec_valor;
  end if;
  if p_cod_informe = g_cam_018 then
      g_lugar:='Asigna otros datos para camt.033';
      r_infspi.monto         := null;
      r_infspi.tipo_limite   := null;
      r_infspi.tipo_informe  := fug_obt_pardinamico( 'SPI_PERIOD' );
      r_infspi.fec_recepcion := null;
      r_infspi.Cod_Moneda    := null;
      r_infspi.msj_mx    := null;
      r_infspi.par_rec_consulta   :=fug_obt_pardinamico( 'SPI_BIC_RECEPTOR' );
      r_infspi.inf_suplementaria:=null;
      r_infspi.nro_ref_msj_original:=null;
      r_infspi.tip_msj_original:=null;
      r_infspi.fec_ins_msj_original:=null;
      r_infspi.hor_ins_msj_original:=null;
      r_infspi.cod_swi_sol_original:=null;
      r_infspi.fec_valor_msj_original:=null;
      r_infspi.nro_cta_solicitante :=PAS_SPI.fu_obt_cta_ban_participante( r_infspi.cod_swi_solicitante,g_cod_mon_local);
  end if;
  g_lugar:='Inserta el informe';
  pr_ins_spi_informes(r_infspi);
  commit;
exception
  when verror then
    PAS_SPI.g_cod_error := 110;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
    raise_application_error(-20000, 'pr_gen_inf_spi-: ' || p_cod_informe);
  when no_procesa then
    null;
  when others then
    PAS_SPI.g_cod_error := 111;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
    raise_application_error(-20000, 'pr_gen_inf_spi-: ' || sqlerrm);
END pr_gen_inf_spi;
PROCEDURE pr_gen_res_spi(p_nro_cuenta  in ge_spi_informes.nro_cta_solicitante%type,
                                                   p_cod_informe in varchar2,
                                                   p_nro_ref_original in ge_snp_transferencias.nro_ref_externa%type,
                                                   p_inf_suplementaria   varchar2)
 /*Genera la solicitud de respuesta insertando datos en la tabla ge_spi_reportes*/
IS
  no_procesa exception;
  verror     exception;
  v_nro_referencia ge_spi_informes.nro_referencia%type;
  v_fecha constant date := pag_cal.fu_obt_fec_actual(1);
  r_infspi ge_spi_informes%rowtype;
  v_fec_tra_ori ge_snp_transferencias.fec_recepcion%type;
  v_hor_tra_ori ge_snp_transferencias.hora%type;
  v_cod_swi_pte_solicitante ge_snp_transferencias.cod_swi_pte_solicitante%type;
  v_fec_valor               ge_snp_transferencias.fec_valor%type;
  v_version                 ge_spi_cab_versiones.version%type;
  /* Insertar datos en ge_spi_informes */
  PROCEDURE pr_ins_spi_informes(r_infspi IN ge_spi_informes%ROWTYPE

                                ) IS
  BEGIN
    g_lugar:='Inserta en ge_spi_informes';
    INSERT INTO ge_spi_informes
      (nro_referencia,
       nro_ref_externa,
       cod_msj_mx,
       fecha,
       hora,
       tipo_limite,
       tipo_informe,
       nro_cta_solicitante,
       cod_swi_solicitante,
       cod_moneda,
       monto,
       msj_mx,
       fec_recepcion,
       situacion,
       estado,
       error,
       par_rec_consulta,
       inf_suplementaria,
       nro_ref_msj_original,
       tip_msj_original,
       fec_ins_msj_original,
       hor_ins_msj_original,
       cod_swi_sol_original,
       fec_valor_msj_original,
       usu_insercion,
       fec_insercion,
       usu_modificacion,
       fec_modificacion)
    VALUES
      (r_infspi.nro_referencia,
       r_infspi.nro_ref_externa,
       r_infspi.cod_msj_mx,
       r_infspi.fecha,
       r_infspi.hora,
       r_infspi.tipo_limite,
       r_infspi.tipo_informe,
       r_infspi.nro_cta_solicitante,
       r_infspi.cod_swi_solicitante,
       r_infspi.cod_moneda,
       r_infspi.monto,
       r_infspi.msj_mx,
       r_infspi.fec_recepcion,
       r_infspi.situacion,
       r_infspi.estado,
       r_infspi.error,
       r_infspi.par_rec_consulta,
       r_infspi.inf_suplementaria,
       r_infspi.nro_ref_msj_original,
       r_infspi.tip_msj_original,
       r_infspi.fec_ins_msj_original,
       r_infspi.hor_ins_msj_original,
       r_infspi.cod_swi_sol_original,
       r_infspi.fec_valor_msj_original,
       r_infspi.usu_insercion,
       r_infspi.fec_insercion,
       r_infspi.usu_modificacion,
       r_infspi.fec_modificacion);
  END;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  g_lugar:='Asigna datos varios para generacion de informe';
  select to_number(to_char(v_fecha, 'RRMMDD') ||
                   s_nro_ref_spi_inf.nextval)
    into v_nro_referencia
    from dual;
  r_infspi.nro_referencia  := v_nro_referencia;
  r_infspi.nro_ref_externa := PAS_SPI.fu_obt_sig_nro_ref_externa;
  r_infspi.msj_mx          := null; --Se inserta despues
  r_infspi.cod_msj_mx      := p_cod_informe;
  r_infspi.fecha           := trunc(sysdate);
  r_infspi.hora            := to_char(sysdate, 'HH24:MI:SS');
  r_infspi.situacion       := 'P';
  r_infspi.estado          := 'U';--ya se inserta autorizado
  r_infspi.error           := null;
  r_infspi.usu_insercion   := user;
  r_infspi.fec_insercion   := sysdate;
  r_infspi.nro_cta_solicitante := p_nro_cuenta;
  g_lugar:='Obtiene swift participante solicitante';
  r_infspi.cod_swi_solicitante :=pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
  g_lugar:='Asigna datos varios para pacs.002';
      select trunc(a.fec_recepcion),to_char(a.fec_recepcion,'HH24:MI:SS'),  a.cod_swi_pte_solicitante, a.fec_valor
        into v_fec_tra_ori,
             v_hor_tra_ori,
             v_cod_swi_pte_solicitante,
             v_fec_valor
        from ge_snp_transferencias a
       where a.nro_ref_externa = p_nro_ref_original
       and rownum=1;
       select version
        into v_version
        from ge_spi_cab_versiones
       where tipo_msj = 'pacs.008';
       r_infspi.tipo_limite    := null;
       r_infspi.tipo_informe   := null;
       r_infspi.monto          := null;
       r_infspi.Cod_Moneda     := null;
       r_infspi.msj_mx         := null;
       r_infspi.fec_recepcion  := null;
       r_infspi.par_rec_consulta:=null;
       r_infspi.inf_suplementaria:=p_inf_suplementaria;
       r_infspi.nro_ref_msj_original:=p_nro_ref_original;--nro_ref_externa del pacs.008 recibido
       r_infspi.tip_msj_original:=v_version;
       r_infspi.fec_ins_msj_original:=v_fec_tra_ori;
       r_infspi.hor_ins_msj_original:=v_hor_tra_ori;
       r_infspi.cod_swi_sol_original:=v_cod_swi_pte_solicitante;
       r_infspi.fec_valor_msj_original:=v_fec_valor;
  g_lugar:='Inserta el informe';
  pr_ins_spi_informes(r_infspi);
  commit;
exception
  when verror then
    pas_spi.g_cod_error := 110;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
  when no_procesa then
    null;
  when others then
    pas_spi.g_cod_error := 111;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
END pr_gen_res_spi;
procedure pr_obt_fec_hor_actual
 (p_cod_modulo in ba_modulos.cod_modulo%type,
  p_fecha      out date,
  p_hora       out varchar2
 )

 is
   /*
   || Obtiene la fecha actual.
   */
v_fecha ge_calendarios.fec_actual%type;
v_hora      varchar2(8) := to_char(sysdate, 'hh24:mi:ss');
begin
begin
--obtiene la fecha actual del modulo
   select fec_actual
   into v_fecha
   from ge_calendarios
   where cod_modulo = p_cod_modulo;
   p_fecha:= v_fecha;

exception
    when no_data_found then
       raise_application_error(-20000,
       'No existe fecha actual p/mod. '||to_char(p_cod_modulo));

end;
p_hora:=v_hora;
end pr_obt_fec_hor_actual;
FUNCTION fu_obt_sig_nro_ref_externa ( p_fecha IN ge_snp_transferencias.fecha%type default NULL ) return varchar2
IS
   /*
   || Genera numero de referencia externa para el spi
   */

   v_nro_referencia varchar2(33);
   v_fecha         constant date:= trunc(sysdate);
   v_existe      char(1) := 'S';
   v_usu_spi     ge_par_dinamicos.val_parametro%type   := fug_obt_pardinamico( 'SPI_USU_CONEXION' );
   v_ref_sec     varchar2(10);
BEGIN
   pas_spi.g_cod_error := 0;
   pas_spi.g_msj_error := NULL;
   g_lugar:='Busca secuencia para referencia externa';
   select lpad(rtrim(s_nro_ref_spi.nextval),10,'0') into v_ref_sec from dual;
   g_lugar:='Concatena valores para para referencia externa';
   select v_usu_spi ||to_char( v_fecha, 'RRMMDD' ) || PAS_SPI.fu_obt_dif_seg ||v_ref_sec
     into v_nro_referencia
     from dual;

   /*
   || Se verifica si el número generado no existe aún.
   */
   g_lugar:='Verifica si existe ya un nro de referencia externa igual al generado';
   BEGIN
     select distinct 'S'
       into v_existe
       from ge_snp_transferencias
      where nro_ref_externa = v_nro_referencia;
   EXCEPTION
      WHEN no_data_found THEN
         v_existe := 'N';
      WHEN others THEN
         v_existe := 'S';
   END;

   if v_existe = 'S' then
      PAS_SPI.g_cod_error := 171;
      PAS_SPI.g_msj_error := 'Error en fu_obt_sig_nro_ref_externa: El Nro. Referencia ' || to_char( v_nro_referencia ) ||' generado ya existe.';
   end if;

   Return v_nro_referencia;

EXCEPTION
   WHEN OTHERS THEN
    PAS_SPI.g_cod_error := 170;
    PAS_SPI.g_msj_error := 'Error en fu_obt_sig_nro_ref_externa' || ' - ' ||g_lugar || ' - ' || sqlerrm;
    return v_nro_referencia;
END fu_obt_sig_nro_ref_externa;
function fu_obt_dif_seg return number is
  /*
   || Genera la diferencia de segundo desde las 00 hs
   || esta diferencia se utiliza para el numero de referencia externa para el spi
  */
   v_diferencia    NUMBER(10, 2) := 0;
   v_tot_seg_desde NUMBER(10, 2);
   v_tot_seg_hasta NUMBER(10, 2);
   v_hora_desde    NUMBER(10, 2);
   v_minuto_desde  NUMBER(10, 2);
   v_segundo_desde NUMBER(10, 2);
   v_hora_hasta    NUMBER(10, 2);
   v_minuto_hasta  NUMBER(10, 2);
   v_segundo_hasta NUMBER(10, 2);
   v_hor_desde     varchar2(20):='00:00:00';
   v_hor_hasta     varchar2(20);
BEGIN
     g_lugar:='Obtiene hora actual';
     select to_char(sysdate,'HH24:MI:SS') into v_hor_hasta from dual;
     g_lugar:='Realiza calculo para obtener diferencia';
      v_hora_desde    := to_number(substr(v_hor_desde, 1, 2)) * 3600;
      v_minuto_desde  := to_number(substr(v_hor_desde, 4, 2)) * 60;
      v_segundo_desde := to_number(substr(v_hor_desde, 7, 2));
      v_tot_seg_desde := v_hora_desde + v_minuto_desde + v_segundo_desde;
      v_hora_hasta    := to_number(substr(v_hor_hasta, 1, 2)) * 3600;
      v_minuto_hasta  := to_number(substr(v_hor_hasta, 4, 2)) * 60;
      v_segundo_hasta := to_number(substr(v_hor_hasta, 7, 2));
      v_tot_seg_hasta := v_hora_hasta + v_minuto_hasta + v_segundo_hasta;
      v_diferencia    := v_tot_seg_hasta - v_tot_seg_desde;

   RETURN v_diferencia;
EXCEPTION
   WHEN OTHERS THEN
    PAS_SPI.g_cod_error := 180;
    PAS_SPI.g_msj_error := 'Error en fu_obt_dif_seg' || ' - ' ||g_lugar || ' - ' || sqlerrm;
    pas_snp.pr_reg_operacion( 'Error al Obtener Genera la diferencia de segundo', g_lugar|| '|' ||PAS_SPI.g_msj_error );  
END fu_obt_dif_seg;
function fu_obt_tra_spi(p_cod_moneda ge_snp_transferencias.cod_moneda%type, p_monto ge_snp_transferencias.monto%type,p_ind_pat varchar2 default 'N',p_cod_swift ge_snp_transferencias.cod_swi_pte_beneficiario%type ) return varchar2 is
  /*
   || Obtiene si la transferencia que se está procesando puede ingresar por SPI
  */
   v_tra_spi   varchar2(1):='N' ;
   v_hab_pte_hab_spi  varchar2(1);

BEGIN
   pas_spi.g_cod_error := 0;
   pas_spi.g_msj_error := NULL;
   g_lugar:='Busca si el pte se encuentra certificado';
   select nvl(v.ind_hab_pte_spi, 'N')
   into v_hab_pte_hab_spi
   from gv_snp_participantes v, ba_personas p
   where v.cod_persona = p.cod_persona
   and v.cod_swift = p_cod_swift;
   g_lugar:='Busca parametros dinamicos y los condiciona';

   if pas_spi.fu_obt_est_hor_spi(fug_obt_pardinamico( 'COD_SPI_PCD' ),'001','002')='N' then
      v_tra_spi:='N';
   elsif p_ind_pat='S' and nvl(fug_obt_pardinamico('HAB_SPI_SUBPTES'),'N')='N' then --SPI Fase 2
      v_tra_spi:='N';
   elsif v_hab_pte_hab_spi='N' then --si el participante no se encuentra certificado por BCP, sigue por LBTR
      v_tra_spi:='N';
   elsif p_cod_moneda !=g_cod_mon_local then
      v_tra_spi:='N';

   elsif pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                  pag_gen.fu_obt_mon_local,
                                  p_monto
                                ) <= fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) 
         /*and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' */then
         v_tra_spi:='S';
   elsif   pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                  pag_gen.fu_obt_mon_local,
                                  p_monto
                                ) > fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) /*and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S'*/ then
      v_tra_spi:='N';
   end if;
   ---N no es SPI por naturaleza, S es SPI funciona todo OK, C( SPI contingencia LBTR/ACH), A generar sin contingencia
   if v_tra_spi ='S' AND nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' AND nvl(fug_obt_pardinamico( 'SPI_DISP_BCP' ),'N')='S'then
     v_tra_spi:='S';
   elsif v_tra_spi ='S' AND nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' AND nvl(fug_obt_pardinamico( 'SPI_DISP_BCP' ),'N')='S'then
      v_tra_spi:='C';--cancelar/reversar
    elsif v_tra_spi ='S' AND nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' AND nvl(fug_obt_pardinamico( 'SPI_DISP_BCP' ),'N')='N'then
      v_tra_spi:='R';--redireccionar
   end if; 
   RETURN v_tra_spi;
exception
when others then
      PAS_SPI.g_cod_error := 160;
      PAS_SPI.g_msj_error := 'Error en PAS_SPI.fu_obt_tra_spi' || ' - ' ||g_lugar || ' - ' || sqlerrm;
      return 'N';
end fu_obt_tra_spi;
FUNCTION fu_obt_cta_ban_participante( p_cod_swift  in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                      p_cod_moneda in ba_monedas.cod_moneda%type
                                    ) return varchar
IS
  /*
  || Obtiene la Cta. Física en BCP del participante según la moneda.
  */

  v_nro_cta_pte ge_snp_cta_bancos.nro_cta_bancaria%type;
BEGIN
  --Primero se buscará la Cta. Física en CC_CTA_BANCARIAS
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
    and fug_obt_paradicional(cb.nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ'
    and NVL(fug_obt_paradicional(cb.nro_cuenta, 'SNP_CTA_INTERB_SPI'),'N') = 'S';

  return v_nro_cta_pte;

EXCEPTION
  when no_data_found then
     --Si no se encuentra en CC_CTA_BANCARIAS,
     --se buscará ó en GE_SNP_CTA_BANCOS ó en GE_SNP_CTA_ENTES
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
            and nvl(cb.ind_spi,'N')='S'
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
            and nvl(ce.ind_spi,'N')='S';

        return v_nro_cta_pte;

     EXCEPTION
        when no_data_found then
          PAS_SPI.g_cod_error := 130;
          PAS_SPI.g_msj_error := 'Cuenta Bancaria inexistente para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
          pas_snp.pr_reg_operacion( 'Error al recuperar Cuenta Bancaria  ' || p_cod_swift||' y Moneda ' || p_cod_moneda , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
          return NULL;
        when too_many_rows Then
          PAS_SPI.g_cod_error := 131;
          PAS_SPI.g_msj_error := 'Existe más de una Cta. Bancaria para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
          pas_snp.pr_reg_operacion( 'Error al recuperar Cuenta Bancaria  ' || p_cod_swift||' y Moneda ' || p_cod_moneda , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
          return NULL;
        when others then
          PAS_SPI.g_cod_error := 132;
          PAS_SPI.g_msj_error := 'Error en PAS_SPI.FU_OBT_CTA_BAN_PARTICIPANTE' || ' - ' || sqlerrm;
          pas_snp.pr_reg_operacion( 'Error al recuperar Cuenta Bancaria  ' || p_cod_swift||' y Moneda ' || p_cod_moneda , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
          return NULL;
     END;
  when too_many_rows Then
     PAS_SPI.g_cod_error := 133;
     PAS_SPI.g_msj_error := 'Existe varias Ctas. Bancarias para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
     pas_snp.pr_reg_operacion( 'Error al recuperar Cuenta Bancaria  ' || p_cod_swift||' y Moneda ' || p_cod_moneda , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
     return NULL;
  when others Then
     PAS_SPI.g_cod_error := 134;
     PAS_SPI.g_msj_error := 'Error inesperado en PAS_SPI.FU_OBT_CTA_BAN_PARTICIPANTE' || ' - ' || sqlerrm;
     pas_snp.pr_reg_operacion( 'Error al recuperar Cuenta Bancaria  ' || p_cod_swift||' y Moneda ' || p_cod_moneda , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
     return NULL;
END fu_obt_cta_ban_participante;
FUNCTION fu_obt_cta_bancaria( p_nro_cuenta in cc_cta_bancarias.nro_cta_bancaria%type,
                              p_tip_cuenta in varchar2 ) return varchar2
IS
   /*
   || Obtiene la Cta. Bancaria.
   */

   v_nro_cta_bancaria cc_cta_bancarias.nro_cta_bancaria%type;
   v_nro_cuenta       cc_cta_bancarias.nro_cuenta%type;
BEGIN
   

   g_lugar :=  'Obteniendo Cta. Bancaria, ';
   if p_tip_cuenta = 'B' then
      select nro_cta_bancaria
        into v_nro_cta_bancaria
        from cc_cta_bancarias
       where nro_cuenta    = p_nro_cuenta
         and cod_modulo    = pas_snp.fu_obt_cod_mod_padre
         and cod_modalidad = pas_snp.fu_obt_cod_mad_padre
         and estado        IN ( 'A', 'N', 'S' ) /*Abierta, Normal, Bloqueo de Saldo*/
         and fug_obt_paradicional(nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ'
         and NVL(fug_obt_paradicional(nro_cuenta, 'SNP_CTA_INTERB_SPI'),'N') = 'S';
      return v_nro_cta_bancaria;
   elsif p_tip_cuenta = 'C' then
     select nro_cuenta
       into v_nro_cuenta
       from cc_cta_bancarias
      where nro_cta_bancaria = p_nro_cuenta
        and cod_modulo       = pas_snp.fu_obt_cod_mod_padre
        and cod_modalidad    = pas_snp.fu_obt_cod_mad_padre
        and estado           IN ( 'A', 'N', 'S' ) /*Abierta, Normal, Bloqueo de Saldo*/
        and fug_obt_paradicional(nro_cuenta, 'SNP_TIP_CTA_INTERBANCARIA') = 'LIQ'
        and NVL(fug_obt_paradicional(nro_cuenta, 'SNP_CTA_INTERB_SPI'),'N') = 'S';
     return v_nro_cuenta;
   end if;
  return NULL;
EXCEPTION
   when no_data_found then
       pas_spi.g_cod_error := '30';
       pas_spi.g_msj_error := 'Sin Cta. Bancaria asignada';
       pas_snp.pr_reg_operacion( 'Error al Obtener la Cta. Bancaria. ' || p_nro_cuenta , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
       return NULL;
    when too_many_rows then
       pas_spi.g_cod_error := '30';
       pas_spi.g_msj_error := 'Nro. Cta. Bancaria '||p_nro_cuenta||' existe para más de una cuenta.!';
       pas_snp.pr_reg_operacion( 'Error al Obtener la Cta. Bancaria. ' || p_nro_cuenta , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
       return NULL;
    when others then
       pas_spi.g_cod_error := '30';
       pas_spi.g_msj_error := 'Error al Obt.Cta.Bancaria '||' - '||sqlerrm;
       pas_snp.pr_reg_operacion( 'Error al Obtener la Cta. Bancaria. ' || p_nro_cuenta , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
       return NULL;
END fu_obt_cta_bancaria;

function fu_obt_cta_lbtr_reserva(p_nro_cuenta in cc_cta_bancarias.nro_cta_bancaria%type,
                                 p_tip_cuenta in varchar2) return varchar2 IS
  /*
  || Obtiene la Cta. Bancaria Reserva en LBTR
  */

  v_nro_cta_bancaria cc_cta_bancarias.nro_cta_bancaria%type;
  v_nro_cuenta       cc_cta_bancarias.nro_cuenta%type;
BEGIN
  g_lugar := 'Obteniendo Cta. Bancaria ReservaSPI, ';
 if p_tip_cuenta = 'B' then --busca la cuenta bancaria 
    SELECT c.nro_cta_bancaria
      INTO v_nro_cta_bancaria
      FROM cc_cta_bancarias c
     WHERE c.cod_modalidad = 455
       AND c.nro_cta_bancaria = p_nro_cuenta
       AND EXISTS (SELECT 1
              FROM SB_SNP_LIM_DEPO S
             WHERE S.VAL_PARAMETRO = C.NRO_CUENTA
               AND S.COD_MONEDA = C.COD_MONEDA);
    return v_nro_cta_bancaria;
 elsif p_tip_cuenta = 'C' then --busca el nro de la cuenta bancaria
     SELECT c.nro_cuenta
    INTO v_nro_cuenta
    FROM cc_cta_bancarias c
   WHERE c.cod_modalidad = 455
     AND c.nro_cta_bancaria = p_nro_cuenta
     AND EXISTS (SELECT 1
            FROM SB_SNP_LIM_DEPO S
           WHERE S.VAL_PARAMETRO = C.NRO_CUENTA
             AND S.COD_MONEDA = C.COD_MONEDA);
    return v_nro_cuenta;
  end if;
  return NULL;
EXCEPTION
  when no_data_found then
    pas_spi.g_cod_error := '31';
    pas_spi.g_msj_error := 'Sin Cta. Bancaria ReservaLBTR asignada';
    return NULL;
  when too_many_rows then
    pas_spi.g_cod_error := '30';
    pas_spi.g_msj_error := 'Nro. Cta. Bancaria ReservaLBTR' || p_nro_cuenta ||
                           ' existe para más de una cuenta.!';
    return NULL;
  when others then
    pas_spi.g_cod_error := '30';
    pas_spi.g_msj_error := 'Error al Obt.Cta.Bancaria ReservaLBTR ' ||
                           ' - ' || sqlerrm;
    return NULL;
END fu_obt_cta_lbtr_reserva;

FUNCTION fu_val_cta_lbtr_reserva ( p_cod_swift            in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                       p_cod_moneda           in ba_monedas.cod_moneda%type,
                                       p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type
                                     ) return varchar
IS
  /*Valida la cuenta bancaria reserva-LBTR del participante - */
  v_existe varchar2(1) := 'N';
BEGIN
 /*Inicializa las variables de error*/
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  --
  --Primero se buscará la Cta. Física en CC_CTA_BANCARIAS
  select distinct 'S'
   into v_existe
      from cc_cta_bancarias cb, ge_cta_clientes cc, gv_snp_participantes v
     where cb.nro_cuenta = cc.nro_cuenta
       and cb.cod_moneda = ltrim(rtrim(p_cod_moneda))
       and cc.relacion = 'P'
       and cb.estado IN ('A', 'N', 'S') /*Abierta, Normal, Bloqueo de Saldo*/
       and cb.cod_modulo = pas_snp.fu_obt_cod_mod_padre
       and cb.cod_modalidad = pas_snp.fu_obt_cod_mad_padre
       and cc.cod_persona = v.cod_persona
       and v.cod_swift = trim(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad))
       and cb.nro_cta_bancaria = p_nro_cta_participante
       and exists (select 1
              from sb_snp_lim_depo s
             where s.val_parametro = cb.nro_cuenta
               and s.cod_moneda = cb.cod_moneda);
       return v_existe;
EXCEPTION
   when no_data_found then
      PAS_SPI.g_cod_error := 100;
      PAS_SPI.g_msj_error := 'Cuenta Bancaria reserva-LBTR ' || p_nro_cta_participante || ' inexistente para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
      return 'N';
   when too_many_rows Then
      PAS_SPI.g_cod_error := 101;
      PAS_SPI.g_msj_error := 'Existe más de una Cta. Bancaria reserva-LBTR ' || p_nro_cta_participante || ' para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
      return 'N';
   when others then
      PAS_SPI.g_cod_error := 103;
      PAS_SPI.g_msj_error := 'Error en PAS_SPI.fu_val_cta_lbtr_reserva' || ' - ' || sqlerrm;
      return 'N';
END fu_val_cta_lbtr_reserva;

FUNCTION fu_val_cta_ban_participante ( p_cod_swift            in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                       p_cod_moneda           in ba_monedas.cod_moneda%type,
                                       p_nro_cta_participante in ge_snp_cta_bancos.nro_cta_bancaria%type
                                     ) return varchar
IS
  /*Valida la cuenta bancaria del participante*/
  v_existe varchar2(1) := 'N';
BEGIN

  --Primero se buscará la Cta. Física en CC_CTA_BANCARIAS
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
     and NVL(fug_obt_paradicional(cb.nro_cuenta, 'SNP_CTA_INTERB_SPI'),'N') = 'S'
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
     and nvl(cb.ind_spi,'N')='S'
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
     and nvl(ce.ind_spi,'N')='S'
  /*union all
     select distinct 'S'
       from ge_snp_patrocinador_cab s, ge_snp_patrocinador_det d
      where s.cod_swift = d.cod_swift_padre
        and d.estado = 'S'
        and ltrim(d.cta_interna_sub,0) = ltrim(p_nro_cta_participante,0)
        and s.cod_moneda = ltrim(rtrim(p_cod_moneda))
        and d.cod_swift_sub = trim(p_cod_swift)*/;

  return v_existe;

EXCEPTION
   when no_data_found then
      PAS_SPI.g_cod_error := 120;
      PAS_SPI.g_msj_error := 'Cuenta Bancaria ' || p_nro_cta_participante || ' inexistente para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
      return 'N';
   when too_many_rows Then
      PAS_SPI.g_cod_error := 121;
      PAS_SPI.g_msj_error := 'Existe más de una Cta. Bancaria ' || p_nro_cta_participante || ' para el Cod. Swift ' || p_cod_swift || ' y Moneda ' || p_cod_moneda;
      return 'N';
   when others then
      PAS_SPI.g_cod_error := 122;
      PAS_SPI.g_msj_error := 'Error en PAS_SPI.FU_VAL_CTA_BAN_PARTICIPANTE' || ' - ' || sqlerrm;
      return 'N';
END fu_val_cta_ban_participante;
  
function fu_obt_cab_spi(p_tip_msj_swift            in ge_snp_par_mensajes.tipo%type, p_nro_ref_externa  in ge_snp_transferencias.nro_ref_externa%type ) return typ_ObtdatCabecera is
  /*
  || Obtiene valores para cabecera de mensaje MX.
  */
  v_ver_cabecera   ge_spi_cab_versiones.version%type;
  v_ver_tipo_msj   ge_spi_cab_versiones.version%type;
  v_bic_spi        ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_BIC_RECEPTOR');
  v_ser_spi        ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_SERVICE');--**
  v_usu_con_spi    ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_USU_CONEXION');--**
  v_rec_spi        ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_RECEIVER');--**
  v_bic_entidad    ge_par_dinamicos.val_parametro%type:=pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
  v_ser_com        ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_SERV_COMERCIAL');
  cabecera typ_ObtdatCabecera := typ_ObtdatCabecera(null,null,null,null,null,null,null,null,null,null,null);

BEGIN
  g_lugar:='Recupera version para head.001';
   --Recupera datos para la cabecera
  select version into v_ver_cabecera from ge_spi_cab_versiones where tipo_msj='head.001';
  g_lugar:='Recupera version para'||p_tip_msj_swift;
  select version into v_ver_tipo_msj from ge_spi_cab_versiones where tipo_msj=p_tip_msj_swift;
  g_lugar:='Asigna datos de cabecera';
  cabecera := typ_ObtdatCabecera(v_ver_cabecera,v_bic_entidad,v_bic_spi,p_nro_ref_externa,v_ver_tipo_msj,v_ser_com,v_ser_spi,v_usu_con_spi,v_rec_spi, trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'));
  return cabecera;
exception
when others then
      pas_spi.g_cod_error := 190;
      pas_spi.g_msj_error := 'Error en PAS_SPI.fu_obt_cab_spi' || ' - ' ||g_lugar || ' - ' || sqlerrm;
      pas_snp.pr_reg_operacion( 'Error al generar cabecera para el tipo de mensaje ' || p_tip_msj_swift , g_lugar|| '|' ||PAS_SPI.g_msj_error );  
end fu_obt_cab_spi;

procedure pr_obt_dat_envio_automatico(p_tipo_mensaje in varchar2,
                                      p_monto out sb_snp_lim_depo.monto%type,
                                      p_cta_sol out cc_cta_bancarias.nro_cta_bancaria%type
                                      
                                      )is
 
 
  v_mto_bcp_disponible    sb_snp_lim_depo.monto%type;
  v_cod_moneda            sb_snp_lim_depo.cod_moneda%type := 'PYG';
  v_cta                   cc_cta_bancarias.nro_cta_bancaria%type;
begin
 --buscamos la cta del pte sol del ultimo deposito enviado
   select  s.nro_cta_pte_solicitante
     into  v_cta
     from ge_snp_transferencias s
    where s.cod_msj_swift = p_tipo_mensaje
      and s.fec_insercion in (select max(g.fec_insercion)
                                from ge_snp_transferencias g
                               where g.cod_msj_swift = s.cod_msj_swift
                                /* and g.situacion = 'L'
                                 and g.estado = 'A'*/) --preguntar como pasa a situacion L y estado A
      and exists
    (select 1
             from ge_snp_mensajes f
            where f.cod_msj_swift = 545
              and f.nro_ref_externa = to_char(s.nro_referencia));
              
  --consultamos el ultimo saldo generado para el fondeo de la cta liq          
    BEGIN
         select distinct substr(x.valor, 11, length(x.valor)) monto
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
            /*and x.nro_referencia in
                (select s.nro_referencia
                   from sb_snp_mensajes s
                  where s.cod_mensaje = 'MT941'
                    and s.campo = '21'
                    and trunc(x.fec_insercion) = trunc(s.fec_insercion)
                    and s.valor like '%F%');*/
       EXCEPTION
         when no_data_found then
           v_mto_bcp_disponible := 0;
       END;   
       
   p_monto := v_mto_bcp_disponible;
   p_cta_sol := v_cta;
exception  
 when no_data_found then
      PAS_SPI.g_cod_error := 123;
      PAS_SPI.g_msj_error := 'No se encontro el monto y participante solicitante del ultimo deposito realizado';
      v_mto_bcp_disponible :=0; 
   when too_many_rows Then
      PAS_SPI.g_cod_error := 124;
      PAS_SPI.g_msj_error := 'Existe mas de un monto y cuenta del participante solicitante para el ultimo deposito realizado';
      v_mto_bcp_disponible :=0; 
   when others then
      PAS_SPI.g_cod_error := 125;
      PAS_SPI.g_msj_error := 'Error en PAS_SPI.pr_obt_dat_envio_automatico' || ' - ' || sqlerrm;
      v_mto_bcp_disponible :=0; 
end pr_obt_dat_envio_automatico;


FUNCTION fu_ver_msj_duplicados ( p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type,
                                 p_fec_valor in ge_snp_transferencias.fec_valor%type
                                ) return varchar2
IS
   /*
   || Verifica si la transferencia RECIBIDA se encuentra duplicada
   */
   cursor cu_tra_dup IS
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

   -- Envía mail notificando que la transferencia se encuentra duplicada.
   PROCEDURE lp_env_not_duplicacion
   IS
   BEGIN
     if g_gru_dir_correo is not null then
        it_mail.mail( fug_obt_dir_correo,
                      g_gru_dir_correo,
                      'Error al intentar recibir mensaje SPI desde el BCP.',
                      'Se ha encontrado una mensajería RECIBIDA DUPLICADA con Fecha ' || to_char(p_fec_valor,'DD/MM/YYYY') ||
                      ' y Nro.Ref.Externa ' || p_nro_ref_externa || chr(10) || chr(10) || chr(10) ||
                      'Atentamente.'
                     );
     end if;
   EXCEPTION
     when others then
        NULL;
   END lp_env_not_duplicacion;
BEGIN

   --PAS_SPI.pr_ini_variables;
   --

   for d in cu_tra_dup loop
      PAS_SPI.g_cod_error := 170;
      PAS_SPI.g_msj_error := 'Mensaje mx ya existente para la Ref. Externa ' || p_nro_ref_externa || ' y Fec.Valor ' || to_char(p_fec_valor,'DD/MM/YYYY');
      lp_env_not_duplicacion;
      return 'S';
   end loop;

   return 'N';
EXCEPTION
   WHEN no_data_found THEN
      return 'N';
   WHEN too_many_rows THEN
      PAS_SPI.g_cod_error := 170;
      PAS_SPI.g_msj_error := 'Mensajería Duplicada para la Ref.Externa ' || p_nro_ref_externa || ' y Fec.Valor ' || to_char(p_fec_valor,'DD/MM/YYYY');
      lp_env_not_duplicacion;
      return 'S';
   WHEN others THEN
      PAS_SPI.g_cod_error := 170;
      PAS_SPI.g_msj_error := substr('Error inesperado en PAS_SPI.fu_ver_msj_duplicados para la Ref.Externa '||p_nro_ref_externa||' y Fec.Valor '|| to_char(p_fec_valor,'DD/MM/YYYY')||', '||sqlerrm, 1, 200);
      return 'S';
END fu_ver_msj_duplicados;
/*Retorna las fechas del calendario del módulo*/
PROCEDURE lp_ver_horario(p_cod_modulo in ba_modulos.cod_modulo%type)IS
   v_est_modulo ba_modulos.estado%TYPE;
   v_cod_entidad ge_par_generales.cod_entidad%TYPE;

   BEGIN
      g_horario    := 'D'; -- Dia normal
      g_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      g_es_cta_noc := 'N';
      g_fec_actual_h := pag_cal.fu_obt_fec_actual(p_cod_modulo);

      v_cod_entidad := pag_gen.fu_obt_cod_entidad();

      if v_cod_entidad = 9999 then --si se trata de casas de crédito
         v_est_modulo := pae_cnf.fu_obt_est_modulo(p_cod_modulo);
      else
         --se busca el estado del módulo 3 debido a ser el primer módulo cuyo estado es modificado
         --en el proceso de cierre
         v_est_modulo := pae_cnf.fu_obt_est_modulo(p_cod_modulo);
      end if;

      IF v_est_modulo = 6 THEN
         -- En cierre.
         g_horario    := 'N'; -- Noche
         g_fec_actual_h := pag_cal.fu_obt_fec_proxima(p_cod_modulo);
         
         g_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         g_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto
         -- Verifica la hora --
         NULL;
      ELSE
         g_horario    := 'N'; -- Noche
         IF v_est_modulo = 1 THEN--En proceso de inicio
          g_fec_actual_h := pag_cal.fu_obt_fec_actual(p_cod_modulo);  
         ELSE  
         g_fec_actual_h := pag_cal.fu_obt_fec_proxima(p_cod_modulo);
         END IF;
         g_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         g_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
      g_fec_valor       := trunc(sysdate);
      pag_cta.g_horario := g_horario;
      g_mod_estado := v_est_modulo;
      
 END lp_ver_horario;
PROCEDURE pr_val_cod_swi_participante( p_cod_swi_participante in out ge_snp_transferencias.cod_swi_pte_solicitante%type )
IS
BEGIN
  -- Recupera el código swift configurado en ITGF a partir del código SWIFT recibido como parámetro.
  select v.cod_swift
    into p_cod_swi_participante
    from gv_snp_participantes v
   where rpad( v.cod_swift, 11, 'X' ) = rpad( p_cod_swi_participante, 11, 'X' );
EXCEPTION
   --busca en la tabla del patrocinador--
   when no_data_found then
       begin
          select d.cod_swift_sub
          into p_cod_swi_participante
          from ge_snp_patrocinador_cab s , ge_snp_patrocinador_det d
          where s.cod_swift = d.cod_swift_padre
          and d.estado = 'S'
          and d.cod_swift_sub = p_cod_swi_participante;
        exception
           when no_data_found then
    pas_spi.g_cod_error := 190;
    pas_spi.g_msj_error := 'BIC ' || p_cod_swi_participante || ' del Participante no coincide con el registrado en ITGF.!';
     pas_snp.pr_reg_operacion( 'Error al Recuperar el código swift configurado en ITGF a partir del código SWIFT recibido :'||p_cod_swi_participante, g_lugar|| '|' ||PAS_SPI.g_msj_error );  
         end;  
  when others then
    pas_spi.g_cod_error := 190;
    pas_spi.g_msj_error := 'Error en PAS_SPI.PR_VAL_COD_SWI_PARTICIPANTE: ' || sqlerrm;
    pas_snp.pr_reg_operacion( 'Error al Recuperar el código swift configurado en ITGF a partir del código SWIFT recibido :'||p_cod_swi_participante, g_lugar|| '|' ||PAS_SPI.g_msj_error );  

END pr_val_cod_swi_participante;
procedure pr_obt_inf_pen_011(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa transferencias pendientes de envio al SPI, de tipo camt.011
  || Solicitud para establecer el límite de cuenta
  */
  v_nro_referencia  ge_spi_informes.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_spi_informes.nro_ref_externa%type:= NULL;
  v_tip_msj         ge_spi_informes.cod_msj_mx%type;
  v_cant number(8):=0;
  transferencia typ_ObtInfPendiente := typ_ObtInfPendiente(null,null,null,null,null,null,null,null,null,null,0);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
  
  cursor cu_msj_inf IS
    SELECT a.nro_referencia,
           a.nro_ref_externa,
           a.cod_msj_mx,
           a.fecha,
           a.hora,
           a.tipo_limite,
           a.tipo_informe,
           a.nro_cta_solicitante,
           a.cod_swi_solicitante,
           a.cod_moneda,
           a.monto
      from ge_spi_informes a
     where a.estado = 'U'
        and a.situacion not in ('B', 'N') --No sean bloqueado, Evitar reenvio SPI
       and a.cod_msj_mx = g_cam_011
       and rownum=1
     order by a.nro_referencia asc
     --fetch first 1 rows only;
     for update skip locked;
    

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe camt.011';
  FOR a IN cu_msj_inf LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:= a.nro_ref_externa;
    v_tip_msj:=a.cod_msj_mx;
    transferencia := typ_ObtInfPendiente(a.nro_referencia,a.nro_ref_externa,a.cod_msj_mx,a.fecha,a.hora,
    a.tipo_limite,a.tipo_informe,a.nro_cta_solicitante,a.cod_swi_solicitante,a.cod_moneda,a.monto);
      ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: camt.011'||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Codigo mx: '||a.cod_msj_mx|| chr(10) || 
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Tipo Limite: '||a.tipo_limite|| chr(10) || 
         ' Tipo Informe: '||a.tipo_informe|| chr(10) || 
         ' Nro cta solicitante: '||a.nro_cta_solicitante|| chr(10) || 
         ' Cod swift solicitante: '||a.cod_swi_solicitante|| chr(10) || 
         ' Codigo Moneda: '||a.cod_moneda|| chr(10) || 
         ' Monto: '||a.monto
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   
  END LOOP;
  g_lugar:='Asigna datos para la cabecera de informe camt.011';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi('camt.011',v_nro_ref_externa);
  g_lugar:='Actualizacion de informe camt.011 a bloqueado';
  UPDATE ge_spi_informes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
  if sql%rowcount > 0 then
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.011';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, v_tip_msj,trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de Camt.011 ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Camt.011 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;


EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 20;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     UPDATE ge_spi_informes
          SET situacion = 'N'
          WHERE nro_referencia = v_nro_referencia;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_011-';
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de' || g_cam_011 , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje         := mensaje;
END pr_obt_inf_pen_011;
procedure pr_obt_inf_pen_060(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa informes pendientes de envio al SPI, de tipo camt.060
  || Solicitud de informe de cuenta
  */
  v_nro_referencia  ge_spi_informes.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_spi_informes.nro_ref_externa%type:= NULL;
  v_tip_msj         ge_spi_informes.cod_msj_mx%type;
  v_cant number(8):=0;
  transferencia typ_ObtInfPendiente := typ_ObtInfPendiente(null,null,null,null,null,null,null,null,null,null,0);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
  cursor cu_msj_inf IS
    SELECT a.nro_referencia,
           a.nro_ref_externa,
           a.cod_msj_mx,
           a.fecha,
           a.hora,
           a.tipo_limite,
           a.tipo_informe,
           a.nro_cta_solicitante,
           a.cod_swi_solicitante,
           a.cod_moneda,
           a.monto
      from ge_spi_informes a
     where a.estado = 'U'
        and a.situacion not in ('B', 'N') --No sean bloqueado, Evitar reenvio SPI
       and a.cod_msj_mx = g_cam_060
       and rownum=1
     order by a.nro_referencia asc
     --fetch first 1 rows only;
     for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe camt.060';
  FOR a IN cu_msj_inf LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:=a.nro_ref_externa;
    v_tip_msj:=a.cod_msj_mx;
    transferencia := typ_ObtInfPendiente(a.nro_referencia,a.nro_ref_externa,a.cod_msj_mx,a.fecha,a.hora,
    a.tipo_limite,a.tipo_informe,a.nro_cta_solicitante,a.cod_swi_solicitante,a.cod_moneda,a.monto);
     ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: '||g_cam_060||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Codigo mx: '||a.cod_msj_mx|| chr(10) || 
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Tipo Limite: '||a.tipo_limite|| chr(10) || 
         ' Tipo Informe: '||a.tipo_informe|| chr(10) || 
         ' Nro cta solicitante: '||a.nro_cta_solicitante|| chr(10) || 
         ' Cod swift solicitante: '||a.cod_swi_solicitante|| chr(10) || 
         ' Codigo Moneda: '||a.cod_moneda|| chr(10) || 
         ' Monto: '||a.monto
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   
  END LOOP;
  g_lugar:='Asigna datos para la cabecera de informe camt.060';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi('camt.060',v_nro_ref_externa);
  g_lugar:='Actualizacion de informe  camt.060 a bloqueado';
  UPDATE ge_spi_informes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
  if sql%rowcount > 0 then
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.060';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, v_tip_msj,trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de camt.060 ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Camt.060 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;
  
EXCEPTION
    WHEN others THEN
        PAS_SPI.g_cod_error := 40;
        PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
         UPDATE ge_spi_informes
              SET situacion = 'N'
              WHERE nro_referencia = v_nro_referencia;
        mensaje.cod_respuesta := 1;
        mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_060-'||g_lugar;
        mensaje.des_Respuesta:=sqlerrm;
        pas_snp.pr_reg_operacion( 'Error en envio de' || g_cam_060 , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
        p_dat_mensaje         := mensaje;
END pr_obt_inf_pen_060;
procedure pr_obt_inf_pen_018(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa informes pendientes de envio al SPI, de tipo camt.018
  || Solicitud de información del día hábil
  */
  v_nro_referencia  ge_spi_informes.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_spi_informes.nro_ref_externa%type:= NULL;
  v_tip_msj         ge_spi_informes.cod_msj_mx%type;
  v_cant number(8):=0;
  transferencia typ_ObtInfPendiente := typ_ObtInfPendiente(null,null,null,null,null,null,null,null,null,null,0);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_inf IS
    SELECT a.nro_referencia,
           a.nro_ref_externa,
           a.cod_msj_mx,
           a.fecha,
           a.hora,
           a.tipo_limite,
           a.tipo_informe,
           a.nro_cta_solicitante,
           a.cod_swi_solicitante,
           a.cod_moneda,
           a.monto
      from ge_spi_informes a
     where a.estado = 'U'
        and a.situacion not in ('B', 'N') --No sean bloqueado, Evitar reenvio SPI
       and a.cod_msj_mx = g_cam_018
       and rownum=1
     order by a.nro_referencia asc
     for update skip locked;
     --fetch first 1 rows only;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe '||g_cam_018;
  FOR a IN cu_msj_inf LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:=a.nro_ref_externa;
    v_tip_msj:=a.cod_msj_mx;
    transferencia := typ_ObtInfPendiente(a.nro_referencia,a.nro_ref_externa,a.cod_msj_mx,a.fecha,a.hora,
    a.tipo_limite,a.tipo_informe,a.nro_cta_solicitante,a.cod_swi_solicitante,a.cod_moneda,a.monto);
     ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: ' ||g_cam_018||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Codigo mx: '||a.cod_msj_mx|| chr(10) || 
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Tipo Limite: '||a.tipo_limite|| chr(10) || 
         ' Tipo Informe: '||a.tipo_informe|| chr(10) || 
         ' Nro cta solicitante: '||a.nro_cta_solicitante|| chr(10) || 
         ' Cod swift solicitante: '||a.cod_swi_solicitante|| chr(10) || 
         ' Codigo Moneda: '||a.cod_moneda|| chr(10) || 
         ' Monto: '||a.monto
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   
  END LOOP;
  g_lugar:='Asigna datos para la cabecera de informe'|| g_cam_018;
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi('camt.018',v_nro_ref_externa);
  g_lugar:='Actualizacion de informe ' || g_cam_018||' a bloqueado';
  UPDATE ge_spi_informes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
  if sql%rowcount > 0 then
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.018';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, v_tip_msj,trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de Camt.018 ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Camt.018 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;
    
EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 140;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     UPDATE ge_spi_informes
          SET situacion = 'N'
          WHERE nro_referencia = v_nro_referencia;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_018-';
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de' || g_cam_018 , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje         := mensaje;
END pr_obt_inf_pen_018;
procedure pr_obt_inf_pen_009(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPendiente,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa informes pendientes de envio al SPI, de tipo camt.009
  || Obtener valor límite.
  */
  v_nro_referencia  ge_spi_informes.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_spi_informes.nro_ref_externa%type:= NULL;
  v_tip_msj         ge_spi_informes.cod_msj_mx%type;
  v_cant number(8):=0;
  transferencia typ_ObtInfPendiente := typ_ObtInfPendiente(null,null,null,null,null,null,null,null,null,null,0);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_inf IS
    SELECT a.nro_referencia,
           a.nro_ref_externa,
           a.cod_msj_mx,
           a.fecha,
           a.hora,
           a.tipo_limite,
           a.tipo_informe,
           a.nro_cta_solicitante,
           a.cod_swi_solicitante,
           a.cod_moneda,
           a.monto
      from ge_spi_informes a
     where a.estado = 'U'
       and a.situacion not in ('B', 'N') --No sean bloqueado, Evitar reenvio SPI
       and a.cod_msj_mx=g_cam_009
       and rownum=1
     order by a.nro_referencia asc
   for update skip locked;
  

BEGIN

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe camt.009';
  FOR a IN cu_msj_inf LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:=a.nro_ref_externa;
    v_tip_msj:=a.cod_msj_mx;
    transferencia := typ_ObtInfPendiente(a.nro_referencia,a.nro_ref_externa,a.cod_msj_mx,a.fecha,a.hora,
    a.tipo_limite,a.tipo_informe,a.nro_cta_solicitante,a.cod_swi_solicitante,a.cod_moneda,a.monto);
     ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: camt.009'||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Codigo mx: '||a.cod_msj_mx|| chr(10) || 
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Tipo Limite: '||a.tipo_limite|| chr(10) || 
         ' Tipo Informe: '||a.tipo_informe|| chr(10) || 
         ' Nro cta solicitante: '||a.nro_cta_solicitante|| chr(10) || 
         ' Cod swift solicitante: '||a.cod_swi_solicitante|| chr(10) || 
         ' Codigo Moneda: '||a.cod_moneda|| chr(10) || 
         ' Monto: '||a.monto
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   
  END LOOP;
  g_lugar:='Asigna datos para la cabecera de informe camt.009';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi('camt.009',v_nro_ref_externa);
  g_lugar:='Actualizacion de informe camt.009 a bloqueado';
  UPDATE ge_spi_informes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
  if sql%rowcount > 0 then
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.009';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, v_tip_msj,trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de camt.009 ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Camt.009 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;
   

EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 10;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
    UPDATE ge_spi_informes
          SET situacion = 'N'
          WHERE nro_referencia = v_nro_referencia;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_009-';
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de' || g_cam_009 , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje         := mensaje;
END pr_obt_inf_pen_009;
procedure pr_obt_inf_pen_028(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPago,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa informes pendientes de envio al SPI, de tipo pacs.028
  || Solicitud para obtener el estado del pago.
  */
  v_nro_referencia  ge_spi_informes.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_spi_informes.nro_ref_externa%type:= NULL;
  v_tip_msj         ge_spi_informes.cod_msj_mx%type;
  v_cant number(8):=0;
  transferencia typ_ObtInfPago := typ_ObtInfPago(null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_inf IS
    SELECT a.nro_referencia,
           a.nro_ref_externa,
           a.cod_msj_mx,
           a.fecha,
           a.hora,
           a.cod_swi_solicitante,
           (select tipo
              from gv_snp_participantes
             where cod_swift = a.cod_swi_solicitante) tip_par_solicitante,
           a.par_rec_consulta,
           a.inf_suplementaria,
           a.nro_ref_msj_original,
           a.tip_msj_original,
           a.fec_ins_msj_original,
           a.hor_ins_msj_original,
           a.cod_swi_sol_original,
           (select tipo
              from gv_snp_participantes
             where cod_swift = a.cod_swi_sol_original) tip_par_original,
           a.fec_valor_msj_original
      from ge_spi_informes a
     where a.estado = 'U'
       and a.situacion not in ('B', 'N') --No sean bloqueado, Evitar reenvio SPI
       and a.cod_msj_mx = g_pac_028
       and rownum=1
     order by a.nro_referencia asc
     --fetch first 1 rows only;
     for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe pacs.028';
  FOR a IN cu_msj_inf LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:=a.nro_ref_externa;
    v_tip_msj:=a.cod_msj_mx;
    transferencia := typ_ObtInfPago(a.nro_referencia,a.nro_ref_externa,a.cod_msj_mx,a.fecha,a.hora,a.cod_swi_solicitante,
    a.tip_par_solicitante,a.par_rec_consulta,a.inf_suplementaria,a.nro_ref_msj_original,a.tip_msj_original,a.fec_ins_msj_original,
    a.hor_ins_msj_original,a.cod_swi_sol_original,a.tip_par_original,a.fec_valor_msj_original,null,null);
    ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: ' ||g_pac_028||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Codigo mx: '||a.cod_msj_mx|| chr(10) || 
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Codigo swift solicitante: '||a.cod_swi_solicitante|| chr(10) || 
         ' Tipo participante solicitante: '||a.tip_par_solicitante|| chr(10) || 
         ' Paramtro consulta : '||a.par_rec_consulta|| chr(10) || 
         ' Informacion suplementaria: '||a.inf_suplementaria|| chr(10) || 
         ' Nro referencia mensaje original: '||a.nro_ref_msj_original|| chr(10) || 
         ' Tipo mensaje original: '||a.tip_msj_original|| chr(10) || 
         ' Fecha mensaje original: '||a.fec_ins_msj_original|| chr(10) || 
         ' Hora mensaje original: '||a.hor_ins_msj_original|| chr(10) || 
         ' Codigo swift mensaje original: '||a.cod_swi_sol_original|| chr(10) || 
         ' Tipo participante original: '||a.tip_par_original|| chr(10) || 
         ' Fecha valor mensaje original: '||a.fec_valor_msj_original
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   
  END LOOP;
  g_lugar:='Asigna datos para la cabecera de informe pacs.028';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi('pacs.028',v_nro_ref_externa);
  g_lugar:='Actualizacion de informe  pacs.028 a bloqueado';
  UPDATE ge_spi_informes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
  if sql%rowcount > 0 then
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
      exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos pacs.028';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, v_tip_msj,trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de Pacs.028 ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Pacs.028 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;

EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 30;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
    UPDATE ge_spi_informes
     SET situacion = 'N'
   WHERE nro_referencia = v_nro_referencia;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_inf_pen_028-'|| g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de' || g_pac_028 , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje         := mensaje;
END pr_obt_inf_pen_028;
procedure pr_obt_inf_pen_033(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPago,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa informes pendientes de envio al SPI, de tipo camt.033
  || Solicitud de copia del pago.
  */
  v_nro_referencia  ge_spi_informes.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_spi_informes.nro_ref_externa%type:= NULL;
  v_tip_msj         ge_spi_informes.cod_msj_mx%type;
  v_cant number(8):=0;
  transferencia typ_ObtInfPago := typ_ObtInfPago(null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_inf IS
    SELECT a.nro_referencia,
           a.nro_ref_externa,
           a.cod_msj_mx,
           a.fecha,
           a.hora,
           a.cod_swi_solicitante,
           (select tipo
              from gv_snp_participantes
             where cod_swift = a.cod_swi_solicitante) tip_par_solicitante,
           a.par_rec_consulta,
           a.inf_suplementaria,
           a.nro_ref_msj_original,
           a.tip_msj_original,
           a.fec_ins_msj_original,
           a.hor_ins_msj_original,
           a.cod_swi_sol_original,
           (select tipo
              from gv_snp_participantes
             where cod_swift = a.cod_swi_sol_original) tip_par_original,
           a.fec_valor_msj_original
      from ge_spi_informes a
     where a.estado = 'U'
       and a.situacion not in ('B', 'N') --No sean bloqueado, Evitar reenvio SPI
       and a.cod_msj_mx = g_cam_033
       and rownum=1
     order by a.nro_referencia asc
     --fetch first 1 rows only;
     for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe camt.033';
  FOR a IN cu_msj_inf LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:=a.nro_ref_externa;
    v_tip_msj:=a.cod_msj_mx;
    transferencia := typ_ObtInfPago(a.nro_referencia,a.nro_ref_externa,a.cod_msj_mx,a.fecha,a.hora,a.cod_swi_solicitante,
    a.tip_par_solicitante,a.par_rec_consulta,a.inf_suplementaria,a.nro_ref_msj_original,a.tip_msj_original,a.fec_ins_msj_original,
    a.hor_ins_msj_original,a.cod_swi_sol_original,a.tip_par_original,a.fec_valor_msj_original,null,null);
        ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: ' ||g_cam_033||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Codigo mx: '||a.cod_msj_mx|| chr(10) || 
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Codigo swift solicitante: '||a.cod_swi_solicitante|| chr(10) || 
         ' Tipo participante solicitante: '||a.tip_par_solicitante|| chr(10) || 
         ' Parametro consulta : '||a.par_rec_consulta|| chr(10) || 
         ' Informacion suplementaria: '||a.inf_suplementaria|| chr(10) || 
         ' Nro referencia mensaje original: '||a.nro_ref_msj_original|| chr(10) || 
         ' Tipo mensaje original: '||a.tip_msj_original|| chr(10) || 
         ' Fecha mensaje original: '||a.fec_ins_msj_original|| chr(10) || 
         ' Hora mensaje original: '||a.hor_ins_msj_original|| chr(10) || 
         ' Codigo swift mensaje original: '||a.cod_swi_sol_original|| chr(10) || 
         ' Tipo participante original: '||a.tip_par_original|| chr(10) || 
         ' Fecha valor mensaje original: '||a.fec_valor_msj_original
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   
  END LOOP;
  g_lugar:='Asigna datos para la cabecera de informe camt.033';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi('camt.033',v_nro_ref_externa);
  g_lugar:='Actualizacion de informe  camt.033 a bloqueado';
  UPDATE ge_spi_informes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
  if sql%rowcount > 0 then
     begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.033';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, v_tip_msj,trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de Camt.033 ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Camt.033 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;


EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 30;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     UPDATE ge_spi_informes
          SET situacion = 'N'
          WHERE nro_referencia = v_nro_referencia;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_inf_pen_033-'||g_lugar;
    mensaje.des_Respuesta :=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de' || g_cam_033 , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje         := mensaje;
END pr_obt_inf_pen_033;
procedure pr_obt_inf_res_002(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtInfPago,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa informes de respuesta al SPI, de tipo pacs.002
  || Respuesta pacs.002 a pacs.008 recibido.
  */
  v_nro_referencia  ge_spi_informes.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_spi_informes.nro_ref_externa%type:= NULL;
  v_tip_msj         ge_spi_informes.cod_msj_mx%type;
  v_cant number(8):=0;
  transferencia typ_ObtInfPago := typ_ObtInfPago(null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
  v_tip_rechazo ge_snp_transferencias.tip_rechazo%type;
  v_des_mot_naut ba_cod_referencias.abreviatura%type;
  
  cursor cu_msj_inf IS
    SELECT a.nro_referencia,
           a.nro_ref_externa,
           a.cod_msj_mx,
           a.fecha,
           a.hora,
           a.cod_swi_solicitante,
             (select tipo
              from gv_snp_participantes
             where cod_swift = a.cod_swi_solicitante) tip_par_solicitante,
           a.par_rec_consulta,
           a.inf_suplementaria,
           a.nro_ref_msj_original,
           a.tip_msj_original,
           a.fec_ins_msj_original,
           a.hor_ins_msj_original,
           a.cod_swi_sol_original,
            (select tipo
              from gv_snp_participantes
             where cod_swift = a.cod_swi_sol_original) tip_par_original,
           a.fec_valor_msj_original

      from ge_spi_informes a
     where a.estado = 'U'
       and a.situacion not in ('B', 'N') --No sean bloqueado, Evitar reenvio SPI
       and a.cod_msj_mx = g_pac_002
     --  and rownum=1
     order by a.nro_referencia asc
     for update skip locked;
     --fetch first 1 rows only;
   r_reg cu_msj_inf%ROWTYPE;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe pacs.002';
  open cu_msj_inf;
  fetch cu_msj_inf into r_reg;
  if cu_msj_inf%found then
  --FOR a IN cu_msj_inf LOOP
     v_nro_referencia:=r_reg.nro_referencia;
     v_nro_ref_externa:=r_reg.nro_ref_externa;
     v_tip_msj:=r_reg.cod_msj_mx;
   --Si la informacion suplementaria es rechazo, entonces recupera el motivo rechazo de la transferencia
   if r_reg.inf_suplementaria='NAUT' then
    begin
    select t.tip_rechazo
        into v_tip_rechazo
        from ge_snp_transferencias t
       where t.nro_ref_externa = r_reg.nro_ref_msj_original;
     exception
       when others then
          UPDATE ge_spi_informes
          SET situacion = 'N'
          WHERE nro_referencia = r_reg.nro_referencia;
         mensaje.cod_respuesta := 1;
         mensaje.nom_respuesta := 'Error en pr_obt_inf_res_002-'||g_lugar;
         mensaje.des_Respuesta:=sqlerrm;
         p_dat_mensaje         := mensaje;
     end;
     --Recupera descripcion de motivo rechazo en base al tipo de rechazo
    begin
      select abreviatura
        into v_des_mot_naut
        from ba_cod_referencias
       where dominio = 'TIP_REC_SPI'
         and val_minimo = v_tip_rechazo;
    exception
      when no_data_found then
        v_des_mot_naut:= null;
      when others then
         v_des_mot_naut:= null;
    end;
    
    end if;
    transferencia := typ_ObtInfPago(r_reg.nro_referencia,r_reg.nro_ref_externa,r_reg.cod_msj_mx,r_reg.fecha,r_reg.hora,r_reg.cod_swi_solicitante,
    r_reg.tip_par_solicitante,r_reg.par_rec_consulta,r_reg.inf_suplementaria,r_reg.nro_ref_msj_original,r_reg.tip_msj_original,r_reg.fec_ins_msj_original,
    r_reg.hor_ins_msj_original,r_reg.cod_swi_sol_original,r_reg.tip_par_original,r_reg.fec_valor_msj_original,v_tip_rechazo,v_des_mot_naut);
     ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||r_reg.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: '||g_pac_002||chr(10) ||
         ' Parametros: Nro_referencia: '||r_reg.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||r_reg.nro_ref_externa|| chr(10) || 
         ' Codigo mx: '||r_reg.cod_msj_mx|| chr(10) || 
         ' Fecha: '||r_reg.fecha|| chr(10) || 
         ' Parametro consulta : '||r_reg.par_rec_consulta|| chr(10) || 
         ' Informacion suplementaria: '||r_reg.inf_suplementaria|| chr(10) || 
         ' Nro referencia mensaje original: '||r_reg.nro_ref_msj_original|| chr(10) || 
         ' Tipo mensaje original: '||r_reg.tip_msj_original|| chr(10) || 
         ' Fecha mensaje original: '||r_reg.fec_ins_msj_original|| chr(10) || 
         ' Hora mensaje original: '||r_reg.hor_ins_msj_original|| chr(10) || 
         ' Codigo swift mensaje original: '||r_reg.cod_swi_sol_original|| chr(10) || 
         ' Tipo participante original: '||r_reg.tip_par_original|| chr(10) || 
         ' Fecha valor mensaje original: '||r_reg.fec_valor_msj_original|| chr(10) || 
         ' Codigo rechazo: '||v_tip_rechazo|| chr(10) || 
         ' Motivo rechazo: '||v_des_mot_naut
         , g_lugar||' Nro_referencia: '||r_reg.nro_referencia);   
 -- END LOOP;
  end if;
  close cu_msj_inf;
 if v_nro_referencia is not null then
  g_lugar:='Asigna datos para la cabecera de informe pacs.002';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi('pacs.002',v_nro_ref_externa);
  g_lugar:='Actualizacion de informe ' || g_pac_002||' a bloqueado';
  UPDATE ge_spi_informes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
     begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.009';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, v_tip_msj,trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    --registrando log
    pas_snp.pr_reg_operacion(g_pac_002|| ' Procesado OK,Ref. externa: '||v_nro_ref_externa , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    g_lugar:='Proceso de pacs.002 ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Pacs.002 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;
 
EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 210;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     UPDATE ge_spi_informes
          SET situacion = 'N'
          WHERE nro_referencia = v_nro_referencia;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_inf_res_002-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de' || g_pac_002 , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje         := mensaje;
END pr_obt_inf_res_002;
PROCEDURE pr_act_inf_spi (p_nro_ref_externa in   ge_spi_informes.nro_ref_externa%type,
                            p_estado         in  ge_spi_informes.estado%type,
                            p_situacion      in  ge_spi_informes.situacion%type,
                            p_msj_mx         in  ge_spi_informes.msj_mx%type,
                            p_error          in  ge_spi_informes.error%type,
                            p_dat_mensaje    out typ_mensajeria_spi)
  /*
  || Actualiza el estado y el mensaje mx de una solicitud de informe
  */
IS

   ex_error EXCEPTION;
   mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,'OK',null);
    v_det_log         varchar2(4000) := NULL;
   PROCEDURE lp_reg_log_transferencia( p_respuesta in varchar2 )
     IS
     BEGIN
        --
        pas_snp.pr_set_texto(v_det_log, p_respuesta, pas_snp.fu_obt_salto );

        pas_snp.pr_set_texto(v_det_log, 'Nro. Ref. Externa:  '|| '~' || p_nro_ref_externa || '~', pas_snp.fu_obt_salto);
        pas_snp.pr_set_texto(v_det_log, 'Situación:          '|| p_situacion, pas_snp.fu_obt_salto);
        pas_snp.pr_set_texto(v_det_log, 'Estado:             '|| p_estado, pas_snp.fu_obt_salto);
        pas_snp.pr_set_texto(v_det_log, 'Error:             '||  p_error, pas_snp.fu_obt_salto);
        pas_snp.pr_reg_operacion( p_msj_mx, v_det_log );
        --
     EXCEPTION
       WHEN others THEN
         NULL;
     END lp_reg_log_transferencia;
BEGIN
   begin
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
   end;
  pas_spi.g_cod_error := 0;
  pas_spi.g_msj_error := NULL;
  g_lugar:='Actualiza datos de informes';
  begin
    update ge_spi_informes
       set estado = p_estado, msj_mx = p_msj_mx,situacion=p_situacion, error=substr(p_error,1,4000)
     where nro_ref_externa = p_nro_ref_externa;
    if sql%notfound then
      pas_snp.pr_reg_operacion( 'Error en actualizacion de informe, Ref. externa: '||p_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
      raise ex_error;
    end if;
    if sql%found then
       lp_reg_log_transferencia( '0' || '|LOG DEL MT ' || trim(p_nro_ref_externa) );
       p_dat_mensaje        := mensaje;
    end if;
  exception
    when ex_error then
    pas_spi.g_cod_error := 90;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'No existe registro de informe con nro_ref_externa ' ||
                         p_nro_ref_externa;
    mensaje.des_Respuesta := sqlerrm;
    pas_snp.pr_reg_operacion( 'Error actualizacion informe con nro_ref_externa ' || p_nro_ref_externa , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje         := mensaje;
      rollback;
  end;

EXCEPTION
   when others then
     PAS_SPI.g_cod_error := 91;
     PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     mensaje.cod_respuesta := 1;
     mensaje.nom_respuesta:= 'Ocurrio error al actualizar datos de informes, nro_ref_externa' ||
                         p_nro_ref_externa;
     mensaje.des_Respuesta := sqlerrm;
     lp_reg_log_transferencia( pas_spi.g_cod_error || '|' || mensaje.nom_respuesta || '|LOG DEL MT ' || trim(p_nro_ref_externa) );
     p_dat_mensaje         := mensaje;

END pr_act_inf_spi;
PROCEDURE pr_act_tra_spi (p_nro_ref_externa in   ge_snp_transferencias.nro_ref_externa%type,
                            p_estado         in  ge_snp_transferencias.estado%type,
                            p_situacion      in  ge_snp_transferencias.situacion%type,
                            p_msj_mx         in  ge_snp_transferencias.msj_swift%type,
                            p_error          in  ge_snp_transferencias.error%type,
                            p_dat_mensaje    out typ_mensajeria_spi)
  /*
  || Actualiza el estado y el mensaje mx de una solicitud de transferencia
  */
IS

   ex_error EXCEPTION;
   mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,'OK',null);
   v_det_log         varchar2(4000) := NULL;
   v_cant_liq        number(5):=0;
   v_cant_can        number(5):=0;
   v_cant_err        number(5):=0; 
   v_cant            number;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_RECHAZO_LIM');
   no_procesa        exception;
   v_msj_error       varchar2(2000);
PROCEDURE lp_reg_log_transferencia( p_respuesta in varchar2 )
   IS
   BEGIN
      --
      pas_snp.pr_set_texto(v_det_log, p_respuesta, pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto(v_det_log, 'Nro. Ref. Externa:  '|| '~' || p_nro_ref_externa || '~', pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Situación:          '|| p_situacion, pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Estado:             '|| p_estado, pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Error:             '||  p_error, pas_snp.fu_obt_salto);
      pas_snp.pr_reg_operacion( p_msj_mx, v_det_log );
      --
   EXCEPTION
     WHEN others THEN
       NULL;
   END lp_reg_log_transferencia;

BEGIN
   begin
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
   end;
  pas_spi.g_cod_error := 0;
  pas_spi.g_msj_error := NULL;
  g_lugar:='Actualiza transferencia';
  begin
    --DA-6727
      if p_situacion = 'V' and p_estado = 'W' then
        select count(*)
          into v_cant_liq
          from ge_snp_transferencias te
         where te.nro_ref_externa = p_nro_ref_externa
           and te.situacion = 'L'
           and te.estado = 'A';
           
        select count(*)
          into v_cant_can
          from ge_snp_transferencias te
         where te.nro_ref_externa = p_nro_ref_externa
           and te.situacion = 'C'
           and te.estado = 'R';
        select count(*)
          into v_cant_err
          from ge_snp_transferencias te
         where te.nro_ref_externa = p_nro_ref_externa
           and te.situacion = 'E'
           and te.estado = 'C';   
       -- 
         if v_cant_liq > 0 or v_cant_can > 0 or v_cant_err > 0  then
           null; --no debe actualizar nada
         else              
           update ge_snp_transferencias
              set estado    = p_estado,
                  msj_swift = p_msj_mx,
                  situacion = p_situacion,
                  error     = substr(p_error, 1, 4000)
            where nro_ref_externa = p_nro_ref_externa;
            if sql%notfound then
               raise ex_error;
            end if;
            if sql%found then
               lp_reg_log_transferencia( '0' /*|| '|' || v_cod_mensaje*/ || '|LOG DEL MT ' || trim(p_nro_ref_externa) );
               p_dat_mensaje        := mensaje;
            end if;
         end if;
      else
         update ge_snp_transferencias
            set estado    = p_estado,
                msj_swift = p_msj_mx,
                situacion = p_situacion,
                error     = substr(p_error, 1, 4000)
          where nro_ref_externa = p_nro_ref_externa;
         if sql%notfound then
          raise ex_error;
        end if; 
        if sql%found then
          --DA-7356 controla cantidad de reintentos,para poder reversar 
          begin
         select count(*)
           into v_cant
           from ge_spi_log_controles t
          where  t.nro_ref_externa = p_nro_ref_externa;
       exception
         when no_data_found then
           v_cant := 0;
         when others then
           v_cant := 0;
       end;
        if v_cant >= fug_obt_pardinamico( 'SPI_CANT_REINTENTO' ) then
           g_reversion:='S';
           pas_spi.pr_gen_rev_tra_008(p_nro_ref_externa);
           g_reversion:='N';
          if pas_spi.fu_obt_cod_error <> 0 then
            v_msj_error:= pas_spi.fu_obt_msj_error;
          raise no_procesa;
          else --spi fase2
               update ge_spi_solicitudes sl
               set sl.est_solicitud='R',
               sl.sit_solicitud='C'
               where sl.nro_referencia=(select tr.nro_referencia
                                        from Ge_Snp_Transferencias tr
                                         where tr.nro_ref_externa=p_nro_ref_externa);
          end if;
        end if; 
          lp_reg_log_transferencia( '0' /*|| '|' || v_cod_mensaje*/ || '|LOG DEL MT ' || trim(p_nro_ref_externa) );
          p_dat_mensaje        := mensaje;
        end if;
     end if;
     
  exception
    when ex_error then
    pas_spi.g_cod_error := 80;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'No existe registro de transferencia con nro_ref_externa ' ||
                         p_nro_ref_externa;
    lp_reg_log_transferencia( pas_spi.g_cod_error /*|| '|' || v_cod_mensaje*/ || '|LOG DEL MT ' || trim(p_nro_ref_externa) );
    mensaje.des_Respuesta:=sqlerrm;
    p_dat_mensaje         := mensaje;
    rollback;
  end;

EXCEPTION
  --DA-7356--envia correo si no puede procesar la reversion SPI
   when no_procesa then
              begin
                    if v_dir_correo is not null then
                       it_mail.mail( fug_obt_dir_correo,
                                     v_dir_correo,
                                     'Inconveniente en reversion SPI',
                                     'Hubo un error en la reversion de la operacion'
                                     || chr(10) ||'Nro. de referencia externa: '||p_nro_ref_externa
                                     || chr(10) ||'Detalle Error: '||v_msj_error
                                    );
                    end if;
                exception
                  when others then
                     null;
                end;
   when others then
     PAS_SPI.g_cod_error := 81;
     PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     mensaje.cod_respuesta  := 1;
     mensaje.nom_respuesta := 'Ocurrio error al actualizar datos de transferencia, nro_ref_externa' ||
                         p_nro_ref_externa;
     mensaje.des_Respuesta := sqlerrm;
     p_dat_mensaje         := mensaje;
END pr_act_tra_spi;
FUNCTION fu_val_dat_ingresado ( p_sql varchar2 ) return boolean
IS
  /*
  || Valida el dato ingresado en configuraciones.
  */

  type     t_tipo_cursor IS REF CURSOR;
  cu_datos t_tipo_cursor;
  v_existe varchar2(1):= 'N';
BEGIN
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
    pas_spi.g_cod_error := 180;
    pas_spi.g_msj_error := substr(sqlerrm,1,200);
    return FALSE;
END fu_val_dat_ingresado;
procedure pr_pro_msj_recibidos(p_dat_recibidos in  typ_Obtdatmsjrespuesta,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa respuesta recibida por el SPI
     1. Pacs.002
     2. Camt.010
     3. Camt.052
     4. Camt.025
     5. Camt.019
     6. Camt.034
  */
  v_tip_msj                     ge_spi_cab_versiones.tipo_msj%type;
  v_tip_msj_ori                 ge_spi_cab_versiones.tipo_msj%type;
  v_tip_msj_rel                 ge_spi_cab_versiones.tipo_msj%type:=null;
  v_mot_rechazo                 ge_snp_transferencias.tip_rechazo%type;
  v_nro_ref_msj_original        ge_spi_informes.nro_ref_msj_original%type;
  v_fec_rec_008                 ge_snp_transferencias.fec_recepcion%type;
  v_nro_ref_008                 ge_snp_transferencias.nro_referencia%type;
  v_situacion_008               ge_snp_transferencias.situacion%type;
  v_estado_008                  ge_snp_transferencias.estado%type;
  v_fecha_008                   ge_snp_transferencias.fecha%type;
  v_hora_008                    ge_snp_transferencias.hora%type;
  v_usuario_008                 ge_snp_transferencias.cod_usuario%type;
  v_nro_documento               ge_movimientos.nro_documento2%type:=null;
  v_nro_documento_noc           ge_movimientos_noc.nro_documento2%type:=null;
  v_fecha_noc                   ge_movimientos_noc.fecha%type;
  v_hora_noc                    ge_movimientos_noc.hora%type;
  v_cod_usuario_noc             ge_movimientos_noc.cod_usuario%type;
  v_cod_respuesta               number(10);
  v_nom_respuesta               varchar2(2000);
  v_monto_008                   ge_snp_transferencias.monto%type;
  v_moneda_008                  ge_snp_transferencias.cod_moneda%type;
  v_referencia_008              ge_snp_transferencias.cod_swi_pte_solicitante%type;
  v_cod_tip_operacion_008       ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_operacion_008   ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_nro_cta_beneficiario_008    ge_snp_transferencias.nro_cta_beneficiario%type;
  v_swi_pte_solicitante_008     ge_snp_transferencias.cod_swi_pte_solicitante%type;
  v_swi_suc_solicitante_008     ge_snp_transferencias.cod_swi_suc_solicitante%type;
  v_nro_cta_solicitante_008     ge_snp_transferencias.nro_cta_solicitante%type;
  v_cod_per_solicitante_008     ge_snp_transferencias.cod_per_solicitante%type;
  v_cod_msj_008                 ge_snp_transferencias.cod_msj_swift%type;
  v_cod_acept_rechazo           VARCHAR2(8);
  v_cod_error                   number(10);
  v_men_error                    varchar2(2000);
  r_spi_lim                     ge_spi_limites%rowtype;
  v_dir_notificaciones          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_RECHAZO_LIM');
  v_dir_rec_lim_correo          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_NOTIFICACIONES');
  rg_mensaje                    pas_snp.rg_msj;
  mensaje                       typ_mensajeria_spi := typ_mensajeria_spi(0,'OK',null);
  v_hor_reverso                 varchar2(10);
  v_hor_actual                  VARCHAR2(08);
  -- JFF Email 09/02/2022  
  v_email                    GE_PAR_GENERALES.DIR_CORREO%TYPE;
  v_email_dest               GE_PAR_GENERALES.DIR_CORREO%TYPE;
  v_nom_persona              ba_personas.nom_completo%type;
  v_error_admi               varchar2(4000);  -- admi.002
  v_error_camt_025           varchar2(4000);  -- camt.025
  v_dir_rec_admi_004         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_NOTIFICACIONES');
  v_dir_rec_admi_002         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_NOTIFICACIONES');
  v_cod_msj_mx               ge_spi_informes.cod_msj_mx%type;
  v_msj_mx                   ge_snp_mensajes.msj_swift%type;
  v_existe_ref               varchar2(1):='N';
  v_existe                   varchar2(1):='N';  
  v_situacion_002            ge_spi_informes.situacion%type;
  v_estado_002               ge_spi_informes.estado%type;
  v_inf_json                 long:=null;
  v_nom_beneficiario_008     ge_snp_transferencias.nom_beneficiario%type;
  v_aviso                    varchar2(2000);
  v_fec_insercion_008        ge_snp_transferencias.fec_insercion%type;
  v_pte_beneficiario         gv_snp_participantes.participante%type;
  v_swi_pte_beneficiario_008 ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  v_swi_suc_beneficiario_008 ge_snp_transferencias.cod_swi_suc_beneficiario%type;
  v_observacion_008          ge_snp_transferencias.observacion%type;
  v_cod_per_beneficiario_008 ge_snp_transferencias.cod_per_beneficiario%type;
  v_moneda                   ba_monedas.cod_mon_iso%type; 
  v_des_monto                varchar2(500) := NULL;
  v_ent_solicitante          varchar2(200) := NULL;
  v_ent_beneficiaria         varchar2(200) := NULL;  
  v_usu_reversion            ba_usuarios.cod_usuario%type;
  ex_ntransf EXCEPTION; 
    --SPI-10 MGF 24/04/2023
  v_fec_rec_004                 ge_snp_transferencias.fec_recepcion%type;
  v_nro_ref_004                 ge_snp_transferencias.nro_referencia%type;
  v_situacion_004               ge_snp_transferencias.situacion%type;
  v_estado_004                  ge_snp_transferencias.estado%type;
  v_fecha_004                   ge_snp_transferencias.fecha%type;
  v_hora_004                    ge_snp_transferencias.hora%type;
  v_usuario_004                 ge_snp_transferencias.cod_usuario%type;--
  v_monto_004                   ge_snp_transferencias.monto%type;
  v_moneda_004                  ge_snp_transferencias.cod_moneda%type;
  v_referencia_004              ge_snp_transferencias.cod_swi_pte_solicitante%type;
  v_cod_tip_operacion_004       ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_operacion_004   ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_nro_cta_beneficiario_004    ge_snp_transferencias.nro_cta_beneficiario%type;
  v_swi_pte_solicitante_004     ge_snp_transferencias.cod_swi_pte_solicitante%type;
  v_swi_suc_solicitante_004     ge_snp_transferencias.cod_swi_suc_solicitante%type;
  v_nro_cta_solicitante_004     ge_snp_transferencias.nro_cta_solicitante%type;
  v_cod_per_solicitante_004     ge_snp_transferencias.cod_per_solicitante%type;
  v_cod_msj_004                 ge_snp_transferencias.cod_msj_swift%type;
  v_nom_beneficiario_004        ge_snp_transferencias.nom_beneficiario%type;
  v_fec_insercion_004           ge_snp_transferencias.fec_insercion%type;
  v_fec_notificacion            varchar2(20);
  v_pte_beneficiario_004        gv_snp_participantes.participante%type;
  v_swi_pte_beneficiario_004    ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  v_swi_suc_beneficiario_004    ge_snp_transferencias.cod_swi_suc_beneficiario%type;
  v_observacion_004             ge_snp_transferencias.observacion%type;
  v_cod_per_beneficiario_004    ge_snp_transferencias.cod_per_beneficiario%type;
  v_nro_ref_msj_original_004    ge_spi_solicitudes.nro_ref_msj_original%type;
  v_nro_documento_004           ge_movimientos.nro_documento2%type:=null;
  v_nro_documento_noc_004       ge_movimientos_noc.nro_documento2%type:=null;
  v_fecha_noc_004               ge_movimientos_noc.fecha%type;
  v_hora_noc_004                ge_movimientos_noc.hora%type;
  v_cod_usuario_noc_004         ge_movimientos_noc.cod_usuario%type;
  v_can_registro                number(8):=0;
  v_nom_solicitante_004         varchar2(100);
  v_tip_persona                 ba_personas.tipo%type;
  v_ent_debito                  varchar2(100);
  v_ent_credito                 varchar2(100);
  v_concepto_004                varchar2(100);
  v_nombre_saludo               varchar2(100);
  v_nro_doc_beneficiario_004    ge_snp_transferencias.nro_doc_beneficiario%type;
  v_nro_ref_externa_004         ge_snp_transferencias.nro_ref_externa%type;
  v_tip_rechazo_004             ge_snp_transferencias.tip_rechazo%type;
  v_des_dev                     varchar2(100);
  --Para pacs008 generado como reversion
  v_concepto_008                ge_snp_transferencias.concepto%type;
  v_msj_respuesta               boolean;
  v_fec_valor                   ge_snp_transferencias.fec_valor%type;
  v_supera_limite               varchar2(1);
  v_error_008                   ge_snp_transferencias.error%type;
  v_ref_devolucion              ge_snp_transferencias.nro_referencia%type;
  v_error                       ge_snp_transferencias.error%type;
  --para solicitudes
  v_cod_sol_spi                 ge_spi_solicitudes.cod_sol_spi%type;
  v_cod_msj_sol                 ge_spi_solicitudes.cod_msj_swift%type;
  r_sol_recibida                ge_spi_solicitudes%rowtype;
  v_tip_mov                     varchar2(1);
  r_gtran                       pas_snp.rg_msj;
  ex_notificar                  exception;
  r_sol_enviada                 ge_spi_solicitudes%rowtype;
  v_titulo                      varchar2(500);
  rg_omp                        ge_entes%rowtype;
  r_sol_spi                     ge_spi_solicitudes%rowtype;
  v_ref_solicitud               ge_spi_solicitudes.nro_ref_externa%type;
  v_por_reversion               varchar2(1):='N';
  v_nro_ref_original            ge_spi_solicitudes.nro_ref_msj_original%type;
  r_pag_original                ge_snp_transferencias%rowtype;
  v_cod_mot_dev                 varchar2(10);
  c_cod_rechazo                 constant varchar2(10) :='EP252';
  v_cod_persona                 ba_personas.cod_persona%type;
  v_des_rechazo                 ba_cod_referencias.abreviatura%type;
  v_dominio                     ba_cod_referencias.dominio%type;
  v_par_cargo                   ba_cod_referencias.dominio%type;
  v_par_car_mon                 ba_cod_referencias.val_minimo%type;
  v_ind_cob_cargos              varchar2(1):='N';
BEGIN
   begin
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
   end;
   v_cod_acept_rechazo := p_dat_recibidos.cod_acept_rechazo;
   pas_spi.g_cod_error := 0;
   pas_spi.g_msj_error := NULL;
   v_usu_reversion:=null;
   v_error_admi :=  substr(p_dat_recibidos.mot_rechazo,1,200) ; 
   g_lugar:='Obtener tipo de mensaje de acuerdo a la version  principal recibida';
   --Obtiene el tipo de mensaje de acuerdo a la version principal recibida
   v_tip_msj := PAS_SPI.fu_tip_msj_ver(p_dat_recibidos.cod_msj_mx);
   g_lugar:='Obtener tipo de mensaje de acuerdo a la version del tip_msj_original';
   --Obtiene el tipo de mensaje de acuerdo a la version del tip_msj_original
   if p_dat_recibidos.tip_msj_original is not null then
      v_tip_msj_ori := PAS_SPI.fu_tip_msj_ver(p_dat_recibidos.tip_msj_original);
   end if;
   g_lugar:='Obtener tipo de mensaje de acuerdo a la version del tip_msj_relacionado';
   --Obtiene el tipo de mensaje de acuerdo a la version del tip_msj_relacionado
   if p_dat_recibidos.tip_msj_relacionado is not null then
      v_tip_msj_rel := PAS_SPI.fu_tip_msj_ver(p_dat_recibidos.tip_msj_relacionado);
   end if;
   if p_dat_recibidos.cod_msj_mx is not null then
      v_cod_msj_mx :=PAS_SPI.fu_tip_msj_ver(p_dat_recibidos.cod_msj_mx);
   end if;
   -- JFF control de duplicado ge_snp_mensajes
   g_lugar :=  'Validando Duplicados.';
         BEGIN   
         select 'S'
           into v_existe_ref
           from ge_snp_mensajes m
          where m.nro_ref_externa = p_dat_recibidos.nro_ref_externa
            and m.nro_referencia = p_dat_recibidos.nro_referencia
            and m.cod_msj_swift = v_cod_msj_mx
            and m.fec_valor = p_dat_recibidos.fec_valor
            and rownum = 1;
         exception 
           when no_data_found then 
             v_existe_ref := 'N'; 
            when others then 
              v_existe_ref := 'N'; 
         END;
        if nvl(v_existe_ref,'N')='S' then   
                raise ex_salir;
         end if;  
   -- MGF control de respuesta a un pacs008 enviado como reversión 
   -- por un pacs004 que no se pudo acreditar.
   g_lugar :=  'Validando si fue un envio por reversión De pacs004.';
         BEGIN   
         select 'S'
           into v_por_reversion
           from ge_snp_transferencias tr 
          where tr.nro_ref_externa = p_dat_recibidos.nro_ref_externa
            and tr.concepto like '/REV/%'
            and rownum = 1;
         EXCEPTION 
           when no_data_found then 
             v_por_reversion := 'N'; 
            when others then 
             v_por_reversion := 'N'; 
         END;  
   --Registra el mensaje
   g_lugar:='Registro de mensaje en ge_snp_mensajes';
   pas_spi.pr_reg_msj_generico(p_dat_recibidos,'S','S');
   -- Solo se procesa, si el registro en ge_snp_mensajes es exitosa
   if pas_spi.fu_obt_cod_error = 0 then

   v_msj_mx           := p_dat_recibidos.msj_mx; 
   g_lugar:='Registro de parametros en log';
   --Registro de parametros 
         pas_snp.pr_reg_operacion('Tipo mensaje recibido: '||v_tip_msj|| chr(10) ||
         ' Parametros: Nro_referencia: '||p_dat_recibidos.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||p_dat_recibidos.nro_ref_externa|| chr(10) || 
         ' Cod_msj_mx: '||p_dat_recibidos.cod_msj_mx|| chr(10) || 
         ' Fec_valor: '||p_dat_recibidos.fec_valor|| chr(10) || 
         ' Cod_moneda: '||p_dat_recibidos.cod_moneda|| chr(10) || 
         ' Monto: '||p_dat_recibidos.monto|| chr(10) || 
         ' Tip_msj_original: '||p_dat_recibidos.tip_msj_original|| chr(10) || 
         ' Res_procesamiento: '||p_dat_recibidos.res_procesamiento|| chr(10) || 
         ' Cod_motivo_rechazo: '||p_dat_recibidos.cod_motivo_rechazo|| chr(10) || 
         ' Mot_rechazo: '||p_dat_recibidos.mot_rechazo|| chr(10) || 
         ' Nro_ref_relacionado: '||p_dat_recibidos.nro_ref_relacionado|| chr(10) || 
         ' Tip_msj_relacionado: '||p_dat_recibidos.tip_msj_relacionado|| chr(10) || 
         ' Can_lim_establecido: '||p_dat_recibidos.can_lim_establecido|| chr(10) || 
         ' Can_lim_utilizada: '||p_dat_recibidos.can_lim_utilizada|| chr(10) || 
         ' Cod. Estado: '||p_dat_recibidos.cod_estado|| chr(10) || 
         ' Por_lim_utilizado: '||p_dat_recibidos.por_lim_utilizado
         , g_lugar||' Nro_referencia: '||p_dat_recibidos.nro_referencia); 
   /*
    || pacs.002: Mensaje de estado
   */
   if v_tip_msj = g_pac_002 then
    if g_cod_error=0 then 
       if  p_dat_recibidos.res_procesamiento not in ('ACSP','ACSC','RJCT') then 
         --Valida el resultado que se recibe en el parametro   res_procesamiento
         g_lugar:='Validacion de respuesta procesamiento';
         mensaje.cod_respuesta := 1;
         mensaje.nom_respuesta := 'El valor ' ||
                                  p_dat_recibidos.res_procesamiento ||
                                  ' es icorrecto';
         mensaje.des_Respuesta := 'No se recibio ACSP o ACSC o RJCT ';
         p_dat_mensaje         := mensaje;
        end if; 
      /*
      || pacs.002: Mensaje de estado- en respuesta de pacs.028
      */ 
      if v_tip_msj_ori =g_pac_008 and v_tip_msj_rel= g_pac_028 then
        
            --busca el pacs.028 del cual se está respondiendo
            select nro_ref_msj_original
              into v_nro_ref_msj_original
              from ge_spi_informes
             where nro_ref_externa = p_dat_recibidos.nro_ref_relacionado;
            --busca el pacs.008 consultado en el pacs.028
            select fec_recepcion, nro_referencia, situacion, estado,fecha,hora,cod_usuario
              into v_fec_rec_008,
                   v_nro_ref_008,
                   v_situacion_008,
                   v_estado_008,
                   v_fecha_008,
                   v_hora_008,
                   v_usuario_008
              from ge_snp_transferencias
             where nro_ref_externa = v_nro_ref_msj_original;--p_dat_recibidos.nro_ref_externa
            if v_fec_rec_008 is null then--significa transferencia enviada
              if p_dat_recibidos.res_procesamiento in ( 'ACSP','ACSC') then
                if v_situacion_008 != 'L' and  v_estado_008 != 'A' then
                  /*
                  || Pago aprobado se recibe pacs.028/ACSP relacionado al pacs.008
                  */
                    begin
                   select distinct nro_documento
                             into v_nro_documento
                             from gv_movimientos
                            where fecha = v_fecha_008
                              and hora = v_hora_008
                              and cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008
                              and reversado = 'N';
                   exception
                                when no_data_found then
                                  v_nro_documento:= null;
                                when others then
                                  v_nro_documento:= null;
                         end;
                 if v_nro_documento is null then
                 
                   g_lugar := 'Actualiza estado y situacion de la transferencia '||v_nro_ref_008;
                   update ge_snp_transferencias
                         set estado = 'A', situacion = 'L'
                       where nro_ref_externa = v_nro_ref_msj_original;--p_dat_recibidos.nro_ref_externa
                 end if;
                 if v_nro_documento is not null then
                   --Se Confirma que existe el movimiento de débito
                   update ge_snp_transferencias
                     set estado = 'A', situacion = 'L'
                   where nro_ref_externa = v_nro_ref_msj_original;
                 end if; 
                  
                end if;
              end if;
              if p_dat_recibidos.res_procesamiento = 'RJCT' then
                if v_situacion_008 != 'C' or v_estado_008 != 'R' then
                  /*
                  || Pago rechazado se recibe  pacs.028/RJCT relacionado al pacs.008
                  */
                     --Controla si el mov esta reversado
                        g_lugar := 'Busca si el movimiento esta reversado, Nro.ref.' ||v_nro_ref_008;
                         begin
                           select distinct nro_documento
                             into v_nro_documento
                             from gv_movimientos
                            where fecha = v_fecha_008
                              and hora = v_hora_008
                              and cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008
                              and reversado = 'S';
                              exception
                                when no_data_found then
                                  v_nro_documento:= null;
                                when others then
                                  v_nro_documento:= null;
                         end;
                           if v_nro_documento is null then
                                g_lugar := 'Actualizar situacion de la operacion con ref.ext.' ||
                                        v_nro_ref_msj_original;
                                 --No se encuentra reversado , reversar el débito de la cuenta y luego actualizar el registro a situacion = C y estado = R ya que por algún motivo el procesamiento del registro no quedó finalizado. 
                                  update ge_snp_transferencias
                                       set situacion = 'C'
                                     where nro_ref_externa = v_nro_ref_msj_original;
                                 g_lugar := 'Reversion de la operacion con ref.' ||
                                            v_nro_ref_msj_original;
                                 pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,
                                                              'Rev.' ||
                                                              v_tip_msj_ori || '-' ||
                                                              p_dat_recibidos.nro_referencia ||
                                                              ' - SPI',
                                                              'R');
                                 if pas_snp.fu_obt_cod_error <> 0 then
                                   mensaje.cod_respuesta := 1;
                                   mensaje.nom_respuesta := 'Reversion de la operacion con ref.' ||
                                                            v_nro_ref_008;
                                   mensaje.des_Respuesta := 'No se pudo procesa RJCT '||sqlerrm;
                                   raise ex_error;
                                 end if;
                           elsif v_nro_documento is not null then
                             --Ya existe movimiento reversado, actualizar solo el estado y situacion
                              g_lugar := 'Actualizar situacion y estado de la operacion con ref.' ||
                                        v_nro_ref_msj_original;
                              update ge_snp_transferencias
                                   set situacion = 'C',estado='R'
                                 where nro_ref_externa = v_nro_ref_msj_original;
                           end if;
                           
                end if;
                if v_situacion_008 = 'C' and v_estado_008 = 'R' then 
                  --Validar que se haya realizado la reversión del movimiento.
                  begin
                  select distinct nro_documento
                             into v_nro_documento
                             from gv_movimientos
                            where fecha = v_fecha_008
                              and hora = v_hora_008
                              and cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008
                              and reversado = 'S';
                   exception
                                when no_data_found then
                                  v_nro_documento:= null;
                                when others then
                                  v_nro_documento:= null;
                         end;
                  if v_nro_documento is null then
                    --No existe la reversión, realizar el movimiento de reversión del nro_ref_externa.
                     g_lugar := 'Reversion de la operacion con ref.' ||v_nro_ref_008;
                             pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,
                                                          'Rev.' ||
                                                          v_tip_msj_ori || '-' ||
                                                          p_dat_recibidos.nro_referencia||
                                                          ' - SPI',
                                                          'R');
                             if PAS_SNP.fu_obt_cod_error <> 0 then
                               mensaje.cod_respuesta := 1;
                               mensaje.nom_respuesta := 'Reversion de la operacion con ref.' ||v_nro_ref_008;
                               mensaje.des_Respuesta := 'No se pudo procesar la reversion ';
                               raise ex_error;
                             end if;
                   end if;
                end if; 
              end if;

            elsif v_fec_rec_008 is not null then--significa transferencia recibida
              if p_dat_recibidos.res_procesamiento in ( 'ACSP','ACSC') then
                if v_situacion_008 != 'L' and v_estado_008 != 'A' then
                  /*
                  || Pago aprobado se recibe pacs.028/ACSP relacionado al pacs.008
                  */
                  --Validar que exista la acreditacion en la cuenta del cliente.
                     g_lugar := 'Busca si el movimiento esta acreditado, Nro.ref.' ||v_nro_ref_008;
                      begin
                           select distinct nro_documento
                             into v_nro_documento
                             from gv_movimientos
                            where fecha = v_fecha_008
                              and hora = v_hora_008
                              and cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008
                              and reversado = 'N';
                      exception
                                when no_data_found then
                                  v_nro_documento:= null;
                                when others then
                                  v_nro_documento:= null;
                         end;
                    if v_nro_documento is not null then
                      --Existe acreditación , solo actualizar el registro a situacion = L y estado = A.
                      g_lugar := 'Actualizar situacion y estado de la operacion con ref.' ||
                                        v_nro_ref_msj_original;
                      update ge_snp_transferencias
                       set estado = 'A', situacion = 'L'
                      where nro_ref_externa = v_nro_ref_msj_original;
                    elsif v_nro_documento is  null then
                      --No existe, realizar acreditación y luego actualizar el registro a situacion = L y estado = A.
                         g_lugar := 'Actualizar situacion y estado de la operacion con ref.' ||
                                        v_nro_ref_msj_original;
                          update ge_snp_transferencias
                           set estado = 'A', situacion = 'L'
                          where nro_ref_externa = v_nro_ref_msj_original; 
                    end if;
                  
                elsif v_situacion_008 = 'L' and  v_estado_008 = 'A' then
                  --Validar que exista la acreditacion en la cuenta del cliente.
                  begin
                           select distinct nro_documento
                             into v_nro_documento
                             from gv_movimientos
                            where fecha = v_fecha_008
                              and hora = v_hora_008
                              and cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008
                              and reversado = 'N';
                     exception
                                when no_data_found then
                                  v_nro_documento:= null;
                                when others then
                                  v_nro_documento:= null;
                         end;
                      if v_nro_documento is  null then
                        --No Existe acreditacion entonces realizar la acreditacion 
                       g_lugar := 'Actualizar situacion y estado de la operacion con ref.' ||
                                        v_nro_ref_msj_original;
                          update ge_snp_transferencias
                           set estado = 'A', situacion = 'L'
                          where nro_ref_externa = v_nro_ref_msj_original; 
                       end if;
                end if;
              end if;
              if p_dat_recibidos.res_procesamiento = 'RJCT' then
                if v_situacion_008 != 'C' or v_estado_008 != 'R' then
                  /*
                  || Pago rechazado se recibe  pacs.028/RJCT relacionado al pacs.008
                  */
                   --validar que no exista movimiento de acreditación en la cuenta.
                   begin
                   select distinct nro_documento
                             into v_nro_documento
                             from gv_movimientos
                            where fecha = v_fecha_008
                              and hora = v_hora_008
                              and cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008
                              and reversado = 'N';
                   exception
                                when no_data_found then
                                  v_nro_documento:= null;
                                when others then
                                  v_nro_documento:= null;
                         end;
                      if v_nro_documento is  not null then
                        --Existe acreditacion ,realizar la reversión de la acreditación y luego actualizar el registro a situacion = C y estado = R.
                       g_lugar := 'Actualizar situacion de la operacion con ref.' ||v_nro_ref_msj_original;
                       update ge_snp_transferencias
                          set situacion = 'C'
                       where nro_ref_externa = v_nro_ref_msj_original;
                       g_lugar := 'Reversion de la operacion con ref.' ||v_nro_ref_msj_original;
                       pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,
                                                              'Rev.' ||
                                                              v_tip_msj_ori || '-' ||
                                                              p_dat_recibidos.nro_referencia ||
                                                              ' - SPI',
                                                              'R');
                        if pas_snp.fu_obt_cod_error <> 0 then
                           mensaje.cod_respuesta := 1;
                           mensaje.nom_respuesta := 'Reversion de la operacion con ref.' ||v_nro_ref_008;
                           mensaje.des_Respuesta := 'No se pudo procesa RJCT ';
                           raise ex_error;
                        end if;
                      elsif v_nro_documento is  null then
                        --Actualizar el registro a situacion = C y estado = R ya que por algún motivo el procesamiento del registro no quedó finalizado.
                         g_lugar := 'Actualizar situacion y estado de la operacion con ref.' ||
                                        v_nro_ref_msj_original;
                         update ge_snp_transferencias
                           set estado = 'R', situacion = 'C'
                         where nro_ref_externa = v_nro_ref_msj_original;
                      end if; 
                elsif  v_situacion_008 = 'C' and  v_estado_008 = 'R' then
                  --validar que no exista movimiento de acreditación en la cuenta.
                 begin
                   select distinct nro_documento
                             into v_nro_documento
                             from gv_movimientos
                            where fecha = v_fecha_008
                              and hora = v_hora_008
                              and cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008
                              and reversado = 'N';
                   exception
                                when no_data_found then
                                  v_nro_documento:= null;
                                when others then
                                  v_nro_documento:= null;
                         end;
                      if v_nro_documento is  not null then
                        --Se debe realizar la reversión de la acreditación.
                         g_lugar := 'Reversion de la operacion con ref.' ||v_nro_ref_008;
                             pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,
                                                          'Rev.' ||
                                                          v_tip_msj_ori || '-' ||
                                                          p_dat_recibidos.nro_referencia||
                                                          ' - SPI',
                                                          'R');
                             if PAS_SNP.fu_obt_cod_error <> 0 then
                               mensaje.cod_respuesta := 1;
                               mensaje.nom_respuesta := 'Reversion de la operacion con ref.' ||v_nro_ref_008;
                               mensaje.des_Respuesta := 'No se pudo procesar la reversion ';
                               raise ex_error;
                             end if;
                        
                      end if; 
                end if;

              end if;

            end if;
            --Actualiza la situacion y estado del informe(pacs.028)
            update ge_spi_informes
               set estado = 'A', situacion = 'L'
             where nro_ref_msj_original = p_dat_recibidos.nro_ref_externa;
      /*
      || pacs.002: Mensaje de estado- en respuesta de pacs.008
      */
      elsif v_tip_msj_ori = g_pac_008 and v_tip_msj_rel is null  then
        g_lugar:='Proceso de pacs.002 en respuesta de pacs.008';
        --busca el pacs.008 recibido, al que corresponde la confirmación o rechazo
        begin
            select fec_recepcion,
                   cod_msj_swift,
                   nro_referencia,
                   situacion,
                   estado,
                   fecha,
                   hora,
                   cod_usuario,
                   cod_moneda,
                   monto,
                   cod_swi_pte_solicitante,
                   cod_tip_operacion,
                   cod_sub_tip_operacion,
                   nro_cta_beneficiario,
                   nro_cta_solicitante,
                   cod_per_solicitante,
                   nom_beneficiario,
                   fec_insercion,
                   cod_swi_pte_beneficiario,
                   observacion,
                   cod_per_beneficiario,
                   cod_swi_pte_solicitante,
                   cod_swi_suc_solicitante,
                   cod_swi_suc_beneficiario,
                   concepto,
                   error,
                   fec_valor
              into v_fec_rec_008,
                   v_cod_msj_008,
                   v_nro_ref_008,
                   v_situacion_008,
                   v_estado_008,
                   v_fecha_008,
                   v_hora_008,
                   v_usuario_008,
                   v_moneda_008,
                   v_monto_008,
                   v_referencia_008,
                   v_cod_tip_operacion_008,
                   v_cod_sub_tip_operacion_008,
                   v_nro_cta_beneficiario_008,
                   v_nro_cta_solicitante_008,
                   v_cod_per_solicitante_008,
                   v_nom_beneficiario_008,
                   v_fec_insercion_008,
                   v_swi_pte_beneficiario_008,
                   v_observacion_008,
                   v_cod_per_beneficiario_008,
                   v_swi_pte_solicitante_008,
                   v_swi_suc_solicitante_008,
                   v_swi_suc_beneficiario_008,
                   v_concepto_008,
                   v_error,
                   v_fec_valor
              from ge_snp_transferencias
             where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
           exception 
             when no_data_found then
               raise ex_ntransf;
             when others then
               raise ex_ntransf;
           end;
           /*SPI FASE2
           Es un pacs002 de un pacs008 en respuesta de un pain.013 enviado
           */
           begin
                 select sl.*
                 into r_sol_spi
                 from ge_spi_solicitudes sl
                 where sl.nro_referencia=v_nro_ref_008
                 and sl.cod_msj_swift in
                 (fug_obt_pardinamico('COD_SPI_SOL_PAGO'),
                 fug_obt_pardinamico('COD_SPI_INI_PAGO'));

                 v_msj_respuesta:=true;
           exception
                when no_data_found then
                     v_msj_respuesta:=false; 
           end;
         if v_cod_msj_008 is not null then
          if v_fec_rec_008 is null then--significa transferencia enviada
         
                 if p_dat_recibidos.res_procesamiento in ( 'ACSP','ACSC') then
                       g_lugar:='Proceso de pacs.002 ACSP transferencia enviada ';
                    g_lugar:='Actualizacion de mensaje MX-ACSP';
                    /*
                    || Pago aprobado se recibe pacs.002/ACSP
                    */
                    --Si es un pacs008 de reversion actualizo Situacion C y estado R en la tranferencia.
                    --Si no es pacs008 de reversion,  actualiza estado y situacion de forma normal.
                    v_can_registro:=0;

                    select count(*)
                    into  v_can_registro
                    from ge_spi_solicitudes sl 
                    where to_char(sl.nro_referencia)=trim(replace(v_concepto_008,'/REV/',''))
                    and sl.cod_msj_swift in (fug_obt_pardinamico('COD_SPI_SOL_PAGO'),
                    fug_obt_pardinamico('COD_SPI_DEV'));

                    if v_can_registro>0 then
                       update ge_snp_transferencias t
                       set situacion = 'L',
                             estado = 'R', 
                             error  = 'Reversion de la devolucion no Acreditada.'
                       where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                    else 
                      update ge_snp_transferencias
                         set estado = 'A', situacion = 'L'
                       where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                       --spi fase 2
                       if v_msj_respuesta then
                              update ge_spi_solicitudes sll
                              set sll.sit_solicitud='L',
                              sll.est_solicitud='A'
                              where sll.nro_referencia=v_nro_ref_008; 
                       end if;
                    end if;   
                 if sql%rowcount > 0 then  --Envio de mail circular 007 enviado , Transf.Recibida Acreditada
                    --DA-8974
                    v_des_monto:=trim(to_char(v_monto_008,'9,999,999,999,999,990.00'))||' '||v_moneda_008||'.';
                    --SPI Fase 2
                    if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                        v_ent_beneficiaria:=it.fus_obt_nom_sub_participante(v_swi_pte_beneficiario_008,v_swi_suc_beneficiario_008);
                    else
                        v_ent_beneficiaria:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_008);
                    end if;
                    --pain001
                    if r_sol_spi.cod_msj_swift=fug_obt_pardinamico('COD_RES_INI_PAGO') then
                       rg_omp:=pas_spi.fu_obt_dat_omp(r_sol_spi.uetr);
                       v_ent_beneficiaria:=rg_omp.descripcion;
                    end if;
                       begin
                         v_inf_json        := '{' || '"nro_transaccion":' || '"' || p_dat_recibidos.nro_ref_externa || '"' || ',' || -- Nro. de Operación
                                                     '"fec_transferencia":' || '"' || to_char(v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || --Fecha y hora de Operación
                                                     '"nom_cue_debito":' || '"' || FUE_OBT_NOM_PERSONA(v_cod_per_solicitante_008) || '"' || ',' || --Cliente Pagador
                                                     '"num_cue_debito":' || '"' || v_nro_cta_solicitante_008 || '"' || ',' || --Nro. de Cuenta del Pagador
                                                     '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                                     '"ban_cue_beneficiario":' || '"' || v_ent_beneficiaria || '"' || ',' || --Entidad Beneficiaria
                                                     '"nom_beneficiario":' || '"' || v_nom_beneficiario_008 || '"' || ',' || --Cliente Beneficiario
                                                     '"num_cue_beneficiario":' || '"' || v_nro_cta_beneficiario_008 || '"' || ',' || --Número de cuenta del Cliente Beneficiario
                                                     '"aviso":' || '"' || 'La transferencia ha sido acreditada al Participante Beneficiario.' || '"' || '}'; --Texto sugerido
                         --Insertar correo para el solicitante
                         --pr_env_alerta(v_cod_per_solicitante_008,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVCLISNP'),v_inf_json); --TCE-249 tipo de producto 8
                     exception
                        when others then
                          null;--no realiza accion si da error envio de correo
                     end;
                 end if;
                 --    
                 elsif  p_dat_recibidos.res_procesamiento = 'RJCT' then
                     g_lugar:='Actualizacion de mensaje MX-RJCT';
                     
                     v_mot_rechazo := p_dat_recibidos.cod_motivo_rechazo;
                     --DA-10242
                     if   ((v_situacion_008='L' and  v_estado_008='A')
                          or (v_situacion_008='C' and  v_estado_008='R')) then
                           g_lugar:='Verificando duplicacion pacs002';
                           pas_spi.g_msj_error:='Mensaje duplicado, la transferencia está en situacion: '||v_situacion_008||' y estado: '||v_estado_008;
                           raise ex_error;
                     end if;
                     
                   /*
                    || Pago rechazado se recibe  pacs.002/RJCT
                    */
                   --Busca movimiento diario
                   begin
                     select distinct nro_documento
                       into v_nro_documento
                       from ge_movimientos
                      where fecha = v_fecha_008
                        and hora = v_hora_008
                        and cod_usuario = v_usuario_008
                        and nro_documento = v_nro_ref_008;
                   exception
                     when no_data_found then
                         begin
                           select distinct nro_documento, fecha, hora, cod_usuario
                             into v_nro_documento_noc,v_fecha_noc,v_hora_noc,v_cod_usuario_noc
                             from ge_movimientos_noc
                            where cod_usuario = v_usuario_008
                              and nro_documento = v_nro_ref_008;
                         exception
                           when no_data_found then
                             v_nro_documento_noc := null;
                           when others then
                             v_nro_documento_noc := null;
                         end;
                     when others then
                       v_nro_documento := null;
                   end;
                   --Reversion del dia
                   if v_nro_documento is not null then
                     update ge_snp_transferencias
                        set situacion = 'C', 
                           -- estado = 'R', 
                            tip_rechazo = v_mot_rechazo,
                            --error = p_dat_recibidos.mot_rechazo
                            error ='Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI'
                      where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                     g_lugar:='Reversion de la operacion con ref.'||p_dat_recibidos.nro_referencia;
                     g_reversion:='S';
                     --pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI','R');
                     --TRFS-602
                     pas_spi.pr_rev_ope_spi(v_nro_ref_008,'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI','R',p_dat_recibidos.nro_ref_externa,v_fecha_008,v_hora_008,v_usuario_008);
                    
                     g_reversion:='N';
                     --spi fase 2
                     if v_msj_respuesta then
                        update ge_spi_solicitudes sll
                        set sll.sit_solicitud='C',
                        sll.est_solicitud='R'
                        where sll.nro_referencia=v_nro_ref_008; 
                     end if;

                     if pas_snp.fu_obt_cod_error <> 0 then
                            raise ex_error;
                     end if;
                   end if; 
                   --Reversion mov nocturnos
                   if v_nro_documento_noc is not null then
                      v_hor_reverso:=fug_obt_mov_hora;
                        g_lugar:='Reversion de la operacion con ref.'||p_dat_recibidos.nro_ref_externa;
                      begin
					    prs_snp_obt_usu_hor_movimiento(user,'S',v_usu_reversion,v_hor_reverso);
                        prg_gen_mov_noc_spi(v_monto_008,
                                            v_nro_cta_solicitante_008,
                                            pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),pag_gen.fu_obt_mon_local) ,'C'),
                                            v_moneda_008,
                                            v_cod_msj_008,
                                            v_cod_tip_operacion_008,
                                            v_cod_sub_tip_operacion_008,
                                            v_nro_ref_008,
                                            p_dat_recibidos.nro_ref_externa,
                                            v_referencia_008,
                                            'E',
                                            'S',
                                            v_fecha_noc,
                                            v_hora_noc,
                                            v_cod_usuario_noc,
                                            v_usu_reversion,
                                            v_hor_reverso,
                                            v_cod_respuesta,
                                            v_nom_respuesta);     
                        exception
                          when others then
                            rollback; 
                            mensaje.cod_respuesta := '1';
                            mensaje.nom_respuesta := 'Error en el proceso de reversion -'||v_nro_ref_008||'-' || sqlerrm;
                            mensaje.des_Respuesta :='No se pudo procesar reversion';
                            raise ex_error;
                        end;
                        if v_cod_respuesta =0 then
                        --Realiza la actualizacion de la transferencia
                         g_lugar:='Actualizacion de mensaje MX-RJCT';
                          update ge_snp_transferencias
                             set situacion   = 'C',
                                 estado      = 'R',
                                 tip_rechazo = v_mot_rechazo,
                                 error       = 'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI'--p_dat_recibidos.mot_rechazo
                           where nro_ref_externa =
                                 p_dat_recibidos.nro_ref_externa;
                       else 
                          g_lugar:='Envio de notificacion por error';
                          begin
                             --SPI Fase 2
                             if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                                 v_pte_beneficiario:=it.fus_obt_nom_sub_participante(v_swi_pte_beneficiario_008,v_swi_suc_beneficiario_008);
                             else
                                 v_pte_beneficiario:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_008);
                             end if;
                             --pain001
                             if r_sol_spi.cod_msj_swift=fug_obt_pardinamico('COD_RES_INI_PAGO') then
                                rg_omp:=pas_spi.fu_obt_dat_omp(r_sol_spi.uetr);
                                v_pte_beneficiario:=rg_omp.descripcion;
                             end if;
                             if v_dir_notificaciones is not null then

                                    IF v_por_reversion = 'N' THEN
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de reversion con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Transferencia enviada con inconvenientes en reversion, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));
                                    ELSE
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de reversion con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Transferencia enviada con inconvenientes en reversion. Favor verificar!'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));  
                                    END IF;              

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                       end if;
                        --spi fase 2
                       if v_msj_respuesta then
                          update ge_spi_solicitudes sll
                          set sll.sit_solicitud='C',
                          sll.est_solicitud='R'
                          where sll.nro_referencia=v_nro_ref_008; 
                       end if;
                   end if; 
                         --Envia notificacion por pacs.002 tipo RJCT rechazado por la contraparte
                       if mensaje.cod_respuesta=0 then
                         if v_mot_rechazo='EL201'then
                                if sql%rowcount > 0 then -- circular 007 spi rechazado , Transf. Enviada Rechazada
                                  if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                                      v_ent_beneficiaria:=it.fus_obt_nom_sub_participante(v_swi_pte_beneficiario_008,v_swi_suc_beneficiario_008);
                                  else
                                      v_ent_beneficiaria:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_008);
                                  end if;
                                  v_des_monto:=trim(to_char(v_monto_008,'9,999,999,999,999,990.00'))||' '||v_moneda_008||'.';
                                    begin
                                         v_inf_json        := '{' || '"nro_transaccion":' || '"' || p_dat_recibidos.nro_ref_externa || '"' || ',' || -- Nro. de Operación
                                                                     '"fec_transferencia":' || '"' || to_char(v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || --Fecha y hora de Operación
                                                                     '"nom_cue_debito":' || '"' || FUE_OBT_NOM_PERSONA(v_cod_per_solicitante_008) || '"' || ',' || --Cliente Pagador
                                                                     '"num_cue_debito":' || '"' || v_nro_cta_solicitante_008 || '"' || ',' || --Nro. de Cuenta del Pagador
                                                                     '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                                                     '"ban_cue_beneficiario":' || '"' ||v_ent_beneficiaria || '"' || ',' || --Entidad Beneficiaria
                                                                     '"nom_beneficiario":' || '"' || v_nom_beneficiario_008 || '"' || ',' || --Cliente Beneficiario
                                                                     '"num_cue_beneficiario":' || '"' || v_nro_cta_beneficiario_008 || '"' || ',' || --Número de cuenta del Cliente Beneficiario
                                                                     '"aviso":' || '"' || 'La transferencia ha sido rechazada por el Participante Beneficiario.' || '"' || '}'; --Texto sugerido
                                          --Insertar correo para el solicitante
                                       --pr_env_alerta(v_cod_per_solicitante_008,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTRVSPI'),v_inf_json);  --TCE-249 tipo de producto 25
                                   exception
                                      when others then
                                        null;--no realiza accion si da error envio de correo
                                   end;
                                 end if;
                         end if;
                         if v_mot_rechazo='EL202'then
                           -- Envia notificacion por pacs.002 tipo Time out
                           /*
                           || Notificaciones al cliente
                           */
                               --Envio de sms
                               begin
                               prg_env_sms_spi(v_cod_per_solicitante_008,g_cod_mad_padre,'GEN_ENV_SMS_TRA_SPI_TO1',v_cod_error,v_men_error);
                               exception
                                  when others then
                                    null;--no realiza accion si da error envio de sms
                               end;
                               --Envio de mail
                               begin
                                   v_aviso:= fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_TO1');
                                   v_inf_json:='{' || '"fec_transferencia":' || '"' ||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')|| '"' || ',' ||
                                   '"nom_beneficiario":' || '"' ||v_nom_beneficiario_008|| '"' || ',' ||
                                   '"monto":' || '"' ||ltrim(rtrim(to_char(v_monto_008,'9,999,999,999,999,990.00')))||' '||initcap(v_moneda_008)||'.'||'"' || ',' ||
                                   '"aviso":' || '"' ||v_aviso|| '"' || '}';
                                   --Insertar correo para el solicitante
                                   --pr_env_alerta(v_cod_per_solicitante_008,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTRECSPI'),v_inf_json);--TCE-249 tipo de producto 26 
                               exception
                                  when others then
                                    null;--no realiza accion si da error envio de correo
                               end;
                               
                               /*
                               || Notificacion internas a operaciones 
                               */
                   
                                begin
                                  if v_dir_notificaciones is not null then
                                      if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                                          v_pte_beneficiario:=it.fus_obt_nom_sub_participante(v_swi_pte_beneficiario_008,v_swi_suc_beneficiario_008);
                                      else
                                         v_pte_beneficiario:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_008);
                                      end if;
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Rechazo de transferencia SPI - RJCT por time out (EL202)'||'.',
                                                   'Transferencia rechazada por time out'
                                                   || chr(10) ||'Nro. Referencia: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                         end if; 
                         if v_mot_rechazo='EP183'then--Lack of funds
                               /*
                               || Notificacion internas a operaciones 
                               */
                   
                                begin
                                  if v_dir_notificaciones is not null then
                                      if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                                          v_pte_beneficiario:=it.fus_obt_nom_sub_participante(v_swi_pte_beneficiario_008,v_swi_suc_beneficiario_008);
                                      else
                                          v_pte_beneficiario:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_008);
                                      end if;
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Rechazo de transferencia SPI - RJCT por falta de fondos (EP183)'||'.',
                                                   'Transferencia rechazada por falta de fondos'
                                                   || chr(10) ||'Nro. Referencia: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                         end if; 
                       end if;
                    IF v_por_reversion = 'S' THEN
                        --Actualizo estado de la transferencia a cancelado
                        update ge_snp_transferencias
                        set situacion = 'C', 
                           -- estado = 'R', 
                            tip_rechazo = v_mot_rechazo,
                            error = p_dat_recibidos.mot_rechazo
                      where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                     g_lugar:='Reversion de la operacion con ref.'||p_dat_recibidos.nro_referencia;
                     --No genera reversion xq no tenía generadop movimiento en esta instancia.
                     --pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI','R');

                          g_lugar:='Envio de notificacion por error en pacs002 por un pacs008 enviado como reversion de una DEV no acreditada.';
                          begin
                             --SPI Fase 2
                             if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                                 v_pte_beneficiario:=it.fus_obt_nom_sub_participante(v_swi_pte_beneficiario_008,v_swi_suc_beneficiario_008);
                             else
                                 v_pte_beneficiario:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_008);
                             end if;
                             if v_dir_notificaciones is not null then

                                    --IF v_por_reversion = 'S' THEN
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de reversion con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Transferencia enviada con inconvenientes en reversion. Favor verificar!'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));  
                                    --END IF;              

                              end if;
                          exception
                              when others then
                                   null;
                          end;
                    END IF;      
                 end if;
          elsif v_fec_rec_008 is not null then--significa transferencia recibida
            
             if p_dat_recibidos.res_procesamiento in ( 'ACSP','ACSC' ) then
                  g_lugar:='Proceso de pacs.002 ACSP transferencia recibida ';
                  --spi Fase 2
                  if v_msj_respuesta  and v_error is null then
                       lp_ver_horario(3);

                       if g_mod_estado in (1,6) then
                         v_error:='Entidad en proceso de cierre';
                       else
                           pag_cta.pr_obt_cuenta (v_nro_cta_beneficiario_008);--recuperar los datos de la cuenta
                           v_supera_limite:= fua_obt_limite_cta_basica
                                                     (v_nro_cta_beneficiario_008,
                                                      v_monto_008,
                                                      v_fec_valor,
                                                      pag_cta.g_ctas.cod_modalidad,
                                                      pag_cta.g_ctas.cod_moneda);

                          if nvl(v_supera_limite,'N')='S' then
                            v_error:='Sumatoria de transferencias recibidas, supera el maximo posible para el tipo de cuenta';
                          end if; 
                       end if;
                   end if;
                 --SPI FASE 2
                if v_msj_respuesta  and v_error is not null then 
                     g_lugar:='Proceso para devolver pacs008 en respuesta de pain.013';
                     pr_gen_rev_dev_013(v_nro_ref_008,
                                        v_cod_respuesta,
                                        v_nom_respuesta,
                                        v_ref_devolucion);

                     update ge_spi_solicitudes sll
                     set sll.sit_solicitud='C',
                     sll.est_solicitud='R'
                     where sll.nro_referencia=v_nro_ref_008
                     and sll.est_solicitud!='R'
                     and sll.sit_solicitud!='C';  

                     update ge_snp_transferencias
                     set estado = 'R', situacion = 'C',
                     error=nvl(error,v_error)
                     where nro_ref_externa = p_dat_recibidos.nro_ref_externa
                     and estado!='R' and situacion!='C';

                     if v_cod_respuesta <> 0 then
                            mensaje.cod_respuesta := 1;
                            mensaje.nom_respuesta := 'Error al intentar devolver la transferencia N°.' ||v_nro_ref_008;
                            mensaje.des_Respuesta := substr('No se pudo registrar la transferencia:'||v_nom_respuesta,1,2000);
                            g_lugar:='Envio de notificacion por error';
                            begin

                                  if v_dir_notificaciones is not null then

                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de devolucion de la transferencia con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Transferencia recibida en respuesta a un pain.013 con inconvenientes en la devolucion, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Beneficiario: '||fue_obt_nom_persona(v_cod_per_beneficiario_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_beneficiario_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99')))
                                                   || chr(10) ||'Error generado: '||v_nom_respuesta);

                                  end if;

                             exception
                                  when others then
                                     null;
                             end;
                             raise ex_error;
                     else
                               begin

                                  if v_dir_notificaciones is not null then

                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Devolucion de la transferencia con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'La transferencia recibida en respuesta a un pain.013 fue devuelta con exito '
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Beneficiario: '||fue_obt_nom_persona(v_cod_per_beneficiario_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_beneficiario_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99')))
                                                   || chr(10) ||'Motivo de la devolucion: '||v_error
                                                   || chr(10) ||'Ref. devolucion generada: '||v_ref_devolucion);

                                  end if;
                             exception
                                  when others then
                                     null;
                             end;
                      end if; 
                else
                --Controla si debe ingresar por nocturno 
                 lp_ver_horario(3); 
                 if g_es_mov_noc='S' THEN
                   --SPI fase 2
                    if v_msj_respuesta then
                        if r_sol_spi.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_PAGO') then
                            v_par_cargo   :='SPI_CAR_013_ENV';
                            v_par_car_mon :='MTO_MIN_'||v_moneda_008;
                        end if;
                       
                       if  not(fue_obt_des_refcodes(v_par_cargo,'HABILITADO')='S'
                           and v_monto_008>=to_number(fue_obt_des_refcodes(v_par_cargo,v_par_car_mon))) then
                           v_par_cargo:=null;
                       end if;
                    end if;
                     prg_gen_mov_noc_spi(v_monto_008,
                                         pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),pag_gen.fu_obt_mon_local) ,'C'),
                                         v_nro_cta_beneficiario_008,
                                         v_moneda_008,
                                         v_cod_msj_008,
                                         v_cod_tip_operacion_008,
                                         v_cod_sub_tip_operacion_008,
                                         v_nro_ref_008,
                                         p_dat_recibidos.nro_ref_externa,
                                         v_referencia_008,
                                         'R',
                                         'N',
                                         null,
                                         null,
                                         null,
                                         null,
                                         null,
                                         v_cod_respuesta,
                                         v_nom_respuesta,
                                         null,
                                         v_par_cargo); --paso el nombre del dominio para recuperar los datos del cargo a aplicar
                        
                         if v_cod_respuesta <> 0 then
                            mensaje.cod_respuesta := 1;
                            mensaje.nom_respuesta := 'Registro movimiento Nocturno de la operacion con ref.' ||v_nro_ref_008;
                            mensaje.des_Respuesta := 'No se pudo procesar registro de movimiento  ';
                            g_lugar:='Envio de notificacion por error';
                            begin
                                     
                                  if v_dir_notificaciones is not null then
                                    
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de acreditacion con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Transferencia recibida con inconvenientes en acreditacion a la cuenta, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Beneficiario: '||fue_obt_nom_persona(v_cod_per_beneficiario_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_beneficiario_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                            raise ex_error;
                        else
                          --Actualiza la situacion y estado del informe
                           begin
                               --SPI FASE2 Si no es una pacs008 en respuesta a un pain.013
                                if not v_msj_respuesta then
                                   update ge_spi_informes
                                   set estado = 'A', situacion = 'L'
                                   where nro_ref_msj_original = p_dat_recibidos.nro_ref_externa;
                                end if;
                           exception
                                when others then
                                   mensaje.cod_respuesta := 1;
                                   mensaje.nom_respuesta := 'Error al cambiar estado del informe  la operacion con ref.' ||p_dat_recibidos.nro_ref_externa;
                                   mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                                    raise ex_error;
                              END;
                        end if;
                 else
                           -- INICIO DA-4875 -- NGRANCE --
                             g_lugar := 'Actualizar situacion y estado de la operacion con ref.' || p_dat_recibidos.nro_ref_externa;
                             if v_situacion_008 != 'L' or v_estado_008 != 'A' then
                              begin
                                     update ge_snp_transferencias
                                     set estado = 'A', situacion = 'L'
                                     where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                              exception
                                when others then
                                   mensaje.cod_respuesta := 1;
                                   mensaje.nom_respuesta := 'No se pudo procesar la actualizacion de la transferencia';
                                   mensaje.des_Respuesta := substr('Error al liquidar  la operacion con ref.' ||p_dat_recibidos.nro_ref_externa||' '||sqlerrm,1,2000);
                                   raise ex_error;
                              end;  
                             end if;

                             --Actualiza la situacion y estado del informe
                             begin
                                  --SPI FASE2 Si no es una pacs008 en respuesta a un pain.013
                                  if not v_msj_respuesta then
                                     g_lugar := 'Actualizar situacion y estado del informe con ref. original:' || p_dat_recibidos.nro_ref_externa;
                                     update ge_spi_informes
                                     set estado = 'A', situacion = 'L'
                                     where nro_ref_msj_original = p_dat_recibidos.nro_ref_externa;
                                  end if;
                              exception
                                when others then
                                   mensaje.cod_respuesta := 1;
                                   mensaje.nom_respuesta := 'No se pudo procesar la actualizacion del informe';
                                   mensaje.des_Respuesta := substr('Error al cambiar estado del informe  la operacion con ref.' ||p_dat_recibidos.nro_ref_externa||' '||sqlerrm,1,2000);
                                   raise ex_error;
                              end;
                end if;
                --
                if mensaje.cod_respuesta=0 then 
                   --spi fase 2
                    if v_msj_respuesta then

                       update bw_movimientos mv 
                       set mv.dato2=v_nro_ref_008,
                       mv.etiqueta2='Nro. Referencia'
                       where mv.nro_documento=(select  sl.cod_sol_spi
                                               from ge_spi_solicitudes sl
                                               where sl.nro_referencia=v_nro_ref_008)
                       and mv.cod_tip_mensaje='027';

                    end if;
                  --DA-8974
                  v_des_monto:=trim(to_char(v_monto_008,'9,999,999,999,999,990.00'))||' '||v_moneda_008||'.';
                  --SPI Fase 2
                  if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                    v_ent_solicitante:=it.fus_obt_nom_sub_participante(v_swi_pte_solicitante_008,v_swi_suc_solicitante_008);
                  else
                    v_ent_solicitante:=it.fug_obt_nom_snp_participante(v_swi_pte_solicitante_008);
                  end if;

                  begin
                  v_inf_json        := '{' || '"fec_transferencia":' || '"' || to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || --Fecha y hora de Operación
                                              '"ban_cue_beneficiario":' || '"' || v_ent_solicitante || '"' || ',' ||
                                              '"num_cue_debito":' || '"' || v_nro_cta_solicitante_008 || '"' || ',' || 
                                              '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                              '"aviso":' || '"' || 'Transferencia acreditada en cuenta' || '"' || ',' ||
                                              '"notas":' || '"' || v_observacion_008 || '"' || '}';
                   --Insertar correo para el solicitante
                        -- pr_env_alerta(v_cod_per_beneficiario_008,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','RECCLISNP'),v_inf_json); --TCE-249 tipo producto 9
                     exception
                        when others then
                          null;--no realiza accion si da error envio de correo
                     end;
                end if; 
               end if;
             end if;
             if p_dat_recibidos.res_procesamiento = 'RJCT' then
                    g_lugar:='Proceso de pacs.002 RJCT transferencia recibida ';
                    --controla si ya esta marcado con error
                    begin
                      select a.situacion,a.estado
                      into v_situacion_002,v_estado_002
                      from ge_spi_informes a 
                      where a.nro_ref_msj_original=p_dat_recibidos.nro_ref_externa;
                      exception 
                        when no_data_found then
                          null;
                        when others then
                          null;
                    end;
                    if v_situacion_002!='E' and not v_msj_respuesta then --spi fase2

                       if v_situacion_008 != 'C' or v_estado_008 != 'R' then
                         /*
                         || Pago rechazado se recibe  pacs.028/RJCT relacionado al pacs.008
                         */
                         update ge_snp_transferencias
                            set situacion = 'C'
                          where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                       end if;
                       
                       --Actualiza la situacion y estado del informe
                       update ge_spi_informes
                          set estado = 'A', situacion = 'L'
                        where nro_ref_msj_original = p_dat_recibidos.nro_ref_externa;
                    ELSE
                     update ge_snp_transferencias
                            set tip_rechazo=p_dat_recibidos.cod_motivo_rechazo,
                            situacion = 'C',
                            estado='R',
                            error=p_dat_recibidos.mot_rechazo
                          where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                    end if;
              end if;
             end if;
        end if;
        end if;
      --end if;

      /* SPI-10 */ 
      -----------------------------------------------------------
      -- pacs.002: Mensaje de estado- en respuesta de pacs.004 --
      -----------------------------------------------------------
     -- elsif v_tip_msj_ori = g_pac_004 and v_tip_msj_rel is null  then --Verificar este
      if v_tip_msj_ori = g_pac_004 then
        g_lugar:='Proceso de pacs.002 en respuesta de pacs.004';
        --busca el pacs.004 recibido, al que corresponde la confirmación o rechazo
        begin
            select fec_recepcion,
                   cod_msj_swift,
                   nro_referencia,
                   situacion,
                   estado,
                   fecha,
                   hora,
                   cod_usuario,
                   cod_moneda,
                   monto,
                   cod_swi_pte_solicitante,
                   cod_tip_operacion,
                   cod_sub_tip_operacion,
                   nro_cta_beneficiario,
                   nro_cta_solicitante,
                   cod_per_solicitante,
                   nom_beneficiario,
                   fec_insercion,
                   cod_swi_pte_beneficiario,
                   observacion,
                   cod_per_beneficiario,
                   cod_swi_pte_solicitante,
                   cod_swi_suc_solicitante,
                   cod_swi_suc_beneficiario,
                   nom_solicitante,
                   concepto,
                   nro_doc_beneficiario,
                   nro_ref_externa,
                   tip_rechazo
              into v_fec_rec_004,
                   v_cod_msj_004,
                   v_nro_ref_004,
                   v_situacion_004,
                   v_estado_004,
                   v_fecha_004,
                   v_hora_004,
                   v_usuario_004,
                   v_moneda_004,
                   v_monto_004,
                   v_referencia_004,
                   v_cod_tip_operacion_004,
                   v_cod_sub_tip_operacion_004,
                   v_nro_cta_beneficiario_004,
                   v_nro_cta_solicitante_004,
                   v_cod_per_solicitante_004,
                   v_nom_beneficiario_004,
                   v_fec_insercion_004,
                   v_swi_pte_beneficiario_004,
                   v_observacion_004,
                   v_cod_per_beneficiario_004,
                   v_swi_pte_solicitante_004,
                   v_swi_suc_solicitante_004,
                   v_swi_suc_beneficiario_004,
                   v_nom_solicitante_004,
                   v_concepto_004,
                   v_nro_doc_beneficiario_004,
                   v_nro_ref_externa_004,
                   v_tip_rechazo_004
              from ge_snp_transferencias
             where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
           exception
             when no_data_found then
               raise ex_ntransf;
             when others then
               raise ex_ntransf;
           end;
         if v_cod_msj_004 is not null then
          if v_fec_rec_004 is null then--significa transferencia enviada

                 if p_dat_recibidos.res_procesamiento in ( 'ACSP','ACSC') then
                       g_lugar:='Proceso de pacs.002 ACSP devolucion enviada ';
                    g_lugar:='Actualizacion de mensaje MX-ACSP';
                    --------------------------------------------------------
                    -- Respuesta de devolucion aprobada se recibe pacs.002/ACSP --
                    --------------------------------------------------------
                    update ge_snp_transferencias
                       set estado = 'A', situacion = 'L'
                     where nro_ref_externa = p_dat_recibidos.nro_ref_externa;

                     Begin
                     Select t.nro_ref_externa , t.cod_mot_solicitud
                     into  v_ref_solicitud , v_cod_mot_dev
                     from ge_spi_solicitudes t 
                     where t.respuesta like '%'||p_dat_recibidos.nro_ref_externa ; 
                     exception
                       when no_data_found then
                         v_ref_solicitud := null;
                     end;

                     if v_ref_solicitud is not null then--Si es en respuesta a un camt.056
                       update ge_spi_solicitudes
                        set est_solicitud = 'A', sit_solicitud = 'L'
                      where nro_ref_externa = v_ref_solicitud;
                     else    --si fue una devolución directa.
                       update ge_spi_solicitudes
                          set est_solicitud = 'A', sit_solicitud = 'L'
                        where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                     end if;                         
               --si actualiza todo envia notificacion al cliente--

                 if sql%rowcount > 0 then
                  --seccion de notificaciones--
                     begin   
                        v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_per_solicitante_004);  --se identifica que tipo de persona es para el envio de mail
                        if v_tip_persona = 'F' then  --obtenemos el nombre corto en base al tipo de persona
                         v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(v_cod_per_solicitante_004);
                        else
                         v_nombre_saludo := fue_obt_nom_comercial(v_cod_per_solicitante_004);
                        end if; 
                        v_ent_debito:=it.fug_obt_nom_snp_participante(v_swi_pte_solicitante_004); 
                        v_ent_credito:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_004); 
                        v_des_dev    := it.fue_obt_des_refcodes('TIP_REC_SPI_P04',v_cod_mot_dev);

                        v_fec_notificacion:= to_char(v_fec_insercion_004, 'dd/mm/yyyy hh24:mi:ss');

                         --formato nuevo
                             v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                                           -- '"nombre_titulo":' || '"' || v_nom_solicitante_004 || '"' || ',' ||
                                            '"cuenta_debito":' || '"' || v_nro_cta_solicitante_004 || '"' || ',' ||
                                            '"titular_debito":' || '"' || v_nom_solicitante_004 || '"' || ',' ||
                                            '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                                            '"monto":' || '"' || trim(to_char(v_monto_004,'9,999,999,999,999,990.00')) || '"' || ',' ||
                                            '"moneda_debito":' || '"' || v_moneda_004 || '"' || ',' ||
                                            '"nro_operacion":' || '"' || substr(v_concepto_004,6) || '"' || ',' || 
                                            '"fecha_hora":' || '"' || v_fec_notificacion || '"' || ',' ||
                                            '"cuenta_credito":' || '"' || v_nro_cta_beneficiario_004 || '"' || ',' ||
                                            '"titular_credito":' || '"' || v_nom_beneficiario_004 || '"' || ',' ||
                                            '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                                            '"doc_credito":' || '"' || v_nro_doc_beneficiario_004 || '"' || ',' ||
                                            '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                                            '"tipo_operacion":' || '"' || 'Devolución Enviada Exitosamente' || '"' || ',' ||
                                            '"comprobante":' || '"' || v_nro_ref_externa_004 || '"' || '}';

                       if v_tip_persona = 'F' then                               
                          pr_env_alerta(v_cod_per_solicitante_004, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'ENVNOTDEVF'),v_inf_json);
                       else
                          pr_env_alerta(v_cod_per_solicitante_004, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'ENVNOTDEVJ'),v_inf_json);
                       end if;                             
                    end;             
                 end if;
                 --

                 elsif  p_dat_recibidos.res_procesamiento = 'RJCT' then
                     g_lugar:='Actualizacion de mensaje MX-RJCT';

                     v_mot_rechazo := p_dat_recibidos.cod_motivo_rechazo;

                    ---------------------------------------------
                    -- Devolucion rechazada se recibe  pacs.002/RJCT --
                    ---------------------------------------------
                   --Busca movimiento diario
                   begin
                     select distinct nro_documento
                       into v_nro_documento_004
                       from ge_movimientos
                      where fecha = v_fecha_004
                        and hora = v_hora_004
                        and cod_usuario = v_usuario_004
                        and nro_documento = v_nro_ref_004;
                   exception
                     when no_data_found then
                         begin
                           select distinct nro_documento, fecha, hora, cod_usuario
                             into v_nro_documento_noc_004,v_fecha_noc_004,v_hora_noc_004,v_cod_usuario_noc_004
                             from ge_movimientos_noc
                            where cod_usuario = v_usuario_004
                              and nro_documento = v_nro_ref_004;
                         exception
                           when no_data_found then
                             v_nro_documento_noc_004 := null;
                           when others then
                             v_nro_documento_noc_004 := null;
                         end;
                     when others then
                       v_nro_documento := null;
                   end;
                   --Reversion del dia
                   if v_nro_documento_004 is not null then
                     update ge_snp_transferencias
                        set situacion = 'C',
                            estado = 'R',
                            tip_rechazo = v_mot_rechazo,
                            error = p_dat_recibidos.mot_rechazo
                      where nro_ref_externa = p_dat_recibidos.nro_ref_externa;

                      update ge_spi_solicitudes
                        set est_solicitud = 'R', sit_solicitud = 'C'
                      where nro_ref_externa = p_dat_recibidos.nro_ref_externa;

                     g_lugar:='Reversion de la operacion con ref.'||p_dat_recibidos.nro_referencia;
                     g_reversion:='S';
                     --pas_snp.pr_rev_ope_con_swift(v_nro_ref_004,'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI','R');
                     --TRFS-602
                     pas_spi.pr_rev_ope_spi(v_nro_ref_004,'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI','R',p_dat_recibidos.nro_ref_externa,v_fecha_004,v_hora_004,v_usuario_004);
                     g_reversion:='N';
                     if pas_snp.fu_obt_cod_error <> 0 then
                        raise ex_error;
                     end if;
                   end if;
                   --Reversion mov nocturnos
                   if v_nro_documento_noc_004 is not null then
                      v_hor_reverso:=fug_obt_mov_hora;
                        g_lugar:='Reversion de la operacion con ref.'||p_dat_recibidos.nro_ref_externa;
                      begin
                        prg_gen_mov_noc_spi(v_monto_004,
                                            v_nro_cta_solicitante_004,
                                            pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),pag_gen.fu_obt_mon_local) ,'C'),
                                            v_moneda_004,
                                            v_cod_msj_004,
                                            v_cod_tip_operacion_004,
                                            v_cod_sub_tip_operacion_004,
                                            v_nro_ref_004,
                                            p_dat_recibidos.nro_ref_externa,
                                            v_referencia_004,
                                            'E',
                                            'S',
                                            v_fecha_noc_004,
                                            v_hora_noc_004,
                                            v_cod_usuario_noc_004,
                                            user,
                                            v_hor_reverso,
                                            v_cod_respuesta,
                                            v_nom_respuesta);
                        exception
                          when others then
                            rollback;
                            mensaje.cod_respuesta := '1';
                            mensaje.nom_respuesta := 'Error en el proceso de reversion -'||v_nro_ref_004||'-' || sqlerrm;
                            mensaje.des_Respuesta :='No se pudo procesar reversion';
                            raise ex_error;
                        end;
                        if v_cod_respuesta =0 then
                        --Realiza la actualizacion de la transferencia
                         g_lugar:='Actualizacion de mensaje MX-RJCT';
                          update ge_snp_transferencias
                             set situacion   = 'C',
                                 estado      = 'R',
                                 tip_rechazo = v_mot_rechazo,
                                 error       = 'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI'--p_dat_recibidos.mot_rechazo
                           where nro_ref_externa =
                                 p_dat_recibidos.nro_ref_externa;

                            update ge_spi_solicitudes
                               set est_solicitud = 'R', sit_solicitud = 'C'
                             where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                       else
                          g_lugar:='Envio de notificacion por error';
                         begin
                                     begin
                                       select participante
                                         into v_pte_beneficiario
                                         from gv_snp_participantes
                                        where cod_swift = v_swi_pte_beneficiario_004;
                                     exception
                                       when no_data_found then
                                         null;
                                       when others then
                                         null;
                                     end;
                                  if v_dir_notificaciones is not null then

                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de reversion con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Devolucion enviada con inconvenientes en reversion, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_004)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_004
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_004,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                       end if;
                   end if;
                         --Envia notificacion por pacs.002 tipo RJCT rechazado por la contraparte
                       /*if mensaje.cod_respuesta=0 then
                         if v_mot_rechazo='EL201'then
                                if sql%rowcount > 0 then -- circular 007 spi rechazado , Transf. Enviada Rechazada
                                  v_des_monto:=trim(to_char(v_monto_004,'9,999,999,999,999,990.00'))||' '||v_moneda_004||'.';
                                    begin
                                         v_inf_json        := '{' || '"nro_transaccion":' || '"' || p_dat_recibidos.nro_ref_externa || '"' || ',' || -- Nro. de Operación
                                                                     '"fec_transferencia":' || '"' || to_char(v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || --Fecha y hora de Operación
                                                                     '"nom_cue_debito":' || '"' || FUE_OBT_NOM_PERSONA(v_cod_per_solicitante_004) || '"' || ',' || --Cliente Pagador
                                                                     '"num_cue_debito":' || '"' || v_nro_cta_solicitante_004 || '"' || ',' || --Nro. de Cuenta del Pagador
                                                                     '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                                                     '"ban_cue_beneficiario":' || '"' || it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_004) || '"' || ',' || --Entidad Beneficiaria
                                                                     '"nom_beneficiario":' || '"' || v_nom_beneficiario_004 || '"' || ',' || --Cliente Beneficiario
                                                                     '"num_cue_beneficiario":' || '"' || v_nro_cta_beneficiario_004 || '"' || ',' || --Número de cuenta del Cliente Beneficiario
                                                                     '"aviso":' || '"' || 'La Sol. de Devolucion ha sido rechazada por el Participante Beneficiario.' || '"' || '}'; --Texto sugerido
                                          --Insertar correo para el solicitante
                                       pr_env_alerta(v_cod_per_solicitante_004,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTRVSPI'),v_inf_json);
                                   exception
                                      when others then
                                        null;--no realiza accion si da error envio de correo
                                   end;
                                 end if;
                         end if;
                         if v_mot_rechazo='EL202'then
                           -- Envia notificacion por pacs.002 tipo Time out
                           -------------------------------
                           -- Notificaciones al cliente --
                           -------------------------------
                               --Envio de sms
                               begin
                               prg_env_sms_spi(v_cod_per_solicitante_004,g_cod_mad_padre,'GEN_ENV_SMS_TRA_SPI_TO1',v_cod_error,v_men_error);
                               exception
                                  when others then
                                    null;--no realiza accion si da error envio de sms
                               end;
                               --Envio de mail
                               begin
                                   v_aviso:= fug_obt_pardinamico('GEN_ENV_SMS_TRA_SPI_TO1');
                                   v_inf_json:='{' || '"fec_transferencia":' || '"' ||to_char( v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS')|| '"' || ',' ||
                                   '"nom_beneficiario":' || '"' ||v_nom_beneficiario_004|| '"' || ',' ||
                                   '"monto":' || '"' ||ltrim(rtrim(to_char(v_monto_004,'9,999,999,999,999,990.00')))||' '||initcap(v_moneda_004)||'.'||'"' || ',' ||
                                   '"aviso":' || '"' ||v_aviso|| '"' || '}';
                                   --Insertar correo para el solicitante
                                   pr_env_alerta(v_cod_per_solicitante_004,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','ENVNOTRECSPI'),v_inf_json);
                               exception
                                  when others then
                                    null;--no realiza accion si da error envio de correo
                               end;

                               -----------------------------------------
                               -- Notificacion internas a operaciones --
                               -----------------------------------------

                                begin
                                  if v_dir_notificaciones is not null then
                                    begin
                                       select participante
                                         into v_pte_beneficiario
                                         from gv_snp_participantes
                                        where cod_swift = v_swi_pte_beneficiario_004;
                                    exception
                                       when no_data_found then
                                        null;
                                       when others then
                                         null;
                                    end;
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Rechazo de transferencia SPI - RJCT por time out (EL202)'||'.',
                                                   'Transferencia rechazada por time out'
                                                   || chr(10) ||'Nro. Referencia: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_004)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_004
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_004,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                         end if;
                         if v_mot_rechazo='EP183'then--Lack of funds
                               -----------------------------------------
                               -- Notificacion internas a operaciones --
                               -----------------------------------------

                                begin
                                  if v_dir_notificaciones is not null then
                                    begin
                                       select participante
                                         into v_pte_beneficiario
                                         from gv_snp_participantes
                                        where cod_swift = v_swi_pte_beneficiario_004;
                                    exception
                                       when no_data_found then
                                        null;
                                       when others then
                                         null;
                                    end;
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Rechazo de transferencia SPI - RJCT por falta de fondos (EP183)'||'.',
                                                   'Transferencia rechazada por falta de fondos'
                                                   || chr(10) ||'Nro. Referencia: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_004)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_004
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_004,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                         end if;
                       end if;*/
                 end if;
          /*elsif v_fec_rec_004 is not null then--significa transferencia recibida

             if p_dat_recibidos.res_procesamiento in ( 'ACSP','ACSC' ) then
               g_lugar:='Proceso de pacs.002 ACSP Sol. Devolucion recibida ';
                --Controla si debe ingresar por nocturno
                 lp_ver_horario(3);
                 if g_es_mov_noc='S' THEN

                     prg_gen_mov_noc_spi(v_monto_004,
                         pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),pag_gen.fu_obt_mon_local) ,'C'),
                         v_nro_cta_beneficiario_004,
                         v_moneda_004,
                         v_cod_msj_004,
                         v_cod_tip_operacion_004,
                         v_cod_sub_tip_operacion_004,
                         v_nro_ref_004,
                         p_dat_recibidos.nro_ref_externa,
                         v_referencia_004,
                         'R',
                         'N',
                         null,
                         null,
                         null,
                         null,
                         null,
                         v_cod_respuesta,
                         v_nom_respuesta);

                         if v_cod_respuesta <> 0 then
                            mensaje.cod_respuesta := 1;
                            mensaje.nom_respuesta := 'Registro movimiento Nocturno de la operacion con ref.' ||v_nro_ref_004;
                            mensaje.des_Respuesta := 'No se pudo procesar registro de movimiento  ';
                            g_lugar:='Envio de notificacion por error';
                            begin

                                  if v_dir_notificaciones is not null then

                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de acreditacion con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Sol. Devolucion recibida con inconvenientes en acreditacion a la cuenta, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Beneficiario: '||fue_obt_nom_persona(v_cod_per_beneficiario_004)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_beneficiario_004
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_004,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                            raise ex_error;
                        else
                          --Actualiza la situacion y estado del informe
                           begin
                             update ge_spi_solicitudes
                                set est_solicitud = 'A', sit_solicitud = 'L'
                              where nro_ref_msj_original = p_dat_recibidos.nro_ref_externa;
                           exception
                                when others then
                                   mensaje.cod_respuesta := 1;
                                   mensaje.nom_respuesta := 'Error al cambiar estado de la solicitud de devolucion de la operacion con ref.' ||p_dat_recibidos.nro_ref_externa;
                                   mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                                    raise ex_error;
                              END;
                        end if;
                 else
                           -- INICIO DA-4875 -- NGRANCE --
                             g_lugar := 'Actualizar situacion y estado de la operacion con ref.' || p_dat_recibidos.nro_ref_externa;
                             if v_situacion_004 != 'L' or v_estado_004 != 'A' then
                              begin
                                  update ge_snp_transferencias
                                       set estado = 'A', situacion = 'L'
                                     where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                              exception
                                when others then
                                   mensaje.cod_respuesta := 1;
                                   mensaje.nom_respuesta := 'Error al liquidar  la operacion con ref.' ||p_dat_recibidos.nro_ref_externa;
                                   mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                                    raise ex_error;
                              end;
                             end if;

                             --Actualiza la situacion y estado del informe
                             begin
                                  update ge_spi_solicitudes
                                set est_solicitud = 'A', sit_solicitud = 'L'
                              where nro_ref_msj_original = p_dat_recibidos.nro_ref_externa;
                              exception
                                when others then
                                   mensaje.cod_respuesta := 1;
                                   mensaje.nom_respuesta := 'Error al cambiar estado de la Sol. Devolucion de la operacion con ref.' ||p_dat_recibidos.nro_ref_externa;
                                   mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                                    raise ex_error;
                              end;
                end if;
                --
                if mensaje.cod_respuesta=0 then
                  --DA-8974
                  v_des_monto:=trim(to_char(v_monto_004,'9,999,999,999,999,990.00'))||' '||v_moneda_004||'.';
                  --SPI Fase 2
                  if  fu_val_tra_subpte(v_cod_tip_operacion_004,v_cod_sub_tip_operacion_004)  then
                    v_ent_solicitante:=it.fus_obt_nom_sub_participante(v_swi_pte_solicitante_004,v_swi_suc_solicitante_004);
                  else
                    v_ent_solicitante:=it.fug_obt_nom_snp_participante(v_swi_pte_solicitante_004);
                  end if;

                  begin
                  v_inf_json        := '{' || '"fec_transferencia":' || '"' || to_char( v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || --Fecha y hora de Operación
                                              '"ban_cue_beneficiario":' || '"' || v_ent_solicitante || '"' || ',' ||
                                              '"num_cue_debito":' || '"' || v_nro_cta_solicitante_004 || '"' || ',' ||
                                              '"monto":' || '"' ||v_des_monto|| '"' || ',' || --Moneda y Monto
                                              '"aviso":' || '"' || 'Transferencia acreditada en cuenta' || '"' || ',' ||
                                              '"notas":' || '"' || v_observacion_004 || '"' || '}';
                   --Insertar correo para el solicitante
                         pr_env_alerta(v_cod_per_beneficiario_004,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO','RECCLISNP'),v_inf_json);
                     exception
                        when others then
                          null;--no realiza accion si da error envio de correo
                  end;
                end if;
             end if;*/

          end if;
         end if;

      end if;
      /* SPI-10 */
    end if;  
  elsif  v_tip_msj =  g_adm_002 then
       begin
         select fec_recepcion,
                cod_msj_swift,
                nro_referencia,
                situacion,
                estado,
                fecha,
                hora,
                cod_usuario,
                cod_moneda,
                monto,
                cod_swi_pte_solicitante,
                cod_tip_operacion,
                cod_sub_tip_operacion,
                nro_cta_beneficiario,
                nro_cta_solicitante
           into v_fec_rec_008,
                v_cod_msj_008,
                v_nro_ref_008,
                v_situacion_008,
                v_estado_008,
                v_fecha_008,
                v_hora_008,
                v_usuario_008,
                v_moneda_008,
                v_monto_008,
                v_referencia_008,
                v_cod_tip_operacion_008,
                v_cod_sub_tip_operacion_008,
                v_nro_cta_beneficiario_008,
                v_nro_cta_solicitante_008
           from ge_snp_transferencias
          where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
       exception
         when no_data_found then
           --significa informes 
           /*pacs.002/AUTH - Solicitud de autorización de pago
           pacs.002/NAUT - Solicitud de autorización de pago
           camt.011 - Solicitud de límite establecido
           camt.009 - Obtener Límite Actual
           camt.060 - Informe de cuenta
           pacs.018 - Informe de cuenta
           pacs.028 - Solicitud de estado del pago
           camt.033 - Solicitud de copia del pago*/
         
           update ge_spi_informes f
              set f.error = v_error_admi, f.estado = 'C', f.situacion = 'E'
            where f.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
         when others then
           null;
       end;
       if v_nro_ref_008 is not null then
         --significa Solicitud de transferencia(pacs.008)
         -- Se modifica el estado -- E ERROR C CANCELADO
         update ge_snp_transferencias
            set estado      = 'C',
                situacion   = 'E',
                tip_rechazo = p_dat_recibidos.cod_motivo_rechazo,
                error       = v_error_admi
          where nro_ref_externa = p_dat_recibidos.nro_ref_externa;

          -- Se modifica el estado -- E ERROR C CANCELADO de la solicitud cuando es una devolucion normal
            update ge_spi_solicitudes ss 
               set ss.est_solicitud = 'C',
                   ss.sit_solicitud = 'E',
                   ss.respuesta = v_error_admi
             where ss.nro_ref_externa = p_dat_recibidos.nro_ref_externa
             and ss.fec_recepcion is null;
         -- Reversion admi.002
         --Controla si el mov esta reversado
         g_lugar := 'Busca si el movimiento esta reversado, Nro.ref.' ||
                    v_nro_ref_008;
       
         --Busca movimiento diario
         begin
           select distinct nro_documento
             into v_nro_documento
             from ge_movimientos
            where fecha = v_fecha_008
              and hora = v_hora_008
              and cod_usuario = v_usuario_008
              and nro_documento = v_nro_ref_008;
         exception
           when no_data_found then
             --busca en movimiento nocturno
             begin
               select distinct nro_documento, fecha, hora, cod_usuario
                 into v_nro_documento_noc,
                      v_fecha_noc,
                      v_hora_noc,
                      v_cod_usuario_noc
                 from ge_movimientos_noc
                where cod_usuario = v_usuario_008
                  and nro_documento = v_nro_ref_008;
             exception
               when no_data_found then
                 v_nro_documento_noc := null;
               when others then
                 v_nro_documento_noc := null;
             end;
           when others then
             v_nro_documento := null;
         end;
         --Reversion del dia
         if v_nro_documento is not null then
           update ge_snp_transferencias
              set tip_rechazo = p_dat_recibidos.cod_motivo_rechazo
            where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
           g_lugar := 'Reversion de la operacion con ref.' ||
                      p_dat_recibidos.nro_referencia;
          /* pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,
                                        'Rev.pacs.008' || '-' ||
                                        p_dat_recibidos.nro_referencia ||
                                        ' - SPI');*/
            --TRFS-602
           pas_spi.pr_rev_ope_spi(v_nro_ref_008,'Rev.pacs.008' || '-' ||
                                        p_dat_recibidos.nro_referencia ||
                                        ' - SPI','R',p_dat_recibidos.nro_ref_externa,v_fecha_008,v_hora_008,v_usuario_008);
                    
           if pas_spi.fu_obt_cod_error <> 0 then
             raise ex_error;
           end if;
         end if;
         --Reversion mov nocturnos
         if v_nro_documento_noc is not null then
           v_hor_reverso := fug_obt_mov_hora;
           g_lugar       := 'Reversion de la operacion con ref.' ||
                            p_dat_recibidos.nro_ref_externa;
           begin
		     prs_snp_obt_usu_hor_movimiento(user,'S',v_usu_reversion,v_hor_reverso);
             prg_gen_mov_noc_spi(v_monto_008,
                                 v_nro_cta_solicitante_008,
                                 pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),
                                                                                                 pag_gen.fu_obt_mon_local),
                                                             'C'),
                                 v_moneda_008,
                                 v_cod_msj_008,
                                 v_cod_tip_operacion_008,
                                 v_cod_sub_tip_operacion_008,
                                 v_nro_ref_008,
                                 p_dat_recibidos.nro_ref_externa,
                                 v_referencia_008,
                                 'E',
                                 'S',
                                 v_fecha_noc,
                                 v_hora_noc,
                                 v_cod_usuario_noc,
                                 v_usu_reversion,
                                 v_hor_reverso,
                                 v_cod_respuesta,
                                 v_nom_respuesta);
           exception
             when others then
               rollback;
               mensaje.cod_respuesta := '1';
               mensaje.nom_respuesta := 'Error en el proceso de reversion -' ||
                                        v_nro_ref_008 || '-' || sqlerrm;
               mensaje.des_Respuesta := 'No se pudo procesar reversion';
               raise ex_error;
           end;
           if v_cod_respuesta = 0 then
             --Realiza la actualizacion de la transferencia
             g_lugar := 'Actualizacion de mensaje MX-RJCT';
             update ge_snp_transferencias
                set error = 'Rev.pacs.008' || '-' ||
                            p_dat_recibidos.nro_referencia || ' - SPI'
              where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
           else
                             g_lugar:='Envio de notificacion por error';
                             begin
                                  if v_dir_notificaciones is not null then
                                    
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de reversion con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Transferencia con inconvenientes en reversion, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Nro.Cuenta Solicitante: ' ||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Nro.Cuenta Beneficiario: '||v_nro_cta_beneficiario_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
           end if;
         end if;
         --por un pacs.004 enviado por un camt.056 recibido y aprobado , se recibe un admin por error de formato , se vuelve a ddisponibilizar el registro para su autorizacion
         update ge_spi_solicitudes ss
            set ss.est_solicitud = 'S', ss.sit_solicitud = 'R'  , ss.respuesta = null
          where ss.nro_referencia = v_nro_ref_008
            and ss.fec_recepcion is not null;

         g_lugar:='Envio de notificacion por error en la Devolución';
                             begin
                                  if v_dir_notificaciones is not null then
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error interno al enviar una Devolución: '||p_dat_recibidos.nro_ref_externa,
                                                   'Devolución con inconvenientes, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_dat_recibidos.nro_ref_externa
                                                   || chr(10) ||'Nro.Cuenta Solicitante: ' ||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Nro.Cuenta Beneficiario: '||v_nro_cta_beneficiario_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;  
         --
       else
         --Actualizo Solicitudes Varias (camt.056, pain.013 pain.001) 
         -- Se modifica el estado -- E ERROR C CANCELADO de la solicitud
            update ge_spi_solicitudes ss 
               set ss.est_solicitud = 'C',
                   ss.sit_solicitud = 'E',
                   ss.respuesta = ss.respuesta||chr(10)||v_error_admi
             where ss.nro_ref_externa = p_dat_recibidos.nro_ref_externa;          
             --SPI fase2
               begin
                       select sl.*
                       into r_sol_enviada
                       from ge_spi_solicitudes sl
                       where sl.nro_ref_externa=p_dat_recibidos.nro_ref_externa;

                       if r_sol_enviada.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_PAGO') then
                          v_titulo:='Solicitud de pago rechazada por BCP';
                       elsif r_sol_enviada.cod_msj_swift= fug_obt_pardinamico('COD_SPI_SOL_DEV') then
                          v_titulo:='Rechazo de solicitud de devolucion de transferencia';
                       else
                          v_titulo:='Solicitud rechazada';
                       end if;

                       if v_dir_rec_admi_002 is not null then

                          if  r_sol_enviada.cod_swi_suc_beneficiario is not null  then
                              v_pte_beneficiario:=it.fus_obt_nom_sub_participante(r_sol_enviada.cod_swi_beneficiario,r_sol_enviada.cod_swi_suc_beneficiario);
                          else
                              v_pte_beneficiario:=it.fug_obt_nom_snp_participante(r_sol_enviada.cod_swi_beneficiario);
                          end if;

                           it_mail.mail( fug_obt_dir_correo,
                                        v_dir_rec_admi_002,
                                        v_titulo||' '||r_sol_enviada.cod_sol_spi,
                                          'La solicitud enviada, fue rechazada, favor verificar'
                                          || chr(10) ||'Nro. Referencia externa: '||r_sol_enviada.nro_ref_externa
                                          || chr(10) ||'Solicitante: '||fue_obt_nom_persona(fue_obt_cod_persona_doc(r_sol_enviada.tip_doc_solicitante,r_sol_enviada.doc_solicitante))
                                          || chr(10) ||'Nro.Cuenta: '||r_sol_enviada.cta_solicitante
                                          || chr(10) ||'Fecha envio: '||r_sol_enviada.fec_insercion
                                          || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                          || chr(10) ||'Monto: '||ltrim(rtrim(to_char(r_sol_enviada.monto,'999,999,999,999,999.99')))||' '||r_sol_enviada.cod_moneda);

                       end if;
                exception
                        when others then
                           null;
                end;
       end if;
   elsif ((v_tip_msj = g_pai_014 and v_tip_msj_ori = g_pai_013)
         or(v_tip_msj = g_pai_002 and v_tip_msj_ori = g_pai_001))  then

             if p_dat_recibidos.res_procesamiento='ACSP' then

                update ge_spi_solicitudes sll
                set sll.sit_solicitud='L',
                sll.est_solicitud='A'
                where sll.nro_ref_externa=p_dat_recibidos.nro_ref_externa
                and sll.est_solicitud!='R'
                and sll.sit_solicitud!='C'; 

             elsif p_dat_recibidos.res_procesamiento='RJCT' then
                  --busco el pain.013 recibido y no contestado
                   g_lugar:='Buscar solicitud relacionada';

                   begin
                        select *
                        into r_sol_recibida
                        from ge_spi_solicitudes sll
                        where sll.nro_ref_externa=p_dat_recibidos.nro_ref_externa;
                   exception
                        when no_data_found then 
                            pas_spi.g_cod_error:=52;
                            pas_spi.g_msj_error:='No se encuentra la solicitud con ref. externa: '||p_dat_recibidos.nro_ref_externa;
                            raise ex_notificar;
                   end;

                   begin
                        if p_dat_recibidos.mot_rechazo is null then

                            if v_tip_msj_ori = g_pai_013 then
                                v_dominio :='TIP_REC_SPI_P14';
                            elsif v_tip_msj_ori = g_pai_001 then
                                  v_dominio :='TIP_REC_SPI_P01';
                            end if;

                            select cc.abreviatura
                            into v_des_rechazo
                            from ba_cod_referencias cc 
                            where cc.dominio=v_dominio
                            and cc.val_minimo=p_dat_recibidos.cod_motivo_rechazo;
                        else 
                            v_des_rechazo:=p_dat_recibidos.mot_rechazo;
                        end if;

                   exception
                        when others then
                             null;
                   end;

                   if r_sol_recibida.fec_recepcion is not null
                      and r_sol_recibida.sit_solicitud='R'
                      and r_sol_recibida.est_solicitud='A' then
                      begin
                         if r_sol_recibida.nro_referencia is not null then --generó el pacs008
                           g_lugar:='Cancela WF';
                           prg_cre_savepoint('rev');

                           pas_snp.pr_ini_registros;

                           if pas_snp.fu_ver_workflow(r_sol_recibida.nro_referencia) then
                              pas_snp.pr_can_workflow(r_sol_recibida.nro_referencia);
                           end if;

                           if pas_snp.fu_obt_cod_error<>0 then
                                prg_rol_savepoint('rev');
                                pas_spi.g_cod_error:=pas_snp.g_cod_error;
                                pas_spi.g_msj_error:=pas_snp.g_msj_error;
                                raise ex_notificar;
                           end if;

                           pas_snp.pr_ini_registros;
                           g_lugar:='Buscar transferencia pacs008';
                           pas_snp.pr_obt_mensaje(r_sol_recibida.nro_referencia,'N');
                           r_gtran := pas_snp.fu_obt_reg_transferencias;

                           if pas_snp.fu_obt_cod_error<>0 then
                                pas_spi.g_cod_error:=pas_snp.g_cod_error;
                                pas_spi.g_msj_error:=pas_snp.g_msj_error;
                                raise ex_notificar;
                           end if;

                           g_lugar:='Buscar mov. relacionado';
                           begin
                                 select distinct 'D'
                                 into  v_tip_mov
                                 from ge_movimientos md
                                 where md.fecha=r_gtran.fecha
                                 and md.hora=r_gtran.hora
                                 and md.cod_usuario=r_gtran.cod_usuario
                                 and md.nro_documento=r_gtran.nro_referencia
                                 union
                                 select distinct 'N' 
                                 from ge_movimientos_noc md
                                 where md.fecha=r_gtran.fecha
                                 and md.hora=r_gtran.hora
                                 and md.cod_usuario=r_gtran.cod_usuario
                                 and md.nro_documento=r_gtran.nro_referencia;

                           exception
                                 when no_data_found then 
                                       pas_spi.g_cod_error:=53;
                                       pas_spi.g_msj_error:='No se encuentra la transferencia con ref. n° '||r_gtran.nro_referencia;
                                       raise ex_notificar;
                           end;
                           lp_ver_horario(3);
                           g_lugar:='Obtener estado del modulo';
                           if g_mod_estado in (1,6) then
                              prg_rol_savepoint('rev');
                              pas_spi.g_cod_error:=50;
                              pas_spi.g_msj_error:='Entidad en proceso de cierre';
                              raise ex_notificar;
                           end if;

                           if v_tip_mov='D' then --mov original generado en el día
                              g_lugar:='Reversar transferencia del dia';
                              --pas_snp.pr_ini_registros;
                              --pas_snp.pr_rev_ope_con_swift(r_gtran.nro_referencia,'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI','R');
                              --TRFS-602
                              pas_spi.pr_ini_registros;
                              pas_spi.pr_rev_ope_spi(r_gtran.nro_referencia,'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI','R',r_gtran.nro_ref_externa,r_gtran.fecha,r_gtran.hora,r_gtran.cod_usuario);
                    
                              if pas_spi.fu_obt_cod_error <> 0 then
                                 prg_rol_savepoint('rev');
                                 --pas_spi.g_cod_error:=pas_snp.g_cod_error;
                                 --pas_spi.g_msj_error:=pas_snp.g_msj_error;
                                 raise ex_notificar;
                              end if;

                           else
                               v_hor_reverso:=fug_obt_mov_hora;
                               g_lugar:='Reversar transferencia nocturna';
                               prg_gen_mov_noc_spi(r_gtran.monto,
                                                   r_gtran.nro_cta_solicitante,
                                                   pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),pag_gen.fu_obt_mon_local) ,'C'),
                                                   r_gtran.cod_moneda,
                                                   r_gtran.cod_msj_swift,
                                                   r_gtran.cod_tip_operacion,
                                                   r_gtran.cod_sub_tip_operacion,
                                                   r_gtran.nro_referencia,
                                                   r_gtran.nro_ref_externa,
                                                   r_gtran.cod_swi_pte_solicitante,
                                                   'E',
                                                   'S',
                                                   r_gtran.fecha,
                                                   r_gtran.hora,
                                                   r_gtran.cod_usuario,
                                                   user,
                                                   v_hor_reverso,
                                                   v_cod_respuesta,
                                                   v_nom_respuesta); 

                               if v_cod_respuesta!=0 then
                                   prg_rol_savepoint('rev');
                                   pas_spi.g_cod_error:=51;
                                   pas_spi.g_msj_error:=v_nom_respuesta;
                                   raise ex_notificar;
                               end if; 
                           end if;
                           update ge_snp_transferencias
                           set situacion= 'C',
                           estado      = 'R',
                           tip_rechazo = p_dat_recibidos.cod_motivo_rechazo,
                           error       = 'Rev.'|| v_tip_msj_ori || '-' ||p_dat_recibidos.nro_referencia ||' - SPI'--p_dat_recibidos.mot_rechazo
                           where nro_referencia=r_gtran.nro_referencia; 
                           begin
                                --notificar rechazos por time-out
                                v_cod_persona:=fue_obt_cod_persona_doc(r_sol_recibida.tip_doc_beneficiario,r_sol_recibida.doc_beneficiario);
                                v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona); 

                                if v_tip_msj_ori = g_pai_013 then
                                   if v_tip_persona='F' then
                                      pr_not_sol_pago('RECSOLPAGTOFI',r_sol_recibida);
                                   elsif v_cod_persona='J' then
                                      pr_not_sol_pago('RECSOLPAGTOJU',r_sol_recibida);
                                   end if; 
                                elsif  v_tip_msj_ori = g_pai_001 then
                                   if v_tip_persona='F' then
                                      pr_not_sol_pago('RECSOLINITOFI',r_sol_recibida);
                                   elsif v_cod_persona='J' then
                                      pr_not_sol_pago('RECSOLINITOJU',r_sol_recibida);
                                   end if; 
                                end if; 

                           exception
                               when others then 
                                   null;
                           end; 
                        end if;
                      exception
                         when ex_notificar then
                                  begin
                                       if v_dir_notificaciones is not null then

                                         if  r_gtran.cod_swi_suc_beneficiario is not null  then
                                             v_pte_beneficiario:=it.fus_obt_nom_sub_participante(r_gtran.cod_swi_pte_beneficiario,r_gtran.cod_swi_suc_beneficiario);
                                         else
                                             if v_tip_msj_ori = g_pai_001 then
                                                 rg_omp:=fu_obt_dat_omp(r_sol_recibida.uetr);
                                                 v_pte_beneficiario:=rg_omp.descripcion;
                                             else
                                                 v_pte_beneficiario:=it.fug_obt_nom_snp_participante(r_gtran.cod_swi_pte_beneficiario);
                                             end if;
                                         end if;

                                          it_mail.mail( fug_obt_dir_correo,
                                                        v_dir_notificaciones,
                                                        'Error en proceso de reversion con ref.externa: '||r_gtran.nro_ref_externa,
                                                        'Transferencia generada en respuesta a un '||v_tip_msj_ori||' con inconvenientes en la reversion, favor verificar'
                                                        || chr(10) ||'Nro. Referencia externa: '||r_gtran.nro_referencia
                                                        || chr(10) ||'Solicitante: '||fue_obt_nom_persona(r_gtran.cod_per_solicitante)
                                                        || chr(10) ||'Nro.Cuenta: '||r_gtran.nro_cta_solicitante
                                                        || chr(10) ||'Fecha Ingreso: '||r_gtran.fec_insercion
                                                        || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                        || chr(10) ||'Monto: '||ltrim(rtrim(to_char(r_gtran.monto,'999,999,999,999,999.99')))||' '||r_gtran.cod_moneda);

                                       end if;
                                   exception
                                      when others then
                                        null;
                                   end;
                                   raise ex_error;
                      end;
                      update ge_spi_solicitudes sll
                      set sll.sit_solicitud='C',
                      sll.est_solicitud='R',
                      sll.tip_rechazo=p_dat_recibidos.cod_motivo_rechazo,
                      sll.respuesta=trim(substr(sll.respuesta||' '||v_des_rechazo,1,2000))
                      where sll.cod_sol_spi=r_sol_recibida.cod_sol_spi
                      and sll.est_solicitud!='R'
                      and sll.sit_solicitud!='C'; 

                   else
                      --enviado

                      update ge_spi_solicitudes sll
                      set sll.sit_solicitud='C',
                      sll.est_solicitud='R',
                      sll.tip_rechazo=p_dat_recibidos.cod_motivo_rechazo,
                      sll.respuesta=trim(substr(sll.respuesta||' '||v_des_rechazo,1,2000))
                      where sll.cod_sol_spi=r_sol_recibida.cod_sol_spi
                      and sll.est_solicitud!='R'
                      and sll.sit_solicitud!='C'; 
                      --notificacion
                      begin
                          if v_tip_msj_ori = g_pai_013 then
                             if r_sol_recibida.fec_recepcion is not null then
                                v_cod_persona:=fue_obt_cod_persona_doc(r_sol_recibida.tip_doc_beneficiario,r_sol_recibida.doc_beneficiario);
                                v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
                                if v_tip_persona='F' then
                                   pr_not_sol_pago('RECSOLPAGTOFI',r_sol_recibida);
                                elsif v_cod_persona='J' then
                                   pr_not_sol_pago('RECSOLPAGTOJU',r_sol_recibida);
                                end if; 
                             else --la parte receptora no responde o rechaza
                               v_cod_persona:=fue_obt_cod_persona_doc(r_sol_recibida.tip_doc_solicitante,r_sol_recibida.doc_solicitante);
                               v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
                               if p_dat_recibidos.cod_motivo_rechazo=c_cod_rechazo then
                                  pr_not_sol_pago('ENVSOLPAGRECTO',r_sol_recibida);
                               else
                                  pr_not_sol_pago('ENVSOLPAGREC',r_sol_recibida,p_dat_recibidos.cod_motivo_rechazo);
                               end if;
                             end if;
                          elsif  v_tip_msj_ori = g_pai_001 then
                                 --se recibió, no se respondió y dio time-out
                                 v_cod_persona:=fue_obt_cod_persona_doc(r_sol_recibida.tip_doc_beneficiario,r_sol_recibida.doc_beneficiario);
                                 v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
                                 if r_sol_recibida.fec_recepcion is not null then
                                    if p_dat_recibidos.cod_motivo_rechazo=c_cod_rechazo then
                                       if v_tip_persona='F' then
                                           pr_not_sol_pago('RECSOLINITOFI',r_sol_recibida);
                                       elsif v_cod_persona='J' then
                                           pr_not_sol_pago('RECSOLINITOJU',r_sol_recibida);
                                       end if;
                                    else
                                       if v_tip_persona='J' then
                                          pr_not_sol_pago('RECSOLINIRECJU',r_sol_recibida,p_dat_recibidos.cod_motivo_rechazo);
                                       elsif v_tip_persona='F' then
                                          pr_not_sol_pago('RECSOLINIRECFI',r_sol_recibida,p_dat_recibidos.cod_motivo_rechazo);
                                       end if;
                                    end if;
                                 end if;
                          end if;
                      exception
                         when others then
                             null;
                      end;
                      --fin notificar
                   end if;
            end if;
   elsif  v_tip_msj =  g_adm_004 then       -- JFF
      v_email          :=    IT.FUG_OBT_DIR_CORREO; -- Ver SPI_MAI_NOTIFICACIONES
            BEGIN
              if v_dir_rec_admi_004 is not null then
                 it_mail.mail( v_email,
                               v_dir_rec_admi_004,
                               'NOTIFICACION SPI',
                               'Nro de referencia externa: '||p_dat_recibidos.nro_referencia||chr(10)||
                               'Código de error: '||p_dat_recibidos.cod_motivo_rechazo||' '||p_dat_recibidos.mot_rechazo||chr(10)
                               
                              );
              end if;
            EXCEPTION
              when others then
                 -- Error intentando enviar la notificación para SPI_MAI_NOTIFICACIONES
                 NULL;
            END;
   elsif  v_tip_msj =  g_cam_025 then  
     if v_tip_msj_ori in (g_pai_014,g_pai_002) then
         if p_dat_recibidos.cod_estado='OK' then
             --pain014 o pain002 enviado
             update ge_spi_solicitudes sll
             set sll.sit_solicitud='C',
             sll.est_solicitud='R'
             where sll.nro_ref_externa=p_dat_recibidos.nro_ref_externa;
             --pain013 o pain001 respondido

             select p1.*
             into  r_sol_recibida
             from ge_spi_solicitudes p1
             where p1.cod_sol_spi=(select sol.nro_referencia
                                    from ge_spi_solicitudes sol
                                    where sol.nro_ref_externa=p_dat_recibidos.nro_ref_externa);
             --ver revisar
             update ge_spi_solicitudes sll
             set sll.sit_solicitud='C',
             sll.est_solicitud='R'
             where sll.cod_sol_spi=r_sol_recibida.cod_sol_spi;
             --notificación
             if v_tip_msj_ori=g_pai_002 then
                begin
                  v_cod_persona := fue_obt_cod_persona_doc(r_sol_recibida.tip_doc_beneficiario, r_sol_recibida.doc_beneficiario);
                  v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
                  if v_tip_persona='J' then
                     pr_not_sol_pago('RECSOLINIRECJU',r_sol_recibida,r_sol_recibida.tip_rechazo);
                  elsif v_tip_persona='F' then
                     pr_not_sol_pago('RECSOLINIRECFI',r_sol_recibida,r_sol_recibida.tip_rechazo);
                  end if;
                exception
                   when others then
                       null;
                end;
             end if;
         end if;
     else
          --DA-6505 actualizamos situacion = C y estado = R
           update ge_spi_informes f
           set f.estado = 'R', f.situacion = 'C'
           where f.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
            --            
           v_cod_msj_mx  := null;
           begin
              select nro_ref_msj_original, cod_msj_mx
              into v_nro_ref_msj_original, v_cod_msj_mx -- agregado cod_msj_mx
              from ge_spi_informes
              where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
           exception--agrego para que pueda procesar solicitudes
              when no_data_found then
                   null;   
           end;
           -- Para ver si es un camt.056
           begin
              select sol.cod_sol_spi , sol.cod_msj_swift
              into v_cod_sol_spi, v_cod_msj_sol -- agregado cod_msj_mx
              from ge_spi_solicitudes sol
              where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
           exception
              when no_data_found then
                   null;   
           end;
                 --DA-5975  pacs.002 RJCT time out
           if v_cod_msj_mx = g_pac_002 and v_nro_ref_msj_original is not null then
               update ge_snp_transferencias
               set situacion = 'C', estado = 'R',tip_rechazo=p_dat_recibidos.cod_motivo_rechazo,
               error=p_dat_recibidos.mot_rechazo
               where nro_ref_externa = v_nro_ref_msj_original;
           end if;
            --DA-5975
           if v_tip_msj_ori <> g_cam_011 then      
              -- JFF actualizamos situación = E y estado = C.
                 update ge_spi_informes f
                 set f.error = v_error_admi, -- error de motivo de rechazo
                 f.estado='C', f.situacion='E'
                 where f.nro_ref_externa =  p_dat_recibidos.nro_ref_externa;
           elsif v_cod_msj_mx = g_pac_028 or v_cod_msj_mx = g_cam_033 then --se agrega para actualizar 028 y 033
                 update ge_spi_informes f
                 set f.error     = v_error_admi, 
                 f.estado    = 'C',
                 f.situacion = 'E'
                 where f.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                --Agrego para controlar camt.025 por solicitudes
           elsif v_cod_sol_spi  is not null then
                 update ge_spi_solicitudes f
                 set f.respuesta      = f.respuesta ||chr(10)|| v_error_admi, 
                 f.est_solicitud  = 'C',
                 f.sit_solicitud  = 'E'
                 where f.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                 -- Enviar la notificación a la dirección de correo definida en el parámetro dinámico SPI_MAI_RECHAZO_LIM
                 BEGIN
                    if v_dir_rec_lim_correo is not null then
                       it_mail.mail( fug_obt_dir_correo,
                                    v_dir_rec_lim_correo,
                                   'RECHAZO DE SOLICITUD DE DEVOLUCION DE TRANSFERENCIA '/*|| nvl(fug_obt_pardinamico('SPI_PORC_LIMITE'), 0) */||'.',
                                   'La solicitud de Devolucion de Transferencia fue rechazada, verifique los datos y vuelva a enviar otra solicitud.'
                                   || chr(10) ||'Nro. de referencia externa: '||p_dat_recibidos.nro_ref_externa||' '|| v_error_admi
                                   );
                   end if;
                 EXCEPTION
                   when others then
                     -- Error intentando enviar la notificación por el porcentaje mínimo superado
                     NULL;
                 END;  
            else
                 begin
                   select f.error
                    into v_error_camt_025
                    from  ge_snp_mensajes f
                    where f.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
                 exception
                    when others then 
                        v_error_camt_025 := null;
                 end;  
                 -- Enviar la notificación a la dirección de correo definida en el parámetro dinámico SPI_MAI_RECHAZO_LIM
                 BEGIN
                     if v_dir_rec_lim_correo is not null then
                        it_mail.mail( fug_obt_dir_correo,
                                     v_dir_rec_lim_correo,
                                     'RECHAZO DE SOLICITUD PARA ESTABLECER LIMITE DE CUENTA '/*|| nvl(fug_obt_pardinamico('SPI_PORC_LIMITE'), 0) */||'.',
                                     'La solicitud de Limite de cuenta fue rechazada, verifique los datos y vuelva a enviar la solicitud.'
                                     || chr(10) ||'Nro. de referencia externa: '||p_dat_recibidos.nro_ref_externa||' '|| v_error_camt_025
                                     );
                     end if;
                  EXCEPTION
                     when others then
                        -- Error intentando enviar la notificación por el porcentaje mínimo superado
                        NULL;
                  END;
            end if; 
     end if;

   elsif  v_tip_msj =  g_cam_052 then   
   --Ajuste para insertar datos del camt.052 en la tabla ge_spi_inf_cuenta
    BEGIN
        g_lugar := 'Inserta en ge_spi_inf_cuenta';
        INSERT INTO ge_spi_inf_cuenta
          (nro_referencia,
           fec_informe,
           nro_ref_externa,
           nro_cta_informe,
           imp_saldo_cta,
           cant_tot_op_sesion,
           mon_tot_op_sesion,
           mon_res_deb_cre,
           cant_liq_credito,
           mon_liq_credito,
           cant_liq_debito,
           mon_liq_debito,
           id_sesion,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion)
        VALUES
          (p_dat_recibidos.nro_referencia,
           p_dat_recibidos.fec_informe,
           p_dat_recibidos.nro_ref_externa,
           p_dat_recibidos.nro_cta_informe,
           p_dat_recibidos.imp_saldo_cta,
           p_dat_recibidos.cant_tot_op_sesion,
           p_dat_recibidos.mon_tot_op_sesion,
           p_dat_recibidos.mon_res_deb_cre,
           p_dat_recibidos.cant_liq_credito,
           p_dat_recibidos.mon_liq_credito,
           p_dat_recibidos.cant_liq_debito,
           p_dat_recibidos.mon_liq_debito,
           p_dat_recibidos.id_sesion,
           user,
           sysdate,
           user,
           sysdate);
      EXCEPTION
        when others then
          PAS_SPI.g_cod_error := 1001;
          PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
          mensaje.cod_respuesta := 1;
          mensaje.nom_respuesta := 'Error en: '||g_lugar;
          mensaje.des_Respuesta:=sqlerrm;
      END;
   --         
      
      If v_tip_msj_ori = g_cam_060 then      
          update ge_spi_informes
             set estado = 'A', situacion = 'L'
           where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
      end if;   
   elsif  v_tip_msj =  g_cam_034 then            
      
          update ge_spi_informes r
             set r.estado = 'A', r.situacion = 'L'
           where r.nro_ref_msj_original = p_dat_recibidos.nro_ref_externa
             and r.cod_msj_mx = g_cam_033
             and r.fecha=trunc(sysdate)
             and r.estado='W'
             and r.situacion='V'
             and r.fec_insercion =
                 (select min(a.fec_insercion)
                    from ge_spi_informes a
                   where a.nro_ref_msj_original =
                         p_dat_recibidos.nro_ref_externa
                     and a.cod_msj_mx = g_cam_033
                     and a.fecha=trunc(sysdate)
                     and a.estado='W'
                     and a.situacion='V');

    elsif  v_tip_msj =  g_cam_019 then        
                       update ge_spi_informes r
                         set r.estado = 'A', r.situacion = 'L'
                       where r.nro_ref_externa = p_dat_recibidos.nro_ref_externa
                         and r.cod_msj_mx = g_cam_018
                         and r.fecha=trunc(sysdate)
                         and r.estado='W'
                         and r.situacion='V'
                         and r.fec_insercion =
                             (select min(a.fec_insercion)
                                from ge_spi_informes a
                               where a.nro_ref_externa =p_dat_recibidos.nro_ref_externa
                                 and a.cod_msj_mx = g_cam_018
                                 and a.estado='W'
                                 and a.fecha=trunc(sysdate)
                                 and a.situacion='V');

   --Agrego para controlar camt.029 MGF 25/05/2023
   elsif  v_tip_msj = g_cam_029 and v_tip_msj_ori = g_cam_056 then
    --TRFS-1166
      if v_cod_acept_rechazo = 'RJCR' then
       update ge_spi_solicitudes f
            set f.respuesta      = f.respuesta ||chr(10)|| v_error_admi, 
                f.sit_solicitud  = 'C',
                f.est_solicitud  = 'R'
          where f.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
   --se busca la referencia del pago original
       begin
         select s.nro_ref_msj_original , s.cod_mot_solicitud
           into v_nro_ref_original, v_cod_mot_dev
           from ge_spi_solicitudes s 
          where s.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
          exception
         when others then
           null;
       end;

     begin
       select s.*
         into r_pag_original
         from ge_snp_transferencias s
        where s.nro_ref_externa = v_nro_ref_original;
     exception
       when no_data_found then
         null;
         return;
     end;

     BEGIN
                  --se identifica que tipo de persona es para el envio de mail
           v_tip_persona := pas_spi.fu_obt_tip_persona(r_pag_original.cod_per_solicitante);
          --obtenemos el nombre corto en base al tipo de persona
          if v_tip_persona = 'F' then
             v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(r_pag_original.cod_per_solicitante);
          else
             v_nombre_saludo := fue_obt_nom_comercial(r_pag_original.cod_per_solicitante);
          end if; 
          v_ent_debito:=it.fug_obt_nom_snp_participante(r_pag_original.cod_swi_pte_beneficiario); 
          v_ent_credito:=it.fug_obt_nom_snp_participante(r_pag_original.cod_swi_pte_solicitante);
          v_des_dev := it.fue_obt_des_refcodes('TIP_REC_SOL_DEV',p_dat_recibidos.cod_motivo_rechazo);
          v_fec_notificacion:= to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss');
               --formato nuevo
               v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                              '"nombre_titulo":' || '"' || r_pag_original.nom_beneficiario|| '"' || ',' ||
                              '"cuenta_debito":' || '"' || r_pag_original.nro_cta_beneficiario || '"' || ',' ||
                              '"titular_debito":' || '"' || r_pag_original.nom_beneficiario || '"' || ',' ||
                              '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                              '"monto":' || '"' || trim(to_char(r_pag_original.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                              '"moneda_debito":' || '"' || r_pag_original.cod_moneda || '"' || ',' ||
                              '"nro_operacion":' || '"' || r_pag_original.nro_ref_externa || '"' || ',' ||
                              '"fecha_hora":' || '"' || v_fec_notificacion || '"' || ',' ||
                              '"cuenta_credito":' || '"' || r_pag_original.nro_cta_solicitante || '"' || ',' ||
                              '"titular_credito":' || '"' || r_pag_original.nom_solicitante || '"' || ',' ||
                              '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                              '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                              '"tipo_operacion":' || '"' || 'Rechazo de Solicitud de Devolución Enviada' || '"' || ',' ||
                              '"comprobante":' || '"' || r_pag_original.nro_ref_externa || '"' || ',' ||
                              '"doc_debito":' || '"' || r_pag_original.nro_doc_beneficiario || '"' || '}';

                if v_tip_persona = 'F' then                               
                   pr_env_alerta(r_pag_original.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECREC029F'),v_inf_json);
                else
                   pr_env_alerta(r_pag_original.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECREC029J'),v_inf_json);
               end if;                 

                EXCEPTION
                  when others then
                     -- Error intentando enviar la notificación
                     NULL;
                END;
      end if;          
   end if;

 -- INICIO DA-4811 -- NGRANCE --
 --camt.010: Confirmación de nuevo límite.
   if v_tip_msj = g_cam_010 then
      /*
      || Inserción del nuevo límite.
      */
      --pre_cam_for_numerico('.,');
      r_spi_lim.nro_referencia := p_dat_recibidos.nro_referencia;
      r_spi_lim.nro_ref_externa := p_dat_recibidos.nro_ref_externa;
      r_spi_lim.can_lim_establecido := p_dat_recibidos.can_lim_establecido;
      r_spi_lim.can_lim_utilizada := p_dat_recibidos.can_lim_utilizada;
      r_spi_lim.por_lim_utilizado := p_dat_recibidos.por_lim_utilizado;

 --antes del insert verificamos que el camt.010 NO sea respuesta sobre la cuenta reserva para no realizar el insert 
 --de una solicitud camt.009
  /* begin
     select 'S'
       into v_existe
       from ge_spi_informes s
      where s.cod_msj_mx = 'camt.009'
        and s.nro_ref_externa = r_spi_lim.nro_ref_externa
        and s.nro_cta_solicitante = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR');
    exception
      when no_data_found then
        v_existe := 'N';
   end;*/
 --
 /*--validamos por la cuenta para realizar el insert en ge_spi_limites  
   if p_dat_recibidos.nro_cta_informe = fug_obt_pardinamico('TRANSF_CTA_RES_LBTR') then
     v_existe := 'S';
   elsif p_dat_recibidos.nro_cta_informe = fug_obt_pardinamico('TRANSF_CTA_SPI_LIQ') then
     v_existe := 'N';
   end if;*/ --DA-6734
 --
 -- 
 --if v_existe = 'N' then  
      BEGIN
        g_lugar := 'Inserta en ge_spi_limites';
        INSERT INTO ge_spi_limites
          (nro_referencia,
           nro_ref_externa,
           can_lim_establecido,
           can_lim_utilizada,
           por_lim_utilizado,
           nro_cta_informe,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion)
        VALUES
          (r_spi_lim.nro_referencia,
           r_spi_lim.nro_ref_externa,
           r_spi_lim.can_lim_establecido,
           r_spi_lim.can_lim_utilizada,
           r_spi_lim.por_lim_utilizado,
           p_dat_recibidos.nro_cta_informe,
           user,
           sysdate,
           user,
           sysdate);
      EXCEPTION
        when others then
          PAS_SPI.g_cod_error := 100;
          PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
          mensaje.cod_respuesta := 1;
          mensaje.nom_respuesta := 'Error en: '||g_lugar;
          mensaje.des_Respuesta:=sqlerrm;
      END;
 -- end if;
      --
      --
      -- Validar el porcentaje que se recibe, comparando con el definido en el parámetro SPI_PORC_LIMITE
      if r_spi_lim.por_lim_utilizado is not NULL then
         if r_spi_lim.por_lim_utilizado >= nvl(fug_obt_pardinamico('SPI_PORC_LIMITE'), 0) then
            -- Enviar la notificación a la dirección de correo definida en el parámetro dinámico SPI_MAI_RECHAZO_LIM
            BEGIN
              if v_dir_rec_lim_correo is not null then
                 g_lugar := 'Se intenta enviar la notificación referente al Límite.';
                 it_mail.mail( fug_obt_dir_correo,
                               v_dir_rec_lim_correo,
                               'PORCENTAJE REAL DE LIMITE DE CUENTA SUPERIOR AL '|| nvl(fug_obt_pardinamico('SPI_PORC_LIMITE'), 0) ||' %.',
                               'El porcentaje real de Limite utilizado es superior al porcentaje de notificación establecido, verifique Monto Límite restante.'|| chr(10) ||
                               'Monto Límite utilizado: '||r_spi_lim.can_lim_utilizada||'.' || chr(10) ||
                               'Monto Límite establecido: '||r_spi_lim.can_lim_establecido||'.' || chr(10) ||
                               'Porcentaje de Límite recibido: '||r_spi_lim.por_lim_utilizado||' %.' || chr(10) ||
                               'Cuenta Informe: '||p_dat_recibidos.nro_cta_informe||'.' --DA-6735
                               || chr(10) || chr(10) || chr(10) ||
                               'Atentamente.'
                              );
              end if;
            EXCEPTION
              when others then
                 -- Error intentando enviar la notificación por el porcentaje mínimo superado
                 --NULL; 
                 PAS_SPI.g_cod_error := 100;
                 PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
                 mensaje.cod_respuesta := 1;
                 mensaje.nom_respuesta := 'Error en: '||g_lugar;
                 mensaje.des_Respuesta:=sqlerrm;                
            END;
         end if;
      end if;
      --Actualiza la situacion y estado del informe
      update ge_spi_informes
         set estado = 'A', situacion = 'L'
       where nro_ref_externa = p_dat_recibidos.nro_ref_externa;
   end if;
   -- FIN DA-4811 -- NGRANCE --
  end if;
   if  pas_spi.g_cod_error <> 0 then
       update ge_snp_mensajes set error = pas_spi.g_msj_error where nro_referencia = p_dat_recibidos.nro_referencia and nro_ref_externa =p_dat_recibidos.nro_ref_externa;
   end if;
   --registrando log
   pas_snp.pr_reg_operacion( v_msj_mx , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
   
   p_dat_mensaje         := mensaje;
EXCEPTION
  when ex_salir then
       mensaje.cod_respuesta := 1;
       mensaje.nom_respuesta := 'pr_pro_msj_recibidos-'||g_lugar;
       mensaje.des_Respuesta:=sqlerrm;
       g_lugar := 'Nro de ref. externa ya existe! '||p_dat_recibidos.nro_ref_externa;
       pas_snp.pr_reg_operacion( p_dat_recibidos.msj_mx , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
       p_dat_mensaje         := mensaje;
  when ex_error then
    PAS_SPI.g_cod_error := 60;
    PAS_SPI.g_msj_error := substr(g_lugar||'-'||nvl(PAS_SPI.g_msj_error,mensaje.des_Respuesta),1,2000);
    update ge_snp_mensajes set error = pas_spi.g_msj_error
    where nro_referencia = p_dat_recibidos.nro_referencia and nro_ref_externa =p_dat_recibidos.nro_ref_externa;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'pr_pro_msj_recibidos-'||g_lugar;
    mensaje.des_Respuesta := PAS_SPI.g_msj_error;
       --registrando log
   g_lugar := 'Ocurrio algun error en pr_pro_msj_recibidos ';
   pas_snp.pr_reg_operacion( v_msj_mx , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    
    p_dat_mensaje         := mensaje;
  when ex_ntransf then
    pas_spi.g_cod_error := 61;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'pr_pro_msj_recibidos-'||g_lugar;
    mensaje.des_Respuesta :=sqlerrm;
       --registrando log
   pas_snp.pr_reg_operacion( v_msj_mx , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    
    p_dat_mensaje         := mensaje;
  WHEN others THEN
    pas_spi.g_cod_error := 62;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    update ge_snp_mensajes set error = pas_spi.g_msj_error where nro_referencia = p_dat_recibidos.nro_referencia and nro_ref_externa =p_dat_recibidos.nro_ref_externa;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'pr_pro_msj_recibidos-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    --registrando log
    g_lugar := 'Error durante en pr_pro_msj_recibidos';
    pas_snp.pr_reg_operacion( v_msj_mx , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    
    p_dat_mensaje         := mensaje;
END pr_pro_msj_recibidos;
procedure pr_reg_msj_generico( p_dat_recibidos in  typ_Obtdatmsjrespuesta,
                              p_ind_msj_recibido in varchar2 default 'S',
                              p_env_mail         in varchar2 default 'S')is

  /*
  || Regisra mensaje recibo por el SPI, en la tabla ge_snp_mensajes.
  */
   v_nro_referencia   ge_snp_mensajes.nro_referencia%type;
   v_nro_ref_externa  ge_snp_mensajes.nro_ref_externa%type;
   v_txt_mail         varchar2(4000);
   v_asunto           varchar2(4000);
   v_cod_msj_mx ge_spi_cab_versiones.tipo_msj%type;
   v_codigo   ge_snp_mensajes.cod_msj_swift%type;
   v_fecha date;
   v_monto ge_snp_mensajes.monto%type;
   v_cod_moneda ge_snp_mensajes.cod_moneda%type;
   v_msj_mx  ge_snp_mensajes.msj_swift%type;



begin
      g_lugar:='Asigna valores Nro referencia';
      v_nro_referencia   :=p_dat_recibidos.nro_referencia ;
      g_lugar:='Asigna valores Nro referencia externa';
      v_nro_ref_externa  :=p_dat_recibidos.nro_ref_externa;
      g_lugar:='Obtiene codigo de mensaje en base a version recibida'|| p_dat_recibidos.cod_msj_mx;
      v_cod_msj_mx :=PAS_SPI.fu_tip_msj_ver(p_dat_recibidos.cod_msj_mx);
      begin
      select to_number(t.val_minimo)
        into v_codigo
        from ba_cod_referencias t
       where dominio = 'COD_MSJ_SWIFT'
         and t.abreviatura = v_cod_msj_mx;
      exception
        when no_data_found then 
             pas_spi.g_cod_error := 110;
             pas_spi.g_msj_error := 'No se encuentra codigo de mensaje para version: '|| p_dat_recibidos.cod_msj_mx ||'!';
        raise ex_error;
        when others then
             pas_spi.g_cod_error := 120;
             pas_spi.g_msj_error := 'Error al recuperar codigo de mensaje para version'||p_dat_recibidos.cod_msj_mx ||'!';
        raise ex_error;
        end;
      v_fecha:=p_dat_recibidos.fec_valor;
      v_msj_mx:=p_dat_recibidos.msj_mx;
      v_cod_moneda:=CASE p_dat_recibidos.cod_moneda WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE g_cod_mon_local END;
      v_monto:=p_dat_recibidos.monto;

   begin
      g_lugar:='Insercion de mensaje en ge_snp_mensajes';
        insert into ge_snp_mensajes( cod_msj_swift,
                                     nro_referencia,
                                     nro_ref_externa,
                                     fec_valor,
                                     msj_swift,
                                     monto,
                                     cod_moneda,
                                     fec_recepcion,
                                     situacion
                                   )
                             values( v_codigo,
                                     v_nro_referencia,
                                     v_nro_ref_externa,
                                     trunc(v_fecha),
                                     v_msj_mx,
                                     v_monto,
                                     v_cod_moneda,
                                     case when p_ind_msj_recibido = 'S' then sysdate else NULL end,
                                     case when p_ind_msj_recibido = 'S' then 'R' else 'P' end
                                   );
   exception
      when dup_val_on_index then
        pas_spi.g_cod_error := 140;
        pas_spi.g_msj_error := 'Ya existen registros en GE_SNP_MENSAJES para el número de Ref.Externa '|| v_nro_ref_externa ||'!';
        raise ex_error;
      when others then
         pas_spi.g_cod_error := 160;
         pas_spi.g_msj_error := 'Error al insertar el mensaje en GE_SNP_MENSAJES: '||sqlerrm;
        raise ex_error;
   end;

EXCEPTION
         
   when ex_error then
    pas_spi.g_cod_error := 170;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    pas_snp.pr_reg_operacion( p_dat_recibidos.cod_msj_mx , g_lugar|| '|' ||pas_spi.g_cod_error|| '|'  || pas_spi.g_msj_error ); 
   when others then
    pas_spi.g_cod_error := 180;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    pas_snp.pr_reg_operacion( p_dat_recibidos.cod_msj_mx , g_lugar|| '|' ||pas_spi.g_cod_error|| '|'  || pas_spi.g_msj_error ); 
end pr_reg_msj_generico;
 procedure pr_pro_msj_rec_008(p_dat_recibidos in  typ_ObtTransrecibido008,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa transferencia RECIBIDA por el SPI, de tipo pacs.008(Mensaje de pago de Crédito Directo)
  */
  ex_salir EXCEPTION;
  ex_error EXCEPTION;
  rg_msj_rec            PAS_SPI.rg_msj := null;
  rg_dat_pte            pas_snp.rg_pte := null;
  --v_nom_respuesta       varchar2(2000):='Proceso realizado correctamente';--Respuesta corta a arrojar en el campo nom_respuesta de type typ_mensajeria_spi(out)
  v_cod_moneda          varchar2(3)    := null;
  v_sql                 varchar2(4000) := null;
  v_tip_doc             varchar2(5)    := null;
  v_cod_msj_mx          ge_spi_cab_versiones.tipo_msj%type;
  v_codigo              ge_snp_mensajes.cod_msj_swift%type;
  v_nro_cuenta          ge_cuentas.nro_cuenta%type;
  v_cod_tip_doc_ben     ge_snp_transferencias.cod_tip_doc_beneficiario%type;
  v_ind_instruccion     ge_snp_transferencias.nro_lote%type;
  v_nro_cta_participante ge_snp_transferencias.nro_cta_solicitante%type:=pas_spi.fu_obt_cta_ban_participante( PAS_SNP.fu_obt_cod_swi_participante(fug_obt_per_entidad),g_cod_mon_local );
  mensaje               typ_mensajeria_spi := typ_mensajeria_spi(0,'OK',null);
  v_existe_ref          varchar2(1):='N'; -- Control Duplicado
 -- Retorno de verificación de operaciones
  v_est_cuenta        ge_cuentas.estado%type;    -- Estado Cta.
  v_sal_disponible    ge_movimientos.monto%type; -- Sal.Dispon.
  v_procesa           varchar2(1) := 'N';
  v_cod_modulo        ge_snp_transferencias.cod_modulo%type;
  v_cod_modalidad     ge_snp_transferencias.cod_modalidad%type;
  v_supera_limite      varchar2(1):='N';
  v_sub_participante   boolean;
  v_cod_swift          ge_spi_solicitudes.cod_msj_swift%type;
  v_responder          boolean:=false;
BEGIN
   begin
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
   end;
   
  begin
      pas_spi.g_cod_error := 0;
      pas_spi.g_msj_error := NULL;
      g_tip_rch           := NULL;
      v_sub_participante  := false;
      g_nom_respuesta:='Proceso realizado correctamente';--Respuesta corta a arrojar en el campo nom_respuesta de type typ_mensajeria_spi(out)
      pas_spi.pr_ini_registros;
      g_lugar:='Registro de parametros en log';
   --Registro de parametros 
         pas_snp.pr_reg_operacion('Tipo mensaje recibido: Pacs.008'|| chr(10) ||
         ' Parametros: Nro_ref_externa: '||p_dat_recibidos.nro_ref_externa|| chr(10) || 
         ' Cod_msj_mx: '||p_dat_recibidos.cod_msj_mx|| chr(10) || 
         ' Fecha: '||p_dat_recibidos.fecha|| chr(10) || 
         ' Hora: '||p_dat_recibidos.hora|| chr(10) ||
         ' Moneda: '||p_dat_recibidos.moneda|| chr(10) || 
         ' Monto: '||p_dat_recibidos.monto|| chr(10) || 
         ' Fecha valor: '||p_dat_recibidos.fec_valor|| chr(10) || 
         ' Nombre solicitante: '||p_dat_recibidos.nom_solicitante|| chr(10) || 
         ' Tipo doc solicitante: '||p_dat_recibidos.tip_doc_solicitante|| chr(10) || 
         ' Documento solicitante: '||p_dat_recibidos.doc_solicitante|| chr(10) || 
         ' Cuenta solicitante: '||p_dat_recibidos.cta_solicitante|| chr(10) || 
         ' Swift pte solicitante: '||p_dat_recibidos.swi_participante_sol|| chr(10) || 
         ' Cuenta pte solicitante: '||p_dat_recibidos.cta_participante_sol|| chr(10) ||
         ' Swift pte beneficiario: '||p_dat_recibidos.swi_participante_ben|| chr(10) || 
         ' Swift sub. solicitante: '||p_dat_recibidos.swi_sub_pte_solicitante|| chr(10) ||
         ' Cuenta sub. solicitante: '||p_dat_recibidos.cta_sub_pte_solicitante|| chr(10) ||
         ' Cuenta pte beneficiario: '||p_dat_recibidos.cta_participante_ben|| chr(10) || 
         ' Nombre beneficiario: '||p_dat_recibidos.nom_beneficiario|| chr(10) || 
         ' Tipo doc beneficiario: '||p_dat_recibidos.tip_doc_beneficiario|| chr(10) || 
         ' Documento beneficiario: '||p_dat_recibidos.doc_beneficiario|| chr(10) || 
         ' Cuenta beneficiario: '||p_dat_recibidos.cta_beneficiario|| chr(10) || 
         ' Concepto: '||p_dat_recibidos.concepto|| chr(10) || 
         ' Codigo transaccion: '||p_dat_recibidos.cod_transaccion|| chr(10) || 
         ' Observacion: '||p_dat_recibidos.observacion|| chr(10) || 
         ' Ref. Solicitud: '||p_dat_recibidos.nro_ref_solicitud|| chr(10) ||
         ' Ind. Instruccion: '||p_dat_recibidos.ind_instruccion
         , g_lugar||' Nro ref. externa: '||p_dat_recibidos.nro_ref_externa); 
      --DA-7726-control del estado del módulo 3 en 1 o 6
      g_lugar :=  'Valida estado del modulo';
      lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
         if g_tip_rch is null then    
            pas_spi.g_cod_error := 185;
            g_nom_respuesta := 'La cuenta no permite el proceso';
            pas_spi.g_msj_error := g_nom_respuesta; 
            g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
         end if;
      end if;
      g_lugar:='Obteniendo parametro de Nro referencia externa';
      if p_dat_recibidos.nro_ref_externa is null then
         pas_spi.g_cod_error := 161;
         g_nom_respuesta := 'El valor Nro. Ref. Externa no puede ser nulo.!';
         pas_spi.g_msj_error := g_nom_respuesta;
       else
         rg_msj_rec.nro_ref_externa:=p_dat_recibidos.nro_ref_externa;
       end if;
        g_lugar :=  'Obteniendo parametro Fecha';
        if p_dat_recibidos.fecha is null then
          pas_spi.g_cod_error := 162;
          g_nom_respuesta := 'El valor fecha no puede ser nulo.!';
          pas_spi.g_msj_error := g_nom_respuesta;
        else
            rg_msj_rec.fec_recepcion := p_dat_recibidos.fecha;
        end if;
        g_lugar :=  'Obteniendo parametro Fecha valor';
        if p_dat_recibidos.fec_valor is null then
         pas_spi.g_cod_error := 163;
         g_nom_respuesta := 'El valor fecha valor no puede ser nulo.!';
         pas_spi.g_msj_error := g_nom_respuesta;
        else
         rg_msj_rec.fec_valor     := p_dat_recibidos.fec_valor;
         rg_msj_rec.fec_ingreso   := p_dat_recibidos.fec_valor;
        end if;

        g_lugar :=  'Verifica si hay duplicacion de la transferencia recibida';
         if nvl(fug_obt_pardinamico('SPI_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
          if PAS_SPI.fu_ver_msj_duplicados ( p_dat_recibidos.nro_ref_externa, rg_msj_rec.fec_valor ) = 'S' then
            pas_spi.g_cod_error := 165;
            g_nom_respuesta := 'Transferencia mx existente para la Ref. Externa '||p_dat_recibidos.nro_ref_externa;
            pas_spi.g_msj_error := g_nom_respuesta;
          end if;
         end if;
         g_lugar :=  'Obteniendo parametro Moneda: ';
         if p_dat_recibidos.moneda is null then
             if g_tip_rch is null then
                 pas_spi.g_cod_error := 166;
                 g_nom_respuesta:='La divisa de cuenta ausente';
                 pas_spi.g_msj_error := g_nom_respuesta;
                 g_tip_rch:=g_rch_ac09;
           end if;
         else
             v_cod_moneda := p_dat_recibidos.moneda;
             v_cod_moneda := CASE v_cod_moneda WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE v_cod_moneda END;
             rg_msj_rec.cod_moneda := v_cod_moneda;
             v_sql := 'SELECT ''S'' '||
                      'FROM   BA_MONEDAS '||
                      'WHERE  COD_MONEDA = '||''''||rg_msj_rec.cod_moneda||'''';
             if not fu_val_dat_ingresado(v_sql) then
               g_lugar :=  'Obteniendo parametro Moneda: 1';
                 pas_spi.g_cod_error := 166;
                 g_nom_respuesta := 'El valor de Moneda no es correcto -'||p_dat_recibidos.moneda;
                 pas_spi.g_msj_error := g_nom_respuesta;
             end if;
         end if;
         g_lugar :=  'Obteniendo parametro Monto: ';
         rg_msj_rec.monto :=p_dat_recibidos.monto ;
         if rg_msj_rec.monto is null then
              pas_spi.g_cod_error:= 167;
              g_nom_respuesta := 'El campo Monto no puede ser nulo.';
              pas_spi.g_msj_error := g_nom_respuesta;
         end if;

         g_lugar :=  'Validando swift del Participante Solicitante, ';
         rg_msj_rec.cod_swi_pte_solicitante :=p_dat_recibidos.swi_participante_sol;
     if rg_msj_rec.cod_moneda is not null then
       if p_dat_recibidos.swi_participante_sol is null then
              pas_spi.g_cod_error := 168;
              g_nom_respuesta := 'El campo swift del participante solicitante no puede ser nulo.';
              pas_spi.g_msj_error := g_nom_respuesta;

       else --Busca con el swift recibido el BIC configurado en ITGF
         pr_val_cod_swi_participante( rg_msj_rec.cod_swi_pte_solicitante );--ver
         if pas_spi.fu_obt_cod_error <> 0 and g_tip_rch is null then
              pas_spi.g_cod_error := 169;
              g_nom_respuesta :='Error al buscar swift del participante solicitante';
              pas_spi.g_msj_error := g_nom_respuesta;
         else
           -- Obtiene datos del Participante Solicitante en caso que el BIC no tenga errores
           g_lugar :=  'Obteniendo Datos del Participante Solicitante,  ';
           pas_snp.pr_obt_dat_participante( rg_msj_rec.cod_swi_pte_solicitante,--ver
                                            rg_dat_pte);
           if pas_snp.fu_obt_cod_error <> 0 then
              pas_spi.g_cod_error := 170;
              g_nom_respuesta := 'Error al buscar swift del participante solicitante ' || rg_msj_rec.cod_swi_pte_solicitante;
              pas_spi.g_msj_error := g_nom_respuesta;
           end if;
          end if;
        end if;
    end if;
     --Validacion del codifo swift y cuenta del subparticipante SPI FASE 2
     begin
          select re.val_minimo,re.val_maximo
          into  rg_msj_rec.cod_tip_operacion,rg_msj_rec.cod_sub_tip_operacion
          from ba_cod_referencias re
          where re.dominio='TIP_OPE_SUBPTE'
          and re.val_minimo=p_dat_recibidos.cod_transaccion
          and re.abreviatura='pacs.008';
          v_sub_participante:=true;
     exception
          when no_data_found then
               v_sub_participante:=false;
     end; 
     if g_tip_rch is null and v_sub_participante then
           if p_dat_recibidos.swi_sub_pte_solicitante is null then
              pas_spi.g_cod_error := 198;
              g_nom_respuesta     := 'El campo relacionado al BIC del Participante Sucursal Solicitante no puede ser nulo';
              pas_spi.g_msj_error := g_nom_respuesta;
              g_tip_rch           := g_rch_dt02;
           else
              rg_msj_rec.cod_swi_suc_solicitante:=p_dat_recibidos.swi_sub_pte_solicitante;
              pr_val_cod_swi_participante(rg_msj_rec.cod_swi_suc_solicitante);

              if pas_spi.fu_obt_cod_error <> 0 then
                 g_nom_respuesta := 'Error al validar el codigo swift del sub-participante ';
                 g_tip_rch       := g_rch_dt02;
              end if;
           end if;

           if g_tip_rch is null then
              if p_dat_recibidos.cta_sub_pte_solicitante is null then
                 pas_spi.g_cod_error := 199;
                 g_nom_respuesta     := 'El campo relacionado a la Cta. del Participante Sucursal Solicitante no puede ser nulo';
                 pas_spi.g_msj_error := g_nom_respuesta;
                 g_tip_rch           := g_rch_dt02;
              else
                  rg_msj_rec.nro_cta_suc_pte_solicitante:=p_dat_recibidos.cta_sub_pte_solicitante;

                  if pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante ) is null then

                     pas_spi.g_cod_error := 200;
                     g_nom_respuesta     := 'No se encuentran datos para la Cta. del Participante Sucursal Solicitante '||rg_msj_rec.nro_cta_suc_pte_solicitante;
                     pas_spi.g_msj_error := g_nom_respuesta;
                     g_tip_rch           := g_rch_dt02;   

                  elsif pas_snp.fu_val_cta_ban_participante( rg_msj_rec.cod_swi_suc_solicitante,
                                                           CASE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante )
                                                           WHEN g_cod_mon_iso_local THEN
                                                                g_cod_mon_local
                                                           ELSE pas_snp.fu_obt_mon_cta_participante( rg_msj_rec.nro_cta_suc_pte_solicitante )
                                                           END,
                                                           rg_msj_rec.nro_cta_suc_pte_solicitante) = 'N' then
                      pas_spi.g_cod_error := 201;
                      g_nom_respuesta     := 'No se pudo validar el cod. swift y la cuenta del subparticipante';
                      pas_spi.g_msj_error := g_nom_respuesta;
                      g_tip_rch           := g_rch_dt02;
                  end if;
               end if;
           end if;
     end if;
     if not v_sub_participante 
        and (p_dat_recibidos.swi_sub_pte_solicitante is not null or p_dat_recibidos.cta_sub_pte_solicitante is not null) 
        and g_tip_rch is null then
         pas_spi.g_cod_error := 202;
         g_nom_respuesta     := 'Tipo de mensajeria no corresponde para transf. a sub-participantes';
         pas_spi.g_msj_error := g_nom_respuesta;
         g_tip_rch           := g_rch_dt02;    
     end if;
     --DA-7726-control del estado del módulo 3 en 1 o 6
     lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
         if g_tip_rch is null then    
            pas_spi.g_cod_error := 185;
            g_nom_respuesta := 'La cuenta no permite el proceso';
            pas_spi.g_msj_error := g_nom_respuesta; 
            g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
         end if;
      end if;
      g_lugar :=  'Validando Cta. del Participante Solicitante,  ';
      rg_msj_rec.nro_cta_pte_solicitante:=p_dat_recibidos.cta_participante_sol;
      if rg_msj_rec.cod_moneda is not null then
     if rg_msj_rec.nro_cta_pte_solicitante is null then
         pas_spi.g_cod_error := 171;
         g_nom_respuesta := 'El valor relacionado a la Cta. del Participante Solicitante no puede ser nulo';
         pas_spi.g_msj_error := g_nom_respuesta;
     else --Valida que la cuenta y el BIC del PTE. SOLICITANTE existan en ITGF
        if fu_val_cta_ban_participante( rg_msj_rec.cod_swi_pte_solicitante,
                                                rg_msj_rec.cod_moneda,
                                                rg_msj_rec.nro_cta_pte_solicitante
                                              ) = 'N'
        then
        
         g_nom_respuesta := pas_spi.fu_obt_msj_error;
         
         if g_tip_rch is null then
            pas_spi.g_cod_error := 172;
            g_nom_respuesta := 'No coincide moneda transferencia con moneda de cta';
            pas_spi.g_msj_error := g_nom_respuesta;
            g_tip_rch:=g_rch_ac09;--AC09 - La divisa de cuenta es incorrecta o ausente
         end if;
        end if;
     end if;
    end if;
    ---
    /**/-- :57a: Cuenta y BIC del participante destino,
     g_lugar :=  'Obteniendo Datos del Participante Beneficiario. ';

     rg_msj_rec.nro_cta_pte_beneficiario := p_dat_recibidos.cta_participante_ben;
     if rg_msj_rec.nro_cta_pte_beneficiario is null then
         pas_spi.g_cod_error := 173;
         g_nom_respuesta := 'El valor relacionado a la Cta. del Participante beneficiario no puede ser nulo';
         pas_spi.g_msj_error := g_nom_respuesta;
     end if;
     g_lugar :=  'Obteniendo, BIC Participante Beneficiario. ';
     rg_msj_rec.cod_swi_pte_beneficiario := p_dat_recibidos.swi_participante_ben;
     if rg_msj_rec.cod_swi_pte_beneficiario is null then
         pas_spi.g_cod_error := 174;
         g_nom_respuesta := 'El valor relacionado al BIC Participante Beneficiario no puede ser nulo';
         pas_spi.g_msj_error := g_nom_respuesta;

     else --Valida que el BIC exista en ITGF
      pr_val_cod_swi_participante( rg_msj_rec.cod_swi_pte_beneficiario );
      if pas_spi.fu_obt_cod_error <> 0 and g_tip_rch is null then
         pas_spi.g_cod_error := pas_spi.fu_obt_cod_error;
         g_nom_respuesta :=pas_spi.fu_obt_msj_error;
      end if;
     end if;
     --end if;
     --DA-7726-control del estado del módulo 3 en 1 o 6
      lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
         if g_tip_rch is null then    
            pas_spi.g_cod_error := 185;
            g_nom_respuesta := 'La cuenta no permite el proceso';
            pas_spi.g_msj_error := g_nom_respuesta; 
            g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
         end if;
      end if;
     -- NGRANCE --
     g_lugar :=  ' Obteniendo valor, Indicador de Instrucción.';
     rg_msj_rec.nro_lote := p_dat_recibidos.ind_instruccion;
     -------------
     g_lugar :=  'Validando Cta. del Participante Beneficiario, ';
     if rg_msj_rec.nro_cta_pte_beneficiario is null then

         pas_spi.g_cod_error := 176;
         g_nom_respuesta := 'El campo relacionado a la Cta. Participante Beneficiario no puede ser nulo.';
         pas_spi.g_msj_error := g_nom_respuesta;
     else --Valida que la cuenta del PTE. BENEFICIARIO exista en ITGF
        if rg_msj_rec.nro_cta_pte_beneficiario <> nvl(pas_spi.fu_obt_cta_bancaria( pas_spi.fu_obt_cta_bancaria( rg_msj_rec.nro_cta_pte_beneficiario, 'C' ), 'B' ),0) then--ver
          if pas_spi.fu_obt_cod_error <> 0  and g_tip_rch is null then
           pas_spi.g_cod_error := pas_spi.fu_obt_cod_error;
           g_nom_respuesta :=pas_spi.fu_obt_msj_error;
          end if;
         pas_spi.g_cod_error := 177;
         g_nom_respuesta := 'El campo relacionado a la Cta. Participante Beneficiario no coincide con el parametrizado para la moneda ' || rg_msj_rec.cod_moneda;
         pas_spi.g_msj_error := g_nom_respuesta;
        end if;
        
     end if;
     g_lugar :=  'Validando Cta. del Cliente Solicitante';
     rg_msj_rec.nro_cta_solicitante := p_dat_recibidos.cta_solicitante;
     if  rg_msj_rec.nro_cta_solicitante is null then
        pas_spi.g_cod_error := 179;
        g_nom_respuesta:='El valor relacionado a la Cta. Cliente Solicitante no puede ser nulo.!';
        pas_spi.g_msj_error := g_nom_respuesta;
     end if;
     g_lugar :=  'Validando tipo documento del Cliente Solicitante';
     --rg_msj_rec.cod_tip_doc_solicitante := p_dat_recibidos.tip_doc_solicitante;
     v_tip_doc:= p_dat_recibidos.tip_doc_solicitante;
     if  v_tip_doc is null then
        pas_spi.g_cod_error  := 180;
        g_nom_respuesta:='El valor relacionado al tipo de documento del solicitante no puede ser nulo.!';
        pas_spi.g_msj_error := g_nom_respuesta;
     end if;
     begin
       -- Recupera el Cod. Tip. Documento, cualquier error retorna el código para RUC
       begin
         if fue_val_es_numerico(fue_obt_tip_documento(v_tip_doc)) = 'S' then

           rg_msj_rec.cod_tip_doc_solicitante := fue_obt_tip_documento(v_tip_doc);
         else
           -- Registra el tipo de documento como RUC en caso de no encontrar en ITGF
           raise ex_salir;
           null;
         end if;
       exception
         when ex_salir then
           raise;
         when others then
           raise;
       end;
     exception
       when others then
        rg_msj_rec.cod_tip_doc_solicitante := fue_obt_tip_documento('RUC');

     end;
     --DA-7726-control del estado del módulo 3 en 1 o 6
      lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
         if g_tip_rch is null then    
            pas_spi.g_cod_error := 185;
            g_nom_respuesta := 'La cuenta no permite el proceso';
            pas_spi.g_msj_error := g_nom_respuesta; 
            g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
         end if;
      end if;
      g_lugar :=  'Validando Nro documento del Cliente Solicitante';
      rg_msj_rec.nro_doc_solicitante := p_dat_recibidos.doc_solicitante;
     if  rg_msj_rec.nro_doc_solicitante is null then
         pas_spi.g_cod_error  := 181;
         g_nom_respuesta:='El valor relacionado al Nro documento del Cliente Solicitante no puede ser nulo.!';
         pas_spi.g_msj_error := g_nom_respuesta;
     end if;
     g_lugar :=  'Obteniendo valor, Nombre Cli. Solicitante';
     rg_msj_rec.nom_solicitante := p_dat_recibidos.nom_solicitante;
     g_lugar :=  'Obteniendo valor, Dir. Solicitante. ';
     rg_msj_rec.dir_solicitante := null;
     rg_msj_rec.cod_oficina:= fug_obt_ofi_usuario (user);

     /**/-- :59: Datos del Beneficiario
     g_lugar :=  'Obteniendo valor, Cta. Cli. Beneficiario';
     rg_msj_rec.nro_cta_beneficiario := p_dat_recibidos.cta_beneficiario;
     if  rg_msj_rec.nro_cta_beneficiario is null then
         if g_tip_rch is null then
             pas_spi.g_cod_error := 182;
             g_nom_respuesta:='El campo relacionado a la Cta. Cliente Beneficiario no puede ser nulo.!';
             pas_spi.g_msj_error := g_nom_respuesta;
             g_tip_rch:=g_rch_ac01;--El codigo de cuenta es invalido o ausente
         end if;
     end if;
     g_lugar :=  'Validando tipo documento del Beneficiario';
     v_tip_doc := null;
     v_tip_doc := nvl(p_dat_recibidos.tip_doc_beneficiario, 'RUC' );
        begin -- Recupera el Cod. Tip. Documento, cualquier error retorna el código para RUC
          begin
             if fue_val_es_numerico( fue_obt_tip_documento( v_tip_doc ) ) = 'S' then
                rg_msj_rec.cod_tip_doc_beneficiario := fue_obt_tip_documento( v_tip_doc );
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
        end;

        if rg_msj_rec.cod_tip_doc_beneficiario is null then
           if g_tip_rch is null then
           pas_spi.g_cod_error := 183;
           g_nom_respuesta:=' No se ha encontrado el Tipo de Documento del Beneficiario';
           pas_spi.g_msj_error := g_nom_respuesta;
           g_tip_rch:=g_rch_ac01;--AC01 - El codigo de cuenta es invalido o ausente
           end if;
        end if;
        rg_msj_rec.nro_doc_beneficiario:=p_dat_recibidos.doc_beneficiario;
        if rg_msj_rec.nro_doc_beneficiario is null then
           if g_tip_rch is null then
             pas_spi.g_cod_error := 184;
             g_nom_respuesta:='No se ha encontrado el Nro. Documento del Beneficiario.!';
             pas_spi.g_msj_error := g_nom_respuesta;
             g_tip_rch:=g_rch_ac01;--AC01 - El codigo de cuenta es invalido o ausente
           end if;
        end if;
            --DA-7726-control del estado del módulo 3 en 1 o 6
            g_lugar :=  'Valida estado del modulo';
            lp_ver_horario(3); 
            if g_mod_estado in (1,6) then
               if g_tip_rch is null then    
                   pas_spi.g_cod_error := 185;
                   g_nom_respuesta := 'La cuenta no permite el proceso';
                   pas_spi.g_msj_error := g_nom_respuesta; 
                   g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
                end if;
            end if;
            
            g_lugar :=  ' Obteniendo valor, Nom. Cli. Beneficiario.';
            --TRFS-1157
            rg_msj_rec.nom_beneficiario :=substr(p_dat_recibidos.nom_beneficiario,1,120);
            g_lugar :=  ' Validando Nro. Cta. del Beneficiario.  ';
            if rg_msj_rec.nro_cta_beneficiario is not null then
            -- Valida que la cuenta del beneficiario sea numérico, si es numérico se intenta validar contra ITGF.
               if fue_val_es_numerico( rg_msj_rec.nro_cta_beneficiario ) = 'S' then
                  g_lugar :=  ' Validando Nro. Cta. del Beneficiario';
                  -- Valida que la cuenta  exista en ITGF.
                  v_cod_tip_doc_ben := rg_msj_rec.cod_tip_doc_beneficiario;
                  g_lugar :=  ' Validando Nro. Cta. del Beneficiario';
                  pas_spi.pr_obt_cta_interna( rg_msj_rec.nro_cta_beneficiario,
                                              v_cod_tip_doc_ben,
                                              rg_msj_rec.nro_doc_beneficiario,
                                              v_nro_cuenta,
                                              rg_msj_rec.cod_per_beneficiario
                                            );
                     if v_nro_cuenta is not null then
                        pag_cta.pr_obt_cuenta( v_nro_cuenta );
                         g_lugar :=  ' Validando Nro. Cta. del Beneficiario';
                        if pag_cta.fu_obt_cod_error <> 0 then
                           --Se cargan los errores en las variables del PAS_SNP, para uso externo al procedimiento.
                            pas_spi.g_cod_error := 186;
                            g_nom_respuesta := substr(pag_cta.fu_obt_msj_error,1,2000);
                            pas_spi.g_msj_error := g_nom_respuesta;
                             g_tip_rch:=g_rch_ms03;--La razon no fue especificada por el agente
                        else
                           g_lugar :=  ' Validando Nro. Cta. del Beneficiario';
                           rg_msj_rec.nro_cta_beneficiario := pag_cta.g_ctas.nro_cuenta;
                           rg_msj_rec.cod_per_beneficiario := nvl( rg_msj_rec.cod_per_beneficiario, pag_cta.g_ctas.cod_cliente );
                           rg_msj_rec.cod_oficina          := pag_cta.g_ctas.cod_oficina;
                        end if;
                        if  pas_spi.g_cod_error = 0 then
                         g_lugar :=  ' Validando Cuenta del cliente';
                         pag_cta.pr_ver_operacion( v_nro_cuenta,   -- Nro.Cta.
                                       pas_snp.fu_obt_cod_tra_padre,         -- Trx. Padre - Transferencia entre cuentas
                                       pas_snp.fu_obt_cod_mod_padre,         -- Mod.Padre
                                       pas_snp.fu_obt_cod_mad_padre,         -- Mad.Padre
                                       'C',   -- Tip.Mov.
                                      rg_msj_rec.cod_moneda,   -- Cod.Mon.
                                       0,                   -- Monto
                                      rg_msj_rec.cod_oficina,  -- Ofic.Orig.
                                       v_cod_modulo,   -- Mod.Hijo
                                       v_cod_modalidad,-- Mad.Hijo
                                       v_est_cuenta,        -- Estado Cta.
                                       v_sal_disponible,    -- Sal.Dispon.
                                       v_procesa            -- Procesa
                                     );

                             if pag_cta.fu_obt_cod_error <> 0 then
                                --Se cargan los errores en las variables del PAS_SPI, para uso externo al procedimiento.
                                pas_spi.g_cod_error := pag_cta.fu_obt_cod_error;
                                pas_spi.g_msj_error := pag_cta.fu_obt_msj_error;
                                g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
                               
                             end if;
                             if  v_procesa <>'S'then
                                  pas_spi.g_cod_error := 187;
                                  g_nom_respuesta := 'La cuenta ' ||v_nro_cuenta || ' no permite el proceso';
                                  pas_spi.g_msj_error := g_nom_respuesta; 
                                  g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
                             end if;
                         
                             if not ( ( v_cod_modulo in ( 3, 4 ) and v_cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39, 334 ) ) or v_cod_modulo = 5 ) then --Para MT recibido la Cuenta de Crédito puede ser la de Tarjetas 
                                           pas_snp.g_cod_error := 188;
                                           pas_snp.g_msj_error := 'Modalidad de la cuenta no permite este tipo de operación';
                                           g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
                             end if;
                        end if;
                        --DA-7726-control del estado del módulo 3 en 1 o 6
                         g_lugar :=  'Valida estado del modulo';
                         lp_ver_horario(3); 
                         if g_mod_estado in (1,6) then
                            if g_tip_rch is null then    
                               pas_spi.g_cod_error := 185;
                               g_nom_respuesta := 'La cuenta no permite el proceso';
                               pas_spi.g_msj_error := g_nom_respuesta; 
                               g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
                             end if;
                         end if;
                        /* g_lugar :=  ' Validando Cliente Beneficiario Inhibido';
                        if it.fug_obt_es_per_inhi(rg_msj_rec.cod_per_beneficiario)='S' then
                           if g_tip_rch is null then
                             pas_spi.g_cod_error := 189;
                             g_nom_respuesta := 'Cliente beneficiario inhibido.';
                             pas_spi.g_msj_error := g_nom_respuesta;
                             g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
                           end if;
                        end if;*/ --caso inhibido solicitado 17/06/2022
                         g_lugar :=  ' Validando Nro. Cta. del Beneficiario';
                        if pag_cta.g_ctas.cod_moneda != rg_msj_rec.cod_moneda then
                           if g_tip_rch is null then
                             pas_spi.g_cod_error := 190;
                             g_nom_respuesta := 'No coincide moneda transferencia con moneda de cta';
                             pas_spi.g_msj_error := g_nom_respuesta;
                             g_tip_rch:=g_rch_ac09;--AC09 - La divisa de cuenta es incorrecta o ausente
                           end if;
                        end if;
                         g_lugar :=  ' Validando Nro. Cta. del Beneficiario';
                        if pas_snp.fu_obt_cod_error <> 0 then
                          if g_tip_rch is null then
                            pas_spi.g_cod_error := 191;
                            g_nom_respuesta := pas_snp.fu_obt_msj_error;
                            pas_spi.g_msj_error := g_nom_respuesta;
                            g_tip_rch:=g_rch_ac09;
                           end if;
                        end if;
                     else
                        if g_tip_rch is null then
                           pas_spi.g_cod_error := 192;
                           g_nom_respuesta := 'No coincide cuenta con datos del cliente';
                           pas_spi.g_msj_error := g_nom_respuesta;
                           g_tip_rch:=g_rch_ac01;--AC01 - El codigo de cuenta es invalido o ausente: 
                       end if;
                     end if;
                 else
                   if g_tip_rch is null then    
                      pas_spi.g_cod_error := 193;
                      g_nom_respuesta := 'La cuenta del beneficiario tiene caracteres no numéricos';
                      pas_spi.g_msj_error := g_nom_respuesta; 
                      g_tip_rch:=g_rch_ac01;--AC01 - El codigo de cuenta es invalido o ausente: 
                   end if;
                 end if;
         
      end if;
      --DA-7726-control del estado del módulo 3 en 1 o 6
      g_lugar :=  'Valida estado del modulo';
      lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
           if g_tip_rch is null then    
               pas_spi.g_cod_error := 185;
               g_nom_respuesta := 'La cuenta no permite el proceso';
               pas_spi.g_msj_error := g_nom_respuesta; 
               g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
      end if;
     end if;
      --valida credito a modalides especificas( cuenta basica, Cuenta bajo riesgo)
      begin
       v_supera_limite:= fua_obt_limite_cta_basica(rg_msj_rec.nro_cta_beneficiario,
                                           rg_msj_rec.monto,
                                          rg_msj_rec.fec_valor,
                                          v_cod_modalidad,
                                          rg_msj_rec.cod_moneda);
                                          
      IF nvl(v_supera_limite,'N')='S' then
                 --DT02 - Politica Interna.
                  if g_tip_rch is null then
                           pas_spi.g_cod_error := 194;
                           g_nom_respuesta := 'Sumatoria de transferencias recibidas, supera el maximo posible para el tipo de cuenta';
                           pas_spi.g_msj_error := g_nom_respuesta;
                           g_tip_rch:=g_rch_dt02;
                  end if;
                                 
      end if;
       exception
         when others then
           null;
      end;
      g_lugar :=  'Obteniendo valor Concepto. ';
      rg_msj_rec.concepto := p_dat_recibidos.nro_ref_externa;
      rg_msj_rec.dir_beneficiario:= null;
      --spi fase 2
      begin
            select sl.cod_msj_swift
            into   v_cod_swift
            from ge_spi_solicitudes sl
            where sl.nro_ref_externa=p_dat_recibidos.nro_ref_solicitud;

      exception
          when no_data_found then
               v_cod_swift:=nvl(v_cod_swift,0); 
               v_responder:=true;
      end;

      if not v_sub_participante then --SPI Fase 2
        g_lugar :=  'Obteniendo valor transaccion, ';
        if fug_obt_pardinamico('COD_SPI_SOL_PAGO')=v_cod_swift then
          rg_msj_rec.cod_tip_operacion := '003';
        else
          rg_msj_rec.cod_tip_operacion := p_dat_recibidos.cod_transaccion;
        end if;
        g_lugar :=  'Asignando valor subtipo operacion, ';
        rg_msj_rec.cod_sub_tip_operacion := '002';
      end if;

      g_lugar :=  'Obteniendo codigo de mensaje mx, en base a la version recibida.';
      v_cod_msj_mx :=pas_spi.fu_tip_msj_ver(p_dat_recibidos.cod_msj_mx);
          begin
            select to_number(t.val_minimo)
              into v_codigo
              from ba_cod_referencias t
             where dominio = 'COD_MSJ_SWIFT'
               and t.abreviatura = v_cod_msj_mx;
          exception
         when no_data_found then
           pas_spi.g_cod_error := 195;
           g_nom_respuesta := 'No se encuentra codigo de mensaje swift para version recibida -'||v_cod_msj_mx;
           pas_spi.g_msj_error := g_nom_respuesta;
         when others then
           pas_spi.g_cod_error := 196;
           g_nom_respuesta := 'No se encuentra codigo de mensaje swift para version recibida -'||v_cod_msj_mx;
           pas_spi.g_msj_error := g_nom_respuesta;
       end;
      -- JFF Control de ref externa 
      g_lugar :=  'Validando Duplicados.';
      begin
        select 'S' 
          into v_existe_ref
          from ge_snp_transferencias g
          where g.nro_ref_externa = p_dat_recibidos.nro_ref_externa
            and rownum=1;     
     exception
         when others then
           v_existe_ref :='N';
      end;  
      if nvl(v_existe_ref,'N')='S' then   
                raise ex_salir;
      end if;   
       
      -- Se Inserta en ge_snp_transferencias
       BEGIN
         g_lugar :=  'Asignacion de valores varios para ge_snp_transferencias ';
         rg_msj_rec.nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
         rg_msj_rec.cod_msj_swift  := v_codigo;
         rg_msj_rec.cod_modulo     := pas_snp.fu_obt_cod_mod_padre;
         rg_msj_rec.cod_modalidad  := pas_snp.fu_obt_cod_mad_padre;
         rg_msj_rec.msj_swift      := p_dat_recibidos.msj_mx;
         rg_msj_rec.ind_valor      := 'S'; --(S) Alto Valor
         rg_msj_rec.situacion      := 'R';
         rg_msj_rec.estado         := nvl(rg_msj_rec.estado, 'S');
         rg_msj_rec.origen         := 'I';
         rg_msj_rec.plataforma     := 'S';
         rg_msj_rec.indemnizado    := 'N';
         BEGIN 
           g_lugar :=  'Insercion en ge_snp_transferencias ';
                   INSERT INTO ge_snp_transferencias
                     (nro_referencia,
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
                      cod_servicio,
                      nro_cta_ben_recibido) --spi fase 2
                   VALUES
                     (rg_msj_rec.nro_referencia,
                      rg_msj_rec.nro_lote,
                      rg_msj_rec.nro_sec_lote,
                      rg_msj_rec.cod_modulo,
                      rg_msj_rec.cod_modalidad,
                      rg_msj_rec.cod_oficina,
                      rg_msj_rec.cod_msj_swift,
                      rg_msj_rec.cod_tip_operacion,
                      rg_msj_rec.cod_sub_tip_operacion,
                      rg_msj_rec.msj_swift,
                      rg_msj_rec.fec_ingreso,
                      rg_msj_rec.fec_recepcion,
                      rg_msj_rec.fec_valor,
                      rg_msj_rec.fecha,
                      rg_msj_rec.hora,
                      rg_msj_rec.cod_usuario,
                      nvl(rg_msj_rec.cod_moneda,'GS'),
                      rg_msj_rec.monto,
                      rg_msj_rec.cod_per_solicitante,
                      rg_msj_rec.nom_solicitante,
                      rg_msj_rec.dir_solicitante,
                      rg_msj_rec.cod_tip_doc_solicitante,
                      rg_msj_rec.nro_doc_solicitante,
                      rg_msj_rec.nro_cta_solicitante,
                      rg_msj_rec.cod_swi_pte_solicitante,
                      rg_msj_rec.cod_swi_suc_solicitante,
                      rg_msj_rec.nro_cta_pte_solicitante,
                      rg_msj_rec.nro_cta_suc_pte_solicitante,
                      rg_msj_rec.cod_per_beneficiario,
                      rg_msj_rec.nom_beneficiario,
                      rg_msj_rec.dir_beneficiario,
                      rg_msj_rec.cod_tip_doc_beneficiario,
                      rg_msj_rec.nro_doc_beneficiario,
                      rg_msj_rec.nro_cta_beneficiario,
                      rg_msj_rec.cod_swi_pte_beneficiario,
                      rg_msj_rec.cod_swi_suc_beneficiario,
                      rg_msj_rec.nro_cta_pte_beneficiario,
                      rg_msj_rec.nro_cta_suc_pte_beneficiario,
                      rg_msj_rec.concepto,
                      rg_msj_rec.observacion,
                      rg_msj_rec.nro_ref_externa,
                      rg_msj_rec.tip_cargo,
                      rg_msj_rec.ind_valor,
                      rg_msj_rec.situacion,
                      rg_msj_rec.estado,
                      rg_msj_rec.tip_rechazo,
                      rg_msj_rec.prioridad,
                      rg_msj_rec.nro_operacion,
                      rg_msj_rec.tip_mensaje,
                      rg_msj_rec.ref_oid,
                      rg_msj_rec.error,
                      rg_msj_rec.origen,
                      rg_msj_rec.plataforma,
                      rg_msj_rec.indemnizado,
                      rg_msj_rec.cod_servicio,
                      p_dat_recibidos.cta_beneficiario);

                exception
                 when dup_val_on_index then
                  --Mensajeria duplicada
                  null;
                  when others THEN
                        pas_spi.g_cod_error := 191;
                        pas_spi.g_msj_error := 'Error al insertar en GE_SNP_TRANSFERENCIAS. Nro. Ref.: ' || rg_msj_rec.nro_referencia || ' - ' || sqlerrm;
                 
                end;
     EXCEPTION
        when others then
           pas_spi.g_cod_error := 197;
           g_nom_respuesta :='Error en la insercion de GE_SNP_TRANSFERENCIAS';
           pas_spi.g_msj_error :=g_nom_respuesta||sqlerrm;
     END;
     --DA-7726-control del estado del módulo 3 en 1 o 6
      g_lugar :=  'Valida estado del modulo';
      lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
           if g_tip_rch is null then    
               pas_spi.g_cod_error := 185;
               g_nom_respuesta := 'La cuenta no permite el proceso';
               pas_spi.g_msj_error := g_nom_respuesta; 
               g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
      end if;
     end if;
      /*SPI  Fase2*/

      if  /*p_dat_recibidos.nro_ref_solicitud is not null*/not v_responder then
           g_lugar :=  'Actualizando solicitud';

          update ge_spi_solicitudes sl
          set sl.nro_referencia=rg_msj_rec.nro_referencia,
          sl.respuesta='Ref. externa del pacs.008 recibido: '||rg_msj_rec.nro_ref_externa
          where sl.nro_ref_externa=p_dat_recibidos.nro_ref_solicitud;

      end if;
      g_lugar :=  'Final del proceso';
     if pas_spi.g_cod_error <> 0 then
       update ge_snp_transferencias t
          set t.tip_rechazo = g_tip_rch,--'AC02',
              t.error       = pas_spi.g_msj_error,
              t.estado      = 'R',
              t.situacion   = 'C'          
        where t.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
       raise ex_error;
     else
        --Invoca al sp que se encarga de enviar AUTORIZACION
        /*
        SPI-FASE 2 , sólo se responde cuando no es un pacs008 en respuesta de un pain.013
        */
         if /*p_dat_recibidos.nro_ref_solicitud is null*/v_responder then 
            pas_spi.pr_gen_res_spi(v_nro_cta_participante,g_pac_002,p_dat_recibidos.nro_ref_externa,'AUTH');
         end if;
         g_lugar := 'Recepcion exitosa del pacs.008 Nro. Ref.externa'||p_dat_recibidos.nro_ref_externa;
         pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );
         p_dat_mensaje         := mensaje;
     end if;
  
  exception
    when ex_error then
    mensaje.cod_respuesta := pas_spi.g_cod_error;
    mensaje.nom_respuesta := g_nom_respuesta;
    mensaje.des_Respuesta := 'pas_spi.pr_pro_msj_rec_008-'||g_lugar||'-'||sqlerrm;
    --Invoca al sp que se encarga de enviar RECHAZO
         /*
         SPI-FASE 2 , sólo se responde cuando no es un pacs008 en respuesta de un pain.013
         */
         if /*p_dat_recibidos.nro_ref_solicitud is null*/ v_responder then
            pas_spi.pr_gen_res_spi(v_nro_cta_participante,g_pac_002,p_dat_recibidos.nro_ref_externa,'NAUT');
         end if;
    --registrando log
    g_lugar := 'Error durante la recepcion del pacs.008 Nro. Ref.externa'||p_dat_recibidos.nro_ref_externa;
    pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
        
    p_dat_mensaje         := mensaje;
  end;

EXCEPTION
  when ex_salir then
       mensaje.cod_respuesta := 1;
       mensaje.nom_respuesta := 'Error en pr_pro_msj_rec_008-'||g_lugar;
       mensaje.des_Respuesta:=sqlerrm;
       g_lugar := 'Error: Nro de ref. externa ya existe! '||p_dat_recibidos.nro_ref_externa;
       pas_snp.pr_reg_operacion( p_dat_recibidos.msj_mx , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
       p_dat_mensaje         := mensaje;
  when ex_error then
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_pro_msj_rec_008-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    --registrando log
    g_lugar := 'Error durante el proceso del Mensaje';
    pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    
    p_dat_mensaje         := mensaje;
  WHEN others THEN
    pas_spi.g_cod_error := 150;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_pro_msj_rec_008'||g_lugar;
    mensaje.des_Respuesta :=sqlerrm;
     g_tip_rch:=g_rch_ms03;
     update ge_snp_transferencias t
          set t.tip_rechazo = g_tip_rch,
              t.error       = pas_spi.g_msj_error,
              t.estado      = 'R',
              t.situacion   = 'C'          
        where t.nro_ref_externa = p_dat_recibidos.nro_ref_externa;
     --Invoca al sp que se encarga de enviar RECHAZO
      /*
    SPI-FASE 2 , sólo se responde cuando no es un pacs008 en respuesta de un pain.013
    */
    if v_responder then
       pas_spi.pr_gen_res_spi(v_nro_cta_participante,g_pac_002,p_dat_recibidos.nro_ref_externa,'NAUT');
    end if;
    --registrando log
    g_lugar := 'Error durante el proceso del Mensaje';
    pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    
    p_dat_mensaje         := mensaje;
END pr_pro_msj_rec_008;
PROCEDURE pr_ini_registros
IS
  /*
  || Inicializa variables del tipo ROWTYPE.
  */
BEGIN
   PAS_SPI.g_msj := NULL;
END pr_ini_registros;
PROCEDURE pr_reg_operacion( p_mensaje   in long,
                            p_respuesta in varchar2 )
IS
   /*
   || Registra LOG de la mensajería
   */

   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   insert into ba_log_mensajerias
       (mensaje, respuesta)
     values
       (p_mensaje, substr(p_respuesta,1,4000));
   commit;
EXCEPTION
  when others then
     pas_spi.g_cod_error := 50;
     pas_spi.g_msj_error := sqlerrm;
     --raise_application_error(-20000, pas_snp.fu_obt_msj_error);
END;

PROCEDURE pr_reg_operacion_spi( p_mensaje   in long,
                            p_respuesta in varchar2 )
IS
   /*
   || Registra LOG de la mensajería
   */

   PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
BEGIN
   insert into ba_log_spi
       (mensaje, respuesta)
     values
       (p_mensaje, substr(p_respuesta,1,4000));
   commit;
EXCEPTION
  when others then
     pas_snp.g_cod_error := 50; --verificar nro
     pas_snp.g_msj_error := sqlerrm;
     raise_application_error(-20001, pas_snp.fu_obt_msj_error);
END;
PROCEDURE pr_obt_cta_interna( p_nro_cuenta            in  ge_snp_transferencias.nro_cta_beneficiario%type,
                              p_tip_documento         in  ba_personas.cod_tip_documento%type,
                              p_nro_documento         in  ba_personas.nro_documento%type,
                              p_nro_cta_interno       out ge_cuentas.nro_cuenta%type,
                              p_cod_persona           out ba_personas.cod_persona%type
                            )
 
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
   v_ind_nro_doc   varchar2(1):= 'N'; -- Existe el Número de Documento (S/N).
   v_estado        ge_cuentas.estado%type;
   v_cod_persona   ba_personas.cod_persona%type;
BEGIN
   for c in cu_cta_clientes loop
      
      p_nro_cta_interno := c.nro_cuenta;
      p_cod_persona     := c.cod_persona;
      v_cod_modulo      := c.cod_modulo;
      v_cod_modalidad   := c.cod_modalidad;
      v_estado          := c.estado;
      -- Si el tipo de documento no está cargado, no se valida.
      /*if p_tip_documento = c.cod_tip_documento or
         p_tip_documento is null
      then
         v_ind_tip_doc := 'S';
      end if;*/ --TCE-489
      -- entonces volvemos a limpiar dichos caracteres del número de documento.
      -- if c.nro_documento =p_nro_documento  then
      --Para que admita el RUC por más que no tenga -
     /*if pas_snp.fu_val_cadena(c.nro_documento, 'A') =
        pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A') or
        instr(pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A'),
               pas_snp.fu_val_cadena(c.nro_documento, 'A'), 1) > 0 then*/
      if (pas_snp.fu_val_cadena(c.nro_documento, 'A') =
        pas_snp.fu_val_cadena(nvl(p_nro_documento, -99), 'A')) or
        (substr( trim(c.nro_documento),1, instr(c.nro_documento, '-')-1))=trim(p_nro_documento) or --TCE-489
        (substr( trim(p_nro_documento),1, instr(p_nro_documento, '-')-1)) =trim(c.nro_documento)   --TCE-489
         then      
         v_ind_nro_doc := 'S';
      end if;
      if /*v_ind_tip_doc = 'S' and */ v_ind_nro_doc = 'S' then --TCE-489
        v_cod_persona := p_cod_persona;
        v_ind_tip_doc := null;
        v_ind_nro_doc := null;
      end if;
      
   end loop;

   if p_nro_cta_interno is null then
     if g_tip_rch is null then    
        pas_spi.g_cod_error := 66;
        g_nom_respuesta := 'Nro de cuenta del cliente beneficiario no corresponde al nro de documento recibido.';
        pas_spi.g_msj_error := g_nom_respuesta;
        g_tip_rch:=g_rch_ac01;--AC01 - La cuenta indicada fue cerrada
     end if;
  else
   
   if not ( ( v_cod_modulo in ( 3, 4 ) and v_cod_modalidad in ( 31, 41, 43, 47, 455, 38, 39, 334 ) ) or v_cod_modulo = 5)then
      if g_tip_rch is null then    
       pas_spi.g_cod_error := 67;
       g_nom_respuesta := 'Modalidad de la cuenta no permite este tipo de operación';
       pas_spi.g_msj_error := g_nom_respuesta;
       g_tip_rch:=g_rch_ac04;--AC04 - La cuenta indicada fue cerrada
      end if;
   end if;

   if  v_cod_modulo in ( 3, 4 ) and v_estado in ( 'C', 'P', 'X', 'T' ) then
      if g_tip_rch is null then    
       pas_spi.g_cod_error := 68;
       g_nom_respuesta := 'Estado de la cuenta no permite este tipo de operación';
       pas_spi.g_msj_error := g_nom_respuesta;
       g_tip_rch:=g_rch_ac04;--AC04 - La cuenta indicada fue cerrada
      end if;
   end if;
 end if;
   /*if v_ind_tip_doc = 'N' then
      if g_tip_rch is null then    
       pas_spi.g_cod_error := 69;
       g_nom_respuesta := 'Tip. Doc. no coincide con el registrado en ITGF para la cuenta';
       pas_spi.g_msj_error := g_nom_respuesta;
       g_tip_rch:=g_rch_dt03;
      end if;
   end if;*/  --TCE-489

   if v_ind_nro_doc = 'N' then
      if g_tip_rch is null then    
       pas_spi.g_cod_error := 70;
       g_nom_respuesta := 'Nro Doc. no coincide con el registrado en ITGF para la cuenta '||p_nro_cta_interno;
       pas_spi.g_msj_error := g_nom_respuesta;
       g_tip_rch:=g_rch_dt03;
      end if;
   end if;
   if pas_spi.fu_obt_cod_error <> 0 then
      p_nro_cta_interno := null;
      p_cod_persona     := null;
   else 
      p_cod_persona := v_cod_persona;

   end if;
EXCEPTION
   when ex_salir then
      p_nro_cta_interno   := null;
      p_cod_persona       := null;
   when others then
      p_nro_cta_interno   := null;
      p_cod_persona       := null;
       if g_tip_rch is null then    
      pas_spi.g_cod_error := 70;
      g_nom_respuesta := 'Error al recuperar la Cuenta Interna en ITGF. Cuenta: ' || p_nro_cuenta || ' ' || SQLERRM;
      pas_spi.g_msj_error := g_nom_respuesta;
      end if;
END pr_obt_cta_interna;
PROCEDURE pr_gen_env_aut_008( p_fec_valor     in ge_snp_transferencias.fec_valor%type default null,
                                  p_can_sin_fondo in varchar2 default 'N'
                                )
IS
   /*
   || Proceso diario de envío de mensajes MX a BCP,
   || 
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
   v_nro_referencia ge_snp_transferencias.nro_referencia%type;
   v_fecha ge_snp_transferencias.fecha%type;
   v_hora ge_snp_transferencias.hora%type;
   v_cod_usuario ge_snp_transferencias.cod_usuario%type;
   v_cod_moneda ge_snp_transferencias.cod_moneda%type;
   v_cod_msj_swift ge_snp_transferencias.cod_msj_swift%type;
   v_nro_cta_solicitante ge_snp_transferencias.nro_cta_solicitante%type;
   v_estado ge_snp_transferencias.estado%type;
   v_situacion ge_snp_transferencias.situacion%type;
   v_monto ge_snp_transferencias.monto%type;
   rg_mensaje               pas_snp.rg_msj;
   v_dir_spi_mail  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_NOTIFICACIONES');
   cursor cu_msj_av is --Cursor de alto valor para aquellos registrados por ITGF y por HB
     select t.nro_referencia, t.cod_msj_swift, t.cod_tip_operacion, t.cod_sub_tip_operacion
       from ge_snp_transferencias t
      where t.fec_valor                =  c_fec_valor
        and nvl( t.ind_valor,'N' )     = 'S'          -- Alto Valor
        and t.estado                   = 'A'          -- Aprobado en ITGF
        and t.situacion                = 'P'          -- Pendiente de envío a BCP
        and t.cod_msj_swift            = fug_obt_pardinamico( 'COD_SPI_PCD' )
        and t.nro_lote                 IS NULL        -- Si nro_lote es NULO significa que todavia no se procesó.
        and t.fec_recepcion            IS NULL        -- Para MT enviados
        and t.monto                    <> 0
        and t.nro_cta_pte_solicitante  IS NOT NULL
        order by t.origen asc, t.cod_moneda asc, t.prioridad asc, monto desc;
   PROCEDURE lp_pro_msj_008
   IS
   BEGIN
      for c in cu_msj_av loop
         pas_snp.g_det_msj_error := NULL;
         v_nro_referencia:=c.nro_referencia;
         --Obtiene el registro de ge_snp_transferencias
         g_lugar :=  'Levantando registros desde GE_SNP_TRANSFERENCIAS, ';
         begin
           select a.fecha, a.hora,a.cod_usuario,a.cod_moneda,a.cod_msj_swift, a.nro_cta_solicitante,a.estado,a.situacion,a.monto
           into v_fecha,v_hora, v_cod_usuario, v_cod_moneda, v_cod_msj_swift,v_nro_cta_solicitante,v_estado,v_situacion,v_monto
           from ge_snp_transferencias a
           where a.nro_referencia=v_nro_referencia;
         end;

         g_lugar :=  'Obteniendo Horario Vigente en BCP para Nro. Ref.: ' || c.nro_referencia;
         if pas_snp.fu_obt_est_horario( c.cod_msj_swift,
                                        c.cod_tip_operacion,
                                        c.cod_sub_tip_operacion
                                      ) = 'A'
         then --Si el horario está VIGENTE en BCP
            if pas_snp.fu_obt_cod_error = 0 then
               if v_fecha is null and
                  v_hora is null and
                  v_cod_usuario is null
               then
                  g_lugar :=  'Obteniendo los datos de la Cta. ' || v_cta_debito || ', ' ;
                  -- Antes de enviar la mensaje a SPI, se verifica si existe saldo disponible
                  -- en la cuenta de DEBITO.

                  v_tra_padre       := pas_snp.fu_obt_cod_tra_padre;
                  v_cod_modulo      := NULL;
                  v_cod_modalidad   := NULL;
                  v_cod_transaccion := NULL;
                  v_mto_destino     := NULL;
                  v_cot_origen      := NULL;
                  v_cot_destino     := NULL;
                  v_env_alerta      := 'S';

                  if v_cod_msj_swift = 8 then
                     v_cta_debito      := v_nro_cta_solicitante;
                     v_cod_transaccion := v_tra_debito;
                  else
                     v_cta_debito := 0;
                     v_tra_padre  := NULL;
                     v_tip_mov    := NULL;
                  end if;

                  -- Recupera los datos de la Cta. de Débito
                  pag_cta.pr_obt_cuenta( v_cta_debito );
                  if pag_cta.fu_obt_cod_error <> 0 then
                     --Se cargan los errores en las variables del PAS_SPI, para uso externo al procedimiento.
                     pas_spi.g_cod_error := pag_cta.fu_obt_cod_error;
                     pas_spi.g_msj_error := pag_cta.fu_obt_msj_error;
                  end if;

                  -- Para el pacs.008 el módulo y la modalidad se carga con el PAG_CTA.PR_OBT_CUENTA
                  v_cod_modulo    := nvl( v_cod_modulo, pag_cta.g_ctas.cod_modulo );
                  v_cod_modalidad := nvl( v_cod_modalidad, pag_cta.g_ctas.cod_modalidad );

                  -- Obtiene el tipo de movimiento según el modulo, modalidad y transaccion de GE_TRANSACCION.
                  g_lugar :=  'Buscando Tipo de Movimiento de GE_TRANSACCION, ';
                  v_tip_mov := pas_snp.fu_obt_tip_mov_transaccion( v_cod_modulo,
                                                                   v_cod_modalidad,
                                                                   v_cod_transaccion
                                                                 );
                  if pas_snp.fu_obt_cod_error <> 0 then
                      pas_spi.g_cod_error := pas_snp.fu_obt_cod_error;
                      pas_spi.g_msj_error := pas_snp.fu_obt_msj_error;
                  end if;

                  -- Si no hubo ningún error
                  if pas_spi.fu_obt_cod_error = 0 then

                     if pag_cta.g_ctas.cod_moneda <> v_cod_moneda then
                        g_lugar :=  'Realizando conversión de moneda, ';
                        pas_snp.pr_con_mon_a_moneda( v_cod_moneda,
                                                     pag_cta.g_ctas.cod_moneda,
                                                     nvl( v_monto, 0 ),
                                                     v_mto_destino,
                                                     v_cot_origen,
                                                     v_cot_destino
                                                   );

                       if pas_snp.fu_obt_cod_error <> 0 then
                           --Se cargan los errores en las variables del PAS_SPI, para uso externo al procedimiento.
                           pas_spi.g_cod_error := pas_snp.fu_obt_cod_error;
                           pas_spi.g_msj_error := pas_snp.fu_obt_msj_error;
                        end if;
                     else
                        v_mto_destino := v_monto;
                     end if;

                     if pas_spi.fu_obt_cod_error = 0 then
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
                           --Se cargan los errores en las variables del PAS_SPI, para uso externo al procedimiento.
                             pas_spi.g_cod_error := pas_snp.fu_obt_cod_error;
                             pas_spi.g_msj_error := pas_snp.fu_obt_msj_error;

                        end if;
                        --controla resultado
                        if  v_procesa <> 'S'then
                            pas_spi.g_cod_error := 1;
                            --DA-7773
                            pas_spi.g_msj_error := 'Inconvenientes al procesar,Cuenta:'||pag_cta.g_ctas.nro_cuenta||',codigo: '||pag_cta.g_cod_error||',causa: '||pag_cta.g_msj_error; 
                              
                       end if;
                     end if;
                  end if;

                  /*
                  || Si existe algún error se actualiza a CANCELADO la mensajería y
                  || Se envía un mail a donde corresponda.
                  */

                if pas_spi.g_msj_error is not null then
                     g_lugar :=  'Registrando error encontrado para la Cta. ' || v_cta_debito || ', ' ;

                     /*
                     || Setea la mensajería a CANCELADO, registrando el error encontrado.
                     */
                     update ge_snp_transferencias
                        set estado = 'R', 
                        situacion = 'C',
                        error=pas_spi.g_msj_error
                      where nro_referencia = c.nro_referencia;
                     if sql%notfound then
                        raise_application_error(-20022,'Error en actualizacion de transferencia, Referencia: ' ||c.nro_referencia);
                      end if;
                     -- Envía el mail notificando el error.
                     BEGIN
                        if g_gru_dir_correo is not null then
                           it_mail.mail( fug_obt_dir_correo,
                                         g_gru_dir_correo,
                                         'Error antes de intentar envíar MX a SPI.',
                                         'Se ha encontrado un error antes de intentar enviar el MX a BCP.'||
                                         ' A continuación los datos de la mensajería: '                             || chr(10) || chr(10) ||
                                         'Cliente        : ' || g_msj.nom_solicitante                               || chr(10) ||
                                         'Nro. Cuenta    : ' || g_msj.nro_cta_solicitante                           || chr(10) ||
                                         'Nro. Operación : ' || g_msj.nro_operacion                                 || chr(10) ||
                                         'Fecha Valor    : ' || to_char(g_msj.fec_valor,'DD/MM/YYYY')               || chr(10) ||
                                         'Moneda         : ' || g_msj.cod_moneda                                    || chr(10) ||
                                         'Monto          : ' || trim(to_char(g_msj.monto,'999,999,999,999,999.99')) || chr(10) ||
                                         'Motivo         : ' || pas_spi.g_msj_error                                 || chr(10) ||
                                         chr(10) || chr(10) ||
                                         'Atentamente.'
                                       );
                        end if;

                     EXCEPTION
                        when others then
                           NULL;
                     END;
                 end if;
               end if;
               if pas_spi.g_msj_error is null and  
                  v_situacion = 'P' and
                  v_estado = 'A'
               then
                  -- Si tiene problemas al intentar generar movimientos se cargará el código de error
                      if pas_spi.fu_obt_cod_error <> 0 then
                         raise ex_salir;
                      else
                          --recupera datos de la transferencia
                         
                           pas_snp.pr_obt_mensaje ( c.nro_referencia, 'N'  );
                         if pas_snp.fu_obt_cod_error <> 0 then
                            raise ex_salir;
                         else
                            rg_mensaje := pas_snp.fu_obt_reg_transferencias;
                            pas_snp.pr_ini_registros;
                         end if;
                          --Genera el movimiento.
                           pas_snp.pr_pro_principal (rg_mensaje);
                           
                           if rg_mensaje.error is not null then 
                                -- Envía el mail notificando el error.
                                   BEGIN
                                      if v_dir_spi_mail is not null then
                                         it_mail.mail( fug_obt_dir_correo,
                                                       v_dir_spi_mail,
                                                       'Error al generar movimiento de tranferencia SPI.',
                                                       'Se ha encontrado un error al generar movimiento de tranferencia SPI.'||
                                                       ' A continuación los datos de la mensajería: '                             || chr(10) || chr(10) ||
                                                       'Nro referencia       : ' ||  rg_mensaje.nro_referencia                    || chr(10) ||
                                                       'Concepto   : ' || rg_mensaje.concepto                                     || chr(10) ||
                                                       'Fecha Valor    : ' || to_char(rg_mensaje.fec_valor ,'DD/MM/YYYY')         || chr(10) ||
                                                       'Moneda         : ' || rg_mensaje.cod_moneda                                    || chr(10) ||
                                                       'Monto          : ' || trim(to_char(rg_mensaje.monto,'999,999,999,999,999.99')) || chr(10) ||
                                                       'Motivo         : ' || rg_mensaje.error                                         || chr(10) ||
                                                       chr(10) || chr(10) ||
                                                       'Atentamente.'
                                                     );
                                      end if;
                                      
                                   exception
                                      when others then
                                         null;
                                   end;
                           else /* Si generó el movimiento*/
                                
                                pas_snp.pr_obt_mensaje(rg_mensaje.nro_referencia,'N');
                               if pas_snp.fu_obt_cod_error <> 0 then
                                  raise_application_error( -20021, pas_snp.fu_obt_msj_error );
                               end if;
                               --
                               update ge_snp_transferencias
                                      set estado = 'U', --para envio al microservicio SPI
                                          fecha = rg_mensaje.fecha,
                                          hora = rg_mensaje.hora,
                                          cod_usuario = rg_mensaje.cod_usuario
                                    where nro_referencia = rg_mensaje.nro_referencia;
                                   if sql%notfound then
                                     raise_application_error(-20022,
                                                             'Error en actualizacion de transferencia, Referencia: ' ||
                                                             rg_mensaje.nro_referencia);
                                   end if;
                               --
                            if  rg_mensaje.fecha is null or rg_mensaje.hora is null 
                                or rg_mensaje.cod_usuario is null then
                               -- Envía el mail notificando el error.
                                   BEGIN
                                      if v_dir_spi_mail is not null then
                                         it_mail.mail( fug_obt_dir_correo,
                                                       v_dir_spi_mail,
                                                       'Error al obtener movimiento de tranferencia SPI.',
                                                       'Se ha encontrado un error al generar movimiento de tranferencia SPI.'||
                                                       ' A continuación los datos de la mensajería: '                             || chr(10) || chr(10) ||
                                                       'Nro referencia       : ' ||  rg_mensaje.nro_referencia                    || chr(10) ||
                                                       'Concepto   : ' || rg_mensaje.concepto                                     || chr(10) ||
                                                       'Fecha Valor    : ' || to_char(rg_mensaje.fec_valor ,'DD/MM/YYYY')         || chr(10) ||
                                                       'Moneda         : ' || rg_mensaje.cod_moneda                                    || chr(10) ||
                                                       'Monto          : ' || trim(to_char(rg_mensaje.monto,'999,999,999,999,999.99')) || chr(10) ||
                                                       'Motivo         : ' || rg_mensaje.error                                         || chr(10) ||
                                                       chr(10) || chr(10) ||
                                                       'Atentamente.'
                                                     );
                                      end if;
                                      
                                   exception
                                      when others then
                                         null;
                                   end;
                             end if; 
                           end if;
                      end if;     
             end if;
            end if;
         end if;
         --- aqui setear variables y pasar al sgte registro
          pas_spi.g_cod_error := 0;
          pas_spi.g_msj_error := NULL;
      end loop;

   EXCEPTION
     when ex_salir then
        raise ex_salir;
     when others then
        pas_spi.g_cod_error := 54;
        pas_spi.g_msj_error := 'Error en LP_PRO_SWI_ALT_VALOR, ' || ' - ' || sqlerrm;
        pas_snp.pr_reg_operacion( 'Error en proceso diario de envío de mensajes MX a BCP,', g_lugar|| '|' ||PAS_SPI.g_msj_error );  
        raise ex_salir;
   END lp_pro_msj_008;

 

BEGIN
   /* Inicializa la aplicacion*/
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   pas_spi.g_cod_error := 0;
   pas_spi.g_msj_error := NULL;

   --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
   pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
   -- Se procesa los mensajes pacs.008
   lp_pro_msj_008;


EXCEPTION
  /* when ex_horario then
      pas_snp.g_cod_error := 54;
      pas_snp.g_msj_error := g_lugar || ' ' || pas_snp.fu_obt_msj_error;*/
   when ex_salir then
      pas_spi.g_cod_error := 54;
      pas_spi.g_msj_error := g_lugar || ' - ' || sqlerrm;
      pas_snp.pr_reg_operacion( 'Error durante envio pacs.008(Fecha Futura),Nro. Referencia: '||v_nro_referencia , g_lugar|| '|' ||  pas_spi.g_cod_error|| '|' ||pas_spi.g_msj_error ); 
   when others then
      pas_spi.g_cod_error := 54;
      pas_spi.g_msj_error := g_lugar || ' - ' || sqlerrm;
      pas_snp.pr_reg_operacion( 'Error durante envio pacs.008(Fecha Futura),Nro. Referencia: '||v_nro_referencia , g_lugar|| '|' ||  pas_spi.g_cod_error|| '|' ||pas_spi.g_msj_error ); 
END pr_gen_env_aut_008;
PROCEDURE pr_gen_rev_tra_008(p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type)
 /*Genera reversion del débito realizado a la cuenta del cliente, por envio de pacs.008*/
IS
  verror     exception;
  v_fec_rec_008                 ge_snp_transferencias.fec_recepcion%type;
  v_nro_ref_008                 ge_snp_transferencias.nro_referencia%type;
  v_situacion_008               ge_snp_transferencias.situacion%type;
  v_estado_008                  ge_snp_transferencias.estado%type;
  v_fecha_008                   ge_snp_transferencias.fecha%type;
  v_hora_008                    ge_snp_transferencias.hora%type;
  v_usuario_008                 ge_snp_transferencias.cod_usuario%type;
  v_cod_msj_008                 ge_snp_transferencias.cod_msj_swift%type;
  v_moneda_008                  ge_snp_transferencias.cod_moneda%type;
  v_referencia_008              ge_snp_transferencias.cod_swi_pte_solicitante%type;
  v_monto_008                   ge_snp_transferencias.monto%type;
  v_cod_tip_operacion_008       ge_snp_transferencias.cod_tip_operacion%type;
  v_cod_sub_tip_operacion_008   ge_snp_transferencias.cod_sub_tip_operacion%type;
  v_nro_cta_beneficiario_008    ge_snp_transferencias.nro_cta_beneficiario%type;
  v_nro_cta_solicitante_008      ge_snp_transferencias.nro_cta_solicitante%type;
  v_nro_documento               ge_movimientos.nro_documento%type:=null;
  v_nro_documento_noc           ge_movimientos_noc.nro_documento%type:=null;
  v_fecha_noc                   ge_movimientos_noc.fecha%type;
  v_hora_noc                    ge_movimientos_noc.hora%type;
  v_cod_usuario_noc             ge_movimientos_noc.cod_usuario%type;
  v_hor_actual                  varchar2(08);
  v_hor_reverso                 varchar2(10);
  v_cod_respuesta               number(10);
  v_nom_respuesta               varchar2(2000);
  v_cod_per_solicitante_008     ge_snp_transferencias.cod_per_solicitante%type;
  v_fec_insercion_008           ge_snp_transferencias.fec_insercion%type;
  v_pte_beneficiario            gv_snp_participantes.participante%type;
  v_swi_pte_beneficiario_008    ge_snp_transferencias.cod_swi_pte_beneficiario%type;
  v_dir_notificaciones          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_RECHAZO_LIM');
  v_swi_suc_beneficiario_008    ge_snp_transferencias.cod_swi_suc_beneficiario%type;
  v_usu_reversion               ba_usuarios.cod_usuario%type; 
BEGIN
begin
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
pas_spi.g_cod_error := 0;
pas_spi.g_msj_error := NULL;
g_lugar             := 'Busca la transferencia';
v_usu_reversion     :=null;
select fec_recepcion,
       cod_msj_swift,
       nro_referencia,
       situacion,
       estado,
       fecha,
       hora,
       cod_usuario,
       cod_moneda,
       monto,
       cod_swi_pte_solicitante,
       cod_tip_operacion,
       cod_sub_tip_operacion,
       nro_cta_beneficiario,
       nro_cta_solicitante,
       cod_per_solicitante,
       fec_insercion,
       cod_swi_pte_beneficiario,
       cod_swi_suc_beneficiario
  into v_fec_rec_008,
       v_cod_msj_008,
       v_nro_ref_008,
       v_situacion_008,
       v_estado_008,
       v_fecha_008,
       v_hora_008,
       v_usuario_008,
       v_moneda_008,
       v_monto_008,
       v_referencia_008,
       v_cod_tip_operacion_008,
       v_cod_sub_tip_operacion_008,
       v_nro_cta_beneficiario_008,
       v_nro_cta_solicitante_008,
       v_cod_per_solicitante_008,
       v_fec_insercion_008,
       v_swi_pte_beneficiario_008,
       v_swi_suc_beneficiario_008
  from ge_snp_transferencias
 where nro_ref_externa = p_nro_ref_externa;
--Busca movimiento diario
begin
  select distinct nro_documento
    into v_nro_documento
    from ge_movimientos
   where fecha = v_fecha_008
     and hora = v_hora_008
     and cod_usuario = v_usuario_008
     and nro_documento = v_nro_ref_008;
exception
  when no_data_found then
    begin
      select distinct nro_documento, fecha, hora, cod_usuario
        into v_nro_documento_noc,
             v_fecha_noc,
             v_hora_noc,
             v_cod_usuario_noc
        from ge_movimientos_noc
       where cod_usuario = v_usuario_008
         and nro_documento = v_nro_ref_008;
    exception
      when no_data_found then
        v_nro_documento_noc := null;
      when others then
        v_nro_documento_noc := null;
    end;
  when others then
    v_nro_documento := null;
end;
--Reversion del dia
if v_nro_documento is not null then
 
  g_lugar := 'Reversion de la operacion con ref.' || p_nro_ref_externa;
  /*pas_snp.pr_rev_ope_con_swift(v_nro_ref_008,
                               'Rev.' || '-' || v_nro_ref_008 || ' - SPI');*/
  --TRFS-602
  pas_spi.pr_rev_ope_spi(v_nro_ref_008,'Rev.' || '-' || v_nro_ref_008 || ' - SPI','R',p_nro_ref_externa,v_fecha_008,v_hora_008,v_usuario_008);
  if pas_spi.fu_obt_cod_error <> 0 then
    --pas_spi.g_cod_error := '1';
    --pas_spi.g_msj_error := pas_snp.fu_obt_msj_error;
    raise verror;
  else
        update ge_snp_transferencias
           set situacion = 'C',
               estado    = 'R',
               error     = 'Rev.pacs.008' || '-' || v_nro_ref_008 || ' - SPI'
         where nro_ref_externa = p_nro_ref_externa;
  end if;
end if;
--Reversion mov nocturnos
if v_nro_documento_noc is not null then
  v_hor_reverso:=fug_obt_mov_hora;
  g_lugar       := 'Reversion de la operacion con ref.' ||
                   p_nro_ref_externa;
  begin
    prs_snp_obt_usu_hor_movimiento(user,'S',v_usu_reversion,v_hor_reverso); 
    prg_gen_mov_noc_spi(v_monto_008,
                        v_nro_cta_solicitante_008,
                        pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),
                                                                                        pag_gen.fu_obt_mon_local),
                                                    'C'),
                        v_moneda_008,
                        v_cod_msj_008,
                        v_cod_tip_operacion_008,
                        v_cod_sub_tip_operacion_008,
                        v_nro_ref_008,
                        p_nro_ref_externa,
                        v_referencia_008,
                        'E',
                        'S',
                        v_fecha_noc,
                        v_hora_noc,
                        v_cod_usuario_noc,
                        v_usu_reversion,
                        v_hor_reverso,
                        v_cod_respuesta,
                        v_nom_respuesta);
  exception
    when others then
      rollback;
      pas_spi.g_cod_error := '2';
      pas_spi.g_msj_error := 'Error en el proceso de reversion -' ||
                             v_nro_ref_008 || '-' || sqlerrm;
      raise ex_error;
  end;
  if v_cod_respuesta= 0 then
      update ge_snp_transferencias
         set situacion = 'C',
             estado    = 'R',
             error     = 'Rev.pacs.008' || '-' || v_nro_ref_008 || ' - SPI'
       where nro_ref_externa = p_nro_ref_externa;
  else
    g_lugar:='Envio de notificacion por error';
                           begin
                                  if  fu_val_tra_subpte(v_cod_tip_operacion_008,v_cod_sub_tip_operacion_008)  then
                                       v_pte_beneficiario:=it.fus_obt_nom_sub_participante(v_swi_pte_beneficiario_008,v_swi_suc_beneficiario_008);
                                  else
                                       v_pte_beneficiario:=it.fug_obt_nom_snp_participante(v_swi_pte_beneficiario_008);
                                  end if;
                                  if v_dir_notificaciones is not null then
                                    
                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de reversion con ref.externa: '||p_nro_ref_externa,
                                                   'Transferencia enviada con inconvenientes en reversion, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||p_nro_ref_externa
                                                   || chr(10) ||'Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante_008)
                                                   || chr(10) ||'Nro.Cuenta: '||v_nro_cta_solicitante_008
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( v_fec_insercion_008, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Entidad Destino: '||v_pte_beneficiario
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(v_monto_008,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
  end if;
end if;
exception when verror then
  pas_snp.pr_reg_operacion( 'Error en el proceso de reversion ,Nro. Ref.externa: '||p_nro_ref_externa , g_lugar|| '|' ||  pas_spi.g_cod_error|| '|' ||pas_spi.g_msj_error );  
  pas_spi.g_cod_error := 110; 
  pas_spi.g_msj_error := g_lugar || '-' || sqlerrm; 
  when others then 
    pas_snp.pr_reg_operacion( 'Error en el proceso de reversion ,Nro. Ref.externa: '||p_nro_ref_externa , g_lugar|| '|' ||  pas_spi.g_cod_error|| '|' ||pas_spi.g_msj_error );  
    pas_spi.g_cod_error := 111; 
    pas_spi.g_msj_error := g_lugar || '-' || sqlerrm; 
END pr_gen_rev_tra_008;
FUNCTION fu_obt_est_hor_spi ( p_cod_msj_swift     in ge_snp_transferencias.cod_msj_swift%type,
                              p_tip_operacion     in ge_snp_transferencias.cod_tip_operacion%type,
                              p_sub_tip_operacion in ge_snp_transferencias.cod_sub_tip_operacion%type
                            ) return varchar2
IS
   /*
   || Obtiene el estado en base al horario configurado
   */

   v_periodo          ge_snp_horarios.cod_periodo%type;
   v_estado       ge_snp_horarios.estado%type := 'N';
   c_fec_actual   constant date := g_fec_actual;
   v_ingresa varchar2(1):='N';

   PROCEDURE lp_ver_est_periodo( p_cod_periodo in     ge_snp_horarios.cod_periodo%type,
                                 p_estado      in out ge_snp_horarios.estado%type
                               )
   IS
     v_hor_inicio ge_snp_horarios.hor_inicio%type := null;
     v_hor_fin    ge_snp_horarios.hor_fin%type    := null;
     v_hor_actual ge_snp_horarios.hor_inicio%type := null;
     v_dia        varchar2(50);
   BEGIN
       
    if fug_obt_pardinamico( 'SPI_CON_HORARIO')= 'S' then
      
            select to_char(trunc(sysdate),'DAY','NLS_DATE_LANGUAGE = ENGLISH')
            into v_dia
            from dual;
            
            /*if ltrim(rtrim(upper(to_char(sysdate,'DAY')))) in ('SATURDAY','SABADO','SÁBADO')
                 or   ltrim(rtrim(upper(to_char(sysdate,'DAY')))) in ('SUNDAY','DOMINGO') then*/
            if trim(v_dia) in ('SATURDAY','SUNDAY') then
               p_estado := 'N';
               v_ingresa:='S';
            end if;
            
            if nvl(v_ingresa,'N') !='S' then
            
                SELECT nvl(sh.estado,'N'), sh.hor_inicio, sh.hor_fin
                  INTO p_estado, v_hor_inicio, v_hor_fin
                  FROM ge_snp_horarios sh
                 WHERE sh.cod_periodo = p_cod_periodo;
                  -- AND sh.fecha       = c_fec_actual;

                v_hor_actual := to_char(sysdate,'hh24mi');

                if to_number(v_hor_inicio) is null or                   -- Si la Hora de Inicio es NULO
                   to_number(v_hor_fin) is null or                      -- Si la Hora Fin es NULO
                   to_number(v_hor_actual) < to_number(v_hor_inicio) or -- Si la Hora Actual es Menor a la Hora Inicial
                   to_number(v_hor_actual) > to_number(v_hor_fin)       -- Si la Hora Actual es Mayor a la Hora Final
                then
                   p_estado := 'N';
                else
                   p_estado  :='S';
                end if;
              end if;
      else
        p_estado := 'S';--indica que no controla horario, por ende siempre devuelve S al fu_obt_tra_spi
      end if;
   EXCEPTION
      when others then
         p_estado := 'N';
   END lp_ver_est_periodo;
BEGIN

  if not pas_snp.fu_val_par_mensajes( p_cod_msj_swift,
                              p_tip_operacion,
                              p_sub_tip_operacion
                            )
  then
     pas_snp.g_cod_error := 33;
     pas_snp.g_msj_error := 'Campo(s) Tip.Operación y/o Sub Tip.Operación no se encuentra(n) en GE_SNP_PAR_MENSAJES';
     raise ex_salir;
  end if;

  begin
      select m.cod_periodo
        into v_periodo
        from ge_snp_par_mensajes m
       where m.cod_msj_swift                  = p_cod_msj_swift
         and m.cod_tip_operacion              = p_tip_operacion
         and m.cod_sub_tip_operacion          = p_sub_tip_operacion;
  exception
    when others then
      raise;
  end;
  lp_ver_est_periodo(v_periodo,v_estado);
  return v_estado;


EXCEPTION
  when ex_salir then
     return 'N';
  when others then
     pas_spi.g_cod_error  := 33;
     pas_spi.g_msj_error  := 'Error en PAS_SPI.FU_OBT_EST_HOR_SPI, ' || sqlerrm ;
     return 'N';
END fu_obt_est_hor_spi;
procedure pr_obt_tra_pen_008(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtTransPendiente008,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa transferencias pendientes de ENVIO al SPI, de tipo pacs.008(Mensaje de pago de Crédito Directo)
  */
  v_nro_referencia  ge_snp_transferencias.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_snp_transferencias.nro_ref_externa%type:= NULL;
  v_cant number(8):=0;
  v_tipo_ben varchar2(10);
  v_tipo_sol varchar2(10);
  transferencia typ_ObtTransPendiente008 := typ_ObtTransPendiente008(null,null,
                                                                     null,null,
                                                                     0,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_tra IS
    SELECT a.nro_referencia nro_referencia,
           a.nro_ref_externa,
           trunc(sysdate) fecha,
           NVL(a.hora,to_char(a.fec_insercion,'HH24:MI:SS')) hora, --Contemplo fec_recepcion para casos de REV
           d.cod_mon_iso moneda,
           a.monto monto,
            trunc(sysdate) fec_actual,
           a.nom_solicitante nom_solicitante,
           a.nro_doc_solicitante doc_solicitante,
           b.abreviatura tip_doc_solicitante,
           case 
              when s.cod_sol_spi is not null then
                  s.cta_ben_recibido
              else
                 lpad(rtrim( a.nro_cta_solicitante),16,'0')
              end cta_solicitante,
           a.cod_swi_pte_solicitante swi_participante_sol,
           a.nro_cta_pte_solicitante cta_participante_sol,
           a.cod_swi_pte_beneficiario swi_participante_ben,
           a.nro_cta_pte_beneficiario cta_participante_ben,
           a.nom_beneficiario nom_beneficiario,
           a.nro_doc_beneficiario doc_beneficiario,
           c.abreviatura tip_doc_beneficiario,
           case 
              when s.cod_sol_spi is not null then
                   s.cta_solicitante
              else
                 lpad(rtrim(a.nro_cta_beneficiario),16,'0')  
              end cta_beneficiario,
           a.concepto concepto,
           decode(s.cod_sol_spi,null,a.observacion,s.info_envio) observacion,
           a.cod_tip_operacion,
           a.cod_swi_suc_beneficiario,
           a.nro_cta_suc_pte_beneficiario,
           fus_obt_nom_sub_participante(a.cod_swi_pte_beneficiario,a.cod_swi_suc_beneficiario)nom_subparticipante,
             case nvl(s.cod_msj_swift,0)
             when fug_obt_pardinamico('COD_SPI_INI_PAGO') then
                 fue_obt_val_max_referencia('TIP_INSTRUMENTO',s.cod_msj_swift)
              when fug_obt_pardinamico('COD_SPI_SOL_PAGO') then
                 fue_obt_val_max_referencia('TIP_INSTRUMENTO',s.cod_msj_swift)
             else
                 fue_obt_val_max_referencia('TIP_INSTRUMENTO',fug_obt_pardinamico('COD_SPI_PCD'))
             end instrumento,--SPI Fase 2
           s.info_envio,
           s.nro_ref_externa nro_ref_original,
           s.uetr,
           s.identificacion,
           s.info_remesa,
           s.nro_ref_msj_original id_pago,
           a.rowid
      from ge_snp_transferencias a,
           ba_tip_documentos     b,
           ba_tip_documentos     c,
           ba_monedas            d,
           ge_spi_solicitudes    s
     where a.nro_referencia=s.nro_referencia(+)
       and a.cod_tip_doc_solicitante = b.cod_tip_documento
       and a.cod_tip_doc_beneficiario = c.cod_tip_documento
       and a.cod_moneda = d.cod_moneda
       and a.estado = 'U'
       and a.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_PCD' )
       and a.situacion not in ('B', 'N','C', 'L','V') --No sean bloqueado, Evitar reenvio SPI, Cancelado,Liquidado, Enviado al BCP
       and rownum=1
       order by a.nro_referencia asc
    for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe pacs.008';
  FOR a IN cu_msj_tra LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:= a.nro_ref_externa;
    --Recupera tipo de participante
    begin
      select tipo
        into v_tipo_sol
        from gv_snp_participantes
       where cod_swift = a.swi_participante_sol;
    exception
      when no_data_found then
        null;
      when others then
        null;
    end;
    begin
      select tipo
        into v_tipo_ben
        from gv_snp_participantes
       where cod_swift = a.swi_participante_ben;
    exception
      when no_data_found then
        null;
      when others then
        null;
    end;
    transferencia := typ_ObtTransPendiente008(a.nro_referencia,
                                               a.fecha,
                                               a.hora,
                                               a.moneda,
                                               a.monto,
                                               a.nom_solicitante,
                                               a.doc_solicitante,
                                               a.tip_doc_solicitante,
                                               a.cta_solicitante,
                                               a.swi_participante_sol,
                                               v_tipo_sol,
                                               a.cta_participante_sol,
                                               a.swi_participante_ben,
                                               v_tipo_ben,
                                               a.cta_participante_ben,
                                               a.nom_beneficiario,
                                               a.doc_beneficiario,
                                               a.tip_doc_beneficiario,
                                               a.cta_beneficiario,
                                               a.concepto,
                                               a.observacion,
                                               a.fec_actual,
                                               a.nro_ref_externa,
                                               a.cod_tip_operacion,
                                               a.nom_subparticipante,
                                               a.cod_swi_suc_beneficiario,
                                               a.nro_cta_suc_pte_beneficiario,
                                               a.instrumento,
                                               a.nro_ref_original,
                                               a.uetr,
                                               a.identificacion,
                                               a.info_remesa,
                                               a.id_pago);
    ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: pacs.008'||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Fecha actual: '||a.fec_actual|| chr(10) || 
         ' Tipo Operacion: '||a.cod_tip_operacion|| chr(10) || 
         ' Moneda: '||a.moneda|| chr(10) || 
         ' Monto: '||a.monto|| chr(10) || 
         ' Solicitante: '||a.nom_solicitante|| chr(10) || 
         ' Documento solicitante: '||a.doc_solicitante|| chr(10) || 
         ' Tipo doc solicitante: '||a.tip_doc_solicitante|| chr(10) || 
         ' Cuenta solicitante: '||a.cta_solicitante|| chr(10) || 
         ' Swift partipante solicitante: '||a.swi_participante_sol|| chr(10) || 
         ' Tipo solicitante: '||v_tipo_sol|| chr(10) || 
         ' Cuenta Participante solicitante: '||a.cta_participante_sol|| chr(10) || 
         ' Swift partipante beneficiario: '||a.swi_participante_ben|| chr(10) || 
         ' Sub-pte beneficiario: '||a.nom_subparticipante|| chr(10) || 
         ' Swift sub-pte beneficiario: '||a.cod_swi_suc_beneficiario|| chr(10) || 
         ' Cta. sub-pte beneficiario: '||a.nro_cta_suc_pte_beneficiario|| chr(10) ||
         ' Tipo beneficiario: '||v_tipo_ben|| chr(10) || 
         ' Cuenta Participante beneficiario: '||a.cta_participante_ben|| chr(10) || 
         ' Beneficiario: '||a.nom_beneficiario|| chr(10) || 
         ' Documento beneficiario: '||a.doc_beneficiario|| chr(10) || 
         ' Tipo doc beneficiario: '||a.tip_doc_beneficiario|| chr(10) || 
         ' Cuenta beneficiario: '||a.cta_beneficiario|| chr(10) || 
         ' Concepto: '||a.concepto|| chr(10) || 
         ' Instrumento: '||a.instrumento|| chr(10) || 
         ' Observacion: '||a.observacion|| chr(10) ||
         ' Ref. original: '||a.nro_ref_original|| chr(10) ||
         ' UETR: '||a.uetr|| chr(10) ||
         ' Identificacion: '||a.identificacion|| chr(10) ||
         ' Id. Pago: '||a.id_pago|| chr(10) ||
         ' Remesa: '||a.info_remesa
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   

  END LOOP;
  g_lugar:='Asigna datos para la cabecera de informe pacs.008';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi(PAS_SPI.fu_tip_msj_spi(fug_obt_pardinamico( 'COD_SPI_PCD' )),v_nro_ref_externa);
  g_lugar:='Actualizacion de transferencia pacs.008 a bloqueado';
  --Modo de bloquear el registro
  UPDATE ge_snp_transferencias
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
  if sql%rowcount > 0 then
    g_lugar:='Recupera cantidad de reintentos pacs.008';
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
      exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos pacs.008';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
    values (v_nro_referencia, v_nro_ref_externa, PAS_SPI.fu_tip_msj_spi(fug_obt_pardinamico( 'COD_SPI_PCD' )),trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de transferencia ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Pacs.008 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  else
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  end if;
  
EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 50;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     UPDATE ge_snp_transferencias
     SET situacion = 'N'
   WHERE nro_referencia = v_nro_referencia;
    pas_spi.pr_gen_rev_tra_008(v_nro_ref_externa);
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_008-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de pacs.008, Ref. externa: '||v_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje        := mensaje;
END pr_obt_tra_pen_008;

PROCEDURE pr_gen_env_api_reporte( p_nro_referencia         out ge_spi_sol_reportes.nro_referencia%type,
                                  p_reportType             out ge_spi_sol_reportes.tip_reporte%type,
                                  p_acc_code               out ge_spi_sol_reportes.nro_cta_solicitante%type,
                                  p_partic_code            out ge_spi_sol_reportes.cod_swi_solicitante%type,
                                  p_payment_status         out ge_spi_sol_reportes.est_pago%type,
                                  p_date_beg               out ge_spi_sol_reportes.fec_desde%type,
                                  p_fecha_end              out ge_spi_sol_reportes.fec_hasta%type,
                                  p_sess_id                out ge_spi_sol_reportes.id_sesion%type,
                                  p_bank_op_code           out ge_spi_sol_reportes.tip_instrumento%type,
                                  p_ttc                    out ge_spi_sol_reportes.tip_transaccion%type,
                                  p_formato                out ge_spi_sol_reportes.formato%type
                            )
 
IS
 v_nro_referencia  ge_spi_sol_reportes.nro_referencia%type:= NULL;
 v_formato         ge_spi_sol_reportes.formato%type;
 cursor reg_informes is
select s.NRO_REFERENCIA,s.TIP_REPORTE,s.NRO_CTA_SOLICITANTE,s.cod_swi_solicitante,
        s.EST_PAGO,s.FEC_DESDE,s.FEC_HASTA,s.FEC_VALOR,s.ID_DISPUTA,
        s.ID_SESION,s.TIP_INSTRUMENTO,s.TIP_PARTICIPANTE,s.TIP_TRANSACCION,
        s.SITUACION,s.formato
   from ge_spi_sol_reportes s
  where s.situacion = 'P'
    and trunc(s.fec_valor) <= trunc(sysdate)
    and rownum=1
    order by s.nro_referencia asc
    for update skip locked;

BEGIN
  begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := 1;end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos del registro';
  
  FOR a IN reg_informes LOOP
    v_nro_referencia := a.NRO_REFERENCIA;
    v_formato        := a.formato;
    p_nro_referencia:= a.NRO_REFERENCIA;
    p_reportType    := a.TIP_REPORTE;
    p_acc_code      := a.NRO_CTA_SOLICITANTE;
    p_partic_code   := a.COD_SWI_solicitante;
    p_payment_status:= a.est_pago;
    p_date_beg      := a.fec_desde;
    p_fecha_end     := a.fec_hasta;
    p_sess_id       := a.id_sesion;
    p_bank_op_code  := a.tip_instrumento;
    p_ttc           := a.tip_transaccion; 
    p_formato       := a.formato; 
   
     g_lugar:='Registro de parametros en log '||a.NRO_REFERENCIA;
     pas_snp.pr_reg_operacion('Tipo informe enviado:'||a.TIP_REPORTE||chr(10) ||
     ' Parametros: Nro_referencia: '||a.NRO_REFERENCIA|| chr(10) || 
     ' Fecha: '||a.FEC_VALOR|| chr(10) || 
     ' Fecha actual: '||trunc(sysdate)|| chr(10) ||  
     ' Tipo Reporte: '||a.TIP_REPORTE|| chr(10) || 
     ' Código de cuenta: '||a.NRO_CTA_SOLICITANTE|| chr(10) || 
     ' Identificación de sesión: '||a.id_sesion|| chr(10) ||
     ' Código de participante del usuario: '||a.COD_SWI_solicitante|| chr(10) ||
     ' Fecha desde: '||a.fec_desde|| chr(10) ||
     ' Fecha hasta: '||a.fec_hasta|| chr(10) ||
     ' Tipo de instrumento: '||a.tip_instrumento|| chr(10) ||
     ' Tipo de transacción: '||a.tip_transaccion|| chr(10) ||
     ' Estado de pago: '||a.est_pago|| chr(10) ||
     ' Formato reporte: '||a.formato
      ,g_lugar||' Nro_referencia: '||a.nro_referencia);   

  END LOOP;  
  g_lugar:='Actualizacion del registro a bloqueado';
  --Modo de bloquear el registro
  UPDATE ge_spi_sol_reportes
     SET situacion = 'B'
   WHERE nro_referencia = v_nro_referencia;
   
   --inserta el registro en la tabla ge_spi_res_reportes para ir actualizando los estados que responde el BCP--
if v_nro_referencia is not null then
  insert into ge_spi_res_reportes
    (nro_referencia, id_peticion, estado, respuesta, fec_ult_consulta, error , formato)
  values
    (v_nro_referencia, null, 'inProcess', null, sysdate, null, v_formato);
end if;
  
  
EXCEPTION
   when ex_salir then
      p_nro_referencia   := null;
   when others then
      p_nro_referencia   := null;
END pr_gen_env_api_reporte;
procedure pr_gen_rec_api_reporte(p_nro_referencia  in ge_spi_res_reportes.nro_referencia%type,
                                 p_id_peticion     in ge_spi_res_reportes.id_peticion%type,
                                 p_estado          in ge_spi_res_reportes.estado%type,
                                 p_cod_err         out number,
                                 p_msj_error       in out varchar2) is
begin
  begin
    update ge_spi_res_reportes s
       set s.id_peticion = p_id_peticion, s.estado = p_estado , s.error = p_msj_error
     where s.nro_referencia = p_nro_referencia;
     
   --tratamos los estados de la tabla de solicitud segun lo que nos devuelve el servicio--
   --para los estados de error--
   if p_msj_error is not null then
     update ge_spi_sol_reportes s
        set s.situacion = 'C' -- se cancela el registro de solicitud
      where s.nro_referencia = p_nro_referencia;
   elsif p_msj_error is null and p_estado <> 'ready' then
     update ge_spi_sol_reportes s
        set s.situacion = 'V' --enviado a al BCP
      where s.nro_referencia = p_nro_referencia;
   end if;
   if sql%rowcount = 0 then
     p_cod_err:= 1000;
     p_msj_error := 'Error al actualizar el registro'||sqlerrm;
   else
     p_cod_err:= 0;
     p_msj_error := 'Ejecucion Existosa';
   end if;
  exception
    when others then
      p_cod_err:= 1001;
      p_msj_error := 'Error en el procedimiento pas_spi.pr_gen_rec_api_reporte'||sqlerrm;
  end;
end pr_gen_rec_api_reporte;

procedure pr_obt_reg_res_api(p_nro_referencia out ge_spi_res_reportes.nro_referencia%type,
                             p_id_peticion    out ge_spi_res_reportes.id_peticion%type,
                             p_estado         out ge_spi_res_reportes.estado%type,
                          --   p_respuesta      out ge_spi_res_reportes.respuesta%type,
                             p_fec_ult_con    out ge_spi_res_reportes.fec_ult_consulta%type,
                             p_formato        out ge_spi_res_reportes.formato%type) is

  cursor reg is
    select s.nro_referencia,
           s.id_peticion,
           s.estado,
         --  s.respuesta,
           s.fec_ult_consulta,
           s.formato
      from ge_spi_res_reportes s
     where s.estado in ('dispatched', 'inProcess')
       and s.id_peticion is not null --DA-7167
       and rownum = 1
     order by s.fec_ult_consulta asc;
begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar             := 'Lee datos del registro';

  FOR a IN reg LOOP
    p_nro_referencia  := a.nro_referencia;
    p_id_peticion     := a.id_peticion;
    p_estado          := a.estado;
  --  p_respuesta       := a.respuesta;
    p_fec_ult_con     := a.fec_ult_consulta;
    p_formato         := a.formato;
  end loop;

end pr_obt_reg_res_api;

procedure pr_rec_arc_api(p_nro_referencia in ge_spi_res_reportes.nro_referencia%type,
                         p_archivo        in ge_spi_res_reportes.respuesta%type,
                         p_cod_err        out number,
                         p_msj_error      out varchar2) is
begin
  begin
    update ge_spi_res_reportes s
       set s.respuesta = p_archivo, s.estado = 'ready'
     where s.nro_referencia = p_nro_referencia;
  
  --tratamos el estado finalizado exitosamente para la tabla de solicitudes
    update ge_spi_sol_reportes s
       set s.situacion = 'L' --situacion liquidado , procesado exitosamente
     where s.nro_referencia = p_nro_referencia;
     
  --apartado donde trataremos el envio de correo con el informe bajado desde la api
   --pas_spi.pr_gen_env_mail_api(p_nro_referencia , null);  --TCE-1870
   
   
    if sql%rowcount = 0 then
      p_cod_err   := 1000;
      p_msj_error := 'Error al actualizar el registro' || sqlerrm;
    else
      p_cod_err   := 0;
      p_msj_error := 'Ejecucion Existosa';
    end if;
  exception
    when others then
      p_cod_err   := 1001;
      p_msj_error := 'Error en el procedimiento pas_spi.pr_gen_rec_api_reporte' ||
                     sqlerrm;
  end;
end pr_rec_arc_api;

procedure pr_gen_env_mail_api(p_nro_referencia in ge_spi_res_reportes.nro_referencia%type,
                              p_correo         in varchar2) is                                     
  v_respuesta                 ge_spi_res_reportes.respuesta%type;
  v_nombre                    ge_spi_tip_reportes.nombre%type;
  v_usuario                   ge_spi_sol_reportes.usu_insercion%type;
  v_formato                   ge_spi_sol_reportes.formato%type;
  v_tipo                      ge_spi_sol_reportes.tip_reporte%type;
  v_destinatario              varchar2(100);
  v_remitente                 varchar2(100) := fug_obt_dir_correo;
  v_asunto                    varchar2(100) := 'Informes SPI';


  
begin
   select s.respuesta, a.nombre , t.usu_insercion, t.formato , t.tip_reporte
     into v_respuesta, v_nombre, v_usuario , v_formato , v_tipo
     from ge_spi_res_reportes s , ge_spi_sol_reportes t , ge_spi_tip_reportes a
    where s.nro_referencia = t.nro_referencia
      and TRIM(t.tip_reporte) = TRIM(a.cod_reporte)
      and s.nro_referencia = p_nro_referencia
      and s.estado = 'ready';
      
 if p_correo is null then
   v_destinatario := fug_obt_pardinamico('SPI_API_NOTIFICACIONES');
 else
   v_destinatario := p_correo;
 end if;        
    --se le llama al procedimiento de envio de email exclusivo del SPI
 begin
   it.prs_spi_send_mail(v_destinatario, 
                        v_remitente, 
                        v_asunto , 
                        'Se notifica en el adjunto el informe solicitado'||chr(10) ||
                        'Nombre Informe : '||v_nombre|| chr(10) ||
                        'Usuario solicitante : '||v_usuario|| chr(10) ||
                        'Formato solicitado : '||v_formato|| chr(10) ||
                        'Nro. Referencia : '||p_nro_referencia|| chr(10) ||
                        'Atentamente.'|| chr(10) ||
                        '---------------------------'|| chr(10) ||
                        '',
                        v_tipo||'.'||v_formato,
                        null,
                        v_respuesta);
 end;
end pr_gen_env_mail_api;
PROCEDURE pr_env_alerta(p_cod_persona in ba_personas.cod_persona%type,
                                   p_tip_producto in ge_mai_onb_templates.tip_producto%type,
                                   p_inf_json in ba_env_correos.parametros%type) IS
  /*
  || Envía alertas al Cliente
  */
  v_cod_persona     ba_personas.cod_persona%type:=p_cod_persona;
  v_dir_mail        ba_personas.dir_correo%type;
 begin
  g_lugar           := 'Envíando alerta, ';
  
  begin
    -- Busca la direccion de Correo del Cliente
    select b.dir_correo
      into v_dir_mail
      from ba_personas b, ge_clientes c
     where b.cod_persona = v_cod_persona
       and b.cod_persona = c.cod_persona;
  
  exception
    when others then
      v_dir_mail     := null;
  end;
   if v_dir_mail is not null then
           begin
             insert into it.ba_env_correos
               (cod_persona,
                tip_producto,
                estado,
                fec_registro,
                parametros,
                mai_destinatario)
             values
               (p_cod_persona,
                p_tip_producto,
                'P',
                sysdate,
                p_inf_json,
                v_dir_mail);
                
           exception
             when others then
                null;--ver para registrar en ba_log_mensajeria
           end;
  end if;
   
 exception
   when others then
    null;
      
end pr_env_alerta;
function fu_obt_tra_spi_notificacion(p_cod_moneda ge_snp_transferencias.cod_moneda%type, p_monto ge_snp_transferencias.monto%type,p_ind_pat varchar2 default 'N',p_cod_swift ge_snp_transferencias.cod_swi_pte_beneficiario%type,p_tipo varchar2 ) return varchar2 is
  /*
   || Obtiene si la transferencia enviada que se está procesando , debío ingresar por SPI,y se debe notificar en los sgtes casos
   || caso 2: redireccionar al ACH, debido a que el pte beneficiaro se encuentra temporalmente inactivo(no se encuentra certificado.)
   || caso 3: redireccionar al ACH, debido a que el pte emisor,se encuentra temporalmente inactivo
   || caso 4: redireccionar al LBTR, debido a que el pte emisor,se encuentra temporalmente inactivo
  */
   v_tra_spi    varchar2(1);
   v_hab_pte_hab_spi  varchar2(1);

BEGIN
   pas_spi.g_cod_error := 0;
   pas_spi.g_msj_error := NULL;
  
  if p_tipo='PBI' then --Participante beneficiario inactivo( caso2)
          g_lugar:='Busca si el pte se encuentra certificado';
         select nvl(v.ind_hab_pte_spi, 'N')
           into v_hab_pte_hab_spi
           from gv_snp_participantes v, ba_personas p
          where v.cod_persona = p.cod_persona
            and v.cod_swift = p_cod_swift;
        g_lugar:='Busca parametros dinamicos y los condiciona';
         if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' then
            v_tra_spi:='N';
         elsif pas_spi.fu_obt_est_hor_spi(fug_obt_pardinamico( 'COD_SPI_PCD' ),'001','002')='N' then
            v_tra_spi:='N';
         elsif p_ind_pat='S' then --si es patrocinador va por LBTR
            v_tra_spi:='N';
         elsif p_cod_moneda !=g_cod_mon_local then
            v_tra_spi:='N';

         elsif pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                        pag_gen.fu_obt_mon_local,
                                        p_monto
                                      ) <= fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) 
               and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' then
               v_tra_spi:='S';
         elsif   pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                        pag_gen.fu_obt_mon_local,
                                        p_monto
                                      ) > fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' then
            v_tra_spi:='N';
         end if;
         if v_tra_spi ='S'  then--debió ser SPI
           if v_hab_pte_hab_spi='N' then
             --si el participante no se encuentra certificado por BCP,debe indicar que debe notificar
             v_tra_spi:='S';--debe notificar
           end if;
           if v_hab_pte_hab_spi='S' then
             --si el participante se encuentra certificado por BCP,debe indicar que NO debe notificar
            v_tra_spi:='N';--no debe notificar, asegura validacion.
           end if;
         else
           v_tra_spi:='N';--no debe notificar , debio ir originalmente por LBTR
         end if;
   elsif p_tipo='PEI' then --Participante emisor inactivo( caso3)
           g_lugar:='Busca si el pte se encuentra certificado';
          select nvl(v.ind_hab_pte_spi, 'N')
           into v_hab_pte_hab_spi
           from gv_snp_participantes v, ba_personas p
          where v.cod_persona = p.cod_persona
            and v.cod_swift = p_cod_swift;
          g_lugar:='Busca parametros dinamicos y los condiciona';
         
          if pas_spi.fu_obt_est_hor_spi(fug_obt_pardinamico( 'COD_SPI_PCD' ),'001','002')='N' then
            v_tra_spi:='N';
          elsif p_ind_pat='S' then --si es patrocinador va por LBTR
            v_tra_spi:='N';
          elsif v_hab_pte_hab_spi='N' then --si el participante no se encuentra certificado por BCP, sigue por LBTR
            v_tra_spi:='N';
          elsif p_cod_moneda !=g_cod_mon_local then
            v_tra_spi:='N';

          elsif pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                        pag_gen.fu_obt_mon_local,
                                        p_monto
                                      ) <= fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) 
              /* and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S'*/ then
               v_tra_spi:='S';
          elsif   pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                        pag_gen.fu_obt_mon_local,
                                        p_monto
                                      ) > fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' then
            v_tra_spi:='N';
          end if;
         if v_tra_spi ='S'  then--debió ser SPI
           if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' then
             --si el participante emisor no se encuentra certificado por BCP( o se encuentra temporalmente inactivo,debe indicar que debe notificar
             v_tra_spi:='S';--debe notificar
           end if;
          if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' then
             --si el participante emisor se encuentra certificado por BCP,debe indicar que NO debe notificar
            v_tra_spi:='N';--no debe notificar, asegura validacion.
           end if;
         else
           v_tra_spi:='N';--no debe notificar , debio ir originalmente por LBTR
         end if;
   elsif p_tipo='PEP' then --Participante emisor (propio banco/financiera) con problemas de conexión en SPI
       g_lugar:='Busca si el pte se encuentra certificado';
          select nvl(v.ind_hab_pte_spi, 'N')
           into v_hab_pte_hab_spi
           from gv_snp_participantes v, ba_personas p
          where v.cod_persona = p.cod_persona
            and v.cod_swift = p_cod_swift;
          g_lugar:='Busca parametros dinamicos y los condiciona';
         
          if pas_spi.fu_obt_est_hor_spi(fug_obt_pardinamico( 'COD_SPI_PCD' ),'001','002')='N' then
            v_tra_spi:='N';
          elsif p_ind_pat='S' then --si es patrocinador va por LBTR
            v_tra_spi:='N';
          elsif v_hab_pte_hab_spi='N' then --si el participante no se encuentra certificado por BCP, sigue por LBTR
            v_tra_spi:='N';
          elsif p_cod_moneda !=g_cod_mon_local then
            v_tra_spi:='N';

          elsif pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                        pag_gen.fu_obt_mon_local,
                                        p_monto
                                      ) <= fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) 
              /* and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S'*/ then
               v_tra_spi:='S';
          elsif   pag_gen.fu_con_mon_a_moneda( p_cod_moneda,
                                        pag_gen.fu_obt_mon_local,
                                        p_monto
                                      ) > fug_obt_pardinamico( 'SPI_MTO_MAX_TRANSF' ) and nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' then
            v_tra_spi:='N';
          end if;
         if v_tra_spi ='S'  then--debió ser SPI
           if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='N' and nvl(fug_obt_pardinamico( 'SPI_DISP_BCP' ),'N')='S' then
             --Participante emisor (propio banco/financiera) con problemas de conexión en SPI, pero BCP arriba con SPI
             v_tra_spi:='S';--debe notificar y generar como pacs.008 sin redireccionar 
           end if;
          if nvl(fug_obt_pardinamico( 'SPI_ENVIO_TRANSF' ),'N')='S' and nvl(fug_obt_pardinamico( 'SPI_DISP_BCP' ),'N')='N'then
             --Participante emisor (propio banco/financiera) con problemas de conexión en SPI, pero BCP con problemas con SPI
            v_tra_spi:='N';--debe notificar y redireccionar LBTR/ACH 
           end if;
         else
           v_tra_spi:='X';--no debe notificar , debio ir originalmente por LBTR( casos mayores a 5mm , part.no certificados,etc)
         end if;
   end if;
   RETURN v_tra_spi;
exception
when others then
      PAS_SPI.g_cod_error := 160;
      PAS_SPI.g_msj_error := 'Error en PAS_SPI.fu_obt_tra_spi' || ' - ' ||g_lugar || ' - ' || sqlerrm;
      return 'N';
end fu_obt_tra_spi_notificacion;
/*
insertar registro en ge_spi_solicitudes
*/
procedure  pr_ins_sol_spi (p_reg ge_spi_solicitudes%rowtype,p_cod_solicitud out number) is
 pragma autonomous_transaction;
 v_uetr  ge_spi_solicitudes.uetr%type;
begin

   p_cod_solicitud :=it.s_cod_sol_spi.nextval;

   if p_reg.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_PAGO') and p_reg.fec_recepcion is null then
      v_uetr:=pas_spi.fu_obt_uetr(p_cod_solicitud);
   else
      v_uetr:=p_reg.uetr;
   end if;

   insert into ge_spi_solicitudes
   (cod_sol_spi, 
   nro_referencia, 
   nro_ref_msj_original, 
   nro_ref_externa,
   cod_msj_swift, 
   fec_recepcion, 
   est_notificacion, 
   est_solicitud,
   sit_solicitud,
   respuesta,
   monto,
   msj_mx,
   cod_moneda,
   nom_solicitante, 
   doc_solicitante, 
   tip_doc_solicitante, 
   cta_solicitante, 
   nom_beneficiario, 
   doc_beneficiario, 
   tip_doc_beneficiario, 
   cta_beneficiario, 
   nro_ref_solicitud, 
   uetr,
   cod_mot_solicitud,
   cod_swi_solicitante, 
   cod_swi_suc_solicitante, 
   cod_swi_beneficiario, 
   cod_swi_suc_beneficiario,
   tip_rechazo,
   cod_tip_operacion,
   info_remesa,
   info_envio,
   identificacion,
   cta_ben_recibido)
   values
   (p_cod_solicitud,
   p_reg.nro_referencia,
   p_reg.nro_ref_msj_original,
   p_reg.nro_ref_externa,
   p_reg.cod_msj_swift,
   p_reg.fec_recepcion,
   p_reg.est_notificacion,
   p_reg.est_solicitud,
   p_reg.sit_solicitud,
   p_reg.respuesta,
   p_reg.monto,
   p_reg.msj_mx,
   p_reg.cod_moneda,
   p_reg.nom_solicitante, 
   p_reg.doc_solicitante, 
   p_reg.tip_doc_solicitante, 
   p_reg.cta_solicitante, 
   p_reg.nom_beneficiario, 
   p_reg.doc_beneficiario, 
   p_reg.tip_doc_beneficiario, 
   p_reg.cta_beneficiario, 
   p_reg.nro_ref_solicitud, 
   v_uetr,
   p_reg.cod_mot_solicitud,
   p_reg.cod_swi_solicitante, 
   p_reg.cod_swi_suc_solicitante, 
   p_reg.cod_swi_beneficiario, 
   p_reg.cod_swi_suc_beneficiario,
   p_reg.tip_rechazo,
   p_reg.cod_tip_operacion,
   p_reg.info_remesa,
   p_reg.info_envio,
   p_reg.identificacion,
   p_reg.cta_ben_recibido);
   commit;
exception
   when others then
       pas_snp.pr_reg_operacion('Error al insertar solicitud: '||sqlerrm,'Nro. solicitud generada: '||p_cod_solicitud); 
       p_cod_solicitud:=null;
end;
/*
Actualizar registro en ge_spi_solicitudes
*/
procedure  pr_act_sol_spi (p_reg ge_spi_solicitudes%rowtype) is
 pragma autonomous_transaction;
begin
  update ge_spi_solicitudes sl
     set sl.est_notificacion = nvl(p_reg.est_notificacion, sl.est_notificacion),
         sl.est_solicitud    = nvl(p_reg.est_solicitud, sl.est_solicitud),
         sl.respuesta        = substr(sl.respuesta || ' ' || p_reg.respuesta,1,2000),
         sl.nro_referencia   = nvl(p_reg.nro_referencia, sl.nro_referencia),
         sl.nro_ref_externa  = nvl(p_reg.nro_ref_externa , sl.nro_ref_externa), 
         sl.nom_solicitante  = nvl(p_reg.nom_solicitante , sl.nom_solicitante),
         sl.doc_solicitante  = nvl(p_reg.doc_solicitante , sl.doc_solicitante),
         sl.tip_doc_solicitante = nvl(p_reg.tip_doc_solicitante, sl.tip_doc_solicitante),
         sl.cta_solicitante = nvl(p_reg.cta_solicitante, sl.cta_solicitante),
         sl.nom_beneficiario= nvl(p_reg.nom_beneficiario, sl.nom_beneficiario),
         sl.doc_beneficiario= nvl(p_reg.doc_beneficiario, sl.doc_beneficiario),
         sl.tip_doc_beneficiario =nvl(p_reg.tip_doc_beneficiario, sl.tip_doc_beneficiario),
         sl.cta_beneficiario = nvl(p_reg.cta_beneficiario , sl.cta_beneficiario),
         sl.cod_moneda       = nvl(p_reg.cod_moneda, sl.cod_moneda),
         sl.cod_mot_solicitud= nvl(p_reg.cod_mot_solicitud, sl.cod_mot_solicitud)
   where sl.cod_sol_spi = p_reg.cod_sol_spi;
  commit;
exception
   when others then
      pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||p_reg.cod_sol_spi);
end;
/*
cancelar transferencia
*/
procedure pr_can_transferencia(p_referencia in number, p_error in varchar2) is
   pragma autonomous_transaction;
begin
    update ge_snp_transferencias g
    set g.error=substr(p_error,1,4000),
    g.estado='P'
    where g.nro_referencia=p_referencia;
    commit;
exception
   when others then
       null;
end;
procedure pr_ini_var_spi is
begin
  v_cod_tra_padre       :=pas_snp.fu_obt_cod_tra_padre;
  v_cod_mod_padre       :=pas_snp.fu_obt_cod_mod_padre;
  v_cod_mad_padre       :=pas_snp.fu_obt_cod_mad_padre;
  v_cod_ofi_debito      :=null;
  v_cod_mod             :=0;
  v_cod_mad             :=0;
  v_est_cuenta          :=null;
  v_sal_disponible      :=null;
  v_procesa             :=null; 
  v_tra_deb             :=null;
end;
/*
Se aplican las validaciones que determinan si una tranf. SPI puede ser devuelta.
*/
procedure pr_val_dev_spi(p_ref_tra_original in varchar2,
                         p_mto_devolver     in number,
                         p_origen           in varchar2,
                         p_cod_retorno      out number,
                         p_men_retorno      out varchar2)is

r_gtran               pas_snp.rg_msj;
e_val                 exception;
v_nro_referencia      ge_snp_transferencias.nro_referencia%type;
v_can_dias            number(3):=0;
v_can_registro        number(5):=0;
v_can_conjunta        number(5):=0;
v_hab_solicitante     varchar2(1);
v_hab_beneficiario    varchar2(1);
v_can_otros           number(5):=0;

begin

      p_cod_retorno       :=0;
      p_men_retorno       :='OK'; 
      v_hab_solicitante   :=null;
      v_hab_beneficiario  :=null;
      pr_ini_var_spi;

       Begin
         select t.nro_referencia
         into v_nro_referencia
         from ge_snp_transferencias t
         where t.nro_ref_externa = p_ref_tra_original;
         --obtener el registro de la transferencia
         pas_snp.pr_ini_registros;
         pas_snp.pr_obt_mensaje (v_nro_referencia,'N');
         r_gtran := pas_snp.fu_obt_reg_transferencias;
         if pas_snp.fu_obt_cod_error!=0 then
             p_cod_retorno:=1;
             p_men_retorno:=pas_snp.fu_obt_msj_error;
             raise e_val;
         end if;
       exception
            when no_data_found then
                p_cod_retorno:=2;
                p_men_retorno:='No se encuentra la transferencia original para la Ref_externa: '||p_ref_tra_original;
                raise e_val;
       end;  

       --validaciones

       if r_gtran.fec_recepcion is null then
          p_cod_retorno:=3;
          p_men_retorno:='La referencia no corresponde a una transferencia recibida';
          return;
       end if;

       if r_gtran.cod_msj_swift!=fug_obt_pardinamico( 'COD_SPI_PCD' ) then
          p_cod_retorno:=4;
          p_men_retorno:='Solo se pueden devolver transferencias SPI';
          return;
       end if;

       if r_gtran.situacion!='L' and r_gtran.estado!='A' then
          p_cod_retorno:=5;
          p_men_retorno:='La transferencia inicial no se encuentra liquidada';
          return;
       end if;
       --monto a devolver 0 , rechazar solicitud
       if p_mto_devolver=0 then
          p_cod_retorno:=6;
          p_men_retorno:='Monto a devolver debe ser mayor a 0';
          return;
       end if;
       --el monto a devolver no puede ser superior al monto de la tranf. inicial
       if p_mto_devolver>r_gtran.monto then
          p_cod_retorno:=7;
          p_men_retorno:='Monto a devolver es superior al monto de la transferencia inicial';
          return;
       end if;
       --la transf. no puede ser devuelva si ya pasaron X dias desde su liquidacion
       v_can_dias:=fug_obt_pardinamico('SPI_MAX_DIA_DEVOLUCION');

       if trunc(sysdate)-r_gtran.fec_valor>v_can_dias then
          p_cod_retorno:=8;
          p_men_retorno:='La transferencia no puede ser devuelta porque ha superado los '||v_can_dias||' dias';
          return;
       end if;
       --si la transf. original ya fue devuelta, rechazar solicitud.
       begin
       select count(*)
       into v_can_registro
       from ge_spi_solicitudes sl
       where sl.nro_ref_msj_original=p_ref_tra_original
       and sl.cod_msj_swift in (fug_obt_pardinamico( 'COD_SPI_DEV'),
                                fug_obt_pardinamico( 'COD_SPI_SOL_DEV'))
       and sl.fec_recepcion is null
       and sl.est_solicitud in('A','S','U','W'); --Aprobado/Solicitado
       exception
         when no_data_found then 
           v_can_registro := 0;
       end;    

       if v_can_registro>0 then
          p_cod_retorno:=9;
          p_men_retorno:='La transferencia inicial ya fue devuelta';
          return;
       end if;

      pag_cta.pr_obt_cuenta(r_gtran.nro_cta_beneficiario);

      if pag_cta.g_ctas.nro_cuenta is null then
           p_cod_retorno :=10;
           p_men_retorno := 'Cuenta de debito inexistente';
           return;
       end if;

       v_cod_ofi_debito:=pag_cta.g_ctas.cod_oficina;
       ---Validaciones sobre la cuenta origen
       pag_cta.pr_ver_operacion(pag_cta.g_ctas.nro_cuenta, 
                                v_cod_tra_padre,
                                v_cod_mod_padre,v_cod_mad_padre, 'D',
                                pag_cta.g_ctas.cod_moneda, 
                                p_mto_devolver, 
                                v_cod_ofi_debito, 
                                v_cod_mod, 
                                v_cod_mad, 
                                v_est_cuenta, 
                                v_sal_disponible, 
                                v_procesa,v_tra_deb);
       if v_procesa='N' then
          p_cod_retorno := 11;
          p_men_retorno :=pag_cta.g_msj_error;
          return;
       end if;
       if p_origen <> 'I' then 
       --verifica si la cuenta de debito es conjunta
       Begin
       select count(*)
       into v_can_conjunta
       from ge_cta_clientes
       where nro_cuenta = pag_cta.g_ctas.nro_cuenta
       and relacion = 'Y';
       exception 
         when no_data_found then
           v_can_conjunta := 0;
       end;    

         if v_can_conjunta>0 then
            p_cod_retorno := 12;
            p_men_retorno := 'Cuenta conjunta, se requiere autorizacion de los firmantes';
            return;
         end if;
       end if;

       if pag_cta.fu_ver_tra_prohibida(pag_cta.g_ctas.nro_cuenta, v_cod_tra_padre,v_cod_mod_padre,v_cod_mad_padre) = 'S' then
          p_cod_retorno := 13;
          p_men_retorno := 'Transaccion prohibida para la cuenta debito';
          return;
       end if;

       --Valida Funcionalidad fase2
       v_hab_solicitante := fu_val_fun_fase2('SPI_PTE_CER_DEVOLUCION','S',r_gtran.cod_swi_pte_solicitante);

       if v_hab_solicitante = 'N' then
          p_cod_retorno:=14;
          p_men_retorno:='Funcionalidad no certificada para la entidad Solicitante.';
          return;
       end if;

       v_hab_beneficiario := fu_val_fun_fase2('SPI_PTE_CER_DEVOLUCION','S',r_gtran.cod_swi_pte_beneficiario);

       if v_hab_beneficiario = 'N' then
          p_cod_retorno:=15;
          p_men_retorno:='Funcionalidad no certificada para la entidad Beneficiaria.';
          return;
       end if;

       if r_gtran.cod_tip_operacion = '002' then 
          p_cod_retorno:=17;
          p_men_retorno:='No se puede hacer una devolución a un Sub-Participante.';
       end if;

       --si la transf. original es por otro tipo de solicitudes.
       Begin
       select count(*)
       into v_can_otros
       from ge_spi_solicitudes sl
       where sl.nro_ref_msj_original=p_ref_tra_original
       and sl.cod_msj_swift not in (fug_obt_pardinamico( 'COD_SPI_DEV'),
                                    fug_obt_pardinamico( 'COD_SPI_SOL_DEV')) 
       and sl.fec_recepcion is null ;
       exception
         when no_data_found then
           v_can_otros := 0;
       end;    

       if v_can_otros > 0 then
          p_cod_retorno:=18;
          p_men_retorno:='No se puede hacer una devolución, por una respuesta a otro tipo de solicitudes.';
          return;
       end if;
exception 
    when others then
        p_cod_retorno:=16;
        p_men_retorno:=sqlerrm;
end;
/*
Procesa el envío de pacs004 - Devolución de transferencia
*/
procedure pr_pro_env_004(p_ref_tra_original in varchar2,
                         p_mto_devolver     in number,
                         p_origen           in varchar2,
                         p_mot_rechazo      in varchar2,
                         p_modo             in varchar2,
                         p_reg_devolucion   out pas_snp.rg_msj,
                         p_cod_retorno      out number,
                         p_men_retorno      out varchar2,
                         p_cod_solicitud    in out number,
                         p_usuario          in varchar2) is

 rg_msj                ge_snp_transferencias%rowtype;
 e_val                 exception; 
 v_est_inicial         ba_modulos.estado%type;
 v_est_actual          ba_modulos.estado%type;
 r_gtran               pas_snp.rg_msj;
 v_nro_referencia      ge_snp_transferencias.nro_referencia%type;
 v_tip_mensaje         ge_snp_transferencias.cod_msj_swift%type:=fug_obt_pardinamico( 'COD_SPI_DEV');
 c_tra_debito          constant number(5):=503;
 v_cod_tra_credito     ge_movimientos.cod_transaccion%type;
 v_nro_secuencia       ge_movimientos.nro_secuencia%type:=0;
 v_hor_mov             ge_movimientos.hora%type;
 v_cta_pte_solicitante varchar2(20); -- Nro de Cuenta Interbancaria
 v_cta_pte_sol_bcp     varchar2(20);
 v_estado              ge_snp_transferencias.estado%type;
 v_tip_movimiento      ge_movimientos.tip_mov_rubro%type;
 rg_sol                ge_spi_solicitudes%rowtype;
 r_gmovim              ge_movimientos%rowtype;
--TRFS-1381 Inicio 
-- v_tip_operacion       ge_snp_par_mensajes.cod_tip_operacion%type;
-- v_sub_tip_operacion   ge_snp_par_mensajes.cod_sub_tip_operacion%type;
--TRFS-1381 Fin

begin
       p_cod_retorno         :=0;
       p_men_retorno         :='OK';                 
       pr_ini_var_spi;

       --P_MODO:  A (Autoriza) - R (Registra) - C (Completo: registra y autoriza)
       if p_modo in ('C','R') then
          rg_sol.cod_msj_swift        := v_tip_mensaje;
          rg_sol.fec_recepcion        := null;
          rg_sol.est_notificacion     := 'X';
          rg_sol.est_solicitud        := 'S';
          rg_sol.sit_solicitud        := 'P';
          rg_sol.nro_ref_msj_original := p_ref_tra_original;
          rg_sol.monto                := p_mto_devolver;
          pr_ins_sol_spi(rg_sol,p_cod_solicitud);
          rg_sol.est_notificacion := null;
       end if;

       rg_sol.cod_sol_spi :=p_cod_solicitud;

--TRFS-1381 Inicio
/*
       --Recupero tipo y sub_tipo de operacion para un pacs.004 directo
       begin
           select m.cod_tip_operacion, m.cod_sub_tip_operacion
            into v_tip_operacion, v_sub_tip_operacion
            from ge_snp_par_mensajes m
           where m.cod_msj_swift = v_tip_mensaje
             and m.tipo = g_pac_004; 
       exception
         when no_data_found then
           pas_spi.g_cod_error := 16;
           g_nom_respuesta := 'No se encuentra Codigo de Tipo y Subtipo de operacion - Mensaje: '||v_tip_mensaje||' Tipo: '||g_pac_004;
           pas_spi.g_msj_error := g_nom_respuesta;
       end; 
*/
--TRFS-1381 Fin
       begin
            select *
            into rg_msj
            from ge_snp_transferencias tf 
            where tf.nro_ref_externa=p_ref_tra_original;
       exception
             when no_data_found then
                 p_cod_retorno:=17;
                 p_men_retorno:='No se encuentra la transf. a devolver: '||p_ref_tra_original;
                 raise e_val;
       end;

       lp_ver_horario(3); 
       v_est_inicial:=g_mod_estado;
       if g_mod_estado in (1,6) then
          p_cod_retorno:=18;
          p_men_retorno:='Entidad en proceso de cierre, vuelva a intentar';
          raise e_val;
       end if;
       --datos de la cuenta de debito
       pag_cta.pr_obt_cuenta(rg_msj.nro_cta_beneficiario);

       if pag_cta.g_ctas.nro_cuenta is null then
           p_cod_retorno :=19;
           p_men_retorno := 'Cuenta de debito inexistente';
           raise e_val;
       end if;
       v_cod_ofi_debito:=pag_cta.g_ctas.cod_oficina;
       ---Validaciones sobre la cuenta origen
       pag_cta.pr_ver_operacion(pag_cta.g_ctas.nro_cuenta, 
                                v_cod_tra_padre,
                                v_cod_mod_padre,v_cod_mad_padre, 'D',
                                pag_cta.g_ctas.cod_moneda, 
                                p_mto_devolver, 
                                v_cod_ofi_debito, 
                                v_cod_mod, 
                                v_cod_mad, 
                                v_est_cuenta, 
                                v_sal_disponible, 
                                v_procesa,v_tra_deb);
       if v_procesa='N' then
          p_cod_retorno := 10;
          p_men_retorno :=pag_cta.g_msj_error;
          raise e_val;
       end if;

       if pag_cta.fu_ver_tra_prohibida(pag_cta.g_ctas.nro_cuenta, v_cod_tra_padre,v_cod_mod_padre,v_cod_mad_padre) = 'S' then
          p_cod_retorno := 21;
          p_men_retorno := 'Transaccion prohibida para la cuenta debito';
          raise e_val;
       end if;

        v_cta_pte_sol_bcp     :=  pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),rg_msj.cod_moneda);

        if v_cta_pte_sol_bcp is null then
           p_cod_retorno:='22';
           p_men_retorno:='Falta configurar la cuenta del participante solicitante';
           raise e_val;
        end if;

        pas_snp.pr_ini_variables;
        v_cta_pte_solicitante :=  pas_snp.fu_obt_cta_bancaria(v_cta_pte_sol_bcp ,'C');

        if p_modo in ('C','R') then
           --carga de valores para insertar el registro
           v_nro_referencia                 := pas_snp.fu_obt_sig_nro_referencia(g_fec_actual_h) ;
           r_gtran.nro_referencia           := v_nro_referencia;
           r_gtran.cod_msj_swift            := v_tip_mensaje;
           --TRFS-1381 Inicio           
           r_gtran.cod_tip_operacion        := rg_msj.cod_tip_operacion;
           r_gtran.cod_sub_tip_operacion    := rg_msj.cod_sub_tip_operacion;
           --TRFS-1381 Fin
           r_gtran.fec_valor                := g_fec_valor;
           r_gtran.nro_cta_solicitante      := pag_cta.g_ctas.nro_cuenta;
           r_gtran.nro_cta_pte_solicitante  := rg_msj.nro_cta_pte_beneficiario;
           r_gtran.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
           r_gtran.nro_cta_beneficiario     := rg_msj.nro_cta_solicitante;
           r_gtran.cod_swi_suc_beneficiario := rg_msj.cod_swi_suc_solicitante;
           r_gtran.cod_moneda               := rg_msj.cod_moneda;
           r_gtran.monto                    := p_mto_devolver ;
           r_gtran.cod_modulo               := rg_msj.cod_modulo;
           r_gtran.cod_modalidad            := rg_msj.cod_modalidad;
           r_gtran.cod_oficina              := pag_cta.g_ctas.cod_oficina;
           r_gtran.fec_ingreso              := g_fec_actual_h;
           r_gtran.cod_per_solicitante      := rg_msj.cod_per_beneficiario;
           r_gtran.nom_solicitante          := fue_obt_nom_persona(rg_msj.cod_per_beneficiario);
           r_gtran.dir_solicitante          := fue_obt_dir_principa(rg_msj.cod_per_beneficiario);
           r_gtran.cod_tip_doc_solicitante  := fue_obt_doc_principal(rg_msj.cod_per_beneficiario);
           r_gtran.nro_doc_solicitante      := fue_obt_nro_doc_persona(rg_msj.cod_per_beneficiario);
           r_gtran.nom_beneficiario         := rg_msj.nom_solicitante;
           r_gtran.dir_beneficiario         := rg_msj.dir_solicitante;
           r_gtran.cod_tip_doc_beneficiario := rg_msj.cod_tip_doc_solicitante;
           r_gtran.nro_doc_beneficiario     := rg_msj.nro_doc_solicitante;
           r_gtran.nro_cta_pte_beneficiario := rg_msj.nro_cta_pte_solicitante;
           r_gtran.cod_swi_pte_beneficiario := rg_msj.cod_swi_pte_solicitante;
           r_gtran.observacion              := null;
           r_gtran.ind_valor                := 'S';
           r_gtran.nro_ref_externa          := pas_spi.fu_obt_sig_nro_ref_externa;
           r_gtran.tip_cargo                := fue_obt_val_max_referencia('TIP_CAR_SIPAP', r_gtran.cod_msj_swift||'-'||rg_msj.cod_moneda);
           r_gtran.situacion                := 'P' ; -- Pendiente de Envio a BCP
           r_gtran.estado                   := 'S' ;
           r_gtran.nro_operacion            := v_nro_referencia ;
           r_gtran.tip_mensaje              := 'CRED' ;
           r_gtran.origen                   := p_origen;
           r_gtran.plataforma               := 'S';
           r_gtran.concepto                 := 'Dev.'||' '||p_ref_tra_original;
           r_gtran.indemnizado              := 'N';
           r_gtran.prioridad                := fus_snp_obt_prioridad(r_gtran.cod_msj_swift, r_gtran.cod_tip_operacion, r_gtran.cod_sub_tip_operacion);
           r_gtran.tip_rechazo               := p_mot_rechazo;

           pas_snp.pr_ini_variables;
           pas_snp.pr_ins_transferencias(r_gtran);
           p_reg_devolucion := r_gtran;

           if pas_snp.fu_obt_cod_error!=0 then
              p_cod_retorno:=23;
              p_men_retorno:=pas_snp.fu_obt_msj_error;
              raise e_val;
           else
              rg_sol.nro_referencia:= v_nro_referencia;
              rg_sol.nro_ref_externa := r_gtran.nro_ref_externa; 
              rg_sol.nom_solicitante := r_gtran.nom_solicitante;
              rg_sol.doc_solicitante := r_gtran.nro_doc_solicitante;
              rg_sol.tip_doc_solicitante := r_gtran.cod_tip_doc_solicitante;
              rg_sol.cta_solicitante := r_gtran.nro_cta_solicitante;
              rg_sol.nom_beneficiario:= r_gtran.nom_beneficiario;
              rg_sol.doc_beneficiario:= r_gtran.nro_doc_beneficiario;
              rg_sol.tip_doc_beneficiario :=r_gtran.cod_tip_doc_beneficiario;
              rg_sol.cta_beneficiario := r_gtran.nro_cta_beneficiario;
              rg_sol.cod_moneda       := r_gtran.cod_moneda;
              rg_sol.cod_mot_solicitud:= p_mot_rechazo;
              pr_act_sol_spi(rg_sol);
           end if;
        end if;

        if p_modo='A' then
           begin
                select sl.nro_referencia
                into v_nro_referencia
                from ge_spi_solicitudes sl
                where sl.cod_sol_spi=p_cod_solicitud;
                --obtener el registro de la transferencia
                pas_snp.pr_ini_registros;
                pas_snp.pr_obt_mensaje (v_nro_referencia, 'N'  );
                p_reg_devolucion := pas_snp.fu_obt_reg_transferencias;
                r_gtran:=p_reg_devolucion;
                if pas_snp.fu_obt_cod_error!=0 then
                    p_cod_retorno:=24;
                    p_men_retorno:=pas_snp.fu_obt_msj_error;
                    raise e_val;
                end if;
           exception
                when no_data_found then
                    p_cod_retorno:=25;
                    p_men_retorno:='No se encuentra la transferencia para la solicitud N° '||p_cod_solicitud;
                    raise e_val;
           end;
        end if;

       if p_modo in ('A','C') then
          --se vuelve a verificar si el estado inicial del modulo cambió
          v_est_actual:=pae_cnf.fu_obt_est_modulo(3);
          if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
             p_cod_retorno:=26;
             p_men_retorno:='Entidad en proceso de cierre, vuelva a intentar';
             raise e_val;
          end if;
          --generar los movimientos
          v_hor_mov:= fug_obt_mov_hora;
          if g_es_mov_noc='N' then
             if p_origen='I' then  --por ITGF
                v_estado:='S';
             else -- por HB
                v_estado:='U';
             end if;
             pas_snp.pr_ini_variables;
             pas_snp.pr_obt_par_mensajes(r_gtran.cod_msj_swift,    -- Tipo MT
                                         r_gtran.cod_tip_operacion,  -- Tipo de Operación
                                         r_gtran.cod_sub_tip_operacion,  -- Sub-Tipo de Operación
                                         'E',    -- Transferencia Enviada
                                         v_cod_mod_padre,
                                         v_cod_mad_padre,
                                         v_cod_tra_credito);

             if pas_snp.fu_obt_cod_error!=0 then
                p_cod_retorno:=27;
                p_men_retorno:=pas_snp.fu_obt_msj_error;
                raise e_val;
             end if;
             pag_cta.g_horario := 'D';
             --setea variables del pag_cta
             pag_cta.pr_set_variables(NVL(p_usuario,user),
                                      g_fec_valor,
                                      v_cod_tra_padre, 'N', 'N',
                                      v_nro_secuencia) ;

             --debito a la cuenta del cliente
             pag_cta.pr_act_operacion(pag_cta.g_ctas.nro_cuenta , -- Nro.Cta.
                                      v_hor_mov, -- Hora
                                      'D', -- Tip.Mov.
                                      pag_cta.g_ctas.cod_moneda, -- Cod.Mon.
                                      p_mto_devolver, -- Monto
                                      v_cod_tra_padre,-- Trx.Padre
                                      c_tra_debito,-- Trx.Hija
                                      v_nro_referencia,  -- Nro.Doc.
                                      null,-- Cotizacion
                                      pag_cta.g_ctas.cod_oficina, -- Ofic.Orig.
                                      v_cod_mod_padre, -- Mod.Pad.Cliente
                                      v_cod_mad_padre, -- Mad.Pad.Cliente
                                      NULL,            -- Cod.Tasa
                                      NULL,            -- Val.Tasa
                                      r_gtran.concepto, -- Concepto
                                      'S',              -- Emit.Aviso
                                      v_nro_secuencia,
                                      g_fec_valor,
                                      null,   -- Cod_Banco
                                      null,   -- Cod_Causa
                                      null);

             if pag_cta.fu_obt_cod_error != 0 then
                p_cod_retorno:=28;
                p_men_retorno:=pag_cta.fu_obt_msj_error;
                raise e_val;
             else
               v_est_actual:=pae_cnf.fu_obt_est_modulo(3);
               if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
                  p_cod_retorno:=29;
                  p_men_retorno:='Entidad en proceso de cierre, vuelva a intentar';
                  raise e_val;
               end if;
               v_tip_movimiento := pas_snp.fu_obt_tip_mov_transaccion(v_cod_mod_padre,v_cod_mad_padre,v_cod_tra_credito) ;
               --credito a la interbancaria
               pag_cta.pr_obt_cuenta(v_cta_pte_solicitante);                    
               r_gmovim.nro_secuencia   := v_nro_secuencia+1;             
               r_gmovim.cod_usuario     := user;
               r_gmovim.nro_cuenta      := v_cta_pte_solicitante;
               r_gmovim.hora            := v_hor_mov;
               r_gmovim.fecha           := g_fec_actual_h;
               r_gmovim.cod_transaccion := v_cod_tra_credito;
               r_gmovim.cod_modulo      := pag_cta.g_ctas.cod_modulo;
               r_gmovim.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
               r_gmovim.cod_oficina     := pag_cta.g_ctas.cod_oficina;
               r_gmovim.cod_moneda      := pag_cta.g_ctas.cod_moneda;
               r_gmovim.nro_documento   := v_nro_referencia;
               r_gmovim.fec_valor       := g_fec_valor;
               r_gmovim.cod_tra_padre   := v_cod_tra_padre;
               r_gmovim.cod_mod_padre   := v_cod_mod_padre;
               r_gmovim.cod_mad_padre   := v_cod_mad_padre;
               r_gmovim.monto           := p_mto_devolver;
               r_gmovim.cod_ofi_origen  := v_cod_ofi_debito; 
               r_gmovim.emi_aviso       := 'S';
               r_gmovim.estado          := 'N';
               r_gmovim.reversado       := 'N';
               r_gmovim.cod_rubro       := pac_che.fu_obt_rub_cta_ban(v_cta_pte_solicitante);
               r_gmovim.tip_mov_rubro   := v_tip_movimiento;
               r_gmovim.cotizacion      := null;
               r_gmovim.mto_equ_local   := null;
               r_gmovim.referencia      :=r_gtran.cod_swi_pte_beneficiario;
               r_gmovim.concepto        :=r_gtran.concepto;
               pag_gen.pr_ins_ge_movimiento(r_gmovim,'N');
           end if;

           IF v_nro_referencia is not null then
           update ge_snp_transferencias tf
           set tf.fecha=g_fec_actual_h,
           tf.hora=v_hor_mov,
           tf.cod_usuario=user,
           tf.estado=v_estado
           where tf.nro_referencia=v_nro_referencia;
           IF sql%notfound THEN
              pas_snp.pr_reg_operacion('Error al intentar actualizar la Transferencia: '||sqlerrm,'Referencia Nro.: '||v_nro_referencia);
           END IF;
           END IF;

         else
           --generación de movimientos nocturnos
            v_estado:='A';
            prg_gen_mov_noc_spi(p_mto_devolver,
                                rg_msj.nro_cta_beneficiario,
                                v_cta_pte_solicitante,
                                rg_msj.cod_moneda,
                                r_gtran.cod_msj_swift,
                                r_gtran.cod_tip_operacion,
                                r_gtran.cod_sub_tip_operacion,
                                v_nro_referencia,
                                r_gtran.nro_ref_externa,
                                r_gtran.cod_swi_pte_beneficiario,
                                'E',
                                'N',
                                 null,
                                 null,
                                 null,
                                 null,
                                 null,
                                 p_cod_retorno,
                                 p_men_retorno,
                                 p_ref_tra_original);

                if p_cod_retorno!=0 then
                   raise e_val;
                end if;
        end if;

        v_est_actual:=pae_cnf.fu_obt_est_modulo(3);

        if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
            p_cod_retorno:=30;
            p_men_retorno:='Entidad en proceso de cierre, vuelva a intentar';
            raise e_val;
        end if;
      end if;

exception
  when e_val then
       rg_sol.est_solicitud    := 'C';
       rg_sol.respuesta        :=substr(p_men_retorno,1,2000);
       pr_act_sol_spi(rg_sol);
  when others then
       p_cod_retorno           :=31;
       p_men_retorno           :=substr(sqlerrm,1,2000);
       rg_sol.est_solicitud    := 'C';
       rg_sol.respuesta        :=substr(sqlerrm,1,2000);
       pr_act_sol_spi(rg_sol);
end pr_pro_env_004;
/*
Determina si la transferencia corresponde a un sub-participante
*/
function fu_val_tra_subpte(p_tipo in varchar2,p_sub_tipo in varchar2) return boolean is
v_cant number(5):=0;
begin

  select count(*)
  into v_cant
  from ba_cod_referencias r
  where r.dominio='TIP_OPE_SUBPTE'
  and r.val_minimo=p_tipo
  and r.val_maximo=p_sub_tipo;

  if v_cant>0 then
      return true;
  else
      return false;
  end if;
exception
     when others then
        return false;
end;
/* */
procedure pr_obt_tra_pen_004(p_dat_cabecera out typ_ObtdatCabecera,p_dat_transferencias out typ_ObtTransPendiente004,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa transferencias pendientes de ENVIO al SPI, de tipo pacs.004(Devolucion de pago de Crédito Directo(SPI))
  */
  v_nro_referencia    ge_snp_transferencias.nro_referencia%type:= NULL;
  v_nro_ref_externa   ge_snp_transferencias.nro_ref_externa%type:= NULL;
  v_cant              number(8) := 0 ;
  v_tipo_ben_devol    varchar2(10);
  v_tipo_sol_devol    varchar2(10);
  v_tipo_ben_orig     varchar2(10);
  v_tipo_sol_orig     varchar2(10);
  v_des_mot_rechazo   varchar2(240);
  v_tip_msj_orig      varchar2(240);--tipo mensaje
  v_tip_msj_orig_ver  varchar2(20);--version del tipo de mensaje
  transferencia typ_ObtTransPendiente004 := typ_ObtTransPendiente004(null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     0,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,0,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null,null,
                                                                     null);
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_tra IS
    SELECT a.nro_referencia nro_referencia,--Obtener la referencia del campo ge_snp_transferencias.nro_ref_externa del pacs.004 generado.
           a.nro_ref_externa,
           a.fecha fec_devolucion,--Obtener la fecha del campo ge_snp_transferencias.fecha del pacs.004 generado.
           a.hora hor_devolucion,--Obtener la hora del campo ge_snp_transferencias.hora  del pacs.004 generado. 
           e.nro_ref_msj_original nro_ref_original,--Obtener de ge_spi_solicitudes.nro_ref_msj_original  del pacs.008 original.
           'pacs.008.001.10' tip_msj_original, -- o variable Obtener ge_spi_cab_versiones.version del pacs.008 original.
           trunc(a8.fec_recepcion) fec_original, --Obtener de ge_snp_transferencias.fecha del pacs.008 relacionado.
           to_char(a8.fec_recepcion,'HH24:MI:SS') hor_original, --Obtener de ge_snp_transferencias.hora del pacs.008 original.
           a8.nro_lote id_tra_original, --Obtener de ge_snp_transferencias.nro_lote del pacs.008 original.
           a8.fec_valor fec_valor_original,--Obtener de ge_snp_transferencias.fec_valor del pacs.008 original.
           d.cod_mon_iso mon_devolucion, --Obtener el código de moneda del pacs.004 a enviar de ge_snp_transferencias.cod_moneda en formato ISO.
           a.monto monto_devolucion,--Obtener el monto de ge_snp_transferencias.monto del pacs.004 a enviar.
           a.fec_valor fec_valor_devolucion, --Obtener el campo ge_snp_transferencias.fec_valor del pacs.004 a enviar.
           a.cod_swi_pte_solicitante swi_pte_sol_devolucion, --BIC del participante emisor, tomar desde ge_snp_transferencias.cod_swi_pte_solicitante para el pacs.004 a enviar.
           --pongo en variable tip_pte_sol_devolucion, Tipo de participante emisor de la devolución BA para bancos, PS para financieras
           null tip_pte_sol_devolucion,
           a.cod_swi_pte_beneficiario swi_pte_ben_devolucion,--BIC del participante receptor, obtener de ge_snp_transferencias.cod_swi_pte_beneficiario para el pacs.004 a enviar.
           --pongo en variable tip_pte_ben_devolucion, Tipo de participante emisor de la devolución BA para bancos, PS para financieras
           null tip_pte_ben_devolucion,
           --Obtener código de ge_snp_transferencias.tip_rechazo  del pacs.004 generado
           case when e.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_DEV') then e.cod_mot_solicitud else a.tip_rechazo end cod_mot_devolucion,
           null des_mot_devolucion,--Obtener descripción de ba_cod_referencias.abreviatura según relación ge_snp_transferencias.tip_rechazo=ba_cod_referencias.val_minimo  del pacs.004 generado donde el dominio = 'TIP_REC_SPI_P04' 
           d8.cod_mon_iso mon_original,--Tomar el código de moneda de ge_snp_transferencias.cod_moneda en formato ISO del pacs.008 original.
           a8.monto monto_original,--Tomar el monto de ge_snp_transferencias.monto del pacs.008 original.
           a8.nom_solicitante nom_solicitante,--Obtener el nombre del cliente emisor del pacs.008 original del campo ge_snp_transferencias.nom_solicitante
           a8.nro_doc_solicitante nro_doc_solicitante,--Obtener el nro de documento del cliente emisor del pacs.008 original del campo ge_snp_transferencias.nro_doc_solicitante
           b8.abreviatura cod_tip_doc_solicitante,--Obtener el tipo de documento del cliente emisor del pacs.008 original del campo ba_tip_documentos.abreviatura según ge_snp_transferencias.cod_tip_doc_solicitante (tipo de documento en formato SWIFT)
           a8.nro_cta_solicitante nro_cta_solicitante,
           fus_obt_nom_sub_participante(a8.cod_swi_pte_beneficiario,a8.cod_swi_suc_beneficiario) des_suc_sol_solicitante,--Obtener el nombre del sub participante emisor de la transferencia original del campo ge_snp_patrocinador_det.subparticipante
           --Enviar null en caso de que ge_snp_transferencias.cod_tip_operacion = 001 para el pacs.004 generado, tomar los valores mencionados solo si ge_snp_transferencias.cod_tip_operacion = 002
           a8.cod_swi_suc_solicitante swi_suc_pte_sol_original,--Obtener el BIC del sub participante emisor del pacs.008 original del campo ge_snp_transferencias.cod_swi_suc_solicitante
           --Enviar null en caso de que ge_snp_transferencias.cod_tip_operacion = 001 para el pacs.004 generado, tomar los valores mencionados solo si ge_snp_transferencias.cod_tip_operacion = 002
           a8.nro_cta_suc_pte_solicitante cta_suc_pte_sol_original,--Obtener la cuenta del sub participante emisor del pacs.008 original del campo ge_snp_transferencias.nro_cta_suc_pte_solicitante.
           --Enviar null en caso de que ge_snp_transferencias.cod_tip_operacion = 001 para el pacs.004 generado, tomar los valores mencionados solo si ge_snp_transferencias.cod_tip_operacion = 002
           a8.cod_swi_pte_solicitante swi_pte_solicitante,--Obtener el BIC del participante emisor del pacs.008 original del campo ge_snp_transferencias.cod_swi_pte_solicitante
           null tip_pte_solicitante,--Enviar el tipo de participante desde gv_snp_participantes.tipo teniendo en cuenta el cod_swift. BA para bancos, PS para financieras
           a8.nro_cta_pte_solicitante cta_pte_solicitante,--Obtener la cuenta del participante emisor del pacs.008 original del campo ge_snp_transferencias.nro_cta_pte_solicitante.
           a8.cod_swi_pte_beneficiario swi_pte_beneficiario,--Obtener el BIC del participante receptor del pacs.008 original del campo ge_snp_transferencias.cod_swi_pte_beneficiario.
           null tip_pte_beneficiario,--Enviar el tipo de participante desde gv_snp_participantes.tipo teniendo en cuenta el cod_swift BA para bancos, PS para financieras
           a8.nro_cta_pte_beneficiario cta_pte_beneficiario,--Obtener la cuenta del participante receptor del pacs.008 original del campo ge_snp_transferencias.nro_cta_pte_beneficiario.
           a8.nom_beneficiario nom_beneficiario,--Obtener el nombre del cliente receptor del pacs.008 original del campo ge_snp_transferencias.nom_beneficiario.
           a8.nro_doc_beneficiario nro_doc_beneficiario,--Obtener el nro. de documento del cliente receptor del pacs.008 original del campo ge_snp_transferencias.nro_doc_beneficiario.
           c8.abreviatura cod_tip_doc_beneficiario,--Obtener el tipo de documento del cliente receptor del pacs.008 original del campo ba_tip_documentos.abreviatura según ge_snp_transferencias.cod_tip_doc_beneficiario (tipo de documento en formato SWIFT).
           a8.nro_cta_ben_recibido nro_cta_beneficiario,
           a.cod_tip_operacion cod_tip_operacion,--SPI Fase 2
           a8.cod_msj_swift cod_msj_swift_original,
           case when e.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_DEV') then e.nro_ref_externa else NULL end nro_ref_solicitud
      from ge_snp_transferencias a,
           ba_tip_documentos     b,
           ba_tip_documentos     c,
           ba_monedas            d,
           ge_spi_solicitudes    e,
           ge_snp_transferencias a8,
           ba_monedas            d8,
           ba_tip_documentos     b8,
           ba_tip_documentos     c8
     where a.cod_tip_doc_solicitante = b.cod_tip_documento
       and a.cod_tip_doc_beneficiario = c.cod_tip_documento
       and a.cod_moneda = d.cod_moneda
       and a.estado = 'U'
       and a.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_DEV' )
       and a.situacion not in ('B', 'N','C', 'L','V') --No sean bloqueado, Evitar reenvio SPI, Cancelado,Liquidado, Enviado al BCP
       and a.fec_recepcion is null
       and to_char(substr(a.concepto,6,38)) = e.nro_ref_msj_original
       and e.nro_ref_msj_original = a8.nro_ref_externa
       and a8.situacion = 'L'
       and a8.estado = 'A'
       and a8.cod_moneda = d8.cod_moneda
       and a8.cod_tip_doc_solicitante = b8.cod_tip_documento
       and a8.cod_tip_doc_beneficiario = c8.cod_tip_documento
       and rownum=1
       order by a.nro_referencia asc
    for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe pacs.004';
  FOR a IN cu_msj_tra LOOP
    v_nro_referencia:=a.nro_referencia;
    v_nro_ref_externa:= a.nro_ref_externa;
    --Recupera tipo de participantes de la devolución
    begin
      g_lugar:='Busca tipo Pte. Solicitante';
      select tipo
        into v_tipo_sol_devol
        from gv_snp_participantes
       where cod_swift = a.swi_pte_sol_devolucion;
    exception
      when no_data_found then
        v_tipo_sol_devol := null;
      when others then
        v_tipo_sol_devol := null;
    end;
    begin
      g_lugar:='Busca tipo Pte. Beneficiario';
      select tipo
        into v_tipo_ben_devol
        from gv_snp_participantes
       where cod_swift = a.swi_pte_ben_devolucion;
    exception
      when no_data_found then
        v_tipo_ben_devol := null;
      when others then
        v_tipo_ben_devol := null;
    end;
    --Recupera tipo de participantes de la trasnferencia original
    begin
      g_lugar:='Busca tipo Pte. Solicitante Tran.Orig';
      select tipo
        into v_tipo_sol_orig
        from gv_snp_participantes
       where cod_swift = a.swi_pte_solicitante;
    exception
      when no_data_found then
        v_tipo_sol_orig := null;
      when others then
        v_tipo_sol_orig := null;
    end;
    begin
      g_lugar:='Busca tipo Pte. Beneficiario Tran.Orig';
      select tipo
        into v_tipo_ben_orig
        from gv_snp_participantes
       where cod_swift = a.swi_pte_beneficiario;
    exception
      when no_data_found then
        v_tipo_ben_orig := null;
      when others then
        v_tipo_ben_orig := null;
    end;
    --Recupera Motivo de Rechazo
    begin
      g_lugar:='Recupera Desc. Motivo de Rechazo';
      select substr(t.abreviatura,1,35)
      into v_des_mot_rechazo
      from ba_cod_referencias t
      where t.dominio = 'TIP_REC_SPI_P04'
      and t.val_minimo = a.cod_mot_devolucion ;
    exception
      when no_data_found then
        v_des_mot_rechazo := null;
      when others then
        v_des_mot_rechazo := null;
    end;
    --Recupero tipo de mensaje original en formato version
    begin
      g_lugar:='Recupero tipo de mensaje original en formato version';
      Select t.abreviatura
      into v_tip_msj_orig
      from ba_cod_referencias t
      where t.dominio = 'COD_MSJ_SWIFT'
      and t.significado = a.cod_msj_swift_original;
    exception
      when no_data_found then
        v_tip_msj_orig := null;
      when others then
        v_tip_msj_orig := null;
    end;
    --Recupero version del tipo de mensaje original
    begin
      g_lugar:='Recupero version del tipo de mensaje original';
      Select t.version
      into v_tip_msj_orig_ver
      from ge_spi_cab_versiones t
      where t.tipo_msj = v_tip_msj_orig;
    exception
      when no_data_found then
        v_tip_msj_orig_ver := null;
      when others then
        v_tip_msj_orig_ver := null;
    end;

    --Cargo el type con los valores a enviar
    transferencia := typ_ObtTransPendiente004(a.nro_ref_externa,
                                               a.fec_devolucion,
                                               a.hor_devolucion,
                                               a.nro_ref_original,
                                               v_tip_msj_orig_ver,
                                               a.fec_original,
                                               a.hor_original,
                                               a.id_tra_original,
                                               a.fec_valor_original,
                                               a.mon_devolucion,
                                               a.monto_devolucion,
                                               a.fec_valor_devolucion,
                                               a.swi_pte_sol_devolucion,
                                               v_tipo_sol_devol,
                                               a.swi_pte_ben_devolucion,
                                               v_tipo_ben_devol,
                                               a.cod_mot_devolucion,
                                               v_des_mot_rechazo,
                                               a.mon_original,
                                               a.monto_original,
                                               a.nom_solicitante,
                                               a.nro_doc_solicitante,
                                               a.cod_tip_doc_solicitante,
                                               a.nro_cta_solicitante,
                                               a.des_suc_sol_solicitante,
                                               a.swi_suc_pte_sol_original,
                                               a.cta_suc_pte_sol_original,
                                               a.swi_pte_solicitante,
                                               v_tipo_sol_orig,
                                               a.cta_pte_solicitante,
                                               a.swi_pte_beneficiario,
                                               v_tipo_ben_orig,
                                               a.cta_pte_beneficiario,
                                               a.nom_beneficiario,
                                               a.nro_doc_beneficiario,
                                               a.cod_tip_doc_beneficiario,
                                               a.nro_cta_beneficiario,
                                               a.cod_tip_operacion,
                                               a.nro_ref_solicitud);
         ---Registro de parametros 
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: pacs.004'||chr(10) ||
         ' Parametros: Nro_referencia: '||a.nro_referencia|| chr(10) || 
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) || 
         ' Fecha: '||a.fec_devolucion|| chr(10) || 
         ' hora: '||a.hor_devolucion|| chr(10) || 
         ' Fecha Original: '||a.fec_original|| chr(10) || 
         ' Fecha Devolucion: '||a.fec_valor_devolucion|| chr(10) ||
         ' Tipo Operacion: '||a.cod_tip_operacion|| chr(10) || 
         ' Moneda Devolucion: '||a.mon_devolucion|| chr(10) || 
         ' Monto Devolucion: '||a.monto_devolucion|| chr(10) ||
         ' Moneda Original: '||a.mon_original|| chr(10) || 
         ' Monto Original: '||a.monto_original|| chr(10) || 
         ' Solicitante: '||a.nom_solicitante|| chr(10) || 
         ' Documento solicitante: '||a.nro_doc_solicitante|| chr(10) || 
         ' Tipo doc solicitante: '||a.cod_tip_doc_solicitante|| chr(10) || 
         ' Cuenta solicitante: '||a.nro_cta_solicitante|| chr(10) || 
         ' Swift partipante solicitante: '||a.swi_pte_solicitante|| chr(10) || 
         ' Tipo solicitante Devolucion: '||v_tipo_sol_devol|| chr(10) || 
         ' Tipo solicitante Original: '||v_tipo_sol_orig|| chr(10) ||
         ' Cuenta Participante solicitante: '||a.cta_pte_solicitante|| chr(10) || 
         ' Swift partipante beneficiario: '||a.swi_pte_beneficiario|| chr(10) ||  
         ' Tipo beneficiario Devolucion: '||v_tipo_ben_devol|| chr(10) || 
         ' Tipo beneficiario Original: '||v_tipo_ben_orig|| chr(10) || 
         ' Cuenta Participante beneficiario: '||a.cta_pte_beneficiario|| chr(10) || 
         ' Beneficiario: '||a.nom_beneficiario|| chr(10) || 
         ' Documento beneficiario: '||a.nro_doc_beneficiario|| chr(10) || 
         ' Tipo doc beneficiario: '||a.cod_tip_doc_beneficiario|| chr(10) || 
         ' Cuenta beneficiario: '||a.nro_cta_beneficiario|| chr(10) || 
         ' Concepto: '||'Envio de Devolucion'|| chr(10) || 
         ' Nro. Ref. Solicitud: '||a.nro_ref_solicitud|| chr(10) ||
         ' Observacion: '||' '
         , g_lugar||' Nro_referencia: '||a.nro_referencia);   

  END LOOP;
  IF v_nro_referencia is not null then
  g_lugar:='Asigna datos para la cabecera de informe pacs.004';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi(PAS_SPI.fu_tip_msj_spi(fug_obt_pardinamico( 'COD_SPI_DEV' )),v_nro_ref_externa);
  g_lugar:='Actualizacion de transferencia pacs.004 a bloqueado';
  --Modo de bloquear el registro
    UPDATE ge_snp_transferencias
       SET situacion = 'B'
     WHERE nro_referencia = v_nro_referencia;

    g_lugar:='Recupera cantidad de reintentos pacs.004';
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
      exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos pacs.004';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_nro_referencia, v_nro_ref_externa, PAS_SPI.fu_tip_msj_spi(fug_obt_pardinamico( 'COD_SPI_DEV' )),trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de transferencia ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Pacs.004 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_transferencias := transferencia;
    p_dat_mensaje        := mensaje;
  ELSE
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_transferencias  := transferencia;
    p_dat_mensaje         := mensaje;
  END IF;

EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 50;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
     UPDATE ge_snp_transferencias
     SET situacion = 'N'
     WHERE nro_referencia = v_nro_referencia;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_004-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de pacs.004, Ref. externa: '||v_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje        := mensaje;
END pr_obt_tra_pen_004;
/*
Se aplican las validaciones que determinan si se puede registra la solicitud de pago por SPI
*/
procedure pr_val_sol_pago(p_cod_moneda       in varchar2,
                          p_monto            in number,
                          p_bic              in varchar2,
                          p_sub_pte          in varchar2,
                          p_cuenta           in varchar2,          
                          p_cod_retorno      out number,
                          p_men_retorno      out varchar2) is

  v_ind_spi       varchar2(1);
  v_habilitado    varchar2(1);
  v_sup_limite    varchar2(1);
  v_cli_principal ba_personas.cod_persona%type;
  v_tipo          ba_personas.tipo%type;
  v_cir_alta      wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SPI_CIR_ALT_CATASTRO');
  v_cir_susp	    wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SPI_CIR_SUS_CATASTRO');
  v_cir_acti      wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SPI_CIR_ACT_CATASTRO');
  v_cir_modi      wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SPI_CIR_MOD_CATASTRO');
  v_can_reg       number(5):=0;
  v_vto_catastro  ge_spi_cat_comercios.fec_vencimiento%type;
  v_est_catas     ge_spi_cat_comercios.estado%type; 
  /*Variable que se utiliza para buscar la persona juridica - 
  relacionada a la persona fisica  */
  v_per_uni       ba_personas.cod_persona%type;
begin
    p_cod_retorno:=0;
    p_men_retorno:='OK';

    pr_ini_var_spi;

    v_habilitado:=fu_val_fun_fase2('SPI_PTE_SOL_PAGO','C','1');

    if v_habilitado='N' then
       p_cod_retorno:=30;
       p_men_retorno:='Funcionalidad no certificada para la entidad emisora';
       return;
    end if;

    v_habilitado:=null;

    v_habilitado:=fu_val_fun_fase2('SPI_PTE_SOL_PAGO','S',p_bic);

    if v_habilitado='N' then
       p_cod_retorno:=31;
       p_men_retorno:='Funcionalidad no certificada para la entidad receptora';
       return;
    end if;

    v_ind_spi := it.PAS_SPI.fu_obt_tra_spi(p_cod_moneda,
                                           p_monto,
                                           p_sub_pte,
                                           p_bic);
  if v_ind_spi in ('C','R') then
     p_cod_retorno:=32;
     p_men_retorno:='El servicio SPI no se encuentra disponible, vuelva a intentar mas tarde';
     return;
  elsif v_ind_spi='N' then
     p_cod_retorno:=33;
     p_men_retorno:='La solicitud no cumple los requisitos para una transferencia SPI';
     return;
  end if;

  pag_cta.pr_obt_cuenta (p_cuenta);--recuperar los datos de la cuenta

  if pag_cta.fu_obt_cod_error <> 0 then
     p_cod_retorno:=34;
     p_men_retorno:= pag_cta.fu_obt_cod_error||' - '||pag_cta.fu_obt_msj_error;
     return;
  end if;  

  v_cli_principal:=fug_obt_cli_principal(p_cuenta);

  select pp.tipo
  into v_tipo
  from ba_personas pp 
  where pp.cod_persona=v_cli_principal;

  begin
    --Buscamos si la persona fisica tiene una tipo relacion UN con una per juridica
    select c.cod_persona
    into v_per_uni 
    from ba_vinculos  c
    where c.cod_per_vinculo = v_cli_principal
    and c.tipo = 'UN';
    exception
      when others then 
        v_per_uni := null;
  end;
  --En el caso de que el principal de la cuenta sea distinto J y
  --No se trate de una unipersonal, entonces debe de retornar un error
  if v_tipo!='J' and 
    not(v_per_uni is not null and 
    nvl(fug_obt_naturaleza(v_per_uni), 'N') = nvl(fug_obt_pardinamico('COD_NAT_UNIPERSONAL'), 'X')) then
     p_cod_retorno:=39;
     p_men_retorno:='La opcion no esta habilitada para personas fisicas';
     return;
  end if;
  --validaciones de catastro para clientes comerciales SPI-292
  begin
       select co.fec_vencimiento,co.estado
       into v_vto_catastro,v_est_catas
       from ge_spi_cat_comercios co
       where co.cod_catastro=
                                 (select max(co.cod_catastro)
                                 from ge_spi_cat_comercios co
                                 where co.nro_cuenta=p_cuenta);
  exception
       when no_data_found then
          p_cod_retorno:=40;
          p_men_retorno:='Cuenta no posee un catastro activo';
          return;
   end;
  
  if v_est_catas!='A' then
     p_cod_retorno:=41;
     p_men_retorno:='Catastro no se encuentra Activo!';
     return;
  end if;
  
  if v_vto_catastro<trunc(sysdate) then
      p_cod_retorno:=42;
      p_men_retorno:='El catrastro de la cuenta esta vencido';
      return;
  end if;
 
    select count(*)
    into v_can_reg
    from wf_circuitos tt,ge_spi_cat_comercios cc
    where tt.referencia=cc.cod_catastro
    and tt.cod_tip_circuito in (v_cir_alta,v_cir_susp,v_cir_acti,v_cir_modi)
    and tt.estado='E'
    and cc.nro_cuenta=p_cuenta;
  
   if v_can_reg>0 then
      p_cod_retorno:=43;
      p_men_retorno:='Cuenta posee un catastro con circuito pendiente de aprobacion/rechazo';
      return;
   end if;
  ---
  if pag_gen.fu_obt_mon_local!=pag_cta.fu_obt_mon_cuenta then
     p_cod_retorno:=35;
     p_men_retorno:='La moneda de la cuenta debe ser : '||pag_gen.fu_obt_mon_local;
     return;
  end if;

  v_sup_limite:= fua_obt_limite_cta_basica(p_cuenta,
                                           p_monto,
                                           trunc(sysdate),
                                           pag_cta.g_ctas.cod_modalidad,
                                           pag_cta.g_ctas.cod_moneda);
  if nvl(v_sup_limite,'N')='S' then
     p_cod_retorno:=36;
     p_men_retorno:='Sumatoria de transferencias recibidas, supera el maximo posible para el tipo de cuenta';
     return;
  end if;

  pag_cta.pr_ver_operacion(p_cuenta,
                           v_cod_tra_padre,                  
                           v_cod_mod_padre, 
                           v_cod_mad_padre, 
                           'C',
                           pag_cta.fu_obt_mon_cuenta,
                           0,
                           fug_obt_ofi_usuario(user),
                           v_cod_mod,
                           v_cod_mad,
                           v_est_cuenta,
                           v_sal_disponible,
                           v_procesa,
                           v_tra_deb); 

   if pag_cta.fu_obt_cod_error <> 0 then
      p_cod_retorno:=37;
      p_men_retorno:=pag_cta.fu_obt_cod_error||' - '||pag_cta.fu_obt_msj_error;
      return;
   end if;
exception 
    when others then 
      p_cod_retorno:=38;
      p_men_retorno:=sqlerrm;
end pr_val_sol_pago;
procedure pr_pro_msj_rec_004(p_dat_recibidos in  typ_ObtTransrecibido004,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa transferencia RECIBIDA por el SPI, de tipo pacs.004(Mensaje de devolucion de Fondos)
  */
  ex_salir EXCEPTION;
  ex_error EXCEPTION;
  rg_msj_rec            pas_snp.rg_msj;
  rg_dat_pte            pas_snp.rg_pte := null;
  rg_msj_dev            ge_spi_solicitudes%rowtype;
  v_cod_moneda          varchar2(3)    := null;
  v_sql                 varchar2(4000) := null;
  v_tip_doc             varchar2(5)    := null;
  v_cod_msj_mx          ge_spi_cab_versiones.tipo_msj%type;
  v_codigo              ge_snp_mensajes.cod_msj_swift%type;
  v_nro_cuenta          ge_cuentas.nro_cuenta%type;
  v_cod_tip_doc_ben     ge_snp_transferencias.cod_tip_doc_beneficiario%type;
  v_ind_instruccion     ge_snp_transferencias.nro_lote%type;
  v_nro_cta_participante ge_snp_transferencias.nro_cta_solicitante%type:=pas_spi.fu_obt_cta_ban_participante( PAS_SNP.fu_obt_cod_swi_participante(fug_obt_per_entidad),g_cod_mon_local );
  mensaje               typ_mensajeria_spi := typ_mensajeria_spi(0,'OK',null);
  v_existe_ref          varchar2(1):='N'; -- Control Duplicado
 -- Retorno de verificación de operaciones
  v_est_cuenta        ge_cuentas.estado%type;    -- Estado Cta.
  v_sal_disponible    ge_movimientos.monto%type; -- Sal.Dispon.
  v_procesa           varchar2(1) := 'N';
  v_cod_modulo        ge_snp_transferencias.cod_modulo%type;
  v_cod_modalidad     ge_snp_transferencias.cod_modalidad%type;
  v_supera_limite      varchar2(1):='N';
  v_sub_participante   boolean;
  rg_msj_invertido     ge_snp_transferencias%rowtype;
  e_val                 exception;
  rg_sol                ge_spi_solicitudes%rowtype; --para insertar la solicitud
  v_cod_solicitud       ge_spi_solicitudes.cod_sol_spi%type;
  v_sub_tip_operacion   ge_snp_transferencias.cod_sub_tip_operacion%type;
  --para movimientos nocturnos
  v_cod_respuesta               number(10);
  v_nom_respuesta               varchar2(2000);
  --notificaciones
  v_dir_notificaciones          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_RECHAZO_LIM');
  v_des_monto                varchar2(500) := NULL;
  v_ent_solicitante          varchar2(200) := NULL;
  v_ent_beneficiaria         varchar2(200) := NULL;
  v_inf_json                 long:=null;
  --p/validacion de max_dias
  v_can_dias            number(3):=0;
  --para validaciones de pacs004 donde se recibe el nro_ref_relacionado del camt056
  v_ref_solicitud       ge_spi_solicitudes.nro_ref_solicitud%type;
  v_cod_sol_spi         ge_spi_solicitudes.cod_sol_spi%type;
  v_tip_persona         ba_personas.tipo%type;
  v_des_dev             varchar2(100);
  v_nombre_saludo       varchar2(100);
  v_ent_debito          varchar2(100);
  v_ent_credito         varchar2(100);
  v_fec_notificacion    varchar2(20);
BEGIN
   begin
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
   end;

  begin
      pas_spi.g_cod_error := 0;
      pas_spi.g_msj_error := NULL;
      g_tip_rch           := NULL;
      v_sub_participante  := false;
      g_nom_respuesta:='Proceso realizado correctamente';--Respuesta corta a arrojar en el campo nom_respuesta de type typ_mensajeria_spi(out)
      pas_spi.pr_ini_registros;
      pas_spi.pr_ini_var_spi;
      g_lugar:='Registro de parametros en log';
         --Registro de parametros 
         pas_snp.pr_reg_operacion('Tipo mensaje recibido: Pacs.004'|| chr(10) ||
         ' Parametros: Nro_ref_externa: '||p_dat_recibidos.nro_ref_externa|| chr(10) || 
         ' Fecha: '||p_dat_recibidos.fec_recepcion|| chr(10) || 
         ' Mensaje swift: ' ||p_dat_recibidos.msj_mx|| chr(10) ||
         ' Cod Msj swift: ' ||p_dat_recibidos.cod_msj_mx|| chr(10)||
         ' Referencia del pacs.008 original: ' ||p_dat_recibidos.nro_ref_msj_original|| chr(10)||
         ' Moneda: '||p_dat_recibidos.cod_moneda|| chr(10) || 
         ' Monto: '||p_dat_recibidos.monto|| chr(10) || 
         ' Fecha valor: '||p_dat_recibidos.fec_valor|| chr(10) || 
         ' Motivo de la Devolucion: '||p_dat_recibidos.cod_motivo|| chr(10) || 
         ' Ref. Solicitud: '||p_dat_recibidos.nro_ref_solicitud|| chr(10) || 
         ' Tip. Operación: '||p_dat_recibidos.cod_tip_operacion|| chr(10) --agrego cod_tip_operacion
         , g_lugar||' Nro ref. externa: '||p_dat_recibidos.nro_ref_externa); 

      --control del estado del módulo 3 en 1 o 6
      g_lugar :=  'Valida estado del modulo';
      lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
         if g_tip_rch is null then    
            pas_spi.g_cod_error := 211;
            g_nom_respuesta := 'La cuenta no permite el proceso';
            pas_spi.g_msj_error := g_nom_respuesta; 
            g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
         end if;
      end if;
      g_lugar:='Obteniendo parametro de Nro referencia externa';
      if p_dat_recibidos.nro_ref_externa is null then
         pas_spi.g_cod_error := 212;
         g_nom_respuesta := 'El valor Nro. Ref. Externa no puede ser nulo.!';
         pas_spi.g_msj_error := g_nom_respuesta;
      else
         rg_msj_rec.nro_ref_externa:=p_dat_recibidos.nro_ref_externa;
      end if;
        g_lugar :=  'Obteniendo parametro Fecha Recepcion';
        if p_dat_recibidos.fec_recepcion is null then
          pas_spi.g_cod_error := 213;
          g_nom_respuesta := 'El valor fecha recepcion no puede ser nulo.!';
          pas_spi.g_msj_error := g_nom_respuesta;
        else
            rg_msj_rec.fec_recepcion := p_dat_recibidos.fec_recepcion;
        end if;
        g_lugar :=  'Obteniendo parametro msj_mx';
        if p_dat_recibidos.msj_mx is null then
          pas_spi.g_cod_error := 214;
          g_nom_respuesta := 'El valor msj_mx no puede ser nulo.!';
          pas_spi.g_msj_error := g_nom_respuesta;
        else
            rg_msj_rec.msj_swift := p_dat_recibidos.msj_mx;
        end if;
        g_lugar :=  'Obteniendo parametro cod_msj_mx';
        if p_dat_recibidos.cod_msj_mx is null then
          pas_spi.g_cod_error := 215;
          g_nom_respuesta := 'El valor msj_mx no puede ser nulo.!';
          pas_spi.g_msj_error := g_nom_respuesta;
        else
           g_lugar :=  'Obteniendo codigo de mensaje mx, en base a la version recibida.';
           v_cod_msj_mx :=pas_spi.fu_tip_msj_ver(p_dat_recibidos.cod_msj_mx);
        end if;
        g_lugar :=  'Obteniendo parametro nro_ref_msj_original';
        if p_dat_recibidos.nro_ref_msj_original is null then
          pas_spi.g_cod_error := 216;
          g_nom_respuesta := 'El Número de Referencia del Mensaje Original no puede ser nulo.!';
          pas_spi.g_msj_error := g_nom_respuesta;
        else
          g_lugar :=  'Generando el valor Concepto en base al nro_ref_msj_original. ';
          rg_msj_rec.concepto := 'Dev. '||p_dat_recibidos.nro_ref_msj_original;--*
        end if;
        g_lugar :=  'Obteniendo parametro Moneda: ';
         if p_dat_recibidos.cod_moneda is null then
             if g_tip_rch is null then
                 pas_spi.g_cod_error := 217;
                 g_nom_respuesta:='La divisa de cuenta ausente';
                 pas_spi.g_msj_error := g_nom_respuesta;
                 g_tip_rch:=g_rch_ac09;
           end if;
         else
             v_cod_moneda := p_dat_recibidos.cod_moneda;
             v_cod_moneda := CASE v_cod_moneda WHEN g_cod_mon_iso_local THEN g_cod_mon_local ELSE v_cod_moneda END;
             rg_msj_rec.cod_moneda := v_cod_moneda;
             v_sql := 'SELECT ''S'' '||
                      'FROM   BA_MONEDAS '||
                      'WHERE  COD_MONEDA = '||''''||rg_msj_rec.cod_moneda||'''';
             if not fu_val_dat_ingresado(v_sql) then
               g_lugar :=  'Obteniendo parametro Moneda: 1';
                 pas_spi.g_cod_error := 218;
                 g_nom_respuesta := 'El valor de Moneda no es correcto -'||p_dat_recibidos.cod_moneda;
                 pas_spi.g_msj_error := g_nom_respuesta;
             end if;
         end if;
         g_lugar :=  'Obteniendo parametro Monto: ';
         rg_msj_rec.monto :=p_dat_recibidos.monto ;
         if rg_msj_rec.monto is null then
              pas_spi.g_cod_error:= 219;
              g_nom_respuesta := 'El campo Monto no puede ser nulo.';
              pas_spi.g_msj_error := g_nom_respuesta;
         end if;
        g_lugar :=  'Obteniendo parametro Fecha valor';
        if p_dat_recibidos.fec_valor is null then
         pas_spi.g_cod_error := 220;
         g_nom_respuesta := 'El valor fecha valor no puede ser nulo.!';
         pas_spi.g_msj_error := g_nom_respuesta;
        else
         rg_msj_rec.fec_valor     := p_dat_recibidos.fec_valor;
         rg_msj_rec.fec_ingreso   := p_dat_recibidos.fec_valor;
        end if;
        g_lugar :=  'Obteniendo parametro cod_motivo';
        if p_dat_recibidos.cod_motivo is null then
          pas_spi.g_cod_error := 221;
          g_nom_respuesta := 'El valor cod_motivo no puede ser nulo.!';
          pas_spi.g_msj_error := g_nom_respuesta;
        else
            rg_msj_rec.tip_rechazo        := p_dat_recibidos.cod_motivo;
        end if;
        g_lugar :=  'Obteniendo parametro nro_ref_solicitud';
        v_ref_solicitud := p_dat_recibidos.nro_ref_solicitud; 
        --
        g_lugar :=  'Obteniendo parametro cod_tip_operacion';
        if p_dat_recibidos.cod_tip_operacion is null then
          pas_spi.g_cod_error := 222;
          g_nom_respuesta := 'El valor cod_tip_operacion no puede ser nulo.!';
          pas_spi.g_msj_error := g_nom_respuesta;
        else
          rg_msj_rec.cod_tip_operacion  := p_dat_recibidos.cod_tip_operacion;
        end if;

        g_lugar :=  'Verifica si hay duplicacion de la transferencia recibida';
         if nvl(fug_obt_pardinamico('SPI_VAL_MSJ_REC_DUPLICADOS'), 'S') = 'S' then
          if pas_spi.fu_ver_msj_duplicados ( rg_msj_rec.nro_ref_externa, rg_msj_rec.fec_valor ) = 'S' then
            pas_spi.g_cod_error := 223;
            g_nom_respuesta := 'Transferencia mx existente para la Ref. Externa '||p_dat_recibidos.nro_ref_externa;
            pas_spi.g_msj_error := g_nom_respuesta;
          end if;
         end if;

   --control del estado del módulo 3 en 1 o 6
     lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
         if g_tip_rch is null then    
            pas_spi.g_cod_error := 224;
            g_nom_respuesta := 'La cuenta no permite el proceso';
            pas_spi.g_msj_error := g_nom_respuesta; 
            g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
         end if;
      end if;

    if pag_cta.g_ctas.cod_moneda != rg_msj_rec.cod_moneda then
       if g_tip_rch is null then
       pas_spi.g_cod_error := 225;
         g_nom_respuesta := 'No coincide moneda transferencia con moneda de cta';
       pas_spi.g_msj_error := g_nom_respuesta;
       g_tip_rch:=g_rch_ac09;--AC09 - La divisa de cuenta es incorrecta o ausente
       end if;
    end if;

  begin
  select to_number(t.val_minimo)
    into v_codigo
    from ba_cod_referencias t
   where dominio = 'COD_MSJ_SWIFT'
     and t.abreviatura = v_cod_msj_mx;
  exception
 when no_data_found then
   pas_spi.g_cod_error := 227;
   g_nom_respuesta := 'No se encuentra codigo de mensaje swift para version recibida -'||v_cod_msj_mx;
   pas_spi.g_msj_error := g_nom_respuesta;
 when others then
   pas_spi.g_cod_error := 228;
   g_nom_respuesta := 'No se encuentra codigo de mensaje swift para version recibida -'||v_cod_msj_mx;
   pas_spi.g_msj_error := g_nom_respuesta;
end;
g_lugar :=  'Obteniendo Codigo Subtipo de operacion.';
begin
   select m.cod_sub_tip_operacion
    into v_sub_tip_operacion
    from ge_snp_par_mensajes m
   where m.cod_msj_swift = v_codigo
     and m.cod_tip_operacion = p_dat_recibidos.cod_tip_operacion; 
  exception
 when no_data_found then
   pas_spi.g_cod_error := 229;
   g_nom_respuesta := 'No se encuentra Codigo Subtipo de operacion - Mensaje: '||v_cod_msj_mx||' Tip_operacion :'||p_dat_recibidos.cod_tip_operacion;
   pas_spi.g_msj_error := g_nom_respuesta;
 when others then
   pas_spi.g_cod_error := 230;
   g_nom_respuesta := 'No se encuentra Codigo Subtipo de operacion - Mensaje: '||v_cod_msj_mx||' Tip_operacion :'||p_dat_recibidos.cod_tip_operacion;
   pas_spi.g_msj_error := g_nom_respuesta;
end;

      g_lugar :=  'Validando Duplicados.';
      begin
        select 'S' 
          into v_existe_ref
          from ge_snp_transferencias g
          where g.nro_ref_externa = p_dat_recibidos.nro_ref_externa
            and g.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV')
            and rownum=1;     
     exception
         when others then
           v_existe_ref :='N';
      end;  
      if nvl(v_existe_ref,'N')='S' then   
                raise ex_salir;
      end if;   

--Invierto datos de la transferencia original para grabar en ge_snp_transferencias el pacs.004 original.
begin
              select *--recupero todos los datos de la transferencia original  
              into rg_msj_invertido
              from ge_snp_transferencias t 
              where t.fec_recepcion is null
               and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_PCD')
               and t.situacion = 'L'
               and t.estado = 'A'
               and t.nro_ref_externa = p_dat_recibidos.nro_ref_msj_original;
         exception
               when no_data_found then
                   pas_spi.g_cod_error := 231;
                   g_nom_respuesta := 'No se encuentra la transf. que se intenta devolver: -'||p_dat_recibidos.nro_ref_msj_original;
                   pas_spi.g_msj_error := g_nom_respuesta;
                   raise e_val;
end;
---      
g_lugar :=  'Validando existencia de relacion con p_dat_recibidos.nro_ref_solicitud.';
begin
  select sol.cod_sol_spi
  into v_cod_sol_spi
  from ge_spi_solicitudes sol
  where sol.nro_ref_externa = v_ref_solicitud
  and sol.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_SOL_DEV');
  exception 
    when no_data_found then
      v_cod_sol_spi := null;
    when others then
      v_cod_sol_spi := null;   
end;      

      -- Se Inserta en ge_snp_transferencias
       BEGIN
         g_lugar :=  'Asignacion de valores varios para ge_snp_transferencias ';
         rg_msj_rec.nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
         rg_msj_rec.cod_msj_swift  := v_codigo;
         rg_msj_rec.cod_modulo     := pas_snp.fu_obt_cod_mod_padre;
         rg_msj_rec.cod_modalidad  := pas_snp.fu_obt_cod_mad_padre;
         rg_msj_rec.ind_valor      := 'S'; --(S) Alto Valor
         rg_msj_rec.situacion      := 'R';
         rg_msj_rec.estado         := nvl(rg_msj_rec.estado, 'A');
         rg_msj_rec.origen         := 'I';
         rg_msj_rec.plataforma     := 'S';
         rg_msj_rec.indemnizado    := 'N';
         rg_msj_rec.cod_oficina    := fug_obt_ofi_usuario (user);
         -------- Datos para cargar lo recibido desde BCP como pacs.004
         rg_msj_rec.tip_cargo      := fue_obt_val_max_referencia('TIP_CAR_SIPAP', v_codigo ||'-'||rg_msj_rec.cod_moneda);
         rg_msj_rec.cod_sub_tip_operacion := v_sub_tip_operacion;
         rg_msj_rec.cod_per_beneficiario := rg_msj_invertido.cod_per_solicitante;
         rg_msj_rec.nom_beneficiario     := rg_msj_invertido.nom_solicitante;
         rg_msj_rec.dir_beneficiario     := rg_msj_invertido.dir_solicitante;
         rg_msj_rec.cod_tip_doc_beneficiario := rg_msj_invertido.cod_tip_doc_solicitante;
         rg_msj_rec.nro_doc_beneficiario     := rg_msj_invertido.nro_doc_solicitante;
         rg_msj_rec.nro_cta_beneficiario     := rg_msj_invertido.nro_cta_solicitante;
         rg_msj_rec.cod_swi_pte_beneficiario := rg_msj_invertido.cod_swi_pte_solicitante;
         rg_msj_rec.cod_swi_suc_beneficiario := rg_msj_invertido.cod_swi_suc_solicitante;
         rg_msj_rec.nro_cta_pte_beneficiario := rg_msj_invertido.nro_cta_pte_solicitante;
         rg_msj_rec.nro_cta_suc_pte_beneficiario := rg_msj_invertido.nro_cta_suc_pte_solicitante;--
         rg_msj_rec.cod_per_solicitante      := rg_msj_invertido.cod_per_beneficiario;
         rg_msj_rec.nom_solicitante          := rg_msj_invertido.nom_beneficiario;
         rg_msj_rec.dir_solicitante          := rg_msj_invertido.dir_beneficiario;
         rg_msj_rec.cod_tip_doc_solicitante  := rg_msj_invertido.cod_tip_doc_beneficiario;
         rg_msj_rec.nro_doc_solicitante      := rg_msj_invertido.nro_doc_beneficiario;
         rg_msj_rec.nro_cta_solicitante      := rg_msj_invertido.nro_cta_beneficiario;
         rg_msj_rec.cod_swi_pte_solicitante  := rg_msj_invertido.cod_swi_pte_beneficiario;
         rg_msj_rec.cod_swi_suc_solicitante  := rg_msj_invertido.cod_swi_suc_beneficiario;
         rg_msj_rec.nro_cta_pte_solicitante  := rg_msj_invertido.nro_cta_pte_beneficiario;
         rg_msj_rec.nro_cta_suc_pte_solicitante  := rg_msj_invertido.nro_cta_suc_pte_beneficiario;
         rg_msj_rec.tip_mensaje              := 'CRED' ;
         rg_msj_rec.prioridad                := NVL(fus_snp_obt_prioridad(rg_msj_rec.cod_msj_swift, rg_msj_rec.cod_tip_operacion, rg_msj_rec.cod_sub_tip_operacion),20);
         rg_msj_rec.cod_moneda               := rg_msj_invertido.cod_moneda;
         -------------- Para insertar dentro de ge_spi_solicitudes -------------------------
         rg_sol.nro_referencia               := rg_msj_rec.nro_referencia;
         rg_sol.nro_ref_externa              := rg_msj_rec.nro_ref_externa;
         rg_sol.cod_msj_swift                := rg_msj_rec.cod_msj_swift;
         rg_sol.fec_recepcion                := rg_msj_rec.fec_recepcion;
         rg_sol.monto                        := rg_msj_rec.monto;
         rg_sol.msj_mx                       := rg_msj_rec.msj_swift;
         rg_sol.nro_ref_msj_original         := p_dat_recibidos.nro_ref_msj_original;
         rg_sol.nom_solicitante              := rg_msj_rec.nom_solicitante;
         rg_sol.doc_solicitante              := rg_msj_rec.nro_doc_solicitante;
         rg_sol.tip_doc_solicitante          := rg_msj_rec.cod_tip_doc_solicitante;
         rg_sol.cta_solicitante              := rg_msj_rec.nro_cta_solicitante;
         rg_sol.cod_swi_suc_solicitante      := rg_msj_rec.cod_swi_suc_solicitante;
         rg_sol.nom_beneficiario             := rg_msj_rec.nom_beneficiario;
         rg_sol.doc_beneficiario             := rg_msj_rec.nro_doc_beneficiario;
         rg_sol.tip_doc_beneficiario         := rg_msj_rec.cod_tip_doc_beneficiario;
         rg_sol.cta_beneficiario             := rg_msj_rec.nro_cta_beneficiario;
         rg_sol.cod_swi_suc_beneficiario     := rg_msj_rec.cod_swi_suc_beneficiario; 
         rg_sol.nro_ref_solicitud            := v_ref_solicitud;
         rg_sol.uetr                         := null;
         rg_sol.cod_moneda                   := rg_msj_rec.cod_moneda;
         rg_sol.cod_mot_solicitud            := rg_msj_rec.tip_rechazo;
         rg_sol.est_notificacion             := 'X';
         rg_sol.sit_solicitud                := rg_msj_rec.situacion;
         rg_sol.est_solicitud                := rg_msj_rec.estado;
         rg_sol.cod_swi_solicitante          := rg_msj_rec.cod_swi_pte_solicitante;
         rg_sol.cod_swi_beneficiario         := rg_msj_rec.cod_swi_pte_beneficiario;

         ---------- Realizo el insert -------------
         BEGIN 
           g_lugar :=  'Insercion en ge_snp_transferencias ';
              --Invoca al sp que se encarga de insertar la transferencia.
              pas_snp.pr_ins_transferencias(rg_msj_rec);
              --Invoca al sp que se encarga de insertar en ge_spi_solicitudes.
              if v_cod_sol_spi is null then
              g_lugar := 'Insercion de la solicitud.';
              pas_spi.pr_ins_sol_spi(rg_sol,v_cod_solicitud);
              g_lugar := 'Devolucion Generada Nro: '||v_cod_solicitud;
              else 
                --Actualizo el nro de referencia en la tabla de solicitudes del pacs004 recibido 
                --en respuesta del camt056 que se habia enviado
                IF v_ref_solicitud is not null then  
                update ge_spi_solicitudes
                   set nro_referencia = rg_sol.nro_referencia, -- del pacs.004 recepcionado
                       respuesta      = respuesta ||chr(10)|| 'Referencia de devolución recibida como aprobación de la solicitud enviada: '||rg_msj_rec.nro_ref_externa
                 where nro_ref_externa = v_ref_solicitud;
                 IF sql%notfound THEN
                 pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Ref. Externa: '||v_ref_solicitud);
                 END IF;
                END IF; 
                --Actualizo el mismo dato en bw_movimiento (Necesario para la WEB/APP) 
                IF v_cod_sol_spi is not null then
                update bw_movimientos
                   set dato2 = rg_sol.nro_referencia -- del pacs.004 recepcionado
                 where nro_documento = v_cod_sol_spi
                   and cod_tip_mensaje = '028';
                IF sql%notfound THEN
                 pas_snp.pr_reg_operacion('Error al intentar actualizar en bw_movimientos: '||sqlerrm,'Nro. Documento: '||v_cod_sol_spi);
                 END IF;
                END IF;   
              end if;
              --Fuerzo el commit para que más abajo ya sea accesible el registro que intente actualizar  
              commit;

        exception
         when dup_val_on_index then
          --Mensajeria duplicada
          null;
          when others THEN
                pas_spi.g_cod_error := 232;
                pas_spi.g_msj_error := 'Error al insertar en GE_SNP_TRANSFERENCIAS. Nro. Ref.: ' || rg_msj_rec.nro_referencia || ' - ' || sqlerrm;

        end;
     EXCEPTION
        when others then
           pas_spi.g_cod_error := 233;
           g_nom_respuesta :='Error en la insercion de GE_SNP_TRANSFERENCIAS';
           pas_spi.g_msj_error :=g_nom_respuesta||sqlerrm;
     END;

     --DA-7726-control del estado del módulo 3 en 1 o 6
      g_lugar :=  'Valida estado del modulo';
      lp_ver_horario(3); 
      if g_mod_estado in (1,6) then
           if g_tip_rch is null then    
               pas_spi.g_cod_error := 234;
               g_nom_respuesta := 'La cuenta no permite el proceso';
               pas_spi.g_msj_error := g_nom_respuesta; 
               g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
      end if;
     end if;
      g_lugar :=  'Final del proceso de recepcion de Devolución.';
     if pas_spi.g_cod_error <> 0 then
       update ge_snp_transferencias t
          set t.tip_rechazo = g_tip_rch,--'AC02',
              t.error       = pas_spi.g_msj_error,
              t.estado      = 'R',
              t.situacion   = 'C'          
        where t.nro_ref_externa = p_dat_recibidos.nro_ref_externa
          and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV');
       raise ex_error;
     else

      --Validando datos de la cuenta
      g_lugar :=  'Validando datos de la cuenta para generar movimientos.';
      pag_cta.pr_obt_cuenta (rg_msj_rec.nro_cta_beneficiario);--recuperar los datos de la cuenta


      if pag_cta.fu_obt_cod_error <> 0 then
         pas_spi.g_cod_error := 236;
         g_nom_respuesta := 'Error validando datos de la cuenta: '||pag_cta.fu_obt_cod_error||' - '||pag_cta.fu_obt_msj_error;
         pas_spi.g_msj_error := g_nom_respuesta;

      else
      
      if pag_gen.fu_obt_mon_local!=pag_cta.fu_obt_mon_cuenta then
         pas_spi.g_cod_error := 237;
         g_nom_respuesta := 'La moneda de la cuenta debe ser : '||pag_gen.fu_obt_mon_local;
         pas_spi.g_msj_error := g_nom_respuesta;
          end if;
      end if;  

      pag_cta.pr_ver_operacion(rg_msj_rec.nro_cta_beneficiario,
                               v_cod_tra_padre,                  
                               v_cod_mod_padre, 
                               v_cod_mad_padre, 
                               'C',
                               pag_cta.fu_obt_mon_cuenta,
                               0,
                               fug_obt_ofi_usuario(user),
                               v_cod_mod,
                               v_cod_mad,
                               v_est_cuenta,
                               v_sal_disponible,
                               v_procesa,
                               v_tra_deb); 
          if v_procesa='N' then
             pas_spi.g_cod_error := 238;
             g_nom_respuesta     := 'Operacion credito : '||pag_cta.fu_obt_cod_error||' - '||pag_cta.fu_obt_msj_error;
             pas_spi.g_msj_error := g_nom_respuesta;
          else
      begin
                g_lugar :=  'validando credito a modalides especificas( cuenta basica, Cuenta bajo riesgo). ';
       v_supera_limite:= fua_obt_limite_cta_basica(rg_msj_rec.nro_cta_beneficiario,
                                           rg_msj_rec.monto,
                                          rg_msj_rec.fec_valor,
                                                            pag_cta.g_ctas.cod_modalidad,
                                                            pag_cta.g_ctas.cod_moneda);

      IF nvl(v_supera_limite,'N')='S' then
                 --DT02 - Politica Interna.
                  if g_tip_rch is null then
                           pas_spi.g_cod_error := 239;
                           g_nom_respuesta := 'Sumatoria de transferencias recibidas, supera el maximo posible para el tipo de cuenta';
                           pas_spi.g_msj_error := g_nom_respuesta;
                           g_tip_rch:=g_rch_dt02;
                  end if;

      end if;
       exception
         when others then
           v_supera_limite := null;
      end; 
          end if;  
      end if;

     g_lugar :=  'Final del proceso de recepcion de Devolución.';
     if pas_spi.g_cod_error <> 0 then
        raise ex_error;
     else
        g_lugar := 'valido si la cuenta puede procesar la operacion y no superar limite en cuentas especificas. ';
        if pas_spi.g_cod_error = 0 then
          if NVL(v_procesa,'N') = 'S' and nvl(v_supera_limite,'S')='N' then
            -----------
            --Controla si debe ingresar por nocturno
                 g_lugar :=  'Valida estado del modulo';
                  lp_ver_horario(3); 
                  if g_mod_estado in (1,6) then
                       if g_tip_rch is null then    
                           pas_spi.g_cod_error := 240;
                           g_nom_respuesta := 'La cuenta no permite el proceso';
                           pas_spi.g_msj_error := g_nom_respuesta; 
                           g_tip_rch:=g_rch_dt02;--DT02 - Politica interna
                           raise ex_error;
                  end if;
                 end if;
                 if g_es_mov_noc='S' THEN

                     prg_gen_mov_noc_spi(rg_msj_rec.monto,
                         pas_snp.fu_obt_cta_bancaria(pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(1),pag_gen.fu_obt_mon_local) ,'C'),
                         rg_msj_rec.nro_cta_beneficiario,
                         nvl(rg_msj_rec.cod_moneda,'GS'),
                         rg_msj_rec.cod_msj_swift,
                         rg_msj_rec.cod_tip_operacion,
                         rg_msj_rec.cod_sub_tip_operacion,
                         rg_msj_rec.nro_referencia,
                         rg_msj_rec.nro_ref_externa,
                         rg_msj_rec.cod_swi_pte_solicitante,
                         'R',
                         'N',
                         null,
                         null,
                         null,
                         null,
                         null,
                         v_cod_respuesta,
                         v_nom_respuesta,
                         p_dat_recibidos.nro_ref_msj_original);

                         if v_cod_respuesta <> 0 then
                            mensaje.cod_respuesta := 1;
                            mensaje.nom_respuesta := 'Registro movimiento Nocturno de la operacion con ref.' ||rg_msj_rec.nro_referencia;
                            mensaje.des_Respuesta := 'No se pudo procesar registro de movimiento  ';
                            g_lugar:='Envio de notificacion por error';
                            begin

                                  if v_dir_notificaciones is not null then

                                     it_mail.mail( fug_obt_dir_correo,
                                                   v_dir_notificaciones,
                                                   'Error en proceso de acreditacion de Dev. con ref.externa: '||p_dat_recibidos.nro_ref_externa,
                                                   'Devolucion recibida con inconvenientes en acreditacion a la cuenta, favor verificar'
                                                   || chr(10) ||'Nro. Referencia externa: '||rg_msj_rec.nro_ref_externa
                                                   || chr(10) ||'Beneficiario: '||fue_obt_nom_persona(rg_msj_rec.cod_per_beneficiario)--(v_cod_per_beneficiario_004)
                                                   || chr(10) ||'Nro.Cuenta: '||rg_msj_rec.nro_cta_beneficiario--v_nro_cta_beneficiario_004
                                                   || chr(10) ||'Fecha Ingreso: '||to_char( rg_msj_rec.fec_ingreso, 'DD/MM/YYYY HH24:MI:SS')--( v_fec_insercion_004, 'DD/MM/YYYY HH24:MI:SS')--rg_msj_rec.fec_ingreso
                                                   || chr(10) ||'Monto: '||ltrim(rtrim(to_char(rg_msj_rec.monto,'999,999,999,999,999.99'))));

                                  end if;
                                exception
                                  when others then
                                     null;
                                end;
                            raise ex_error;
                        else
                          --Actualiza la situacion y estado de la solicitud
                           begin
                             if v_cod_sol_spi is null then
                               --Actualizo pacs004
                               IF rg_msj_rec.nro_ref_externa is not null then
                               update ge_spi_solicitudes
                                  set est_solicitud = 'A', sit_solicitud = 'L'
                                where nro_ref_externa = rg_msj_rec.nro_ref_externa
                                  and cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV');
                               IF sql%notfound THEN
                               pas_snp.pr_reg_operacion('Error al intentar actualizar el pacs.004: '||sqlerrm,'Ref. Externa Nro.: '||rg_msj_rec.nro_ref_externa);
                               END IF;
                               END IF;   
                             else
                               --actualizo camt056
                               IF v_ref_solicitud is not null then
                               update ge_spi_solicitudes
                                  set est_solicitud = 'A', sit_solicitud = 'L'
                                where nro_ref_externa = v_ref_solicitud
                                  and cod_msj_swift = fug_obt_pardinamico('COD_SPI_SOL_DEV');   
                               IF sql%notfound THEN
                               pas_snp.pr_reg_operacion('Error al intentar actualizar el camt.056: '||sqlerrm,'Ref. Externa Nro.: '||v_ref_solicitud);
                               END IF;
                               END IF;   
                             end if;   
                           exception
                                when others then
                                   mensaje.cod_respuesta := 241;
                                   mensaje.nom_respuesta := 'Error al cambiar estado de la solicitud de devolucion de la operacion con ref.' ||p_dat_recibidos.nro_ref_externa;
                                   mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                                    raise ex_error;
                              END;
                       --seccion de notificaciones nocturna--
                        if sql%rowcount > 0 then 
                         --se identifica que tipo de persona es para el envio de mail
                           v_tip_persona := pas_spi.fu_obt_tip_persona(rg_msj_invertido.cod_per_solicitante);
                           v_fec_notificacion:= to_char(rg_msj_invertido.fec_insercion, 'dd/mm/yyyy hh24:mi:ss');
                        --notificacion para un pacs.004 recibido por la aprobación de un camt.056
                          IF v_ref_solicitud is not null then 
                             begin                
                                --obtenemos el nombre corto en base al tipo de persona
                                if v_tip_persona = 'F' then
                                 v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(rg_msj_invertido.cod_per_solicitante);
                                else
                                 v_nombre_saludo := fue_obt_nom_comercial(rg_msj_invertido.cod_per_solicitante);
                                end if; 

                                v_ent_debito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_beneficiario); 
                                v_ent_credito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_solicitante);
                                v_des_dev := it.fue_obt_des_refcodes('TIP_REC_SPI_P04',p_dat_recibidos.cod_motivo);

                                     --formato nuevo
                                     v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                                                    '"nombre_titulo":' || '"' || rg_msj_invertido.nom_beneficiario|| '"' || ',' ||
                                                    '"cuenta_debito":' || '"' || rg_msj_invertido.nro_cta_beneficiario || '"' || ',' ||
                                                    '"titular_debito":' || '"' || rg_msj_invertido.nom_beneficiario || '"' || ',' ||
                                                    '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                                                    '"monto":' || '"' || trim(to_char(rg_msj_rec.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                                                    '"moneda_debito":' || '"' || nvl(rg_msj_rec.cod_moneda,'GS') || '"' || ',' ||
                                                    '"nro_operacion":' || '"' || rg_msj_invertido.nro_ref_externa || '"' || ',' ||
                                                    '"fecha_hora":' || '"' ||v_fec_notificacion || '"' || ',' ||
                                                    '"cuenta_credito":' || '"' || rg_msj_invertido.nro_cta_solicitante || '"' || ',' ||
                                                    '"titular_credito":' || '"' || rg_msj_invertido.nom_solicitante || '"' || ',' ||
                                                    '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                                                    '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                                                    '"tipo_operacion":' || '"' || 'Aprobación de Solicitud de Devolución' || '"' || ',' ||
                                                    '"comprobante":' || '"' || rg_msj_rec.nro_ref_externa || '"' || ',' ||
                                                    '"doc_debito":' || '"' || rg_msj_invertido.nro_doc_beneficiario || '"' || '}';


                                     if v_tip_persona = 'F' then                               
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004F'),v_inf_json);
                                     else
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004J'),v_inf_json);
                                     end if;              
                                   exception
                                     when others then
                                       null;
                                   end;
                                 -- 
                           else --envio de notificacion de un pacs.004 recibido forma directa
                             begin                
                                --obtenemos el nombre corto en base al tipo de persona
                                if v_tip_persona = 'F' then
                                 v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(rg_msj_invertido.cod_per_solicitante);
                                else
                                 v_nombre_saludo := fue_obt_nom_comercial(rg_msj_invertido.cod_per_solicitante);
                                end if; 
                                v_ent_debito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_beneficiario); 
                                v_ent_credito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_solicitante);
                                v_des_dev := it.fue_obt_des_refcodes('TIP_REC_SPI_P04',rg_msj_rec.tip_rechazo);
                                     --formato nuevo
                                     v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                                                    -- '"nombre_titulo":' || '"' || rg_msj_invertido.nom_solicitante|| '"' || ',' ||
                                                    '"cuenta_debito":' || '"' || rg_msj_invertido.nro_cta_beneficiario || '"' || ',' ||
                                                    '"titular_debito":' || '"' || rg_msj_invertido.nom_beneficiario || '"' || ',' ||
                                                    '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                                                    '"monto":' || '"' || trim(to_char(rg_msj_rec.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                                                    '"moneda_debito":' || '"' || nvl(rg_msj_rec.cod_moneda,'GS') || '"' || ',' ||
                                                    '"nro_operacion":' || '"' || rg_msj_invertido.nro_ref_externa || '"' || ',' ||
                                                    '"fecha_hora":' || '"' || v_fec_notificacion || '"' || ',' ||
                                                    '"cuenta_credito":' || '"' || rg_msj_invertido.nro_cta_solicitante || '"' || ',' ||
                                                    '"titular_credito":' || '"' || rg_msj_invertido.nom_solicitante || '"' || ',' ||
                                                    '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                                                    '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                                                    '"tipo_operacion":' || '"' || 'Aprobación de Solicitud de Devolución' || '"' || ',' ||
                                                    '"comprobante":' || '"' || rg_msj_rec.nro_ref_externa || '"' || ',' ||
                                                    '"doc_debito":' || '"' || rg_msj_invertido.nro_doc_solicitante || '"' || '}';


                                     if v_tip_persona = 'F' then                               
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004DF'),v_inf_json);
                                     else
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004DJ'),v_inf_json);
                                     end if;              
                                   exception
                                     when others then
                                       null;
                                   end;  
                           end if;                   
                        end if;
                      end if;
                 else
                           -- Actualizo situacion y estado para generar movimientos --
                             g_lugar := 'Actualizar situacion y estado de la operacion con ref.' || p_dat_recibidos.nro_ref_externa;
                             if rg_msj_rec.situacion != 'L' or rg_msj_rec.estado != 'A' then
                              begin
                                  IF p_dat_recibidos.nro_ref_externa is not null then
                                  update ge_snp_transferencias t
                                     set t.situacion   = 'L', 
                                         t.estado      = 'A'        
                                  where t.nro_ref_externa = p_dat_recibidos.nro_ref_externa
                                    and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV'); 
                                  IF sql%notfound THEN
                                     pas_snp.pr_reg_operacion('Error al intentar actualizar la Transferencia: '||sqlerrm,'Ref. Externa Nro.: '||p_dat_recibidos.nro_ref_externa);
                                  END IF;
                                  END IF;  
                              exception
                                when others then
                                   mensaje.cod_respuesta := 242;
                                   mensaje.nom_respuesta := 'Error al liquidar  la operacion con ref.' ||p_dat_recibidos.nro_ref_externa;
                                   mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                                    raise ex_error;
                              end;
                             end if;

                             --Actualiza la situacion y estado de la solicitud
                             begin
                               if v_cod_sol_spi is null then
                                 --Actualizo pacs004
                                 IF rg_msj_rec.nro_ref_externa is not null then
                                 update ge_spi_solicitudes
                                    set est_solicitud = 'A', sit_solicitud = 'L'
                                  where nro_ref_externa = rg_msj_rec.nro_ref_externa
                                    and cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV');
                                 IF sql%notfound THEN
                                 pas_snp.pr_reg_operacion('Error al intentar actualizar el pacs.004: '||sqlerrm,'Ref. Externa Nro.: '||rg_msj_rec.nro_ref_externa);
                                 END IF;
                                 END IF;   
                               else
                                 --actualizo camt056
                                 IF v_ref_solicitud is not null then
                                 update ge_spi_solicitudes
                                    set est_solicitud = 'A', sit_solicitud = 'L'
                                  where nro_ref_externa = v_ref_solicitud
                                    and cod_msj_swift = fug_obt_pardinamico('COD_SPI_SOL_DEV');   
                                 IF sql%notfound THEN
                                 pas_snp.pr_reg_operacion('Error al intentar actualizar el camt.056: '||sqlerrm,'Ref. Externa Nro.: '||v_ref_solicitud);
                                 END IF;
                                 END IF;   
                               end if;
                              exception
                                when others then
                                   mensaje.cod_respuesta := 243;
                                   mensaje.nom_respuesta := 'Error al cambiar estado de la Sol. Devolucion de la operacion con ref.' ||p_dat_recibidos.nro_ref_externa;
                                   mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                                    raise ex_error;
                              end;
                  --Envio de mail Transf. Devolucion Recibida Acreditada            
                  if sql%rowcount > 0 then  
                   --se identifica que tipo de persona es para el envio de mail
                    v_tip_persona := pas_spi.fu_obt_tip_persona(rg_msj_invertido.cod_per_solicitante);
                    v_fec_notificacion:= to_char(rg_msj_invertido.fec_insercion, 'dd/mm/yyyy hh24:mi:ss');
                          IF v_ref_solicitud is not null then  --notificacion para un pacs.004 recibido por el envio de un camt.056
                             begin                
                                if v_tip_persona = 'F' then --obtenemos el nombre corto en base al tipo de persona
                                 v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(rg_msj_invertido.cod_per_solicitante);
                                else
                                 v_nombre_saludo := fue_obt_nom_comercial(rg_msj_invertido.cod_per_solicitante);
                                end if; 
                                v_ent_debito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_beneficiario); 
                                v_ent_credito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_solicitante);
                                v_des_dev := it.fue_obt_des_refcodes('TIP_REC_SPI_P04',p_dat_recibidos.cod_motivo);
                                     --formato nuevo
                                     v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                                                    '"nombre_titulo":' || '"' || rg_msj_invertido.nom_beneficiario|| '"' || ',' ||
                                                    '"cuenta_debito":' || '"' || rg_msj_invertido.nro_cta_beneficiario || '"' || ',' ||
                                                    '"titular_debito":' || '"' || rg_msj_invertido.nom_beneficiario || '"' || ',' ||
                                                    '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                                                    '"monto":' || '"' || trim(to_char(rg_msj_rec.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                                                    '"moneda_debito":' || '"' || nvl(rg_msj_rec.cod_moneda,'GS') || '"' || ',' ||
                                                    '"nro_operacion":' || '"' || rg_msj_invertido.nro_ref_externa || '"' || ',' ||
                                                    '"fecha_hora":' || '"' || v_fec_notificacion || '"' || ',' ||
                                                    '"cuenta_credito":' || '"' || rg_msj_invertido.nro_cta_solicitante || '"' || ',' ||
                                                    '"titular_credito":' || '"' || rg_msj_invertido.nom_solicitante || '"' || ',' ||
                                                    '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                                                    '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                                                    '"tipo_operacion":' || '"' || 'Aprobación de Solicitud de Devolución' || '"' || ',' ||
                                                    '"comprobante":' || '"' || rg_msj_rec.nro_ref_externa || '"' || ',' ||
                                                    '"doc_debito":' || '"' || rg_msj_invertido.nro_doc_beneficiario || '"' || '}';


                                     if v_tip_persona = 'F' then                               
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004F'),v_inf_json);
                                     else
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004J'),v_inf_json);
                                     end if;              
                                   exception
                                     when others then
                                       null;
                                   end;
                           else -- notificacion de un pacs.004 recibido de forma directa
                             begin                
                                if v_tip_persona = 'F' then --obtenemos el nombre corto en base al tipo de persona
                                 v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(rg_msj_invertido.cod_per_solicitante);
                                else
                                 v_nombre_saludo := fue_obt_nom_comercial(rg_msj_invertido.cod_per_solicitante);
                                end if; 
                                v_ent_debito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_beneficiario); 
                                v_ent_credito:=it.fug_obt_nom_snp_participante(rg_msj_invertido.cod_swi_pte_solicitante);
                                v_des_dev := it.fue_obt_des_refcodes('TIP_REC_SPI_P04',rg_msj_rec.tip_rechazo);
                                     --formato nuevo
                                     v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                                                  --  '"nombre_titulo":' || '"' || rg_msj_invertido.nom_solicitante|| '"' || ',' ||
                                                    '"cuenta_debito":' || '"' || rg_msj_invertido.nro_cta_beneficiario || '"' || ',' ||
                                                    '"titular_debito":' || '"' || rg_msj_invertido.nom_beneficiario || '"' || ',' ||
                                                    '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                                                    '"monto":' || '"' || trim(to_char(rg_msj_rec.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                                                    '"moneda_debito":' || '"' || nvl(rg_msj_rec.cod_moneda,'GS') || '"' || ',' ||
                                                    '"nro_operacion":' || '"' || rg_msj_invertido.nro_ref_externa || '"' || ',' ||
                                                    '"fecha_hora":' || '"' || v_fec_notificacion || '"' || ',' ||
                                                    '"cuenta_credito":' || '"' || rg_msj_invertido.nro_cta_solicitante || '"' || ',' ||
                                                    '"titular_credito":' || '"' || rg_msj_invertido.nom_solicitante || '"' || ',' ||
                                                    '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                                                    '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                                                    '"tipo_operacion":' || '"' || 'Aprobación de Solicitud de Devolución' || '"' || ',' ||
                                                    '"comprobante":' || '"' || rg_msj_rec.nro_ref_externa || '"' || ',' ||
                                                    '"doc_debito":' || '"' || rg_msj_invertido.nro_doc_solicitante || '"' || '}';


                                     if v_tip_persona = 'F' then                               
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004DF'),v_inf_json);
                                     else
                                        pr_env_alerta(rg_msj_invertido.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECNOT004DJ'),v_inf_json);
                                     end if;              
                                   exception
                                     when others then
                                       null;
                                   end;   
                           end if;             
                       end if; 
                end if;   
          else --Supera limite o la cuenta no permite el proceso...
            g_lugar :='Supera limite o la cuenta no permite el proceso.';
            pas_spi.pr_gen_rev_dev_004(rg_msj_rec.nro_ref_externa, p_dat_recibidos.nro_ref_msj_original);
          end if;
        else
          --SP nuevo para generar la devolucion(pacs008) del pacs004 en esta parte.
          g_lugar :='Error en el Proceso.'||g_cod_error||' Msj.Error: '||pas_spi.g_msj_error;
          pas_spi.pr_gen_rev_dev_004(rg_msj_rec.nro_ref_externa, p_dat_recibidos.nro_ref_msj_original);  
        end if;

        --Invoca al sp que se encarga de insertar en ba_log_mensajerias.
         g_lugar := 'Registro en BA_LOG_MENSAJERIAS del pacs.004 Nro. Ref.externa'||p_dat_recibidos.nro_ref_externa;
         pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta);
         rg_sol.respuesta    := pas_spi.g_msj_error; 
         p_dat_mensaje         := mensaje;

     end if;

  exception
    when ex_error then
    mensaje.cod_respuesta := pas_spi.g_cod_error;
    mensaje.nom_respuesta := g_nom_respuesta;
    mensaje.des_Respuesta := 'pas_spi.pr_pro_msj_rec_004-'||g_lugar||'-'||sqlerrm;
    --Invoca al SP que se encarga de generar el pacs.008 de devolución del pacs.004
    g_lugar :='Error en el Proceso..'||g_cod_error||' Msj.Error: '||pas_spi.g_msj_error;
    update ge_snp_transferencias t
    set t.tip_rechazo = g_tip_rch,--'AC02',
        t.error       = pas_spi.g_msj_error,
        t.estado      = 'R',
        t.situacion   = 'C'          
     where t.nro_ref_externa = p_dat_recibidos.nro_ref_externa
     and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV');
    pas_spi.pr_gen_rev_dev_004(rg_msj_rec.nro_ref_externa, p_dat_recibidos.nro_ref_msj_original);
    --Invoca al sp que se encarga de insertar en ba_log_mensajerias.
    g_lugar := 'Error durante la recepcion del pacs.004 Nro. Ref.externa'||p_dat_recibidos.nro_ref_externa;
    pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_mensaje         := mensaje;
  end;

EXCEPTION
  when ex_salir then
       mensaje.cod_respuesta := 1;
       mensaje.nom_respuesta := 'Error en pr_pro_msj_rec_004-'||g_lugar;
       mensaje.des_Respuesta:=sqlerrm;
       g_lugar := 'Error: Nro de ref. externa ya existe! '||p_dat_recibidos.nro_ref_externa;
       pas_snp.pr_reg_operacion( p_dat_recibidos.msj_mx , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
       p_dat_mensaje         := mensaje;
  when ex_error then
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_pro_msj_rec_004-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    --Invoca al sp que se encarga de insertar en ba_log_mensajerias.
    g_lugar := 'Error durante el proceso del Mensaje';
    pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 

    p_dat_mensaje         := mensaje;
  WHEN others THEN
    pas_spi.g_cod_error := 150;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_pro_msj_rec_004'||g_lugar;
    mensaje.des_Respuesta :=sqlerrm;
     g_tip_rch:=g_rch_ms03;
     update ge_snp_transferencias t
          set t.tip_rechazo = g_tip_rch,
              t.error       = pas_spi.g_msj_error,
              t.estado      = 'R',
              t.situacion   = 'C'          
        where t.nro_ref_externa = p_dat_recibidos.nro_ref_externa
          and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV');--pacs.004;
    --Invoca al SP que se encarga de generar el pacs.008 de devolución del pacs.004
    g_lugar :='Error en el Proceso...'||g_cod_error||' Msj.Error: '||pas_spi.g_msj_error;
    pas_spi.pr_gen_rev_dev_004(rg_msj_rec.nro_ref_externa, p_dat_recibidos.nro_ref_msj_original);
    --Invoca al sp que se encarga de insertar en ba_log_mensajerias.
    g_lugar := 'Error durante el proceso del Mensaje.';
    pas_snp.pr_reg_operacion( rg_msj_rec.msj_swift , g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    p_dat_mensaje         := mensaje;
END pr_pro_msj_rec_004;
/*
Valida si la funcionalidad de la fase2 está cerificada para la entidad financiera
*/
function fu_val_fun_fase2(p_funcionalidad in varchar2,
                          p_tip_filtro in varchar2,
                          p_filtro in varchar2) return varchar2 is

v_cod_persona   ba_personas.cod_persona%type;
v_valor         ba_per_dat_adicionales.val_parametro%type:='N';
begin
     if p_tip_filtro='S' then --por el  cod. swift

         select p.cod_persona
         into v_cod_persona
         from gv_snp_participantes p
         where p.cod_swift=trim(p_filtro);

     elsif p_tip_filtro='C' then
          v_cod_persona:=trim(p_filtro);
     end if;

     v_valor:=nvl(fue_per_dat_adicional(v_cod_persona,p_funcionalidad),'N');

     return v_valor;
exception
     when no_data_found then
         return 'N';
     when others then
           return 'N';
end fu_val_fun_fase2;
/*
SPI - FASE2  Envío de solicitude pago (pain.013) al MS
*/
procedure pr_obt_tra_pen_013(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtSolicitudPago013,p_dat_mensaje out typ_mensajeria_spi)  is
  /*
  || Procesa transferencias pendientes de ENVIO al SPI, de tipo pacs.008(Mensaje de pago de Crédito Directo)
  */
  v_cod_solicitud    ge_spi_solicitudes.cod_sol_spi%type;
  v_nro_ref_externa  ge_snp_transferencias.nro_ref_externa%type:= NULL;
  v_cant             number(8):=0;
  v_tip_mensaje      ge_spi_solicitudes.cod_msj_swift%type;

  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_tra IS
       select sl.cod_sol_spi,
              sl.nro_ref_externa ref_externa,
              trunc(sl.fec_insercion) fecha,
              to_char(sl.fec_insercion,'HH24:MI:SS') hora,
              it.fus_obt_nom_sub_participante(sl.cod_swi_beneficiario,sl.cod_swi_suc_beneficiario)nom_subpte,
              sl.cod_swi_suc_beneficiario swi_suc_beneficiario,
              (select de.cta_interna_sub
              from ge_snp_patrocinador_det de
              where de.cod_swift_padre=sl.cod_swi_beneficiario
              and de.cod_swift_sub=sl.cod_swi_suc_beneficiario)cta_sub_pte,
              sl.cod_swi_beneficiario swi_beneficiario,
              (select tipo 
              from gv_snp_participantes pp
              where pp.cod_swift=sl.cod_swi_beneficiario)tipo_receptor,
              sl.nom_beneficiario,
              sl.cta_beneficiario,
              sl.doc_beneficiario,
              fue_obt_tip_doc_abreviatura(sl.tip_doc_beneficiario)tip_doc_beneficiario,
              fue_obt_val_max_referencia('TIP_INSTRUMENTO',fug_obt_pardinamico('COD_SPI_SOL_PAGO')) instrumento,
              fue_obt_mon_iso(sl.cod_moneda,null)cod_moneda,
              sl.monto,
              sl.cod_swi_solicitante,
              (select tipo 
              from gv_snp_participantes pp
              where pp.cod_swift=sl.cod_swi_solicitante)tipo_emisor,
              sl.nom_solicitante,
              sl.doc_solicitante,
              fue_obt_tip_doc_abreviatura(sl.tip_doc_solicitante)tip_doc_solicitante,
              sl.cta_solicitante,
              sl.cod_tip_operacion,
              sl.info_remesa inf_reglamentarios,
              sl.info_envio,
              sl.uetr
              from ge_spi_solicitudes sl 
              where sl.cod_msj_swift=v_tip_mensaje
              and sl.est_solicitud='U'
              and sl.sit_solicitud='P'
              and sl.fec_recepcion is null
              and rownum=1
              order by 1 asc
              for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  p_dat_solicitud    := typ_ObtSolicitudPago013();
  v_tip_mensaje      :=fug_obt_pardinamico('COD_SPI_SOL_PAGO');
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe pain.013';

  FOR a IN cu_msj_tra LOOP

    v_cod_solicitud   :=a.cod_sol_spi;
    v_nro_ref_externa :=a.ref_externa;

    p_dat_solicitud.nro_ref_externa            := a.ref_externa;
    p_dat_solicitud.fecha                      := a.fecha;    
    p_dat_solicitud.hora                       := a.hora;     
    p_dat_solicitud.des_suc_sol_beneficiario   := a.nom_subpte;       
    p_dat_solicitud.swi_suc_sol_beneficiario   := a.swi_suc_beneficiario;
    p_dat_solicitud.cta_suc_sol_beneficiario   := a.cta_sub_pte;
    p_dat_solicitud.swi_pte_beneficiario       := a.swi_beneficiario;
    p_dat_solicitud.tip_pte_beneficiario       := a.tipo_receptor;
    p_dat_solicitud.nom_beneficiario           := a.nom_beneficiario;
    p_dat_solicitud.nro_cta_beneficiario       := a.cta_beneficiario;
    p_dat_solicitud.nro_doc_beneficiario       := a.doc_beneficiario;
    p_dat_solicitud.cod_tip_doc_beneficiario   := a.tip_doc_beneficiario;
    p_dat_solicitud.instrumento                := a.instrumento;
    p_dat_solicitud.moneda                     := a.cod_moneda;
    p_dat_solicitud.monto                      := a.monto;
    p_dat_solicitud.swi_pte_solicitante        := a.cod_swi_solicitante;
    p_dat_solicitud.tip_pte_solicitante        := a.tipo_emisor;
    p_dat_solicitud.nom_solicitante            := a.nom_solicitante;
    p_dat_solicitud.nro_doc_solicitante        := a.doc_solicitante;
    p_dat_solicitud.cod_tip_doc_solicitante    := a.tip_doc_solicitante;
    p_dat_solicitud.nro_cta_solicitante        := a.cta_solicitante;
    p_dat_solicitud.cod_tip_operacion          := a.cod_tip_operacion;
    p_dat_solicitud.info_remesa                := a.inf_reglamentarios;
    p_dat_solicitud.info_envio                 := a.info_envio;
    p_dat_solicitud.uetr                       := a.uetr;
    ---Registro de parametros 
    g_lugar:='Registro de parametros en log '||a.ref_externa;
    pas_snp.pr_reg_operacion('Tipo mensaje enviado: pacs.013'||chr(10) ||
         ' Cod. Solicitud: '||v_cod_solicitud|| chr(10) || 
         ' Ref. externa: '||v_nro_ref_externa|| chr(10) ||
         ' Tip. Operacion: '||a.cod_tip_operacion|| chr(10) ||
         ' Fecha: '||a.fecha|| chr(10) || 
         ' hora: '||a.hora|| chr(10) || 
         ' Sub-pte: '||a.nom_subpte|| chr(10) || 
         ' Swift. sub-pte: '||a.swi_suc_beneficiario|| chr(10) || 
         ' Cta. Sub. pte.: '||a.cta_sub_pte|| chr(10) || 
         ' Swift pte. receptor: '||a.swi_beneficiario|| chr(10) ||
         ' Tipo Receptor: '||a.tipo_receptor|| chr(10) ||
         ' Nom. Receptor: '||a.nom_beneficiario|| chr(10) || 
         ' Cuenta Receptor: '|| a.cta_beneficiario|| chr(10) || 
         ' Documento receptor: '||a.doc_beneficiario|| chr(10) || 
         ' Tipo doc receptor: '||a.tip_doc_beneficiario|| chr(10) || 
         ' Instrumento: '||a.instrumento|| chr(10) || 
         ' Moneda: '||a.cod_moneda|| chr(10) || 
         ' Monto: '||a.monto|| chr(10) || 
         ' Swift solicitante: '||a.cod_swi_solicitante|| chr(10) || 
         ' Tipo Emisor: '||a.tipo_emisor|| chr(10) ||
         ' Solicitante: '||a.nom_solicitante|| chr(10) ||
         ' Documento solicitante: '||a.doc_solicitante|| chr(10) ||
         ' Tipo doc. solicitante: '||a.tip_doc_solicitante|| chr(10) || 
         ' Cuenta solicitante: '||a.cta_solicitante|| chr(10) ||
         ' Swift Solicitante: '||a.cod_swi_solicitante|| chr(10) ||
         ' Inf. reglamentaria: '||a.inf_reglamentarios|| chr(10) ||
         ' Inf. envio: '||a.info_envio||chr(10) ||
         ' UETR: '||a.uetr
         , g_lugar||' Cod. Sol.: '||v_cod_solicitud);   

  END LOOP;
  IF v_cod_solicitud IS NOT NULL THEN
    g_lugar:='Asigna datos para la cabecera de informe pain.013';
    p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi(PAS_SPI.fu_tip_msj_spi(v_tip_mensaje),v_nro_ref_externa);
    g_lugar:='Actualizacion de transferencia pacs.013 a bloqueado';
    --Modo de bloquear el registro
    UPDATE ge_spi_solicitudes sl
    SET sl.sit_solicitud='B'
    WHERE sl.cod_sol_spi=v_cod_solicitud;

    g_lugar:='Recupera cantidad de reintentos pain.013';
    begin
      select nvl( max(cantidad),0) into v_cant 
      from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
        when others then
          v_cant:=0;
    end;

    g_lugar:='Insercion de reintentos pain.013';

    insert into ge_spi_log_controles(nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
    values (v_cod_solicitud, v_nro_ref_externa, PAS_SPI.fu_tip_msj_spi(v_tip_mensaje),trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);

    g_lugar:='Proceso de envio de Sol. Pago, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Pain.013 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'Registro procesado';
    p_dat_mensaje         := mensaje;
  else

    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_mensaje         := mensaje;

  end if;

EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 50;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;
    UPDATE ge_spi_solicitudes sl
    SET sl.est_solicitud='C'
    WHERE sl.cod_sol_spi=v_cod_solicitud;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_013-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de pain.013, Ref. externa: '||v_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje        := mensaje;
END pr_obt_tra_pen_013;
PROCEDURE pr_gen_rev_dev_004(p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type,
                             p_nro_ref_msj_original in ge_spi_solicitudes.nro_ref_msj_original%type)
 /*Genera la reversion de un pacs.004 que no se haya podido acreditar por no cumplir las validaciones  */
 /*Devolvemos con un pacs.008 tomando como referencia los datos de la transferencia original */
 /*Contemplando los campos que son especificos de la devolución (fechas, monto, concepto) */
IS
  ex_salir EXCEPTION;
  ex_error EXCEPTION;
  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,'OK',null);
  rg_msj_rev  ge_snp_transferencias%rowtype;--variable de registro para la devolucion (pacs.008)
  rg_msj_004  ge_snp_transferencias%rowtype;--variable de registro con datos del pacs.004
  v_nro_referencia      ge_snp_transferencias.nro_referencia%type;
  v_dir_notificaciones  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_RECHAZO_LIM');
BEGIN
  begin
     pre_ini_aplicacion;
     pas_spi.pr_ini_registros;
     pas_spi.pr_ini_var_spi;
     pae_cnf.g_cod_modulo := 1;
   end;

   begin
     pas_snp.pr_ini_variables;
     pas_spi.g_cod_error := 0;
     pas_spi.g_msj_error := NULL;
     g_nom_respuesta:='Proceso de Reversión realizado correctamente.';--Respuesta corta a arrojar en el campo nom_respuesta de type typ_mensajeria_spi(out)

     --Recupero datos de la transferencia original(pacs.008) para realizar la reversion del pacs.004.
     begin
              select *--recupero todos los datos de la transferencia original  
              into rg_msj_rev
              from ge_snp_transferencias t 
              where t.fec_recepcion is null
               and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_PCD')--pacs.008 original
               and t.situacion = 'L'
               and t.estado = 'A'
               and t.nro_ref_externa = p_nro_ref_msj_original;
         exception
               when no_data_found then
                   pas_spi.g_cod_error := 244;
                   g_nom_respuesta := 'No se encuentra la transf. que se intenta devolver: -'||p_nro_ref_msj_original;
                   pas_spi.g_msj_error := g_nom_respuesta;
                   raise ex_error;
     end;

     --Recupero datos del pacs.004 que son necesarios para insertar el 008 de devolución.
     begin
              select *--recupero todos los datos de la transferencia original  
              into rg_msj_004
              from ge_snp_transferencias t 
              where t.fec_recepcion is not null
               and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV')--pacs.008 original
               and t.nro_ref_externa = p_nro_ref_externa;
         exception
               when no_data_found then
                   pas_spi.g_cod_error := 245;
                   g_nom_respuesta := 'No se encuentra la transf. que se intenta devolver: -'||p_nro_ref_msj_original;
                   pas_spi.g_msj_error := g_nom_respuesta;
                   raise ex_error;
     end;

     --- Se Inserta en ge_snp_transferencias
       BEGIN
         g_lugar :=  'Asignacion de valores varios para ge_snp_transferencias ';
         v_nro_referencia           := pas_snp.fu_obt_sig_nro_referencia(g_fec_actual_h) ;
         rg_msj_rev.nro_referencia  := v_nro_referencia;
         rg_msj_rev.nro_ref_externa := pas_spi.fu_obt_sig_nro_ref_externa;
         rg_msj_rev.fec_valor       := g_fec_valor;
         rg_msj_rev.fec_ingreso     := rg_msj_rev.fec_valor;
         rg_msj_rev.fec_recepcion   := null;
         rg_msj_rev.fecha           := null;
         rg_msj_rev.hora            := null;
         rg_msj_rev.cod_usuario     := null;
         rg_msj_rev.monto          := rg_msj_004.monto;
         rg_msj_rev.concepto       := ('/REV/'||rg_msj_004.nro_ref_externa);
         rg_msj_rev.situacion      := 'P';
         rg_msj_rev.estado         := 'U';

         --Inserto la transferencia a enviarse como reversion del pacs004
           BEGIN 
           g_lugar :=  'Insercion en ge_snp_transferencias ';
             INSERT INTO ge_snp_transferencias
               (nro_referencia,
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
                cod_servicio)
             VALUES
               (rg_msj_rev.nro_referencia,
                rg_msj_rev.nro_lote,
                rg_msj_rev.nro_sec_lote,
                rg_msj_rev.cod_modulo,
                rg_msj_rev.cod_modalidad,
                rg_msj_rev.cod_oficina,
                rg_msj_rev.cod_msj_swift,
                rg_msj_rev.cod_tip_operacion,
                rg_msj_rev.cod_sub_tip_operacion,
                rg_msj_rev.msj_swift,
                rg_msj_rev.fec_ingreso,
                rg_msj_rev.fec_recepcion,
                rg_msj_rev.fec_valor,
                rg_msj_rev.fecha,
                rg_msj_rev.hora,
                rg_msj_rev.cod_usuario,
                nvl(rg_msj_rev.cod_moneda,'GS'),
                rg_msj_rev.monto,
                rg_msj_rev.cod_per_solicitante,
                rg_msj_rev.nom_solicitante,
                rg_msj_rev.dir_solicitante,
                rg_msj_rev.cod_tip_doc_solicitante,
                rg_msj_rev.nro_doc_solicitante,
                rg_msj_rev.nro_cta_solicitante,
                rg_msj_rev.cod_swi_pte_solicitante,
                rg_msj_rev.cod_swi_suc_solicitante,
                rg_msj_rev.nro_cta_pte_solicitante,
                rg_msj_rev.nro_cta_suc_pte_solicitante,
                rg_msj_rev.cod_per_beneficiario,
                rg_msj_rev.nom_beneficiario,
                rg_msj_rev.dir_beneficiario,
                rg_msj_rev.cod_tip_doc_beneficiario,
                rg_msj_rev.nro_doc_beneficiario,
                rg_msj_rev.nro_cta_beneficiario,
                rg_msj_rev.cod_swi_pte_beneficiario,
                rg_msj_rev.cod_swi_suc_beneficiario,
                rg_msj_rev.nro_cta_pte_beneficiario,
                rg_msj_rev.nro_cta_suc_pte_beneficiario,
                rg_msj_rev.concepto,
                rg_msj_rev.observacion,
                rg_msj_rev.nro_ref_externa,
                rg_msj_rev.tip_cargo,
                rg_msj_rev.ind_valor,
                rg_msj_rev.situacion,
                rg_msj_rev.estado,
                rg_msj_rev.tip_rechazo,
                rg_msj_rev.prioridad,
                rg_msj_rev.nro_operacion,
                rg_msj_rev.tip_mensaje,
                rg_msj_rev.ref_oid,
                rg_msj_rev.error,
                rg_msj_rev.origen,
                rg_msj_rev.plataforma,
                rg_msj_rev.indemnizado,
                rg_msj_rev.cod_servicio);
                --pas_snp.pr_ins_transferencias(rg_msj_rev); --mejorar luego
           exception
           when dup_val_on_index then
            --Mensajeria duplicada
            null;
            when others THEN
                  pas_spi.g_cod_error := 300;
                  pas_spi.g_msj_error := 'Error al insertar en GE_SNP_TRANSFERENCIAS. Nro. Ref.: ' || p_nro_ref_externa || ' - ' || sqlerrm;

           END;
       EXCEPTION
        when others then
           pas_spi.g_cod_error := 301;
           g_nom_respuesta :='Error en la insercion de GE_SNP_TRANSFERENCIAS';
           pas_spi.g_msj_error :=g_nom_respuesta||sqlerrm;    
       END;

       If sql%rowcount > 0 and pas_spi.g_cod_error = 0 then
         -- Actualizo situacion y estado para generar movimientos --
         g_lugar := 'Actualizar situacion y estado de la transf. y sol. con ref.' || p_nro_ref_externa;
          begin
              IF p_nro_ref_externa is not null then
              update ge_snp_transferencias t
                 set t.situacion   = 'C', 
                     t.estado      = 'R',
                     t.error       = rg_msj_004.error        
              where t.nro_ref_externa = p_nro_ref_externa
                and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV')
                and t.fec_recepcion is not null; 
                commit;
              IF sql%notfound THEN
                 pas_snp.pr_reg_operacion('Error al intentar actualizar la Transferencia: '||sqlerrm,'Ref. Externa Nro.: '||p_nro_ref_externa);
              END IF;
              END IF;  
          exception
            when others then
               mensaje.cod_respuesta := 1;
               mensaje.nom_respuesta := 'Error al liquidar  la operacion con ref.' ||p_nro_ref_externa;
               mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                raise ex_error;
          end;

         --Actualiza la situacion y estado de la solicitud
         begin
              IF p_nro_ref_externa is not null then
              update ge_spi_solicitudes
                 set sit_solicitud = 'C',
                     est_solicitud = 'R',
                     respuesta = respuesta ||chr(10)|| rg_msj_004.error
              where nro_ref_externa = p_nro_ref_externa
                and cod_msj_swift = fug_obt_pardinamico('COD_SPI_DEV');
                commit;
              IF sql%notfound THEN
                 pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Ref Externa Nro.: '||p_nro_ref_externa);
              END IF;
              END IF;  
          exception
            when others then
               mensaje.cod_respuesta := 2;
               mensaje.nom_respuesta := 'Error al cambiar estado de la Sol. Devolucion de la operacion con ref.' ||p_nro_ref_externa;
               mensaje.des_Respuesta := 'No se pudo procesar la actualizacion';
                raise ex_error;
          end;
       end if;  

    g_lugar:='Envio de notificacion por error';
    begin
              if v_dir_notificaciones is not null then

                 it_mail.mail( fug_obt_dir_correo,
                               v_dir_notificaciones,
                               'Reversa de una devolucion recibida: '||p_nro_ref_externa,
                               'Devolucion recibida con inconvenientes, favor verificar'
                               || chr(10) ||'Nro. Referencia externa: '||p_nro_ref_externa
                               || chr(10) ||'Fecha Ingreso: '||to_char( rg_msj_004.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS')
                               || chr(10) ||'Monto: '||ltrim(rtrim(to_char(rg_msj_004.monto,'999,999,999,999,999.99'))));

              end if;
  exception
    when others then
       null;
  end;

   end;
exception when ex_error then
  pas_snp.pr_reg_operacion( 'Error en el proceso de reversion ,Nro. Ref.externa: '||p_nro_ref_msj_original , g_lugar|| '|' ||  pas_spi.g_cod_error|| '|' ||pas_spi.g_msj_error );
  pas_spi.g_cod_error := 110;
  pas_spi.g_msj_error := g_lugar || '-' || sqlerrm;
  when others then
    pas_snp.pr_reg_operacion( 'Error en el proceso de reversion ,Nro. Ref.externa: '||p_nro_ref_msj_original , g_lugar|| '|' ||  pas_spi.g_cod_error|| '|' ||pas_spi.g_msj_error );
    pas_spi.g_cod_error := 111;
    pas_spi.g_msj_error := g_lugar || '-' || sqlerrm;   
END pr_gen_rev_dev_004;
/*
Cancela de forma automática los circuitos que no fueron autorizados/rechazados.
*/                            
procedure pr_can_aut_solicitudes is
v_cir_004      wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SPI_CIR_DEV_004');
v_cir_056      wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SPI_CIR_SOL_DEV_056');
v_cir_013      wf_circuitos.cod_tip_circuito%type:=fug_obt_pardinamico('SPI_CIR_PAG_013');
v_causa        ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_MOT_REC_AUTOM');
cursor c_cir is
     select *
      from wf_circuitos w
      where w.cod_tip_circuito in (v_cir_004,v_cir_056,v_cir_013)
      and w.estado='E' --ejecucion
      and exists (select 1 from ge_spi_solicitudes tr
                   where tr.cod_sol_spi=w.referencia
                   and tr.fec_recepcion is null
                   union all
                  select 1 from ge_spi_solicitudes tr
                   where tr.nro_referencia=w.referencia
                   and tr.fec_recepcion is null);
begin
 begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

  for reg in c_cir loop 

      IF reg.cod_circuito is not null then
      update wf_circuitos cr
      set cr.estado='C',
      cr.fec_fin=trunc(sysdate)
      where cr.cod_circuito=reg.cod_circuito;
      IF sql%notfound THEN
         pas_snp.pr_reg_operacion('Error al intentar actualizar el circuito: '||sqlerrm,'Nro.: '||reg.cod_circuito);
      END IF;
      END IF;

      IF reg.cod_circuito is not null and reg.cod_tar_actual is not null then   
      update wf_cir_tareas ta
      set ta.fec_finalizacion=trunc(sysdate),
      ta.estado='C',
      ta.comentario='Canc. automatica por falta de respuesta',
      ta.cod_usuario=user,
      ta.cod_causa=v_causa
      where ta.cod_circuito=reg.cod_circuito
      and ta.cod_tarea=reg.cod_tar_actual;
      IF sql%notfound THEN
         pas_snp.pr_reg_operacion('Error al intentar actualizar la tarea del circuito: '||sqlerrm,'Nro. Tarea: '||reg.cod_tar_actual);
      END IF;
      END IF;

      IF reg.referencia is not null then
      update ge_spi_solicitudes sl 
      set sl.sit_solicitud='C',
      sl.est_solicitud='R'
      where sl.cod_sol_spi=reg.referencia;
      IF sql%notfound THEN
         pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||reg.referencia);
      END IF;
      END IF;

      --Si es circuito de Devoluciones debe reversar los movimientos generados
      if reg.cod_tip_circuito=v_cir_004 then 
          --reversar movimiento 
         pas_snp.pr_rev_ope_con_swift (reg.referencia, 'Circuito de Aprobación Rechazado', 'R');
          IF pas_snp.fu_obt_cod_error <> 0 THEN
             raise_application_error( -20201, pas_snp.fu_obt_msj_error );
          else
            --actualizo transferencia a C R
            IF reg.referencia is not null then
            update ge_snp_transferencias t
               set t.situacion = 'C',
                   t.estado = 'R',
                   t.error = 'Canc. automatica por falta de respuesta'
             where t.nro_referencia = reg.referencia
               and t.fec_recepcion is null;
            IF sql%notfound THEN
               pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Referencia Nro.: '||reg.referencia);
            END IF;
            END IF;   

               IF reg.referencia is not null then
               update ge_spi_solicitudes ss 
                  set ss.sit_solicitud='C',
                      ss.est_solicitud='R',
                      ss.respuesta=ss.respuesta||chr(10)||'Canc. automatica por falta de respuesta'
               where ss.nro_referencia=reg.referencia;
               IF sql%notfound THEN
                  pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Referencia Nro.: '||reg.referencia);
               END IF;
               END IF;

          END IF;
      end if;
  end loop;
exception 
     when others then 
           null; --si se produce alguna excepción no retringir la ejecución de los otros procesos
end pr_can_aut_solicitudes;
/*
Se aplican las validaciones que determinan si se puede generar una Solicitud de Devolucion por una transf. SPI.
*/    
procedure pr_val_sol_dev_spi(p_ref_tra_original in varchar2,
                             p_mto_devolver     in number,
                             p_origen           in varchar2,
                             p_cod_retorno      out number,
                             p_men_retorno      out varchar2)is

r_gtran               pas_snp.rg_msj;
e_val                 exception;
v_nro_referencia      ge_snp_transferencias.nro_referencia%type;
v_can_dias            number(3):=0;
v_can_registro        number(5):=0;
v_can_conjunta        number(5):=0;
v_hab_solicitante     varchar2(1);
v_hab_beneficiario    varchar2(1);
v_existe              varchar2(1);   
v_can_otros           number(5):=0;  
v_sol_dev_aprobado    number(5):=0; 

begin

      p_cod_retorno       := 0;
      p_men_retorno       := 'OK'; 
      v_hab_solicitante   := null;
      v_hab_beneficiario  := null;
      pr_ini_var_spi;

       Begin
         select t.nro_referencia
         into v_nro_referencia
         from ge_snp_transferencias t
         where t.nro_ref_externa = p_ref_tra_original;
         --obtener el registro de la transferencia
         pas_snp.pr_ini_registros;
         pas_snp.pr_obt_mensaje(v_nro_referencia,'N');
         r_gtran := pas_snp.fu_obt_reg_transferencias;
         if pas_snp.fu_obt_cod_error!=0 then
             p_cod_retorno:=39;
             p_men_retorno:=pas_snp.fu_obt_msj_error;
             raise e_val;
         end if;
       exception
            when no_data_found then
                p_cod_retorno:=40;
                p_men_retorno:='No se encuentra la transferencia original para la Ref_externa: '||p_ref_tra_original;
                raise e_val;
       end;  

       --buscamos el registro del camt.056 para los casos de recepcion--
       begin  
         select 'S'
           into v_existe
           from ge_spi_solicitudes s
          where s.nro_ref_msj_original = p_ref_tra_original
            and s.fec_recepcion is not null
            and rownum = 1;
        exception
          when no_data_found then
            v_existe := 'N';
        end;

        --Si se intenta enviar nuevamente una solicitud de devolucion por una transferencia ya devuelta.
       begin 
        select count(*)
        into v_sol_dev_aprobado
        from ge_spi_solicitudes s
       where s.nro_ref_msj_original = p_ref_tra_original
         and s.est_solicitud = 'A'
         and s.sit_solicitud = 'L';
       exception 
        when others then
          v_sol_dev_aprobado := 0;
       end;

       if v_sol_dev_aprobado > 0 then
          p_cod_retorno:=54;
          p_men_retorno:='No se puede hacer una Solicitud de devolución, por una transferencia que ya fue devuelta.';
          return;
       end if;

       --validaciones
       if r_gtran.cod_msj_swift!=fug_obt_pardinamico( 'COD_SPI_PCD' ) then
          p_cod_retorno:=41;
          p_men_retorno:='Solo se pueden devolver transferencias SPI';
          return;
       end if;
        /*
       Si es un pacs008 donde la cuenta de origen no es GS, no puede solicitarse su devolucion
       porque no está contemplado realizar operaciones de cambio para transferencias recibidas, sólo
       se contempla para las enviadas
       */
       if r_gtran.fec_recepcion is null and FUG_OBT_MON_CTA(r_gtran.nro_cta_solicitante)!=g_cod_mon_local then
          p_cod_retorno:=55;
          p_men_retorno:='No se puede solicitar la devolucion de una transferencia con operacion de cambio';
          return;
       end if;
       --si es not null es una transf recibida este deberia saltar en GMSNP103 pero no GMSNPSOL
        if v_existe = 'S' then 
         if r_gtran.fec_recepcion is null then
            p_cod_retorno:=42;
            p_men_retorno:='La referencia corresponde a una transferencia enviada.';
            return;
         end if;
        else
          if r_gtran.fec_recepcion is not null then
            p_cod_retorno:=53;
            p_men_retorno:='La referencia corresponde a una transferencia recibida.';
            return;
         end if;
        end if;
      -- 
       if r_gtran.situacion!='L' and r_gtran.estado!='A' then
          p_cod_retorno:=43;
          p_men_retorno:='La transferencia inicial no se encuentra liquidada.';
          return;
       end if;
       --monto a devolver 0 , rechazar solicitud
       if p_mto_devolver <= 0 then
          p_cod_retorno:=44;
          p_men_retorno:='Monto a Solicitar devolucion debe ser mayor a 0.';
          return;
       end if;
       --el monto a devolver no puede ser superior al monto de la tranf. inicial
       if p_mto_devolver > r_gtran.monto then
          p_cod_retorno:=45;
          p_men_retorno:='Monto a Solicitar devolucion es superior al monto de la transferencia inicial.';
          return;
       end if;
       --la transf. no puede ser devuelva si ya pasaron X dias desde su liquidacion
       v_can_dias:=fug_obt_pardinamico('SPI_CAN_DIA_SOL_DEVOLUCION');

       if trunc(sysdate)-r_gtran.fec_valor > v_can_dias then
          p_cod_retorno:=46;
          p_men_retorno:='No se puede realizar la solicitud de Devolucion porque la transferencia original a superado los '||v_can_dias||' dias.';
          return;
       end if;

       --si la transf. original ya fue solicitada, rechazar solicitud.
       IF v_existe = 'N' then --Para los enviados controlamos de esta forma
         Begin
           select count(*)
           into v_can_registro
           from ge_spi_solicitudes sl
           where sl.nro_ref_msj_original=p_ref_tra_original
           and sl.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_SOL_DEV')
           and sl.fec_recepcion is null
           and sl.est_solicitud in('A','S','U','W'); --Aprobado/Solicitado/Pendiente de envio/Enviado a BCP
         exception
           when others then
             v_can_registro := 0;
         end;    
       ELSE --Para los recibidos controlamos de esta forma
         Begin
           select count(*)
           into v_can_registro
           from ge_spi_solicitudes sl
           where sl.nro_ref_msj_original=p_ref_tra_original
           and sl.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_SOL_DEV')
           and sl.fec_recepcion is not null
           and sl.est_solicitud in('A'); --Aprobado 
         exception
           when others then
             v_can_registro := 0;
         end;
       END IF;

       if v_can_registro>0 then
          p_cod_retorno:=47;
          p_men_retorno:='Existe una solicitud de Devolucion en Curso o Aprobado.';
          return;
       end if;

       --Valida Funcionalidad fase2
       v_hab_solicitante := fu_val_fun_fase2('SPI_PTE_CER_SOL_DEVOL','S',r_gtran.cod_swi_pte_solicitante);

       if v_hab_solicitante = 'N' then
          p_cod_retorno:=48;
          p_men_retorno:='Funcionalidad no certificada para la entidad Solicitante.';
          return;
       end if;

       v_hab_beneficiario := fu_val_fun_fase2('SPI_PTE_CER_SOL_DEVOL','S',r_gtran.cod_swi_pte_beneficiario);

       if v_hab_beneficiario = 'N' then
          p_cod_retorno:=49;
          p_men_retorno:='Funcionalidad no certificada para la entidad Beneficiaria.';
          return;
       end if;

       if r_gtran.cod_tip_operacion = '002' then 
          p_cod_retorno:=51;
          p_men_retorno:='No se puede hacer una Solicitud de devolución a un Sub-Participante.';
       end if;

       --si la transf. original es por otro tipo de solicitudes.
       select count(*)
       into v_can_otros
       from ge_spi_solicitudes sl
       where sl.nro_ref_msj_original=p_ref_tra_original
       and sl.cod_msj_swift not in (fug_obt_pardinamico( 'COD_SPI_DEV'),
                                    fug_obt_pardinamico( 'COD_SPI_SOL_DEV'))
       and sl.fec_recepcion is not null ;

       if v_can_otros > 0 then
          p_cod_retorno:=52;
          p_men_retorno:='No se puede hacer una Solicitud de devolución, por una respuesta a otro tipo de solicitudes.';
          return;
       end if;

exception 
    when others then
        p_cod_retorno:=50;
        p_men_retorno:=sqlerrm;
end;
/*
Devolver un pacs008 en respuesta a un pain.013 que no se puedo acreditar
*/
procedure pr_gen_rev_dev_013(p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                             p_cod_respuesta  out number,
                             p_mensaje        out varchar2,
                             p_ref_devolucion out number) is

rg_mensaje            pas_snp.rg_msj;
v_nro_referencia      ge_snp_transferencias.nro_referencia%type;
r_gtran               pas_snp.rg_msj;
begin
     p_cod_respuesta:=0;
     p_mensaje      :='OK';
     pas_snp.pr_obt_mensaje (p_nro_referencia,'N');

     if pas_snp.fu_obt_cod_error <> 0 then
        p_cod_respuesta:=pas_snp.fu_obt_cod_error;
        p_mensaje      :=pas_snp.fu_obt_msj_error;
        return;
     else
         rg_mensaje := pas_snp.fu_obt_reg_transferencias;
     end if;

     lp_ver_horario(3);

     v_nro_referencia                 := pas_snp.fu_obt_sig_nro_referencia(g_fec_actual_h);
     r_gtran.nro_referencia           := v_nro_referencia;
     r_gtran.cod_msj_swift            := rg_mensaje.cod_msj_swift;  
     r_gtran.cod_tip_operacion        := rg_mensaje.cod_tip_operacion; 
     r_gtran.cod_sub_tip_operacion    := rg_mensaje.cod_sub_tip_operacion; 
     r_gtran.fec_valor                := g_fec_valor;
     r_gtran.nro_cta_solicitante      := rg_mensaje.nro_cta_beneficiario;
     r_gtran.nro_cta_pte_solicitante  := rg_mensaje.nro_cta_pte_beneficiario;
     r_gtran.cod_swi_pte_solicitante  := rg_mensaje.cod_swi_pte_beneficiario;
     r_gtran.nro_cta_beneficiario     := rg_mensaje.nro_cta_solicitante;
     r_gtran.cod_swi_suc_beneficiario := rg_mensaje.cod_swi_suc_solicitante;
     r_gtran.cod_moneda               := rg_mensaje.cod_moneda;
     r_gtran.monto                    := rg_mensaje.monto;
     r_gtran.cod_modulo               := rg_mensaje.cod_modulo;
     r_gtran.cod_modalidad            := rg_mensaje.cod_modalidad;
     r_gtran.cod_oficina              := rg_mensaje.cod_oficina;
     r_gtran.fec_ingreso              := g_fec_actual_h; 
     r_gtran.cod_per_solicitante      := rg_mensaje.cod_per_beneficiario;
     r_gtran.nom_solicitante          := rg_mensaje.nom_beneficiario;
     r_gtran.dir_solicitante          := rg_mensaje.dir_beneficiario;
     r_gtran.cod_tip_doc_solicitante  := rg_mensaje.cod_tip_doc_beneficiario;
     r_gtran.nro_doc_solicitante      := rg_mensaje.nro_doc_beneficiario;
     r_gtran.nom_beneficiario         := rg_mensaje.nom_solicitante;
     r_gtran.dir_beneficiario         := rg_mensaje.dir_solicitante;
     r_gtran.cod_tip_doc_beneficiario := rg_mensaje.cod_tip_doc_solicitante;
     r_gtran.nro_doc_beneficiario     := rg_mensaje.nro_doc_solicitante;
     r_gtran.nro_cta_pte_beneficiario := rg_mensaje.nro_cta_pte_solicitante;
     r_gtran.cod_swi_pte_beneficiario := rg_mensaje.cod_swi_pte_solicitante;
     r_gtran.observacion              := rg_mensaje.observacion;
     r_gtran.ind_valor                := rg_mensaje.ind_valor;
     r_gtran.nro_ref_externa          := pas_spi.fu_obt_sig_nro_ref_externa;
     r_gtran.tip_cargo                := rg_mensaje.tip_cargo;
     r_gtran.situacion                := 'P' ; -- Pendiente de Envio a BCP
     r_gtran.estado                   := 'U' ;
     r_gtran.nro_operacion            := v_nro_referencia ;
     r_gtran.tip_mensaje              := rg_mensaje.tip_mensaje;
     r_gtran.origen                   := rg_mensaje.origen;
     r_gtran.plataforma               := 'S';
     r_gtran.concepto                 := '/REV/'||p_nro_referencia;
     r_gtran.indemnizado              := 'N';
     r_gtran.prioridad                := fus_snp_obt_prioridad(r_gtran.cod_msj_swift, r_gtran.cod_tip_operacion, r_gtran.cod_sub_tip_operacion);
     r_gtran.tip_rechazo              := rg_mensaje.tip_rechazo;

     pas_snp.pr_ini_variables;
     pas_snp.pr_ins_transferencias(r_gtran);

    if pas_snp.fu_obt_cod_error!=0 then
       p_cod_respuesta:=pas_snp.fu_obt_cod_error;
       p_mensaje      :=pas_snp.fu_obt_msj_error;
       return;
    end if;    
    p_ref_devolucion:= v_nro_referencia;     
exception 
    when others then 
       p_cod_respuesta:=51;
       p_mensaje      :=sqlerrm;
end;
/*
Procesa el envío de camt.056 - Solicitud de Devolución de transferencia
*/
procedure pr_pro_env_056(p_ref_tra_original in varchar2,
                         p_mto_devolver     in number,
                         p_origen           in varchar2,
                         p_mot_solicitud    in varchar2,
                         p_modo             in varchar2,
                         p_reg_devolucion   out pas_snp.rg_msj,
                         p_cod_retorno      out number,
                         p_men_retorno      out varchar2,
                         p_cod_solicitud    in out number,
                         p_usuario          in varchar2) is

 e_val                 exception; 
 v_nro_referencia      ge_snp_transferencias.nro_referencia%type;
 v_tip_mensaje         ge_snp_transferencias.cod_msj_swift%type:=fug_obt_pardinamico( 'COD_SPI_SOL_DEV');
 rg_tran               pas_snp.rg_msj;
 v_estado              ge_snp_transferencias.estado%type;
 rg_sol                ge_spi_solicitudes%rowtype;

begin
       p_cod_retorno         :=0;
       p_men_retorno         :='OK';                 
       pr_ini_var_spi;

       Begin
         select t.nro_referencia
         into v_nro_referencia
         from ge_snp_transferencias t
         where t.nro_ref_externa = p_ref_tra_original;
         --obtener el registro de la transferencia
         pas_snp.pr_ini_registros;
         pas_snp.pr_obt_mensaje (v_nro_referencia,'N');
         rg_tran := pas_snp.fu_obt_reg_transferencias;
         if pas_snp.fu_obt_cod_error!=0 then
             p_cod_retorno:=52;
             p_men_retorno:=pas_snp.fu_obt_msj_error;
             raise e_val;
         end if;
       exception
            when no_data_found then
                p_cod_retorno:=53;
                p_men_retorno:='No se encuentra la transferencia original para Solicitar Devolucion: '||p_ref_tra_original;
                raise e_val;
       end;

        if p_origen = 'I' then  --por ITGF
           v_estado:='S';
        else -- por HB o APP
           v_estado:='U';
        end if;

       --P_MODO:  A (Autoriza) - R (Registra) - C (Completo: registra y autoriza)
       if p_modo in ('C','R') then
          rg_sol.nro_referencia       := null;
          rg_sol.nro_ref_externa      := pas_spi.fu_obt_sig_nro_ref_externa;
          rg_sol.cod_msj_swift        := v_tip_mensaje;
          rg_sol.fec_recepcion        := null;
          rg_sol.cod_moneda           := rg_tran.cod_moneda;
          rg_sol.monto                := p_mto_devolver;
          rg_sol.cod_mot_solicitud    := p_mot_solicitud;
          rg_sol.msj_mx               := rg_tran.msj_swift;
          rg_sol.sit_solicitud        := 'P';
          rg_sol.est_solicitud        := v_estado;
          rg_sol.respuesta            := 'Pago Original: '||p_ref_tra_original;
          rg_sol.nro_ref_msj_original := p_ref_tra_original;
          rg_sol.nom_solicitante      := rg_tran.nom_solicitante;
          rg_sol.doc_solicitante      := rg_tran.nro_doc_solicitante;
          rg_sol.tip_doc_solicitante  := rg_tran.cod_tip_doc_solicitante;
          rg_sol.cta_solicitante      := rg_tran.nro_cta_solicitante;
          rg_sol.cod_swi_solicitante  := rg_tran.cod_swi_pte_solicitante;
          rg_sol.cod_swi_suc_solicitante := rg_tran.cod_swi_suc_solicitante;
          rg_sol.nom_beneficiario     := rg_tran.nom_beneficiario;
          rg_sol.doc_beneficiario     := rg_tran.nro_doc_beneficiario;
          rg_sol.tip_doc_beneficiario := rg_tran.cod_tip_doc_beneficiario;
          rg_sol.cta_beneficiario     := rg_tran.nro_cta_beneficiario;
          rg_sol.cod_swi_beneficiario := rg_tran.cod_swi_pte_beneficiario;
          rg_sol.cod_swi_suc_beneficiario := rg_tran.cod_swi_suc_beneficiario;
          rg_sol.nro_ref_solicitud    := null;
          rg_sol.uetr                 := null;
          rg_sol.est_notificacion     := 'X';
          rg_sol.identificacion       := null;
          rg_sol.info_remesa          := null;
          rg_sol.info_envio           := null;
          rg_sol.tip_rechazo          := null;
          pr_ins_sol_spi(rg_sol,p_cod_solicitud); 
       end if;
       if p_cod_solicitud is null then
           p_cod_retorno:=55;
           p_men_retorno:='Error al insertar la solicitud de devolucion';
           raise e_val;
       end if;
       rg_sol.cod_sol_spi :=p_cod_solicitud;
       p_reg_devolucion := rg_tran;          

exception
  when e_val then
       rg_sol.est_solicitud    := 'C';
       rg_sol.respuesta        :=substr(p_men_retorno,1,2000);
       pr_act_sol_spi(rg_sol);
  when others then
       p_cod_retorno           :=54;
       p_men_retorno           :=substr(sqlerrm,1,2000);
       rg_sol.est_solicitud    := 'C';
       rg_sol.respuesta        :=substr(sqlerrm,1,2000);
       pr_act_sol_spi(rg_sol);
end pr_pro_env_056;
/* 
Obtiene solicitudes pendientes de envio camt.056 
*/
procedure pr_obt_sol_pen_056(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtSolDevPendiente056,p_dat_mensaje out typ_mensajeria_spi )is
  /*
  || Procesa solicitudes pendientes de ENVIO al SPI, de tipo camt.056(Solicitud de Devolucion de pago de Crédito Directo(SPI))
  */
  v_nro_referencia  ge_snp_transferencias.nro_referencia%type:= NULL;
  v_nro_ref_externa ge_snp_transferencias.nro_ref_externa%type:= NULL;
  v_cod_sol_spi     ge_spi_solicitudes.cod_sol_spi%type:= NULL;
  v_cant number(8):=0;
  v_tipo_ben varchar2(10);
  v_tipo_sol varchar2(10);

  mensaje typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);

  cursor cu_msj_tra IS
    Select sol.nro_referencia,
           trunc(sol.fec_insercion) fec_solicitud,
           to_char(sol.fec_insercion, 'HH24:MI:SS') hor_solicitud,
           sol.cod_swi_solicitante swi_pte_sol_remitente,
           sol.cod_swi_beneficiario swi_pte_sol_receptor,
           sol.nro_ref_msj_original nro_ref_msj_original,
           'pacs.008.001.10' cod_msj_original,
           trunc(tr.fec_insercion) fec_msj_original,
           to_char(tr.fec_insercion,'HH24:MI:SS') hor_msj_original,
           trunc(tr.fec_valor) fec_valor_original,
           sol.cod_mot_solicitud cod_mot_devolucion,
           FUE_OBT_DES_REFCODES('TIP_REC_SPI_P04', sol.cod_mot_solicitud, 'N') des_mot_devolucion,
           sol.monto monto,
           sol.nro_ref_externa nro_ref_externa, 
           sol.cod_sol_spi

      from ge_spi_solicitudes sol, ge_snp_transferencias tr
     where sol.nro_ref_msj_original = tr.nro_ref_externa
       and sol.cod_moneda = tr.cod_moneda
       and tr.cod_moneda = sol.cod_moneda
       and tr.cod_msj_swift = fug_obt_pardinamico('COD_SPI_PCD') -- pacs.008
       and tr.fec_recepcion is null --transferencia enviada
       and sol.cod_msj_swift = fug_obt_pardinamico('COD_SPI_SOL_DEV')
       and sol.est_solicitud = 'U'
       and sol.sit_solicitud not in ('B', 'N', 'C', 'L', 'V') --No sean bloqueado, Evitar reenvio SPI, Cancelado,Liquidado, Enviado al BCP
       and sol.fec_recepcion is null --solicitud enviada
       and rownum = 1
     order by sol.nro_ref_externa asc
       for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  p_dat_solicitud := typ_ObtSolDevPendiente056();
  pas_spi.g_cod_error := 0;
  pas_spi.g_msj_error := NULL;
  g_lugar:='Lee datos de Solicitudes camt.056';
  FOR a IN cu_msj_tra LOOP
    v_nro_referencia  := a.nro_referencia;
    v_nro_ref_externa := a.nro_ref_externa;
    v_cod_sol_spi     := a.cod_sol_spi;
    --Recupera tipo de participante
    begin
      g_lugar:='Recupera tipo de participante remitente';
      select tipo
        into v_tipo_sol
        from gv_snp_participantes
       where cod_swift = a.swi_pte_sol_remitente;
    exception
      when no_data_found then
        v_tipo_sol := null;
      when others then
        v_tipo_sol := null;
    end;
    begin
      g_lugar:='Recupera tipo de participante receptor';
      select tipo
        into v_tipo_ben
        from gv_snp_participantes
       where cod_swift = a.swi_pte_sol_receptor;
    exception
      when no_data_found then
        v_tipo_ben := null;
      when others then
        v_tipo_ben := null;
    end;

        --Cargo valores en el type
         p_dat_solicitud.nro_referencia        := a.nro_ref_externa;
         p_dat_solicitud.fec_solicitud         := a.fec_solicitud;
         p_dat_solicitud.hor_solicitud         := a.hor_solicitud;
         p_dat_solicitud.swi_pte_sol_remitente := a.swi_pte_sol_remitente;
         p_dat_solicitud.swi_pte_sol_receptor  := a.swi_pte_sol_receptor;
         p_dat_solicitud.nro_ref_msj_original  := a.nro_ref_msj_original;
         p_dat_solicitud.cod_msj_original      := a.cod_msj_original;
         p_dat_solicitud.fec_msj_original      := a.fec_msj_original;
         p_dat_solicitud.hor_msj_original      := a.hor_msj_original;
         p_dat_solicitud.fec_valor_original    := a.fec_valor_original;
         p_dat_solicitud.cod_mot_devolucion    := a.cod_mot_devolucion;
         p_dat_solicitud.des_mot_devolucion    := substr(a.des_mot_devolucion,1,35);
         p_dat_solicitud.monto                 := a.monto;
         p_dat_solicitud.tip_pte_remitente     := v_tipo_sol;
         p_dat_solicitud.tip_pte_receptor      := v_tipo_ben;

         ---Registro de parametros
         g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
         pas_snp.pr_reg_operacion('Tipo mensaje enviado: camt.056'||chr(10) ||
         ' Parametros: Nro_solicitud: '||a.cod_sol_spi|| chr(10) ||
         ' Nro_ref_externa: '||a.nro_ref_externa|| chr(10) ||
         ' Fecha Solicitud: '||a.fec_solicitud|| chr(10) ||
         ' Hora Solicitud: '||a.hor_solicitud|| chr(10) ||
         ' Fecha Transf. Original: '||a.fec_msj_original|| chr(10) ||
         ' Hora Transf. Original: '||a.hor_msj_original|| chr(10) ||
         ' Monto Solicitud Devolucion: '||a.monto|| chr(10) ||
         ' Swift partipante solicitante: '||a.swi_pte_sol_remitente|| chr(10) ||
         ' Tipo solicitante: '||v_tipo_sol|| chr(10) ||
         ' Swift partipante beneficiario: '||a.swi_pte_sol_receptor|| chr(10) ||
         ' Tipo beneficiario: '||v_tipo_ben|| chr(10) ||
         ' Concepto: '||'Solicitud de Devolucion.'|| chr(10) ||
         ' Observacion: '||'Proceso de envio.'
         , g_lugar||' Nro_solicitud: '||a.cod_sol_spi);

  END LOOP;
  IF v_cod_sol_spi is not null then
  g_lugar:='Asigna datos para la cabecera de solicitud camt.056';
  p_dat_cabecera :=pas_spi.fu_obt_cab_spi(FUE_OBT_DES_REFCODES('COD_MSJ_SWIFT', fug_obt_pardinamico('COD_SPI_SOL_DEV'),'N'),v_nro_ref_externa);
  g_lugar:='Actualizacion de solicitud camt.056 a bloqueado';
  --Modo de bloquear el registro
  UPDATE ge_spi_solicitudes sl
     SET sl.sit_solicitud = 'B'
   WHERE sl.cod_sol_spi = v_cod_sol_spi;

    g_lugar:='Recupera cantidad de reintentos camt.056';
    begin
      select nvl( max(cantidad),0) into v_cant from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
      exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.056';
    insert into ge_spi_log_controles
    (nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
       values (v_cod_sol_spi, v_nro_ref_externa, FUE_OBT_DES_REFCODES('COD_MSJ_SWIFT', fug_obt_pardinamico('COD_SPI_SOL_DEV'),'N'),trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);
    g_lugar:='Proceso de Solicitud ENVIO al SPI, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Camt.056 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );
    p_dat_mensaje    := mensaje;
  ELSE
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_mensaje    := mensaje;
  END IF;

EXCEPTION
  WHEN others THEN
    pas_spi.g_cod_error := 50;
    pas_spi.g_msj_error := g_lugar||'-'||sqlerrm;
    UPDATE ge_spi_solicitudes 
       SET sit_solicitud = 'N'
    WHERE nro_referencia = v_cod_sol_spi;
    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_sol_pen_056-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de camt.056, Ref. externa: '||v_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );
    p_dat_mensaje        := mensaje;
END pr_obt_sol_pen_056;
/*
Actualiza el estado y la situacion de las solicitudes SPI.
Debe ser invocado por el XAIX
*/
procedure pr_act_solicitudes (p_nro_ref_externa   in ge_snp_transferencias.nro_ref_externa%type,
                            p_estado            in  ge_snp_transferencias.estado%type,
                            p_situacion         in  ge_snp_transferencias.situacion%type,
                            p_msj_mx            in  ge_snp_transferencias.msj_swift%type,
                            p_error             in  ge_snp_transferencias.error%type,
                            p_dat_mensaje       out typ_mensajeria_spi) is
   ex_error          EXCEPTION;
   mensaje           typ_mensajeria_spi := typ_mensajeria_spi(0,'OK',null);
   v_det_log         varchar2(4000) := NULL;
   v_cant            number;
   v_dir_correo      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('SPI_MAI_RECHAZO_LIM');
   v_msj_error       varchar2(2000);
   v_sit_sol         ge_spi_solicitudes.sit_solicitud%type;
   v_est_sol         ge_spi_solicitudes.est_solicitud%type;
   v_ref_msj_orig    ge_spi_solicitudes.nro_ref_msj_original%type;
   v_cod_msj_swift   ge_spi_solicitudes.cod_msj_swift%type;
   v_cod_mot_dev     ge_spi_solicitudes.cod_mot_solicitud%type;
   rg_msj_original   ge_snp_transferencias%rowtype;
   rg_solicitud      ge_spi_solicitudes%rowtype;
   v_tip_persona         ba_personas.tipo%type;
   v_des_dev             varchar2(100);
   v_nombre_saludo       varchar2(100);
   v_ent_debito          varchar2(100);
   v_ent_credito         varchar2(100);
   v_fec_notificacion    varchar2(20);
   v_inf_json                 long:=null;

PROCEDURE lp_reg_log_transferencia( p_respuesta in varchar2 )
IS
   BEGIN
      --
      pas_snp.pr_set_texto(v_det_log, p_respuesta, pas_snp.fu_obt_salto );
      pas_snp.pr_set_texto(v_det_log, 'Nro. Ref. Externa:  '|| '~' || p_nro_ref_externa || '~', pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Situación:          '|| p_situacion, pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Estado:             '|| p_estado, pas_snp.fu_obt_salto);
      pas_snp.pr_set_texto(v_det_log, 'Error:             '||  p_error, pas_snp.fu_obt_salto);
      pas_snp.pr_reg_operacion( p_msj_mx, v_det_log );
      --
   EXCEPTION
     WHEN others THEN
       NULL;
END lp_reg_log_transferencia;

BEGIN
   begin
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
   end;

   pas_spi.g_cod_error := 0;
   pas_spi.g_msj_error := NULL;

     if p_situacion = 'V' and p_estado = 'W' then
        g_lugar:='Buscar solicitud';
        begin
            --select sl.sit_solicitud,sl.est_solicitud, sl.nro_ref_msj_original, sl.cod_msj_swift, sl.cod_mot_solicitud
            --into  v_sit_sol , v_est_sol, v_ref_msj_orig, v_cod_msj_swift, v_cod_mot_dev
            Select sl.*
            into rg_solicitud 
            from ge_spi_solicitudes sl
            where sl.nro_ref_externa=p_nro_ref_externa;
        exception
            when no_data_found then
               pas_spi.g_msj_error:='No existe la solicitud con ref. externa: '||p_nro_ref_externa;
               raise ex_error;
        end;
        --Recupero mensaje original para notificaciones camt_056
        IF rg_solicitud.cod_msj_swift = fug_obt_pardinamico('COD_SPI_SOL_DEV') then
          g_lugar:='Buscar datos Pago Original para Notificaciones';
          begin
              select *--recupero todos los datos de la transferencia original  
              into rg_msj_original
              from ge_snp_transferencias t 
              where t.fec_recepcion is null
               and t.cod_msj_swift = fug_obt_pardinamico('COD_SPI_PCD')
               and t.situacion = 'L'
               and t.estado = 'A'
               and t.nro_ref_externa = rg_solicitud.nro_ref_msj_original;-- v_ref_msj_orig;
         exception
               when no_data_found then
                   --pas_spi.g_msj_error :='No se encuentra la transf. : '||v_ref_msj_orig|| ' con los datos para las Notificaciones.';
                   pas_spi.g_msj_error :='No se encuentra la transf. : '||rg_solicitud.nro_ref_msj_original|| ' con los datos para las Notificaciones.';
                   raise ex_error;
         end;
        END IF;
        --verificar el estado anterior de la solicitud
        --if v_sit_sol not in('L','C','E') and v_est_sol not in('A','R','C') then
        if rg_solicitud.sit_solicitud not in('L','C','E') and rg_solicitud.est_solicitud not in('A','R','C') then
               g_lugar:='Actualiza solicitud';
               IF p_nro_ref_externa is not null then
               update ge_spi_solicitudes so
               set so.sit_solicitud=p_situacion,
               so.est_solicitud=p_estado,
               so.msj_mx=substr(p_msj_mx,1,4000),
               so.respuesta=so.respuesta||chr(10)||substr(p_error,1,2000)
               where so.nro_ref_externa=p_nro_ref_externa;
               IF sql%notfound THEN
                  pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Ref. Externa Nro.: '||p_nro_ref_externa);
               END IF;
               END IF;

               if sql%rowcount > 0 and rg_solicitud.cod_msj_swift = fug_obt_pardinamico('COD_SPI_SOL_DEV') then
                  --seccion de notificaciones--
                     begin   
                        v_tip_persona := pas_spi.fu_obt_tip_persona(rg_msj_original.cod_per_solicitante);  --se identifica que tipo de persona es para el envio de mail
                        if v_tip_persona = 'F' then  --obtenemos el nombre corto en base al tipo de persona
                         v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(rg_msj_original.cod_per_solicitante);
                        else
                         v_nombre_saludo := fue_obt_nom_comercial(rg_msj_original.cod_per_solicitante);
                        end if; 
                        v_ent_debito:=it.fug_obt_nom_snp_participante(rg_msj_original.cod_swi_pte_solicitante); 
                        v_ent_credito:=it.fug_obt_nom_snp_participante(rg_msj_original.cod_swi_pte_beneficiario); 
                        v_cod_mot_dev := rg_solicitud.cod_mot_solicitud;
                        v_des_dev    := it.fue_obt_des_refcodes('TIP_REC_SPI_P04',v_cod_mot_dev);

                        v_fec_notificacion:= to_char(rg_msj_original.fec_insercion, 'dd/mm/yyyy hh24:mi:ss');

                         --formato nuevo
                             v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                                           -- '"nombre_titulo":' || '"' || v_nom_solicitante_004 || '"' || ',' ||
                                            '"cuenta_debito":' || '"' || rg_solicitud.cta_beneficiario || '"' || ',' ||
                                            '"titular_debito":' || '"' || rg_solicitud.nom_beneficiario || '"' || ',' ||
                                            '"entidad_debito":' || '"' || v_ent_credito || '"' || ',' ||
                                            '"monto":' || '"' || trim(to_char(rg_solicitud.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                                            '"moneda_debito":' || '"' || rg_solicitud.cod_moneda || '"' || ',' ||
                                            '"nro_operacion":' || '"' || substr(rg_solicitud.nro_ref_externa,6) || '"' || ',' || 
                                            '"fecha_hora":' || '"' || v_fec_notificacion || '"' || ',' ||
                                            '"cuenta_credito":' || '"' || rg_solicitud.cta_solicitante || '"' || ',' ||
                                            '"titular_credito":' || '"' || v_nombre_saludo || '"' || ',' ||
                                            '"entidad_credito":' || '"' || v_ent_debito || '"' || ',' ||
                                            '"doc_credito":' || '"' || rg_solicitud.doc_solicitante || '"' || ',' ||
                                            '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                                            '"tipo_operacion":' || '"' || 'Solicitud de Devolución Enviada Exitosamente' || '"' || ',' ||
                                            '"comprobante":' || '"' || rg_solicitud.nro_ref_externa || '"' || '}';

                       if v_tip_persona = 'F' then                               
                          pr_env_alerta(rg_msj_original.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'ENVNOT056F'),v_inf_json);
                       else
                          pr_env_alerta(rg_msj_original.cod_per_solicitante, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'ENVNOT056J'),v_inf_json);
                       end if;                             
                    end;             
               END IF;

               lp_reg_log_transferencia( '0'|| '|LOG DE SOL. SPI ' || trim(p_nro_ref_externa) );
               p_dat_mensaje        := mensaje;
        end if;

      else
           g_lugar:='Actualiza solicitud';
           IF p_nro_ref_externa is not null THEN
           update ge_spi_solicitudes so
           set so.sit_solicitud=p_situacion,
           so.est_solicitud    =p_estado,
           so.msj_mx           =substr(p_msj_mx,1,4000),
           so.respuesta        =so.respuesta||chr(10)||substr(p_error,1,2000)
           where so.nro_ref_externa=p_nro_ref_externa;
           IF sql%notfound THEN
              pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Ref. Externa Nro.: '||p_nro_ref_externa);
           END IF;
           END IF;
           --reintento de envios 
          begin
              select count(*)
              into v_cant
              from ge_spi_log_controles t
              where t.nro_ref_externa = p_nro_ref_externa;
          exception
             when others then
                  v_cant := 0;
          end;
          if v_cant >= fug_obt_pardinamico( 'SPI_CANT_REINTENTO' ) then
             begin
                  g_lugar:='Cancela solicitud';
                   IF p_nro_ref_externa is not null then
                   update ge_spi_solicitudes
                   set est_solicitud = 'R',
                       sit_solicitud = 'C'
                   where nro_ref_externa = p_nro_ref_externa;
                   IF sql%notfound THEN
                   pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Ref. Externa Nro.: '||p_nro_ref_externa);
                   END IF;
                   END IF;

             exception
                 when others then 
                     v_msj_error:=sqlerrm;
                     begin
                        if v_dir_correo is not null then
                           it_mail.mail( fug_obt_dir_correo,
                                        v_dir_correo,
                                        'Inconveniente en reversion SPI',
                                        'Hubo un error en la reversion de la operacion'
                                         || chr(10) ||'Nro. de referencia externa: '||p_nro_ref_externa
                                         || chr(10) ||'Detalle Error: '||v_msj_error
                                        );
                       end if;
                     exception
                       when others then
                          null;
                     end;
                     pas_spi.g_msj_error:='No se pudo marcar como cancelada la solicitud';
                     raise ex_error;
             end;
          end if;
          lp_reg_log_transferencia( '0' || '|LOG DE SOL. SPI ' || trim(p_nro_ref_externa));
          p_dat_mensaje        := mensaje;
      end if;

EXCEPTION
   when ex_error then
    pas_spi.g_cod_error     := 80;
    pas_spi.g_msj_error     := g_lugar||'-'||pas_spi.g_msj_error;
    mensaje.cod_respuesta   := 1;
    mensaje.nom_respuesta   := 'Actualizar datos de la solicitud ' ||p_nro_ref_externa;
    lp_reg_log_transferencia(pas_spi.g_cod_error|| '|LOG SOL. SPI ' || trim(p_nro_ref_externa));
    mensaje.des_Respuesta   :=substr(pas_spi.g_msj_error,1,2000);
    p_dat_mensaje           := mensaje;

   when others then
     PAS_SPI.g_cod_error    := 81;
     PAS_SPI.g_msj_error    := g_lugar||'-'||sqlerrm;
     mensaje.cod_respuesta  := 1;
     mensaje.nom_respuesta  := 'Ocurrio error al actualizar datos de la solicitud, nro_ref_externa' ||p_nro_ref_externa;
     lp_reg_log_transferencia(pas_spi.g_cod_error|| '|LOG SOL. SPI ' || trim(p_nro_ref_externa));
     mensaje.des_Respuesta  :=substr(sqlerrm,1,2000);
     p_dat_mensaje          := mensaje;

end pr_act_solicitudes;
/*Genera codigo UERT a partir de una clave*/
function fu_obt_uetr(p_clave in number) return varchar2 is
  v_hash         varchar2(500);
  v_posicion     number(5):=0;
  v_uetr         varchar2(500);
  v_grupo        varchar2(500);
  v_lon_con      number(5):=0;
  v_lon_clave    number(5):=0;
  c_can_grupos   constant number(5):=5;
begin
   v_hash:=regexp_replace(rawtohex(sys_guid()), '([A-F0-9]{8})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{12})', '\1-\2-\3-\4-\5');

   for i in 1..c_can_grupos loop
      if i!=c_can_grupos then
         v_posicion :=instr(v_hash,'-',1,1);
         v_grupo    :=substr(v_hash,1,v_posicion-1);
      else
         v_grupo :=v_hash;
      end if;

      case i 
        when 1 then 
            v_uetr :=v_grupo;
        when 3 then
            v_grupo :=substr(v_grupo,2);
            v_grupo :='4'||v_grupo;
            v_uetr  :=v_uetr||'-'||v_grupo;
        when 4 then 
            v_grupo :=substr(v_grupo,2);
            if mod(p_clave,2)=0 then
               v_grupo :='A'||v_grupo;
            else
               v_grupo :='B'||v_grupo;
            end if;

            v_uetr :=v_uetr||'-'||v_grupo;
        when 5 then
            v_lon_con   :=length(v_grupo);
            v_lon_clave :=length(p_clave);

            if v_lon_con<=v_lon_clave then
              v_grupo :=substr(p_clave,-v_lon_con);
            else
              v_grupo :=substr(v_grupo,1,(v_lon_con-v_lon_clave))||p_clave;
            end if;
            v_uetr :=v_uetr||'-'||v_grupo;
        else
            v_uetr :=v_uetr||'-'||v_grupo;
       end case;
       v_hash :=substr(v_hash,v_posicion+1);
   end loop;
   return lower(v_uetr);
exception
   when others then 
      return null;
end fu_obt_uetr;
/*
Inserta las solicitudes recibidas
*/
procedure pr_pro_sol_recibidas(p_dat_recibidos in typ_ObtSolRecibido,p_dat_mensaje out typ_mensajeria_spi) is
 r_sol_rec         ge_spi_solicitudes%rowtype;
 r_sol_res         ge_spi_solicitudes%rowtype;
 v_mto_maximo      ge_spi_solicitudes.monto%type;
 v_tip_rechazo     ge_spi_solicitudes.tip_rechazo%type;
 e_val             exception;
 v_nro_cuenta      ge_cuentas.nro_cuenta%type;
 v_cod_persona     ba_personas.cod_persona%type;
 e_respuesta       exception;
 v_inf_json        long;
 v_bic_emisor      ge_spi_solicitudes.cod_swi_solicitante%type;
 v_bic_suc_emisor  ge_spi_solicitudes.cod_swi_suc_solicitante%type;
 v_msj_error       ge_spi_solicitudes.respuesta%type;
 v_habilitado      varchar2(1);
 v_cod_msj_mx      ge_spi_cab_versiones.tipo_msj%type;
 v_cod_mensaje     ge_spi_solicitudes.cod_msj_swift%type;
 v_sol_devolucion  ge_par_dinamicos.parametro%type:=fug_obt_pardinamico('COD_SPI_SOL_DEV');
 v_sol_ini_pago    ge_par_dinamicos.parametro%type:=fug_obt_pardinamico('COD_SPI_INI_PAGO');
 rg_tran           pas_snp.rg_msj;
 v_nro_referencia  ge_snp_transferencias.nro_referencia%type;
 v_mon_recibido    ge_spi_solicitudes.monto%type;
 rg_omp            ge_entes%rowtype;    
 v_tip_persona     ba_personas.tipo%type;     
 v_ent_debito      varchar2(100);
 v_ent_credito     varchar2(100);  
 v_des_dev         varchar2(100);
 v_nombre_saludo   varchar2(100);
 v_fec_not         varchar2(20);
 v_per_not         ba_personas.cod_persona%type; 
 --procedimiento interno para validaciones
 procedure pr_val_sol_pagos is

 begin
     p_dat_mensaje                     :=typ_mensajeria_spi(0,'OK',null);
     v_tip_rechazo                     :=g_rch_dt02;
     r_sol_rec.cod_moneda              :=fue_obt_iso_moneda(p_dat_recibidos.cod_moneda);
     v_mto_maximo                      :=fug_obt_pardinamico('SPI_MTO_MAX_TRANSF');
     r_sol_rec.tip_doc_beneficiario    :=fue_obt_tip_documento(p_dat_recibidos.cod_tip_doc_receptor);

     if v_cod_msj_mx=g_pai_013 then
         v_habilitado:=fu_val_fun_fase2('SPI_PTE_SOL_PAGO','C','1');
     elsif v_cod_msj_mx=g_pai_001 then
          v_habilitado:=fu_val_fun_fase2('SPI_PTE_CER_INI_PAGO','C','1');
     end if;

     if v_habilitado='N' then
         pas_spi.g_cod_error := 115;
         pas_spi.g_msj_error :='Funcionalidad no certificada para la entidad receptora';
         raise e_val;
     end if;

     if r_sol_rec.cod_moneda is null then
         pas_spi.g_cod_error := 103;
         pas_spi.g_msj_error :='Campo moneda no puede ser nulo';
         raise e_val;
     elsif r_sol_rec.cod_moneda!=pag_gen.fu_obt_mon_local then
          pas_spi.g_cod_error := 102;
          pas_spi.g_msj_error :='Solo se permiten operaciones en moneda local';
          raise e_val;
     end if;

     if p_dat_recibidos.monto is null then 
        pas_spi.g_cod_error := 100;
        pas_spi.g_msj_error :='Campo monto no puede ser nulo';
        r_sol_rec.monto:=0;
        raise e_val;
     elsif p_dat_recibidos.monto>v_mto_maximo then
       pas_spi.g_cod_error := 101;
       pas_spi.g_msj_error :='Monto de la solicitud supera el maximo establecido: '||v_mto_maximo||' '||pag_gen.fu_obt_mon_local;
       v_tip_rechazo:=g_rch_am02;
       raise e_val;
     elsif  p_dat_recibidos.monto<=0 then
           pas_spi.g_cod_error := 110;
           pas_spi.g_msj_error :='Monto invalido';
           raise e_val;
     end if;

     if p_dat_recibidos.nro_ref_externa is null then
        pas_spi.g_cod_error := 104;
        pas_spi.g_msj_error :='Campo referencia externa no puede ser nulo';
        raise e_val;
     end if;

     if p_dat_recibidos.swi_pte_emisor is null then 
        pas_spi.g_cod_error := 106;
        pas_spi.g_msj_error := 'BIC del emisor no puede ser nulo';
        raise e_val;
     else
        r_sol_rec.cod_swi_solicitante :=p_dat_recibidos.swi_pte_emisor;
        pr_val_cod_swi_participante(r_sol_rec.cod_swi_solicitante);
        if pas_spi.fu_obt_cod_error <> 0 then
              pas_spi.g_cod_error := 117;
              pas_spi.g_msj_error := 'Error al buscar swift del participante emisor';
              raise e_val;
         end if;

     end if;
     --validar OMP
     if v_cod_msj_mx=g_pai_001 then

         rg_omp:=fu_obt_dat_omp(p_dat_recibidos.uetr);

         if pas_spi.fu_obt_cod_error <> 0 then
              pas_spi.g_cod_error := 105;
              pas_spi.g_msj_error := 'Error al buscar swift del OMP';
              raise e_val;
         end if;
     end if;

     pas_spi.g_cod_error:=0;
     pas_spi.g_msj_error:=null;


     if p_dat_recibidos.cod_swi_suc_emisor is not null then
        r_sol_rec.cod_swi_suc_solicitante :=p_dat_recibidos.cod_swi_suc_emisor;
        pr_val_cod_swi_participante(r_sol_rec.cod_swi_suc_solicitante);

        if pas_spi.fu_obt_cod_error <> 0 then
              pas_spi.g_cod_error := 107;
              pas_spi.g_msj_error := 'Error al buscar swift del subparticipante emisor';
              raise e_val;
         end if;
     end if;

     if p_dat_recibidos.swi_pte_receptor is null then 
        pas_spi.g_cod_error := 108;
        pas_spi.g_msj_error := 'BIC del receptor no puede ser nulo';
        raise e_val;
     else 
          if p_dat_recibidos.swi_pte_receptor!=pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) then
             pas_spi.g_cod_error := 109;
             pas_spi.g_msj_error := 'BIC no corresponde a la entidad receptora';
             raise e_val;
          end if;
     end if;

     if p_dat_recibidos.cod_tip_doc_receptor is null then 
        pas_spi.g_cod_error := 111;
        pas_spi.g_msj_error := 'Tipo de documento del receptor no puede ser nulo';
        v_tip_rechazo:=g_rch_dt03;
        raise e_val;
     end if;

     if p_dat_recibidos.nro_doc_receptor is null then 
        pas_spi.g_cod_error := 112;
        pas_spi.g_msj_error := 'Documento del receptor no puede ser nulo';
        v_tip_rechazo:=g_rch_dt03;
        raise e_val;
     end if;
      if p_dat_recibidos.nro_cta_receptor is null then 
        pas_spi.g_cod_error := 113;
        pas_spi.g_msj_error := 'Cuenta del receptor no puede ser nulo';
        v_tip_rechazo:=g_rch_ac01;
        raise e_val;
     end if;
     pas_spi.g_cod_error:=0;
     pas_spi.g_msj_error:=null;

     pas_spi.pr_obt_cta_interna(p_dat_recibidos.nro_cta_receptor,
                                r_sol_rec.tip_doc_beneficiario,
                                p_dat_recibidos.nro_doc_receptor,
                                v_nro_cuenta,
                                v_cod_persona);

     if pas_spi.fu_obt_cod_error <> 0  then
        v_tip_rechazo:=g_rch_dt03;
        raise e_val;
     end if;

     pag_cta.pr_obt_cuenta(v_nro_cuenta);

     if pag_cta.g_ctas.cod_moneda!=r_sol_rec.cod_moneda then
        pas_spi.g_cod_error := 114;
        pas_spi.g_msj_error := 'Moneda de la operacion no coincide con moneda de la cuenta';
        v_tip_rechazo:=g_rch_ac01;
        raise e_val;
     end if;

     pag_cta.pr_ver_operacion(v_nro_cuenta, 
                              v_cod_tra_padre,
                              v_cod_mod_padre,v_cod_mad_padre, 
                              'D',
                              pag_cta.g_ctas.cod_moneda, 
                              p_dat_recibidos.monto, 
                              pag_cta.g_ctas.cod_oficina, 
                              v_cod_mod, 
                              v_cod_mad, 
                              v_est_cuenta, 
                              v_sal_disponible, 
                              v_procesa,v_tra_deb);
       if v_procesa='N' then

          if pag_cta.G_COD_ERROR=24 then
             v_tip_rechazo:=g_rch_ac04;
          elsif pag_cta.G_COD_ERROR=31 then
             v_tip_rechazo:=g_rch_am04;
          end if;

          pas_spi.g_cod_error := pag_cta.fu_obt_cod_error;
          pas_spi.g_msj_error := pag_cta.fu_obt_msj_error;
          raise e_val;
       end if;
 exception
     when e_val then
          v_msj_error:= pas_spi.g_msj_error;
     when others then 
         pas_spi.g_cod_error:=115;
         pas_spi.g_msj_error:=sqlerrm;
         v_msj_error:=pas_spi.g_msj_error;
 end pr_val_sol_pagos;

 procedure pr_validaciones_056 is

 begin
     p_dat_mensaje                     := typ_mensajeria_spi(0,'OK',null);
     v_tip_rechazo                     :=g_rch_dt02;
     v_mto_maximo                      :=fug_obt_pardinamico('SPI_MTO_MAX_TRANSF');


     if v_cod_msj_mx=g_cam_056 then
         v_habilitado:=fu_val_fun_fase2('SPI_PTE_CER_SOL_DEVOL','C','1');
     end if;

     if v_habilitado='N' then
         pas_spi.g_cod_error := 116;
         pas_spi.g_msj_error :='Funcionalidad no certificada para la entidad receptora';
         raise e_val;
     end if;

    if p_dat_recibidos.monto is not null then    
     if p_dat_recibidos.monto>v_mto_maximo then
       pas_spi.g_cod_error := 118;
       pas_spi.g_msj_error :='Monto de la solicitud supera el maximo establecido: '||v_mto_maximo||' '||pag_gen.fu_obt_mon_local;
       raise e_val;
     elsif  p_dat_recibidos.monto<=0 then
           pas_spi.g_cod_error := 119;
           pas_spi.g_msj_error :='Monto invalido';
           raise e_val;
     end if;
    end if;

     if p_dat_recibidos.nro_ref_externa is null then
        pas_spi.g_cod_error := 120;
        pas_spi.g_msj_error :='Campo referencia externa no puede ser nulo';
        raise e_val;
     end if;

     if p_dat_recibidos.nro_ref_original is null then
        pas_spi.g_cod_error := 121;
        pas_spi.g_msj_error :='Campo referencia original no puede ser nulo';
        raise e_val;
     end if;

     if p_dat_recibidos.fec_valor is null then
        pas_spi.g_cod_error := 122;
        pas_spi.g_msj_error :='Campo Fecha Valor no puede ser nulo';
        raise e_val;
     end if;

     if p_dat_recibidos.msj_mx is null then
        pas_spi.g_cod_error := 123;
        pas_spi.g_msj_error :='Campo Msj Xml no puede ser nulo';
        raise e_val;
     end if;

     if p_dat_recibidos.cod_msj_mx is null then
        pas_spi.g_cod_error := 124;
        pas_spi.g_msj_error :='Campo Codigo Msj Swift no puede ser nulo';
        raise e_val;
     end if;

     if p_dat_recibidos.cod_motivo_dev is null then
        pas_spi.g_cod_error := 125;
        pas_spi.g_msj_error :='Campo Codigo Motivo de la Solicitud no puede ser nulo';
        raise e_val;
     end if; 

     if p_dat_recibidos.swi_pte_emisor is null then 
        pas_spi.g_cod_error := 126;
        pas_spi.g_msj_error := 'BIC del emisor no puede ser nulo';
        raise e_val;
     else
        r_sol_rec.cod_swi_solicitante :=p_dat_recibidos.swi_pte_emisor;
        pr_val_cod_swi_participante(r_sol_rec.cod_swi_solicitante);
        if pas_spi.fu_obt_cod_error <> 0 then
              pas_spi.g_cod_error := 127;
              pas_spi.g_msj_error := 'Error al buscar swift del participante emisor';
              raise e_val;
         end if;
     end if;

     if p_dat_recibidos.cod_swi_suc_emisor is not null then
        r_sol_rec.cod_swi_suc_solicitante :=p_dat_recibidos.cod_swi_suc_emisor;
        pr_val_cod_swi_participante(r_sol_rec.cod_swi_suc_solicitante);

        if pas_spi.fu_obt_cod_error <> 0 then
              pas_spi.g_cod_error := 128;
              pas_spi.g_msj_error := 'Error al buscar swift del subparticipante emisor';
              raise e_val;
         end if;
     end if;

      if p_dat_recibidos.swi_pte_receptor is null then 
        pas_spi.g_cod_error := 129;
        pas_spi.g_msj_error := 'BIC del receptor no puede ser nulo';
        raise e_val;
     else 
          if p_dat_recibidos.swi_pte_receptor!=pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) then
             pas_spi.g_cod_error := 130;
             pas_spi.g_msj_error := 'BIC no corresponde a la entidad receptora';
             raise e_val;
          end if;
     end if;

     pag_cta.pr_obt_cuenta(rg_tran.nro_cta_beneficiario);

     if pag_cta.g_ctas.cod_moneda!=rg_tran.cod_moneda then
        pas_spi.g_cod_error := 131;
        pas_spi.g_msj_error := 'Moneda de la operacion no coincide con moneda de la cuenta';
        v_tip_rechazo:=g_rch_ac01;
        raise e_val;
     end if;

     pas_spi.pr_obt_cta_interna(rg_tran.nro_cta_beneficiario,
                                rg_tran.cod_tip_doc_beneficiario,
                                rg_tran.nro_doc_beneficiario,
                                v_nro_cuenta,
                                v_cod_persona);

     if pas_spi.fu_obt_cod_error <> 0  then
        v_tip_rechazo:=g_rch_dt03;
        raise e_val;
     end if;

     pag_cta.pr_ver_operacion(rg_tran.nro_cta_beneficiario, 
                                v_cod_tra_padre,
                                v_cod_mod_padre,v_cod_mad_padre, 
                                'D',
                                pag_cta.g_ctas.cod_moneda, 
                                v_mon_recibido,
                                pag_cta.g_ctas.cod_oficina, 
                                v_cod_mod, 
                                v_cod_mad, 
                                v_est_cuenta, 
                                v_sal_disponible, 
                                v_procesa,v_tra_deb);
       if v_procesa='N' then
          pas_spi.g_cod_error := pag_cta.fu_obt_cod_error;
          pas_spi.g_msj_error := pag_cta.fu_obt_msj_error;
          raise e_val;
       end if;
 exception
     when e_val then
          v_msj_error:= pas_spi.g_msj_error;
     when others then 
         pas_spi.g_cod_error:=132;
         pas_spi.g_msj_error:=sqlerrm;
         v_msj_error:=pas_spi.g_msj_error;
 end pr_validaciones_056;

begin
     begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
     g_lugar:='Log de parametros';
     pas_snp.pr_reg_operacion('Tipo mensaje recibido: '||p_dat_recibidos.cod_msj_mx|| chr(10) ||
         ' Nro_ref_externa: '||p_dat_recibidos.nro_ref_externa|| chr(10) ||
         ' Nro. ref. original: '||p_dat_recibidos.nro_ref_original|| chr(10) ||  
         ' Fec. valor: '||p_dat_recibidos.fec_valor|| chr(10) || 
         ' Nom. Receptor: '||p_dat_recibidos.nom_receptor|| chr(10) || 
         ' Tipo doc. Receptor: '||p_dat_recibidos.cod_tip_doc_receptor|| chr(10) ||
         ' Doc. Receptor: '||p_dat_recibidos.nro_doc_receptor|| chr(10) || 
         ' Cta. Receptor: '||p_dat_recibidos.nro_cta_receptor|| chr(10) ||
         ' BIC  Receptor: '||p_dat_recibidos.swi_pte_receptor|| chr(10) || 
         ' BIC sub. pte. emisor: '||p_dat_recibidos.cod_swi_suc_emisor|| chr(10) ||
         ' BIC emisor: '||p_dat_recibidos.swi_pte_emisor|| chr(10) ||
         ' Nom. Emisor: '||p_dat_recibidos.nom_emisor|| chr(10) ||
         ' Tipo doc. Emisor: '||p_dat_recibidos.cod_tip_doc_emisor|| chr(10) ||
         ' Doc. Emisor: '||p_dat_recibidos.nro_doc_emisor|| chr(10) ||
         ' Cta. Emisor: '||p_dat_recibidos.nro_cta_emisor|| chr(10) ||
         ' Info. Envio: '||p_dat_recibidos.info_envio|| chr(10) ||
         ' Info. Remera: '||p_dat_recibidos.info_remesa|| chr(10) ||
         ' Tip. Operacion: '||p_dat_recibidos.cod_tip_operacion|| chr(10) ||
         ' Identificacion: '||p_dat_recibidos.identificacion|| chr(10) ||
         ' UETR: '||p_dat_recibidos.uetr|| chr(10) ||
         ' Motivo Solicitud: '||p_dat_recibidos.cod_motivo_dev|| chr(10) ||
         ' Monto: '||p_dat_recibidos.monto|| chr(10)
         , g_lugar||' Nro ref. externa: '||p_dat_recibidos.nro_ref_externa); 

      pr_ini_var_spi;

      if p_dat_recibidos.cod_msj_mx is not null then
         v_cod_msj_mx :=pas_spi.fu_tip_msj_ver(p_dat_recibidos.cod_msj_mx);
      end if;

      if v_cod_msj_mx = g_cam_056 then
        Begin
           select t.nro_referencia
           into v_nro_referencia
           from ge_snp_transferencias t
           where t.nro_ref_externa = p_dat_recibidos.nro_ref_original;
           --obtener el registro de la transferencia
           pas_snp.pr_ini_registros;
           pas_snp.pr_obt_mensaje (v_nro_referencia,'N');
           rg_tran := pas_snp.fu_obt_reg_transferencias;
           if pas_snp.fu_obt_cod_error!=0 then
               pas_spi.g_cod_error := 133;
               g_nom_respuesta:=pas_snp.fu_obt_msj_error;
               raise e_val;
           end if;
         exception
              when no_data_found then
                  pas_spi.g_cod_error := 134;
                  g_nom_respuesta:='No se encuentra la transferencia original para las Solicitudes de Devolucion: '||p_dat_recibidos.nro_ref_original;
                  raise e_val;
         end;
       end if;
      begin
        select to_number(t.val_minimo)
          into v_cod_mensaje
          from ba_cod_referencias t
         where dominio = 'COD_MSJ_SWIFT'
           and t.abreviatura = v_cod_msj_mx;
      exception     
      when no_data_found then 
        pas_spi.g_cod_error := 135;
        g_nom_respuesta := 'No se encuentra codigo de mensaje swift para version recibida -' ||v_cod_msj_mx;
        pas_spi.g_msj_error := g_nom_respuesta;
      when others then 
        pas_spi.g_cod_error := 136; 
        g_nom_respuesta := 'No se encuentra codigo de mensaje swift para version recibida -' || v_cod_msj_mx; 
        pas_spi.g_msj_error := g_nom_respuesta; 
      end;

      g_lugar:='Aplicar validaciones';
      if v_cod_mensaje != v_sol_devolucion then
         pr_val_sol_pagos;
      else
        --en el caso de que se recepcione con valor nulo se debe asumir la totalidad del pago original
         r_sol_rec.monto := nvl(p_dat_recibidos.monto,rg_tran.monto);
         v_mon_recibido  := nvl(p_dat_recibidos.monto,rg_tran.monto);
         pr_validaciones_056;
      end if;

      r_sol_rec.cod_msj_swift           :=v_cod_mensaje;
      r_sol_rec.nro_ref_externa         :=p_dat_recibidos.nro_ref_externa;
      r_sol_rec.nro_ref_msj_original    :=p_dat_recibidos.nro_ref_original;
      r_sol_rec.fec_recepcion           :=p_dat_recibidos.fec_valor;
      r_sol_rec.msj_mx                  :=p_dat_recibidos.msj_mx;
      r_sol_rec.monto                   :=nvl(r_sol_rec.monto,p_dat_recibidos.monto);
      r_sol_rec.sit_solicitud           :='R';
      r_sol_rec.est_solicitud           :='S';
      r_sol_rec.est_notificacion        :='N';
      r_sol_rec.cod_mot_solicitud       := p_dat_recibidos.cod_motivo_dev;

      if v_cod_msj_mx in (g_pai_013,g_pai_001) then

         r_sol_rec.nom_beneficiario        :=p_dat_recibidos.nom_receptor;
         r_sol_rec.doc_beneficiario        :=p_dat_recibidos.nro_doc_receptor;
         r_sol_rec.cta_beneficiario        :=v_nro_cuenta;
         r_sol_rec.cta_ben_recibido        :=p_dat_recibidos.nro_cta_receptor;
         r_sol_rec.cod_swi_solicitante     :=nvl(r_sol_rec.cod_swi_solicitante,p_dat_recibidos.swi_pte_emisor);
         r_sol_rec.cod_swi_suc_solicitante :=nvl(r_sol_rec.cod_swi_suc_solicitante,p_dat_recibidos.cod_swi_suc_emisor);
         r_sol_rec.cod_swi_beneficiario    :=p_dat_recibidos.swi_pte_receptor;
         r_sol_rec.identificacion          :=p_dat_recibidos.identificacion;
         r_sol_rec.nom_solicitante         :=p_dat_recibidos.nom_emisor;
         r_sol_rec.doc_solicitante         :=p_dat_recibidos.nro_doc_emisor;
         r_sol_rec.tip_doc_solicitante     :=fue_obt_tip_documento(p_dat_recibidos.cod_tip_doc_emisor);
         r_sol_rec.cta_solicitante         :=p_dat_recibidos.nro_cta_emisor;
         r_sol_rec.info_envio              :=p_dat_recibidos.info_envio;
         r_sol_rec.info_remesa             :=p_dat_recibidos.info_remesa;
         r_sol_rec.cod_tip_operacion       :=p_dat_recibidos.cod_tip_operacion;
         r_sol_rec.uetr                    :=p_dat_recibidos.uetr;

      end if;

      if v_cod_msj_mx=g_cam_056 then
         r_sol_rec.nom_solicitante      := rg_tran.nom_solicitante;
         r_sol_rec.doc_solicitante      := rg_tran.nro_doc_solicitante;
         r_sol_rec.tip_doc_solicitante  := rg_tran.cod_tip_doc_solicitante;
         r_sol_rec.cta_solicitante      := rg_tran.nro_cta_solicitante;
         r_sol_rec.cod_swi_solicitante  := rg_tran.cod_swi_pte_solicitante;
         r_sol_rec.cod_swi_suc_solicitante := rg_tran.cod_swi_suc_solicitante;
         r_sol_rec.nom_beneficiario     := rg_tran.nom_beneficiario;
         r_sol_rec.doc_beneficiario     := rg_tran.nro_doc_beneficiario;
         r_sol_rec.tip_doc_beneficiario := rg_tran.cod_tip_doc_beneficiario;
         r_sol_rec.cta_beneficiario     := rg_tran.nro_cta_beneficiario;
         r_sol_rec.cod_swi_beneficiario := rg_tran.cod_swi_pte_beneficiario;
         r_sol_rec.cod_swi_suc_beneficiario := rg_tran.cod_swi_suc_beneficiario;  
         r_sol_rec.nro_ref_solicitud    := null;
         r_sol_rec.uetr                 := null;
         r_sol_rec.est_notificacion     := 'N';
         r_sol_rec.identificacion       := null;
         r_sol_rec.info_remesa          := null;
         r_sol_rec.info_envio           := null;
         r_sol_rec.tip_rechazo          := null;
         r_sol_rec.cod_moneda           := rg_tran.cod_moneda;
         r_sol_rec.respuesta            := 'Pago Original: '||r_sol_rec.nro_ref_msj_original;
      end if;

      if pas_spi.fu_obt_cod_error<>0 then

         if v_cod_msj_mx=g_pai_001 then
           -- r_sol_rec.sit_solicitud :='C';
            r_sol_rec.est_solicitud :='R';
         end if;

         r_sol_rec.est_notificacion   :='X';
         r_sol_rec.tip_rechazo        :=v_tip_rechazo;
         if v_cod_msj_mx=g_cam_056 then
            r_sol_rec.respuesta          :=r_sol_rec.respuesta||chr(10)||v_msj_error;
         else  
            r_sol_rec.respuesta          :=v_msj_error;
         end if;   
      end if;

      g_lugar:='Insertar solicitud recibida';
      pas_spi.pr_ins_sol_spi(r_sol_rec,r_sol_rec.cod_sol_spi);

      if r_sol_rec.cod_sol_spi is null or pas_spi.fu_obt_cod_error<>0 then

          if v_cod_msj_mx in(g_pai_001,g_pai_013) then

             if v_cod_msj_mx=g_pai_001 then
                 r_sol_res.cod_msj_swift   :=fug_obt_pardinamico('COD_RES_INI_PAGO');
             elsif v_cod_msj_mx=g_pai_013 then
                 r_sol_res.cod_msj_swift  :=fug_obt_pardinamico('COD_RES_SOL_PAGO');
             end if;

             r_sol_res.nro_ref_externa     :=PAS_SPI.fu_obt_sig_nro_ref_externa;
             r_sol_res.nro_referencia      :=r_sol_rec.cod_sol_spi;
             r_sol_res.monto               :=r_sol_rec.monto;
             r_sol_res.cod_moneda          :=r_sol_rec.cod_moneda;
             r_sol_res.msj_mx              :=r_sol_rec.msj_mx;
             r_sol_res.sit_solicitud       :='P';
             r_sol_res.est_solicitud       :='U';
             r_sol_res.est_notificacion    :='X';

             g_lugar:='Insertar respuesta a la solictiud';
             pas_spi.pr_ins_sol_spi(r_sol_res,r_sol_res.cod_sol_spi);

             if r_sol_res.cod_sol_spi is  null then
                  raise e_respuesta;
                  --no se pudo generar la respuesta, se espera recibir el pain014 por time-out
             else 
                 if v_cod_msj_mx=g_pai_013 then
                     update ge_spi_solicitudes su
                     set su.est_solicitud = 'R'
                     where su.cod_sol_spi = r_sol_rec.cod_sol_spi;  
                 end if;
             end if;
          end if;

          if v_cod_msj_mx=g_cam_056 then

             r_sol_res.nro_ref_externa     :=PAS_SPI.fu_obt_sig_nro_ref_externa;
             r_sol_res.nro_referencia      :=r_sol_rec.cod_sol_spi;
             r_sol_res.cod_msj_swift       :=fug_obt_pardinamico('COD_SPI_SOL_REC');
             r_sol_res.monto               :=r_sol_rec.monto;
             r_sol_res.msj_mx              :=r_sol_rec.msj_mx;
             r_sol_res.sit_solicitud       :='P';
             r_sol_res.est_solicitud       :='U';
             r_sol_res.est_notificacion    :='X';

             g_lugar:='Insertar respuesta a la solictiud';
             pas_spi.pr_ins_sol_spi(r_sol_res,r_sol_res.cod_sol_spi);

             if r_sol_res.cod_sol_spi is  null then
                  raise e_respuesta;
                  --no se pudo generar la respuesta...
             end if;
                    IF r_sol_rec.cod_sol_spi is not null then
                    update ge_spi_solicitudes sol 
                    set sol.est_solicitud='R',
                        sol.sit_solicitud='C'
                    where sol.cod_sol_spi=r_sol_rec.cod_sol_spi;
                    IF sql%notfound THEN
                       pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||r_sol_rec.cod_sol_spi);
                    END IF;
                    END IF;
          end if;
       else
         begin     
           if v_cod_msj_mx=g_pai_013 then
                v_per_not     :=fue_obt_cod_persona_doc(r_sol_rec.tip_doc_beneficiario, r_sol_rec.doc_beneficiario);
                v_tip_persona := pas_spi.fu_obt_tip_persona(v_per_not); 
               if v_tip_persona='J' then
                  pr_not_sol_pago('RECSOLPAGJU',r_sol_rec);
               elsif v_tip_persona='F' then
                  pr_not_sol_pago('RECSOLPAGFI',r_sol_rec);
               end if;
           elsif v_cod_msj_mx=g_pai_001 then
               v_per_not     :=fue_obt_cod_persona_doc(r_sol_rec.tip_doc_beneficiario, r_sol_rec.doc_beneficiario);
               v_tip_persona := pas_spi.fu_obt_tip_persona(v_per_not); 
               if v_tip_persona='J' then
                  pr_not_sol_pago('RECSOLINIJU',r_sol_rec);
               elsif v_tip_persona='F' then
                  pr_not_sol_pago('RECSOLINIFI',r_sol_rec);
               end if;
           elsif v_cod_msj_mx=g_cam_056 then
                   v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
                if v_tip_persona = 'F' then
                   v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(v_cod_persona);
                else
                   v_nombre_saludo := fue_obt_nom_comercial(v_cod_persona);
                end if; 
                v_ent_debito:=it.fug_obt_nom_snp_participante(rg_tran.cod_swi_pte_beneficiario); 
                v_ent_credito:=it.fug_obt_nom_snp_participante(rg_tran.cod_swi_pte_solicitante);
                v_des_dev := it.fue_obt_des_refcodes('TIP_REC_SPI_P04',p_dat_recibidos.cod_motivo_dev);

                v_fec_not:= to_char(p_dat_recibidos.fec_valor, 'dd/mm/yyyy hh24:mi:ss');

                v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                      '"cuenta_debito":' || '"' || rg_tran.nro_cta_beneficiario || '"' || ',' ||
                      '"titular_debito":' || '"' || rg_tran.nom_beneficiario || '"' || ',' ||
                      '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                      '"monto":' || '"' || trim(to_char(rg_tran.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                      '"moneda_debito":' || '"' || rg_tran.cod_moneda || '"' || ',' ||
                      '"nro_operacion":' || '"' || p_dat_recibidos.nro_ref_original || '"' || ',' ||
                      '"fecha_hora":' || '"' ||v_fec_not || '"' || ',' ||
                      '"cuenta_credito":' || '"' || rg_tran.nro_cta_solicitante || '"' || ',' ||
                      '"titular_credito":' || '"' || rg_tran.nom_solicitante || '"' || ',' ||
                      '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                      '"doc_credito":' || '"' || rg_tran.nro_doc_solicitante || '"' || ',' ||
                      '"concepto":' || '"' || v_des_dev || '"' || ',' ||
                      '"tipo_operacion":' || '"' || 'Recepcion de Solicitud de Devolucion de Fondos' || '"' || ',' ||
                      '"comprobante":' || '"' || p_dat_recibidos.nro_ref_externa || '"' || '}';

               if v_tip_persona = 'F' then                               
                  pr_env_alerta(v_cod_persona, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECDEV056F'),v_inf_json);
               else
                  pr_env_alerta(v_cod_persona, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'RECDEV056J'),v_inf_json);
               end if;                             
           end if;   


           IF r_sol_rec.cod_sol_spi is not null then
              update ge_spi_solicitudes sl 
              set sl.est_notificacion='R'
              where sl.cod_sol_spi=r_sol_rec.cod_sol_spi;

              IF sql%notfound THEN
                 pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||r_sol_rec.cod_sol_spi);
              END IF;
           END IF;

         exception
             when others then
                 null;
         end;              
      end if;

exception  
     when e_respuesta then
          p_dat_mensaje.cod_respuesta :=1;
          p_dat_mensaje.nom_respuesta :='Insercion de respuesta';
          p_dat_mensaje.des_Respuesta :='No se pudo insertar la respuesta a la solicitud';
          pas_snp.pr_reg_operacion(p_dat_recibidos.msj_mx , g_lugar||'-'||p_dat_recibidos.nro_ref_externa ||'|' || p_dat_mensaje.cod_respuesta|| '|' ||p_dat_mensaje.des_Respuesta );
      when others then 
          p_dat_mensaje.cod_respuesta :=2;
          p_dat_mensaje.nom_respuesta :='Recepcion de sol. SPI';
          p_dat_mensaje.des_Respuesta :=SQLERRM;
          pas_snp.pr_reg_operacion(p_dat_recibidos.msj_mx , g_lugar||'-'||p_dat_recibidos.nro_ref_externa ||'|' || p_dat_mensaje.cod_respuesta|| '|' ||p_dat_mensaje.des_Respuesta );
end pr_pro_sol_recibidas;
/*
SPI - FASE2  Envío de solicitude pago (pain.014) al MS
*/
procedure pr_obt_tra_pen_014(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtRespuesta014,p_dat_mensaje out typ_mensajeria_spi)  is
  /*
  || Procesa transferencias pendientes de ENVIO al SPI, de tipo pacs.008(Mensaje de pago de Crédito Directo)
  */
  v_cod_solicitud    ge_spi_solicitudes.cod_sol_spi%type;
  v_nro_ref_externa  ge_snp_transferencias.nro_ref_externa%type:= NULL;
  v_cant             number(8):=0;
  v_tip_mensaje      ge_spi_solicitudes.cod_msj_swift%type;
  c_mensaje          constant varchar2(10):='pain.014';
  mensaje            typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
  v_version          ge_spi_cab_versiones.version%type;

  cursor cu_msj_tra IS
          select   
              s14.cod_sol_spi,  
              s14.nro_ref_externa,
              s13.cod_swi_solicitante,
              s13.nro_ref_externa nro_ref_original,
              s13.fec_recepcion,
              'RJCT' tipo,
              s13.cod_swi_beneficiario,
              s13.tip_rechazo,
              (select cc.abreviatura
               from ba_cod_referencias cc 
               where cc.dominio='TIP_REC_SPI_P14'
               and cc.val_minimo=s13.tip_rechazo)respuesta,
              (select pt.tipo
              from gv_snp_participantes pt
              where pt.cod_swift=s13.cod_swi_solicitante)tip_emi_original,
              (select pt.tipo
              from gv_snp_participantes pt
              where pt.cod_swift=s14.cod_swi_solicitante)tip_emisor
              from ge_spi_solicitudes s14 join ge_spi_solicitudes s13
              on s14.nro_referencia=s13.cod_sol_spi
              where s14.cod_msj_swift=v_tip_mensaje
              and s14.est_solicitud='U'
              and s14.sit_solicitud='P'
              and s14.fec_recepcion is null
              and rownum=1
              order by 1 asc
              for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  p_dat_solicitud     := typ_ObtRespuesta014();
  v_tip_mensaje       := fug_obt_pardinamico('COD_RES_SOL_PAGO');
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe pain.014';

  FOR a IN cu_msj_tra LOOP
    select version
    into   v_version
    from ge_spi_cab_versiones 
    where tipo_msj='pain.013';

     v_cod_solicitud   :=a.cod_sol_spi;
     v_nro_ref_externa :=a.nro_ref_externa;

     p_dat_solicitud.nro_ref_externa      :=a.nro_ref_externa;
     p_dat_solicitud.fec_valor            :=sysdate;
     p_dat_solicitud.swi_pte_emi_original :=a.cod_swi_solicitante;
     p_dat_solicitud.nro_ref_original     :=a.nro_ref_original;
     p_dat_solicitud.fec_original         :=a.fec_recepcion;
     p_dat_solicitud.resp_procesamiento   :=a.tipo;
     p_dat_solicitud.swi_pte_emisor       :=a.cod_swi_beneficiario;
     p_dat_solicitud.cod_motivo_rechazo   :=a.tip_rechazo;
     p_dat_solicitud.mot_rechazo          :=a.respuesta;
     p_dat_solicitud.cod_msj_mx_original  :=v_version;
     p_dat_solicitud.tip_pte_emi_original :=a.tip_emi_original;
     p_dat_solicitud.tip_pte_emisor       :=a.tip_emisor;
    ---Registro de parametros 
    g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
    pas_snp.pr_reg_operacion('Tipo mensaje enviado: pain.014'||chr(10) ||
         ' Cod. Solicitud: '||a.cod_sol_spi|| chr(10) || 
         ' Ref. Externa: '||a.nro_ref_externa|| chr(10) ||
         ' Fecha valor: '||p_dat_solicitud.fec_valor|| chr(10) ||
         ' Tipo mensaje: '||a.tipo|| chr(10) ||
         ' BIC pte. emisor pain.013: '||a.cod_swi_solicitante|| chr(10) ||
         ' Ref. pain013: '||a.nro_ref_original|| chr(10) || 
         ' Fecha recepcion pain.013: '||a.fec_recepcion|| chr(10) || 
         ' Mot. rechazo: '||a.tip_rechazo|| chr(10) || 
         ' Descripcion rechazo: '||a.respuesta|| chr(10) ||
         ' BIC pte. emisor pain.013: '||a.cod_swi_beneficiario|| chr(10) ||
         ' Version pain.013: '||v_version||chr(10) ||
         ' Tipo emisor pain.013: '||a.tip_emi_original|| chr(10) ||
         ' Tipo emisor pain.014: '||a.tip_emisor
         , g_lugar||' Cod. Sol.: '||a.cod_sol_spi);   

  END LOOP;

  IF v_cod_solicitud IS NOT NULL THEN
    g_lugar:='Asigna datos para la cabecera de informe pain.014';
    p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi(c_mensaje,v_nro_ref_externa);
    g_lugar:='Actualizacion de transferencia pain.014 a bloqueado';
    --Modo de bloquear el registro
    UPDATE ge_spi_solicitudes sl
    SET sl.sit_solicitud='B'
    WHERE sl.cod_sol_spi=v_cod_solicitud;

    g_lugar:='Recupera cantidad de reintentos pain.014';
    begin
      select nvl( max(cantidad),0) into v_cant 
      from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos pain.014';

    insert into ge_spi_log_controles(nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
    values (v_cod_solicitud, v_nro_ref_externa, PAS_SPI.fu_tip_msj_spi(v_tip_mensaje),trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);

    g_lugar:='Proceso de envio de Sol. Pago, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Pain.014 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'Registro procesado';
    p_dat_mensaje         := mensaje;

  ELSE

    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_mensaje         := mensaje;

  END IF;

EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 50;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;

    UPDATE ge_spi_solicitudes sl
    SET sl.est_solicitud='C'
    WHERE sl.cod_sol_spi=v_cod_solicitud;

    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_014-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de pain.014, Ref. externa: '||v_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje        := mensaje;
END pr_obt_tra_pen_014;
/*
SPI - FASE2  Envío de solicitude pago (pain.014) al MS
*/
procedure pr_obt_tra_pen_002(p_dat_cabecera out typ_ObtdatCabecera,p_dat_solicitud out typ_ObtRespuesta002,p_dat_mensaje out typ_mensajeria_spi)  is
  /*
  || Procesa transferencias pendientes de ENVIO al SPI, de tipo pacs.008(Mensaje de pago de Crédito Directo)
  */
  v_cod_solicitud    ge_spi_solicitudes.cod_sol_spi%type;
  v_nro_ref_externa  ge_snp_transferencias.nro_ref_externa%type:= NULL;
  v_cant             number(8):=0;
  v_tip_mensaje      ge_spi_solicitudes.cod_msj_swift%type;
  c_mensaje          constant varchar2(10):='pain.002';
  mensaje            typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
  v_version          ge_spi_cab_versiones.version%type;

  cursor cu_msj_tra IS
          select   
              s2.cod_sol_spi,  
              s2.nro_ref_externa,
              s1.uetr,
              s1.nro_ref_externa nro_ref_original,
              s1.fec_recepcion,
              'NAUT' tipo,
              s1.tip_rechazo,
              (select cc.abreviatura
              from ba_cod_referencias cc 
              where cc.dominio='TIP_REC_SPI_P01'
              and cc.val_minimo=s1.tip_rechazo)respuesta,
              (select pt.tipo
              from gv_snp_participantes pt
              where pt.cod_swift=s1.cod_swi_solicitante)tip_emi_original
              from ge_spi_solicitudes s2 join ge_spi_solicitudes s1
              on s2.nro_referencia=s1.cod_sol_spi
              where s2.cod_msj_swift=v_tip_mensaje
              and s2.est_solicitud='U'
              and s2.sit_solicitud='P'
              and s2.fec_recepcion is null
              and rownum=1
              order by 1 asc
              for update skip locked;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  p_dat_solicitud     := typ_ObtRespuesta002();
  v_tip_mensaje       := fug_obt_pardinamico('COD_RES_INI_PAGO');
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de informe pain.002';


  FOR a IN cu_msj_tra LOOP
      select version
      into   v_version
      from ge_spi_cab_versiones 
      where tipo_msj='pain.001';

     v_cod_solicitud                      :=a.cod_sol_spi;
     v_nro_ref_externa                    :=a.nro_ref_externa;
     p_dat_solicitud.nro_ref_externa      :=a.nro_ref_externa;
     p_dat_solicitud.fec_valor            :=sysdate;
     p_dat_solicitud.swi_pte_ini_original :=a.uetr;
     p_dat_solicitud.nro_ref_original     :=a.nro_ref_original;
     p_dat_solicitud.fec_original         :=a.fec_recepcion;
     p_dat_solicitud.resp_procesamiento   :=a.tipo;
     p_dat_solicitud.cod_motivo_rechazo   :=a.tip_rechazo;
     p_dat_solicitud.mot_rechazo          :=a.respuesta;
     p_dat_solicitud.cod_msj_mx_original  :=v_version;
     p_dat_solicitud.tip_pte_emi_original :=a.tip_emi_original;
    ---Registro de parametros 
    g_lugar:='Registro de parametros en log '||a.nro_ref_externa;

    pas_snp.pr_reg_operacion('Tipo mensaje enviado: pain.002'||chr(10) ||
         ' Cod. Solicitud: '||a.cod_sol_spi|| chr(10) || 
         ' Ref. Externa: '||a.nro_ref_externa|| chr(10) ||
         ' Fecha valor: '||p_dat_solicitud.fec_valor|| chr(10) ||
         ' Tipo mensaje: '||a.tipo|| chr(10) ||
         ' BIC pte. emisor pain.001: '||a.uetr|| chr(10) ||
         ' Tipo pte. emisor pain.001: '||a.tip_emi_original|| chr(10) ||
         ' Ref. pain001: '||a.nro_ref_original|| chr(10) || 
         ' Fecha recepcion pain.001: '||a.fec_recepcion|| chr(10) || 
         ' Mot. rechazo: '||a.tip_rechazo|| chr(10) || 
         ' Descripcion rechazo: '||a.respuesta|| chr(10) ||
         ' Version pain.001: '||v_version
         , g_lugar||' Cod. Sol.: '||a.cod_sol_spi);   

  END LOOP;

  IF v_cod_solicitud IS NOT NULL THEN 
    g_lugar:='Asigna datos para la cabecera de informe pain.002';
    p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi(c_mensaje,v_nro_ref_externa);
    g_lugar:='Actualizacion de transferencia pain.002 a bloqueado';
    --Modo de bloquear el registro
    UPDATE ge_spi_solicitudes sl
    SET sl.sit_solicitud='B'
    WHERE sl.cod_sol_spi=v_cod_solicitud;

    g_lugar:='Recupera cantidad de reintentos pain.002';
    begin
      select nvl( max(cantidad),0) into v_cant 
      from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
    exception
        when no_data_found then
          v_cant:=0;
        when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos pain.002';

    insert into ge_spi_log_controles(nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
    values (v_cod_solicitud, v_nro_ref_externa, PAS_SPI.fu_tip_msj_spi(v_tip_mensaje),trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);

    g_lugar:='Proceso de envio de Sol. Pago, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Pain.002 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'Registro procesado';
    p_dat_mensaje         := mensaje;

  ELSE
    mensaje.cod_respuesta := 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_mensaje         := mensaje;
  END IF;
EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 50;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;

    UPDATE ge_spi_solicitudes sl
    SET sl.est_solicitud='C'
    WHERE sl.cod_sol_spi=v_cod_solicitud;

    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_002-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de pain.002, Ref. externa: '||v_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje        := mensaje;
END pr_obt_tra_pen_002;
/*Procesa la autorización de una solicitud recibida*/
procedure pr_pro_aut_solicitud(p_cod_solicitud in ge_spi_solicitudes.cod_sol_spi%type,
                               p_origen        in varchar2,
                               p_usuario       in varchar2,
                               p_monto         in number,
                               p_cod_retorno   out number,
                               p_men_retorno   out varchar2) is

r_sol                 ge_spi_solicitudes%rowtype;
e_val                 exception;
v_cta_pte_solicitante varchar2(20); -- Nro de Cuenta Interbancaria
v_cta_pte_sol_bcp     varchar2(20);
v_can_conjunta        number(5):=0;
v_ind_spi             varchar2(1);
v_sub_pte             varchar2(1):='N';
v_tip_rechazo         ge_spi_solicitudes.tip_rechazo%type;
v_est_inicial         ba_modulos.estado%type;
v_est_actual          ba_modulos.estado%type;
r_gtran               pas_snp.rg_msj;
v_tip_mensaje         ge_spi_solicitudes.cod_msj_swift%type;
v_cta_sub             ge_snp_patrocinador_det.cta_interna_sub%type;
v_hor_mov             ge_movimientos.hora%type;
v_estado              ge_snp_transferencias.estado%type;
c_tra_debito          constant number(5):=503;
v_cod_tra_credito     ge_movimientos.cod_transaccion%type;
v_nro_secuencia       ge_movimientos.nro_secuencia%type:=0;
v_tip_movimiento      ge_movimientos.tip_mov_rubro%type;
v_cod_tip_circuito    wf_tip_circuitos.cod_tip_circuito%type;
r_sol_res             ge_spi_solicitudes%rowtype;
r_gmovim              ge_movimientos%rowtype;
v_cod_swift_013       ge_spi_solicitudes.cod_msj_swift%type:=fug_obt_pardinamico('COD_SPI_SOL_PAGO');
v_cod_swift_056       ge_spi_solicitudes.cod_msj_swift%type:=fug_obt_pardinamico('COD_SPI_SOL_DEV');
v_cod_swift_001       ge_spi_solicitudes.cod_msj_swift%type:=fug_obt_pardinamico('COD_SPI_INI_PAGO');
v_cod_retorno         number(5):=0;
v_men_retorno         ge_spi_solicitudes.respuesta%type:='OK';
rg_msj                ge_snp_transferencias%rowtype;--mensaje original
/*v_cod_persona         ba_personas.cod_persona%type; 
v_nom_persona         ba_personas.nom_completo%type;
v_des_monto           varchar2(50);
v_ent_emisora         varchar2(100);
v_inf_json            long;*/

--TRFS-1381 Inicio
--v_tip_operacion       ge_snp_par_mensajes.cod_tip_operacion%type;
--v_sub_tip_operacion   ge_snp_par_mensajes.cod_sub_tip_operacion%type;
--TRFS-1381 Fin

begin
      begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

      p_cod_retorno :=0;
      p_men_retorno :='OK';
      v_tip_rechazo :=g_rch_dt02;
      pr_ini_var_spi;

      begin 
      select sl.*
      into r_sol
      from ge_spi_solicitudes sl
      where sl.cod_sol_spi=p_cod_solicitud;
      exception
        when no_data_found then
          p_cod_retorno := 19;
          p_men_retorno := 'No se encuentra la solicitud: ' ||p_cod_solicitud;
          raise e_val;
      end;
      --Si es un camt.056 recupero la transferencia original
      if r_sol.cod_msj_swift = fug_obt_pardinamico('COD_SPI_SOL_DEV') then
      begin
        Select tf.*
          into rg_msj
          from ge_snp_transferencias tf
         where tf.nro_ref_externa = r_sol.nro_ref_msj_original;
      exception
        when no_data_found then
          p_cod_retorno := 17;
          p_men_retorno := 'No se encuentra la transf. original: ' ||r_sol.nro_ref_msj_original;
          raise e_val;
      end;
--TRFS-1381 Inicio
/*
      --Recupero tipo y sub_tipo de operacion para un pacs.004 en respuesta de un camt.056
       begin
           select m.cod_tip_operacion, m.cod_sub_tip_operacion
            into v_tip_operacion, v_sub_tip_operacion
            from ge_snp_par_mensajes m
           where m.cod_msj_swift = (fug_obt_pardinamico('COD_SPI_DEV'))
             and m.tipo = g_pac_004;--g_cam_056; 
       exception
         when no_data_found then
           pas_spi.g_cod_error := 18;
           g_nom_respuesta := 'No se encuentra Codigo de Tipo y Subtipo de operacion - Mensaje: '||(fug_obt_pardinamico('COD_SPI_DEV'))||' Tipo: '||g_cam_056;
           pas_spi.g_msj_error := g_nom_respuesta;
       end;
*/       
--TRFS-1381 Fin
      end if;

      if r_sol.cod_swi_suc_solicitante is not null then
         v_sub_pte:='S';

         Begin
         select de.cta_interna_sub
         into v_cta_sub
         from ge_snp_patrocinador_det de
         where de.cod_swift_sub=r_sol.cod_swi_suc_solicitante
         and de.cod_swift_padre=r_sol.cod_swi_solicitante;
         exception
           when no_data_found then
          p_cod_retorno := 20;
          p_men_retorno := 'No se encuentra la cta_interna subparticipante.';
          raise e_val;
      end;

      end if;

      v_ind_spi := it.pas_spi.fu_obt_tra_spi(r_sol.cod_moneda,
                                             r_sol.monto,
                                             v_sub_pte,
                                             r_sol.cod_swi_solicitante);
    if v_ind_spi in ('C','R') then
       p_cod_retorno :=1;
       p_men_retorno :='El servicio SPI no se encuentra disponible, vuelva a intentar mas tarde';
       raise e_val;
    elsif v_ind_spi='N' then
       p_cod_retorno :=2;
       p_men_retorno :='La solicitud no cumple los requisitos para una transferencia SPI';
       v_tip_rechazo :=g_rch_am02;
       raise e_val;
    end if;

      pag_cta.pr_obt_cuenta(r_sol.cta_beneficiario);

      if pag_cta.g_ctas.nro_cuenta is null then
         p_cod_retorno :=3;
         p_men_retorno :='Cuenta de debito inexistente';
         v_tip_rechazo :=g_rch_ac01;
        raise e_val;
      end if;

      if p_origen='H' then

         begin
         select count(*)
         into v_can_conjunta
         from ge_cta_clientes
         where nro_cuenta = pag_cta.g_ctas.nro_cuenta
         and relacion = 'Y';
         exception
           when no_data_found then
             v_can_conjunta := 0;
         end;    

         if v_can_conjunta>0 then
            p_cod_retorno := 4;
            p_men_retorno := 'Cuenta conjunta, se requiere autorizacion de los firmantes';
            v_tip_rechazo:=g_rch_ag01;
            raise e_val;
         end if;
      end if;
      ---Validaciones sobre la cuenta origen
       lp_ver_horario(3); 
       v_est_inicial:=g_mod_estado;

       if g_mod_estado in (1,6) then
          p_cod_retorno :=5;
          p_men_retorno :='Entidad en proceso de cierre, vuelva a intentar';
          raise e_val;
       end if;

       v_cod_ofi_debito:=pag_cta.g_ctas.cod_oficina;

       pag_cta.pr_ver_operacion(pag_cta.g_ctas.nro_cuenta, 
                                v_cod_tra_padre,
                                v_cod_mod_padre,v_cod_mad_padre, 'D',
                                pag_cta.g_ctas.cod_moneda, 
                                --r_sol.monto, --Tomamos monto del formulario
                                case nvl(p_monto,0)
                                  when 0 then
                                    r_sol.monto
                                  else
                                    p_monto
                                end, 
                                v_cod_ofi_debito, 
                                v_cod_mod, 
                                v_cod_mad, 
                                v_est_cuenta, 
                                v_sal_disponible, 
                                v_procesa,v_tra_deb);
       if v_procesa='N' then
           if pag_cta.G_COD_ERROR=24 then
              v_tip_rechazo:=g_rch_ac04;
           elsif pag_cta.G_COD_ERROR=31 then
              v_tip_rechazo:=g_rch_am04;
           end if;
          p_cod_retorno := 6;
          p_men_retorno :=pag_cta.g_msj_error;
          raise e_val;
       end if;

        v_cta_pte_sol_bcp :=  pas_spi.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad),r_sol.cod_moneda);

        if v_cta_pte_sol_bcp is null then
           p_cod_retorno:= 7;
           p_men_retorno:='Falta configurar la cuenta del participante solicitante';
           raise e_val;
        end if;

        pas_snp.pr_ini_variables;
        v_cta_pte_solicitante :=  pas_snp.fu_obt_cta_bancaria(v_cta_pte_sol_bcp ,'C');
        --obtención del tipo y sub-tipo de operacion
        if r_sol.cod_msj_swift=v_cod_swift_013 then
           v_tip_mensaje :=fug_obt_pardinamico('COD_SPI_PCD');

           if r_sol.cod_tip_operacion='003' then

              if  v_sub_pte='N' then
                  r_gtran.cod_tip_operacion    :='003';
                  r_gtran.cod_sub_tip_operacion:='002';
              else
                  r_gtran.cod_tip_operacion    :='002';
                  r_gtran.cod_sub_tip_operacion:='002';
              end if;

           elsif r_sol.cod_tip_operacion='013' then
               if  v_sub_pte='N' then
                  r_gtran.cod_tip_operacion    :='013';
                  r_gtran.cod_sub_tip_operacion:='002';
              else
                  r_gtran.cod_tip_operacion    :='012';
                  r_gtran.cod_sub_tip_operacion:='002';
              end if;
           end if;
        elsif r_sol.cod_msj_swift = v_cod_swift_056 then
            v_tip_mensaje :=fug_obt_pardinamico('COD_SPI_DEV');
            --Asigno valores que recupero más arriba
            --TRFS-1381 Inicio
            r_gtran.cod_tip_operacion    := rg_msj.cod_tip_operacion;
            r_gtran.cod_sub_tip_operacion:= rg_msj.cod_sub_tip_operacion;
            --TRFS-1381 Fin
        elsif r_sol.cod_msj_swift=v_cod_swift_001 then 
              v_tip_mensaje :=fug_obt_pardinamico('COD_SPI_PCD');

               if r_sol.cod_tip_operacion='004' then
                  r_gtran.cod_tip_operacion    :='004';
                  r_gtran.cod_sub_tip_operacion:='002';
               elsif r_sol.cod_tip_operacion='014' then
                   r_gtran.cod_tip_operacion    :='014';
                   r_gtran.cod_sub_tip_operacion:='002';
               end if;
        end if;

          If r_sol.cod_msj_swift = v_cod_swift_056 then
           --carga de valores para insertar el registro del pacs.004
           r_gtran.nro_referencia           := pas_snp.fu_obt_sig_nro_referencia(g_fec_actual_h);
           r_gtran.cod_msj_swift            := v_tip_mensaje;
           r_gtran.fec_valor                := g_fec_valor;
           r_gtran.nro_cta_solicitante      := pag_cta.g_ctas.nro_cuenta;
           r_gtran.nro_cta_pte_solicitante  := rg_msj.nro_cta_pte_beneficiario;
           r_gtran.cod_swi_pte_solicitante  := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
           r_gtran.nro_cta_beneficiario     := rg_msj.nro_cta_solicitante;
           r_gtran.cod_swi_suc_beneficiario := rg_msj.cod_swi_suc_solicitante;
           r_gtran.cod_moneda               := rg_msj.cod_moneda;
           r_gtran.monto                    := p_monto;
           r_gtran.cod_modulo               := v_cod_mod_padre;
           r_gtran.cod_modalidad            := v_cod_mad_padre;
           r_gtran.cod_oficina              := pag_cta.g_ctas.cod_oficina;
           r_gtran.fec_ingreso              := g_fec_actual_h;
           r_gtran.cod_per_solicitante      := rg_msj.cod_per_beneficiario;
           r_gtran.nom_solicitante          := fue_obt_nom_persona(rg_msj.cod_per_beneficiario);
           r_gtran.dir_solicitante          := fue_obt_dir_principa(rg_msj.cod_per_beneficiario);
           r_gtran.cod_tip_doc_solicitante  := fue_obt_doc_principal(rg_msj.cod_per_beneficiario);
           r_gtran.nro_doc_solicitante      := fue_obt_nro_doc_persona(rg_msj.cod_per_beneficiario);
           r_gtran.nom_beneficiario         := rg_msj.nom_solicitante;
           r_gtran.dir_beneficiario         := rg_msj.dir_solicitante;
           r_gtran.cod_tip_doc_beneficiario := rg_msj.cod_tip_doc_solicitante;
           r_gtran.nro_doc_beneficiario     := rg_msj.nro_doc_solicitante;
           r_gtran.nro_cta_pte_beneficiario := rg_msj.nro_cta_pte_solicitante;
           r_gtran.cod_swi_pte_beneficiario := rg_msj.cod_swi_pte_solicitante;
           r_gtran.observacion              := null;
           r_gtran.ind_valor                := 'S';
           r_gtran.nro_ref_externa          := pas_spi.fu_obt_sig_nro_ref_externa;
           r_gtran.tip_cargo                := fue_obt_val_max_referencia('TIP_CAR_SIPAP', r_gtran.cod_msj_swift||'-'||rg_msj.cod_moneda);
           r_gtran.situacion                := 'P' ; -- Pendiente de Envio a BCP
           r_gtran.estado                   := 'S' ;
           r_gtran.nro_operacion            := r_gtran.nro_referencia ;
           r_gtran.tip_mensaje              := 'CRED' ;
           r_gtran.origen                   := p_origen;
           r_gtran.plataforma               := 'S';
           r_gtran.concepto                 := 'Dev.'||' '||r_sol.nro_ref_msj_original;
           r_gtran.indemnizado              := 'N';
           r_gtran.prioridad                := fus_snp_obt_prioridad(r_gtran.cod_msj_swift, r_gtran.cod_tip_operacion, r_gtran.cod_sub_tip_operacion);
           --r_gtran.tip_rechazo              := r_sol.tip_rechazo;
           --Insertamos en tip_rechazo de ge_snp_transferencias el motivo de la devolución.
           r_gtran.tip_rechazo              := r_sol.cod_mot_solicitud;

          else
           r_gtran.nro_referencia               := pas_snp.fu_obt_sig_nro_referencia(g_fec_actual_h);
           r_gtran.cod_msj_swift                := v_tip_mensaje;
           r_gtran.fec_valor                    := g_fec_valor;
           r_gtran.nro_cta_solicitante          := pag_cta.g_ctas.nro_cuenta;
           r_gtran.cod_moneda                   := r_sol.cod_moneda;
           r_gtran.cod_swi_pte_solicitante      := r_sol.cod_swi_beneficiario;
           r_gtran.nro_cta_pte_solicitante      := pas_spi.fu_obt_cta_ban_participante(r_gtran.cod_swi_pte_solicitante,r_gtran.cod_moneda);
           r_gtran.nro_cta_beneficiario         := r_sol.cta_solicitante;
           r_gtran.cod_swi_suc_beneficiario     := r_sol.cod_swi_suc_solicitante;
           r_gtran.monto                        := r_sol.monto ;
           r_gtran.cod_modulo                   := v_cod_mod_padre;
           r_gtran.cod_modalidad                := v_cod_mad_padre;
           r_gtran.cod_oficina                  := pag_cta.g_ctas.cod_oficina;
           r_gtran.fec_ingreso                  := g_fec_actual_h;    
           r_gtran.cod_per_solicitante          := fue_obt_cod_persona_doc(r_sol.tip_doc_beneficiario,r_sol.doc_beneficiario);
           r_gtran.nom_solicitante              := r_sol.nom_beneficiario;
           r_gtran.dir_solicitante              := fue_obt_dir_principa(r_gtran.cod_per_solicitante);
           r_gtran.cod_tip_doc_solicitante      := r_sol.tip_doc_beneficiario;
           r_gtran.nro_doc_solicitante          := r_sol.doc_beneficiario;
           r_gtran.nom_beneficiario             := r_sol.nom_solicitante;
           r_gtran.dir_beneficiario             := null;
           r_gtran.cod_tip_doc_beneficiario     := r_sol.tip_doc_solicitante;
           r_gtran.nro_doc_beneficiario         := r_sol.doc_solicitante;
           r_gtran.cod_swi_pte_beneficiario     := r_sol.cod_swi_solicitante;
           r_gtran.nro_cta_pte_beneficiario     := pas_spi.fu_obt_cta_ban_participante(r_gtran.cod_swi_pte_beneficiario, r_gtran.cod_moneda);
           r_gtran.nro_cta_suc_pte_beneficiario := v_cta_sub;
           r_gtran.ind_valor                    := 'S';
           r_gtran.nro_ref_externa              := pas_spi.fu_obt_sig_nro_ref_externa;
           r_gtran.tip_cargo                    := fue_obt_val_max_referencia('TIP_CAR_SIPAP', r_gtran.cod_msj_swift||'-'||r_gtran.cod_moneda);
           r_gtran.situacion                    := 'P' ; -- Pendiente de Envio a BCP
           r_gtran.estado                       := 'S' ;
           r_gtran.nro_operacion                :=  r_gtran.nro_referencia ;
           r_gtran.tip_mensaje                  := 'CRED' ;
           r_gtran.origen                       :=  p_origen;
           r_gtran.plataforma                   := 'S';
           r_gtran.concepto                     := r_gtran.nro_ref_externa;
           r_gtran.observacion                  := 'Resp. '||r_sol.nro_ref_externa;
           r_gtran.indemnizado                  := 'N';
           r_gtran.prioridad                    :=  fus_snp_obt_prioridad(r_gtran.cod_msj_swift, r_gtran.cod_tip_operacion, r_gtran.cod_sub_tip_operacion);
          end if;

          pas_snp.pr_ini_variables;
          pas_snp.pr_ins_transferencias(r_gtran);

          if pas_snp.fu_obt_cod_error!=0 then
              p_cod_retorno:=8;
              p_men_retorno:=pas_snp.fu_obt_msj_error;
          else
              --se vuelve a verificar si el estado inicial del modulo cambió
              v_est_actual:=pae_cnf.fu_obt_est_modulo(3);

              if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
                  p_cod_retorno:=9;
                  p_men_retorno:='Entidad en proceso de cierre, vuelva a intentar';
                  raise e_val;
              end if;
             --generar los movimientos
              v_hor_mov:= fug_obt_mov_hora;

              if g_es_mov_noc='N' then
                 if p_origen='I' then  --por ITGF
                   v_estado:='S';
                 else -- por HB
                   v_estado:='U';
                 end if;
                 pas_snp.pr_ini_variables;
                 pas_snp.pr_obt_par_mensajes(r_gtran.cod_msj_swift,    -- Tipo MT
                                            r_gtran.cod_tip_operacion,  -- Tipo de Operación
                                            r_gtran.cod_sub_tip_operacion,  -- Sub-Tipo de Operación
                                            'E',    -- Transferencia Enviada
                                            v_cod_mod_padre,
                                            v_cod_mad_padre,
                                            v_cod_tra_credito);

                if pas_snp.fu_obt_cod_error!=0 then
                   p_cod_retorno:=10;
                   p_men_retorno:=pas_snp.fu_obt_msj_error;
                   raise e_val;
                end if;
                pag_cta.g_horario := 'D';
                --setea variables del pag_cta
                pag_cta.pr_set_variables(nvl(p_usuario,user),
                                        g_fec_valor,
                                        v_cod_tra_padre,'N','N',
                                        v_nro_secuencia) ;

               --debito a la cuenta del cliente
                pag_cta.pr_act_operacion(pag_cta.g_ctas.nro_cuenta , -- Nro.Cta.
                                         v_hor_mov, -- Hora
                                         'D', -- Tip.Mov.
                                          pag_cta.g_ctas.cod_moneda, -- Cod.Mon.
                                          r_gtran.monto, -- Monto
                                          v_cod_tra_padre,-- Trx.Padre
                                          c_tra_debito,-- Trx.Hija
                                          r_gtran.nro_referencia,  -- Nro.Doc.
                                          null,-- Cotizacion
                                          pag_cta.g_ctas.cod_oficina, -- Ofic.Orig.
                                          v_cod_mod_padre, -- Mod.Pad.Cliente
                                          v_cod_mad_padre, -- Mad.Pad.Cliente
                                          null,            -- cod.tasa
                                          null,            -- val.tasa
                                          r_gtran.concepto, -- Concepto
                                          'S',              -- Emit.Aviso
                                          v_nro_secuencia,
                                          g_fec_valor,
                                          null,   -- Cod_Banco
                                          null,   -- Cod_Causa
                                         null);

               if pag_cta.fu_obt_cod_error != 0 then
                  p_cod_retorno:=11;
                  p_men_retorno:=pag_cta.fu_obt_msj_error;
                  raise e_val;
               else
                  v_est_actual:=pae_cnf.fu_obt_est_modulo(3);
                  if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
                     p_cod_retorno:=12;
                     p_men_retorno:='Entidad en proceso de cierre, vuelva a intentar';
                     raise e_val;
                  end if;
                  v_tip_movimiento := pas_snp.fu_obt_tip_mov_transaccion(v_cod_mod_padre,v_cod_mad_padre,v_cod_tra_credito) ;
                  --credito a la interbancaria
                  pag_cta.pr_obt_cuenta(v_cta_pte_solicitante);                    
                  r_gmovim.nro_secuencia   := v_nro_secuencia+1;             
                  r_gmovim.cod_usuario     := nvl(p_usuario,user);
                  r_gmovim.nro_cuenta      := v_cta_pte_solicitante;
                  r_gmovim.hora            := v_hor_mov;
                  r_gmovim.fecha           := g_fec_actual_h;
                  r_gmovim.cod_transaccion := v_cod_tra_credito;
                  r_gmovim.cod_modulo      := pag_cta.g_ctas.cod_modulo;
                  r_gmovim.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
                  r_gmovim.cod_oficina     := pag_cta.g_ctas.cod_oficina;
                  r_gmovim.cod_moneda      := pag_cta.g_ctas.cod_moneda;
                  r_gmovim.nro_documento   := r_gtran.nro_referencia;
                  r_gmovim.fec_valor       := g_fec_valor;
                  r_gmovim.cod_tra_padre   := v_cod_tra_padre;
                  r_gmovim.cod_mod_padre   := v_cod_mod_padre;
                  r_gmovim.cod_mad_padre   := v_cod_mad_padre;
                  r_gmovim.monto           := r_gtran.monto;
                  r_gmovim.cod_ofi_origen  := v_cod_ofi_debito; 
                  r_gmovim.emi_aviso       := 'S';
                  r_gmovim.estado          := 'N';
                  r_gmovim.reversado       := 'N';
                  r_gmovim.cod_rubro       := pac_che.fu_obt_rub_cta_ban(v_cta_pte_solicitante);
                  r_gmovim.tip_mov_rubro   := v_tip_movimiento;
                  r_gmovim.cotizacion      := null;
                  r_gmovim.mto_equ_local   := null;
                  r_gmovim.referencia      := r_gtran.cod_swi_pte_beneficiario;
                  r_gmovim.concepto        := r_gtran.concepto;

                  pag_gen.pr_ins_ge_movimiento(r_gmovim,'N');
               end if;

               IF r_gtran.nro_referencia is not null then
               update ge_snp_transferencias tf
               set tf.fecha   = g_fec_actual_h,
               tf.hora        = v_hor_mov,
               tf.cod_usuario = nvl(p_usuario,user),
               tf.estado      = v_estado
               where tf.nro_referencia=r_gtran.nro_referencia;
               IF sql%notfound THEN
                  pas_snp.pr_reg_operacion('Error al intentar actualizar la Transferencia: '||sqlerrm,'Referencia Nro.: '||r_gtran.nro_referencia);
               END IF;
               END IF;

            else
              --generación de movimientos nocturnos
              v_estado:='A';
              prg_gen_mov_noc_spi(r_gtran.monto,
                                  r_gtran.nro_cta_solicitante,
                                  v_cta_pte_solicitante,
                                  r_gtran.cod_moneda,
                                  r_gtran.cod_msj_swift,
                                  r_gtran.cod_tip_operacion,
                                  r_gtran.cod_sub_tip_operacion,
                                  r_gtran.nro_referencia,
                                  r_gtran.nro_ref_externa,
                                  r_gtran.cod_swi_pte_beneficiario,
                                  'E',
                                  'N',
                                  null,
                                  null,
                                  null,
                                  null,
                                  null,
                                  p_cod_retorno,
                                  p_men_retorno);

                if p_cod_retorno!=0 then
                   raise e_val;
                end if;
            end if;

            IF r_sol.cod_sol_spi is not null then
            update ge_spi_solicitudes st 
            set st.nro_referencia=r_gtran.nro_referencia,
            st.est_solicitud='A',
            st.respuesta=st.respuesta||chr(10)||'Ref. externa del pacs.00'||v_tip_mensaje||' enviado:'||r_gtran.nro_ref_externa
            where st.cod_sol_spi=r_sol.cod_sol_spi;
            IF sql%notfound THEN
               pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||r_sol.cod_sol_spi);
            END IF;
            END IF;
            --Notificación al cliente por el rechazo realizado.
             /*begin
               --enviar email de notificacion
               v_cod_persona := FUE_OBT_COD_PERSONA_DOC(r_gtran.cod_tip_doc_beneficiario, r_gtran.nro_doc_beneficiario);
               v_nom_persona := FUE_OBT_NOM_USUARIO(p_usuario);
               v_des_monto:=trim(to_char(r_gtran.monto,'9,999,999,999,999,990.00'))||' '||r_gtran.cod_moneda||'.';
               v_ent_emisora:=it.fug_obt_nom_snp_participante(r_gtran.cod_swi_pte_solicitante);
                v_inf_json := '"aviso":' || '"' ||
                              'Solicitud de Devolución Confirmada.' || '"' || '}';
                v_inf_json := '{' || '"referencia":' || '"' || r_gtran.nro_ref_externa || '"' || ',' ||
                              '"Receptor":' || '"' || FUE_OBT_NOM_PERSONA(v_cod_persona) || '"' || ',' ||
                              '"Cuenta:":' || '"' || r_gtran.nro_cta_beneficiario || '"' || ',' ||
                              '"monto":' || '"' || v_des_monto || '"' || ',' ||
                              '"ban_cue_beneficiario":' || '"' || v_ent_emisora || '"' || ',' ||
                              '"Emisor":' || '"' || r_gtran.nom_solicitante || '"' || ',' ||
                              '"Cuenta":' || '"' || r_gtran.nro_cta_solicitante || '"' || ',' ||
                              '"OP. Autorizante":' || '"' || v_nom_persona || '"' || ',' ||
                              v_inf_json;

                --Insertar correo para el solicitante
                pr_env_alerta(v_cod_persona,
                              fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'ENVCLISNP'),
                              v_inf_json);

             exception
               when others then
                 null;
             end;*/

         end if;
         v_est_actual:=pae_cnf.fu_obt_est_modulo(3);

         if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
             p_cod_retorno :=13;
             p_men_retorno :='Entidad en proceso de cierre, vuelva a intentar';
             raise e_val;
         end if;

         if p_origen='I' then 

           v_cod_tip_circuito := pas_snp.fu_obt_cod_tip_cir_workflow(r_gtran.cod_msj_swift,
                                                                    'E',
                                                                     r_gtran.cod_tip_operacion,
                                                                     r_gtran.cod_sub_tip_operacion);

           pas_snp.pr_ini_variables;
           if pas_snp.fu_obt_cod_error <> 0 then
              p_cod_retorno :=14;
              p_men_retorno :='No se pudo recuperar el circuito para el mensaje: '||r_gtran.cod_msj_swift;
              raise e_val;
           end if;

           if pas_snp.fu_ver_workflow(r_gtran.nro_referencia) then
              pas_snp.pr_can_workflow(r_gtran.nro_referencia);
           end if;

           if paw_cir.fu_ini_circuito(v_cod_tip_circuito,r_gtran.nro_referencia,r_gtran.cod_per_solicitante) <> 0 then
              p_cod_retorno :=15;
              p_men_retorno :=paw_cir.fu_obt_msj_error;
              raise e_val;
           end if;
         end if; 
exception
  when e_val then
       rollback;
       if r_sol.cod_msj_swift in(v_cod_swift_013,v_cod_swift_001,v_cod_swift_056) then
          pr_pro_rec_solicitud(r_sol.cod_sol_spi,v_tip_rechazo,v_cod_retorno,v_men_retorno);
       end if;

  when others then
       rollback;
       if r_sol.cod_msj_swift in(v_cod_swift_013,v_cod_swift_001,v_cod_swift_056) then
          p_cod_retorno :=16;
          p_men_retorno :=sqlerrm;
          pr_pro_rec_solicitud(r_sol.cod_sol_spi,v_tip_rechazo,v_cod_retorno,v_men_retorno);
       end if;
end pr_pro_aut_solicitud;
/*Procesa el rechazo de una solicitud recibida*/
procedure pr_pro_rec_solicitud(p_cod_solicitud in ge_spi_solicitudes.cod_sol_spi%type,
                               p_cod_rechazo   in ge_spi_solicitudes.tip_rechazo%type,
                               p_cod_retorno   out number,
                               p_men_retorno   out varchar2) is

r_sol             ge_spi_solicitudes%rowtype;
r_pag_original    ge_snp_transferencias%rowtype;
v_des_rechazo     ba_cod_referencias.abreviatura%type;
r_sol_res         ge_spi_solicitudes%rowtype;  
v_cod_persona     ba_personas.cod_persona%type;
v_tip_persona     ba_personas.tipo%type;    
v_des_monto       varchar2(50);
v_ent_emisora     varchar2(100);
v_inf_json        long;
v_nombre_saludo   varchar2(100);  
v_ent_debito      varchar2(100);
v_ent_credito     varchar2(100); 

begin
     p_cod_retorno:=0;
     p_men_retorno:='OK';
     begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
    --solicitud que se va rechazar
     begin
          select sl.*
          into r_sol
          from ge_spi_solicitudes sl
          where sl.cod_sol_spi=p_cod_solicitud;
     exception
          when no_data_found then 
           p_cod_retorno:=37;
           p_men_retorno:='No se encuentra la solicitud N°: '||p_cod_solicitud;
           return;
     end;
     --datos del pago original para las notificaciones
     if r_sol.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_DEV') then
     begin
          select s.*
          into r_pag_original
          from ge_snp_transferencias s
          where s.nro_ref_externa = r_sol.nro_ref_msj_original;
     exception
          when no_data_found then 
           p_cod_retorno:=44;
           p_men_retorno:='No se encuentra el pago Original: '||r_sol.nro_ref_msj_original;
           return;
     end;
     end if;
     --013  
     if r_sol.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_PAGO') then
         begin
            select cc.abreviatura
            into v_des_rechazo
            from ba_cod_referencias cc 
            where cc.dominio='TIP_REC_SPI_P14'
            and cc.val_minimo=p_cod_rechazo;

         exception
           when no_data_found then
               p_cod_retorno:=38;
               p_men_retorno:='No existe el motivo de rechazo: '||p_cod_rechazo;
               return;
         end;

         r_sol_res.nro_ref_externa     :=pas_spi.fu_obt_sig_nro_ref_externa;
         r_sol_res.nro_referencia      :=r_sol.cod_sol_spi;
         r_sol_res.cod_msj_swift       :=fug_obt_pardinamico('COD_RES_SOL_PAGO');
         r_sol_res.monto               :=r_sol.monto;
         r_sol_res.cod_moneda          :=r_sol.cod_moneda;
         r_sol_res.msj_mx              :=r_sol.msj_mx;
         r_sol_res.sit_solicitud       :='P';
         r_sol_res.est_solicitud       :='U';
         r_sol_res.est_notificacion    :='X';

         pas_spi.pr_ins_sol_spi(r_sol_res,r_sol_res.cod_sol_spi);

         if r_sol_res.cod_sol_spi is null then
            p_cod_retorno:=40;
            p_men_retorno:='No se puedo generar la respuesta pain.014';
            return;
         end if;

         IF r_sol.cod_sol_spi is not null then
            update ge_spi_solicitudes su
            set su.est_solicitud = 'R',
            su.respuesta     = v_des_rechazo,
            su.tip_rechazo   = p_cod_rechazo
            where su.cod_sol_spi = r_sol.cod_sol_spi;   
            IF sql%notfound THEN
               pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||r_sol.cod_sol_spi);
            END IF;
         END IF;
         begin
             v_cod_persona := fue_obt_cod_persona_doc(r_sol.tip_doc_beneficiario, r_sol.doc_beneficiario);
             v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
             if v_tip_persona='J' then
                pr_not_sol_pago('RECSOLPAGRECJU',r_sol,p_cod_rechazo);
             elsif v_tip_persona='F' then
                pr_not_sol_pago('RECSOLPAGRECFI',r_sol,p_cod_rechazo);
             end if;
         exception
            when others then
                 null;
         end;
     end if;
     --001
     if r_sol.cod_msj_swift=fug_obt_pardinamico('COD_SPI_INI_PAGO') then
         begin
            select cc.abreviatura
            into v_des_rechazo
            from ba_cod_referencias cc 
            where cc.dominio='TIP_REC_SPI_P01'
            and cc.val_minimo=p_cod_rechazo;

         exception
           when no_data_found then
               p_cod_retorno:=45;
               p_men_retorno:='No existe el motivo de rechazo: '||p_cod_rechazo;
               return;
         end;

         r_sol_res.nro_ref_externa     :=pas_spi.fu_obt_sig_nro_ref_externa;
         r_sol_res.nro_referencia      :=r_sol.cod_sol_spi;
         r_sol_res.cod_msj_swift       :=fug_obt_pardinamico('COD_RES_INI_PAGO');
         r_sol_res.monto               :=r_sol.monto;
         r_sol_res.cod_moneda          :=r_sol.cod_moneda;
         r_sol_res.msj_mx              :=r_sol.msj_mx;
         r_sol_res.sit_solicitud       :='P';
         r_sol_res.est_solicitud       :='U';
         r_sol_res.est_notificacion    :='X';

         pas_spi.pr_ins_sol_spi(r_sol_res,r_sol_res.cod_sol_spi);

         if r_sol_res.cod_sol_spi is null then
            p_cod_retorno:=44;
            p_men_retorno:='No se puedo generar la respuesta pain.001';
            return;
         end if;

         IF r_sol.cod_sol_spi is not null then
            update ge_spi_solicitudes su
            set su.est_solicitud = 'R',
            su.respuesta     = v_des_rechazo,
            su.tip_rechazo   = p_cod_rechazo
           where su.cod_sol_spi = r_sol.cod_sol_spi;   
           IF sql%notfound THEN
              pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||r_sol.cod_sol_spi);
           END IF;
         END IF;
         begin
              v_cod_persona := fue_obt_cod_persona_doc(r_sol.tip_doc_beneficiario, r_sol.doc_beneficiario);
              v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
              if v_tip_persona='J' then
                     pr_not_sol_pago('RECSOLINIRECJU',r_sol,p_cod_rechazo);
              elsif v_tip_persona='F' then
                     pr_not_sol_pago('RECSOLINIRECFI',r_sol,p_cod_rechazo);
              end if;
         exception
              when others then
                    null;
          end;
     end if;
     --056
     if r_sol.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_DEV') then
        begin
            select cc.abreviatura
            into v_des_rechazo
            from ba_cod_referencias cc 
            where cc.dominio='TIP_REC_SOL_DEV'
            and cc.val_minimo=p_cod_rechazo;

         exception
           when no_data_found then
               p_cod_retorno:=41;
               p_men_retorno:='No existe el motivo de rechazo: '||p_cod_rechazo;
               return;
         end;

             r_sol_res.nro_ref_externa     :=PAS_SPI.fu_obt_sig_nro_ref_externa;
             r_sol_res.nro_referencia      :=r_sol.cod_sol_spi;
             r_sol_res.cod_msj_swift       :=fug_obt_pardinamico('COD_SPI_SOL_REC');
             r_sol_res.monto               :=r_sol.monto;
             r_sol_res.msj_mx              :=r_sol.msj_mx;
             r_sol_res.sit_solicitud       :='P';
             r_sol_res.est_solicitud       :='U';
             r_sol_res.est_notificacion    :='X';

             g_lugar:='Insertar respuesta a la solictiud. (camt.029)';
             pas_spi.pr_ins_sol_spi(r_sol_res,r_sol_res.cod_sol_spi);

             if r_sol_res.cod_sol_spi is  null then
                  p_cod_retorno:=42;
                  p_men_retorno:='No se puedo generar la respuesta camt.029';
                  return;
             end if;
     --seccion de notificaciones--
       begin
           v_cod_persona := r_pag_original.cod_per_beneficiario;   
          --se identifica que tipo de persona es para el envio de mail
           v_tip_persona := pas_spi.fu_obt_tip_persona(v_cod_persona);
          --obtenemos el nombre corto en base al tipo de persona
          if v_tip_persona = 'F' then
           v_nombre_saludo := FUE_OBT_NOM_PER_CORTO(v_cod_persona);
          else
           v_nombre_saludo := fue_obt_nom_comercial(v_cod_persona);
          end if; 
          v_ent_debito:=it.fug_obt_nom_snp_participante(r_sol.cod_swi_beneficiario); 
          v_ent_credito:=it.fug_obt_nom_snp_participante(r_sol.cod_swi_solicitante);
               --formato nuevo
               v_inf_json := '{' || '"nombre_saludo":' || '"' || v_nombre_saludo || '"' || ',' || 
                              '"nombre_titulo":' || '"' || r_sol.nom_solicitante|| '"' || ',' ||
                              '"cuenta_debito":' || '"' || r_sol.cta_beneficiario || '"' || ',' ||
                              '"titular_debito":' || '"' || r_sol.nom_beneficiario || '"' || ',' ||
                              '"entidad_debito":' || '"' || v_ent_debito || '"' || ',' ||
                              '"monto":' || '"' || trim(to_char(r_sol.monto,'9,999,999,999,999,990.00')) || '"' || ',' ||
                              '"moneda_debito":' || '"' || r_sol.cod_moneda || '"' || ',' ||
                              '"nro_operacion":' || '"' || r_sol.nro_ref_externa || '"' || ',' ||
                              '"fecha_hora":' || '"' || r_sol.fec_insercion || '"' || ',' ||
                              '"cuenta_credito":' || '"' || r_sol.cta_solicitante || '"' || ',' ||
                              '"titular_credito":' || '"' || r_sol.nom_solicitante || '"' || ',' ||
                              '"entidad_credito":' || '"' || v_ent_credito || '"' || ',' ||
                              '"doc_credito":' || '"' || r_sol.doc_solicitante || '"' || ',' ||
                              '"concepto":' || '"' || v_des_rechazo || '"' || ',' ||
                              '"tipo_operacion":' || '"' || 'Rechazo de Solicitud de Devolución' || '"' || ',' ||
                              '"comprobante":' || '"' || r_sol_res.nro_ref_externa || '"' || '}';


               if v_tip_persona = 'F' then                               
                pr_env_alerta(v_cod_persona, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'ENVNOT029F'),v_inf_json);
               else
                pr_env_alerta(v_cod_persona, fue_obt_val_max_referencia('TIP_MAI_PRODUCTO', 'ENVNOT029J'),v_inf_json);
               end if;              
                --Actualizó la solicitud luego del rechazo.(camt.029 enviado)     
                IF r_sol.cod_sol_spi is not null then  
                update ge_spi_solicitudes su
                   set su.sit_solicitud = 'C',
                       su.est_solicitud = 'R',
                       su.respuesta     = su.respuesta ||chr(10)|| v_des_rechazo,
                       su.tip_rechazo   = p_cod_rechazo
                 where su.cod_sol_spi = r_sol.cod_sol_spi;      
                 IF sql%notfound THEN
                    pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Solicitud Nro.: '||r_sol.cod_sol_spi);
                 END IF;
                END IF;        
             exception
               when others then
                 null;
             end;
           --  
     end if;
exception
   when others then
        p_cod_retorno:=43;
        p_men_retorno:=sqlerrm;
end pr_pro_rec_solicitud;
/*
SPI - FASE2  Envío de Rechazo de Solicitud de devolución Recibida (camt.029) al MS
*/
procedure pr_obt_tra_pen_029(p_dat_cabecera out typ_ObtdatCabecera,p_dat_respuesta out typ_ObtRechazoSoldev029,p_dat_mensaje out typ_mensajeria_spi)  is
  /*
  || Procesa transferencias pendientes de ENVIO al SPI, de tipo pacs.008(Mensaje de pago de Crédito Directo)
  */
  v_cod_solicitud    ge_spi_solicitudes.cod_sol_spi%type;
  v_nro_ref_externa  ge_snp_transferencias.nro_ref_externa%type:= NULL;
  v_cant             number(8):=0;
  v_tip_mensaje      ge_spi_solicitudes.cod_msj_swift%type;
  cab_mensaje          constant varchar2(10):=g_cam_029;
  bdy_mensaje        constant varchar2(10):=g_cam_056;
  mensaje            typ_mensajeria_spi := typ_mensajeria_spi(0,null,null);
  v_version          ge_spi_cab_versiones.version%type;
  v_tipo_ben         varchar2(10);
  v_tipo_sol         varchar2(10);

  cursor cu_msj_tra IS
          select   
              s14.cod_sol_spi,  
              s14.nro_ref_externa,
              s13.cod_swi_solicitante,
              s13.nro_ref_externa nro_ref_original,
              s13.fec_recepcion,
              'RJCR' tipo,
              s13.cod_swi_beneficiario,
              s13.tip_rechazo,
              FUE_OBT_DES_REFCODES('TIP_REC_SOL_DEV', s13.tip_rechazo, 'N') desc_rechazo,
              s13.respuesta
              from ge_spi_solicitudes s14 join ge_spi_solicitudes s13
              on s14.nro_referencia=s13.cod_sol_spi
              where s14.cod_msj_swift=v_tip_mensaje
              and s14.est_solicitud='U'
              and s14.sit_solicitud='P'
              and s14.fec_recepcion is null
              and rownum=1
              order by 1 asc
              for update skip locked;

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  p_dat_respuesta     := typ_ObtRechazoSoldev029();
  v_tip_mensaje       := fug_obt_pardinamico( 'COD_SPI_SOL_REC');
  PAS_SPI.g_cod_error := 0;
  PAS_SPI.g_msj_error := NULL;
  g_lugar:='Lee datos de rechazo camt.029';

  FOR a IN cu_msj_tra LOOP 
  Begin
    g_lugar:='Recupero version del mensaje camt.029';
  select version
  into   v_version
  from ge_spi_cab_versiones 
  where tipo_msj=bdy_mensaje;
  exception
    when no_data_found then
      v_version := null;
  end;    

     v_cod_solicitud   :=a.cod_sol_spi;
     v_nro_ref_externa :=a.nro_ref_externa;
     --Recupera tipo de participante
    begin
      g_lugar:='Recupero tipo de participante del solicitante';
      select tipo
        into v_tipo_sol
        from gv_snp_participantes
       where cod_swift = a.cod_swi_solicitante;
    exception
      when no_data_found then
        v_tipo_sol := null;
      when others then
        v_tipo_sol := null;
    end;
    begin
      g_lugar:='Recupero tipo de participante del beneficiario';
      select tipo
        into v_tipo_ben
        from gv_snp_participantes
       where cod_swift = a.cod_swi_beneficiario;
    exception
      when no_data_found then
        v_tipo_ben := null;
      when others then
        v_tipo_ben := null;
    end;

     p_dat_respuesta.nro_ref_externa      :=a.nro_ref_externa;
     p_dat_respuesta.fec_valor            :=sysdate;
     p_dat_respuesta.swi_pte_receptor     :=a.cod_swi_solicitante; --debe ser el solicitante para el MS(estaba beneficiario)
     p_dat_respuesta.nro_ref_original     :=a.nro_ref_original;
     p_dat_respuesta.fec_original         :=a.fec_recepcion;
     p_dat_respuesta.cod_clave            :=a.tipo;
     p_dat_respuesta.swi_pte_emisor       :=a.cod_swi_beneficiario; --debe ser el beneficiario para el MS(estaba solicitante)
     p_dat_respuesta.cod_motivo_rechazo   :=a.tip_rechazo;
     p_dat_respuesta.mot_rechazo          :=substr(a.desc_rechazo,1,35);--para que no falle el MS
     p_dat_respuesta.cod_msj_mx_original  :=v_version;
     p_dat_respuesta.tip_pte_emisor       :=v_tipo_sol;
     p_dat_respuesta.tip_pte_receptor     :=v_tipo_ben;

    ---Registro de parametros 
    g_lugar:='Registro de parametros en log '||a.nro_ref_externa;
    pas_snp.pr_reg_operacion('Tipo mensaje enviado: camt.029'||chr(10) ||
         ' Cod. Solicitud: '||a.cod_sol_spi|| chr(10) || 
         ' Ref. Externa: '||a.nro_ref_externa|| chr(10) ||
         ' Fecha valor: '||p_dat_respuesta.fec_valor|| chr(10) ||
         ' Tipo mensaje: '||a.tipo|| chr(10) ||
         ' BIC pte. emisor camt.056: '||a.cod_swi_solicitante|| chr(10) ||
         ' Tipo pte. emisor camt.056: '||v_tipo_sol|| chr(10) ||
         ' Ref. camt.056: '||a.nro_ref_original|| chr(10) || 
         ' Fecha recepcion camt.056: '||a.fec_recepcion|| chr(10) || 
         ' Mot. rechazo: '||a.tip_rechazo|| chr(10) || 
         ' Descripcion rechazo: '||a.desc_rechazo|| chr(10) ||
         ' BIC pte. receptor camt.056: '||a.cod_swi_beneficiario|| chr(10) ||
         ' Tipo pte. receptor camt.056: '||v_tipo_ben|| chr(10) ||
         ' Version camt.056: '||v_version
         , g_lugar||' Cod. Sol.: '||a.cod_sol_spi);   

  END LOOP;

  IF v_cod_solicitud is not null THEN
  g_lugar:='Asigna datos para la cabecera del rechazo camt.029';
  p_dat_cabecera :=PAS_SPI.fu_obt_cab_spi(cab_mensaje,v_nro_ref_externa);
  g_lugar:='Actualizacion de transferencia camt.029a bloqueado';
  --Modo de bloquear el registro
  UPDATE ge_spi_solicitudes sl
  SET sl.sit_solicitud='B'
  WHERE sl.cod_sol_spi=v_cod_solicitud;

    g_lugar:='Recupera cantidad de reintentos camt.029';
    begin
      select nvl( max(cantidad),0) into v_cant 
      from ge_spi_log_controles
      where nro_ref_externa=v_nro_ref_externa;
      exception
        when no_data_found then
          v_cant:=0;
           when others then
          v_cant:=0;
    end;
    g_lugar:='Insercion de reintentos camt.029';

    insert into ge_spi_log_controles(nro_referencia, nro_ref_externa, cod_msj_mx, fecha, hora, cantidad)
    values (v_cod_solicitud, v_nro_ref_externa, FUE_OBT_DES_REFCODES('COD_MSJ_SWIFT', fug_obt_pardinamico('COD_SPI_SOL_REC'),'N'),trunc(sysdate),to_char(sysdate, 'HH24:MI:SS'),v_cant+1);

    g_lugar:='Proceso de envio de Rechazo por Sol. Devolucion, Ref.Externa: '||v_nro_ref_externa;
    pas_snp.pr_reg_operacion( g_lugar, 'Camt.029 Procesado OK,Ref. externa: '||v_nro_ref_externa|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta ); 
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'Registro procesado';
    p_dat_mensaje         := mensaje;

  ELSE
    mensaje.cod_respuesta:= 0;
    mensaje.nom_respuesta := 'OK';
    mensaje.des_Respuesta := 'No existe registro a procesar';
    p_dat_mensaje         := mensaje;

  END IF;

EXCEPTION
  WHEN others THEN
    PAS_SPI.g_cod_error := 137;
    PAS_SPI.g_msj_error := g_lugar||'-'||sqlerrm;

    UPDATE ge_spi_solicitudes sl
    SET sl.est_solicitud='C'
    WHERE sl.cod_sol_spi=v_cod_solicitud;

    mensaje.cod_respuesta := 1;
    mensaje.nom_respuesta := 'Error en pr_obt_tra_pen_029-'||g_lugar;
    mensaje.des_Respuesta:=sqlerrm;
    pas_snp.pr_reg_operacion( 'Error en envio de camt.029, Ref. externa: '||v_nro_ref_externa, g_lugar|| '|' || mensaje.cod_respuesta|| '|' ||mensaje.nom_respuesta|| '|' ||mensaje.des_Respuesta );  
    p_dat_mensaje        := mensaje;
END pr_obt_tra_pen_029;
/*
Obtiene los datos del OMP
*/
function fu_obt_dat_omp(p_cod_swift in varchar2) return ge_entes%rowtype is
r_reg ge_entes%rowtype;
begin
      pas_spi.g_cod_error:=0;
      pas_spi.g_msj_error:=null;

      select c.*
      into r_reg
      from ge_entes c join ge_par_entes d
      on c.cod_ente=d.cod_ente
      where tipo='PS'
      and d.parametro='COD_SWIFT'
      and d.val_parametro=p_cod_swift;
       return r_reg;
exception      
   when no_data_found then
     pas_spi.g_cod_error:=205;
     pas_spi.g_msj_error:='No se encuentra el swift: '||p_cod_swift||' para una OMP';
     return r_reg;
end fu_obt_dat_omp;

/*Obtiene el tipo de persona , F: Fisica , J: Juridica*/
function fu_obt_tip_persona(p_cod_persona in varchar2) return varchar2 is
  v_tip_persona ba_personas.tipo%type;
begin
  pas_spi.g_cod_error := 0;
  pas_spi.g_msj_error := null;

  select tipo
    into v_tip_persona
    from ba_personas
   where cod_persona = p_cod_persona;

  return v_tip_persona;
exception
  when no_data_found then
    pas_spi.g_cod_error := 206;
    pas_spi.g_msj_error := 'No se encuentra el tipo de persona para el codigoPersona: ' ||
                           p_cod_persona;
end fu_obt_tip_persona;
/*
Envía notificaciones sobre solicitudes de pago o solicitudes de inicio de pago
*/
procedure pr_not_sol_pago(p_notifica in varchar2,p_solicitud in ge_spi_solicitudes%rowtype,p_cod_rechazo in varchar2 default null) is
v_inf_json     long:=null;
v_persona      ba_personas.cod_persona%type;
v_des_rechazo  ba_cod_referencias.abreviatura%type;
v_dominio      ba_cod_referencias.abreviatura%type;
v_nom_saludo   varchar2(1000);
begin
      begin
           if p_cod_rechazo is not null then

             if p_solicitud.cod_msj_swift=fug_obt_pardinamico('COD_SPI_SOL_PAGO') then
                v_dominio:='TIP_REC_SPI_P14';
             elsif p_solicitud.cod_msj_swift=fug_obt_pardinamico('COD_SPI_INI_PAGO') then
                v_dominio:='TIP_REC_SPI_P01';
             end if;

              select cc.abreviatura
              into v_des_rechazo
              from ba_cod_referencias cc 
              where cc.dominio=v_dominio
              and cc.val_minimo=p_cod_rechazo;

           end if;

       exception
           when no_data_found then
              v_des_rechazo:=null;
       end;

     if p_notifica='ENVSOLPAGREC' then

       v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_solicitante,p_solicitud.doc_solicitante);
       v_nom_saludo :=fue_obt_nom_comercial(v_persona);
       v_inf_json        := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_insercion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"motivo":' || '"' ||v_des_rechazo|| '"' || '}'; 

     elsif p_notifica='ENVSOLPAG' then
           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_solicitante,p_solicitud.doc_solicitante);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json     := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}'; 

     elsif p_notifica='RECSOLPAGJU' then
           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}'; 

     elsif p_notifica='RECSOLPAGFI' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_per_corto(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}';

     elsif p_notifica='RECSOLPAGRECJU' then
           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || ',' ||
                            '"motivo":' || '"' ||v_des_rechazo|| '"' || '}';

     elsif p_notifica='RECSOLPAGRECFI' then
           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_per_corto(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || ',' ||
                            '"motivo":' || '"' ||v_des_rechazo|| '"' || '}';

     elsif p_notifica='ENVSOLPAGRECTO' then
           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_solicitante,p_solicitud.doc_solicitante);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json        := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_insercion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"'|| '}'; 
     elsif p_notifica='RECSOLPAGTOFI' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_per_corto(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}';
     elsif p_notifica='RECSOLPAGTOJU' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}';
       elsif p_notifica='RECSOLINIJU' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de Inicio de Pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}';
      elsif p_notifica='RECSOLINIFI' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_per_corto(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de Inicio de Pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}';

      elsif p_notifica='RECSOLINIRECJU' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de Inicio de Pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || ',' ||
                            '"motivo":' || '"' ||v_des_rechazo|| '"' || '}';

         elsif p_notifica='RECSOLINIRECFI' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_per_corto(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de Inicio de Pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || ',' ||
                            '"motivo":' || '"' ||v_des_rechazo|| '"' || '}';

         elsif p_notifica='RECSOLINITOJU' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_comercial(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de Inicio de Pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}';

         elsif p_notifica='RECSOLINITOFI' then

           v_persona    :=fue_obt_cod_persona_doc(p_solicitud.tip_doc_beneficiario,p_solicitud.doc_beneficiario);
           v_nom_saludo :=fue_obt_nom_per_corto(v_persona);
           v_inf_json       := '{' || '"nombre_saludo":' || '"' || v_nom_saludo || '"' || ',' || 
                            '"nro_cta_debito":' || '"' ||p_solicitud.cta_beneficiario|| '"' || ',' || 
                            '"nom_cta_debito":' || '"' ||p_solicitud.nom_beneficiario || '"' || ',' || 
                            '"ban_cue_debito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_beneficiario)|| '"' || ',' ||
                            '"monto":' || '"' ||trim(to_char(p_solicitud.monto,'9,999,999,999,999,990.00'))|| '"' || ',' || 
                            '"cod_moneda":' || '"' ||p_solicitud.cod_moneda|| '"' || ',' ||
                            '"nro_transaccion":' || '"' ||null || '"' || ',' || 
                            '"fec_solicitud":' || '"' || to_char(p_solicitud.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS') || '"' || ',' || 
                            '"nro_cta_credito":' || '"' ||p_solicitud.cta_solicitante|| '"' || ',' ||
                            '"nom_cta_credito":' || '"' ||p_solicitud.nom_solicitante|| '"' || ',' ||
                            '"ban_cta_credito":' || '"' ||it.fug_obt_nom_snp_participante(p_solicitud.cod_swi_solicitante)|| '"' || ',' ||   
                            '"concepto":' || '"' ||null|| '"' || ',' ||
                            '"tip_operacion":' || '"' ||'Solicitud de Inicio de Pago'|| '"' || ',' ||
                            '"nro_comprobante":' || '"' ||p_solicitud.nro_ref_externa|| '"' || ',' ||
                            '"doc_cli_debito":' || '"' ||p_solicitud.doc_beneficiario|| '"' || '}';
         end if;

         pas_spi.pr_env_alerta(v_persona,fue_obt_val_max_referencia('TIP_MAI_PRODUCTO',p_notifica),v_inf_json);
exception
    when others then 
        null;
end;
/*
Cancela de forma automática las solicitudes de devolución que no fueron autorizados/rechazados.
*/  
procedure pr_can_aut_sol_dev is
v_sol_del       ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('COD_SPI_SOL_DEV');
v_dias_maximos  ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('SPI_CAN_DIA_SOL_DEVOLUCION');

cursor c_sol is
     select *
      from ge_spi_solicitudes sol
      where sol.cod_msj_swift in (v_sol_del)
      and sol.est_solicitud in ('S','A')
      and sol.sit_solicitud not in ('L')
      and (trunc(sysdate)-trunc(sol.fec_insercion)) > v_dias_maximos ;
begin
 begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

  for reg in c_sol loop 

      IF reg.cod_sol_spi is not null then
      update ge_spi_solicitudes soli
      set soli.est_solicitud = 'C',
      soli.tip_rechazo = 'DT02' --Ver que debe ir acá
      where soli.cod_sol_spi = reg.cod_sol_spi ;
      IF sql%notfound THEN
         pas_snp.pr_reg_operacion('Error al intentar actualizar la solicitud: '||sqlerrm,'Nro.: '||reg.cod_sol_spi);
      END IF;
      END IF;

  end loop;

exception 
     when others then 
           null; --si se produce alguna excepción no retringir la ejecución de los otros procesos
end pr_can_aut_sol_dev;
PROCEDURE pr_rev_ope_spi( p_nro_referencia in ge_snp_transferencias.nro_referencia%type,
                                p_concepto       in ge_movimientos.concepto%type default null,
                                p_estado         in ge_snp_transferencias.estado%type default 'C',
                                p_ref_externa   ge_snp_transferencias.nro_ref_externa%type,
                                p_fecha         ge_movimientos.fecha%type,
                                p_hora          ge_movimientos.hora%type,
                                p_cod_usuario   ge_movimientos.cod_usuario%type)
IS
   /*
   || Reversión de operación SPI 
   */

   v_hor_reversion ge_movimientos.hor_reversion%type := fug_obt_mov_hora;
   v_concepto      ge_movimientos.concepto%type;
   v_usu_reversion ba_usuarios.cod_usuario%type;

   cursor cur_snp ( p_fecha         ge_movimientos.fecha%type,
                    p_hora          ge_movimientos.hora%type,
                    p_cod_usuario   ge_movimientos.cod_usuario%type,
                    p_nro_documento ge_movimientos.nro_documento%type
                  ) is
      select distinct fecha,
             hora,
             cod_usuario,
             cod_mod_padre,
             cod_mad_padre,
             cod_tra_padre,
             nro_documento,--TRFS-1121
             nro_documento2,
             concepto
        from ge_movimientos
       where fecha         = p_fecha
         and hora          = p_hora
         and cod_usuario   = p_cod_usuario
         and nro_documento = p_nro_documento
         and reversado = 'N';

BEGIN

   g_lugar := 'Buscando movimientos para el proceso de reversión ';
   for rg in cur_snp (p_fecha,  p_hora,  p_cod_usuario, p_nro_referencia ) loop

      --Reversión de la operación
      g_lugar := 'Intentando reversar la operación ';
        v_concepto:='RV'||p_ref_externa;


	    prs_snp_obt_usu_hor_movimiento(user,'S',v_usu_reversion,v_hor_reversion);
      prg_rev_operacion( rg.fecha,
                         rg.hora,
                         rg.cod_usuario,
                         pas_snp.fu_obt_cod_mod_padre,
                         pas_snp.fu_obt_cod_mad_padre,
                         pas_snp.fu_obt_cod_tra_padre,
                         v_usu_reversion,
                         v_hor_reversion,
                         'N',
                         v_concepto,
                         null,
                         null,
                         rg.nro_documento--TRFS-1121
                       );

   end loop;

EXCEPTION
  when ex_salir then
     pas_spi.g_cod_error := 51;
     pas_spi.g_msj_error := g_lugar || ' - ' || pas_spi.fu_obt_msj_error;
     raise_application_error(-20000, 'Error en pr_rev_ope_spi, ' || pas_spi.fu_obt_msj_error);
  when no_data_found then
     pas_spi.g_cod_error := 51;
     pas_spi.g_msj_error := g_lugar || ' - ' || 'No se han encontrados datos para la Reversión';
     raise_application_error(-20001, 'Error en pr_rev_ope_spi, ' || pas_spi.fu_obt_msj_error);
  when others then
     pas_spi.g_cod_error := 51;
     pas_spi.g_msj_error := g_lugar || ' - ' || sqlerrm;
     raise_application_error(-20002, 'Error en pr_rev_ope_spi, ' || pas_spi.fu_obt_msj_error);
END pr_rev_ope_spi;
end PAS_SPI;
/

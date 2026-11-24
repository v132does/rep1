CREATE OR REPLACE PACKAGE BODY IT.PAW_BCP IS

PROCEDURE LP_INS_LOG_ERROR (p_parametros IN VARCHAR2 DEFAULT NULL) IS
   PRAGMA AUTONOMOUS_TRANSACTION;   
BEGIN
   INSERT INTO ge_bcp_dat_log (cod_error, error, lugar, parametro)
   VALUES (g_cod_error, g_error, g_lugar, p_parametros);
  
   COMMIT;
EXCEPTION
   WHEN others THEN
      RAISE_APPLICATION_ERROR(-20000, SQLERRM);
END;

PROCEDURE PR_INS_BCP_DAT_PER (RP_CAB IN GE_BCP_DAT_PERSONALES%ROWTYPE) IS
BEGIN
   INSERT INTO ge_bcp_dat_personales 
   VALUES rp_cab;
EXCEPTION
   WHEN others THEN
      g_cod_error := 102;
      g_error     := sqlerrm;
      g_lugar     := 'Al insertar en ge_bcp_dat_personales';
      LP_INS_LOG_ERROR('Cod. Persona: '||g_cod_persona);
END;

PROCEDURE PR_INS_BCP_DAT_PER_DET (RP_DET IN GE_BCP_DAT_PERSONALES_DET%ROWTYPE) IS 
BEGIN
   INSERT INTO ge_bcp_dat_personales_det 
   VALUES rp_det;
EXCEPTION
   WHEN others THEN
      g_cod_error := 103;
      g_error     := sqlerrm;
      g_lugar     := 'Al insertar en ge_bcp_dat_personales_det';
      LP_INS_LOG_ERROR('Cod. Persona: '||g_cod_persona);
END;

FUNCTION FU_OBT_PAR_BCP_SERVICIOS (P_COD_SERVICIO IN NUMBER,
                                   P_TIPO         IN VARCHAR2) RETURN VARCHAR2 IS
   v_nom_servicio VARCHAR2(50);
   v_par_envio    VARCHAR2(50);                             
BEGIN
   SELECT a.abreviatura, a.val_maximo
     INTO v_nom_servicio, v_par_envio
     FROM ba_cod_referencias a
    WHERE a.dominio = 'PAR_WSI_BCP_SERVICIOS'
      AND a.val_minimo = p_cod_servicio;
   IF P_TIPO = 'N' THEN
      RETURN v_nom_servicio;
   ELSIF P_TIPO = 'P' THEN
      RETURN v_par_envio;
   ELSE 
      RETURN null;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN null;
END;
   
-- Procedimiento que invoca a todos los servicios
PROCEDURE PR_PRO_EJE_SERVICIOS (P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_PERIODO      IN VARCHAR2,
                                P_COD_SERVICIO IN NUMBER,
                                P_ERROR       OUT VARCHAR2) IS
   v_nro_doc_cli       ba_personas.nro_documento%type := null;
   v_tip_doc_cli_abr   ba_tip_documentos.abreviatura%type := null;
   
   v_guion             NUMBER(2);
   v_dig_verificador   NUMBER(2);
   v_parametros        VARCHAR2(3000);
   v_wsi_metodo        VARCHAR2(50)  := fu_obt_par_bcp_servicios(p_cod_servicio, 'P');
   v_url               VARCHAR2(100) := g_bcp_webservice || v_wsi_metodo;
   v_resPost           TYP_POSTRESPUESTA;
   v_ws_respuesta      paw_json.JSONStructObj;
   v_des_retorno       VARCHAR2(4500);
   v_error             VARCHAR2(500) := null;
   
BEGIN
   g_lugar := 'Inicia PR_PRO_EST_DEU_AFE_DIA';
   BEGIN
      SELECT nro_documento, decode(fue_obt_tip_doc_abreviatura(cod_tip_documento), 'DNI', 'CRC', 'PAS', 'CRC', 'SW', 'CRC', 'OTR', 'CRC', 'PJ', 'CRC',
                   fue_obt_tip_doc_abreviatura(cod_tip_documento)) 
        INTO v_nro_doc_cli, v_tip_doc_cli_abr
        FROM ba_personas
       WHERE cod_persona = p_cod_persona;
   EXCEPTION
      WHEN others THEN
         v_nro_doc_cli     := null;
         v_tip_doc_cli_abr := null;
   END;
   IF v_tip_doc_cli_abr not in ('RUC', 'CI', 'CRC', 'CRP') THEN
      v_tip_doc_cli_abr := null;
   END IF;
   IF v_tip_doc_cli_abr='RUC' THEN
      v_guion:= instr(v_nro_doc_cli,'-');
      IF v_guion = 0 THEN
         v_dig_verificador:= fue_obt_dig_verificador(v_nro_doc_cli);
         v_nro_doc_cli:= v_nro_doc_cli||'-'||v_dig_verificador;
      END IF;
   END IF;  
   
   IF v_tip_doc_cli_abr is not null AND v_nro_doc_cli is not null THEN
      IF p_periodo is null THEN
         v_parametros := utl_lms.format_message('codTipoDocumento=%s&numeroDocumento=%s', utl_url.escape(v_tip_doc_cli_abr), utl_url.escape(v_nro_doc_cli));
      ELSE
         v_parametros := utl_lms.format_message('codTipoDocumento=%s&numeroDocumento=%s&periodo=%s', utl_url.escape(v_tip_doc_cli_abr), utl_url.escape(v_nro_doc_cli), utl_url.escape(p_periodo));
      END IF;         
      g_lugar := 'Llamar al servicio - PR_PRO_EJE_SERVICIOS';
      v_resPost := fue_env_post(p_parametros => v_parametros, p_url => v_url);
      
      IF v_resPost.error != 'N' THEN
         g_cod_error := v_resPost.codigoError;
         g_error     := 'Error: '||substr(v_resPost.respuesta, 1, 2000);
         g_lugar     := 'Error en el servicio. ';
         lp_ins_log_error(v_parametros);
         v_error     := 'Error al consultar servicio de BCP';
      ELSE
        v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
        v_des_retorno:= paw_json.getAttrValue(v_ws_respuesta, 'status');
      END IF;
      
      IF nvl(v_des_retorno, 'X') <> '200' THEN
         g_cod_error := 104;
         g_error     := 'Error: '||substr(v_resPost.respuesta, 1, 2000);
         g_lugar     := 'Error en el servicio - CORE. ';
         lp_ins_log_error('Cod. Persona: '||p_cod_persona);
         v_error     := 'Error al procesar servicio de BCP';
      END IF;
   ELSE
      g_cod_error := 101;
      g_error     := 'Tipo o Nro de Documentos no pueden ser nulos.';
      g_lugar     := 'En FU_PRO_BCP_WEBSERVICE';
      LP_INS_LOG_ERROR('Cod. Persona: '||p_cod_persona);
      v_error     := 'Tipo o Nro de Documentos no pueden ser nulos.';
   END IF;
   IF v_error is not null THEN
      p_error := v_error;
   ELSE
      p_error := 'Procesado correctamente';
      BEGIN
         UPDATE ge_bcp_dat_personales
            SET cod_usuario = user
          WHERE nro_solicitud = (SELECT max(nro_solicitud)
                                FROM ge_bcp_dat_personales
                               WHERE cod_persona = p_cod_persona
                                 AND tip_servicio = fu_obt_par_bcp_servicios(p_cod_servicio, 'N'));
      EXCEPTION
         WHEN others THEN
            g_cod_error := 130;
            g_error     := 'Error: '||sqlerrm;
            g_lugar     := 'Al actualizar cod_usuario';
            LP_INS_LOG_ERROR('Cod. Persona: '||p_cod_persona);
      END;
   END IF;
   COMMIT;
END PR_PRO_EJE_SERVICIOS;


-- 1.7.1 Consulta Consolidada Por Persona.
FUNCTION FU_PRO_CON_CONSOLIDADA (P_TIP_DOC_CLI     IN VARCHAR2,
                                 P_NRO_DOC_CLI     IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_CON_CONSOLIDADO IN TYP_LISTA_CONSOLIDADO) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 1; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   v_lis_detalle    TYP_LISTA_CONSOLIDADO;
   v_detalle        TYP_CONSOLIDADO;
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_lis_detalle   := p_con_consolidado;
      FOR i IN 1 .. v_lis_detalle.count LOOP
         rg_cab         := NULL;
         v_detalle      := v_lis_detalle(i);
         v_nro_registro := v_nro_registro+1;
         
         rg_cab.fec_calendario    := g_fec_actual;
         rg_cab.cod_persona       := v_cod_persona;
         rg_cab.nro_solicitud     := v_nro_solicitud;
         rg_cab.tip_servicio      := v_tip_servicio;
         rg_cab.nro_registro      := v_nro_registro;
         rg_cab.cod_resultado     := v_detalle.codigoResultado;
         rg_cab.des_resultado     := v_detalle.descripcionResultado;
         IF TRIM(v_detalle.periodo) is not null THEN
            rg_cab.periodo        := ltrim(substr(v_detalle.periodo,7,2)||'/'||substr(v_detalle.periodo,5,2)||'/'||substr(v_detalle.periodo,1,4),'/');
         END IF;
         rg_cab.cod_tip_documento := v_detalle.codTipoDocumento;
         rg_cab.nro_documento     := v_detalle.numeroDocumento;
         rg_cab.nro_gvp           := v_detalle.nroGpv;
         rg_cab.nombre            := v_detalle.nombres;
         rg_cab.apellido          := v_detalle.apellidos;
         IF TRIM(v_detalle.fechaNacimiento) is not null THEN
            rg_cab.fec_nacimiento := substr(v_detalle.fechaNacimiento,7,2)||'/'||substr(v_detalle.fechaNacimiento,5,2)||'/'||substr(v_detalle.fechaNacimiento,1,4);
         END IF;
         rg_cab.tip_vinculo       := v_detalle.tipoVinculo;
         rg_cab.tip_operacion     := v_detalle.tipoOperacion;
         rg_cab.des_operacion     := v_detalle.desOperacion;
         rg_cab.cod_cta_contable  := v_detalle.codCuentaSaldoCapital;
         rg_cab.cod_act_destino   := v_detalle.codActividadDestino;
         rg_cab.region            := v_detalle.region;
         rg_cab.cod_moneda        := v_detalle.codigoMoneda;
         rg_cab.dia_atraso        := v_detalle.diasAtraso;
         rg_cab.mto_deu_activa    := v_detalle.deudaActiva;
         rg_cab.mto_deu_vendida   := v_detalle.deudaVendida;
         rg_cab.mto_deu_incobrable:= v_detalle.deudaIncobrable;
         rg_cab.mto_deu_fideicomiso:= v_detalle.deudaFideicomiso;
         rg_cab.mto_contingencia  := v_detalle.montoContingencia;
         rg_cab.mto_prevision     := v_detalle.montoPrevision;
         rg_cab.cla_sistema       := v_detalle.clasificacionSistema;
         rg_cab.usu_insercion     := substr(USER,1,10);
         rg_cab.fec_insercion     := SYSDATE;
         rg_cab.usu_modificacion  := substr(USER,1,10);
         rg_cab.fec_modificacion  := SYSDATE;
         PR_INS_BCP_DAT_PER(rg_cab);
      END LOOP;
      RETURN 'S';
   ELSE
      g_cod_error := 107;
      g_error     := 'Cod. Persona NULO';
      g_lugar     := 'Iniciar FU_PRO_CON_CONSOLIDADA';
      LP_INS_LOG_ERROR('Nro. Doc.: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 112;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_CON_CONSOLIDADA';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.2 Estado Deuda Afectado Diario Por Persona  
FUNCTION FU_PRO_EST_DEU_AFE_DIA (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_DEU_AFE_DIARIO IN TYP_LISTA_AFECTADO_DIARIO_DET) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 2; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   v_lis_detalle    TYP_LISTA_AFECTADO_DIARIO_DET;
   v_detalle        TYP_AFECTADO_DIARIO_DETALLE;
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   rg_det           ge_bcp_dat_personales_det%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
   v_nro_secuencia  number(3);
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      rg_cab          := NULL;
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_nro_registro  := v_nro_registro+1;
      
      rg_cab.fec_calendario    := g_fec_actual;
      rg_cab.cod_persona       := v_cod_persona;
      rg_cab.nro_solicitud     := v_nro_solicitud;
      rg_cab.tip_servicio      := v_tip_servicio;
      rg_cab.nro_registro      := v_nro_registro;
      rg_cab.cod_resultado     := p_cod_resultado;
      rg_cab.des_resultado     := p_des_resultado;
      rg_cab.cod_tip_documento := p_cod_tip_documento;
      rg_cab.nro_documento     := p_nro_documento;
      rg_cab.nombre            := p_nombre;
      rg_cab.apellido          := p_apellido;
      IF TRIM(p_fec_nacimiento) is not null THEN
         rg_cab.fec_nacimiento := to_char(substr(p_fec_nacimiento,7,2)||'/'||substr(p_fec_nacimiento,5,2)||'/'||substr(p_fec_nacimiento,1,4));
      END IF;
      rg_cab.cod_pais          := p_cod_pais;
      rg_cab.des_pais          := p_des_pais;
      rg_cab.tip_persona       := p_tip_persona;
      IF TRIM(p_fec_baja) is not null THEN
         rg_cab.fec_baja       := to_char(substr(p_fec_baja,7,2)||'/'||substr(p_fec_baja,5,2)||'/'||substr(p_fec_baja,1,4));
      END IF;
      rg_cab.nro_gvp           := p_nro_gvp;
      rg_cab.usu_insercion     := substr(USER,1,10);
      rg_cab.fec_insercion     := SYSDATE;
      rg_cab.usu_modificacion  := substr(USER,1,10);
      rg_cab.fec_modificacion  := SYSDATE;
      PR_INS_BCP_DAT_PER(rg_cab);
      
      v_lis_detalle   := p_deu_afe_diario;
      v_nro_secuencia := 0;
      FOR i in 1 .. v_lis_detalle.count LOOP
         rg_det     	   := NULL;
         v_detalle       := v_lis_detalle(i);
         v_nro_secuencia := v_nro_secuencia + 1;
         
         rg_det.nro_solicitud       := v_nro_solicitud;
         rg_det.nro_registro        := v_nro_registro;
         rg_det.nro_secuencia       := v_nro_secuencia;
         rg_det.cod_entidad         := v_detalle.codEntidad;
         rg_det.des_entidad         := v_detalle.desEntidad;
         rg_det.mto_deuda           := v_detalle.deuda;
         IF TRIM(v_detalle.periodo) is not null THEN
            rg_det.periodo          := ltrim(substr(v_detalle.periodo,7,2)||'/'||substr(v_detalle.periodo,5,2)||'/'||substr(v_detalle.periodo,1,4),'/');
         END IF;
         rg_det.cla_sistema         := NULL;
         rg_det.mto_codeudoria      := to_number(v_detalle.codeudoria);
         rg_det.mto_contingencia    := to_number(v_detalle.contingencia);
         rg_det.mto_deu_fideicomiso := to_number(v_detalle.deudaFideicomiso);
         rg_det.mto_deu_vendida     := to_number(v_detalle.deudaVendida);
         rg_det.cod_moneda          := NULL;
         rg_det.tip_operacion       := NULL;
         rg_det.cla_entidad         := v_detalle.clasificacionEntidad;
         rg_det.comprador           := NULL;
         rg_det.fideicomitente      := NULL;
         rg_det.usu_insercion       := substr(USER,1,10);
         rg_det.fec_insercion       := SYSDATE;
         rg_det.usu_modificacion    := substr(USER,1,10);
         rg_det.fec_modificacion    := SYSDATE;
         PR_INS_BCP_DAT_PER_DET(rg_det);
      END LOOP;
      RETURN 'S';
   ELSE
      g_cod_error := 106;
      g_error     := 'Cód. Persona NULO';
      g_lugar     := 'En FU_PRO_EST_DEU_AFE_DIA';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 113;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_EST_DEU_AFE_DIA';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.3 Inhabilitación de Cuentas Corrientes Por Persona
FUNCTION FU_PRO_INH_CTA_CTE (P_TIP_DOC_CLI    IN VARCHAR2,
                             P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                             P_INHABILITACION IN TYP_LISTA_INHABILITACION) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 3; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   v_lis_detalle    TYP_LISTA_INHABILITACION;
   v_detalle        TYP_INHABILITACION;
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_lis_detalle   := p_inhabilitacion;
      FOR i IN 1 .. v_lis_detalle.count LOOP
         rg_cab         := NULL;
         v_detalle      := v_lis_detalle(i);
         v_nro_registro := v_nro_registro+1;
         
         rg_cab.fec_calendario    := g_fec_actual;
         rg_cab.cod_persona       := v_cod_persona;
         rg_cab.nro_solicitud     := v_nro_solicitud;
         rg_cab.tip_servicio      := v_tip_servicio;
         rg_cab.nro_registro      := v_nro_registro;
         rg_cab.cod_resultado     := v_detalle.codigoResultado;
         rg_cab.des_resultado     := v_detalle.descripcionResultado;
         rg_cab.tip_inhabilitacion:= v_detalle.tipo;
         rg_cab.nro_circular      := v_detalle.nroCircular;
         IF TRIM(v_detalle.fechaCircular) is not null THEN
            rg_cab.fec_circular   := substr(v_detalle.fechaCircular,7,2)||'/'||substr(v_detalle.fechaCircular,5,2)||'/'||substr(v_detalle.fechaCircular,1,4);
         END IF;
         rg_cab.cod_entidad       := v_detalle.codEntidad;
         rg_cab.des_entidad       := v_detalle.desEntidad;
         rg_cab.causa             := v_detalle.causal;
         rg_cab.observacion       := v_detalle.observacion;
         rg_cab.cod_tip_documento := v_detalle.codTipoDocumento;
         rg_cab.nro_documento     := v_detalle.numeroDocumento;
         IF TRIM(v_detalle.fechaInhabilitacion) is not null THEN
            rg_cab.fec_inhabilitacion := substr(v_detalle.fechaInhabilitacion,7,2)||'/'||substr(v_detalle.fechaInhabilitacion,5,2)||'/'||substr(v_detalle.fechaInhabilitacion,1,4);
         END IF;
         IF TRIM(v_detalle.fechaFin) is not null THEN
            rg_cab.fec_fin        := substr(v_detalle.fechaFin,7,2)||'/'||substr(v_detalle.fechaFin,5,2)||'/'||substr(v_detalle.fechaFin,1,4);
         END IF;
         rg_cab.nro_cir_inhabilitacion := v_detalle.inhabCircularNro;
         rg_cab.nombre            := v_detalle.nombres;
         rg_cab.apellido          := v_detalle.apellidos;
         
         rg_cab.usu_insercion     := substr(USER,1,10);
         rg_cab.fec_insercion     := SYSDATE;
         rg_cab.usu_modificacion  := substr(USER,1,10);
         rg_cab.fec_modificacion  := SYSDATE;
         PR_INS_BCP_DAT_PER(rg_cab);
      END LOOP;
      RETURN 'S';
   ELSE
      g_cod_error := 107;
      g_error     := 'Cod. Persona NULO';
      g_lugar     := 'Iniciar FU_PRO_INH_CTA_CTE';
      LP_INS_LOG_ERROR('Nro. Doc.: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 112;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_INH_CTA_CTE';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.4 Estado de Deuda Mensual Por Persona
FUNCTION FU_PRO_EST_DEU_MENSUAL (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_PERIODO        IN GE_BCP_DAT_PERSONALES.PERIODO%TYPE,
                                 P_CLA_SISTEMA    IN GE_BCP_DAT_PERSONALES.CLA_SISTEMA%TYPE,
                                 P_MTO_DEUDA      IN GE_BCP_DAT_PERSONALES.MTO_DEUDA%TYPE,
                                 P_MTO_CONTINGENCIA IN GE_BCP_DAT_PERSONALES.MTO_CONTINGENCIA%TYPE,
                                 P_MTO_EMI_CODEUD IN GE_BCP_DAT_PERSONALES.MTO_EMI_CODEUDORIA%TYPE,
                                 P_MTO_TOT_RIESGO IN GE_BCP_DAT_PERSONALES.MTO_TOT_RIESGO%TYPE) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 4; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      rg_cab          := NULL;
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_nro_registro  := v_nro_registro+1;
      
      rg_cab.fec_calendario    := g_fec_actual;
      rg_cab.cod_persona       := v_cod_persona;
      rg_cab.nro_solicitud     := v_nro_solicitud;
      rg_cab.tip_servicio      := v_tip_servicio;
      rg_cab.nro_registro      := v_nro_registro;
      rg_cab.cod_resultado     := p_cod_resultado;
      rg_cab.des_resultado     := p_des_resultado;
      rg_cab.cod_tip_documento := p_cod_tip_documento;
      rg_cab.nro_documento     := p_nro_documento;
      rg_cab.nombre            := p_nombre;
      rg_cab.apellido          := p_apellido;
      IF TRIM(p_fec_nacimiento) is not null THEN
         rg_cab.fec_nacimiento := substr(p_fec_nacimiento,7,2)||'/'||substr(p_fec_nacimiento,5,2)||'/'||substr(p_fec_nacimiento,1,4);
      END IF;
      rg_cab.cod_pais          := p_cod_pais;
      rg_cab.des_pais          := p_des_pais;
      rg_cab.tip_persona       := p_tip_persona;
      IF TRIM(p_fec_baja) is not null THEN
         rg_cab.fec_baja       := substr(p_fec_baja,7,2)||'/'||substr(p_fec_baja,5,2)||'/'||substr(p_fec_baja,1,4);
      END IF;
      rg_cab.nro_gvp           := p_nro_gvp;
      IF trim(p_periodo) is not null THEN
         rg_cab.periodo        := ltrim(substr(p_periodo,7,2)||'/'||substr(p_periodo,5,2)||'/'||substr(p_periodo,1,4),'/');
      END IF;
      rg_cab.cla_sistema       := p_cla_sistema;
      rg_cab.mto_deuda         := p_mto_deuda;
      rg_cab.mto_contingencia  := p_mto_contingencia;
      rg_cab.mto_emi_codeudoria:= p_mto_emi_codeud;
      rg_cab.mto_tot_riesgo    := p_mto_tot_riesgo;
      rg_cab.usu_insercion     := substr(USER,1,10);
      rg_cab.fec_insercion     := SYSDATE;
      rg_cab.usu_modificacion  := substr(USER,1,10);
      rg_cab.fec_modificacion  := SYSDATE;
      PR_INS_BCP_DAT_PER(rg_cab);
      RETURN 'S';
   ELSE
      g_cod_error := 110;
      g_error     := 'Cód. Persona NULO';
      g_lugar     := 'En FU_PRO_EST_DEU_MENSUAL';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 111;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_EST_DEU_MENSUAL';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.5 Operaciones Cartera Vendida Por Persona
FUNCTION FU_PRO_OPE_CAR_VENDIDA (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_CAR_VENDIDA_DET IN TYP_LISTA_CARTERA_VENDIDA_DET) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 5; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   v_lis_detalle    TYP_LISTA_CARTERA_VENDIDA_DET;
   v_detalle        TYP_CARTERA_VENDIDA_DETALLE;
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   rg_det           ge_bcp_dat_personales_det%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
   v_nro_secuencia  number(3);
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      rg_cab          := NULL;
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_nro_registro  := v_nro_registro+1;
      
      rg_cab.fec_calendario    := g_fec_actual;
      rg_cab.cod_persona       := v_cod_persona;
      rg_cab.nro_solicitud     := v_nro_solicitud;
      rg_cab.tip_servicio      := v_tip_servicio;
      rg_cab.nro_registro      := v_nro_registro;
      rg_cab.cod_resultado     := p_cod_resultado;
      rg_cab.des_resultado     := p_des_resultado;
      rg_cab.cod_tip_documento := p_cod_tip_documento;
      rg_cab.nro_documento     := p_nro_documento;
      rg_cab.nombre            := p_nombre;
      rg_cab.apellido          := p_apellido;
      IF TRIM(p_fec_nacimiento) is not null THEN
         rg_cab.fec_nacimiento := substr(p_fec_nacimiento,7,2)||'/'||substr(p_fec_nacimiento,5,2)||'/'||substr(p_fec_nacimiento,1,4);
      END IF;
      rg_cab.cod_pais          := p_cod_pais;
      rg_cab.des_pais          := p_des_pais;
      rg_cab.tip_persona       := p_tip_persona;
      IF TRIM(p_fec_baja) is not null THEN
         rg_cab.fec_baja       := substr(p_fec_baja,7,2)||'/'||substr(p_fec_baja,5,2)||'/'||substr(p_fec_baja,1,4);
      END IF;
      rg_cab.nro_gvp           := p_nro_gvp;
      rg_cab.usu_insercion     := substr(USER,1,10);
      rg_cab.fec_insercion     := SYSDATE;
      rg_cab.usu_modificacion  := substr(USER,1,10);
      rg_cab.fec_modificacion  := SYSDATE;
      PR_INS_BCP_DAT_PER(rg_cab);
      
      v_lis_detalle   := p_car_vendida_det;
      v_nro_secuencia := 0;
      FOR i in 1 .. v_lis_detalle.count LOOP
         rg_det     	   := NULL;
         v_detalle       := v_lis_detalle(i);
         v_nro_secuencia := v_nro_secuencia + 1;
         
         rg_det.nro_solicitud       := v_nro_solicitud;
         rg_det.nro_registro        := v_nro_registro;
         rg_det.nro_secuencia       := v_nro_secuencia;
         rg_det.cod_entidad         := v_detalle.codEntidad;
         rg_det.des_entidad         := v_detalle.desEntidad;
         IF TRIM(v_detalle.periodo) is not null THEN
            rg_det.periodo          := ltrim(substr(v_detalle.periodo,7,2)||'/'||substr(v_detalle.periodo,5,2)||'/'||substr(v_detalle.periodo,1,4),'/');
         END IF;
         rg_det.cod_moneda          := v_detalle.moneda;
         rg_det.des_operacion       := v_detalle.desOperacion;
         rg_det.mto_deuda           := v_detalle.deuda;
         rg_det.cla_entidad         := v_detalle.clasificacionSistema;
         rg_det.comprador           := v_detalle.comprador;
         
         rg_det.usu_insercion       := substr(USER,1,10);
         rg_det.fec_insercion       := SYSDATE;
         rg_det.usu_modificacion    := substr(USER,1,10);
         rg_det.fec_modificacion    := SYSDATE;
         PR_INS_BCP_DAT_PER_DET(rg_det);
      END LOOP;
      RETURN 'S';
   ELSE
      g_cod_error := 115;
      g_error     := 'Cód. Persona NULO';
      g_lugar     := 'En FU_PRO_OPE_CAR_VENDIDA';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 116;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_OPE_CAR_VENDIDA';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.6 Operaciones de Fideicomiso Por Persona
FUNCTION FU_PRO_OPE_FIDEICOMISO (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_FIDEICOMISO_DET IN TYP_LISTA_FIDEICOMISO_DET) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 6; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   v_lis_detalle    TYP_LISTA_FIDEICOMISO_DET;
   v_detalle        TYP_FIDEICOMISO_DETALLE;
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   rg_det           ge_bcp_dat_personales_det%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
   v_nro_secuencia  number(3);
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      rg_cab          := NULL;
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_nro_registro  := v_nro_registro+1;
      
      rg_cab.fec_calendario    := g_fec_actual;
      rg_cab.cod_persona       := v_cod_persona;
      rg_cab.nro_solicitud     := v_nro_solicitud;
      rg_cab.tip_servicio      := v_tip_servicio;
      rg_cab.nro_registro      := v_nro_registro;
      rg_cab.cod_resultado     := p_cod_resultado;
      rg_cab.des_resultado     := p_des_resultado;
      rg_cab.cod_tip_documento := p_cod_tip_documento;
      rg_cab.nro_documento     := p_nro_documento;
      rg_cab.nombre            := p_nombre;
      rg_cab.apellido          := p_apellido;
      IF TRIM(p_fec_nacimiento) is not null THEN
         rg_cab.fec_nacimiento := substr(p_fec_nacimiento,7,2)||'/'||substr(p_fec_nacimiento,5,2)||'/'||substr(p_fec_nacimiento,1,4);
      END IF;
      rg_cab.cod_pais          := p_cod_pais;
      rg_cab.des_pais          := p_des_pais;
      rg_cab.tip_persona       := p_tip_persona;
      IF TRIM(p_fec_baja) is not null THEN
         rg_cab.fec_baja       := substr(p_fec_baja,7,2)||'/'||substr(p_fec_baja,5,2)||'/'||substr(p_fec_baja,1,4);
      END IF;
      rg_cab.nro_gvp           := p_nro_gvp;
      rg_cab.usu_insercion     := substr(USER,1,10);
      rg_cab.fec_insercion     := SYSDATE;
      rg_cab.usu_modificacion  := substr(USER,1,10);
      rg_cab.fec_modificacion  := SYSDATE;
      PR_INS_BCP_DAT_PER(rg_cab);
      
      v_lis_detalle   := p_fideicomiso_det;
      v_nro_secuencia := 0;
      FOR i in 1 .. v_lis_detalle.count LOOP
         rg_det     	   := NULL;
         v_detalle       := v_lis_detalle(i);
         v_nro_secuencia := v_nro_secuencia + 1;
         
         rg_det.nro_solicitud       := v_nro_solicitud;
         rg_det.nro_registro        := v_nro_registro;
         rg_det.nro_secuencia       := v_nro_secuencia;
         rg_det.cod_entidad         := v_detalle.codEntidad;
         rg_det.des_entidad         := v_detalle.desEntidad;
         IF TRIM(v_detalle.periodo) is not null THEN
            rg_det.periodo          := ltrim(substr(v_detalle.periodo,7,2)||'/'||substr(v_detalle.periodo,5,2)||'/'||substr(v_detalle.periodo,1,4),'/');
         END IF;
         rg_det.cod_moneda          := v_detalle.moneda;
         rg_det.des_operacion       := v_detalle.desOperacion;
         rg_det.mto_deuda           := v_detalle.deuda;
         rg_det.cla_sistema         := v_detalle.clasificacionSistema;
         rg_det.fideicomitente      := v_detalle.fideicomitente;
         
         rg_det.usu_insercion       := substr(USER,1,10);
         rg_det.fec_insercion       := SYSDATE;
         rg_det.usu_modificacion    := substr(USER,1,10);
         rg_det.fec_modificacion    := SYSDATE;
         PR_INS_BCP_DAT_PER_DET(rg_det);
      END LOOP;
      RETURN 'S';
   ELSE
      g_cod_error := 117;
      g_error     := 'Cód. Persona NULO';
      g_lugar     := 'En FU_PRO_OPE_FIDEICOMISO';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 118;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_OPE_FIDEICOMISO';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.7 Estado de Deuda Diario Por Persona
FUNCTION FU_PRO_EST_DEU_DIARIO  (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_PERIODO        IN GE_BCP_DAT_PERSONALES.PERIODO%TYPE,
                                 P_CLA_SISTEMA    IN GE_BCP_DAT_PERSONALES.CLA_SISTEMA%TYPE,
                                 P_MTO_DEUDA      IN GE_BCP_DAT_PERSONALES.MTO_DEUDA%TYPE,
                                 P_MTO_CODEUDORIA IN GE_BCP_DAT_PERSONALES.MTO_CODEUDORIA%TYPE,
                                 P_MTO_CONTINGENCIA  IN GE_BCP_DAT_PERSONALES.MTO_CONTINGENCIA%TYPE,
                                 P_MTO_TOT_RIESGO IN GE_BCP_DAT_PERSONALES.MTO_TOT_RIESGO%TYPE,
                                 P_CAN_ENTIDAD    IN GE_BCP_DAT_PERSONALES.CAN_ENTIDAD%TYPE) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 7; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      rg_cab          := NULL;
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_nro_registro  := v_nro_registro+1;
      
      rg_cab.fec_calendario    := g_fec_actual;
      rg_cab.cod_persona       := v_cod_persona;
      rg_cab.nro_solicitud     := v_nro_solicitud;
      rg_cab.tip_servicio      := v_tip_servicio;
      rg_cab.nro_registro      := v_nro_registro;
      rg_cab.cod_resultado     := p_cod_resultado;
      rg_cab.des_resultado     := p_des_resultado;
      rg_cab.cod_tip_documento := p_cod_tip_documento;
      rg_cab.nro_documento     := p_nro_documento;
      rg_cab.nombre            := p_nombre;
      rg_cab.apellido          := p_apellido;
      IF TRIM(p_fec_nacimiento) is not null THEN
         rg_cab.fec_nacimiento := substr(p_fec_nacimiento,7,2)||'/'||substr(p_fec_nacimiento,5,2)||'/'||substr(p_fec_nacimiento,1,4);
      END IF;
      rg_cab.cod_pais          := p_cod_pais;
      rg_cab.des_pais          := p_des_pais;
      rg_cab.tip_persona       := p_tip_persona;
      IF TRIM(p_fec_baja) is not null THEN
         rg_cab.fec_baja       := substr(p_fec_baja,7,2)||'/'||substr(p_fec_baja,5,2)||'/'||substr(p_fec_baja,1,4);
      END IF;
      rg_cab.nro_gvp           := p_nro_gvp;
      IF trim(p_periodo) is not null THEN
         rg_cab.periodo        := ltrim(substr(p_periodo,7,2)||'/'||substr(p_periodo,5,2)||'/'||substr(p_periodo,1,4),'/');
      END IF;
      rg_cab.cla_sistema       := p_cla_sistema;
      rg_cab.mto_deuda         := p_mto_deuda;
      rg_cab.mto_codeudoria    := p_mto_codeudoria;
      rg_cab.mto_contingencia  := p_mto_contingencia;
      rg_cab.mto_tot_riesgo    := p_mto_tot_riesgo;
      rg_cab.can_entidad       := p_can_entidad;
      rg_cab.usu_insercion     := substr(USER,1,10);
      rg_cab.fec_insercion     := SYSDATE;
      rg_cab.usu_modificacion  := substr(USER,1,10);
      rg_cab.fec_modificacion  := SYSDATE;
      PR_INS_BCP_DAT_PER(rg_cab);
      RETURN 'S';
   ELSE
      g_cod_error := 110;
      g_error     := 'Cód. Persona NULO';
      g_lugar     := 'En FU_PRO_EST_DEU_DIARIO';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 111;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_EST_DEU_DIARIO';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.8 Estado Deuda Afectado Mensual Por Persona  
FUNCTION FU_PRO_EST_DEU_AFE_MEN (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2,
                                 P_NRO_GVP        IN GE_BCP_DAT_PERSONALES.NRO_GVP%TYPE,
                                 P_DEU_AFE_MENSUAL IN TYP_LISTA_AFECTADO_MENSUAL_DET) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 8; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   v_lis_detalle    TYP_LISTA_AFECTADO_MENSUAL_DET;
   v_detalle        TYP_AFECTADO_MENSUAL_DETALLE;
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   rg_det           ge_bcp_dat_personales_det%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
   v_nro_secuencia  number(3);
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      rg_cab          := NULL;
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_nro_registro  := v_nro_registro+1;
      
      rg_cab.fec_calendario    := g_fec_actual;
      rg_cab.cod_persona       := v_cod_persona;
      rg_cab.nro_solicitud     := v_nro_solicitud;
      rg_cab.tip_servicio      := v_tip_servicio;
      rg_cab.nro_registro      := v_nro_registro;
      rg_cab.cod_resultado     := p_cod_resultado;
      rg_cab.des_resultado     := p_des_resultado;
      rg_cab.cod_tip_documento := p_cod_tip_documento;
      rg_cab.nro_documento     := p_nro_documento;
      rg_cab.nombre            := p_nombre;
      rg_cab.apellido          := p_apellido;
      IF TRIM(p_fec_nacimiento) is not null THEN
         rg_cab.fec_nacimiento := substr(p_fec_nacimiento,7,2)||'/'||substr(p_fec_nacimiento,5,2)||'/'||substr(p_fec_nacimiento,1,4);
      END IF;
      rg_cab.cod_pais          := p_cod_pais;
      rg_cab.des_pais          := p_des_pais;
      rg_cab.tip_persona       := p_tip_persona;
      IF TRIM(p_fec_baja) is not null THEN
         rg_cab.fec_baja       := substr(p_fec_baja,7,2)||'/'||substr(p_fec_baja,5,2)||'/'||substr(p_fec_baja,1,4);
      END IF;
      rg_cab.nro_gvp           := p_nro_gvp;
      rg_cab.usu_insercion     := substr(USER,1,10);
      rg_cab.fec_insercion     := SYSDATE;
      rg_cab.usu_modificacion  := substr(USER,1,10);
      rg_cab.fec_modificacion  := SYSDATE;
      PR_INS_BCP_DAT_PER(rg_cab);
      
      v_lis_detalle   := p_deu_afe_mensual;
      v_nro_secuencia := 0;
      FOR i in 1 .. v_lis_detalle.count LOOP
         rg_det     	   := NULL;
         v_detalle       := v_lis_detalle(i);
         v_nro_secuencia := v_nro_secuencia + 1;
         
         rg_det.nro_solicitud       := v_nro_solicitud;
         rg_det.nro_registro        := v_nro_registro;
         rg_det.nro_secuencia       := v_nro_secuencia;
         rg_det.cod_entidad         := v_detalle.codEntidad;
         rg_det.des_entidad         := v_detalle.desEntidad;
         IF TRIM(v_detalle.periodo) is not null THEN
            rg_det.periodo          := ltrim(substr(v_detalle.periodo,7,2)||'/'||substr(v_detalle.periodo,5,2)||'/'||substr(v_detalle.periodo,1,4),'/');
         END IF;
         rg_det.mto_deuda           := v_detalle.deuda;
         rg_det.mto_codeudoria      := v_detalle.codeudoria;
         rg_det.mto_contingencia    := v_detalle.contingencia;
         rg_det.mto_deu_vendida     := v_detalle.deudaVendida;
         rg_det.mto_deu_fideicomiso := v_detalle.deudaFideicomiso;
         rg_det.cla_entidad         := v_detalle.clasificacionEntidad;
         rg_det.usu_insercion       := substr(USER,1,10);
         rg_det.fec_insercion       := SYSDATE;
         rg_det.usu_modificacion    := substr(USER,1,10);
         rg_det.fec_modificacion    := SYSDATE;
         PR_INS_BCP_DAT_PER_DET(rg_det);
      END LOOP;
      RETURN 'S';
   ELSE
      g_cod_error := 119;
      g_error     := 'Cód. Persona NULO';
      g_lugar     := 'En FU_PRO_EST_DEU_AFE_MEN';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 120;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_EST_DEU_AFE_MEN';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;

-- 1.7.9 Datos de Personas
FUNCTION FU_PRO_DAT_PERSONAS    (P_TIP_DOC_CLI    IN VARCHAR2,
                                 P_NRO_DOC_CLI    IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                 P_COD_RESULTADO  IN GE_BCP_DAT_PERSONALES.COD_RESULTADO%TYPE,
                                 P_DES_RESULTADO  IN GE_BCP_DAT_PERSONALES.DES_RESULTADO%TYPE,
                                 P_COD_TIP_DOCUMENTO IN GE_BCP_DAT_PERSONALES.COD_TIP_DOCUMENTO%TYPE,
                                 P_NRO_DOCUMENTO  IN GE_BCP_DAT_PERSONALES.NRO_DOCUMENTO%TYPE,
                                 P_NOMBRE         IN GE_BCP_DAT_PERSONALES.NOMBRE%TYPE,
                                 P_APELLIDO       IN GE_BCP_DAT_PERSONALES.APELLIDO%TYPE,
                                 P_FEC_NACIMIENTO IN VARCHAR2,
                                 P_COD_PAIS       IN GE_BCP_DAT_PERSONALES.COD_PAIS%TYPE,
                                 P_DES_PAIS       IN GE_BCP_DAT_PERSONALES.DES_PAIS%TYPE,
                                 P_GENERO         IN GE_BCP_DAT_PERSONALES.SEXO%TYPE,
                                 P_TIP_PERSONA    IN GE_BCP_DAT_PERSONALES.TIP_PERSONA%TYPE,
                                 P_FEC_BAJA       IN VARCHAR2) RETURN VARCHAR2 IS
   v_cod_servicio   number(2) := 9; -- Referencia="PAR_WSI_BCP_SERVICIOS"
   v_tip_servicio   varchar(50) := fu_obt_par_bcp_servicios(v_cod_servicio, 'N');
   
   rg_cab           ge_bcp_dat_personales%rowtype;
   v_nro_solicitud  ge_bcp_dat_personales.nro_solicitud%type;
   v_cod_persona    ba_personas.cod_persona%type;
   
   v_nro_registro   number(3) := 0;
BEGIN
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   v_cod_persona := fue_obt_cod_persona_doc(fue_obt_tip_documento(p_tip_doc_cli), p_nro_doc_cli);
   IF v_cod_persona is not null THEN  
      rg_cab          := NULL;
      v_nro_solicitud := s_wsi_bcp_nro_solicitud.nextval();
      v_nro_registro  := v_nro_registro+1;
      
      rg_cab.fec_calendario    := g_fec_actual;
      rg_cab.cod_persona       := v_cod_persona;
      rg_cab.nro_solicitud     := v_nro_solicitud;
      rg_cab.tip_servicio      := v_tip_servicio;
      rg_cab.nro_registro      := v_nro_registro;
      rg_cab.cod_resultado     := p_cod_resultado;
      rg_cab.des_resultado     := p_des_resultado;
      rg_cab.cod_tip_documento := p_cod_tip_documento;
      rg_cab.nro_documento     := p_nro_documento;
      rg_cab.nombre            := p_nombre;
      rg_cab.apellido          := p_apellido;
      IF TRIM(p_fec_nacimiento) is not null THEN
         rg_cab.fec_nacimiento := substr(p_fec_nacimiento,7,2)||'/'||substr(p_fec_nacimiento,5,2)||'/'||substr(p_fec_nacimiento,1,4);
      END IF;
      rg_cab.cod_pais          := p_cod_pais;
      rg_cab.des_pais          := p_des_pais;
      rg_cab.sexo              := p_genero;
      rg_cab.tip_persona       := p_tip_persona;
      IF TRIM(p_fec_baja) is not null THEN
         rg_cab.fec_baja       := substr(p_fec_baja,7,2)||'/'||substr(p_fec_baja,5,2)||'/'||substr(p_fec_baja,1,4);
      END IF;
      rg_cab.usu_insercion     := substr(USER,1,10);
      rg_cab.fec_insercion     := SYSDATE;
      rg_cab.usu_modificacion  := substr(USER,1,10);
      rg_cab.fec_modificacion  := SYSDATE;
      PR_INS_BCP_DAT_PER(rg_cab);
      RETURN 'S';
   ELSE
      g_cod_error := 121;
      g_error     := 'Cód. Persona NULO';
      g_lugar     := 'En FU_PRO_DAT_PERSONAS';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
   END IF;
   
EXCEPTION
   WHEN others THEN
      g_cod_error := 122;
      g_error     := 'Error: '||sqlerrm;
      g_lugar     := 'En FU_PRO_DAT_PERSONAS';
      LP_INS_LOG_ERROR('Nro. Doc: '||p_nro_doc_cli);
      RETURN 'N';
END;
-----------------------------
-- Procedimiento Principal --
-----------------------------
FUNCTION FU_PRO_BCP_WEBSERVICE (P_COD_PERSONA  IN BA_PERSONAS.COD_PERSONA%TYPE,
                                P_PERIODO      IN VARCHAR2,
                                P_COD_SERVICIO IN VARCHAR2) RETURN VARCHAR2 IS
   v_error varchar(2000);
BEGIN
   g_lugar       := 'Inicia FU_PRO_BCP_WEBSERVICE';
   g_cod_error   := null;
   g_error       := null;
   g_cod_persona := p_cod_persona;
   
   --
   g_lugar := 'Invocar al PR_PRO_EJE_SERVICIOS. Cod.Ser.: '||P_COD_SERVICIO;
   IF p_cod_servicio = 1 THEN
      IF p_periodo is not null THEN
         PR_PRO_EJE_SERVICIOS(p_cod_persona, p_periodo, p_cod_servicio, v_error);
      ELSE
         v_error := 'Periodo no puede ser nulo para este Servicio';
      END IF;
   ELSIF p_cod_servicio = 2 THEN
      PR_PRO_EJE_SERVICIOS(p_cod_persona, null, p_cod_servicio, v_error);
   ELSIF p_cod_servicio = 3 THEN
      PR_PRO_EJE_SERVICIOS(p_cod_persona, null, p_cod_servicio, v_error);
   ELSIF p_cod_servicio = 4 THEN
      IF p_periodo is not null THEN
         PR_PRO_EJE_SERVICIOS(p_cod_persona, p_periodo, p_cod_servicio, v_error);
      ELSE
         v_error := 'Periodo no puede ser nulo para este Servicio';
      END IF;
   ELSIF p_cod_servicio = 5 THEN
      IF p_periodo is not null THEN
         PR_PRO_EJE_SERVICIOS(p_cod_persona, p_periodo, p_cod_servicio, v_error);
      ELSE
         v_error := 'Periodo no puede ser nulo para este Servicio';
      END IF;
   ELSIF p_cod_servicio = 6 THEN
      IF p_periodo is not null THEN
         PR_PRO_EJE_SERVICIOS(p_cod_persona, p_periodo, p_cod_servicio, v_error);
      ELSE
         v_error := 'Periodo no puede ser nulo para este Servicio';
      END IF;
   ELSIF p_cod_servicio = 7 THEN
      PR_PRO_EJE_SERVICIOS(p_cod_persona, null, p_cod_servicio, v_error);
   ELSIF p_cod_servicio = 8 THEN
      IF p_periodo is not null THEN
         PR_PRO_EJE_SERVICIOS(p_cod_persona, p_periodo, p_cod_servicio, v_error);
      ELSE
         v_error := 'Periodo no puede ser nulo para este Servicio';
      END IF;
   ELSIF p_cod_servicio = 9 THEN
      PR_PRO_EJE_SERVICIOS(p_cod_persona, null, p_cod_servicio, v_error);
   END IF;
   RETURN v_error;
EXCEPTION
   WHEN others THEN
      return 'Error en el procedimiento principal. Lugar: '||g_lugar||'. Error: '||sqlerrm;
END;                                

END PAW_BCP;
/

